{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.my.host.profiles.desktop;
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
    services.displayManager.enable = true;

    my.host.services.ly.enable = true;
    my.host.services.hyprland.enable = true;

    boot.loader.systemd-boot.consoleMode = "max";

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

    # NOTE: For desktops having this enabled is frustrating
    security.lockKernelModules = false;

    # Globally installed programs
    programs = {
      git.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
      };
    };

    networking.networkmanager.enable = true;

    # Console Configuration
    console = {
      enable = true;
      earlySetup = true;
      useXkbConfig = true;
      font = "ter-v20n";
      packages = with pkgs; [ terminus_font ];
      colors = [
        "1D1D1D" # color0 (background)
        "AA0000"
        "00AA00"
        "AA5500"
        "0000AA"
        "AA00AA"
        "00AAAA"
        "C0C0C0" # color7 (foreground)
        "555555"
        "FF5555"
        "55FF55"
        "FFFF55"
        "5555FF"
        "FF55FF"
        "55FFFF"
        "FFFFFF"
      ];
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
