{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.host.profiles.desktop;

  lyLoginCmd = pkgs.writeShellScript "ly-login-cmd" ''
    set -eu
    cmd="$*"
    case "$cmd" in
      *uwsm*)
        ${pkgs.systemd}/bin/systemctl --user stop \
          graphical-session.target \
          graphical-session-pre.target \
          xdg-desktop-autostart.target \
          2>/dev/null || true

        ${pkgs.systemd}/bin/systemctl --user stop 'wayland-wm@*.service' 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl --user reset-failed 2>/dev/null || true
        ;;
    esac
    exec "$@"
  '';
in
{
  options.my.host.profiles.desktop = {
    enable = lib.mkEnableOption ''
      Enable Desktop preset, configures ly as display manager,
      hyprland as desktop enviroment along side configuring other aplications.

      It sets up a single privledged user with configuration files set.
    '';
  };

  config = lib.mkIf cfg.enable {

    # Enable Display Manager
    services.displayManager = {
      enable = true;
      ly = {
        enable = true;
        settings = {
          # --- Authentication & Input ---
          allow_empty_password = false;
          clear_password = true;
          default_input = "password";

          # --- Appearance ---
          # 0xSSRRGGBB: SS=Style, RR=Red, GG=Green, BB=Blue
          bg = "0x001d1d1d";
          fg = "0x00c0c0c0";
          border_fg = "0x00595959";

          # --- UI Elements ---
          clock = "%H:%M";
          hide_key_hints = true;
          hide_version_string = true;
          xinitrc = null;

          # TODO: add my.host.hardware.battery or something for this
          # or a "battery powered" option or something
          # Identifier for battery whose charge to display at top left
          # Primary battery is usually BAT0 or BAT1
          # If set to null, battery status won't be shown
          battery_id = "BAT0";

          # --- Power & Commands ---
          sleep_cmd = "/run/current-system/sw/bin/systemctl sleep";

          # INFO: This isn't implemented in v1.2.0 (nixpkgs)
          # Either it works, or doesnt...
          # hibernate_cmd = "/run/current-system/sw/bin/systemctl hibernate";

          # TODO: Incorporate this with power management (sleep-then-hibernate)
          # Command executed when no input is detected for a certain time
          # If null, no command will be executed
          # INFO: This isn't implemented in v1.2.0
          # inactivity_cmd = null;
          # Executes a command after a certain amount of seconds
          # inactivity_delay = 0;

          # INFO: Fixes the "A compositor or graphical-session* target is already active!" error
          login_cmd = "${lyLoginCmd}";
        };
      };
    };

    # Enable Window Manager
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    # Enable Sound
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Fonts
    fonts.fontDir.enable = true;
    fonts.packages = with pkgs; [
      fira-sans
      font-awesome
      nerd-fonts.jetbrains-mono
    ];

    # Security / Polkit
    # TODO: Create secure core defaults for this (not enabling it)
    security.polkit.enable = true;

    # Globally ininstalled
    programs = {
      git.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
      };
    };

    networking.networkmanager.enable = true;

    services.xserver.xkb.layout = config.my.host.keyMap;

    console = {
      enable = true;
      earlySetup = true;
      useXkbConfig = true;
      font = "ter-v20n";
      packages = with pkgs; [ terminus_font ];
    };

    programs.direnv = {
      enable = true;
      silent = true;
    };

    # User Configuration
    my.host.users.main = {
      shell = "fish";
      features = {
        sudo.enable = true;
      };
      # TODO: Move the config to the new generic config implementation
      programs = {
        git.template = ../../../../templates/git/personal;

        neovim = {
          enable = true;
          profile = "personal";
          configPath = config.users.users.main.home + "/repos/nvim-config";
        };

        tmux = {
          enable = true;
          template = ../../../../templates/tmux/personal;
        };
      };
      config = {
        fish = {
          enable = true;
          src = "${inputs.dotfiles}/fish";
          symlink = false;
          deploy."fish-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/fish";
          };
        };
        hyprland = {
          enable = true;
          src = "${inputs.dotfiles}/hypr";
          deploy."hypr-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/hypr";
          };
        };
        kitty = {
          enable = true;
          src = "${inputs.dotfiles}/kitty";
          deploy."kitty-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/kitty";
          };
        };
        rofi = {
          enable = true;
          src = "${inputs.dotfiles}/rofi";
          deploy."rofi-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/rofi";
          };
        };
        swaync = {
          enable = true;
          src = "${inputs.dotfiles}/swaync";
          deploy."swaync-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/swaync";
          };
        };
        waybar = {
          enable = true;
          src = "${inputs.dotfiles}/waybar";
          deploy."waybar-config" = {
            source = "";
            target = "${config.users.users.main.home}/.config/waybar";
          };
        };
      };
    };
    users.users.main = {
      isNormalUser = true;
    };
  };
}
