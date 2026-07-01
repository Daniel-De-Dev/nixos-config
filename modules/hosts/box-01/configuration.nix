{ self, ... }: {

  flake.nixosModules.box-01Configuration =
    {
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      orca-slicer-pkg = pkgs.symlinkJoin {
        name = "orca-slicer-wrapped";
        paths = [ pkgs.orca-slicer ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/orca-slicer \
          --set GBM_BACKEND dri \
          --set LC_ALL C.UTF-8
        '';
      };
    in
    {

      imports = [
        self.nixosModules.box-01Hardware
        inputs.spicetify-nix.nixosModules.default # TODO: Integrate this more properly, move to hyprland maybe?
      ];

      my.hardware.secure-boot.enable = true;
      my.programs.git.enable = true;
      my.programs.ssh.enable = true;
      my.programs.fish.enable = true;
      my.programs.nvim.enable = true;

      my.services.google-drive.enable = true;
      my.services.google-drive.remoteName = "secret-drive";

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

      my.hardware.monitors = [
        {
          name = "DP-4";
          width = 2560;
          height = 1440;
          refreshRate = 170.07;
          x = 0;
          y = 0;
          scale = "1";
        }
        {
          name = "HDMI-A-2";
          width = 1920;
          height = 1080;
          refreshRate = 75;
          x = 2560;
          y = 360;
          scale = "1";
        }
      ];

      # Fixes ACPI instant-wake loop from suspend
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
      '';

      system.stateVersion = "24.11";

      # INFO: TEMPORARY -----
      environment.systemPackages = with pkgs; [
        obsidian
        orca-slicer-pkg
        networkmanagerapplet
        pandoc
        pulseaudio
        inkscape
        blender
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

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      # --------

      # NOTE: Orca-slicer/3d printer realted change
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = lib.mkForce 1;
      };

      networking.firewall = {
        enable = true;

        # NetworkManager "shared" uses dnsmasq for DHCP (+DNS)
        interfaces.eno1.allowedUDPPorts = [
          67
          53
        ];
        interfaces.eno1.allowedTCPPorts = [ 53 ];

        checkReversePath = lib.mkForce "loose";
      };
      # NOTE: end 3d
    };
}
