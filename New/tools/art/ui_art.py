#!/usr/bin/env python3
"""Small interface pictures made from the hero art (Pillow only).

    python3 tools/art/ui_art.py     # assets/art/ui/head.png

- head.png: Panoramic's face in a round badge (the portrait on a warm sunset disc, a gold ring and
  a dark ink edge): the marker that runs along the HUD's way home, and the results.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
PORTRAIT = ROOT / "assets/art/hero/portrait.png"
OUT = ROOT / "assets/art/ui"

SIZE = 160  # px of the badge
SS = 4  # supersampling


def disc_mask(n: int, r: float) -> Image.Image:
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).ellipse((n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r), fill=255)
    return m


def head_badge() -> Image.Image:
    n = SIZE * SS
    c = n / 2
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # sunset disc
    yy = np.linspace(0, 1, n)[:, None] * np.ones((1, n))
    top, bottom = np.array([255, 196, 92]), np.array([226, 76, 34])
    sky = (top * (1 - yy[..., None]) + bottom * yy[..., None]).astype(np.uint8)
    sky_img = Image.fromarray(np.dstack([sky, np.full((n, n), 255, np.uint8)]), "RGBA")
    inner_r = c * 0.80
    out.paste(sky_img, (0, 0), disc_mask(n, inner_r))
    # the face: the portrait cropped around it
    p = Image.open(PORTRAIT).convert("RGBA")
    centre, radius = (338, 318), 150
    crop = p.crop((centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius))
    crop = crop.resize((int(inner_r * 2.0), int(inner_r * 2.0)), Image.LANCZOS)
    face = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    face.paste(crop, (int(c - inner_r), int(c - inner_r)))
    face_mask = Image.fromarray(np.minimum(np.asarray(face.getchannel("A")), np.asarray(disc_mask(n, inner_r))))
    out.paste(face, (0, 0), face_mask)
    # a soft inner shadow under the ring
    shade = Image.new("RGBA", (n, n), (60, 16, 4, 0))
    ring_shadow = disc_mask(n, inner_r).filter(ImageFilter.GaussianBlur(SS * 3))
    a = np.asarray(disc_mask(n, inner_r)).astype(np.float32) - np.asarray(ring_shadow).astype(np.float32)
    shade.putalpha(Image.fromarray(np.clip(a * 0.9, 0, 255).astype(np.uint8)))
    out.alpha_composite(shade)
    # gold ring and ink edge
    d = ImageDraw.Draw(out)
    ring_w = c * 0.12
    d.ellipse((c - c * 0.96, c - c * 0.96, c + c * 0.96, c + c * 0.96), outline=(46, 13, 4, 255), width=int(c * 0.08))
    d.ellipse((c - c * 0.89, c - c * 0.89, c + c * 0.89, c + c * 0.89), outline=(255, 196, 64, 255), width=int(ring_w))
    d.arc((c - c * 0.86, c - c * 0.86, c + c * 0.86, c + c * 0.86), 200, 320, fill=(255, 244, 196, 255), width=int(c * 0.035))
    d.ellipse((c - inner_r, c - inner_r, c + inner_r, c + inner_r), outline=(46, 13, 4, 255), width=int(c * 0.03))
    return out.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    head_badge().save(OUT / "head.png", optimize=True)
    print("head", SIZE)


if __name__ == "__main__":
    main()
