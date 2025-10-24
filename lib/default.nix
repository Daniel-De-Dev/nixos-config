{ inputs }:
let
  inherit (inputs.nixpkgs) lib;

  errPrefix = "mkHostConfigurations: ";
  hcAssert = cond: msg: lib.assertMsg cond "${errPrefix}${msg}";
  hcThrow = msg: throw "${errPrefix}${msg}";

  listHostNames =
    dir:
    let
      entries =
        if builtins.pathExists dir then
          builtins.readDir dir
        else
          hcThrow "host directory ${toString dir} does not exist";
      hostNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") entries);
    in
    assert hcAssert (hostNames != [ ]) "no host directories found in ${toString dir}.";
    hostNames;

  /*
    Generate NixOS system configurations for a set of hosts.

    The function automates the creation of `nixosSystem` derivations by
    scanning a directory (`hostDir`). Each subdirectory is treated as a
    host, and its name is used as the default `hostName`.

    @inputs: An attribute set with the following keys:
      - supportedSystems: list of explicetly supported systems which can be built
      - hostDir: The path to the directory containing host subdirectories.
      - modules: A list of modules to be included in every host.

    @returns: An attribute set where each key is a hostname and each
              value is a NixOS system configuration.
  */
  mkHostConfigurations =
    {
      supportedSystems,
      hostDir ? ../hosts,
      modules ? [ ],
    }:
    let

      # Ensure only real systems are explicitly specified
      knownSystems = lib.systems.flakeExposed;
      invalidSystems = lib.filter (system: !(lib.elem system knownSystems)) supportedSystems;
      systemsAreValid =
        hcAssert (invalidSystems == [ ])
          "The following systems in `supportedSystems` are not valid: ${builtins.toString invalidSystems}. See `lib.systems.flakeExposed` for a list of valid systems.";

      # Ensure `modules` is a list of valid modules
      moduleList =
        let
          modulesAreList = hcAssert (lib.isList modules) "`modules` must be a list of NixOS modules.";
          modulesAreValid = hcAssert (lib.all (
            module: lib.isAttrs module || lib.isFunction module
          ) modules) "each entry in `modules` must be either an attribute set or a module function.";
        in
        assert systemsAreValid;
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
            hcThrow "expected ${fileName} for host '${hostName}' at ${toString filePath}";
        hostMainModule =
          let
            imported = import (requireFile hostPath "configuration.nix");
            moduleValid = lib.isAttrs imported || lib.isFunction imported;
          in
          assert hcAssert moduleValid
            "configuration.nix for host '${hostName}' must return an attribute set or module function.";
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
}
