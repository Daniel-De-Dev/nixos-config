# =============================================================================
# Governs baseline cryptography, access control, and network defense.
#
# DESIGN CONSTRAINTS:
# 1. Ensure minimal overlap with existing moduels
# =============================================================================
{ ... }:
{
  flake.nixosModules.core-security =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      hostUsbGuard = config.my.host.security.usbguard;
      hostStrictKernel = config.my.host.security.strictKernel;
    in
    {

      # =======================================================================
      # KERNEL & HARDWARE HARDENING
      # =======================================================================
      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      boot.loader.systemd-boot.editor = false;

      security = {
        protectKernelImage = lib.mkDefault true;
        lockKernelModules = false;
      };

      boot.kernelParams = lib.mkIf hostStrictKernel [
        "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
        "lockdown=integrity"

        # Memory Safety & Allocator Hardening
        "slab_nomerge"
        "init_on_alloc=1"
        "init_on_free=1"
        "page_poison=1"
        "page_alloc.shuffle=1"
        "pti=on"
        "randomize_kstack_offset=on"
        "vsyscall=none"
        "debugfs=off"
        "oops=panic"

        # IOMMU & DMA
        "iommu=force"
        "intel_iommu=on"
        "amd_iommu=force_isolation"
      ];

      security.apparmor = {
        enable = true;
        killUnconfinedConfinables = true;
        packages = [ pkgs.apparmor-profiles ];
      };

      boot.blacklistedKernelModules = [
        "dccp"
        "sctp"
        "rds"
        "tipc"
        "ax25"
        "netrom"
        "rose" # Obscure protocols
        "jffs2"
        "hfs"
        "hfsplus"
        "squashfs"
        "udf"
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
        "ufs" # Old filesystems
        "firewire-core"
        "thunderbolt" # DMA attack vectors
      ];

      services.usbguard = lib.mkIf hostUsbGuard {
        enable = true;
        dbus.enable = true;
        implicitPolicyTarget = "block";
        presentDevicePolicy = "allow";
      };

      systemd.coredump.enable = false;

      # =======================================================================
      # SYSCTL & KERNEL MITIGATIONS
      # =======================================================================
      boot.kernel.sysctl = {
        "kernel.kexec_load_disabled" = 1;
        "kernel.perf_event_paranoid" = 3;
        "kernel.unprivileged_userfaultfd" = 0;
        "kernel.yama.ptrace_scope" = 1;
        "kernel.sysrq" = 0;
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = 1;
        "kernel.randomize_va_space" = 2;
        "vm.mmap_min_addr" = 64 * 1024;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;
        "fs.protected_symlinks" = 1;
        "fs.protected_hardlinks" = 1;
        "fs.suid_dumpable" = 0;

        # Network Spoofing & TCP Hardening
        "net.ipv4.tcp_rfc1337" = 1;
        "net.ipv4.ip_forward" = 0;
        "net.ipv6.conf.all.forwarding" = 0;
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;
      };

      # =======================================================================
      # IDENTITY & PRIVILEGE ESCALATION
      # =======================================================================
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = false;
        pinentryPackage = pkgs.pinentry-curses;
        settings = {
          default-cache-ttl = 600;
          max-cache-ttl = 7200;
          allow-loopback-pinentry = "";
        };
      };

      security.sudo.enable = false;
      security.sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = true;
        extraConfig = ''
          Defaults        timestamp_timeout=5
          Defaults        passwd_timeout=1
          Defaults        passwd_tries=3
        '';
      };

      security.polkit.enable = true;
      environment.etc."securetty".text = "";

      # =======================================================================
      # NETWORK DEFENSE
      # =======================================================================
      networking.nftables.enable = true;

      networking.firewall = {
        enable = true;
        checkReversePath = "strict";
        allowPing = false;
        pingLimit = "10/minute burst 5 packets";
        logRefusedConnections = lib.mkDefault true;
        logReversePathDrops = true;
      };

      services.fail2ban = {
        enable = true;
        banaction = "nftables-multiport";
        maxretry = 3;
        bantime = "1h";
        bantime-increment = {
          enable = true;
          factor = "4";
          maxtime = "168h";
        };
        jails.sshd.settings = {
          mode = "aggressive";
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=sshd.service + _COMM=sshd";
        };
      };
    };
}
