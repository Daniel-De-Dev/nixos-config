{ lib, config, ... }:
{
  # 1. Secure /boot (ESP)
  # Prevents modification of boot files by non-root users.
  # Currently set to 0022 in your hardware-config (readable by everyone).
  fileSystems."/boot".options = lib.mkForce [ "umask=0077" ];

  # 2. Harden /tmp
  # Use RAM for /tmp and restrict execution.
  # This prevents malware from dropping and running binaries in /tmp.
  boot.tmp = {
    useTmpfs = true;
    # If you run large builds in /tmp, you might need to increase this or disable noexec
    tmpfsSize = "50%";
    # strict mount options
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

  # 3. Harden Shared Memory (/dev/shm)
  # Prevent execution in shared memory (common attack vector)
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

  # 4. Restrict /home
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

  systemd.tmpfiles.rules = [
    "Z /home/* ~0700 - - - -"
  ];
}
