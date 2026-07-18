# Purpose: Defines global unified color palette options for system-wide themes.
# Scope: Repository invariants and visual design tokens.
_: {
  # TODO: properly define and integrate it into the project
  # idea is to centrelize themes
  flake.nixosModules.core-palette = { lib, ... }: with lib;
    {
      options.my.desktop.hyprland.palette = {
        bg = mkOption {
          type = types.str;
          default = "0b0b0b";
        };
        surface = mkOption {
          type = types.str;
          default = "161616";
        };
        active_border = mkOption {
          type = types.str;
          default = "ffffff";
        };
        inactive_border = mkOption {
          type = types.str;
          default = "262626";
        };
      };
    };
}
