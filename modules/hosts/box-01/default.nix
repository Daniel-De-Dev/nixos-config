{ inputs, self, ... }: {
  flake.nixosConfigurations.box-01 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit inputs;
      machine = "box-01";
    };

    modules = [
      self.nixosModules.box-01Configuration
      self.nixosModules.core
      self.nixosModules.core-unfree
      self.nixosModules.core-network
      self.nixosModules.core-locale
      self.nixosModules.core-operator
      self.nixosModules.core-security
      self.nixosModules.core-console
      self.nixosModules.core-fonts
      self.nixosModules.hardware-secure-boot
      self.nixosModules.hardware-hibernation
      self.nixosModules.hardware-power
      self.nixosModules.hardware-gpu
      self.nixosModules.hyprland
      self.nixosModules.desktop-display-manager
      self.nixosModules.programs-git
      self.nixosModules.programs-ssh
      self.nixosModules.programs-fish
      self.nixosModules.programs-nvim
    ];
  };
}
