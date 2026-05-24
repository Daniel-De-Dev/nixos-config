# =============================================================================
# Configures a cryptographic root of trust for the operating system using
# Lanzaboote. Ensures only signed kernels and initrd images can be booted.
#
# DESIGN CONSTRAINTS:
# 1. This is an opt-in hardware profile. Make sure to do the nessessary setup
#    (Generate and install keys)
# 2. Automatically disables standard systemd-boot to prevent conflicts.
# =============================================================================
{ ... }:
{
  flake.nixosModules.hardware-secure-boot =
    {
      lib,
      config,
      pkgs,
      inputs,
      ...
    }:
    {
      # Ingest the external Lanzaboote module dynamically
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      config = {
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
