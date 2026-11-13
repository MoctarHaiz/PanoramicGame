#!/usr/bin/env python3
"""The panels' ink-brush art (2026-11-13; the user, of three panel styles shown for the pause, the results and the
settings: "C", no box, ink brush: the scene darkened, a wide band of dark ink with dry-brush ends behind the
interface, the titles in gold brush lettering over a fast red stroke, the red leaning button of the menu).

GPT Image 2.6 Sunburst painted the three options over the game's own screens (tools/art/gen/kie/world/panels_*.txt),
then, from the chosen one's crops, the pieces that are pictures in the game, each alone on a transparent background:

    ink_band.png   one thick stroke of black ink, its ends leaning right and breaking into bristle streaks, and a thin
                   red stroke under it
                   -> assets/art/ui/ink_band.png (InkStyle lays several of them one over the other, each stretched
                      in its solid middle only: a band of any size with painted ends), ink_stroke.png (the red one:
                      under a title set in the display font)
    titles_c.png   the panels' titles in the game's two languages, each over its own red stroke
                   -> assets/art/ui/title_<slug>.png (Ui.ink_title; another language's title is set in the display
                      font over ink_stroke.png)
    words_c2.png   RESUME, PLAY AGAIN, REPRENDRE, REJOUER in the heavy slanted white capitals of the menu's PLAY
                   -> assets/art/ui/word_<slug>.png (Ui.cta_button)

A slug is its text in lower case, accents dropped, everything else an underscore (Ui.slug).

    python3 tools/art/kie/panel_ui.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

from menu_ui import UI, WORD_H, box, premult, save

GEN = Path(__file__).resolve().parents[1] / "gen/kie"
TITLES = ["paused", "settings", "home_sweet_home", "game_over", "about",
          "pause", "reglages", "enfin_a_la_maison", "perdu", "a_propos"]  # top to bottom in titles_c.png
TITLE_K = 0.72  # the titles' size in the game, of the painting's (the tallest: 280 px)
WORDS = ["resume", "play_again", "reprendre", "rejouer"]  # top to bottom in words_c2.png
INK = (0.075, 0.05, 0.045)  # the band's ink: a warm black
BAND_W = 1280  # px


def pieces(a: np.ndarray, rows: int) -> list:
    """Its `rows` lines, top to bottom: each connected piece goes with the line whose big piece is nearest."""
    lab, n = ndi.label(a[..., 3] > 0.3)
    area = ndi.sum(a[..., 3] > 0.3, lab, range(1, n + 1))
    at = [c[0] for c in ndi.center_of_mass(a[..., 3] > 0.3, lab, range(1, n + 1))]
    lines = sorted(at[i] for i in np.argsort(area)[-rows:])
    out = []
    for y in lines:
        mine = [i + 1 for i in range(n) if area[i] > 40 and min(lines, key=lambda q: abs(q - at[i])) == y]
        keep = ndi.binary_dilation(np.isin(lab, mine), iterations=4)
        part = a * keep[..., None]
        y0, y1, x0, x1 = box(part, 4, 0.05)
        out.append(part[y0:y1, x0:x1])
    return out


def lines(a: np.ndarray, rows: int) -> list:
    """Its `rows` lines of letters, top to bottom, cut at the widest gaps between them."""
    filled = np.nonzero((a[..., 3] > 0.3).any(axis=1))[0]
    cuts = sorted(filled[i] for i in np.argsort(np.diff(filled))[-(rows - 1):])
    out, y = [], 0
    for c in cuts + [a.shape[0] - 1]:
        part = a[y:c + 1]
        y0, y1, x0, x1 = box(part, 4, 0.3)
        out.append(part[y0:y1, x0:x1])
        y = c + 1
    return out


if __name__ == "__main__":
    for name, part in zip(TITLES, pieces(premult(GEN / "titles_c.png"), len(TITLES))):
        save(part, (round(part.shape[1] * TITLE_K), round(part.shape[0] * TITLE_K)), UI / f"title_{name}.png")
    for name, part in zip(WORDS, lines(premult(GEN / "words_c2.png"), len(WORDS))):
        save(part, (round(part.shape[1] * WORD_H / part.shape[0]), WORD_H), UI / f"word_{name}.png")
    band, stroke = pieces(premult(GEN / "ink_band.png"), 2)
    # the band: its ink in one colour, solid wherever the brush was full (no pinhole shows what is behind a panel)
    al = band[..., 3]
    al = np.where(ndi.binary_fill_holes(al > 0.6), np.maximum(al, np.clip((al - 0.6) / 0.25, 0, 1)), al)
    band = np.dstack([INK[0] * al, INK[1] * al, INK[2] * al, al]).astype(np.float32)
    save(band, (BAND_W, round(band.shape[0] * BAND_W / band.shape[1])), UI / "ink_band.png")
    cols = np.nonzero((al[al.shape[0] * 2 // 5:al.shape[0] * 3 // 5] > 0.97).all(axis=0))[0]
    print("  (solid through its middle band from %.3f to %.3f of its width: InkStyle.END)" % (cols.min() / al.shape[1], cols.max() / al.shape[1]))
    rows = np.nonzero((al[:, al.shape[1] * 2 // 5:al.shape[1] * 3 // 5] > 0.97).all(axis=1))[0]
    print("  (and from %.3f to %.3f of its height)" % (rows.min() / al.shape[0], rows.max() / al.shape[0]))
    save(stroke, (900, round(stroke.shape[0] * 900 / stroke.shape[1])), UI / "ink_stroke.png")
