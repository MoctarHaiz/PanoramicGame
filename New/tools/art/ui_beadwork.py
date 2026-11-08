#!/usr/bin/env python3
"""Zulu beadwork for the interface kit's frames (src/ui/card.gd), in the language of Panoramic's chakram
(tools/art/ring_beadwork.py): red and near-black diamonds and triangles on ivory glass beads, a little blue.

    python3 tools/art/ui_beadwork.py   # assets/art/ui/beadwork_band.png, beadwork_motifs.png

(UI r21, the judges of j17: the r20 band "dithers / moires at phone size, the most detailed thing on every panel; the
corner rosettes read as bottle caps: 2-3 larger motif blocks, softer".) So the beadwork is now calm: a plain run of
oxblood beads along the frame (close in value to the wood: it reads as an inlay, not a stripe), and on each side two or
three larger motif blocks; a small flat beaded diamond on each corner. The motifs are clean shapes (not single-bead
stairs, which read as dithering); the beads are a soft texture over them: a gentle dome per bead, a dim thread line
between beads, a broad soft light, no hot glints; muted colours.

- beadwork_band.png: the run (tiles left to right): three rows of oxblood beads in a brick stitch between two thin
  leather edges.
- beadwork_motifs.png: an atlas: the motif block (a pointed ivory cartouche, a big near-black diamond with a red heart in
  its middle, a red triangle pointing at it from each end) in the 114 x 28 units at its top left; the corner diamond
  (ivory in a dark line, a red diamond, a dark heart) in the 42 x 42 from CORNER_AT.

Painted in numpy at 4x and reduced (no aliasing). SCALE px per card unit.
"""
from pathlib import Path

import numpy as np
from PIL import Image

NEW = Path(__file__).resolve().parents[2]
OUT = NEW / "assets/art/ui"
SS = 4  # supersampling
SCALE = 3  # px per card unit (sharp on a tablet)
PITCH = 6.0  # units from one bead to the next (11 px on a phone: a texture, not a dither)
ROWS = 3
EDGE = 1.0  # units of leather along each side of the band
BAND_H = ROWS * PITCH + EDGE * 2  # 20 units
PERIOD = 16  # beads in the run's period (each bead's own shade varies a little)
BLOCK = (112.0, 26.0)  # the motif block's size (units): longer and taller than the run (over the wood a little)
BLOCK_PITCH = 6.5  # its beads (four rows)
CORNER = 40.0  # the corner diamond's side box (units)
CORNER_AT = 116.0  # its place in the atlas (units from the left)

IVORY = np.array([0.90, 0.85, 0.74])
RED = np.array([0.72, 0.18, 0.12])
DARK = np.array([0.20, 0.13, 0.11])
BLUE = np.array([0.26, 0.43, 0.70])
OXBLOOD = np.array([0.50, 0.15, 0.10])
LEATHER = np.array([0.24, 0.10, 0.05])
LINE = np.array([0.17, 0.07, 0.04])


def _grid(xx, yy, x0: float, y0: float, stagger: bool, pitch: float = PITCH):
    """Each pixel's bead (column, row) and its offset from that bead's centre (units), in a brick stitch from (x0, y0)."""
    row = np.floor((yy - y0) / pitch)
    shift = np.where((row % 2 == 1) & stagger, pitch / 2, 0.0)
    col = np.floor((xx - x0 - shift) / pitch)
    u = (xx - x0 - shift) - (col + 0.5) * pitch
    v = (yy - y0) - (row + 0.5) * pitch
    return col, row, u, v


