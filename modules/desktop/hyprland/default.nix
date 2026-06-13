{ ... }:
{
  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.desktop.hyprland;

      cursorTheme = "OpenZone_Black";
      cursorSize = "24";

      inputConf = pkgs.replaceVars ./src/input.conf {
        cursorTheme = cursorTheme;
        cursorSize = cursorSize;
      };

      hyprlandConf = inputConf;
    in
    {
      options.my.desktop.hyprland.enable =
        lib.mkEnableOption "Hyprland Desktop Environment";

      config = lib.mkIf cfg.enable {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          withUWSM = true;
          package =
            config.wrapper-manager.packages.${pkgs.stdenv.hostPlatform.system}.default.hyprland;
        };

        security.polkit.enable = true;

        wrapper-manager.packages.${pkgs.stdenv.hostPlatform.system}.default = {
          wrappers.hyprland = {
            basePackage = pkgs.hyprland;

            env = {
              # Core Wayland/GTK variables
              XDG_CURRENT_DESKTOP.value = "Hyprland";
              XDG_SESSION_TYPE.value = "wayland";
              XDG_SESSION_DESKTOP.value = "Hyprland";
              QT_QPA_PLATFORM.value = "wayland;xcb";
              GDK_BACKEND.value = "wayland,x11,*";

              # Cursor Environment Variables
              XCURSOR_THEME.value = cursorTheme;
              XCURSOR_SIZE.value = cursorSize;
            };

            flags = [
              "-c"
              "${hyprlandConf}"
            ];
          };
        };

        environment.sessionVariables = {
          WLR_NO_HARDWARE_CURSORS = "1";
          NIXOS_OZONE_WL = "1";
        };
      };
    };
}
