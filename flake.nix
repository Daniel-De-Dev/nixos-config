{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Private repository for personal configuration data that are not wanted to
    # be public.
    privacy = {
      url = "git+ssh://git@github.com/Daniel-De-Dev/nixos-privacy.git";
      flake = false;
    };
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
