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


def spire(seed: int, w: int = 128, h: int = 840) -> np.ndarray:
    """A sandstone stack standing in the river (RGBA, 2 px a unit): wider at its foot, the outline
    eroded into bulges and notches, rounded like a column (lit on the sun's side, a core shadow, a
    little bounce on the far edge), the same weathered blocks as rock.png."""
    rng = np.random.default_rng(seed)
    n = 512
    tex_h = 34.0 * sandstone_height(n, rng)  # relief to light
    top = 64  # rows lit and dropped (the shadows march over the top edge)
    h += top
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    t = yy / h  # 0 top .. 1 foot
    wob = np.interp(yy[:, 0], np.linspace(0, h, 24), rng.normal(0, 1, 24))
    wob = ndimage.gaussian_filter1d(wob, 6)
    half = (31.0 + 22.0 * t[:, 0] ** 1.6 + 5.0 * wob)  # px: ~32 units wide at the top, ~53 at the foot
    notch = ndimage.gaussian_filter1d(rng.normal(0, 1, h), 9) * 5.0
    cx = w / 2.0 + ndimage.gaussian_filter1d(rng.normal(0, 1, h), 30) * 4.0
    left = cx - half + notch
    right = cx + half - notch * 0.6
    u = np.clip((xx - left[:, None]) / np.maximum(right - left, 1)[:, None], 0.0, 1.0)  # 0..1 across
    inside = np.clip(np.minimum(xx - left[:, None], right[:, None] - xx) + 0.5, 0.0, 1.0)
    # the column's round form as height, plus the stone's relief (tiled from the sandstone)
    form = np.sqrt(np.clip(1.0 - (2.0 * u - 1.0) ** 2, 0.0, 1.0)) * 46.0
    relief = tex_h[(yy.astype(int)) % n, (xx.astype(int) * 2) % n]
    height = form + relief * 0.5
    tones = hexc("c48650") * (0.9 + 0.2 * spectral(n, rng)[(yy.astype(int)) % n, (xx.astype(int) * 3) % n])[..., None]
    rgb = light(height / 34.0, tones, relief=34.0, shadow_steps=10)
    # darker and cooler towards the foot (in the river's shade), a damp band near the bottom
    rgb *= (1.0 - 0.35 * t ** 1.5)[..., None]
    rgb = rgb * (1.0 - 0.25 * t[..., None] ** 2) + np.array([0.18, 0.16, 0.3]) * 0.25 * t[..., None] ** 2
    return np.dstack([rgb, inside])[top:]


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

