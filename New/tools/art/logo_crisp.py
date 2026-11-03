#!/usr/bin/env python3
"""The Haiz Studio logo, crisp (the same design: the user hasn't asked for a new one): the upscaled
2017 picture (tools/art/studio_logo.py) had soft, waxy shading in its flat colours. Each pixel is
sorted into the logo's own flat colours, each colour's shape is smoothed and redrawn with clean
anti-aliased edges at twice the size, then reduced.

    python3 tools/art/logo_crisp.py [SOURCE_PNG]   # default: the picture made by studio_logo.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else NEW / "tools/art/gen/haiz_studio_upscaled.png"
OUT = NEW / "assets/art/haiz_studio.png"
# the logo's colours (measured: k-means on the 2017 picture), in drawing order
PALETTE = [
    ("frame", (61, 62, 50)),
    ("lettering", (190, 205, 14)),
    ("orange", (255, 120, 0)),
    ("alien", (1, 0, 0)),
    ("studio", (129, 134, 77)),
    ("studio_edge", (245, 217, 2)),
]


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    w, h = src.size
    big = np.asarray(src.resize((w * 2, h * 2), Image.LANCZOS)).astype(np.float32)
    big = ndimage.median_filter(big, size=(5, 5, 1))
    rgb, alpha = big[..., :3], big[..., 3] / 255.0
    cols = np.array([c for _, c in PALETTE], np.float32)
    dist = ((rgb[..., None, :] - cols[None, None]) ** 2).sum(-1)
    label = np.argmin(dist, -1)
    label[alpha < 0.5] = -1
    out = np.zeros((h * 2, w * 2, 4), np.float32)
    for i, (_, colour) in enumerate(PALETTE):
        soft = ndimage.gaussian_filter((label == i).astype(np.float32), 1.6)
        a = np.clip((soft - 0.35) / 0.3, 0.0, 1.0)  # a clean edge, 2 px of anti-aliasing at 2x
        a = a * a * (3 - 2 * a)
        c = np.array(colour, np.float32) / 255.0
        out[..., :3] = out[..., :3] * (1 - a[..., None]) + c * a[..., None]
        out[..., 3] = out[..., 3] * (1 - a) + a
    rgb = np.where(out[..., 3:4] > 1e-4, out[..., :3], 0)
    img = Image.fromarray((np.dstack([rgb, out[..., 3:4]]) * 255 + 0.5).astype(np.uint8), "RGBA")
    img.resize((w, h), Image.LANCZOS).save(OUT, optimize=True)
    print("haiz_studio.png", w, h)


if __name__ == "__main__":
    main()
