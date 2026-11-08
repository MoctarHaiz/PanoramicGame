#!/usr/bin/env python3
"""(round 20, the judges: "the panels a generic casual kit with stock diamond studs, no game identity") Zulu beadwork for
the interface kit, in the language of Panoramic's chakram (tools/art/ring_beadwork.py): red and black triangles on white
glass beads, a blue bead at the foot of each white one (his armour's blue).

    python3 tools/art/ui_beadwork.py   # assets/art/ui/beadwork_band.png, bead_rosette.png

- beadwork_band.png: a band of seed beads in a square stitch, three rows, triangles standing on its lower (inner) edge,
  red and black in turn, white between; a leather edging along both sides. It tiles left to right (12 beads a period).
  Card draws it along the middle of its wooden frame, the triangles pointing out.
- bead_rosette.png: a beaded medallion for a panel's corner (where the bands meet): a red centre bead, a ring of white,
  a ring of red and black in turn, a ring of white with blue, on a leather disc in an ink ring.

Painted in numpy at 4x and reduced (no aliasing). SCALE px per card unit.
"""
from pathlib import Path

import numpy as np
from PIL import Image

NEW = Path(__file__).resolve().parents[2]
OUT = NEW / "assets/art/ui"
SS = 4  # supersampling
SCALE = 3  # px per card unit (sharp on a tablet, where a unit is about 3 px)
PITCH = 14  # px from one bead to the next (4.7 units: each bead reads on a phone)
ROWS = 3
PERIOD = 12  # beads: a red triangle and a black one
EDGE = 3  # px of leather along each side of the band

WHITE = np.array([0.96, 0.93, 0.86])
RED = np.array([0.82, 0.13, 0.10])
BLACK = np.array([0.13, 0.10, 0.11])
BLUE = np.array([0.16, 0.40, 0.82])
GOLD = np.array([0.99, 0.76, 0.20])
THREAD = np.array([0.17, 0.07, 0.03])
LEATHER = np.array([0.30, 0.12, 0.04])
INK = np.array([0.18, 0.05, 0.02])
LIGHT = np.array([-0.45, -0.75, 0.5]) / np.linalg.norm([-0.45, -0.75, 0.5])


def _bead(colour: np.ndarray, u: np.ndarray, v: np.ndarray, rx: float, ry: float):
    """A glass seed bead (a rounded pillow `rx` x `ry` px round its centre; u, v px from it), lit from the upper left:
    its colour shaded by its dome, a hot glint, a darker foot. Returns (rgb, coverage)."""
    q = np.sqrt((u / rx) ** 4 + (v / ry) ** 4) ** 0.5  # a superellipse: rounder than a box, squarer than a disc
    cover = np.clip((1.0 - q) * min(rx, ry) * 1.2, 0, 1)
    nx = np.clip(u / rx, -1, 1) * 0.85
    ny = np.clip(v / ry, -1, 1) * 0.85
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.05, 1))
    diffuse = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    spec = np.clip((nx * -0.35 + ny * -0.6 + nz * 0.72), 0, 1) ** 30
    dark = colour.mean() < 0.3
    col = colour * (0.45 + 0.7 * diffuse[..., None]) + spec[..., None] * (0.75 if dark else 0.55)
    col += (1 - diffuse[..., None]) * 0.04 * colour  # a little light through the glass
    return np.clip(col, 0, 1), cover


