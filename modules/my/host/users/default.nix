{
  lib,
  config,
  ...
}:
{
  imports = [
    ./features
    ./programs
  ];

  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.strMatching "^[a-z_][a-z0-9_-]*$";
              default = name;
              description = ''
                The user's login name, defaults to the attribute name
              '';
            };

            features = {
              sudo = {
                enable = lib.mkEnableOption ''
                  Enable sudo access for this user.
                  This will add the user to the 'wheel' group
                '';
              };

              ssh = {
                enable = lib.mkEnableOption "automatic SSH key generation on first login";

                email = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Email address to use as a comment for the SSH key. Required if enabled.
                  '';
                };
              };

              gpg = {
                enable = lib.mkEnableOption "automatic GPG key generation on first login";

                realName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Full name for the GPG key. Required if enabled.";
                };

                email = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Email address for the GPG key. Required if enabled.";
                };
              };
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
                    userSigningKey = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "The GPG key ID or fingerprint for commit signing. Value for @userSigningKey@ placeholder.";
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
