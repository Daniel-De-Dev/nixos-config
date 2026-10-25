---
id: DEC-002
kind: decision
topic: external_privacy_repo
status: active
applies_to:
  - /modules/core/privacy-integration.nix
last_updated: 2026-10-25
---

> [!summary]
> Records the decision to isolate sensitive data in an external repository.

# 1. Context

Main repository is public. System requires sensitive user data including hashes, SSH keys, emails, and network configurations.

# 2. Decision

Store sensitive identity data in a private GitHub repository (`nixos-privacy`).
Fetch it over SSH via `inputs.privacy` with `flake = false`, then import `data.nix`.
The main configuration's lock file pins the private Git revision.

# 3. Rationale

Keeps identifying data out of the public configuration while making its version
reproducible. Optional named profiles share data across subsets of hosts. Missing
input uses schema defaults; invalid supplied data fails rather than being hidden.

# 4. Consequences

Each machine must have working SSH access before its first private evaluation.
A manual clone is only needed for editing or local overrides. Commit and push
private changes before updating the main configuration's privacy lock entry.
The private repository's own flake may remain for tooling, independently of how
the main configuration consumes its data. Input data is locally readable in the
Nix store; this decision does not provide runtime secret storage.

# 5. Alternatives

sops-nix / agenix. Rejected due to key management overhead for simple strings and runtime installation behavior.
