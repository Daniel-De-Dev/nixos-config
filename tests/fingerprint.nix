# Verify authentication boundaries and the generated PAM stacks.
{
  lib,
  nixosSystem,
  modules,
  configurations,
}:
let
  evaluate =
    extra:
    (nixosSystem {
      system = "x86_64-linux";
      modules = [
        modules.core-unfree
        modules.hardware-fingerprint
        {
          boot.isContainer = true;
          system.stateVersion = "26.11";
          security.polkit.enable = true;
          services.openssh.enable = true;
        }
        extra
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate {
    my.hardware.fingerprint = {
      enable = true;
      pamServices = [
        "login"
        "sudo"
        "polkit-1"
      ];
    };
  };
  oem = evaluate (
    { pkgs, ... }: {
      my.hardware.fingerprint = {
        enable = true;
        driver = pkgs.libfprint-2-tod1-broadcom-cv3plus;
      };
    }
  );
  unsupportedPam = evaluate {
    my.hardware.fingerprint = {
      enable = true;
      pamServices = [ "custom" ];
    };
    security.pam.services.custom.useDefaultRules = false;
  };
  hosts = map (host: host.config) (lib.attrValues configurations);
  fingerprintHosts = lib.filter (config: config.services.fprintd.enable) hosts;
  passwordFallback =
    service:
    service.unixAuth
    && !service.allowNullPassword
    && service.rules.auth.unix.enable
    && service.rules.auth.fprintd.control == "sufficient"
    && service.rules.auth.fprintd.order < service.rules.auth.unix.order;
in
lib.runTests {
  testDisabledFeatureLeavesAuthenticationAlone = {
    expr =
      !disabled.services.fprintd.enable
      && disabled.my.allowedUnfree == [ ]
      && !disabled.security.pam.services.login.fprintAuth
      && !disabled.security.pam.services.sudo.fprintAuth;
    expected = true;
  };
  testUpstreamReadersNeedNoOemDriver = {
    expr = enabled.services.fprintd.enable && !enabled.services.fprintd.tod.enable;
    expected = true;
  };
  testOnlySelectedPamServicesAcceptFingerprints = {
    expr = lib.attrNames (
      lib.filterAttrs (_: service: service.fprintAuth) enabled.security.pam.services
    );
    expected = [
      "login"
      "polkit-1"
      "sudo"
    ];
  };
  testSelectedServicesKeepPasswordFallback = {
    expr = lib.all (
      name: passwordFallback enabled.security.pam.services.${name}
    ) enabled.my.hardware.fingerprint.pamServices;
    expected = true;
  };
  testSshAndPrivilegeSwitchingDoNotAcquireFingerprintAuth = {
    expr =
      !enabled.security.pam.services.sshd.rules.auth.fprintd.enable
      && !enabled.security.pam.services.su.rules.auth.fprintd.enable;
    expected = true;
  };
  testOemDriverIsAllowedAndPassedToFprintd = {
    expr =
      oem.services.fprintd.tod.enable
      && lib.elem "libfprint-2-tod1-broadcom-cv3plus" oem.my.allowedUnfree
      && lib.elem oem.services.fprintd.tod.driver oem.services.udev.packages
      &&
        oem.systemd.services.fprintd.environment.FP_TOD_DRIVERS_DIR
        == "${oem.services.fprintd.tod.driver}${oem.services.fprintd.tod.driver.driverPath}"
      && !oem.services.fprintd.enablePam;
    expected = true;
  };
  testCustomPamStacksRequireExplicitIntegration = {
    expr = lib.any (
      entry: !entry.assertion && lib.hasInfix "fingerprint.pamServices" entry.message
    ) unsupportedPam.assertions;
    expected = true;
  };
  testConfiguredHostsKeepPamAuthenticationScoped = {
    expr = lib.all (
      config:
      !config.services.fprintd.enablePam
      && lib.all (
        name: passwordFallback config.security.pam.services.${name}
      ) config.my.hardware.fingerprint.pamServices
      && !config.security.pam.services.sshd.fprintAuth
      && !config.security.pam.services.hyprlock.fprintAuth
    ) fingerprintHosts;
    expected = true;
  };
  testLyAllowsFingerprintSubmissionOnlyWhenLoginAcceptsIt = {
    expr = lib.all (
      config:
      config.services.displayManager.ly.enable
      ->
        config.services.displayManager.ly.settings.allow_empty_password == (
          config.security.pam.services.login.fprintAuth
          && !config.security.pam.services.login.allowNullPassword
        )
    ) hosts;
    expected = true;
  };
  testHyprlockUsesNativeFingerprintAuth = {
    expr = lib.all (
      config:
      config.programs.hyprlock.enable
      ->
        lib.hasInfix "enabled = true"
          config.environment.etc."xdg/hypr/hyprlock.conf".text
        &&
          lib.hasInfix
            (builtins.unsafeDiscardStringContext "${config.programs.hyprlock.package}/share/hypr/hyprlock.conf")
            config.environment.etc."xdg/hypr/hyprlock.conf".text
    ) fingerprintHosts;
    expected = true;
  };
}
