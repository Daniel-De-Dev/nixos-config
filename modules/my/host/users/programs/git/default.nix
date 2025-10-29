{
  lib,
  config,
  pkgs,
  ...
}:
let
  allUsers = config.my.host.users or { };

  gitUsers = lib.filterAttrs (_: userConfig: userConfig.programs.git.enable or false) allUsers;

  generateScriptForUser =
    userName: userConfig:
    let
      gitCfg = userConfig.programs.git;
      settings = gitCfg.settings;

      realUserConfig = config.users.users.${userName};

      templateDef = import gitCfg.template { inherit pkgs; };
      templateContent = builtins.readFile templateDef.src;

      vars = {
        userName = settings.userName;
        userEmail = settings.userEmail;
      };

      finalConfigPath = pkgs.replaceVars templateDef.src vars;
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
      in
      {
        packages = [ pkgs.git ] ++ (templateDef.packages or [ ]);
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
            assertion = gitCfg.template != null;
            message = "User '${userName}' has 'git' enabled but 'programs.git.template' is not set.";
          }
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
