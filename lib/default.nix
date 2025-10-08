{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  listHostNames =
    dir: builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

  mkHostConfigurations =
    {
      hostDir ? ../hosts,
      modules ? [ ],
    }:
    lib.genAttrs (listHostNames hostDir) (
      hostName:
      let
        hostMetaModule = import (hostDir + "/${hostName}" + "/meta.nix");
        hostMainModule = import (hostDir + "/${hostName}" + "/configuration.nix");
      in
      inputs.nixpkgs.lib.nixosSystem {
        system = (hostMetaModule { }).my.host.system;
        specialArgs = { inherit inputs hostName; };
        modules = modules ++ [
          hostMetaModule
          hostMainModule
        ];
      }
    );
in
{
  inherit mkHostConfigurations;
}
