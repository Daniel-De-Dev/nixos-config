{ config, ... }:
let
  adminName = config.my.privacy.schema.users.main.name;
in
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

  # Define admin user
  users.users.${adminName} = config.my.users.predefined.admin // {
    group = "${adminName}";
  };
  users.groups.${adminName} = { };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # allow for having internet upon first startup
  networking.networkmanager.enable = true;

  # git needed intially
  programs.git.enable = true;

  # Make neovim available system wide
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  console.keyMap = config.my.privacy.schema.console.keyMap;

  system.stateVersion = "25.05";
}
