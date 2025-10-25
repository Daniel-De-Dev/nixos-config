{ inputs, config, ... }:
let
  adminName = config.my.hostData.users.main.name;
  hostSystem = config.nixpkgs.hostPlatform.system;
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

    packages = [
      inputs.nvim-config.packages.${hostSystem}.default
    ];
  };
  users.groups.${adminName} = { };

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

  console.keyMap = config.my.hostData.console.keyMap;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.05";
}
