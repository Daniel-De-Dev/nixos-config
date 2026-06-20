---
id: R-PKG-002
kind: rule
topic: script_baking
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
---

> [!summary]
> Defines pattern for parsing and importing shell scripts to prevent runtime dependency failures.

# 1. Rule

Native scripts (`.sh`, `.lua`) MUST be injected into the Nix store via `pkgs.writeShellApplication` or `pkgs.replaceVars`.

# 2. Correct Pattern

```nix
pkgs.writeShellApplication {
  name = "script";
  text = builtins.readFile ./script.sh;
}
```

# 3. Exceptions

None.

# 4. Validation

Review code for raw script path references.

# 5. Migration

Convert existing direct script references to `writeShellApplication` or `replaceVars` derivations.
