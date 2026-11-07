#!/usr/bin/env python3
"""Hands the painted death to the game's packer (New/tools/art/hero_atlas.py): the frames flipped
left-right (the game shows this death mirrored: knocked back to the left, as its old "other_side" render
did), renamed 000.png..., and points.json with every x mirrored.

    python3 game_export.py RENDER_DIR OUT_DIR    # RENDER_DIR/paint/*.png + RENDER_DIR/points.json -> OUT_DIR/*.png + points.json
"""
import json
import os
import sys

from PIL import Image, ImageOps

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    if f.endswith(".png"):
        os.remove(os.path.join(out, f))
pts = json.load(open(os.path.join(src, "points.json")))
size = pts["size"]
names = sorted(f for f in os.listdir(os.path.join(src, "paint")) if f.endswith(".png"))
assert len(names) == len(pts["frames"]), (len(names), len(pts["frames"]))
for i, n in enumerate(names):
    ImageOps.mirror(Image.open(os.path.join(src, "paint", n))).save(os.path.join(out, f"{i:03d}.png"))
flip = lambda p: [round(size - p[0], 2), p[1]]  # noqa: E731
json.dump({
    "view": "other_side", "size": size, "origin": flip(pts["origin"]),
    "frames": [{k: flip(v) for k, v in fr.items()} for fr in pts["frames"]],
    "source": "Making/Animation.blend 4_Die (mixamo.com.003) through Cam_Side, painted by Making/DieSide_sprites, mirrored",
    "source_frames": pts.get("source_frames"),
}, open(os.path.join(out, "points.json"), "w"), indent=1)
print(len(names), "frames ->", out)
