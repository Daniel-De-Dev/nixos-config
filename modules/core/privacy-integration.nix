# =============================================================================
# Data Bus & Typed Abstraction Layer
#
# This module acts as the central nervous system for system configuration.
# It ingests untyped, sensitive information from an external repository
# (inputs.privacy) and routes it into a strictly typed, globally accessible API
# (`config.my.operator` and `config.my.host`).
#
# USAGE EXPECTATIONS:
# 1. The host entry point (`nixosConfigurations."box-01"`) must inject its
#    identity via `specialArgs = { machine = "box-01"; };`.
# 2. Downstream modules MUST consume data via the typed API
#    (e.g., `config.my.operator.username`), NOT the raw privacy bus.
# 3. If the privacy input is absent, or the machine ID is not found, this
#    module safely returns fallback defaults to prevent evaluation crashes.
#
# EXPECTED PRIVACY REPO SCHEMA (data.nix):
# {
#   global = { operator = { username = "..."; hashedPassword = "..."; }; };
#   hosts = {
#     "box-01" = { hostName = "..."; hostId = "..."; };
#   };
# }
#
# DESIGN CONSTRAINTS:
# 1. The `options` block defines the strict schema contract.
# 2. The `config` block actively routes `rawPrivacy` into that schema.
# 3. Downstream hosts can override these values imperatively because they
#    are mapped using `lib.mkDefault`.
# =============================================================================
{ ... }: {
  flake.nixosModules.core =
    {
      lib,
      config,
      inputs,
      machine ? null,
      ...
    }:
    let
      hasPrivacyInput = inputs ? privacy;
      privacyPath = if hasPrivacyInput then inputs.privacy or null else null;
      dataFile = if privacyPath != null then "${privacyPath}/data.nix" else null;
      hasPrivacyData = dataFile != null && builtins.pathExists dataFile;

      parsedData =
        if hasPrivacyData then
          (import dataFile)
        else
          {
            global = { };
            hosts = { };
          };

      globalData = parsedData.global or { };
      hostData =
        if hasPrivacyInput && machine != null && machine != "" then
          parsedData.hosts.${machine} or { }
        else
          { };

      # The raw, merged privacy attribute set
      rawPrivacy = lib.recursiveUpdate globalData hostData;
    in
    {
      # -------------------------------------------------------------------------
      # OPTION DEFINITIONS (The Schema Contract)
      # -------------------------------------------------------------------------
      options.my = {
        privacy = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Raw, untyped privacy data. Modules should prefer my.operator or my.host.";
        };

        operator = {
          username = lib.mkOption {
            type = lib.types.str;
            description = "Primary operator username";
          };
          hashedPassword = lib.mkOption {
            type = lib.types.str;
            description = "The yescrypt hash for the primary operator.";
          };
          sshKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Authorized SSH keys for the primary operator.";
          };

          fullName = lib.mkOption {
            type = lib.types.str;
            description = "The human-readable name of the operator.";
          };

          email = lib.mkOption {
            type = lib.types.str;
            description = "The primary email address of the operator.";
          };

          signingKey = lib.mkOption {
            type = lib.types.str;
            description = "Absolute path to the public SSH key.";
          };

          locale = {
            default = lib.mkOption {
              type = lib.types.str;
              description = "The primary system language.";
            };
            measurement = lib.mkOption {
              type = lib.types.str;
              description = "The locale used for units, time formatting, and currency.";
            };
          };
        };

        host = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "System hostname";
          };
          id = lib.mkOption {
            type = lib.types.str;
            description = "8-character System ID";
          };

          network = {
            macRandomize = lib.mkOption {
              type = lib.types.bool;
              description = "Enable MAC address randomization for Wi-Fi.";
            };
          };

          timeZone = lib.mkOption {
            type = lib.types.str;
            description = "The physical time zone of the host.";
          };
          keyMap = lib.mkOption {
            type = lib.types.str;
            description = "The physical keyboard layout of the host.";
          };

          ssh = {
            authorizedKeys = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of public SSH keys authorized to log into this host.";
            };
            matchBlocks = lib.mkOption {
              type = lib.types.attrs;
              description = "Host-specific SSH client routing and identity rules.";
            };
          };

          security = {
            usbguard = lib.mkOption {
              type = lib.types.bool;
              description = "Enable strict USBGuard device whitelisting.";
            };
            strictKernel = lib.mkOption {
              type = lib.types.bool;
              description = "Enable lockdown=integrity and aggressive memory allocator hardening.";
            };
          };
        };
      };

      # -------------------------------------------------------------------------
      # DATA MAPPING (The Routing Table)
      # -------------------------------------------------------------------------
      config = {
        # Keep the raw data accessible
        my.privacy = rawPrivacy;

        my.operator = {
          username = lib.mkDefault (rawPrivacy.operator.username or "operator");
          hashedPassword = lib.mkDefault (rawPrivacy.operator.hashedPassword or "!");
          sshKeys = lib.mkDefault (rawPrivacy.operator.sshKeys or [ ]);

          locale = {
            default = lib.mkDefault (rawPrivacy.locale.default or "en_US.UTF-8");
            measurement = lib.mkDefault (rawPrivacy.locale.measurement or "en_US.UTF-8");
          };

          fullName = lib.mkDefault (rawPrivacy.operator.fullName or "System Operator");
          email = lib.mkDefault (rawPrivacy.operator.email or "operator@localhost");
          signingKey = lib.mkDefault (
            rawPrivacy.operator.signingKey or "~/.ssh/id_ed25519_git.pub"
          );
        };

        my.host = {
          name = lib.mkDefault (rawPrivacy.hostName or machine);
          id = lib.mkDefault (rawPrivacy.hostId or "00000000");
          network = {
            macRandomize = lib.mkDefault (rawPrivacy.network.macRandomize or false);
          };

          timeZone = lib.mkDefault (rawPrivacy.timeZone or "UTC");
          keyMap = lib.mkDefault (rawPrivacy.keyMap or "us");

          ssh = {
            authorizedKeys = lib.mkDefault (rawPrivacy.ssh.authorizedKeys or [ ]);
            matchBlocks = lib.mkDefault (rawPrivacy.ssh.matchBlocks or { });
          };

          security = {
            usbguard = lib.mkDefault (rawPrivacy.security.usbguard or false);
            strictKernel = lib.mkDefault (rawPrivacy.security.strictKernel or true);
          };
        };
      };
    };
}
