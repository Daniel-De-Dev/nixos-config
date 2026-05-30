# =============================================================================
# Configures the Git version control system and injects signing identities.
# =============================================================================
{ ... }:
{
  flake.nixosModules.programs-git =
    {
      pkgs,
      config,
      inputs,
      lib,
      ...
    }:
    let
      opName = config.my.operator.fullName;
      opEmail = config.my.operator.email;
      opSigningKey = config.my.operator.signingKey;
      opUsername = config.my.operator.username;

      # Using a version patched to work respect `GIT_CONFIG_GLOBAL`
      myDelta = pkgs.delta.overrideAttrs (
        finalAttrs: prevAttrs: {
          version = "0.19.2";
          src = pkgs.fetchFromGitHub {
            owner = "Daniel-De-Dev";
            repo = "delta";
            rev = "2802eb488b96a90f098443f61efbba1bddc8eba5";
            hash = "sha256-T85KFtYDyt6KfO49KSNb1VTTlnDS0mcgDA4lrCkE5ok=";
          };

          cargoHash = "sha256-CC2ncgujdcn1CJxU16beCjfQ1HR2+f6D8qYbZULEm7g=";

          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit (finalAttrs) pname src version;
            hash = finalAttrs.cargoHash;
          };
        }
      );

      compiledGitConfig = pkgs.replaceVars ./gitconfig {
        userName = opName;
        userEmail = opEmail;
        userSshKey = opSigningKey;
        # INFO: `ssh-forge.sh` ensures to generate this when generating `sign`
        # scoped key
        allowedSignersPath = "~/.ssh/allowed_signers";
      };

      wm-eval = inputs.wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.git = {
              basePackage = pkgs.git;
              env.GIT_CONFIG_GLOBAL.value = toString compiledGitConfig;

              pathAdd = [
                wm-eval.config.wrappers.delta.wrapped
                pkgs.difftastic
                pkgs.neovim
              ];
            };

            wrappers.delta = {
              basePackage = myDelta;
              env.GIT_CONFIG_GLOBAL.value = toString compiledGitConfig;
            };
          }
        ];
      };
    in
    {
      options.my.programs.git.enable = lib.mkEnableOption "Git version control";

      config = lib.mkIf config.my.programs.git.enable {
        environment.systemPackages = [ pkgs.git ];
        users.users.${opUsername}.packages = [ wm-eval.config.wrappers.git.wrapped ];

        warnings = lib.mkIf (opEmail == "operator@localhost") [
          "Git: Privacy data missing! Commits will be authored as 'operator@localhost'."
        ];
      };
    };
}
