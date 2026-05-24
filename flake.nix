{
  description = "NixOS Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:denful/import-tree";

    wrapper-manager.url = "github:viperML/wrapper-manager";

    standards = {
      url = "github:Daniel-De-Dev/nixos-standards";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
    };

    privacy = {
      # TODO: Switch to the remote repo
      url = "path:///home/zeus/repos/nixos-privacy";
      flake = false;
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "git+file:///home/zeus/repos/dotfiles";
      flake = false;
    };

    nvim-config = {
      url = "github:Daniel-De-Dev/nvim-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.standards.flakeModules.default
        (inputs.import-tree ./modules)
      ];
    };
}
