#!/usr/bin/env python3
"""Marvin backgrounds.

Turns a source painting into a wallpaper the system can sit on: softened a
little, then graded toward the theme's ground so the bar and every card read
as surfaces over it rather than against it. The painting stays recognisable.

    tools/background.py --source path/to/painting.jpg --name lilies
    tools/background.py --palette lilies          # no source: synthesize a field

Outputs backgrounds/<n>-<name>.jpg (dark) and light/backgrounds/<n>-<name>.jpg.
Needs Pillow and numpy.

Grading, per tone:
  1. no blur by default (--blur, a fraction of the height, if you want one)
  2. push saturation up a little, so the field stays rich under the grading
  3. mix toward the theme ground colour, then clamp luminance into a band that
     keeps the bar (dark #161616 / light #f5f5f5) readable over it
  4. add fine grain so the gradients do not band
"""
import argparse, math, pathlib, sys, random
import numpy as np
from PIL import Image, ImageFilter

OUT_W, OUT_H = 3840, 2160
WORK_W, WORK_H = 960, 540

# Theme grounds, from colors.toml dark_background / darker_background and the
# light ramp. Luminance bands are in 0..1 relative luminance.
TONES = {
    "dark":  dict(ground=(0x0f, 0x0f, 0x0f), band=(0.020, 0.900), mix=0.00, sat=1.30, out="backgrounds"),
    "light": dict(ground=(0xeb, 0xeb, 0xeb), band=(0.200, 0.920), mix=0.04, sat=1.30, out="light/backgrounds"),
}

# Palette-derived fields for when no source painting is on disk. Colours are
# the dominant hues of the named work, not the work itself.
PALETTES = {
    # Water Lilies — teal water, blue-lilac sky reflections, pink blooms, ivory light
    "lilies":  ["#1f5a5e", "#2f6f9e", "#5f97c9", "#7e6fb8", "#c98ab0", "#3d7f7a", "#eee6cc"],
    # Impression, Sunrise — blue-grey harbour, orange sun, violet haze
    "sunrise": ["#3f5f83", "#7a97b5", "#c48a6e", "#ef7a3a", "#f7b955", "#5a5f93", "#d9c9bd"],
}

def hex_rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def luminance(rgb):  # rgb float 0..1, shape (...,3)
    c = np.where(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722

def synthesize(palette, seed):
    """A field of soft radial blobs in the palette over its own mean colour."""
    rng = np.random.default_rng(seed)
    cols = np.array([hex_rgb(c) for c in palette], dtype=np.float32) / 255
    base = cols.mean(axis=0)
    yy, xx = np.mgrid[0:WORK_H, 0:WORK_W].astype(np.float32)
    img = np.tile(base, (WORK_H, WORK_W, 1))
    for i in range(26):
        c = cols[rng.integers(len(cols))]
        cx, cy = rng.uniform(-0.1, 1.1) * WORK_W, rng.uniform(-0.1, 1.1) * WORK_H
        rx, ry = rng.uniform(0.10, 0.34) * WORK_W, rng.uniform(0.10, 0.34) * WORK_H
        w = np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2))[..., None] * rng.uniform(0.5, 0.9)
        img = img * (1 - w) + c * w
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


# Original compositions in the idiom of the 1910s avant-garde, drawn at 4K so
# nothing is upscaled and nothing is anyone else's copyright. "orphic" is
# Delaunay's Rythme: overlapping discs of concentric rings. "planes" is
# Malevich and Léger: flat rotated planes over an ivory ground.
POP = ["#2f93d3", "#1b2436", "#f9ecad", "#ffd23f", "#ef7a3a", "#e0475b", "#7e6fb8", "#2f8f6b"]
IVORY = "#f6f1e8"

