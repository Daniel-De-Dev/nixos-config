{
  lib,
  hostName,
  config,
  ...
}:
{
  imports = [
    ./users
    ./secure-boot.nix
    ./hardware/storage.nix
    ./profiles
  ];

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

    hibernation = {
      enable = lib.mkEnableOption "system hibernation support (disables conflicting security hardening)";
    };
  };

  config = {
    networking.hostName = config.my.host.name;
  };

}
