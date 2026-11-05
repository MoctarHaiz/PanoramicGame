#!/usr/bin/env python3
"""Textures of the interface kit (numpy + Pillow).

    python3 tools/art/ui_kit.py      # assets/art/ui/paper.png, corners.png, ribbon_plain.png

- paper.png: a seamless warm paper/hide grain (256 x 256, tiles both ways), near white: the panels
  multiply their cream by it, so the body reads as a material, not a flat fill. Soft mottling, fine
  fibres running mostly across, a few darker flecks.
- ribbon_plain.png: the menu's subtitle ribbon (ribbon.png) without its dashed stitch.
- corners.png: the jewelled bosses on the panels' corners (src/ui/card.gd): a bevelled metal ring
  set with a ring of small beads, a domed cabochon in it, a soft shadow. Two cells: brass with a red
  stone (every panel), dark bronze with a garnet (a defeat). BOSS_SS px per card unit.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from paint import fbm  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui"


def paper(size: int = 256) -> Image.Image:
    rng = np.random.default_rng(5)
    mottle = fbm(size, size, 4, 4, 4, rng, wrap_x=True, wrap_y=True)
    fibres = ndimage.gaussian_filter(rng.standard_normal((size, size)), (0.6, 5.0), mode="wrap")
    fibres /= np.abs(fibres).max()
    flecks = ndimage.gaussian_filter((rng.random((size, size)) > 0.9975).astype(float), 0.8, mode="wrap")
    flecks /= max(flecks.max(), 1e-6)
    v = 0.955 + (mottle - 0.5) * 0.09 + fibres * 0.03 - flecks * 0.16
    v = np.clip(v, 0.0, 1.0)
    rgb = np.dstack([v, v * 0.985, v * 0.96]) * 255.0
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


BOSS_SS = 3  # px per card unit (sharp on a tablet, where a unit is about 3 px)
BOSS_CELL = 48  # one boss's cell, in units (Card.BOSS)
METALS = {
    "brass": {"ramp": [(0.0, "fffbe2"), (0.22, "ffe27a"), (0.45, "f6b232"), (0.62, "dc8a16"), (0.82, "a0560a"), (1.0, "5a2804")],
              "bead": ["ff9a78", "d81e0c", "5a0604"], "ink": "2e0d04"},
    "bronze": {"ramp": [(0.0, "fff0d8"), (0.22, "e8c08a"), (0.45, "b88a58"), (0.62, "8a6036"), (0.82, "5a3c20"), (1.0, "2e1c0e")],
               "bead": ["d88a7a", "8a2418", "320806"], "ink": "1e1208"},
}


def _hex(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def _ramp(t: np.ndarray, stops) -> np.ndarray:
    out = np.zeros(t.shape + (3,))
    for ch in range(3):
        out[..., ch] = np.interp(np.clip(t, 0, 1), [p for p, _ in stops], [_hex(c)[ch] for _, c in stops])
    return out


def _over(rgb, a, src, sa):
    k = sa[..., None]
    na = sa + a * (1 - sa)
    return (src * k + rgb * a[..., None] * (1 - k)) / np.maximum(na[..., None], 1e-6), na


def _boss(metal: dict) -> np.ndarray:
    """One boss, lit from the upper left: a soft shadow, an ink ring, a bevelled metal ring (a domed
    torus), a ring of small beads pressed into it, the cabochon (a domed stone with a hot glint)."""
    n = BOSS_CELL * BOSS_SS
    s = float(BOSS_SS)
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / s - BOSS_CELL / 2  # units, from the boss's centre
    d = np.hypot(xx, yy)
    ang = np.arctan2(yy, xx)
    light = np.array([-0.5, -0.7, 0.55])
    light /= np.linalg.norm(light)

    def cover(r: float) -> np.ndarray:
        return np.clip((r - d) * s + 0.5, 0, 1)

    rgb = np.zeros((n, n, 3))
    a = np.zeros((n, n))
    shadow = ndimage.gaussian_filter(np.clip((20.5 - np.hypot(xx, yy - 2.2)) * s, 0, 1), 1.5 * s) * 0.55
    rgb, a = _over(rgb, a, np.zeros((n, n, 3)), shadow)
    rgb, a = _over(rgb, a, np.broadcast_to(_hex(metal["ink"]), (n, n, 3)), cover(20.0))
    # the ring: a torus from radius 10.5 to 18.6, its normal from where across it a point lies
    u = np.clip((d - 10.5) / 8.1, 0, 1) * 2 - 1  # -1 inner edge, +1 outer edge
    nz = np.sqrt(np.clip(1 - u * u, 0, 1))
    nx, ny = u * np.cos(ang), u * np.sin(ang)
    diffuse = np.clip(nx * light[0] + ny * light[1] + nz * light[2], 0, 1)
    spec = np.clip(nx * 0.35 * -1 + ny * -0.5 + nz * 0.8, 0, 1) ** 24
    metal_rgb = _ramp(1 - diffuse, metal["ramp"]) + spec[..., None] * 170
    rgb, a = _over(rgb, a, metal_rgb, cover(18.6))
    # small beads pressed into the ring (the Zulu touch), each a lit dome
    for k in range(12):
        t = k * np.pi / 6 + np.pi / 12
        bx, by = np.cos(t) * 14.6, np.sin(t) * 14.6
        bd = np.hypot(xx - bx, yy - by)
        bead = np.clip((1.55 - bd) * s + 0.5, 0, 1)
        shade = np.clip(1 - np.hypot(xx - bx + 0.5, yy - by + 0.6) / 1.6, 0, 1)
        rgb, a = _over(rgb, a, _ramp(1 - shade, metal["ramp"]) * 1.05 + shade[..., None] ** 4 * 90, bead)
    # the stone: an ink ring, then a domed cabochon, lit at its top left, the light caught at its foot
    rgb, a = _over(rgb, a, np.broadcast_to(_hex(metal["ink"]), (n, n, 3)), cover(10.6))
    t = np.clip((yy + 9.0) / 18.0, 0, 1)
    stone = _ramp(t, [(0.0, metal["bead"][0]), (0.5, metal["bead"][1]), (1.0, metal["bead"][2])])
    rim_light = np.clip(1 - np.hypot(xx * 0.9, (yy - 6.2) * 1.6) / 3.2, 0, 1)
    stone = stone + rim_light[..., None] * np.array([90, 40, 20])
    rgb, a = _over(rgb, a, stone, cover(9.4))
    glint = np.clip((2.2 - np.hypot(xx + 3.2, yy + 3.6)) * s * 0.6, 0, 1)
    rgb, a = _over(rgb, a, np.full((n, n, 3), 255.0), glint * 0.95)
    small = np.clip((0.9 - np.hypot(xx - 3.4, yy - 3.0)) * s * 0.6, 0, 1)
    rgb, a = _over(rgb, a, np.full((n, n, 3), 255.0), small * 0.5)
    return np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255])


def corners() -> Image.Image:
    n = BOSS_CELL * BOSS_SS
    atlas = np.zeros((n, n * 2, 4))
    atlas[:, 0:n] = _boss(METALS["brass"])
    atlas[:, n:2 * n] = _boss(METALS["bronze"])
    return Image.fromarray(atlas.astype(np.uint8), "RGBA")


def ribbon_plain() -> Image.Image:
    """The menu's subtitle ribbon (ribbon.png, tools/art/logo.py) without its dashed stitch (it read
    as fussy): each stitch pixel takes the colour of the band a few rows nearer its middle."""
    a = np.asarray(Image.open(OUT / "ribbon.png").convert("RGBA")).astype(float)
    h = a.shape[0]
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    stitch = (r > 190) & (g > 120) & (b < 150) & (al > 150)
    stitch = ndimage.binary_dilation(stitch, iterations=1)
    out = a.copy()
    ys, xs = np.nonzero(stitch)
    for y, x in zip(ys, xs):
        src = y + 4 if y < h / 2 else y - 4  # towards the band's middle, past the stitch
        out[y, x, :3] = a[src, x, :3]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    paper().save(OUT / "paper.png", optimize=True)
    print("paper.png (256, 256)")
    ribbon_plain().save(OUT / "ribbon_plain.png", optimize=True)
    print("ribbon_plain.png")
    img = corners()
    img.save(OUT / "corners.png", optimize=True)
    print(f"corners.png {img.size}")


if __name__ == "__main__":
    main()
