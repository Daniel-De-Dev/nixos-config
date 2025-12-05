{ inputs, config, ... }:
{
  nix = {
    settings = {
      sandbox = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      require-sigs = true;
      trusted-users = [ "root" ];
      allowed-users = [ "@wheel" ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  systemd = {
    services.nix-store-verify = {
      description = "Verify Nix store contents";
      serviceConfig = {
        Type = "oneshot";
        IOSchedulingClass = "idle";
        CPUSchedulingPolicy = "idle";
        ExecStart = [
          "${config.nix.package}/sw/bin/nix-store"
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
}
