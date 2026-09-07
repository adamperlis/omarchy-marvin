# Backgrounds

Four wallpapers per tone, each blurred into a colour field by
`tools/background.py`; the same four, sharp, live in `docs/images/art/`
for imagery inside the UI. The light set is under `light/backgrounds/`.

| File | Work | Source | Status |
|------|------|--------|--------|
| `1-orphic.jpg` | *Orphic*, an original composition after Robert Delaunay's *Rythme* | drawn at 3840 × 2160 by the tool (`--style orphic --seed 11`) | this repository's MIT licence |
| `2-composition.jpg` | Wassily Kandinsky, *Composition VII* (1913) | 4032 × 3022 | public domain (Kandinsky d. 1944; published before 1930) |
| `3-edtaonisl.jpg` | Francis Picabia, *Edtaonisl* (1913) | 800 × 776, upscaled under the blur (`--allow-upscale`) | public domain (Picabia d. 1953; published before 1930) |
| `4-planes.jpg` | *Planes*, an original after Malevich and Léger | drawn at 3840 × 2160 by the tool (`--style planes --seed 5`) | this repository's MIT licence |

The reproductions come from style images vendored in
[Kautenja/a-neural-algorithm-of-artistic-style](https://github.com/Kautenja/a-neural-algorithm-of-artistic-style)
and [gordicaleksa/pytorch-neural-style-transfer](https://github.com/gordicaleksa/pytorch-neural-style-transfer).
Faithful photographs of public-domain paintings carry no new copyright.

Grading, per tone, at 3840 × 2160: cover-crop to 16:9, Gaussian blur at
4.5 % of the height, saturation × 1.3, a 0–4 % mix toward the theme
ground, luminance kept inside 0.02–0.90 (dark) or 0.20–0.92 (light), then
fine grain against banding. The dark tone is not dimmed. `--crop-out DIR`
also writes the sharp 1600 × 900 crop for the UI. JPEG quality 88.

```
tools/background.py --style orphic --index 1 --blur 0.045 --seed 11 --crop-out docs/images/art
tools/background.py --source composition-vii.jpg --name composition --index 2 --blur 0.045 --crop-out docs/images/art
tools/background.py --source edtaonisl.jpg --name edtaonisl --index 3 --blur 0.045 --allow-upscale --crop-out docs/images/art
tools/background.py --style planes --index 4 --blur 0.045 --seed 5 --crop-out docs/images/art
```

A source under 3840 × 2160 is refused unless `--allow-upscale` is passed;
under a full blur the upscale is invisible, sharp it would not be.
