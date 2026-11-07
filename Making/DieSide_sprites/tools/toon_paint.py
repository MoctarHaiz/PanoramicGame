#!/usr/bin/env python3
"""Paints the hero's death frames in the anime cel look of the user's key art, from the data passes of
tools/die_render.py (albedo, light, normal, misc). Deterministic: the same rules on every frame, so the
animation is consistent by construction.

- materials from the unlit colours: skin, hair, scarf, blue armour, silver armour, white fur;
- four soft-edged cel bands from the key light (deep, shade, mid, lit), cool and violet in the shade,
  warm in the light, darkened in the creases (ambient occlusion);
- a hot golden rim where the back sun reaches an edge; crisp glints on the armour; an anime shine band
  on the hair;
- ink: a dark warm-brown outline around the silhouette, thinner lines where one form passes in front of
  another (depth) and where materials meet.

    python3 toon_paint.py RENDER_DIR [--game]   # reads RENDER_DIR/{albedo,light,normal,misc}, writes RENDER_DIR/paint

--game leaves out the outer outline and the rim: the game's packer (tools/art/hero_atlas.py) draws its own on
every animation, so the death gets the same line and sun rim as the run and the jump.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1]
GAME = "--game" in sys.argv[2:]
OUT = os.path.join(SRC, "paint")
os.makedirs(OUT, exist_ok=True)

SKIN, HAIR, SCARF, BLUE, SILVER, FUR = range(6)
INK = np.array([0.17, 0.10, 0.08], np.float32)
# key light direction in camera space (x right, y up, z towards the camera): as in die_render.py
KEY = np.array([-0.55, 0.65, 0.55], np.float32)
KEY /= np.linalg.norm(KEY)
HALF = KEY + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)

# base colour grading, per material (sRGB 0..1): multiply, then pull towards the key art's colour
GRADE = {
    SKIN: ((0.96, 1.12, 1.08), None, 0.0),  # the albedo's orange-red towards the key art's golden brown
    HAIR: ((1, 1, 1), (0.075, 0.072, 0.09), 1.0),
    SCARF: ((1.0, 1.0, 1.0), (0.78, 0.14, 0.12), 0.45),
    BLUE: ((1.0, 1.0, 1.0), (0.16, 0.30, 0.70), 0.45),
    SILVER: ((1.0, 1.0, 1.0), (0.66, 0.68, 0.74), 0.7),
    FUR: ((1.0, 1.0, 1.0), (0.93, 0.90, 0.84), 0.75),
}
# band multipliers (deep, shade, mid, lit): the shade cool and violet, the light warm
BANDS = {
    SKIN: ((0.42, 0.32, 0.44), (0.62, 0.48, 0.57), (0.92, 0.84, 0.78), (1.12, 1.06, 0.95)),
    HAIR: ((0.6, 0.6, 0.8), (0.8, 0.8, 1.0), (1.05, 1.05, 1.15), (1.7, 1.55, 1.5)),
    SCARF: ((0.42, 0.30, 0.45), (0.62, 0.45, 0.55), (0.92, 0.85, 0.82), (1.12, 1.05, 0.95)),
    BLUE: ((0.40, 0.38, 0.55), (0.60, 0.58, 0.72), (0.92, 0.92, 0.95), (1.12, 1.08, 1.02)),
    SILVER: ((0.40, 0.41, 0.54), (0.58, 0.59, 0.72), (0.88, 0.88, 0.90), (1.02, 1.0, 0.97)),
    FUR: ((0.56, 0.52, 0.62), (0.74, 0.70, 0.78), (0.96, 0.93, 0.90), (1.05, 1.02, 0.96)),
}
EDGES = (0.16, 0.40, 0.80)  # key light thresholds between the bands
SOFT = 0.035  # half width of the soft step between bands
RIM = np.array([1.0, 0.80, 0.50], np.float32)


def load(kind, name):
    return np.asarray(Image.open(os.path.join(SRC, kind, name)).convert("RGBA"), np.float32) / 255.0


def hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, (mx - mn) / (mx + 1e-6), mx


def classify(a, solid):
    h, s, v = hsv(a)
    c = np.full(h.shape, SKIN, np.int8)
    c[(v < 0.26)] = HAIR
    c[(a[..., 1] / (a[..., 0] + 1e-6) < 0.36) & (s > 0.7) & (v > 0.35) & ((h < 20) | (h > 340))] = SCARF
    c[(h > 190) & (h < 255) & (s > 0.3) & (v > 0.30)] = BLUE
    c[(s < 0.22) & (v >= 0.42)] = SILVER
    c[(s < 0.16) & (v >= 0.76)] = FUR
    # majority vote over a small window: no single-pixel material flips
    votes = np.stack([ndimage.uniform_filter((c == k).astype(np.float32), 5) for k in range(6)])
    c = votes.argmax(0).astype(np.int8)
    return np.where(solid, c, -1)


def smooth_step(x, e):
    return np.clip((x - (e - SOFT)) / (2 * SOFT), 0.0, 1.0)


def paint(name):
    alb = load("albedo", name)
    lig = load("light", name)
    nrm = load("normal", name)
    mis = load("misc", name)
    a = alb[..., :3]
    alpha = alb[..., 3]
    solid = alpha > 0.5
    k = alb.shape[0] / 1024.0  # pixel sizes are given at 1024
    cls = classify(a, solid)
    key, rim = lig[..., 0], lig[..., 2]
    n = nrm[..., :3] * 2 - 1
    depth, ao = mis[..., 0], mis[..., 1]

    # base colour, graded per material
    base = a.copy()
    for c, (mul, target, pull) in GRADE.items():
        m = cls == c
        col = a[m] * np.array(mul, np.float32)
        if target is not None:
            col = col * (1 - pull) + np.array(target, np.float32) * pull * (col.mean(-1, keepdims=True) / max(np.mean(target), 1e-3)) ** 0.35
        base[m] = col

    # cel bands from the key light, darkened in the creases
    s = np.clip(key * (0.55 + 0.45 * ao), 0, 1)
    s = ndimage.gaussian_filter(s, 1.2 * k)  # clean band shapes, not the normal map's noise
    w = [smooth_step(s, e) for e in EDGES]
    tint = np.zeros_like(a)
    for c, bands in BANDS.items():
        m = cls == c
        b = [np.array(x, np.float32) for x in bands]
        t = b[0] + w[0][m, None] * (b[1] - b[0])
        t = t + w[1][m, None] * (b[2] - b[1])
        t = t + w[2][m, None] * (b[3] - b[2])
        tint[m] = t
    col = np.clip(base * tint, 0, 1)

    # glints on the armour, a shine band on the hair (from the key light's half vector)
    nh = np.clip((n * HALF).sum(-1), 0, 1)
    lit = key > 0.35
    armour = (cls == BLUE) | (cls == SILVER)
    glint = armour & (key > 0.55) & (nh > 0.965)
    col[glint] = col[glint] * 0.35 + np.array([0.98, 0.97, 0.95]) * 0.65
    shine = (cls == HAIR) & lit & (nh > 0.84) & (nh < 0.91)
    col[shine] = col[shine] * 0.55 + np.array([0.30, 0.27, 0.29]) * 0.45

    # the hot rim: where the back sun reaches an edge
    edge = 1.0 - np.clip(n[..., 2], 0, 1)
    rim_m = np.clip((rim - 0.25) / 0.2, 0, 1) * np.clip((edge - 0.35) / 0.2, 0, 1)
    rim_col = np.where((cls == HAIR)[..., None], np.array([0.36, 0.25, 0.19]), RIM * np.clip(base * 1.6 + 0.25, 0, 1))
    if not GAME:
        col = col * (1 - 0.85 * rim_m[..., None]) + rim_col * 0.85 * rim_m[..., None]

    # ink: where one form passes in front of another (depth), where materials meet, and the silhouette
    st = ndimage.generate_binary_structure(2, 1)
    dz = np.zeros_like(depth)
    mat = np.zeros(solid.shape, bool)
    for ax in (0, 1):
        for sh in (1, -1):
            d2 = np.roll(depth, sh, ax)
            s2 = np.roll(solid, sh, ax)
            dz = np.maximum(dz, np.where(s2, depth - d2, 0))  # > 0: this pixel is behind its neighbour
            c2 = np.roll(cls, sh, ax)
            mat |= (c2 != cls) & s2 & solid & (c2 != HAIR) & (cls != HAIR) | ((c2 == HAIR) ^ (cls == HAIR)) & s2 & solid
    occl = solid & (dz > 0.02)  # the far side of a depth step: the line hugs the nearer form
    occl = ndimage.binary_dilation(occl, st, iterations=max(1, round(1 * k)))
    col[occl] = col[occl] * 0.15 + INK * 0.85
    matl = mat & ~occl
    col[matl] = col[matl] * 0.45 + INK * 0.55
    if GAME:
        out_a = alpha
    else:
        ring = ndimage.binary_dilation(solid, st, iterations=max(1, round(3 * k))) & ~solid
        soft_ring = ring | (solid & ~ndimage.binary_erosion(solid, st, iterations=1))
        col[soft_ring] = INK
        out_a = np.maximum(alpha, ring.astype(np.float32))
    img = np.dstack([col, out_a])
    Image.fromarray((img * 255).round().clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))


names = sorted(f for f in os.listdir(os.path.join(SRC, "albedo")) if f.endswith(".png"))
for nme in names:
    paint(nme)
print("painted", len(names), "frames ->", OUT)
