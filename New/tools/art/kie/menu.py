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

AIR = np.array([0.86, 0.8, 0.9], np.float32)  # the far air: a pale lilac, the sky's colour near the horizon
HORIZON = 0.64  # of the picture's height
AIR_MOST = 0.4  # how much of it at the horizon


def planes(bg: Image.Image) -> Image.Image:
    """The landscape in planes of value behind him (blind round 12: "separate the planes by value: push the mesas and
    the field behind him into a lighter, cooler, softer haze"; he was drawn over mesas as dark, as sharp and as
    saturated as he is): the air is thickest along the horizon, so the far mesas and the far field are drawn toward a
    pale lilac, flatter and a little out of focus there, less with height (the top of the sky keeps its deep blue)
    and none in the foreground (the rocks and the grass at the bottom stay crisp and go a step darker: the near
    plane)."""
    a = np.asarray(bg).astype(np.float32) / 255.0
    soft = np.asarray(bg.filter(ImageFilter.GaussianBlur(2.6))).astype(np.float32) / 255.0
    v = (np.arange(a.shape[0], dtype=np.float32) / a.shape[0])[:, None, None]
    air = np.where(v < HORIZON, np.exp(-((v - HORIZON) / 0.32) ** 2), np.exp(-((v - HORIZON) / 0.13) ** 2))
    a = a + (soft - a) * np.clip(air * 1.2, 0, 1)
    grey = a.mean(axis=2, keepdims=True)
    k = air * AIR_MOST
    a = grey + (a - grey) * (1 - 0.5 * k)  # less colour,
    a = a + (AIR - a) * k  # into the air
    near = np.clip((v - 0.84) / 0.16, 0, 1)
    a = a * (1 - 0.16 * near)
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))


if __name__ == "__main__":
    # (menu_bg2: the first painting, menu_bg, had him in it in spite of its prompt: a second, smaller Panoramic showed
    # round the cut-out; the model took him out of its own painting, world/menu_bg2.txt. Look at the landscape alone
    # before laying him over it.)
    bg = Image.open(GEN / "menu_bg2.png").convert("RGB")
    w = round(bg.height * SIZE[0] / SIZE[1])  # the menu's shape, cut about the painting's middle
    x = (bg.width - w) // 2
    bg = bg.crop((x, 0, x + w, bg.height)).resize(SIZE, Image.LANCZOS)
    bg = planes(bg)
    hero = Image.open(GEN / "menu_hero.png").convert("RGBA")
    # (his cut-out's edge drawn in a pixel: none of the old storm sky's grey left round his ink)
    alpha = hero.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    hero.putalpha(alpha)
    bg.paste(hero, (0, 0), hero)
    bg.save(UI / "menu_keyart.png")
    print("wrote", UI / "menu_keyart.png", bg.size)
