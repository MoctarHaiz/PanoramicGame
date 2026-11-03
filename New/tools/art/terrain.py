#!/usr/bin/env python3
"""The level's ground, painted in numpy to sit with the hero sheet: warm savanna soil with strata
and stones, sandstone deeper in the walls, a lush grass cap with blades over the edge, roots and
shadow under floating ledges, all lit from the upper left. 2 pixels per design unit.

The ground is drawn by src/game/terrain_view.gd in layers:
  soil.png        laterite soil, 512 px square, tiles both ways; sampled in level space by
                  terrain.gdshader, so it runs on across cells without seams
  rock.png        sandstone ledges for deep wall faces (same size, same use)
  terrain_shape.png  per cell: coverage (A), edge light (R, 0.5 = none), outline (G), rim (B);
                  16 masks of open sides (N=1, E=2, S=4, W=8) x 4 variants, 64 px each with
                  a 4 px extruded border (72 px apart)
  grass_cap.png   the grass along the top of a run of cells, tiles in x: blades rise 18 units above
                  the surface, the lush band hangs over the soil, roots and shadow fade below it
  grass_ends.png  the rounded left and right ends of a cap (where a top meets an open side)
  underside.png   hanging roots and shadow under a cell open below, tiles in x
  hanging.png     (round 2) masses of earth and rock hanging under floating ledges, 4 variants
  tufts.png       one row of grass clumps and wild flowers that stand on tops (they sway)
  front_grass.png short blades drawn in front of the runners' feet, tiles in x
  spires.png      three sandstone spires (96 x 560 units each) drawn for one-cell-wide walls
                  (the poles in the river) instead of their soil (tools/art/material.py)

    python3 tools/art/terrain.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
import material  # noqa: E402
from paint import (blur, dither_rgba, fbm, hexc, mix, noise1, normals_light, poly_mask, ramp, save,  # noqa: E402
                   smooth, strokes)

PX = 2  # pixels per design unit
STRIP = 2048  # px width of the strips along the tops (1024 units: no repeat visible on a screen)
CELL = 32 * PX  # 64 px
N, E, S, W = 1, 2, 4, 8

SOIL_STRATA = ["9c5a36", "8a4c30", "a8683f", "7a3e28", "945434", "84482c", "aa7048", "723a24"]
GRASS_TIP = hexc("f2ec92")
GRASS_HI = hexc("cdd65a")
GRASS = hexc("95b53a")
GRASS_MID = hexc("66952e")
GRASS_DEEP = hexc("3b6a2a")
GRASS_SHADOW = hexc("2c4c38")  # cool blue-green in the deepest shade
OUTLINE = hexc("3b1a12")
ROOT = hexc("4a2616")
ROOT_HI = hexc("8a5636")


def wrap_offsets(size: int):
    return [(ox, oy) for ox in (-size, 0, size) for oy in (-size, 0, size)]


def stones_layer(size: int, rng, count: int, rmin: float, rmax: float, ss: int = 4):
    """Embedded stones (wrapping): coverage and a height field for lighting."""
    m = Image.new("L", (size * ss, size * ss), 0)
    d = ImageDraw.Draw(m)
    for _ in range(count):
        cx, cy = rng.random(2) * size
        rx = rng.uniform(rmin, rmax)
        ry = rx * rng.uniform(0.55, 0.85)
        pts = []
        k = int(rng.integers(7, 11))
        for i in range(k):
            a = 2 * np.pi * i / k + rng.uniform(-0.2, 0.2)
            rr = rng.uniform(0.82, 1.08)
            pts.append((np.cos(a) * rx * rr, np.sin(a) * ry * rr))
        for ox, oy in wrap_offsets(size):
            d.polygon([((cx + ox + x) * ss, (cy + oy + y) * ss) for x, y in pts], fill=255)
    cov = np.asarray(m.resize((size, size), Image.LANCZOS), float) / 255
    return cov


def soil() -> np.ndarray:
    """Laterite soil with wavy strata, pebbles and a few half-buried stones, 512 px, tiles both ways."""
    size = 512
    rng = np.random.default_rng(3)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    warp = (fbm(size, size, 2, 3, 3, rng, True, True) - 0.5) * 60
    yw = (yy + warp) % size
    # strata: bands of colour along the warped height, soft transitions
    nb = len(SOIL_STRATA)
    band = yw / size * nb
    i0 = np.floor(band).astype(int) % nb
    f = smooth(0.7, 1.0, band - np.floor(band))
    cols = np.array([hexc(c) for c in SOIL_STRATA])
    col = cols[i0] * (1 - f[..., None]) + cols[(i0 + 1) % nb] * f[..., None]
    # thin dark seams between some strata
    seam = np.exp(-((band - np.round(band)) * size / nb / 2.2) ** 2) * (np.round(band) % 2 == 0)
    col *= 1 - seam[..., None] * 0.22
    # broad patches of darker umber and paler ochre, then painterly mottling and brush marks
    patch = fbm(size, size, 3, 3, 4, rng, True, True)
    col = mix(col, hexc("6e3420"), smooth(0.55, 0.78, patch) * 0.45)
    col = mix(col, hexc("d0905a"), (1 - smooth(0.22, 0.42, patch)) * 0.35)
    mott = fbm(size, size, 6, 6, 5, rng, True, True)
    col *= (0.86 + 0.28 * mott)[..., None]
    brush = blur(rng.standard_normal((size, size)), (1.2, 8), wrap_x=True)
    brush = ndimage.gaussian_filter(brush, (1.2, 0), mode="wrap")
    col += (brush / brush.std() * 3.5)[..., None] * np.array([1.0, 0.85, 0.7])
    # pebbles and stones, lit from the upper left
    for count, rmin, rmax, tint, dark in ((70, 2.0, 5.0, "e2c098", "9a6a4e"), (26, 7.0, 15.0, "c9a07a", "7a5448"),
                                          (10, 16.0, 28.0, "bca39a", "6a5260")):
        cov = stones_layer(size, rng, count, rmin, rmax)
        height = ndimage.gaussian_filter(cov, rmax * 0.35, mode="wrap") * rmax * 0.9
        lam = normals_light(height, 1.0)
        stone = mix(hexc(dark), hexc(tint), smooth(0.25, 0.85, lam))
        stone = mix(stone, hexc("f2d3a8"), smooth(0.86, 1.0, lam) * 0.6)
        stone *= (0.9 + 0.2 * fbm(size, size, 16, 16, 2, rng, True, True))[..., None]
        # contact shadow below/right of each stone
        sh = np.clip(np.roll(ndimage.gaussian_filter(cov, 1.6, mode="wrap"), (3, 2), (0, 1)) - cov, 0, 1)
        col *= 1 - sh[..., None] * 0.45
        col = mix(col, stone, cov)
    # tiny cracks
    crack = strokes(size, size, rng, length=30, width=0.7)
    col *= 1 - (np.clip(np.abs(crack) < 0.02, 0, 1) * 0.0)[..., None]
    return np.clip(col, 0, 255)


def rock() -> np.ndarray:
    """Warm sandstone in horizontal beds, as the cliffs of a mesa: beds of uneven thickness, each
    split by a few vertical joints into long blocks; the top of each bed a lit ledge, its bottom an
    undercut in shade (violet-brown), weathered pocks and fine bedding lines inside. Lit from the
    upper left. 512 px (256 units), tiles both ways; terrain.gdshader adds the form shading."""
    size = 512
    rng = np.random.default_rng(9)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    # bed boundaries: thicknesses summing to the tile height
    th = rng.uniform(12, 90, 16)
    th = th[: np.searchsorted(np.cumsum(th), size) + 1]
    th *= size / th.sum()
    tops = np.concatenate([[0], np.cumsum(th)[:-1]])
    warp = (fbm(size, size, 3, 4, 3, rng, True, True) - 0.5) * 34  # wavy bedding planes
    warp += (fbm(size, size, 8, 16, 2, rng, True, True) - 0.5) * 5
    yw = (yy + warp) % size
    bed = np.searchsorted(np.cumsum(th), yw, side="right").clip(0, len(th) - 1)
    in_bed = yw - tops[bed]  # px from the top of its bed
    bed_h = th[bed]
    # vertical joints: per bed, a few x positions (wrapping), each a little slanted
    joint_d = np.full((size, size), 1e9)
    block = np.zeros((size, size))
    recess = np.zeros((size, size))  # some beds stand out, some are weathered back
    jwob = (fbm(size, size, 16, 4, 2, rng, True, True) - 0.5) * 8
    for b in range(len(th)):
        m = bed == b
        n = int(rng.integers(1, 4))
        xs = np.sort(rng.uniform(0, size, n))
        slant = rng.uniform(-0.35, 0.35)
        x_b = (xx + (in_bed - bed_h / 2) * slant + jwob) % size
        ds = []
        for j in xs:  # a joint through the bed, or a crack that dies out half way
            d = np.abs(((x_b - j + size / 2) % size) - size / 2)
            if rng.random() < 0.45:
                stop = rng.uniform(0.35, 0.7) * th[b]
                d = d + smooth(stop, stop + 8, in_bed if rng.random() < 0.5 else bed_h - in_bed) * 40
            ds.append(d)
        joint_d = np.where(m, np.min(ds, axis=0), joint_d)
        idx = np.searchsorted(xs, x_b) % n
        block = np.where(m, (b * 7 + idx) % 11 / 10.0, block)
        recess = np.where(m, rng.uniform(-1, 1), recess)
    # relief: ledge at the top of each bed, undercut at the bottom, joints cut in, pocks
    from_bottom = bed_h - in_bed
    height = smooth(0, 7, in_bed) * 6 - (1 - smooth(0, 10, from_bottom)) * 7
    height -= (1 - smooth(0.5, 5, joint_d)) * 7
    pock = fbm(size, size, 24, 24, 3, rng, True, True)
    height -= smooth(0.62, 0.8, pock) * 3
    height += (fbm(size, size, 12, 12, 4, rng, True, True) - 0.5) * 3
    height = ndimage.gaussian_filter(height, 1.0, mode="wrap")
    lam = normals_light(height, 1.0) * (0.92 + 0.1 * recess)
    tone = np.clip(block * 0.5 + fbm(size, size, 4, 8, 3, rng, True, True) * 0.5, 0, 1)
    base = ramp(tone, [(0, "a85a36"), (0.35, "c06e3e"), (0.65, "cf8a4e"), (1, "dca266")])
    col = mix(hexc("4e2c36"), base, smooth(0.12, 0.6, lam))
    col = mix(col, hexc("f8d49c"), smooth(0.78, 1.0, lam) * 0.55)
    # the lit lip of each ledge and the deep shade under each overhang
    lip = np.exp(-(in_bed / 2.2) ** 2) * (joint_d > 2)
    col = mix(col, hexc("ffe2b0"), lip * 0.55)
    under = np.exp(-(from_bottom / 5.0) ** 2)
    col = mix(col, hexc("3a1e2c"), under * 0.7)
    col = mix(col, hexc("4a2630"), (1 - smooth(0.4, 2.0, joint_d)) * 0.55)
    # sandstone grain, larger weathering stains, painterly marks
    grain_n = ndimage.gaussian_filter(rng.standard_normal((size, size)), 0.7, mode="wrap")
    col *= (1 + grain_n / grain_n.std() * 0.035)[..., None]
    stain = fbm(size, size, 5, 5, 4, rng, True, True)
    col = mix(col, col * np.array([0.82, 0.74, 0.78]), smooth(0.55, 0.8, stain) * 0.6)
    col *= (0.9 + 0.18 * fbm(size, size, 32, 32, 2, rng, True, True))[..., None]
    brush = blur(rng.standard_normal((size, size)), (0.6, 6), wrap_x=True)
    col += (brush / brush.std() * 2.5)[..., None]
    return np.clip(col, 0, 255)


def shape_tile(mask: int, variant: int) -> np.ndarray:
    """RGBA of one cell: R edge light (0.5 none), G outline, B rim light, A coverage."""
    rng = np.random.default_rng(100 + mask * 7 + variant * 131)
    T, ss = CELL, 4
    big = T * ss
    t = np.linspace(0, 1, big)
    # each open side is pushed in a little and wobbles; the wobble is 0 at the cell's corners so
    # neighbouring cells meet
    def wob(amp):
        k = rng.uniform(0, 6.28, 3)
        return amp * np.sin(t * np.pi) * (0.6 * np.sin(t * np.pi * 2 + k[0]) + 0.4 * np.sin(t * np.pi * 5 + k[1]))
    inset = 1.5 * PX * ss
    yy, xx = np.mgrid[0:big, 0:big].astype(float)
    inside = np.ones((big, big), bool)
    dist = np.full((big, big), 1e9)
    if mask & N:
        edge = inset * 0.5 + wob(1.0 * PX * ss)[None, :]
        inside &= yy >= edge
        dist = np.minimum(dist, yy - edge)
    if mask & S:
        edge = big - inset - np.abs(wob(2.0 * PX * ss))[None, :]
        inside &= yy <= edge
        dist = np.minimum(dist, edge - yy)
    if mask & W:
        edge = inset + np.abs(wob(3.6 * PX * ss))[:, None]
        inside &= xx >= edge
        dist = np.minimum(dist, xx - edge)
    if mask & E:
        edge = big - inset - np.abs(wob(3.6 * PX * ss))[:, None]
        inside &= xx <= edge
        dist = np.minimum(dist, edge - xx)
    # rounded outer corners
    r = 11 * PX * ss
    for sides, cx, cy in ((N | W, r, r), (N | E, big - r, r), (S | E, big - r, big - r), (S | W, r, big - r)):
        if mask & sides == sides:
            inx = (xx < cx) if cx == r else (xx > cx)
            iny = (yy < cy) if cy == r else (yy > cy)
            dd = r - np.hypot(xx - cx, yy - cy) - inset
            corner = inx & iny
            inside &= ~corner | (dd >= 0)
            dist = np.where(corner, np.minimum(dist, dd), dist)
    cov = downsample(inside.astype(float), ss)
    dist = downsample(np.clip(dist, -50, 1e4), ss) / (PX * ss) * ss  # in design units (approx)
    dist = downsample_dist(dist)
    yy1, xx1 = np.mgrid[0:T, 0:T].astype(float) / (T - 1)
    light = np.full((T, T), 0.5)
    if mask & W:
        light += 0.27 * np.exp(-np.clip(xx1 * 32 - 1.5, 0, None) / 3.5)
    if mask & E:
        light -= 0.36 * np.exp(-np.clip((1 - xx1) * 32 - 1.5, 0, None) / 9.0)
    if mask & S:
        light -= 0.38 * np.exp(-np.clip((1 - yy1) * 32 - 1.5, 0, None) / 9.0)
    outline = 1 - smooth(0.6, 1.9, dist)
    rim = (1 - smooth(1.6, 3.6, dist)) * (1 - outline)
    if not mask & (W | N):
        rim *= 0.0
    a = cov
    return np.dstack([np.clip(light, 0, 1) * 255, outline * 255, rim * 255, a * 255])


def downsample(a: np.ndarray, ss: int) -> np.ndarray:
    h, w = a.shape[0] // ss, a.shape[1] // ss
    return a.reshape(h, ss, w, ss).mean(axis=(1, 3))


def downsample_dist(d: np.ndarray) -> np.ndarray:
    return d


PAD = 4  # pixels of extruded border around each atlas cell: no seams from filtering
STRIDE = CELL + 2 * PAD


def shape_atlas() -> Image.Image:
    """16 masks across x 4 variants down, each cell at (mask * STRIDE + PAD, variant * STRIDE + PAD)."""
    atlas = np.zeros((4 * STRIDE, 16 * STRIDE, 4))
    for mask in range(16):
        for v in range(4):
            t = np.pad(shape_tile(mask, v), ((PAD, PAD), (PAD, PAD), (0, 0)), mode="edge")
            atlas[v * STRIDE:(v + 1) * STRIDE, mask * STRIDE:(mask + 1) * STRIDE] = t
    return Image.fromarray(np.clip(atlas + 0.5, 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ grass

CAP_ABOVE = 18  # units of blades above the surface
CAP_BELOW = 34  # units of grass, roots and shadow below it
CAP_H = (CAP_ABOVE + CAP_BELOW) * PX


def grass_mass(w: int, h: int, surface: float, rng, wrap: bool, ss: int = 3,
               left_end: bool = False, right_end: bool = False) -> tuple:
    """The lush band: coverage of the mass and of the blades, and their colour, at w x h px.
    surface: y (px) of the ground line. Blades are painted strokes over a scalloped mass."""
    W, H = w * ss, h * ss
    sf = surface * ss
    xs = np.arange(W) / ss
    # lower edge of the mass: scallops (clumps hanging over the soil)
    n = max(4, w // 26)
    phase = rng.uniform(0, 1, n)
    lower = np.zeros(W)
    for i in range(n):
        cx = (i + 0.5 + rng.uniform(-0.3, 0.3)) * w / n
        width = w / n * rng.uniform(0.55, 0.85)
        depth = rng.uniform(7, 15) * PX
        d = (xs - cx)
        if wrap:
            d = (d + w / 2) % w - w / 2
        lower = np.maximum(lower, depth * np.sqrt(np.clip(1 - (d / width) ** 2, 0, 1)))
    lower = np.maximum(lower, 5 * PX) + rng.uniform(-0.5, 0.5, W) * 0
    lower = ndimage.gaussian_filter1d(lower, 2 * ss, mode="wrap" if wrap else "nearest")
    yy = np.arange(H)[:, None]
    ragged = (np.abs(ndimage.gaussian_filter1d(rng.standard_normal(W), 1.5 * ss, mode="wrap" if wrap else "nearest")) * 9) * PX * ss
    mass = (yy >= sf - 3 * PX * ss + ragged[None, :]) & (yy <= sf + lower[None, :] * ss)
    mass_img = Image.fromarray((mass * 255).astype(np.uint8))
    blades_img = Image.new("L", (W, H), 0)
    tone_img = Image.new("L", (W, H), 0)  # 0 dark .. 255 light, per blade
    db, dt = ImageDraw.Draw(blades_img), ImageDraw.Draw(tone_img)
    count = int(w * 2.2)
    for i in range(count):
        bx = rng.uniform(0, w)
        top_k = rng.random()
        hgt = (3 + top_k ** 2.2 * (CAP_ABOVE - 4)) * PX
        lean = rng.normal(0.25, 0.35) * hgt
        bw = rng.uniform(1.0, 1.9) * PX
        base_y = surface + rng.uniform(1, 6) * PX
        tone = int(np.clip(110 + top_k * 120 + rng.normal(0, 25) + (lean < 0) * -40, 0, 255))
        offs = (-w, 0, w) if wrap else (0,)
        for ox in offs:
            x0 = (bx + ox) * ss
            pts = [(x0 - bw * ss, base_y * ss), (x0 + bw * ss, base_y * ss),
                   (x0 + (lean * 0.6 + bw * 0.4) * ss, (base_y - hgt * 0.6) * ss), (x0 + lean * ss, (base_y - hgt) * ss)]
            db.polygon(pts, fill=255)
            dt.polygon(pts, fill=tone)
    # hanging blades along the lower edge
    for i in range(int(w * 0.5)):
        bx = rng.uniform(0, w)
        i0 = int(np.clip(bx * ss, 0, W - 1))
        y0 = surface + lower[i0] / PX * PX - 2 * PX
        hgt = rng.uniform(3, 9) * PX
        lean = rng.normal(0.1, 0.3) * hgt
        bw = rng.uniform(1.0, 1.6) * PX
        offs = (-w, 0, w) if wrap else (0,)
        for ox in offs:
            x0 = (bx + ox) * ss
            pts = [(x0 - bw * ss, y0 * ss), (x0 + bw * ss, y0 * ss), (x0 + lean * ss, (y0 + hgt) * ss)]
            db.polygon(pts, fill=255)
            dt.polygon(pts, fill=60)
    blades = np.asarray(blades_img, float) / 255
    tone = np.asarray(tone_img, float) / 255
    m = np.asarray(mass_img, float) / 255
    cov = np.maximum(m, blades)
    return downsample(cov, ss), downsample(m, ss), downsample(blades, ss), downsample(tone * blades, ss) / np.maximum(downsample(blades, ss), 1e-3), lower[::ss] / PX


def paint_cap(w: int, rng, wrap: bool = True) -> tuple:
    """The grass cap strip: RGB and alpha, w px wide, CAP_H tall; the surface at CAP_ABOVE units."""
    surface = CAP_ABOVE * PX
    cov, mass, blades, tone, lower = grass_mass(w, CAP_H, surface, rng, wrap)
    return colour_grass(mass, blades, tone, cov, surface, np.asarray(lower) * PX, rng, wrap), cov


def roots_strip() -> Image.Image:
    """Roots reaching down into the soil under the grass, tiles in x: 512 x 34 units at 2 px, the
    surface at the top edge. Drawn only under tops with no open side (the corners are rounded)."""
    w, h = STRIP, int(34 * PX)
    rng = np.random.default_rng(19)
    ss = 3
    img = Image.new("L", (w * ss, h * ss), 0)
    hi = Image.new("L", (w * ss, h * ss), 0)
    d, dh = ImageDraw.Draw(img), ImageDraw.Draw(hi)
    clusters = rng.uniform(0, w, int(w / 160))  # roots gather under the clumps, gaps between
    for _ in range(int(w / 55)):
        x = (rng.choice(clusters) + rng.normal(0, 40)) % w if rng.random() < 0.8 else rng.uniform(0, w)
        y = rng.uniform(5, 11) * PX
        length = rng.uniform(8, 24) * PX
        width = rng.uniform(1.0, 2.4) * PX
        steps = 10
        drift = rng.uniform(-0.5, 0.5)
        pts = []
        for k in range(steps + 1):
            t = k / steps
            pts.append((x + np.sin(t * 5 + x) * 1.6 * PX + drift * t * length * 0.5, y + length * t))
        for ox in (-w, 0, w):
            for k in range(steps):
                wk = width * (1 - 0.75 * k / steps)
                (x0, y0), (x1, y1) = pts[k], pts[k + 1]
                d.line([((x0 + ox) * ss, y0 * ss), ((x1 + ox) * ss, y1 * ss)], fill=255, width=max(1, int(wk * ss)))
                dh.line([((x0 + ox - wk * 0.25) * ss, y0 * ss), ((x1 + ox - wk * 0.25) * ss, y1 * ss)], fill=255,
                        width=max(1, int(wk * 0.35 * ss)))
            # a few rootlets
            for _ in range(2):
                k = int(rng.integers(2, steps - 1))
                x0, y0 = pts[k]
                sgn = rng.choice([-1, 1])
                x1, y1 = x0 + sgn * rng.uniform(3, 7) * PX, y0 + rng.uniform(2, 6) * PX
                for ox in (-w, 0, w):
                    d.line([((x0 + ox) * ss, y0 * ss), ((x1 + ox) * ss, y1 * ss)], fill=255, width=max(1, int(0.8 * PX * ss)))
    m = downsample(np.asarray(img, float) / 255, ss)
    lit = downsample(np.asarray(hi, float) / 255, ss)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    m *= 1 - smooth(h * 0.55, h, yy)
    col = mix(ROOT, ROOT_HI, lit)
    # a soft dark seam around each root: they sit in the soil
    seam = np.clip(blur(m, 1.5, wrap_x=True) * 1.6 - m, 0, 1) * 0.5
    alpha = np.clip(m + seam, 0, 1)
    rgb = (col * m[..., None] + hexc("2a120c") * seam[..., None]) / np.maximum(alpha, 1e-4)[..., None]
    return dither_rgba(np.clip(rgb, 0, 255), alpha * 0.9, rng)


def grass_cap() -> Image.Image:
    rng = np.random.default_rng(17)
    rgb, a = paint_cap(STRIP, rng, True)
    return dither_rgba(rgb, a, rng)


END_OUT = 12  # units an end piece reaches past the cell's open side
END_FADE = 10  # units it reaches into the next cell, fading over that cell's strip
END_W = END_OUT + 32 + END_FADE  # 54
END_H = CAP_ABOVE + 30  # 48


def paint_end(rng, side: str) -> tuple:
    """One end of a cap, END_W x END_H units: the grass band rounds the corner and drapes a little
    down the open side; blades lean out over the edge. side: 'left' (open side on the left, lit)
    or 'right' (open side on the right, in shade). Laid out for the left; the right is painted
    the same way mirrored, then lit from its own side."""
    ss = 3
    w, h = END_W * PX, END_H * PX
    W, H = w * ss, h * ss
    surface = CAP_ABOVE * PX
    yy, xx = np.mgrid[0:H, 0:W].astype(float) / ss  # in px
    edge = END_OUT * PX  # the cell's open side
    top = surface - 3 * PX
    # lower edge of the band: scallops like the strip, deepening into a drape at the corner
    xs = np.arange(W) / ss
    lower = np.full(W, 7.0 * PX)
    for i in range(4):
        cx = edge + (8 + i * 11 + rng.uniform(-2, 2)) * PX
        lower = np.maximum(lower, rng.uniform(8, 13) * PX * np.sqrt(np.clip(1 - ((xs - cx) / (6 * PX)) ** 2, 0, 1)))
    drape_len = rng.uniform(15, 19) * PX
    lower = np.maximum(lower, drape_len * np.sqrt(np.clip(1 - ((xs - edge - 3 * PX) / (8 * PX)) ** 2, 0, 1)))
    lower = ndimage.gaussian_filter1d(lower, 2 * ss)
    ragged = np.abs(ndimage.gaussian_filter1d(rng.standard_normal(W), 1.5 * ss)) * 9 * PX
    band = (yy >= top + ragged[None, :]) & (yy <= surface + lower[None, :])
    # rounded outer side: a circle at the corner, the drape's outer face a little past the edge
    r = 7 * PX
    out_x = edge - 3 * PX
    corner = (xx < out_x + r) & (yy < top + r) & (np.hypot(xx - out_x - r, yy - top - r) > r)
    band &= (xx >= out_x) & ~corner
    drape_bottom = surface + drape_len
    round_b = (yy > drape_bottom - 6 * PX) & (np.hypot((xx - out_x - 6 * PX) / 1.0, yy - drape_bottom + 6 * PX) > 6 * PX) & (xx < out_x + 6 * PX)
    band &= ~round_b
    mass = downsample(band.astype(float), ss)
    blades_img = Image.new("L", (W, H), 0)
    tone_img = Image.new("L", (W, H), 0)
    db, dt = ImageDraw.Draw(blades_img), ImageDraw.Draw(tone_img)

    def blade(bx, by, hgt, lean, bw, tone, down=False):
        sgn = 1 if down else -1
        pts = [((bx - bw) * ss, by * ss), ((bx + bw) * ss, by * ss),
               ((bx + lean * 0.6 + bw * 0.3) * ss, (by + sgn * hgt * 0.6) * ss), ((bx + lean) * ss, (by + sgn * hgt) * ss)]
        db.polygon(pts, fill=255)
        dt.polygon(pts, fill=int(np.clip(tone, 0, 255)))

    for _ in range(int(w * 1.3)):
        bx = rng.uniform(out_x + 2 * PX, w)
        k = rng.random()
        hgt = (3 + k ** 2.2 * (CAP_ABOVE - 5)) * PX
        near = np.clip(1 - (bx - out_x) / (14 * PX), 0, 1)  # near the corner: shorter, leaning out
        hgt *= 1 - near * 0.4
        lean = (rng.normal(0.25, 0.35) - near * 0.9) * hgt
        blade(bx, surface + rng.uniform(1, 6) * PX, hgt, lean, rng.uniform(1.0, 1.9) * PX, 110 + k * 120 + rng.normal(0, 25))
    for _ in range(14):  # blades sticking out of the corner sideways
        by = rng.uniform(top, top + 10 * PX)
        hgt = rng.uniform(5, 11) * PX
        blade(out_x + 3 * PX, by + hgt * 0.3, hgt * 0.5, -hgt * 0.9, rng.uniform(1.0, 1.6) * PX, 150 + rng.normal(0, 30))
    for _ in range(int(w * 0.35)):  # hanging from the band's lower edge and the drape
        bx = rng.uniform(out_x + 1 * PX, w)
        i0 = int(np.clip(bx * ss, 0, W - 1))
        hgt = rng.uniform(3, 9) * PX
        blade(bx, surface + lower[i0] - 2 * PX, hgt, rng.normal(0.0, 0.3) * hgt, rng.uniform(1.0, 1.5) * PX, 60, down=True)
    blades = downsample(np.asarray(blades_img, float) / 255, ss)
    tone = downsample(np.asarray(tone_img, float) / 255, ss) / np.maximum(blades, 1e-3)
    cov = np.maximum(mass, blades)
    lower_px = downsample(lower[None, :].repeat(ss, 0), ss)[0]
    col = colour_grass(mass, blades, tone, cov, surface, lower_px, rng, wrap=False)
    # the outer side: lit (left end) or in shade (right end, mirrored afterwards)
    y1, x1 = np.mgrid[0:h, 0:w].astype(float)
    near = np.clip(1 - (x1 - out_x) / (10 * PX), 0, 1) * mass
    if side == "left":
        col = mix(col, col * np.array([1.18, 1.12, 0.9]), near * 0.6)
    else:
        col = mix(col, col * np.array([0.62, 0.7, 0.82]), near * 0.7)
    # fade the inner end over the next cell's strip
    fade = 1 - smooth((END_OUT + 32) * PX, w, x1)
    alpha = cov * fade
    if side == "right":
        col, alpha = col[:, ::-1], alpha[:, ::-1]
    return col, alpha


def blade_texture(w: int, h: int, rng, density: float = 1.0, wrap: bool = True) -> np.ndarray:
    """Short slanted strokes of random value (0..1): the grass seen inside the band, painted."""
    ss = 2
    img = Image.new("L", (w * ss, h * ss), 128)
    d = ImageDraw.Draw(img)
    for _ in range(int(w * h / 18 * density)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ln = rng.uniform(3, 8) * PX
        lean = rng.normal(0.25, 0.3) * ln
        v = int(np.clip(rng.normal(128, 55), 0, 255))
        wd = max(1, int(rng.uniform(0.8, 1.5) * PX * ss))
        for ox in ((-w, 0, w) if wrap else (0,)):
            d.line([((x + ox) * ss, y * ss), ((x + ox + lean) * ss, (y - ln) * ss)], fill=v, width=wd)
    return downsample(np.asarray(img, float) / 255, ss)


def colour_grass(mass, blades, tone, cov, surface, lower, rng, wrap=True):
    """Colours a grass band (mass) and its blades: lit tips, deep cool shade at the bottom."""
    h, w = mass.shape
    yy = np.arange(h)[:, None] * np.ones((1, w))
    height = blur(mass, 3 * PX, wrap_x=wrap) * 10 + blur(mass, 1 * PX, wrap_x=wrap) * 3
    lam = normals_light(height, 1.0)
    rel = (yy - (surface - 4 * PX)) / ((np.asarray(lower)[None, :] / PX + 4) * PX)
    mass_col = ramp(np.clip(rel, 0, 1), [(0, GRASS_HI), (0.35, GRASS), (0.75, GRASS_MID), (1.0, GRASS_DEEP)])
    mass_col = mix(mass_col, GRASS_SHADOW, smooth(0.75, 1.1, rel) * 0.5)
    mass_col = mass_col * (0.85 + 0.3 * lam[..., None])
    bt = blade_texture(w, h, rng, 1.0, wrap)
    mass_col = mass_col * (0.8 + 0.4 * bt[..., None])
    above = np.clip((surface - yy) / (CAP_ABOVE * PX), 0, 1)
    blade_col = ramp(above, [(0, GRASS_MID), (0.4, GRASS), (0.8, GRASS_HI), (1.0, GRASS_TIP)])
    blade_col = mix(blade_col * 0.72, blade_col, tone)
    col = mix(mass_col, blade_col, np.clip(blades - mass * 0.35, 0, 1))
    rim = np.clip(cov - np.roll(cov, PX * 2, axis=0), 0, 1) * (1 - mass)
    col = mix(col, GRASS_TIP, rim * 0.35)
    under_edge = np.clip(mass - np.roll(mass, -PX, axis=0), 0, 1)
    col = mix(col, GRASS_SHADOW * 0.7, under_edge * 0.45)
    return np.clip(col, 0, 255)


def grass_ends() -> Image.Image:
    """The left end (lit) and the right end (in shade) of a cap, END_W x END_H units each, side by
    side. A piece covers its whole end cell, reaches END_OUT past the open side, and fades over
    the first END_FADE units of the next cell."""
    rng = np.random.default_rng(23)
    cl, al = paint_end(rng, "left")
    cr, ar = paint_end(rng, "right")
    return dither_rgba(np.hstack([cl, cr]), np.hstack([al, ar]), rng)


DRAPE_W, DRAPE_H = 30, 50  # units of one drape piece
DRAPE_IN = 8  # units of the piece over its own cell; the rest hangs out past the open side
DRAPE_TOP = 12  # units of the piece above the grass surface


def paint_drape(rng, side: str) -> tuple:
    """Grass hanging over a top's open side: a tuft whose blades lean out past the edge and droop
    down the face, with a few roots dangling below and a soft shadow on the face under it.
    DRAPE_W x DRAPE_H units; the edge of the cell is DRAPE_IN units from the piece's inner side."""
    w, h = DRAPE_W * PX, DRAPE_H * PX
    ss = 3
    edge = DRAPE_IN * PX
    surf = DRAPE_TOP * PX
    blades = Image.new("L", (w * ss, h * ss), 0)
    tone = Image.new("L", (w * ss, h * ss), 0)
    roots = Image.new("L", (w * ss, h * ss), 0)
    db, dt, dr = ImageDraw.Draw(blades), ImageDraw.Draw(tone), ImageDraw.Draw(roots)
    for _ in range(46):
        x0 = rng.uniform(0, edge + 2 * PX)  # rooted on the top, near the edge
        y0 = surf + rng.uniform(0, 3) * PX
        out = rng.uniform(4, 20) * PX  # how far past the edge it leans
        drop = rng.uniform(2, 30) * PX * (0.3 + out / (20 * PX))
        bw = rng.uniform(0.9, 2.0) * PX
        pts = []
        for k in range(9):
            t = k / 8
            x = x0 + (edge - x0 + out) * np.sin(t * np.pi / 2)
            y = y0 - rng.uniform(2, 7) * PX * np.sin(t * np.pi) * 0.6 + drop * t * t
            pts.append((x, y))
        v = int(np.clip(rng.normal(150, 60), 30, 255))
        for k in range(8):
            wk = bw * (1 - 0.8 * k / 8)
            (xa, ya), (xb, yb) = pts[k], pts[k + 1]
            db.line([(xa * ss, ya * ss), (xb * ss, yb * ss)], fill=255, width=max(1, int(wk * ss)))
            dt.line([(xa * ss, ya * ss), (xb * ss, yb * ss)], fill=v, width=max(1, int(wk * ss)))
    for _ in range(3):  # roots dangling down the face
        x = edge + rng.uniform(-1, 3) * PX
        y0 = surf + rng.uniform(4, 8) * PX
        ln = rng.uniform(10, 30) * PX
        pts = [(x + np.sin(k * 0.9) * 1.2 * PX + k * 0.25 * PX, y0 + ln * k / 10) for k in range(11)]
        dr.line([(px_ * ss, py_ * ss) for px_, py_ in pts], fill=150, width=max(1, int(0.55 * PX * ss)))
    bm = downsample(np.asarray(blades, float) / 255, ss)
    tm = downsample(np.asarray(tone, float) / 255, ss) / np.maximum(bm, 1e-3)
    rm = downsample(np.asarray(roots, float) / 255, ss)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    above = np.clip((surf + 6 * PX - yy) / (14 * PX), 0, 1)  # higher blades catch more light
    col = ramp(np.clip(above * 0.7 + tm * 0.3, 0, 1), [(0, GRASS_DEEP), (0.35, GRASS_MID), (0.65, GRASS), (0.85, GRASS_HI), (1.0, GRASS_TIP)])
    col = mix(col, GRASS_SHADOW, smooth(surf + 8 * PX, h, yy) * 0.5)  # drooping blades in shade
    if side == "right":  # the shaded side of a top
        col = col * np.array([0.78, 0.8, 0.9])
    col = mix(col, ROOT, rm * (1 - bm))
    # the shadow the tuft throws on the face below it
    shade = blur(bm, 3.0) * (xx > edge) * (yy > surf) * 0.45
    alpha = np.clip(np.maximum(np.maximum(bm, rm * 0.9), shade), 0, 1)
    col = np.where((bm + rm)[..., None] > 0.05, col, np.array([30.0, 18.0, 16.0]))
    if side == "left":
        col, alpha = col[:, ::-1], alpha[:, ::-1]
    return col, alpha


