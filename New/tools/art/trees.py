#!/usr/bin/env python3
"""Savanna trees for the background, painted in numpy (assets/art/world/tree_*.png): umbrella thorn
acacias (a short trunk forking into a fan of branches under a flat, layered crown) and baobabs (a
huge bottle trunk with folds, stubby crooked branches, sparse leaves). Lit from the upper left like
the hero sheet: warm light on top and left, cool olive-violet shade under the crowns.

The trees are drawn at several depths by src/game/savanna_view.gd (small and hazy far away, larger
in front), so the same few pictures make a varied savanna. The ground line is the bottom row of each
picture; tree_info.json gives each tree's trunk x (its anchor).

    python3 tools/art/trees.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from paint import (WORLD, blur, dither_rgba, fbm, hexc, mix, normals_light, ramp, save, smooth)  # noqa: E402

SS = 3
BARK_DARK = hexc("3e2b26")
BARK = hexc("6e4f3c")
BARK_LIT = hexc("b08660")
LEAF_DARK = hexc("344233")
LEAF = hexc("6f7e38")
LEAF_LIT = hexc("b4b453")
LEAF_TIP = hexc("e3d68a")


class Canvas:
    """Supersampled coverage layers for a tree: branches (with a lit side) and leaves."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.wood = Image.new("L", (w * SS, h * SS), 0)
        self.wood_lit = Image.new("L", (w * SS, h * SS), 0)
        self.blobs = []  # leaf clumps: (cx, cy, rx, ry, level 0 low .. 1 top of its pad)
        self.dw, self.dl = ImageDraw.Draw(self.wood), ImageDraw.Draw(self.wood_lit)

    def limb(self, p0, p1, w0, w1, bend=0.0, steps=8):
        """A tapered, slightly bent branch from p0 to p1; its left/upper side marked as lit."""
        x0, y0 = p0
        x1, y1 = p1
        dx, dy = x1 - x0, y1 - y0
        ln = np.hypot(dx, dy) + 1e-6
        nx, ny = -dy / ln, dx / ln  # normal
        pts_l, pts_r, lit_l = [], [], []
        for k in range(steps + 1):
            t = k / steps
            off = np.sin(t * np.pi) * bend
            cx, cy = x0 + dx * t + nx * off, y0 + dy * t + ny * off
            wd = (w0 + (w1 - w0) * t) / 2
            pts_l.append((cx + nx * wd, cy + ny * wd))
            pts_r.append((cx - nx * wd, cy - ny * wd))
            # the lit strip: towards the upper left
            side = 1 if (nx * -0.6 + ny * -0.8) > 0 else -1
            lit_l.append((cx + nx * wd * side * 0.15, cy + ny * wd * side * 0.15, cx + nx * wd * side, cy + ny * wd * side))
        poly = pts_l + pts_r[::-1]
        self.dw.polygon([(x * SS, y * SS) for x, y in poly], fill=255)
        lit_poly = [(a, b) for a, b, _, _ in lit_l] + [(c, d) for _, _, c, d in lit_l[::-1]]
        self.dl.polygon([(x * SS, y * SS) for x, y in lit_poly], fill=255)

    def blob(self, cx, cy, rx, ry, level=0.5):
        self.blobs.append((cx, cy, rx, ry, level))

    def leaves(self):
        """Coverage and light (0..1) of the leaf clumps, painted back to front: each clump is a
        little dome lit from the upper left, lighter near the top of its pad."""
        cov = np.zeros((self.h, self.w))
        shade = np.zeros((self.h, self.w))
        L = np.array([-0.55, -0.75, 0.62])
        L /= np.linalg.norm(L)
        for cx, cy, rx, ry, level in sorted(self.blobs, key=lambda b: b[4]):
            x0, x1 = int(max(0, cx - rx - 2)), int(min(self.w, cx + rx + 3))
            y0, y1 = int(max(0, cy - ry - 2)), int(min(self.h, cy + ry + 3))
            if x1 <= x0 or y1 <= y0:
                continue
            ys, xs = np.mgrid[y0:y1, x0:x1].astype(float) + 0.5
            dx, dy = (xs - cx) / rx, (ys - cy) / ry
            r = np.sqrt(dx * dx + dy * dy)
            c = np.clip((1 - r) * min(rx, ry) + 0.5, 0, 1)
            nz = np.sqrt(np.clip(1 - r * r, 0, 1))
            lam = np.clip((dx * L[0] + dy * L[1] + nz * L[2]) / np.maximum(np.sqrt(dx * dx + dy * dy + nz * nz), 1e-3), 0, 1)
            sv = lam * 0.72 + level * 0.38 - 0.08
            sub_c = cov[y0:y1, x0:x1]
            sub_s = shade[y0:y1, x0:x1]
            shade[y0:y1, x0:x1] = sub_s * (1 - c) + sv * c
            cov[y0:y1, x0:x1] = sub_c + c * (1 - sub_c)
        return cov, np.clip(shade, 0, 1)

    def arrays(self):
        def get(img):
            a = np.asarray(img, float) / 255
            return a.reshape(self.h, SS, self.w, SS).mean(axis=(1, 3))
        leaf, self.leaf_shade = self.leaves()
        return get(self.wood), get(self.wood_lit), leaf


