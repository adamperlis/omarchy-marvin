# Omarchy 4 theming: what a theme can and cannot control

Researched against `basecamp/omarchy` @ `4.0.0.alpha`. This documents the
platform surface only. Design decisions live elsewhere.

## The shape of the system

Omarchy 4 replaced Waybar with a QML shell (`omarchy-shell`). Theme values
reach it through two singletons:

- `Color` — palette and per-surface color roles (`Color.menu.border`)
- `Style` — spacing, type scale, control states, border specs, bar sizing

Both are fed from two files in the active theme:

| File | Carries |
|------|---------|
| `colors.toml` | The palette. Semantic keys, ANSI 16, and arbitrary extra keys. |
| `shell.toml` | Design tokens: spacing scale, type scale, control states, borders, per-surface color roles. |

`shell.<section>.toml` overrides exactly one section of the generated
`shell.toml` (e.g. `shell.lock.toml` replaces `[lock]`). The filename picks
the section; the `[header]` is optional.

## Theme activation

`omarchy-theme-set <name>`:

1. Copies `themes/<name>/` into a staging dir.
2. Overlays `~/.config/omarchy/themes/<name>/` — **in full** if the user wrote
   it, **filtered** if it came from a git clone.
3. Generates `colors.toml` from `alacritty.toml` if absent (legacy path).
4. Runs `omarchy-theme-set-templates`, rendering `default/themed/*.tpl`.
   **A template never overwrites a file the theme already shipped.**
5. Atomically swaps staging into `~/.local/state/omarchy/current/theme`.
6. Fires the `theme-set` hook and retints running apps in parallel.

User templates in `~/.config/omarchy/themed/*.tpl` are processed before
built-ins, and a matching output filename suppresses the built-in entirely.

## Hard constraint: git-installed themes are filtered

`omarchy theme install <url>` clones into `~/.config/omarchy/themes/<name>/`.
A `.git` directory there marks the theme as third-party, and staging drops
anything that can execute code:

- **any `*.lua`** — so no `hyprland.lua`, no `neovim.lua`, no `gum_env.lua`
- **`alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`** — a terminal
  config names the program the terminal launches
- **`vscode.json`** — names an extension to install
- **all symlinks, at any depth**

Dropped files are named on stderr and regenerated from templates instead.

Everything that is only colour is kept: `shell.toml`, `btop.theme`,
`chromium.theme`, `helix.toml`, `icons.theme`, `keyboard.rgb`, `backgrounds/`,
`preview.png`, `preview-unlock.png`, `unlock.png`, `light.mode`.

### The loophole

`colors.toml` accepts arbitrary keys, and those keys substitute into the
generated templates. So a git-installed theme still controls Hyprland border
colour without shipping Lua:

```toml
hyprland_active_border   = "rgba(33ccffee) rgba(00ff99ee) 45deg"
hyprland_inactive_border = "rgba(595959aa)"
```

These feed `hyprland.lua.tpl` via `{{ hypr_gradient ... }}`. What is *not*
reachable this way is anything the template does not already emit — window
shadows, for instance, since `hyprland.lua.tpl` only writes border colours.

## Hard constraint: geometry and typeface are not theme tokens

Three things a theme cannot set, confirmed in `shell/Commons/Style.qml`:

| Property | Where it actually comes from |
|----------|------------------------------|
| Corner radius | `Style.cornerRadius` polls `hyprctl` for `decoration:rounding` |
| Window gaps | `Style.gapsOut` polls `hyprctl` for `general:gaps_out`, halved |
| Font family | Hardcoded `"monospace"`, resolved through `fc-match` |

Only font *size* is themeable (`[font] base-size` plus per-token overrides).
Changing radius, gaps, or typeface requires writing user config under
`~/.config/omarchy/` — outside the theme.

`OMARCHY_MENU_FONT` overrides the family for menus only.

## Template placeholder reference

Any `colors.toml` key is available as `{{ key }}`, plus:

| Form | Output |
|------|--------|
| `{{ accent }}` | `#7aa2f7` |
| `{{ accent_strip }}` | `7aa2f7` |
| `{{ accent_rgb }}` | `122,162,247` |
| `{{ mix a b 15% }}` | blended hex (`mix_strip`, `mix_rgb` also exist) |
| `{{ hypr_gradient key fallback }}` | Lua string or `{ colors = {...}, angle = N }` |
| `{{ shell_gradient key fallback }}` | `rgba(..) rgba(..) 45deg` |
| `{{ gradient_start key fallback }}` | first stop as flat hex |

