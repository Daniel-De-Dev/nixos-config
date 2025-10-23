{ inputs, ... }:
{
  imports = [
    inputs.nvim-config.homeManagerModules.default
  ];

  home.stateVersion = "25.05";
}
