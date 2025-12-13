{
  lib,
  config,
  pkgs,
  inputs,
  hostName,
  ...
}:
let
  allUsers = config.my.host.users;
  nvimUsers = lib.filterAttrs (_: u: u.programs.neovim.enable) allUsers;
in
{
  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.programs.neovim = {
          enable = lib.mkEnableOption ''
            Enable the setting up and managing of neovim configuration
            for this user.
          '';
          profile = lib.mkOption {
            type = lib.types.str;
            description = "The profile to use from 'inputs.nvim-config.configs'.";
          };
          configPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Absolute path the where the nvim config repo lives on system
              Used for developer mode so it is used as config once env
              variable is set (see neovim.nix)
            '';
          };
        };
      }
    );
  };

  config = {
    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        nvimCfg = userConfig.programs.neovim;
        system = pkgs.stdenv.hostPlatform.system;

        nvimConfig =
          if inputs ? nvim-config then
            inputs.nvim-config
          else
            throw "User '${userName}': 'programs.neovim' is enabled, but 'inputs.nvim-config' is not present in your flake.";

        systemConfigs =
          if nvimConfig.configs ? ${system} then
            nvimConfig.configs.${system}
          else
            throw "User '${userName}': 'inputs.nvim-config.configs' has no attribute '${system}'.";

        profile =
          if systemConfigs ? ${nvimCfg.profile} then
            systemConfigs.${nvimCfg.profile}
          else
            throw "User '${userName}': Neovim profile '${nvimCfg.profile}' does not exist for system '${system}' in 'inputs.nvim-config.configs.${system}'. Available: ${toString (lib.attrNames systemConfigs)}";

        nvim-wrapper = pkgs.writeShellScriptBin "nvim" ''
          #!/usr/bin/env bash
          set -euo pipefail

          NVIM_REPO_PATH="${if nvimCfg.configPath != null then nvimCfg.configPath else ""}"
          NVIM_PROFILE="${nvimCfg.profile}"

          if [ "''${NIX_NVIM_DEV:-0}" = "1" ]; then
            echo "STARTING NEOVIM IN DEV MODE"

            if [ -z "$NVIM_REPO_PATH" ]; then
              echo "Error: NIX_NVIM_DEV is set to 1, but no 'configPath' was defined in the user configuration."
              echo "Please set 'programs.neovim.configPath' to your local repo path string."
              exit 1
            fi

            # Setup the dev environment
            DEV_CONFIG="$HOME/.cache/nvim-dev/$NVIM_PROFILE"
            mkdir -p "$DEV_CONFIG"

            SOURCE_CONFIG="$NVIM_REPO_PATH/profiles/$NVIM_PROFILE/config"

            if [ ! -d "$SOURCE_CONFIG" ]; then
              echo "Error: Configuration profile not found at: $SOURCE_CONFIG"
              exit 1
            fi

            # Symlink local config so Neovim finds init.lua in .../nvim/init.lua
            ln -snf "$SOURCE_CONFIG" "$DEV_CONFIG/nvim"

            export XDG_CONFIG_HOME="$DEV_CONFIG"
            export XDG_DATA_HOME="$HOME/.local/share/nvim-dev/$NVIM_PROFILE"
            export XDG_CACHE_HOME="$HOME/.cache/nvim-dev/$NVIM_PROFILE-cache"

          else
            # Standard Nix mode
            export XDG_CONFIG_HOME="${profile.dir}"
            export XDG_DATA_HOME="$HOME/.local/share/nvim/${nvimCfg.profile}"
            export XDG_CACHE_HOME="$HOME/.cache/nvim/${nvimCfg.profile}"
          fi

          export NIXOS_HOSTNAME="${hostName}"

          exec "${pkgs.neovim-unwrapped}/bin/nvim" "$@"
        '';
      in
      {
        packages = [ nvim-wrapper ] ++ profile.deps;
      }
    ) nvimUsers;
  };
}
