#!/usr/bin/env python3
"""The menu's inked interface art (2026-11-13; the user, of three interfaces shown: "the A, inked gold, but with the
RED play in the C, bold action").

GPT Image 2.6 Sunburst painted the three whole-screen options (tools/art/gen/kie/world/menu_ui_[abc].txt), then, from
the chosen ones' crops, the two pieces that are pictures in the game, each alone on a transparent background:

    logo_a.png   the title: angular gold lettering, inked, over a cowhide shield and two crossed spears
                 -> assets/art/ui/logo.png (the menu, the settings' mark, the share card)
    words_c.png  PLAY and JOUER (the game's two languages) in heavy slanted white capitals with an ink line
                 -> assets/art/ui/word_play.png, word_jouer.png (Ui.cta_button lays the word of the language on its
                    plate; another language's word is set in the display font)

The red plate itself, the subtitle's band, the score's plate and the gear are drawn by the game (SlantStyle, Ui).

    python3 tools/art/kie/menu_ui.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

GEN = Path(__file__).resolve().parents[1] / "gen/kie/world"
UI = Path(__file__).resolve().parents[3] / "assets/art/ui"
LOGO_W = 1300  # px (the old logo: 1150)
WORD_H = 150  # px: each word's height
WORDS = ["play", "jouer"]  # top to bottom in words_c.png


def premult(path) -> np.ndarray:
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def save(a: np.ndarray, size, path: Path) -> None:
    r = np.clip(np.dstack([np.asarray(Image.fromarray(a[..., q]).resize(size, Image.LANCZOS)) for q in range(4)]), 0, 1)
    al = r[..., 3:4]
    rgb = np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), 0.0)
    Image.fromarray((np.dstack([rgb, al[..., 0]]).clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print(path.name, size)


def box(a: np.ndarray, pad=6, over=0.02):
    ys, xs = np.nonzero(a[..., 3] > over)
    return max(ys.min() - pad, 0), ys.max() + pad + 1, max(xs.min() - pad, 0), xs.max() + pad + 1


if __name__ == "__main__":
    logo = premult(GEN / "logo_a.png")
    y0, y1, x0, x1 = box(logo)
    logo = logo[y0:y1, x0:x1]
    save(logo, (LOGO_W, round(logo.shape[0] * LOGO_W / logo.shape[1])), UI / "logo.png")
    ys, xs = np.nonzero(logo[..., 3] > 0.5)
    print("  (its lettering: measure LETTERS_U on it if the menu's gear touches it)")
    words = premult(GEN / "words_c.png")
    rows = np.nonzero((words[..., 3] > 0.3).any(axis=1))[0]
    cut = rows[np.argmax(np.diff(rows))]  # the gap between the two lines
    for name, part in zip(WORDS, (words[:cut + 1], words[cut + 1:])):
        y0, y1, x0, x1 = box(part, 4, 0.3)  # (the letters themselves: a faint haze lay between the two lines)
        part = part[y0:y1, x0:x1]
        save(part, (round(part.shape[1] * WORD_H / part.shape[0]), WORD_H), UI / f"word_{name}.png")
