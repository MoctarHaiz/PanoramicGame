#!/usr/bin/env python3
"""Packs the painted death frames (tools/toon_paint.py) into game sprites.

Each frame is reduced to the 1024 render scale (premultiplied, so edges stay clean), all are cropped to
one shared box (their union, so the animation stays registered), then written to OUT:

    frames/die_00.png ... die_19.png   transparent, same size, registered
    die_sheet.png / die_sheet_half.png the frames in a 5x4 grid, full and half size (half = the game's atlas scale)
    die_sheet.json                     frame size, grid, fps, pivot (the ground under his hips), source frames
    die_preview.gif                    the animation at 12 fps on the game's sky, the last frame held
    compare.png                        the video frame above, the sprite below

    python3 pack_frames.py PAINT_DIR OUT_DIR
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
CLEAN = os.path.join(HERE, "..", "work", "clean")  # the video's frames, overlays removed
FPS = 12.0
COLS, ROWS = 5, 4
GROUND_Y, ORIGIN_X = 858.5, 501.0  # at 1024: the ground line and the hero's origin (the video's 3D cursor)
MARGIN = 6
SKY = (120, 160, 200, 255)


def premultiplied_resize(img, size):
    a = np.asarray(img.convert("RGBA"), np.float32) / 255.0
    al = a[..., 3]
    ch = [Image.fromarray(a[..., i] * al) for i in range(3)] + [Image.fromarray(al)]
    small = np.stack([np.asarray(c.resize(size, Image.LANCZOS)) for c in ch], -1)
    al2 = np.clip(small[..., 3], 0, 1)
    rgb = np.where(al2[..., None] > 1e-4, small[..., :3] / np.maximum(al2[..., None], 1e-4), 0)
    return Image.fromarray((np.dstack([rgb, al2]) * 255).round().clip(0, 255).astype(np.uint8), "RGBA")


names = sorted(f for f in os.listdir(SRC) if f.endswith(".png"))
ims = []
for n in names:
    im = Image.open(os.path.join(SRC, n))
    if im.width != 1024:
        im = premultiplied_resize(im, (1024, 1024))
    ims.append(im)
al = np.stack([np.asarray(i)[..., 3] > 0 for i in ims]).any(0)
ys, xs = np.nonzero(al)
box = (int(xs.min()) - MARGIN, int(ys.min()) - MARGIN, int(xs.max()) + 1 + MARGIN, int(ys.max()) + 1 + MARGIN)
fw, fh = box[2] - box[0], box[3] - box[1]
os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
frames = [i.crop(box) for i in ims]
for k, f in enumerate(frames):
    f.save(os.path.join(OUT, "frames", f"die_{k:02d}.png"))

sheet = Image.new("RGBA", (COLS * fw, ROWS * fh), (0, 0, 0, 0))
for k, f in enumerate(frames):
    sheet.alpha_composite(f, ((k % COLS) * fw, (k // COLS) * fh))
sheet.save(os.path.join(OUT, "die_sheet.png"))
hw, hh = fw // 2, fh // 2
half = Image.new("RGBA", (COLS * hw, ROWS * hh), (0, 0, 0, 0))
for k, f in enumerate(frames):
    half.alpha_composite(premultiplied_resize(f, (hw, hh)), ((k % COLS) * hw, (k // COLS) * hh))
half.save(os.path.join(OUT, "die_sheet_half.png"))
pivot = [round(ORIGIN_X - box[0], 1), round(GROUND_Y - box[1], 1)]
json.dump({
    "animation": "die", "frame_size": [fw, fh], "half_frame_size": [hw, hh], "columns": COLS, "rows": ROWS,
    "count": len(frames), "fps": FPS, "loop": False, "hold_last": True,
    "pivot": pivot, "half_pivot": [round(pivot[0] / 2, 1), round(pivot[1] / 2, 1)],
    "pivot_note": "pixels from each frame's top-left: the ground under his hips",
    "source_frames": [int(n[:4]) for n in names], "source": "Making/Animation.blend, 4_Die (mixamo.com.003), Cam_Side, 30 fps",
}, open(os.path.join(OUT, "die_sheet.json"), "w"), indent=1)

# preview: on the game's sky, at half size (about phone size), the last frame held
gif = []
for f in frames + [frames[-1]] * 10:
    b = Image.new("RGBA", (fw, fh), SKY)
    ImageDraw.Draw(b).rectangle([0, pivot[1], fw, fh], fill=(196, 160, 110, 255))
    b.alpha_composite(f)
    gif.append(b.convert("RGB").resize((hw, hh), Image.LANCZOS))
gif[0].save(os.path.join(OUT, "die_preview.gif"), save_all=True, append_images=gif[1:], duration=round(1000 / FPS), loop=0)

# compare: the video's frame above, the sprite below
tw, th = fw // 3, fh // 3
cmp_ = Image.new("RGBA", (10 * tw, 4 * th), (245, 240, 230, 255))
for k, (n, f) in enumerate(zip(names, frames)):
    cx, cy = (k % 10) * tw, (k // 10) * 2 * th
    p = os.path.join(CLEAN, n)
    if os.path.exists(p):
        cmp_.alpha_composite(Image.open(p).convert("RGBA").crop(box).resize((tw, th), Image.LANCZOS), (cx, cy))
    cmp_.alpha_composite(f.resize((tw, th), Image.LANCZOS), (cx, cy + th))
cmp_.convert("RGB").save(os.path.join(OUT, "compare.png"))
print("frames", len(frames), "size", fw, "x", fh, "pivot", pivot, "box", box)
