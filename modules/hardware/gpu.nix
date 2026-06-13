# =============================================================================
# Hardware abstraction for GPU's
#
# DESIGN CONSTRAINTS:
# 1. Desktop environments query `cfg.vendor` to self-configure.
# 2. Enforces VRAM allocation preservation to survive suspend and hibernation
#    states.
# =============================================================================
{ ... }: {
  flake.nixosModules.hardware-gpu =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.gpu;
    in
    {
      options.my.hardware.gpu = {
        vendor = lib.mkOption {
          type = lib.types.enum [
            "none"
            "nvidia"
          ];
          default = "none";
          description = "The primary GPU vendor driving the display.";
        };
        multiGpu = lib.mkEnableOption "Optimizations for multi-GPU setups";
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.vendor != "none") {
          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };
        })

        (lib.mkIf (cfg.vendor == "nvidia") {
          services.xserver.videoDrivers = [ "nvidia" ];

          my.allowedUnfree = [
            "nvidia-x11"
            "nvidia-settings"
            "nvidia-kernel-modules"
          ];

          hardware.nvidia = {
            modesetting.enable = true;
            videoAcceleration = true;
            branch = "latest";
            open = false;
            nvidiaSettings = true;
            powerManagement.enable = true;
            nvidiaPersistenced = cfg.multiGpu;
          };

          environment.sessionVariables = {
            LIBVA_DRIVER_NAME = "nvidia";
            GBM_BACKEND = "nvidia-drm";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          };

          # TODO: Figure out which one of these fixes "suspend-then-hibernate"
          boot.kernelParams = [
            "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
            "nvidia.NVreg_TemporaryFilePath=/var/tmp"
          ];

          # systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
          #   "false";
          # systemd.services.systemd-hibernate.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
          #   "false";
          # systemd.services.systemd-suspend-then-hibernate.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
          #   "false";

          systemd.services.nvidia-suspend = {
            before = [ "systemd-suspend-then-hibernate.service" ];
            wantedBy = [ "systemd-suspend-then-hibernate.service" ];
          };

          systemd.services.nvidia-resume = {
            after = [ "systemd-suspend-then-hibernate.service" ];
            wantedBy = [ "systemd-suspend-then-hibernate.service" ];
          };

          # TODO: End
        })
      ];
    };
}
