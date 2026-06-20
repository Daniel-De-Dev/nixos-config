---
id: DEC-004
kind: decision
topic: dendritic_structure
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
---

> [!summary]
> Records the decision to adopt the Dendritic pattern for module organization to eliminate location dependence and default index files.

# 1. Context

Standard module directories depend on file location and require `default.nix` indexes.

# 2. Decision

Adopt the [Dendritic Pattern](https://github.com/mightyiam/dendritic) for configuration structure.

# 3. Rationale

Makes modules easily movable. Eliminates location dependence. Renders `default.nix` files obsolete.

# 4. Consequences

Requires importing each module individually for each host. Resolved by defining collection modules (like `core`) that bundle related imports.

# 5. Alternatives

Standard hierarchical directories with manual `default.nix` exports.
