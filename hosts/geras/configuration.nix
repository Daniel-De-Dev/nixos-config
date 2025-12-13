{
  imports = [
    ./hardware-configuration.nix
  ];

  my = {
    privacy = {
      enable = true;

      sshAliasConfig = {
        enable = true;
        sshKey = "/etc/nixos/secrets/nixos-privacy-key";
      };
    };

    host = {
      profiles.desktop.enable = true;

      users.main = {
        features = {
          ssh.enable = true;
          gpg.enable = true;
        };
      };

      hibernation.enable = true;
      hardware = {
        battery = "BAT0";
        disks = {
          "/dev/disk/by-uuid/aae4e3b1-b95d-4be0-b050-5ffcbf16784a" = {
            type = "ssd";
          };
        };

        luks = {
          "cryptroot" = {
            device = "/dev/disk/by-uuid/aae4e3b1-b95d-4be0-b050-5ffcbf16784a";
          };
        };

        mounts = {
          "/" = {
            type = "btrfs";
            device = "cryptroot";
          };
          "/home" = {
            type = "btrfs";
            device = "cryptroot";
          };
          "/nix" = {
            type = "btrfs";
            device = "cryptroot";
          };
          "/swap" = {
            type = "btrfs";
            device = "cryptroot";
            compress = false;
          };
        };
      };
    };
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 15259; # ~16 GB
    }
  ];

  boot.kernelParams = [ "resume_offset=2664699" ];
  boot.resumeDevice = "/dev/mapper/cryptroot";
  powerManagement.enable = true;

  my.host.secureBoot = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  system.stateVersion = "25.05";
}
