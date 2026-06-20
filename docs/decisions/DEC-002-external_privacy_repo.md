---
id: DEC-002
kind: decision
topic: external_privacy_repo
status: active
applies_to:
  - /modules/core/privacy-integration.nix
last_updated: 2026-06-20
---

> [!summary]
> Records the decision to isolate sensitive data in an external repository.

# 1. Context

Main repository is public. System requires sensitive user data including hashes, SSH keys, emails, and network configurations.

# 2. Decision

Store sensitive data in a separate private flake (`nixos-privacy`). Inject via `inputs.privacy`.

# 3. Rationale

Keeps main configuration public. Prevents secret leakage in commit history. Missing data handled gracefully by `privacy-integration.nix`.

# 4. Consequences

Requires manual clone of privacy repository before full system build.

# 5. Alternatives

sops-nix / agenix. Rejected due to key management overhead for simple strings and runtime installation behavior.
