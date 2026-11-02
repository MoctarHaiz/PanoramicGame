#!/usr/bin/env python3
"""The vine along the top of the screen (where Panoramic hooks his staff), painted in numpy:
assets/art/world/vine.png holds 5 variants of one span (160 x 48 units at 2 px, stacked), each a
thick twisted liana sagging between two hooks at its ends, with knots at the hooks, clusters of
heart-shaped leaves of several sizes hanging down, a few orange blossoms and curled tendrils. Lit
from the upper left.
Drawn span after span by src/game/vine_view.gd (the rope's ends meet at y = 2 units).

    python3 tools/art/vine.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from paint import blur, dither_rgba, hexc, mix, poly_mask, save, smooth  # noqa: E402

PX = 2
SPAN, H = 160, 48
TOP = 2.0  # the rope's ends, in units from the top
SAG = 12.0


def rope_y(t):
    return TOP + np.sin(np.pi * t) * SAG


def span(seed: int) -> tuple:
    rng = np.random.default_rng(seed)
    w, h = SPAN * PX, H * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    t = xx / w
    cy = rope_y(t) * PX
    thick = 3.4 * PX
    d = yy - cy
    rope = np.clip(thick - np.abs(d) + 0.5, 0, 1)
    # twist: diagonal bands along the rope, light on the upper side
    twist = np.sin((xx * 0.55 + d * 1.6))
    across = np.clip(-d / thick, -1, 1)  # 1 at the top edge
    shade = 0.45 + 0.35 * across + 0.18 * twist
    rope_col = mix(hexc("2e2414"), hexc("8e8a44"), np.clip(shade, 0, 1)[..., None][..., 0])
    rope_col = mix(rope_col, hexc("c8c070"), np.clip((twist > 0.7) * (across > 0.2), 0, 1) * 0.5)
    col = rope_col * 1.0
    alpha = rope.copy()
    # a second thin strand winding round the first
    d2 = yy - (cy + np.sin(xx * 0.08 + seed) * thick * 1.1)
    strand = np.clip(1.0 * PX - np.abs(d2) + 0.5, 0, 1)
    col = mix(col, mix(hexc("3a3018"), hexc("a09a50"), np.clip(-d2 / PX * 0.5 + 0.5, 0, 1)), strand * 0.9)
    alpha = np.maximum(alpha, strand)
    # knots at the hooks (both ends, so spans meet on a knot)
    for kx in (0.0, w):
        knot = poly_mask(w, h, [], ellipses=[(kx, TOP * PX + 1.0 * PX, 4.2 * PX, 3.6 * PX)])
        kl = np.clip(0.6 - (xx - kx) / (4 * PX) * 0.3 - (yy - TOP * PX) / (4 * PX) * 0.4, 0, 1)
        col = mix(col, mix(hexc("2a2012"), hexc("9a8a48"), kl), knot)
        alpha = np.maximum(alpha, knot)
    # leaves hanging in small clusters, and tendrils
    leaves = Image.new("L", (w * 3, h * 3), 0)
    lit = Image.new("L", (w * 3, h * 3), 0)
    dl, dli = ImageDraw.Draw(leaves), ImageDraw.Draw(lit)
    blossoms = []
    for _ in range(int(rng.integers(3, 6))):
        tx = rng.uniform(0.06, 0.94)
        ax, ay = tx * w, rope_y(tx) * PX + 1.5 * PX
        big = rng.uniform(0.8, 1.45)
        if rng.random() < 0.3:
            blossoms.append((ax + rng.uniform(-3, 3) * PX, ay + rng.uniform(2, 5) * PX))
        for j in range(int(rng.integers(2, 5))):
            ang = np.pi / 2 + rng.uniform(-1.0, 1.0)
            ln = rng.uniform(7, 12) * PX * big
            wd = ln * rng.uniform(0.32, 0.42)
            stem = rng.uniform(1, 3) * PX
            bx, by = ax + np.cos(ang) * stem, ay + np.sin(ang) * stem
            ex, ey = bx + np.cos(ang) * ln, by + np.sin(ang) * ln
            nx, ny = -np.sin(ang), np.cos(ang)
            left, right = [], []
            for k in range(13):  # a rounded leaf with a pointed tip
                q = k / 12
                half = wd * np.sin(np.pi * min(1.0, q * 1.08)) ** 0.75 * (1.15 - 0.45 * q)
                px_, py_ = bx + np.cos(ang) * ln * q, by + np.sin(ang) * ln * q
                left.append((px_ + nx * half, py_ + ny * half))
                right.append((px_ - nx * half, py_ - ny * half))
            pts = left + right[::-1]
            dl.polygon([(x * 3, y * 3) for x, y in pts], fill=255)
            lit_side = left if (nx * -0.6 + ny * -0.8) > 0 else right
            mid = [(bx + np.cos(ang) * ln * k / 12, by + np.sin(ang) * ln * k / 12) for k in range(13)]
            dli.polygon([(x * 3, y * 3) for x, y in lit_side + mid[::-1]], fill=255)
            dl.line([(ax * 3, ay * 3), (bx * 3, by * 3)], fill=255, width=3)
    for _ in range(2):  # tendrils curling down
        tx = rng.uniform(0.15, 0.85)
        x, y = tx * w, rope_y(tx) * PX + 2 * PX
        pts = []
        for k in range(24):
            a = k * 0.45
            r = (1 - k / 24) * 2.5 * PX
            pts.append(((x + np.sin(a) * r + k * 0.35) * 3, (y + k * 0.75 * PX + np.cos(a) * r) * 3))
        dl.line(pts, fill=255, width=3)
    lm = np.asarray(leaves, float).reshape(h, 3, w, 3).mean(axis=(1, 3)) / 255
    li = np.asarray(lit, float).reshape(h, 3, w, 3).mean(axis=(1, 3)) / 255
    leaf_col = mix(hexc("2f5a26"), hexc("8ab83e"), li * 0.9)
    leaf_col = mix(leaf_col, hexc("cfe07a"), np.clip(li - blur(li, 1.5), 0, 1) * 0.0 + li * smooth(0, 1, 1 - yy / h) * 0.25)
    col = mix(col, leaf_col, lm)
    alpha = np.maximum(alpha, lm)
    # blossoms: five round petals, lit, a dark centre
    for bx, by in blossoms:
        petals = [(bx + np.cos(a) * 2.2 * PX, by + np.sin(a) * 2.2 * PX, 1.9 * PX, 1.9 * PX)
                  for a in np.linspace(0, 2 * np.pi, 6)[:5] + rng.uniform(0, 1)]
        pm = poly_mask(w, h, [], ellipses=petals)
        pl = np.clip(0.75 - (xx - bx) / (6 * PX) * 0.4 - (yy - by) / (6 * PX) * 0.5, 0, 1)
        col = mix(col, mix(hexc("c8401a"), hexc("ffb04a"), pl), pm)
        cm = poly_mask(w, h, [], ellipses=[(bx, by, 1.1 * PX, 1.1 * PX)])
        col = mix(col, hexc("5a1a08"), cm)
        alpha = np.maximum(alpha, pm)
    return col, alpha


def main() -> None:
    cols, alphas = [], []
    for seed in (5, 9, 14, 21, 27):
        c, a = span(seed)
        cols.append(c)
        alphas.append(a)
    img = dither_rgba(np.clip(np.vstack(cols), 0, 255), np.clip(np.vstack(alphas), 0, 1))
    save(img, "vine.png")
    print("vine written")


if __name__ == "__main__":
    main()
