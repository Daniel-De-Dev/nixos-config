{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/monitors.nix {
        inherit lib;
        modules = self.nixosModules;
      };
    in
    {
      checks.monitors =
        assert lib.assertMsg (
          failures == [ ]
        ) "Monitor tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "monitor-tests" { } ''
          touch "$out"
        '';
    };
}
