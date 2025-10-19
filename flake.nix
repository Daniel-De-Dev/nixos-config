{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Private repository for personal configuration data that are not wanted to
    # be public.
    # WARNING: For first ever build, comment out this import
    privacy = {
      url = "git+ssh://nixos-privacy/Daniel-De-Dev/nixos-privacy.git";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      lib = inputs.nixpkgs.lib;
      myLib = import ./lib { inherit inputs; };
    in
    {
      nixosModules = {
        my = import ./modules/my;
      };

      lib = {
        inherit (myLib) mkHostConfigurations;
      };

      nixosConfigurations = myLib.mkHostConfigurations { modules = lib.attrValues self.nixosModules; };
    };
}
