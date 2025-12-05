{
  config,
  lib,
  pkgs,
  ...
}:

let
  # A "Safe Default" template derived from best practices (Nix-Mineral / Systemd recommendations)
  hardeningDefaults = {
    # File System Isolation
    ProtectSystem = "strict"; # Read-only /usr, /boot, /etc
    ProtectHome = "read-only"; # Read-only /home
    PrivateTmp = true; # Unique /tmp per service
    PrivateDevices = true; # No access to /dev (except /dev/null, etc.)
    PrivateMounts = true; # Isolate mount namespace

    # Kernel & Privilege Restrictions
    NoNewPrivileges = true; # Prevent sudo/suid
    ProtectControlGroups = true; # Read-only cgroups
    ProtectKernelLogs = true; # No access to dmesg
    ProtectKernelModules = true; # Cannot load modules
    ProtectKernelTunables = true; # Cannot change sysctl
    ProtectHostname = true; # Cannot change hostname
    LockPersonality = true; # Block changing architecture (e.g. 32bit)

    # Network & Memory
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ]; # TCP/IP/Unix sockets only
    RestrictNamespaces = true; # Restrict namespace creation
    RestrictRealtime = true; # Block realtime scheduling
    RestrictSUIDSGID = true; # Block SUID binaries
    MemoryDenyWriteExecute = true; # Block W^X memory mappings

    # Syscall Filtering
    SystemCallArchitectures = "native";
    # Allow standard service calls, block privileged ones (mount, swap, reboot)
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];

    # Default Permissions
    UMask = "0077"; # Files created are only readable by the service user
  };

  # Helper to apply the defaults to a service
  hardenedService = name: {
    serviceConfig = hardeningDefaults;
  };

  cfg = config.my.hardening;
in
{
  options.my.hardening.localServices = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = ''
      List of systemd service names to apply strict hardening defaults to.
      Example: [ "my-custom-script" "forgejo-runner" ]
    '';
  };

  config = lib.mkIf (cfg.localServices != [ ]) {
    # Ensure AppArmor is available if we are hardening services
    security.apparmor = {
      enable = true;
      packages = [ pkgs.apparmor-profiles ];
    };

    # Apply the hardening config to every service listed in the option
    systemd.services = lib.genAttrs cfg.localServices hardenedService;
  };
}
