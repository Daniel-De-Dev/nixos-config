# Purpose: Build the shared Neovim wrapper for NixOS and nix run.
# Scope: Editor configuration, plugins, and runtime tools.
{
  lib,
  pkgs,
  wrapper-manager,
  appName ? null,
}:
let
  nvimConfig = ../../modules/programs/neovim/config;

  nvimDeps = with pkgs; [
    lua-language-server
    nixd
    bash-language-server
    fish-lsp
    marksman
    basedpyright
    ruff
    nodejs # Runtime for project-local JS/TS language server scripts.
    typescript-language-server
    vscode-langservers-extracted
    astro-language-server
    svelte-language-server
    csharp-ls
    clang-tools
    tinymist
    harper

    git
    bat
    fzf
    ripgrep
    fd
    wl-clipboard
    xclip

    curl
    websocat
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
    typst-preview-nvim
  ];

  withDependencies =
    plugins:
    lib.concatMap (
      plugin: [ plugin ] ++ withDependencies (plugin.dependencies or [ ])
    ) plugins;
  allPlugins = lib.unique (withDependencies myPlugins);

  pluginPack = pkgs.runCommand "nvim-packpath" { } ''
    mkdir -p $out/pack/nix/start
    for plugin in ${builtins.concatStringsSep " " allPlugins}; do
      ln -s "$plugin" "$out/pack/nix/start/$(basename "$plugin")"
    done
  '';

  wm-eval = wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.nvim = {
          basePackage = pkgs.neovim-unwrapped;
          pathAdd = nvimDeps;

          env = {
            HYPRLAND_STUBS.value = "${pkgs.hyprland}/share/hypr/stubs";
          }
          // lib.optionalAttrs (appName != null) {
            NVIM_APPNAME = {
              value = appName;
              force = true;
            };
          };

          prependFlags = [
            "--cmd"
            "set packpath^=${pluginPack}"
            "--cmd"
            "set rtp^=${nvimConfig}"
            "-u"
            "${nvimConfig}/init.lua"
          ];
        };
      }
    ];
  };

in
wm-eval.config.wrappers.nvim.wrapped
