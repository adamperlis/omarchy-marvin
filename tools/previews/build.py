#!/usr/bin/env python3
"""Render the theme previews and the README images from the tokens.

    tools/previews/build.py --fonts <dir with Inter-*.ttf and JetBrainsMono-*.ttf> [--out <repo>]

Draws the same desktop Omarchy's own previews show — bar, editor over
terminal, monitor over files, wallpaper through the gaps — at 1:1 token
values, plus the boot screen and a sheet of the widget cards, for both
tones. Needs node + playwright (Chromium) on PATH.
"""
import argparse, base64, os, subprocess, sys, tempfile, pathlib, re

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent

def toml(path):
    d = {}
    for line in open(path):
        m = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=\s*(?:"([^"]*)"|([^#\n]+))', line)
        if m: d[m.group(1)] = (m.group(2) if m.group(2) is not None else m.group(3)).strip()
    return d

def font_face(dirp):
    css = ""
    for fam, files in (("Inter", [("Inter-Regular.ttf", 400), ("Inter-Medium.ttf", 500), ("Inter-SemiBold.ttf", 600)]),
                       ("JetBrains Mono", [("JetBrainsMono-Regular.ttf", 400), ("JetBrainsMono-Medium.ttf", 500)]),
                       ("Libre Baskerville", [("LibreBaskerville.ttf", 400)])):
        for f, w in files:
            p = pathlib.Path(dirp) / f
            if p.exists():
                css += f"@font-face{{font-family:'{fam}';font-weight:{w};src:url('file://{p}') format('truetype')}}\n"
    return css

# ---- icons: tiny inline SVGs, stroke = currentColor, 24 viewBox
ICONS = {
 "search": '<circle cx="10" cy="10" r="6"/><path d="M15 15l5 5"/>',
 "apps": '<circle cx="6" cy="6" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="6" r="1.6" fill="currentColor" stroke="none"/><circle cx="18" cy="6" r="1.6" fill="currentColor" stroke="none"/><circle cx="6" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="18" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="6" cy="18" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="18" r="1.6" fill="currentColor" stroke="none"/><circle cx="18" cy="18" r="1.6" fill="currentColor" stroke="none"/>',
 "wifi": '<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5.5 12.5a10 10 0 0 1 13 0"/><path d="M9 16a5 5 0 0 1 6 0"/><circle cx="12" cy="19.5" r="1.2" fill="currentColor" stroke="none"/>',
 "bluetooth": '<path d="M7 7l10 10-5 5V2l5 5L7 17"/>',
 "volume": '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M16 8a5 5 0 0 1 0 8"/>',
 "battery": '<rect x="2" y="7" width="17" height="10" rx="2"/><path d="M22 10v4"/><rect x="4" y="9" width="11" height="6" fill="currentColor" stroke="none"/>',
 "battery_full": '<rect x="2" y="7" width="17" height="10" rx="2"/><path d="M22 10v4"/><rect x="4" y="9" width="13" height="6" fill="currentColor" stroke="none"/>',
 "update": '<circle cx="12" cy="12" r="9"/><path d="M12 7v9M8.5 12.5L12 16l3.5-3.5"/>',
 "folder": '<path d="M3 6h6l2 2h10v11H3z"/>',
 "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
 "terminal": '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9l3 3-3 3M12 15h5"/>',
 "text": '<path d="M5 6h14M12 6v13M9 19h6"/>',
 "mail": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
 "sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
 "cloud": '<path d="M7 18a4 4 0 0 1-.5-8A6 6 0 0 1 18 9a4 4 0 0 1 0 9z"/>',
 "partly": '<circle cx="8" cy="8" r="3"/><path d="M8 2v2M2 8h2M3.8 3.8l1.4 1.4"/><path d="M9 19a3.5 3.5 0 0 1-.4-7A5 5 0 0 1 18.5 13a3 3 0 0 1 0 6z"/>',
 "chevron_left": '<path d="M14 6l-6 6 6 6"/>', "chevron_right": '<path d="M10 6l6 6-6 6"/>',
 "prev": '<path d="M6 5v14M18 5l-10 7 10 7z"/>', "next": '<path d="M18 5v14M6 5l10 7-10 7z"/>',
 "pause": '<rect x="6" y="5" width="4" height="14" fill="currentColor" stroke="none"/><rect x="14" y="5" width="4" height="14" fill="currentColor" stroke="none"/>',
 "play": '<path d="M7 4l13 8-13 8z" fill="currentColor" stroke="none"/>',
 "music": '<path d="M9 18V6l10-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
 "eco": '<path d="M5 19c0-8 4-13 14-14 0 10-5 14-14 14z"/><path d="M5 19c3-5 6-8 10-10"/>',
 "balance": '<circle cx="12" cy="12" r="8"/><path d="M12 4v16"/>',
 "bolt": '<path d="M13 2L5 14h6l-1 8 8-12h-6z" fill="currentColor" stroke="none"/>',
 "home": '<path d="M4 11l8-7 8 7v9H4z"/>', "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
 "star": '<path d="M12 3l2.8 6 6.2.6-4.7 4.3 1.4 6.1L12 16.8 6.3 20l1.4-6.1L3 9.6 9.2 9z"/>',
 "network": '<circle cx="12" cy="5" r="2"/><circle cx="5" cy="19" r="2"/><circle cx="19" cy="19" r="2"/><path d="M12 7v5M12 12l-6 5M12 12l6 5"/>',
 "trash": '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>', "moon": '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>', "check": '<path d="M5 12l5 5L20 7"/>', "lock": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/><circle cx="12" cy="16" r="1.2" fill="currentColor" stroke="none"/>', "download": '<path d="M12 4v12M7 11l5 5 5-5M4 20h16"/>',
}
def ic(name, size=16, sw=1.75):
    return f'<svg class="i" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</svg>'

def sections(path):
    out, sec = {}, ""
    for line in open(path):
        m = re.match(r"^\s*\[([A-Za-z0-9_-]+)\]", line)
        if m: sec = m.group(1); continue
        m = re.match(r'^\s*([A-Za-z0-9_-]+)\s*=\s*(?:"([^"]*)"|([0-9.]+))', line)
        if m and sec: out.setdefault(sec, {})[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3)
    return out

WALLS = ("1-plain.jpg", "2-ember.jpg", "3-lilac.jpg", "4-sky.jpg", "5-citrus.jpg", "6-dusk.jpg", "7-magenta.jpg")   # the plain ground first, then the rooms
ARTS = ("ember.jpg", "lilac.jpg", "sky.jpg", "citrus.jpg", "dusk.jpg", "magenta.jpg")   # the same rooms, ungraded, for imagery inside the UI

def tone(root, light):
    c = toml(root / ("light/colors.toml" if light else "colors.toml"))
    sh = sections(root / ("light/shell.toml" if light else "shell.toml"))
    wx, pw, ch, ct = sh["marvin-weather"], sh["marvin-power"], sh["marvin-chip"], sh["controls"]
    return dict(light=light, bg=c["background"], raised=c["lighter_background"], ground=c["dark_background"], fg=c["foreground"], muted=c["muted"],
                accent=c["accent"], attn=c["attention"], red=c["red"], green=c["green"], yellow=c["yellow"], blue=c["blue"], magenta=c["magenta"], cyan=c["cyan"],
                bright_fg=c["bright_foreground"], selection=c["selection"], ansi=[c[k] for k in ("background","red","green","yellow","blue","magenta","cyan","foreground","muted","bright_red","bright_green","bright_yellow","bright_blue","bright_magenta","bright_cyan","bright_foreground")],
                wall=root / "backgrounds" / ("abstract-04.jpg" if light else "abstract-05.jpg"),
                room=root / "backgrounds" / ("abstract-04.jpg" if light else "abstract-05.jpg"),
                walls=[(n, root / (("light/" if light else "") + f"backgrounds/{n}")) for n in WALLS],
                arts=[(n, root / "backgrounds" / n) for n in ("abstract-35.jpg", "abstract-23.jpg", "abstract-08.jpg", "abstract-50.jpg")],
                wx=(wx["background"], wx["text"], wx["muted"], wx.get("background-end", wx["background"])),
                sky=dict(sunset=(wx["sunset"], wx["sunset-end"], wx["sunset-muted"]), night=(wx["night"], wx["night-end"], wx["night-muted"])),
                pw=(pw["background"], pw["text"], pw["muted"], pw.get("background-end", pw["background"])),
                chip=(ch["attention-fill"], ch["attention-text"]),
                alphas=(ct["normal-fill-alpha"], ct["hover-cursor-fill-alpha"], ct["selected-fill-alpha"], ct["focus-border-alpha"]))

