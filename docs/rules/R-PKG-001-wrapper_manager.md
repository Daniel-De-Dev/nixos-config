---
id: R-PKG-001
kind: rule
topic: wrapper_manager
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
---

> [!summary]
> Defines pattern for wrapping programs using wrapper-manager.

# 1. Rule

Programs MUST use `wrapper-manager` to generate wrapped derivations. Simple binaries MAY use global `environment.systemPackages` where minimal to none configuration is required.

# 2. Correct Pattern

```nix
wrapper-manager.packages.${pkgs.system}.default
```

# 3. Exceptions

Simple binaries without complex environment configurations.

# 4. Validation

Verify complex tools avoid global `environment.systemPackages` pollution and any other solution deviating from `wrapper-manager`.

# 5. Migration

Move complex dotfiles and CLI derivations to `wrapper-manager`.
