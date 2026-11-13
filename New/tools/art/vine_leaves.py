#!/usr/bin/env python3
"""assets/art/world/vine_leaves.png: the liana's leaves, each cluster and each hanging tendril a whole picture of its own.

The owner, 2026-11-13, on the vine: "Some leaves next to the rope that looks cut". VineView drew its leaves as rectangles
cut out of vine.png's spans, where leaves overlapped the rope and each other: a leaf ran out of its rectangle and ended on
a straight line, the rope's edge showing as a hairline at the cut. Here each cluster is painted alone in its own cell (as
vine.py paints them: heart-shaped leaves of several sizes and greens, lit from the upper left, on short stems from one
hanging point), trimmed to what it covers with a clear margin, so no rectangle can cut one.

Prints the rectangles and hanging points for src/game/vine_view.gd (CLUSTERS, TENDRILS: x, y, w, h, hanging point's x
share of the width).

    python3 tools/art/vine_leaves.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from paint import dither_rgba, hexc, mix, save, smooth  # noqa: E402

PX = 2
SS = 3  # supersampling
PAD = 4  # px of clear margin round each picture
ATLAS_W = 512


def leaf(dl, dli, dto, bx, by, ang, ln, wd, tone):
    nx, ny = -np.sin(ang), np.cos(ang)
    left, right = [], []
    for k in range(13):  # a rounded leaf with a pointed tip
        q = k / 12
        half = wd * np.sin(np.pi * min(1.0, q * 1.08)) ** 0.75 * (1.15 - 0.45 * q)
        px_, py_ = bx + np.cos(ang) * ln * q, by + np.sin(ang) * ln * q
        left.append((px_ + nx * half, py_ + ny * half))
        right.append((px_ - nx * half, py_ - ny * half))
    pts = left + right[::-1]
    dl.polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    dto.polygon([(x * SS, y * SS) for x, y in pts], fill=tone)
    lit_side = left if (nx * -0.6 + ny * -0.8) > 0 else right
    mid = [(bx + np.cos(ang) * ln * k / 12, by + np.sin(ang) * ln * k / 12) for k in range(13)]
    dli.polygon([(x * SS, y * SS) for x, y in lit_side + mid[::-1]], fill=255)


def paint(w, h, draw) -> np.ndarray:
    leaves = Image.new("L", (w * SS, h * SS), 0)
    lit = Image.new("L", (w * SS, h * SS), 0)
    tones = Image.new("L", (w * SS, h * SS), 128)
    draw(ImageDraw.Draw(leaves), ImageDraw.Draw(lit), ImageDraw.Draw(tones))
    lm = np.asarray(leaves, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    li = np.asarray(lit, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    tm = np.asarray(tones, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    yy = np.mgrid[0:h, 0:w][0].astype(float)
    col = mix(hexc("2f5a26"), hexc("8ab83e"), li * 0.9)
    col = mix(col, hexc("cfe07a"), li * smooth(0, 1, 1 - yy / h) * 0.25)
    col = col * (0.74 + 0.52 * tm)[..., None]
    col = mix(col, col * np.array([1.15, 1.02, 0.7]), smooth(0.62, 0.78, tm) * 0.5)
    return np.dstack([np.clip(col, 0, 255), lm])


def cluster(seed: int) -> tuple:
    rng = np.random.default_rng(seed)
    w, h = 300, 200
    ax, ay = w / 2, 6.0

    def draw(dl, dli, dto):
        big = rng.uniform(1.1, 2.0)
        for _ in range(int(rng.integers(3, 8))):
            ang = np.pi / 2 + rng.uniform(-1.15, 1.15)
            tone = int(rng.uniform(70, 200))
            ln = rng.uniform(9, 15) * PX * big
            wd = ln * rng.uniform(0.32, 0.42)
            stem = rng.uniform(1, 5) * PX
            sx = ax + rng.uniform(-14, 14) * PX
            bx, by = sx + np.cos(ang) * stem, ay + np.sin(ang) * stem
            dl.line([(sx * SS, ay * SS), (bx * SS, by * SS)], fill=255, width=SS)
            leaf(dl, dli, dto, bx, by, ang, ln, wd, tone)
        if rng.random() < 0.5:  # a tendril curling down from it
            x, y = ax + rng.uniform(-10, 10) * PX, ay + 2 * PX
            pts = []
            for k in range(24):
                a = k * 0.45
                r = (1 - k / 24) * 2.5 * PX
                pts.append(((x + np.sin(a) * r + k * 0.35) * SS, (y + k * 0.75 * PX + np.cos(a) * r) * SS))
            dl.line(pts, fill=255, width=SS)
    return paint(w, h, draw), ax


def tendril(seed: int) -> tuple:
    rng = np.random.default_rng(seed)
    w, h = 80, 260
    x0, y0 = w / 2, 4.0

    def draw(dl, dli, dto):
        length = rng.uniform(40, 110) * PX
        sway = rng.uniform(-8, 8) * PX
        pts = [(x0 + sway * q * q + np.sin(q * 5 + seed) * 1.5 * PX, y0 + length * q) for q in np.linspace(0, 1, 24)]
        # (tapering: it thins to its tip, no square end)
        for k in range(len(pts) - 1):
            wdt = max(1, int(round((1.7 - 1.2 * k / len(pts)) * PX * SS)))
            dl.line([(pts[k][0] * SS, pts[k][1] * SS), (pts[k + 1][0] * SS, pts[k + 1][1] * SS)], fill=255, width=wdt)
        for q in np.sort(rng.uniform(0.15, 0.95, int(rng.integers(3, 6)))):
            lx, ly = pts[int(q * 23)]
            side = 1 if rng.random() < 0.5 else -1
            ang = np.pi / 2 - side * rng.uniform(0.6, 1.2)
            ln = rng.uniform(6, 10) * PX
            leaf(dl, dli, dto, lx, ly, ang, ln, ln * 0.36, int(rng.uniform(80, 190)))
    return paint(w, h, draw), x0


def trim(rgba: np.ndarray, ax: float) -> tuple:
    a = rgba[..., 3]
    ys, xs = np.nonzero(a > 0.01)
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, rgba.shape[1])
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, rgba.shape[0])
    return rgba[y0:y1, x0:x1], (ax - x0) / (x1 - x0)


def main() -> None:
    pics = [("C",) + trim(*cluster(s)) for s in (3, 8, 12, 19, 25, 31, 40, 47, 52, 66)]
    pics += [("T",) + trim(*tendril(s)) for s in (5, 11, 23, 29, 37, 43)]
    # shelf packing
    x = y = row_h = 0
    places = []
    for kind, pic, af in pics:
        ph, pw = pic.shape[:2]
        if x + pw > ATLAS_W:
            x, y, row_h = 0, y + row_h, 0
        places.append((kind, x, y, pw, ph, af))
        x += pw
        row_h = max(row_h, ph)
    H = y + row_h
    rgb = np.zeros((H, ATLAS_W, 3))
    alpha = np.zeros((H, ATLAS_W))
    for (kind, pic, af), (_, px, py, pw, ph, _) in zip(pics, places):
        rgb[py:py + ph, px:px + pw] = pic[..., :3]
        alpha[py:py + ph, px:px + pw] = pic[..., 3]
    save(dither_rgba(rgb, np.clip(alpha, 0, 1)), "vine_leaves.png")
    for kind in "CT":
        print(("const CLUSTERS := [" if kind == "C" else "const TENDRILS := [") + ", ".join(
            "Rect2(%d, %d, %d, %d)" % (px, py, pw, ph) for k, px, py, pw, ph, af in places if k == kind) + "]")
        print(("const CLUSTER_AT := [" if kind == "C" else "const TENDRIL_AT := [") + ", ".join(
            "%.3f" % af for k, px, py, pw, ph, af in places if k == kind) + "]")
    print("atlas", ATLAS_W, H)


if __name__ == "__main__":
    main()
