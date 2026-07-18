_: {
  flake.nixosModules.programs-cli-essentials =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      options.my.programs.cli-essentials.enable = lib.mkEnableOption "CLI essentials";

      config = lib.mkIf config.my.programs.cli-essentials.enable {
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
        ];
      };
    };
}
