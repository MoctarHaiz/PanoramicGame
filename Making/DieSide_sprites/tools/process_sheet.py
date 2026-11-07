#!/usr/bin/env python3
"""Turns the image model's repainted sheet back into game sprites.

For every cell of work/layout.json: cut it out of the model's sheet (any size), key out the chroma
green (with despill), drop stray specks, then snap it back onto the original frame's silhouette
(the model may drift a few pixels: the 3D frames are the truth for where the body is), so the
animation does not jitter. Writes, into OUT_DIR:

    frames/die_00.png ... die_19.png   transparent, all the same size, registered
    die_sheet.png                      the frames in a 5x4 grid (cell = frame size)
    die_sheet.json                     frame size, grid, fps, the pivot (ground under the hips), source frames
    die_preview.gif                    the animation on a plain backdrop, to check it plays smoothly
    compare.png                        3D frame above, repainted frame below, for every frame

    python3 process_sheet.py MODEL_SHEET.png OUT_DIR [--scale=1.0]
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(HERE, "..", "work")
FPS = 12.0
GROUND_Y = 858  # the ground line in the 1024 viewport frames
ORIGIN_X = 501  # the hero's origin (under his hips) in the 1024 viewport frames

sheet_path, out = sys.argv[1], sys.argv[2]
scale_arg = next((float(a.split("=")[1]) for a in sys.argv[3:] if a.startswith("--scale=")), 1.0)
L = json.load(open(os.path.join(WORK, "layout.json")))
W, H = L["sheet"]
bx0, by0, bx1, by1 = L["box"]
model = Image.open(sheet_path).convert("RGB")
sx, sy = model.width / W, model.height / H
k = (sx + sy) / 2 * scale_arg  # cell scale: the model sheet -> output frames
cw, ch = L["cells"][0]["w"], L["cells"][0]["h"]
OW, OH = round(cw * k), round(ch * k)
os.makedirs(os.path.join(out, "frames"), exist_ok=True)
st8 = ndimage.generate_binary_structure(2, 2)


def key_green(rgb: np.ndarray) -> np.ndarray:
    """RGB uint8 -> RGBA float [0,1], green keyed out and despilled."""
    f = rgb.astype(np.float32) / 255.0
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    spill = g - np.maximum(r, b)  # ~1 on the backdrop, <=0 on the hero (no green in his design)
    alpha = np.clip(1.0 - (spill - 0.12) / (0.45 - 0.12), 0.0, 1.0)
    # unmix the edge pixels from the known backdrop (pure green): C = a*F + (1-a)*G  ->  F
    a_ = np.maximum(alpha, 1e-3)[..., None]
    fg = np.clip((f - (1.0 - a_) * np.array([0.0, 1.0, 0.0], np.float32)) / a_, 0.0, 1.0)
    fg = np.where(alpha[..., None] > 0.97, f, fg)
    r, g, b = fg[..., 0], fg[..., 1], fg[..., 2]
    g2 = np.minimum(g, np.maximum(r, b))  # despill: green never exceeds the other two
    rgba = np.stack([r, g2, b, alpha], -1)
    # keep the hero: big solid pieces only (drop specks and stray marks)
    solid = alpha > 0.5
    lab, n = ndimage.label(solid, st8)
    if n:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        big = max(sizes)
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(150 * k * k, 0.01 * big)])
        keep = ndimage.binary_dilation(keep, st8, iterations=2)
        rgba[..., 3] *= keep
    return rgba


def best_shift(ref: np.ndarray, mov: np.ndarray, max_shift: int) -> tuple:
    """Integer (dy, dx) that best lays mov's alpha over ref's (FFT cross-correlation, bounded)."""
    a = ref - ref.mean()
    b = mov - mov.mean()
    F = np.fft.rfft2(a) * np.conj(np.fft.rfft2(b))
    cc = np.fft.irfft2(F, s=a.shape)
    cc = np.fft.fftshift(cc)
    cy, cx = a.shape[0] // 2, a.shape[1] // 2
    win = cc[cy - max_shift: cy + max_shift + 1, cx - max_shift: cx + max_shift + 1]
    dy, dx = np.unravel_index(np.argmax(win), win.shape)
    return int(dy - max_shift), int(dx - max_shift)


def shift_img(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    o = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    o[yd, xd] = a[ys, xs]
    return o


frames, refs, report = [], [], []
pad = round(L.get("gap", 40) / 2 * min(sx, sy))
for i, c in enumerate(L["cells"]):
    # the model's cell, with a little slack around it (it may draw past the 3D silhouette)
    x0, y0 = round(c["x"] * sx) - pad, round(c["y"] * sy) - pad
    x1, y1 = round((c["x"] + cw) * sx) + pad, round((c["y"] + ch) * sy) + pad
    cell = np.asarray(model.crop((x0, y0, x1, y1)))
    rgba = key_green(cell)
    img = Image.fromarray((rgba * 255).round().astype(np.uint8), "RGBA")
    big = img.resize((round(img.width * k / ((sx + sy) / 2)), round(img.height * k / ((sx + sy) / 2))), Image.LANCZOS) if scale_arg != 1.0 else img
    p = round(pad * scale_arg)
    # the 3D frame at the same scale, on the same canvas (slack included)
    src = Image.open(os.path.join(WORK, "clean", f"{c['frame']:04d}.png")).convert("RGBA").crop(L["box"])
    src = src.resize((OW, OH), Image.LANCZOS)
    ref = Image.new("RGBA", big.size, (0, 0, 0, 0))
    ref.alpha_composite(src, (p, p))
    ra = np.asarray(ref)[..., 3].astype(np.float32) / 255.0
    ma = np.asarray(big)[..., 3].astype(np.float32) / 255.0
    dy, dx = best_shift(ra, ma, max_shift=max(4, round(40 * k)))
    reg = shift_img(np.asarray(big), dy, dx)
    frame = Image.fromarray(reg, "RGBA").crop((p, p, p + OW, p + OH))
    frames.append(frame)
    refs.append(src)
    inter = ((ra > 0.5) & (np.asarray(Image.fromarray(reg, "RGBA"))[..., 3] > 127)).sum()
    union = ((ra > 0.5) | (np.asarray(Image.fromarray(reg, "RGBA"))[..., 3] > 127)).sum()
    report.append({"frame": c["frame"], "shift": [dx, dy], "iou": round(float(inter / max(union, 1)), 3)})
    frame.save(os.path.join(out, "frames", f"die_{i:02d}.png"))

# the sheet
cols, rows = L["cols"], L["rows"]
sheet = Image.new("RGBA", (cols * OW, rows * OH), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, ((i % cols) * OW, (i // cols) * OH))
sheet.save(os.path.join(out, "die_sheet.png"))
pivot = [round((ORIGIN_X - bx0) * k, 1), round((GROUND_Y - by0) * k, 1)]
json.dump({
    "animation": "die", "frame_size": [OW, OH], "columns": cols, "rows": rows, "count": len(frames),
    "fps": FPS, "loop": False,
    "pivot": pivot, "pivot_note": "pixels from the frame's top-left: the ground under his hips",
    "source_frames": [c["frame"] for c in L["cells"]], "source": "Making/DieSide (30 fps)",
    "registration": report,
}, open(os.path.join(out, "die_sheet.json"), "w"), indent=1)

# preview: the animation on a warm backdrop, holding the last frame
bg = (236, 204, 150, 255)
gif = []
for f in frames + [frames[-1]] * 8:
    b = Image.new("RGBA", (OW, OH), bg)
    d = ImageDraw.Draw(b)
    d.line([(0, pivot[1]), (OW, pivot[1])], fill=(150, 110, 70, 255), width=max(1, round(3 * k)))
    b.alpha_composite(f)
    gif.append(b.convert("RGB").resize((OW // 2, OH // 2), Image.LANCZOS))
gif[0].save(os.path.join(out, "die_preview.gif"), save_all=True, append_images=gif[1:], duration=round(1000 / FPS), loop=0)

# compare: 3D above, repainted below, two rows of 10
tw, th = OW // 3, OH // 3
cmp_ = Image.new("RGBA", (10 * tw, 4 * th), (245, 240, 230, 255))
for i, (r, f) in enumerate(zip(refs, frames)):
    cx, cy = (i % 10) * tw, (i // 10) * 2 * th
    cmp_.alpha_composite(r.resize((tw, th), Image.LANCZOS), (cx, cy))
    cmp_.alpha_composite(f.resize((tw, th), Image.LANCZOS), (cx, cy + th))
cmp_.convert("RGB").save(os.path.join(out, "compare.png"))
print("frame", OW, "x", OH, "pivot", pivot)
for r in report:
    print(r)
