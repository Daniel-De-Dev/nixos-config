# Package and run the desktop shell independently of compositor configuration.
{ self, ... }: {
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tooling = pkgs.callPackage ../../packages/ags-shell/tooling.nix { };
      source = lib.fileset.toSource {
        root = ../../packages/ags-shell;
        fileset = lib.fileset.unions [
          ../../packages/ags-shell/src
          ../../packages/ags-shell/tests/types.test.ts
          ../../packages/ags-shell/tsconfig.json
          ../../packages/ags-shell/eslint.config.mjs
        ];
      };
      check =
        name: command:
        pkgs.runCommand name { nativeBuildInputs = [ tooling ]; } ''
          cp -R ${source}/. .
          chmod -R u+w .
          ln -s ${tooling}/node_modules node_modules
          ${command}
          touch "$out"
        '';
    in
    {
      packages.ags-shell = pkgs.callPackage ../../packages/ags-shell { };
      packages.ags-tooling = tooling;
      packages.clipboard-history = pkgs.callPackage ../../packages/clipboard { };
      checks.ags-clipboard =
        pkgs.runCommand "ags-clipboard-tests"
          {
            nativeBuildInputs = [
              (pkgs.python3.withPackages (ps: [ ps.pillow ]))
              pkgs.ffmpeg-headless
            ];
          }
          ''
            mkdir -p packages
            cp -R ${../../packages/clipboard} packages/clipboard
            cp ${../../tests/clipboard.py} test_clipboard.py
            mkdir -p packages/ags-shell/tests
            cp ${../../packages/ags-shell/tests/search-cases.json} packages/ags-shell/tests/search-cases.json
            mkdir -p modules/desktop/hyprland/src/scripts
            cp ${./hyprland/src/scripts/screenshot.sh} modules/desktop/hyprland/src/scripts/screenshot.sh
            PYTHONDONTWRITEBYTECODE=1 python -m unittest -v test_clipboard
            touch "$out"
          '';
      checks.ags-types = check "ags-types-check" "tsc --noEmit";
      checks.ags-lint = check "ags-lint-check" "eslint src --max-warnings=0";
      checks.ags-shell = config.packages.ags-shell;
      checks.ags-search =
        pkgs.runCommand "ags-search-tests" { nativeBuildInputs = [ pkgs.nodejs_24 ]; }
          ''
            mkdir -p src
            cp -R ${../../packages/ags-shell/src/lib} src/lib
            cp -R ${../../packages/ags-shell/tests} tests
            node --experimental-strip-types --test tests/*.test.mjs
            touch "$out"
          '';

      devShells.ags = pkgs.mkShell {
        packages = [
          tooling
          pkgs.git
          pkgs.nodejs_24
          pkgs.vscode-langservers-extracted
        ];
        shellHook = ''
          ags_project="$(git rev-parse --show-toplevel)/packages/ags-shell"
          if [[ ! -f "$ags_project/tsconfig.json" ]]; then
            echo "Enter the AGS shell from the nixos-config checkout." >&2
            return 1
          fi
          if [[ -e "$ags_project/node_modules" && ! -L "$ags_project/node_modules" ]]; then
            echo "Move the existing packages/ags-shell/node_modules directory aside before using the Nix environment." >&2
            return 1
          fi
          ln -sfnT ${tooling}/node_modules "$ags_project/node_modules"
        '';
      };
    };

  flake.nixosModules.desktop-ags =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.desktop.ags;
      profileBinDirs = lib.concatMapStringsSep ":" (
        profile: "${profile}/bin"
      ) config.environment.profiles;
      profileDataDirs = lib.concatMapStringsSep ":" (
        profile: "${profile}/share"
      ) config.environment.profiles;
    in
    {
      imports = [ self.nixosModules.core-palette ];

      options.my.desktop.ags = {
        enable = lib.mkEnableOption "the AGS desktop shell";
        package = lib.mkOption {
          type = lib.types.package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.ags-shell.override {
            theme = config.my.theme;
          };
          description = "Shell package providing ags-shell and ags-shell-request.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.programs.hyprland.enable;
            message = "The current AGS window switcher requires Hyprland.";
          }
        ];

        environment.systemPackages = [ cfg.package ];
        fonts.packages = config.my.theme.fonts.packages;

        systemd.user.services.ags = {
          description = "AGS desktop shell";
          partOf = [ "graphical-session.target" ];
          wantedBy = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          # User services do not source the NixOS shell environment.
          # GIO needs profile binaries for Exec/TryExec and terminal discovery.
          # Expand profile variables before GIO caches its application search paths.
          script = ''
            XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
            export PATH="${profileBinDirs}:$PATH"
            export XDG_DATA_DIRS="${profileDataDirs}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            exec ${lib.getExe cfg.package}
          '';
          serviceConfig = {
            Restart = "on-failure";
          };
        };
      };
    };

  flake.nixosModules.desktop-ags-hyprland =
    { config, lib, ... }:
    let
      cfg = config.my.desktop.ags;
      integration = import ../../packages/ags-shell/hyprland.nix { inherit lib; };
    in
    {
      imports = [ self.nixosModules.desktop-ags ];

      options.my.desktop.ags.hyprland = integration.options;

      config = lib.mkIf (cfg.enable && config.my.desktop.hyprland.enable) {
        my.desktop.hyprland = integration.render {
          # Keep style/bundle changes out of the installed compositor's Lua.
          command = "/run/current-system/sw/bin/ags-shell-request";
          bindings = cfg.hyprland;
        };
      };
    };
}
