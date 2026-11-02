#!/usr/bin/env python3
"""Makes the store pictures in docs/store/ from real screens of the game (landscape):

    play/<lang>/phone_<n>.png         Google Play phone screenshots, 1920 x 1080
    play/<lang>/feature_graphic.png   Google Play feature graphic, 1024 x 500
    appstore/<lang>/iphone_<n>.png    App Store 6.9" iPhone screenshots, 2868 x 1320
    appstore/<lang>/iphone63_<n>.png  App Store 6.3" iPhone screenshots, 2622 x 1206 (the 6.9" ones, scaled)
    appstore/<lang>/ipad_<n>.png      App Store 13" iPad screenshots, 2752 x 2064

Each screenshot is a screen rendered by tests/capture.tscn (no ad banner) under a caption, on the
game's sunset. Usage (from New/): python3 tools/store_art.py [--skip-capture]
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

NEW = Path(__file__).resolve().parents[1]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
OUT = NEW / "docs/store"
CAPTURES = NEW / "build/store_captures"
FONT = NEW / "assets/fonts/Fredoka.ttf"
TOP = (122, 31, 58)
MIDDLE = (217, 72, 28)
BOTTOM = (255, 196, 110)
SHADOW = (60, 14, 8)

SHOTS = ["game", "hang", "climb", "home", "menu"]
CAPTIONS = {
    "en": ["Run across the savanna", "Hang from the vines", "Throw rings at the bandits",
           "Get home and earn 3 stars", "Chaka Zulu is back!"],
    "fr": ["Cours à travers la savane", "Accroche-toi aux lianes", "Lance des anneaux aux bandits",
           "Rentre à la maison, gagne 3 étoiles", "Chaka Zulu est de retour !"],
}
DEVICES = {  # capture device: (store folder, file prefix, final size)
    "phone_1920x1080": ("play", "phone", (1920, 1080)),
    "iphone17promax_2868x1320": ("appstore", "iphone", (2868, 1320)),
    "ipad13_2752x2064": ("appstore", "ipad", (2752, 2064)),
}
IPHONE_63 = (2622, 1206)


def font(size: int, weight: int = 700) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([weight, 100])
    return f


def background(size: tuple) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        k = y / (h - 1)
        a, b, t = (TOP, MIDDLE, k / 0.6) if k < 0.6 else (MIDDLE, BOTTOM, (k - 0.6) / 0.4)
        d.line([(0, y), (w, y)], fill=tuple(round(p + (q - p) * t) for p, q in zip(a, b)))
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    r = h * 0.45
    ImageDraw.Draw(glow).ellipse([w * 0.5 - r, h * 0.95 - r, w * 0.5 + r, h * 0.95 + r], fill=(255, 230, 160, 90))
    return Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(h * 0.08)))


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def caption(canvas: Image.Image, text: str, center_x: int, middle_y: int, size: int) -> None:
    f = font(size)
    d = ImageDraw.Draw(canvas)
    w = d.textlength(text, font=f)
    x, y = center_x - w / 2, middle_y - size * 0.6
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x, y + size * 0.08), text, font=f, fill=SHADOW + (150,))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.06)))
    d.text((x, y), text, font=f, fill=(255, 255, 255), stroke_width=max(2, size // 16), stroke_fill=SHADOW)


def frame(shot: Image.Image, text: str, size: tuple) -> Image.Image:
    w, h = size
    canvas = background(size)
    band = round(h * 0.17)
    caption(canvas, text, w // 2, band // 2 + round(h * 0.01), round(band * 0.5))
    k = min((w * 0.9) / shot.width, (h - band - h * 0.05) / shot.height)
    s = shot.resize((round(shot.width * k), round(shot.height * k)), Image.LANCZOS)
    s = rounded(s, round(h * 0.03))
    x, y = (w - s.width) // 2, band
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x, y + 12, x + s.width, y + s.height + 12], round(h * 0.03), fill=SHADOW + (130,))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(h * 0.015)))
    canvas.alpha_composite(s, (x, y))
    return canvas.convert("RGB")


def feature_graphic(lang: str) -> Image.Image:
    size = (1024, 500)
    canvas = background(size)
    hero = Image.open(NEW / "assets/art/hero/portrait.png").convert("RGBA")
    k = 500 * 0.98 / hero.height
    hero = hero.resize((round(hero.width * k), round(hero.height * k)), Image.LANCZOS)
    canvas.alpha_composite(hero, (1024 - hero.width - 30, 500 - hero.height))
    caption(canvas, "CHAKA ZULU", 330, 200, 104)
    caption(canvas, "Les aventures de Panoramic" if lang == "fr" else "The adventures of Panoramic", 330, 300, 38)
    return canvas.convert("RGB")


def main() -> None:
    if "--skip-capture" not in sys.argv:
        for lang in CAPTIONS:
            subprocess.run([GODOT, "--path", str(NEW), "--fixed-fps", "60", "--resolution", "200x200",
                            "--always-on-top", "res://tests/capture.tscn", "--", f"--out={CAPTURES / lang}",
                            f"--devices={','.join(DEVICES)}", f"--shots={','.join(SHOTS)}", f"--lang={lang}",
                            "--ads=off"], check=True)
    for lang, texts in CAPTIONS.items():
        for device, (store, prefix, size) in DEVICES.items():
            folder = OUT / store / lang
            folder.mkdir(parents=True, exist_ok=True)
            for n, (shot, text) in enumerate(zip(SHOTS, texts), 1):
                pic = frame(Image.open(CAPTURES / lang / f"{device}__{shot}.png").convert("RGB"), text, size)
                pic.save(folder / f"{prefix}_{n}.png")
                if prefix == "iphone":
                    pic.resize(IPHONE_63, Image.LANCZOS).save(folder / f"iphone63_{n}.png")
        (OUT / "play" / lang).mkdir(parents=True, exist_ok=True)
        feature_graphic(lang).save(OUT / "play" / lang / "feature_graphic.png")
    print("store art in", OUT)


if __name__ == "__main__":
    main()
