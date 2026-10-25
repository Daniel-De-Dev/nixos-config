# Identity Data and Public Evaluation

The configuration uses a typed identity interface shared by all hosts. Its
[schema](../../modules/core/identity.nix) declares `my.operator` and `my.host`,
including their defaults. Import `core-identity` when providing these values
directly, or import `core-privacy` to obtain the schema and external data adapter.

The [adapter](../../modules/core/privacy-integration.nix) reads `data.nix` from
`inputs.privacy`, a directory input with `flake = false`. The
[mapper](../../lib/privacy.nix) converts that data to the typed options. Consumers
use those options.

## Remote Input and Bootstrap

The deployment input is set to a private repository.

Use each machine's own GitHub SSH key. Reuse the existing
`~/.ssh/id_ed25519_git`, or generate a new key on that machine if needed and
register its public key with GitHub. A read-only deploy key is sufficient for
a host that only needs to fetch this repository. Never add private key files to
either Nix repository.

On a fresh machine, SSH access must work before evaluating the private input.
The SSH configuration generated from private data cannot bootstrap its own
fetch. If the existing client setup does not already select the right key,
add this temporary block to `~/.ssh/config`:

```sshconfig
Host github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_git
  IdentitiesOnly yes
```

For a passphrase-protected key, load it into the user's running SSH agent with
`ssh-add ~/.ssh/id_ed25519_git`. Verify repository access as that user:

```sh
git ls-remote ssh://git@github.com/Daniel-De-Dev/nixos-privacy.git refs/heads/main
```

The global private SSH rules can provide the same GitHub block after the first
activation, allowing the temporary user configuration to be removed.

Run rebuilds as the normal user and elevate activation with the rebuild tool:

```sh
nixos-rebuild switch --flake .#box-01 --sudo
```

## Commit and Lock Workflow

Commit and push the private `data.nix` changes to `main` first. Then, from the
public configuration repository, update only that input:

```sh
nix flake update privacy
```

Commit the resulting public `flake.lock` together with the configuration changes.
The public lock exposes the private repository URL and revision, not its contents.
Input data is still copied into the locally readable Nix store. This setup keeps
it out of public source control rather than hiding it from local users.

For uncommitted local development, override the input without changing the lock:

```sh
nix eval .#nixosConfigurations.box-01.config.system.build.toplevel.drvPath \
  --override-input privacy path:../nixos-privacy --no-write-lock-file
```

Adjust that relative path to the local private repository. The remote input
always uses the locked commit. Editing a local clone alone does not change it.

## Public Checks

From the repository root, use the public fixture explicitly:

```bash
nix flake check --override-input privacy path:./tests/fixtures/privacy --no-write-lock-file
```

The [fixture](../../tests/fixtures/privacy/data.nix) contains a locked password
value and a public SSH key with a discarded private key. Use it for evaluation
and checks. Use real private data for a system you intend to deploy.

## Data Mapping and Overrides

`global` contains data shared by all hosts. Optional `profiles.<name>` entries
contain data shared by selected hosts. A host opts into them with a `profiles`
list, then supplies its own overrides alongside that list:

```nix
{
  global = {
    operator.email = "operator@example.invalid";
    ssh.matchBlocks."github.com" = {
      user = "git";
      identityFile = "~/.ssh/id_ed25519_git";
      identitiesOnly = true;
    };
  };
  profiles.university.ssh.matchBlocks.cluster = {
    hostname = "cluster.example.invalid";
    user = "student";
    identityFile = "~/.ssh/id_ed25519_uni";
    identitiesOnly = true;
  };
  hosts = {
    box-01 = {
      profiles = [ "university" ];
      hostName = "workstation";
    };
    box-02.hostName = "laptop";
  };
}
```

Precedence is `global -> selected profiles, in list order -> host`. The mapper
recursively merges attribute sets. Later scalar or list values replace earlier
ones. A host-specific `ssh.authorizedKeys` list therefore replaces the inherited
list, and `[ ]` explicitly clears it. To extend a list, use ordinary Nix `let`
bindings and `++` in `data.nix`. SSH match blocks with different names accumulate.
Matching names merge their individual options using the same precedence.

Omitting the host's `profiles` list is equivalent to `[ ]` and preserves the
original global/host behavior. Selection is explicit per host. Profiles do not
implicitly inherit other profiles. Missing or malformed selected profiles fail
with a message identifying the data path. Profile metadata is not exposed as a
system option.

The `machine` value from `specialArgs` is the stable configuration key, such as
`box-01`, distinct from the network `hostName` and eight-hex-digit `hostId`.
Locale data remains alongside `operator` at any layer, rather than inside it.

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
| Invalid profiles container, invalid host profile list, unknown profile, or malformed selected profile     | Fail with a message identifying the profile or selection.                                 |
| A supplied value has the wrong option type                                                                | Fail through the module option type check. Host IDs require eight hexadecimal characters. |
| The operator retains the fallback password `!`, or SSH password login is disabled without authorized keys | The existing operator assertions fail when evaluating a complete host.                    |
| `data.nix` has a syntax or evaluation error                                                               | Evaluation fails. Field defaults do not repair invalid Nix code.                          |

## Verification

`checks.x86_64-linux.privacy-schema` runs the
[identity tests](../../tests/privacy.nix), covering mapping, types, precedence,
adapter inputs, and the operator's authentication assertions. The check uses the
library from the locked `nixpkgs` input. The public fixture selects a shared
evaluation profile for both hosts, exercising profiles through the real adapter.
The public `nix flake check` command also
evaluates the declared host configurations. Successful evaluation does not
establish runtime or hardware behavior. Validate deployment builds with real
private input.
