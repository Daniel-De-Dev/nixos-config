_: {
  flake.nixosModules.box-02Hardware =
    {
      config,
      lib,
      modulesPath,
      ...
    }:

    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "vmd"
        "nvme"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=@" ];
      };

      boot.initrd.luks.devices."cryptroot".device =
        "/dev/disk/by-uuid/993242b4-5b5d-43b7-b526-771570329a2e";

      fileSystems."/nix" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=@nix" ];
      };

      fileSystems."/home" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=@home" ];
      };

      fileSystems."/swap" = {
        device = "/dev/mapper/cryptroot";
        fsType = "btrfs";
        options = [ "subvol=@swap" ];
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/A481-934F";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.npu.enable = true;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
