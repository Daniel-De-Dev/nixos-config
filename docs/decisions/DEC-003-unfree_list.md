---
id: DEC-003
kind: decision
topic: unfree_packages
status: active
applies_to:
  - /modules/core/unfree.nix
last_updated: 2026-06-20
---

> [!summary]
> Records the decision to use a custom `my.allowedUnfree` list for proprietary software instead of overriding `allowUnfreePredicate`.

# 1. Context

Proprietary software needs whitelisting. Default `allowUnfreePredicate` option does not merge entries across multiple files. Requires defining all unfree packages in a single location.

# 2. Decision

Implement `my.allowedUnfree` custom option. Serve as a list to collect all merged packages and generate the final NixOS option.

# 3. Rationale

Allows appending an unfree entry in the specific module file that imports it. Keeps module dependencies localized.

# 4. Consequences

Must use custom namespace over standard nixpkgs option.

# 5. Alternatives

Override `allowUnfreePredicate` locally. Rejected due to lack of merging capability.
