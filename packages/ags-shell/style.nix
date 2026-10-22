# Render GTK3 CSS from the shared theme without embedding it in JavaScript.
{ lib, theme }:
let
  values = {
    fontSans = builtins.toJSON theme.fonts.sans;
  }
  // lib.mapAttrs' (
    name: value: lib.nameValuePair "fontSize-${name}" "${toString value}px"
  ) theme.fontSizes
  // lib.mapAttrs' (
    name: value: lib.nameValuePair "spacing-${name}" "${toString value}px"
  ) theme.spacing;
  render = lib.replaceStrings (map (name: "@${name}@") (
    builtins.attrNames values
  )) (builtins.attrValues values);
in
lib.concatStringsSep "\n" (
  lib.mapAttrsToList (
    name: value: "@define-color theme_${name} ${value};"
  ) theme.colors
)
+ "\n"
+ render (builtins.readFile ./src/style.css)
+ "\n"
+ render (builtins.readFile ./src/widget/window-switcher.css)
