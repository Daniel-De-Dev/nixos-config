---
id: ARCH-001
kind: architecture
topic: system_architecture
status: active
applies_to:
  - /modules/**
last_updated: 2026-06-20
related:
  - DEC-002
---

> [!summary]
> Explains NixOS configuration organization, module boundaries, and configuration flow.

# 1. Responsibilities

- `core`: Baseline system life cycle, networking, security, operator identity. MUST be host agnostic. All hosts SHOULD enable.
- `hardware`: Hardware abstraction layer (GPU, power, boot).
- `desktop`: Display manager and GUI environments.
- `programs`: User-space applications and shell configurations.
- `hosts`: Machine-specific hardware configs and module selection.

# 2. Structure

```text
modules/
├── core/       # Global invariants
├── hardware/   # Hardware abstractions
├── desktop/    # GUI environments
├── programs/   # App configurations
└── hosts/      # Machine definitions
```

Follows Dendritic Pattern

# 3. Data and Dependency Flow

Privacy data injects from external repository (`inputs.privacy`). Data routes into typed `config.my.operator` and `config.my.host` APIs. Downstream modules consume `config.my.*` options.

# 4. Boundaries

Hosts assemble modules. Modules expose `my.*` options. Modules do not import other modules directly.

# 5. Related Documentation

- [DEC-002](DEC-002-external_privacy_repo.md)
- [DEC-004](DEC-004-dendritic_pattern.md)
