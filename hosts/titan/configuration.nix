{ pkgs, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
  ];

  # Enable the privacy module for titan
  my.privacy.enable = true;

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

  #! Temporary solution for now
  # Configure Nix to use the deploy key for fetching private inputs.
  # The key must be manually placed at /etc/nixos/secrets/nixos-privacy-key
  # Steps:
  # sudo mkdir -p /etc/nixos/secrets
  # sudo mv </path/to/key> /etc/nixos/secrets/ (assumes the key as been transferred)
  # sudo chown root:root /etc/nixos/secrets/nixos-privacy-key
  # sudo chmod 0400 /etc/nixos/secrets/nixos-privacy-key
  nix.extraOptions = ''
    netrc-file = ${pkgs.writeText "netrc" ''
      machine github.com login git
    ''}
    ssh-command = ${pkgs.openssh}/bin/ssh -i /etc/nixos/secrets/nixos-privacy-key -o StrictHostKeyChecking=no
  '';

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
