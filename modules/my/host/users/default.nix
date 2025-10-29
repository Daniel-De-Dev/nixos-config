{
  lib,
  config,
  ...
}:
{
  imports = [
    ./programs
  ];

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

            programs.git = {
              enable = lib.mkEnableOption ''
                Enable the setting up and managing of git configuration for
                this user.
              '';

              template = lib.mkOption {
                type = lib.types.path;
                description = ''
                  Path to the .nix file that defines the git template.
                  (its dependecies & raw config file)
                '';
              };

              settings = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    userName = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Value for @userName@ placeholder.";
                    };
                    userEmail = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Value for @userEmail@ placeholder.";
                    };
                  };
                };
                default = { };
                description = "Private settings to substitute into the template.";
              };
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
      It's really up to you what you consider "private"
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
