{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  allUsers = config.my.host.users;
  nvimUsers = lib.filterAttrs (_: u: u.programs.neovim.enable) allUsers;
in
{
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
            throw "User '${userName}': Neovim profile '${nvimCfg.profile}' does not exist in 'inputs.nvim-config.configs.${system}'. Available: ${toString (lib.attrNames systemConfigs)}";

        nvim-wrapper = pkgs.writeShellScriptBin "nvim" ''
          #!/usr/bin/env bash
          export XDG_CONFIG_HOME="${profile.dir}"

          export XDG_CACHE_HOME="$HOME/.cache/nvim/${nvimCfg.profile}"
          export XDG_DATA_HOME="$HOME/.local/share/nvim/${nvimCfg.profile}"

          exec "${pkgs.neovim-unwrapped}/bin/nvim" "$@"
        '';
      in
      {
        packages = [ nvim-wrapper ] ++ profile.deps;
      }
    ) nvimUsers;
  };
}
