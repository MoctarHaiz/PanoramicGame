#!/usr/bin/env python3
"""Props standing on the ground, painted in numpy like the rest of the world (lit from the upper
left, warm rim, cool shade): they replace the 2017 stock decorations and dress the savanna.

  prop_stump.png    a broken acacia stump with flaring roots (old tile 8, the trunk)
  prop_bush_a/b.png savanna shrubs, clumps of small leaves (old tiles 29, 30, 41, 42)
  prop_reeds.png    tall grass and reeds rising from the bottom of a pit (old tiles 31-34, 43-46)
  prop_rock_a/b.png sandstone boulders, half buried
  prop_aloe.png     an aloe: a rosette of fleshy toothed leaves and a red-orange flower spike
  prop_termite.png  a termite mound with chimneys (stands in the background rows)

2 px per design unit; each picture stands on its bottom row, anchored at its middle (props.json
lists sizes). Used by src/game/prop_view.gd and src/game/savanna_view.gd.

    python3 tools/art/props.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from paint import WORLD, blur, dither_rgba, fbm, hexc, mix, normals_light, poly_mask, ramp, save, smooth  # noqa: E402
from trees import Canvas, shade_tree  # noqa: E402

PX = 2


def relief_paint(cov: np.ndarray, stops: list, sigma: float, rng, tex_amount: float = 0.12,
                 rim: str = "ffe0a8") -> np.ndarray:
    """Colour of a rounded form: light from a blurred height field, a little texture, a warm rim
    on the upper-left silhouette."""
    h, w = cov.shape
    height = blur(cov, sigma) * sigma * 2.2 + blur(cov, sigma / 3) * sigma * 0.4
    lam = normals_light(height, 1.0)
    t = np.clip(lam + (fbm(h, w, max(1, h // 8), max(1, w // 8), 4, rng, False) - 0.5) * tex_amount * 2, 0, 1)
    col = ramp(t, stops)
    edge = np.clip(cov - np.roll(np.roll(cov, 2, axis=0), 2, axis=1), 0, 1)
    col = mix(col, hexc(rim), edge * 0.5)
    return col


def contact_shadow(cov: np.ndarray, col: np.ndarray, rows: int = 10) -> np.ndarray:
    """Darkens the bottom of a prop where it meets the ground."""
    h = cov.shape[0]
    yy = np.arange(h)[:, None] * np.ones((1, cov.shape[1]))
    k = smooth(h - rows * PX, h, yy) * 0.45
    return col * (1 - k[..., None])


def stump() -> Image.Image:
    """A broken acacia stump: a round trunk with grooved bark lit from the left, a splintered top
    showing pale wood, roots gripping the ground."""
    w, h = 60 * PX, 50 * PX
    rng = np.random.default_rng(5)
    cx, base = w / 2, h - 1
    half = 11 * PX
    top = 16 * PX
    # splintered top edge: jagged teeth, the tallest at the back left
    xs = np.linspace(cx - half, cx + half, 9)
    teeth = [(x, top + (rng.uniform(-9, 3) if 0 < i < 8 else 5) * PX) for i, x in enumerate(xs)]
    body = teeth + [(cx + half + 1 * PX, base), (cx - half - 1 * PX, base)]
    roots = []
    for side in (-1, 1):
        for k, (reach, rise, th) in enumerate(((9, 9, 3.4), (15, 5, 2.4))):
            x0 = cx + side * (half - 2 * PX)
            x1 = cx + side * (half + reach * PX)
            roots.append([(x0, base - rise * PX - th * PX), (x0 + side * 3 * PX, base - rise * PX * 0.6),
                          (x1, base), (x1 - side * th * 2 * PX, base), (x0 - side * 2 * PX, base)])
    cov = poly_mask(w, h, [body] + roots)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    xn = np.clip((xx - cx) / half, -1.3, 1.3)
    grooves = blur(rng.standard_normal((h, w)), (8, 0.7))
    grooves /= grooves.std() + 1e-6
    t = np.clip(0.5 - xn * 0.4 + grooves * 0.12 - np.abs(xn) ** 4 * 0.2, 0, 1)
    col = ramp(t, [(0, "261a1c"), (0.3, "3e2e28"), (0.6, "64483a"), (0.85, "8c6a4c"), (1, "b8946a")])
    # pale broken wood just under the teeth
    inner = poly_mask(w, h, [teeth + [(cx + half, top + 9 * PX), (cx - half, top + 9 * PX)]])
    wood = ramp(np.clip(0.7 - xn * 0.3 + grooves * 0.08, 0, 1), [(0, "8a6a48"), (0.6, "d6b282"), (1, "f2dcb0")])
    col = mix(col, wood, np.clip(inner * (1 - smooth(top + 2 * PX, top + 9 * PX, yy)) * 0.9, 0, 1))
    col = contact_shadow(cov, col, 7)
    edge = np.clip(cov - np.roll(np.roll(cov, 2, axis=0), 2, axis=1), 0, 1)
    col = mix(col, hexc("ffd8a0"), edge * 0.45)
    return dither_rgba(np.clip(col, 0, 255), cov, rng)


def bush(seed: int, w: int, h: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    cv = Canvas(w, h)
    cx = w / 2
    # a few stems
    for _ in range(5):
        cv.limb((cx + rng.uniform(-8, 8), h + 2), (cx + rng.uniform(-w * 0.35, w * 0.35), h * rng.uniform(0.3, 0.55)),
                rng.uniform(4, 6), 1.5, bend=rng.uniform(-6, 6))
    # mound of clumps: lower ones darker (level), sitting on the ground
    n = int(w * h / 90)
    for _ in range(n):
        u = rng.uniform(-1, 1)
        top = h * 0.12 + (h * 0.55) * (u * u)
        y = rng.uniform(top, h * 0.92)
        x = cx + u * w * 0.44
        r = rng.uniform(5, 10) * PX * 0.6
        level = np.clip(1 - (y - h * 0.1) / (h * 0.85), 0, 1)
        cv.blob(x, y, r * 1.25, r, level)
    img = shade_tree(cv, rng)
    a = np.asarray(img, float)
    rgb, al = a[..., :3], a[..., 3] / 255
    rgb = contact_shadow(al, rgb, 6)
    return dither_rgba(np.clip(rgb, 0, 255), al, rng)


def rock(seed: int, w: int, h: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    cx = w / 2
    polys = []
    pts = []
    k = 11
    for i in range(k + 1):
        a = np.pi + np.pi * i / k  # upper half, left to right
        rr = rng.uniform(0.85, 1.05)
        pts.append((cx + np.cos(a) * w * 0.46 * rr, h - 2 + np.sin(a) * (h - 4) * rr * (0.95 if 0.2 < i / k < 0.8 else 0.85)))
    pts.append((cx + w * 0.47, h))
    pts.append((cx - w * 0.47, h))
    polys.append(pts)
    cov = poly_mask(w, h, polys)
    col = relief_paint(cov, [(0, "4e3036"), (0.3, "7a4e44"), (0.6, "b47a52"), (0.85, "d9a06a"), (1, "f2cd96")], 9 * PX, rng)
    # cracks and strata lines
    yy = np.arange(h)[:, None] * np.ones((1, w))
    strata = (np.sin(yy * 0.55 + blur(rng.standard_normal((h, w)), 6) * 8) > 0.86) * 0.18
    col *= (1 - strata[..., None])
    crack = poly_mask(w, h, [], lines=[((cx + rng.uniform(-5, 5) * PX, h * 0.25, cx + rng.uniform(-9, 9) * PX, h * 0.85), 1.2 * PX)])
    col = mix(col, hexc("3a2228"), crack * 0.6)
    col = contact_shadow(cov, col, 6)
    # a little dry grass at the foot
    return dither_rgba(np.clip(col, 0, 255), cov, rng)


def aloe() -> Image.Image:
    """A spotted aloe: a low rosette of thick lance leaves, blue-green with pale spots and tiny teeth,
    each shaded along its midrib, and a stalk carrying a raceme of hanging red-orange tubes."""
    w, h = 70 * PX, 96 * PX
    rng = np.random.default_rng(13)
    cx, base = w / 2, h - 2 * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    col = np.zeros((h, w, 3))
    alpha = np.zeros((h, w))
    # the flower stalk and raceme, behind the leaves
    stalk_top = 8 * PX
    stalk = poly_mask(w, h, [[(cx - 1.2 * PX, base - 10 * PX), (cx + 1.2 * PX, base - 10 * PX), (cx + 3.2 * PX, stalk_top + 6 * PX),
                              (cx + 1.6 * PX, stalk_top + 6 * PX)]])
    col = mix(col, hexc("6e6a3a"), stalk)
    alpha = np.maximum(alpha, stalk)
    for i in range(30):
        t = i / 29
        fy = stalk_top + t * 30 * PX
        fx = cx + 2.4 * PX + (1 - t) * 0.5 * PX + rng.uniform(-3.2, 3.2) * PX * (0.4 + t * 0.6)
        tube = poly_mask(w, h, [], ellipses=[(fx, fy + 2.4 * PX, 1.2 * PX, 2.8 * PX)])
        c = mix(hexc("b8261a"), hexc("ff9a3a"), t)
        c = mix(c, hexc("ffe08a"), 0.2 * (rng.random() < 0.3))
        lit = np.clip(0.85 + 0.3 * (fx - xx) / (1.2 * PX), 0.7, 1.15)  # each tube lit on its left
        col = mix(col, c * lit[..., None], tube)
        alpha = np.maximum(alpha, tube)
    # leaves: back ones first, lower front ones last
    leaves = []
    for i in range(13):
        ang = np.pi * (0.06 + 0.88 * rng.random())
        leaves.append((ang, rng.uniform(22, 32) * PX * (0.7 + 0.45 * np.sin(ang)), rng.uniform(0.0, 0.5)))
    leaves.sort(key=lambda l: np.sin(l[0]), reverse=True)  # upright ones (back) first
    for ang, length, droop in leaves:
        steps = 14
        left, right, mid = [], [], []
        dirx, diry = -np.cos(ang), -np.sin(ang)
        for k in range(steps + 1):
            t = k / steps
            x = cx + dirx * length * t
            y = base - 4 * PX + diry * length * t + droop * (t ** 2) * 16 * PX
            wd = 4.6 * PX * (1 - t) ** 0.8 + 0.3 * PX
            nx, ny = -diry, dirx
            left.append((x + nx * wd, y + ny * wd))
            right.append((x - nx * wd, y - ny * wd))
            mid.append((x, y))
        m = poly_mask(w, h, [left + right[::-1]])
        upper = poly_mask(w, h, [[p for p in (left if left[1][1] < right[1][1] else right)] + mid[::-1]])
        spots = poly_mask(w, h, [], ellipses=[(mid[k][0] + rng.uniform(-2, 2) * PX, mid[k][1] + rng.uniform(-1.5, 1.5) * PX, 0.9 * PX, 0.6 * PX)
                                              for k in range(1, steps - 2) for _ in range(2)]) * m
        lc = mix(hexc("3a5a52"), hexc("82aa96"), upper * 0.9)
        lc = mix(lc, hexc("d8e6c8"), spots * 0.8)
        tip = smooth(0.0, 1.0, (np.hypot(xx - cx, yy - base) / length))
        lc = mix(lc, hexc("b0604a"), (tip > 0.85) * 0.5 * m)
        # a dark seam where this leaf lies over the ones behind it
        col = mix(col, lc, m)
        ring = np.clip(blur(m, 1.0) - m, 0, 1) * 0.6
        col = mix(col, hexc("22342e"), ring * (alpha > 0.5))
        alpha = np.maximum(alpha, m)
    col *= (1 - 0.35 * smooth(base - 8 * PX, base, yy))[..., None]
    edge = np.clip(alpha - np.roll(np.roll(alpha, 2, axis=0), 2, axis=1), 0, 1)
    col = mix(col, hexc("fff0c0"), edge * 0.4)
    return dither_rgba(np.clip(col, 0, 255), alpha, rng)


def reeds() -> Image.Image:
    """Tall grass and reeds with seed heads, 96 x 80 units, rising from the bottom edge."""
    w, h = 96 * PX, 80 * PX
    rng = np.random.default_rng(17)
    ss = 3
    img = Image.new("L", (w * ss, h * ss), 0)
    tone = Image.new("L", (w * ss, h * ss), 0)
    d, dt = ImageDraw.Draw(img), ImageDraw.Draw(tone)
    heads = []
    for _ in range(70):
        bx = w * (0.5 + rng.normal(0, 0.2))
        hgt = rng.uniform(0.35, 0.95) * h
        lean = rng.normal(0.1, 0.25) * hgt * 0.5
        bw = rng.uniform(1.0, 2.0) * PX
        v = int(rng.uniform(60, 255))
        pts = [((bx - bw) * ss, h * ss), ((bx + bw) * ss, h * ss), ((bx + lean * 0.6 + bw * 0.2) * ss, (h - hgt * 0.6) * ss), ((bx + lean) * ss, (h - hgt) * ss)]
        d.polygon(pts, fill=255)
        dt.polygon(pts, fill=v)
        if rng.random() < 0.25:
            heads.append((bx + lean, h - hgt))
    a = np.asarray(img, float).reshape(h, ss, w, ss).mean(axis=(1, 3)) / 255
    tn = np.asarray(tone, float).reshape(h, ss, w, ss).mean(axis=(1, 3)) / 255 / np.maximum(a, 1e-3)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    up = 1 - yy / h
    col = ramp(up, [(0, "3e5a2a"), (0.4, "7c8f3a"), (0.8, "c4b45e"), (1, "ecd88e")])
    col = mix(col * 0.72, col, tn)
    hm = poly_mask(w, h, [], ellipses=[(x, y + 4 * PX, 1.8 * PX, 5 * PX) for x, y in heads])
    col = mix(col, hexc("8a5a34"), hm)
    al = np.maximum(a, hm)
    return dither_rgba(np.clip(col, 0, 255), al, rng)


def termite() -> Image.Image:
    """A termite mound: a lumpy clay cone with chimneys, 90 x 130 units."""
    w, h = 90 * PX, 130 * PX
    rng = np.random.default_rng(23)
    cx = w * 0.48
    ells = []
    polys = [[(cx - 34 * PX, h), (cx - 18 * PX, h * 0.45), (cx - 4 * PX, h * 0.1), (cx + 6 * PX, h * 0.06), (cx + 16 * PX, h * 0.35),
              (cx + 36 * PX, h)]]
    for _ in range(9):  # chimneys and lumps
        y = rng.uniform(0.08, 0.7) * h
        spread = (y / h) * 30 * PX + 5 * PX
        x = cx + rng.uniform(-1, 1) * spread
        rr = rng.uniform(4, 9) * PX
        ells.append((x, y, rr * 0.8, rr * 1.6))
    cov = poly_mask(w, h, polys, ellipses=ells)
    col = relief_paint(cov, [(0, "4a2a28"), (0.3, "7e4632"), (0.6, "b56a3e"), (0.85, "d8955a"), (1, "f0c08a")], 12 * PX, rng, 0.18)
    yy = np.arange(h)[:, None] * np.ones((1, w))
    ridges = blur(rng.standard_normal((h, w)), (10, 1.5))
    col *= (1 + (ridges / ridges.std() * 0.05))[..., None]
    col = contact_shadow(cov, col, 10)
    return dither_rgba(np.clip(col, 0, 255), cov, rng)


def main() -> None:
    out = {
        "prop_stump": stump(),
        "prop_bush_a": bush(31, 72 * PX, 46 * PX),
        "prop_bush_b": bush(37, 54 * PX, 36 * PX),
        "prop_reeds": reeds(),
        "prop_rock_a": rock(41, 46 * PX, 28 * PX),
        "prop_rock_b": rock(43, 30 * PX, 18 * PX),
        "prop_aloe": aloe(),
        "prop_termite": termite(),
    }
    info = {}
    for name, img in out.items():
        save(img, name + ".png")
        info[name] = {"size": [img.width / PX, img.height / PX]}
    (WORLD / "props.json").write_text(json.dumps(info, indent=1))
    print("props written")


if __name__ == "__main__":
    main()