def leaf_pad(cv: Canvas, rng, cx, cy, half_w, thick):
    """A flat clump of foliage: many small rounded tufts packed into a wide, thin mound."""
    n = int(half_w * thick / 9) + 12
    for _ in range(n):
        u = rng.uniform(-1, 1)
        x = cx + u * half_w
        top = cy - thick * 0.55 * np.sqrt(max(0.0, 1 - u * u)) - thick * 0.15
        y = rng.uniform(top, cy + thick * 0.35)
        r = rng.uniform(4, 9) * (0.7 + 0.5 * (1 - abs(u)))
        level = np.clip((cy + thick * 0.35 - y) / (thick * 0.9), 0, 1)
        cv.blob(x, y, r * 1.5, r * 0.85, level)
    # the flat underside: a band slightly ragged, in shade
    for _ in range(int(half_w / 3)):
        x = cx + rng.uniform(-0.92, 0.92) * half_w
        cv.blob(x, cy + thick * 0.25 + rng.uniform(-2, 2), rng.uniform(5, 9), rng.uniform(2.5, 4), -0.2)


def shade_tree(cv: Canvas, rng, crown_shade: float = 1.0, haze_bottom: float = 0.0) -> Image.Image:
    wood, wood_lit, leaf = cv.arrays()
    h, w = leaf.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # foliage: clumps painted one by one (Canvas.leaves), a little leaf texture over them
    lam = cv.leaf_shade
    t = np.clip(lam + (fbm(h, w, h // 10 + 1, w // 10 + 1, 3, rng, False) - 0.5) * 0.12, 0, 1)
    leaf_col = ramp(t, [(0, LEAF_DARK), (0.4, LEAF), (0.75, LEAF_LIT), (1.0, LEAF_TIP)])
    # speckle: little leaves catching light
    speck = rng.random((h, w))
    leaf_col = mix(leaf_col, LEAF_TIP, (speck > 0.985) * smooth(0.55, 0.85, lam) * 0.8)
    leaf_col *= (0.9 + 0.2 * blur(rng.random((h, w)), 0.8))[..., None]
    # wood: dark bark, lit strip on the upper-left side; shadow from the crown above
    wood_col = mix(BARK_DARK, BARK, 0.55)
    wood_col = mix(wood_col, BARK_LIT, wood_lit * 0.85)
    crown_shadow = np.clip(blur(np.roll(leaf, 14, axis=0), 8) * 1.4, 0, 1)
    wood_col = mix(wood_col, BARK_DARK * 0.8, crown_shadow * 0.6)
    bark_n = blur(rng.standard_normal((h, w)), (2.5, 0.6))
    wood_col += (bark_n / (bark_n.std() + 1e-6) * 6)[..., None]
    col = mix(wood_col, leaf_col, leaf)
    alpha = np.clip(np.maximum(leaf, wood), 0, 1)
    # rim of warm light on the upper-left silhouette
    rim = np.clip(alpha - np.roll(np.roll(alpha, 2, axis=0), 2, axis=1), 0, 1)
    col = mix(col, hexc("ffe0a0"), rim * 0.45)
    if haze_bottom:
        col = mix(col, hexc("c9a46a"), smooth(h * 0.75, h, yy) * haze_bottom)
    return dither_rgba(np.clip(col, 0, 255), alpha, rng)


def foot_grass(img: Image.Image, cx: float, half: float, seed: int) -> Image.Image:
    """Dry golden grass over the foot of a tree, so its base sits in the savanna."""
    rng = np.random.default_rng(seed)
    w, h = img.size
    g = Image.new("L", (w * SS, h * SS), 0)
    tone = Image.new("L", (w * SS, h * SS), 0)
    d, dt = ImageDraw.Draw(g), ImageDraw.Draw(tone)
    for _ in range(int(half * 2.6)):
        bx = cx + rng.normal(0, half * 0.55)
        hgt = rng.uniform(10, 40)
        lean = rng.normal(0.2, 0.35) * hgt
        bw = rng.uniform(1.2, 2.4)
        pts = [((bx - bw) * SS, h * SS), ((bx + bw) * SS, h * SS), ((bx + lean * 0.6) * SS, (h - hgt * 0.6) * SS),
               ((bx + lean) * SS, (h - hgt) * SS)]
        d.polygon(pts, fill=255)
        dt.polygon(pts, fill=int(rng.uniform(60, 255)))
    a = np.asarray(g, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    tn = np.asarray(tone, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255 / np.maximum(a, 1e-3)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    up = np.clip((h - yy) / 30, 0, 1)
    col = ramp(up, [(0, "7a5a32"), (0.5, "b89050"), (1, "ecd08c")])
    col = mix(col * 0.75, col, tn)
    base = np.asarray(img, float)
    rgb, al = base[..., :3], base[..., 3] / 255
    out_a = a + al * (1 - a)
    out = (col * a[..., None] + rgb * (al * (1 - a))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
    return dither_rgba(np.clip(out, 0, 255), out_a, rng)


def acacia(seed: int, w: int = 560, h: int = 400) -> tuple:
    """Umbrella thorn: trunk at x = w * 0.5 on the bottom row."""
    rng = np.random.default_rng(seed)
    cv = Canvas(w, h)
    base = (w * rng.uniform(0.42, 0.55), h - 1.0)
    trunk_h = h * rng.uniform(0.28, 0.38)
    lean = rng.uniform(-0.18, 0.18)
    top = (base[0] + trunk_h * lean, base[1] - trunk_h)
    tw = rng.uniform(19, 25)
    cv.limb((base[0], base[1] + 4), top, tw * 1.25, tw * 0.85, bend=rng.uniform(-6, 6))
    # root flare
    cv.limb((base[0] - tw * 1.2, base[1] + 2), (base[0], base[1] - tw * 1.5), tw * 0.5, tw * 0.3)
    cv.limb((base[0] + tw * 1.2, base[1] + 2), (base[0], base[1] - tw * 1.5), tw * 0.5, tw * 0.3)
    crown_y = h * rng.uniform(0.14, 0.2)
    crown_w = w * rng.uniform(0.40, 0.47)
    tips = []
    n = int(rng.integers(3, 5))
    for i in range(n):
        a = -np.pi / 2 + (i - (n - 1) / 2) * rng.uniform(0.38, 0.5) + rng.uniform(-0.1, 0.1)
        ln = (top[1] - crown_y) / max(0.35, -np.sin(a)) * rng.uniform(0.55, 0.7)
        mid = (top[0] + np.cos(a) * ln, top[1] + np.sin(a) * ln)
        cv.limb(top, mid, tw * 0.85, tw * 0.55, bend=rng.uniform(-8, 8))
        # second fork, spreading wider, up to the crown
        for j in range(2):
            a2 = a + (j - 0.5) * rng.uniform(0.35, 0.7)
            tx = mid[0] + np.cos(a2) * rng.uniform(40, 90) * (1.3 if abs(np.cos(a)) > 0.4 else 1.0)
            ty = crown_y + rng.uniform(4, 22)
            tx = np.clip(tx, w / 2 - crown_w * 0.95, w / 2 + crown_w * 0.95)
            cv.limb(mid, (tx, ty), tw * 0.55, tw * 0.22, bend=rng.uniform(-10, 10))
            tips.append((tx, ty))
    # crown: separate flat pads over the branch tips, at slightly different heights, a couple
    # of smaller ones riding higher; sky shows between them
    xs = [p[0] for p in tips]
    cx = (min(xs) + max(xs)) / 2
    order = sorted(tips, key=lambda p: -p[1])  # lowest first: higher pads drawn over them
    for p in order:
        leaf_pad(cv, rng, p[0] + rng.uniform(-12, 12), p[1] + rng.uniform(-4, 6), rng.uniform(42, 74), rng.uniform(20, 28))
    for _ in range(int(rng.integers(2, 4))):
        leaf_pad(cv, rng, cx + rng.uniform(-90, 90), crown_y - rng.uniform(2, 16), rng.uniform(36, 70), rng.uniform(18, 24))
    img = shade_tree(cv, rng)
    return foot_grass(img, base[0], tw * 2.2, seed), base[0]


def baobab(seed: int, w: int = 460, h: int = 560) -> tuple:
    """A baobab: a bottle trunk with vertical folds, a crown of massive crooked limbs that grow
    out of it like roots in the air, and sparse leaf clusters at the twigs."""
    rng = np.random.default_rng(seed)
    cv = Canvas(w, h)
    cx = w * 0.5
    trunk_top = h * rng.uniform(0.42, 0.47)
    bottom_w = w * rng.uniform(0.36, 0.42)
    top_w = bottom_w * rng.uniform(0.62, 0.74)
    yy, xx = np.mgrid[0:h * SS, 0:w * SS].astype(float) / SS
    t = np.clip((yy - trunk_top) / (h - trunk_top), 0, 1)
    belly = np.sin(t * np.pi) * 0.1
    flare = np.clip((t - 0.9) / 0.1, 0, 1) ** 2 * 0.25
    half = (top_w + (bottom_w - top_w) * t ** 0.9) / 2 * (1 + belly + flare)
    trunk = (np.abs(xx - cx) <= half) & (yy >= trunk_top)
    trunk_cov = trunk.reshape(h, SS, w, SS).mean(axis=(1, 3))
    half_px = half.reshape(h, SS, w, SS).mean(axis=(1, 3))
    tips = []
    n = int(rng.integers(5, 7))
    for i in range(n):
        u = (i - (n - 1) / 2) / ((n - 1) / 2)
        p0 = (cx + u * top_w * 0.36, trunk_top + 26)
        ang = -np.pi / 2 + u * rng.uniform(0.75, 1.05) + rng.uniform(-0.12, 0.12)
        ln = rng.uniform(70, 115) * (1.0 - 0.25 * abs(u))
        p1 = (p0[0] + np.cos(ang) * ln, p0[1] + np.sin(ang) * ln)
        cv.limb(p0, p1, rng.uniform(34, 44), rng.uniform(16, 22), bend=rng.uniform(-16, 16))
        for j in range(int(rng.integers(2, 4))):
            a2 = ang + rng.uniform(-0.8, 0.8)
            l2 = rng.uniform(32, 62)
            p2 = (p1[0] + np.cos(a2) * l2, p1[1] + np.sin(a2) * l2 * 0.85)
            cv.limb(p1, p2, rng.uniform(13, 17), rng.uniform(5, 8), bend=rng.uniform(-9, 9))
            for _ in range(int(rng.integers(1, 3))):
                a3 = a2 + rng.uniform(-0.6, 0.6)
                l3 = rng.uniform(14, 28)
                p3 = (p2[0] + np.cos(a3) * l3, p2[1] + np.sin(a3) * l3)
                cv.limb(p2, p3, rng.uniform(5, 7), 2.0, bend=rng.uniform(-4, 4))
                tips.append(p3)
    for p in tips:  # sparse leaf clusters
        if rng.random() < 0.7:
            for _ in range(int(rng.integers(2, 5))):
                cv.blob(p[0] + rng.normal(0, 9), p[1] + rng.normal(0, 5), rng.uniform(6, 11), rng.uniform(4, 6.5))
    wood, wood_lit, leaf = cv.arrays()
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    xn = np.clip((xs - cx) / np.maximum(half_px, 1), -1, 1)
    fold = blur(rng.standard_normal((h, w)), (16, 1.8))
    fold = fold / (fold.std() + 1e-6)
    # cylinder light from the left, folds catch light and shade
    shade_x = np.clip(0.78 - xn * 0.62 + fold * 0.16 - np.abs(xn) ** 6 * 0.25, 0, 1)
    trunk_col = ramp(shade_x, [(0, "3e2e3a"), (0.3, "5e4648"), (0.62, "86624f"), (0.85, "a97e60"), (1.0, "c89c74")])
    trunk_col += (blur(rng.standard_normal((h, w)), (3, 0.8)) * 5)[..., None]
    # horizontal wrinkles near the foot, a shadow under the limbs
    wr = np.sin(ys * 0.7 + fold * 2) * smooth(h * 0.8, h, ys) * 0.05
    trunk_col *= (1 + wr)[..., None]
    trunk_col *= (1 - 0.3 * (1 - smooth(trunk_top, trunk_top + 50, ys)))[..., None]
    # limbs: the same bark, lit on their upper left
    limb_col = mix(hexc("4e3c44"), hexc("a98066"), wood_lit * 0.9)
    limb_col = mix(limb_col, hexc("4a3a44"), smooth(0.0, 1.0, (xs - cx) / (w * 0.5)) * 0.3)
    rng2 = np.random.default_rng(seed + 1)
    leaf_img = shade_tree(cv, rng2)
    lt = np.asarray(leaf_img, float)
    leaf_rgb, leaf_a = lt[..., :3], lt[..., 3] / 255
    col = mix(trunk_col, limb_col, wood)
    col = mix(col, leaf_rgb, leaf)
    alpha = np.clip(np.maximum.reduce([trunk_cov, wood, leaf]), 0, 1)
    rim = np.clip(alpha - np.roll(np.roll(alpha, 2, axis=0), 2, axis=1), 0, 1)
    col = mix(col, hexc("ffe0a8"), rim * 0.4)
    img = dither_rgba(np.clip(col, 0, 255), alpha, rng)
    return foot_grass(img, cx, bottom_w * 0.75, seed), cx


def main() -> None:
    info = {}
    for i, seed in enumerate((101, 107, 113, 127, 131)):
        img, ax = acacia(seed)
        save(img, f"tree_acacia_{i + 1}.png")
        info[f"tree_acacia_{i + 1}"] = {"size": list(img.size), "anchor_x": round(float(ax), 1)}
    for i, seed in enumerate((201, 211)):
        img, ax = baobab(seed)
        save(img, f"tree_baobab_{i + 1}.png")
        info[f"tree_baobab_{i + 1}"] = {"size": list(img.size), "anchor_x": round(float(ax), 1)}
    (WORLD / "tree_info.json").write_text(json.dumps(info, indent=1))
    print("trees written")


if __name__ == "__main__":
    main()
