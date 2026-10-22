# Shared Theme and AGS Styles

`my.theme` defines shared visual values to be used across configuration. Import
`self.nixosModules.core-palette` to use the interface in an application module.

## Change the Theme

Edit [`themes/carbon-dark.nix`](../../themes/carbon-dark.nix) to change the
defaults. This is the shared source
for semantic colors, font families, font sizes, and spacing. Application adapters
translate those values into their own configuration formats.

A host can override individual values through normal module configuration:

```nix
my.theme.colors.accent = "#78a9ff";
my.theme.spacing.md = 12;
```

Unspecified values keep their defaults. Colors require six hexadecimal digits
and a leading `#`. Font sizes are positive integers and spacing is non negative,
both in logical pixels. Unknown roles fail evaluation.

`my.theme.fonts.packages` defaults to the IBM Plex Sans and Mono packages. AGS
installs these through `fonts.packages` when enabled. When selecting a different
font, provide both its family name and its package, for example:

```nix
my.theme.fonts = {
  sans = "Noto Sans";
  packages = [ pkgs.noto-fonts ];
};
```

## Default Appearance

The initial preset adapts IBM Carbon's Gray 100 theme for a small desktop shell:

| Role              | Default   | Carbon reference                |
| ----------------- | --------- | ------------------------------- |
| `background`      | `#161616` | Gray 100                        |
| `surface`         | `#262626` | Layer 01 / Gray 90              |
| `surfaceHover`    | `#333333` | Layer 01 hover                  |
| `surfaceSelected` | `#393939` | Layer 01 selected / Gray 80     |
| `surfaceActive`   | `#525252` | Layer 01 active / Gray 70       |
| `text`            | `#f4f4f4` | Primary text / Gray 10          |
| `textMuted`       | `#c6c6c6` | Secondary text / Gray 30        |
| `border`          | `#393939` | Subtle border on the background |
| `borderStrong`    | `#6f6f6f` | Strong border on Layer 01       |
| `accent`          | `#4589ff` | Interactive / Blue 50           |
| `focus`           | `#ffffff` | Focus indicator                 |

The shell uses IBM Plex Sans, square corners, neutral surfaces, and visible focus
indicators. These are local GTK components using Carbon's foundations. White
marks keyboard focus and blue is reserved for interactive emphasis.

## Packaging and Validation

The package builds JavaScript from TypeScript sources only. Nix generates a
separate stylesheet and a small launcher sets `AGS_SHELL_STYLE` to its immutable
store path. Changes to TypeScript rebuild the bundle. Include additional asset
types in the source fileset if future widgets require them.

`nix build .#ags-shell` uses the shared default preset. The NixOS module overrides
the package with `config.my.theme`, so per-host values also reach AGS. A custom
`my.desktop.ags.package` is responsible for its own theme integration.

The `checks.<system>.theme` check validates theme overrides, rejected inputs,
stylesheet generation, and theme-independent bundle identity. Build AGS and
run `nix flake check`, including the public privacy-fixture override when needed.
After rebuilding the host, restart `systemctl --user restart ags.service` and
check search, Enter, clicking a result, and Escape in the real session.

## Sources

- [Carbon color and layering](https://www.carbondesignsystem.com/building-blocks/foundations/color)
- [Carbon semantic color tokens](https://www.carbondesignsystem.com/building-blocks/foundations/color/tokens)
- [Carbon typography](https://www.carbondesignsystem.com/building-blocks/foundations/typography)
- [Carbon spacing](https://www.carbondesignsystem.com/building-blocks/foundations/spacing/overview)
- [GTK3 CSS and symbolic colors](https://docs.gtk.org/gtk3/css-overview.html)
- [Astal GTK3 theming and stylesheet paths](https://aylur.github.io/astal-legacy-docs/guide/typescript/theming)
- [Chromium's BrowserThemeColor policy](https://chromeenterprise.google/policies/browser-theme-color/)
- [Brave's Linux policy location](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy)