def hexrgb(h): return ",".join(str(int(h[i:i+2],16)) for i in (1,3,5))

BASE_CSS = """
*{box-sizing:border-box}body{margin:0;font-family:Inter,sans-serif;font-size:14px;line-height:1;color:var(--fg);-webkit-font-smoothing:antialiased}
.mono{font-family:'JetBrains Mono',monospace}
.i{display:inline-block;vertical-align:middle;flex:none}
.bar{position:absolute;left:0;top:0;right:0;height:32px;background:var(--bg);display:grid;grid-template-columns:1fr auto 1fr;align-items:center;color:var(--fg)}
.bar .l,.bar .r{display:flex;align-items:center}.bar .r{justify-content:flex-end}
.slot{width:32px;height:32px;display:flex;align-items:center;justify-content:center}
.ws{display:flex}.ws span{width:24px;height:24px;margin:4px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:500;color:var(--muted)}
.ws span.on{background:rgba(var(--fg-rgb),var(--a3));color:var(--fg)}
.clock{font-weight:500;padding:0 16px}.clock i{font-style:normal;color:var(--muted);font-weight:400;margin-right:8px}
.attn{color:var(--attn)}
.hair{height:2px;border-radius:1px;background:rgba(var(--fg-rgb),.08);position:relative;overflow:hidden}.hair i{position:absolute;left:0;top:0;bottom:0;background:var(--muted);border-radius:1px}
.hair.acc i{background:var(--accent)}
.card{background:var(--raised);border-radius:24px;padding:24px;display:flex;flex-direction:column;gap:24px;border:1px solid rgba(var(--fg-rgb),.10);box-shadow:0 8px 32px rgba(0,0,0,var(--sh))}
.card .hd{height:32px;display:flex;align-items:center;justify-content:space-between;font-size:16px;font-weight:500}.card .hd span{font-size:12px;color:var(--muted);font-weight:400}
.card .hero{display:flex;align-items:flex-start;gap:12px}.card .hero b{font-size:56px;font-weight:400;letter-spacing:-.03em;font-variant-numeric:normal}
.card .hero .cap{display:flex;flex-direction:column;gap:4px;margin-top:10px;font-size:15px}.card .hero .cap span{font-size:12px;color:var(--muted)}
.card .hero .end{margin-left:auto;align-self:center}
.card .stats{display:grid;grid-template-columns:1fr 1fr;gap:16px 24px}.card .stats div{display:flex;flex-direction:column;gap:4px}.card .stats b{font-size:16px;font-weight:400}.card .stats span{font-size:12px;color:var(--muted)}
.card .stats.three{grid-template-columns:auto auto auto;justify-content:start}
.card .pills span.l{font-size:12px;color:var(--muted)}.card .pills{display:flex;flex-direction:column;gap:8px}.card .pills div{display:flex;flex-wrap:wrap;gap:8px}
.card .pills em{font-style:normal;height:40px;padding:0 20px;border-radius:20px;display:flex;align-items:center;gap:8px;background:rgba(var(--fg-rgb),var(--a1));white-space:nowrap}.card .pills em.on{background:rgba(var(--fg-rgb),var(--a3))}
.card .rail{display:flex;flex-direction:column;gap:8px}.card .rail .lbl{display:flex;justify-content:space-between;font-size:12px;color:var(--muted)}.card .rail .lbl b{font-weight:400;color:var(--fg)}
.card .mo{display:flex;align-items:center;justify-content:space-between;height:32px;font-size:16px;font-weight:500}.card .mo div{display:flex;gap:4px}
.card .grid{display:grid;grid-template-columns:32px 20px repeat(7,36px)}.card .grid span{height:32px;display:flex;align-items:center;justify-content:center}
.card .grid .h{height:24px;font-size:12px;color:var(--muted)}.card .grid .w{font-size:12px;color:var(--muted)}.card .grid .o{color:var(--muted)}.card .grid .t{background:rgba(var(--fg-rgb),var(--a3));border-radius:16px;font-weight:500}
.card .now{display:flex;gap:16px;align-items:center}.card .now .tt{flex:1}.card .now .tr{margin-top:8px}.card .now .art{width:96px;height:96px;border-radius:12px;overflow:hidden;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;justify-content:center;color:var(--muted)}
.card .now .tt{display:flex;flex-direction:column;gap:4px}.card .now .tt b{font-size:16px;font-weight:500}.card .now .tt i{font-style:normal;color:var(--muted)}.card .now .tt small{font-size:12px;color:var(--muted)}
.card .tr{display:flex;gap:8px;align-items:center}.card .tr .b{width:40px;height:40px;display:flex;align-items:center;justify-content:center}.card .tr .play{width:40px;height:40px;border-radius:20px;background:var(--fg);color:var(--raised);display:flex;align-items:center;justify-content:center}
.wx{background:linear-gradient(180deg,var(--wx-bg),var(--wx-end));color:var(--wx-ink)}.wx.sun{background:linear-gradient(180deg,var(--sun-bg),var(--sun-end))}.wx.sun .hero .cap span,.wx.sun .stats span,.wx.sun .days span,.wx.sun .days em i{color:var(--sun-muted)}.wx.nt{background:linear-gradient(180deg,var(--nt-bg),var(--nt-end))}.wx.nt .hero .cap span,.wx.nt .stats span,.wx.nt .days span,.wx.nt .days em i{color:var(--nt-muted)}
.pw{background:linear-gradient(180deg,var(--pw-bg),var(--pw-end));color:var(--pw-ink)}.pw .hd span{color:var(--pw-muted)}.pw .stats b{color:var(--pw-ink)}.pw .stats span,.pw .pills span.l{color:var(--pw-muted)}
.pw .pills em{background:rgba(var(--pw-rgb),.06)}.pw .pills em.on{background:rgba(var(--pw-rgb),.14)}
.chip{font-size:12px;color:var(--pw-muted);font-weight:400}
.ring{position:relative;width:160px;height:160px;margin:0 auto}.ring b{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:56px;font-weight:400;letter-spacing:-.03em;font-variant-numeric:normal}
.tile{width:20px;height:20px;border-radius:6px;flex:none}.tile.lg{width:64px;height:64px;border-radius:8px}
.mood{display:grid;grid-template-columns:1fr 1fr;gap:8px}.mood span{height:112px;border-radius:12px;display:block}
.notes .page{font-family:'Libre Baskerville',Baskerville,'Noto Serif',serif;font-size:28px;line-height:1.25;letter-spacing:-.01em;padding-bottom:24px}
.chip2{align-self:flex-start;height:28px;padding:0 12px;border-radius:6px;display:flex;align-items:center;font-size:13px;font-weight:400;background:var(--chip2-fill);color:var(--chip2-text)}
.files{display:flex;gap:16px;min-height:200px}.files .sb{display:flex;flex-direction:column;gap:4px;width:128px;flex:none}.files .sb div{height:40px;border-radius:20px;padding:0 14px;display:flex;align-items:center;gap:10px;font-size:13px;white-space:nowrap}.files .sb div.on{background:rgba(var(--fg-rgb),var(--a3))}
.files .fg{flex:1;display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px 8px;align-content:start}.files .fd{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:11px}
.picker .tabs{display:flex;gap:8px}.picker .tabs span{height:40px;padding:0 20px;border-radius:20px;display:flex;align-items:center;color:var(--muted)}.picker .tabs span.on{background:rgba(var(--fg-rgb),var(--a3));color:var(--fg)}
.picker .shots{display:grid;grid-template-columns:1fr 1fr;gap:8px}.picker .shot{border-radius:12px;background:rgba(var(--fg-rgb),var(--a1));padding:8px;display:flex;flex-direction:column;gap:8px;font-size:12px;color:var(--muted)}.picker .shot i{display:block;height:80px;border-radius:8px}
.picker .shot.on{background:rgba(var(--fg-rgb),var(--a3));box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.picker .go{align-self:flex-end;height:40px;padding:0 20px;border-radius:20px;background:var(--fg);color:var(--raised);display:flex;align-items:center}
.lock{align-items:center;justify-content:center;gap:24px;height:240px;padding:24px}.lock .mark{font-size:40px;line-height:40px;height:40px;font-weight:500;letter-spacing:-.03em}.lock .in{width:240px;height:40px;border-radius:20px;background:rgba(var(--fg-rgb),var(--a2));display:flex;align-items:center;gap:8px;padding:0 16px;box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.lock .in .dots{display:flex;gap:8px;flex:1;justify-content:center;margin-right:20px}.lock .in i{width:8px;height:8px;border-radius:4px;background:var(--fg)}
.pk .row2{display:flex;gap:12px;align-items:flex-start}.pk .ic{width:40px;height:40px;border-radius:20px;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;justify-content:center;flex:none}
.pk .tt b{font-size:16px;font-weight:500;display:block}.pk .tt span{color:var(--muted);line-height:1.5;display:block;margin-top:4px}
.pk .in{height:40px;border-radius:20px;background:rgba(var(--fg-rgb),var(--a2));display:flex;align-items:center;padding:0 16px;gap:8px;box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.pk .in i{width:8px;height:8px;border-radius:4px;background:var(--fg)}
.pk .btns{display:flex;gap:8px;justify-content:flex-end}.pk .btns span{height:40px;padding:0 20px;border-radius:20px;display:flex;align-items:center;background:rgba(var(--fg-rgb),var(--a1))}.pk .btns span.go{background:var(--fg);color:var(--raised)}

.menu .rows .row .ch{margin-left:auto;color:var(--muted)}
.clip .rows .row{height:auto;min-height:40px;padding:10px 16px;line-height:1.35;align-items:flex-start}.clip .rows .row .n{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1}.clip .rows .row .k{flex:none;margin-left:12px}
.pick .strip{display:flex;gap:8px}.pick .th{flex:1;border-radius:12px;padding:6px;background:rgba(var(--fg-rgb),var(--a1))}.pick .th i{display:block;height:72px;border-radius:8px}.pick .th.on{background:rgba(var(--fg-rgb),var(--a3));box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.pick .names{display:flex;gap:8px;font-size:12px;color:var(--muted)}.pick .names span{flex:1;text-align:center}.pick .names span.on{color:var(--fg)}
.term{font-family:'JetBrains Mono',monospace;font-size:13px;line-height:20px;white-space:pre;overflow:hidden;background:var(--bg);color:var(--fg)}.term .p{color:var(--accent)}.term .c{color:var(--muted)}.wx .hero .cap span,.wx .stats span,.wx .days span{color:var(--wx-muted)}.wx .stats b{color:var(--wx-ink)}
.wx .days{display:flex;gap:32px}.wx .days div{display:flex;flex-direction:column;gap:4px}.wx .days span{font-size:12px}.wx .days em{font-style:normal}.wx .days em i{font-style:normal;color:var(--wx-muted);margin-left:4px}
.launcher{background:var(--raised);border-radius:24px;padding:24px;display:flex;flex-direction:column;gap:16px;border:1px solid rgba(var(--fg-rgb),.10);box-shadow:0 8px 32px rgba(0,0,0,var(--sh))}
.field{height:40px;border-radius:20px;background:rgba(var(--fg-rgb),var(--a2));display:flex;align-items:center;gap:8px;padding:0 16px;box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.field i{font-style:normal;color:var(--muted)}
.rows{display:flex;flex-direction:column;gap:8px}.row{height:40px;border-radius:20px;display:flex;align-items:center;gap:12px;padding:0 16px}.row .n{flex:1}.row .k{font-size:12px;color:var(--muted)}.row.sel{background:rgba(var(--fg-rgb),var(--a3))}.row.hov{background:rgba(var(--fg-rgb),var(--a2))}
.note{background:var(--raised);border-radius:24px;padding:24px;display:flex;flex-direction:column;gap:8px;line-height:1.5;border:1px solid rgba(var(--fg-rgb),.10);box-shadow:0 8px 32px rgba(0,0,0,var(--sh))}
.note .app{display:flex;align-items:center;gap:8px;font-size:12px;color:var(--muted);line-height:1}.note .app .t{margin-left:auto}.note .title{font-size:16px;font-weight:500;margin-top:4px}.note .thumbs{display:flex;gap:8px;margin-top:8px}.note .thumbs span{width:56px;height:56px;border-radius:8px;overflow:hidden}.note .body{color:var(--muted)}
.spec{display:flex;flex-direction:column;gap:12px}.spec .r{display:flex;align-items:baseline;justify-content:space-between;gap:16px}.spec .r span{font-size:12px;color:var(--muted);white-space:nowrap}
.spec .d{font-size:56px;font-weight:400;letter-spacing:-.03em;line-height:1}.spec .h{font-size:18px;font-weight:500}.spec .t{font-size:16px;font-weight:500}.spec .b{font-size:14px}.spec .c{font-size:12px;color:var(--muted)}
.sw{display:grid;grid-template-columns:repeat(4,1fr);gap:12px 8px}.sw div{display:flex;flex-direction:column;gap:6px;font-size:11px;color:var(--muted)}.sw i{display:block;height:40px;border-radius:20px;box-shadow:inset 0 0 0 1px rgba(var(--fg-rgb),.10)}
.bset{display:flex;flex-direction:column;gap:12px}.bset .row3{display:flex;gap:8px;align-items:center}
.bt{height:40px;padding:0 20px;border-radius:20px;display:inline-flex;align-items:center;gap:8px;white-space:nowrap;font-size:14px}
.bt.pri{background:var(--fg);color:var(--raised)}.bt.pri.hov{opacity:.85}.bt.pri.dis{opacity:.35}
.bt.sec{background:rgba(var(--fg-rgb),var(--a1))}.bt.sec.hov{background:rgba(var(--fg-rgb),var(--a2))}.bt.sec.on{background:rgba(var(--fg-rgb),var(--a3))}.bt.sec.dis{opacity:.4}
.bt.gho{background:transparent;color:var(--muted)}.bt.gho.hov{background:rgba(var(--fg-rgb),var(--a1));color:var(--fg)}
.flds{display:flex;flex-direction:column;gap:12px}.fld{height:40px;border-radius:20px;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;padding:0 16px;gap:8px;color:var(--muted)}
.fld.foc{background:rgba(var(--fg-rgb),var(--a3));color:var(--fg);box-shadow:0 0 0 1px rgba(var(--fg-rgb),var(--ring))}.fld.err{box-shadow:0 0 0 1px var(--red);color:var(--fg)}.fld .cur{width:1px;height:16px;background:var(--fg)}
.ctl{display:flex;align-items:center;gap:16px;flex-wrap:wrap;font-size:13px}.ctl div{display:flex;align-items:center;gap:8px}
.tg{width:40px;height:24px;border-radius:12px;background:rgba(var(--fg-rgb),var(--a3));position:relative}.tg i{position:absolute;top:4px;left:4px;width:16px;height:16px;border-radius:8px;background:var(--raised)}.tg.on{background:var(--accent)}.tg.on i{left:20px}
.cb{width:18px;height:18px;border-radius:6px;box-shadow:inset 0 0 0 1.5px var(--muted)}.cb.on{background:var(--accent);box-shadow:none;display:flex;align-items:center;justify-content:center;color:#fff}
.rd{width:18px;height:18px;border-radius:9px;box-shadow:inset 0 0 0 1.5px var(--muted)}.rd.on{box-shadow:inset 0 0 0 5px var(--accent)}
.icons{display:grid;grid-template-columns:repeat(8,1fr);gap:12px 0;justify-items:center;color:var(--fg)}
.toast{background:var(--raised);border-radius:24px;padding:16px 16px 16px 24px;display:flex;align-items:center;gap:16px;border:1px solid rgba(var(--fg-rgb),.10);box-shadow:0 8px 32px rgba(0,0,0,var(--sh))}.toast .m{flex:1;display:flex;flex-direction:column;gap:2px}.toast .m span{font-size:12px;color:var(--muted)}
.osd{width:280px;height:56px;background:var(--raised);border-radius:24px;display:flex;align-items:center;gap:16px;padding:0 24px;border:1px solid rgba(var(--fg-rgb),.10);box-shadow:0 8px 32px rgba(0,0,0,var(--sh))}.osd .hair{flex:1}.osd .n{font-size:16px;font-weight:500;width:2ch;text-align:right}
"""

