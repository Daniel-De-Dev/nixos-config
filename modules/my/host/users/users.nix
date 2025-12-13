{
  lib,
  config,
  ...
}:
{
  imports = [
    ./features
    ./programs
    ./configs.nix
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

            shell = lib.mkOption {
              type = lib.types.enum [
                "bash"
                "fish"
              ];
              default = "bash";
              description = "The shell to use for this user.";
            };

            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of public SSH keys allowed to login as this user.";
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
      openssh.authorizedKeys.keys = userConfig.authorizedKeys;
    }) config.my.host.users;

    users.groups = lib.mapAttrs (_: userConfig: {
      name = userConfig.name;
    }) config.my.host.users;

    services.openssh.settings.AllowUsers = lib.mapAttrsToList (_: u: u.name) config.my.host.users;

    assertions = lib.flatten (
      lib.mapAttrsToList (
        name: userCfg:
        let
          sshEnabled = config.services.openssh.enable;
          passAuthDisabled = (config.services.openssh.settings.PasswordAuthentication or true) == false;
          hasKeys = userCfg.authorizedKeys != [ ];
        in
        [
          {
            assertion = (sshEnabled && passAuthDisabled) -> hasKeys;
            message = ''
              User '${name}' is configured in 'my.host.users' (and whitelisted in AllowUsers),
              but has no 'authorizedKeys' defined.

              Since 'services.openssh.settings.PasswordAuthentication' is disabled, this user
              will be permanently locked out of SSH access.

              Fix: Add an SSH public key to 'my.host.users.${name}.authorizedKeys' or enable password auth.
            '';
          }
        ]
      ) config.my.host.users
    );
  };
}
