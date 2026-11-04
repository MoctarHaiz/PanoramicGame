#!/usr/bin/env python3
"""Textures of the interface kit (numpy + Pillow).

    python3 tools/art/ui_kit.py      # assets/art/ui/paper.png, corners.png

- paper.png: a seamless warm paper/hide grain (256 x 256, tiles both ways), near white: the panels
  multiply their cream by it, so the body reads as a material, not a flat fill. Soft mottling, fine
  fibres running mostly across, a few darker flecks.
- corners.png: the metal brackets over the panels' corners (src/ui/card.gd): an L of bevelled metal
  following the frame's rounded corner, each arm ending in an assegai's leaf blade, a cabochon bead
  set in the bend. Two rows: brass with a red bead (every panel), iron with a slate bead (a defeat);
  two columns: the top left corner and the bottom left one (the right ones are their mirrors: lit
  from straight above, so a mirror keeps the light). Geometry in the card's units (Card.FRAME,
  Card.radius), CORNER_SS px per unit.
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


CORNER_SS = 3  # px per card unit (sharp on a tablet, where a unit is about 3 px)
CORNER_CELL = 100  # one corner's cell, in units (from 6 units outside the card's corner)
CARD_FRAME = 18.0  # Card.FRAME
CARD_RADIUS = 34.0  # Card.radius
METALS = {
    "brass": {"ramp": [(0.0, "fffbe2"), (0.22, "ffe27a"), (0.45, "f6b232"), (0.62, "dc8a16"), (0.82, "a0560a"), (1.0, "5a2804")],
              "bead": ["ff8a6a", "d0200c", "6a0804"], "ink": "2e0d04"},
    "iron": {"ramp": [(0.0, "f4f7fc"), (0.28, "c4ccda"), (0.5, "8e9ab0"), (0.75, "5c6880"), (1.0, "2e364a")],
             "bead": ["9ab4e8", "3a5290", "141e3a"], "ink": "141a2c"},
}


def _hex(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def _ramp(t: np.ndarray, stops) -> np.ndarray:
    out = np.zeros(t.shape + (3,))
    for ch in range(3):
        out[..., ch] = np.interp(np.clip(t, 0, 1), [p for p, _ in stops], [_hex(c)[ch] for _, c in stops])
    return out


def _corner_mask(n: int) -> np.ndarray:
    """The top left bracket's coverage (n x n px, from -6 units outside the corner)."""
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / CORNER_SS - 6.0  # card units, the card's corner at 0, 0
    r, c = CARD_RADIUS, CARD_RADIUS
    outer_r, inner = r + 3.0, CARD_FRAME + 3.0  # 3 units proud of the frame both sides
    mid = (inner - 3.0) / 2.0  # the band's middle line, from the card's edge
    half = (inner + 3.0) / 2.0
    # distance from the rounded corner's centre, for the bend
    d = np.hypot(np.minimum(xx - c, 0), np.minimum(yy - c, 0))
    in_outer = (xx > -3) & (yy > -3) & (d < outer_r)
    hole_r = max(r - inner, 0.0)
    hole = (xx > inner - hole_r) & (yy > inner - hole_r) & (np.hypot(np.minimum(xx - c, 0), np.minimum(yy - c, 0)) < r - inner + 0.001) \
        if hole_r > 0 else (xx > inner) & (yy > inner)
    hole |= (xx > inner) & (yy > inner) & (np.hypot(np.minimum(xx - c, 0), np.minimum(yy - c, 0)) <= hole_r + 1e-3)
    band = in_outer & ~hole
    # each arm: the band's width, then an assegai's leaf blade swelling smoothly from it, widest a
    # third of the way along, drawn to a point
    def leaf(t: np.ndarray) -> np.ndarray:
        v = np.clip((t - 50.0) / 40.0, 0, 1)
        return np.where(t > 89.5, -1.0, half * (1 + 2.2 * v) * (1 - v) ** 0.9)
    top_arm = (xx >= c) & (np.abs(yy - mid) < leaf(xx)) & (yy > -3)
    left_arm = (yy >= c) & (np.abs(xx - mid) < leaf(yy)) & (xx > -3)
    bend = (xx < c) & (yy < c) & band
    mask = (top_arm | left_arm | bend).astype(float)
    return ndimage.gaussian_filter(mask, 0.6)


