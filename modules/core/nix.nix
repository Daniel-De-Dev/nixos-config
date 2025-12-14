{ pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

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
}
