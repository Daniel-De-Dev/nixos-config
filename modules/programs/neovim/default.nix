# =============================================================================
# Configures Neovim as the default system editor.
# =============================================================================
{ ... }: {
  flake.nixosModules.programs-nvim =
    {
      pkgs,
      config,
      inputs,
      lib,
      machine,
      ...
    }:
    let
      cfg = config.my.programs.nvim;
      opUsername = config.my.operator.username;

      nvimDeps = with pkgs; [
        lua-language-server
        nixd
        bash-language-server
        fish-lsp
        marksman
        basedpyright
        ruff
        typescript-language-server
        vscode-langservers-extracted
        astro-language-server

        fzf
        ripgrep
        fd
        wl-clipboard
        xclip
      ];

      darkvoid-nvim = pkgs.vimUtils.buildVimPlugin {
        name = "darkvoid.nvim";
        src = pkgs.fetchFromGitHub {
          owner = "darkvoid-theme";
          repo = "darkvoid.nvim";
          rev = "45be993a5617e05811b6b293c05e6aded7003cc9";
          hash = "sha256-JiNuv1TAIHVL9tGNDYC0RdRPnI9l4zn+ZCU9B4wQ5Io=";
        };
      };

      myPlugins = with pkgs.vimPlugins; [
        gitsigns-nvim
        darkvoid-nvim
        nvim-treesitter.withAllGrammars
        mini-nvim
        fzf-lua
        blink-cmp
        oil-nvim
        fidget-nvim
        lazydev-nvim
        lualine-nvim
        nvim-web-devicons
        todo-comments-nvim
        harpoon2
        plenary-nvim
      ];

      pluginPack = pkgs.runCommand "nvim-packpath" { } ''
        mkdir -p $out/pack/nix/start
        for plugin in ${builtins.concatStringsSep " " myPlugins}; do
          ln -s "$plugin" "$out/pack/nix/start/$(basename "$plugin")"
        done
      '';

      wm-eval = inputs.wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.nvim = {
              basePackage = pkgs.neovim-unwrapped;
              pathAdd = nvimDeps;

              env.HYPRLAND_STUBS.value = "${pkgs.hyprland}/share/hypr/stubs";

              prependFlags = [
                "-u"
                "${./config}/init.lua"
                "--cmd"
                "set packpath^=${pluginPack}"
                "--cmd"
                "set rtp^=${./config}"
              ];
            };
          }
        ];
      };

      wrappedNvim = wm-eval.config.wrappers.nvim.wrapped;

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
