{ lib, config, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "The actual user name";
      default = config._module.args.name;
    };

    git = {
      user.name = lib.mkOption {
        type = lib.types.str;
        description = "Git config username";
        default = "";
      };
      user.email = lib.mkOption {
        type = lib.types.str;
        description = "Git config user.email.";
        default = "";
      };
    };
  };
}
