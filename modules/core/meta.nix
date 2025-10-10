{
  lib,
  hostName,
  config,
  ...
}:
{
  options.my.host = {
    system = lib.mkOption {
      type = lib.types.enum [
        "x86_64-linux"
      ];
      description = "The system architecture for this host";
    };

    hostName = lib.mkOption {
      # Enforce RFC 1123 rules for hostnames (1-63 chars, no leading/trailing hyphen).
      type = lib.types.strMatching "[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?";
      default = hostName;
      description = "The hostname for the machine. Defaults to the host's directory name.";
    };
  };

  config = {
    # Specify the platform the NixOS configuration will run (Host Spesific)
    # Main reason for it being here is to have the type for `system` enforced
    nixpkgs.hostPlatform = config.my.host.system;

    networking.hostName = config.my.host.hostName;
  };
}
