{ lib, ... }:
{
  options = {

    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          imports = [ ./privacy-schema-user.nix ];
        }
      );
      default = { };
      description = "An attribute set of private user definitions for this host.";
      example = lib.literalExpression ''
        {
          # "admin" is the arbitrary logical key
          admin = {
            # ...
          };
          # "desktop" is another arbitrary key
          desktop = {
            # ...
          };
        }
      '';
    };

    console = {
      keyMap = lib.mkOption {
        type = lib.types.str;
        default = "us";
        description = "The keymap for the TTY console.";
      };
    };
  };
}