def grass_drape() -> Image.Image:
    """The drape for a left open side (lit, its tuft leaning left) and for a right one (in shade),
    side by side, each DRAPE_W x DRAPE_H units."""
    rng = np.random.default_rng(29)
    cl, al = paint_drape(rng, "left")
    cr, ar = paint_drape(rng, "right")
    return dither_rgba(np.hstack([cl, cr]), np.hstack([al, ar]), rng)


UNDER_H = 44  # units of underside.png


def underside() -> Image.Image:
    """Under a cell open below: the earth of a floating ledge hanging under it in uneven lumps
    (its thickness varies along the ledge), shaded from above, a few roots dangling from them, a
    dark shadow lip. 512 x UNDER_H units at 2 px, tiles in x; the cell's bottom edge is 6 units down."""
    w, h = 1024, UNDER_H * PX
    rng = np.random.default_rng(29)
    edge = 6 * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # the lumps' bottom line: slow swells and small knobs, wrapping in x
    depth = (noise1(w, 6, rng, 3) * 26 + noise1(w, 30, rng, 2) * 6 + 2) * PX
    bottom = edge + depth[None, :]
    lump = smooth(1.0, -1.0, yy - bottom) * (yy >= edge - 5 * PX)  # overlaps the cell's inset edge: no gap
    height = blur(lump, (3.0, 3.0), wrap_x=True) * 10
    lam = normals_light(height, 1.0)
    lam = mix(np.full_like(lam, 0.55), lam, smooth(edge, edge + 6 * PX, yy))  # no lit seam at the top
    rel = np.clip((yy - edge + 2 * PX) / (26 * PX), 0, 1)
    soil_col = ramp(rel, [(0, "8c4c2e"), (0.35, "6a3422"), (1.0, "341818")])  # from the soil's colour down
    soil_col = soil_col * (0.75 + 0.45 * lam[..., None])
    soil_col = soil_col * (0.9 + 0.2 * fbm(h, w, 6, 40, 3, rng, wrap_x=True))[..., None]
    rim = np.clip(lump - np.roll(lump, -2, axis=0), 0, 1)  # the lumps' lower edge, an ink line
    soil_col = mix(soil_col, hexc("2a120c"), rim * 0.8)
    roots = Image.new("L", (w * 3, h * 3), 0)
    dr = ImageDraw.Draw(roots)
    for _ in range(int(w / 45)):
        x = rng.uniform(0, w)
        y = float(bottom[0, int(x) % w]) - 2
        length = rng.uniform(4, 16) * PX
        pts = []
        steps = 7
        sway = rng.uniform(-1, 1)
        for k in range(steps + 1):
            t = k / steps
            pts.append(((x + np.sin(t * 3 + x) * 2 + sway * t * t * 6) * 3, (y + length * t) * 3))
        width = rng.uniform(0.8, 1.8)
        for ox in (-w, 0, w):
            for k in range(steps):
                wk = max(1, int(width * (1 - k / steps * 0.7) * 3))
                dr.line([(pts[k][0] + ox * 3, pts[k][1]), (pts[k + 1][0] + ox * 3, pts[k + 1][1])], fill=255, width=wk)
    rm = np.asarray(roots.resize((w, h), Image.LANCZOS), float) / 255 * (1 - lump)
    col = mix(soil_col, mix(ROOT, ROOT_HI, 0.3), rm)
    alpha = np.clip(np.maximum(lump * smooth(edge - 5 * PX, edge + 1 * PX, yy), rm), 0, 1)  # fades in under the soil
    return dither_rgba(np.clip(col, 0, 255), alpha, rng)


