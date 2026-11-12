#!/usr/bin/env python3
"""A clip's cycle to a sheet for Nano Banana 2 and back.

    python3 tools/art/kie/sheet.py make CLIP [COLS] [FROM]  # gen/kie/CLIP/cycle/NN.png (or gen/kie/FROM/NN.png, a sheet
                                                             # cut before) -> gen/kie/CLIP_sheet.png (or FROM_sheet.png),
                                                             # the drawings in COLS columns (4) on flat magenta
    python3 tools/art/kie/sheet.py cut NAME CLIP [COLS] [legs]  # gen/kie/NAME.png, a redraw of that sheet (cleaned,
                                                             # or the arms changed) -> gen/kie/NAME/NN.png

The video model gives the motion (every pose of the stride, in place, bobbing as filmed) but soft, smeared drawings;
the image model redraws the sheet crisp without moving a limb. Each redrawn figure is put back where the clip had it,
on the clip's canvas at twice its size with a margin round it (an arm thrown forward reaches past the clip's frame):
slid to the best overlap with the clip's drawing (legs: of its lower half only, for a sheet whose arms were changed),
so the cycle keeps the clip's own movement from drawing to drawing.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).parent))
from cells import key, unpink  # noqa: E402
from clip import PINK  # noqa: E402

GEN = Path(__file__).resolve().parents[1] / "gen/kie"
PAD = 30  # px of magenta between the cells of the sheet given to the generator
UP = 2  # the cut drawings are kept at this many times the clip's size
MARGIN = 2 * PAD  # clip px of room kept round the clip's canvas in the cut drawings
SCRAP = 800  # redraw px: a detached piece smaller than this is a speck, not a part of him


def rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def make(clip: str, cols: int, frm: str) -> None:
    if frm:  # (drawings cut before: back at the clip's size and canvas, so every sheet has the same cells)
        fr = []
        for p in sorted((GEN / frm).glob("[0-9][0-9].png")):
            f = Image.open(p).convert("RGBA")
            f = f.crop((MARGIN * UP, MARGIN * UP, f.width - MARGIN * UP, f.height - MARGIN * UP))
            fr.append(f.resize((f.width // UP, f.height // UP), Image.LANCZOS))
    else:
        fr = [Image.open(p).convert("RGBA") for p in sorted((GEN / clip / "cycle").glob("*.png"))]
    cw, ch = fr[0].size
    rows = (len(fr) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cw + PAD), rows * (ch + PAD)), (255, 0, 255))
    for i, f in enumerate(fr):
        sheet.paste(f, ((i % cols) * (cw + PAD) + PAD // 2, (i // cols) * (ch + PAD) + PAD // 2), f)
    out = GEN / ((frm or clip) + "_sheet.png")
    sheet.save(out)
    print(out, sheet.size, "aspect %.3f" % (sheet.width / sheet.height))


def overlap(a: np.ndarray, r: np.ndarray, w: np.ndarray, dy: int, dx: int) -> float:
    s = np.roll(np.roll(a, dy, axis=0), dx, axis=1)
    return float((np.minimum(s, r) * w).sum() / max((np.maximum(s, r) * w).sum(), 1.0))


def slide(a: np.ndarray, ref: np.ndarray, legs: bool) -> tuple:
    """The (dy, dx) that lays `a` best over `ref` (their outlines: at a quarter of the size, then to the pixel)."""
    w = np.ones(ref.shape[:2], np.float32)
    if legs:
        ys = np.nonzero(ref[..., 3].max(axis=1) > 0.5)[0]
        w[: int(ys.min() + (ys.max() - ys.min()) * 0.56)] = 0.0

    def small(x):
        return np.asarray(Image.fromarray(x).resize((x.shape[1] // 4, x.shape[0] // 4), Image.BILINEAR))

    sa, sr, sw = small(a[..., 3]), small(ref[..., 3]), small(w)
    best = max(((overlap(sa, sr, sw, dy, dx), dy, dx) for dy in range(-7, 8) for dx in range(-7, 8)))
    fine = max(((overlap(a[..., 3], ref[..., 3], w, dy, dx), dy, dx)
                for dy in range(best[1] * 4 - 3, best[1] * 4 + 4) for dx in range(best[2] * 4 - 3, best[2] * 4 + 4)))
    return (fine[1], fine[2]), fine[0]


def cut(name: str, clip: str, cols: int, legs: bool) -> None:
    refs = [rgba(p) for p in sorted((GEN / clip / "cycle").glob("*.png"))]
    ch, cw = refs[0].shape[:2]
    rows = (len(refs) + cols - 1) // cols
    img = Image.open(GEN / (name + ".png")).convert("RGB")
    k = img.width / (cols * (cw + PAD))  # the redraw's px a sheet px
    ky = img.height / (rows * (ch + PAD))
    keyed = key(np.asarray(img).astype(np.float32) / 255.0)
    who = clip.split("_")[0]
    out = GEN / name
    out.mkdir(exist_ok=True)
    for f in out.glob("*.png"):
        f.unlink()
    # each figure whole: the pieces of the keyed sheet whose middle falls in its cell (an arm or a scarf's tip may
    # cross into the next cell); specks dropped
    lab, n = ndi.label(ndi.binary_opening(keyed[..., 3] > 0.5, iterations=2))
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < SCRAP:
            continue
        cy, cx = ndi.center_of_mass(piece)
        owner[i] = int((cy + sl[0].start) / (img.height / rows)) * cols + int((cx + sl[1].start) / (img.width / cols))
    report = []
    m = round(MARGIN * k)
    for c in range(len(refs)):
        mine = ndi.binary_dilation(np.isin(lab, [i for i, o in owner.items() if o == c]), iterations=4)
        x0 = round(((c % cols) * (cw + PAD) + PAD // 2) * k)
        y0 = round(((c // cols) * (ch + PAD) + PAD // 2) * ky)
        w, h = round(cw * k), round(ch * ky)
        # the cell and MARGIN round it, as far as the sheet goes
        ya, xa = max(y0 - m, 0), max(x0 - m, 0)
        cell = keyed[ya:y0 + h + m, xa:x0 + w + m].copy()
        cell[..., 3] *= mine[ya:y0 + h + m, xa:x0 + w + m]
        if who in PINK:
            cell = unpink(cell, *PINK[who])
        pm = cell.copy()
        pm[..., :3] *= pm[..., 3:4]
        size = (round(cell.shape[1] * UP / k), round(cell.shape[0] * UP / ky))
        r = np.clip(np.dstack([np.asarray(Image.fromarray(pm[..., q]).resize(size, Image.LANCZOS)) for q in range(4)]), 0, 1)
        al = r[..., 3:4]
        big = np.dstack([np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]])
        canvas = np.zeros(((ch + 2 * MARGIN) * UP, (cw + 2 * MARGIN) * UP, 4), np.float32)
        oy, ox = round((ya - (y0 - m)) * UP / ky), round((xa - (x0 - m)) * UP / k)
        hh, ww = min(big.shape[0], canvas.shape[0] - oy), min(big.shape[1], canvas.shape[1] - ox)
        canvas[oy:oy + hh, ox:ox + ww] = big[:hh, :ww]
        ref = np.zeros_like(canvas)
        ref[MARGIN * UP:MARGIN * UP + ch * UP, MARGIN * UP:MARGIN * UP + cw * UP] = np.dstack(
            [np.asarray(Image.fromarray(refs[c][..., q]).resize((cw * UP, ch * UP), Image.BILINEAR)) for q in range(4)])
        (dy, dx), fit = slide(canvas, ref, legs)
        moved = ndi.shift(canvas, (dy, dx, 0), order=0, mode="constant")
        Image.fromarray((np.clip(moved, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(out / ("%02d.png" % c))
        # (drawn up to the sheet's own edge: the generator had no room for the rest of it)
        yb, xb = min(y0 + h + m, img.height), min(x0 + w + m, img.width)
        solid = keyed[..., 3] * mine > 0.5
        cutoff = (xb == img.width and solid[ya:yb, -3:].any()) or (xa == 0 and solid[ya:yb, :3].any()) \
            or (ya == 0 and solid[:3, xa:xb].any()) or (yb == img.height and solid[-3:, xa:xb].any())
        report.append("%d: %+d,%+d fit %.2f%s" % (c, dx, dy, fit, " CUT AT THE SHEET'S EDGE" if cutoff else ""))
    print(name, "x%.3f slid" % k, "; ".join(report))
    tiles = [Image.open(p) for p in sorted(out.glob("*.png"))]
    tw, th = tiles[0].width // 2, tiles[0].height // 2
    prev = Image.new("RGB", (tw * min(6, len(tiles)), th * ((len(tiles) + 5) // 6)), (158, 184, 219))
    for i, t in enumerate(tiles):
        t = t.resize((tw, th), Image.LANCZOS)
        prev.paste(t, ((i % 6) * tw, (i // 6) * th), t)
    prev.save(GEN / (name + "_cut.png"))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "make":
        make(a[1], int(a[2]) if len(a) > 2 else 4, a[3] if len(a) > 3 else "")
    else:
        cut(a[1], a[2], int(a[3]) if len(a) > 3 else 4, len(a) > 4 and a[4] == "legs")
