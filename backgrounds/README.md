# Backgrounds

A plain ground and six lit rooms per tone, drawn by `tools/background.py`
at 3840 × 2160. The light set is under `light/backgrounds/`, graded to the
light ground; the ungraded rooms are in `docs/images/art/` for imagery
inside the UI.

| File | Style | Palette | Seed |
|------|-------|---------|------|
| `1-plain.jpg` | plain | the tone's ground, raised at the top | 7 |
| `2-ember.jpg` | corridors | ember | 8 |
| `3-lilac.jpg` | corridors | lilac | 3 |
| `4-sky.jpg` | corridors | sky | 8 |
| `5-citrus.jpg` | corridors | citrus | 8 |
| `6-dusk.jpg` | corridors | dusk | 8 |
| `7-magenta.jpg` | corridors | magenta | 8 |

How a room is drawn: a vanishing point sits somewhere off centre with a
small opening around it; every pixel's ray from that point leaves the
opening on one of four planes (left, right, floor, ceiling) and reaches the
screen edge, which gives it a plane and a depth. Each plane runs from the
far light at the opening to its own colour at the viewer, a little darker
at the near edge; the creases between planes are softened; the opening has
its own gradient; light from it is bloomed outward and screened in; a
2.5-level grain keeps the gradients from banding. Everything is the
repository's own work, so it carries the MIT licence.

Grading, per tone: saturation × 1.0, no mix, luminance kept inside
0.02–0.90 (dark) or 0.20–0.92 (light), grain 1.6. No blur: the softness
is drawn in. Reproducible:

```
tools/background.py --style plain --index 1
tools/background.py --style corridors --palette ember   --name ember   --index 2 --seed 8 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
tools/background.py --style corridors --palette lilac   --name lilac   --index 3 --seed 3 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
tools/background.py --style corridors --palette sky     --name sky     --index 4 --seed 8 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
tools/background.py --style corridors --palette citrus  --name citrus  --index 5 --seed 8 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
tools/background.py --style corridors --palette dusk    --name dusk    --index 6 --seed 8 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
tools/background.py --style corridors --palette magenta --name magenta --index 7 --seed 8 --blur 0 --sat 1 --mix 0 --crop-out docs/images/art
```

`--source` still grades a painting or photograph (blurred at 4.5 % for the
desktop, `--allow-upscale` under a blur), and `--style orphic|planes`
draws the earlier flat compositions.
