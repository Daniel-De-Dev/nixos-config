{ pkgs, ... }:
{
  imports = [
    ../my
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = [ pkgs.nixfmt-rfc-style ];
}
