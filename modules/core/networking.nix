{
  boot.kernel.sysctl = {
    # --- Performance (BBR & FQ) ---
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # --- TCP Optimization ---
    # Low latency mode for TCP
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    # Enable MTU probing
    "net.ipv4.tcp_mtu_probing" = 1;
    # TCP Fast Open (speeds up repeated connections)
    "net.ipv4.tcp_fastopen" = 3;

    # --- Keepalive Optimization ---
    # default is 7200 (2 hours), this drops dead connections faster (5 mins)
    "net.ipv4.tcp_keepalive_time" = 300;
    "net.ipv4.tcp_keepalive_intvl" = 75;
    "net.ipv4.tcp_keepalive_probes" = 9;

    # Buffer latency control
    "net.ipv4.tcp_notsent_lowat" = 131072;

    # --- Network Buffer Sizing ---
    # Increase max backlog for high packet rates
    "net.core.netdev_max_backlog" = 250000;
    # Buffer limits (Start, Default, Max)
    "net.ipv4.tcp_rmem" = "4096 87380 33554432";
    "net.ipv4.tcp_wmem" = "4096 87380 33554432";
    "net.core.rmem_default" = 1048576;
    "net.core.wmem_default" = 1048576;
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.core.optmem_max" = 65536;

    # --- Port & Sync ---
    "net.ipv4.tcp_synack_retries" = 5;
    "net.ipv4.ip_local_port_range" = "1024 65535";
    "net.ipv4.tcp_base_mss" = 1024;

    # --- IPv6 behaviour ---
    # Accept router advertisements even if forwarding is disabled so hosts can
    # autoconfigure correctly on managed networks.
    "net.ipv6.conf.all.accept_ra" = 2;
    # Prefer temporary IPv6 addresses (RFC 4941) for privacy
    "net.ipv6.conf.all.use_tempaddr" = 2;
  };

  networking = {
    nameservers = [
      "1.1.1.1"
      "9.9.9.9"
    ];
  };

  # Enable local DNS caching
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [
      "1.1.1.1"
      "9.9.9.9"
    ];
    dnsovertls = "true";
  };

  networking.networkmanager.wifi = {
    macAddress = "random";
    scanRandMacAddress = true;
  };
}
