# =============================================================================
# Configures the raw TTY console (pre-graphical environment).
#
# DESIGN CONSTRAINTS:
# 1. Aesthetics (colors, fonts) are hardcoded
# 2. Physical layout (keymap) is inherited from the XKB configuration,
#    which is governed by the Host API.
# =============================================================================
_: {
  flake.nixosModules.core-console = { config, pkgs, ... }: {
    console = {
      enable = true;
      earlySetup = true;
      useXkbConfig = true;
      font = "ter-v20n";
      packages = [ pkgs.terminus_font ];
      colors = [
        "1D1D1D"
        "AA0000"
        "00AA00"
        "AA5500"
        "0000AA"
        "AA00AA"
        "00AAAA"
        "C0C0C0"
        "555555"
        "FF5555"
        "55FF55"
        "FFFF55"
        "5555FF"
        "FF55FF"
        "55FFFF"
        "FFFFFF"
      ];
    };
  };
}
