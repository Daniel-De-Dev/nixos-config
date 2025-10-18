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
