---
id: ARCH-002
kind: architecture
topic: privacy_data_bus
status: active
applies_to:
  - /modules/core/privacy-integration.nix
last_updated: 2026-10-25
related:
  - DEC-002
  - ARCH-001
---

> [!summary]
> Define privacy data bus. Map external untyped repository data to typed system API.

# 1. Responsibilities

Read `data.nix` from the private Git directory input (`flake = false`) and map it
into typed `config.my.operator` and `config.my.host` options. Missing input uses
schema defaults. Malformed supplied data fails. Complete hosts still enforce the
operator's authentication requirements.

# 2. Structure

Expected external `data.nix` schema:

```nix
{
  global = {
    operator = {
      username = "...";
      hashedPassword = "...";
    };
  };
  profiles.university = {
    ssh.matchBlocks.cluster.hostname = "cluster.example.invalid";
  };
  hosts = {
    "box-01" = {
      profiles = [ "university" ];
      hostName = "...";
      hostId = "...";
    };
  };
}
```

Merge `global`, the host's selected profiles in order, then the host's own data.
Attribute sets merge recursively; later scalars and lists replace earlier ones.
The mapper supplies the result as `mkDefault` values, so explicit system
configuration can override it. Consumers read the typed API, not the raw data.

See [the privacy guide](../guides/privacy.md) for SSH bootstrap, lock updates,
public evaluation, and detailed failure behavior.
