{
  lib,
  config,
  pkgs,
  ...
}:
let
  allUsers = config.my.host.users;
  gitUsers = lib.filterAttrs (_: userConfig: userConfig.programs.git.enable or false) allUsers;

  validateTemplate =
    userName: gitCfg:
    let
      importResult = builtins.tryEval (import gitCfg.template { inherit pkgs; });
    in
    if !importResult.success then
      throw ''
        User ${userName} has git.template set to "${gitCfg.template}"
        but evaluating the template failed with: ${builtins.toString importResult.error}
      ''
    else
      let
        templateDef = importResult.value;
      in
      assert lib.assertMsg (builtins.isAttrs templateDef) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        but the template did not return an attribute set
      '';
      assert lib.assertMsg (templateDef ? src) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        it coudlnt find attribute "src"
      '';
      assert lib.assertMsg (builtins.typeOf templateDef.src == "path") ''
        User ${userName} has git.template set to "${gitCfg.template}"
        the attribute type of "src" is not a path
      '';
      assert lib.assertMsg (templateDef ? packages) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        it coudlnt find attribute "packages"
      '';
      assert lib.assertMsg (builtins.typeOf templateDef.packages == "list") ''
        User ${userName} has git.template set to "${gitCfg.template}"
        The value attribute "packages" has is not a list
      '';
      templateDef;

  validatedTemplates = lib.mapAttrs (
    userName: userConfig: validateTemplate userName userConfig.programs.git
  ) gitUsers;
in
{
  config = {
    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        gitCfg = userConfig.programs.git;
        settings = gitCfg.settings;
        templateDef = validatedTemplates.${userName};
        vars = { inherit (settings) userName userEmail userSigningKey; };

        finalConfigPath = pkgs.replaceVars templateDef.src vars;

        git-wrapper = pkgs.stdenv.mkDerivation {
          name = "git-wrapper-${userName}";
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontUnpack = true;

          installPhase = ''
            mkdir -p $out/bin
            # Wrap the real git binary
            makeWrapper ${pkgs.git}/bin/git $out/bin/git \
              --set GIT_CONFIG_SYSTEM "${finalConfigPath}"
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
          {
            assertion = settings.userSigningKey != null;
            message = "User '${userName}' has 'git' enabled but 'programs.git.settings.userSigningKey' is not set.";
          }
        ]
      ) gitUsers
    );
  };
}
