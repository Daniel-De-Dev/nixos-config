{ ... }: {
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
      palette = cfg.palette;

      cursorTheme = "Posy_Cursor_Black";
      cursorSize = "24";

      inputConf = pkgs.replaceVars ./src/input.lua {
        kbLayout = config.services.xserver.xkb.layout;
      };

      autostartConf = pkgs.replaceVars ./src/autostart.lua {
        cursorTheme = cursorTheme;
        cursorSize = cursorSize;
      };

      themeLua = pkgs.replaceVars ./src/theme.lua {
        activeColor = "0xff${palette.active_border}";
        inactiveColor = "0xff${palette.inactive_border}";
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
        text = builtins.readFile ./src/scripts/screenrecording.sh;
      };

      scScript = pkgs.writeShellApplication {
        name = "screenshot";
        runtimeInputs = with pkgs; [
          gimp
          grimblast
          wl-clipboard
          libnotify
        ];
        text = builtins.readFile ./src/scripts/screenshot.sh;
      };

      bindsLua = pkgs.writeText "binds.lua" (
        builtins.replaceStrings
          [ "@scScriptPath@" "@recScriptPath@" ]
          [ "${scScript}/bin/screenshot" "${recScript}/bin/screenrecording" ]
          (builtins.readFile ./src/binds.lua)
      );

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

      # Write the generated Lua config to the store
      monitorsLua = pkgs.writeText "monitors.lua" ''
        ${builtins.concatStringsSep "\n" monitorStrings}
      '';

      hyprlandConf = pkgs.replaceVars ./src/hyprland.lua {
        inputConfPath = inputConf;
        autostartConfPath = autostartConf;
        themeConfPath = themeLua;
        layoutConfPath = ./src/layout.lua;
        miscConfPath = ./src/misc.lua;
        bindsConfPath = bindsLua;
        monitorsConfPath = monitorsLua;
      };

      # TODO: Implement the AGS config (figure out if to keep it here to seperate it)
      agsConfig = pkgs.runCommand "ags-config" { } ''
        mkdir -p $out
        # cp -r {./src/ags}/* $out/
      '';

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
                    env = {
                      XDG_CURRENT_DESKTOP.value = "Hyprland";
                      XDG_SESSION_TYPE.value = "wayland";
                      XDG_SESSION_DESKTOP.value = "Hyprland";
                      QT_QPA_PLATFORM.value = "wayland;xcb";
                      GDK_BACKEND.value = "wayland,x11,*";

                      # Cursor
                      XCURSOR_THEME.value = cursorTheme;
                      XCURSOR_SIZE.value = cursorSize;
                    };
                    prependFlags = [
                      "-c"
                      "${hyprlandConf}"
                    ];
                  };

                  programs.start-hyprland = {
                    env = {
                      XDG_CURRENT_DESKTOP.value = "Hyprland";
                      XDG_SESSION_TYPE.value = "wayland";
                      XDG_SESSION_DESKTOP.value = "Hyprland";
                      QT_QPA_PLATFORM.value = "wayland;xcb";
                      GDK_BACKEND.value = "wayland,x11,*";

                      # Cursor
                      XCURSOR_THEME.value = cursorTheme;
                      XCURSOR_SIZE.value = cursorSize;
                    };
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

      imports = [
        inputs.self.nixosModules.brave
        inputs.self.nixosModules.palette
      ];

      options.my.desktop.hyprland.enable =
        lib.mkEnableOption "Hyprland Desktop Environment";

      config = lib.mkIf cfg.enable {
        programs.hyprland = {
          enable = true;
          xwayland.enable = true;
          withUWSM = true;
          package = wrappedHyprland;
        };

        security.polkit.enable = true;

        my.allowedUnfree = [
          "posy-cursors"
          "davinci-resolve"
        ];
        environment.systemPackages = with pkgs; [
          posy-cursors
          awww # TODO: FIX that it starts
          hyprpolkitagent
          ghostty
          yazi
          bemoji
          wtype
          qalculate-qt

          (pkgs.makeDesktopItem {
            name = "yazi-ghostty";
            desktopName = "Yazi File Manager";

            exec = "ghostty --class=yazi-files -e yazi %U";

            icon = "system-file-manager";
            terminal = false;
            mimeTypes = [ "inode/directory" ];

            categories = [
              "System"
              "FileTools"
              "FileManager"
              "Utility"
              "Core"
            ];
          })

          brightnessctl
          grimblast
          slurp
          wl-clipboard
          wl-screenrec
          libnotify
          gimp
          davinci-resolve

          gpu-screen-recorder-gtk

          proton-vpn # TODO: Integrate this

          ags
          bun # TODO: Look into not having bun installed system wide
          dart-sass
        ];

        environment.sessionVariables = {
          WLR_NO_HARDWARE_CURSORS = "1";
          NIXOS_OZONE_WL = "1";
        };

        services.xserver.xkb.extraLayouts.real-prog-dvorak = {
          description = "English (Real Programmers Dvorak)";
          languages = [ "eng" ];
          symbolsFile = ./src/real-prog-dvorak;
        };

        services.hypridle.enable = true;

        systemd.user.services = {
          awww = {
            description = "awww wallpaper daemon";
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.awww}/bin/awww-daemon";
              ExecStartPost = "${pkgs.awww}/bin/awww img ${./src/wallpaper.jpg}";
              Restart = "on-failure";
            };
          };

          cliphist = {
            description = "Clipboard history manager";
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
              Restart = "always";
            };
          };

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

          ags = {
            description = "Aylur's Gtk Shell";
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.ags}/bin/ags -c ${agsConfig}/config.js";
              Restart = "on-failure";
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

        environment.sessionVariables = {
          GTK_THEME = "Adwaita:dark";
        };

        xdg.mime.defaultApplications = {
          # route all folder requests to our custom entry
          "inode/directory" = "yazi-ghostty.desktop";
          "application/x-directory" = "yazi-ghostty.desktop";

          # Route PDFs to Brave
          "application/pdf" = "brave-browser.desktop";

          # Route common image formats to Brave
          "image/jpeg" = "brave-browser.desktop";
          "image/png" = "brave-browser.desktop";
          "image/gif" = "brave-browser.desktop";
          "image/webp" = "brave-browser.desktop";
          "image/svg+xml" = "brave-browser.desktop";

          # Route MP4 Video to Brave
          "video/mp4" = "brave-browser.desktop";
        };

        # Set standard environment variables so CLI apps know your preference
        environment.variables = {
          TERMINAL = "ghostty";
          FILEMANAGER = "yazi";
        };

        # TODO: Look into moving it into a hardware/audio.nix or soemthing
        services.pulseaudio.enable = false;

        security.rtkit.enable = true;

        services.pipewire = {
          enable = true;

          alsa.enable = true;
          alsa.support32Bit = true;

          pulse.enable = true;

          wireplumber.enable = true;
        };

        # --- end of audio

        services.playerctld.enable = true;

        programs.hyprlock.enable = true;
        programs.gpu-screen-recorder.enable = true;
      };
    };
}
