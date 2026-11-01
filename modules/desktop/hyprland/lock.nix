# Purpose: Integrate the declarative lock screen and idle policy with UWSM.
# Scope: The installed Hyprland session.
# - All lock requests use one service. sleep waits for the Wayland lock event.
{ inputs, ... }: {
  flake.nixosModules.hyprland-lock =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.desktop.hyprland;
      desktop = import ../../../packages/hyprland/desktop.nix {
        inherit lib pkgs;
        inherit (inputs) wrapper-manager;
      };
      lockScreen = pkgs.callPackage ../../../packages/hyprlock {
        inherit (inputs) wrapper-manager;
        theme = config.my.theme;
        inherit (cfg.lockScreen) wallpaper blurSize blurPasses;
        batteryId = config.my.hardware.power.batteryId or null;
        fingerprint = config.services.fprintd.enable;
      };
      hibernation = config.my.hardware.hibernation.enable or false;
      sleepAction = if hibernation then "suspend-then-hibernate" else "suspend";
      lockCommand = "${config.systemd.package}/bin/loginctl lock-session";
      displayCommand =
        action:
        "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"${action}\" })'";
      listener = timeout: commands: ''
        listener {
            timeout = ${toString timeout}
            ${commands}
        }
      '';
      idleText = ''
        general {
            lock_cmd = ${config.systemd.package}/bin/systemctl --user start hyprlock.service
            before_sleep_cmd = ${lockCommand}
            after_sleep_cmd = ${displayCommand "enable"}
            inhibit_sleep = 3
            ignore_dbus_inhibit = false
            ignore_systemd_inhibit = false
            ignore_wayland_inhibit = false
        }
      ''
      + (
        if !cfg.idle.enable then
          # Hypridle requires a listener even when only its lock/sleep hooks run.
          # This listener has no commands, so inactivity performs no action.
          listener 1 ""
        else
          listener cfg.idle.lockAfter "on-timeout = ${lockCommand}"
          + lib.optionalString (cfg.idle.screenOffAfter != null) (
            listener cfg.idle.screenOffAfter ''
              on-timeout = ${displayCommand "disable"}
              on-resume = ${displayCommand "enable"}
            ''
          )
          + lib.optionalString (cfg.idle.suspendAfter != null) (
            listener cfg.idle.suspendAfter "on-timeout = ${config.systemd.package}/bin/systemctl ${sleepAction}"
          )
      );
      idleConfig = pkgs.writeText "hypridle.conf" idleText;
      idleDaemon =
        (inputs.wrapper-manager.lib {
          inherit pkgs;
          modules = [
            {
              wrappers.hypridle = {
                basePackage = pkgs.hypridle;
                programs.hypridle.prependFlags = [
                  "--config"
                  idleConfig
                ];
              };
            }
          ];
        }).config.wrappers.hypridle.wrapped.overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              inherit idleConfig idleText;
            };
          });
    in
    {
      options.my.desktop.hyprland = {
        lockScreen = {
          wallpaper = lib.mkOption {
            type = lib.types.path;
            default = desktop.wallpaper;
            description = "Wallpaper to blur on the lock screen.";
          };
          blurSize = lib.mkOption {
            type = lib.types.ints.between 1 32;
            default = 8;
            description = "Lock screen wallpaper blur radius.";
          };
          blurPasses = lib.mkOption {
            type = lib.types.ints.between 0 10;
            default = 3;
            description = "Wallpaper blur passes; zero disables blur.";
          };
        };
        idle = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable automatic idle timeouts. Manual locking and locking before sleep remain active when false.";
          };
          lockAfter = lib.mkOption {
            type = lib.types.ints.positive;
            default = 300;
            description = "Seconds of inactivity before locking the session.";
          };
          screenOffAfter = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = 600;
            description = "Seconds of inactivity before turning displays off; null disables this timeout.";
          };
          suspendAfter = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = 1800;
            description = "Seconds of inactivity before sleep; null disables this timeout. Uses suspend-then-hibernate when my.hardware.hibernation.enable is true.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        programs.hyprlock = {
          enable = true;
          package = lockScreen;
        };
        # Prevent a second fingerprint client in PAM competing with native auth.
        security.pam.services.hyprlock.fprintAuth = lib.mkForce false;
        services.hypridle = {
          enable = true;
          package = idleDaemon;
        };
        systemd.user.services = {
          hypridle = {
            # The upstream unit embeds the unwrapped binary's store path.
            overrideStrategy = "asDropin";
            serviceConfig.ExecStart = [
              ""
              (lib.getExe idleDaemon)
            ];
          };
          hyprlock = {
            description = "Hyprland lock screen";
            partOf = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
            # Keep an already locked session running across rebuilds.
            restartIfChanged = false;
            serviceConfig = {
              ExecStart = lib.getExe lockScreen;
              Restart = "on-failure";
              RestartSec = 1;
            };
          };
        };

        assertions = [
          {
            assertion =
              !cfg.idle.enable
              || cfg.idle.screenOffAfter == null
              || cfg.idle.screenOffAfter > cfg.idle.lockAfter;
            message = "Hyprland idle.screenOffAfter must be later than idle.lockAfter (or null).";
          }
          {
            assertion =
              !cfg.idle.enable
              || cfg.idle.suspendAfter == null
              ||
                cfg.idle.suspendAfter > (
                  if cfg.idle.screenOffAfter == null then
                    cfg.idle.lockAfter
                  else
                    cfg.idle.screenOffAfter
                );
            message = "Hyprland idle.suspendAfter must be later than locking and screen-off timeouts (or null).";
          }
        ];
      };
    };
}
