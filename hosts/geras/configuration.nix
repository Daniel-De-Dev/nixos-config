{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Enable and configure the privacy module for titan
  my.privacy = {
    enable = true;

    sshAliasConfig = {
      enable = true;
      sshKey = "/etc/nixos/secrets/nixos-privacy-key";
    };
  };

  my.host.hardware = {
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

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 15259; # ~16 GB
    }
  ];

  my.host.secureBoot = true;

  my.host.users.main = {
    shell = "fish";

    features = {
      sudo.enable = true;
      ssh.enable = true;
      gpg.enable = true;
    };

    programs = {
      git.template = ../../templates/git/personal;

      neovim = {
        enable = true;
        profile = "personal";
        configPath = config.users.users.main.home + "/repos/nvim-config";
      };

      tmux = {
        enable = true;
        template = ../../templates/tmux/personal;
      };
    };
  };

  users.users.main = {
    isNormalUser = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # allow for having internet upon first startup
  networking.networkmanager.enable = true;

  # git needed intially
  programs.git.enable = true;

  # initial editor setup
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  services.xserver.xkb.layout = config.my.host.keyMap;

  console = {
    enable = true;
    earlySetup = true;
    useXkbConfig = true;
    font = "ter-v20n";
    packages = with pkgs; [ terminus_font ];
  };

  services.kmscon = {
    enable = true;
    hwRender = true;
    useXkbConfig = true;
    fonts = [
      {
        name = "JetBrainsMono Nerd Font Mono";
        package = pkgs.nerd-fonts.jetbrains-mono;
      }
    ];
  };

  programs.direnv = {
    enable = true;
    silent = true;
  };

  system.stateVersion = "25.05";
}
