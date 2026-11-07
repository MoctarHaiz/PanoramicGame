#!/usr/bin/env python3
"""Tiles the chosen cleaned frames into one sheet (on flat chroma green) for the image model, all cropped
to the same box so every cell keeps the animation's registration. Writes work/grid_in.png, work/ref_hero.png
and work/layout.json (where each cell sits, to cut the model's sheet back into frames).

    python3 make_grid.py
"""
import json

import numpy as np
from PIL import Image

FRAMES = [1, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48, 51, 54, 60, 78]
COLS, ROWS = 5, 4
GREEN = (0, 255, 0)
ASPECT = 3 / 2  # the sheet's width:height (one the model accepts)

ims = [Image.open(f"work/clean/{f:04d}.png").convert("RGBA") for f in FRAMES]
al = np.stack([np.asarray(i)[..., 3] > 40 for i in ims]).any(0)
ys, xs = np.nonzero(al)
x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
m = 24
box = (int(x0 - m), int(y0 - m), int(x1 + m), int(y1 + m))
cw, ch = box[2] - box[0], box[3] - box[1]
gap = 40
W = COLS * cw + (COLS + 1) * gap
H = ROWS * ch + (ROWS + 1) * gap
if W / H < ASPECT:
    W = int(round(H * ASPECT))
else:
    H = int(round(W / ASPECT))
ox = (W - (COLS * cw + (COLS - 1) * gap)) // 2
oy = (H - (ROWS * ch + (ROWS - 1) * gap)) // 2
sheet = Image.new("RGBA", (W, H), GREEN + (255,))
cells = []
for k, im in enumerate(ims):
    c, r = k % COLS, k // COLS
    x, y = ox + c * (cw + gap), oy + r * (ch + gap)
    sheet.alpha_composite(im.crop(box), (x, y))
    cells.append({"frame": FRAMES[k], "x": x, "y": y, "w": cw, "h": ch})
sheet.convert("RGB").save("work/grid_in.png")
# a larger, detailed look at the hero (first frame) as the identity reference
ref = ims[0].crop(ims[0].getbbox())
bg = Image.new("RGBA", (ref.width + 120, ref.height + 120), GREEN + (255,))
bg.alpha_composite(ref, (60, 60))
bg.convert("RGB").save("work/ref_hero.png")
json.dump({"sheet": [W, H], "box": box, "cols": COLS, "rows": ROWS, "cells": cells}, open("work/layout.json", "w"), indent=1)
print("box", box, "cell", cw, ch, "sheet", W, H)
