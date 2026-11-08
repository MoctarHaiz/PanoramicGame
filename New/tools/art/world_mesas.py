#!/usr/bin/env python3
"""The escarpments on the horizon, one landform at a time (src/game/savanna_view.gd places them in three depth rows).

Round 20 (the judges, j16: "the same mesa shape x4 with no atmospheric layering"): the world redraw's painted strip
(kept as tools/art/ref/far_mesas_strip.png) cut into its five landforms, each cut in a valley of the strip with its
sides fading out.
Round 21 (the judges, j17: "still the same flat-topped striped block, stamped"): new silhouettes painted here in the
strip's own palette and manner (no generator): a lone spire, a cluster of hoodoos, a natural arch, a broken arch, a
cracked twin-topped butte and a tilted cuesta. Each is a silhouette (polygons, its edges wavering) painted as the
strip's landforms are: a lit peach face on the sun's side (upper left), a pink middle, a cool lavender shadow face,
soft darker strata across it, brushy mottling and runoff streaks, a pale rim along its tops, an undercut under a cap
rock, a thin dark ink line down its shadow side and flared feet, and the warm haze of distance rising over its foot.
On every piece the ink lines dissolve in that haze lower down (soften_ink: far away at dusk they read as wires).

  far_mesa_pieces.png   the pieces in two rows (the strip's five, then the painted ones), 1 px per unit as the strip
  far_mesa_pieces.json  {"pieces": [[x, y, width, kind], ...] in px of the picture, "height"}; kind: "block" (the
                        flat-topped ones), "spire", "arch", "low"

    python3 tools/art/world_mesas.py [--sheet out.png]   (--sheet: a contact sheet on a sky colour, to review)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

WORLD = Path(__file__).resolve().parents[2] / "assets/art/world"
# px ranges of the strip, each cut in a valley between two landforms (a butte, the tall butte, the mesa,
# the twin spires, the long stepped plateau)
CUTS = [(112, 348, "block"), (296, 566, "block"), (556, 1000, "block"), (972, 1128, "spire"), (1108, 1760, "block")]
FADE = 34  # px over which each side fades out
H = 249  # the strip's height (the pieces' too)
GAP = 6  # px between two pieces in the picture
SS = 4  # supersampling of the silhouettes

# the strip's colours (sampled from the tall butte, mid height)
LIT = np.array([255, 203, 140], float)
LIT_EDGE = np.array([226, 158, 116], float)  # where the lit face turns into the middle one
MID = np.array([203, 143, 128], float)
SHADE = np.array([140, 122, 152], float)
RIM = np.array([255, 218, 172], float)
HAZE = np.array([219, 188, 168], float)
INK = np.array([92, 66, 80], float)


def poly(points, w):
    """The silhouette of a list of polygons (each a list of (x, y) px) minus `holes`, antialiased, w x H."""
    img = Image.new("L", (w * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    for p in points:
        d.polygon([(x * SS, y * SS) for x, y in p], fill=255)
    return img


def cut(img, holes):
    d = ImageDraw.Draw(img)
    for p in holes:
        d.polygon([(x * SS, y * SS) for x, y in p], fill=0)
    return img


def finish(img, w, seed=0, warp=1.6):
    """The silhouette at 1 px a unit, its edges wavering a little (no ruler-straight sides)."""
    m = np.asarray(img.resize((w, H), Image.LANCZOS)).astype(float) / 255.0
    if warp <= 0.0:
        return m
    rng = np.random.default_rng(seed + 7)
    dx = ndimage.gaussian_filter(rng.normal(0, 1, (H, w)), (5, 3)) * warp * 9.0
    dy = ndimage.gaussian_filter(rng.normal(0, 1, (H, w)), (3, 5)) * warp * 5.0
    yy, xx = np.mgrid[0:H, 0:w].astype(float)
    return np.clip(ndimage.map_coordinates(m, [yy + dy, xx + dx], order=1, mode="nearest"), 0.0, 1.0)


def ellipse_pts(cx, cy, rx, ry, a0, a1, n=24):
    t = np.linspace(a0, a1, n)
    return [(cx + rx * np.cos(a), cy + ry * np.sin(a)) for a in t]


def strata(seed, w):
    """Soft darker bands across the rock (and their red), wavering a little along x: a multiplier per pixel."""
    rng = np.random.default_rng(seed)
    y = np.arange(H, dtype=float)[:, None]
    x = np.arange(w, dtype=float)[None, :]
    wave = ndimage.gaussian_filter1d(rng.normal(0, 1, w + 40), 9)[20:20 + w][None, :] * 9.0 + x * rng.uniform(-0.03, 0.03)
    band = np.zeros((H, w))
    at = rng.uniform(0, 14)
    while at < H:
        thick = rng.uniform(3.5, 7.5)
        depth = rng.uniform(0.55, 1.0)
        band = np.maximum(band, depth * np.exp(-((y + wave - at) / thick) ** 2))
        at += rng.uniform(20, 38)
    return band


def paint(mask, seed, cap=0.0):
    """The rock: the strip's faces, strata, mottling, rims, ink and haze over a silhouette (0..1, H x w)."""
    h, w = mask.shape
    rng = np.random.default_rng(seed)
    solid = mask > 0.5
    # per row, each run of rock: how far each pixel is from its left (sun side) and right edges, and its width
    dl = np.zeros((h, w))
    dr = np.zeros((h, w))
    span = np.ones((h, w))
    for y in range(h):
        row = solid[y]
        x = 0
        while x < w:
            if not row[x]:
                x += 1
                continue
            s = x
            while x < w and row[x]:
                x += 1
            idx = np.arange(s, x)
            dl[y, s:x] = idx - s + 0.5
            dr[y, s:x] = x - idx - 0.5
            span[y, s:x] = x - s
    # (smoothed down the rock: the faces' boundaries flow, they don't jump from row to row)
    span = ndimage.gaussian_filter1d(np.where(solid, span, np.nan_to_num(span)), 14, axis=0)
    # how far below the top of the rock each pixel is (in its column)
    above = np.cumsum(solid, axis=0)
    dt = np.where(solid, above, 0).astype(float)
    lit_w = np.clip(span * 0.36, 5.0, 52.0)
    shade_w = np.clip(span * 0.26, 4.0, 46.0)
    lit = 1.0 - np.clip((dl - lit_w) / 2.2, 0.0, 1.0)
    edge = np.clip(1.0 - np.abs(dl - lit_w - 4.0) / 5.0, 0.0, 1.0) * 0.6
    shade = 1.0 - np.clip((dr - shade_w) / 2.0, 0.0, 1.0)
    c = MID[None, None, :] * np.ones((h, w, 1))
    c = c * (1 - edge[..., None]) + LIT_EDGE * edge[..., None]
    c = c * (1 - lit[..., None]) + LIT * lit[..., None]
    c = c * (1 - shade[..., None]) + SHADE * shade[..., None]
    # strata: darker and redder bands (weaker on the lit face, cooler on the shadow face)
    band = strata(seed + 1, w)[..., None] * (1.0 - 0.2 * lit[..., None] - 0.3 * shade[..., None])
    c = c * (1.0 - band * np.array([0.13, 0.27, 0.24]))
    # mottling and vertical runoff streaks
    mott = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)), 2.5) * 0.09
    streak = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)), (22, 1.2)) * 0.12
    c = c * (1.0 + mott[..., None] + streak[..., None])
    # its tops: a pale rim on the lit and middle faces, the shadow face's top a lighter lavender; under a cap
    # rock an undercut's shade
    rim = np.clip(1.0 - (dt - 1.0) / 3.0, 0.0, 1.0) * (1.0 - shade * 0.6)
    c = c * (1 - rim[..., None] * 0.75) + RIM * rim[..., None] * 0.75
    if cap > 0.0:
        under = np.exp(-((dt - cap) / 3.5) ** 2) * 0.22
        c = c * (1.0 - under[..., None])
    # the ink line down its shadow side (from its shoulder) and round its flared feet
    y = np.arange(h, dtype=float)[:, None] * np.ones((1, w))
    ink_r = np.clip(2.3 - dr, 0.0, 1.0) * np.clip((dt - 14.0) / 12.0, 0.0, 1.0)
    ink_l = np.clip(2.0 - dl, 0.0, 1.0) * np.clip((y - 140.0) / 30.0, 0.0, 1.0) * 0.85
    ink = np.maximum(ink_r, ink_l) * 0.85 * (1.0 - np.clip((y - 225.0) / 20.0, 0.0, 1.0))
    c = c * (1 - ink[..., None]) + INK * ink[..., None]
    # the haze of distance rising over its foot (as the strip's pieces)
    haze = np.clip((y - 150.0) / 85.0, 0.0, 1.0) ** 1.4 * 0.92
    c = c * (1 - haze[..., None]) + HAZE * haze[..., None]
    out = np.zeros((h, w, 4))
    out[..., :3] = np.clip(c, 0, 255)
    out[..., 3] = mask * 255.0
    return out


