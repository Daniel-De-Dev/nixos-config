# Package and run the desktop shell independently of compositor configuration.
{ self, ... }: {
  perSystem = { config, pkgs, ... }: {
    packages.ags-shell = pkgs.callPackage ../../packages/ags-shell { };
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
          serviceConfig = {
            ExecStart = lib.getExe cfg.package;
            Restart = "on-failure";
          };
        };
      };
    };

  flake.nixosModules.desktop-ags-hyprland =
    { config, lib, ... }:
    let
      cfg = config.my.desktop.ags;
      # Resolve the installed helper at runtime to keep bundle changes out of Lua.
      shellBinding =
        keys: request: description:
        let
          requestCommand = lib.escapeShellArgs [
            "/run/current-system/sw/bin/ags-shell-request"
            request
          ];
        in
        "nixos_shortcuts.bind(${builtins.toJSON keys}, hl.dsp.exec_cmd(${builtins.toJSON requestCommand}), ${builtins.toJSON description}, nil, ${
          lib.boolToString (request != "keybinding-search")
        })";
    in
    {
      imports = [ self.nixosModules.desktop-ags ];

      options.my.desktop.ags.hyprland.keybinding = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "SUPER + Tab";
        description = "Hyprland key combination, or null to omit the shell binding.";
      };

      options.my.desktop.ags.hyprland.keybindingSearch = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "SUPER + CTRL + K";
        description = "Hyprland key combination for shortcut search, or null to omit it.";
      };

      config = lib.mkIf (cfg.enable && config.my.desktop.hyprland.enable) {
        my.desktop.hyprland.extraLayerRules = [
          ''
            hl.layer_rule({
              name = "nixos-shell-no-animation",
              match = { namespace = "^nixos-shell$" },
              no_anim = true,
            })
          ''
        ];
        my.desktop.hyprland.extraBindings =
          lib.optional (cfg.hyprland.keybinding != null) (
            shellBinding cfg.hyprland.keybinding "window-switcher" "Windows: Switch window"
          )
          ++ lib.optional (cfg.hyprland.keybindingSearch != null) (
            shellBinding cfg.hyprland.keybindingSearch "keybinding-search"
              "Help: Search keyboard shortcuts"
          );
      };
    };
}