def _beads(colour: np.ndarray, u: np.ndarray, v: np.ndarray, vary: np.ndarray, pitch: float = PITCH) -> np.ndarray:
    """Soft glass beads over a colour field: a gentle dome per bead (lit from the upper left), a dim thread line between
    them, a broad soft light; `vary`: each bead's own shade (+-)."""
    rx, ry = pitch * 0.5, pitch * 0.5
    q = np.sqrt(np.sqrt((u / rx) ** 4 + (v / ry) ** 4))  # a rounded square: beads packed side by side
    nx = np.clip(u / rx, -1, 1) * 0.7
    ny = np.clip(v / ry, -1, 1) * 0.7
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.05, 1))
    light = np.clip(-0.45 * nx - 0.6 * ny + 0.66 * nz, 0, 1)
    shade = 0.78 + 0.3 * light  # low contrast: the bead's form, not a sparkle
    gap = np.clip((q - 0.82) / 0.18, 0, 1)  # the thread between beads: dimmer, not black
    shade = shade * (1 - 0.32 * gap) * (1 + vary)
    soft = np.clip(1 - np.hypot(u + rx * 0.3, v + ry * 0.35) / (rx * 0.55), 0, 1) ** 2 * 0.12 * (1 - gap)
    return np.clip(colour * shade[..., None] + soft[..., None], 0, 1)


def _vary(col, row, seed: int) -> np.ndarray:
    h = (np.mod(col, PERIOD) * 73.0 + row * 191.0 + seed * 37.0)
    return (np.mod(np.sin(h) * 43758.5453, 1.0) - 0.5) * 0.08


def _canvas(w_units: float, h_units: float):
    n_w, n_h = int(round(w_units * SCALE)) * SS, int(round(h_units * SCALE)) * SS
    yy, xx = (np.mgrid[0:n_h, 0:n_w] + 0.5) / (SCALE * SS)  # units
    return xx, yy


