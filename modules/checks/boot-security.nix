{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/boot-security.nix {
        inherit lib;
        configurations = self.nixosConfigurations;
      };
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
        hibernation-kernel = import ../../tests/hibernation-kernel.nix {
          kernel = self.nixosConfigurations.box-01.config.boot.kernelPackages.kernel;
        };
      };
    };
}
