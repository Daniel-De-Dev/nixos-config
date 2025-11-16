{ ... }:
{
  # Enable the sudo-rs implementation
  security = {
    sudo.enable = false; # Disable classic sudo
    sudo-rs = {
      enable = true;
      execWheelOnly = true;
      wheelNeedsPassword = true;

      extraConfig = ''
        Defaults        timestamp_timeout=5
        Defaults        passwd_timeout=1
        Defaults        passwd_tries=3
        Defaults        secure_path="/run/wrappers/bin:/run/current-system/sw/bin"
      '';

      defaultOptions = [ ];
    };
  };
}
