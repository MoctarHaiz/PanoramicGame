#!/usr/bin/env python3
"""Cuts the hero out of the user's key art at full resolution (segments_src/segments/full.png), using the
segment tool's character mask (muscular-male-character.png, a smaller copy of the same pixels): finds
where and how big that cut-out sits in full.png, scales its mask up, and writes work/ref_style.png
(the hero on chroma green, for the image model) and work/ref_style_rgba.png (on transparency).

    python3 make_reference.py
"""
import numpy as np
from PIL import Image

SEG = "segments_src/segments/"
full = Image.open(SEG + "full.png").convert("RGB")
seg = Image.open(SEG + "muscular-male-character.png").convert("RGBA")
F = np.asarray(full, np.float32)
S = np.asarray(seg, np.float32)
m = S[..., 3] > 250

# coarse-to-fine search: scale s (segment px -> full px) and offset, compared at the segment's size
def score(s, ox, oy):
    w, h = round(seg.width * s), round(seg.height * s)
    if ox < 0 or oy < 0 or ox + w > full.width or oy + h > full.height:
        return 1e9
    win = np.asarray(full.crop((ox, oy, ox + w, oy + h)).resize(seg.size, Image.BILINEAR), np.float32)
    return float(np.abs(win[m] - S[..., :3][m]).mean())

cands = []
for s in np.arange(1.40, 1.64, 0.02):
    w, h = round(seg.width * s), round(seg.height * s)
    for ox in range(0, full.width - w + 1, 16):
        for oy in range(0, full.height - h + 1, 16):
            cands.append((score(s, ox, oy), s, ox, oy))
cands.sort()
_, s0, x0, y0 = cands[0]
best = cands[0]
for s in np.arange(s0 - 0.02, s0 + 0.021, 0.004):
    for ox in range(x0 - 16, x0 + 17, 2):
        for oy in range(y0 - 16, y0 + 17, 2):
            c = (score(s, ox, oy), s, ox, oy)
            if c < best:
                best = c
err, s, ox, oy = best
print(f"segment sits at ({ox}, {oy}) x{s:.3f} in full.png, mean error {err:.1f}/255")
w, h = round(seg.width * s), round(seg.height * s)
alpha = seg.getchannel("A").resize((w, h), Image.LANCZOS)
hero = full.crop((ox, oy, ox + w, oy + h)).convert("RGBA")
hero.putalpha(alpha)
hero = hero.crop(hero.getbbox())
hero.save("work/ref_style_rgba.png")
bg = Image.new("RGBA", (hero.width + 160, hero.height + 160), (0, 255, 0, 255))
bg.alpha_composite(hero, (80, 80))
bg.convert("RGB").save("work/ref_style.png")
print("hero", hero.size)
