# Purpose: Polyfill for NixOS Issue #55674.
# Scope: Global unfree package whitelist collection.
# Invariants:
# - Modules must append to `my.allowedUnfree`.
_: {
  flake.nixosModules.core-unfree = { lib, config, ... }: {
    options.my.allowedUnfree = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of unfree package names allowed to be evaluated.";
    };

    config = {
      nixpkgs.config.allowUnfreePredicate =
        pkg: builtins.elem (lib.getName pkg) config.my.allowedUnfree;
    };
  };
}
