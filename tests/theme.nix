{
  lib,
  pkgs,
  modules,
  package,
}:
let
  evaluate =
    overrides:
    lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        modules.core-palette
        { my.theme = overrides; }
      ];
    };
  defaults = (evaluate { }).config.my.theme;
  changed =
    (evaluate {
      colors.accent = "#ff00ff";
      fonts.sans = "Noto Sans";
      spacing.md = 20;
    }).config.my.theme;
  variant = package.override { theme = changed; };
  css = import ../packages/ags-shell/style.nix {
    inherit lib;
    theme = changed;
  };
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
lib.runTests {
  testNoDesktopRequired = {
    expr = (evaluate { }).options.my ? desktop;
    expected = false;
  };
  testPartialOverrideRetainsDefaults = {
    expr = { inherit (changed.colors) accent background; };
    expected = {
      accent = "#ff00ff";
      background = "#161616";
    };
  };
  testColorsNeedHashAndSixDigits = {
    expr =
      map (value: fails (evaluate { colors.accent = value; }).config.my.theme.colors)
        [
          "4589ff"
          "#fff"
          "blue"
          "#123456; color: red"
        ];
    expected = [
      true
      true
      true
      true
    ];
  };
  testUnknownRoleRejected = {
    expr = fails (evaluate { colors.typo = "#ffffff"; }).config.my.theme.colors;
    expected = true;
  };
  testInvalidSizesRejected = {
    expr = [
      (fails (evaluate { spacing.md = -1; }).config.my.theme.spacing)
      (fails (evaluate { fontSizes.body = 0; }).config.my.theme.fontSizes)
    ];
    expected = [
      true
      true
    ];
  };
  testOverridesReachStylesheet = {
    expr = lib.all (part: lib.hasInfix part css) [
      "@define-color theme_accent #ff00ff;"
      ''font-family: "Noto Sans", sans-serif;''
      "padding: 0 20px;"
    ];
    expected = true;
  };
  testNoUnresolvedPlaceholders = {
    expr = !(lib.hasInfix "var(--" css);
    expected = true;
  };
  testThemeKeepsBundle = {
    expr = package.bundle.drvPath == variant.bundle.drvPath;
    expected = true;
  };
  testThemeChangesStyleAndLauncher = {
    expr =
      package.stylesheet.drvPath != variant.stylesheet.drvPath
      && package.drvPath != variant.drvPath;
    expected = true;
  };
  testDefaultStylesheetUsesSharedColors = {
    expr =
      lib.hasInfix "@define-color theme_background ${defaults.colors.background};"
        (
          import ../packages/ags-shell/style.nix {
            inherit lib;
            theme = defaults;
          }
        );
    expected = true;
  };
}
