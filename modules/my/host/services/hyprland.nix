{
  lib,
  config,
  ...
}:
let
  cfg = config.my.host.services.hyprland;
  gpu = config.my.host.hardware.gpu;
in
{
  options.my.host.services.hyprland = {
    enable = lib.mkEnableOption "Hyprland Window Manager";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    environment.sessionVariables = lib.mkMerge [
      {
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        XDG_SESSION_TYPE = "wayland";
      }
      (lib.mkIf (gpu.type == "nvidia") {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        NVD_BACKEND = "direct";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      })
    ];
  };
}
