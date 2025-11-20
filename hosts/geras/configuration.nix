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

  my.host.users.main = {
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

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.05";
}
