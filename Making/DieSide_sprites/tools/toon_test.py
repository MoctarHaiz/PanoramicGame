#!/usr/bin/env python3
"""A free, local stand-in for the image model: repaints the 20 cleaned 3D frames with the colours of the
user's key art (segments_src/segments) as cel-shaded sprites with an ink outline, and lays them out
exactly like work/grid_in.png, on chroma green, as work/toon_sheet.png. Run tools/process_sheet.py on it
to test the whole cut-out -> sheet -> preview pipeline.

Every pixel is sorted into a material (skin, hair, scarf, blue armour, white/silver) by its colour; its
brightness rank within that material (over all 20 frames at once, so every frame gets the same mapping)
picks the colour at the same brightness rank in the key art's matching part, in 4 flat cel bands.

    python3 toon_test.py
"""
import colorsys
import json

import numpy as np
from PIL import Image
from scipy import ndimage

SEG = "segments_src/segments/"
BANDS = 4
FRAME_EDGES = [0.30, 0.72, 0.93]  # brightness ranks splitting each material into shadow / mid / lit / highlight
REF_RANKS = [0.18, 0.55, 0.82, 0.96]  # where in the key art's brightness range each band takes its colour
OUTLINE = np.array([0.16, 0.09, 0.06], np.float32)  # dark warm brown ink
L = json.load(open("work/layout.json"))
box = L["box"]


def rgb_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, (mx - mn) / (mx + 1e-6), 0)
    return h, s, mx


def classify(rgb):
    h, s, v = rgb_hsv(rgb)
    cls = np.full(h.shape, 0, np.int8)  # 0 skin by default
    cls[(v < 0.30) & (s < 0.45)] = 1  # hair (near black)
    cls[((h < 15) | (h > 340)) & (s > 0.45) & (v > 0.25)] = 2  # scarf (red)
    cls[(h > 195) & (h < 260) & (s > 0.30)] = 3  # blue armour
    cls[(s < 0.22) & (v >= 0.42)] = 4  # white fur, silver armour
    return cls


def lum(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114], np.float32)


def palette(pixels):
    """One colour per cel band, dark to light: the median hue, saturation and value of the reference
    pixels around the band's brightness rank (medians keep the colour pure; means turn it to mud)."""
    order = np.argsort(lum(pixels))
    p = pixels[order]
    h, s_, v = rgb_hsv(p)
    out = []
    for q in REF_RANKS:
        i0, i1 = int(max(0, q - 0.05) * len(p)), int(min(1, q + 0.05) * len(p))
        hh = np.deg2rad(h[i0:i1])
        hue = np.rad2deg(np.arctan2(np.median(np.sin(hh)), np.median(np.cos(hh)))) % 360
        out.append(colorsys.hsv_to_rgb(hue / 360, float(np.median(s_[i0:i1])), float(np.median(v[i0:i1]))))
    return np.array(out, np.float32)


def seg_pixels(name, keep=None):
    a = np.asarray(Image.open(SEG + name).convert("RGBA"), np.float32) / 255.0
    p = a[a[..., 3] > 0.9][:, :3]
    return p if keep is None else p[keep(p)]


# the key art's palettes, part by part
hero = np.asarray(Image.open("work/ref_style_rgba.png").convert("RGBA"), np.float32) / 255.0
hp = hero[hero[..., 3] > 0.9][:, :3]
hc = classify(hp)
blue_parts = np.concatenate([seg_pixels(f"blue-and-white-boots/blue-and-white-boots-{i}.png") for i in (1, 2)]
                            + [seg_pixels(f"blue-armored-arm-guards/blue-armored-arm-guards-{i}.png") for i in (1, 2)])
bc = classify(blue_parts)
hh, hs, hv = rgb_hsv(hp)
skin = hp[(hh > 8) & (hh < 42) & (hs > 0.35) & (hs < 0.92) & (hv > 0.22)]
fur = seg_pixels("white-fur-loincloth.png")
fh, fs, fv = rgb_hsv(fur)
PAL = {
    0: palette(skin),                                         # skin, from the hero
    1: palette(seg_pixels("spiky-black-hair.png")),           # hair
    2: palette(seg_pixels("red-scarf.png")),                  # scarf
    3: palette(blue_parts[bc == 3]),                          # blue armour
    4: palette(np.concatenate([fur[(fs < 0.30) & (fv > 0.35)], blue_parts[bc == 4]])),  # white / silver
}
for k, v in PAL.items():
    print(k, (v * 255).round().astype(int).tolist())

# the frames, in the sheet's cell boxes
frames = [np.asarray(Image.open(f"work/clean/{c['frame']:04d}.png").convert("RGBA").crop(box), np.float32) / 255.0
          for c in L["cells"]]
stack = np.stack(frames)
rgb, al = stack[..., :3], stack[..., 3]
cls = classify(rgb)
cls = np.where(al > 0.05, cls, -1)
# smooth the class map a little (no salt-and-pepper material flips)
for i in range(len(frames)):
    c = cls[i]
    votes = np.stack([ndimage.uniform_filter((c == k).astype(np.float32), 5) for k in range(5)])
    cls[i] = np.where(c >= 0, votes.argmax(0), -1)
# brightness rank within each material, over all frames together -> band
Y = lum(rgb)
band = np.zeros(Y.shape, np.int8)
for k in range(5):
    m = cls == k
    if m.any():
        y = Y[m]
        edges = np.quantile(y, FRAME_EDGES)
        band[m] = np.searchsorted(edges, y)
# smooth band edges (clean cel shapes, not noise)
out = np.zeros_like(rgb)
for i in range(len(frames)):
    b = band[i].astype(np.float32)
    b = ndimage.median_filter(b, 5).astype(np.int8)
    for k in range(5):
        m = cls[i] == k
        out[i][m] = PAL[k][b[m]]

st = ndimage.generate_binary_structure(2, 2)
W, H = L["sheet"]
sheet = Image.new("RGBA", (W, H), (0, 255, 0, 255))
for i, c in enumerate(L["cells"]):
    a = al[i]
    solid = a > 0.5
    # inner ink: where the material changes
    edge = np.zeros_like(solid)
    ci = cls[i]
    for dy, dx in ((0, 1), (1, 0)):
        edge |= (ci != np.roll(ci, (dy, dx), (0, 1))) & solid & np.roll(solid, (dy, dx), (0, 1))
    col = out[i].copy()
    col[edge] = col[edge] * 0.35 + OUTLINE * 0.65
    # outer ink: a 3 px band around the silhouette
    ring = ndimage.binary_dilation(solid, st, iterations=3) & ~ndimage.binary_erosion(solid, st, iterations=1)
    col[ring] = OUTLINE
    alpha = np.maximum(a, ring.astype(np.float32))
    alpha = ndimage.gaussian_filter(alpha, 0.6)
    img = Image.fromarray((np.dstack([col, alpha]) * 255).clip(0, 255).astype(np.uint8), "RGBA")
    sheet.alpha_composite(img, (c["x"], c["y"]))
sheet.convert("RGB").save("work/toon_sheet.png")
print("wrote work/toon_sheet.png", sheet.size)
