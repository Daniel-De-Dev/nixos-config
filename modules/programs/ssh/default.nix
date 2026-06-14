# =============================================================================
# Manages SSH capabilities. Strictly consumes host-specific routing rules
# and authorized keys from the external data bus.
#
# DESIGN CONSTRAINTS:
# 1.  Keys must be generated uniquely per host using the provided
#    `ssh-forge` script to prevent key reuse across the fleet.
# =============================================================================
_: {
  flake.nixosModules.programs-ssh =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      opUsername = config.my.operator.username;
      opEmail = config.my.operator.email;

      hostAuthorizedKeys = config.my.host.ssh.authorizedKeys;
      hostMatchBlocks = config.my.host.ssh.matchBlocks;

      rotationLimitDays = 90;

      forgeScript = builtins.replaceStrings [ "@email@" ] [ opEmail ] (
        builtins.readFile ./scripts/ssh-forge.sh
      );
      monitorScript =
        builtins.replaceStrings [ "@limit@" ] [ (toString rotationLimitDays) ]
          (builtins.readFile ./scripts/ssh-monitor.sh);

      sshForge = pkgs.writeShellApplication {
        name = "ssh-forge";
        runtimeInputs = [ pkgs.openssh ];
        text = forgeScript;
      };

      sshMonitor = pkgs.writeShellApplication {
        name = "ssh-rotation-monitor";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.libnotify
        ];
        text = monitorScript;
      };

      # -----------------------------------------------------------------------
      # Converts Attrs to SSH Config String
      # -----------------------------------------------------------------------
      compileSshOptions =
        options:
        let
          formatValue =
            v: if builtins.isBool v then (if v then "yes" else "no") else toString v;
        in
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (k: v: "  ${k} ${formatValue v}") options
        );

      compiledMatchBlocksStr = lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (host: options: ''
          Host ${host}
          ${compileSshOptions options}
        '') hostMatchBlocks
      );

    in
    {
      options.my.programs.ssh.enable = lib.mkEnableOption "SSH capabilities";

      config = lib.mkIf config.my.programs.ssh.enable {
        environment.systemPackages = [
          sshForge
          sshMonitor
        ];

        # ---------------------------------------------------------------------
        # Outbound Configuration & Routing
        # ---------------------------------------------------------------------
        programs.ssh = {
          startAgent = true;

          extraConfig = ''
            ${compiledMatchBlocksStr}

            Host *
              AddKeysToAgent yes
              ServerAliveInterval 60
              ServerAliveCountMax 3
              HashKnownHosts yes
              UpdateHostKeys ask
          '';
        };

        # ---------------------------------------------------------------------
        # Inbound Configuration & Hardening
        # ---------------------------------------------------------------------
        services.openssh = {
          enable = true;
          openFirewall = false; # Host must explicitly open port 22

          hostKeys = [
            {
              path = "/etc/ssh/ssh_host_ed25519_key";
              type = "ed25519";
            }
          ];

          settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PubkeyAuthentication = true;
            AuthenticationMethods = "publickey";

            # Hardened Cryptography
            KexAlgorithms = [
              "sntrup761x25519-sha512@openssh.com"
              "curve25519-sha256"
              "curve25519-sha256@libssh.org"
              "diffie-hellman-group18-sha512"
              "diffie-hellman-group16-sha512"
            ];
            Ciphers = [
              "chacha20-poly1305@openssh.com"
              "aes256-gcm@openssh.com"
              "aes128-gcm@openssh.com"
            ];
            Macs = [
              "hmac-sha2-512-etm@openssh.com"
              "hmac-sha2-256-etm@openssh.com"
            ];

            # Feature Restriction
            X11Forwarding = false;
            AllowAgentForwarding = "no";
            AllowTcpForwarding = "no";
            AllowStreamLocalForwarding = "no";
            PermitTunnel = "no";

            # Connection Limits
            MaxStartups = "10:30:60";
            MaxSessions = 3;
            MaxAuthTries = 3;
            LoginGraceTime = "20s";
            ClientAliveInterval = 300;
            ClientAliveCountMax = 2;
            LogLevel = "VERBOSE";
          };
        };

        users.users.${opUsername}.openssh.authorizedKeys.keys = hostAuthorizedKeys;

        # ---------------------------------------------------------------------
        # Background Rotation Monitor
        # ---------------------------------------------------------------------
        systemd.user.services.ssh-rotation-monitor = {
          description = "Monitor SSH key age and notify if rotation is required";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe sshMonitor}";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            PrivateTmp = true;
            MemoryDenyWriteExecute = true;
          };
        };

        systemd.user.timers.ssh-rotation-monitor = {
          description = "Daily trigger for SSH rotation monitor";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };
      };
    };
}