def vars_css(t):
    return f":root{{--bg:{t['bg']};--raised:{t['raised']};--fg:{t['fg']};--fg-rgb:{hexrgb(t['fg'])};--muted:{t['muted']};--accent:{t['accent']};--attn:{t['attn']};--wx-bg:{t['wx'][0]};--wx-ink:{t['wx'][1]};--acc-rgb:{hexrgb(t['accent'])};--wx-muted:{t['wx'][2]};--wx-end:{t['wx'][3]};--sun-bg:{t['sky']['sunset'][0]};--sun-end:{t['sky']['sunset'][1]};--sun-muted:{t['sky']['sunset'][2]};--nt-bg:{t['sky']['night'][0]};--nt-end:{t['sky']['night'][1]};--nt-muted:{t['sky']['night'][2]};--pw-bg:{t['pw'][0]};--pw-ink:{t['pw'][1]};--pw-rgb:{hexrgb(t['pw'][1])};--pw-muted:{t['pw'][2]};--pw-end:{t['pw'][3]};--chip2-fill:{t['chip'][0]};--chip2-text:{t['chip'][1]};--a1:{t['alphas'][0]};--a2:{t['alphas'][1]};--a3:{t['alphas'][2]};--ring:{t['alphas'][3]};--accent-rgb:{hexrgb(t['accent'])};--attn-rgb:{hexrgb(t['attn'])};--sh:{'.06' if t['light'] else '.28'}}}"

