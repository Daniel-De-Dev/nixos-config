# Purpose: Expose the shared Neovim wrapper as a standalone app and system editor.
# Scope: User-space terminal editor configuration.
{ inputs, ... }: {
  perSystem = { config, pkgs, ... }: {
    packages.nvim = pkgs.callPackage ../../../packages/neovim {
      inherit (inputs) wrapper-manager;
      appName = "nixos-config-nvim";
    };

    apps.nvim = {
      type = "app";
      meta.description = "Run Neovim with this repository's configuration";
      program = "${config.packages.nvim}/bin/nvim";
    };

    checks.nvim = pkgs.runCommand "nvim-startup-check" { } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/.config"
      export XDG_DATA_HOME="$HOME/.local/share"
      export XDG_STATE_HOME="$HOME/.local/state"
      export XDG_CACHE_HOME="$HOME/.cache"

      # Catch accidental loading of the recipient's configuration or plugins.
      mkdir -p "$XDG_CONFIG_HOME/nvim" \
        "$XDG_DATA_HOME/nvim/site/pack/test/start/unexpected/plugin"
      echo 'error("unexpected user init.lua")' > "$XDG_CONFIG_HOME/nvim/init.lua"
      echo 'vim.g.unexpected_user_plugin = true' \
        > "$XDG_DATA_HOME/nvim/site/pack/test/start/unexpected/plugin/init.lua"
      export NVIM_APPNAME=nvim
      export VIMINIT='lua error("unexpected VIMINIT")'

      # Use a loopback RPC server where the build environment restricts Unix sockets.
      ${config.packages.nvim}/bin/nvim --headless -n -i NONE \
        --cmd "lua vim.g.fzf_lua_server = vim.fn.serverstart('127.0.0.1:0')" \
        -c "lua dofile('${../../../tests/neovim.lua}')"
      touch "$out"
    '';
  };

  flake.nixosModules.programs-nvim =
    {
      pkgs,
      config,
      lib,
      machine,
      ...
    }:
    let
      cfg = config.my.programs.nvim;
      opUsername = config.my.operator.username;
      wrappedNvim = pkgs.callPackage ../../../packages/neovim {
        inherit (inputs) wrapper-manager;
      };
    in
    {
      options.my.programs.nvim.enable = lib.mkEnableOption "Neovim";
      config = lib.mkIf cfg.enable {
        users.users.${opUsername}.packages = [ wrappedNvim ];
        environment.variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          NIXOS_HOSTNAME = machine;
        };
      };
    };
}
