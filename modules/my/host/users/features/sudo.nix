{
  lib,
  config,
  ...
}:
let
  allUsers = config.my.host.users;
  sudoUsers = lib.filterAttrs (_: userConfig: userConfig.features.sudo.enable or false) allUsers;
in
{
  config = {
    users.users = lib.mapAttrs (userName: userConfig: {
      extraGroups = [ "wheel" ];
    }) sudoUsers;

    assertions = lib.flatten (
      lib.mapAttrsToList (userName: userConfig: [
        {
          assertion = config.security.sudo.enable == true || config.security.sudo-rs.enable == true;
          message = ''
            User '${userName}' has 'features.sudo' enabled, but
            'security.sudo.enable' is not true.
          '';
        }
      ]) sudoUsers
    );
  };
}
