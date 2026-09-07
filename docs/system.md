# How Marvin fits together

This is the map: what each part is, how a value travels from a file in this
repository to a pixel on the desktop, and where to go to change something.
The rules themselves are in `principles.md`; what the platform allows is in
`platform-constraints.md`.

## Three layers

```
┌──────────────────────────────────────────────────────────────────────┐
│ 1. THEME              omarchy theme install …          filtered, safe │
│   colors.toml   shell.toml   icons.theme   backgrounds/  previews     │
│   → palette, grid, type scale, surfaces, states, window border colour │
├──────────────────────────────────────────────────────────────────────┤
│ 2. CONFIG LAYER       install/marvin                  snapshot+revert │
│   hypr/marvin.lua   fontconfig rule   marvin-light   plugins enabled  │
│   → rounding, gaps, shadow, motion, Inter, the light sibling          │
├──────────────────────────────────────────────────────────────────────┤
│ 3. WIDGETS            plugins/marvin.*                unsandboxed QML │
│   clonedFrom the built-ins; logic upstream's, layout Marvin's         │
│   → what the inside of each card looks like                           │
└──────────────────────────────────────────────────────────────────────┘
```

Each layer works without the ones below it and looks intentional on its own.
The theme alone is what a stranger gets from `omarchy theme install`; it is
the honest baseline, and every choice in it was made knowing rounding,
gaps, typeface and motion might never arrive.

## Layer 1: how the theme reaches the screen

**`colors.toml`** is the palette. Omarchy reads it in two ways:

- `omarchy-theme-set-templates` substitutes every key into
  `default/themed/*.tpl` — terminals, btop, chromium, helix, neovim,
  vscode, and `hyprland.lua`. That last one is why the theme carries
  `hyprland_active_border` and `hyprland_inactive_border`: a git-installed
  theme may not ship Lua, but any key in `colors.toml` flows into the
  generated `hyprland.lua`, so the quiet neutral window borders arrive
  without a line of code.
- The shell's `Color` singleton loads `foreground`, `background`, `accent`,
  `muted` and `red` (as the urgent role) directly.

`attention` is Marvin's own key. No template reads it; `shell.toml`'s
`[bar] active` carries the same hex, so the bar's alert colour is a designed
amber rather than the terminal's error red.

**`shell.toml`** is the design token file. The shell parses it into a flat
`section.key` dictionary and two singletons read from it:

- `Color` — per-surface roles: `[bar] [popups] [tooltip] [notifications]
  [launcher] [menu] [polkit] [lock] [image-picker]`, each with background,
  text, border and alphas. Marvin sets `border-width = 0` on every surface
  and gives the bar the base tone and everything that opens over it the
  raised tone.
- `Style` — `[spacing]`, `[font]`, `[bar]` sizes and `[controls]` states.
  Marvin pins every spacing and type token to the grid and turns
  `scale-with-font` off everywhere, because pinned tokens do not scale and
  the bar does; a fixed grid is the only kind that stays a grid.

