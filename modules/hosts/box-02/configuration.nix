{ self, ... }: {

  flake.nixosModules.box-02Configuration = { pkgs, inputs, ... }: {

    imports = [
      self.nixosModules.box-02Hardware
      inputs.spicetify-nix.nixosModules.default # TODO: Integrate this more properly, move to hyprland maybe?
    ];

    my.core.fonts.enable = true;

    my.hardware.audio.enable = true;
    my.hardware.secure-boot.enable = true;
    my.programs.git.enable = true;
    my.programs.ssh.enable = true;
    my.programs.fish.enable = true;
    my.programs.nvim.enable = true;

    my.programs.cli-essentials.enable = true;

    my.services.google-drive.enable = true;
    my.services.google-drive.remoteName = "secret-drive";

    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };

    # Bootloader specific to this machine's motherboard
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    my.host.security.strictKernel = true;

    my.desktop.ly.enable = true;
    my.desktop.hyprland.enable = true;

    # my.hardware.hibernation = {
    #   enable = true;
    #   resumeDevice = "/dev/mapper/cryptroot";
    #   resumeOffset = 91848876;
    # };

    swapDevices = [
      {
        device = "/swap/swapfile";
        size = 36 * 1024;
      }
    ];

    my.hardware.gpu.vendor = "none";

    # my.hardware.monitors = [
    #   {
    #     name = "DP-4";
    #     width = 2560;
    #     height = 1440;
    #     refreshRate = 170.07;
    #     x = 0;
    #     y = 0;
    #     scale = "1";
    #   }
    #   {
    #     name = "HDMI-A-2";
    #     width = 1920;
    #     height = 1080;
    #     refreshRate = 75;
    #     x = 2560;
    #     y = 360;
    #     scale = "1";
    #   }
    # ];

    services.udev.extraRules = ''
      # ======== INFO: MANGOPI FEL PERMSISSION FIX ========

      # Allwinner FEL USB device
      SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", GROUP="fel", MODE="0660"

      # Prevent USB autosuspend during FEL transfers
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", ATTR{idProduct}=="efe8", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"

      # ========= END OF MANGOPI FEL =========
    '';

    system.stateVersion = "24.11";

    # INFO: TEMPORARY -----
    environment.systemPackages = with pkgs; [
      obsidian
      networkmanagerapplet
    ];

    my.allowedUnfree = [
      "obsidian"
      "steam-unwrapped"
      "steam"
      "spotify"
    ];

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.spicetify =
      let
        spicePkgs =
          inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        enable = true;

        enabledExtensions = with spicePkgs.extensions; [
          adblock
          hidePodcasts
          shuffle
        ];
        enabledCustomApps = with spicePkgs.apps; [
          newReleases
          ncsVisualizer
        ];
        enabledSnippets = with spicePkgs.snippets; [
          rotatingCoverart
          pointer
        ];

        theme = spicePkgs.themes.catppuccin;
        colorScheme = "mocha";
      };
    # --------
  };
}
