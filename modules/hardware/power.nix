# =============================================================================
# Manages power profiles, battery abstraction, and laptop-specific daemon
# tuning.
#
# DESIGN CONSTRAINTS:
# 1. Opt-in via defining a `batteryId`. If null, the machine is treated as a
#    desktop.
# =============================================================================
{ ... }:
{
  flake.nixosModules.hardware-power =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.power;
    in
    {
      options.my.hardware.power = {
        batteryId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "BAT0";
          description = "The ACPI battery ID. If set, enables laptop power profiles.";
        };
      };

      config = lib.mkIf (cfg.batteryId != null) { services.upower.enable = true; };
    };
}
