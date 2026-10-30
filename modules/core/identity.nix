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
        network = {
          macRandomize = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable MAC address randomization for Wi-Fi.";
          };
          vpnProfiles = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  gateway = lib.mkOption {
                    type = lib.types.strMatching ".+";
                    description = "OpenConnect gateway, including any login path.";
                  };
                  protocol = lib.mkOption {
                    type = lib.types.str;
                    default = "anyconnect";
                    description = "VPN protocol understood by OpenConnect.";
                  };
                  authGroup = lib.mkOption {
                    type = lib.types.nullOr (lib.types.strMatching ".+");
                    default = null;
                    description = "Optional AnyConnect group value for the main login form.";
                  };
                  userAgent = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Optional user agent required by the gateway.";
                  };
                  mtu = lib.mkOption {
                    type = lib.types.nullOr (lib.types.ints.between 576 65535);
                    default = null;
                    description = "Optional tunnel MTU in bytes.";
                  };
                  dnsSearch = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "DNS search or routing domains, such as ~example.invalid.";
                  };
                };
              }
            );
            default = { };
            description = ''
              OpenConnect profiles supplied by private data. Attribute names are
              connection IDs and must contain no spaces or path separators.
              Passwords, session cookies and MFA tokens do not belong here.
            '';
          };
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
            description = "Enable allocator, memory, and DMA hardening boot parameters.";
          };
          kernelLockdown = lib.mkOption {
            type = lib.types.enum [
              "none"
              "integrity"
              "confidentiality"
            ];
            default = "none";
            description = ''
              Kernel lockdown policy, independent of strictKernel and UEFI Secure Boot.
              Enabling it requires trusted module signatures and blocks ordinary
              hibernation unless the explicit custom-kernel exception is active. "none"
              omits the lockdown parameter; it cannot undo a kernel-enforced policy.
            '';
          };
        };
      };
    };
  };
}
