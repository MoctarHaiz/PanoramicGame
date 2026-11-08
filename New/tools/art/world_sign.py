#!/usr/bin/env python3
"""Round 21 (the judges, j17: "the HOME sign's letters look like a UI font, not carved"): the letters of the painted
signpost (tools/art/ref/home_sign_painted.png, the world redraw's picture) cut into the board and burned: each letter's
cream fill becomes a groove of charred wood with the board's grain running through it, the groove's upper-left walls
in shadow (the sun and the fire light it from the upper left) and its lower-right walls catching the light, a thin
lit lip where the cut meets the board below and to the right.
Round 22 (the judges, j18: "the beaded pole under the HOME sign reads as a corn cob"): the post's long wrap of beads in
rows is plain wood again (the post's grain below it, carried up), with two narrow bands of Zulu beadwork round it (a
row of small beads, red, white, blue and gold, darker toward the post's sides as it turns), so the beadwork stays.

    python3 tools/art/world_sign.py   -> assets/art/world/home_sign.png
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
SRC = Path(__file__).parent / "ref/home_sign_painted.png"
OUT = NEW / "assets/art/world/home_sign.png"
BOARD = (slice(28, 112), slice(4, 232))  # rows, columns of the board where the letters are (px)
WRAP = (112, 186)  # round 22: rows of the post wrapped in beads (px)
POST_COLS = slice(100, 150)  # columns round the post (px)
BANDS = (115, 177)  # round 22: top rows of the two narrow bead bands (px)
BEADS = [(196, 52, 38), (244, 236, 214), (52, 112, 176), (232, 176, 52)]  # red, white, blue, gold


def plain_post(res: np.ndarray) -> None:
    """Round 22: the beaded wrap replaced by the post's own wood, with two narrow bands of beads round it."""
    y0, y1 = WRAP
    wood = res[188:252, POST_COLS].copy()  # (the plain post under the wrap)
    for y in range(y0, y1):
        res[y, POST_COLS] = wood[(y - y0) % wood.shape[0]]
    cols = np.where(res[200, POST_COLS, 3] > 128)[0] + POST_COLS.start
    left, right = int(cols.min()), int(cols.max())
    mid = (left + right) / 2.0
    half = (right - left) / 2.0
    for k, top in enumerate(BANDS):
        # the band's shadow on the post under it, then two rows of beads, 3 px each, the second offset
        res[top + 6, left:right + 1, :3] = res[top + 6, left:right + 1, :3] * 0.5
        res[top + 7, left:right + 1, :3] = res[top + 7, left:right + 1, :3] * 0.75
        for row in range(2):
            for i, x in enumerate(range(left - row, right + 1, 3)):
                r, g, b = BEADS[(i + k * 2 + row * 2) % len(BEADS)]
                turn = 1.0 - 0.55 * ((x + 1 - mid) / half) ** 2  # (the post turning away at its sides)
                for dy in range(3):
                    for dx in range(3):
                        xx = x + dx
                        if xx < left or xx > right:
                            continue
                        corner = dy in (0, 2) and dx in (0, 2)  # (round beads: their corners in shade)
                        lit = 1.18 if (dy, dx) == (0, 1) else (0.72 if dy == 2 or corner else 1.0)  # (lit from above)
                        res[top + row * 3 + dy, xx, :3] = np.clip(np.array([r, g, b]) * max(turn, 0.3) * lit, 0, 255)
                        res[top + row * 3 + dy, xx, 3] = 255


def shift(m, dy, dx):
    return np.roll(np.roll(m, dy, axis=0), dx, axis=1)


def main() -> None:
    img = np.asarray(Image.open(SRC).convert("RGBA")).astype(float)
    rgb = img[..., :3]
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    region = np.zeros(lum.shape, bool)
    region[BOARD] = True
    # the letters' cream fill (light and pale), closed over its painted specks
    cream = region & (lum > 168) & (sat < 85) & (img[..., 3] > 200)
    cream = ndimage.binary_opening(cream, iterations=1)
    cream = ndimage.binary_closing(cream, iterations=2)
    labels, n = ndimage.label(cream)
    sizes = ndimage.sum(cream, labels, range(1, n + 1))
    keep = np.isin(labels, [i + 1 for i, s in enumerate(sizes) if s > 60])  # (the letters, not a highlight fleck)
    # (and the light specks and shading left round their edges)
    keep = keep | (ndimage.binary_dilation(keep, iterations=2) & (lum > 130) & (sat < 100))
    keep = ndimage.binary_closing(keep, iterations=1)
    mask = ndimage.gaussian_filter(keep.astype(float), 0.6)
    # (the dark outline painted round each letter: it becomes the groove's steep walls)
    walls = ndimage.binary_dilation(keep, iterations=2) & ~keep & (lum < 120)

    rng = np.random.default_rng(21)
    h, w = lum.shape
    y = np.arange(h, dtype=float)[:, None]
    x = np.arange(w, dtype=float)[None, :]
    # the board's grain, running along it: long dark streaks wavering a little
    grain = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)), (0.6, 14.0))
    grain = grain / (np.abs(grain).max() + 1e-6)
    rings = np.sin(y * 0.9 + np.sin(x * 0.03) * 3.0 + grain * 2.0)
    # the groove's floor: charred wood, warm in its grain
    floor = np.stack([74 + 14 * rings + 16 * grain, 42 + 8 * rings + 9 * grain, 25 + 4 * rings + 5 * grain], axis=-1)
    # depth: the walls on the upper left throw their shadow onto the floor; the lower-right walls catch the light
    soft = mask
    shadow = np.clip(soft - shift(soft, 3, 3), 0, 1)  # (near the groove's upper-left edges)
    lit_wall = np.clip(soft - shift(soft, -2, -2), 0, 1)  # (near its lower-right edges)
    c = floor * (1.0 - 0.55 * shadow[..., None])
    c = c * (1 - lit_wall[..., None] * 0.7) + np.array([182, 120, 70]) * lit_wall[..., None] * 0.7
    # the floor a little warmer down the middle of each stroke (the fire's glow in it), so the word reads at a glance
    core = ndimage.distance_transform_edt(keep)
    warm = np.clip((core - 1.5) / 3.0, 0, 1) * 0.22
    c = c * (1 - warm[..., None]) + np.array([150, 84, 40]) * warm[..., None]
    out = rgb.copy()
    out = out * (1 - mask[..., None]) + c * mask[..., None]
    # the cut's steep walls (the old outline): darker, the lower-right ones lit
    wall_lit = walls & (shift(keep, -2, -2) | shift(keep, -1, -2) | shift(keep, -2, -1)) & ~(shift(keep, 2, 2))
    out[walls] = out[walls] * 0.55
    out[wall_lit] = np.array([168, 112, 66])
    # the lip of the board round each letter: a thin light edge below and to the right of the cut
    ring = ndimage.binary_dilation(keep, iterations=3) & ~ndimage.binary_dilation(keep, iterations=2)
    lip = ring & ~shift(ndimage.binary_dilation(keep, iterations=3), 2, 2)
    out[lip] = np.minimum(out[lip] * 1.22 + 10, 255)
    res = img.copy()
    res[..., :3] = np.clip(out, 0, 255)
    plain_post(res)
    Image.fromarray(res.round().astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print("home_sign.png written:", int(keep.sum()), "px of letters carved")


if __name__ == "__main__":
    main()
