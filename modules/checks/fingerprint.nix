{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/fingerprint.nix {
        inherit lib;
        inherit (inputs.nixpkgs.lib) nixosSystem;
        modules = self.nixosModules;
        configurations = self.nixosConfigurations;
      };
    in
    {
      checks.fingerprint =
        assert lib.assertMsg (
          failures == [ ]
        ) "Fingerprint tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "fingerprint-tests" { } ''
          touch "$out"
        '';
    };
}