# Corridors: a lit room. Four gradient planes (walls, floor, ceiling) recede
# in perspective to a small door or window at the far end; light blooms from
# it, and a whisper of grain keeps the gradients from banding. Every room is
# drawn from the system's own colours, plus the hot magenta and orange the
# reference runs on.
ROOMS = {
    #            far light,  left wall,  right wall, floor,      ceiling,    door,       door edge
    "ember":   ["#fff3d0", "#ff4d1f", "#ffa34a", "#ff7a3d", "#ffd9c2", "#d8290b", "#ffe27a"],
    "lilac":   ["#fbefff", "#e2c4ff", "#f2a7ff", "#ff6ad9", "#cfd2ff", "#17091b", "#ff7ad9"],
    "sky":     ["#ecf8ff", "#2f93d3", "#7fd0ff", "#1f3f7a", "#a8cbe9", "#d6f0ff", "#ffffff"],
    "citrus":  ["#fff8c0", "#ffd23f", "#c5df4f", "#ef7a3a", "#fbe98a", "#2a1a05", "#fff4a8"],
    "dusk":    ["#ffe0b0", "#8a6bb3", "#ff6a3d", "#3b2a5c", "#ffb08a", "#ffa8e0", "#fff0b0"],
    "tide":    ["#f4fbff", "#2f8f6b", "#6ea5d8", "#0f2a3a", "#bfe3ee", "#0f1626", "#5fc6ff"],
    "magenta": ["#ffd0f0", "#4a2a9a", "#38c0ff", "#ff5fd2", "#7c5ce0", "#ff3fb0", "#ff9a3d"],
}

def _srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float32) / 255
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def _lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)

def _sig(x, k):
    return 1 / (1 + np.exp(-np.clip(x / k, -30, 30)))

def _rect_mask(xx, yy, x0, y0, x1, y1, soft=0.6, shape="rect"):
    """1 inside the opening. Edges are crisp (a sub-pixel ramp). An arch rounds the top; a slot is just tall."""
    m = _sig(xx - x0, soft) * _sig(x1 - xx, soft) * _sig(yy - y0, soft) * _sig(y1 - yy, soft)
    if shape == "arch":
        cx, r = (x0 + x1) / 2, (x1 - x0) / 2
        cap = _sig(r - np.sqrt((xx - cx) ** 2 + (yy - (y0 + r)) ** 2), soft)
        m = np.where(yy < y0 + r, cap * _sig(yy - y0 + r, soft), m)
    return m

