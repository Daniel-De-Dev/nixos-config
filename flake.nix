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
        my = import ./modules/my;
      };

      lib = {
        inherit (lib) mkHostConfigurations;
      };

      nixosConfigurations = lib.mkHostConfigurations { modules = [ self.nixosModules.my ]; };
    };
}
