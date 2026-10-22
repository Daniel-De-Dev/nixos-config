# Identity Data and Public Evaluation

The configuration uses a typed identity interface shared by all hosts. Its
[schema](../../modules/core/identity.nix) declares `my.operator` and `my.host`,
including their defaults. Import `core-identity` when providing these values
directly, or import `core-privacy` to obtain the schema and external data adapter.

The [adapter](../../modules/core/privacy-integration.nix) reads `data.nix` from
`inputs.privacy`, a directory input with `flake = false`. The
[mapper](../../lib/privacy.nix) converts that data to the typed options. Consumers
use those options.

## Public Checks

From the repository root, use the public fixture explicitly:

```bash
nix flake check --override-input privacy path:./tests/fixtures/privacy --no-write-lock-file
```

The [fixture](../../tests/fixtures/privacy/data.nix) contains a locked password
value and a public SSH key with a discarded private key. Use it for evaluation
and checks. Use real private data for a system you intend to deploy.

## Data Mapping and Overrides

`global` contains shared data and `hosts.<machine>` supplies overrides for the
selected host. The `machine` value from `specialArgs` is the stable
configuration key, such as `box-01`. `hostName` may set a different network
hostname.

The mapper recursively merges the global and host attribute sets. Host values
win when both sides are not attribute sets, so host lists replace global lists.
For example, `hosts.box-01.ssh.authorizedKeys` replaces the global key list.
Locale data remains at `global.locale` or `hosts.<machine>.locale`, alongside
`operator`, rather than inside it.

Supplied values become `lib.mkDefault` definitions. Ordinary host definitions
take precedence. Missing fields use the schema's option defaults, allowing a
profile's `lib.mkDefault` to supply them. Two differing scalar `mkDefault`
definitions at the same priority still conflict. An explicit host definition
can resolve that conflict. Unknown metadata is not forwarded to the typed API.

## Failure Behavior

| Condition                                                                                                 | Result                                                                                    |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| No `privacy` entry in `inputs`, or an explicit `null` input                                               | Use schema defaults and the supplied machine name.                                        |
| No machine name and no data-provided hostname                                                             | Use `nixos` as the hostname.                                                              |
| No matching host entry                                                                                    | Keep global data and use the machine key unless `hostName` is provided.                   |
| A supplied directory has no `data.nix`                                                                    | Fail with a message identifying the missing file.                                         |
| Invalid root, global, selected host, or mapped group shape                                                | Fail with a message naming the invalid attribute set.                                     |
| A supplied value has the wrong option type                                                                | Fail through the module option type check. Host IDs require eight hexadecimal characters. |
| The operator retains the fallback password `!`, or SSH password login is disabled without authorized keys | The existing operator assertions fail when evaluating a complete host.                    |
| `data.nix` has a syntax or evaluation error                                                               | Evaluation fails. Field defaults do not repair invalid Nix code.                          |

The broad fallback wording in [ARCH-002](../architecture/ARCH-002-privacy_data_bus.md)
and [DEC-002](../decisions/DEC-002-external_privacy_repo.md) must be read with these
limits. This guide describes current behavior without rewriting those records.

## Verification

`checks.x86_64-linux.privacy-schema` runs the
[identity tests](../../tests/privacy.nix), covering mapping, types, precedence,
adapter inputs, and the operator's authentication assertions. The check uses the
library from the locked `nixpkgs` input. The public `nix flake check` command also
evaluates the declared host configurations. Successful evaluation does not
establish runtime or hardware behavior. Validate deployment builds with real
private input.
