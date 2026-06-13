# =============================================================================
# Polyfill for NixOS Issue #55674 (Unfree Package Merging)
#
# DESIGN CONSTRAINTS:
# 1. Modules and hosts must append to `my.allowedUnfree` rather than defining
#    their own `nixpkgs.config.allowUnfreePredicate`.
# =============================================================================
{ ... }: {
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
