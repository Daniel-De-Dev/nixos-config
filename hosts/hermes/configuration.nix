{
  imports = [
    ./hardware-configuration.nix
  ];

  my = {
    privacy = {
      enable = true;
      bootstrap = false;
      sshAliasConfig = {
        enable = true;
        sshKey = "/etc/nixos/secrets/nixos-privacy-key";
      };
    };

    host = {
      users.main = {
        name = "zeus";
        features = {
          ssh.enable = true;
          gpg.enable = true;
        };
      };

      profiles.desktop.enable = true;

      hibernation.enable = true;

      hardware = {
        disks = {
          "/dev/disk/by-uuid/993242b4-5b5d-43b7-b526-771570329a2e" = {
            type = "ssd";
          };
        };

        luks = {
          "cryptroot" = {
            device = "/dev/disk/by-uuid/993242b4-5b5d-43b7-b526-771570329a2e";
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
      size = 34332; # ~36 GB
    }
  ];

  boot.kernelParams = [ "resume_offset=10008738" ];
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
