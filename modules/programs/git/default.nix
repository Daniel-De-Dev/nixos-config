# =============================================================================
# Git configuration
# =============================================================================
{ ... }:
{
  flake.nixosModules.programs-git =
    {
      pkgs,
      config,
      inputs,
      ...
    }:
    let
      opName = config.my.operator.fullName;
      opEmail = config.my.operator.email;
      opSigningKey = config.my.operator.signingKey;
      opUsername = config.my.operator.username;

      compiledGitConfig = pkgs.replaceVars ./gitconfig {
        userName = opName;
        userEmail = opEmail;
        userSshKey = opSigningKey;
        #TODO: Make sure this file exists
        allowedSignersPath = "~/.ssh/allowed_signers";

        nvim = "${pkgs.neovim}/bin/nvim";
        delta = "${pkgs.delta}/bin/delta";
        difft = "${pkgs.difftastic}/bin/difft";
      };

      wm-eval = inputs.wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.git = {
              basePackage = pkgs.git;
              env.GIT_CONFIG_GLOBAL.value = toString compiledGitConfig;
            };
          }
        ];
      };
    in
    {
      environment.systemPackages = [ pkgs.git ];

      users.users.${opUsername}.packages = [ wm-eval.config.wrappers.git.wrapped ];
    };
}