## Palette resolution

`omarchy-theme-color` resolves the cascade every consumer shares. Worth
knowing:

- `cursor` is **forced** to `bright_foreground`. A `cursor` key in
  `colors.toml` is overwritten.
- `selection_background = selection`, `selection_foreground = bright_foreground`.
  Both are derived; setting them directly is redundant.
- There is no `urgent` palette key. The shell's urgent role comes from `red`.
- Missing shades are auto-derived: `dark_background = mix(background, #000, 25%)`,
  `darker_background = 50%`, and every `bright_*` is `mix(base, #fff, 20%)`.
- Mode precedence: `mode` key, then legacy `theme_type`, then a `light.mode`
  file, then background-luminance auto-detect (sum of RGB > 382 is light),
  then dark.
- Key charset is restricted. Values may not contain `|`, `\`, or `&` — they
  are used as `sed` replacement text. Rejected keys are announced on stderr
  and leave a raw `{{ placeholder }}` behind.

## `shell.toml` token inventory

Defaults from `default/themed/shell.toml.tpl` and `Style.qml`.

**`[spacing]`** — `scale` multiplier, `scale-with-font` flag, then per-token px
overrides: `xxs 2, xs 3, sm 4, md 6, lg 8, xl 10, xxl 12, xxxl 14, huge 18`,
plus `control-gap 8, control-padding-x 10, control-padding-y 6,
input-padding-y 7, control-height 28, popup-row-height 28, row-gap 8,
row-padding-x 12, label-gap 4, panel-gap 14, panel-padding 18,
popup-padding 14, dropdown-width 240, searchable-dropdown-width 260,
number-field-width 120, searchable-popup-min-height 220`.

**`[font]`** — `base-size 12` is the rem root. Derived: `caption 0.833,
body-small 0.917, body 1.0, subtitle 1.083, title 1.167, heading 1.333,
display 2.0, display-large 2.333`. Icons: `icon-small = body-small`,
`icon = title`, `icon-large 1.5`. Each is individually pinnable in px.

**`[bar]`** — `background`, `background-alpha`, `text`, `active`,
`scale-with-font`, `size-horizontal 26`, `size-vertical 28`. Also readable
but uncommented in the template: `icon-slot 27`, `icon-canvas 16`,
`icon-font 13`, `status-slot 21`.

**`[controls]`** — five states, each with colour, fill alpha, border, border
width, border alpha: `normal` (0.04 / 0.4), `hover-cursor` (0.08 / 0.25),
`focus` (defaults to hover), `selected` (0.18 / 1.0, border width 0),
plus `pressed-fill-alpha 0.22` and `selection-fill-alpha 0.35`.

**Surface sections** — `[popups] [tooltip] [notifications] [launcher] [menu]
[polkit] [lock] [image-picker]`. Each carries `background`,
`background-alpha`, `text`, `border`, `border-alpha`, and where relevant
`scrim`, `selected-*`, and error states. Clipboard and emoji pickers inherit
`[menu]`.

**Borders** — any `*-border` key accepts a solid colour or a Hyprland-style
gradient. Widths accept CSS-style lists (`2`, `"2 4"`, `"2 4 6"`,
`"2 4 6 8"`), and per-side keys (`border-width-left`) override the list.
Stop alpha and `border-alpha` multiply.

## Assets a theme ships

`backgrounds/` (jpg, png, webp, gif, bmp, and video: mp4, mov, webm, mkv,
m4v, avi), `preview.png`, `preview-unlock.png`, `unlock.png`, `icons.theme`,
`keyboard.rgb`, `light.mode`.

Users overlay their own backgrounds at `~/.config/omarchy/backgrounds/<name>/`.
The active one is the `~/.local/state/omarchy/current/background` symlink;
`omarchy-theme-set` advances it one file per invocation.

## Motion

Motion splits across two engines, and only one of them is reachable.

### Compositor motion — fully controllable, config layer only

Hyprland animation lives in `looknfeel.lua`. Defaults from
`default/hypr/looknfeel.lua`; users override in `~/.config/hypr/looknfeel.lua`.
Hyprland's `speed` unit is deciseconds, so `3.79` is 379ms.

Named curves are declared with `hl.curve(name, { type = "bezier", points = {...} })`.
Upstream declares five:

| Curve | Control points |
|-------|----------------|
| `easeOutQuint` | `{0.23, 1}, {0.32, 1}` |
| `easeInOutCubic` | `{0.65, 0.05}, {0.36, 1}` |
| `linear` | `{0, 0}, {1, 1}` |
| `almostLinear` | `{0.5, 0.5}, {0.75, 1.0}` |
| `quick` | `{0.15, 0}, {0.1, 1}` |

Per-leaf animation is set with
`hl.animation({ leaf, enabled, speed, bezier, style })`:

| Leaf | Speed | ms | Curve | Style |
|------|-------|-----|-------|-------|
| `global` | 10 | 1000 | `default` | |
| `border` | 5.39 | 539 | `easeOutQuint` | |
| `windows` | 3.79 | 379 | `easeOutQuint` | |
| `windowsIn` | 4.1 | 410 | `easeOutQuint` | `popin 87%` |
| `windowsOut` | 1.49 | 149 | `linear` | `popin 87%` |
| `fadeIn` | 1.73 | 173 | `almostLinear` | |
| `fadeOut` | 1.46 | 146 | `almostLinear` | |
| `fade` | 3.03 | 303 | `quick` | |
| `fadeSwitch` | — | — | disabled | |
| `layers` | 3.81 | 381 | `easeOutQuint` | |
| `layersIn` | 4 | 400 | `easeOutQuint` | `fade` |
| `layersOut` | 1.5 | 150 | `linear` | `fade` |
| `fadeLayersIn` | 1.79 | 179 | `almostLinear` | |
| `fadeLayersOut` | 1.39 | 139 | `almostLinear` | |
| `workspaces` | — | — | disabled | |

`qconsole.lua` adds `specialWorkspaceIn` (300ms, `easeOutQuint`, `slide top`)
and `specialWorkspaceOut` (200ms, `easeInOutCubic`, `slide bottom`).

Shell surfaces opt out of compositor animation entirely via layer rules in
`default/hypr/apps/omarchy-shell.lua` — the bar, launcher, menu, image
selector, emoji and clipboard overlays all carry `no_anim = true` and
`animation = "none"`, because they animate themselves in QML.

### Shell motion — not themeable

There are no motion tokens anywhere in the theme system. `shell.toml.tpl`
contains no animation keys, and `Style.qml` parses only four sections —
`font`, `bar`, `spacing`, and `controls`/`style`. There is no `Anim` or
`Motion` singleton in `shell/Commons/`.

Shell motion is hardcoded per component. Across `shell/`, 26 distinct
duration values appear: 0, 35, 50, 55, 60, 70, 100, 110, 120, 140, 160, 180,
200, 220, 240, 260, 320, 400, 420, 550, 600, 650, 800, 900, 950, 1200.
Easings are `OutCubic` (26 uses), `OutQuad` (7), `InQuad` (5), `InOutCubic`
(5), `InOutQuad` (3), `InOutSine` (2), `Linear` (1).

**Consequence:** a theme cannot change how the bar, menus, popups,
notifications, or OSD move. Only compositor-level motion — windows, layers,
fades, borders, workspaces — is ours, and only through the config layer.

## Typography

The shell font family is the fontconfig `monospace` alias, hardcoded in
`Style.qml` (`property string fontFamily: "monospace"`). `docs/omarchy-shell.md`
is explicit: *"themes don't set it, the user does via `omarchy font set`."*
The only override is `OMARCHY_MENU_FONT`, an environment variable that
changes the family for menus alone.

`omarchy font set <name>` rewrites every terminal config (alacritty, kitty,
ghostty, foot) **and** writes `~/.config/fontconfig/fonts.conf` with a
`prepend_first` rule on `monospace`. So setting a proportional UI face that
way would also set every terminal to it. Not viable.

### The scoped-alias path

fontconfig `<test>` accepts `prgname`, and the shell runs as `quickshell`
(`omarchy-restart-shell` calls `quickshell kill -p`). A rule scoped to that
process gives the shell a different `monospace` resolution than everything
else:

```xml
<match target="pattern">
  <test name="prgname"><string>quickshell</string></test>
  <test name="family" qual="any"><string>monospace</string></test>
  <edit name="family" mode="prepend_first" binding="strong">
    <string>Inter</string>
  </edit>
