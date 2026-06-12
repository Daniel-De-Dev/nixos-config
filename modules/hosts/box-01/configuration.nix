{ self, ... }:
{

  flake.nixosModules.box-01Configuration =
    { pkgs, lib, ... }:
    {

      imports = [ self.nixosModules.box-01Hardware ];

      my.hardware.secure-boot.enable = true;
      my.programs.git.enable = true;
      my.programs.ssh.enable = true;
      my.programs.fish.enable = true;
      my.programs.nvim.enable = true;

      # Bootloader specific to this machine's motherboard
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      my.host.security.strictKernel = true;

      my.desktops.ly.enable = true;
      my.desktop.hyprland.enable = true;

      my.hardware.hibernation = {
        enable = true;
        resumeDevice = "/dev/mapper/cryptroot";
        resumeOffset = 91848876;
      };

      swapDevices = [
        {
          device = "/swap/swapfile";
          size = 36 * 1024;
        }
      ];

      my.hardware.gpu.vendor = "nvidia";
      my.hardware.gpu.multiGpu = true;

      # Fixes ACPI instant-wake loop from suspend
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
      '';

      system.stateVersion = "24.11";

      # INFO: TEMPORARY -----
      # Essential Packages
      environment.systemPackages = with pkgs; [
        kitty # Hyprland's hardcoded default terminal (needed to open a shell)
        brave # Web browser
        obsidian
        ripgrep
      ];

      my.allowedUnfree = [
        "obsidian"
        "steam-unwrapped"
        "steam"
      ];

      environment.sessionVariables = {
        XDG_SESSION_TYPE = "wayland";
      };

      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
      };
      # --------
    };
}
