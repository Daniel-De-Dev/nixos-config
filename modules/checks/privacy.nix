{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/privacy.nix {
        inherit lib;
        modules = self.nixosModules;
      };
    in
    {
      checks.privacy-schema =
        assert lib.assertMsg (
          failures == [ ]
        ) "Privacy schema tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "privacy-schema-tests" { } ''
          touch "$out"
        '';
    };
}
