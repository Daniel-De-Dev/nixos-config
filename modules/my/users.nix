{ lib, ... }:
{
  options.my.users.predefined.admin = lib.mkOption {
    type = lib.types.attrs;

    default = {
      isNormalUser = true;
      description = "Administrator user";
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
    description = "Predefined settings for an admin user.";
  };
}
