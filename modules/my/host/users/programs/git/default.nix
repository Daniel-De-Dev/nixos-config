{
  lib,
  config,
  pkgs,
  ...
}:
let
  allUsers = config.my.host.users;

  gitUsers = lib.filterAttrs (_: userConfig: userConfig.programs.git.enable or false) allUsers;

  generateScriptForUser =
    userName: userConfig:
    let
      gitCfg = userConfig.programs.git;
      settings = gitCfg.settings;

      realUserConfig = config.users.users.${userName};

      templateDef = import gitCfg.template { inherit pkgs; };

      vars = {
        inherit (settings) userName userEmail;
      };

      finalConfigPath =
        assert lib.assertMsg (templateDef ? src) ''
          User ${userName} has git.templates set to "${gitCfg.template}"
          it coudlnt find attribute "src"
        '';
        assert lib.assertMsg (builtins.typeOf templateDef.src == "path") ''
          User ${userName} has git.templates set to "${gitCfg.template}"
          the attribute type of "src" is not a path
        '';
        pkgs.replaceVars templateDef.src vars;
    in
    {
      name = "writeGitConfig-${realUserConfig.name}";
      value = {
        text = ''
          echo "Installing .gitconfig for user ${realUserConfig.name}..."
          configDir="${realUserConfig.home}/.config"
          targetDir="$configDir/git"
          targetFile="$targetDir/config"

          mkdir -p "$targetDir"
          cp "${finalConfigPath}" "$targetFile"
          chown -R "${realUserConfig.name}:${realUserConfig.group}" "$targetDir"
          chmod 0600 "$targetFile"
        '';
      };
    };
in
{
  config = {

    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        gitCfg = userConfig.programs.git;
        templateDef = import gitCfg.template { inherit pkgs; };
        templatePkgs =
          assert lib.assertMsg (templateDef ? packages) ''
            User ${userName} has git.templates set to "${gitCfg.template}"
            it coudlnt find attribute "packages"
          '';
          assert lib.assertMsg (builtins.typeOf templateDef.packages == "list") ''
            User ${userName} has git.templates set to "${gitCfg.template}"
            it coudlnt find attribute "packages"
          '';
          templateDef.packages;
      in
      {
        packages = [ pkgs.git ] ++ templatePkgs;
      }
    ) gitUsers;

    system.activationScripts = lib.mapAttrs' generateScriptForUser gitUsers;

    assertions = lib.flatten (
      lib.mapAttrsToList (
        userName: userConfig:
        let
          gitCfg = userConfig.programs.git;
          settings = gitCfg.settings;
        in
        [
          {
            assertion = settings.userName != null;
            message = "User '${userName}' has 'git' enabled but 'programs.git.settings.userName' is not set.";
          }
          {
            assertion = settings.userEmail != null;
            message = "User '${userName}' has 'git' enabled but 'programs.git.settings.userEmail' is not set.";
          }
        ]
      ) gitUsers
    );
  };
}
