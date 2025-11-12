{ pkgs, ... }:
{
  # Configure GnuPG
  programs.gnupg.agent = {
    enable = true;

    pinentryPackage = pkgs.pinentry-curses;

    settings = {
      default-cache-ttl = 600;
      max-cache-ttl = 7200;
      allow-loopback-pinentry = "";
    };
  };
}
