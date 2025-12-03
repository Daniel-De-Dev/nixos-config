{ inputs, supportedSystems }:
let
  pkgsFor = system: inputs.nixpkgs.legacyPackages.${system};
  lib = inputs.nixpkgs.lib;

  forEachSystem = lib.genAttrs supportedSystems;
in
{
  devShells = forEachSystem (
    system:
    let
      pkgs = pkgsFor system;
    in
    {
      default = pkgs.mkShell {
        packages = [
        ];
      };
    }
  );
}
