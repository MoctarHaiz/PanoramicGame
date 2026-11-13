"""grass_ends.png from grass_cap.png: the rounded ends of a top cut from the turf itself.

The owner, 2026-11-13, on a floating ledge: "the floating grass that looks weird (we feel there are many
incoherent grass that are used)". The ends (terrain.py's painted lime curls) and the drapes hanging from them were
drawn in another language than the turf along the tops (grass_cap.png, kie.ai). Here each end is a piece of that
same turf, its columns bent down over the corner (a quarter circle), so the band and its dark fringe wrap the open
side as one picture with the strip; it melts into the strip drawn under it (TerrainView: the cap runs on under the
end, short of its corner).

Layout as before (TerrainView END_OUT, END_FADE, END_W, END_H; 2 px a unit): two pieces of 108 x 100 px, the left
end (12 units past the open side, the cell, 10 units over the next cell) then the right end (its mirror).

    python3 tools/art/grass_ends_cap.py
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD = os.path.join(HERE, "..", "..", "assets", "art", "world")
PX = 2
END_OUT, END_FADE, T, END_H = 12, 10, 32, 50
W = (END_OUT + T + END_FADE) * PX  # 108
H = END_H * PX  # 100
SURFACE = 24  # px: the walking line in the strip (TerrainView CAP_ABOVE)
RC = 16.0  # px: the radius the walking line turns round at the corner
CX = END_OUT * PX + 12.0  # px: the corner's centre, 6 units inside the open side
CY = SURFACE + RC
THETA_MAX = 1.95  # how far round it wraps (radians from straight up: a little past level)
SOLID_TO = 46  # px: the end's own turf, then it melts into the strip under it (drawn from 44 px)
MELT = 14  # px


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def turf(src: np.ndarray) -> np.ndarray:
    """ink.gdshader's `turf` light (round 23), baked before the bend: the strip gets it by its rows on screen, so a
    bent end drawn with it had its blades repainted as a smooth lime band; TerrainView draws the ends with plain ink."""
    out = src.copy()
    c = out[..., :3] / 255.0
    v = (np.arange(src.shape[0], dtype=np.float32) / src.shape[0])[:, None, None]
    lum = (c * np.array([0.3, 0.59, 0.11])).sum(-1, keepdims=True)
    out[..., 3] *= smooth(0.05, 0.13, v[..., 0])
    c = c + ((c * np.array([1.12, 1.1, 0.96]) + np.array([0.04, 0.035, 0.0])) - c) * (1.0 - smooth(0.2, 0.26, v))
    band = smooth(0.22, 0.3, v) * (1.0 - smooth(0.5, 0.62, v))
    sage = (lum + (c - lum) * 0.7) * np.array([1.16, 1.14, 0.98]) + np.array([0.06, 0.06, 0.02])
    c = c + (sage - c) * band
    top = smooth(0.22, 0.25, v) * (1.0 - smooth(0.31, 0.4, v))
    c = c + (np.array([0.9, 0.86, 0.56]) * (0.86 + 0.28 * lum) - c) * top * 0.5
    lip = smooth(0.235, 0.25, v) * (1.0 - smooth(0.265, 0.285, v))
    c = c + (np.array([0.98, 0.94, 0.7]) - c) * lip * 0.55
    under = smooth(0.48, 0.66, v)
    c = c + ((lum + (c - lum) * 0.3) * np.array([0.82, 0.8, 0.9]) * 0.72 - c) * under
    out[..., :3] = np.clip(c, 0, 1) * 255.0
    return out


def left_end(cap: np.ndarray, at: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    src = turf(cap[:, at:at + W].astype(np.float32))
    ys = np.arange(H, dtype=np.float32)[:, None] * np.ones((1, W), np.float32)
    xs = np.arange(W, dtype=np.float32)[None, :] * np.ones((H, 1), np.float32)
    # the turf wrapped round the corner: left of the corner's centre each pixel reads the strip by its angle (the
    # arc along the walking line) and its distance from the centre (height over the walking line)
    rho = np.hypot(xs - CX, ys - CY)
    theta = np.arctan2(CX - xs, CY - ys)  # 0 straight up, pi / 2 out over the open side, pi straight down
    wrap = (xs < CX) & (theta <= THETA_MAX)
    sx = np.where(wrap, CX - theta * RC, np.maximum(xs, CX))
    # (round the corner it reads the band's green under the straw lip: its outer face is turf, not the lit walking line)
    sy = np.where(wrap, CY - rho + 12.0 * smooth(0.3, 0.8, theta), ys)
    ix = np.clip(np.round(sx).astype(int), 0, W - 1)
    iy = np.round(sy).astype(int)
    out = src[np.clip(iy, 0, H - 1), ix]
    a = out[..., 3] * ((iy >= 0) & (iy < H))
    # the wrap ends a little past level, ragged (its own blades); under it the band and its fringe (the strip's at the
    # corner's centre) recede as they go down, a slope, not a cut
    jag = np.convolve(rng.uniform(-0.12, 0.12, W), np.ones(5) / 5, "same")[None, :]
    under = (xs < CX) & ~wrap
    recede = CX - RC * 0.9 + np.maximum(ys - CY, 0.0) * 0.8 + rng.uniform(-1.5, 1.5, H)[:, None]
    a *= np.where(under, smooth(recede - 2.0, recede + 2.0, xs) * (ys > CY), 1.0)
    a *= np.where(wrap, 1.0 - smooth(THETA_MAX - 0.3, THETA_MAX + 0.02 + jag, theta) * (ys < CY + 2), 1.0)
    # (2026-11-13, the director: "the ragged yellow bits at the two ends of the mat": round the corner the blades over the
    # walking line are left off, the band's clean rounded edge in the turf's own green; they stay where it joins the strip)
    a *= np.where(wrap, 1.0 - smooth(0.3, 0.75, theta) * smooth(RC + 1.0, RC + 3.5, rho), 1.0)
    # into the strip under it, and nothing reaching the piece's bottom
    a *= 1.0 - smooth(SOLID_TO, SOLID_TO + MELT, xs)
    a *= 1.0 - smooth(H - 14, H - 2, ys)
    out[..., 3] = a
    # the outer face turns from the light a little (the strip's own colours, darker as it turns down)
    shade = 1.0 - 0.16 * smooth(0.9, THETA_MAX, np.where(xs < CX, theta, 0.0))
    out[..., :3] *= shade[..., None]
    return np.clip(out, 0, 255).astype(np.uint8)


def main() -> None:
    cap = np.array(Image.open(os.path.join(WORLD, "grass_cap.png")).convert("RGBA"))
    left = left_end(cap, 610, 3)
    right = left_end(cap, 1330, 5)[:, ::-1]
    sheet = np.concatenate([left, right], axis=1)
    Image.fromarray(sheet, "RGBA").save(os.path.join(WORLD, "grass_ends.png"))
    print("grass_ends.png", sheet.shape)


if __name__ == "__main__":
    main()
