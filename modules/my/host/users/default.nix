{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./features
    ./programs
  ];

  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.strMatching "^[a-z_][a-z0-9_-]*$";
              default = name;
              description = ''
                The user's login name, defaults to the attribute name
              '';
            };

            shell = lib.mkOption {
              type = lib.types.enum [
                "bash"
                "fish"
              ];
              default = "bash";
              description = "The shell to use for this user.";
            };

            features = {
              sudo = {
                enable = lib.mkEnableOption ''
                  Enable sudo access for this user.
                  This will add the user to the 'wheel' group
                '';
              };

              ssh = {
                enable = lib.mkEnableOption "automatic SSH key generation on first login";

                email = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Email address to use as a comment for the SSH key. Required if enabled.
                  '';
                };
              };

              gpg = {
                enable = lib.mkEnableOption "automatic GPG key generation on first login";

                realName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Full name for the GPG key. Required if enabled.";
                };

                email = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Email address for the GPG key. Required if enabled.";
                };
              };
            };

            programs = {
              git = {
                enable = lib.mkEnableOption ''
                  Enable the setting up and managing of git configuration for
                  this user.
                '';

                template = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    Path to the .nix file that defines the git template.
                    (its dependecies & raw config file)
                  '';
                };

                settings = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      userName = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "Value for @userName@ placeholder.";
                      };
                      userEmail = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "Value for @userEmail@ placeholder.";
                      };
                      userSigningKey = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "The GPG key ID or fingerprint for commit signing. Value for @userSigningKey@ placeholder.";
                      };
                    };
                  };
                  default = { };
                  description = "Private settings to substitute into the template.";
                };
              };

              neovim = {
                enable = lib.mkEnableOption ''
                  Enable the setting up and managing of neovim configuration
                  for this user.
                '';
                profile = lib.mkOption {
                  type = lib.types.str;
                  description = "The profile to use from 'inputs.nvim-config.configs'.";
                };
                configPath = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Absolute path the where the nvim config repo lives on system
                    Used for developer mode so it is used as config once env
                    variable is set (see neovim.nix)
                  '';
                };
              };
              tmux = {
                enable = lib.mkEnableOption "Enable tmux configuration for this user.";

                template = lib.mkOption {
                  type = lib.types.path;
                  description = "Path to the .nix file that defines the tmux template.";
                };

                settings = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      defaultShellPath = lib.mkOption {
                        type = lib.types.str;
                        readOnly = true;
                        description = ''
                          Path to the shell that the user has by defualt.
                          Its automatically derived based on the shell selected.
                        '';
                      };
                    };
                  };
                  default = { };
                  description = "Private settings to substitute into the template.";
                };
              };
            };
          };
          config = {
            programs.tmux.settings.defaultShellPath =
              let
                shellMap = {
                  fish = lib.getExe pkgs.fish;
                  bash = lib.getExe pkgs.bash;
                };
              in
              shellMap.${config.shell};
          };
        }
      )
    );
    default = { };
    description = ''
      Defines the authoritative map of users for this host.

      This module automatically generates the corresponding `users.users`
      and `users.groups` entries from this definition.

      This data is generally intended to be populated by the `my.privacy` module.
      It's really up to you what you consider "private"
    '';
  };

  config = {
    users.users = lib.mapAttrs (_: userConfig: {
      name = userConfig.name;
      group = userConfig.name;
    }) config.my.host.users;

    users.groups = lib.mapAttrs (_: userConfig: {
      name = userConfig.name;
    }) config.my.host.users;
  };
}