def room(palette, seed, grain=2.5):
    """A gradient room in perspective. Some edges are hard, some are soft; that mix is what makes it read as light."""
    rng = np.random.default_rng(seed)
    w, h = OUT_W // 2, OUT_H // 2
    far, left, right, floor, ceil, door, edge = (_srgb_to_lin(hex_rgb(c)) for c in palette)
    layout = rng.choice(["corridor", "corridor", "backwall", "corner"])
    # the vanishing point; a corner room puts it near one edge so only two or three planes show
    if layout == "corner":
        vx = (rng.uniform(0.04, 0.14) if rng.random() < 0.5 else rng.uniform(0.86, 0.96)) * w
        vy = rng.uniform(0.25, 0.75) * h
    else:
        vx, vy = rng.uniform(0.18, 0.82) * w, rng.uniform(0.30, 0.70) * h
    # the far plane: for a corridor it is the opening itself; for a back wall it is a big plane with an opening in it
    if layout == "backwall":
        fw, fh = rng.uniform(0.45, 0.80) * w, rng.uniform(0.55, 0.85) * h
    else:
        fw, fh = rng.uniform(0.06, 0.22) * w, rng.uniform(0.14, 0.40) * h
        if rng.random() < 0.35: fw, fh = fh * 0.45, fw * 1.8
    x0, x1, y0, y1 = vx - fw / 2, vx + fw / 2, vy - fh / 2, vy + fh / 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    dx, dy = xx - vx, yy - vy
    eps = 1e-6
    sx = np.where(dx > 0, (x1 - vx) / (dx + eps), (x0 - vx) / (dx - eps))
    sy = np.where(dy > 0, (y1 - vy) / (dy + eps), (y0 - vy) / (dy - eps))
    s_rect = np.minimum(sx, sy)
    ex = np.where(dx > 0, (w - vx) / (dx + eps), (0 - vx) / (dx - eps))
    ey = np.where(dy > 0, (h - vy) / (dy + eps), (0 - vy) / (dy - eps))
    s_scr = np.minimum(ex, ey)
    t = np.clip((1.0 - s_rect) / np.maximum(s_scr - s_rect, eps), 0, 1)
    in_far = _rect_mask(xx, yy, x0, y0, x1, y1, soft=0.6)
    # creases: each room decides whether its corners are knife-sharp or soft, per crease
    k_side = rng.choice([0.012, 0.03, 0.14]) * np.maximum(s_rect, 0.05)
    k_lr, k_fc = rng.choice([0.004, 0.02, 0.05]) * w, rng.choice([0.004, 0.02, 0.05]) * h
    side = _sig(sy - sx, k_side); lr = _sig(dx, k_lr); fc = _sig(dy, k_fc)
    dist = np.sqrt((np.clip(np.abs(dx) - fw / 2, 0, None) / w) ** 2 + (np.clip(np.abs(dy) - fh / 2, 0, None) / h) ** 2)
    lit = np.exp(-dist / rng.uniform(0.08, 0.18))
    depth = t ** rng.uniform(0.45, 0.8)
    # the opening inside the far plane (backwall) or the far plane itself (corridor, corner)
    if layout == "backwall":
        ow, oh = rng.uniform(0.10, 0.30) * fw, rng.uniform(0.25, 0.55) * fh
        if rng.random() < 0.4: ow, oh = oh * 0.5, ow * 1.6
        ox, oy = rng.uniform(x0 + ow, x1 - ow), rng.uniform(y0 + oh, y1 - oh * 0.6)
        shape = rng.choice(["rect", "rect", "arch"])
        opening = _rect_mask(xx, yy, ox - ow / 2, oy - oh / 2, ox + ow / 2, oy + oh / 2, 0.6, shape)
        frame = _rect_mask(xx, yy, ox - ow / 2 - 0.02 * w, oy - oh / 2 - 0.02 * w, ox + ow / 2 + 0.02 * w, oy + oh / 2 + 0.02 * w, 0.6, shape)
    else:
        shape = rng.choice(["rect", "rect", "arch"])
        opening = _rect_mask(xx, yy, x0, y0, x1, y1, 0.6, shape)
        frame = _rect_mask(xx, yy, x0 - 0.012 * w, y0 - 0.012 * w, x1 + 0.012 * w, y1 + 0.012 * w, 0.6, shape)
    rim = np.clip(frame - opening, 0, 1) * (rng.random() < 0.5)          # a bright rim around the opening, sometimes
    nested = rng.random() < 0.35                                             # a dark doorway with a lit slab inside it
    if nested:
        cx, cy = (ox, oy) if layout == "backwall" else (vx, vy)
        cw, ch = (ow, oh) if layout == "backwall" else (fw, fh)
        inner = _rect_mask(xx, yy, cx - cw * 0.22, cy - ch * 0.10, cx + cw * 0.22, cy + ch * 0.45, 0.6)
    img = np.zeros((h, w, 3), dtype=np.float32)
    for i in range(3):
        wall_c = left[i] * (1 - lr) + right[i] * lr
        vert_c = ceil[i] * (1 - fc) + floor[i] * fc
        plane = wall_c * side + vert_c * (1 - side)
        plane = (far[i] * (1 - depth) + plane * depth) * (1 - 0.18 * depth) + far[i] * 0.6 * lit * (1 - depth)
        if layout == "backwall":
            # the back wall is its own flat plane: a soft vertical gradient, darkening toward its bottom corners
            v = np.clip((yy - y0) / max(fh, 1), 0, 1)
            back = (ceil[i] * (1 - v) + wall_c * v) * (0.85 + 0.15 * (1 - np.abs((xx - vx) / max(fw / 2, 1))))
            plane = plane * (1 - in_far) + back * in_far
        dd = np.clip(((xx - x0) / max(fw, 1)) * 0.5 + ((yy - y0) / max(fh, 1)) * 0.5, 0, 1)
        door_c = door[i] * (1 - dd) + edge[i] * dd
        if nested:
            door_c = door_c * (1 - inner) + (edge[i] * 0.6 + far[i] * 0.4) * inner
        c = plane * (1 - opening) + door_c * opening
        c = c * (1 - rim) + edge[i] * rim
        img[..., i] = c
    im = Image.fromarray((_lin_to_srgb(img) * 255).astype(np.uint8))
    # bloom: light from the opening, wide and soft, screened over an image whose edges stay where they are
    glow = im.filter(ImageFilter.GaussianBlur(radius=h * 0.10))
    soft = im.filter(ImageFilter.GaussianBlur(radius=float(h * rng.choice([0.0, 0.004, 0.010]))))
    a = np.asarray(soft, dtype=np.float32); b = np.asarray(glow, dtype=np.float32)
    lum = (0.2126 * b[..., 0] + 0.7152 * b[..., 1] + 0.0722 * b[..., 2]) / 255
    a = 255 - (255 - a) * (255 - b * (0.5 * lum[..., None])) / 255
    big = np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((OUT_W, OUT_H), Image.BICUBIC), dtype=np.float32)
    big += rng.normal(0, grain, (OUT_H, OUT_W, 1)).astype(np.float32)
    return Image.fromarray(np.clip(big, 0, 255).astype(np.uint8))

