{ inputs, ... }:
{
  flake.nixosConfigurations.box-01 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = { inherit inputs; };

    modules = [
      ./configuration.nix
      ./hardware-configuration.nix
    ];
  };
}
