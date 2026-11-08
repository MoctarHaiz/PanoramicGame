#!/usr/bin/env python3
"""(round 23) Measures on the hero's atlas (hero_frames.json and its pages) what HeroView draws at his contacts and adds
it to each frame of hero_frames.json:
- "soles": the bottom of each boot (or what lies lowest: his back when he is down), [x from, x to, y] in the frame's px,
  the lowest two: HeroView's contact occlusion touches each sole, as dark as the sole is near the ground (the judges,
  j19: "a floating dark oval under him");
- "fists" (hanging and catching the vine): the middle of each fist, [x, y] in the frame's px, left to right: HeroView
  hangs him with the vine through his fists and draws its front strand over his fingers (j19: "his hand sits on top of
  the vine, not wrapped").

    python3 tools/art/hero_contacts.py [DIR]   # default assets/art/hero; hero_atlas_ai.py runs it after build()
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[2]
BOOT = 26  # atlas px: the band at the bottom of the figure a boot's sole is looked for in
FIST = 26  # atlas px: the band at the top of the figure (hanging) a fist is in
MIN_PX = 40  # a piece smaller than this is a scrap (a scarf's tip), not a boot


def soles(a):
    al = a > 128
    ys = np.nonzero(al.any(1))[0]
    if not len(ys):
        return []
    bottom = ys.max()
    band = al.copy()
    band[: max(bottom - BOOT, 0)] = False
    lab, n = ndi.label(band)
    out = []
    for i in range(1, n + 1):
        py, px = np.nonzero(lab == i)
        if len(py) < MIN_PX:
            continue
        low = py.max()
        xs = px[py >= low - 3]
        out.append([float(xs.min()), float(xs.max() + 1), float(low + 1)])
    out.sort(key=lambda s: -s[2])
    return out[:2]


def fists(a):
    al = a > 128
    ys = np.nonzero(al.any(1))[0]
    top = ys.min()
    band = al.copy()
    band[top + FIST:] = False
    lab, n = ndi.label(band)
    pieces = []
    for i in range(1, n + 1):
        py, px = np.nonzero(lab == i)
        if len(py) < MIN_PX:
            continue
        top_i = py.min()
        sel = py <= top_i + 18  # the fist: the top of the arm
        pieces.append((len(py), [float(px[sel].mean()), float(top_i + 9)]))
    pieces.sort(key=lambda p: -p[0])
    return sorted([p[1] for p in pieces[:2]], key=lambda p: p[0])


def main(folder):
    data = json.loads((folder / "hero_frames.json").read_text())
    pages = [np.asarray(Image.open(folder / p).convert("RGBA"))[..., 3] for p in data["pages"]]
    for anim, entry in data["anims"].items():
        for f in entry["frames"]:
            x, y, w, h = f["region"]
            a = pages[f["page"]][y:y + h, x:x + w]
            f["soles"] = [[round(v, 1) for v in s] for s in soles(a)]
            if anim in ("hang", "catch"):
                f["fists"] = [[round(v, 1) for v in p] for p in fists(a)]
    (folder / "hero_frames.json").write_text(json.dumps(data, separators=(",", ":")))
    print("soles and fists measured:", sum(len(e["frames"]) for e in data["anims"].values()), "frames")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else NEW / "assets/art/hero")