def compose(style, seed, palette=None):
    from PIL import ImageDraw
    if style == "corridors":
        return room(ROOMS[palette or "ember"], seed)
    rng = random.Random(seed)
    S = 2  # supersample for clean edges
    W, H = OUT_W * S, OUT_H * S
    im = Image.new("RGB", (W, H), IVORY); d = ImageDraw.Draw(im)
    if style == "orphic":
        centres = [(0.28, 0.55, 0.62), (0.68, 0.40, 0.55), (0.55, 0.95, 0.45), (0.92, 0.85, 0.35)]
        for cx, cy, r in centres:
            cols = rng.sample(POP, len(POP)); n = rng.randint(7, 10)
            R = r * H
            for i in range(n):
                rr = R * (1 - i / n)
                d.ellipse((cx * W - rr, cy * H - rr, cx * W + rr, cy * H + rr), fill=cols[i % len(cols)])
        # two quarter arcs, the way Delaunay cuts a disc with another
        for _ in range(2):
            cx, cy, R = rng.uniform(0.1, 0.9) * W, rng.uniform(0.1, 0.9) * H, rng.uniform(0.25, 0.4) * H
            a0 = rng.choice([0, 90, 180, 270])
            d.pieslice((cx - R, cy - R, cx + R, cy + R), a0, a0 + 90, fill=rng.choice(POP))
    else:
        cols = rng.sample(POP, len(POP))
        for i in range(7):
            w, h = rng.uniform(0.18, 0.55) * W, rng.uniform(0.06, 0.32) * H
            cx, cy = rng.uniform(0.15, 0.85) * W, rng.uniform(0.15, 0.85) * H
            ang = rng.choice([0, 0, 12, -18, 30, 90])
            layer = Image.new("RGBA", (int(w) + 8, int(h) + 8), (0, 0, 0, 0))
            ImageDraw.Draw(layer).rectangle((4, 4, int(w) + 4, int(h) + 4), fill=cols[i % len(cols)])
            layer = layer.rotate(ang, expand=True, resample=Image.BICUBIC)
            im.paste(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)), layer)
        for _ in range(2):
            R = rng.uniform(0.08, 0.18) * H; cx, cy = rng.uniform(0.1, 0.9) * W, rng.uniform(0.1, 0.9) * H
            ImageDraw.Draw(im).ellipse((cx - R, cy - R, cx + R, cy + R), fill=rng.choice(POP))
    return im.resize((OUT_W, OUT_H), Image.LANCZOS)

def prepare_source(path, allow_upscale=False):
    im = Image.open(path).convert("RGB")
    # cover-crop to 16:9 at the source's own resolution; never upscale
    w, h = im.size
    target = OUT_W / OUT_H
    if w / h > target:
        nw = int(h * target); im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / target); im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    if (im.size[0] < OUT_W or im.size[1] < OUT_H) and not allow_upscale:
        sys.exit(f"{path}: {w}x{h} crops to {im.size[0]}x{im.size[1]}, under {OUT_W}x{OUT_H}; a 4K screen would have to upscale it. Pass --allow-upscale if the output is blurred anyway.")
    return im.resize((OUT_W, OUT_H), Image.LANCZOS)

