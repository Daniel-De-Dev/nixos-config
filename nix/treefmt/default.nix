{ inputs, myLib, ... }:
let
  inherit (inputs) self nixpkgs treefmt-nix;
  lib = nixpkgs.lib;
  forEachSystem = lib.genAttrs myLib.supportedSystems;
  treefmtModule = ./config.nix;
  evalFor =
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    treefmt-nix.lib.evalModule pkgs treefmtModule;
  mkOutputs =
    system:
    let
      eval = evalFor system;
    in
    {
      formatter = eval.config.build.wrapper;
      check = eval.config.build.check self;
    };
  outputsBySystem = forEachSystem mkOutputs;
in
{
  formatter = forEachSystem (system: (outputsBySystem.${system}).formatter);
  checks = forEachSystem (system: {
    formatting = (outputsBySystem.${system}).check;
  });
}