def bar(t, wide=True):
    return f'''<div class="bar"><div class="l"><div class="slot">{ic("apps")}</div><div class="ws"><span>1</span><span class="on">2</span><span>3</span><span>4</span><span>5</span></div></div>
<div class="clock"><i>Monday</i>14:32</div>
<div class="r"><div class="slot attn">{ic("update")}</div><div class="slot">{ic("wifi")}</div><div class="slot">{ic("bluetooth")}</div><div class="slot">{ic("volume")}</div><div class="slot">{ic("battery_full")}</div></div></div>'''

def widgets(t):
    days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    g = '<span class="h w">W</span><span></span>' + "".join(f'<span class="h">{d}</span>' for d in days)
    rows = [(36,["31","1","2","3","4","5","6"]),(37,["7","8","9","10","11","12","13"]),(38,["14","15","16","17","18","19","20"]),(39,["21","22","23","24","25","26","27"]),(40,["28","29","30","1","2","3","4"])]
    for i,(w,ds) in enumerate(rows):
        g += f'<span class="w">{w}</span><span></span>'
        for j,d in enumerate(ds):
            o = (i==0 and j==0) or (i==4 and j>=3)
            g += f'<span class="{"t" if (i==0 and d=="7") else ("o" if o else "")}">{d}</span>'
    return {
     "launcher": f'''<div class="launcher"><div class="field">{ic("search",20)}<div>fi<i>refox</i></div></div><div class="rows">
<div class="row sel"><span class="tile" style="background:linear-gradient(135deg,#ff9a3c,#e8412c)"></span><span class="n">Firefox</span><span class="k">Application</span></div><div class="row hov"><span class="tile" style="background:linear-gradient(135deg,#7aa6ff,#2a63d8)"></span><span class="n">Files</span><span class="k">Application</span></div>
<div class="row"><span class="tile" style="background:linear-gradient(135deg,#f24e1e 0 33%,#a259ff 33% 66%,#1abcfe 66%)"></span><span class="n">Figma</span><span class="k">Web app</span></div><div class="row"><span class="tile" style="background:#1a1a1a;border:1px solid rgba(var(--fg-rgb),.2)"></span><span class="n">Fastfetch</span><span class="k">Command</span></div><div class="row"><span class="tile" style="background:linear-gradient(135deg,#6b6b6b,#3a3a3a)"></span><span class="n">Font manager</span><span class="k">Application</span></div></div></div>''',
     "note": f'''<div class="note" style="width:352px"><div class="app"><span class="tile" style="background:linear-gradient(135deg,#3c8ff0,#1c4fb0)"></span>Thunderbird<span class="t">now</span></div><div class="title">Adam Perlis</div><div class="body">Grid first, then a clean type scale. Art direct a few key widgets and the rest is propagation.</div><div class="thumbs"><span style="background:url('file://{t["arts"][0][1]}') 20% 30%/220% auto"></span><span style="background:url('file://{t["arts"][1][1]}') 60% 60%/220% auto"></span><span style="background:url('file://{t["arts"][0][1]}') 80% 70%/220% auto"></span></div><div class="hair acc" style="margin-top:8px"><i style="width:62%"></i></div></div>''',
     "weather": f'''<div class="card wx" style="width:352px"><div class="hd" style="justify-content:flex-start">Bodega Bay</div><div class="hero"><b>58</b><div class="cap" style="font-size:13px;color:var(--wx-muted)">°F</div><span class="end">{ic("partly",48,1.25)}</span></div>
<div class="stats three"><div><b>61°F</b><span>Feels like</span></div><div><b>8 mph</b><span>Wind</span></div><div><b>70%</b><span>Humidity</span></div></div>
<div class="days"><div><span>Sat</span>{ic("sun",20)}<em>63°<i>51°</i></em></div><div><span>Sun</span>{ic("sun",20)}<em>65°<i>52°</i></em></div><div><span>Mon</span>{ic("cloud",20)}<em>72°<i>55°</i></em></div></div></div>''',
     "weather_sunset": f'''<div class="card wx sun" style="width:352px"><div class="hd" style="justify-content:flex-start">Bodega Bay</div><div class="hero"><b>64</b><div class="cap" style="font-size:13px;color:var(--wx-muted)">°F</div><span class="end">{ic("sun",48,1.25)}</span></div>
<div class="stats three"><div><b>66°F</b><span>Feels like</span></div><div><b>8 mph</b><span>Wind</span></div><div><b>52%</b><span>Humidity</span></div></div>
<div class="days"><div><span>Sat</span>{ic("sun",20)}<em>63°<i>51°</i></em></div><div><span>Sun</span>{ic("sun",20)}<em>65°<i>52°</i></em></div><div><span>Mon</span>{ic("cloud",20)}<em>72°<i>55°</i></em></div></div></div>''',
     "weather_night": f'''<div class="card wx nt" style="width:352px"><div class="hd" style="justify-content:flex-start">Bodega Bay</div><div class="hero"><b>49</b><div class="cap" style="font-size:13px;color:var(--wx-muted)">°F</div><span class="end">{ic("moon",48,1.25)}</span></div>
<div class="stats three"><div><b>47°F</b><span>Feels like</span></div><div><b>3 mph</b><span>Wind</span></div><div><b>88%</b><span>Humidity</span></div></div>
<div class="days"><div><span>Sat</span>{ic("sun",20)}<em>63°<i>51°</i></em></div><div><span>Sun</span>{ic("sun",20)}<em>65°<i>52°</i></em></div><div><span>Mon</span>{ic("cloud",20)}<em>72°<i>55°</i></em></div></div></div>''',
     "clock": f'''<div class="card" style="width:352px"><div class="hero"><b>7</b><div class="cap"><div>September</div><span>Monday</span></div></div>
<div class="rail"><div class="lbl">2026<b>68%</b></div><div class="hair"><i style="width:68%"></i></div></div>
<div class="mo">September 2026<div>{ic("chevron_left",20)}{ic("chevron_right",20)}</div></div><div class="grid">{g}</div></div>''',
     "power": f'''<div class="card pw" style="width:352px"><div class="hd">Battery<span class="chip">Charging · 1:05 to full</span></div>
<div class="ring"><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(0deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(6deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(12deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(18deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(24deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(30deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(36deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(42deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(48deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(54deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(60deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(66deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(72deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(78deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(84deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(90deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(96deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(102deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(108deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(114deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(120deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(126deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(132deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(138deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(144deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(150deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(156deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(162deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(168deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(174deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(180deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(186deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(192deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(198deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(204deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(210deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(216deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(222deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(228deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(234deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(240deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(246deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(252deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(258deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(264deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(270deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(276deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(282deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(288deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(294deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(300deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:var(--pw-ink);transform-origin:1px 80px;transform:rotate(306deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(312deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(318deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(324deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(330deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(336deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(342deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(348deg)"></span><span style="position:absolute;left:79px;top:0;width:2px;height:8px;border-radius:1px;background:rgba(var(--pw-rgb),.08);transform-origin:1px 80px;transform:rotate(354deg)"></span><b>87%</b></div>
<div class="stats"><div><b>62 Wh</b><span>Battery size</span></div><div><b>1:05</b><span>Time to full</span></div><div><b>214</b><span>Charge cycles</span></div><div><b>31 W</b><span>Charging</span></div></div>
<div class="pills"><span class="l">Power profile</span><div><em>{ic("eco")}Saver</em><em class="on">{ic("balance")}Balanced</em><em>{ic("bolt")}Performance</em></div></div></div>''',
     "media": f'''<div class="card" style="width:352px;gap:24px"><div class="now"><div class="art" style="background:url('file://{t["arts"][1][1]}') 30% 40%/200% auto"></div><div class="tt"><b>The Visit</b><i>Agar Agar</i><div class="tr"><span class="b">{ic("prev",20)}</span><span class="play">{ic("pause",20)}</span><span class="b">{ic("next",20)}</span></div></div></div>
<div class="rail" style="gap:16px"><div class="hair"><i style="width:56%"></i></div><div class="lbl">2:22<span>-1:48</span></div></div></div>''',
     "mood": f'''<div class="card" style="width:352px;gap:16px"><div class="mood"><span style="background:url('file://{t["arts"][0][1]}') 10% 20%/180% auto"></span><span style="background:url('file://{t["arts"][1][1]}') 70% 30%/180% auto"></span><span style="background:url('file://{t["arts"][1][1]}') 20% 80%/180% auto"></span><span style="background:url('file://{t["arts"][0][1]}') 80% 70%/180% auto"></span></div><div class="hd" style="height:auto"><div>Backgrounds<div style="font-size:14px;color:var(--muted);font-weight:400;margin-top:4px">Graded to the ground</div></div><span>7 per tone</span></div></div>''',
     "notes": f'''<div class="card notes" style="width:352px;gap:24px"><div class="hd" style="justify-content:flex-start">Quick note</div><div class="page">Leave a little room for the unexpected.</div><span class="chip2">Draft · This session</span></div>''',
     "files": f'''<div class="card" style="width:352px;gap:16px"><div class="hd" style="height:auto"><div style="display:flex;gap:8px;align-items:center">{ic("chevron_left",20)}{ic("chevron_right",20)}<span style="height:32px;padding:0 16px;border-radius:16px;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;gap:8px;font-size:14px;font-weight:400">{ic("home",16)}Home</span></div>{ic("search",20)}</div>
<div class="files"><div class="sb"><div class="on">{ic("home",16)}Home</div><div>{ic("clock",16)}Recent</div><div>{ic("star",16)}Starred</div><div>{ic("trash",16)}Trash</div></div>
<div class="fg">{"".join(f'<div class="fd"><svg width="40" height="32" viewBox="0 0 56 44"><path d="M2 8a4 4 0 0 1 4-4h14l4 4h24a4 4 0 0 1 4 4v26a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z" fill="#e9cf86"/><path d="M2 14h52v24a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z" fill="#f3dd9a"/></svg><span>{f}</span></div>' for f in ("Desktop","Documents","Downloads","Music","Pictures","Videos"))}</div></div></div>''',
     "picker": f'''<div class="card picker" style="width:352px;gap:16px"><div class="tabs"><span class="on">Screens</span><span>Windows</span><span>Region</span></div>
<div class="shots"><div class="shot on"><i style="background:url('file://{t["arts"][0][1]}') center/cover"></i>DP-1 · 3840 × 2160</div><div class="shot"><i style="background:url('file://{t["arts"][1][1]}') center/cover"></i>eDP-1 · 2880 × 1800</div></div><span class="go">Share</span></div>''',
     "lock": f'''<div class="card lock" style="width:352px"><div class="mark">Marvin</div><div class="in">{ic("lock",20)}<span class="dots"><i></i><i></i><i></i><i></i><i></i><i></i></span></div></div>''',
     "polkit": f'''<div class="card pk" style="width:352px;gap:24px"><div class="row2"><div class="ic">{ic("battery",20)}</div><div class="tt"><b>Authentication required</b><span>Omarchy wants to change the power profile. Enter your password to allow this.</span></div></div><div class="in"><i></i><i></i><i></i><i></i><i></i><i></i></div><div class="btns"><span>Cancel</span><span class="go">Authenticate</span></div></div>''',
     "terminal": f'''<div class="card term" style="width:352px;gap:0;padding:24px"><div><span class="p">❯</span> omarchy theme set marvin
<span class="c">Theme set to marvin</span>
<span class="p">❯</span> omarchy theme list
<span class="c">marvin  marvin-light  nord  …</span>
<span class="p">❯</span> <span style="display:inline-block;width:8px;height:16px;background:var(--fg);vertical-align:-3px"></span></div></div>''',
     "menu": f'''<div class="launcher menu" style="width:352px"><div class="hd" style="height:32px;display:flex;align-items:center;justify-content:space-between;font-size:16px;font-weight:500">Omarchy<span style="font-size:12px;color:var(--muted);font-weight:400">SUPER + ALT + SPACE</span></div><div class="rows">
<div class="row sel">{ic("apps",20)}<span class="n">Apps</span><span class="ch">{ic("chevron_right",16)}</span></div><div class="row">{ic("star",20)}<span class="n">Style</span><span class="ch">{ic("chevron_right",16)}</span></div><div class="row">{ic("search",20)}<span class="n">Capture</span><span class="ch">{ic("chevron_right",16)}</span></div><div class="row">{ic("balance",20)}<span class="n">Toggle</span><span class="ch">{ic("chevron_right",16)}</span></div><div class="row">{ic("download",20)}<span class="n">Install</span><span class="ch">{ic("chevron_right",16)}</span></div><div class="row">{ic("update",20)}<span class="n">Update</span><span class="ch">{ic("chevron_right",16)}</span></div></div></div>''',
     "clipboard": f'''<div class="launcher clip" style="width:352px"><div class="field">{ic("search",20)}<div><i>Search clipboard</i></div></div><div class="rows">
<div class="row sel"><span class="n">Padding equals radius, so content sits at the centre of the corner arc.</span><span class="k">2m</span></div><div class="row"><span class="n">https://github.com/adamperlis/omarchy-marvin</span><span class="k">14m</span></div><div class="row"><span class="n">omarchy theme set marvin-light</span><span class="k">1h</span></div><div class="row"><span class="n">#7aa6ff</span><span class="k">3h</span></div></div></div>''',
     "themes": f'''<div class="card pick" style="width:352px;gap:12px"><div class="hd" style="height:auto">Theme<span>4 of 22</span></div><div class="strip"><div class="th"><i style="background:url('file://{t["arts"][1][1]}') center/cover"></i></div><div class="th on"><i style="background:url('file://{t["arts"][0][1]}') center/cover"></i></div><div class="th"><i style="background:linear-gradient(135deg,#1a1b26,#414868)"></i></div></div><div class="names"><span>Marvin Light</span><span class="on">Marvin</span><span>Tokyo Night</span></div></div>''',
     "type": f'''<div class="card spec" style="width:352px"><div class="hd">Type scale<span>Inter · 12 to 56</span></div><div class="r"><div class="d">56</div><span>display-large · 400 · −3%</span></div><div class="r"><div class="h">Heading</div><span>18 · 500</span></div><div class="r"><div class="t">Title</div><span>16 · 500</span></div><div class="r"><div class="b">Body, the working size</div><span>14 · 400</span></div><div class="r"><div class="c">Caption and labels</div><span>12 · 400</span></div></div>''',
     "colour": f'''<div class="card" style="width:352px;gap:16px"><div class="hd">Colour<span>one accent</span></div><div class="sw"><div><i style="background:{t["bg"]}"></i>base {t["bg"]}</div><div><i style="background:{t["raised"]}"></i>raised {t["raised"]}</div><div><i style="background:{t["fg"]}"></i>text {t["fg"]}</div><div><i style="background:{t["muted"]}"></i>muted {t["muted"]}</div><div><i style="background:{t["accent"]}"></i>accent {t["accent"]}</div><div><i style="background:{t["chip"][0]}"></i>chip {t["chip"][0]}</div><div><i style="background:{t["red"]}"></i>error {t["red"]}</div><div><i style="background:{t["green"]}"></i>ok {t["green"]}</div></div></div>''',
     "buttons": f'''<div class="card bset" style="width:352px;gap:16px"><div class="hd">Buttons<span>normal · hover · pressed</span></div><div class="row3"><span class="bt pri">Save</span><span class="bt pri hov">Save</span><span class="bt pri dis">Save</span></div><div class="row3"><span class="bt sec">Cancel</span><span class="bt sec hov">Cancel</span><span class="bt sec on">Cancel</span></div><div class="row3"><span class="bt gho">{ic("chevron_left",16)}Back</span><span class="bt gho hov">{ic("chevron_left",16)}Back</span><span class="bt sec">{ic("search",16)}</span><span class="bt sec on">{ic("star",16)}</span></div></div>''',
     "fields": f'''<div class="card flds" style="width:352px;gap:16px"><div class="hd">Fields<span>never an accent ring</span></div><div class="fld">{ic("search",16)}Search</div><div class="fld foc">{ic("search",16)}fire<span class="cur"></span></div><div class="fld err">{ic("lock",16)}••••••<span style="margin-left:auto;font-size:12px;color:var(--red)">Wrong password</span></div><div class="ctl"><div><span class="tg on"><i></i></span>On</div><div><span class="tg"><i></i></span>Off</div><div><span class="cb on">{ic("check",12)}</span>Done</div><div><span class="cb"></span>Open</div><div><span class="rd on"></span></div><div><span class="rd"></span></div></div></div>''',
     "icons": f'''<div class="card" style="width:352px;gap:16px"><div class="hd">Icons<span>Material · 16 / 20 / 24</span></div><div class="icons">{"".join(ic(n,20) for n in ("apps","search","wifi","bluetooth","volume","battery_full","update","home","clock","star","trash","download","network","lock","sun","cloud","partly","moon","eco","balance","bolt","prev","pause","next"))}</div></div>''',
     "toast": f'''<div class="toast" style="width:352px">{ic("check",20)}<div class="m">Theme set to Marvin<span>Light · 22 wallpapers</span></div><span class="bt sec" style="height:32px;padding:0 16px;border-radius:16px;font-size:13px">Undo</span></div>''',
     "osd": f'''<div class="osd">{ic("volume",20)}<div class="hair"><i style="width:64%"></i></div><div class="n">64</div></div>''',
     "todos": f'''<div class="card" style="width:352px;gap:16px"><div class="hd">To-dos<span>3 of 6</span></div>
<div style="display:flex;flex-direction:column;gap:14px">
<div style="display:flex;align-items:center;gap:12px;font-size:14px"><span class="cb on">{ic("check",12)}</span><s style="color:var(--muted)">Blur the gradient rooms</s></div>
<div style="display:flex;align-items:center;gap:12px;font-size:14px"><span class="cb on">{ic("check",12)}</span><s style="color:var(--muted)">Compress the wallpapers</s></div>
<div style="display:flex;align-items:center;gap:12px;font-size:14px"><span class="cb on">{ic("check",12)}</span><s style="color:var(--muted)">Compose the bento desktop</s></div>
<div style="display:flex;align-items:center;gap:12px;font-size:14px"><span class="cb"></span>Credit Marvin up top</div>
<div style="display:flex;align-items:center;gap:12px;font-size:14px"><span class="cb"></span>Try it on Omarchy</div>
</div></div>''',
    }

