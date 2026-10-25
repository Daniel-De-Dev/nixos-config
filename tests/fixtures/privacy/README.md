# Privacy Evaluation Fixture

This input contains public test identity data for evaluating both hosts without
the private repository.

From the repository root:

```bash
nix flake check --override-input privacy path:./tests/fixtures/privacy --no-write-lock-file
```

Use this override for evaluation checks. Use your real private input when
building a system you intend to deploy. The override is not written to the lock
file, and it is not the default deployment input.

The [privacy tests](../../privacy.nix) exercise data mapping, type validation,
default precedence, ordered profile selection, and the operator's existing
authentication assertions. Both fixture hosts select the shared `evaluation`
profile to obtain their test SSH authorized key.
See the [identity guide](../../../docs/guides/privacy.md) for the data format,
override precedence, and failure behavior.
