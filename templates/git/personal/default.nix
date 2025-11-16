{
  pkgs,
  config,
  lib,
  ...
}:
let
  # Using a version i pacthed to work with `GIT_CONFIG_GLOBAL`
  myDelta = pkgs.delta.overrideAttrs (
    finalAttrs: prevAttrs: {
      version = "unstable-${builtins.substring 0 7 finalAttrs.src.rev}";
      src = pkgs.fetchFromGitHub {
        owner = "Daniel-De-Dev";
        repo = "delta";
        rev = "dee1c2869de160996e034e8ad31139b0ae9ecb5d";
        hash = "sha256-Zn9C6SM90faZpZAj8JLLWZJwWpV2dgkJCOyeVNgW4B8=";
      };

      cargoHash = "sha256-/0CVhCjfPwWxmCOC01wcTGhLxsSzuZkPhIJga0QaAL8=";

      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname src version;
        hash = finalAttrs.cargoHash;
      };
    }
  );
in
{
  src = ./gitconfig;

  packages = [
    myDelta
    pkgs.difftastic
  ];

  requiredSettings = [
    "userName"
    "userEmail"
    "userSigningKey"
  ];

  assertions = [
    {
      assertion = config.programs.gnupg.agent.enable;
      message = "personal template expects GPG agent to be enabled";
    }
    {
      assertion = config.programs.neovim.enable;
      message = "personal template expects neovim to be enabled";
    }
  ];
}
