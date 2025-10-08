{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, ... }:
    let
      lib = import ./lib { inherit inputs; };
    in
    {
      nixosModules = {
        core = import ./modules/core;
      };

      lib = {
        inherit (lib) mkHostConfigurations;
      };

      nixosConfigurations = lib.mkHostConfigurations { modules = [ self.nixosModules.core ]; };
    };
}
