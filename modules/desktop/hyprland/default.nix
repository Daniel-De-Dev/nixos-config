{ ... }:
{
  flake.nixosModules.hyprland =
    { config, lib, ... }:
    let
      cfg = config.my.desktop.hyprland;
    in
    {
      options.my.desktop.hyprland.enable =
        lib.mkEnableOption "Hyprland Desktop Environment";

      config = lib.mkIf cfg.enable {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          withUWSM = true;
        };

        # Set required environment variables for Wayland
        environment.sessionVariables = {
          WLR_NO_HARDWARE_CURSORS = "1";
          NIXOS_OZONE_WL = "1";
        };
      };
    };
}
