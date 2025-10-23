{ inputs, config, ... }:
let
  adminName = config.my.privacy.data.user.admin.name;
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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.${adminName} = ./home.nix;
  home-manager.extraSpecialArgs = { inherit inputs; };

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

  system.stateVersion = "25.05";
}
