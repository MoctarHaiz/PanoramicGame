#!/usr/bin/env python3
"""The ground's turf drawn toward the savanna's gold-green (2026-11-12; blind round 5: "the thin grass-and-dirt strip
under everyone reads as a pasted band": a saturated lawn green under a golden plain).

Its greens are turned toward yellow-green and a little down in saturation, each pixel's light and shade kept; the
straws, flowers and soil in the same pictures are not touched (other hues). In place; done once (a picture already
turned must not be turned again: each pass once).

    python3 tools/art/grass_gold.py greens    the blades and the mat (done 2026-11-12)
    python3 tools/art/grass_gold.py under     the teal underside of the lip and its fringe (done 2026-11-12)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from bandit_palette import hsv, rgb_of  # noqa: E402

ART = Path(__file__).resolve().parents[2] / "assets/art/world"
PICTURES = ["grass_cap", "grass_ends", "grass_drape", "tufts", "front_grass"]
## pass -> the hues it takes (degrees, from, to), the turn toward yellow, saturation x, value x
PASSES = {
    "greens": (72.0, 150.0, -24.0, 0.86, 1.0),  # the lawn green of the blades and the mat: toward gold-green
    # (blind round 8: "a lawn-green band with a sawtooth fringe: a vector platformer tile") the teal underside of the
    # turf's lip and its hanging fringe: a dry dark olive, the shade under a mat of savanna grass
    "under": (150.0, 206.0, -104.0, 0.6, 0.8),
}


def main(which: str) -> None:
    lo, hi, turn, ks, kv = PASSES[which]
    for name in PICTURES:
        path = ART / (name + ".png")
        im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
        h, s, v = hsv(im[..., :3])
        k = np.clip((h - lo) / 8.0, 0, 1) * np.clip((hi - h) / 8.0, 0, 1) * np.clip((s - 0.12) / 0.1, 0, 1)
        new = rgb_of((h + turn) % 360.0, s * ks, v * kv)
        out = im[..., :3] * (1 - k[..., None]) + new * k[..., None]
        Image.fromarray((np.dstack([out, im[..., 3]]).clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
        print("%s: %.0f%% of it turned" % (name, float((k > 0.5).sum()) / max(float((im[..., 3] > 0.5).sum()), 1.0) * 100))


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in PASSES:
        raise SystemExit("usage: grass_gold.py greens|under   (each pass once: both are done on the pictures in git)")
    main(sys.argv[1])
