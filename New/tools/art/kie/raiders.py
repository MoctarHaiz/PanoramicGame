#!/usr/bin/env python3
"""The bandits' two looks (2026-11-12; of three designs shown, the user first chose B, the savanna raiders, "and let
me see them in the game", then, having seen them: "use the 2 versions of the bandits"): look b, the savanna raiders
(assets/art/bandit/<kind>.png), and look a, the user's own two bandits redrawn in the hero's proportions
(<kind>_a.png). Each bandit in the game is one or the other (BanditView.LOOKS).

Their motion is the bandits' own: every drawing of the sheets in the game (the run's 12, the stance, the punch's 2,
the recoil, the leap and the jump's 4) is laid on a pose sheet, and GPT Image 2.6 Sunburst redraws each sheet with
the new character in the same pose in the same cell (kie.py --model sunburst --transparent; prompts
tools/art/gen/kie/world/raider_*.txt, the design sheet as its reference). Each redrawn figure is then given the old
drawing's pivot, measured from its own lowest point and its own middle, at the old drawing's size on the whole
(one scale for a sheet: nothing pulses), and packed with the same data as before (frames, heads, the run's pace).

    python3 tools/art/kie/raiders.py pack b|a          gen/kie/raiders/[a_]<kind>_<run|poses>.png -> assets/art/bandit/
    python3 tools/art/kie/raiders.py gif               build/review/raider_runs.gif (the four runs at their pace)
    python3 tools/art/kie/raiders.py sheets            the pose sheets, gen/kie/raiders/<kind>_<run|poses>_sheet.jpg +
                                                       .json: made ONCE, from the bandits' sheets of commit 8e819d2
                                                       (the motion's source); it refuses to make them from a redrawn sheet
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[3]
GEN = NEW / "tools/art/gen/kie/raiders"
ART = NEW / "assets/art/bandit"
KINDS = ("bandit", "bandit_strong")
## a pose sheet: its frames (indices in the old sheet), columns, rows; the cell of the sheet given to the generator
SHEETS = {"run": (list(range(12)), 4, 3), "poses": ([12, 13, 14, 15, 16, 17, 18, 19, 20], 3, 3)}
SHEET_PX = (1920, 1080)
## drawings painted again alone, each from its own prompt (raider_<kind>_<name>.txt): frame -> name
REDONE = {15: "hit"}
FOOT = 34  # px over a cell's bottom edge where a drawing's pivot (the ground under it) is put
PAD = 3
ATLAS_W = 1024


def rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def old_frames(kind: str, ref: str = "") -> tuple:
    """The sheet in the game (or at a git ref) and its data."""
    data = json.loads((ART / f"{kind}.json").read_text())
    return rgba(ART / f"{kind}.png"), data


def middle(a: np.ndarray) -> float:
    """The middle of its trunk: the median opaque column of the middle half of its height (not its cape or braid)."""
    ys, xs = np.nonzero(a[..., 3] > 0.5)
    y0, y1 = ys.min(), ys.max()
    band = (ys > y0 + (y1 - y0) * 0.25) & (ys < y0 + (y1 - y0) * 0.75)
    return float(np.median(xs[band]))


def sheets() -> None:
    if (GEN / "bandit_run_sheet.json").exists():
        raise SystemExit("the pose sheets are made: they come from the bandits' sheets of commit 8e819d2, not from a redrawn one")
    GEN.mkdir(parents=True, exist_ok=True)
    for kind in KINDS:
        atlas, d = old_frames(kind)
        for name, (frames, cols, rows) in SHEETS.items():
            cw, ch = SHEET_PX[0] // cols, SHEET_PX[1] // rows
            tall = max(d["frames"][i][5] for i in frames)  # the tallest reach over a pivot
            k = min((ch - FOOT - 12) / tall, 1.0)
            sheet = Image.new("RGB", SHEET_PX, (226, 222, 214))
            meta = []
            for n, i in enumerate(frames):
                x, y, w, h, px, py = d["frames"][i]
                f = atlas[int(y):int(y + h), int(x):int(x + w)]
                im = Image.fromarray((f * 255 + 0.5).astype(np.uint8), "RGBA").resize((round(w * k), round(h * k)), Image.LANCZOS)
                cx, cy = (n % cols) * cw + cw // 2, (n // cols) * ch + ch - FOOT  # the pivot, in the sheet
                sheet.paste(im, (round(cx - px * k), round(cy - py * k)), im)
                ys, xs = np.nonzero(f[..., 3] > 0.5)
                meta.append({"frame": i, "k": k, "height": float(ys.max() - ys.min() + 1),
                             "under": float(py - (ys.max() + 1)),  # px from its lowest point down to its pivot
                             "aside": float(px - middle(f)), "head": d["head"][i]})
            sheet.save(GEN / f"{kind}_{name}_sheet.jpg", quality=93)
            (GEN / f"{kind}_{name}_sheet.json").write_text(json.dumps(meta))
            print(GEN / f"{kind}_{name}_sheet.jpg", "x%.2f" % k)


def figures(path: Path, cols: int, rows: int) -> list:
    """The figures of a redrawn sheet, each whole (a braid's tuft or a cape's tip apart from it goes with the cell its
    middle is in), premultiplied."""
    a = rgba(path)
    a[..., :3] *= a[..., 3:4]
    h, w = a.shape[:2]
    lab, n = ndi.label(a[..., 3] > 0.3)
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < 300:
            continue
        cy, cx = ndi.center_of_mass(piece)
        owner[i] = int((cy + sl[0].start) / (h / rows)) * cols + int((cx + sl[1].start) / (w / cols))
    out = []
    for c in range(cols * rows):
        mine = np.isin(lab, [i for i, o in owner.items() if o == c])
        ys, xs = np.nonzero(mine)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        soft = ndi.binary_dilation(mine, iterations=3)[y0:y1, x0:x1]
        out.append(a[y0:y1, x0:x1] * soft[..., None])
    return out


def resized(a: np.ndarray, k: float) -> np.ndarray:
    size = (max(round(a.shape[1] * k), 1), max(round(a.shape[0] * k), 1))
    return np.clip(np.dstack([np.asarray(Image.fromarray(a[..., q]).resize(size, Image.LANCZOS)) for q in range(4)]), 0, 1)


def head_of(a: np.ndarray) -> tuple:
    """The middle of its head: the top sixth of its height (its horns or its braid's root with it)."""
    ys, xs = np.nonzero(a[..., 3] > 0.5)
    y0, y1 = ys.min(), ys.max()
    top = ys < y0 + (y1 - y0) * 0.17
    return float(np.median(xs[top])), float(y0 + (y1 - y0) * 0.1)


def pack(look: str) -> None:
    pre, post = ("", "") if look == "b" else ("a_", "_a")
    for kind in KINDS:
        _, old = old_frames(kind)
        frames = {}
        for name, (ids, cols, rows) in SHEETS.items():
            meta = json.loads((GEN / f"{kind}_{name}_sheet.json").read_text())
            figs = figures(GEN / f"{pre}{kind}_{name}.png", cols, rows)
            heights = [np.nonzero(f[..., 3] > 0.5)[0].ptp() + 1 for f in figs]
            # one scale for the sheet: its drawings as tall as the old ones on the whole (the median of the ratios)
            k = float(np.median([m["height"] / h for m, h in zip(meta, heights)]))
            print(f"{kind} {name}: x{k:.3f} (each drawing's own would be",
                  " ".join("%.2f" % (m["height"] / h) for m, h in zip(meta, heights)) + ")")
            for m, f, h in zip(meta, figs, heights):
                one = GEN / f"{pre}{kind}_{REDONE.get(m['frame'], '')}.png"
                if m["frame"] in REDONE and one.exists():
                    # a pose painted again alone (the sheet's came out as another man): as tall as the sheet's was
                    f = figures(one, 1, 1)[0]
                    f = resized(f, h * k / (np.nonzero(f[..., 3] > 0.5)[0].ptp() + 1))
                else:
                    f = resized(f, k)
                ys, xs = np.nonzero(f[..., 3] > 0.5)
                pivot = (middle(f) + m["aside"], float(ys.max() + 1) + m["under"])
                frames[m["frame"]] = (f, pivot)
        order = sorted(frames)
        sizes = [(frames[i][0].shape[1] + 2 * PAD, frames[i][0].shape[0] + 2 * PAD) for i in order]
        at, x, y, row = [], 0, 0, 0
        for w, h in sizes:  # rows of drawings, in their order
            if x + w > ATLAS_W:
                x, y, row = 0, y + row, 0
            at.append((x, y))
            x += w
            row = max(row, h)
        atlas = np.zeros((y + row, ATLAS_W, 4), np.float32)
        rects, heads = [], []
        for i, (ax, ay), (w, h) in zip(order, at, sizes):
            f, (px, py) = frames[i]
            atlas[ay + PAD:ay + PAD + f.shape[0], ax + PAD:ax + PAD + f.shape[1]] = f
            rects.append([ax, ay, w, h, round(px + PAD, 2), round(py + PAD, 2)])
            hx, hy = head_of(f)
            heads.append([round(hx - px, 1), round(hy - py, 1)])
        al = atlas[..., 3:4]
        rgb = np.where(al > 1e-4, atlas[..., :3] / np.maximum(al, 1e-4), 0.0)
        Image.fromarray((np.dstack([rgb, al[..., 0]]).clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(ART / f"{kind}{post}.png")
        data = dict(old)
        data.update({"frames": rects, "head": heads})
        (ART / f"{kind}{post}.json").write_text(json.dumps(data, indent=1))
        print(f"{kind}{post}: {len(rects)} drawings, {atlas.shape[1]}x{atlas.shape[0]}")


def gif() -> None:
    out = NEW / "build/review"
    out.mkdir(parents=True, exist_ok=True)
    strips = []
    for kind in ("bandit", "bandit_a", "bandit_strong", "bandit_strong_a"):
        if (ART / f"{kind}.json").exists():
            strips.append((rgba(ART / f"{kind}.png"), json.loads((ART / f"{kind}.json").read_text())))
    w, h = 460, 400
    n = 24
    pics = []
    for t in range(n):
        im = Image.new("RGB", (w * len(strips), h), (222, 196, 140))
        for j, (atlas, d) in enumerate(strips):
            i = int(t / n * 2 * 12 * d["run_fps"] / max(s[1]["run_fps"] for s in strips)) % 12
            x, y, fw, fh, px, py = d["frames"][i]
            f = Image.fromarray((atlas[int(y):int(y + fh), int(x):int(x + fw)] * 255 + 0.5).astype(np.uint8), "RGBA")
            im.paste(f, (round(j * w + w / 2 - px), round(h - 30 - py)), f)
        pics.append(im)
    pics[0].save(out / "raider_runs.gif", save_all=True, append_images=pics[1:], duration=round(1000 * 2 * 12 / n / max(s[1]["run_fps"] for s in strips)), loop=0)
    print(out / "raider_runs.gif")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "sheets":
        sheets()
    elif cmd == "pack":
        pack(sys.argv[2] if len(sys.argv) > 2 else "b")
    elif cmd == "gif":
        gif()
    else:
        raise SystemExit(__doc__)
