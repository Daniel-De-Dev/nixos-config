{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  users.users.main.packages = with pkgs; [
    # TODO: Move to desktop and integrate it with dotfiles/hyprland
    protonvpn-gui
  ];

  # NOTE: Split keyboard
  services.usbguard.rules = ''
    allow id 05e3:0608 name "USB2.0 Hub"
    allow id 05ac:024f name "USB KEYBOARD"
  '';

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

      profiles.desktop.enable = true;

      hardware = {
        battery = "BAT0";

        hibernation = {
          enable = true;
          resumeOffset = 10008738;
          resumeDevice = "/dev/mapper/cryptroot";
        };

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
