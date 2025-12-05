{ ... }:
{
  imports = [
    ./nix.nix
    ./gpg.nix
    ./sudo.nix
    ./ssh.nix
    ./fail2ban.nix
    ./firewall.nix
    ./security.nix
    ./networking.nix
    ./system.nix
    ./hardened-services.nix
    ./filesystem.nix
  ];
}
