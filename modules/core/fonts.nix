# =============================================================================
# Provisions system-wide typography, icon fonts, and rendering fallbacks.
# =============================================================================
_: {
  flake.nixosModules.core-fonts = { pkgs, ... }: {
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

        # Enforce crisp rendering
        antialias = true;
        hinting = {
          enable = true;
          style = "slight";
        };
        subpixel = {
          rgba = "rgb";
          lcdfilter = "default";
        };

        # Explicitly map the installed packages to the system categories
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
}
