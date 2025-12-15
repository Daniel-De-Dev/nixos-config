{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;

  users.users.main.packages = with pkgs; [
    discord
    protonvpn-gui
  ];

  programs.steam = {
    enable = true;
  };

  boot.kernelParams = [
    "video=DP-1:1920x1080@60"
    "video=HDMI-A-2:1920x1080@60"
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
        features = {
          ssh.enable = true;
          gpg.enable = true;
        };
      };

      users.main.config.hyprland.variables = {
        monitorConfig = ''
          monitorv2 {
            output = DP-1
            mode = 2560x1440@170
            position = 0x0
            scale = 1
          }
          monitorv2 {
            output = HDMI-A-2
            mode = 1920x1080@60
            position = 2560x360
            scale = 1
          }
          monitor=,preferred,auto,1
        '';
      };

      profiles.desktop.enable = true;

      hardware = {
        gpu.type = "nvidia";

        hibernation = {
          enable = true;
          resumeOffset = 109407071;
          resumeDevice = "/dev/mapper/cryptroot";
        };

        disks = {
          "/dev/disk/by-uuid/2d8f30c9-608e-4111-aa9f-ff13218b78f4" = {
            type = "ssd";
          };
        };

        luks = {
          "cryptroot" = {
            device = "/dev/disk/by-uuid/2d8f30c9-608e-4111-aa9f-ff13218b78f4";
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
