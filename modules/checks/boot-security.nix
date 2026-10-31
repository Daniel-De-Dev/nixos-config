{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/boot-security.nix {
        inherit lib;
        configurations = self.nixosConfigurations;
      };
      exceptionKernels = lib.unique (
        map (host: host.config.boot.kernelPackages.kernel) (
          lib.filter (host: host.config.my.hardware.hibernation.lockdownOverride.active) (
            lib.attrValues self.nixosConfigurations
          )
        )
      );
    in
    {
      checks = {
        boot-security =
          assert lib.assertMsg (
            failures == [ ]
          ) "Boot security tests failed: ${builtins.toJSON failures}";
          pkgs.runCommand "boot-security-tests" { } ''
            touch "$out"
          '';
      }
      // lib.optionalAttrs (exceptionKernels != [ ]) {
        hibernation-kernel = pkgs.linkFarm "hibernation-kernel-tests" (
          lib.imap0 (index: kernel: {
            name = toString index;
            path = import ../../tests/hibernation-kernel.nix { inherit kernel; };
          }) exceptionKernels
        );
      };
    };
}