def grade(im, tone, seed, blur=0.0, sat=None, mix=None, grain=1.6):
    t = dict(TONES[tone])
    if sat is not None: t["sat"] = sat
    if mix is not None: t["mix"] = mix
    if im.size != (OUT_W, OUT_H):
        im = im.resize((OUT_W, OUT_H), Image.BICUBIC)   # synthesized fields come in small
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(radius=OUT_H * blur))
    a = np.asarray(im, dtype=np.float32) / 255
    # saturation
    grey = a.mean(axis=2, keepdims=True)
    a = grey + (a - grey) * t["sat"]
    # mix toward ground
    ground = np.array(t["ground"], dtype=np.float32) / 255
    a = a * (1 - t["mix"]) + ground * t["mix"]
    # clamp luminance into the band by scaling around the ground
    lo, hi = t["band"]
    L = luminance(a)
    cur_lo, cur_hi = np.percentile(L, 1), np.percentile(L, 99)
    # map [cur_lo, cur_hi] -> [lo, hi] in luminance, applied as a per-pixel gain
    target = lo + (np.clip((L - cur_lo) / max(cur_hi - cur_lo, 1e-4), 0, 1)) * (hi - lo)
    gain = (target / np.maximum(L, 1e-4))[..., None]
    # apply gain in linear-ish space: cheap approximation via sqrt of gain on sRGB
    a = np.clip(a * np.sqrt(gain), 0, 1)
    # grain
    b = a * 255
    rng = np.random.default_rng(seed + 1)
    if grain > 0:
        b = np.clip(b + rng.normal(0, grain, b.shape).astype(np.float32), 0, 255)
    return Image.fromarray(b.astype(np.uint8))

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", help="path to a source painting (CC0 / public domain)")
    p.add_argument("--palette", choices=sorted(set(PALETTES) | set(ROOMS)), help="a named palette: for --style corridors one of the rooms, otherwise a synthesised field")
    p.add_argument("--name", help="output name; defaults to the palette name or the source stem")
    p.add_argument("--index", type=int, default=1, help="ordering prefix in backgrounds/")
    p.add_argument("--style", choices=("orphic", "planes", "corridors", "plain"), help="draw an original composition instead of grading a source; corridors takes --palette ember|lilac|sky|citrus|dusk|tide|magenta")
    p.add_argument("--allow-upscale", action="store_true", help="accept a source under 3840 × 2160 (fine when the output is blurred)")
    p.add_argument("--crop-out", help="also write the sharp, ungraded 16:9 crop at 1600 × 900 into this directory, for imagery inside the UI")
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--quality", type=int, default=88, help="JPEG quality (default 88)")
    p.add_argument("--sat", type=float, help="saturation multiplier; defaults to the tone's (1.3)")
    p.add_argument("--mix", type=float, help="mix toward the theme ground, 0..1; defaults to the tone's (0.05 dark, 0.06 light)")
    p.add_argument("--grain", type=float, default=1.6, help="grain sigma in 8-bit levels; 0 for none (default 1.6)")
    p.add_argument("--blur", type=float, default=0.0, help="Gaussian radius as a fraction of the height; 0 (default) for none")
    args = p.parse_args()
    if args.style == "plain":
        # No image: the reference's own ground, raised at the top falling to the base, grained.
        root = pathlib.Path(__file__).resolve().parent.parent
        for tone, top, bottom in (("dark", (0x1e, 0x1e, 0x1e), (0x0f, 0x0f, 0x0f)), ("light", (0xff, 0xff, 0xff), (0xeb, 0xeb, 0xeb))):
            yy = np.linspace(0, 1, OUT_H, dtype=np.float32)[:, None, None]
            a = np.array(top, dtype=np.float32) * (1 - yy) + np.array(bottom, dtype=np.float32) * yy
            a = np.broadcast_to(a, (OUT_H, OUT_W, 3)).copy()
            a += np.random.default_rng(args.seed).normal(0, 1.0, (OUT_H, OUT_W, 1)).astype(np.float32)
            out = root / TONES[tone]["out"] / f"{args.index}-{args.name or 'plain'}.jpg"
            out.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(out, "JPEG", quality=args.quality, optimize=True, progressive=True)
            print(f"{out.relative_to(root)}  {OUT_W}x{OUT_H}  plain ground  {out.stat().st_size // 1024} KB")
        return
    if not args.source and not args.palette and not args.style:
        p.error("give --source, --style or --palette")
    name = args.name or (args.palette if args.style == "corridors" else None) or args.style or args.palette or (pathlib.Path(args.source).stem if args.source else None)
    root = pathlib.Path(__file__).resolve().parent.parent
    base = compose(args.style, args.seed, args.palette) if args.style else (prepare_source(args.source, args.allow_upscale) if args.source else synthesize(PALETTES[args.palette], args.seed))
    if args.crop_out:
        cdir = pathlib.Path(args.crop_out); cdir.mkdir(parents=True, exist_ok=True)
        base.resize((1600, 900), Image.LANCZOS).save(cdir / f"{name}.jpg", "JPEG", quality=85, optimize=True, progressive=True)
        print(f"{cdir / (name + '.jpg')}  1600x900 sharp crop")
    for tone, t in TONES.items():
        out = root / t["out"] / f"{args.index}-{name}.jpg"
        out.parent.mkdir(parents=True, exist_ok=True)
        img = grade(base, tone, args.seed, args.blur, args.sat, args.mix, args.grain)
        img.save(out, "JPEG", quality=args.quality, optimize=True, progressive=True)
        L = luminance(np.asarray(img, dtype=np.float32) / 255)
        print(f"{out.relative_to(root)}  {img.size[0]}x{img.size[1]}  L p1/p50/p99 = {np.percentile(L,1):.3f}/{np.percentile(L,50):.3f}/{np.percentile(L,99):.3f}  {out.stat().st_size//1024} KB")

if __name__ == "__main__":
    sys.exit(main())
