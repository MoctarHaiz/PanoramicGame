#!/usr/bin/env python3
"""Pictures for Panoramic's costume pieces made in round 15 (the character judge: "a ragged white towel cut high";
"blue-and-white high-top sneakers"): the leather panels hanging from his belt (a dark warm leather, a cream stitched
edge, a white zigzag band and blue beads: his own colours), drawn here and mapped on the panels by
ROOT/_agents/AAA/hero3d/scripts (live Blender).

    python3 tools/art/hero_costume.py   # writes ROOT/_agents/AAA/hero3d/textures/costume/panel.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())
DIR = ROOT / "_agents/AAA/hero3d/textures/costume"
LEATHER = np.array([0.43, 0.25, 0.15])  ## sRGB, the belt's brown
CREAM = (238, 226, 200)
BLUE = (40, 80, 190)  ## the armour's blue


def panel(w=256, h=512, ss=4):
    rng = np.random.default_rng(15)
    grain = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)), 2.5)
    grain = grain / np.abs(grain).max()
    rgb = LEATHER[None, None] * (1.0 + 0.06 * grain[..., None])
    yy = np.mgrid[0:h, 0:w][0] / h
    rgb = rgb * (1.0 - 0.18 * yy[..., None])  # darker towards its foot (worn, in his shade)
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).resize((w * ss, h * ss), Image.BILINEAR)
    d = ImageDraw.Draw(img)
    S = ss
    # the stitched edge: dashes a little in from each side
    for x0 in (14, w - 14):
        for y0 in range(10, h - 10, 18):
            d.line([(x0 * S, y0 * S), (x0 * S, (y0 + 10) * S)], fill=CREAM, width=3 * S)
    # a white zigzag band across, between two cream rules, a row of blue beads under it
    for yb in (150, 230):
        d.rectangle([(22 * S, yb * S), ((w - 22) * S, (yb + 5) * S)], fill=CREAM)
    pts = []
    for i in range(0, 9):
        x = 22 + i * (w - 44) / 8
        pts.append((x * S, (165 if i % 2 == 0 else 215) * S))
    d.line(pts, fill=(250, 246, 236), width=12 * S, joint="curve")
    for i in range(7):
        x = 40 + i * (w - 80) / 6
        d.ellipse([((x - 9) * S, 262 * S), ((x + 9) * S, 280 * S)], fill=BLUE)
        d.ellipse([((x - 3) * S, 265 * S), ((x + 1) * S, 269 * S)], fill=(150, 185, 255))
    # a blue triangle at its foot
    d.polygon([(60 * S, 380 * S), ((w - 60) * S, 380 * S), (w / 2 * S, 470 * S)], fill=BLUE)
    d.polygon([(90 * S, 392 * S), ((w - 90) * S, 392 * S), (w / 2 * S, 446 * S)], fill=(210, 222, 245))
    return img.resize((w, h), Image.LANCZOS)


def main():
    DIR.mkdir(parents=True, exist_ok=True)
    panel().save(DIR / "panel.png", optimize=True)
    print("panel.png")


if __name__ == "__main__":
    main()