MASS_W, MASS_H = 160, 120  # units of one hanging mass (hanging.png: MASS_VARIANTS side by side)
MASS_VARIANTS = 4


def hanging_mass(rng) -> tuple:
    """Round 2: the earth and rock a floating ledge carries under it, so it reads as a floating
    island, not a tiled strip: a mass hanging from a flat top (under the ledge's soil), narrowing
    down in lumps and boulders to an uneven point, soil at the top turning to stone, in the ledge's
    own shade (lit from above: only its upper left catches a warm rim), roots dangling under it.
    MASS_W x MASS_H units at 2 px."""
    w, h = MASS_W * PX, MASS_H * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    u = xx / w
    # the bottom line: deepest a little off the middle, lumps along it
    mid = rng.uniform(0.4, 0.6)
    reach = np.clip(1.0 - np.abs(u - mid) / np.where(u < mid, mid, 1 - mid), 0, 1) ** 0.8
    depth = ((0.15 + 0.85 * reach) * (h - 30 * PX) * (0.8 + 0.4 * noise1(w, 5, rng, 2)[None, :])
             + (noise1(w, 14, rng, 3)[None, :] - 0.5) * 26 * PX * (0.3 + reach[:1]))
    cov = smooth(1.5, -1.5, yy - depth)
    for _ in range(int(rng.integers(3, 6))):  # boulders bulging out of the mass
        bx = rng.uniform(0.2, 0.8) * w
        by = float(depth[0, int(bx)]) * rng.uniform(0.55, 0.9)
        br = rng.uniform(9, 17) * PX
        cov = np.maximum(cov, smooth(br + 1.5, br - 1.5, np.hypot(xx - bx, (yy - by) * 1.1)))
    cov *= smooth(0, 4 * PX, xx) * smooth(w, w - 4 * PX, xx)  # (the ends melt under the ledge's)
    height = blur(cov, 5.0) * 26
    lam = normals_light(height, 1.0)
    rel = np.clip(yy / (h - 30 * PX), 0, 1)
    col = ramp(rel, [(0, "7e4228"), (0.3, "5e3024"), (0.65, "45262e"), (1.0, "2c1a2c")])
    grain = fbm(h, w, 18, 30, 4, rng, wrap_x=False)
    chunks = blur(rng.standard_normal((h, w)), 6.0)
    chunks = np.gradient(chunks / chunks.std(), axis=0) + np.gradient(chunks / chunks.std(), axis=1)
    grain = grain + chunks * 0.6
    from paint import cel, ink_edge  # (round 5: flat light bands and ink, the hero's style)
    col = col * (0.68 + 0.5 * cel(lam, (0.4, 0.62))[..., None]) * (0.95 + 0.1 * grain[..., None])
    rim = np.clip(cov - np.roll(np.roll(cov, 3, axis=0), 3, axis=1), 0, 1) * (1 - rel) ** 1.5
    col = mix(col, hexc("d08a52"), blur(rim, 1.0) * 0.7)
    ink = np.clip(cov - np.roll(cov, -2, axis=0), 0, 1)  # its lower edge, an ink line
    col = mix(col, hexc("22101a"), ink * 0.7)
    roots = Image.new("L", (w * 3, h * 3), 0)
    dr = ImageDraw.Draw(roots)
    for _ in range(int(rng.integers(5, 9))):
        x = rng.uniform(0.15, 0.85) * w
        y = float(depth[0, int(x)]) - 3
        length = rng.uniform(10, 26) * PX
        sway = rng.uniform(-1, 1)
        pts = [((x + np.sin(t * 3 + x) * 2 + sway * t * t * 8) * 3, (y + length * t) * 3) for t in np.linspace(0, 1, 8)]
        for k in range(7):
            dr.line([pts[k], pts[k + 1]], fill=255, width=max(1, int(rng.uniform(1.0, 2.0) * (1 - k / 9) * 3)))
    rm = np.asarray(roots.resize((w, h), Image.LANCZOS), float) / 255 * (1 - cov)
    col = mix(col, mix(ROOT, ROOT_HI, 0.25), rm)
    alpha = np.clip(np.maximum(cov, rm), 0, 1)
    ink = ink_edge(cov, 2.4) * (yy > 6 * PX)  # (not along its top: the ledge's soil sits on it)
    col = mix(col, hexc("2a120e"), ink * 0.9)
    return col, alpha


