{ self, inputs, ... }:
{

  flake.nixosModules.box-01Configuration =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {

      imports = [ self.nixosModules.box-01Hardware ];

      my.hardware.secure-boot.enable = true;
      my.programs.git.enable = true;
      my.programs.ssh.enable = true;

      # Bootloader specific to this machine's motherboard
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      my.host.security.strictKernel = true;

      system.stateVersion = "24.11";

      # INFO: TEMPORARY -----
      services.displayManager.ly.enable = true;

      # 2. Window Manager
      # This automatically enables OpenGL, XWayland, and the required display variables.
      programs.hyprland.enable = true;

      # 3. Essential Packages
      environment.systemPackages = with pkgs; [
        kitty # Hyprland's hardcoded default terminal (needed to open a shell)
        brave # Web browser
        neovim # Text editor for iterative config work
        obsidian
        steam
        ripgrep
      ];

      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "nvidia-x11"
          "obsidian"
          "nvidia-settings"
          "nvidia-kernel-modules"
          "steam-unwrapped"
          "steam"
        ];

      hardware.graphics.enable = true;

      # Tells Xorg and Wayland to use the NVIDIA drivers
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        # Modesetting is strictly required for Hyprland/Wayland
        modesetting.enable = true;

        # Power management is experimental; generally safer left disabled initially
        powerManagement.enable = false;

        # Use the proprietary NVML driver (set to true ONLY if you have a Turing or newer GPU and want the open kernel module)
        open = false;

        # Enables the nvidia-settings control panel
        nvidiaSettings = true;

        # Force the stable driver branch
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      # --------
    };
}