</match>
```

Placed in `~/.config/fontconfig/conf.d/`, it survives `omarchy font set`
(which only rewrites `fonts.conf`). Nerd Font icon glyphs are private-use
codepoints Inter does not carry, so fontconfig's charset fallback walks
the remaining chain and lands on the Nerd Font as before.

`OpticalGlyph` measures glyphs with `TextMetrics.tightBoundingRect` and
corrects horizontally, so proportional families do not break its
centering. `Style.resolvedFontFamily` runs `fc-match monospace` without
`prgname` and will report the terminal font — cosmetic only.

Config layer only. A plain `omarchy theme install` keeps the monospace UI.

## Icons

Shell icons are **text glyphs**, not images. `shell/Ui/OpticalGlyph.qml`
renders a single character from `Style.font.family` at a `Style.font.icon*`
size. The characters are Nerd Font private-use codepoints hardcoded in each
component: 117 distinct glyphs, 185 uses, across 35 files. There is no
central icon map — `weather/Model.js`, `osd/OsdModel.js`, `power/Model.js`
and `audio/Model.js` each keep their own small lookup, and the rest are
inline literals.

Three consequences:

- A theme cannot change which codepoint a component uses.
- An SVG icon set cannot be dropped in; the shell never loads SVG for UI
  glyphs. (`Image` is used only for app icons: tray, notification app
  icons, launcher entries — those come from the freedesktop icon theme
  named in `icons.theme`, a separate axis.)
- The only way to substitute a different icon style is a **font** whose
  glyphs sit at the same codepoints, placed ahead of the Nerd Font in the
  scoped fontconfig chain above.

IBM Carbon ships icons as SVG (`@carbon/icons`); there is no official
Carbon icon font, and Nerd Fonts include no Carbon set. Substituting Carbon
means building a font: map each Nerd Font codepoint the shell uses to a
Carbon SVG, compile with fontTools or FontForge, and prepend it for
`quickshell`. Coverage is bounded by the inventory above plus whatever the
per-model lookups emit at runtime. Glyph advance widths need not match a
monospace cell — `OpticalGlyph` centers on painted bounds.

Carbon draws on a 16px grid with 20, 24 and 32 variants, so icon tokens
should pin to those sizes rather than derive from the type scale
(`icon = title` gives 14 by default).

Config layer only. Degraded install shows Nerd Font glyphs.

## Plugins

Shell widgets are plugins: a directory with `manifest.json` and QML entry
points. Third-party plugins live at the top level of
`~/.config/omarchy/plugins/<id>/` and are plain QML with the same `Style` and
`Color` singletons the shell uses. They run **unsandboxed** inside
`omarchy-shell`, land disabled, and `omarchy plugin enable` talks to the
running shell over IPC.

`omarchy plugin clone omarchy.<id>` copies a built-in and replaces it: the
manifest gains `omarchy.clonedFrom`, the shell disables the source, and the
source's IPC targets keep routing to the clone. A hand-written plugin with
the same `clonedFrom` key behaves identically.

What a plugin can and cannot restyle:

- The popup card chrome — padding, radius, border, background — comes from
  `PopupCard` / `KeyboardPanel`, which read `[popups]` and `cornerRadius`.
  A plugin does not draw it and cannot set the card colour directly.
- `contentHolder` does not clip, so a Rectangle with
  `anchors.margins: -padding` and `radius: Style.cornerRadius` reproduces
  the card's shape beneath the content: that is how a per-widget tint works.
- `Color.shellValues` exposes every `shell.toml` key as `"section.key"`,
  including sections the shell itself never reads, so a theme can carry
  per-widget tokens.
- `omarchy-plugin-validate` is jq-only and checks the manifest and entry
  points; it does not parse QML. There is no QML lint in the repo.

## Config layer mechanics

- `~/.config/hypr/hyprland.lua` is the user's file. It `require`s
  `hypr.looknfeel`, `hypr.bindings` etc. after `default.hypr.omarchy`, and the
  generated theme `hyprland.lua` is loaded inside the defaults. A separate
  `hypr/marvin.lua` required after `hypr.looknfeel` therefore wins over both
  and never edits a file the user wrote, beyond one marked `require` line.
- `~/.config/fontconfig/conf.d/*.conf` is included by the system
  `fonts.conf`; `omarchy font set` only rewrites `fonts.conf`, so a scoped
  rule there survives it.
- `omarchy plugin enable` and `omarchy-plugin-list` go over IPC to the
  running shell; without a session they cannot run. Files can still be
  placed, and the shell picks them up at the next `rescanPlugins`.
- `hyprctl reload` re-reads the Lua config; `omarchy-restart-shell`
  restarts quickshell, which re-resolves fonts.
