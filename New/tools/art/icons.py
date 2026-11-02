#!/usr/bin/env python3
"""App icons from Panoramic's portrait (assets/art/hero/portrait.png, cut out of the art the user
made) on the brand sunset: a warm radial glow behind his head.

  assets/art/icons/icon_1024.png                 iOS + App Store (opaque, square: Apple rounds it)
  assets/art/icons/icon_512.png, icon_192.png    Play Store listing, Android legacy launcher
  assets/art/icons/adaptive_{foreground,background,monochrome}_432.png   Android adaptive layers

The subject of the adaptive foreground stays inside the central 66 % safe zone; where the canvas
cuts him (the chest), the bottom fades so launcher masks don't show a hard edge.

    python3 tools/art/icons.py [SUBJECT.png]   (default: the cut-out portrait)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/icons"
INNER = (255, 214, 120)
OUTER = (217, 72, 28)
DEEP = (122, 31, 58)


def sunset(size: int, centre=(0.5, 0.42)) -> Image.Image:
    y, x = np.mgrid[0:size, 0:size] / size
    d = np.sqrt((x - centre[0]) ** 2 + (y - centre[1]) ** 2) / 0.75
    c1, c2, c3 = (np.array(c, float) for c in (INNER, OUTER, DEEP))
    t = np.clip(d, 0, 1)[..., None]
    col = np.where(t < 0.5, c1 + (c2 - c1) * (t / 0.5), c2 + (c3 - c2) * ((t - 0.5) / 0.5))
    return Image.fromarray(col.astype(np.uint8), "RGB").convert("RGBA")


def subject(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    return im.crop(im.getbbox())


def place(canvas: int, sub: Image.Image, height: float, top: float, x_centre: float) -> Image.Image:
    """The subject scaled to `height` (fraction of the canvas), its top at `top`."""
    k = canvas * height / sub.height
    s = sub.resize((round(sub.width * k), round(sub.height * k)), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    layer.alpha_composite(s, (round(canvas * x_centre - s.width / 2), round(canvas * top)))
    return layer


def fade_bottom(img: Image.Image, start: float) -> Image.Image:
    a = np.asarray(img).astype(float)
    h = a.shape[0]
    ramp = np.clip((np.arange(h) / h - start) / (1 - start), 0, 1)[:, None]
    a[..., 3] *= 1 - ramp ** 1.5
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sub = subject(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/art/hero/portrait.png")
    # Square icon: head and shoulders, big, the head a little right of centre like the portrait.
    icon = sunset(1024)
    hero = place(1024, sub, 1.18, 0.02, 0.47)
    shadow = hero.copy().filter(ImageFilter.GaussianBlur(18))
    sh = np.asarray(shadow).copy()
    sh[..., :3] = (60, 14, 10)
    sh[..., 3] = (sh[..., 3] * 0.45).astype(np.uint8)
    icon.alpha_composite(Image.fromarray(sh, "RGBA"), (10, 16))
    icon.alpha_composite(hero)
    icon = icon.convert("RGB")
    icon.save(OUT / "icon_1024.png")
    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon_512.png")
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "icon_192.png")
    icon.resize((48, 48), Image.LANCZOS).save(OUT / "preview_48.png")
    # Adaptive: 432 canvas, safe zone = central 288 (66 %).
    fg = fade_bottom(place(432, sub, 0.86, 0.12, 0.49), 0.7)
    fg.save(OUT / "adaptive_foreground_432.png")
    sunset(432).convert("RGB").save(OUT / "adaptive_background_432.png")
    mono = np.asarray(fg).copy()
    mono[..., :3] = 255
    Image.fromarray(mono, "RGBA").save(OUT / "adaptive_monochrome_432.png")
    print("icons written to", OUT)


if __name__ == "__main__":
    main()