Two things `shell.toml` cannot set, because the shell reads them from
elsewhere: **corner radius** (`Style.cornerRadius` polls Hyprland's
`decoration:rounding`) and **font family** (fontconfig's `monospace`). Those
are why the config layer exists.

`shell.toml` also carries sections the shell itself never reads —
`[marvin-weather]` today — because the parser accepts any section name and
a plugin can read `Color.shellValues["marvin-weather.background"]`. That is
how per-widget tone stays in the theme, where both tone tables live, while
the plugin owns only geometry.

**`light/`** is the same `shell.toml` with every colour swapped and every
geometry token identical; `test/shell-toml` fails if the 94 non-colour keys
ever differ. It is installed as a user-written theme (`marvin-light`) by the
config layer rather than as a second git repo.

## Layer 2: what the config layer does and how it is undone

`install/marvin` runs six steps, in this order, each idempotent:

1. **Snapshot.** Copies `hypr/hyprland.lua`, `hypr/marvin.lua`,
   `fontconfig/conf.d/60-marvin-shell.conf`, `omarchy/shell.json`,
   `omarchy/themes/marvin-light` and any existing `marvin.*` plugin
   directories into `~/.local/state/marvin/snapshot`, recording which were
   absent, plus the active theme name. Taken once; a re-run keeps the
   original.
2. **marvin-light.** Copies `light/` to `~/.config/omarchy/themes/marvin-light`.
3. **Inter.** Installs `inter-font` if missing, then places a fontconfig
   rule that says: for the process named `quickshell`, `monospace` resolves
   to Inter first. Terminals never see it; Nerd Font icon glyphs fall
   through to the Nerd Font as before.
4. **Hyprland.** Places `hypr/marvin.lua` and adds one marked
   `require("hypr.marvin")` line after your `require("hypr.looknfeel")`, so
   Marvin's values are the last word on geometry and motion without editing
   anything else you wrote.
5. **Widgets.** Copies `plugins/marvin.*` into `~/.config/omarchy/plugins/`
   and, if the shell is running, enables each.
6. **Apply.** Sets the theme, reloads Hyprland, restarts the shell.

`--revert` reverses it from the snapshot: files back byte for byte, absent
files removed, clones disabled through the shell, and — because enabling a
clone rewrites `shell.json` (your ids into the bar layout, the built-ins
into `disabledPlugins`) — a jq pass that strips `marvin.*` entries and
re-enables every built-in a clone had disabled, for the case where the
shell was not running. Then the previous theme is set. `test/install-revert`
proves the round-trip leaves `~/.config` identical.

## Layer 3: widgets

Omarchy's shell is plugins all the way down; every panel is a directory
with a `manifest.json` and QML entry points. `omarchy plugin clone`
establishes the mechanism Marvin uses: a plugin whose manifest carries
`omarchy.clonedFrom: "omarchy.<id>"` **replaces** the built-in in its bar
slot, and the built-in's IPC targets keep routing to it. Marvin ships
fourteen such clones.

What a clone changes and what it does not:

- **The card chrome is the theme's.** Every panel opens inside
  `PopupCard`/`KeyboardPanel`, whose padding, radius, border and background
  come from `[popups]` and `cornerRadius`. A plugin does not draw its own
  card.
- **The inside is the plugin's.** That is where upstream drifts: a
  temperature at a hardcoded 64px, section headers in bold uppercase with
  letter-spacing, `PanelSeparator` rules between every section, secondary
  text as `Qt.darker(foreground, 1.4)` — a third tone nobody chose.
- **The logic is untouched.** Networking, processes, IPC handlers, keyboard
  cursors, settings persistence: byte for byte upstream's.

Four were built by hand to the reference (weather, clock, power, media).
Ten were built by `tools/restyle.py`, which is the rulebook as a script:
each rule is a text transform over upstream's `Panel.qml`, it reports how
often each fired, and it lists any upstream habit it could not classify.
Run it against a new upstream release and the clone is regenerated.

## Changing things

**A colour.** Edit `colors.toml` (and `light/colors.toml`), then
`./test/run`. The contrast test reads the shipped files and fails on any
pair below its floor; `shell.toml` carries the same hex for the surfaces,
so change both. The tint sections are checked too.

**Density.** Everything is on the 4px grid and pinned; there is no slider by
design. To make a denser preset, copy `shell.toml`, change `[spacing]`,
`[font]` and `[bar]` together, keep the relationships (unit = control
height = row height; radius = unit/2; padding = radius), and run the
geometry test against the light sibling.

**Radius.** One number, `decoration.rounding` in `config/hypr/marvin.lua`;
cards, pills and windows all follow it. A 32px control is a pill only while
the radius is 16.

**Motion.** `config/hypr/marvin.lua`. Three curves and one scale; keep exits
at 0.6 of entrances and keep everything a direct action triggers at or
under 320ms.

**A widget's tone.** Add a `[marvin-<widget>]` section to both `shell.toml`
files with `background`, `text`, `muted` in hex, have the plugin read
`Color.shellValues` with a fallback to `Color.popups.*`, and the tint test
picks it up by the `marvin-` prefix.

**A new widget.** `tools/restyle.py upstream/Panel.qml plugins/marvin.<id>/Panel.qml`,
copy the rest of the upstream directory beside it, write a manifest with
`clonedFrom`, and `omarchy-plugin-validate` it. Read the leftover list;
anything there is a habit the rules do not yet cover.

**A wallpaper.** `tools/background.py --source painting.jpg --name x --index n`
writes both tones with the grading baked in.

## The honest limits

- Shell motion — how the bar, menus and popups animate — is not themeable
  in Omarchy 4 and is not touched. Only compositor motion is Marvin's.
- Icons are Nerd Font glyphs chosen by codepoint inside each component.
  Marvin uses the Material Design Icons set the shell already draws; a
  different set would mean compiling a font at the same codepoints.
- A git-installed theme is filtered: no Lua, no terminal configs, no
  `vscode.json`. Marvin never ships those in the theme; they are exactly
  what the config layer is for.
- Nothing here has been rendered by the shell. See `testing.md`.
