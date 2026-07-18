# Purpose: Manages the graphical login manager.
# Scope: Desktop environment login and session routing.
# Invariants:
# - Enforces a minimal, terminal-based aesthetic via Ly.
# - Integrates natively with the system's displayManager domain.
_: {
  flake.nixosModules.desktop-display-manager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.my.desktop.ly;

      power = config.my.hardware.power;
      hibernate = config.my.hardware.hibernation;
    in
    {
      options.my.desktop.ly.enable = lib.mkEnableOption "Ly display manager";

      config = lib.mkIf cfg.enable {
        services.displayManager.ly = {
          enable = true;
          settings = {
            # Authentication & Input
            allow_empty_password = false;
            clear_password = true;
            default_input = "password";

            # Appearance
            # 0xSSRRGGBB: SS=Style, RR=Red, GG=Green, BB=Blue
            bg = "0x001d1d1d";
            error_bg = "0x001d1d1d";
            fg = "0x00c0c0c0";
            border_fg = "0x00595959";

            # UI Elements
            clock = "%H:%M";
            hide_key_hints = false;
            hide_version_string = true;
            xinitrc = null;

            # Visual Effects
            animate = false;
            animation = 0;

            # Battery
            battery_id = power.batteryId;

            # Power & Commands
            hibernate_cmd =
              if hibernate.enable then
                "${lib.getExe' pkgs.systemd "systemctl"} hibernate"
              else
                null;

            sleep_cmd =
              if hibernate.enable then
                "${lib.getExe' pkgs.systemd "systemctl"} suspend-then-hibernate"
              else
                "${lib.getExe' pkgs.systemd "systemctl"} suspend";

            inactivity_cmd =
              if hibernate.enable then
                "${lib.getExe' pkgs.systemd "systemctl"} suspend-then-hibernate"
              else
                "${lib.getExe' pkgs.systemd "systemctl"} suspend";

            inactivity_delay = 300;
          };
        };
      };
    };
}
