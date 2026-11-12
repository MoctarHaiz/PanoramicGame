#!/usr/bin/env python3
"""The level's backdrop from its painted layers (2026-11-12, the world redesign).

GPT Image 2.6 Sunburst (kie.py --model sunburst: chosen over Seedream 5.5 on one style frame, world/frame.txt) painted
the frame, then each layer of it alone on a transparent background, with the frame as its reference
(tools/art/gen/kie/world/NAME.txt -> NAME.png). This cuts them into the pictures SavannaView draws:

    sky.png              the sky's panorama, repeating left to right
    far_wall.png         the far escarpment (a strip: its top part, the rest is behind the plain)
    far_mesa_pieces.png  twelve landforms, each alone (+ .json: where, what kind)
    far_hills.png        the plain, from its horizon down (a strip)
    mid_hills.png        the middle-ground rise (a strip)
    near_grass.png       the tall grass behind the path (a strip)
    tree_*.png           ten trees (+ tree_info.json: the foot of each trunk)
    fg_props.png         six plants and rocks near the camera

    python3 tools/art/kie/world.py [sky wall mesas plain rise grass trees front]   (none: all)

A strip repeats: its right end is laid over its left end along the path where the two differ least (the plain, the
grass), or faded across it (the sky, the far wall: smooth things), and that much is cut off its width.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

GEN = Path(__file__).resolve().parents[1] / "gen/kie/world"
OUT = Path(__file__).resolve().parents[3] / "assets/art/world"
## landform kinds, in the sheet's order (SavannaView.MESA_KINDS: a spire stands taller and sinks at dusk, a low one squats)
MESA_KINDS = ["block", "block", "arch", "spire", "low", "block", "block", "spire", "arch", "low", "spire", "low"]
TREES = ["tree_acacia_1", "tree_acacia_2", "tree_acacia_3", "tree_acacia_4", "tree_acacia_5",
         "tree_baobab_1", "tree_baobab_2", "tree_baobab_3", "tree_acacia_6", "tree_baobab_4"]
## how big each tree is kept (of the sheet's px): the four tall ones stand big behind the tall grass (SavannaView
## .TREE_TALL: 232 units), two are level props too (PropView: 140 to 150 units), the others are small and far
TREE_SCALE = {"tree_acacia_2": 0.9, "tree_acacia_5": 0.9, "tree_baobab_2": 0.9, "tree_baobab_4": 0.9,
              "tree_acacia_1": 0.6, "tree_acacia_3": 0.6}
FRONT_CELL = (440, 390)  # px: SavannaView.FRONT_PROP at 1.7 px a unit (dark shapes passing fast: no finer)


def load(name) -> np.ndarray:
    """Premultiplied RGBA, 0..1."""
    a = np.asarray(Image.open(GEN / (name + ".png")).convert("RGBA")).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def save(a: np.ndarray, path: Path, opaque=False) -> None:
    al = a[..., 3:4]
    rgb = np.where(al > 1e-4, a[..., :3] / np.maximum(al, 1e-4), 0.0)
    out = (np.clip(np.dstack([rgb, al[..., 0]]), 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(out, "RGBA").convert("RGB" if opaque else "RGBA").save(path)
    print("%s %dx%d" % (path.name, out.shape[1], out.shape[0]))


def resize(a: np.ndarray, size) -> np.ndarray:
    return np.clip(np.dstack([np.asarray(Image.fromarray(a[..., q]).resize(size, Image.LANCZOS)) for q in range(4)]), 0, 1)


def fade(a: np.ndarray, b: int) -> np.ndarray:
    """Repeats left to right: the last `b` columns faded over the first `b`."""
    t = np.linspace(0.0, 1.0, b, dtype=np.float32)
    t = (t * t * (3 - 2 * t))[None, :, None]
    zone = a[:, -b:] * (1 - t) + a[:, :b] * t
    return np.concatenate([zone, a[:, b:-b]], axis=1)


def seam(a: np.ndarray, b: int, feather=5.0) -> np.ndarray:
    """Repeats left to right: the last `b` columns joined to the first `b` along the top-to-bottom path where the two
    differ least (a blade of grass is one end's or the other's, never a ghost of both)."""
    end, start = a[:, -b:], a[:, :b]
    cost = ((end - start) ** 2).sum(axis=-1) + 1e-5
    lo, hi = int(b * 0.12), int(b * 0.88)
    cost[:, :lo] += 10.0
    cost[:, hi:] += 10.0
    acc = cost.copy()
    for y in range(1, acc.shape[0]):
        prev = acc[y - 1]
        acc[y] += np.minimum(prev, np.minimum(np.roll(prev, 1), np.roll(prev, -1)))
    path = np.zeros(acc.shape[0], np.int64)
    path[-1] = int(np.argmin(acc[-1]))
    for y in range(acc.shape[0] - 2, -1, -1):
        x = path[y + 1]
        x0, x1 = max(x - 1, 0), min(x + 2, b)
        path[y] = x0 + int(np.argmin(acc[y, x0:x1]))
    m = (np.arange(b)[None, :] > path[:, None]).astype(np.float32)  # 1: the start's side
    m = ndi.gaussian_filter1d(m, feather, axis=1)[..., None]
    zone = end * (1 - m) + start * m
    return np.concatenate([zone, a[:, b:-b]], axis=1)


def top_edge(a: np.ndarray, share=0.5) -> int:
    """The first row that is solid across `share` of the width."""
    return int(np.nonzero((a[..., 3] > 0.5).mean(axis=1) > share)[0].min())


def sky() -> None:
    a = load("sky2")
    # its two ends brought to the same colour, row by row, over a long reach (the painter left one end warmer: a faint
    # column where the picture repeats), then faded across each other
    reach = 800
    d = ndi.gaussian_filter1d(a[:, -40:].mean(axis=1) - a[:, :40].mean(axis=1), 14.0, axis=0)
    ramp = np.linspace(1.0, 0.0, reach, dtype=np.float32)
    ramp = (ramp * ramp * (3 - 2 * ramp))[None, :, None]
    a[:, :reach] += 0.5 * d[:, None, :] * ramp
    a[:, -reach:] -= 0.5 * d[:, None, :] * ramp[:, ::-1]
    out = np.clip(fade(a, 300), 0, 1)
    out = resize(out, (3072, round(out.shape[0] * 3072 / out.shape[1])))  # (soft clouds, far away: 1.7 px a unit)
    out[..., 3] = 1.0
    save(out, OUT / "sky.png", opaque=True)


def wall() -> None:
    a = load("wall")
    top = top_edge(a, 0.02)
    out = fade(a[top - 12:top + 300], 256)
    out = resize(out, (out.shape[1] // 2, out.shape[0] // 2))  # (far and faint: 1 px a unit)
    save(out, OUT / "far_wall.png")


def plain() -> None:
    a = load("plain")
    first = top_edge(a, 0.004)  # (the smoke's top, the baobab's crown)
    line = top_edge(a, 0.97)  # the horizon
    out = seam(a[first - 8:line + 216], 256)  # (its horizon at y 432: 216 px reach under the rise's top edge)
    save(out, OUT / "far_hills.png")
    print("  horizon at row %d of it" % (line - first + 8))


def rise() -> None:
    a = load("rise")
    first = top_edge(a, 0.004)
    line = top_edge(a, 0.97)
    out = seam(a[first - 8:line + 232], 256)  # (solid from y 532: 232 px reach the screen's bottom edge)
    save(out, OUT / "mid_hills.png")
    print("  solid from row %d of it" % (line - first + 8))


def grass() -> None:
    a = load("grass")
    first = top_edge(a, 0.004)
    line = top_edge(a, 0.97)
    out = seam(a[first - 8:line + 130], 256)  # (solid from y 584: 130 px reach under the screen's bottom edge)
    save(out, OUT / "near_grass.png")
    print("  solid from row %d of it" % (line - first + 8))


def pieces(name: str, cols: int, rows: int) -> list:
    """The figures of a sheet, each whole, in the grid's order (a twig or a cap stone apart from its figure goes with
    the cell its middle is in)."""
    a = load(name)
    h, w = a.shape[:2]
    lab, n = ndi.label(a[..., 3] > 0.3)
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < 400:
            continue
        cy, cx = ndi.center_of_mass(piece)
        owner[i] = int((cy + sl[0].start) / (h / rows)) * cols + int((cx + sl[1].start) / (w / cols))
    out = []
    for c in range(cols * rows):
        mine = np.isin(lab, [i for i, o in owner.items() if o == c])
        ys, xs = np.nonzero(mine)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        soft = ndi.binary_dilation(mine, iterations=3)[y0:y1, x0:x1]  # (its antialiased edge with it)
        cut = a[y0:y1, x0:x1].copy() * soft[..., None]
        out.append(cut)
    return out


def flat_foot(p: np.ndarray) -> np.ndarray:
    """Its last rows are its foot, cut straight: nothing thinner than half of the foot's width is left under it."""
    full = (p[..., 3] > 0.5).sum(axis=1)
    wide = np.nonzero(full >= 0.5 * full[-40:].max())[0].max()
    return p[:wide + 1]


