# Backgrounds

Two public-domain paintings, unblurred, graded to each tone by
`tools/background.py`. The same files exist under `light/backgrounds/`,
graded to the light ground. Every source is at least 3840 wide, so a 4K
screen shows the painting at full resolution with no upscaling.

| File | Painting | Date | Source size | Status |
|------|----------|------|-------------|--------|
| `1-starry.jpg` | Vincent van Gogh, *The Starry Night* | 1889 | 5000 × 3959 | public domain (van Gogh d. 1890) |
| `2-composition.jpg` | Wassily Kandinsky, *Composition VII* | 1913 | 4032 × 3022 | public domain (Kandinsky d. 1944; published before 1930) |

The reproductions were taken from the style images vendored in
[Kautenja/a-neural-algorithm-of-artistic-style](https://github.com/Kautenja/a-neural-algorithm-of-artistic-style)
(`img/styles/`). Faithful photographs of public-domain paintings carry no
new copyright, so the graded files here are under this repository's MIT
licence.

Grading, per tone, at full 3840 × 2160: cover-crop to 16:9, no blur
(`--blur` adds one), saturation × 1.3, a 5–6 % mix toward the theme
ground, luminance clamped into a band the bar stays readable over (dark
0.02–0.34, light 0.30–0.90), then fine grain against banding. Output is
JPEG at quality 88, about 1–2 MB each; raise `--quality` if you want more.
Reproducible:

```
tools/background.py --source the-starry-night.jpg --name starry      --index 1
tools/background.py --source composition-vii.jpg  --name composition --index 2
```

The tool refuses a source smaller than 3840 × 2160 after the crop, so
nothing in this set is ever upscaled.
