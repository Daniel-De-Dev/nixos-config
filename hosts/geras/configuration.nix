{
  config,
  pkgs,
  inputs,
  ...
}:
let
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
  imports = [
    ./hardware-configuration.nix
  ];

  # Enable and configure the privacy module for titan
  my.privacy = {
    enable = true;

    sshAliasConfig = {
      enable = true;
      sshKey = "/etc/nixos/secrets/nixos-privacy-key";
    };
  };

  my.host.hibernation.enable = true;
  my.host.hardware = {
    disks = {
      "/dev/disk/by-uuid/aae4e3b1-b95d-4be0-b050-5ffcbf16784a" = {
        type = "ssd";
      };
    };

    luks = {
      "cryptroot" = {
        device = "/dev/disk/by-uuid/aae4e3b1-b95d-4be0-b050-5ffcbf16784a";
      };
    };

    mounts = {
      "/" = {
        type = "btrfs";
        device = "cryptroot";
      };
      "/home" = {
        type = "btrfs";
        device = "cryptroot";
      };
      "/nix" = {
        type = "btrfs";
        device = "cryptroot";
      };
      "/swap" = {
        type = "btrfs";
        device = "cryptroot";
        compress = false;
      };
    };
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 15259; # ~16 GB
    }
  ];

  boot.kernelParams = [ "resume_offset=2664699" ];
  boot.resumeDevice = "/dev/mapper/cryptroot";
  powerManagement.enable = true;

  my.host.secureBoot = true;

  my.host.users.main = {
    shell = "fish";

    features = {
      sudo.enable = true;
      ssh.enable = true;
      gpg.enable = true;
    };

    # TODO: Move the config to the new generic config implementation
    programs = {
      git.template = ../../templates/git/personal;

      neovim = {
        enable = true;
        profile = "personal";
        configPath = config.users.users.main.home + "/repos/nvim-config";
      };

      tmux = {
        enable = true;
        template = ../../templates/tmux/personal;
      };
    };
  };

  users.users.main = {
    isNormalUser = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # allow for having internet upon first startup
  networking.networkmanager.enable = true;

  # git needed intially
  programs.git.enable = true;

  # initial editor setup
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

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

  # GUI related configurations
  # NOTE: Will be moved to a profile once complete
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

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    fira-sans
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  # TODO: Define system-wide (core) settings for it
  # (without actually enabling it, so once enable they take effect)
  security.polkit.enable = true;

  my.host.users.main.config = {
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

  # INFO: Belongs with GUI since servers wont need these
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # end if GUI changes

  system.stateVersion = "25.05";
}
