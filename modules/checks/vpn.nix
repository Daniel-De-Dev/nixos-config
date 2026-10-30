{ inputs, self, ... }: {
  perSystem =
    { pkgs, ... }:
    let
      lib = inputs.nixpkgs.lib;
      failures = import ../../tests/vpn.nix {
        inherit lib;
        inherit (inputs.nixpkgs.lib) nixosSystem;
        modules = self.nixosModules;
      };
    in
    {
      checks.vpn =
        assert lib.assertMsg (
          failures == [ ]
        ) "VPN tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "vpn-tests"
          {
            nativeBuildInputs = [
              pkgs.diffutils
              pkgs.gnused
            ];
          }
          ''
            ${pkgs.bash}/bin/bash ${../../tests/vpn-mtu.sh} \
              ${../../modules/services/vpn/mtu.sh} ${pkgs.runtimeShell}
            touch "$out"
          '';
    };
}
