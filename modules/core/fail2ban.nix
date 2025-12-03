{
  services.fail2ban = {
    enable = true;

    bantime = "1h";

    bantime-increment = {
      enable = true;
      factor = "2";
      maxtime = "168h";
    };

    jails = {
      sshd = {
        settings = {
          mode = "aggressive";
        };
      };
    };
  };
}
