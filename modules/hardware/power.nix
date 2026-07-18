# Purpose: Manage power profiles and battery abstraction.
# Scope: Hardware power state.
# Invariants:
# - Opt-in via `batteryId`. Null treats machine as desktop.
_: {
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
