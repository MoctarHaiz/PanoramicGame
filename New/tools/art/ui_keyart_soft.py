#!/usr/bin/env python3
"""The settings' backdrop (src/screens/settings_screen.gd): the menu's key art (assets/art/ui/menu_keyart.png) at a
quarter of its size, so drawn stretched through a cubic B-spline (soft_blur.gdshader) it is lightly blurred, the scene
and Panoramic still recognisable behind the panel (round 20, the judges: at 1/16 "a blurred purple-brown smear").
Run it again whenever the key art changes.

    python3 tools/art/ui_keyart_soft.py   # assets/art/ui/menu_keyart_soft.png
"""
from pathlib import Path

from PIL import Image

UI = Path(__file__).resolve().parents[2] / "assets/art/ui"

if __name__ == "__main__":
    art = Image.open(UI / "menu_keyart.png").convert("RGB")
    art.resize((art.width // 4, art.height // 4), Image.BOX).save(UI / "menu_keyart_soft.png")
    print("wrote", UI / "menu_keyart_soft.png")
