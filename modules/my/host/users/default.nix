{
  lib,
  config,
  ...
}:
{
  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.str; # Enforce regex eventually
              default = name;
              description = ''
                The user's login name, defaults to the attribute name
              '';
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Defines the authoritative map of users for this host.

      This module automatically generates the corresponding `users.users`
      and `users.groups` entries from this definition.

      This data is generally intended to be populated by the `my.privacy` module.
    '';
  };

  config = {
    users.users = lib.mapAttrs (_: userConfig: {
      name = userConfig.name;
      group = userConfig.name;
    }) config.my.host.users;

    users.groups = lib.mapAttrs (_: userConfig: {
      name = userConfig.name;
    }) config.my.host.users;
  };
}
