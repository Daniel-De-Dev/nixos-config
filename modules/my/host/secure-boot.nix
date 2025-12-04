{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.my.host.secureBoot;
in
{
  options.my.host.secureBoot = lib.mkEnableOption "Secure Boot support using Lanzaboote";

  # Following docs https://github.com/nix-community/lanzaboote/blob/6242b3b2b5e5afcf329027ed4eb5fa6e2eab10f1/docs/getting-started/prepare-your-system.md
  config = lib.mkIf cfg {
    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
