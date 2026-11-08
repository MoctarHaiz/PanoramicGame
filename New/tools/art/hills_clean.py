#!/usr/bin/env python3
"""Round 23 (the judges, j19: "the midground acacias are one dark stamp repeated in rows"): the far savanna strip
mid_hills.png carried a row of small dark acacias and bushes painted along its crest, the same ones every 1760 px.
They are taken off here (the hill's crest cleaned, the dark feet of the bushes painted over in the grass's colour under
them); the acacias of the plain are SavannaView's tree rows instead, each its own picture, size, shape, side and lean,
in groves with open plain between.

Run once on the painted strip (it reads the dark crowns). Rewrites assets/art/world/mid_hills.png in place.

    python3 tools/art/hills_clean.py [--sheet out.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

WORLD = Path(__file__).resolve().parents[2] / "assets/art/world"


def main() -> None:
    path = WORLD / "mid_hills.png"
    img = np.array(Image.open(path).convert("RGBA")).astype(float)
    h, w = img.shape[:2]
    rgb = img[..., :3] / 255.0
    a = img[..., 3] / 255.0
    value = rgb.max(axis=-1)
    hill = (a > 0.5) & (value > 0.62) & (rgb[..., 0] > rgb[..., 2] + 0.15)
    hill[:-3] &= hill[1:-2] & hill[2:-1] & hill[3:]  # (four lit rows running: a lit leaf in a crown is no crest)
    # each column's first row of the hill's lit grass, then the crest smoothed along the strip (a bush's foot dipped it)
    first = np.where(hill.any(axis=0), hill.argmax(axis=0), h // 3)
    wrap = np.concatenate([first[-80:], first, first[:80]])  # (the strip repeats: smoothed across its seam)
    crest = ndimage.median_filter(wrap, 81)[80:-80]
    crest = ndimage.gaussian_filter1d(np.concatenate([crest[-40:], crest, crest[:40]]).astype(float), 6.0)[40:-40]
    crest = np.minimum(crest, first + 1.0)
    out = img.copy()
    ys = np.arange(h)
    for x in range(w):
        c = crest[x]
        # above the crest: open sky, with a one-pixel soft edge
        edge = np.clip(ys - c + 0.5, 0.0, 1.0)
        out[:, x, 3] = np.minimum(img[:, x, 3], edge * 255.0)
        # under it, down to the grass's first lit row: the dark feet of the bushes painted over in the grass below
        f = int(first[x])
        if f > c + 0.5:
            src = img[min(f + 2, h - 1), x, :3]
            for y in range(int(np.floor(c)), f + 2):
                if value[y, x] < 0.66:
                    out[y, x, :3] = src
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
    print(f"{path.name}: crest from {crest.min():.0f} to {crest.max():.0f} px")
    if "--sheet" in sys.argv:
        sheet = Path(sys.argv[sys.argv.index("--sheet") + 1])
        bg = Image.new("RGBA", (w, h), (150, 170, 210, 255))
        bg.alpha_composite(Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA"))
        bg.convert("RGB").save(sheet)


if __name__ == "__main__":
    main()
