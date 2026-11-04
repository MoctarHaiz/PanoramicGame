#!/usr/bin/env python3
"""The CHAKA ZULU logo, rendered (numpy + Pillow): custom letters locked up with a Zulu shield, lit
from the upper left like the 3D hero, so the title belongs with him.

    python3 tools/art/ui_logo.py      # assets/art/ui/logo.png

- The letters are drawn here, not set in a font: heavy, chiselled (cut corners instead of round
  ones), their ends cut like blades (the C's mouth, the Z's and L's feet run out to a point), the A's
  apex an assegai's point rising above the line; CHAKA over a bigger ZULU, both on one gentle arch,
  leaning forward a little (he runs).
- Behind the middle of the words an isihlangu shield of cowhide (cream, dark brown patches, dark
  leather laces threaded down its middle, its stick through it with a tuft of fur at the top) stands
  taller than both lines, an assegai crossing behind it; its tips show above CHAKA and under ZULU
  (the menu's ribbon crosses its foot): one mark, not a picture beside a title.
- The letters: polished gold (a bright upper half, a crisp horizon to a deeper lower half, as metal
  reflecting the sky and the ground) with a rounded bevel (normals from the letters' distance field: lit top-left edges, shaded bottom-right
  ones, a hot specular), a thin light line inside a thick dark brown outline, an extruded depth, and
  a soft drop shadow under the whole, cast on the shield.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui/logo.png"
SS = 2  # drawn at twice the size, then halved (smooth edges)
W, H = 1400, 1000  # final size in px (cropped to the mark): the words over the shield, one mark
LIGHT = np.array([-0.5, -0.7, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
INK = np.array([46, 13, 4], float)


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def ramp(t, stops):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    pos = [p for p, _ in stops]
    cols = [hexc(c) for _, c in stops]
    for ch in range(3):
        out[..., ch] = np.interp(t, pos, [c[ch] for c in cols])
    return out


def dist_in(mask: np.ndarray) -> np.ndarray:
    return ndimage.distance_transform_edt(mask > 0.5)


def grow(mask: np.ndarray, r: float) -> np.ndarray:
    """The mask grown by r px (soft edge)."""
    d = ndimage.distance_transform_edt(mask < 0.5)
    return np.clip(r + 0.5 - d, 0, 1)


def shade(mask: np.ndarray, bevel: float, strength: float = 1.0, smooth: float = 1.0) -> tuple:
    """Lighting of a rounded bevel `bevel` px wide: (diffuse 0..1, specular 0..1). `smooth`: px of blur
    on its height (more for straight cut edges, whose distance field steps)."""
    if smooth > 1.0:  # the distance measured on a mask twice as fine: no steps along slanted edges
        fine = ndimage.zoom(mask, 2, order=1)
        dist = ndimage.zoom(ndimage.distance_transform_edt(fine > 0.5), 0.5, order=1) / 2.0
        dist = dist[:mask.shape[0], :mask.shape[1]]
    else:
        dist = dist_in(mask)
    d = np.minimum(dist, bevel) / bevel
    h = np.sqrt(1 - (1 - d) ** 2) * bevel * strength
    h = ndimage.gaussian_filter(h, smooth)
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    diffuse = np.clip(n @ LIGHT, 0, 1)
    half = LIGHT + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    spec = np.clip(n @ half, 0, 1) ** 40
    return diffuse, spec


def poly(points, w, h) -> np.ndarray:
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in points], fill=255)
    return np.asarray(img, float) / 255.0


def over(dst_rgb, dst_a, src_rgb, src_a):
    a = src_a[..., None]
    out_a = src_a + dst_a * (1 - src_a)
    rgb = (src_rgb * a + dst_rgb * dst_a[..., None] * (1 - a)) / np.maximum(out_a[..., None], 1e-6)
    return rgb, out_a


def cham(x0, y0, x1, y1, tl=0.0, tr=0.0, br=0.0, bl=0.0):
    """A rectangle with its corners cut (tl, tr, br, bl units), as a polygon."""
    return [(x0 + tl, y0), (x1 - tr, y0), (x1, y0 + tr), (x1, y1 - br), (x1 - br, y1), (x0 + bl, y1),
            (x0, y1 - bl), (x0, y0 + tl)]


# The letters, in units: the capital height 100, y down from the cap line, x from the letter's left.
# Each: (advance, [(+1 add | -1 cut, polygon), ...]). Strokes about 30 units; corners cut, not round.
GLYPHS = {
    "C": (88, [(1, cham(0, 0, 88, 100, 30, 24, 24, 30)), (-1, cham(30, 30, 60, 70, 10, 0, 0, 10)),
               (-1, [(54, 33), (96, 16), (96, 84), (54, 67)])]),
    "H": (96, [(1, cham(0, 0, 31, 100, 5, 5, 0, 0)), (1, cham(65, 0, 96, 100, 5, 5, 0, 0)),
               (1, [(26, 40), (70, 35), (70, 61), (26, 66)])]),
    "A": (112, [(1, [(0, 100), (56, -16), (112, 100), (79, 100), (72, 84), (40, 84), (33, 100)]),
                (-1, [(56, 50), (63.6, 68), (48.4, 68)])]),
    "K": (98, [(1, cham(0, 0, 31, 100, 5, 0, 0, 0)), (1, [(28, 38), (62, 0), (98, 0), (28, 80)]),
               (1, [(44, 54), (66, 36), (100, 100), (64, 100)])]),
    "Z": (90, [(1, [(0, 0), (90, 0), (90, 28), (8, 28)]), (1, [(56, 28), (90, 28), (34, 72), (0, 72)]),
               (1, [(0, 72), (80, 72), (94, 100), (0, 100)])]),
    "U": (94, [(1, cham(0, 0, 94, 100, 0, 0, 30, 30)), (-1, cham(31, -5, 63, 70, 0, 0, 10, 10))]),
    "L": (82, [(1, cham(0, 0, 31, 100, 5, 0, 0, 0)), (1, [(0, 70), (64, 70), (84, 100), (0, 100)])]),
}
TRACK = 7  # units between two letters
SLANT = 0.11  # the lean: x moves this much per unit up
ARCH = 16  # units the middle of each line rises above its ends


def word_width(word: str) -> float:
    return sum(GLYPHS[ch][0] for ch in word) + TRACK * (len(word) - 1)


def word_mask(w: int, h: int, word: str, cx: float, top: float, unit: float, span: float) -> np.ndarray:
    """One line of letters (px), its cap line at `top`, centred on cx, `unit` px per unit; the arch
    is measured over `span` px (both lines share it). Each letter is drawn 4x over its own box and
    shrunk (smooth edges: a stepped edge would light up in dots along its bevel)."""
    m = np.zeros((h, w))
    x = cx - word_width(word) * unit / 2
    up = 4
    for ch in word:
        adv, ops = GLYPHS[ch]
        polys = []
        for sign, pts in ops:
            pp = []
            for gx, gy in pts:
                px = x + (gx + (100 - gy) * SLANT) * unit
                u = (px - cx) / (span / 2)
                pp.append((px, top + gy * unit - ARCH * unit * (1 - min(u * u, 1.0))))
            polys.append((sign, pp))
        xs = [p[0] for _, pp in polys for p in pp]
        ys = [p[1] for _, pp in polys for p in pp]
        x0, y0 = int(min(xs)) - 4, int(min(ys)) - 4
        bw, bh = int(max(xs)) + 4 - x0, int(max(ys)) + 4 - y0
        layer = Image.new("L", (bw * up, bh * up), 0)
        draw = ImageDraw.Draw(layer)
        for sign, pp in polys:
            draw.polygon([((px - x0) * up, (py - y0) * up) for px, py in pp], fill=255 if sign > 0 else 0)
        small = np.asarray(layer.resize((bw, bh), Image.BOX), float) / 255.0
        m[y0:y0 + bh, x0:x0 + bw] = np.maximum(m[y0:y0 + bh, x0:x0 + bw], small)
        x += (adv + TRACK) * unit
    return m


def shield_layers(w: int, h: int, cx: float, cy: float, sh: float, ang: float = -0.42, tilt: float = 0.0):
    """The shield, its stick and an assegai behind it: [(rgb, alpha), ...] back to front. `ang`: the
    assegai's lean, `tilt`: the shield's (radians, positive leans its top to the left)."""
    layers = []
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # one long assegai behind, leaning right: a wooden shaft, a bound grip, a long iron leaf blade
    # with a ridge down its middle (one, not two: two blades either side read as ears)
    d = np.array([np.sin(ang), -np.cos(ang)])
    n = np.array([d[1], -d[0]])
    u = (xx - cx) * d[0] + (yy - cy) * d[1]
    v = (xx - cx) * n[0] + (yy - cy) * n[1]
    shaft = (np.abs(v) < sh * 0.02) & (u > -sh * 0.62) & (u < sh * 0.42)
    blade_u = (u - sh * 0.42) / (sh * 0.3)
    leaf = np.sin(np.clip(blade_u, 0, 1) ** 0.55 * np.pi)  # widest near its foot, a sharp point
    blade = (blade_u >= 0) & (blade_u <= 1) & (np.abs(v) < sh * 0.05 * leaf)
    m = ndimage.gaussian_filter((shaft | blade).astype(float), 1.0)
    diff, spec = shade(m, sh * 0.03)
    wood = ramp((v / (sh * 0.04)) * 0.5 + 0.5, [(0, "d8995a"), (0.5, "a8622e"), (1, "6a3414")])
    iron = ramp((v / (sh * 0.1)) * 0.5 + 0.5, [(0, "ffffff"), (0.48, "c4ccd8"), (0.52, "6a7280"), (1, "8a94a2")])
    rgb = np.where(blade[..., None], iron, wood) * (0.55 + 0.6 * diff[..., None]) + spec[..., None] * 255
    grip = shaft & (np.abs(u - sh * 0.42) < sh * 0.07) & (np.sin(u * 0.8) > 0)
    rgb = np.where(grip[..., None], hexc("e8d8b0") * (0.6 + 0.5 * diff[..., None]), rgb)
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(m, sh * 0.014)))
    layers.append((rgb, m))
    # the shield and its stick, leaning: sample them on a turned grid
    ct, st = np.cos(tilt), np.sin(tilt)
    xx, yy = (xx - cx) * ct + (yy - cy) * st + cx, -(xx - cx) * st + (yy - cy) * ct + cy
    # the shield's stick, through it from top to bottom, a tuft of fur at its top
    stick = (np.abs(xx - cx) < sh * 0.022) & (yy > cy - sh * 0.62) & (yy < cy + sh * 0.58)
    tuft_r = np.hypot((xx - cx) / (sh * 0.05), (yy - (cy - sh * 0.64)) / (sh * 0.07))
    tuft = tuft_r < 1 + 0.25 * np.sin(np.arctan2(yy - (cy - sh * 0.64), xx - cx) * 7)
    m = ndimage.gaussian_filter((stick | tuft).astype(float), 1.0)
    diff, spec = shade(m, sh * 0.025)
    stick_rgb = ramp(((xx - cx) / (sh * 0.044)) * 0.5 + 0.5, [(0, "c88a50"), (0.5, "8a4e24"), (1, "4a2410")])
    rgb = np.where(tuft[..., None], hexc("2a1a14"), stick_rgb) * (0.55 + 0.6 * diff[..., None]) + spec[..., None] * 160
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(m, sh * 0.014)))
    layers.append((rgb, m))
    # the shield: a tall oval of cowhide, pointed at both ends
    t = (yy - cy) / (sh * 0.5)
    half_w = sh * 0.25 * np.clip(1 - np.abs(t) ** 1.6, 0, 1) ** 0.72
    oval = ndimage.gaussian_filter(((np.abs(xx - cx) < half_w) & (np.abs(t) < 1)).astype(float), 1.0)
    diff, spec = shade(oval, sh * 0.08, 1.3)
    rng = np.random.default_rng(3)
    hide = ramp(t * 0.5 + 0.5, [(0, "fff8ea"), (0.6, "f2e2c4"), (1, "dcc096")])
    patches = np.zeros((h, w))
    for px, py, r in ((-0.6, -0.42, 0.44), (0.62, -0.02, 0.4), (-0.5, 0.42, 0.38), (0.55, 0.64, 0.3), (0.6, -0.64, 0.28)):
        ex, ey = cx + px * sh * 0.25, cy + py * sh * 0.5
        rr = np.hypot((xx - ex) / (r * sh * 0.28), (yy - ey) / (r * sh * 0.4))
        wob = 1 + 0.18 * np.sin(np.arctan2(yy - ey, xx - ex) * 5 + px * 7)
        patches = np.maximum(patches, np.clip((wob - rr) * 8, 0, 1))
    hair = ndimage.gaussian_filter(rng.standard_normal((h, w)), (6, 0.8)) * 6
    hide = hide * (1 - patches[..., None]) + hexc("3a1c10")[None, None] * patches[..., None]
    hide += hair[..., None]
    # the lacing down the middle: a band of darker hide, dark leather laces threaded across it
    band = np.abs(xx - cx) < sh * 0.05
    hide = np.where(band[..., None], hexc("c9a272"), hide)
    row = (yy - cy) / (sh * 0.07)
    lace = band & (np.abs(row - np.round(row)) < 0.16) & (np.abs(xx - cx) < sh * 0.042)
    lace_lit = band & (np.abs(row - np.round(row) + 0.12) < 0.05) & (np.abs(xx - cx) < sh * 0.036)
    hide = np.where(lace[..., None], hexc("4a2210"), hide)
    hide = np.where(lace_lit[..., None], hexc("9a6038"), hide)
    edge = band & (np.abs(np.abs(xx - cx) - sh * 0.05) < 2.0)
    hide = np.where(edge[..., None], hexc("6a3a1c"), hide)
    rgb = hide * (0.5 + 0.62 * diff[..., None]) + spec[..., None] * 180
    # the rim: a darker hide edge, as if the skin were folded over a frame
    rim = np.clip(1 - dist_in(oval) / (sh * 0.025), 0, 1)
    rgb = rgb * (1 - rim[..., None] * 0.45)
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(oval, sh * 0.018)))
    layers.append((rgb, oval))
    return layers


def text_layers(w: int, h: int, lines: list, unit: float, cx: float, span: float) -> tuple:
    """The letters, lit: `lines` = [(mask, cap line px, cap height px), ...] on an arch centred on cx,
    `span` px wide. (layers back to front, the letters' mask)."""
    m = np.zeros((h, w))
    for lm, _, _ in lines:
        m = np.maximum(m, lm)
    m = ndimage.gaussian_filter(m, 0.7)
    ow = unit * 9.0  # the outline's width
    depth = unit * 13.0
    outline = grow(m, ow)
    layers = []
    # the drop shadow and the extruded depth under the outline
    shadow = ndimage.gaussian_filter(ndimage.shift(outline, (depth + unit * 8, unit * 3)), unit * 5)
    layers.append((np.zeros((h, w, 3)), shadow * 0.55))
    steps = int(depth)
    for st in range(steps, 0, -1):
        sm = ndimage.shift(outline, (st, 0), order=1)
        k = st / steps
        layers.append((np.broadcast_to(INK * (0.9 + 0.5 * (1 - k)) + np.array([30, 6, 0]) * (1 - k), (h, w, 3)).copy(), sm))
    layers.append((np.broadcast_to(INK, (h, w, 3)).copy(), outline))
    # a thin warm light line just inside the outline
    layers.append((np.broadcast_to(hexc("ffe9b0"), (h, w, 3)).copy(), grow(m, ow * 0.28)))
    # the gold face: each line its own gradient along its arch, a bevel, a hot specular, a gloss band
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    grad = np.zeros((h, w))
    for lm, top, cap in lines:
        u = np.clip((xx - cx) / (span / 2), -1, 1)
        line_top = top - ARCH * unit * (1 - u * u)
        near = ndimage.binary_dilation(lm > 0.05, iterations=int(unit * 14))
        grad = np.where(near, (yy - line_top) / cap, grad)
    # polished metal: a bright upper half and a crisp horizon to a deeper, warmer lower half (the sky
    # and the ground reflected), not one soft gradient
    face = ramp(grad, [(0.0, "fffbd0"), (0.25, "ffe36a"), (0.5, "ffc83a"), (0.505, "f08a14"), (0.7, "ffa82a"),
                       (1.0, "d8560a")])
    diff, spec = shade(m, unit * 8.0, 1.6, 2.2)
    rgb = face * (0.62 + 0.5 * diff[..., None]) + spec[..., None] * 230

    layers.append((rgb, m))
    return layers, m


def main() -> None:
    w, h = W * SS, H * SS
    unit = (w * 0.7) / word_width("CHAKA")  # px per letter unit
    zulu = 1.22  # ZULU's letters are bigger
    words_x = w * 0.6  # the words' middle
    top1 = h * 0.22
    top2 = top1 + 100 * unit + 16 * unit
    block = (top2 + 100 * unit * zulu) - top1
    rgb = np.zeros((h, w, 3))
    a = np.zeros((h, w))
    # the shield, taller than both lines, its right half behind the C and the Z, leaning; the assegai
    # crossing behind it
    sh = block * 1.2
    left = words_x - word_width("CHAKA") * unit / 2
    for lr, la in shield_layers(w, h, left + 30 * unit, top1 + block * 0.5, sh, -0.5, -0.22):
        rgb, a = over(rgb, a, lr, la)
    span = word_width("CHAKA") * unit * 1.06
    lines = [(word_mask(w, h, "CHAKA", words_x, top1, unit, span), top1, 100 * unit),
             (word_mask(w, h, "ZULU", words_x, top2, unit * zulu, span), top2, 100 * unit * zulu)]
    layers, _ = text_layers(w, h, lines, unit, words_x, span)
    for lr, la in layers:
        rgb, a = over(rgb, a, lr, la)
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8), "RGBA")
    img = img.resize((W, H), Image.LANCZOS)
    box = img.getchannel("A").getbbox()
    img = img.crop((max(box[0] - 6, 0), max(box[1] - 6, 0), min(box[2] + 6, W), min(box[3] + 6, H)))
    # colour under the clear pixels: the nearest painted one (no dark halo when scaled)
    arr = np.asarray(img).astype(float)
    solid = arr[..., 3] > 2
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    arr[..., :3] = np.where(solid[..., None], arr[..., :3], arr[..., :3][iy, ix])
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print(f"{OUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