def esc(s): return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def editor_lines(t, src):
    kw = re.compile(r'^(\[[a-z-]+\])')
    out = []
    for n, line in enumerate(src, 1):
        l = esc(line.rstrip("\n"))
        if l.startswith("#"): body = f'<span style="color:{t["muted"]}">{l}</span>'
        elif kw.match(l): body = f'<span style="color:{t["magenta"]}">{l}</span>'
        elif "=" in l:
            k, v = l.split("=", 1)
            v2 = re.sub(r'(&quot;|")([^"]*)(&quot;|")', lambda m: f'<span style="color:{t["green"]}">{m.group(0)}</span>', v)
            v2 = re.sub(r'(?<![\w#])(-?\d+(\.\d+)?)(?![\w])', lambda m: f'<span style="color:{t["yellow"]}">{m.group(0)}</span>', v2) if '"' not in v else v2
            body = f'<span style="color:{t["blue"]}">{k}</span>={v2}'
        else: body = l
        out.append(f'<div class="ln"><span class="no">{n}</span>{body}</div>')
    return "".join(out)

def desktop(t, fonts):
    src = open(ROOT / "shell.toml").read().split("\n")[52:92]
    swatch = "".join(f'<span style="display:inline-block;width:20px;height:12px;background:{c};margin-right:4px;border-radius:2px"></span>' for c in t["ansi"][:8])
    swatch2 = "".join(f'<span style="display:inline-block;width:20px;height:12px;background:{c};margin-right:4px;border-radius:2px"></span>' for c in t["ansi"][8:])
    procs = [("omarchy-shell","1.8","412M"),("firefox","3.1","1.2G"),("Hyprland","0.9","188M"),("pipewire","0.4","31M"),("nvim","0.2","64M"),("ghostty","0.1","52M"),("tailscaled","0.0","28M"),("btop","0.3","19M")]
    plist = "".join(f'<div class="pr"><span>{n}</span><span class="m">{c}%</span><span class="m">{m}</span></div>' for n,c,m in procs)
    pts = [12,14,11,18,22,17,26,31,24,28,35,30,22,19,24,29,38,33,27,25,21,26,30,36,40,34,29,24,20,23]
    poly = " ".join(f"{i*10},{60-p}" for i,p in enumerate(pts))
    folders = ["Desktop","Documents","Downloads","Dropbox","Music","Pictures","Public","Videos"]
    fgrid = "".join(f'<div class="fd"><svg width="56" height="44" viewBox="0 0 56 44"><path d="M2 8a4 4 0 0 1 4-4h14l4 4h24a4 4 0 0 1 4 4v26a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z" fill="#e9cf86"/><path d="M2 14h52v24a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z" fill="#f3dd9a"/></svg><span>{f}</span></div>' for f in folders)
    side = "".join(f'<div class="si{" on" if n=="Home" else ""}">{ic(i,16)}{n}</div>' for i,n in (("home","Home"),("clock","Recent"),("star","Starred"),("network","Network"),("trash","Trash"),("download","Downloads")))
    obs_side = "".join(f'<div class="si{" on" if n=="Principles" else ""}">{ic("text",16)}{n}</div>' for n in ("Principles","Grid","Type scale","Motion","Backgrounds","Widgets"))
    w = widgets(t)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_face(fonts)}{vars_css(t)}{BASE_CSS}
