# Render the same Lua sources for the installed desktop and the nested preview.
{
  lib,
  pkgs,
  desktop,
  colors,
  kbLayout ? "us",
  autostartConf,
  monitorRules,
  recScriptPath ? "${pkgs.coreutils}/bin/false",
  extraBindings ? [ ],
  extraLayerRules ? [ ],
  nested ? false,
}:
let
  src = ../../modules/desktop/hyprland/src;
  inputConf = pkgs.replaceVars (src + /input.lua) { inherit kbLayout; };
  themeConf = pkgs.replaceVars (src + /theme.lua) {
    activeColor = "0xff${lib.removePrefix "#" colors.focus}";
    inactiveColor = "0xff${lib.removePrefix "#" colors.border}";
  };
  applicationsConf = pkgs.writeText "applications.lua" (
    "return " + lib.generators.toLua { } desktop.commands
  );
  bindsConf = pkgs.writeText "binds.lua" (
    builtins.replaceStrings
      [ "@scScriptPath@" "@recScriptPath@" "@nested@" "@applicationsPath@" ]
      [
        (lib.getExe desktop.screenshot)
        recScriptPath
        (lib.boolToString nested)
        "${applicationsConf}"
      ]
      (builtins.readFile (src + /binds.lua))
    + "\n"
    + lib.concatStringsSep "\n" extraBindings
  );
in
pkgs.replaceVars (src + /hyprland.lua) {
  inputConfPath = inputConf;
  autostartConfPath = autostartConf;
  themeConfPath = themeConf;
  layoutConfPath = pkgs.replaceVars (src + /layout.lua) { };
  miscConfPath = pkgs.replaceVars (src + /misc.lua) { };
  bindsConfPath = bindsConf;
  layerRulesConfPath = pkgs.writeText "layer-rules.lua" (
    lib.concatStringsSep "\n" extraLayerRules
  );
  monitorsConfPath = pkgs.writeText "monitors.lua" (
    lib.concatStringsSep "\n" monitorRules
  );
}
