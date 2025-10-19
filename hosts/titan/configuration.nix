{ config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
  ];

  # Enable and configure the privacy module for titan
  my.privacy = {
    enable = true;

    sshAliasConfig = {
      enable = true;
      sshKey = "/etc/nixos/secrets/nixos-privacy-key";
    };
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

  console.keyMap = config.my.privacy.data.console.keyMap or "us";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  system.stateVersion = "25.05";
}
