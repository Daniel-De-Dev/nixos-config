# Typed theme data, independent of the desktop, applications, and privacy input.
{ lib, pkgs, ... }:
let
  defaults = import ./carbon-dark.nix;
  color = lib.types.strMatching "#[0-9a-fA-F]{6}";
  optionsFor =
    type: description:
    lib.mapAttrs (
      name: value:
      lib.mkOption {
        inherit type;
        default = value;
        description = "${description} (${name}).";
      }
    );
in
{
  options.my.theme = {
    colors =
      optionsFor color "Shared semantic color in #RRGGBB format"
        defaults.colors;
    fonts = (optionsFor lib.types.singleLineStr "Font family" defaults.fonts) // {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [
          (pkgs.ibm-plex.override {
            families = [
              "sans"
              "mono"
            ];
          })
        ];
        description = "Font packages installed by theme consumers that need them.";
      };
    };
    fontSizes =
      optionsFor lib.types.ints.positive "Font size in logical pixels"
        defaults.fontSizes;
    spacing =
      optionsFor lib.types.ints.unsigned "Spacing in logical pixels"
        defaults.spacing;
  };
}
