---
id: ARCH-002
kind: architecture
topic: privacy_data_bus
status: active
applies_to:
  - /modules/core/privacy-integration.nix
last_updated: 2026-07-18
related:
  - DEC-002
  - ARCH-001
---

> [!summary]
> Define privacy data bus. Map external untyped repository data to typed system API.

# 1. Responsibilities

Route `inputs.privacy` to `config.my.operator` and `config.my.host`. Provide safe fallback. Prevent evaluation crash if data missing. Enforce strict type schema.

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
  hosts = {
    "box-01" = {
      hostName = "...";
      hostId = "...";
    };
  };
}
```
