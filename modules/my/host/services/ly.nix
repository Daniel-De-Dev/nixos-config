{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.host.services.ly;

  lyLoginCmd = pkgs.writeShellApplication {
    name = "ly-login-cmd";
    runtimeInputs = [ pkgs.systemd ];
    text = builtins.readFile ./scripts/ly-login.sh;
  };
in
{
  options.my.host.services.ly = {
    enable = lib.mkEnableOption "Enable and configure Ly Display Manager";
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.ly = {
      enable = true;
      settings = {
        # --- Authentication & Input ---
        allow_empty_password = false;
        clear_password = true;
        default_input = "password";

        # --- Appearance ---
        # 0xSSRRGGBB: SS=Style, RR=Red, GG=Green, BB=Blue
        bg = "0x001d1d1d";
        error_bg = "0x001d1d1d";
        fg = "0x00c0c0c0";
        border_fg = "0x00595959";

        # --- UI Elements ---
        clock = "%H:%M";
        hide_key_hints = true;
        hide_version_string = true;
        xinitrc = null;

        # --- Battery ---
        # INFO: Automatically set based on the host hardware configuration
        battery_id = config.my.host.hardware.battery;

        # --- Power & Commands ---
        sleep_cmd = "/run/current-system/sw/bin/systemctl sleep";

        # INFO: not implemented in current version (v1.2.0)
        # hibernate_cmd = "/run/current-system/sw/bin/systemctl hibernate"
        # inactivity_cmd = null;
        # inactivity_cmd = null;

        # INFO: Fixes the "A compositor or graphical-session* target is already active!" error
        login_cmd = "${lib.getExe lyLoginCmd}";
      };
    };

    assertions = [
      {
        assertion = config.services.displayManager.ly.package.version == "1.2.0";
        message = ''
          Ly version is currently ${config.services.displayManager.ly.package.version}
          If its v1.3.0 or greater, review the config options available. Also define
          inactivity and hibernation options that should be available and defined now
        '';
      }
    ];
  };
}
