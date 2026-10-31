# Check boot security and feature-dependent policies.
{ lib, configurations }:
let
  systems = lib.attrValues configurations;
  hosts = map (host: host.config) systems;
  hibernatingHosts = lib.filter (
    config: config.my.hardware.hibernation.enable
  ) hosts;
  exceptionHosts = lib.filter (
    config: config.my.hardware.hibernation.lockdownOverride.enable
  ) hibernatingHosts;
  nvidiaHosts = lib.filter (
    config: config.my.hardware.gpu.vendor == "nvidia"
  ) hosts;
  fixtureValue = lib.mkOverride 75;
  fixture = (lib.head systems).extendModules {
    modules = [
      {
        my.host.security.kernelLockdown = fixtureValue "integrity";
        my.hardware.hibernation = {
          enable = fixtureValue true;
          lockdownOverride.enable = fixtureValue true;
          resumeDevice = fixtureValue "/dev/mapper/boot-security-test";
          resumeOffset = fixtureValue 0;
        };
        boot.initrd.luks.devices.boot-security-test.device =
          "/dev/disk/by-label/boot-security-test";
      }
    ];
  };
  extendFixture =
    module: (fixture.extendModules { modules = [ module ]; }).config;
  rejects =
    message: config:
    lib.any (
      item: !item.assertion && lib.hasInfix message item.message
    ) config.assertions;
  withoutOverride = extendFixture {
    my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
  };
  withoutLockdown = extendFixture {
    my.host.security.kernelLockdown = lib.mkForce "none";
    my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
  };
  hasPatch =
    config:
    lib.any (
      patch: patch.name == "hibernate-lockdown-opt-in"
    ) config.boot.kernelPatches;
  overrideFlag = "hibernate=allow_locked_down";
