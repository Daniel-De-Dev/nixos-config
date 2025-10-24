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

    nvim-config = {
      url = "github:Daniel-De-Dev/nvim-config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      supportedSystems = [ "x86_64-linux" ];
      lib = inputs.nixpkgs.lib;
      myLib = import ./lib { inherit inputs; };
      treefmt = import ./nix/treefmt {
        inherit inputs;
        inherit supportedSystems;
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

      nixosConfigurations = myLib.mkHostConfigurations {
        modules = lib.attrValues self.nixosModules;
        inherit supportedSystems;
      };
    };
}