def spire():
    w = 104
    left = [(36, 18), (31, 22), (33, 30), (38, 40), (39, 66), (36, 104), (33, 140), (30, 168), (22, 198), (10, 228), (0, 249)]
    right = [(60, 14), (66, 18), (68, 25), (62, 33), (60, 48), (62, 80), (63, 124), (68, 162), (78, 200), (92, 232), (104, 249)]
    return finish(poly([left + right[::-1]], w), w, 1, 1.2), 12


def hoodoos():
    """A cluster of earth pillars, each its own height and girth, a boulder of cap rock on each."""
    w = 236
    shapes = []
    for cx, top, wid, cap_w in [(30, 92, 22, 30), (74, 30, 30, 40), (116, 104, 18, 24), (148, 60, 26, 34), (196, 128, 20, 26)]:
        # the boulder of cap rock: a squashed lump, wider than the neck under it, leaning to the right
        shapes.append(ellipse_pts(cx + 2, top + cap_w * 0.22, cap_w / 2, cap_w * 0.24, 0, 2 * np.pi, 20))
        neck = top + cap_w * 0.4
        shapes.append([(cx - wid * 0.42, neck), (cx - wid * 0.5, neck + 30), (cx - wid * 0.42, neck + 60),
                       (cx - wid * 0.62, 196), (cx - wid * 1.3, 249), (cx + wid * 1.3, 249), (cx + wid * 0.66, 196),
                       (cx + wid * 0.5, neck + 66), (cx + wid * 0.56, neck + 30), (cx + wid * 0.44, neck)])
    shapes.append([(0, 249), (8, 214), (34, 190), (100, 196), (170, 194), (214, 206), (236, 249)])
    return finish(poly(shapes, w), w, 2, 1.0), 9


