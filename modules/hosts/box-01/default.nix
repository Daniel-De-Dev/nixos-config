{ inputs, self, ... }:
{
  flake.nixosConfigurations.box-01 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit inputs;
      machine = "box-01";
    };

    modules = [
      self.nixosModules.box-01Configuration
      self.nixosModules.core
      self.nixosModules.core-network
      self.nixosModules.core-locale
      self.nixosModules.core-operator
      self.nixosModules.core-security
      self.nixosModules.core-console
      self.nixosModules.hardware-secure-boot
      self.nixosModules.programs-git
      self.nixosModules.programs-ssh
    ];
  };
}
