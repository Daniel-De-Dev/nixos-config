# Shared identity options and defaults, independent of their data provider.
_: {
  flake.nixosModules.core-identity = { lib, ... }: {
    options.my = {
      operator = {
        username = lib.mkOption {
          type = lib.types.str;
          default = "operator";
          description = "Primary operator username.";
        };
        hashedPassword = lib.mkOption {
          type = lib.types.str;
          default = "!";
          description = "Password hash for the primary operator.";
        };
        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Operator-wide public SSH keys.";
        };
        fullName = lib.mkOption {
          type = lib.types.str;
          default = "System Operator";
          description = "The human-readable name of the operator.";
        };
        email = lib.mkOption {
          type = lib.types.str;
          default = "operator@localhost";
          description = "The primary email address of the operator.";
        };
        signingKey = lib.mkOption {
          type = lib.types.str;
          default = "~/.ssh/id_ed25519_git.pub";
          description = "Path to the operator's public SSH signing key.";
        };
        locale = {
          default = lib.mkOption {
            type = lib.types.str;
            default = "en_US.UTF-8";
            description = "The primary system language.";
          };
          measurement = lib.mkOption {
            type = lib.types.str;
            default = "en_US.UTF-8";
            description = "Locale for units, time formatting, and currency.";
          };
        };
      };

      host = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "nixos";
          description = "System hostname.";
        };
        id = lib.mkOption {
          type = lib.types.strMatching "[0-9a-fA-F]{8}";
          default = "00000000";
          description = "The 32-bit host ID as eight hexadecimal characters.";
        };
        network.macRandomize = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable MAC address randomization for Wi-Fi.";
        };
        timeZone = lib.mkOption {
          type = lib.types.str;
          default = "UTC";
          description = "The physical time zone of the host.";
        };
        keyMap = lib.mkOption {
          type = lib.types.str;
          default = "us";
          description = "The physical keyboard layout of the host.";
        };
        ssh = {
          authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Public SSH keys authorized to log into this host.";
          };
          matchBlocks = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Host-specific SSH client routing and identities.";
          };
        };
        security = {
          usbguard = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable USBGuard device restrictions.";
          };
          strictKernel = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable kernel lockdown and allocator hardening.";
          };
        };
      };
    };
  };
}