def mesas() -> None:
    ps = [flat_foot(p) for p in pieces("mesas", 4, 3)]
    ps = [resize(p, (p.shape[1] // 2, p.shape[0] // 2)) for p in ps]
    cell = max(p.shape[0] for p in ps) + 6
    width = 2048
    spots, x, y = [], 0, 0
    for p in ps:
        if x + p.shape[1] > width:
            x, y = 0, y + cell
        spots.append((x, y))
        x += p.shape[1] + 6
    atlas = np.zeros((y + cell, width, 4), np.float32)
    info = []
    for p, (x, y), kind in zip(ps, spots, MESA_KINDS):
        atlas[y + cell - p.shape[0]:y + cell, x:x + p.shape[1]] = p  # (standing on its cell's foot)
        info.append([x, y, p.shape[1], kind])
    save(atlas, OUT / "far_mesa_pieces.png")
    (OUT / "far_mesa_pieces.json").write_text(json.dumps({"pieces": info, "height": cell, "pitch": cell}))
    print("  cells %d px tall; widths %s" % (cell, [p.shape[1] for p in ps]))


def trees() -> None:
    info = {}
    for name, p in zip(TREES, pieces("trees", 5, 2)):
        p = flat_foot(p)
        k = TREE_SCALE.get(name, 0.45)
        p = resize(p, (round(p.shape[1] * k), round(p.shape[0] * k)))
        foot = np.nonzero(p[-6:, :, 3].max(axis=0) > 0.5)[0]
        save(p, OUT / (name + ".png"))
        info[name] = {"size": [p.shape[1], p.shape[0]], "anchor_x": float(foot.min() + foot.max()) / 2}
    (OUT / "tree_info.json").write_text(json.dumps(info, indent=1))


def front() -> None:
    ps = pieces("front", 3, 2)
    cw, ch = FRONT_CELL
    atlas = np.zeros((ch * 2, cw * 3, 4), np.float32)
    for i, p in enumerate(ps):
        k = min((cw - 8) / p.shape[1], (ch - 4) / p.shape[0])
        p = resize(p, (round(p.shape[1] * k), round(p.shape[0] * k)))
        x = (i % 3) * cw + (cw - p.shape[1]) // 2
        y = (i // 3) * ch + ch - p.shape[0]
        atlas[y:y + p.shape[0], x:x + p.shape[1]] = p
    save(atlas, OUT / "fg_props.png")


if __name__ == "__main__":
    todo = sys.argv[1:] or ["sky", "wall", "mesas", "plain", "rise", "grass", "trees", "front"]
    for name in todo:
        globals()[name]()
