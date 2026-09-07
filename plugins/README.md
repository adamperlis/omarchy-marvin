# Plugins

Restyled clones of Omarchy's built-in widgets. Each is a `clonedFrom` plugin:
the built-in's data, networking and IPC code verbatim, the layout rewritten to
the Marvin rules. Enabling one replaces the built-in in its bar slot, and the
built-in's IPC targets keep routing to it.

Plugins are unsandboxed QML — they are not part of the theme and are never
installed by `omarchy theme install`. They land disabled so you can read them
first.

| Plugin | Clones | What changed |
|--------|--------|--------------|
| `marvin.weather` | `omarchy.weather` | Temperature at `display-large` with the unit as a caption, value-over-label stats, forecast days as columns, no dividers, per-theme tint from `[marvin-weather]` in `shell.toml`. |
| `marvin.clock` | `omarchy.clock` | Day number at `display-large` with month and weekday as its caption, year and life progress as 2px hairlines, month name left with chevrons right, 40×32 grid cells with no gutter line, today as a fill. |
| `marvin.power` | `omarchy.power` | Charge percentage at `display-large`, charge as a 2px hairline, stats as value over label in two columns, profiles as a caption and a row of pills with no divider before them. |

## Install by hand

```
cp -r plugins/marvin.* ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
for p in marvin.weather marvin.clock marvin.power; do omarchy plugin enable $p; done
```

`omarchy plugin enable` talks to the running shell, so do this from a live
session. Validate a plugin without the shell: `omarchy-plugin-validate plugins/marvin.weather`.
