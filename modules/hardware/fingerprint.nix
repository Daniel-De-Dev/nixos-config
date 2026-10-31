# Purpose: Opt-in fingerprint reader support and local authentication.
# Scope: fprintd, optional OEM drivers, and explicitly selected PAM services.
# Depends on: core-unfree for the driver allowlist.
_: {
  flake.nixosModules.hardware-fingerprint =
    { config, lib, ... }:
    let
      cfg = config.my.hardware.fingerprint;
    in
    {
      # TODO: Look into if possible to unlock luks disk via finger print
      # TODO: Look into what it takes to make fingerprints valid for ssh keys
      options.my.hardware.fingerprint = {
        enable = lib.mkEnableOption "fingerprint authentication";

        driver = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = ''
            Optional Touch OEM Driver. Leave null for readers supported by
            upstream libfprint. A selected driver's package name is added to
            the unfree allowlist.
          '';
        };

        pamServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "login"
            "sudo"
            "polkit-1"
          ];
          description = ''
            PAM services that accept an enrolled fingerprint as an alternative
            to a password. Select login for Ly, which uses the login substack.
            Hyprlock uses its native fingerprint backend instead.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.fprintd = {
          enable = true;
          # The upstream default enables fingerprint auth for every PAM service.
          enablePam = false;
          tod = lib.mkIf (cfg.driver != null) {
            enable = true;
            inherit (cfg) driver;
          };
        };

        my.allowedUnfree = lib.optional (cfg.driver != null) (lib.getName cfg.driver);
        services.udev.packages = lib.optional (cfg.driver != null) cfg.driver;

        security.pam.services = lib.genAttrs cfg.pamServices (_: {
          fprintAuth = true;
          # NixOS permits null passwords for login by default. An empty Ly
          # submission must start fingerprint auth, never bypass authentication.
          allowNullPassword = lib.mkForce false;
        });

        assertions = [
          {
            assertion = lib.all (
              name: config.security.pam.services.${name}.useDefaultRules
            ) cfg.pamServices;
            message = "my.hardware.fingerprint.pamServices requires services using NixOS default PAM rules; select login for Ly.";
          }
        ];
      };
    };
}
