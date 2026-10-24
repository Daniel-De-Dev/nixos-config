# Hyprland Preview

Run from a Wayland session on NixOS:

```sh
nix run .#hyprland -- --mod ALT
```

Omit `--mod ALT` to use SUPER. The desktop starts without application windows.

`nix build .#checks.x86_64-linux.hyprland-config` validates the generated Lua,
both modifier choices, AGS bindings and exclusion of host controls without a GPU.
Rendering and interactive input still need testing in the graphical session.
