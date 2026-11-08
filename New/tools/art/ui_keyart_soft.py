#!/usr/bin/env python3
"""The settings' backdrop (src/screens/settings_screen.gd): the savanna of the menu's key art
(assets/art/ui/menu_keyart.png) without Panoramic, at a third of its size, so drawn stretched through a cubic
B-spline (soft_blur.gdshader) it is lightly blurred, the scene recognisable behind the panel.
(UI r21, the judges of j17: his blurred hair and chakram "peeking above the panel's top-left edge read as a layering
mistake"): the crop is the part right of him (the sun's shafts, the mesas, the acacias, the grass), at the screen's
shape. Run it again whenever the key art changes.

    python3 tools/art/ui_keyart_soft.py   # assets/art/ui/menu_keyart_soft.png
"""
from pathlib import Path

from PIL import Image

UI = Path(__file__).resolve().parents[2] / "assets/art/ui"
LEFT = 0.575  # the crop starts right of his reaching hand (a share of the key art's width)
TOP = 0.47  # and from this high (the sky's shafts, the horizon, the grass)

if __name__ == "__main__":
    art = Image.open(UI / "menu_keyart.png").convert("RGB")
    w = art.width - int(art.width * LEFT)
    h = int(w * art.height / art.width)  # the key art's own shape (a phone's)
    top = min(int(art.height * TOP), art.height - h)
    crop = art.crop((art.width - w, top, art.width, top + h))
    crop.resize((crop.width // 3, crop.height // 3), Image.BOX).save(UI / "menu_keyart_soft.png")
    print("wrote", UI / "menu_keyart_soft.png", crop.size)
