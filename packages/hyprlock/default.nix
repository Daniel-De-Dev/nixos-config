# Self-contained lock screen. No mutable dotfiles or desktop screenshots.
{
  lib,
  pkgs,
  wrapper-manager,
  theme,
  wallpaper,
  blurSize ? 8,
  blurPasses ? 3,
  batteryId ? null,
  fingerprint ? false,
}:
let
  batteryStatus = pkgs.writeShellApplication {
    name = "hyprlock-battery";
    text = ''
      battery_id=${lib.escapeShellArg (if batteryId == null then "" else batteryId)}
      low_color=${lib.escapeShellArg theme.colors.danger}
    ''
    + builtins.readFile ./battery.sh;
  };
  configText = import ./config.nix {
    inherit
      lib
      theme
      wallpaper
      blurSize
      blurPasses
      fingerprint
      ;
    dateCommand = "${pkgs.coreutils}/bin/date '+%A, %d %B %Y'";
    batteryCommand = lib.getExe batteryStatus;
  };
  configFile = pkgs.writeText "hyprlock.conf" configText;
  wrapped = wrapper-manager.lib {
    inherit pkgs;
    modules = [
      {
        wrappers.hyprlock = {
          basePackage = pkgs.hyprlock;
          programs.hyprlock = {
            prependFlags = [
              "--config"
              configFile
              "--grace"
              "0"
            ];
            env.FONTCONFIG_FILE.value = pkgs.makeFontsConf {
              fontDirectories = theme.fonts.packages;
            };
          };
        };
      }
    ];
  };
in
wrapped.config.wrappers.hyprlock.wrapped.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit configFile configText batteryStatus;
  };
})
