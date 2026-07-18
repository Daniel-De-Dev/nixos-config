# Purpose: Establish primary administrative identity and baseline access control.
# Scope: Authentication, permissions, operator identity.
# Invariants:
# - No user-space software, dotfiles, or shell configuration.
# - Imperative user management disabled.
_: {
  flake.nixosModules.core-operator =
    { lib, config, ... }:
    let
      cfg = config.my.operator;
    in
    {
      config = {
        users.mutableUsers = false;
        users.users.root.hashedPassword = "!";

        users.groups.${cfg.username} = { };

        users.users.${cfg.username} = {
          isNormalUser = true;
          description = "Primary System Operator";
          inherit (cfg) hashedPassword;
          group = cfg.username;

          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
            "audio"
            "render"
            "input"
            "systemd-journal"
            "dialout"
          ];

          openssh.authorizedKeys.keys = config.my.host.ssh.authorizedKeys;
        };

        # Security: Restrict SSH to the operator
        services.openssh.settings.AllowUsers = lib.mkIf config.services.openssh.enable [
          cfg.username
        ];

        assertions = [
          {
            assertion =
              let
                sshEnabled = config.services.openssh.enable;
                passAuthDisabled =
                  config.services.openssh.settings.PasswordAuthentication == false;
                hasKeys = config.my.host.ssh.authorizedKeys != [ ];
              in
              (sshEnabled && passAuthDisabled) -> hasKeys;
            message = ''
              Primary operator '${cfg.username}' whitelisted for SSH, but `config.my.host.ssh.authorizedKeys` empty.
              PasswordAuthentication disabled. Machine inaccessible over network.
            '';
          }
          {
            assertion = cfg.hashedPassword != "!";
            message = ''
              The primary operator '${cfg.username}' has no 'hashedPassword' set (defaults to '!').
              Because imperative user management (mutableUsers) is disabled and root is locked,
              you must provide a valid hash to prevent being permanently locked out of local logins and sudo.
            '';
          }
        ];
      };
    };
}