html,body{{width:1800px;height:1012px;overflow:hidden}}
body{{background:url('file://{t["wall"]}') center/cover}}
.win{{position:absolute;background:var(--bg);border-radius:24px;overflow:hidden;box-shadow:0 8px 40px rgba(0,0,0,var(--sh)),0 0 0 1px rgba(var(--fg-rgb),var(--a2))}}
.win.focus{{box-shadow:0 12px 48px rgba(0,0,0,var(--sh)),0 0 0 1px rgba(var(--fg-rgb),.16)}}
.ed{{padding:16px 20px 64px;font-size:13px;line-height:20px;height:100%;overflow:hidden}}.ln{{display:flex;white-space:pre}}.no{{width:40px;color:var(--muted);text-align:right;margin-right:20px;font-variant-numeric:tabular-nums}}
.status{{position:absolute;left:16px;right:16px;bottom:12px;height:32px;border-radius:16px;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;gap:16px;padding:0 16px;font-size:11px}}
.status b{{font-weight:500;color:var(--fg)}}.status span{{color:var(--muted)}}
.term{{padding:16px 20px;font-size:13px;line-height:20px;white-space:pre}}
.term .p{{color:var(--accent)}}.term .c{{color:var(--muted)}}
.mon{{padding:16px 20px;font-size:12px;line-height:20px}}.mon h4{{margin:0 0 8px;font:500 13px Inter}}.mon .sec{{margin-bottom:16px}}.mon .lab{{display:flex;justify-content:space-between;font-size:11px;color:var(--muted);margin-bottom:6px}}
.pr{{display:grid;grid-template-columns:1fr 60px 70px;font-family:'JetBrains Mono';font-size:12px}}.pr .m{{color:var(--muted);text-align:right}}
.obs{{display:grid;grid-template-columns:272px 1fr;height:100%}}.obs .sb{{background:var(--bg);padding:24px 16px;display:flex;flex-direction:column;gap:4px}}
.obs .vault{{font-size:12px;color:var(--muted);padding:0 16px 12px}}.obs .sb .si{{height:40px;border-radius:20px;padding:0 16px;display:flex;align-items:center;gap:12px}}.obs .sb .si.on{{background:rgba(var(--fg-rgb),var(--a3));font-weight:500}}
.obs .ed{{background:var(--raised);position:relative;padding:0}}.obs .tabs{{height:48px;display:flex;align-items:center;gap:8px;padding:8px 16px}}.obs .tab{{height:32px;padding:0 16px;border-radius:16px;display:flex;align-items:center;color:var(--muted)}}.obs .tab.on{{background:rgba(var(--fg-rgb),var(--a3));color:var(--fg);font-weight:500}}
.obs .doc{{padding:24px 32px;max-width:640px;font-size:15px;line-height:1.5}}.obs h1{{font-size:32px;font-weight:500;letter-spacing:-.02em;margin:0 0 16px;line-height:1.15}}.obs h2{{font-size:18px;font-weight:500;margin:24px 0 8px}}.obs p{{margin:0 0 12px}}
.obs .chk{{display:flex;align-items:center;gap:10px;margin:4px 0}}.obs .chk i{{width:16px;height:16px;border-radius:8px;border:1.5px solid var(--muted);display:inline-block}}.obs .chk i.d{{background:var(--accent);border-color:var(--accent)}}.obs .chk s{{color:var(--muted)}}
.obs .tag{{display:inline-flex;align-items:center;height:24px;padding:0 12px;border-radius:16px;background:rgba(var(--acc-rgb),.12);color:var(--accent);font-size:13px;font-weight:500;margin-right:8px}}
.obs code{{font-family:'JetBrains Mono';font-size:13px;background:rgba(var(--fg-rgb),var(--a1));border-radius:8px;padding:2px 6px}}.obs blockquote{{margin:12px 0;padding-left:16px;border-left:2px solid var(--accent);color:var(--muted)}}
.obs .status{{position:absolute;left:16px;right:16px;bottom:12px;height:32px;display:flex;align-items:center;justify-content:flex-end;gap:16px;font-size:11px;color:var(--muted)}}
.files{{display:grid;grid-template-columns:272px 1fr;height:100%;gap:0;min-height:0}}.files .sb{{width:auto;padding:24px 16px;display:flex;flex-direction:column;gap:4px;background:var(--raised)}}.files .si{{width:auto}}
.si{{height:40px;border-radius:20px;padding:0 16px;display:flex;align-items:center;gap:12px;color:var(--fg)}}.si.on{{background:rgba(var(--fg-rgb),var(--a3))}}
.files .main{{padding:24px}}.files .top{{display:flex;align-items:center;gap:12px;margin-bottom:24px}}.files .top .pathf{{height:40px;flex:1;border-radius:20px;background:rgba(var(--fg-rgb),var(--a1));display:flex;align-items:center;padding:0 16px;gap:8px}}
.fgrid{{display:grid;grid-template-columns:repeat(4,1fr);gap:20px 12px}}.fd{{display:flex;flex-direction:column;align-items:center;gap:8px;font-size:11px}}
.tile{{position:absolute;border-radius:24px;overflow:hidden;box-shadow:0 10px 36px rgba(0,0,0,var(--sh)),inset 0 0 0 1px rgba(var(--fg-rgb),var(--a2))}}
.tile>.win{{position:static;width:100%;height:100%;box-shadow:none;border-radius:0}}
.tile>.card{{width:100%!important;height:100%!important;justify-content:flex-start;box-shadow:none;border:none;border-radius:0}}
</style></head><body>
{bar(t)}
<div class="tile" style="left:24px;top:56px;width:720px;height:600px"><div class="win focus">
  <div class="obs"><div class="sb"><div class="vault">Notes</div>{obs_side}</div>
  <div class="ed"><div class="tabs"><div class="tab on">Principles</div><div class="tab">Grid</div><div class="tab">Motion</div></div>
  <div class="doc"><h1>Principles</h1>
  <p>Understand the grid, set a clean type scale, art-direct a few key widgets, then propagate. After that it gets rather easy.</p>
  <h2>Rules</h2>
  <div class="chk"><i class="d"></i><s>Every step in a scale must be perceptible</s></div>
  <div class="chk"><i class="d"></i><s>Depth from surfaces, not outlines</s></div>
  <div class="chk"><i></i>Tone is a property of each surface</div>
  <div class="chk"><i></i>Large numerals, small labels</div>
  <p style="margin-top:16px">Padding equals radius: <code>popup-padding = 16</code>, so content sits at the centre of the corner arc.</p>
  <blockquote>Leave a little room for the unexpected.</blockquote>
  <p><span class="tag">#design-system</span><span class="tag">#omarchy</span></p></div>
  <div class="status"><span>212 words</span><span>1,280 characters</span></div></div></div></div></div>
