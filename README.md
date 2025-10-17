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

## Handling Private Data

To keep personal information (like locale settings, usernames, or email
addresses) out of this public repository, this configuration uses a `privacy`
module. This separates the public configuration logic from your private,
host-specific data.

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