def _reduce(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    h, w = alpha.shape[0] // SS, alpha.shape[1] // SS
    pre = np.dstack([rgb * alpha[..., None], alpha]).reshape(h, SS, w, SS, 4).mean(axis=(1, 3))  # premultiplied
    pre[..., :3] /= np.maximum(pre[..., 3:], 1e-6)
    return Image.fromarray((np.clip(pre, 0, 1) * 255).astype(np.uint8), "RGBA")


def band() -> Image.Image:
    xx, yy = _canvas(PERIOD * PITCH, BAND_H)
    col, row, u, v = _grid(xx, yy, 0.0, EDGE, True)
    colour = np.broadcast_to(OXBLOOD, xx.shape + (3,)).copy()
    rgb = _beads(colour, u, v, _vary(col, row, 1))
    for top in (True, False):  # the leather edges: a dark line, its outer side a little lit
        t = (yy / EDGE) if top else ((BAND_H - yy) / EDGE)
        e = t < 1.0
        leather = LEATHER * (0.8 + 0.4 * (1 - t))[..., None]
        rgb = np.where(e[..., None], leather, rgb)
    return _reduce(rgb, np.ones(xx.shape))


def _diamond(xx, yy, cx, cy, hx, hy):
    """Signed distance-ish (units, < 0 inside) to a diamond of half sizes hx, hy round (cx, cy)."""
    return (np.abs(xx - cx) / hx + np.abs(yy - cy) / hy - 1.0) * min(hx, hy) / 1.4142


def _cover(d: np.ndarray, feather: float = 0.25) -> np.ndarray:
    return np.clip(0.5 - d / feather, 0, 1)


def motifs() -> Image.Image:
    w, h = CORNER_AT + CORNER + 2.0, max(CORNER, BLOCK[1]) + 2.0
    xx, yy = _canvas(w, h)
    rgb = np.zeros(xx.shape + (3,))
    alpha = np.zeros(xx.shape)

    def over(colour, cov):
        nonlocal rgb, alpha
        k = cov[..., None]
        na = cov + alpha * (1 - cov)
        rgb = (colour * k + rgb * alpha[..., None] * (1 - k)) / np.maximum(na[..., None], 1e-6)
        alpha = na

    # the block: a pointed cartouche (its ends at 45 degrees) in a dark line, ivory beads, a big near-black diamond
    # with a red heart and an ivory eye, a red triangle pointing at it from each end, a blue bead at each point
    bw, bh = BLOCK
    cy = 1.0 + bh / 2  # (a unit of clear round it in the atlas)
    cx = 1.0 + bw / 2
    hexa = np.maximum(np.abs(yy - cy) - bh / 2, (np.abs(xx - cx) + np.abs(yy - cy)) - (bw / 2)) * 0.7071
    hexa = np.where(xx > bw + 2.0, 9.0, hexa)
    shadow = np.maximum(np.abs(yy - cy - 1.2) - bh / 2, (np.abs(xx - cx) + np.abs(yy - cy - 1.2)) - (bw / 2)) * 0.7071
    shadow = np.where(xx > bw + 2.0, 9.0, shadow)
    over(np.zeros(xx.shape + (3,)), np.clip(-shadow / 1.6 + 0.5, 0, 1) * 0.3)  # it sits on the wood
    field = np.broadcast_to(IVORY, xx.shape + (3,)).copy()
    big = _diamond(xx, yy, cx, cy, 22.0, 11.6)
    field = np.where((big < 0)[..., None], DARK, field)
    heart = _diamond(xx, yy, cx, cy, 13.5, 7.1)
    field = np.where((heart < 0)[..., None], RED, field)
    eye = _diamond(xx, yy, cx, cy, 4.6, 2.5)
    field = np.where((eye < 0)[..., None], IVORY, field)
    for side in (-1.0, 1.0):  # the triangles: base towards the cartouche's point, tip towards the middle
        bx = cx + side * 42.0
        tip = cx + side * 28.0
        k = (xx - bx) / (tip - bx)
        tri = (k >= 0) & (k <= 1) & (np.abs(yy - cy) <= (1 - k) * 8.6)
        field = np.where(tri[..., None], RED, field)
        dot = _diamond(xx, yy, cx + side * 47.5, cy, 2.6, 2.6)  # a blue bead near each point
        field = np.where((dot < 0)[..., None], BLUE, field)
    col, row, u, v = _grid(xx, yy, 1.0, 1.0, True, BLOCK_PITCH)
    beads = _beads(field, u, v, _vary(col, row, 2), BLOCK_PITCH)
    over(np.broadcast_to(LINE, xx.shape + (3,)), _cover(hexa))  # its line
    over(beads, _cover(hexa + 1.1))

    # the corner: a beaded diamond, a soft shadow under it, a dark line, ivory, a red diamond, a dark heart
    ox, oy = CORNER_AT + 1.0 + CORNER / 2, 1.0 + CORNER / 2
    r = CORNER / 2 - 1.0
    shadow = _diamond(xx, yy, ox, oy + 1.4, r + 0.6, r + 0.6)
    over(np.zeros(xx.shape + (3,)), np.clip(-shadow / 2.0, 0, 1) * 0.35)
    outer = _diamond(xx, yy, ox, oy, r, r)
    field = np.broadcast_to(IVORY, xx.shape + (3,)).copy()
    mid = _diamond(xx, yy, ox, oy, r * 0.58, r * 0.58)
    field = np.where((mid < 0)[..., None], RED, field)
    core = _diamond(xx, yy, ox, oy, r * 0.26, r * 0.26)
    field = np.where((core < 0)[..., None], DARK, field)
    # its beads on the diagonal (a diamond of beads, as it is stitched)
    rx = (xx - ox + yy - oy) * 0.7071
    ry = (yy - oy - xx + ox) * 0.7071
    col, row, u, v = _grid(rx, ry, -BLOCK_PITCH * 0.5, -BLOCK_PITCH * 0.5, False, BLOCK_PITCH)
    beads = _beads(field, u, v, _vary(col, row, 3), BLOCK_PITCH)
    over(np.broadcast_to(LINE, xx.shape + (3,)), _cover(outer))
    over(beads, _cover(outer + 1.2))
    return _reduce(rgb, alpha)


if __name__ == "__main__":
    band().save(OUT / "beadwork_band.png")
    motifs().save(OUT / "beadwork_motifs.png")
    print("wrote", OUT / "beadwork_band.png", OUT / "beadwork_motifs.png")
