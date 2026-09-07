# Backgrounds

Three public-domain paintings, lightly softened and graded to each
tone by `tools/background.py`. The same three files exist under
`light/backgrounds/`, graded to the light ground.

| File | Painting | Date | Status |
|------|----------|------|--------|
| `1-parliament.jpg` | Claude Monet, *The Houses of Parliament, Sunset* | 1900–1903 | public domain (Monet d. 1926) |
| `2-starry.jpg` | Vincent van Gogh, *The Starry Night* | 1889 | public domain (van Gogh d. 1890) |
| `3-composition.jpg` | Wassily Kandinsky, *Composition VII* | 1913 | public domain (Kandinsky d. 1944; published before 1930) |

The reproductions were taken from the style images vendored in
[Kautenja/a-neural-algorithm-of-artistic-style](https://github.com/Kautenja/a-neural-algorithm-of-artistic-style)
(`img/styles/`), which carries them at 2145 × 1830, 5000 × 3959 and
4032 × 3022. Faithful photographs of public-domain paintings carry no new
copyright, so the graded files here are under this repository's MIT licence.

Grading, per tone, at full 3840 × 2160: a Gaussian blur of 0.4 % of the
height (about 9 px; `--blur 0` for none), saturation × 1.3,
a 5–6 % mix toward the theme ground, luminance clamped into a band the bar
stays readable over (dark 0.02–0.34, light 0.30–0.90), then fine grain
against banding. Reproducible:

```
tools/background.py --source houses-of-parliament.jpg --name parliament --index 1
tools/background.py --source the-starry-night.jpg      --name starry      --index 2
tools/background.py --source composition-vii.jpg       --name composition --index 3
```
