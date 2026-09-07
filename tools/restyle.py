#!/usr/bin/env python3
"""Apply the Marvin rules to an upstream Omarchy panel, mechanically.

    tools/restyle.py <upstream Panel.qml> <out Panel.qml>

Every rewrite is a rule from docs/principles.md, applied as a text transform
over upstream's file so the logic stays byte-identical and only presentation
moves. Each rule reports how many times it fired; anything matching an
upstream tone habit that survives is listed at the end, so nothing slips by
silently. The card chrome is the theme's already; this is the inside.
"""
import re, sys

RULES = []
def rule(name):
    def wrap(f): RULES.append((name, f)); return f
    return wrap

@rule("card width 380 → 328 (content 328 like every other card)")
def _(s): return re.subn(r"panel\.fittedContentWidth\(Style\.space\(380\)\)", "panel.fittedContentWidth(Style.space(328))", s)

@rule("column rhythm: spacing 14 is the section rhythm → xxl")
def _(s): return re.subn(r"spacing: Style\.space\(14\)", "spacing: Style.spacing.xxl", s)

@rule("no bold: weight Medium carries emphasis")
def _(s):
    s, a = re.subn(r"font\.bold: true", "font.weight: Font.Medium", s)
    s, b = re.subn(r"font\.bold: ([^\n]+)", r"font.weight: \1 ? Font.Medium : Font.Normal", s)
    return s, a + b

@rule("no letter-spacing")
def _(s): return re.subn(r"\n\s*font\.letterSpacing: [0-9.]+", "", s)

@rule("large type is tracked in: −0.02em at display-large, −0.01em at display")
def _(s):
    s, a = re.subn(r"(\n(\s+)font\.pixelSize: Style\.font\.displayLarge\n)", r"\1\2font.letterSpacing: -Style.font.displayLarge * 0.02\n", s)
    s, b = re.subn(r"(\n(\s+)font\.pixelSize: Style\.font\.display\n)(?!\2font\.letterSpacing)", r"\1\2font.letterSpacing: -Style.font.display * 0.01\n", s)
    return s, a + b

@rule("status lines in sentence case, not uppercase")
def _(s): return re.subn(r"\.toUpperCase\(\)", "", s)

@rule("two tones: Qt.darker(foreground) is muted")
def _(s): return re.subn(r"Qt\.darker\((?:root\.bar\.foreground|root\.contentForeground|root\.bar\.barForeground), [0-9.]+\)", "Color.muted", s)

@rule("no dividers: PanelSeparator blocks removed")
def _(s):
    pat = re.compile(r"\n(\s*)PanelSeparator \{\n(?:\1  .*\n)*?\1\}\n")
    return pat.subn("\n", s)

@rule("section headers are muted captions in sentence case")
def _(s):
    n = 0
    def fix(m):
        nonlocal n; n += 1
        indent, body = m.group(1), m.group(2)
        body = re.sub(r'text: "([A-Z][A-Z /-]+)"', lambda t: 'text: "' + t.group(1).capitalize() + '"', body)
        body = re.sub(r"\n\s*foreground: [^\n]+", "", body)
        body = re.sub(r"fontFamily: ([^\n]+)", r"font.family: \1\n" + indent + "  font.pixelSize: Style.font.caption\n" + indent + "  color: Color.muted", body)
        return f"\n{indent}Text {{\n{body}{indent}}}\n"
    out = re.sub(r"\n(\s*)PanelSectionHeader \{\n((?:\1  .*\n)*?)\1\}\n", fix, s)
    return out, n

@rule("spacing on the grid")
def _(s):
    table = {"1": "xxs", "2": "xxs", "3": "xs", "4": "xs", "5": "xs", "6": "sm", "8": "sm", "10": "sm", "12": "md", "14": "lg", "16": "lg", "18": "xl", "20": "xl", "22": "xxl", "24": "xxl"}
    n = 0
    def fix(m):
        nonlocal n
        if m.group(2) in table: n += 1; return f"{m.group(1)}Style.spacing.{table[m.group(2)]}"
        return m.group(0)
    table.update({"22": "xxl", "36": "xxxl + Style.spacing.sm", "44": "huge"})
    return re.sub(r"()Style\.space\((\d+)\)", fix, s), n

@rule("sliders are hairlines: 2px track on the normal fill, 12px knob")
def _(s):
    n = 0
    def fix(m):
        nonlocal n; n += 1
        ind = m.group(1)
        return (m.group(0) + f"{ind}trackHeight: Style.spacing.xxs\n{ind}knobSize: Style.spacing.md\n"
                f"{ind}trackColor: Style.normalFillFor(root.bar.foreground, Color.accent)\n")
    return re.sub(r"PanelSlider \{\n(?:(\s+)id: \w+\n)?(\s+)bar: root\.bar\n", lambda m: fix(type("M",(),{"group":lambda self,i: (m.group(2) if i==1 else m.group(0))})()), s), n

@rule("meters are hairlines")
def _(s): return re.subn(r"height: Math\.max\(Style\.space\(5\), Style\.spacing\.xs\)\n(\s+)color: Util\.alpha\(root\.bar\.foreground, 0\.18\)", r"height: Style.spacing.xxs\n\1radius: 1\n\1color: Style.normalFillFor(root.bar.foreground, Color.accent)", s)

LEFTOVER = re.compile(r"Qt\.darker|PanelSeparator|PanelSectionHeader|font\.bold|letterSpacing|toUpperCase|font\.pixelSize: \d+|Style\.space\((?:14|18|22|36|44)\)")

def restyle(src, banner):
    s = src.replace("\nPanel {\n", "\n" + banner + "Panel {\n", 1)
    report = []
    for name, f in RULES:
        s, n = f(s)
        report.append((name, n))
    left = [l.strip() for l in s.split("\n") if LEFTOVER.search(l)]
    return s, report, left

if __name__ == "__main__":
    src = open(sys.argv[1]).read()
    banner = ("// Marvin restyle. A clone of the built-in: every line of logic is\n"
              "// upstream's. Presentation is rewritten by tools/restyle.py to the rules\n"
              "// in docs/principles.md — no dividers, sentence-case muted captions,\n"
              "// hairline sliders and meters, spacing on the grid, two text tones.\n")
    out, report, left = restyle(src, banner)
    open(sys.argv[2], "w").write(out)
    for name, n in report: print(f"  {n:3d}  {name}")
    print(f"  leftover upstream habits: {len(left)}")
    for l in left: print("       ", l[:100])
    d = 0
    for ch in out: d += (ch == "{") - (ch == "}")
    print("  braces:", "OK" if d == 0 else f"BROKEN {d}")
    sys.exit(0 if d == 0 else 1)
