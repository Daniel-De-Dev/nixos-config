{
  lib,
  config,
  pkgs,
  ...
}:
let
  users = config.my.host.users;

  shellImplementations = {
    bash = {
      pkg = pkgs.bash;
      enableProgram = false;
    };
    fish = {
      pkg = pkgs.fish;
      enableProgram = true;
    };
  };

  activeShells = lib.unique (lib.catAttrs "shell" (lib.attrValues users));
in
{
  config = {
    programs = lib.mkMerge (
      map (
        shellName:
        let
          impl = shellImplementations.${shellName};
        in
        lib.mkIf impl.enableProgram {
          ${shellName}.enable = true;
        }
      ) activeShells
    );

    environment.shells = map (name: shellImplementations.${name}.pkg) activeShells;

    users.users = lib.mapAttrs (name: userCfg: {
      shell = shellImplementations.${userCfg.shell}.pkg;
    }) users;
  };
}
