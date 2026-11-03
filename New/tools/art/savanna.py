#!/usr/bin/env python3
"""The level's background at golden hour, painted in numpy (assets/art/world/sky_*.png, bg_*.png):

  sky.png         the sky, top to bottom: warm blue, lavender, peach, gold at the horizon, with
                  soft horizontal brush marks and thin lit cirrus (stretched to the screen width)
  sun.png         the sun's disc and glow (drawn additively)
  rays.png        soft god rays fanning from the sun to the lower right (additive, very faint)
  cloud_N.png     cumulus lit from the upper left: gold rims, lavender undersides
  far_mesas.png   escarpments on the horizon (mesas()): a far stepped plateau, nearer buttes,
                  chimneys and kopjes, sun-facing cliffs lit warm, the far sides violet (tiles in x)
  far_hills.png   rolling hills with tiny acacias, dusty rose (tiles in x)
  mid_hills.png   nearer olive-ochre hills with small trees and bushes (tiles in x)
  near_grass.png  a band of tall golden grass in front of the near trees (tiles in x)
  fg_grass.png    dark out-of-focus grass clumps passing in front of the play (tiles in x)
  haze.png        a soft band of warm air laid between layers
  mote.png        a soft speck of glowing dust (pollen in the light)
  bird.png        a bird far away, 4 wing frames in a row
  animals.png     (round 2) giraffes, an elephant, wildebeest: far away among the tree rows
  canopy.png      (round 3) acacia boughs hanging in along the top of the screen, near the camera

Every strip is 1 pixel per design unit for far layers and 2 for nearer ones; the game scrolls them
at different speeds (src/game/savanna_view.gd). The trees standing in the savanna are made by
tools/art/trees.py.

    python3 tools/art/savanna.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from paint import (blur, dither_rgba, fbm, hexc, mix, noise1, normals_light, poly_mask, ramp,  # noqa: E402
                   save, smooth, strokes)

# Horizon colours shared by every layer: far things melt into these.
HAZE = hexc("f6c27e")  # warm air near the horizon
HAZE_HIGH = hexc("b9c4d6")  # higher up, the cool blue of distance
SKY_STOPS = [(0.00, "143a86"), (0.24, "2659ad"), (0.42, "4b86cc"), (0.55, "86b3dc"),
             (0.65, "c9d3c6"), (0.75, "f3cd92"), (0.87, "fbb766"), (1.00, "fcae5c")]  # (round 2: a deeper zenith)


def sky() -> Image.Image:
    w, h = 1024, 640
    rng = np.random.default_rng(1)
    y = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    # the horizon line of the far layers is at 470 of 640: the gradient ends a little below
    t = np.clip(y * 640 / 520, 0, 1)
    col = ramp(t, SKY_STOPS)
    # broad painterly marks: long horizontal strokes, a few colour units, stronger low in the sky
    s1 = strokes(h, w, rng, length=180, width=4)
    s2 = strokes(h, w, rng, length=60, width=1.5)
    col += (s1 * 5.0 + s2 * 2.0)[..., None] * (0.5 + 0.5 * t)[..., None] * np.array([1.0, 0.9, 0.8])
    # thin cirrus: stretched noise, thresholded softly, lit gold from below
    n = fbm(h, w, 6, 3, 5, rng, wrap_x=True)
    n = blur(n, (1.0, 24.0), wrap_x=True)
    band = smooth(0.14, 0.32, y) * (1 - smooth(0.52, 0.66, y))
    cir = smooth(0.56, 0.74, n) * band
    cir_col = mix(hexc("fff0dc"), hexc("ffd6a6"), smooth(0.2, 0.6, y))
    col = mix(col, cir_col, cir * 0.45)
    # a lower bank of long warm stratus near the horizon
    n2 = blur(fbm(h, w, 10, 4, 4, rng, wrap_x=True), (0.6, 30.0), wrap_x=True)
    band2 = smooth(0.58, 0.66, y) * (1 - smooth(0.70, 0.78, y))
    strat = smooth(0.55, 0.72, n2) * band2
    col = mix(col, hexc("f6b98f"), strat * 0.35)
    col = mix(col, hexc("fbe2b8"), blur(strat, (1.5, 0), wrap_x=True) * 0.12)
    return dither_rgba(col, np.ones((h, w)), rng)


def sun() -> Image.Image:
    s = 512
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.hypot(xx - s / 2, yy - s / 2) / (s / 2)
    disc_r = 0.08
    disc = 1 - smooth(disc_r - 0.012, disc_r + 0.004, r)
    # round 2: the sun now sits low in the picture: a tighter, more golden glow (the wide pale one
    # washed out the left third of the screen)
    # round 4: a warm sun with a soft bloom (it read as a grey-white smudge): a smaller hot disc,
    # a golden bloom round it, a faint wide orange halo
    glow = np.exp(-(r / 0.1) ** 2) * 0.9 + np.exp(-(r / 0.26) ** 1.5) * 0.5 + np.exp(-(r / 0.7) ** 2) * 0.14
    glow *= 1 - smooth(0.85, 1.0, r)
    core = hexc("ffeab4")
    halo = hexc("ff8a28")
    # additive: the colour is the light added; alpha unused (1) but kept for premultiplication
    light = halo * glow[..., None] + (core - halo * glow[..., None]) * disc[..., None]
    a = np.clip(np.maximum(glow, disc), 0, 1)
    rgb = light / np.maximum(a, 1e-4)[..., None]
    return dither_rgba(np.clip(rgb, 0, 255), a)


RAYS_ORIGIN = (80, 80)  # px of rays.png where the sun is


def rays() -> Image.Image:
    """Soft shafts fanning from the sun (at RAYS_ORIGIN) down and to the right, fading at the
    sides of the fan, near the sun (lost in its glow) and far away."""
    w, h = 1280, 820
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    ox, oy = RAYS_ORIGIN
    ang = np.arctan2(yy - oy, xx - ox)  # 0 = right, pi/2 = down
    d = np.hypot(xx - ox, yy - oy)
    a = np.zeros((h, w))
    for _ in range(11):
        c = rng.uniform(0.2, 1.3)
        width = rng.uniform(0.018, 0.06)
        strength = rng.uniform(0.35, 1.0)
        a += np.exp(-((ang - c) / width) ** 2) * strength
    a = blur(a, 4)
    window = smooth(0.08, 0.3, ang) * (1 - smooth(1.15, 1.4, ang))
    fall = smooth(60, 260, d) * (1 - smooth(450, 1150, d))
    a = np.clip(a * window * fall * 0.45, 0, 1)
    rgb = np.ones((h, w, 3)) * hexc("ffe2a8")
    # stored at half size: soft light with no detail to lose (the views draw it at RAYS_SIZE units)
    return dither_rgba(rgb, a, rng).resize((w // 2, h // 2), Image.LANCZOS)


def cloud(seed: int, w: int = 1000, h: int = 440) -> Image.Image:
    """A soft cumulus, painted as volume rather than cut out: a density field of overlapping puffs
    (a broad flat base, rounded heads, small puffs on the heads), lit from the upper left through
    its own relief; warm white tops with a gold rim on the sun side, cool blue-grey undersides that
    melt into the sky, wispy edges eroded by noise. No outline. Painted at full size and stored at
    half (it has no hard detail to lose); the view draws it at twice its pixels."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    dens = np.zeros((h, w))
    base = h * 0.74

    def puff(cx, cy, rx, ry, k=1.0):
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        np.maximum(dens, k * np.clip(1 - d, 0, 1) ** 0.6, out=dens)

    n = int(r.integers(4, 7))
    for i in range(n):  # the heads, tallest a little left of the middle
        cx = w * (0.16 + 0.68 * i / (n - 1)) + r.uniform(-20, 20)
        mid = 1 - abs(i / (n - 1) - 0.4) * 1.6
        rad = r.uniform(70, 100) * (0.6 + 0.8 * max(mid, 0.15))
        cy = base - rad * r.uniform(0.45, 0.75)
        cy = base - rad * r.uniform(0.25, 0.4)  # round 4: low, long heads (painted like the mesas)
        puff(cx, cy, rad * 1.7, rad * 0.62)
        for _ in range(5):  # puffs crowning each head
            a = r.uniform(np.pi * 1.1, np.pi * 1.9)
            pr = rad * r.uniform(0.38, 0.62)
            puff(cx + np.cos(a) * rad * 0.9, cy + np.sin(a) * rad * 0.4, pr * 1.6, pr * 0.6)
    for x in np.linspace(w * 0.08, w * 0.92, 14):  # the long flat base
        puff(x + r.uniform(-12, 12), base - r.uniform(4, 20), r.uniform(60, 90), r.uniform(24, 34))
    dens *= 1 - smooth(base + 4, base + 34, yy)  # a flat bottom, softly
    noise = fbm(h, w, 6, 12, 5, r)
    soft = blur(dens, 2.0)
    cov = smooth(0.1, 0.32, soft - (noise - 0.5) * 0.22 * (1 - smooth(0.25, 0.7, soft)))
    height = blur(dens, 14.0) * 120.0
    lam = normals_light(height, 1.0)
    under = smooth(base - 110, base + 10, yy)  # the shaded belly
    t = np.clip(lam * 1.15 - under * 0.45 + 0.08, 0, 1)
    # round 4: the mesas' palette: lavender in the shade (not a heavy blue), peach and gold where lit
    col = ramp(t, [(0.0, "8f7f9f"), (0.32, "b49fb2"), (0.58, "e6c1ac"), (0.8, "ffdcb0"), (1.0, "fff0d2")])
    # the sun side: a warm gold rim where the cloud thins towards the upper left
    edge = np.clip(cov - np.roll(np.roll(cov, 9, axis=0), 9, axis=1), 0, 1)
    col = mix(col, hexc("ffd890"), blur(edge, 2.0) * 0.7)
    col += strokes(h, w, r, length=60, width=2.0, wrap_x=False)[..., None] * 7  # long painted marks
    a = np.clip(cov, 0, 1) * (0.94 - 0.25 * under)  # the belly lets a little sky through
    img = dither_rgba(np.clip(col, 0, 255), a, r)
    img = img.crop(img.getbbox())
    return img.resize((img.width // 2, img.height // 2), Image.LANCZOS)


def relief(cov: np.ndarray, sigma: float, wrap: bool = True, strength: float = 1.0) -> np.ndarray:
    """Lambert light (0..1) of a silhouette seen as a rounded relief: left and top edges lit."""
    height = blur(cov, sigma, wrap_x=wrap) * sigma * 2.0 * strength
    return normals_light(height, 1.0)


def plateau_profile(w: int, rng, count: int, hmin: float, hmax: float, wmin: float, wmax: float) -> np.ndarray:
    """Heights (up) of flat-topped plateaus with steep eroded cliffs and concave talus feet."""
    x = np.arange(w, dtype=float)
    out = np.zeros(w)
    for _ in range(count):
        c = rng.uniform(0, w)
        half = rng.uniform(wmin, wmax) / 2
        hh = rng.uniform(hmin, hmax)
        cliff = rng.uniform(6, 16)
        talus = rng.uniform(30, 90)
        d = np.abs(((x - c + w / 2) % w) - w / 2) - half
        f = np.where(d <= 0, 1.0, 0.0)
        f = np.where((d > 0) & (d <= cliff), 1 - 0.5 * (d / cliff) ** 1.3, f)
        f = np.where(d > cliff, 0.5 * np.clip(1 - (d - cliff) / talus, 0, 1) ** 2.2, f)
        if rng.random() < 0.5:  # a step on the top
            sx = c + rng.uniform(-half, half) * 0.6
            step = np.abs(((x - sx + w / 2) % w) - w / 2) < rng.uniform(10, max(12, half * 0.5))
            f = np.where(step & (d <= 0), 1.08, f)
        out = np.maximum(out, hh * f)
    return out


def far_mesas(stops=None, haze_high=None, haze=None, top_col="f4d2b6", seed: int = 21) -> Image.Image:
    """Escarpments and buttes in the far distance: 2048 x 240 at 1 px per unit; the base melts into
    the horizon haze. Rounded relief lit from the upper left, vertical gullies on the cliffs."""
    w, h = 2048, 300
    rng = np.random.default_rng(seed)
    stops = stops or [(0.0, "2c3672"), (0.4, "485492"), (0.7, "8a7fa6"), (0.88, "d2a48a"), (1.0, "f0c69a")]
    haze_high = HAZE_HIGH if haze_high is None else haze_high
    haze = HAZE if haze is None else haze
    base = h - 8 - noise1(w, 10, rng, 3) * 18
    heights = plateau_profile(w, rng, 7, 80, 150, 120, 420)
    heights = np.maximum(heights, plateau_profile(w, rng, 6, 45, 95, 40, 120))
    for _ in range(5):  # tall buttes and chimneys standing off the escarpments
        c = rng.uniform(0, w)
        half = rng.uniform(10, 34)
        d = np.abs(((np.arange(w) - c + w / 2) % w) - w / 2)
        heights = np.maximum(heights, np.where(d < half, rng.uniform(110, 175) * (1 - (d / half) ** 6), 0))
    for _ in range(16):  # kopjes: heaps of rounded boulders
        c = rng.uniform(0, w)
        rr = rng.uniform(10, 26)
        d = ((np.arange(w) - c + w / 2) % w) - w / 2
        bump = np.sqrt(np.clip(1 - (d / rr) ** 2, 0, 1)) * rr * rng.uniform(0.8, 1.2)
        heights = np.maximum(heights, bump)
    rough = noise1(w, 300, rng, 3) * 3.0 + noise1(w, 60, rng, 3) * 7.0  # eroded, uneven tops
    profile = np.clip(base - heights - rough * (heights > 6), 4, h)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    cov = np.clip(yy - profile[None, :] + 0.5, 0, 1)
    lam = relief(cov, 9.0)
    gully = blur(rng.standard_normal((h, w)), (6, 2.0), wrap_x=True)
    gully = gully / gully.std()
    below = yy - profile[None, :]
    cliff_band = smooth(0, 6, below) * (1 - smooth(25, 70, below))
    col = ramp(np.clip(lam * 1.1 - 0.05, 0, 1), stops)
    col *= (1 + gully[..., None] * 0.025 * cliff_band[..., None])
    # bands of rock along the cliffs: harder beds paler, softer ones in shade
    beds = np.sin((yy + blur(rng.standard_normal(w)[None, :], (0, 30), wrap_x=True)[0] * 40) * 0.16)
    col *= (1 + beds[..., None] * 0.06 * smooth(4, 20, below)[..., None])
    top_band = 1 - smooth(1, 5, below)  # flat tops catch the light
    col = mix(col, hexc(top_col), top_band * 0.3)
    # aerial perspective: the air thickens towards the ground
    col = mix(col, haze_high, 0.06 + 0.2 * smooth(0.3 * h, h, yy))
    col = mix(col, haze, smooth(0.6 * h, h, yy) * 0.5)
    return dither_rgba(col, cov, rng)


def _runs(cov: np.ndarray) -> tuple:
    """Per pixel of a mask that tiles in x: how far (px) to its left and right edge along the row."""
    inside = cov > 0.5
    h, w = inside.shape
    t = np.tile(inside, (1, 3))
    idx = np.arange(3 * w)[None, :] * np.ones((h, 1), int)
    last_out = np.maximum.accumulate(np.where(~t, idx, -1), axis=1)
    next_out = np.flip(np.minimum.accumulate(np.flip(np.where(~t, idx, 9 * w), axis=1), axis=1), axis=1)
    return (idx - last_out)[:, w:2 * w].astype(float), (next_out - idx)[:, w:2 * w].astype(float)


def _butte(x: np.ndarray, c: float, half: float, height: float, w: int, cliff: float, talus: float) -> np.ndarray:
    """Height (up) of a flat-topped butte centred at c: steep eroded cliffs over a concave talus."""
    d = np.abs(((x - c + w / 2) % w) - w / 2) - half
    f = np.where(d <= 0, 1.0, 0.0)
    f = np.where((d > 0) & (d <= cliff), 1 - 0.55 * (np.clip(d, 0, None) / cliff) ** 1.2, f)
    f = np.where(d > cliff, 0.45 * np.clip(1 - (d - cliff) / talus, 0, 1) ** 2.4, f)
    return height * f


def mesas() -> Image.Image:
    """New (env, round 2): the escarpments on the horizon, 2048 x 360 at 1 px per unit (tiles in x).
    Two planes: a long stepped escarpment far away (pale, deep in the haze) and, nearer, a few
    distinct landmarks: a tall flat butte, twin chimneys, a broad stepped mesa, a kopje of
    boulders. Lit by the low sun on the upper left: the cliffs facing it warm sandstone with a hot
    rim along their lit edges and tops, the faces turned away cool violet, gullies and beds of rock
    down the cliffs, the feet melting into the warm air of the horizon."""
    w, h = 2048, 360
    rng = np.random.default_rng(77)
    x = np.arange(w, dtype=float)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    base = h - 6 - noise1(w, 12, rng, 3) * 10

    def plane(heights: np.ndarray, rough_amp: float, stops: list, haze_k: float, rim_k: float, seed: int):
        r = np.random.default_rng(seed)
        rough = noise1(w, 260, r, 3) * rough_amp * 0.4 + noise1(w, 70, r, 3) * rough_amp
        profile = np.clip(base - heights - rough * (heights > 8), 2, h)
        cov = np.clip(yy - profile[None, :] + 0.5, 0, 1)
        below = yy - profile[None, :]
        # the face's turn: towards the sun at its left edges, away at its right (the slope of the
        # silhouette blurred mostly across), gullies ribbing the cliffs a little
        soft = blur(cov, (3.0, 14.0), wrap_x=True)
        gx = np.gradient(soft, axis=1)
        corner = np.clip(gx / (np.abs(gx).max() * 0.55), -1, 1)
        gul = blur(r.standard_normal((h, w)), (22.0, 5.0), wrap_x=True)
        gul /= gul.std()
        talus = smooth(0.0, 1.0, (below - (base[None, :] - profile[None, :]) * 0.62) / 40.0)
        nx = np.gradient(gul, axis=1) * 3.0 * smooth(4, 20, below) * (1 - talus)
        light = 0.46 + 0.62 * corner - 0.22 * nx + 0.12 * talus
        top = 1 - smooth(1, 6, below)  # the flat tops catch the sun
        light = np.clip(light + top * 0.4, 0, 1)
        col = ramp(light, stops)
        beds = np.sin((yy + blur(r.standard_normal(w)[None, :], (0, 40), wrap_x=True)[0] * 60) * 0.21)
        col *= (1 + beds[..., None] * 0.05 * smooth(6, 24, below)[..., None] * (1 - talus[..., None]))
        # the hot rim on the edges facing the sun (left sides and tops)
        rim = np.clip(cov - np.roll(cov, 3, axis=1), 0, 1) * 0.8 + np.clip(cov - np.roll(cov, 2, axis=0), 0, 1)
        col = mix(col, hexc("ffd9a0"), blur(np.clip(rim, 0, 1), 0.8, wrap_x=True) * rim_k)
        # aerial perspective: the plane's own haze, thicker towards its foot
        col = mix(col, HAZE_HIGH, haze_k)
        col = mix(col, HAZE, smooth(0.55 * h, h, yy) * 0.45)
        return col, cov

    far_h = np.zeros(w)
    for c, half, hh in [(140, 260, 112), (620, 150, 96), (900, 90, 128), (1240, 220, 104), (1720, 300, 120)]:
        far_h = np.maximum(far_h, _butte(x, c, half, hh, w, 10, 70))
        for _ in range(2):  # steps on the escarpment's top
            sx = c + rng.uniform(-half, half) * 0.7
            far_h = np.maximum(far_h, _butte(x, sx, rng.uniform(20, 60), hh + rng.uniform(10, 24), w, 6, 10))
    near_h = np.zeros(w)
    near_h = np.maximum(near_h, _butte(x, 420, 70, 210, w, 12, 90))  # the tall flat butte
    near_h = np.maximum(near_h, _butte(x, 372, 26, 236, w, 6, 30))  # its higher shoulder
    near_h = np.maximum(near_h, _butte(x, 1040, 16, 232, w, 8, 40))  # twin chimneys
    near_h = np.maximum(near_h, _butte(x, 1086, 12, 196, w, 7, 40))
    near_h = np.maximum(near_h, _butte(x, 1520, 170, 136, w, 14, 110))  # the broad stepped mesa
    near_h = np.maximum(near_h, _butte(x, 1455, 60, 168, w, 10, 30))
    near_h = np.maximum(near_h, _butte(x, 1960, 40, 182, w, 10, 60))  # a lone butte
    for _ in range(9):  # kopjes: heaps of rounded boulders
        c = rng.uniform(0, w)
        for k in range(int(rng.integers(3, 6))):
            rr = rng.uniform(9, 24)
            cc = c + k * rr * rng.uniform(0.9, 1.4)
            d = ((x - cc + w / 2) % w) - w / 2
            near_h = np.maximum(near_h, np.sqrt(np.clip(1 - (d / rr) ** 2, 0, 1)) * rr * rng.uniform(1.0, 1.8))
    far_col, far_cov = plane(far_h, 6.0, [(0.0, "566292"), (0.45, "8188ae"), (0.75, "c9a7a6"), (1.0, "f4cfa4")],
                             0.38, 0.35, 81)
    near_col, near_cov = plane(near_h, 5.0, [(0.0, "2e3066"), (0.38, "554f82"), (0.6, "a4697a"), (0.8, "e8925e"),
                                             (1.0, "ffc98e")], 0.1, 0.85, 83)
    col = mix(far_col, near_col, near_cov)
    cov = np.maximum(far_cov, near_cov)
    return dither_rgba(col, cov, rng)


def tiny_acacia(cx: float, base: float, s: float, rng) -> tuple:
    """Silhouette parts of a far acacia: a short forked trunk under a flat, wide, layered crown."""
    lean = rng.uniform(-2, 2) * s
    top = base - rng.uniform(9, 13) * s
    polys = [[(cx - 0.9 * s, base + 1), (cx + 0.9 * s, base + 1), (cx + lean + 0.5 * s, top), (cx + lean - 0.5 * s, top)]]
    for side in (-1, 1):
        fx = cx + lean * 0.6
        fy = base - (base - top) * 0.55
        polys.append([(fx - 0.4 * s, fy), (fx + 0.4 * s, fy), (fx + side * 5 * s + 0.3 * s, top + 1 * s),
                      (fx + side * 5 * s - 0.3 * s, top + 1 * s)])
    wcrown = rng.uniform(10, 15) * s
    ell = [(cx + lean, top - 0.5 * s, wcrown, 2.4 * s)]
    for _ in range(int(rng.integers(2, 4))):
        ell.append((cx + lean + rng.uniform(-0.6, 0.6) * wcrown, top - rng.uniform(1.0, 2.8) * s,
                    wcrown * rng.uniform(0.35, 0.6), rng.uniform(1.6, 2.4) * s))
    return polys, ell


def hills_strip(w: int, h: int, seed: int, top_y: float, amp: float, cells: int, stops: list, tree_col: str,
                trees: int, tree_scale: tuple, haze_k: float, bushes: int = 0, sigma: float = 14.0,
                haze=None, rim=None) -> Image.Image:
    """Rolling hills (tiles in x): rounded relief lit from the upper left, small acacias and bushes
    on the crests, the air thickening towards the bottom."""
    rng = np.random.default_rng(seed)
    profile = top_y + noise1(w, cells, rng, 4, 0.45) * amp * 2 - amp * 0.4
    profile = blur(profile[None, :], (0, 3), wrap_x=True)[0]
    yy = np.arange(h)[:, None] * np.ones((1, w))
    cov = np.clip(yy - profile[None, :] + 0.5, 0, 1)
    polys, ells = [], []
    for _ in range(trees):
        cx = rng.uniform(20, w - 20)
        p, e = tiny_acacia(cx, profile[int(cx)] + 2, rng.uniform(*tree_scale), rng)
        polys += p
        ells += e
    for _ in range(bushes):
        cx = rng.uniform(10, w - 10)
        rr = rng.uniform(3, 8)
        for k in range(int(rng.integers(1, 4))):
            ells.append((cx + k * rr * 0.9, profile[int(min(cx + k * rr, w - 1))] + rr * 0.2, rr * rng.uniform(1.0, 1.5), rr * 0.7))
    flora = poly_mask(w, h, polys, ellipses=ells)
    allcov = np.maximum(cov, flora)
    lam = relief(cov, sigma)
    tex = fbm(h, w, 8, 96, 4, rng, wrap_x=True)
    col = ramp(np.clip(lam * 0.9 + (tex - 0.5) * 0.18, 0, 1), stops)
    streak = blur(rng.standard_normal((h, w)), (2.0, 0.6), wrap_x=True)
    col += (streak / streak.std() * 3.0)[..., None]
    # the flora: darker, its top lit
    f_lam = relief(flora, 2.0)
    f_col = mix(hexc(tree_col) * 0.8, hexc(tree_col) * 1.35, smooth(0.4, 0.9, f_lam))
    col = mix(col, f_col, flora)
    rim_m = np.clip(allcov - np.roll(allcov, 2, axis=0), 0, 1)
    col = mix(col, hexc(rim) if rim else hexc(stops[-1][1]), rim_m * (0.8 if rim else 0.5))
    below = np.clip((yy - profile[None, :]) / (h - top_y + amp), 0, 1)
    col = mix(col, HAZE if haze is None else haze, haze_k + (1 - haze_k) * 0.55 * smooth(0.15, 1.0, below))
    return dither_rgba(col, allcov, rng)


def near_grass() -> Image.Image:
    """Tall golden grass in clumps, 2 px per unit: 2048 x 200 (1024 x 100 units), tiles in x. Blades
    lit on their left, seed stalks above, darker gaps between clumps, a few green shrubs."""
    w, h = 2048, 200
    ss = 2
    rng = np.random.default_rng(41)
    W, H = w * ss, h * ss
    from PIL import ImageDraw
    img = Image.new("RGB", (W, H), (0, 0, 0))
    alpha = Image.new("L", (W, H), 0)
    d, da = ImageDraw.Draw(img), ImageDraw.Draw(alpha)
    ground = H * 0.62
    clump = noise1(w, 40, rng, 3)  # where the grass is tall and dense
    d.rectangle([0, ground + H * 0.05, W, H], fill=(128, 96, 52))  # the grass mass under the blades
    da.rectangle([0, ground + H * 0.05, W, H], fill=255)
    for row in range(3):
        k = row / 2
        for _ in range(int(w * (1.1 + 0.9 * k))):
            x = rng.uniform(0, w)
            c = clump[int(x) % w]
            if rng.random() > 0.35 + c:
                continue
            bx = x * ss
            hgt = rng.uniform(0.2, 0.55) * H * (0.6 + 0.9 * c) * (0.8 + 0.3 * (1 - k))
            lean = rng.normal(0.18, 0.14) * hgt
            bw = rng.uniform(2.0, 4.2) * ss
            by = ground + k * H * 0.22 + rng.uniform(0, 8)
            tone = rng.random()
            lit = np.array([228, 182, 96]) * (1 - tone) + np.array([248, 218, 146]) * tone
            dark = np.array([150, 102, 52]) * (1 - tone) + np.array([186, 132, 64]) * tone
            colr = mix(dark, lit, (0.3 + 0.45 * (1 - k)) * (1.0 if lean > 0 else 0.4))
            colr = colr * (0.8 + 0.2 * (1 - k)) * (0.85 + 0.2 * c)
            for ox in (-W, 0, W):
                pts = [(bx + ox - bw, by), (bx + ox + bw, by), (bx + ox + lean * 0.55 + bw * 0.3, by - hgt * 0.55),
                       (bx + ox + lean, by - hgt)]
                d.polygon(pts, fill=tuple(int(v) for v in colr))
                da.polygon(pts, fill=255)
    for _ in range(int(w * 0.06)):  # seed stalks over the grass
        x = rng.uniform(0, w) * ss
        hgt = rng.uniform(0.45, 0.75) * H
        lean = rng.normal(0.1, 0.1) * hgt
        by = ground + rng.uniform(0, H * 0.15)
        tip = (x + lean, by - hgt)
        for ox in (-W, 0, W):
            d.line([(x + ox, by), (tip[0] + ox, tip[1])], fill=(196, 150, 84), width=2 * ss)
            da.line([(x + ox, by), (tip[0] + ox, tip[1])], fill=255, width=2 * ss)
            d.ellipse([tip[0] + ox - 3 * ss, tip[1] - 9 * ss, tip[0] + ox + 3 * ss, tip[1] + 2 * ss], fill=(232, 196, 122))
            da.ellipse([tip[0] + ox - 3 * ss, tip[1] - 9 * ss, tip[0] + ox + 3 * ss, tip[1] + 2 * ss], fill=255)
    # under the blades the grass goes on, denser and in shade: no floor shows in the holes
    for _ in range(int(w * 1.2)):
        bx = rng.uniform(0, W)
        by = H + rng.uniform(0, 10)
        hgt = rng.uniform(0.15, 0.32) * H
        lean = rng.normal(0.18, 0.14) * hgt
        bw = rng.uniform(2.0, 4.0) * ss
        tone = rng.random()
        c = np.array([150, 112, 60]) * (1 - tone) + np.array([186, 140, 74]) * tone
        for ox in (-W, 0, W):
            d.polygon([(bx + ox - bw, by), (bx + ox + bw, by), (bx + ox + lean, by - hgt)], fill=tuple(int(v) for v in c))
    rgb = np.asarray(img.resize((w, h), Image.LANCZOS), float)
    a = np.asarray(alpha.resize((w, h), Image.LANCZOS), float) / 255
    rgb = rgb / np.maximum(a, 1e-3)[..., None]
    yy = np.linspace(0, 1, h)[:, None]
    rgb = mix(rgb, hexc("4a3418"), (smooth(0.5, 1.0, yy) * 0.7)[..., None])
    rgb = mix(rgb, HAZE, 0.04)
    return dither_rgba(np.clip(rgb, 0, 255), a, rng)


def fg_grass() -> Image.Image:
    """The foreground: dark, out-of-focus clumps of savanna grass, a few rocks and seed stalks
    passing in front of the play along the bottom edge (they frame the shot and give it depth).
    2048 x 150 units at 1 px per unit, tiles in x; mostly low (the ground and its gaps stay
    readable), clumps with gaps between them, a thin warm rim where the low sun catches the tops."""
    w, h = 2048, 150
    ss = 3
    rng = np.random.default_rng(57)
    from PIL import ImageDraw
    m = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(m)
    # clumps: centre, half width, height (units above the bottom edge)
    clumps = []
    x = rng.uniform(0, 120)
    while x < w - 60:
        half = rng.uniform(50, 140)
        tall = rng.uniform(24, 40) if rng.random() < 0.85 else rng.uniform(44, 62)  # (round 4: lower: nothing hidden)
        clumps.append((x + half, half, tall))
        x += half * 2 + rng.uniform(10, 150)  # (round 2: denser, a frame along the whole edge)
    for cx, half, tall in clumps:
        blades = []
        for _ in range(int(half * 2.2)):
            u = rng.normal(0, 0.45)
            hgt = tall * rng.uniform(0.55, 1.2) * max(0.25, 1 - abs(u) * 0.8)
            lean = (u * 0.9 + rng.normal(0.12, 0.25)) * hgt  # blades fan out from the middle
            bw = rng.uniform(2.2, 5.0)
            blades.append((cx + u * half, hgt, lean, bw))
        rock = None
        if rng.random() < 0.45:  # a rock half hidden in the clump
            rock = (cx + rng.uniform(-half, half) * 0.5, rng.uniform(18, 34), rng.uniform(12, 20))
        for ox in (-w, 0, w):
            base = h + 4
            d.ellipse([(cx + ox - half * 1.05) * ss, (base - tall * 0.22) * ss, (cx + ox + half * 1.05) * ss, (base + tall * 0.3) * ss], fill=255)
            if rock:
                rcx, rx, ry = rock
                d.ellipse([(rcx + ox - rx) * ss, (base - ry * 1.7) * ss, (rcx + ox + rx) * ss, (base + ry) * ss], fill=255)
            for bx, hgt, lean, bw in blades:
                # a curved blade: wide at the foot, bending over towards its tip
                pts = [(bx + ox - bw, base), (bx + ox + bw, base),
                       (bx + ox + lean * 0.35 + bw * 0.6, base - hgt * 0.55),
                       (bx + ox + lean, base - hgt),
                       (bx + ox + lean * 0.3 - bw * 0.2, base - hgt * 0.6)]
                d.polygon([(px * ss, py * ss) for px, py in pts], fill=255)
    for _ in range(12):  # a few grass panicles above the clumps
        cx, half, tall = clumps[int(rng.integers(len(clumps)))]
        bx = cx + rng.uniform(-half, half) * 0.6
        hgt = tall + rng.uniform(16, 40)
        lean = rng.normal(0.18, 0.1) * hgt
        for ox in (-w, 0, w):
            tip = (bx + ox + lean, h - hgt)
            d.line([((bx + ox) * ss, (h + 4) * ss), (tip[0] * ss, tip[1] * ss)], fill=255, width=int(1.8 * ss))
            for k in range(5):  # the seed head: little spikelets along the last part
                t = 0.72 + k * 0.06
                px, py = bx + ox + lean * t, h + 4 - (hgt + 4) * t
                d.ellipse([(px - 2.2 + lean * 0.02) * ss, (py - 5) * ss, (px + 2.2 + 3) * ss, (py + 1) * ss], fill=255)
    a = np.asarray(m.resize((w, h), Image.LANCZOS), float) / 255
    edge = h - 12 - noise1(w, 40, rng, 3) * 10  # a low dark band of grass along the whole edge
    a = np.maximum(a, np.clip(np.arange(h)[:, None] - edge[None, :], 0, 1))
    a = blur(a, 1.4, wrap_x=True)  # out of focus
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    col = mix(hexc("3a3214"), hexc("140c06"), smooth(0.35, 1.0, yy))
    rim = np.clip(a - np.roll(np.roll(a, 3, axis=0), 3, axis=1), 0, 1)
    col = mix(col, hexc("c88a3a"), blur(rim, 1.0, wrap_x=True) * 0.55)
    return dither_rgba(np.clip(col, 0, 255), np.clip(a * 1.15, 0, 1), rng)


def _animal_parts(kind: str, w: float, h: float, rng) -> tuple:
    """Polygons and ellipses (px) of a savanna animal standing on y = h, facing left."""
    polys, ells = [], []

    def leg(x, top, bottom, wt, wb, lean=0.0):
        polys.append([(x - wt, top), (x + wt, top), (x + wb + lean, bottom), (x - wb + lean, bottom)])

    if kind == "giraffe":
        by, bx = h * 0.5, w * 0.58
        ells.append((bx, by, w * 0.2, h * 0.085))
        ells.append((bx - w * 0.14, by - h * 0.02, w * 0.1, h * 0.09))  # the shoulder, higher
        for x, lean in ((bx - w * 0.17, -2), (bx - w * 0.08, 3), (bx + w * 0.1, -1), (bx + w * 0.18, 4)):
            leg(x, by, h, w * 0.038, w * 0.017, lean)
        nx, ny = bx - w * 0.36, h * 0.07  # the neck up to the head, thick at its root
        polys.append([(bx - w * 0.26, by - h * 0.02), (bx - w * 0.05, by - h * 0.06), (nx + w * 0.08, ny + h * 0.05), (nx, ny + h * 0.03)])
        ells.append((nx - w * 0.04, ny + h * 0.02, w * 0.08, h * 0.028))
        polys.append([(nx + w * 0.01, ny), (nx + w * 0.02, ny - h * 0.04), (nx + w * 0.03, ny)])
        polys.append([(bx + w * 0.19, by), (bx + w * 0.22, by + h * 0.2), (bx + w * 0.2, by)])
    elif kind == "elephant":
        by, bx = h * 0.5, w * 0.56
        ells.append((bx, by, w * 0.3, h * 0.27))
        ells.append((bx - w * 0.3, by - h * 0.08, w * 0.13, h * 0.2))  # the head
        ells.append((bx - w * 0.2, by - h * 0.06, w * 0.1, h * 0.19))  # the ear
        polys.append([(bx - w * 0.4, by - h * 0.02), (bx - w * 0.33, by), (bx - w * 0.4, h * 0.92), (bx - w * 0.45, h * 0.9)])
        polys.append([(bx - w * 0.36, by + h * 0.04), (bx - w * 0.48, by + h * 0.1), (bx - w * 0.47, by + h * 0.13), (bx - w * 0.35, by + h * 0.09)])  # a tusk
        for x in (bx - w * 0.17, bx - w * 0.05, bx + w * 0.11, bx + w * 0.22):
            leg(x, by + h * 0.05, h, w * 0.055, w * 0.045)
        polys.append([(bx + w * 0.29, by - h * 0.05), (bx + w * 0.33, by + h * 0.25), (bx + w * 0.31, by - h * 0.05)])
    else:  # a few wildebeest grazing, heads down
        for k in range(5):
            cx = w * (0.12 + 0.19 * k) + rng.uniform(-6, 6)
            s = rng.uniform(0.85, 1.1)
            top = h * (0.38 + rng.uniform(-0.05, 0.05))
            ells.append((cx, top + h * 0.15 * s, w * 0.07 * s, h * 0.16 * s))
            ells.append((cx - w * 0.04 * s, top + h * 0.08 * s, w * 0.04 * s, h * 0.12 * s))  # the hump
            down = rng.random() < 0.6
            hx, hy = cx - w * 0.09 * s, top + (h * 0.42 if down else h * 0.1) * s
            polys.append([(cx - w * 0.05 * s, top + h * 0.05 * s), (cx - w * 0.03 * s, top + h * 0.2 * s), (hx + 4, hy + 4), (hx - 2, hy)])
            ells.append((hx, hy + 2, w * 0.02 * s, h * 0.07 * s))
            for x in (cx - w * 0.05 * s, cx - w * 0.02 * s, cx + w * 0.03 * s, cx + w * 0.06 * s):
                leg(x, top + h * 0.22 * s, h, w * 0.008, w * 0.005)
    return polys, ells


def animals() -> Image.Image:
    """New (env, round 2): life on the plain, far away: two giraffes, an elephant and a few
    wildebeest grazing, side by side in one strip (ANIMALS units each, 2 px a unit), dark against
    the grass with a warm rim where the low sun catches their backs. Drawn among the tree rows by
    src/game/savanna_view.gd, hazed like the trees at their depth."""
    rng = np.random.default_rng(63)
    out_c, out_a = [], []
    for kind, (wu, hu) in zip(["giraffe", "giraffe", "elephant", "herd"], ANIMALS):
        w, h = wu * 2, hu * 2
        polys, ells = _animal_parts(kind, w, h - 2, rng)
        cov = poly_mask(w, h, polys, ellipses=ells)
        lam = relief(cov, 3.0, wrap=False)
        col = mix(hexc("3a2418"), hexc("8a5a36"), smooth(0.35, 0.9, lam))
        if kind == "giraffe":  # a hint of the patches
            patches = smooth(0.55, 0.62, fbm(h, w, 14, 9, 2, rng, wrap_x=False))
            col = mix(col, hexc("2a160e"), patches * 0.5)
        rim = np.clip(cov - np.roll(np.roll(cov, 2, axis=0), 2, axis=1), 0, 1)
        col = mix(col, hexc("f0b878"), rim * 0.75)
        out_c.append(col)
        out_a.append(cov)
    hmax = max(c.shape[0] for c in out_c)
    pad = lambda a, ch: np.concatenate([np.zeros((hmax - a.shape[0],) + a.shape[1:]), a], axis=0)  # noqa: E731
    col = np.concatenate([pad(c, 3) for c in out_c], axis=1)
    alpha = np.concatenate([pad(a, 1) for a in out_a], axis=1)
    return dither_rgba(col, alpha, rng)


ANIMALS = [(70, 110), (64, 104), (110, 76), (150, 44)]  # units of each animal in animals.png


def canopy() -> Image.Image:
    """New (env, round 3): the frame along the top of the screen: acacia boughs hanging in from
    just in front of the camera, dark against the sky (out of focus), a warm rim where the low sun
    catches their lower edges, gaps of sky between the clumps. 2048 x 160 px at 2 px a screen unit
    (1024 x 80), tiles in x; clumps reach 22-66 units down (never to the vine, under the HUD)."""
    w, h = 2048, 160
    rng = np.random.default_rng(97)
    polys, ells, lines = [], [], []
    x = rng.uniform(0, 80)
    while x < w:
        span = rng.uniform(150, 420)
        if rng.random() < 0.3:  # a gap of open sky
            x += span * 0.6
            continue
        depth = rng.uniform(44, 132)  # px: how far this bough hangs down
        cx = x + span / 2
        # the bough: a branch from the top edge, forking, pads of leaves on its twigs
        bx, by = cx + rng.uniform(-span * 0.3, span * 0.3), depth * 0.55
        lines.append(((cx - span * 0.45, -4, bx, by), rng.uniform(5, 9)))
        lines.append(((bx, by, cx + span * 0.45, rng.uniform(-4, 20)), rng.uniform(3, 6)))
        for _ in range(int(span / 20)):  # flat acacia pads, each a cloud of small leaflets
            px = cx + rng.uniform(-0.5, 0.5) * span
            py = rng.uniform(0.0, 1.0) ** 1.6 * depth * (1.0 - abs(px - cx) / span * 0.8)
            rx = rng.uniform(16, 38)
            ry = rx * rng.uniform(0.28, 0.4)
            ells.append((px, py, rx * 0.6, ry * 0.6))
            for _ in range(int(rx * 1.2)):
                a = rng.uniform(0, 2 * np.pi)
                rr = np.sqrt(rng.uniform(0, 1))
                ells.append((px + np.cos(a) * rx * rr, py + np.sin(a) * ry * rr, rng.uniform(2.0, 5.0), rng.uniform(1.4, 3.0)))
            if rng.random() < 0.6:
                lines.append(((bx, by, px, py), rng.uniform(1.2, 2.4)))
        x += span * rng.uniform(0.75, 1.1)
    cov = poly_mask(w, h, polys, ellipses=ells, lines=lines)
    cov = np.maximum(cov, np.roll(poly_mask(w, h, polys, ellipses=[(e[0] - w, *e[1:]) for e in ells] + [(e[0] + w, *e[1:]) for e in ells],
                                            lines=[((a - w, b, c - w, d), lw) for (a, b, c, d), lw in lines] + [((a + w, b, c + w, d), lw) for (a, b, c, d), lw in lines]), 0, axis=1))
    leaf = blur(rng.standard_normal((h, w)), 1.2, wrap_x=True)  # ragged leafy edges
    cov = np.clip(cov * (1.0 + 0.35 * leaf) - 0.1 * (leaf < -0.8), 0, 1)
    cov = np.clip(blur(cov, 1.6, wrap_x=True) * 1.25, 0, 1)  # near the camera: soft
    yy = np.arange(h)[:, None] * np.ones((1, w))
    col = mix(hexc("20190f"), hexc("2f2a17"), smooth(0, h, yy))
    rim = np.clip(cov - np.roll(np.roll(cov, -4, axis=0), 3, axis=1), 0, 1)  # lower left edges, to the sun
    col = mix(col, hexc("d89448"), blur(rim, 1.2, wrap_x=True) * 0.75)
    return dither_rgba(col, cov, rng)


def haze() -> Image.Image:
    w, h = 16, 256
    y = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    a = np.exp(-((y - 0.5) / 0.22) ** 2)
    return dither_rgba(np.ones((h, w, 3)) * HAZE, a * 0.9)


def mote() -> Image.Image:
    s = 32
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.hypot(xx - s / 2 + 0.5, yy - s / 2 + 0.5) / (s / 2)
    a = np.exp(-(r / 0.35) ** 2) * (1 - smooth(0.8, 1.0, r))
    return dither_rgba(np.ones((s, s, 3)) * hexc("fff1c8"), a)


def bird() -> Image.Image:
    """4 frames (64 x 32 each) of a far bird gliding and flapping: a soft dark-violet chevron."""
    fw, fh, ss = 64, 32, 4
    frames = []
    for k, lift in enumerate((-9, -3, 4, -3)):
        cx, cy = fw / 2, fh / 2 + 2
        wing = 22
        pts_l = [(cx, cy), (cx - wing * 0.5, cy + lift * 0.6 - 2), (cx - wing, cy + lift), (cx - wing * 0.45, cy + lift * 0.4 + 1.5), (cx, cy + 3)]
        pts_r = [(cx, cy), (cx + wing * 0.5, cy + lift * 0.6 - 2), (cx + wing, cy + lift), (cx + wing * 0.45, cy + lift * 0.4 + 1.5), (cx, cy + 3)]
        body = (cx + 1, cy + 1.5, 5, 2.2)
        m = poly_mask(fw, fh, [pts_l, pts_r], ss=ss, ellipses=[body])
        frames.append(m)
    a = np.hstack(frames)
    return dither_rgba(np.ones(a.shape + (3,)) * hexc("4a3550"), a)


# ------------------------------------------------------------------ the menu's sunset

SUNSET_STOPS = [(0.0, "2e2152"), (0.25, "5a2c62"), (0.45, "9a3a64"), (0.62, "d8542e"), (0.78, "f2903a"),
                (0.9, "ffc260"), (1.0, "ffe0a0")]


def sunset_sky() -> Image.Image:
    """Dusk: indigo high, magenta, orange, gold at the horizon (at the bottom of the picture), long
    stratus lit from below, painterly marks."""
    w, h = 1024, 720
    rng = np.random.default_rng(91)
    y = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    col = ramp(y, SUNSET_STOPS)
    s1 = strokes(h, w, rng, length=200, width=4)
    col += (s1 * 5.0)[..., None]
    n = blur(fbm(h, w, 14, 3, 5, rng, wrap_x=True), (0.8, 40.0), wrap_x=True)
    band = smooth(0.18, 0.32, y) * (1 - smooth(0.78, 0.9, y))
    cl = smooth(0.55, 0.7, n) * band
    lit = np.clip(cl - np.roll(cl, -4, axis=0), 0, 1)  # undersides catch the sun
    cloud_col = mix(hexc("6a3060"), hexc("c0486a"), smooth(0.2, 0.75, y))
    col = mix(col, cloud_col, cl * 0.75)
    col = mix(col, hexc("ffb070"), np.clip(lit * 3, 0, 1) * 0.7 * smooth(0.3, 0.7, y))
    return dither_rgba(col, np.ones((h, w)), rng)


def sunset_grass() -> Image.Image:
    """Foreground grass against the low sun: dark plum blades with gold-lit edges, 2048 x 220."""
    w, h = 2048, 220
    rng = np.random.default_rng(97)
    ss = 2
    from PIL import ImageDraw
    m = Image.new("L", (w * ss, h * ss), 0)
    rim = Image.new("L", (w * ss, h * ss), 0)
    d, dr = ImageDraw.Draw(m), ImageDraw.Draw(rim)
    ground = h * 0.7
    for _ in range(int(w * 3.2)):
        bx = rng.uniform(0, w)
        hgt = rng.uniform(0.15, 0.62) * h * (1.4 if rng.random() < 0.05 else 1.0)
        lean = rng.normal(0.15, 0.25) * hgt
        bw = rng.uniform(1.6, 3.6)
        by = ground + rng.uniform(0, h * 0.25)
        for ox in (-w, 0, w):
            pts = [((bx + ox - bw) * ss, by * ss), ((bx + ox + bw) * ss, by * ss), ((bx + ox + lean * 0.6) * ss, (by - hgt * 0.6) * ss),
                   ((bx + ox + lean) * ss, (by - hgt) * ss)]
            d.polygon(pts, fill=255)
            dr.line([pts[0], pts[2], pts[3]], fill=255, width=max(1, int(0.7 * ss)))
        if rng.random() < 0.08:  # seed heads
            for ox in (-w, 0, w):
                d.ellipse([(bx + ox + lean - 2) * ss, (by - hgt - 6) * ss, (bx + ox + lean + 2) * ss, (by - hgt + 2) * ss], fill=255)
    d.rectangle([0, (ground + h * 0.02) * ss, w * ss, h * ss], fill=255)
    a = np.asarray(m.resize((w, h), Image.LANCZOS), float) / 255
    r = np.asarray(rim.resize((w, h), Image.LANCZOS), float) / 255
    yy = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    col = mix(hexc("4a2034"), hexc("1c0c16"), smooth(0.3, 0.9, yy))
    col = mix(col, hexc("ffae5a"), r * (1 - smooth(0.35, 0.7, yy)) * 0.75)
    return dither_rgba(np.clip(col, 0, 255), a, rng)


def sunset_set() -> None:
    save(sunset_sky(), "sunset_sky.png")
    save(far_mesas([(0.0, "3e2452"), (0.45, "52295c"), (0.75, "6c3262"), (1.0, "94486a")],
                   hexc("7a3462"), hexc("c8563e"), "ff9a5a", seed=23), "sunset_far.png")
    save(hills_strip(2048, 200, 35, 60, 22, 8, [(0.0, "3a1c38"), (0.45, "5a2846"), (0.8, "7e3a50"), (1.0, "b4566a")],
                     "2a1428", 34, (0.7, 1.2), 0.08, bushes=40, haze=hexc("d8643c"), rim="ffb070"), "sunset_hills.png")
    save(sunset_grass(), "sunset_grass.png")


FAR_HILLS = [(0.0, "5d6c86"), (0.45, "7d8792"), (0.75, "aea58e"), (1.0, "e6c88e")]
MID_HILLS = [(0.0, "4f5a26"), (0.4, "7a7c30"), (0.72, "b39a40"), (1.0, "eac66a")]


def main() -> None:
    which = set(sys.argv[1:])

    def want(name: str) -> bool:
        return not which or name in which

    if want("sky"):
        # a soft gradient: stored at half size (it is stretched over the screen anyway; 0.8 MB of
        # video memory instead of 3.3)
        save(sky().resize((512, 320), Image.LANCZOS), "sky.png")
    if want("sun"):
        save(sun(), "sun.png")
        save(rays(), "rays.png")
    if want("clouds"):
        for i in range(4):
            save(cloud(60 + i), f"cloud_{i + 1}.png")
    if want("far"):
        save(mesas(), "far_mesas.png")
        save(hills_strip(2048, 170, 31, 60, 24, 9, FAR_HILLS, "4f5a6e", 46, (0.55, 0.9), 0.18, bushes=30), "far_hills.png")
    if want("mid"):
        save(hills_strip(2048, 240, 33, 70, 30, 7, MID_HILLS, "34481c", 22, (1.1, 1.8), 0.04, bushes=70, sigma=18), "mid_hills.png")
    if want("grass"):
        save(near_grass(), "near_grass.png")
    if want("fg"):
        save(fg_grass(), "fg_grass.png")
    if want("animals"):
        save(animals(), "animals.png")
    if want("canopy"):
        save(canopy().resize((1024, 80), Image.LANCZOS), "canopy.png")  # (out of focus: half size is enough)
    if want("sunset"):
        sunset_set()
    if want("small"):
        save(haze(), "haze.png")
        save(mote(), "mote.png")
        save(bird(), "bird.png")
    print("savanna written")


if __name__ == "__main__":
    main()
