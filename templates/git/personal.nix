{
  pkgs,
  settings,
  config,
  ...
}:
{
  packages = [
  ];

  src = ./gitconfig.personal.template;

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
  ];
}
