# Hardware abstraction for physical displays.
_: {
  flake.nixosModules.hardware-monitors =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.monitors;
      positiveNumber = lib.types.addCheck lib.types.number (value: value > 0);
      connectors = lib.filter (m: m.connector != null) cfg;
    in
    {
      options.my.hardware.monitors = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule (
            { config, ... }: {
              options = {
                description = lib.mkOption {
                  type = lib.types.nullOr (lib.types.strMatching ".+");
                  default = null;
                  description = "Monitor's EDID description, without a compositor prefix or connector suffix.";
                };

                connector = lib.mkOption {
                  type = lib.types.nullOr (lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9-]*");
                  default = null;
                  example = "DP-1";
                  description = "Kernel DRM connector for the console mode. Also a desktop fallback when no description is provided.";
                };

                width = lib.mkOption {
                  type = lib.types.ints.positive;
                  description = "Desktop mode width in physical pixels.";
                };

                height = lib.mkOption {
                  type = lib.types.ints.positive;
                  description = "Desktop mode height in physical pixels.";
                };

                refreshRate = lib.mkOption {
                  type = positiveNumber;
                  default = 60;
                  description = "Desktop refresh rate in Hz, including fractional rates.";
                };
                x = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                  description = "Horizontal desktop position in logical pixels, after scaling.";
                };
                y = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                  description = "Vertical desktop position in logical pixels, after scaling.";
                };
                scale = lib.mkOption {
                  type = positiveNumber;
                  default = 1;
                  description = "Desktop scale factor.";
                };
                ttyWidth = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = config.width;
                  defaultText = lib.literalExpression "width";
                  description = "Console mode width in pixels; defaults to the desktop width.";
                };
                ttyHeight = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = config.height;
                  defaultText = lib.literalExpression "height";
                  description = "Console mode height in pixels; defaults to the desktop height.";
                };
                ttyRefreshRate = lib.mkOption {
                  type = lib.types.ints.positive;
                  default = 60;
                  description = "Console refresh rate in whole Hz, as required by the kernel video parameter.";
                };
              };
            }
          )
        );
        default = [ ];
        description = "Host monitor identities, desktop layout, and optional DRM console modes.";
      };

      config = lib.mkIf (builtins.length cfg > 0) {
        assertions = [
          {
            assertion = lib.all (m: m.description != null || m.connector != null) cfg;
            message = "Each my.hardware.monitors entry needs a description or connector.";
          }
          {
            assertion =
              lib.length (lib.unique (map (m: m.connector) connectors))
              == lib.length connectors;
            message = "my.hardware.monitors must not repeat a DRM connector.";
          }
          {
            assertion =
              let
                descriptions = map (m: m.description) (
                  lib.filter (m: m.description != null) cfg
                );
              in
              lib.length (lib.unique descriptions) == lib.length descriptions;
            message = "my.hardware.monitors descriptions must be unique; use connectors for identical monitors without unique descriptions.";
          }
        ];

        boot.kernelParams = map (
          m:
          "video=${m.connector}:${toString m.ttyWidth}x${toString m.ttyHeight}@${toString m.ttyRefreshRate}"
        ) connectors;
      };
    };
}
