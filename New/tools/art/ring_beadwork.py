#!/usr/bin/env python3
"""(round 19) Panoramic's chakram in play (assets/art/fx/ring_spin.png, RingView): a blue-steel ring whose face carries a
band of Zulu beadwork, red and black triangles on white (the judges: the old emblem "reads as a brand logo"; the end
screens' victory still carries the same band). 8 frames of a half turn about its upright axis, side by side, 96 px each
(the frame RingView draws 40 units across): face-on, turning, edge-on (its steel rim), then its other face.

Painted in numpy at 4x and reduced (no aliasing on the triangles): each frame is the ring as a flat disc with a hole
and a thickness, turned by the frame's angle, drawn back to front (the far face, the rim's slices, the near face).

    python3 tools/art/ring_beadwork.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

NEW = Path(__file__).resolve().parents[2]
OUT = NEW / "assets/art/fx/ring_spin.png"
FRAMES, PX, SS = 8, 96, 4
R_OUT, R_IN = 0.88, 0.58  # the ring's edge and its hole, in shares of half the frame
RIM = 0.8  # the steel rim outside the beadwork
BEAD_IN = 0.66  # the beadwork band: BEAD_IN .. RIM
TRIANGLES = 14  # beadwork triangles round the band, each red or black in turn
THICK = 0.14  # the ring's thickness, in shares of half the frame
INK = np.array([0.08, 0.035, 0.05])
NAVY = np.array([0.04, 0.17, 0.36])
STEEL = np.array([0.6, 0.76, 0.9])
WHITE = np.array([0.95, 0.92, 0.85])
RED = np.array([0.78, 0.12, 0.12])
BLACK = np.array([0.1, 0.07, 0.08])
SIDE = np.array([0.1, 0.3, 0.58])


def face(rho, phi, lit):
    """The colour of the ring's face at polar (rho, phi), and whether it is there."""
    col = np.zeros(rho.shape + (3,))
    on = (rho >= R_IN) & (rho <= R_OUT)
    # the steel rim: deep navy with a lighter band towards the upper left
    shine = 0.5 + 0.5 * np.cos(phi - np.radians(225))
    rim = NAVY + (STEEL - NAVY) * (0.18 + 0.3 * shine ** 3)[..., None]
    col[:] = rim
    # the inner lip: light steel
    lip = (rho < BEAD_IN)
    col[lip] = (STEEL * (0.8 + 0.2 * shine[..., None]))[lip]
    # the beadwork: triangles standing on the band's inner edge, red and black in turn, white between
    band = (rho >= BEAD_IN) & (rho <= RIM)
    u = (phi / (2 * np.pi) * TRIANGLES) % 1.0  # across a triangle's sector
    k = np.floor(phi / (2 * np.pi) * TRIANGLES).astype(int) % 2
    v = (rho - BEAD_IN) / (RIM - BEAD_IN)  # 0 at the base, 1 at the apex
    tri = np.abs(u - 0.5) * 2.0 < (1.0 - v) * 0.92
    bead = np.where(tri[..., None], np.where((k == 0)[..., None], RED, BLACK), WHITE)
    col[band] = bead[band]
    # thin ink rings between the zones and at the edges (a drawn ring, like the world's props)
    d = np.minimum.reduce([np.abs(rho - R_OUT), np.abs(rho - R_IN), np.abs(rho - RIM), np.abs(rho - BEAD_IN)])
    ink = np.clip(1.0 - d / 0.022, 0, 1)
    col = col * (1 - ink[..., None]) + INK * ink[..., None]
    return col * lit, on


def frame(theta):
    n = PX * SS
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / (n / 2) - 1.0
    c, s = np.cos(theta), np.sin(theta)
    cc = c if abs(c) > 0.03 else 0.03 * (1 if c >= 0 else -1)
    rgb = np.zeros((n, n, 3))
    alpha = np.zeros((n, n))
    near = THICK / 2 if c >= 0 else -THICK / 2  # the face turned towards us
    slices = np.linspace(-near, near, 24)  # far face first
    for i, depth in enumerate(slices):
        X = (xx - depth * s) / cc
        rho = np.hypot(X, yy)
        phi = np.arctan2(yy, X)
        if i == len(slices) - 1 or i == 0:  # a face
            lit = 0.72 + 0.28 * abs(c)
            col, on = face(rho, phi if c >= 0 else np.pi - phi, lit)
        else:  # the rim between the faces: the outer band lit from the left, the hole's wall darker
            on = (rho >= R_IN) & (rho <= R_OUT)
            outer = rho > (R_IN + R_OUT) / 2
            shade = np.where(outer, 0.75 + 0.35 * np.clip(-xx, 0, 1), 0.55)
            col = SIDE * shade[..., None]
            edge = np.clip(1.0 - np.minimum(np.abs(rho - R_OUT), np.abs(rho - R_IN)) / 0.016, 0, 1)
            col = col * (1 - edge[..., None]) + INK * edge[..., None]
        rgb[on] = col[on]
        alpha[on] = 1.0
    img = np.dstack([rgb, alpha])
    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    # reduced premultiplied (no dark fringe), then back to straight alpha
    a = np.asarray(im).astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    ch = [np.asarray(Image.fromarray(pm[..., k]).resize((PX, PX), Image.BOX)) for k in range(4)]
    r = np.clip(np.dstack(ch), 0, 1)
    al = r[..., 3:4]
    r[..., :3] = np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), INK)
    return r


def main():
    strip = np.concatenate([frame(f * np.pi / FRAMES) for f in range(FRAMES)], 1)
    Image.fromarray((strip * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print(OUT.name, strip.shape[1], strip.shape[0])


if __name__ == "__main__":
    main()