def hanging() -> Image.Image:
    rng = np.random.default_rng(91)
    parts = [hanging_mass(rng) for _ in range(MASS_VARIANTS)]
    col = np.concatenate([p[0] for p in parts], axis=1)
    alpha = np.concatenate([p[1] for p in parts], axis=1)
    return dither_rgba(np.clip(col, 0, 255), alpha, rng)


EDGE_W, EDGE_H = 22, 64  # units of one rock edge piece


def rock_edge(rng, side: str) -> tuple:
    """Rocks jutting out of a wall's open side: a column of angular sandstone chunks of several
    sizes, each bevelled (lit facets towards the upper left), grained, with an ink line round them,
    so the wall's outline breaks into ledges and blocks. The left side catches the sun, the right one
    is in violet shade. EDGE_W x EDGE_H units, tiles top to bottom; the wall's face is 6 units from
    the piece's inner side."""
    w, h = EDGE_W * PX, EDGE_H * PX
    face = 6 * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    cov = np.zeros((h, w))
    height = np.zeros((h, w))
    tone = np.zeros((h, w))
    y = 0.0
    while y < h:
        ry = rng.uniform(4, 11) * PX
        rx = rng.uniform(5, 13) * PX
        cx = face + rng.uniform(-1, 7) * PX - rx * 0.25
        k = int(rng.integers(5, 8))
        rot = rng.uniform(0, np.pi)
        pts = [(cx + np.cos(rot + i * 2 * np.pi / k) * rx * rng.uniform(0.75, 1.05),
                np.sin(rot + i * 2 * np.pi / k) * ry * rng.uniform(0.75, 1.05)) for i in range(k)]
        for oy in (-h, 0, h):  # wraps top to bottom
            m = poly_mask(w, h, [[(px_, py_ + y + oy) for px_, py_ in pts]])
            if m.max() < 0.01:
                continue
            bevel = ndimage.distance_transform_edt(m > 0.5)
            hgt = np.minimum(bevel, 3.5 * PX) + 2.0
            sel = m > 0.5
            height = np.where(sel, hgt, height)
            tone = np.where(sel, rng.uniform(0, 1), tone)
            cov = np.maximum(cov, m)
        y += ry * rng.uniform(1.2, 1.8)
    cov *= smooth(face - 5 * PX, face - 3 * PX, xx)  # nothing reaches back into the wall's middle
    lam = normals_light(blur(height, 0.8), 1.0)
    grain = fbm(h, w, 8, 4, 3, rng)
    col = ramp(np.clip(lam * 0.85 + tone * 0.15 + (grain - 0.5) * 0.2, 0, 1),
               [(0, "4a2832"), (0.35, "8a4a32"), (0.6, "b8683c"), (0.82, "d89656"), (1.0, "f4cc94")])
    if side == "right":
        col = col * np.array([0.5, 0.45, 0.62])
    seams = np.clip(blur(cov, 1.0) - cov, 0, 1) + np.clip(np.abs(np.gradient(height, axis=0)) > 2.5, 0, 1) * 0.0
    edge = np.clip(cov - blur(cov, 1.2), 0, 1) * 2.2
    col = mix(col, hexc("3b1a12"), np.clip(edge + seams, 0, 1) * 0.9)
    if side == "left":
        col, cov = col[:, ::-1], cov[:, ::-1]
    return col, np.clip(cov, 0, 1)


