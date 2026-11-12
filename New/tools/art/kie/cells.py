#!/usr/bin/env python3
"""Cuts a kie.ai sprite sheet drawn on flat magenta into its cells (tools/art/gen/kie/<name>/NN.png, RGBA, each
trimmed to its figure) and measures each figure: its hair (the near-black blob at its top: the size all poses are
brought to), its hips (the top middle of the white fur loincloth, or of the trousers' belt for the bandits) and
its lowest pixel. Writes <name>/cells.json and a preview on the game's sky colours.

    python3 tools/art/kie/cells.py NAME COLS ROWS
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

GEN = Path(__file__).resolve().parents[1] / "gen/kie"


def key(rgb: np.ndarray, bg=None) -> np.ndarray:
    """RGBA (floats 0..1) of a picture on a flat magenta: the background's colour read from the picture's border
    (the stills and the clips come on slightly different magentas), alpha from how far a pixel is from it, and the
    background's share taken out of the edge pixels' colours (no pink fringe)."""
    if bg is None:
        border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3), rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
        bg = np.median(border, axis=0)
    d = np.sqrt(((rgb - bg) ** 2).sum(axis=-1))
    alpha = np.clip((d - 0.10) / 0.22, 0.0, 1.0)
    # a pixel as pink as the background is background whatever its brightness (the clips' compression mottles it)
    m = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    alpha = np.where(m > 0.30, np.minimum(alpha, np.clip((0.46 - m) / 0.16, 0.0, 1.0)), alpha)
    a3 = alpha[..., None]
    colour = np.where(a3 > 0.02, (rgb - (1.0 - a3) * bg) / np.maximum(a3, 0.02), rgb)
    # what pink is left on a half-covered edge pixel comes down to its green
    colour = np.clip(colour, 0.0, 1.0)
    spill = np.clip(np.minimum(colour[..., 0], colour[..., 2]) - colour[..., 1] - 0.08, 0.0, 1.0) * (alpha < 0.98)
    colour[..., 0] -= spill
    colour[..., 2] -= spill
    return np.clip(np.dstack([colour, alpha]), 0.0, 1.0)


def hue_sat(rgb: np.ndarray):
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    c = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.maximum(c, 1e-6)
    h = np.where(mx == r, ((g - b) / safe) % 6.0, np.where(mx == g, (b - r) / safe + 2.0, (r - g) / safe + 4.0)) * 60.0
    return np.where(c < 1e-6, 0.0, h), c / np.maximum(mx, 1e-6), mx


def unpink(a: np.ndarray, lo: float, hi: float, blue_to: float = -1.0) -> np.ndarray:
    """Takes the backdrop's pink out of a keyed figure whose own colours hold no hue between lo and hi degrees: such
    a pixel keeps its brightness and takes the colour of the clean pixels around it (pink on skin turns to skin, on
    the scarf to red). With blue_to, hues from lo up to 300 are steel that the pink light turned purple: they turn
    to that hue first."""
    rgb = a[..., :3].copy()
    al = a[..., 3]
    h, s, v = hue_sat(rgb)
    if blue_to >= 0.0:
        purple = (h > lo) & (h < 300.0) & (s > 0.06)
        k = np.where(purple, np.clip((s - 0.06) / 0.08, 0.0, 1.0), 0.0)
        # (round his head there is no steel: a purple sheen on his black hair goes grey, not blue)
        head = head_zone(rgb, al, 1.5)
        grey = np.repeat((rgb @ np.array([0.299, 0.587, 0.114], np.float32))[..., None], 3, axis=2)
        rgb = np.where((head & purple)[..., None], grey, rgb)
        # (and it is steel only among steel: a purple edge or fold of his scarf, of his skin, takes their colour below)
        sig = max(4.0, rgb.shape[1] / 110.0)
        blue = ndi.gaussian_filter(((al > 0.6) & (h > 185.0) & (h <= lo) & (s > 0.25)).astype(np.float32), sig)
        warm = ndi.gaussian_filter(((al > 0.6) & ((h < 45.0) | (h > 346.0)) & (s > 0.3)).astype(np.float32), sig)
        steel = blue >= 0.35 * warm
        other = purple & ~steel & ~head
        k = k * ~head * steel
        # (the same pixel at the steel's hue: its lightest and darkest channels kept)
        mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
        hh = blue_to + (h - lo) * 0.06
        x = (hh - 180.0) / 60.0                      # 180..240: blue the top channel, green on its way down
        steel_rgb = np.dstack([mn, mn + (mx - mn) * np.clip(1.0 - x, 0.0, 1.0), mx])
        rgb = rgb * (1.0 - k[..., None]) + steel_rgb * k[..., None]
        h, s, v = hue_sat(rgb)
    bad = (al > 0.02) & (h > (300.0 if blue_to >= 0.0 else lo)) & (h < hi) & (s > 0.14)
    if blue_to >= 0.0:
        bad |= other & (al > 0.02) & (s > 0.14)
    if not bad.any():
        return np.dstack([rgb, al])
    y = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    cb, cr = rgb[..., 2] - y, rgb[..., 0] - y
    good = (al > 0.6) & ~ndi.binary_dilation(bad, iterations=1)
    w = good * (0.1 + s) * (0.2 + v)
    near = [ndi.gaussian_filter((c / np.maximum(y, 0.08)) * w, 5.0) for c in (cb, cr)]
    ws = ndi.gaussian_filter(w.astype(np.float32), 5.0)
    idx = ndi.distance_transform_edt(~good, return_distances=False, return_indices=True)
    out = []
    for c, n in zip((cb, cr), near):
        ratio = (c / np.maximum(y, 0.08))[idx[0], idx[1]]
        out.append(np.where(ws > 0.02, n / np.maximum(ws, 1e-6), ratio) * np.maximum(y, 0.08))
    ncb, ncr = out
    r2, b2 = y + ncr, y + ncb
    g2 = (y - 0.299 * r2 - 0.114 * b2) / 0.587
    fixed = np.clip(np.dstack([r2, g2, b2]), 0.0, 1.0)
    k = (bad * np.clip((s - 0.14) / 0.10, 0.0, 1.0))[..., None]
    rgb = rgb * (1.0 - k) + fixed * k
    if blue_to >= 0.0:
        rgb = flush(rgb, al)
    return np.dstack([rgb, al])


SKIN_HUE = 21.0


def head_zone(rgb: np.ndarray, al: np.ndarray, below: float) -> np.ndarray:
    """Round his hair (the biggest near-black mass): its width and a half across, down to `below` of its radius under
    its middle (1.25: his face; 1.5: to his chin)."""
    dark = ndi.binary_opening((al > 0.5) & (rgb.max(axis=-1) < 0.26), iterations=2)
    lab, n = ndi.label(dark)
    if not n:
        return np.zeros(al.shape, bool)
    sizes = ndi.sum(dark, lab, range(1, n + 1))
    ys, xs = np.nonzero(lab == int(np.argmax(sizes)) + 1)
    r = np.sqrt(len(ys) / np.pi)
    yy, xx = np.mgrid[0:al.shape[0], 0:al.shape[1]]
    return (yy - ys.mean() < below * r) & (np.abs(xx - xs.mean()) < 1.5 * r)


def flush(rgb: np.ndarray, al: np.ndarray) -> np.ndarray:
    """The hero's skin where the pink light left it red (a glow on a fist, a knee, under his chin): light reds that
    are not his scarf's deep red go back to his skin's hue. His face keeps its red marks (the head: round his hair)."""
    h, s, v = hue_sat(rgb)
    hs = (h + 180.0) % 360.0 - 180.0
    k = np.clip((15.0 - hs) / 6.0, 0.0, 1.0) * (hs > -30.0) * np.clip((0.68 - s) / 0.06, 0.0, 1.0) \
        * np.clip((s - 0.10) / 0.06, 0.0, 1.0) * np.clip((v - 0.48) / 0.08, 0.0, 1.0) * (al > 0.02)
    k = k * ~head_zone(rgb, al, 1.25)
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    skin = np.dstack([mx, mn + (mx - mn) * SKIN_HUE / 60.0, mn])
    return rgb * (1.0 - k[..., None]) + skin * k[..., None]


def measure(a: np.ndarray) -> dict:
    al = a[..., 3] > 0.5
    ys, xs = np.nonzero(al)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dark = al & (np.maximum(np.maximum(r, g), b) < 0.26)
    lab, n = ndi.label(dark)
    hair = {"x": 0.0, "y": 0.0, "area": 0.0}
    if n:
        sizes = ndi.sum(dark, lab, range(1, n + 1))
        # the biggest dark blob in the upper two thirds of the figure
        best, best_s = 0, 0.0
        for i, s in enumerate(sizes, 1):
            cy = ndi.center_of_mass(dark, lab, i)[0]
            if cy < ys.min() + (ys.max() - ys.min()) * 0.6 and s > best_s:
                best, best_s = i, s
        if best:
            cy, cx = ndi.center_of_mass(dark, lab, best)
            hair = {"x": float(cx), "y": float(cy), "area": float(best_s)}
    white = al & (np.minimum(np.minimum(r, g), b) > 0.72) & (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b) < 0.12)
    lab, n = ndi.label(ndi.binary_opening(white, iterations=2))
    hips = {"x": float(xs.mean()), "y": float(ys.min() + (ys.max() - ys.min()) * 0.5)}
    if n:
        sizes = ndi.sum(white, lab, range(1, n + 1))
        i = int(np.argmax(sizes)) + 1
        wy, wx = np.nonzero(lab == i)
        top = wy.min()
        band = wx[wy < top + 14]
        hips = {"x": float(band.mean()), "y": float(top)}
    return {"hair": hair, "hips": hips, "bottom": int(ys.max()), "top": int(ys.min()), "w": a.shape[1], "h": a.shape[0]}


def main() -> None:
    name, cols, rows = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    rgb = np.asarray(Image.open(GEN / (name + ".png")).convert("RGB")).astype(np.float32) / 255.0
    a = key(rgb)
    solid = ndi.binary_opening(a[..., 3] > 0.5, iterations=2)
    lab, n = ndi.label(solid)
    H, W = solid.shape
    out = GEN / name
    out.mkdir(exist_ok=True)
    boxes = {}
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if ys.size < 400:
            continue
        cell = int(ys.mean() * rows / H) * cols + int(xs.mean() * cols / W)
        x0, y0, x1, y1 = boxes.get(cell, (W, H, 0, 0))
        boxes[cell] = (min(x0, xs.min()), min(y0, ys.min()), max(x1, xs.max() + 1), max(y1, ys.max() + 1))
    info = {}
    tiles = []
    for cell in sorted(boxes):
        x0, y0, x1, y1 = boxes[cell]
        x0, y0, x1, y1 = max(x0 - 3, 0), max(y0 - 3, 0), min(x1 + 3, W), min(y1 + 3, H)
        c = a[y0:y1, x0:x1].copy()
        # (only this cell's figure: bits of a neighbour's scarf inside the box are dropped)
        keep = ndi.binary_dilation(np.isin(lab[y0:y1, x0:x1], [i for i in range(1, n + 1) if (lab[y0:y1, x0:x1] == i).sum() > 400]), iterations=3)
        c[..., 3] *= keep
        Image.fromarray((c * 255).astype(np.uint8), "RGBA").save(out / ("%02d.png" % cell))
        info["%02d" % cell] = measure(c)
        tiles.append(c)
    (out / "cells.json").write_text(json.dumps(info, indent=1))
    # preview on the game's sky and grass colours
    th = max(t.shape[0] for t in tiles)
    tw = max(t.shape[1] for t in tiles)
    prev = np.zeros((th + 20, (tw + 10) * len(tiles), 3), np.float32)
    prev[: th // 2] = (0.62, 0.72, 0.86)
    prev[th // 2:] = (0.78, 0.66, 0.36)
    for k, t in enumerate(tiles):
        x = k * (tw + 10) + (tw - t.shape[1]) // 2
        y = th - t.shape[0] + 10
        al = t[..., 3:4]
        prev[y:y + t.shape[0], x:x + t.shape[1]] = prev[y:y + t.shape[0], x:x + t.shape[1]] * (1 - al) + t[..., :3] * al
    Image.fromarray((prev * 255).astype(np.uint8)).save(out / "preview.png")
    print(out, len(tiles), "cells", {k: (round(v["hair"]["area"]), v["h"]) for k, v in info.items()})


if __name__ == "__main__":
    main()
