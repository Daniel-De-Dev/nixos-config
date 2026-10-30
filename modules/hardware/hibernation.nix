# Purpose: Configures system hibernation and resume capabilities.
# Scope: System power state and resume targets.
_: {
  flake.nixosModules.hardware-hibernation =
    { lib, config, ... }:
    let
      cfg = config.my.hardware.hibernation;
      overrideEnabled = cfg.enable && cfg.lockdownOverride.enable;
      overrideActive = cfg.lockdownOverride.active;
      overridePatch = ./patches/hibernate-lockdown-opt-in.patch;
      overrideFlag = "hibernate=allow_locked_down";
      lockdownRequested = lib.any (lib.hasPrefix "lockdown=") config.boot.kernelParams;
    in
    {
      options.my.hardware.hibernation = {
        enable = lib.mkEnableOption "System hibernation capability";

        lockdownOverride = {
          enable = lib.mkEnableOption ''
            a custom Linux 7.3 exception allowing unauthenticated hibernation
            images under lockdown, accepting the loss of that protection
          '';
          active = lib.mkOption {
            type = lib.types.bool;
            readOnly = true;
            description = "Whether this configuration includes the custom kernel patch and boot opt-in; not a runtime attestation.";
          };
        };

        resumeOffset = lib.mkOption {
          type = lib.types.int;
          description = "The physical block offset of the swapfile on the filesystem.";
        };

        resumeDevice = lib.mkOption {
          type = lib.types.str;
          example = "/dev/mapper/cryptroot";
          description = "The block device path where the swapfile resides.";
        };
      };

      config = lib.mkMerge [
        {
          my.hardware.hibernation.lockdownOverride.active =
            overrideEnabled
            && lib.any (item: item.patch == overridePatch) config.boot.kernelPatches
            && lib.elem overrideFlag config.boot.kernelParams;
        }
        (lib.mkIf cfg.enable {
          powerManagement.enable = true;

          boot.resumeDevice = cfg.resumeDevice;
          boot.kernelParams = [
            "resume_offset=${toString cfg.resumeOffset}"
          ]
          ++ lib.optional overrideEnabled overrideFlag;

          boot.kernelPatches = lib.optional overrideEnabled {
            name = "hibernate-lockdown-opt-in";
            patch = overridePatch;
          };

          # Hibernation requires writing the kernel from memory to disk
          security.protectKernelImage = false;

          # Power & Sleep Behavior
          services.logind.settings.Login = {
            HandleLidSwitch = "suspend-then-hibernate";
            IdleAction = "suspend-then-hibernate";
            IdleActionSec = "30m";
          };
          systemd.sleep.settings.Sleep = {
            HibernateDelaySec = "30m";
          };

          assertions = [
            {
              assertion = !overrideEnabled || overrideActive;
              message = "The requested hibernation lockdown exception requires both its kernel patch and boot parameter. Neither may be overridden away.";
            }
            {
              assertion = !lockdownRequested || overrideActive;
              message = ''
                Hibernation under lockdown requires an explicit custom-kernel exception:
                set my.hardware.hibernation.lockdownOverride.enable = true, or disable
                lockdown.
              '';
            }
            {
              assertion = !lib.elem "nohibernate" config.boot.kernelParams;
              message = "Hibernation conflicts with the nohibernate boot parameter, including security.protectKernelImage.";
            }
            {
              assertion =
                !overrideActive
                || lib.versions.majorMinor config.boot.kernelPackages.kernel.version == "7.3";
              message = "The hibernation lockdown exception is reviewed for Linux 7.3.x only; review the patch before changing kernel series.";
            }
            {
              assertion =
                !overrideActive
                || lib.elem cfg.resumeDevice (
                  map (name: "/dev/mapper/${name}") (
                    builtins.attrNames config.boot.initrd.luks.devices
                  )
                );
              message = "The hibernation lockdown exception requires resumeDevice to name a decrypted LUKS mapper declared in boot.initrd.luks.devices.";
            }
            {
              assertion = overrideActive || !lib.elem overrideFlag config.boot.kernelParams;
              message = "hibernate=allow_locked_down requires the managed hibernation.lockdownOverride; a boot parameter alone does not patch the kernel.";
            }
            {
              assertion = config.swapDevices != [ ];
              message = "Hibernation is enabled, but the `swapDevices` list is empty. You must define a swapfile larger than your physical RAM in the host configuration.";
            }
          ];
        })
      ];
    };
}
