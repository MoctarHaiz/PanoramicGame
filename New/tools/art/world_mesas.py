#!/usr/bin/env python3
"""Round 20 (the judges, j16: "the same mesa shape x4 with no atmospheric layering"): the escarpments on the
horizon (the world redraw's painted strip, kept as tools/art/ref/far_mesas_strip.png) cut into its five landforms, each cut in a valley
of the strip with its sides fading out, so the level can place them one by one (src/game/savanna_view.gd):
in two rows, the far one smaller, paler and cooler, the near one bigger, warmer and darker, each piece its
own scale, the order never repeating a piece next to itself.

  far_mesa_pieces.png   the five pieces side by side (4 px apart), 1 px per unit as the strip
  far_mesa_pieces.json  {"pieces": [[x, width], ...]} in px of the picture, "height"

    python3 tools/art/world_mesas.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

WORLD = Path(__file__).resolve().parents[2] / "assets/art/world"
# px ranges of the strip, each cut in a valley between two landforms (a butte, the tall butte, the mesa,
# the twin spires, the long stepped plateau)
CUTS = [(112, 348), (296, 566), (556, 1000), (972, 1128), (1108, 1760)]
FADE = 34  # px over which each side fades out


def main() -> None:
    strip = np.asarray(Image.open(Path(__file__).parent / "ref/far_mesas_strip.png").convert("RGBA")).astype(float)
    h = strip.shape[0]
    parts = []
    rects = []
    x = 0
    for a, b in CUTS:
        p = strip[:, a:b].copy()
        w = b - a
        u = np.arange(w, dtype=float)
        side = np.minimum(u, w - 1 - u)
        k = np.clip(side / FADE, 0, 1)
        k = k * k * (3 - 2 * k)
        p[..., 3] *= k[None, :]
        parts.append(p)
        parts.append(np.zeros((h, 4, 4)))
        rects.append([x, w])
        x += w + 4
    img = np.concatenate(parts, axis=1)
    Image.fromarray(np.clip(img, 0, 255).round().astype(np.uint8), "RGBA").save(WORLD / "far_mesa_pieces.png", optimize=True)
    (WORLD / "far_mesa_pieces.json").write_text(json.dumps({"pieces": rects, "height": h}))
    print("far_mesa_pieces written:", rects)


if __name__ == "__main__":
    main()
