#!/usr/bin/env python3
"""Render Omarchy's app templates through Marvin's palette.

    tools/apptheme.py            # writes the app files for both tones
    tools/apptheme.py --check    # render, report, write nothing

Omarchy themes an app one of two ways: the theme ships the file, or Omarchy
renders its own template from the theme's colors.toml. Files the theme ships
win (omarchy-theme-set-templates only writes a template when the output is
absent), so shipping them pins the result against upstream template drift and
lets Marvin make the role choices upstream leaves to a fallback.

These are palette maps, not layouts: the app owns its own structure and takes
only colours. So this is a renderer, not a stylesheet — the same shape as
tools/restyle.py, which transforms upstream's QML. Run it against a new Omarchy
release and the files are regenerated; it reports every placeholder it filled
and refuses to guess at one it does not know.

Only claude.json and vscode-theme.json are shipped. omarchy-theme-set refuses
Lua and terminal configs from a theme installed out of a git repo — those can
execute — so ghostty.conf, foot.ini, neovim.lua and gum_env.lua are ignored
with a warning on every theme-set no matter what they contain. Those four apps
still get Marvin's palette: Omarchy renders its own template from colors.toml,
and the names upstream asks for that a neutral ramp lacks are set there rather
than patched per file. Adding one back here only reintroduces the warning.

Marvin names three colours upstream's templates ask for but a neutral ramp does
not carry — orange, brown and purple. Left unset, Omarchy's resolver derives
them, and orange lands exactly on Marvin's yellow, which flattens enumMember
against class and type in the editor themes. They are set here instead, and
tested against the same contrast floors as the rest of the palette.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPSTREAM = pathlib.Path("/usr/share/omarchy/default/themed")

# The apps Marvin ships a file for. Everything else keeps Omarchy's template,
# rendered from colors.toml. Confined to the two extensions omarchy-theme-set
# accepts from a git-installed theme; see the note above before adding to it.
APPS = ("claude.json", "vscode-theme.json")


def toml(p):
    d = {}
    for l in open(p):
        m = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=\s*"([^"]*)"', l)
        if m:
            d[m.group(1)] = m.group(2)
    return d


def _lum(h):
    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(h[i:i+2], 16) for i in (1, 3, 5))
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a, b):
    la, lb = _lum(a), _lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def mix(start, end, amount):
    """Omarchy's mix_color: start + (end - start) * amount, rounded."""
    s = [int(start[i:i+2], 16) for i in (1, 3, 5)]
    e = [int(end[i:i+2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02x" % round(a + (b - a) * amount) for a, b in zip(s, e))


def palette(c):
    """Every key the six templates ask for, resolved to Marvin hex.

    The names upstream assumes but a neutral ramp does not define are set
    deliberately rather than left to Omarchy's derivation:

      orange  a real step between red and yellow, so the editor themes do not
              collapse enumMember onto the class/type colour
      brown   the warm end of the ramp, dimmed — a single neovim role. Given
              per tone rather than mixed toward the background: on the light
              ramp that direction lowers contrast instead of raising it.
      purple  Marvin has no separate purple; magenta is the one violet in the
              ramp and foot's regular5 is the same slot

    Both new colours are measured, not eyeballed: each sits inside the band its
    own ramp already occupies against the background (dark 6.8–10.2, light
    4.5–5.0). test/contrast holds them there.
    """
    p = dict(c)
    dark = c["mode"] == "dark"
    p.setdefault("orange", "#e0a273" if dark else "#a1560f")
    p.setdefault("brown", "#a37857" if dark else "#96622e")
    p.setdefault("purple", c["magenta"])
    p["selection_background"] = c["selection"]
    p["selection_foreground"] = c.get("bright_foreground", c["foreground"])
    p["theme_type"] = c["mode"]
    return p


MIX_RE = re.compile(
    r"\{\{\s*mix(_strip|_rgb)?\s+([A-Za-z0-9_]+)\s+([A-Za-z0-9_]+)\s+([0-9]+(?:\.[0-9]+)?)%?\s*\}\}")
KEY_RE = re.compile(r"\{\{\s*([A-Za-z0-9_]+?)(_strip|_rgb)?\s*\}\}")


def render(text, p, unknown):
    """Fill Omarchy's placeholder forms. Anything unknown is recorded, not guessed."""
    def suffix(value, kind):
        if kind == "_strip":
            return value.lstrip("#")
        if kind == "_rgb":
            return ",".join(str(int(value[i:i+2], 16)) for i in (1, 3, 5))
        return value

    def do_mix(m):
        kind, a, b, amount = m.group(1), m.group(2), m.group(3), float(m.group(4))
        if a not in p or b not in p:
            unknown.add(m.group(0))
            return m.group(0)
        return suffix(mix(p[a], p[b], amount / 100), kind)

    def do_key(m):
        key, kind = m.group(1), m.group(2)
        if key not in p:
            unknown.add(m.group(0))
            return m.group(0)
        return suffix(p[key], kind)

    return KEY_RE.sub(do_key, MIX_RE.sub(do_mix, text))


BANNER = {
    ".conf": "# Marvin. Generated by tools/apptheme.py from colors.toml.\n",
    ".ini":  "# Marvin. Generated by tools/apptheme.py from colors.toml.\n",
    ".lua":  "-- Marvin. Generated by tools/apptheme.py from colors.toml.\n",
    ".json": "",  # JSON carries no comments; the "name" field says it instead
}


def main():
    check = "--check" in sys.argv
    if not UPSTREAM.is_dir():
        sys.exit(f"apptheme: {UPSTREAM} not found — Omarchy must be installed to regenerate")

    failures = 0
    for pre in ("", "light/"):
        c = toml(ROOT / f"{pre}colors.toml")
        p = palette(c)
        for app in APPS:
            tpl = UPSTREAM / f"{app}.tpl"
            if not tpl.is_file():
                print(f"  MISSING upstream template: {tpl}")
                failures += 1
                continue
            unknown = set()
            out = render(tpl.read_text(), p, unknown)
            if unknown:
                print(f"  {pre}{app}: unresolved {sorted(unknown)}")
                failures += 1
                continue
            # Marvin names itself, so a stray "Omarchy" in a theme file does not
            # show up in the app's own theme picker.
            out = out.replace('"name": "Omarchy"', '"name": "Marvin"')
            out = BANNER.get(pathlib.Path(app).suffix, "") + out
            if not check:
                (ROOT / f"{pre}{app}").write_text(out)
        if not check:
            print("wrote", f"{pre}{{{', '.join(APPS)}}}")

    if failures:
        sys.exit(f"apptheme: {failures} template(s) did not render")


if __name__ == "__main__":
    main()
