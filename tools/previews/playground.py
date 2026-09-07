#!/usr/bin/env python3
"""Wallpaper bench: the desktop preview with live controls over the grade.

Builds one self-contained HTML page: the 1800 × 1012 desktop mock from
build.py in both tones over a chosen painting, with a DialKit panel for
blur, saturation, mix-to-ground and grain, and a filmstrip of every
candidate painting with its source size. The readout prints the exact
tools/background.py command that reproduces the current settings.

    tools/previews/playground.py --pool DIR --dialkit DIR --out bench.html

--pool holds 1600 × 900 previews plus manifest.json (see the scratch
script that built them); --dialkit is the unpacked npm package's
dist/vanilla directory. Needs no network at view time: images, the
DialKit bundle and its stylesheet are inlined; fonts come from Google
Fonts, the one font host the artifact sandbox admits.
"""
import argparse, base64, json, pathlib, re, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build  # noqa: E402

def data_uri(p, mime="image/jpeg"):
    return f"data:{mime};base64," + base64.b64encode(pathlib.Path(p).read_bytes()).decode()

def desktop_parts(t):
    """The desktop mock's own CSS (minus page sizing and wallpaper) and its body."""
    html = build.desktop(t, "/nonexistent")
    style = html.split("<style>", 1)[1].split("</style>", 1)[0]
    body = html.split("</style></head><body>", 1)[1].split("</body></html>", 1)[0]
    desk_css = style.split(build.BASE_CSS, 1)[1]
    desk_css = re.sub(r"html,body\{[^}]*\}\n?", "", desk_css)
    desk_css = re.sub(r"body\{background:url\([^)]*\)[^}]*\}\n?", "", desk_css)
    return desk_css, body

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pool", required=True); ap.add_argument("--dialkit", required=True); ap.add_argument("--out", required=True)
    a = ap.parse_args()
    pool = pathlib.Path(a.pool); dk = pathlib.Path(a.dialkit)
    manifest = json.load(open(pool / "manifest.json"))
    paintings = [dict(m, src=data_uri(pool / f"{m['key']}.jpg")) for m in manifest]
    tones = {}
    for light in (False, True):
        t = build.tone(build.ROOT, light)
        desk_css, body = desktop_parts(t)
        vars_ = build.vars_css(t).replace(":root{", f".tone-{'light' if light else 'dark'}{{", 1)
        tones["light" if light else "dark"] = dict(vars=vars_, body=body, ground=t["ground"], bg=t["bg"], fg=t["fg"], raised=t["raised"], muted=t["muted"], accent=t["accent"])
    desk_css, _ = desktop_parts(build.tone(build.ROOT, False))
    dk_js = (dk / "browser.global.js").read_text()
    dk_css = (dk / "styles.css").read_text()
    L, D = tones["light"], tones["dark"]
    strip = "".join(
        f'<button class="film" data-key="{m["key"]}" title="{m["artist"]}, {m["title"]} ({m["year"]})">'
        f'<img src="{m["src"]}" alt=""><span class="cap"><b>{m["title"]}</b><i>{m["artist"]}</i></span>'
        f'<span class="px{" ok" if m["eligible"] else ""}">{m["w"]} × {m["h"]}{"" if m["eligible"] else " · under 4K"}</span></button>'
        for m in paintings)
    page = f"""<title>Marvin Wallpaper Bench</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&family=Libre+Baskerville&display=swap">
<style>
{dk_css}
:root{{--pg-bg:{L["ground"]};--pg-raised:{L["raised"]};--pg-fg:{L["fg"]};--pg-muted:{L["muted"]};--pg-accent:{L["accent"]};--pg-fg-rgb:{build.hexrgb(L["fg"])};--pg-sh:.06}}
@media (prefers-color-scheme: dark){{:root:not([data-theme="light"]){{--pg-bg:{D["ground"]};--pg-raised:{D["raised"]};--pg-fg:{D["fg"]};--pg-muted:{D["muted"]};--pg-accent:{D["accent"]};--pg-fg-rgb:{build.hexrgb(D["fg"])};--pg-sh:.28}}}}
:root[data-theme="dark"]{{--pg-bg:{D["ground"]};--pg-raised:{D["raised"]};--pg-fg:{D["fg"]};--pg-muted:{D["muted"]};--pg-accent:{D["accent"]};--pg-fg-rgb:{build.hexrgb(D["fg"])};--pg-sh:.28}}
{build.BASE_CSS}
{L["vars"]}
{D["vars"]}
{desk_css}
html,body{{margin:0;background:var(--pg-bg);color:var(--pg-fg);font-family:Inter,system-ui,sans-serif;font-size:14px;line-height:1.4;-webkit-font-smoothing:antialiased}}
.page{{display:flex;flex-direction:column;gap:24px;padding:24px;min-height:100vh;box-sizing:border-box}}
.head{{display:flex;align-items:baseline;justify-content:space-between;gap:24px;flex-wrap:wrap;padding-right:320px}}
.head h1{{font-size:16px;font-weight:500;margin:0}}.head p{{margin:0;color:var(--pg-muted);max-width:64ch}}
.frame{{display:flex;justify-content:center}}
.scaler{{position:relative}}
.stage{{position:absolute;left:0;top:0;width:1800px;height:1012px;overflow:hidden;border-radius:24px;transform-origin:0 0;box-shadow:0 8px 40px rgba(0,0,0,var(--pg-sh)),0 0 0 1px rgba(var(--pg-fg-rgb),.10);isolation:isolate}}
.wall{{position:absolute;inset:-48px;background-size:cover;background-position:center;will-change:filter}}
.scrim{{position:absolute;inset:0;pointer-events:none}}
.grain{{position:absolute;inset:0;pointer-events:none;mix-blend-mode:overlay;opacity:.18}}
.tone{{position:absolute;inset:0}}.tone[hidden]{{display:none}}
.tone .bar{{position:absolute}}
.strip{{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}}
.film{{all:unset;cursor:pointer;display:flex;flex-direction:column;gap:8px;border-radius:16px;padding:8px;background:var(--pg-raised);box-shadow:0 0 0 1px rgba(var(--pg-fg-rgb),.10);color:var(--pg-fg)}}
.film:focus-visible{{box-shadow:0 0 0 1px rgba(var(--pg-fg-rgb),.24),0 0 0 4px rgba(var(--pg-fg-rgb),.10)}}
.film.on{{box-shadow:0 0 0 2px var(--pg-accent)}}
.film img{{display:block;width:100%;aspect-ratio:16/9;object-fit:cover;border-radius:10px}}
.film .cap{{display:flex;flex-direction:column;gap:2px;padding:0 4px}}.film .cap b{{font-weight:500;font-size:13px}}.film .cap i{{font-style:normal;color:var(--pg-muted);font-size:12px}}
.film .px{{font-size:11px;color:var(--pg-muted);padding:0 4px 4px;font-variant-numeric:tabular-nums}}.film .px.ok{{color:var(--pg-accent)}}
.readout{{display:grid;grid-template-columns:1fr auto;gap:12px 24px;align-items:center;background:var(--pg-raised);border-radius:24px;padding:16px 24px;box-shadow:0 0 0 1px rgba(var(--pg-fg-rgb),.10)}}
.readout .who{{display:flex;flex-direction:column;gap:2px}}.readout .who b{{font-weight:500}}.readout .who span{{color:var(--pg-muted);font-size:12px}}
.readout code{{font-family:'JetBrains Mono',monospace;font-size:12px;color:var(--pg-fg);white-space:nowrap;overflow-x:auto;display:block;grid-column:1/-1;padding:12px 16px;border-radius:12px;background:rgba(var(--pg-fg-rgb),.04)}}
.readout .flag{{font-size:12px;padding:6px 12px;border-radius:14px;background:rgba(var(--pg-fg-rgb),.05);color:var(--pg-muted);white-space:nowrap}}.readout .flag.ok{{color:var(--pg-accent)}}
@media (prefers-reduced-motion: no-preference){{.wall{{transition:filter .15s}}}}
</style>
<div class="page">
  <div class="head"><h1>Marvin Wallpaper Bench</h1><p>The desktop as the theme renders it, over a painting you grade live. Blur, saturation, mix toward the ground and grain map one to one onto <code style="font-family:'JetBrains Mono';font-size:12px">tools/background.py</code>; the command below reproduces whatever the panel shows. Tone switches the whole desktop.</p></div>
  <div class="frame"><div class="scaler" id="scaler"><div class="stage" id="stage">
    <div class="wall" id="wall"></div>
    <div class="scrim" id="scrim"></div>
    <svg class="grain" id="grain" xmlns="http://www.w3.org/2000/svg"><filter id="g"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 .5 0 0 0 0 .5 0 0 0 0 .5 0 0 0 1 0"/></filter><rect width="100%" height="100%" filter="url(#g)"/></svg>
    <div class="tone tone-light" id="tone-light">{L["body"]}</div>
    <div class="tone tone-dark" id="tone-dark" hidden>{D["body"]}</div>
  </div></div></div>
  <div class="readout"><div class="who" id="who"></div><div class="flag" id="flag"></div><code id="cmd"></code></div>
  <div class="strip" id="strip">{strip}</div>
</div>
<script>{dk_js}</script>
<script>
(function(){{
  var P = {json.dumps([{k: m[k] for k in ("key","artist","title","year","w","h","eligible")} for m in paintings])};
  var SRC = {{}};
  document.querySelectorAll('.film').forEach(function(b){{ SRC[b.dataset.key] = b.querySelector('img').src; }});
  var GROUND = {{light: "{L["ground"]}", dark: "{D["ground"]}"}};
  var titles = P.map(function(m){{ return m.title; }});
  var root = DialKit.createDialRoot({{position: "top-right"}});
  var kit = DialKit.createDialKit("Wallpaper", {{
    painting: {{type: "select", options: titles}},
    tone: {{type: "select", options: ["light", "dark"]}},
    blur: [0, 0, 60, 1],
    saturation: [1.3, 0.5, 2, 0.05],
    mix: [0.06, 0, 0.6, 0.01],
    grain: true,
    windows: true
  }}, {{persist: {{key: "marvin-bench"}}}});
  var wall = document.getElementById('wall'), scrim = document.getElementById('scrim'), grain = document.getElementById('grain');
  var who = document.getElementById('who'), flag = document.getElementById('flag'), cmd = document.getElementById('cmd');
  function apply(v){{
    var m = P[Math.max(0, titles.indexOf(v.painting))];
    var tone = v.tone === "dark" ? "dark" : "light";
    // the stage is 1012 tall; the tool works at 2160, so the same look is blur/1012 of the height
    var frac = v.blur / 1012;
    wall.style.backgroundImage = 'url("' + SRC[m.key] + '")';
    wall.style.filter = 'saturate(' + v.saturation + ') blur(' + v.blur + 'px)';
    scrim.style.background = GROUND[tone]; scrim.style.opacity = v.mix;
    grain.hidden = !v.grain;
    document.getElementById('tone-light').hidden = tone !== "light";
    document.getElementById('tone-dark').hidden = tone !== "dark";
    document.querySelectorAll('#tone-light .win, #tone-light .bar, #tone-light > div[style], #tone-dark .win, #tone-dark .bar, #tone-dark > div[style]').forEach(function(el){{ el.style.visibility = v.windows ? '' : 'hidden'; }});
    document.querySelectorAll('.film').forEach(function(b){{ b.classList.toggle('on', b.dataset.key === m.key); }});
    who.innerHTML = '<b>' + m.artist + ', <i style="font-style:normal">' + m.title + '</i> (' + m.year + ')</b><span>source ' + m.w + ' × ' + m.h + ' · shown in the ' + tone + ' tone</span>';
    flag.textContent = m.eligible ? 'Full resolution on a 4K screen' : 'Under 3840 wide: a 4K screen would upscale it';
    flag.classList.toggle('ok', m.eligible);
    cmd.textContent = 'tools/background.py --source ' + m.key + '.jpg --name ' + m.key + ' --index 1 --blur ' + frac.toFixed(4) + ' --sat ' + v.saturation.toFixed(2) + ' --mix ' + v.mix.toFixed(2) + ' --grain ' + (v.grain ? '1.6' : '0');
  }}
  kit.subscribe(apply);
  document.getElementById('strip').addEventListener('click', function(e){{
    var b = e.target.closest('.film'); if (!b) return;
    var m = P.find(function(x){{ return x.key === b.dataset.key; }});
    if (kit.set) kit.set({{painting: m.title}}); else if (kit.setValues) kit.setValues({{painting: m.title}}); else if (kit.update) kit.update({{painting: m.title}});
  }});
  function fit(){{
    var pad = 48, w = Math.min(window.innerWidth - pad, 1800), s = w / 1800;
    var sc = document.getElementById('scaler'); sc.style.width = (1800 * s) + 'px'; sc.style.height = (1012 * s) + 'px';
    document.getElementById('stage').style.transform = 'scale(' + s + ')';
  }}
  window.addEventListener('resize', fit); fit();
}})();
</script>
"""
    pathlib.Path(a.out).write_text(page)
    print(f"wrote {a.out} ({pathlib.Path(a.out).stat().st_size // 1024} KB, {len(paintings)} paintings)")

if __name__ == "__main__":
    main()
