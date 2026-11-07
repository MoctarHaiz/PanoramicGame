#!/usr/bin/env python3
"""Removes Blender's viewport overlays (armature, camera frame, ground line, 3D cursor, relationship
line) from the DieSide viewport captures, keeping only the character on transparency.

    python3 clean_frames.py SRC_DIR OUT_DIR
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
names = sorted(f for f in os.listdir(src) if f.endswith(".png"))
A = np.stack([np.asarray(Image.open(os.path.join(src, f)).convert("RGBA")) for f in names]).astype(np.int16)

# static overlays: a pixel showing the same visible value in most frames (the character moves, lines don't)
q = (A // 8).astype(np.int32)
key = ((q[..., 0] * 32 + q[..., 1]) * 32 + q[..., 2]) * 32 + q[..., 3]
mode = np.zeros(key.shape[1:], np.int32)
count = np.zeros(key.shape[1:], np.int32)
# mode over frames, vectorised via sorting
s = np.sort(key, axis=0)
run_start = np.ones_like(s, bool)
run_start[1:] = s[1:] != s[:-1]
idx = np.cumsum(run_start, axis=0)
for k in range(1, idx.max() + 1):
    m = idx == k
    c = m.sum(0)
    v = np.where(m, s, -1).max(0)
    better = c > count
    count[better] = c[better]
    mode[better] = v[better]
static = (count >= 0.6 * len(names)) & ((mode % 32) > 0)  # visible (alpha>0) and present in 60%+ of frames
print("static overlay pixels:", int(static.sum()))

st = ndimage.generate_binary_structure(2, 2)
CURSOR = (501, 858)
GUIDE = (498, 502)
for name, a in zip(names, A):
    a = a.copy()
    rgb, al = a[..., :3], a[..., 3]
    vis = al > 0
    black = (rgb.max(-1) <= 3) & vis                      # armature, camera frame (pure black)
    green = (rgb[..., 1] > rgb[..., 0] + 30) & (rgb[..., 1] > rgb[..., 2] + 30) & vis  # ground line
    kq = (((a // 8)[..., 0] * 32 + (a // 8)[..., 1]) * 32 + (a // 8)[..., 2]) * 32 + (a // 8)[..., 3]
    stat = static & (np.abs(kq - mode) == 0)              # the static line is on top here
    # the 3D cursor: a red and white dashed ring around (501, 858)
    yy, xx = np.mgrid[: a.shape[0], : a.shape[1]]
    rr = np.hypot(xx - CURSOR[0], yy - CURSOR[1])
    ring = (rr >= 13) & (rr <= 24) & vis & (((rgb[..., 0] > 140) & (rgb[..., 1] < 120)) | (rgb.min(-1) > 190))
    mask = ndimage.binary_dilation(black | green | stat | ring, st, iterations=1)
    # the object's vertical guide line (x 499-501, black at ~30% over everything): interpolate across it
    l, r_ = a[:, GUIDE[0] - 1].astype(np.float32), a[:, GUIDE[1] + 1].astype(np.float32)
    n_ = GUIDE[1] - GUIDE[0] + 2
    for i, x in enumerate(range(GUIDE[0], GUIDE[1] + 1), 1):
        a[:, x] = np.round(l + (r_ - l) * i / n_).astype(np.int16)
    # fill masked pixels with the nearest clean pixel (all four channels: lines over air become air)
    _, (iy, ix) = ndimage.distance_transform_edt(mask, return_indices=True)
    f = a[iy, ix].copy()
    # keep only the character: the big connected pieces of solid alpha
    solid = f[..., 3] > 40
    lab, n = ndimage.label(solid, st)
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s_ in enumerate(sizes) if s_ >= 400])
    keep = ndimage.binary_dilation(keep, st, iterations=2)
    f[..., 3] = np.where(keep, f[..., 3], 0)
    Image.fromarray(f.astype(np.uint8), "RGBA").save(os.path.join(out, name))
print("cleaned", len(names), "frames ->", out)
