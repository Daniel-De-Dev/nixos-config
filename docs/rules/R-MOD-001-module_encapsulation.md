---
id: R-MOD-001
kind: rule
topic: module_encapsulation
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
related:
  - DEC-003
---

> [!summary]
> Enforces custom option namespaces and unfree package whitelisting.

# 1. Rule

Modules MUST expose configuration via `my.*` namespace. Modules MUST NOT enable system services unconditionally. Unfree packages MUST append to `my.allowedUnfree` (see DEC-003).

# 2. Correct Pattern

```nix
_: {
	flake.nixosModules.<name> = {
		options.my.programs.<tool>.enable = lib.mkEnableOption "Tool";
		config = lib.mkIf config.my.programs.<tool>.enable {
			  my.allowedUnfree = [ "tool-unfree" ];
		};
	};
}
```

# 3. Exceptions

Core modules MAY enforce baseline system limits unconditionally. Core SHOULD set universal modern practice defaults applicable to all hosts.

# 4. Validation

Check for `lib.mkEnableOption`. Verify `my.allowedUnfree` usage for proprietary software. Ensure Dendritic pattern adherence.

# 5. Migration

Rewrite raw `nixpkgs.config.allowUnfreePredicate` overrides to use `my.allowedUnfree` polyfill. Ensure every module follows the dendritic pattern.
