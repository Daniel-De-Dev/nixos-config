---
id: DEC-001
kind: decision
topic: wrapper_manager
status: active
applies_to:
  - /modules/programs/**
last_updated: 2026-06-20
---

> [!summary]
> Records the decision to use wrapper-manager over Home Manager for user-space CLI configurations.

# 1. Context

Need dotfile management for programs like Neovim, Fish, and Git. Require complex environment variables and wrapped binaries. Home Manager introduces heavy state management, bloat, and complexity.

# 2. Decision

Use [`wrapper-manager`](https://github.com/viperML/wrapper-manager) to generate wrapped derivations for user-space tools.

# 3. Rationale

Generates stateless, self-contained packages. Eliminates profile conflicts. Simplifies configuration into pure Nix derivations. Makes dotfiles deterministic with generations.

# 4. Consequences

Configurations live in the Nix store. Users cannot edit files imperatively. Rebuild required for application changes.

# 5. Alternatives

Home Manager (rejected for complexity). NixOS `environment.etc` (rejected for global pollution).
