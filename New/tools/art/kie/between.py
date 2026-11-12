#!/usr/bin/env python3
"""A bandit's run from six drawings to twelve: the clip gave one whole stride in six clean drawings (the video model
animated him on twos); played at the pace that holds his boot on the ground that is nine drawings a second, a
stop-motion step. Nano Banana 2 draws the six in-betweens on a chart where each one's cell lies between its two
neighbours: three rows of key, empty, key, empty, key; a row starts on the key the row above ended on, the last row
ends on the first key (the stride loops). (A first chart, 4 x 3 read like a page, left the in-betweens at the row
ends with their next drawing a row away: all of those came out in the wrong part of the stride.)

    python3 tools/art/kie/between.py make CLIP   # gen/kie/CLIP/cycle/00-05.png -> gen/kie/CLIP_between_sheet.png (16:9)
    python3 tools/art/kie/between.py cut CLIP [TO]  # gen/kie/CLIP_between.png (the redraw) -> gen/kie/CLIP/TO/00-11.png
                                                 # (TO: cycle12_b; the first chart's are kept in cycle12_a)
    python3 tools/art/kie/between.py fixmake NAME  # a chart of the gaps still wrong (FIX) -> gen/kie/NAME_sheet.png
    python3 tools/art/kie/between.py fixcut NAME   # gen/kie/NAME.png -> gen/kie/CLIP/fix/NN.png
    python3 tools/art/kie/between.py pick CLIP     # the keys and the in-between chosen for each gap (PICK)
                                                 # -> gen/kie/CLIP/cycle12/00-11.png, gen/kie/CLIP_cycle12.png

The image model does not in-between reliably: of a chart's six, about half are right, the others a near copy of a key
or a moment of a walk. So: two charts, then a third of only the gaps still wrong (FIX), each beside a finished example
(the same moment of the other leg's step, one that came out right); PICK names the drawing used for each gap.

The keys are put back where the clip had them (sheet.slide: the best overlap with the clip's own); an in-between has
no drawing to be laid over: it goes where it was drawn, moved as the two keys beside it were, then its head (his hair)
is brought midway between theirs (the stride's bob stays smooth). `cut` prints, for each in-between, what tells a
drawing from the wrong part of the stride: how like each neighbour it is, and where its lowest boot is.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).parent))
from bandit_pack import head  # noqa: E402
from cells import key, unpink  # noqa: E402
from clip import PINK  # noqa: E402
from sheet import PAD, SCRAP, rgba, slide  # noqa: E402

GEN = Path(__file__).resolve().parents[1] / "gen/kie"
COLS, ROWS = 5, 3
## the chart's cells, row by row: a key of the clip (0-5) or an in-between (the cycle's odd drawings, as "b1".."b11")
CHART = [[0, "b1", 1, "b3", 2], [2, "b5", 3, "b7", 4], [4, "b9", 5, "b11", 0]]


def keys(clip: str) -> tuple:
    fr = [rgba(p) for p in sorted((GEN / clip / "cycle").glob("*.png"))]
    side = max(fr[0].shape[:2])  # square cells
    return fr, side


def squared(a: np.ndarray, side: int) -> np.ndarray:
    out = np.zeros((side, side, 4), np.float32)
    y, x = (side - a.shape[0]) // 2, (side - a.shape[1]) // 2
    out[y:y + a.shape[0], x:x + a.shape[1]] = a
    return out


def layout(side: int) -> tuple:
    """(width, height, left margin) of the chart: 16:9, one of the generator's own shapes."""
    h = ROWS * (side + PAD)
    w = round(h * 16 / 9)
    return w, h, (w - COLS * (side + PAD)) // 2


