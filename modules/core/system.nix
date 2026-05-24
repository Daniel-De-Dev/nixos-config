# =============================================================================
# This module establishes the base runtime hygiene and lifecycle maintenance
# for all managed machines.
#
# DESIGN CONSTRAINTS:
# 1. Every configuration inside this file must be fully agnostic
#    of physical form factors, storage topologies, and graphics hardware.
# 2. Do not use conditional toggles (`mkIf`) or abstract custom choices here;
#    a host inherits this entire profile explicitly.
# =============================================================================
{ ... }:
{
  flake.nixosModules.core =
    { pkgs, ... }:
    {
      nix = {
        settings = {
          sandbox = true;
          require-sigs = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "@wheel"
          ];
          allowed-users = [ "@wheel" ];
          auto-optimise-store = true;
        };

        optimise = {
          automatic = true;
          dates = [ "weekly" ];
        };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        registry.nixpkgs.to = {
          type = "path";
          path = pkgs.path;
        };

        nixPath = [ "nixpkgs=flake:nixpkgs" ];
      };

      systemd = {
        services.nix-store-verify = {
          description = "Verify Nix store contents";
          serviceConfig = {
            Type = "oneshot";
            IOSchedulingClass = "idle";
            CPUSchedulingPolicy = "idle";
            ExecStart = [
              "${pkgs.nix}/bin/nix-store"
              "--verify"
              "--check-contents"
            ];
          };
        };

        timers.nix-store-verify = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "weekly";
            Persistent = true;
          };
        };
      };

      boot.kernel.sysctl = {
        # System Limits
        "kernel.panic" = 10;
        "kernel.core_uses_pid" = 1;
        "kernel.pid_max" = 4 * 1024 * 1024;
        "fs.inotify.max_user_watches" = 512 * 1024;
        "fs.file-max" = 9223372036854775807; # INT64_MAX
      };

      boot.tmp = {
        useTmpfs = true;
        cleanOnBoot = true;
      };

      # Prevent Log Bloat
      services.journald.extraConfig = ''
        SystemMaxUse=250M
        SystemMaxFileSize=50M
      '';
    };
}
