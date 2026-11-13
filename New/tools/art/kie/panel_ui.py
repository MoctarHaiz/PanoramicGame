#!/usr/bin/env python3
"""The panels' ink-brush art (2026-11-13; the user, of three panel styles shown for the pause, the results and the
settings: "C", no box, ink brush: the scene darkened, a wide band of dark ink with dry-brush ends behind the
interface, the titles in gold brush lettering over a fast red stroke, the red leaning button of the menu).

GPT Image 2.6 Sunburst painted the three options over the game's own screens (tools/art/gen/kie/world/panels_*.txt),
then, from the chosen one's crops, the pieces that are pictures in the game, each alone on a transparent background:

    ink_band.png   one thick stroke of black ink, its ends leaning right and breaking into bristle streaks, and a thin
                   red stroke under it
                   -> assets/art/ui/ink_band.png (InkStyle: the one stroke behind a panel, stretched in its solid
                      middle only: a band of any size with painted ends), ink_stroke.png (the red one: under a
                      title set in the display font)
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
INK = (0.112, 0.072, 0.058)  # the band's ink: a warm dark brown-black, where the brush was full
INK_DRY = (0.33, 0.215, 0.15)  # ... and where it ran dry: the same ink thinner (a streak's lightest)
INK_POOL = (0.062, 0.038, 0.032)  # ... and where it pooled: along the stroke's edge, in a streak's deepest
BAND_W = 1600  # px
LEAN = 0.12  # the band's two ends lean this much, px a px of its height (the red plates': SlantStyle)


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


def upright(a: np.ndarray, lean: float) -> np.ndarray:
    """The band sheared so its two ends lean as the red plates do, `lean` px a px of height (it was painted leaning
    four times as much: a panel's corners then needed a band far wider than what it holds; blind round 13: "cut the
    band to a compact stroke that hugs its content")."""
    al = a[..., 3] > 0.5
    rows = np.arange(a.shape[0] * 3 // 10, a.shape[0] * 7 // 10)
    left = np.array([np.nonzero(al[y])[0].min() for y in rows])
    right = np.array([np.nonzero(al[y])[0].max() for y in rows])
    painted = -(np.polyfit(rows, left, 1)[0] + np.polyfit(rows, right, 1)[0]) / 2.0  # its top further right
    k = painted - lean  # each row moved left by k px for each row above the middle one
    mid = a.shape[0] / 2.0
    out = np.empty_like(a)
    for q in range(a.shape[2]):
        out[..., q] = ndi.affine_transform(a[..., q], [[1.0, 0.0], [-k, 1.0]], offset=[0.0, k * mid], order=1)
    y0, y1, x0, x1 = box(out, 4, 0.05)
    print("  (the band leaned %.2f, now %.2f)" % (painted, lean))
    return out[y0:y1, x0:x1]


def material(al: np.ndarray) -> np.ndarray:
    """The band's ink over its alpha `al`, as a broad wet brush leaves it: a wash, fuller here and thinner there in
    wide soft passes with no line in them, a darker line where the ink pooled along its outline, the bristles parting
    in a few long dry drags only where the brush leaves (its right end) and along its rough edges, and a fine paper
    grain. (Blind round 12: "a dead, flat pure-black slab"; round 13, of the bristles' streaks drawn all through it:
    "uniform horizontal streaks: scanlines or wood veneer, not a brush".)"""
    rng = np.random.default_rng(12)
    h, w = al.shape

    def cloud(sy: float, sx: float) -> np.ndarray:
        n = ndi.gaussian_filter(rng.standard_normal((h, w)).astype(np.float32), (sy, sx))
        return n / n.std()

    inside = ndi.distance_transform_edt(al > 0.5).astype(np.float32)  # px from its outline
    cols = np.nonzero((al > 0.5).any(axis=0))[0]
    u = (np.arange(w) - cols.min()) / max(cols.max() - cols.min(), 1)
    wash = 0.65 * cloud(h * 0.17, h * 0.5) + 0.35 * cloud(h * 0.06, h * 0.16)  # the brush's load, pass by pass
    thin = np.clip(wash * 0.55 + 0.08, 0.0, 1.0) * 0.3
    leaves = (np.clip((u - 0.6) / 0.32, 0.0, 1.0) ** 1.6)[None, :]  # where the brush leaves, spent
    edge = np.clip(1.0 - inside / (h * 0.07), 0.0, 1.0)  # 1 at the outline, 0 a little inside
    drag = np.clip(cloud(h * 0.011, h * 1.1) - 0.55, 0.0, 1.0)  # a bristle's dry drag: a few, long, far apart
    light = np.clip(thin + drag * (0.75 * leaves + 0.5 * edge) + 0.12 * leaves, 0.0, 1.0)
    deep = np.clip(-wash * 0.5 - 0.15, 0.0, 1.0) * 0.6
    pool = np.clip(1.0 - inside / (h * 0.018), 0.0, 1.0) ** 2 * 0.7  # the pooled line along its outline
    rgb = np.empty((h, w, 3), np.float32)
    for q in range(3):
        c = INK[q] + (INK_DRY[q] - INK[q]) * light
        c = c + (INK_POOL[q] - c) * np.maximum(deep, pool * (1.0 - light))
        rgb[..., q] = c
    grain = ndi.gaussian_filter(rng.standard_normal((h, w)).astype(np.float32), 0.9)
    rgb *= (1.0 + 0.05 * grain / grain.std())[..., None]
    return np.clip(rgb, 0.0, 1.0)


if __name__ == "__main__":
    for name, part in zip(TITLES, pieces(premult(GEN / "titles_c.png"), len(TITLES))):
        save(part, (round(part.shape[1] * TITLE_K), round(part.shape[0] * TITLE_K)), UI / f"title_{name}.png")
    for name, part in zip(WORDS, lines(premult(GEN / "words_c2.png"), len(WORDS))):
        save(part, (round(part.shape[1] * WORD_H / part.shape[0]), WORD_H), UI / f"word_{name}.png")
    band, stroke = pieces(premult(GEN / "ink_band.png"), 2)
    band = upright(band, LEAN)
    # the band: solid wherever the brush was full (no pinhole shows what is behind a panel), its ink a material
    al = band[..., 3]
    al = np.where(ndi.binary_fill_holes(al > 0.6), np.maximum(al, np.clip((al - 0.6) / 0.25, 0, 1)), al)
    band = np.dstack([material(al) * al[..., None], al]).astype(np.float32)
    save(band, (BAND_W, round(band.shape[0] * BAND_W / band.shape[1])), UI / "ink_band.png")
    cols = np.nonzero((al[al.shape[0] * 2 // 5:al.shape[0] * 3 // 5] > 0.97).all(axis=0))[0]
    print("  (solid through its middle band from %.3f to %.3f of its width: InkStyle.END)" % (cols.min() / al.shape[1], cols.max() / al.shape[1]))
    rows = np.nonzero((al[:, al.shape[1] * 2 // 5:al.shape[1] * 3 // 5] > 0.97).all(axis=1))[0]
    print("  (and from %.3f to %.3f of its height)" % (rows.min() / al.shape[0], rows.max() / al.shape[0]))
    save(stroke, (900, round(stroke.shape[0] * 900 / stroke.shape[1])), UI / "ink_stroke.png")