def band() -> Image.Image:
    w, h = PERIOD * PITCH, ROWS * PITCH + EDGE * 2
    n_w, n_h = w * SS, h * SS
    yy, xx = (np.mgrid[0:n_h, 0:n_w] + 0.5) / SS  # px
    rgb = np.zeros((n_h, n_w, 3))
    rgb[:] = THREAD
    alpha = np.ones((n_h, n_w))
    # the beads: row r (0 at the top, the outer edge), column c
    by = yy - EDGE
    row = np.clip(np.floor(by / PITCH).astype(int), 0, ROWS - 1)
    col = np.floor(xx / PITCH).astype(int) % PERIOD
    u = (xx % PITCH) - PITCH / 2
    v = (by - row * PITCH) - PITCH / 2
    # triangles standing on the bottom row (the inner edge), their tips at the top: a red one centred on column 3,
    # a black one on column 9; white between, a blue bead where a white wedge meets the outer edge
    colour = np.zeros((n_h, n_w, 3))
    colour[:] = WHITE
    for centre, c in ((3, RED), (9, BLACK)):
        d = np.abs(col - centre)
        inside = d <= row  # row 0: its tip; row 2: 5 beads wide
        colour[inside] = c
    tip = (row == 0) & ((col == 0) | (col == 6))
    colour[tip] = BLUE
    bead_rgb, cover = _bead(colour, u, v, PITCH * 0.47, PITCH * 0.44)
    inside_band = (by >= 0) & (by < ROWS * PITCH)
    k = (cover * inside_band)[..., None]
    rgb = rgb * (1 - k) + bead_rgb * k
    # the leather edging: a lit lip on its top, darker below
    for top in (True, False):
        e = (yy < EDGE) if top else (yy >= h - EDGE)
        t = (yy / EDGE) if top else ((yy - (h - EDGE)) / EDGE)
        leather = LEATHER * (1.25 - 0.5 * t)[..., None]
        rgb = np.where(e[..., None], leather, rgb)
    img = np.dstack([rgb, alpha])
    img = img.reshape(h, SS, w, SS, 4).mean(axis=(1, 3))
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA")


def rosette(units: float = 46.0) -> Image.Image:
    n = int(units * SCALE)
    m = n * SS
    yy, xx = (np.mgrid[0:m, 0:m] + 0.5) / SS - n / 2  # px from the centre
    d = np.hypot(xx, yy)
    ang = np.arctan2(yy, xx)
    r_out = n / 2 - 1.5
    rgb = np.zeros((m, m, 3))
    a = np.zeros((m, m))

    def over(src, cov):
        nonlocal rgb, a
        k = cov[..., None]
        na = cov + a * (1 - cov)
        rgb = (src * k + rgb * a[..., None] * (1 - k)) / np.maximum(na[..., None], 1e-6)
        a = na

    # a soft shadow under it, the ink ring, the leather disc (lit at its top left)
    shadow = np.clip((r_out - np.hypot(xx, yy - 4.0)) / 6.0, 0, 1) * 0.5
    over(np.zeros((m, m, 3)), shadow)
    over(np.broadcast_to(INK, (m, m, 3)), np.clip((r_out - d) * SS / SS + 0.5, 0, 1))
    shade = np.clip(0.75 - (xx + yy) / (n * 1.4), 0.35, 1.0)
    over(LEATHER * shade[..., None] * 1.1, np.clip((r_out - 3.0 - d) + 0.5, 0, 1))
    # rings of beads packed close (each touching the next), from the rim in: (radius px, colours in turn)
    pitch = 16.5
    rings = [
        (r_out - 11.5, [WHITE, BLUE]),
        (r_out - 11.5 - pitch, [RED, BLACK]),
        (r_out - 11.5 - pitch * 2, [WHITE]),
    ]
    for radius, colours in rings:
        count = int(round(2 * np.pi * radius / pitch / len(colours))) * len(colours)
        br = min(np.pi * radius / count, pitch / 2) * 0.9
        for k in range(count):
            t = k * 2 * np.pi / count - np.pi / 2
            bx, by = np.cos(t) * radius, np.sin(t) * radius
            col, cov = _bead(colours[k % len(colours)], xx - bx, yy - by, br, br)
            over(col, cov)
    # the centre: a big red bead in a ring of ink
    over(np.broadcast_to(INK, (m, m, 3)), np.clip((11.0 - d) + 0.5, 0, 1))
    col, cov = _bead(RED, xx, yy, 9.6, 9.6)
    over(col, cov)
    img = np.dstack([rgb * a[..., None], a]).reshape(n, SS, n, SS, 4).mean(axis=(1, 3))  # premultiplied: no dark fringe
    img[..., :3] /= np.maximum(img[..., 3:], 1e-6)
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    band().save(OUT / "beadwork_band.png")
    rosette().save(OUT / "bead_rosette.png")
    print("wrote", OUT / "beadwork_band.png", OUT / "bead_rosette.png")