def make(clip: str) -> None:
    fr, side = keys(clip)
    w, h, left = layout(side)
    sheet = Image.new("RGB", (w, h), (255, 0, 255))
    for r, row in enumerate(CHART):
        for c, what in enumerate(row):
            if isinstance(what, int):
                im = Image.fromarray((squared(fr[what], side) * 255).astype(np.uint8), "RGBA")
                sheet.paste(im, (left + c * (side + PAD) + PAD // 2, r * (side + PAD) + PAD // 2), im)
    out = GEN / (clip + "_between_sheet.png")
    sheet.save(out)
    print(out, sheet.size, "aspect %.3f" % (sheet.width / sheet.height))


def boot(a: np.ndarray) -> tuple:
    """(y, x) of his lowest boot."""
    ys, xs = np.nonzero(a[..., 3] > 0.5)
    return int(ys.max()), int(round(xs[ys >= ys.max() - 5].mean()))


def like(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.minimum(a[..., 3], b[..., 3]).sum() / max(np.maximum(a[..., 3], b[..., 3]).sum(), 1.0))


def hair(a: np.ndarray) -> int:
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    return int(((al > 0.5) & (b > r + 0.15) & (g > r + 0.1)).sum())


## a fixing chart -> its clip, its rows (gap, the folder its in-between is taken from as the example, or None: to draw)
FIX = {"bandit_run_v1_fix": ("bandit_run_v1", [(9, "cycle12_a"), (3, None)]),
       "strong_run_v1_fix": ("strong_run_v1", [(9, "cycle12_b"), (3, None), (1, "cycle12_b"), (7, None)]),
       # (its gap 3 came out late in the 4-row chart: the planted boot already where the push-off has it)
       "strong_run_v1_fix3": ("strong_run_v1", [(9, "cycle12_b"), (3, None)])}
KEPT = {"strong_run_v1_fix": [7]}  # the gaps taken from a chart (all it drew, unless named here)
MIRRORED = {("bandit_run_v1", 3)}  # drawn facing the other way ("the same moment on his other leg"): turned back
## clip -> gap -> the folder its in-between is taken from
PICK = {"bandit_run_v1": {1: "cycle12_b", 3: "fix", 5: "cycle12_b", 7: "cycle12_b", 9: "cycle12_a", 11: "cycle12_b"},
        "strong_run_v1": {1: "cycle12_b", 3: "fix", 5: "cycle12_b", 7: "fix", 9: "cycle12_b", 11: "cycle12_b"}}


def half(a: np.ndarray, side: int) -> Image.Image:
    return Image.fromarray((a * 255).astype(np.uint8), "RGBA").resize((side, side), Image.LANCZOS)


def fixmake(name: str) -> None:
    clip, rows = FIX[name]
    fr, side = keys(clip)
    sheet = Image.new("RGB", (3 * (side + PAD), len(rows) * (side + PAD)), (255, 0, 255))
    for r, (gap, src) in enumerate(rows):
        cells = [half(squared(fr[(gap - 1) // 2], side), side), None, half(squared(fr[((gap + 1) // 2) % 6], side), side)]
        if src:
            cells[1] = half(rgba(GEN / clip / src / ("%02d.png" % gap)), side)
        for c, im in enumerate(cells):
            if im is not None:
                sheet.paste(im, (c * (side + PAD) + PAD // 2, r * (side + PAD) + PAD // 2), im)
    out = GEN / (name + "_sheet.png")
    sheet.save(out)
    print(out, sheet.size, "aspect %.3f" % (sheet.width / sheet.height))


def cell_of(keyed: np.ndarray, lab: np.ndarray, owner: dict, who: str, idx: int, box: tuple, side: int) -> np.ndarray:
    """One cell of a keyed chart, whole (the pieces whose middle is in it), at twice the clip's size."""
    x0, y0, w, h = box
    mine = ndi.binary_dilation(np.isin(lab, [i for i, o in owner.items() if o == idx]), iterations=4)
    cell = keyed[y0:y0 + h, x0:x0 + w].copy()
    cell[..., 3] *= mine[y0:y0 + h, x0:x0 + w]
    if who in PINK:
        cell = unpink(cell, *PINK[who])
    pm = cell.copy()
    pm[..., :3] *= pm[..., 3:4]
    q = np.clip(np.dstack([np.asarray(Image.fromarray(pm[..., j]).resize((side * 2, side * 2), Image.LANCZOS)) for j in range(4)]), 0, 1)
    al = q[..., 3:4]
    return np.dstack([np.where(al > 1e-4, q[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]])


def fixcut(name: str) -> None:
    clip, rows = FIX[name]
    fr, side = keys(clip)
    img = Image.open(GEN / (name + ".png")).convert("RGB")
    k, ky = img.width / (3 * (side + PAD)), img.height / (len(rows) * (side + PAD))
    keyed = key(np.asarray(img).astype(np.float32) / 255.0)
    lab, n = ndi.label(ndi.binary_opening(keyed[..., 3] > 0.5, iterations=2))
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < SCRAP:
            continue
        cy, cx = ndi.center_of_mass(piece)
        owner[i] = int((cy + sl[0].start) / (img.height / len(rows))) * 3 + int((cx + sl[1].start) / (img.width / 3))
    dst = GEN / clip / "fix"
    dst.mkdir(exist_ok=True)
    report = []
    for r, (gap, src) in enumerate(rows):
        if src or gap not in KEPT.get(name, [gap]):
            continue
        got = []
        for c in range(3):
            box = (round((c * (side + PAD) + PAD // 2) * k), round((r * (side + PAD) + PAD // 2) * ky), round(side * k), round(side * ky))
            got.append(cell_of(keyed, lab, owner, clip.split("_")[0], r * 3 + c, box, side))
        if (clip, gap) in MIRRORED:
            got[1] = got[1][:, ::-1]
        placed, moves = [], []
        for c, ki in ((0, (gap - 1) // 2), (2, ((gap + 1) // 2) % 6)):
            ref = squared(fr[ki], side)
            ref = np.dstack([np.asarray(Image.fromarray(ref[..., j]).resize((side * 2, side * 2), Image.BILINEAR)) for j in range(4)])
            mv, fit = slide(got[c], ref, False)
            moves.append(mv)
            placed.append(ndi.shift(got[c], (mv[0], mv[1], 0), order=0, mode="constant"))
        dy, dx = (moves[0][0] + moves[1][0]) / 2.0, (moves[0][1] + moves[1][1]) / 2.0
        moved = ndi.shift(got[1], (round(dy), round(dx), 0), order=0, mode="constant")
        want = (np.array(head(placed[0])) + np.array(head(placed[1]))) / 2.0
        d = want - np.array(head(moved))
        res = ndi.shift(moved, (round(d[1]), round(d[0]), 0), order=0, mode="constant")
        Image.fromarray((np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(dst / ("%02d.png" % gap))
        report.append("%d: head %+d,%+d; lowest boot y,x: before %s, his %s, after %s" % (gap, round(d[0]), round(d[1]), boot(placed[0]), boot(res), boot(placed[1])))
    print(clip, "x%.3f" % k, "; ".join(report))


def pick(clip: str) -> None:
    out = []
    for i in range(12):
        src = "cycle12_b" if i % 2 == 0 else PICK[clip][i]
        out.append(rgba(GEN / clip / src / ("%02d.png" % i)))
    side = out[0].shape[0] // 2
    for i in range(1, 12, 2):  # (a drawing of another chart: its head midway between these keys')
        want = (np.array(head(out[i - 1])) + np.array(head(out[(i + 1) % 12]))) / 2.0
        d = want - np.array(head(out[i]))
        out[i] = ndi.shift(out[i], (round(d[1]), round(d[0]), 0), order=0, mode="constant")
    dst = GEN / clip / "cycle12"
    dst.mkdir(exist_ok=True)
    for f in dst.glob("*.png"):
        f.unlink()
    for c, a in enumerate(out):
        Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(dst / ("%02d.png" % c))
    print(clip, "lowest boots y,x:", " ".join("%d:%s" % (i, boot(a)) for i, a in enumerate(out)))
    prev = Image.new("RGB", (side * 6, side * 2), (158, 184, 219))
    for i, a in enumerate(out):
        t = half(a, side)
        prev.paste(t, ((i % 6) * side, (i // 6) * side), t)
    prev.save(GEN / (clip + "_cycle12.png"))


def cut(clip: str, to: str = "cycle12_b") -> None:
    fr, side = keys(clip)
    w0, h0, left = layout(side)
    img = Image.open(GEN / (clip + "_between.png")).convert("RGB")
    k, ky = img.width / w0, img.height / h0
    keyed = key(np.asarray(img).astype(np.float32) / 255.0)
    who = clip.split("_")[0]
    lab, n = ndi.label(ndi.binary_opening(keyed[..., 3] > 0.5, iterations=2))
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < SCRAP:
            continue
        cy, cx = ndi.center_of_mass(piece)
        col = int(np.clip(((cx + sl[1].start) / k - left) / (side + PAD), 0, COLS - 1))
        owner[i] = int((cy + sl[0].start) / (img.height / ROWS)) * COLS + col
    cells = {}
    for r in range(ROWS):
        for c in range(COLS):
            mine = ndi.binary_dilation(np.isin(lab, [i for i, o in owner.items() if o == r * COLS + c]), iterations=4)
            x0 = round((left + c * (side + PAD) + PAD // 2) * k)
            y0 = round((r * (side + PAD) + PAD // 2) * ky)
            w, h = round(side * k), round(side * ky)
            cell = keyed[y0:y0 + h, x0:x0 + w].copy()
            cell[..., 3] *= mine[y0:y0 + h, x0:x0 + w]
            if who in PINK:
                cell = unpink(cell, *PINK[who])
            pm = cell.copy()
            pm[..., :3] *= pm[..., 3:4]
            q = np.clip(np.dstack([np.asarray(Image.fromarray(pm[..., j]).resize((side * 2, side * 2), Image.LANCZOS)) for j in range(4)]), 0, 1)
            al = q[..., 3:4]
            cells[r, c] = np.dstack([np.where(al > 1e-4, q[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]])
    out, moves, report = [None] * 12, {}, []
    for r, row in enumerate(CHART):  # the keys: back onto the clip's own drawing
        for c, what in enumerate(row):
            if not isinstance(what, int):
                continue
            ref = squared(fr[what], side)
            ref = np.dstack([np.asarray(Image.fromarray(ref[..., j]).resize((side * 2, side * 2), Image.BILINEAR)) for j in range(4)])
            moves[r, c], fit = slide(cells[r, c], ref, False)
            if out[what * 2] is None:
                out[what * 2] = ndi.shift(cells[r, c], (moves[r, c][0], moves[r, c][1], 0), order=0, mode="constant")
                report.append("%d: %+d,%+d fit %.2f" % (what * 2, moves[r, c][1], moves[r, c][0], fit))
    for r, row in enumerate(CHART):  # the in-betweens: moved as the keys beside them, their head midway between theirs
        for c, what in enumerate(row):
            if isinstance(what, int):
                continue
            i = int(what[1:])
            a, b = out[i - 1], out[(i + 1) % 12]
            dy = (moves[r, c - 1][0] + moves[r, c + 1][0]) / 2.0
            dx = (moves[r, c - 1][1] + moves[r, c + 1][1]) / 2.0
            moved = ndi.shift(cells[r, c], (round(dy), round(dx), 0), order=0, mode="constant")
            want = (np.array(head(a)) + np.array(head(b))) / 2.0
            d = want - np.array(head(moved))
            out[i] = ndi.shift(moved, (round(d[1]), round(d[0]), 0), order=0, mode="constant")
            report.append("%d: head %+d,%+d" % (i, round(d[0]), round(d[1])))
    dst = GEN / clip / to
    dst.mkdir(exist_ok=True)
    for f in dst.glob("*.png"):
        f.unlink()
    for c, a in enumerate(out):
        Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(dst / ("%02d.png" % c))
    print(clip, "x%.3f" % k, "; ".join(report))
    for i in range(1, 12, 2):
        a, b = out[i - 1], out[(i + 1) % 12]
        print("  %2d: like the one before %.2f, the one after %.2f (those two: %.2f); lowest boot y,x: before %s, his %s, after %s; "
              "hair x%.2f of theirs" % (i, like(out[i], a), like(out[i], b), like(a, b), boot(a), boot(out[i]), boot(b),
                                         hair(out[i]) * 2.0 / max(hair(a) + hair(b), 1)))
    prev = Image.new("RGB", (side * 6, side * 2), (158, 184, 219))
    for i, a in enumerate(out):
        t = Image.fromarray((a * 255).astype(np.uint8), "RGBA").resize((side, side), Image.LANCZOS)
        prev.paste(t, ((i % 6) * side, (i // 6) * side), t)
    prev.save(GEN / (clip + "_between_cut.png"))


if __name__ == "__main__":
    {"make": make, "cut": cut, "fixmake": fixmake, "fixcut": fixcut, "pick": pick}[sys.argv[1]](*sys.argv[2:])
