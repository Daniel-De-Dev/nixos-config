{
  lib,
  config,
  pkgs,
  ...
}:
let
  allUsers = config.my.host.users;
  gitUsers = lib.filterAttrs (_: userConfig: userConfig.programs.git.enable) allUsers;

  getValidatedTemplate =
    userName: gitCfg:
    let
      templateModuleOptions =
        { lib, ... }:
        {
          options = {
            src = lib.mkOption {
              type = lib.types.path;
              description = "Path to the gitconfig template file.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages to install.";
            };
            requiredSettings = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of setting names that must be provided.";
            };
            assertions = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule {
                  options = {
                    assertion = lib.mkOption {
                      type = lib.types.bool;
                      description = "The assertion expression";
                    };
                    message = lib.mkOption {
                      type = lib.types.str;
                      description = "The error message to show if the assertion fails.";
                    };
                  };
                }
              );
              default = [ ];
              description = "A list of assertions to run against the settings.";
            };
          };
        };
      eval = lib.evalModules {
        modules = [
          templateModuleOptions
          gitCfg.template
        ];
        specialArgs = {
          inherit
            pkgs
            config
            lib
            ;
        };
      };
    in
    eval.config;

  validatedTemplates = lib.mapAttrs (
    userName: userConfig: getValidatedTemplate userName userConfig.programs.git
  ) gitUsers;
in
{
  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.programs.git = {
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
      }
    );
  };

  config = {
    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        gitCfg = userConfig.programs.git;
        templateDef = validatedTemplates.${userName};
        vars = lib.filterAttrs (_: value: value != null) gitCfg.settings;

        finalConfigPath = pkgs.replaceVars templateDef.src vars;

        git-wrapper = pkgs.stdenv.mkDerivation {
          name = "git-wrapper-${userName}";
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontUnpack = true;

          installPhase = ''
            mkdir -p $out/bin
            # Wrap the real git binary
            makeWrapper ${pkgs.git}/bin/git $out/bin/git \
              --set GIT_CONFIG_GLOBAL "${finalConfigPath}"
          '';
        };
      in
      {
        packages = [ git-wrapper ] ++ templateDef.packages;
      }
    ) gitUsers;

    assertions = lib.flatten (
      lib.mapAttrsToList (
        userName: userConfig:
        let
          gitCfg = userConfig.programs.git;
          settings = gitCfg.settings;
          templateDef = validatedTemplates.${userName};

          requiredSettingAssertions = map (
            settingName:
            let
              value = lib.attrByPath [ settingName ] null settings;
            in
            {
              assertion = value != null;
              message = "User '${userName}' uses a git template that requires 'programs.git.settings.${settingName}' to be set.";
            }
          ) templateDef.requiredSettings;

          templateAssertions = map (
            tplAssertion: tplAssertion // { message = "User '${userName}': ${tplAssertion.message}"; }
          ) templateDef.assertions;
        in
        requiredSettingAssertions ++ templateAssertions
      ) gitUsers
    );
  };
}
