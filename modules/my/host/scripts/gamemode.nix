{
  config,
  lib,
  pkgs,
  ...
}:
let
  toggle-script = pkgs.writeShellScriptBin "toggle-game-security" (
    builtins.readFile ./toggle-game-security.sh
  );
in
{
  # only apply if Steam is enabled on the host
  config = lib.mkIf config.programs.steam.enable {
    environment.systemPackages = [ toggle-script ];
  };
}
