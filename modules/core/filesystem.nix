{ lib, config, ... }:
{
  # Secure /boot
  # Prevents modification of boot files by non-root users.
  fileSystems."/boot".options = lib.mkForce [ "umask=0077" ];

  # Harden /tmp
  # Use RAM for /tmp and restrict execution.
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%";
    cleanOnBoot = true;
  };

  # Apply mount options to the tmpfs mount
  systemd.mounts = [
    {
      where = "/tmp";
      what = "tmpfs";
      type = "tmpfs";
      mountConfig.Options = "mode=1777,strictatime,nodev,nosuid,noexec";
    }
  ];

  # Harden Shared Memory (/dev/shm)
  fileSystems."/dev/shm" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=1777"
      "nosuid"
      "nodev"
      "strictatime"
      "noexec"
    ];
  };

  # Restrict /home
  fileSystems."/home".options = lib.mkIf (config.fileSystems ? "/home") [
    "nodev"
    "nosuid"
  ];

  # Hide processes from other users (hardening /proc).
  # Users can only see their own processes.
  boot.specialFileSystems."/proc" = {
    device = "proc";
    fsType = "proc";
    options = [
      "nosuid"
      "nodev"
      "noexec"
      "hidepid=2"
    ];
  };
}
