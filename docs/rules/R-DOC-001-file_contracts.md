---
id: R-DOC-001
kind: rule
topic: file_contracts
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
---

> [!summary]
> Standardizes source file documentation headers and compact file contracts.

# 1. Rule

Non-trivial source files MAY use compact file contracts containing `Purpose:`, `Scope:`, and `Invariants:`.

# 2. Correct Pattern

```nix
# Purpose: Baseline runtime hygiene inherited by all managed hosts.
# Scope: Host-agnostic system defaults and lifecycle maintenance.
# Invariants:
# - No hardware, storage, graphics, or desktop assumptions.
# - No `mkIf` feature toggles; hosts opt into this profile explicitly.
# Optional fields:
# Depends on: <important module or data source>
# Excludes: <things that must not be added here>
_: {
  ...
}
```

# 3. Exceptions

Trivial source files require no contract.

# 4. Validation

Check non-trivial files for standard contract.

# 5. Migration

Remove decorative headers. Insert compact contracts in complex modules.
