{
  lib,
  config,
  ...
}:
let
  allUsers = config.my.host.users;
  nmUsers = lib.filterAttrs (
    _: userConfig: userConfig.features.networkmanager.enable or false
  ) allUsers;
in
{
  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.features.networkmanager = {
          enable = lib.mkEnableOption ''
            Add user to the 'networkmanager' group.
            Required for controlling networking via GUI or CLI without sudo.
          '';
        };
      }
    );
  };

  config = {
    users.users = lib.mapAttrs (userName: userConfig: {
      extraGroups = [ "networkmanager" ];
    }) nmUsers;
  };
}
