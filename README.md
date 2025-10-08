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
    └── default.nix                     # List of modules enabled for every host
```

## Making a new host

1. Make a new directory `./hosts/<hostname>`
1. Generate the default configurations files `nixos-generate-config --dir ./hosts/<hostname>`
1. Create `./hosts/<hostname>/meta.nix` which follows the structure of `./modules/core/meta.nix`
1. Still work in progress, i'll see how i proceed
