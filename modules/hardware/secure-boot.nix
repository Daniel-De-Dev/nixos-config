# Purpose: Cryptographic root of trust via Lanzaboote.
# Scope: Hardware bootloader override.
# Invariants:
# - Requires manual sbctl key generation.
# - Disables standard systemd-boot.
_: {
  flake.nixosModules.hardware-secure-boot =
    {
      lib,
      config,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      options.my.hardware.secure-boot.enable =
        lib.mkEnableOption "Secure Boot via Lanzaboote";

      config = lib.mkIf config.my.hardware.secure-boot.enable {
        # Secure Boot requires systemd-boot to be explicitly disabled so Lanzaboote
        # can take over the UEFI stub generation.
        boot.loader.systemd-boot.enable = lib.mkForce false;

        boot.lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
        };

        boot.initrd.systemd.enable = true;

        # SBCTL is required for generating and enrolling the platform keys.
        environment.systemPackages = [ pkgs.sbctl ];
      };
    };
}
