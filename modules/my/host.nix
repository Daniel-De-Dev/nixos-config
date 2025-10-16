{
  lib,
  hostName,
  config,
  ...
}:
{
  options.my.host = {
    hostName = lib.mkOption {
      # Enforce RFC 1123 rules for hostnames (1-63 chars, no leading/trailing hyphen).
      type = lib.types.strMatching "[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?";
      default = hostName;
      description = "The hostname for the machine. Defaults to the host's directory name.";
    };
  };

  config = {
    networking.hostName = config.my.host.hostName;
  };
}
