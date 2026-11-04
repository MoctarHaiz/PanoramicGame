#!/usr/bin/env python3
"""Small interface pictures made from the hero art (Pillow only).

    python3 tools/art/ui_art.py     # assets/art/ui/head.png

- head.png: Panoramic's face on a warm sunset disc (128 px), cut from today's portrait (the menu's key
  art): the marker that runs along the HUD's way home (the HUD draws its gold ring round it).
  (Round 9, QA ART-2: it was still round 1's studio-render face; the crop follows the portrait.)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
PORTRAIT = ROOT / "assets/art/hero/portrait.png"
OUT = ROOT / "assets/art/ui"

SIZE = 128  # px of the badge (hud.gd draws it 42 units wide, in its own gold ring)
SS = 4  # supersampling
FACE, FACE_R = (286, 226), 116  ## his face in portrait.png (hair to chin), and the crop's radius (px)


def disc_mask(n: int, r: float) -> Image.Image:
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).ellipse((n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r), fill=255)
    return m


def head_badge() -> Image.Image:
    n = SIZE * SS
    c = n / 2
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # the sunset disc behind him
    yy = np.linspace(0, 1, n)[:, None] * np.ones((1, n))
    top, bottom = np.array([255, 206, 110]), np.array([232, 98, 44])
    sky = (top * (1 - yy[..., None]) + bottom * yy[..., None]).astype(np.uint8)
    sky_img = Image.fromarray(np.dstack([sky, np.full((n, n), 255, np.uint8)]), "RGBA")
    inner_r = c - SS * 0.5
    out.paste(sky_img, (0, 0), disc_mask(n, inner_r))
    # the face: the portrait cropped round it
    p = Image.open(PORTRAIT).convert("RGBA")
    crop = p.crop((FACE[0] - FACE_R, FACE[1] - FACE_R, FACE[0] + FACE_R, FACE[1] + FACE_R))
    crop = crop.resize((n, n), Image.LANCZOS)
    face_mask = Image.fromarray(np.minimum(np.asarray(crop.getchannel("A")), np.asarray(disc_mask(n, inner_r))))
    out.paste(crop, (0, 0), face_mask)
    # a soft shade inside the edge, so the ring sits on it
    shade = Image.new("RGBA", (n, n), (60, 16, 4, 0))
    ring_shadow = disc_mask(n, inner_r - SS * 2).filter(ImageFilter.GaussianBlur(SS * 3))
    a = np.asarray(disc_mask(n, inner_r)).astype(np.float32) - np.asarray(ring_shadow).astype(np.float32)
    shade.putalpha(Image.fromarray(np.clip(a * 0.7, 0, 255).astype(np.uint8)))
    out.alpha_composite(shade)
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    head_badge().save(OUT / "head.png", optimize=True)
    print("head.png", SIZE)


if __name__ == "__main__":
    main()
