# Purpose: Configures system hibernation and resume capabilities.
# Scope: System power state and resume targets.
_: {
  flake.nixosModules.hardware-hibernation =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.hibernation;
    in
    {
      options.my.hardware.hibernation = {
        enable = lib.mkEnableOption "System hibernation capability";

        resumeOffset = lib.mkOption {
          type = lib.types.int;
          description = "The physical block offset of the swapfile on the filesystem.";
        };

        resumeDevice = lib.mkOption {
          type = lib.types.str;
          example = "/dev/mapper/cryptroot";
          description = "The block device path where the swapfile resides.";
        };
      };

      config = lib.mkIf cfg.enable {
        powerManagement.enable = true;

        boot.resumeDevice = cfg.resumeDevice;
        boot.kernelParams = [ "resume_offset=${toString cfg.resumeOffset}" ];

        # Hibernation requires writing the kernel from memory to disk
        security.protectKernelImage = false;

        # Power & Sleep Behavior
        services.logind.settings.Login = {
          handleLidSwitch = "suspend-then-hibernate";
          idleAction = "suspend-then-hibernate";
          idleActionSec = "30m";
        };
        systemd.sleep.settings.Sleep = {
          HibernateDelaySec = "30m";
        };

        assertions = [
          {
            assertion = config.swapDevices != [ ];
            message = "Hibernation is enabled, but the `swapDevices` list is empty. You must define a swapfile larger than your physical RAM in the host configuration.";
          }
        ];
      };
    };
}
