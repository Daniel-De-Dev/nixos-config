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
      importResult = builtins.tryEval (
        import gitCfg.template {
          inherit pkgs;
          settings = gitCfg.settings;
          inherit config;
        }
      );
    in
    if !importResult.success then
      throw ''
        User ${userName} has git.template set to "${gitCfg.template}"
        but evaluating the template failed with: ${builtins.toString importResult.error}
      ''
    else
      let
        templateDef = importResult.value;
        requiredSettings = if templateDef ? requiredSettings then templateDef.requiredSettings else [ ];
        templateAssertions = if templateDef ? assertions then templateDef.assertions else [ ];
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
      assert lib.assertMsg (builtins.isList requiredSettings) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        but the attribute "requiredSettings" is not a list
      '';
      assert lib.assertMsg (lib.all builtins.isString requiredSettings) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        every entry in "requiredSettings" must be a string
      '';
      assert lib.assertMsg (builtins.isList templateAssertions) ''
        User ${userName} has git.template set to "${gitCfg.template}"
        but the attribute "assertions" is not a list
      '';
      assert lib.assertMsg
        (lib.all (
          assertion:
          builtins.isAttrs assertion
          && (assertion ? assertion)
          && (assertion ? message)
          && builtins.isBool assertion.assertion
          && builtins.isString assertion.message
        ) templateAssertions)
        ''
          User ${userName} has git.template set to "${gitCfg.template}"
          every entry in "assertions" must be an attribute set with
          boolean `assertion` and string `message`
        '';
      {
        src = templateDef.src;
        packages = templateDef.packages;
        requiredSettings = requiredSettings;
        assertions = templateAssertions;
      };

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
        vars = lib.filterAttrs (_: value: value != null) settings;

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
