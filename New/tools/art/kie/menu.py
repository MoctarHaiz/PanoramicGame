#!/usr/bin/env python3
"""The menu's key art: Panoramic, as he was painted, over a landscape in the game's own world (2026-11-12; the blind
judges, round after round: "a hard-outlined cel hero on a soft painterly storm with god rays that never touch him: two
pictures glued together").

He is cut out of the key art as it was (kie.py cutout: Recraft, tools/art/gen/kie/world/menu_hero.png: not a pixel of
him repainted) and laid over the landscape GPT Image 2.6 Sunburst painted for him in the level's style, from the
level's style frame and the old key art's composition (world/menu_bg.txt, then menu_bg2.txt -> menu_bg2.png): the same inked cel painting
and the same low sun from the upper left as his own drawing.

    python3 tools/art/kie/menu.py && python3 tools/art/ui_keyart_soft.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

GEN = Path(__file__).resolve().parents[1] / "gen/kie/world"
UI = Path(__file__).resolve().parents[3] / "assets/art/ui"
SIZE = (2556, 1179)

if __name__ == "__main__":
    # (menu_bg2: the first painting, menu_bg, had him in it in spite of its prompt: a second, smaller Panoramic showed
    # round the cut-out; the model took him out of its own painting, world/menu_bg2.txt. Look at the landscape alone
    # before laying him over it.)
    bg = Image.open(GEN / "menu_bg2.png").convert("RGB")
    w = round(bg.height * SIZE[0] / SIZE[1])  # the menu's shape, cut about the painting's middle
    x = (bg.width - w) // 2
    bg = bg.crop((x, 0, x + w, bg.height)).resize(SIZE, Image.LANCZOS)
    hero = Image.open(GEN / "menu_hero.png").convert("RGBA")
    # (his cut-out's edge drawn in a pixel: none of the old storm sky's grey left round his ink)
    alpha = hero.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    hero.putalpha(alpha)
    bg.paste(hero, (0, 0), hero)
    bg.save(UI / "menu_keyart.png")
    print("wrote", UI / "menu_keyart.png", bg.size)
