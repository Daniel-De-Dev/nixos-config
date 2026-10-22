{ inputs, self, ... }: {
  perSystem =
    { config, pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/theme.nix {
        inherit lib pkgs;
        modules = self.nixosModules;
        package = config.packages.ags-shell;
      };
    in
    {
      checks.theme =
        assert lib.assertMsg (
          failures == [ ]
        ) "Theme tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "theme-tests" { } ''
          touch "$out"
        '';
    };
}
