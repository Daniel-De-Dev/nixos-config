# A Wayland-only desktop preview for an existing NixOS graphical session.
{
  lib,
  pkgs,
  wrapper-manager,
  agsShell,
  theme ?
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [ ../../themes/module.nix ];
    }).config.my.theme,
}:
let
  # TODO: Make the keyboard layout selectable trough options similarly to super
  desktop = import ./desktop.nix { inherit lib pkgs wrapper-manager; };
  shell = agsShell.override { inherit theme; };
  integration = (import ../ags-shell/hyprland.nix { inherit lib; }).render {
    command = "${shell}/bin/ags-shell-request";
  };
  services = pkgs.writeShellApplication {
    name = "hyprland-preview-services";
    text = ''
      ${lib.getExe shell} &
      ${lib.concatMapStringsSep "\n" (service: "${service.command} &") (
        lib.attrValues desktop.services
      )}
      ${lib.concatMapStringsSep "\n" (service: service.afterStart or "") (
        lib.attrValues desktop.services
      )}
      wait
    '';
  };
  autostartConf = pkgs.writeText "preview-autostart.lua" ''
    hl.on('hyprland.start', function()
      hl.exec_cmd(${builtins.toJSON (lib.getExe services)})
    end)
    hl.on('monitor.removed', function() hl.dispatch(hl.dsp.exit()) end)
  '';
  config = import ./config.nix {
    inherit
      lib
      pkgs
      desktop
      autostartConf
      ;
    inherit (theme) colors;
    nested = true;
    monitorRules = [
      ''hl.monitor({ output = "", mode = "1280x720@60", position = "auto", scale = 1 })''
    ];
    inherit (integration) extraLayerRules;
    extraBindings = integration.extraBindings ++ [
      "nixos_shortcuts.bind('SUPER + CTRL + SHIFT + Escape', hl.dsp.exit(), 'Preview: Close desktop')"
    ];
  };
  xkb = pkgs.runCommand "hyprland-preview-xkb" { } ''
    mkdir -p "$out/symbols"
    cp ${../../modules/desktop/hyprland/src/real-prog-dvorak} "$out/symbols/real-prog-dvorak"
  '';
  launcher = pkgs.writeShellApplication {
    name = "hyprland-preview";
    runtimeInputs = desktop.packages ++ [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = builtins.readFile (
      pkgs.replaceVars ./launch.sh {
        hyprland = "${pkgs.hyprland}/bin/Hyprland";
        startHyprland = "${pkgs.hyprland}/bin/start-hyprland";
        dbusRunSession = "${pkgs.dbus}/bin/dbus-run-session";
        bash = "${pkgs.bashInteractive}/bin/bash";
        inherit config;
      }
    );
  };
  wrapped = wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.hyprland-preview = {
          basePackage = launcher;
          programs.hyprland-preview.env = lib.mapAttrs (_: value: { inherit value; }) (
            desktop.environment
            // {
              FONTCONFIG_FILE = "${pkgs.makeFontsConf {
                fontDirectories = theme.fonts.packages ++ [ pkgs.noto-fonts-color-emoji ];
              }}";
              XCURSOR_PATH = "${desktop.cursor.package}/share/icons:${pkgs.adwaita-icon-theme}/share/icons";
              XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
              XKB_CONFIG_EXTRA_PATH = "${xkb}";
              XDG_DATA_DIRS = lib.concatMapStringsSep ":" (p: "${p}/share") (
                desktop.packages
                ++ [
                  pkgs.adwaita-icon-theme
                  pkgs.gsettings-desktop-schemas
                ]
              );
            }
          );
        };
      }
    ];
  };
in
wrapped.config.wrappers.hyprland-preview.wrapped.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit config desktop;
  };
  meta = (old.meta or { }) // {
    description = "Test the Hyprland desktop inside a Wayland window on NixOS";
    mainProgram = "hyprland-preview";
    platforms = lib.platforms.linux;
  };
})
