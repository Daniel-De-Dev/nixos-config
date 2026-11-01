{ inputs, self, ... }: {
  perSystem =
    { lib, pkgs, ... }:
    let
      failures = import ../../tests/hyprlock.nix {
        inherit lib;
        inherit (inputs.nixpkgs.lib) nixosSystem;
        modules = self.nixosModules;
      };
      lockScreen = pkgs.callPackage ../../packages/hyprlock {
        inherit (inputs) wrapper-manager;
        theme =
          (lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [ ../../themes/module.nix ];
          }).config.my.theme;
        wallpaper = ../desktop/hyprland/src/wallpaper.jpg;
      };
    in
    {
      checks.hyprlock =
        assert lib.assertMsg (
          failures == [ ]
        ) "Hyprlock tests failed: ${builtins.toJSON failures}";
        pkgs.runCommand "hyprlock-tests" { } ''
          # Build the real wrapper and shellcheck the baked battery helper.
          test -x ${lib.getExe lockScreen}
          export HYPRLOCK_POWER_SUPPLY_DIR="$TMPDIR/supplies"
          mkdir -p "$HYPRLOCK_POWER_SUPPLY_DIR"
          test -z "$(${lib.getExe lockScreen.batteryStatus})"
          mkdir -p "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0"
          printf 'Battery\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/type"
          printf '73\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/capacity"
          printf 'Charging\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/status"
          test "$(${lib.getExe lockScreen.batteryStatus})" = 'Battery 73% · Charging'
          printf '10\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/capacity"
          printf 'Discharging\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/status"
          [[ "$(${lib.getExe lockScreen.batteryStatus})" == '<span '* ]]
          printf 'Device\n' > "$HYPRLOCK_POWER_SUPPLY_DIR/BAT0/scope"
          test -z "$(${lib.getExe lockScreen.batteryStatus})"
          touch "$out"
        '';
    };
}
