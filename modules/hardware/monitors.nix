# Purpose: Hardware abstraction for physical displays.
# Scope: Centralized data structure for Window Managers and early KMS rendering.
# Invariants:
# - Sets early KMS video kernel parameters for TTY and Display Managers.
_: {
  flake.nixosModules.hardware-monitors =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.monitors;
    in
    {
      options.my.hardware.monitors = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                example = "DP-1";
                description = "The port name of the monitor (DP-1, HDMI-A-1).";
              };
              primary = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "If true, this monitor is used for the TTY and boot screen.";
              };
              width = lib.mkOption {
                type = lib.types.int;
                example = 3840;
              };
              height = lib.mkOption {
                type = lib.types.int;
                example = 2160;
              };
              refreshRate = lib.mkOption {
                type = lib.types.number;
                default = 60;
                description = "Refresh rate in Hz.";
              };
              x = lib.mkOption {
                type = lib.types.int;
                default = 0;
              };
              y = lib.mkOption {
                type = lib.types.int;
                default = 0;
              };
              scale = lib.mkOption {
                type = lib.types.str;
                default = "1";
              };
              ttyWidth = lib.mkOption {
                type = lib.types.int;
                default = 1920;
              };
              ttyHeight = lib.mkOption {
                type = lib.types.int;
                default = 1080;
              };
              ttyRefreshRate = lib.mkOption {
                type = lib.types.number;
                default = 60;
              };
            };
          }
        );
        default = [ ];
        description = "List of physical monitors connected to the system.";
      };

      config = lib.mkIf (builtins.length cfg > 0) {
        boot.kernelParams = map (
          m:
          "video=${m.name}:${toString m.ttyWidth}x${toString m.ttyHeight}@${toString m.ttyRefreshRate}"
        ) cfg;
      };
    };
}
