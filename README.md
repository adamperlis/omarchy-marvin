# Marvin

A design system for [Omarchy 4](https://omarchy.org), delivered as a theme,
a reversible config layer, and fourteen restyled widgets.

Omarchy's stock look is assembled rather than designed: an irregular spacing
ramp, six type sizes crammed between 10 and 16px, every surface the same
colour with a gradient border doing the work of depth, hover and keyboard
focus drawn identically. Marvin replaces that with a small number of rules
and applies them everywhere — the bar, every popup, the launcher,
notifications, the lock screen, the window manager's motion — so the desktop
reads as one object.

Named for [Marvin Schwaibold](https://x.com/MSchwaibold). The method —
understand the grid, set a clean type scale, art-direct a few key widgets,
then propagate — is his, and his widget studies are the visual reference. He
is not involved in this project; the name is a credit, not an endorsement.

## The system in one screen

| | Rule | Value |
|---|---|---|
| **Grid** | base 4, module 8, unit 32 | bar, controls and popup rows are all 32px |
| **Radius** | half the unit, one radius for everything | 16px — cards, pills, windows |
| **Padding** | equals the radius | 16px, so content sits at the centre of the corner arc |
| **Type** | Inter, pinned scale, every step perceptible | 11 / 13 / 15 / 18 / 24 / 48; hero numerals tracked −0.03em |
| **Colour** | true-neutral ramp, one accent, one attention role | accent `#7aa6ff` / `#2a63d8`; attention amber, not terminal red |
| **Text** | two tones, no third | foreground and muted |
| **Depth** | surfaces, not outlines | no borders, no dividers; shadow in the config layer |
| **Tone** | a property of each surface | bar is base, popups are raised, weather is tinted |
| **State** | emphasis rises in one direction; focus ≠ hover | fills 0.06 → 0.10 → 0.14 → 0.18; focus is a 2px accent ring |
| **Progress** | a hairline | 2px, track at 0.06, fill foreground or accent |
| **Motion** | a scale, exits faster than entrances | 120 / 200 / 320 ms, exits at 0.6; workspaces slide, borders don't linger |
| **Icons** | Material Design Icons on their own grid | 16 / 20 / 24 |

Every one of those is measured, not eyeballed: contrast floors, parser
compatibility, dark/light geometry identity and the install/revert round-trip
run under `./test/run`. The reasoning behind each rule, and what is still
open, is in [`docs/principles.md`](docs/principles.md). How the pieces fit
together is in [`docs/system.md`](docs/system.md).

## Install

### 1. The theme

```
omarchy theme install https://github.com/adamperlis/omarchy-marvin
omarchy theme set marvin
```

This alone gives you the palette, the grid, the type scale, borderless
surfaces, the state model, quiet neutral window borders, wallpapers, and the
boot logo. It is everything a theme file can carry, and it has to look
intentional by itself — a plain install is the honest baseline.

What a theme file *cannot* carry in Omarchy 4: window rounding and gaps, the
shell's typeface, shadows, compositor motion, and widget layouts. Those are
the config layer.

### 2. The config layer

```
~/.config/omarchy/themes/marvin/install/marvin
```

Adds, in order:

- **`marvin-light`** — the same geometry over a light tone table.
  `omarchy theme set marvin-light` to switch.
- **Inter for the shell** — through a fontconfig rule scoped to the shell's
  process, so your terminal font is untouched and `omarchy font set` keeps
  working. Installs `inter-font` with `sudo pacman` if it is missing (one
  prompt).
- **Hyprland** — rounding 16, gaps 8 inside and 16 at the edge, a 1px
  theme-coloured focus border, a shadow in place of surface outlines, and
  the motion scale. Written to `~/.config/hypr/marvin.lua` and required from
  your `hyprland.lua` by one marked line; nothing else of yours is edited.
- **Widgets** — all fourteen plugins, enabled if the shell is running.

Before it changes anything, it snapshots every file it will touch and the
theme that was active. `install/marvin --status` shows what is installed and
what the snapshot holds.

### 3. Widgets by hand

If you would rather enable them one at a time (recommended for a first
test), skip the installer's enable step and:

```
omarchy-shell shell rescanPlugins
omarchy plugin enable marvin.weather      # then marvin.clock, marvin.power, marvin.media …
```

Enabling a clone replaces the built-in in its bar slot; disabling it brings
the built-in back. Plugins are unsandboxed QML and land disabled so you can
read them first. See [`plugins/README.md`](plugins/README.md).

## Put it back

```
install/marvin --revert
```

Restores every touched file byte for byte, removes what did not exist,
re-enables the built-in widgets, and sets your previous theme again. Then, if
you want the theme gone too: `omarchy theme remove marvin`. The only thing
left behind is the Inter package if the installer added it
(`sudo pacman -Rns inter-font`).

This is tested: `test/install-revert` installs against Omarchy's stock
config, simulates the shell enabling the clones, reverts, and fails unless
`~/.config` is identical to before.

## Testing it

Nothing in this repository has been rendered by the Omarchy shell — it was
built against upstream's source and scripts, not on a desktop. The first
real look is yours. [`docs/testing.md`](docs/testing.md) gives the order to
judge it in (theme alone, then config layer, then widgets one at a time with
the shell journal open) and what to send back.

## Repository map

| Path | What |
|------|------|
| `colors.toml`, `shell.toml`, `icons.theme` | The theme. Dark. |
| `light/` | The light sibling: same geometry, different tone table. |
| `backgrounds/`, `light/backgrounds/` | Wallpapers, graded to the ground. |
| `preview.png`, `preview-unlock.png`, `unlock.png` | Theme-switcher preview and the Plymouth boot logo. |
| `config/hypr/marvin.lua` | Rounding, gaps, border, shadow, motion. |
| `config/fontconfig/60-marvin-shell.conf` | Inter for `quickshell` only. |
| `install/marvin` | Installs the config layer; `--revert`, `--status`. |
| `plugins/marvin.*` | Fourteen restyled clones of the built-in widgets. |
| `tools/restyle.py` | The rules as a script; builds a widget from upstream's. |
| `tools/background.py` | Grades a painting (or a palette) into wallpapers. |
| `test/run` | Every check. |
| `docs/system.md` | How the whole thing fits together, and how to change it. |
| `docs/principles.md` | Every design rule, confirmed or proposed, and why. |
| `docs/platform-constraints.md` | What Omarchy 4 lets a theme control, and what it doesn't. |
| `docs/testing.md` | The on-machine test plan. |

## Backgrounds

The wallpaper is the ground the whole system sits on, so it is graded, not
chosen: a painting blurred until nothing is recognisable, saturation pulled
down, mixed toward the theme ground, luminance clamped into a band the bar
stays readable over, grain added against banding.

The shipped set is synthesised from named palettes — the dominant hues of
Monet's *Water Lilies* and *Impression, Sunrise* — because no image host was
reachable from the environment that built it. To grade a real public-domain
painting:

```
tools/background.py --source path/to/monet.jpg --name lilies --index 1
```

It writes both tones. Needs Pillow and numpy.
