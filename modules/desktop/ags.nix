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
