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
      options,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.my.hardware.secure-boot;
      kernel = config.boot.kernelPackages.kernel;
      verifiedKernel =
        (config.boot.kernelPackages.rebuildImage {
          target = config.system.boot.loader.kernelFile;
          inherit (config.system) modulesTree;
        }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              inherit (kernel) config configfile modDirVersion;
            };
          });
      verifiedKernelPath = "${verifiedKernel}/${config.system.boot.loader.kernelFile}";
    in
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      options.my.hardware.secure-boot.enable =
        lib.mkEnableOption "Secure Boot via Lanzaboote";

      options.my.hardware.secure-boot.verifyKernelModules = lib.mkOption {
        type = lib.types.bool;
        default = config.my.host.security.kernelLockdown != "none";
        defaultText = lib.literalExpression ''config.my.host.security.kernelLockdown != "none"'';
        description = ''
          Rebuild the booted kernel image with certificates for the complete module
          tree, including external modules, and enforce module signatures. Uses
          Nixpkgs' deterministic kmodigest support without a module signing secret.
        '';
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # Secure Boot requires systemd-boot to be explicitly disabled so Lanzaboote
            # can take over the UEFI stub generation.
            boot.loader.systemd-boot.enable = lib.mkForce false;

            boot.lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
              configurationLimit = 3;
            };

            # SBCTL is required for generating and enrolling the platform keys.
            environment.systemPackages = [ pkgs.sbctl ];

            assertions = [
              {
                assertion =
                  config.my.host.security.kernelLockdown == "none" || cfg.verifyKernelModules;
                message = "Lockdown with this Lanzaboote integration requires my.hardware.secure-boot.verifyKernelModules.";
              }
            ];
          }
          (lib.mkIf cfg.verifyKernelModules {
            boot.kernelParams = [ "module.sig_enforce=1" ];
            system.build.kernel = lib.mkForce verifiedKernel;
            system.build.verifiedKernel = verifiedKernel;

            # Keep both consumers on the certificate-bearing image. Updating only
            # the toplevel symlink would leave Lanzaboote signing the old bootspec path.
            system.systemBuilderCommands = lib.mkAfter ''
              ln -sfn -- ${lib.escapeShellArg verifiedKernelPath} "$out/kernel"
            '';
            boot.bootspec.writer = ''
              ${options.boot.bootspec.writer.default}
              ${lib.getExe pkgs.jq} --arg kernel ${lib.escapeShellArg verifiedKernelPath} \
                '."org.nixos.bootspec.v1".kernel = $kernel' \
                "$out/${config.boot.bootspec.filename}" > "$out/boot-verified.json"
              mv -- "$out/boot-verified.json" "$out/${config.boot.bootspec.filename}"
            '';

            assertions = [
              {
                assertion =
                  pkgs.stdenv.hostPlatform.isx86_64
                  && config.system.boot.loader.kernelFile == "bzImage";
                message = "This certificate-bearing kernel integration is currently reviewed for x86_64 bzImage only.";
              }
            ];
          })
        ]
      );
    };
}
