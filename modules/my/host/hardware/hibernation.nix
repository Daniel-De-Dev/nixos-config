{
  lib,
  config,
  ...
}:
let
  cfg = config.my.host.hardware.hibernation;
in
{
  options.my.host.hardware.hibernation = {
    enable = lib.mkEnableOption "Hibernation support";

    resumeOffset = lib.mkOption {
      type = lib.types.int;
      description = "The offset of the swapfile in the filesystem.";
    };

    resumeDevice = lib.mkOption {
      type = lib.types.str;
      description = "The device path (usually mapper/cryptroot) where the swapfile resides.";
    };
  };

  config = lib.mkIf cfg.enable {
    powerManagement.enable = true;

    boot.resumeDevice = cfg.resumeDevice;
    boot.kernelParams = [ "resume_offset=${toString cfg.resumeOffset}" ];

    # NOTE: Hibernation by defintion requires to write kernel from disk to ram
    security.protectKernelImage = false;

    services.logind.settings.Login.handleLidSwitch = "suspend-then-hibernate";
    systemd.sleep.extraConfig = "HibernateDelaySec=1h";

    assertions = [
      {
        assertion = config.swapDevices != [ ];
        message = ''
          [${config.my.host.name}] Hibernation is enabled, yet swapDevices list 
          is empty, please define one (with a size greater than actual ram on host)
        '';
      }
    ];
  };
}
