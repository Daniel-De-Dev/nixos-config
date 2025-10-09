{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  listHostNames =
    dir:
    let
      entries =
        if builtins.pathExists dir then
          builtins.readDir dir
        else
          throw "mkHostConfigurations: host directory ${toString dir} does not exist";
    in
    builtins.attrNames (lib.filterAttrs (_: type: type == "directory") entries);

  mkHostConfigurations =
    {
      hostDir ? ../hosts,
      modules ? [ ],
    }:
    let
      moduleList =
        assert lib.assertMsg (lib.isList modules)
          "mkHostConfigurations: `modules` must be a list of NixOS modules.";
        modules;
    in
    lib.genAttrs (listHostNames hostDir) (
      hostName:
      let
        hostPath = hostDir + "/${hostName}";

        requireFile =
          hPath: fileName:
          let
            filePath = hPath + "/${fileName}";
          in
          if builtins.pathExists filePath then
            filePath
          else
            throw "mkHostConfigurations: expected ${fileName} for host '${hostName}' at ${toString filePath}";
        hostMetaModule = import (requireFile hostPath "meta.nix");
        hostMainModule = import (requireFile hostPath "configuration.nix");
      in
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs hostName; };
        modules = moduleList ++ [
          hostMetaModule
          hostMainModule
        ];
      }
    );
in
{
  inherit mkHostConfigurations;
}
