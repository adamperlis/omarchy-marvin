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

## Install by hand

```
cp -r plugins/marvin.weather ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
omarchy plugin enable marvin.weather
```

`omarchy plugin enable` talks to the running shell, so do this from a live
session. Validate a plugin without the shell: `omarchy-plugin-validate plugins/marvin.weather`.