<div class="tile" style="left:24px;top:680px;width:720px;height:308px"><div class="win">
  <div class="files"><div class="sb">{side}</div><div class="main"><div class="top">{ic("chevron_left",20)}{ic("chevron_right",20)}<div class="pathf">{ic("home",16)}Home</div>{ic("search",20)}</div><div class="fgrid">{fgrid}</div></div></div>
</div></div>
<div class="tile" style="left:768px;top:56px;width:480px;height:280px"><div class="win">
  <div class="term mono"><span class="p">❯</span> omarchy theme set marvin
<span class="c">Theme set · radius 24 · type 12–56</span>
<span class="p">❯</span> omarchy theme list
<span class="c">marvin · marvin-light · nord · …</span>
<span class="p">❯</span> ./test/run
<span style="color:{t["green"]}">ok</span>  contrast floors   <span class="c">40 pairs</span>
<span style="color:{t["green"]}">ok</span>  shell parser      <span class="c">154 keys</span>
<span style="color:{t["green"]}">ok</span>  geometry identity <span class="c">94 tokens</span>
<span style="color:{t["green"]}">ok</span>  install → revert  <span class="c">byte for byte</span>
<span class="p">❯</span> <span style="display:inline-block;width:8px;height:16px;background:var(--fg);vertical-align:-3px"></span></div>
</div></div>
<div class="tile" style="left:1272px;top:56px;width:480px;height:250px">{w["weather"]}</div>
<div class="tile" style="left:1272px;top:330px;width:480px;height:214px">{w["todos"]}</div>
<div class="tile" style="left:768px;top:360px;width:480px;height:628px">{w["clock"]}</div>
<div class="tile" style="left:1272px;top:568px;width:480px;height:420px">{w["power"]}</div>
</body></html>"""

def boot(t, fonts):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_face(fonts)}{vars_css(t)}{BASE_CSS}
html,body{{width:1920px;height:1080px;overflow:hidden}}body{{background:{t["ground"] if t["light"] else "#0a0a0a"};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:48px}}
.mark{{font-size:96px;font-weight:500;letter-spacing:-.03em}}
.input{{width:280px;height:32px;border-radius:16px;background:rgba({hexrgb(t["raised"])},.85);display:flex;align-items:center;justify-content:center;gap:8px}}
.input i{{width:8px;height:8px;border-radius:4px;background:var(--fg)}}
</style></head><body><div class="mark">Marvin</div><div class="input"><i></i><i></i><i></i><i></i></div></body></html>"""

