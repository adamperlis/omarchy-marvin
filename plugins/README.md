# Plugins

Restyled clones of Omarchy's built-in widgets, plus two new widgets. Each clone
is a `clonedFrom` plugin: the built-in's data, networking and IPC code verbatim,
the layout rewritten to the Marvin rules. Enabling one replaces the built-in in
its bar slot, and the built-in's IPC targets keep routing to it. The exceptions
are `marvin.mode` (a light/dark control panel) and `marvin.todos` (a to-do
list) — they clone nothing, so you add them to the bar yourself.

Plugins are unsandboxed QML — they are not part of the theme and are never
installed by `omarchy theme install`. They land disabled so you can read them
first.

| Plugin | Clones | What changed |
|--------|--------|--------------|
| `marvin.weather` | `omarchy.weather` | Temperature at `display-large` with the unit as a caption, value-over-label stats, forecast days as columns, no dividers, per-theme tint from `[marvin-weather]` in `shell.toml`. |
| `marvin.clock` | `omarchy.clock` | Day number at `display-large` with month and weekday as its caption, year and life progress as 2px hairlines, month name left with chevrons right, 40×32 grid cells with no gutter line, today as a fill. |
| `marvin.media` | `omarchy.media` | Art at a nested radius, title and artist in two tones, play as the card's one inverted element, a 2px scrub hairline with times as captions, sources as 32px rows. |
| `marvin.audio`, `marvin.bluetooth`, `marvin.monitor`, `marvin.network`, `marvin.tailscale`, `marvin.agents`, `marvin.dropbox`, `marvin.wifiqr`, `marvin.speedtest`, `marvin.disk-speedtest` | the built-in of the same name | Mechanical pass by `tools/restyle.py`: separators out, section headers to muted sentence-case captions, `Qt.darker` collapsed to `muted`, bold to weight, uppercase and letter-spacing off, spacing snapped to the grid, sliders and meters as 2px hairlines, card width 352 (content 304). Logic untouched. |
| `marvin.power` | `omarchy.power` | Charge percentage at `display-large`, charge as a 2px hairline, stats as value over label in two columns, profiles as a caption and a row of pills with no divider before them. |
| `marvin.mode` | — (new) | Not a clone: a light/dark control. A sun in light, a moon in dark; left click opens a panel (appearance, next wallpaper, reduce motion, daily schedule), right click is a quick flip. Calls `marvin-mode` from the config layer. |
| `marvin.todos` | — (new) | Not a clone: a to-do list in the bar. Add tasks, check them off, clear done. Stored in `~/todos.md` (Markdown checkboxes) so Obsidian and OmaWrite share the list. Backed by `marvin-todo`. |

## Install by hand

```
cp -r plugins/marvin.* ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
for p in ~/.config/omarchy/plugins/marvin.*; do omarchy plugin enable $(basename $p); done
```

`omarchy plugin enable` talks to the running shell, so do this from a live
session. Validate a plugin without the shell: `omarchy-plugin-validate plugins/marvin.weather`.

## The mechanical pass

`tools/restyle.py <upstream Panel.qml> <out>` applies the rules as text
transforms and prints how often each fired plus every upstream habit it
could not classify. A module with no supplied design is built exactly this
way: the system, no new rules.

## License

Every plugin here reproduces the built-in it clones, which is Omarchy's code
under MIT; that notice is in `LICENSE-omarchy`. The changes are MIT under the
repository's `LICENSE`.
