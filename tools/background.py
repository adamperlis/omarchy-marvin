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
import argparse, math, pathlib, sys
import numpy as np
from PIL import Image, ImageFilter

OUT_W, OUT_H = 3840, 2160
WORK_W, WORK_H = 960, 540

# Theme grounds, from colors.toml dark_background / darker_background and the
# light ramp. Luminance bands are in 0..1 relative luminance.
TONES = {
    "dark":  dict(ground=(0x0f, 0x0f, 0x0f), band=(0.020, 0.340), mix=0.05, sat=1.30, out="backgrounds"),
    "light": dict(ground=(0xeb, 0xeb, 0xeb), band=(0.300, 0.900), mix=0.06, sat=1.30, out="light/backgrounds"),
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

def prepare_source(path):
    im = Image.open(path).convert("RGB")
    # cover-crop to 16:9 at the source's own resolution; never upscale
    w, h = im.size
    target = OUT_W / OUT_H
    if w / h > target:
        nw = int(h * target); im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / target); im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    if im.size[0] < OUT_W or im.size[1] < OUT_H:
        sys.exit(f"{path}: {w}x{h} crops to {im.size[0]}x{im.size[1]}, under {OUT_W}x{OUT_H}; a 4K screen would have to upscale it. Find a larger reproduction.")
    return im.resize((OUT_W, OUT_H), Image.LANCZOS)

def grade(im, tone, seed, blur=0.0):
    t = TONES[tone]
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
    b = np.clip(b + rng.normal(0, 1.6, b.shape).astype(np.float32), 0, 255)
    return Image.fromarray(b.astype(np.uint8))

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", help="path to a source painting (CC0 / public domain)")
    p.add_argument("--palette", choices=sorted(PALETTES), help="synthesize from a named palette instead")
    p.add_argument("--name", help="output name; defaults to the palette name or the source stem")
    p.add_argument("--index", type=int, default=1, help="ordering prefix in backgrounds/")
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--quality", type=int, default=88, help="JPEG quality (default 88)")
    p.add_argument("--blur", type=float, default=0.0, help="Gaussian radius as a fraction of the height; 0 (default) for none")
    args = p.parse_args()
    if not args.source and not args.palette:
        p.error("give --source or --palette")
    name = args.name or args.palette or pathlib.Path(args.source).stem
    root = pathlib.Path(__file__).resolve().parent.parent
    base = prepare_source(args.source) if args.source else synthesize(PALETTES[args.palette], args.seed)
    for tone, t in TONES.items():
        out = root / t["out"] / f"{args.index}-{name}.jpg"
        out.parent.mkdir(parents=True, exist_ok=True)
        img = grade(base, tone, args.seed, args.blur)
        img.save(out, "JPEG", quality=args.quality, optimize=True, progressive=True)
        L = luminance(np.asarray(img, dtype=np.float32) / 255)
        print(f"{out.relative_to(root)}  {img.size[0]}x{img.size[1]}  L p1/p50/p99 = {np.percentile(L,1):.3f}/{np.percentile(L,50):.3f}/{np.percentile(L,99):.3f}  {out.stat().st_size//1024} KB")

if __name__ == "__main__":
    sys.exit(main())
