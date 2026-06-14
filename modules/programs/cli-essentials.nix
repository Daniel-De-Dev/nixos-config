# =============================================================================
# Bundles most foundational command-line tools and modern coreutil replacements.
# =============================================================================
_: {
  flake.nixosModules.programs-cli-essentials = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      # Network
      wget
      curl

      # Modern Coreutils
      ripgrep # Fast grep
      fd # Fast find
      eza # Modern ls/tree
      bat # Modern cat
      zoxide # Smart cd
      dust # Visual disk usage

      # Workflow & System
      fzf # Fuzzy finder
      btop # System monitor
      jq # JSON processor
      neovim # Terminal editor
    ];
  };
}
