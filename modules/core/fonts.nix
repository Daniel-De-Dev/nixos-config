# Purpose: Provisions system-wide typography, icon fonts, and rendering fallbacks.
# Scope: Host-agnostic global font configuration.
# Invariants:
# - Hardware independent.
_: {
  flake.nixosModules.core-fonts =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.core.fonts;
    in
    {
      options.my.core.fonts.enable =
        lib.mkEnableOption "Set preferred system fonts and typography";

      config = lib.mkIf cfg.enable {
        fonts = {
          enableDefaultPackages = true;
          fontDir.enable = true;
          packages = with pkgs; [
            nerd-fonts.jetbrains-mono
            font-awesome
            fira-sans
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];
          fontconfig = {
            enable = true;
            antialias = true;
            hinting = {
              enable = true;
              style = "slight";
            };
            subpixel = {
              rgba = "rgb";
              lcdfilter = "default";
            };
            defaultFonts = {
              monospace = [ "JetBrainsMono Nerd Font" ];
              sansSerif = [
                "Noto Sans"
                "JetBrainsMono Nerd Font"
              ];
              serif = [
                "Noto Serif"
                "JetBrainsMono Nerd Font"
              ];
              emoji = [ "Noto Color Emoji" ];
            };
          };
        };
      };
    };
}
