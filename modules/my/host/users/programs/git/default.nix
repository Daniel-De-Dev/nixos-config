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
        User ${userName} has git.templates set to "${gitCfg.template}"
        but evaluating the template failed with: ${builtins.toString importResult.error}
      ''
    else
      let
        templateDef = importResult.value;
      in
      assert lib.assertMsg (builtins.isAttrs templateDef) ''
        User ${userName} has git.templates set to "${gitCfg.template}"
        but the template did not return an attribute set
      '';
      assert lib.assertMsg (templateDef ? src) ''
        User ${userName} has git.templates set to "${gitCfg.template}"
        it coudlnt find attribute "src"
      '';
      assert lib.assertMsg (builtins.typeOf templateDef.src == "path") ''
        User ${userName} has git.templates set to "${gitCfg.template}"
        the attribute type of "src" is not a path
      '';
      assert lib.assertMsg (templateDef ? packages) ''
        User ${userName} has git.templates set to "${gitCfg.template}"
        it coudlnt find attribute "packages"
      '';
      assert lib.assertMsg (builtins.typeOf templateDef.packages == "list") ''
        User ${userName} has git.templates set to "${gitCfg.template}"
        The value attribute "packages" has is not a list
      '';
      templateDef;

  validatedTemplates = lib.mapAttrs (
    userName: userConfig: validateTemplate userName userConfig.programs.git
  ) gitUsers;

  generateGitConfig =
    userName: userConfig:
    let
      gitCfg = userConfig.programs.git;
      settings = gitCfg.settings;

      realUserConfig =
        let
          hasSystemUser = lib.hasAttr userName config.users.users;
        in
        assert lib.assertMsg hasSystemUser ''
          Git configuration was requested for "${userName}", but no matching
          entry exists in users.users. Define the system user or disable
          programs.git for this entry.
          (shouldnt be possible since all host.users are generated)
        '';
        config.users.users.${userName};

      templateDef = validatedTemplates.${userName};

      vars = {
        inherit (settings) userName userEmail;
      };

      finalConfigPath = pkgs.replaceVars templateDef.src vars;

      systemdName = "git-config-installer-${realUserConfig.name}";
      installScript = pkgs.writeShellScript systemdName ''
        set -euo pipefail
        echo "Installing .gitconfig for user ${realUserConfig.name}"

        configDir="${realUserConfig.home}/.config"
        targetDir="$configDir/git"
        targetFile="$targetDir/config"

        mkdir -p "$targetDir"
        ${pkgs.coreutils}/bin/install -m 0600 "${finalConfigPath}" "$targetFile"
        chown -R "${realUserConfig.name}:${realUserConfig.group}" "$targetDir"
      '';
    in
    {
      service = {
        ${systemdName} = {
          description = "Install ${userName}'s .gitconfig";
          unitConfig.RequiresMountsFor = [ realUserConfig.home ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = installScript;
            User = "root";
            Group = "root";
          };

          wantedBy = [ "sysinit-reactivation.target" ];
          before = [ ];
        };
      };
    };

  perUser = lib.mapAttrs (u: uc: generateGitConfig u uc) gitUsers;
in
{
  config = {
    users.users = lib.mapAttrs (
      userName: userConfig:
      let
        templateDef = validatedTemplates.${userName};
        templatePkgs = templateDef.packages;
      in
      {
        packages = [ pkgs.git ] ++ templatePkgs;
      }
    ) gitUsers;

    systemd.services = lib.mkMerge (lib.attrValues (lib.mapAttrs (_: v: v.service) perUser));

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
