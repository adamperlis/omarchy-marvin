# Marvin: design principles

The rules and why. For how the parts fit together see `system.md`; for what
the platform allows see `platform-constraints.md`; to test it see
`testing.md`.

A theme for Omarchy 4, built as a design system first. Each entry is marked
**confirmed** (agreed) or **proposed** (on the table, not yet accepted).
`docs/platform-constraints.md` records what the platform allows; this file
records what we chose within it.

## Scope and shape

- **Theme + config layer** — confirmed. The installable theme is the core.
  An opt-in installer writes `~/.config/omarchy/` and `~/.config/hypr/`
  overrides for what a theme cannot carry: rounding, gaps, typeface, shadow,
  motion. A plain `omarchy theme install` must still look intentional.
- **One theme, done exceptionally** — confirmed. Principles live here,
  values live in the files. No generator.
- **Reference** — the widget studies of
  [Marvin Schwaibold](https://x.com/MSchwaibold), for whom the theme is
  named: fixed-width cards on a fine grid, generous radius, no borders, two
  text tones, rationed accent, large numerals with small labels, per-surface
  tone. He is not involved in this project.

## Method

Confirmed. Schwaibold's, stated for prompting models on design: *"You have
to get the model to understand the underlying grid system and set a clean
type scale etc — art direct a few key widgets first also to get a general
style and design standard set. After that it gets rather easy."* Sequence
matters more than any single value.

1. Establish the grid.
2. Set the type scale.
3. Art-direct a few key widgets to fix the standard.
4. Propagate. After step 3 the rest is application, not invention.

Proposed key widgets for step 3: the **bar** (always on screen, sets the
density read), the **menu/launcher card** (most-used overlay; its tokens
cascade to clipboard and emoji pickers), and a **notification** (the only
surface that appears unbidden, so it tests restraint).

## Grid

Proposed.

- Base unit **4px**. Spacing ramp: 2, 4, 8, 12, 16, 20, 24, 32, 48.
  `xxs = 2` is a deliberate half-unit for hairline insets; everything else
  is on-grid.
- **Unit 32** for the bar; **rows and controls 40** inside cards, so they
  breathe like the reference. Both on the 8 module.
- **Radius 24.** One radius for cards and windows; a 40px control is a pill
  at radius 20. Chosen to match the reference after seeing it at full size.
- **Padding = radius.** Popup padding 24. Content origin sits at the center
  of the corner arc, so content never collides with the curve.
- Cards are 352 wide (content 304 inside the 24 inset), captions above cards in the muted
  tone, columns 56 apart.
- The grid is **fixed**, not fluid. `[font]` and `[spacing]` per-token
  overrides do not scale with `base-size` (only `[bar]` does), so a pinned
  grid must set `scale-with-font = false` everywhere and ship density
  presets instead of pretending to scale.

## Type

- **Family: Inter** — proposed. Installed through a `prgname`-scoped
  fontconfig rule so terminals keep their monospace face. In the official
  Arch repos as `inter-font`. Config layer only.
- **Scale, pinned: 12 / 14 / 16 / 18 / 24 / 56** — confirmed, one step up
  from the first pass after comparing against the reference at full size. Minimum step
  2px. `caption` and `body-small` both pin to 11; `body` and `subtitle`
  both pin to 13. Two tokens that cannot be told apart become one value.
  `display-large` is 56, regular weight, because every consumer of it in
  the shell is a hero numeral or glyph, and a hero numeral has to be large
  and light to be one.
- **Large type is tracked in.** Inter is fit for text sizes; at 48 the
  numerals sit loose. Tracking derives from the size so it scales with the
  token: `−0.03em` at `display-large`, `−0.01em` at `display`, none below.
  In QML: `font.letterSpacing: -Style.font.displayLarge * 0.03`. Hero
  numerals use proportional figures, never tabular — tabular spacing is
  for columns, and a hero number is not in a column. Confirmed.
- **A second voice only for the words that are yours.** The interface is
  Inter everywhere. Note text in Obsidian is a serif — Libre Baskerville — because
  the reference does exactly this for its note card, and reading prose is
  the one place a second voice belongs. Confirmed.
- **No monospace outside terminals and code.** The reference has none.
  The shell is Inter through the config layer; GTK apps through
  `gsettings`; the group bar through `marvin.lua`; Obsidian and the share
  picker through their stylesheets. A terminal is monospace by nature and
  is not asked to be otherwise. Confirmed.
- **Large numerals, small labels** — confirmed as a rule from the
  reference. The number is the biggest thing on the surface; its unit or
  label drops to caption beside it. Applies to the lock clock, bar clock,
  OSD level.

## Icons

Confirmed.

- **Material Design Icons**, as the shell already wires by codepoint —
  96 of 117 glyphs. No substitution font.
- Sizes pin to **16 / 20 / 24** (`icon-small`, `icon`, `icon-large`), on
  the 4px grid, not derived from the type scale.
- App icons resolve through **Yaru**, in its yellow variant, so folders
  read as manila rather than a saturated block of accent. The reference's
  files view is warm paper, not blue.

## Surfaces and depth

Extracted from the reference; proposed as rules.

- **Depth from surfaces, not outlines.** Every card gets a hairline at 10%
  of the text colour (a hair darker than it first looks right; the
  reference's border is just visible) and, in the config layer, a wide
  faint shadow (range 40, 12%). Never a structural border: no accent, no gradient, never more
  than 1px. The reference uses exactly this pair.
- **No dividers.** Rows separate by whitespace — a full unit — not
  hairlines.
- **Tone is a surface property.** Structure is invariant; each surface
  picks a tone: default, inverted, tinted, media. Omarchy exposes this
  directly through per-section `background` / `text`. Per-widget tone goes
  in a `[marvin-<widget>]` section of `shell.toml` (the shell's parser takes
  any section name) and the widget reads it from `Color.shellValues`; the
  theme owns the tint, the plugin owns only geometry. Tint text and muted
  clear the same 10:1 and 4.5:1 floors as the palette, against every
  gradient stop, tested.
- **Tone varies across the set, not within a card.** The reference's life
  comes from one gradient card, one dark card and white for the rest. So:
  weather is a sky, a vertical gradient that follows the hour: day
  (`background` → `background-end`), sunset in the first and last hour of
  daylight (`sunset` → `sunset-end`), night after dark (`night` →
  `night-end`), read from Open-Meteo's `is_day` and the clock; power
  is the inverted card in both tones with a ring of sixty ticks around the
  numeral, and every other surface stays raised. Applied.
- **State is muted text.** The reference's focus card says "In progress"
  in the muted tone, no chip, no colour; the battery's charging state does
  the same. The one chip in the reference is the note's "Draft", pale
  yellow `#f9ecad` with olive text, and that is the only chip we ship
  (`[marvin-chip]`).
- **Controls are the text color at alpha**, so they survive any tone.
  Upstream's model is right and its values are too faint (0.04 normal).
  The reference's Search pill is #f4f4f4 on white and its button #f1f1f1:
  0.05 of the text colour. Light runs 0.04 / 0.05 / 0.07 / 0.09; dark needs
  more to read at all and runs 0.06 / 0.10 / 0.14 / 0.18. Alphas are the one geometry
  token that differs by tone.
- **One inverted element per surface, and it is the primary action.**
- **Progress is a hairline.** 2–3px; track is foreground at low alpha,
  fill is foreground or accent.
- **Controls size to their label.** A pill never gets a fixed share of a
  row; it takes its content width and the row wraps. Clipped text is a
  bug.
- **Nested radius is concentric**: inner = outer − padding. Not
  enforceable in the shell; a rule for anything we draw ourselves.

## Color

Proposed.

- **Two text tones** — `foreground` and `muted`. No third.
- **Accent is rationed.** It appears rarely enough that it always means
  something; in the reference it is a 6px dot.
- **Semantic color is a soft fill**, never a saturated block: tinted
  surface with darker text of the same hue.
- **Every step in every ramp must be perceptible.** If two values cannot
  be told apart at a glance, one of them should not exist.
- **Contrast floors are measured**, not eyeballed.

## State

Proposed. Direct correction of upstream.

- **State changes move in one direction.** As emphasis rises, fill,
  border, and text rise with it. Never crossed signals (upstream: fill up,
  border down on hover).
- **Focus is always visible and always distinct from hover.** Upstream
  defaults focus to identical values as hover.
- **Never an accent outline on an input.** A focused field is the
  selected fill with a 1px ring of the text colour (0.12 light, 0.24
  dark).
- **One blue, pulled from the reference.** The inbox dots, the activity
  bars and the flight line are all the same sky blue, `#2f93d3`. It is
  the accent and the attention colour both; there is no amber. It clears
  3:1 on white as a graphic; text set in it (links, tags) uses the deeper
  `accent_text`, `#1a72ad`, which clears 4.5. The reference never draws a blue ring; the field
  itself darkens. Applies to the launcher, lock, polkit, Obsidian and the
  share picker.
- **Card geometry is 352 wide, radius 24, inset 24, rows on the 8
  grid.** Music: art beside title (16 · 500), artist (14 · 400) and the
  transport, then a hairline with elapsed and remaining (12 · 400).
  Quick note: the text sits in its own hairline field in the serif, with
  a soft-fill chip below. Both measured off the reference at 1:1.

## Motion

Confirmed, in `config/hypr/marvin.lua`. Compositor motion only — shell motion
is not themeable. The scale is 120 / 200 / 320 ms (1.2 / 2.0 / 3.2 in
Hyprland's deciseconds); exits run at 0.6 of their entrance; three curves —
enter settles, leave accelerates, move is the standard in-out; border gets
the short step and workspaces get the long one, the inverse of upstream.

- Durations come from a **scale**, not a slider. Upstream's speeds (5.39,
  3.79, 4.1, 1.49, 1.73, 1.46, 3.03 …) share no rhythm.
- **Exits are faster than entrances**, by one consistent ratio. Upstream
  uses three different ratios for the same idea.
- **Motion budget follows importance.** Upstream animates `border` at
  539ms — the slowest thing on screen is a border recolor — and disables
  `workspaces` entirely, the most spatially meaningful transition in a
  tiling WM. Invert that.
- **Exits are never linear.** Linear reads as mechanical.
- Direct-manipulation responses stay under ~300ms. The workspace slide at
  320 is the one deliberate exception, because it is the transition that
  tells you where you went.

## Backgrounds

Confirmed. An avant-garde painting, public domain, or an original drawn in
that idiom, blurred into a
colour field, graded so it complements the palette: saturation up (1.5,
the reference's imagery is rich, not pastel), mixed lightly toward the
ground, luminance in a band the bar reads over (dark 0.02–0.34, light
0.30–0.90), fine grain against banding. `tools/background.py` is the
rule made executable. Shipped set: Monet's *Houses of Parliament, Sunset*,
Van Gogh's *Starry Night*, Kandinsky's *Composition VII*, all public domain,
chosen for sharing the system's sky blue, navy, pale yellow and orange.

## Apps

Confirmed. Where an app takes more than colour, the theme or the config
layer gives it the whole system: Obsidian (`obsidian.css`, shipped by the
theme, synced into every vault by Omarchy), the share picker, GTK apps
(font and accent by `gsettings`), the Hyprland group bar. Where an app
takes only colour — btop, Chromium, VS Code, Claude Code, Helix, Neovim,
terminals — the generated templates carry the palette and nothing is
hand-written.

## Widgets

Confirmed: panels first, dashboard later. System widgets are restyled as
`clonedFrom` plugins under `plugins/` — upstream's data code verbatim, the
layout rewritten. Plugins are unsandboxed QML and belong to the config
layer, never the theme. Hand-built: `marvin.weather`, `marvin.clock`, `marvin.power`,
`marvin.media`. Mechanical (`tools/restyle.py`): audio, bluetooth, monitor,
network, tailscale, agents. Any module that can be styled but has no supplied design is
built from the system: the same rules, no new ones.

## Reversibility

Confirmed. The config layer snapshots every file it will touch, and the
active theme, before its first change. `install/marvin --revert` restores
the snapshot: files back byte for byte, absent files removed, built-ins
re-enabled in `shell.json`, previous theme set. With no snapshot it falls
back to removing only what is recognisably Marvin's. `test/install-revert`
fails unless the restore is exact.

## Open

- Default surface tone: light (as the reference), dark (as the audience
  runs), or both as two tone tables over one geometry.
- Windows inherit the 16px radius from `decoration:rounding`; there is no
  separate card radius. Accept, or lower the radius for everything.
- Motion scale values.
- Palette.
