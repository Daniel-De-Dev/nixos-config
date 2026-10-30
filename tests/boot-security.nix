# Exercise the assembled hosts and the explicit hibernation exception policy.
{ lib, configurations }:
let
  desktop = configurations.box-01.config;
  laptop = configurations.box-02.config;
  hosts = map (host: host.config) (lib.attrValues configurations);
  extendDesktop =
    module: (configurations.box-01.extendModules { modules = [ module ]; }).config;
  rejects =
    message: config:
    lib.any (
      item: !item.assertion && lib.hasInfix message item.message
    ) config.assertions;
  withoutOverride = extendDesktop {
    my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
  };
  withoutLockdown = extendDesktop {
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
      let
        nvidia = desktop.hardware.nvidia;
        nvidiaModule = if nvidia.open then nvidia.package.open else nvidia.package.mod;
      in
      lib.all (
        config:
        config.system.build.verifiedKernel.moduleCertificates
        == "${config.system.modulesTree}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/modules.cer"
      ) hosts
      && lib.elem nvidiaModule desktop.boot.extraModulePackages;
    expected = true;
  };
  testLockdownRejectsDisablingModuleVerification = {
    expr =
      rejects "requires my.hardware.secure-boot.verifyKernelModules"
        (extendDesktop {
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
  testDesktopResumeUsesTheEncryptedRootAndSwapDevice = {
    expr =
      desktop.boot.resumeDevice == desktop.fileSystems."/swap".device
      && desktop.boot.resumeDevice == desktop.fileSystems."/".device
      && lib.hasPrefix "/dev/mapper/" desktop.boot.resumeDevice
      && builtins.hasAttr (lib.removePrefix "/dev/mapper/" desktop.boot.resumeDevice) desktop.boot.initrd.luks.devices;
    expected = true;
  };
  testDesktopKeepsHibernationAndResumeParameters = {
    expr =
      desktop.my.hardware.hibernation.enable
      && !desktop.security.protectKernelImage
      && !lib.elem "nohibernate" desktop.boot.kernelParams
      && lib.elem "resume=${desktop.my.hardware.hibernation.resumeDevice}" desktop.boot.kernelParams
      && lib.elem "resume_offset=${toString desktop.my.hardware.hibernation.resumeOffset}" desktop.boot.kernelParams
      && desktop.boot.kernel.sysctl."kernel.kexec_load_disabled" == 1;
    expected = true;
  };
  testDesktopKeepsNvidiaHibernationSupport = {
    expr =
      desktop.hardware.nvidia.powerManagement.enable
      && lib.elem "nvidia.NVreg_PreserveVideoMemoryAllocations=1" desktop.boot.kernelParams;
    expected = true;
  };
  testDesktopExceptionIncludesPatchAndBootOptIn = {
    expr =
      desktop.my.hardware.hibernation.lockdownOverride.active
      && hasPatch desktop
      && lib.elem overrideFlag desktop.boot.kernelParams;
    expected = true;
  };
  testLaptopHasNoHibernationException = {
    expr =
      !laptop.my.hardware.hibernation.enable
      && !laptop.my.hardware.hibernation.lockdownOverride.active
      && !hasPatch laptop
      && !lib.elem overrideFlag laptop.boot.kernelParams;
    expected = true;
  };
  testExceptionIsInactiveWhenHibernationIsDisabled = {
    expr =
      let
        config = extendDesktop { my.hardware.hibernation.enable = lib.mkForce false; };
      in
      !config.my.hardware.hibernation.lockdownOverride.active
      && !hasPatch config
      && !lib.elem overrideFlag config.boot.kernelParams;
    expected = true;
  };
  testActiveStatusIsReadOnly = {
    expr =
      configurations.box-01.options.my.hardware.hibernation.lockdownOverride.active.readOnly;
    expected = true;
  };
  testRemovingThePatchMakesExceptionInactiveAndFailsPolicy = {
    expr =
      let
        config = extendDesktop { boot.kernelPatches = lib.mkForce [ ]; };
      in
      !config.my.hardware.hibernation.lockdownOverride.active
      && rejects "Hibernation under lockdown requires" config;
    expected = true;
  };
  testRemovingTheFlagMakesExceptionInactiveAndFailsPolicy = {
    expr =
      let
        config = extendDesktop {
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
    expr = rejects "Hibernation under lockdown requires" (extendDesktop {
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
    expr = rejects "Hibernation conflicts with the nohibernate" (extendDesktop {
      boot.kernelParams = [ "nohibernate" ];
    });
    expected = true;
  };
  testBootFlagAloneCannotClaimAnException = {
    expr =
      rejects "a boot parameter alone does not patch the kernel"
        (extendDesktop {
          my.hardware.hibernation.lockdownOverride.enable = lib.mkForce false;
          boot.kernelParams = [ overrideFlag ];
        });
    expected = true;
  };
  testExceptionRequiresDeclaredLuksResumeDevice = {
    expr =
      rejects "requires resumeDevice to name a decrypted LUKS mapper"
        (extendDesktop {
          my.hardware.hibernation.resumeDevice = lib.mkForce "/dev/sda2";
        });
    expected = true;
  };
  testChangingKernelSeriesRequiresPatchReview = {
    expr = rejects "reviewed for Linux 7.3.x only" (extendDesktop {
      boot.kernelPackages = lib.mkForce (
        desktop.boot.kernelPackages.extend (
          _: previous: {
            kernel = previous.kernel.override { argsOverride.version = "7.4"; };
          }
        )
      );
    });
    expected = true;
  };
  testRemovedInitrdToggleHasNoDefinitions = {
    expr = lib.all (host: !host.options.boot.initrd.systemd.enable.isDefined) (
      lib.attrValues configurations
    );
    expected = true;
  };
}
