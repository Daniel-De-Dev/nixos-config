{
  lib,
  hostName,
  config,
  ...
}:
{
  options.my.host = {
    name = lib.mkOption {
      # Enforce RFC 1123 rules for hostnames (1-63 chars, no leading/trailing hyphen).
      type = lib.types.strMatching "[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?";
      default = hostName;
      description = "The hostname for the machine. Defaults to the host's directory name.";
    };

    keyMap = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "The keymap set system wide";
    };

    timeZone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "What time zone will be set system wide";
    };

    hardware.battery = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "BAT0";
      description = "The battery identifier (BAT0). Used by modules to configure accordingly";
    };
  };

  config = {
    networking.hostName = config.my.host.name;
    services.xserver.xkb.layout = config.my.host.keyMap;
    console.keyMap = lib.mkDefault config.my.host.keyMap;
    time.timeZone = config.my.host.timeZone;
  };
}
