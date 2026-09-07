# Testing Marvin on a machine

Nothing in this repo has been rendered by the Omarchy shell — the environment
it was built in has no quickshell. Everything below was verified against
upstream's source and scripts; the first real look is yours. Go in this order
so each layer is judged on its own.

## 0. Before you start

`omarchy theme install` clones the repo's **default branch**. Until this work
is merged, either merge it first or check the branch out after installing:

```
omarchy theme install https://github.com/adamperlis/omarchy-marvin
git -C ~/.config/omarchy/themes/marvin checkout claude/omarchy-design-system-0vzriw
omarchy theme set marvin
```

Keep a terminal open on the shell's log. Every QML error a plugin throws
lands here, with file and line:

```
journalctl --user -t omarchy-shell -f
```

## 1. The theme alone (what a stranger gets)

No config layer yet. This is the degraded install and it has to look
intentional on its own.

- Bar is 32px, popups have 24px padding, a hairline border, 14px text.
- Window borders are quiet neutral hairlines, not the cyan–green gradient.
- Launcher rows are 40px pills; the selected row is a fill, text stays
  foreground; the search field shows a 2px accent focus ring.
- Notifications: no border, two text tones, accent countdown hairline.
- Lock screen: no idle border; typing shows the accent ring; a wrong
  password shows the red ring.
- `omarchy dev theme-preview marvin` prints the palette ramp.

Expect: rounding is still whatever you had (0 by default), the shell font is
still your monospace, shadows are off. Those are the config layer's.

## 2. The config layer

```
~/.config/omarchy/themes/marvin/install/marvin
```

It snapshots first, then applies. `sudo` will prompt once if Inter is not
installed. Then check:

- Windows and every card round at 24; gaps are 8 inside, 24 at the edge.
- Shadows under cards and windows; the focused window has a 1px hairline.
- The bar and every popup are in Inter. Open a terminal: still monospace.
- Motion: open and close a window, switch workspaces (they slide now),
  change focus (the border recolours quickly, not over half a second).
- `omarchy theme set marvin-light` works and swaps only tone.
- Open Files: Inter, blue accent on selection. Open Obsidian: Inter chrome, note text in Libre Baskerville, hairline panes,
  neutral headings, tag chips; code blocks are the only monospace. Lock the
  screen: the wordmark and a pill input with an accent ring while typing.
  Trigger a polkit prompt (change the power profile): the dialog is a card. Group two windows (`SUPER+G`): the group bar is Inter on a
  32px row.
- `install/marvin --status` lists everything and the snapshot.

## 3. Widgets, one at a time

The installer copies all fourteen and enables them if the shell was
running. If it was not, enable them yourself — **one at a time, watching
the log**, so a failure is attributable:

```
omarchy-shell shell rescanPlugins
omarchy plugin enable marvin.weather     # then clock, power, media, audio …
```

Enabling a clone replaces the built-in in its bar slot. For each:

| Plugin | Open it | Look for |
|--------|---------|----------|
| weather | click the weather pill | tinted blue card, 48px temperature with the unit as a caption, forecast as columns, no rule |
| clock | click the clock | 48px day number, month/weekday caption, 2px year hairline, grid with no lines, today as a fill |
| power | click the battery | 48px percentage, 2px charge hairline, stats value-over-label, profile pills sized to their label |
| media | right-click the now-playing strip | art at 8px radius, inverted play circle, 2px scrub hairline with times |
| audio, bluetooth, monitor, network, tailscale, agents … | click each | no separators, sentence-case muted section captions, hairline sliders, 32px rows, card width 352 |

If a panel does not open, the log has the QML error. Paste it back; the
fix is usually one line.

## 4. Revert

```
install/marvin --revert
```

Everything under `~/.config` that the installer touched comes back byte
for byte, the built-in widgets are re-enabled, your previous theme is set.
`omarchy theme remove marvin` drops the theme itself. Confirm the bar is
the stock bar again and `hyprctl getoption decoration:rounding` is what it
was.

## What to send back

Screenshots of the bar, the launcher, a notification, and any card — dark
and light — plus anything from the log. A screenshot with the 4px grid
overlaid from the art-direction page beside it is the fastest way to spot
a value that drifted.
