# Marvin

A theme for [Omarchy 4](https://omarchy.org), built as a design system first.
Neutral ramp, one accent, no outlines, a fixed 4px grid, and a type scale you
can actually see.

Named for [Marvin Schwaibold](https://x.com/MSchwaibold). The method here —
grid first, then a clean type scale, then art-direct a few key widgets and let
the rest follow — is his, and the widget studies that set the visual reference
are his work. He isn't involved in this project; the name is a credit, not an
endorsement.

```
omarchy theme install https://github.com/adamperlis/omarchy-marvin
```

That gives you `marvin` (dark). The light sibling, the Inter typeface, the
16px rounding, shadows and motion live in the config layer — see `install/`
once it lands.

## What's here

| Path | What |
|------|------|
| `colors.toml`, `shell.toml`, `icons.theme` | The theme. Dark. |
| `light/` | The same geometry over a light tone table. |
| `docs/principles.md` | Every design decision, marked confirmed or proposed. |
| `docs/platform-constraints.md` | What Omarchy 4 lets a theme control, and what it doesn't. |
| `plugins/` | Restyled clones of built-in widgets. Config layer, not theme; see `plugins/README.md`. |
| `test/run` | Contrast floors, parser compatibility, dark/light geometry identity, widget tint floors. |

## Rules that are tested, not eyeballed

- Body text clears 10:1 on every surface; muted text, accent, and every ANSI
  color clear 4.5:1.
- Every line of `shell.toml` matches the shell's own parser, so nothing is
  silently dropped.
- Dark and light share all 94 geometry tokens byte for byte.
- Control emphasis rises monotonically, and focus is never identical to hover.

Run `./test/run`.
