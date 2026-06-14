# =============================================================================
# Manages system-wide networking configuration, local machine identity, and
# kernel-level packet routing optimizations.
#
# DESIGN CONSTRAINTS:
# 1. Enforces strict DNS-over-TLS and DNSSEC using zero-logging,
#    privacy-respecting European providers.
# 2. Active mitigation against IP spoofing, routing table manipulation, and
#    ICMP-based denial of service.
# =============================================================================
_: {
  flake.nixosModules.core-network =
    { lib, config, ... }:
    let
      pMacRandomize = config.my.host.network.macRandomize;
    in
    {
      # Machine Identity
      networking.hostName = config.my.host.name;
      networking.hostId = config.my.host.id;

      # Base Networking Service & Privacy
      networking.networkmanager = {
        enable = true;
        wifi = {
          backend = "iwd";

          macAddress = lib.mkIf pMacRandomize "random";
          scanRandMacAddress = lib.mkIf pMacRandomize true;
        };
      };

      # Explicit Firewall Baseline
      networking.firewall = {
        enable = true;
        allowPing = false;
        logReversePathDrops = true;
        logRefusedConnections = false;
      };

      # DNS Resolution & Security
      networking.nameservers = [
        "9.9.9.9" # Quad9
        "194.242.2.4" # Mullvad
      ];

      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNSOverTLS = true;
          DNSSEC = true;
          LLMNR = false;
          MulticastDNS = false;
          Domains = [ "~." ];
          FallbackDNS = [
            "9.9.9.9" # Quad9
            "194.242.2.4" # Mullvad
          ];
        };
      };

      # Kernel Network Tuning & Security Hardening
      boot.kernelModules = [ "tcp_bbr" ];

      boot.kernel.sysctl = {
        # --- Performance (BBR & CAKE) ---
        "net.core.default_qdisc" = "cake";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.tcp_slow_start_after_idle" = 0;
        "net.ipv4.tcp_mtu_probing" = 1;
        "net.ipv4.tcp_fastopen" = 3;
        "net.ipv4.tcp_keepalive_time" = 300;
        "net.ipv4.tcp_keepalive_intvl" = 75;
        "net.ipv4.tcp_keepalive_probes" = 9;
        "net.ipv4.tcp_notsent_lowat" = 128 * 1024;
        "net.core.netdev_max_backlog" = 250000;
        "net.ipv4.tcp_rmem" = "4096 87380 ${toString (32 * 1024 * 1024)}";
        "net.ipv4.tcp_wmem" = "4096 87380 ${toString (32 * 1024 * 1024)}";
        "net.core.rmem_default" = 1024 * 1024;
        "net.core.wmem_default" = 1024 * 1024;
        "net.core.rmem_max" = 32 * 1024 * 1024;
        "net.core.wmem_max" = 32 * 1024 * 1024;
        "net.core.optmem_max" = 64 * 1024;
        "net.ipv4.tcp_synack_retries" = 5;
        "net.ipv4.ip_local_port_range" = "1024 65535";
        "net.ipv4.tcp_base_mss" = 1024;

        # --- IPv6 Privacy ---
        "net.ipv6.conf.all.accept_ra" = 2;
        "net.ipv6.conf.all.use_tempaddr" = 2;

        # --- Security Hardening ---
        # Strict reverse path filtering
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;

        # Protect against SYN flood attacks
        "net.ipv4.tcp_syncookies" = 1;

        # Ignore broadcast ICMP
        "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

        # Ignore malicious ICMP error messages
        "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

        # Disable ICMP redirect acceptance
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.secure_redirects" = 0;
        "net.ipv4.conf.default.secure_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;

        # Do not send ICMP redirects
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;

        # Log martian packets
        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.default.log_martians" = 1;
      };
    };
}
