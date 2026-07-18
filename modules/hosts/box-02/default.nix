{ inputs, self, ... }: {
  flake.nixosConfigurations.box-02 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit inputs;
      machine = "box-02";
    };

    # TODO: Standardize paths/names
    modules = [
      self.nixosModules.box-02Configuration
      self.nixosModules.core
      self.nixosModules.core-privacy
      self.nixosModules.core-unfree
      self.nixosModules.core-network
      self.nixosModules.core-locale
      self.nixosModules.core-operator
      self.nixosModules.core-security
      self.nixosModules.core-console
      self.nixosModules.core-fonts
      self.nixosModules.core-palette
      self.nixosModules.hardware-audio
      self.nixosModules.hardware-secure-boot
      self.nixosModules.hardware-hibernation
      self.nixosModules.hardware-power
      self.nixosModules.hardware-gpu
      self.nixosModules.hardware-monitors
      self.nixosModules.services-google-drive
      self.nixosModules.hyprland
      self.nixosModules.desktop-display-manager
      self.nixosModules.programs-cli-essentials
      self.nixosModules.programs-git
      self.nixosModules.programs-ssh
      self.nixosModules.programs-fish
      self.nixosModules.programs-nvim
      self.nixosModules.programs-brave
    ];
  };
}
