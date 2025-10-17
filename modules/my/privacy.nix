{
  lib,
  config,
  inputs,
  hostName,
  ...
}:
{
  options.my.privacy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to load private data for this host from the privacy input.";
    };

    data = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      description = "The private data loaded from the privacy flake input for this host.";
    };
  };

  config = lib.mkIf config.my.privacy.enable {
    my.privacy.data =
      let
        privacyRoot =
          if inputs ? privacy then
            inputs.privacy
          else
            builtins.throw ''
              my.privacy.enable is true, but the 'privacy' flake input is not defined.
              Please add the 'privacy' input to your flake.nix or set my.privacy.enable = false for host "${hostName}".
            '';

        hostPrivacyFile = privacyRoot + "/hosts/${hostName}.nix";

        rawPrivacy =
          if builtins.pathExists hostPrivacyFile then
            let
              imported = import hostPrivacyFile;
            in
            if builtins.isFunction imported then imported { inherit hostName; } else imported
          else
            builtins.throw ''
              my.privacy.enable is true, but the privacy file was not found for host "${hostName}".
              Nix looked for the file at the following path:
              ${hostPrivacyFile}
            '';
      in
      if builtins.isAttrs rawPrivacy then
        rawPrivacy
      else
        builtins.throw ''
          The privacy file for host "${hostName}" did not return an attribute set.
          Please ensure the file content is in the format `{ key = "value"; }`.
        '';
  };
}
