{
  lib,
  config,
  pkgs,
  ...
}:
let
  allUsers = config.my.host.users;
  tmuxUsers = lib.filterAttrs (_: userConfig: userConfig.programs.tmux.enable) allUsers;

  getValidatedTemplate =
    userName: tmuxCfg:
    let
      templateModuleOptions =
        { lib, ... }:
        {
          options = {
            src = lib.mkOption {
              type = lib.types.path;
              description = "Path to the tmux.conf template file.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Extra packages (plugins, tools) to install.";
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
          tmuxCfg.template
        ];
        specialArgs = {
          inherit pkgs config lib;
        };
      };
    in
    eval.config;

  validatedTemplates = lib.mapAttrs (
    userName: userConfig: getValidatedTemplate userName userConfig.programs.tmux
  ) tmuxUsers;

  shellName = userConfig.shell;

  shellPkgs = {
    fish = pkgs.fish;
    bash = pkgs.bashInteractive;
  };

  shellPkg =
    if builtins.hasAttr shellName shellPkgs then
      builtins.getAttr shellName shellPkgs
    else
      throw "Unknown shell '${shellName}'. Expected one of: ${builtins.concatStringsSep ", " (builtins.attrNames shellPkgs)}";

  userConfig.programs.tmux.programs.settings.defaultShellPath = lib.getExe shellPkg;
in
{
  options.my.host.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options.programs.tmux = {
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

          config.programs.tmux.settings.defaultShellPath =
            let
              shellMap = {
                fish = lib.getExe pkgs.fish;
                bash = lib.getExe pkgs.bash;
              };
            in
            shellMap.${config.shell};
        }
      )
    );
  };

  config = {
    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        tmuxCfg = userConfig.programs.tmux;
        templateDef = validatedTemplates.${userName};

        vars = lib.filterAttrs (
          name: value: value != null && lib.elem name templateDef.requiredSettings
        ) tmuxCfg.settings;

        finalConfigPath = pkgs.replaceVars templateDef.src vars;

        tmux-wrapper = pkgs.stdenv.mkDerivation {
          name = "tmux-wrapper-${userName}";
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontUnpack = true;

          installPhase = ''
            mkdir -p $out/bin
            # Wrap the real tmux binary
            makeWrapper ${pkgs.tmux}/bin/tmux $out/bin/tmux \
              --add-flags "-f ${finalConfigPath}"
          '';
        };
      in
      {
        packages = [ tmux-wrapper ] ++ templateDef.packages;
      }
    ) tmuxUsers;

    assertions = lib.flatten (
      lib.mapAttrsToList (
        userName: userConfig:
        let
          tmuxCfg = userConfig.programs.tmux;
          settings = tmuxCfg.settings;
          templateDef = validatedTemplates.${userName};

          requiredSettingAssertions = map (
            settingName:
            let
              value = lib.attrByPath [ settingName ] null settings;
            in
            {
              assertion = value != null;
              message = "User '${userName}' uses a tmux template that requires 'programs.tmux.settings.${settingName}' to be set.";
            }
          ) templateDef.requiredSettings;

          templateAssertions = map (
            tplAssertion: tplAssertion // { message = "User '${userName}': ${tplAssertion.message}"; }
          ) templateDef.assertions;
        in
        requiredSettingAssertions ++ templateAssertions
      ) tmuxUsers
    );
  };
}
