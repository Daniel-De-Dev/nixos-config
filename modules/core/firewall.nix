{
  networking = {
    firewall = {
      enable = true;
      checkReversePath = "strict";
      logRefusedConnections = true;
      logReversePathDrops = true;
      pingLimit = "1/minute burst 5 packets";

      # Explicit baseline rules applied before the default drop policy. We keep
      # loopback and established/related traffic fast-pathed, drop invalid
      # packets early, and only allow minimal ICMP required for path MTU
      # discovery and diagnostics. Service-specific openings should be defined
      # in host modules via allowedTCPPorts/allowedUDPPorts to keep the base
      # policy lean.
      extraInputRules = ''
        iifname "lo" accept

        ct state invalid drop
        ct state { established, related } accept

        # ICMPv4: permit core types (echo, destination unreachable, time
        # exceeded, parameter problem) with a modest rate-limit for logging
        # hygiene.
        ip protocol icmp icmp type {
          echo-request,
          echo-reply,
          destination-unreachable,
          time-exceeded,
          parameter-problem
        } limit rate 10/second accept

        # ICMPv6: permit discovery/error handling traffic plus echo for
        # diagnostics with the same rate-limit.
        ip6 nexthdr icmpv6 icmpv6 type {
          echo-request,
          echo-reply,
          destination-unreachable,
          packet-too-big,
          time-exceeded,
          parameter-problem,
          nd-router-solicit,
          nd-router-advert,
          nd-neighbor-solicit,
          nd-neighbor-advert
        } limit rate 10/second accept
      '';

      extraForwardRules = ''
        ct state invalid drop
        ct state { established, related } accept
      '';
    };

    nftables.enable = true;
  };

  boot.kernel.sysctl = {
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
  };
}