in
lib.runTests {
  testHostsKeepSignedUefiBoot = {
    expr = lib.all (
      config: config.boot.lanzaboote.enable && !config.boot.loader.systemd-boot.enable
    ) hosts;
    expected = true;
  };
  testHostsRequestLockdownAndModuleVerification = {
    expr = lib.all (
      config:
      config.my.host.security.kernelLockdown == "integrity"
      && lib.elem "lockdown=integrity" config.boot.kernelParams
      && config.my.hardware.secure-boot.verifyKernelModules
      && lib.elem "module.sig_enforce=1" config.boot.kernelParams
    ) hosts;
    expected = true;
  };
  testBootspecAndSystemLinkUseVerifiedKernel = {
    expr = lib.all (
      config:
      let
        image = builtins.unsafeDiscardStringContext "${config.system.build.verifiedKernel}/${config.system.boot.loader.kernelFile}";
      in
      config.system.build.kernel == config.system.build.verifiedKernel
      && lib.hasInfix image config.system.systemBuilderCommands
      && lib.hasInfix image config.boot.bootspec.writer
      && lib.hasInfix ''."org.nixos.bootspec.v1".kernel = $kernel'' config.boot.bootspec.writer
    ) hosts;
    expected = true;
  };
  testCertificatesCoverTheCompleteModuleTree = {
    expr =
      lib.all (
        config:
        config.system.build.verifiedKernel.moduleCertificates
        == "${config.system.modulesTree}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/modules.cer"
      ) hosts
      && lib.all (
        config:
        let
          nvidia = config.hardware.nvidia;
          nvidiaModule = if nvidia.open then nvidia.package.open else nvidia.package.mod;
        in
        lib.elem nvidiaModule config.boot.extraModulePackages
      ) nvidiaHosts;
    expected = true;
  };
  testLockdownRejectsDisablingModuleVerification = {
    expr =
      rejects "requires my.hardware.secure-boot.verifyKernelModules"
        (extendFixture {
          my.hardware.secure-boot.verifyKernelModules = lib.mkForce false;
        });
    expected = true;
  };
  testStrictHardeningRemainsEnabled = {
    expr = lib.all (
      config:
      config.my.host.security.strictKernel
      && lib.all (parameter: lib.elem parameter config.boot.kernelParams) [
        "slab_nomerge"
        "init_on_alloc=1"
        "iommu=force"
      ]
    ) hosts;
    expected = true;
  };
  testNixosGeneratesOneLsmParameterWithBpfLast = {
    expr = lib.all (
      config:
      lib.length (lib.filter (lib.hasPrefix "lsm=") config.boot.kernelParams) == 1
      && lib.last config.security.lsm == "bpf"
      && lib.elem "apparmor" config.security.lsm
      && lib.elem "integrity" config.security.lsm
    ) hosts;
    expected = true;
  };
  testEnabledExceptionsUseDeclaredLuksResumeDevice = {
    expr = lib.all (
      config:
      lib.hasPrefix "/dev/mapper/" config.boot.resumeDevice
      && builtins.hasAttr (lib.removePrefix "/dev/mapper/" config.boot.resumeDevice) config.boot.initrd.luks.devices
    ) exceptionHosts;
    expected = true;
  };
  testHibernatingHostsKeepResumeParameters = {
    expr = lib.all (
      config:
      config.boot.resumeDevice == config.my.hardware.hibernation.resumeDevice
      && !config.security.protectKernelImage
      && !lib.elem "nohibernate" config.boot.kernelParams
      && lib.elem "resume=${config.my.hardware.hibernation.resumeDevice}" config.boot.kernelParams
      && lib.elem "resume_offset=${toString config.my.hardware.hibernation.resumeOffset}" config.boot.kernelParams
      && config.boot.kernel.sysctl."kernel.kexec_load_disabled" == 1
    ) hibernatingHosts;
    expected = true;
  };
  testNvidiaHostsKeepHibernationSupport = {
    expr = lib.all (
      config:
      config.hardware.nvidia.powerManagement.enable
      && lib.elem "nvidia.NVreg_PreserveVideoMemoryAllocations=1" config.boot.kernelParams
    ) nvidiaHosts;
    expected = true;
  };
  testConfiguredExceptionsIncludePatchAndBootOptIn = {
    expr = lib.all (
      config:
      config.my.hardware.hibernation.lockdownOverride.active
      && hasPatch config
      && lib.elem overrideFlag config.boot.kernelParams
    ) exceptionHosts;
    expected = true;
  };
  testExplicitExceptionIncludesPatchAndBootOptIn = {
    expr =
      fixture.config.my.hardware.hibernation.lockdownOverride.active
      && hasPatch fixture.config
      && lib.elem overrideFlag fixture.config.boot.kernelParams;
    expected = true;
  };
  testExceptionIsInactiveWhenHibernationIsDisabled = {
    expr =
      let
        config = extendFixture { my.hardware.hibernation.enable = lib.mkForce false; };
      in
      !config.my.hardware.hibernation.lockdownOverride.active
      && !hasPatch config
      && !lib.elem overrideFlag config.boot.kernelParams;
    expected = true;
  };
  testActiveStatusIsReadOnly = {
    expr = lib.all (
      host: host.options.my.hardware.hibernation.lockdownOverride.active.readOnly
    ) systems;
    expected = true;
  };
  testRemovingThePatchMakesExceptionInactiveAndFailsPolicy = {
    expr =
      let
        config = extendFixture { boot.kernelPatches = lib.mkForce [ ]; };
      in
      !config.my.hardware.hibernation.lockdownOverride.active
      && rejects "Hibernation under lockdown requires" config;
    expected = true;
  };
  testRemovingTheFlagMakesExceptionInactiveAndFailsPolicy = {
    expr =
      let
        config = extendFixture {
          boot.kernelParams = lib.mkForce [ "lockdown=integrity" ];
        };
      in
      !config.my.hardware.hibernation.lockdownOverride.active
      && rejects "Hibernation under lockdown requires" config;
    expected = true;
  };
  testLockdownAndHibernationRequireException = {
    expr = rejects "Hibernation under lockdown requires" withoutOverride;
    expected = true;
  };
  testManualLockdownAlsoRequiresException = {
    expr = rejects "Hibernation under lockdown requires" (extendFixture {
      my.host.security.kernelLockdown = lib.mkForce "none";
      my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
      boot.kernelParams = [ "lockdown=confidentiality" ];
    });
    expected = true;
  };
  testNoLockdownNeedsNoException = {
    expr =
      !rejects "Hibernation under lockdown requires" withoutLockdown
      && !hasPatch withoutLockdown
      && !withoutLockdown.my.hardware.secure-boot.verifyKernelModules
      && !lib.elem overrideFlag withoutLockdown.boot.kernelParams;
    expected = true;
  };
  testExceptionDoesNotOverrideNohibernate = {
    expr = rejects "Hibernation conflicts with the nohibernate" (extendFixture {
      boot.kernelParams = [ "nohibernate" ];
    });
    expected = true;
  };
  testBootFlagAloneCannotClaimAnException = {
    expr =
      rejects "a boot parameter alone does not patch the kernel"
        (extendFixture {
          my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
          boot.kernelParams = [ overrideFlag ];
        });
    expected = true;
  };
  testExceptionRequiresDeclaredLuksResumeDevice = {
    expr =
      rejects "requires resumeDevice to name a decrypted LUKS mapper"
        (extendFixture {
          my.hardware.hibernation.resumeDevice = lib.mkForce "/dev/sda2";
        });
    expected = true;
  };
  testChangingKernelSeriesRequiresPatchReview = {
    expr = rejects "reviewed for Linux 7.3.x only" (extendFixture {
      boot.kernelPackages = lib.mkForce (
        fixture.config.boot.kernelPackages.extend (
          _: previous: {
            kernel = previous.kernel.override { argsOverride.version = "7.4"; };
          }
        )
      );
    });
    expected = true;
  };
  testRemovedInitrdToggleHasNoDefinitions = {
    expr = lib.all (
      host: !host.options.boot.initrd.systemd.enable.isDefined
    ) systems;
    expected = true;
  };
}
