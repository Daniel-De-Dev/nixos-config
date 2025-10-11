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
      rogueEntries = lib.filterAttrs (_: type: type != "directory") entries;
    in
    assert lib.assertMsg (rogueEntries == { })
      "mkHostConfigurations: non-directory entries found in ${toString dir}: ${builtins.toString (builtins.attrNames rogueEntries)}";
    builtins.attrNames (lib.filterAttrs (_: type: type == "directory") entries);

  /*
    Generate NixOS system configurations for a set of hosts.

    The function automates the creation of `nixosSystem` derivations by
    scanning a directory (`hostDir`). Each subdirectory is treated as a
    host, and its name is used as the default `hostName`.

    It also enforces a strict directory structure to ensure consistency.

    @inputs: An attribute set with the following keys:
      - hostDir: The path to the directory containing host subdirectories.
      - modules: A list of modules to be included in every host.

    @returns: An attribute set where each key is a hostname and each
              value is a NixOS system configuration.
  */
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

        allowedFiles = [
          "meta.nix"
          "configuration.nix"
          "hardware-configuration.nix"
        ];
        actualEntries = builtins.readDir hostPath;

        rogueEntries = lib.filterAttrs (
          name: type: !(lib.elem name allowedFiles) || type != "regular"
        ) actualEntries;

        requireFile =
          hPath: fileName:
          let
            filePath = hPath + "/${fileName}";
          in
          if lib.pathIsRegularFile filePath then
            filePath
          else
            throw "mkHostConfigurations: expected ${fileName} for host '${hostName}' at ${toString filePath}";
        hostMetaModule = import (requireFile hostPath "meta.nix");
        hostMainModule = import (requireFile hostPath "configuration.nix");
      in
      assert lib.assertMsg (rogueEntries == { })
        "mkHostConfigurations: host '${hostName}' contains non-whitelisted files or subdirectories: ${builtins.toString (builtins.attrNames rogueEntries)}";
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
