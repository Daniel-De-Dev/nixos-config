{
  pkgs,
  config,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_hardened;
  # TODO: The recompile takes way to long, run it later
  # Add option to enable this
  # boot.kernelPatches = [{
  #     name = "kernel-lockdown";
  #     patch = null;
  #     extraConfig = ''
  #      SECURITY_LOCKDOWN_LSM y
  #      MODULE_SIG y
  #     '';
  # }];

  # Prevents root from swapping the kernel to a compromised one.
  # (enabling it makes hibernation disabled)
  security.protectKernelImage = !config.my.host.hibernation.enable;

  # TODO: Make this togglable, for desktops & laptops this is impractical
  # The 'hardened' profile normally sets this to true, which prevents ANY new
  # module loading after boot. This breaks USB wifi, some peripherals, and
  # virtualization if not pre-loaded.
  # security.lockKernelModules = true;

  # -------------------------------------------------------------------------
  # 2. Kernel Parameters (Boot Flags)
  # -------------------------------------------------------------------------
  boot.kernelParams = [
    # --- Memory Safety & Allocator Hardening ---
    "slab_nomerge" # Isolate kernel structures to prevent heap spraying
    "init_on_alloc=1" # Zero-init memory to prevent use-after-free info leaks
    "init_on_free=1" # Zero-fill freed memory
    "page_poison=1" # Overwrite free'd pages
    "page_alloc.shuffle=1" # Randomize page allocator freelists
    "pti=on" # Force Page Table Isolation (Meltdown mitigation)
    "randomize_kstack_offset=on" # Randomize kernel stack offset on syscalls
    "vsyscall=none" # Disable legacy vsyscall (ASLR bypass vector)
    "debugfs=off" # Reduce attack surface (unless you are debugging kernel)
    "oops=panic" # Panic on kernel oops to prevent exploit continuation

    # --- IOMMU & DMA ---
    # Force IOMMU for all devices to prevent DMA attacks
    "iommu=force"
    "intel_iommu=on"
    "amd_iommu=force_isolation"

    "module.sig_enforce=1"

    # Prevents root from modifying kernel code/data.
    # NOTE: Doesnt seems to work or be recognized by the kernel.
    # Might actually need the recompiling of the kernel
    # havent tested, but make addition togglable together with the patch
    # further, probably breaks hibernation too
    #"lockdown=confidentiality"
  ];

  # -------------------------------------------------------------------------
  # 3. Sysctl Hardening
  # -------------------------------------------------------------------------
  boot.kernel.sysctl = {
    # Restrict debug and tracing capabilities to privileged users
    "kernel.kexec_load_disabled" = 1;
    "kernel.perf_event_paranoid" = 3;
    "kernel.unprivileged_userfaultfd" = 0;

    # Restrict ptrace() scope to parent processes only (prevents process injection)
    "kernel.yama.ptrace_scope" = 1;

    # Hide kernel pointers from unprivileged users
    "kernel.kptr_restrict" = 2;

    # Restrict access to kernel logs (dmesg)
    "kernel.dmesg_restrict" = 1;

    # Harden BPF JIT and memory layout randomization
    "net.core.bpf_jit_harden" = 2;
    "kernel.randomize_va_space" = 2;
    "vm.mmap_min_addr" = 65536;
    "vm.mmap_rnd_bits" = 32;

    # Disable BPF JIT for unprivileged users (reduces attack surface)
    "kernel.unprivileged_bpf_disabled" = 1;

    # Prevent unprivileged users from creating hard/symlinks to files they don't own
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;

    # Disable SysRq to avoid unexpected privileged actions
    "kernel.sysrq" = 0;

    # Disable core dumps (can contain sensitive info like keys)
    "fs.suid_dumpable" = 0;

    # Unprivileged User Namespaces
    # The hardened kernel disables this by default.
    # We MUST enable it for modern desktop apps (Chrome, Discord, Flatpak) to work.
    "kernel.unprivileged_userns_clone" = 1;
  };

  # -------------------------------------------------------------------------
  # 4. Attack Surface Reduction
  # -------------------------------------------------------------------------

  # Enable AppArmor (Mandatory Access Control)
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true; # Kill processes that *should* be confined but aren't
    packages = [ pkgs.apparmor-profiles ];
  };

  # Blacklist rare/insecure protocols to reduce kernel attack surface
  boot.blacklistedKernelModules = [
    # Obscure protocols often used in exploits
    "dccp"
    "sctp"
    "rds"
    "tipc"
    # Old/Insecure filesystems
    "jffs2"
    "hfs"
    "hfsplus"
    "squashfs"
    "udf"
    # Hardware/Legacy (disable if you actually use Firewire/Thunderbolt)
    "firewire-core"
    "thunderbolt"
    # Obscure network protocols
    "ax25"
    "netrom"
    "rose"
    # Old or rare or insufficiently audited filesystems
    "adfs"
    "affs"
    "bfs"
    "befs"
    "cramfs"
    "efs"
    "erofs"
    "exofs"
    "freevxfs"
    "f2fs"
    "hpfs"
    "jfs"
    "minix"
    "nilfs2"
    "ntfs"
    "omfs"
    "qnx4"
    "qnx6"
    "sysv"
    "ufs"
  ];

  # -------------------------------------------------------------------------
  # 5. Entropy & Randomness
  # -------------------------------------------------------------------------
  # Ensure the system has plenty of entropy during boot (critical for crypto)
  services.jitterentropy-rngd.enable = true;
  boot.kernelModules = [ "jitterentropy_rng" ];

  # -------------------------------------------------------------------------
  # 7. Bootloader Hardening
  # -------------------------------------------------------------------------
  # Prevent editing the kernel command line at boot (prevents 'init=/bin/sh' attacks).
  # NOTE: This means if you break your boot, you need a live USB to fix it.
  boot.loader.systemd-boot.editor = false;

  # -------------------------------------------------------------------------
  # 9. Authentication Hardening
  # -------------------------------------------------------------------------
  # Increase hashing rounds for passwords (slows down brute-force attacks)
  security.pam.services.passwd.rules.password.unix.settings.rounds = 65536;

  # Prevent root login on TTYs (physical terminals)
  environment.etc."securetty".text = "";

  services.usbguard = {
    enable = true;
    dbus.enable = true; # Allows GUI tools to interact with it
    implicitPolicyTarget = "block";
    presentDevicePolicy = "allow";
  };
}
