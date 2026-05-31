# =============================================================================
# Manages the graphical login manager
#
# DESIGN CONSTRAINTS:
# 1. Strictly enforces a terminal-based aesthetic.
# 2. Automatically points to the system's default Wayland compositor.
# =============================================================================
{ ... }:
{
  flake.nixosModules.desktop-display-manager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.my.desktops.greetd;
    in
    {
      options.my.desktops.greetd.enable = lib.mkEnableOption "greetd display manager";

      config = lib.mkIf cfg.enable {
        environment.pathsToLink = [
          "/share/wayland-sessions"
          "/share/xsessions"
        ];

        services.greetd = {
          enable = true;
          useTextGreeter = true;
          settings = {
            default_session = {
              command = ''
                  ${pkgs.tuigreet}/bin/tuigreet \
                --time \
                --remember \
                --remember-user-session \
                --asterisks \
                --sessions /run/current-system/sw/share/wayland-sessions:/run/current-system/sw/share/xsessions
              '';
              user = "greeter";
            };
          };
        };

        # Prevent the raw console from fighting with greetd over TTY1
        boot.kernelParams = [ "console=tty1" ];
      };
    };
}