def _corner(mask: np.ndarray, metal: dict, bottom: bool) -> np.ndarray:
    """One bracket lit from straight above (`bottom`: the bottom left one, its mask already flipped): a
    rounded bevel, the ink outline, a soft shadow, the bead in the bend."""
    n = mask.shape[0]
    s = float(CORNER_SS)
    inside = ndimage.distance_transform_edt(mask > 0.5) / s
    bevel = 3.6
    h = np.sqrt(1 - (1 - np.minimum(inside, bevel) / bevel) ** 2) * bevel * 1.4
    h = ndimage.gaussian_filter(h, 1.0)
    gy, gx = np.gradient(h * s)
    nrm = np.dstack([-gx / s, -gy / s, np.ones_like(h)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    light = np.array([0.0, -0.75, 0.66])
    light /= np.linalg.norm(light)
    diffuse = np.clip(nrm @ light, 0, 1)
    halfv = light + np.array([0, 0, 1.0])
    halfv /= np.linalg.norm(halfv)
    spec = np.clip(nrm @ halfv, 0, 1) ** 30
    yy = (np.mgrid[0:n, 0:n][0] + 0.5) / s
    flat = light[2]  # the diffuse light of the flat top
    t = np.clip(0.52 + (flat - diffuse) * 1.5 + 0.1 * (yy / CORNER_CELL - 0.3), 0, 1)
    rgb = _ramp(t, metal["ramp"]) + spec[..., None] * 160
    ink = _hex(metal["ink"])
    out_mask = np.clip(2.0 * s + 0.5 - ndimage.distance_transform_edt(mask < 0.5), 0, 1)
    shadow = ndimage.gaussian_filter(ndimage.shift(out_mask, (2.5 * s, 0)), 1.6 * s) * 0.5
    # the bead in the bend, on the band's middle
    yy2, xx2 = (np.mgrid[0:n, 0:n] + 0.5) / s - 6.0
    # the band's middle in the bend: between the outer radius (r + 3) and the hole's (r - frame - 3)
    along = CARD_RADIUS - (CARD_RADIUS + 3.0 + max(CARD_RADIUS - CARD_FRAME - 3.0, 0.0)) / 2.0 / np.sqrt(2)
    bc = np.array([along, CORNER_CELL - 12.0 - along if bottom else along])
    br = 9.0
    dist = np.hypot(xx2 - bc[0], yy2 - bc[1])
    ring = np.clip((br + 1.6 - dist) * s, 0, 1)
    bead = np.clip((br - dist) * s, 0, 1)
    t = np.clip((yy2 - (bc[1] - br)) / (2 * br), 0, 1)
    bead_rgb = _ramp(t, [(0.0, metal["bead"][0]), (0.55, metal["bead"][1]), (1.0, metal["bead"][2])])
    glint = np.clip((2.6 - np.hypot(xx2 - bc[0] + 2.6, yy2 - bc[1] + 3.2)) * s * 0.5, 0, 1)
    # compose: shadow, ink outline, metal, bead ring, bead, glint
    out_rgb = np.zeros((n, n, 3))
    out_a = np.zeros((n, n))
    for lr, la in ((np.zeros((n, n, 3)), shadow), (np.broadcast_to(ink, (n, n, 3)), out_mask), (rgb, mask),
                   (np.broadcast_to(ink, (n, n, 3)), ring), (bead_rgb, bead),
                   (np.full((n, n, 3), 255.0), glint * 0.9)):
        a = la[..., None]
        new_a = la + out_a * (1 - la)
        out_rgb = (lr * a + out_rgb * out_a[..., None] * (1 - a)) / np.maximum(new_a[..., None], 1e-6)
        out_a = new_a
    return np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a, 0, 1) * 255])


def corners() -> Image.Image:
    n = CORNER_CELL * CORNER_SS
    mask = _corner_mask(n)
    atlas = np.zeros((n * 2, n * 2, 4))
    for row, name in enumerate(("brass", "iron")):
        atlas[row * n:(row + 1) * n, 0:n] = _corner(mask, METALS[name], False)  # top left
        atlas[row * n:(row + 1) * n, n:2 * n] = _corner(mask[::-1], METALS[name], True)  # bottom left, lit from above too
    return Image.fromarray(atlas.astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    paper().save(OUT / "paper.png", optimize=True)
    print("paper.png (256, 256)")
    img = corners()
    img.save(OUT / "corners.png", optimize=True)
    print(f"corners.png {img.size}")


if __name__ == "__main__":
    main()