def arch():
    w = 330
    outer = [(0, 249), (14, 210), (30, 160), (38, 92), (44, 70), (108, 64), (112, 58), (150, 58), (156, 72), (232, 80),
             (262, 84), (290, 88), (296, 120), (302, 170), (316, 214), (330, 249)]
    hole = ellipse_pts(186, 252, 74, 114, np.pi, 2 * np.pi)
    hole = [(x, min(y, 252)) for x, y in hole]
    return finish(cut(poly([outer], w), [hole]), w, 3, 1.0), 0


def broken_arch():
    """An arch whose crown has fallen: its two legs and the stubs of its span, broken off at a jagged slant."""
    w = 330
    outer = [(0, 249), (16, 208), (32, 156), (40, 78), (46, 52), (104, 46), (110, 40), (146, 40), (152, 50), (230, 58),
             (282, 64), (292, 74), (296, 124), (304, 176), (316, 214), (330, 249)]
    hole = [(x, min(y, 252)) for x, y in ellipse_pts(176, 252, 66, 140, np.pi, 2 * np.pi)]
    gap = [(178, 30), (204, 30), (198, 50), (206, 62), (196, 82), (200, 100), (186, 130), (176, 128), (182, 104),
           (172, 86), (182, 68), (172, 52)]
    return finish(cut(poly([outer], w), [hole, gap]), w, 4, 1.0), 0


