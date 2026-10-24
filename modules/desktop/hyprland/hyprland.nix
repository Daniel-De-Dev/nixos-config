# Purpose: Configures the Hyprland desktop environment and core Wayland compositor utilities.
# Scope: GUI environment initialization and visual appearance.
{ self, inputs, ... }: {
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      defaults = import ../../../packages/hyprland/desktop.nix {
        inherit lib pkgs;
        inherit (inputs) wrapper-manager;
      };
      desktopPkgs = import inputs.nixpkgs {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfreePredicate =
          pkg: builtins.elem (lib.getName pkg) defaults.unfree;
      };
    in
    {
      packages.hyprland = desktopPkgs.callPackage ../../../packages/hyprland {
        inherit (inputs) wrapper-manager;
        agsShell = config.packages.ags-shell;
      };
      apps.hyprland = {
        type = "app";
        meta.description = "Test the desktop configuration inside a Wayland window on NixOS";
        program = "${config.packages.hyprland}/bin/hyprland-preview";
      };
      checks.hyprland = config.packages.hyprland;
      checks.hyprland-config = pkgs.runCommand "hyprland-preview-config-check" { } ''
        export XDG_RUNTIME_DIR="$TMPDIR"
        for modifier in SUPER ALT; do
          export NIXOS_HYPRLAND_MOD="$modifier"
          ${pkgs.hyprland}/bin/Hyprland --i-am-really-stupid --verify-config \
            -c ${config.packages.hyprland.config}
          ${pkgs.luajit}/bin/luajit ${../../../tests/hyprland-preview.lua} \
            ${config.packages.hyprland.config} "$modifier"
        done
        touch "$out"
      '';
    };

  flake.nixosModules.hyprland =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.my.desktop.hyprland;
      colors = config.my.theme.colors;
      desktop = import ../../../packages/hyprland/desktop.nix {
        inherit lib pkgs;
        inherit (inputs) wrapper-manager;
      };

      recordingCodec =
        if config.my.hardware.gpu.vendor == "nvidia" then "h264_nvenc" else "libx264";

      cursorTheme = desktop.cursor.name;
      cursorSize = toString desktop.cursor.size;

      autostartConf = pkgs.replaceVars ./src/autostart.lua {
        inherit cursorTheme;
        inherit cursorSize;
      };

      recScript = pkgs.writeShellApplication {
        name = "screenrecording";
        runtimeInputs = with pkgs; [
          wf-recorder
          ffmpeg
          slurp
          wl-clipboard
          libnotify
          pulseaudio
          hyprland
          coreutils
          jq
          procps
          davinci-resolve
        ];
        text = builtins.replaceStrings [ "@recordingCodec@" ] [ recordingCodec ] (
          builtins.readFile ./src/scripts/screenrecording.sh
        );
      };

      # TODO: Fix or add a way to specify where workspace 1 and 2 intilize to
      # Generate the Lua monitor configurations
      monitorStrings =
        if (builtins.length config.my.hardware.monitors > 0) then
          map (
            m:
            "hl.monitor({ output = \"${m.name}\", mode = \"${toString m.width}x${toString m.height}@${toString m.refreshRate}\", position = \"${toString m.x}x${toString m.y}\", scale = ${m.scale} })"
          ) config.my.hardware.monitors
        else
          [
            "hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = 1 })"
          ];

      hyprlandConf = import ../../../packages/hyprland/config.nix {
        inherit
          lib
          pkgs
          desktop
          colors
          autostartConf
          ;
        kbLayout = config.services.xserver.xkb.layout;
        recScriptPath = "${recScript}/bin/screenrecording";
        monitorRules = monitorStrings;
        inherit (cfg) extraBindings extraLayerRules;
      };

      # TODO: Fix hyprlock

      # TODO: Add keyboard layout short cut and add keybind shortcut for hyprland

      sessionEnv = lib.mapAttrs (_: value: { inherit value; }) (
        desktop.environment
        // {
          XDG_CURRENT_DESKTOP = "Hyprland";
          XDG_SESSION_TYPE = "wayland";
          XDG_SESSION_DESKTOP = "Hyprland";
          QT_QPA_PLATFORM = "wayland;xcb";
          GDK_BACKEND = "wayland,x11,*";
        }
      );

      # NixOS needs to apply custom overrides
      wrapperFn =
        args:
        let
          base = pkgs.hyprland.override args;

          wm-eval = inputs.wrapper-manager.lib {
            inherit pkgs;
            modules = [
              {
                wrappers.hyprland = {
                  basePackage = base;

                  programs.Hyprland = {
                    env = sessionEnv;
                    prependFlags = [
                      "-c"
                      "${hyprlandConf}"
                    ];
                  };

                  programs.start-hyprland = {
                    env = sessionEnv;
                    prependFlags = [
                      "-c"
                      "${hyprlandConf}"
                    ];
                  };

                  programs.hyprctl = { };
                  programs.hyprpm = { };
                };
              }
            ];
          };
        in
        wm-eval.config.wrappers.hyprland.wrapped;

      wrapperFnWithArgs = lib.setFunctionArgs wrapperFn (
        lib.functionArgs pkgs.hyprland.override
      );

      wrappedHyprland = lib.makeOverridable wrapperFnWithArgs { };
    in
    {
      imports = [ self.nixosModules.core-palette ];

      options.my.desktop.hyprland = {
        enable = lib.mkEnableOption "Hyprland Desktop Environment";
        extraBindings = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Lua bindings appended to the compositor's keybinding configuration.";
        };
        extraLayerRules = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Lua layer rules added by desktop integrations.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          withUWSM = true;
          package = wrappedHyprland;
        };

        security.polkit.enable = true;

        my.allowedUnfree = desktop.unfree ++ [ "davinci-resolve" ];
        environment.systemPackages =
          desktop.packages
          ++ (with pkgs; [
            hyprpolkitagent
            brightnessctl
            grimblast
            slurp
            wl-clipboard
            wl-screenrec
            libnotify
            gimp
            davinci-resolve

            gpu-screen-recorder-gtk

            proton-vpn # TODO: Integrate this to start up automatically
          ]);

        environment.sessionVariables = desktop.environment // {
          WLR_NO_HARDWARE_CURSORS = "1";
        };

        services.xserver.xkb.extraLayouts.real-prog-dvorak = {
          description = "English (Real Programmers Dvorak)";
          languages = [ "eng" ];
          symbolsFile = ./src/real-prog-dvorak;
        };

        services.hypridle.enable = true;

        systemd.user.services =
          lib.mapAttrs (name: service: {
            description = "Hyprland ${name}";
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = service.command;
              Restart = "on-failure";
            }
            // lib.optionalAttrs (service ? afterStart) {
              ExecStartPost = service.afterStart;
            };
          }) desktop.services
          // {
            hyprpolkitagent = {
              description = "Hyprland Polkit Authentication Agent";
              wantedBy = [ "graphical-session.target" ];
              wants = [ "graphical-session.target" ];
              after = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "simple";
                ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
                Restart = "on-failure";
                RestartSec = 1;
                TimeoutStopSec = 10;
              };
            };
          };

        # Enable dconf to manage system-level preferences
        programs.dconf.enable = true;

        programs.dconf.profiles.user.databases = [
          {
            settings = {
              "org/gnome/desktop/interface" = {
                color-scheme = "prefer-dark";
              };
            };
          }
        ];

        xdg.mime.defaultApplications = {
          # route all folder requests to yazi
          "inode/directory" = desktop.fileManagerDesktopId;
          "application/x-directory" = desktop.fileManagerDesktopId;

          # Route PDFs to Brave
          "application/pdf" = desktop.browserDesktop;

          # Route common image formats to Brave
          "image/jpeg" = desktop.browserDesktop;
          "image/png" = desktop.browserDesktop;
          "image/gif" = desktop.browserDesktop;
          "image/webp" = desktop.browserDesktop;
          "image/svg+xml" = desktop.browserDesktop;

          # Route MP4 Video to Brave
          "video/mp4" = desktop.browserDesktop;
        };

        programs.hyprlock.enable = true;
        programs.gpu-screen-recorder.enable = true;
      };
    };
}
