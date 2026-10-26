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

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # TODO: add gh actions based of flake-base template
    # TODO: look into switching to structure similar to rust. {module}.nix ./{module}/ rather than {module}/default.nix
    # TODO: Review the general project structure and if things might need reorganizing
    # TODO: refine the documentation for the project (per file and docs/)
    # TODO: Update flake inputs and get the build working (deal with fixing module signing)

    privacy = {
      url = "git+ssh://git@github.com/Daniel-De-Dev/nixos-privacy.git?ref=main";
      flake = false;
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
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

  # TODO: decide if moving the configs as extenal repos makes sense and just
  # referenced as a dir

  # TODO: decide if needed to add documentation for the program configs to also
  # establish spec and where the docs should live
}
