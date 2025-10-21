{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  supportedSystems = [ "x86_64-linux" ];

  listHostNames =
    dir:
    let
      entries =
        if builtins.pathExists dir then
          builtins.readDir dir
        else
          throw "mkHostConfigurations: host directory ${toString dir} does not exist";
      rogueEntries = lib.filterAttrs (_: type: type != "directory") entries;
      hostNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
    in
    assert lib.assertMsg (rogueEntries == { })
      "mkHostConfigurations: non-directory entries found in ${toString dir}: ${builtins.toString (builtins.attrNames rogueEntries)}";
    assert lib.assertMsg (
      hostNames != [ ]
    ) "mkHostConfigurations: no host directories found in ${toString dir}.";
    hostNames;

  /*
    Generate NixOS system configurations for a set of hosts.

    The function automates the creation of `nixosSystem` derivations by
    scanning a directory (`hostDir`). Each subdirectory is treated as a
    host, and its name is used as the default `hostName`.

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
        let
          modulesAreList = lib.assertMsg (lib.isList modules) "mkHostConfigurations: `modules` must be a list of NixOS modules.";
          modulesAreValid =
            lib.assertMsg (lib.all (module: lib.isAttrs module || lib.isFunction module) modules)
              "mkHostConfigurations: each entry in `modules` must be either an attribute set or a module function.";
        in
        assert modulesAreList;
        assert modulesAreValid;
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
          if lib.pathIsRegularFile filePath then
            filePath
          else
            throw "mkHostConfigurations: expected ${fileName} for host '${hostName}' at ${toString filePath}";
        hostMainModule =
          let
            imported = import (requireFile hostPath "configuration.nix");
            moduleValid = lib.isAttrs imported || lib.isFunction imported;
          in
          assert lib.assertMsg moduleValid
            "mkHostConfigurations: configuration.nix for host '${hostName}' must return an attribute set or module function.";
          imported;

        systemCheckModule =
          { config, ... }:
          {
            assertions = [
              {
                assertion = lib.elem config.nixpkgs.hostPlatform.system supportedSystems;
                message = ''
                  Host "${hostName}" has a hostPlatform (${config.nixpkgs.hostPlatform.system})
                  that is not in the global supportedSystems list.
                  Please either add this platform to lib/default.nix
                  or correct the host's hardware configuration.
                '';
              }
            ];
          };
      in
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs hostName; };
        modules = moduleList ++ [
          hostMainModule
          systemCheckModule
        ];
      }
    );
in
{
  inherit mkHostConfigurations;
  inherit supportedSystems;
}