def rock_edges() -> Image.Image:
    """Two rock edge pieces for a left open side and two for a right one, side by side."""
    rng = np.random.default_rng(37)
    pieces = [rock_edge(rng, side) for side in ("left", "left", "right", "right")]
    return dither_rgba(np.clip(np.hstack([p[0] for p in pieces]), 0, 255), np.hstack([p[1] for p in pieces]), rng)


def tufts() -> Image.Image:
    """One row of 8 clumps (64 x 64 units each at 2 px, standing on the bottom edge): grass,
    grass with white, yellow and violet flowers, dry seed grass."""
    cw, chh = 64 * PX, 48 * PX
    rng = np.random.default_rng(37)
    ss = 3
    cells = []
    kinds = ["grass", "flowers_w", "grass", "flowers_y", "seed", "flowers_v", "grass_tall", "seed"]
    for kind in kinds:
        img = Image.new("RGBA", (cw * ss, chh * ss), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        base = chh * ss
        n = int(rng.integers(16, 26))
        tall = 1.4 if kind == "grass_tall" else 1.0
        dry = kind == "seed"
        for i in range(n):
            bx = cw * ss * (0.5 + rng.normal(0, 0.16))
            hgt = rng.uniform(0.3, 0.8) * chh * ss * 0.75 * tall
            lean = rng.normal(0.15, 0.4) * hgt * 0.6
            bw = rng.uniform(1.2, 2.2) * PX * ss
            k = rng.random()
            if dry:
                c = mix(hexc("b98a3e"), hexc("f0d48a"), k)
            else:
                c = mix(GRASS_MID, GRASS_HI, k * 0.8 + 0.1)
            pts = [(bx - bw, base), (bx + bw, base), (bx + lean * 0.6 + bw * 0.3, base - hgt * 0.6), (bx + lean, base - hgt)]
            d.polygon(pts, fill=tuple(int(v) for v in c) + (255,))
            if dry and rng.random() < 0.5:
                sx, sy = bx + lean, base - hgt
                d.ellipse([sx - 2 * ss * PX, sy - 5 * ss * PX, sx + 2 * ss * PX, sy + 1 * ss * PX], fill=(236, 205, 130, 255))
        if kind.startswith("flowers"):
            petal = {"flowers_w": (250, 246, 236), "flowers_y": (255, 214, 72), "flowers_v": (186, 128, 220)}[kind]
            for i in range(int(rng.integers(3, 6))):
                fx = cw * ss * (0.5 + rng.normal(0, 0.18))
                fh = rng.uniform(0.35, 0.75) * chh * ss
                d.line([(fx, base), (fx + rng.normal(0, 4) * ss, base - fh)], fill=(70, 120, 40, 255), width=int(1.2 * PX * ss))
                cx, cy = fx, base - fh
                r = rng.uniform(2.6, 3.8) * PX * ss
                for p in range(5):
                    a = p * 2 * np.pi / 5 + rng.uniform(0, 1)
                    px, py = cx + np.cos(a) * r * 0.7, cy + np.sin(a) * r * 0.7
                    d.ellipse([px - r * 0.55, py - r * 0.55, px + r * 0.55, py + r * 0.55], fill=petal + (255,))
                d.ellipse([cx - r * 0.4, cy - r * 0.4, cx + r * 0.4, cy + r * 0.4], fill=(240, 160, 40, 255))
        cell = img.resize((cw, chh), Image.LANCZOS)
        a = np.asarray(cell, float)
        rgb, al = a[..., :3], a[..., 3] / 255
        rgb = rgb / np.maximum(al, 1e-3)[..., None] * 1.0
        # shading: lighter on the left of the clump and at the top
        yy, xx = np.mgrid[0:chh, 0:cw].astype(float)
        rgb *= (0.82 + 0.25 * (1 - yy / chh))[..., None] * (1.06 - 0.12 * xx / cw)[..., None]
        cells.append((rgb, al))
    rgb = np.hstack([c[0] for c in cells])
    al = np.hstack([c[1] for c in cells])
    return dither_rgba(np.clip(rgb, 0, 255), al, rng)


def front_grass() -> Image.Image:
    """Blades seen in front of the runners' feet along a top, tiles in x: 512 x 24 units at 2 px.
    The surface is 14 units below the top edge; blades rise from 8 units under it (where the
    boots stand) and fade at their base into the grass band behind."""
    w, h = 1024, int(24 * PX)
    rng = np.random.default_rng(43)
    ss = 3
    img = Image.new("L", (w * ss, h * ss), 0)
    tone = Image.new("L", (w * ss, h * ss), 0)
    d, dt = ImageDraw.Draw(img), ImageDraw.Draw(tone)
    base = (14 + 8) * PX
    for _ in range(int(w * 0.16)):  # clumps of 3-6 blades, gaps between them
        cx = rng.uniform(0, w)
        for _ in range(int(rng.integers(3, 7))):
            bx = (cx + rng.normal(0, 3 * PX)) * ss
            hgt = rng.uniform(7, 20) * PX * ss
            lean = rng.normal(0.35, 0.3) * hgt
            bw = rng.uniform(0.9, 1.7) * PX * ss
            t = int(rng.uniform(70, 255))
            by = (base + rng.uniform(-2, 2) * PX) * ss
            for ox in (-w * ss, 0, w * ss):
                pts = [(bx + ox - bw, by), (bx + ox + bw, by), (bx + ox + lean * 0.6 + bw * 0.2, by - hgt * 0.6),
                       (bx + ox + lean, by - hgt)]
                d.polygon(pts, fill=255)
                dt.polygon(pts, fill=t)
    a = downsample(np.asarray(img, float) / 255, ss)
    tn = downsample(np.asarray(tone, float) / 255, ss) / np.maximum(a, 1e-3)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    up = np.clip((base - yy) / (18 * PX), 0, 1)
    col = ramp(up, [(0, GRASS_DEEP), (0.35, GRASS_MID), (0.7, GRASS), (1, GRASS_HI)])
    col = mix(col * 0.78, col, tn)
    a *= smooth(base, base - 6 * PX, yy)  # the base melts into the band behind
    return dither_rgba(np.clip(col, 0, 255), np.clip(a, 0, 1), rng)


def main() -> None:
    which = set(sys.argv[1:])

    def want(name: str) -> bool:
        return not which or name in which

    # New: the soil and the sandstone are lit reliefs (tools/art/material.py: blocks and stones in
    # volume, cast shadows, occlusion), no longer flat paint with strata stripes and pebble decals
    # (soil() and rock() above are the previous look).
    if want("soil"):
        s = np.clip(material.laterite() * 1.12, 0, 1) * 255.0
        save(dither_rgba(s, np.ones(s.shape[:2])), "soil.png")
    if want("rock"):
        r = np.clip(material.sandstone() * 1.1, 0, 1) * 255.0
        save(dither_rgba(r, np.ones(r.shape[:2])), "rock.png")
    if want("spires"):  # New: the stacks standing in the river (one cell wide walls), 3 side by side
        a = np.concatenate([material.spire(21 + i) for i in range(3)], axis=1)
        save(dither_rgba(a[..., :3] * 255.0, a[..., 3]), "spires.png")
    if want("shape"):
        save(shape_atlas(), "terrain_shape.png")
    if want("cap"):
        save(grass_cap(), "grass_cap.png")
        save(grass_ends(), "grass_ends.png")
        save(grass_drape(), "grass_drape.png")
    if want("under"):
        save(underside(), "underside.png")
        save(roots_strip(), "roots.png")
        save(hanging(), "hanging.png")
    if want("tufts"):
        save(tufts(), "tufts.png")
        save(front_grass(), "front_grass.png")
    print("terrain written")


if __name__ == "__main__":
    main()
