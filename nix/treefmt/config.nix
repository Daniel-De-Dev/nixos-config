{ ... }:
{
  projectRootFile = "flake.nix";

  settings.global.excludes = [
  ];

  # Nix
  programs.nixfmt = {
    enable = true;
    includes = [
      "*.nix"
    ];
  };

  # Markdown
  programs.mdformat = {
    enable = true;
    includes = [ "*.md" ];

    settings = {
      wrap = 80;
    };
  };

  # Shell / Bash
  programs.shfmt = {
    enable = true;
    indent_size = 2;
  };
}
