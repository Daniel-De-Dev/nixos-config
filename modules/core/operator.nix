# =============================================================================
# This module establishes the primary administrative identity and enforces
# baseline access control policies for all managed machines.
#
# DESIGN CONSTRAINTS:
# 1. This file strictly governs authentication and permissions. Do not
#    configure user-space software, dotfiles, or shells here.
# 2. Imperative user management is disabled. All identity changes, authorized
#    SSH keys, and group policies must be declared here.
# =============================================================================
{ ... }: {
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
          hashedPassword = cfg.hashedPassword;
          group = cfg.username;

          extraGroups = [
            "wheel"
            "networkmanager"
            "video"
            "audio"
            "render"
            "input"
            "systemd-journal"
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
                  (config.services.openssh.settings.PasswordAuthentication) == false;
                hasKeys = config.my.host.ssh.authorizedKeys != [ ];
              in
              (sshEnabled && passAuthDisabled) -> hasKeys;
            message = ''
              The primary operator '${cfg.username}' is whitelisted for SSH, but has no 'sshKeys' defined.
              Since PasswordAuthentication is disabled, this machine will be inaccessible over the network.
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
