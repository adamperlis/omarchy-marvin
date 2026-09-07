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
- **Unit 32.** Bar height, control height, and popup row height all equal
  32, so the bar is never off by a pixel from the popups it opens.
- **Radius 16 = unit / 2.** A 32px control is automatically a pill. Cards
  get a 16px corner.
- **Padding = radius.** Popup padding 16. Content origin sits at the center
  of the corner arc, so content never collides with the curve.
- The grid is **fixed**, not fluid. `[font]` and `[spacing]` per-token
  overrides do not scale with `base-size` (only `[bar]` does), so a pinned
  grid must set `scale-with-font = false` everywhere and ship density
  presets instead of pretending to scale.

## Type

- **Family: Inter** — proposed. Installed through a `prgname`-scoped
  fontconfig rule so terminals keep their monospace face. In the official
  Arch repos as `inter-font`. Config layer only.
- **Scale, pinned: 11 / 13 / 15 / 18 / 24 / 48** — confirmed. Minimum step
  2px. `caption` and `body-small` both pin to 11; `body` and `subtitle`
  both pin to 13. Two tokens that cannot be told apart become one value.
  `display-large` is 48 because every consumer of it in the shell is a
  hero numeral or glyph — the battery percentage, the media art placeholder,
  the clipboard preview — and a hero numeral has to be large to be one.
- **Large type is tracked in.** Inter is fit for text sizes; at 48 the
  numerals sit loose. Tracking derives from the size so it scales with the
  token: `−0.03em` at `display-large`, `−0.01em` at `display`, none below.
  In QML: `font.letterSpacing: -Style.font.displayLarge * 0.03`. Hero
  numerals use proportional figures, never tabular — tabular spacing is
  for columns, and a hero number is not in a column. Confirmed.
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
- App icons resolve through **Yaru**; the color variant follows the accent.

## Surfaces and depth

Extracted from the reference; proposed as rules.

- **Depth from surfaces, not outlines.** `border-width = 0` on shell
  surfaces. Edge comes from tone difference and, in the config layer,
  `decoration.shadow`.
- **No dividers.** Rows separate by whitespace — a full unit — not
  hairlines.
- **Tone is a surface property.** Structure is invariant; each surface
  picks a tone: default, inverted, tinted, media. Omarchy exposes this
  directly through per-section `background` / `text`. Per-widget tone goes
  in a `[marvin-<widget>]` section of `shell.toml` (the shell's parser takes
  any section name) and the widget reads it from `Color.shellValues`; the
  theme owns the tint, the plugin owns only geometry. Tint text and muted
  clear the same 10:1 and 4.5:1 floors as the palette, tested.
- **Controls are the text color at alpha**, so they survive any tone.
  Upstream's model is right and its values are too faint (0.04 normal).
  Target roughly 0.06–0.08 on light surfaces, 0.12–0.16 on dark.
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

Confirmed. A famous painting, public domain, blurred past recognition into a
colour field, graded so it complements the palette: saturation down, mixed
toward the ground, luminance in a band the bar reads over (dark 0.01–0.17,
light 0.60–0.86), fine grain against banding. `tools/background.py` is the
rule made executable. Shipped set is palette-synthesised until a source
painting is supplied.

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