def cracked_butte():
    w = 260
    body = [(0, 249), (18, 214), (36, 170), (44, 120), (46, 56), (52, 46), (118, 42), (124, 50), (131, 112),
            (139, 70), (146, 64), (204, 72), (212, 80), (216, 130), (222, 172), (238, 214), (260, 249)]
    return finish(poly([body], w), w, 5, 1.2), 8


def cuesta():
    w = 470
    body = [(0, 249), (22, 214), (44, 160), (54, 108), (60, 90), (70, 82), (96, 84), (150, 96), (220, 112),
            (300, 132), (370, 152), (420, 172), (450, 198), (470, 249)]
    return finish(poly([body], w), w, 6, 1.4), 6


PAINTED = [
    ("spire", spire, "spire"), ("hoodoos", hoodoos, "spire"), ("arch", arch, "arch"), ("broken_arch", broken_arch, "arch"),
    ("cracked_butte", cracked_butte, "block"), ("cuesta", cuesta, "low"),
]


def soften_ink(p):
    """The thin dark ink lines down a landform's flanks dissolve in the haze over its foot (on a pale far landform at
    dusk they read as wires hanging in the sky): blended into the rock round them, more the lower they are."""
    rgb = p[..., :3]
    closed = np.stack([ndimage.grey_closing(rgb[..., i], size=(5, 5)) for i in range(3)], axis=-1)
    line = np.clip((closed.mean(axis=-1) - rgb.mean(axis=-1) - 18.0) / 30.0, 0.0, 1.0)
    y = np.arange(p.shape[0], dtype=float)[:, None]
    k = (line * np.clip((y - 110.0) / 90.0, 0.0, 1.0))[..., None]
    out = p.copy()
    out[..., :3] = rgb * (1 - k) + closed * k
    return out


def main() -> None:
    strip = np.asarray(Image.open(Path(__file__).parent / "ref/far_mesas_strip.png").convert("RGBA")).astype(float)
    rows = [[], []]
    for a, b, kind in CUTS:
        p = strip[:, a:b].copy()
        w = b - a
        u = np.arange(w, dtype=float)
        side = np.minimum(u, w - 1 - u)
        k = np.clip(side / FADE, 0, 1)
        k = k * k * (3 - 2 * k)
        p[..., 3] *= k[None, :]
        rows[0].append((soften_ink(p), kind))
    for i, (name, fn, kind) in enumerate(PAINTED):
        mask, cap = fn()
        rows[1].append((soften_ink(paint(mask, 100 + i * 17, cap)), kind))
    width = max(sum(p.shape[1] + GAP for p, _ in r) for r in rows)
    img = np.zeros(((H + GAP) * 2, width, 4))
    pieces = []
    for r, row in enumerate(rows):
        x = 0
        for p, kind in row:
            img[r * (H + GAP):r * (H + GAP) + H, x:x + p.shape[1]] = p
            pieces.append([x, r * (H + GAP), p.shape[1], kind])
            x += p.shape[1] + GAP
    out = Image.fromarray(np.clip(img, 0, 255).round().astype(np.uint8), "RGBA")
    out.save(WORLD / "far_mesa_pieces.png", optimize=True)
    (WORLD / "far_mesa_pieces.json").write_text(json.dumps({"pieces": pieces, "height": H}))
    print("far_mesa_pieces written:", out.size, pieces)
    if "--sheet" in sys.argv:
        sheet = Image.new("RGBA", out.size, (150, 170, 205, 255))
        sheet.alpha_composite(out)
        sheet.save(sys.argv[sys.argv.index("--sheet") + 1])


if __name__ == "__main__":
    main()
