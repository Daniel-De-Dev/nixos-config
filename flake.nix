{
  description = "NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Private repository for personal configuration data
    # WARNING: For first ever build, comment out this import
    privacy = {
      url = "git+ssh://nixos-privacy/Daniel-De-Dev/nixos-privacy.git";
      flake = false;
    };

    # Formater
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      lib = inputs.nixpkgs.lib;
      myLib = import ./lib { inherit inputs; };
      treefmt = import ./nix/treefmt {
        inherit inputs;
        inherit myLib;
      };
    in
    treefmt
    // {
      nixosModules = {
        core = import ./modules/core;
        my = import ./modules/my;
      };

      lib = {
        inherit (myLib) mkHostConfigurations;
      };

      nixosConfigurations = myLib.mkHostConfigurations { modules = lib.attrValues self.nixosModules; };
    };
}
