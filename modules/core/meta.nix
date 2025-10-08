{ lib, hostName, ... }:
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
}
