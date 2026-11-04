#!/usr/bin/env python3
"""Lit ground materials for the level (tools/art/terrain.py uses them for soil.png and rock.png):
a height field that tiles both ways (spectral noise, wrapped Voronoi cells), lit as a relief by
the game's sun (upper left, golden hour) with cast shadows, ambient occlusion in the cracks, a cool
violet sky light in the shade and a warm bounce: the stone reads as carved volume, as the hero's
3D render does, not as flat paint with decals.

    python3 tools/art/material.py   # writes previews to tools/art/gen/material_*.png
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

SUN = np.array([-0.55, -0.62, 0.56])  ## towards the sun: left, up (image y is down), out of the wall
SUN = SUN / np.linalg.norm(SUN)
SUN_COLOUR = np.array([1.0, 0.86, 0.64])
SKY_COLOUR = np.array([0.52, 0.5, 0.72])  # the shade: cool violet, never grey
BOUNCE_COLOUR = np.array([0.62, 0.42, 0.24])


def spectral(n: int, rng, beta: float = 2.0, low: float = 1.0) -> np.ndarray:
    """Noise that tiles both ways (power falling as 1/f^beta), normalised to 0..1."""
    white = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx * fx + fy * fy) * n
    amp = np.where(r < low, 0.0, 1.0 / np.maximum(r, 1e-6) ** (beta / 2.0))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return (out - out.min()) / (out.max() - out.min())


def warp(field: np.ndarray, dx: np.ndarray, dy: np.ndarray) -> np.ndarray:
    """Samples a tiling field at offsets (pixels), wrapping."""
    ny, nx = field.shape
    yy, xx = np.mgrid[0:ny, 0:nx].astype(float)
    return ndimage.map_coordinates(field, [(yy + dy) % ny, (xx + dx) % nx], order=1, mode="wrap")


def voronoi(n: int, count: int, rng, stretch: float = 1.0):
    """Wrapped Voronoi of `count` random sites: (distance to the nearest site, to the edge between
    the two nearest, index of the nearest), all tiling. `stretch` > 1 widens the cells in x."""
    pts = rng.random((count, 2))
    yy, xx = np.mgrid[0:n, 0:n] / n
    d1 = np.full((n, n), 9.0)
    d2 = np.full((n, n), 9.0)
    idx = np.zeros((n, n), int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, 1.0 - dx) / stretch
        dy = np.abs(yy - py)
        dy = np.minimum(dy, 1.0 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1 * n, (d2 - d1) * n, idx


def light(height: np.ndarray, albedo: np.ndarray, relief: float, occlusion: float = 1.0,
          shadow_steps: int = 28) -> np.ndarray:
    """The relief lit by the sun: Lambert with cast shadows, ambient occlusion, sky and bounce."""
    h = ndimage.gaussian_filter(height, 0.9, mode="wrap") * relief
    gy, gx = np.gradient(np.pad(h, 1, mode="wrap"))
    gx, gy = gx[1:-1, 1:-1], gy[1:-1, 1:-1]
    nrm = np.dstack([-gx, -gy, np.ones_like(h)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    diffuse = np.clip(nrm @ SUN, 0.0, 1.0)
    # cast shadows: march towards the sun over the height field
    step = SUN[:2] / np.linalg.norm(SUN[:2])
    rise = SUN[2] / np.linalg.norm(SUN[:2])  # height gained per pixel towards the sun
    lit = np.ones_like(h)
    hs = ndimage.gaussian_filter(h, 2.5, mode="wrap")  # only the larger forms cast shadows
    for k in range(1, shadow_steps + 1):
        dist = k * 1.5
        ahead = warp(hs, step[0] * dist, step[1] * dist)
        lit = np.minimum(lit, np.clip(1.0 - (ahead - hs - dist * rise) * 0.3, 0.0, 1.0))
    lit = ndimage.gaussian_filter(lit, 0.8, mode="wrap")
    # occlusion: lower than the surroundings
    ao = np.clip(1.0 + (h - ndimage.gaussian_filter(h, 7, mode="wrap")) * 0.09 * occlusion, 0.35, 1.0)
    ao = ao * np.clip(1.0 + (h - ndimage.gaussian_filter(h, 2.5, mode="wrap")) * 0.12 * occlusion, 0.5, 1.0)
    up = np.clip(-nrm[..., 1], 0.0, 1.0)  # faces turned to the sky
    down = np.clip(nrm[..., 1], 0.0, 1.0)  # faces turned to the ground below
    lightc = (SUN_COLOUR * (diffuse * lit)[..., None] * 1.05
              + SKY_COLOUR * (0.42 + 0.25 * up)[..., None] * ao[..., None]
              + BOUNCE_COLOUR * (0.22 * down)[..., None] * ao[..., None])
    return np.clip(albedo * lightc, 0.0, 1.0)


def hexc(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def sandstone(n: int = 512, seed: int = 7) -> np.ndarray:
    """Weathered sandstone: rounded blocks of uneven size (bedding a little wider than tall, never
    brick rows), deep cracks between them, eroded faces, iron streaks and pale dust on the tops."""
    rng = np.random.default_rng(seed)
    big = spectral(n, rng, 2.4, 1.0)
    fine = spectral(n, rng, 1.6, 4.0)
    wx = (spectral(n, rng, 2.6) - 0.5) * 34.0
    wy = (spectral(n, rng, 2.6) - 0.5) * 22.0
    cells = 15
    _, edge, idx = voronoi(n, cells, rng, stretch=2.3)
    edge = warp(edge, wx, wy)
    idx = np.rint(warp(idx.astype(float), wx, wy)).astype(int) % cells
    cell_h = rng.random(cells)
    block = np.clip(edge / 42.0, 0.0, 1.0)
    block = np.sqrt(1.0 - (1.0 - block) ** 2)  # rounded like weathered boulders
    height = block * (0.5 + 0.5 * cell_h[idx]) * 1.3 + big * 0.5 + fine * 0.07
    # horizontal erosion grooves, broken (not continuous strata)
    yy = np.mgrid[0:n, 0:n][0] / n
    grooves = np.sin((yy * 9.0 + big * 1.6) * np.pi * 2.0)
    height -= np.clip(grooves - 0.82, 0.0, 1.0) * 1.4 * (fine > 0.45)
    tones = [hexc("c98a52"), hexc("b8743f"), hexc("d39a5e"), hexc("a8653a"), hexc("bf8048")]
    albedo = np.zeros((n, n, 3))
    for i in range(cells):
        albedo[idx == i] = tones[i % len(tones)]
    albedo = ndimage.gaussian_filter(albedo, (2, 2, 0), mode="wrap")
    albedo *= (0.93 + 0.14 * fine)[..., None]
    streak = np.clip((warp(big, 0, 0) - 0.62) * 4.0, 0.0, 1.0) * np.clip(1.0 - edge / 30.0, 0.0, 1.0)
    albedo = albedo * (1.0 - 0.35 * streak[..., None]) + hexc("6e2f1c") * 0.35 * streak[..., None]
    return light(height, albedo, relief=34.0)


def laterite(n: int = 512, seed: int = 11) -> np.ndarray:
    """Packed red savanna earth: a lumpy surface, stones half buried in it (lit, with their own
    shadow and the dirt gathered round them, not stickers), fine roots and grit."""
    rng = np.random.default_rng(seed)
    big = spectral(n, rng, 2.2, 1.0)
    fine = spectral(n, rng, 1.4, 6.0)
    lumps = spectral(n, rng, 2.0, 3.0)
    height = big * 0.9 + lumps * 0.45 + fine * 0.05
    albedo = hexc("a85a33") * (0.82 + 0.3 * big)[..., None] + (hexc("c27a48") - hexc("a85a33")) * fine[..., None] * 0.5
    # half-buried stones of a few sizes
    d1, _, idx = voronoi(n, 70, rng)
    radius = 6.0 + 14.0 * rng.random(70) ** 2.0
    keep = rng.random(70) < 0.4
    r = radius[idx]
    inside = np.clip(1.0 - d1 / r, 0.0, 1.0) * keep[idx]
    stone = np.sqrt(inside) * r * 0.05
    height = height + stone
    tint = np.array([hexc("b98e6c"), hexc("9d7a5e"), hexc("c49c74"), hexc("8e6a50")])[idx % 4]
    a = np.clip(inside * 3.0, 0.0, 1.0)[..., None]
    albedo = albedo * (1.0 - a) + tint * (0.85 + 0.3 * fine[..., None]) * a
    # dirt gathered round them: a darker ring
    ring = np.clip(1.0 - np.abs(d1 / r - 1.15) * 4.0, 0.0, 1.0) * keep[idx]
    albedo *= (1.0 - 0.18 * ring)[..., None]
    # thin roots
    roots = np.clip(1.0 - np.abs(warp(spectral(n, rng, 3.0), 0, 0) - 0.5) * 60.0, 0.0, 1.0)
    roots *= spectral(n, rng, 2.0) > 0.6
    albedo = albedo * (1.0 - 0.4 * roots[..., None]) + hexc("4a2414") * 0.4 * roots[..., None]
    height -= roots * 0.08
    return light(height, albedo, relief=22.0, occlusion=1.2)


def main() -> None:
    out = Path(__file__).parent / "gen"
    out.mkdir(exist_ok=True)
    for name, fn in (("sandstone", sandstone), ("laterite", laterite)):
        rgb = fn()
        Image.fromarray((rgb * 255 + 0.5).astype(np.uint8)).save(out / f"material_{name}.png")
        print(name, rgb.reshape(-1, 3).mean(0).round(3))


if __name__ == "__main__":
    main()


def spire(seed: int, w: int = 192, h: int = 1120) -> np.ndarray:
    """A sandstone stack standing in the river (RGBA, 2 px a unit). Round 9 (they read as "totem
    poles / stacked bricks": an even column of equal waists and ruled beds): a natural stack that
    tapers from a broad foot to a narrower broken top, each side its own wandering profile, only a
    few uneven beds (a notch at some joints, a ledge stepping out under others, the rock above
    shading the one below), long vertical fissures, each block its own stone colour and patches,
    moss on its lit ledges and under the cap. Lit by the low sun on the upper left in the level's
    cel bands (the pillars' palette: warm lit side, violet-brown shade), inked."""
    from paint import cel, ink_edge
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    y = np.arange(h, dtype=float)
    t = y / h  # 0 top .. 1 foot (the river's surface is about 0.74 down on the poles in the river)
    cap_h = rng.uniform(34, 52)
    joints = [cap_h]
    while joints[-1] < h:  # beds of very uneven thickness
        joints.append(joints[-1] + rng.uniform(110, 300))
    joints = np.array(joints[:-1])
    bed = np.searchsorted(joints, y)  # bed index per row (0: the cap)
    limit = w / 2.0 - 11.0  # (inside its cell, its wobble included)
    base = 40.0 + 34.0 * smooth_np(0.0, 0.72, t) + 18.0 * smooth_np(0.62, 0.8, t)  # tapering up

    def profile() -> np.ndarray:
        big = ndimage.gaussian_filter1d(rng.normal(0, 1, h), 80)
        big = big / (np.abs(big).max() + 1e-6) * 14.0
        mid = ndimage.gaussian_filter1d(rng.normal(0, 1, h), 22)
        mid = mid / (np.abs(mid).max() + 1e-6) * 6.0
        rough = ndimage.gaussian_filter1d(rng.normal(0, 1, h), 5) * 2.6
        out = big + mid + rough
        for j in joints:  # at some joints a notch, under others the bed steps out (a ledge)
            k = rng.random()
            if k < 0.4:
                out -= np.exp(-((y - j) / rng.uniform(5, 12)) ** 2) * rng.uniform(5, 14)
            elif k < 0.8:  # a block jutting out on this side
                out += rng.uniform(5, 14) * smooth_np(j - 2, j + 4, y) * (1 - smooth_np(j + 30, j + 150, y))
        return out

    cap_k = smooth_np(cap_h + 4, cap_h - 3, y)  # 1 on the cap rock
    half_l = base + profile()
    half_r = base + profile() - 3.0
    capw = 44.0 + rng.uniform(0, 8)  # the cap a little wider than its neck
    half_l = half_l * (1 - cap_k) + (capw + rng.uniform(-3, 3) - np.clip(6 - y, 0, 6) * 1.4) * cap_k
    half_r = half_r * (1 - cap_k) + (capw - 2.0 - np.clip(6 - y, 0, 6) * 1.6) * cap_k
    under_cap = np.exp(-((y - cap_h - 8) / 7.0) ** 2) * 7.0
    half_l = np.minimum(half_l - under_cap, limit)
    half_r = np.minimum(half_r - under_cap, limit)
    cx = w / 2.0 + ndimage.gaussian_filter1d(rng.normal(0, 1, h), 90) * 5.0
    left = cx - half_l
    right = cx + half_r
    inside = np.clip(np.minimum(xx - left[:, None], right[:, None] - xx) + 0.5, 0.0, 1.0)
    u = np.clip((xx - left[:, None]) / np.maximum(right - left, 1)[:, None], 0.0, 1.0)  # 0..1 across
    turn = 1.0 - 2.0 * u  # 1 facing the sun .. -1 away
    # the faces: broad, soft facets (a few large planes, not flutes), a little of the stone's grain
    facets = ndimage.gaussian_filter(rng.standard_normal((h, w)), (60.0, 14.0))
    facets = np.gradient(facets / (facets.std() + 1e-6), axis=1) * 3.0
    grain = sandstone_height(512, rng)[(yy.astype(int)) % 512, (xx.astype(int) * 2) % 512]
    grain = grain - ndimage.gaussian_filter(grain, 4)
    # the rock above a joint shades the bed below it; a ledge's top catches the light
    dist_j = np.min(np.abs(y[:, None] - joints[None, :]), axis=1)
    below_j = np.array([y[k] - joints[joints <= y[k]].max() if (joints <= y[k]).any() else 99.0 for k in range(h)])
    shade_j = np.exp(-np.clip(below_j, 0, None) / 8.0) * 0.32
    lam = 0.47 + 0.5 * turn - 0.3 * facets + 0.35 * grain - shade_j[:, None]
    lam += cap_k[:, None] * 0.14 * (turn > -0.35)
    # the band edges follow the beds: each bed's lit band a little wider or narrower
    lam += (rng.random(len(joints) + 1)[bed] - 0.5)[:, None] * 0.18
    lam = 0.1 + 0.8 * cel(np.clip(lam, 0, 1), (0.38, 0.64))
    rgb = ramp_np(lam, [(0.0, "2e1c30"), (0.3, "5a3040"), (0.52, "a4583a"), (0.76, "dc8a4c"), (1.0, "ffc47e")])
    # each bed its own stone: redder, paler, greyer; soft patches within it
    tones = rng.choice([0, 1, 2, 3], len(joints) + 1, p=[0.4, 0.25, 0.2, 0.15])
    tint = np.array([[1.0, 1.0, 1.0], [1.06, 0.92, 0.86], [1.08, 1.06, 0.96], [0.92, 0.9, 0.98]])[tones[bed]]
    rgb *= tint[:, None, :]
    patch = ndimage.gaussian_filter(rng.standard_normal((h, w)), 10.0)
    rgb *= (1.0 + np.clip(patch / (patch.std() + 1e-6), -2, 2) * 0.04)[..., None]
    # long vertical fissures down the faces (jointing: rock splits along, not only across)
    ink = np.zeros((h, w))
    for _ in range(int(rng.integers(2, 4))):
        y0 = rng.uniform(cap_h + 10, h * 0.55)
        y1 = min(y0 + rng.uniform(140, 380), h * 0.8)
        uu = rng.uniform(0.28, 0.78)
        rows = np.arange(int(y0), int(y1))
        walk = np.cumsum(rng.normal(0, 0.8, len(rows)))
        walk = ndimage.gaussian_filter1d(walk, 3)
        xs = left[rows] + uu * (right[rows] - left[rows]) + walk
        for r, x in zip(rows, xs):
            fade = min(1.0, (r - y0) / 30.0, (y1 - r) / 30.0)
            d = np.abs(np.arange(w) - x)
            ink[r] = np.maximum(ink[r], np.clip(1.6 - d, 0, 1) * fade)
            lip = np.clip(1.0 - np.abs(np.arange(w) - x + 2.5) / 1.2, 0, 1) * fade  # its lit lip on the sun side
            rgb[r] = rgb[r] + (np.minimum(rgb[r] * 1.35, 1.0) - rgb[r]) * lip[:, None] * 0.7
    # the bedding joints: a broken ink line across (not ruled), lit just below on the sun side
    broken = ndimage.gaussian_filter1d(rng.normal(0, 1, w), 6)
    broken = broken / (broken.std() + 1e-6)
    for j in joints[1:]:
        tilt = rng.uniform(-0.12, 0.12)  # the beds lean, each its own way
        wav = ndimage.gaussian_filter1d(rng.normal(0, 1, w), 10) * 3.0 + (np.arange(w) - w / 2) * tilt
        d = np.abs(yy - j - wav[None, :])
        on = (np.roll(broken, int(rng.integers(0, w)))[None, :] + rng.uniform(-1.0, 0.0)) > 0.0
        ink = np.maximum(ink, np.clip(1.5 - d, 0, 1) * on * (u > 0.02) * (u < 0.98))
        lit_lip = np.clip(1.0 - np.abs(yy - j - wav[None, :] - 3.0) / 1.5, 0, 1) * (turn > 0.0)
        rgb = rgb + (np.minimum(rgb * 1.3, 1.0) - rgb) * (lit_lip * 0.6)[..., None]
    # the hot rim on the sun's edge and on the cap's top
    rim = np.clip(1.0 - (xx - left[:, None]) / 3.0, 0, 1) + np.clip(1.0 - y / 4.0, 0, 1)[:, None]
    rgb = rgb + (hexc("ffd8a0") - rgb) * (np.clip(rim, 0, 1) * inside * 0.7)[..., None]
    # moss: under the cap and on the lit ledges, in ragged patches
    moss_n = ndimage.gaussian_filter(rng.standard_normal((h, w)), 9.0)
    moss_n = moss_n / (moss_n.std() + 1e-6)
    near_top = smooth_np(cap_h + 60, cap_h + 6, y)[:, None]
    moss = np.clip((near_top + moss_n * 0.3 - 0.5) * 4.0, 0, 1) * inside * smooth_np(cap_h + 90, cap_h + 40, y)[:, None]  # (under the cap only: spots read as dirt)
    moss_col = np.where((moss_n > 0.3)[..., None], hexc("6e8c2c"), hexc("3e5a1e"))
    rgb = rgb + (moss_col * (0.55 + 0.45 * lam[..., None]) - rgb) * (moss * 0.85)[..., None]
    # darker, cooler and damp towards the foot (in the river's shade)
    rgb = rgb * (1.0 - 0.34 * smooth_np(0.4, 1.0, t) ** 1.4)[:, None, None] + np.array([0.06, 0.05, 0.12]) * smooth_np(0.6, 1.0, t)[:, None, None]
    ink = np.maximum(ink_edge(inside, 2.6), ink * inside)
    rgb = rgb * (1 - ink[..., None] * 0.9) + np.array([0.16, 0.08, 0.07]) * ink[..., None] * 0.9
    return np.dstack([np.clip(rgb, 0, 1), inside])


def ramp_np(t: np.ndarray, stops: list) -> np.ndarray:
    """Colour 0..1 of t along stops [(pos, 'hex'), ...]."""
    pos = np.array([p for p, _ in stops])
    cols = np.array([hexc(c) for _, c in stops])
    return np.dstack([np.interp(t, pos, cols[:, k]) for k in range(3)])


def smooth_np(e0: float, e1: float, x):
    x = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def sandstone_height(n: int, rng) -> np.ndarray:
    """The blocks of sandstone() as a height field only (0..~2)."""
    big = spectral(n, rng, 2.4, 1.0)
    wx = (spectral(n, rng, 2.6) - 0.5) * 34.0
    wy = (spectral(n, rng, 2.6) - 0.5) * 22.0
    _, edge, idx = voronoi(n, 15, rng, stretch=2.3)
    edge = warp(edge, wx, wy)
    idx = np.rint(warp(idx.astype(float), wx, wy)).astype(int) % 15
    block = np.sqrt(1.0 - (1.0 - np.clip(edge / 42.0, 0.0, 1.0)) ** 2)
    return block * (0.5 + 0.5 * rng.random(15)[idx]) * 1.3 + big * 0.5

