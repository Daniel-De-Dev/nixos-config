# Exercise idle policy branches without identifying any host's hardware role.
{
  lib,
  nixosSystem,
  modules,
}:
let
  has =
    needle: haystack:
    lib.hasInfix (builtins.unsafeDiscardStringContext needle) haystack;
  evaluate =
    extra:
    (nixosSystem {
      system = "x86_64-linux";
      modules = [
        modules.core-palette
        modules.hardware-hibernation
        modules.hyprland-lock
        ({ lib, ... }: {
          options.my.desktop.hyprland.enable = lib.mkEnableOption "test session";
          config = {
            my.desktop.hyprland.enable = true;
            boot.isContainer = true;
            system.stateVersion = "26.11";
          };
        })
        extra
      ];
    }).config;
  plain = evaluate { };
  disabled = evaluate { my.desktop.hyprland.enable = lib.mkForce false; };
  hibernation = evaluate {
    my.hardware.hibernation = {
      enable = true;
      resumeDevice = "/dev/disk/by-label/resume";
      resumeOffset = 0;
    };
    swapDevices = [ { device = "/dev/disk/by-label/resume"; } ];
  };
  fingerprint = evaluate { services.fprintd.enable = true; };
  manualOnly = evaluate { my.desktop.hyprland.idle.enable = false; };
  custom = evaluate {
    my.desktop.hyprland.idle = {
      lockAfter = 60;
      screenOffAfter = null;
      suspendAfter = 120;
    };
  };
  invalid = evaluate { my.desktop.hyprland.idle.suspendAfter = 1; };
  idle = config: config.services.hypridle.package.idleText;
  screen = config: config.programs.hyprlock.package.configText;
in
lib.runTests {
  testDisabledDesktopDoesNotEnableLockServices = {
    expr = !disabled.programs.hyprlock.enable && !disabled.services.hypridle.enable;
    expected = true;
  };
  testSleepPolicyFollowsConfiguredHibernation = {
    expr =
      has "/bin/systemctl suspend\n" (idle plain)
      && has "/bin/systemctl suspend-then-hibernate\n" (idle hibernation)
      && !(hibernation.services.logind.settings.Login ? IdleAction);
    expected = true;
  };
  testManualLockAndSleepWaitForWaylandLock = {
    expr =
      has "inhibit_sleep = 3" (idle plain)
      && has "lock_cmd = ${plain.systemd.package}/bin/systemctl --user start hyprlock.service" (
        idle plain
      )
      && has "before_sleep_cmd = ${plain.systemd.package}/bin/loginctl lock-session" (
        idle plain
      )
      && plain.systemd.user.services.hyprlock.wantedBy == [ ]
      && !plain.systemd.user.services.hyprlock.restartIfChanged;
    expected = true;
  };
  testServiceStartsWrappedIdleDaemon = {
    expr =
      plain.systemd.user.services.hypridle.serviceConfig.ExecStart == [
        ""
        (lib.getExe plain.services.hypridle.package)
      ];
    expected = true;
  };
  testDisablingTimeoutsKeepsManualAndSleepLocking = {
    expr =
      manualOnly.services.hypridle.enable
      && !has "on-timeout =" (idle manualOnly)
      && has "before_sleep_cmd =" (idle manualOnly);
    expected = true;
  };
  testTimeoutsCanBeChangedAndScreenOffDisabled = {
    expr =
      has "timeout = 60" (idle custom)
      && has "timeout = 120" (idle custom)
      && !has "action = \"disable\"" (idle custom);
    expected = true;
  };
  testInvalidTimerOrderingIsRejected = {
    expr = lib.any (
      item: !item.assertion && has "idle.suspendAfter" item.message
    ) invalid.assertions;
    expected = true;
  };
  testNativeFingerprintIsConditionalAndPamKeepsPasswords = {
    expr =
      has "fingerprint:enabled = false" (screen plain)
      && has "fingerprint:enabled = true" (screen fingerprint)
      && !fingerprint.security.pam.services.hyprlock.fprintAuth
      && fingerprint.security.pam.services.hyprlock.unixAuth;
    expected = true;
  };
  testLockScreenUsesWallpaperOnAllMonitors = {
    expr =
      has "path = ${plain.my.desktop.hyprland.lockScreen.wallpaper}" (screen plain)
      && !has "path = screenshot" (screen plain)
      && has "monitor =\n" (screen plain)
      && has "immediate_render = true" (screen plain)
      && has "animations {\n    enabled = false" (screen plain);
    expected = true;
  };
}
