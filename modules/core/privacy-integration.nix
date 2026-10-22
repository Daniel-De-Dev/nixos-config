# Supply identity defaults from an optional external data directory.
{ self, ... }: {
  flake.nixosModules.core-privacy =
    args@{ lib, inputs, ... }:
    let
      machine = args.machine or null;
      privacyPath = inputs.privacy or null;
      dataFile = if privacyPath != null then "${privacyPath}/data.nix" else null;
      data =
        if dataFile == null then
          { }
        else if builtins.pathExists dataFile then
          import dataFile
        else
          throw "privacy input: expected data.nix in the supplied directory";

      mapPrivacy = import ../../lib/privacy.nix { inherit lib; };
    in
    {
      imports = [ self.nixosModules.core-identity ];

      config.my = mapPrivacy { inherit data machine; };
    };
}
