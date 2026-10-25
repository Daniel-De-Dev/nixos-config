{ lib, modules }:
let
  evaluate =
    monitors:
    (lib.evalModules {
      modules = [
        modules.hardware-monitors
        {
          options.boot.kernelParams = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [ ];
          };
          config.my.hardware.monitors = monitors;
        }
      ];
    }).config;
  display = {
    description = ''Example "display"'';
    connector = "DP-1";
    width = 2560;
    height = 1440;
    refreshRate = 170.07;
    x = -2560;
    y = 180;
    scale = 1.25;
    ttyWidth = 1920;
    ttyHeight = 1080;
  };
  configured = evaluate [ display ];
  render =
    monitors: import ../packages/hyprland/monitors.nix { inherit lib monitors; };
  rules = render configured.my.hardware.monitors;
  valid = monitors: lib.all (item: item.assertion) (evaluate monitors).assertions;
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
lib.runTests {
  testEmptyHostDoesNotForceConsoleModes = {
    expr = (evaluate [ ]).boot.kernelParams;
    expected = [ ];
  };
  testConfiguredConsoleModes = {
    expr = configured.boot.kernelParams;
    expected = [ "video=DP-1:1920x1080@60" ];
  };
  testConsoleDefaultsToDesktopDimensions = {
    expr =
      (evaluate [
        (builtins.removeAttrs display [
          "ttyWidth"
          "ttyHeight"
        ])
      ]).boot.kernelParams;
    expected = [ "video=DP-1:2560x1440@60" ];
  };
  testDescriptionOnlyDoesNotInventKernelConnector = {
    expr =
      (evaluate [ (builtins.removeAttrs display [ "connector" ]) ]).boot.kernelParams;
    expected = [ ];
  };
  testDesktopKeepsItsModeAndLayout = {
    expr = lib.all (part: lib.hasInfix part (builtins.head rules)) [
      "2560x1440@170.07"
      "-2560x180"
      ''["scale"] = 1.25''
      ''desc:Example \"display\"''
    ];
    expected = true;
  };
  testConnectorIsDesktopFallback = {
    expr = lib.hasInfix ''["output"] = "DP-1"'' (
      builtins.head (
        render
          (evaluate [ (builtins.removeAttrs display [ "description" ]) ])
          .my.hardware.monitors
      )
    );
    expected = true;
  };
  testUnlistedDisplaysHaveFallback = {
    expr = lib.last rules == builtins.head (render [ ]);
    expected = true;
  };
  testInvalidNumbersRejected = {
    expr =
      map (change: fails (evaluate [ (display // change) ]).my.hardware.monitors)
        [
          { width = 0; }
          { height = -1; }
          { scale = "1"; }
          { scale = 0; }
          { refreshRate = 0; }
          { ttyWidth = 0; }
          { ttyRefreshRate = 59.94; }
        ];
    expected = lib.replicate 7 true;
  };
  testInvalidIdentitiesRejected = {
    expr = [
      (valid [
        (builtins.removeAttrs display [
          "description"
          "connector"
        ])
      ])
      (valid [
        display
        display
      ])
      (valid [
        display
        (display // { connector = "HDMI-A-1"; })
      ])
    ];
    expected = [
      false
      false
      false
    ];
  };
  testDescriptionAndConnectorAreIndependent = {
    expr = valid [
      display
      (
        display
        // {
          description = "Second display";
          connector = "HDMI-A-2";
        }
      )
    ];
    expected = true;
  };
}
