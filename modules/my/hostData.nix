{ lib, ... }:
{
  options.my.hostData = {
    users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          imports = [ ./hostData-user-schema.nix ];
        }
      );

      default = {
        main = {
        };
      };
      description = "An attribute set of private user definitions for host.";
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
