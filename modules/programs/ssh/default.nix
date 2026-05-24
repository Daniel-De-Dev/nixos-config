# =============================================================================
# Manages SSH capabilities. Strictly consumes host-specific routing rules
# and authorized keys from the external data bus.
# =============================================================================
{ ... }:
{
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
      # THE COMPILER: Converts Attrs to SSH Config String
      # -----------------------------------------------------------------------
      compileSshOptions =
        options:
        let
          # SSH requires "yes" or "no" instead of true/false
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
      environment.systemPackages = [
        sshForge
        sshMonitor
      ];

      # -----------------------------------------------------------------------
      # CLIENT: Outbound Configuration & Routing
      # -----------------------------------------------------------------------
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

      # -----------------------------------------------------------------------
      # SERVER: Inbound Configuration & Hardening
      # -----------------------------------------------------------------------
      services.openssh = {
        enable = true;

        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];

        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          X11Forwarding = false;
          AllowAgentForwarding = false;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;
        };
      };

      users.users.${opUsername}.openssh.authorizedKeys.keys = hostAuthorizedKeys;

      # -----------------------------------------------------------------------
      # HYGIENE: Background Rotation Monitor
      # -----------------------------------------------------------------------
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
}
