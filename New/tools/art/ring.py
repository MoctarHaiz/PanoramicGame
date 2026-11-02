#!/usr/bin/env python3
"""Panoramic's throwing ring, painted in numpy (assets/art/fx/ring.png): a thick glowing torus of
blue light, as on the hero sheet. The tube is shaded as a solid lit from the upper left (deep navy
in its shadow, the ring's blue #3fa2ff in the light, cyan and a white-hot specular on top), with a
pale core of light inside the hole. 128 px for a ring 40 units across (src/game/ring_view.gd turns
it as it flies and adds the glow and the streak).

    python3 tools/art/ring.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from paint import ROOT, dither_rgba, ramp, smooth  # noqa: E402

SIZE = 128


def ring():
    s = SIZE
    yy, xx = np.mgrid[0:s, 0:s].astype(float) + 0.5
    dx, dy = (xx - s / 2) / (s / 2), (yy - s / 2) / (s / 2)
    r = np.hypot(dx, dy)
    centre, tube = 0.7, 0.24  # the tube's middle and half thickness, in shares of the radius
    t = np.clip((r - centre) / tube, -1, 1)  # across the tube: -1 inner edge, 1 outer edge
    inside = np.abs((r - centre) / tube) <= 1.0
    nz = np.sqrt(np.clip(1 - t * t, 0, 1))
    ux, uy = dx / np.maximum(r, 1e-4), dy / np.maximum(r, 1e-4)
    n = np.dstack([ux * t, uy * t, nz])
    light = np.array([-0.5, -0.62, 0.6])
    light /= np.linalg.norm(light)
    lam = np.clip(n @ light, 0, 1)
    spec = np.clip(n @ (light + np.array([0, 0, 1.0])) / np.linalg.norm(light + np.array([0, 0, 1.0])), 0, 1) ** 40
    col = ramp(np.clip(lam * 1.05, 0, 1), [(0.0, "0b2050"), (0.3, "1d5cc0"), (0.6, "3fa2ff"), (0.85, "8fd8ff"), (1.0, "e6f8ff")])
    col = col + (np.array([255, 255, 255]) - col) * (spec * 0.95)[..., None]
    # a fine energy band running round the middle of the tube
    band = np.exp(-(t / 0.18) ** 2) * (0.5 + 0.5 * np.cos(np.arctan2(dy, dx) * 9.0))
    col = col + (np.array([200, 240, 255]) - col) * (band * 0.25)[..., None]
    edge = smooth(1.0, 0.92, np.abs((r - centre) / tube))  # anti-aliased tube edge
    alpha = edge * inside + (1 - inside) * 0.0
    # the light in the hole: a pale glow, strongest at the tube's inner edge
    hole = (r < centre - tube) * np.exp(-((centre - tube - r) / 0.12) ** 2) * 0.55
    col = np.where((alpha > 0.01)[..., None], col, np.array([170.0, 225.0, 255.0]))
    alpha = np.maximum(alpha, hole)
    return dither_rgba(np.clip(col, 0, 255), np.clip(alpha, 0, 1))


def main() -> None:
    out = ROOT / "assets/art/fx"
    out.mkdir(parents=True, exist_ok=True)
    ring().save(out / "ring.png", optimize=True)
    print("ring written")


if __name__ == "__main__":
    main()
