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
      type = lib.types.str;
      default = hostName;
      description = "The hostname for the machine. Defaults to the host's directory name.";
    };
  };

  config = {
    # Specify the platform the NixOS configuration will run (Host Spesific)
    # Main reason for it being here is to have the type for `system` enforced
    nixpkgs.hostPlatform = config.my.host.system;
  };
}