def workspace(t, fonts):
    """Bar over the wallpaper with one notification: the wallpaper as the ground."""
    w = widgets(t)
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_face(fonts)}{vars_css(t)}{BASE_CSS}
html,body{{width:1800px;height:1012px;overflow:hidden}}body{{background:url('file://{t["room"]}') center/cover;position:relative}}
.n{{position:absolute;right:16px;top:48px}}
</style></head><body>{bar(t)}<div class="n">{w["note"]}</div></body></html>"""

def backgrounds(t, fonts):
    """Both wallpapers of one tone, labelled, with the bar tone as a swatch beside each."""
    tiles = "".join(f"""<div class="bgtile"><div class="img" style="background:url('file://{p}') center/cover"></div>
<div class="cap"><b>{n.split('.')[0][2:].capitalize()}</b><span>{'light' if t['light'] else 'dark'} · 3840 × 2160 · graded to {t['ground']}</span></div></div>""" for n, p in t["walls"])
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_face(fonts)}{vars_css(t)}{BASE_CSS}
html,body{{width:1600px;height:1100px;overflow:hidden}}body{{background:{t["ground"]};padding:48px;display:flex;flex-wrap:wrap;gap:40px 48px;justify-content:center;align-content:start}}
.bgtile{{display:flex;flex-direction:column;gap:12px}}.img{{width:464px;height:261px;border-radius:16px;box-shadow:0 12px 32px rgba(0,0,0,var(--sh))}}
.cap{{display:flex;justify-content:space-between;align-items:baseline;padding:0 4px}}.cap b{{font-size:15px;font-weight:500}}.cap span{{font-size:11px;color:var(--muted)}}
</style></head><body>{tiles}</body></html>"""

def sheet(t, fonts):
    """Three columns, a caption above each card, cards at their natural height."""
    w = widgets(t)
    ground = "#f5f5f5" if t["light"] else "#0f0f0f"
    def cell(label, html): return f'<div class="cell"><div class="lab">{label}</div>{html}</div>'
    # The lock card sits at the dead centre of the sheet; the middle column
    # stacks away from it, upward above and downward below.
    # Three columns in flow, balanced to the same height; the lock card sits
    # at the middle of the middle column.
    cols = [
        cell("Music", w["media"]) + cell("Launcher", w["launcher"]) + cell("Omarchy menu", w["menu"]) + cell("Notes · Obsidian", w["notes"]) + cell("Theme picker", w["themes"]) + cell("Type scale", w["type"]) + cell("Buttons", w["buttons"]) + cell("Toast", w["toast"]),
        cell("Battery", w["power"]) + cell("Weather", w["weather"]) + cell("Lock screen", w["lock"]) + cell("Files", w["files"]) + cell("Clipboard", w["clipboard"]) + cell("Terminal", w["terminal"]) + cell("Colour", w["colour"]) + cell("Icons", w["icons"]),
        cell("Calendar", w["clock"]) + cell("Notification", w["note"]) + cell("Screen share", w["picker"]) + cell("Authentication", w["polkit"]) + cell("Backgrounds", w["mood"]) + cell("Volume", w["osd"]) + cell("Fields", w["fields"]),
    ]
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{font_face(fonts)}{vars_css(t)}{BASE_CSS}
html,body{{width:1600px;height:2760px;overflow:hidden}}body{{background:{ground};padding:56px 0}}
.g{{display:grid;grid-template-columns:352px 352px 352px;gap:0 56px;justify-content:center;align-items:start}}
.col{{display:flex;flex-direction:column;gap:40px}}

.cell{{display:flex;flex-direction:column;gap:12px}}.lab{{font-size:12px;color:var(--muted);padding-left:4px}}
.card,.note,.launcher{{width:352px}}
</style></head><body><div class="g">{"".join(f'<div class="col">{c}</div>' for c in cols)}</div></body></html>"""

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--fonts", required=True); ap.add_argument("--out", default=str(ROOT)); a = ap.parse_args()
    out = pathlib.Path(a.out); tmp = pathlib.Path(tempfile.mkdtemp())
    jobs = []
    for light in (False, True):
        t = tone(ROOT, light); pre = "light/" if light else ""; tag = "light" if light else "dark"
        for name, html, size, dests in (
            ("desktop", desktop(t, a.fonts), (1800, 1012), [out / f"{pre}preview.png"]),
            ("boot", boot(t, a.fonts), (1920, 1080), [out / f"{pre}preview-unlock.png"]),
            ("widgets", sheet(t, a.fonts), (1600, 2760), [out / f"docs/images/widgets-{tag}.png"]),
            ("workspace", workspace(t, a.fonts), (1800, 1012), [out / f"docs/images/workspace-{tag}.png"]),
            ("backgrounds", backgrounds(t, a.fonts), (1600, 1100), [out / f"docs/images/backgrounds-{tag}.png"]),
        ):
            h = tmp / f"{name}-{tag}.html"; h.write_text(html)
            png = tmp / f"{name}-{tag}.png"
            subprocess.run(["node", str(HERE / "render.js"), str(h), str(png), str(size[0]), str(size[1])], check=True, env={**os.environ, "NODE_PATH": os.environ.get("NODE_PATH", "")})
            for d in dests:
                d.parent.mkdir(parents=True, exist_ok=True); d.write_bytes(png.read_bytes()); print("wrote", d.relative_to(out), size)
