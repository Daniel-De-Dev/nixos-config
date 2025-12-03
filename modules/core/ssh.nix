{
  services.openssh = {
    enable = true;

    openFirewall = false;

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];

    settings = {
      PermitRootLogin = "no";

      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;

      AuthenticationMethods = "publickey";

      KexAlgorithms = [
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group18-sha512"
        "diffie-hellman-group16-sha512"
      ];

      AllowAgentForwarding = "no";
      AllowTcpForwarding = "no";
      AllowStreamLocalForwarding = "no";
      PermitTunnel = "no";

      MaxStartups = "10:30:60";
      MaxSessions = 3;
      MaxAuthTries = 3;
      LoginGraceTime = "20s";

      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      LogLevel = "VERBOSE";
    };
  };
}
