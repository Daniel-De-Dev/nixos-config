# nixos-config

A Nixos config meant for mutliple hosts and high level of modularity. Idea
being that modules can be toggled on/off and everything will configure itself
where only thing that would need configuration is the hosts themselves, the
modules it needs enabled and defintion of what hardware it has.

Config will be very fine tuned for my spesfic setup and needs.

## Directory layout

```
.
├── flake.nix                           # Flake entrypoint
├── hosts/                              # One directory per host
│   ├── <hostname>/
│   │   ├── meta.nix                    # Host metadata
│   │   ├── config.nix                  # Host-specific logic, imports, options
│   │   └── hardware-configuration.nix  # Machine-generated hardware profile
├── lib/                                # Shared library helpers
│   └── default.nix                     # mkHostConfiguration helper
└── modules/
    ├── core/                           # Global options and secure defaults
    └── my/                             # Custom options for info about host
```

## Making a new host

1. Make a new directory `./hosts/<hostname>`
1. Generate the default configurations files `nixos-generate-config --dir ./hosts/<hostname>`
1. Still work in progress, i'll see how i proceed

## Using a Private Repository (Bootstrap Guide)

To keep personal information (like locale settings, usernames, or email
addresses) out of this public repository, this configuration uses a `privacy`
module. This separates the public configuration logic from your private,
host-specific data.

But, because Nix needs to fetch this repository *before* it can build your
system, there is a one-time "chicken-and-egg" problem to solve.

The solution is a two-stage build process.

1.  **First Build:** You'll build the system *without* the private repository.
This build's only job would be to **add an SSH rule** to your system so it
learns how to access the private repo.
2.  **Second Build:** Now that your system has the SSH rule, you'll build it
again *with* the private repository enabled. This build will succeed.

> [!NOTE]
> There might be possible simplifications when installing trough nix installer
> image by manually adding the ssh rule, but has not been tested

### Stage 1: Apply the SSH Configuration

On a new machine, you must first tell your system how to resolve the private
repository's address.

1.  **Edit `flake.nix`:**
    Open `flake.nix` and comment out the `privacy` input:

    ```nix
    # in flake.nix
    {
      inputs = {
        # ...

        # 1. COMMENT OUT THIS INPUT FOR THE FIRST BUILD
        # privacy = {
        #   url = "git+ssh://nixos-privacy/<user>/<repo>.git";
        #   flake = false;
        # };
      };
      # ... rest of your flake ...
    }
    ```

2.  **Edit Host Configuration:**
    Open your host's configuration file (e.g., `hosts/<yourHost>/configuration.nix`)
    and enable the `my.privacy.gitRepo` module. You **must** set the `sshKey`
    path to your secret key (as a string).

    **Note:** You must manually copy your private SSH key to this path *before*
    running the build.

    ```nix
    # in hosts/<yourHost>/configuration.nix
    { pkgs, ... }: {

      my.privacy = {
        # 2. You can leave this enabled; it will just load an empty set for now.
        enable = false;

        # 3. Enable the gitRepo module and set the key path
        gitRepo = {
          enable = true;
          sshKey = "/etc/nixos/secrets/id_ed25519_privacy";
        };
      };

      # ... rest of your configuration ...
    }
    ```

3.  **Run the First Build:**
    Now, apply this configuration.

    ```bash
    sudo nixos-rebuild switch --flake .#your-host
    ```

    This build will succeed and install a new rule in `/etc/ssh/ssh_config`
    that defines the `nixos-privacy` host alias.

### Stage 2: Enable the Private Repository

Now that your system has the SSH rule, you can safely fetch the private repository.

1.  **Edit `flake.nix`:**
    Go back to your `flake.nix` and uncomment the `privacy` input. Make sure
    its URL uses the `git+ssh://nixos-privacy/` alias.

    ```nix
    # in flake.nix
    {
      inputs = {
        # ...

        # 1. UNCOMMENT THIS INPUT
        privacy = {
          url = "git+ssh://nixos-privacy/<user>/<repo>.git";
          flake = false;
        };
      };
      # ... rest of your flake ...
    }
    ```

2.  **Run the Second Build:**
    Run the build command one more time.

    ```bash
    sudo nixos-rebuild switch --flake .#your-host
    ```

Nix will now successfully use your SSH key and the `nixos-privacy` alias to
fetch your private repository, and your system will build with all your private
data. Your setup is complete


### How It Works
1. **Flake Input**: The system relies on a flake input named `privacy`.
You must point this input to a private Git repository containing your personal
data. This can be done by overriding the input in your `flake.lock` file.

1. **Data Structure**: The private repository must contain a `hosts/`
directory, with a separate `.nix` file for each host (like `hosts/titan.nix`).
Each file must return a Nix attribute set.

1. **Enabling Per-Host**: To use this feature, you must explicitly enable it
for each host by setting `my.privacy.enable = true;` in its configuration.

If enabled, the module will load the corresponding file from your private
repository and make the data available at `config.my.privacy.data`. The build
will fail with a descriptive error if the `privacy` input is missing or the
host-specific file cannot be found, making sure the configuration is always
correct.

## Think Out Loud Section

I cant yet figure out how i want to structure this config. The idea im left with
is having `config.my` where `my` attribute will be defined to hold information
about the host nix cant possibly know.

For example, disk information, define `config.my.disk.<disk_idetifier>.type = "ssd"`,
which could allow other modules to enable special options to optimize for ssd's.

But then complexity arises where for that to be useful a relation between disks,
partitions and file systems has to be made, atleast from my current understanding.
I'll leave this idea behind for now so i dont get stuck on this.

Moving on looking at the defintion for user(s), i stumble on a question regarding
"How much do i want to abstract?". Let's say i want to define a user using
`config.my.users.<username>` with options, that would basically be re-impleming
the existing `users.users.<name>`. Rendering it really just useless.

So i will for now atleast not be doing this, ill simply implement a spesific "hardcoded"
implementation for `titan` and eventually expand `config.my` and/or create modules
as i see fit with the main purpose for the attributes under `config.my` to
answer this with **yes**: `Does it provide information to NixOS previously not known?`
, meaning my idea about disks would be useful, but i just lack the knowledge to
yet implementing and structure it in a way that makese sense.

Atleast `config.my.host` feels like it belongs there as it gives NixOS information
it didnt have.
