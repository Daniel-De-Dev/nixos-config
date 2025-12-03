{
  networking = {
    firewall = {
      enable = true;

      checkReversePath = "strict";

      logRefusedConnections = true;
      logReversePathDrops = true;

      pingLimit = "1/minute burst 5 packets";
    };

    enableIPv6 = true;
    nftables.enable = true;
  };

  boot.kernel.sysctl = {
    # --- Protection ---
    # Protect against SYN flood attacks
    "net.ipv4.tcp_syncookies" = 1;
    # Protect against TIME-WAIT assassination
    "net.ipv4.tcp_rfc1337" = 1;

    # Hosts should not forward packets (unless they are routers)
    "net.ipv4.ip_forward" = 0;
    "net.ipv6.conf.all.forwarding" = 0;

    # Do not send redirects
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Ignore ICMP broadcasts (Smurf attack protection)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Ignore redirects (Man-in-the-Middle protection)
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Disable source routing
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # Log 'martian' packets (impossible addresses)
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # Strict Reverse Path Filter
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # --- IPv6 ---
    "net.ipv6.conf.all.accept_ra" = 2;

    # Prefer temporary IPv6 addresses (RFC 4941) for privacy
    "net.ipv6.conf.all.use_tempaddr" = 2;

    # --- Performance ---
    # Use BBR congestion control for better throughput/latency
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
