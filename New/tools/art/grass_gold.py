#!/usr/bin/env python3
"""The ground's turf drawn toward the savanna's gold-green (2026-11-12; blind round 5: "the thin grass-and-dirt strip
under everyone reads as a pasted band": a saturated lawn green under a golden plain).

Its greens are turned toward yellow-green and a little down in saturation, each pixel's light and shade kept; the
straws, flowers and soil in the same pictures are not touched (other hues). In place; done once (a picture already
turned has no pure green left to turn).

    python3 tools/art/grass_gold.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from bandit_palette import hsv, rgb_of  # noqa: E402

ART = Path(__file__).resolve().parents[2] / "assets/art/world"
PICTURES = ["grass_cap", "grass_ends", "grass_drape", "tufts", "front_grass"]
FROM, TO = 72.0, 150.0  # the greens' hues (degrees)
TURN = -24.0  # degrees toward yellow
SAT = 0.86


def main() -> None:
    for name in PICTURES:
        path = ART / (name + ".png")
        im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
        h, s, v = hsv(im[..., :3])
        k = np.clip((h - FROM) / 8.0, 0, 1) * np.clip((TO - h) / 8.0, 0, 1) * np.clip((s - 0.12) / 0.1, 0, 1)
        new = rgb_of((h + TURN) % 360.0, s * SAT, v)
        out = im[..., :3] * (1 - k[..., None]) + new * k[..., None]
        Image.fromarray((np.dstack([out, im[..., 3]]).clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
        print("%s: %.0f%% of it turned" % (name, float((k > 0.5).sum()) / max(float((im[..., 3] > 0.5).sum()), 1.0) * 100))


if __name__ == "__main__":
    main()
