#!/usr/bin/env python3
"""Panoramic's faces: one picture per expression, laid over his face by its rest shape (hero_toon_aaa.py: the face
material's decal, mapped by the rest shape's y and z, so it bends with his face in every pose).

Round 15 (the character judges: "the face never reads at phone size", "heavy blue eyeshadow and glowing blue irises
read as make-up", "calm eyes on a dazed game over", "an angry face on the win"): the old painted eyes, brows and mouth
are filled with his own skin (taken round them in a front picture of his face), and new ones drawn over it, a little
bigger, in the game's bold language: clear whites, a dark brown iris with a warm lower half and two catchlights, a
thick lash line with a flick, strong tapered brows, and a mouth that acts (a gritted shout, an open grin, a slack daze).

    python3 tools/art/hero_face.py   # writes ROOT/_agents/AAA/hero3d/textures/face/face_<expression>.png

The picture's frame: 1024 px across 0.17 rest units, centred on (y 0, z 0.365); x right = his left (+y), up = +z.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())
DIR = ROOT / "_agents/AAA/hero3d/textures/face"
N = 1024  ## px of the picture
SS = 4  ## drawn at 4x and reduced (smooth edges)
EYES = ((395.0, 538.0), (635.0, 538.0))  ## the old eyes' centres (picture px): his right eye, his left eye
MOUTH = (513.0, 736.0)  ## the mouth's centre
EYE_W = 192.0  ## px from corner to corner (round 14's were ~155; round 16: 178 -> 192, "bigger, cleaner shapes")
EYE_H = 0.5  ## the opening's height, a share of its width
MOUTH_W = 168.0  ## (round 16: 150 -> 168)
PAINT_WHITE = (0.97, 0.95, 0.9)  ## (round 16, "one distinctive, iconic feature": tribal face paint in his white and red)
PAINT_RED = (0.78, 0.07, 0.06)
INK = (0.11, 0.05, 0.04)  ## lash lines and brows: a warm near-black (sRGB)
WHITE = (0.96, 0.94, 0.89)
IRIS = ((0.07, 0.035, 0.025), (0.22, 0.11, 0.06), (0.58, 0.31, 0.12))  ## the iris: its ring, its top, its warm lower half
MOUTH_IN = (0.2, 0.045, 0.045)
TEETH = (0.97, 0.95, 0.9)
TONGUE = (0.72, 0.27, 0.27)
LIP = (0.32, 0.12, 0.08)

# per expression: brow (raise, inner end, tilt per eye), lids (top, bottom) per eye, gaze (x, y: a share of the
# eye's width), iris size, mouth (kind, open, smile, width)
EXPRESSIONS = {
    "determined": dict(brow=(0.0, -0.32), lids=((0.18, 0.12), (0.18, 0.12)), gaze=(-0.12, 0.0), mouth=("line", 0.0, -0.15, 1.0)),
    "shout": dict(brow=(-0.05, -0.55), lids=((0.22, 0.18), (0.22, 0.18)), gaze=(0.12, 0.0), mouth=("teeth", 0.58, -0.3, 1.1)),
    "grin": dict(brow=(0.32, 0.2), lids=((0.0, 0.36), (0.0, 0.36)), gaze=(-0.14, 0.02), mouth=("grin", 0.7, 0.85, 1.3)),
    "smile": dict(brow=(0.25, 0.12), lids=((0.04, 0.42), (0.04, 0.42)), gaze=(-0.12, 0.0), mouth=("grin", 0.62, 1.0, 1.32)),
    "dazed": dict(brow=(0.15, 0.25), brow_tilt=(0.25, -0.2), lids=((0.55, 0.08), (0.08, 0.05)), gaze=(0.0, 0.0),
                  gaze_each=((0.16, 0.1), (-0.12, -0.12)), iris=0.82, mouth=("slack", 0.35, -0.1, 0.8)),
    "focus": dict(brow=(-0.02, -0.38), lids=((0.16, 0.12), (0.16, 0.12)), gaze=(0.2, -0.22), mouth=("open", 0.28, -0.1, 0.9)),
    "effort": dict(brow=(-0.02, -0.5), lids=((0.25, 0.2), (0.25, 0.2)), gaze=(0.12, 0.08), mouth=("teeth", 0.32, -0.2, 1.08)),
    "hurt": dict(brow=(0.1, 0.5), lids=((0.6, 0.42), (0.6, 0.42)), gaze=(0.0, 0.0), mouth=("teeth", 0.42, -0.45, 1.05)),
}


def _pts(f, n=48):
    return [f(i / (n - 1)) for i in range(n)]


class Canvas:
    """Layers drawn at SS x: each a mask, composited in order (colour, mask) onto an RGBA picture."""

    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.float32)
        self.a = np.zeros((N, N), np.float32)

    def mask(self, draw):
        img = Image.new("L", (N * SS, N * SS), 0)
        draw(ImageDraw.Draw(img), SS)
        m = np.asarray(img, np.float32).reshape(N, SS, N, SS).mean((1, 3)) / 255.0
        return m

    def paint(self, colour, m, opacity=1.0):
        m = np.clip(m * opacity, 0, 1)
        c = np.asarray(colour, np.float32)
        self.rgb = self.rgb * (1 - m[..., None]) + c * m[..., None]
        self.a = self.a + m * (1 - self.a)

    def multiply(self, colour, m):
        c = np.asarray(colour, np.float32)
        self.rgb = self.rgb * (1 - m[..., None]) + self.rgb * c * m[..., None]


def stroke(d, s, pts, widths, colour=255):
    """A tapered stroke: a polygon round the points, `widths` (px) at each."""
    pts = np.asarray(pts, np.float64) * s
    w = np.asarray(widths, np.float64) * s
    tan = np.gradient(pts, axis=0)
    tan /= np.maximum(np.hypot(*tan.T)[:, None], 1e-6)
    nrm = np.stack([-tan[:, 1], tan[:, 0]], -1)
    left = pts + nrm * (w[:, None] / 2)
    right = pts - nrm * (w[:, None] / 2)
    d.polygon([tuple(p) for p in np.concatenate([left, right[::-1]])], fill=colour)
    for p, r in ((pts[0], w[0] / 2), (pts[-1], w[-1] / 2)):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colour)


def clean_skin():
    """The front picture with the old eyes, brows and mouth (and the hair in front of them) filled with the skin round
    them: a smooth pull of the surrounding skin into the holes."""
    src = np.asarray(Image.open(DIR / "front_albedo.png").convert("RGBA"), np.float32) / 255.0
    reg = np.asarray(Image.open(DIR / "front_regions.png").convert("RGB"), np.int32)
    skin = (np.abs(reg - np.array([255, 203, 169])).sum(-1) < 40) | (np.abs(reg - np.array([231, 170, 124])).sum(-1) < 40)
    yy, xx = np.mgrid[0:N, 0:N]
    hole = np.zeros((N, N), bool)
    hole |= (xx > 285) & (xx < 745) & (yy > 430) & (yy < 615)  # eyes and brows
    hole |= (xx > 405) & (xx < 620) & (yy > 700) & (yy < 775)  # mouth
    # the old lines: darker than the skin round them, anywhere on the face's front
    good = skin & ~hole
    rgb = src[..., :3]
    fill = rgb * good[..., None]
    w = good.astype(np.float32)
    out = rgb.copy()
    todo = ~good
    for sigma in (3, 6, 12, 24, 48, 96):
        num = ndimage.gaussian_filter(fill, (sigma, sigma, 0))
        den = ndimage.gaussian_filter(w, sigma)
        ok = todo & (den > 0.05)
        out[ok] = num[ok] / den[ok, None]
        todo &= ~ok
    # a little of the painted shading kept: smooth the fill into the skin round it
    soft = ndimage.gaussian_filter(hole.astype(np.float32), 10)
    return out, np.clip(soft * 1.6, 0, 1), skin


def eye(cv, c, side, lids, gaze, iris_k, brow, tilt):
    """One eye at c; side -1 his right (picture left), +1 his left: its outer corner is on that side."""
    cx, cy = c
    W, H = EYE_W, EYE_W * EYE_H
    top, bot = lids
    ang = math.radians(7.0)  # the outer corner a little up: a hero's eye

    def corner(t):  # along the eye from the inner corner (t 0) to the outer (t 1)
        x = cx + side * (t - 0.5) * W
        y = cy + (0.12 - 0.3 * t) * H * 0.5 - side * 0 + math.tan(ang) * (-(t - 0.5) * W) * 0.35
        return x, y

    def up(t):
        x, y = corner(t)
        lift = H * 0.62 * (math.sin(math.pi * min(max(t, 0), 1)) ** 0.75) * (1.0 - top)
        return x, y - lift + H * 0.06 * (1 - t)

    def down(t):
        x, y = corner(t)
        drop = H * 0.4 * (math.sin(math.pi * min(max(t, 0), 1)) ** 0.9) * (1.0 - bot)
        return x, y + drop

    opening = _pts(up) + _pts(down)[::-1]
    m_open = cv.mask(lambda d, s: d.polygon([(x * s, y * s) for x, y in opening], fill=255))
    cv.paint(WHITE, m_open)
    # the iris (clipped to the opening), its warm lower half, the pupil and two catchlights
    R = W * 0.26 * iris_k
    ix, iy = cx + side * 0 + gaze[0] * W, cy - H * 0.06 + gaze[1] * W
    def disc(r, ox=0.0, oy=0.0, sx=1.0, sy=1.0):
        return lambda d, s: d.ellipse([(ix + ox - r * sx) * s, (iy + oy - r * sy) * s, (ix + ox + r * sx) * s,
                                       (iy + oy + r * sy) * s], fill=255)
    cv.paint(IRIS[0], cv.mask(disc(R, sy=1.06)) * m_open)
    cv.paint(IRIS[1], cv.mask(disc(R * 0.86, sy=1.06)) * m_open)
    low = cv.mask(disc(R * 0.72, 0, R * 0.22, sy=0.9))
    cv.paint(IRIS[2], ndimage.gaussian_filter(low, 3) * m_open * 0.85)
    cv.paint((0.03, 0.015, 0.012), cv.mask(disc(R * 0.42, sy=1.05)) * m_open)
    # the upper lid's shadow on the white
    shade = cv.mask(lambda d, s: stroke(d, s, _pts(lambda t: (up(t)[0], up(t)[1] + H * 0.12)),
                                        [H * 0.32] * 48))
    cv.multiply((0.72, 0.62, 0.62), shade * m_open * 0.7)
    cv.paint((1, 1, 1), cv.mask(disc(R * 0.2, -R * 0.34, -R * 0.36)) * m_open)
    cv.paint((1, 1, 1), cv.mask(disc(R * 0.08, R * 0.36, R * 0.3)) * m_open * 0.8)
    # the lash line: thick, thicker at the outer corner, with a flick; a thin lower lid; a crease
    flick = lambda t: (corner(1.0)[0] + side * W * 0.07 * t, corner(1.0)[1] - H * (0.03 + 0.08 * t))  # noqa: E731
    lash = _pts(up, 40) + _pts(flick, 8)[1:]
    widths = [W * (0.05 + 0.03 * (i / 39) ** 1.4) for i in range(40)] + [W * 0.08 * (1 - j / 7) + 2 for j in range(1, 8)]
    cv.paint(INK, cv.mask(lambda d, s: stroke(d, s, lash, widths)))
    low_line = _pts(lambda t: down(0.3 + 0.7 * t), 30)
    cv.paint((0.24, 0.11, 0.07), cv.mask(lambda d, s: stroke(d, s, low_line, [W * 0.018 + W * 0.012 * (i / 29) for i in range(30)])), 0.85)
    crease = _pts(lambda t: (up(0.25 + 0.6 * t)[0], up(0.25 + 0.6 * t)[1] - H * (0.28 + 0.1 * top)), 30)
    cv.paint((0.3, 0.14, 0.08), cv.mask(lambda d, s: stroke(d, s, crease, [W * 0.016 * math.sin(math.pi * i / 29) + 1 for i in range(30)])), 0.5)
    # the brow: a strong tapered stroke, the inner end thick
    raise_, inner = brow
    def brow_pt(t):
        # a hero's brow: thick and low at the inner end, rising to a peak two thirds out, falling a little at the end;
        # inner > 0: its inner end raised (joy, pain); < 0: lowered (anger, effort); tilt: the whole brow turned
        x = cx + side * (-0.46 + 1.1 * t) * W
        base = cy - H * (1.12 + 0.55 * raise_)
        y_in, y_peak, y_out = base - H * 0.9 * inner, base - H * 0.32, base + H * 0.02
        u = min(t / 0.65, 1.0)
        y = (1 - u) ** 2 * y_in + 2 * (1 - u) * u * (y_in + y_peak) / 2 + u * u * y_peak if t < 0.65 else \
            y_peak + (y_out - y_peak) * ((t - 0.65) / 0.35) ** 1.5
        return x, y + H * 0.25 * tilt * (2 * t - 1)
    pts = _pts(brow_pt, 40)
    cv.paint(INK, cv.mask(lambda d, s: stroke(d, s, pts, [W * (0.15 - 0.12 * (i / 39) ** 0.8) for i in range(40)])))


def mouth(cv, kind, opened, smile, width):
    cx, cy = MOUTH
    W = MOUTH_W * width
    Ho = W * 0.48 * opened

    def lip(t, y_off, curve):  # t 0..1 across; + smile lifts the corners
        x = cx + (t - 0.5) * W
        u = (t - 0.5) * 2
        return x, cy + y_off - smile * W * 0.12 * (u * u) + curve * (1 - u * u)

    if kind == "line":
        pts = _pts(lambda t: lip(t, 0, W * 0.03), 40)
        cv.paint(LIP, cv.mask(lambda d, s: stroke(d, s, pts, [W * (0.025 + 0.04 * math.sin(math.pi * i / 39)) for i in range(40)])))
        under = _pts(lambda t: lip(0.3 + 0.4 * t, W * 0.13, W * 0.02), 20)
        cv.paint((0.42, 0.2, 0.12), cv.mask(lambda d, s: stroke(d, s, under, [W * 0.03 * math.sin(math.pi * i / 19) + 1 for i in range(20)])), 0.45)
        return
    if kind == "slack":  # a small open mouth hanging a little to one side
        top = _pts(lambda t: (cx - W * 0.05 + (t - 0.5) * W * 0.75, cy - Ho * 0.15 + W * 0.04 * (2 * t - 1)), 30)
        bot = _pts(lambda t: (cx - W * 0.05 + (t - 0.5) * W * 0.62, cy + Ho * 0.85 * math.sin(math.pi * t) ** 0.8 + W * 0.04 * (2 * t - 1)), 30)
        shape = top + bot[::-1]
    elif kind in ("teeth", "open"):  # a wide, square mouth (a shout through the teeth), its corners down
        sq = 0.55 if kind == "teeth" else 0.25
        top = _pts(lambda t: lip(t, -Ho * 0.5, -Ho * 0.25 * sq), 40)
        bot = _pts(lambda t: lip(t, Ho * 0.6, Ho * (0.35 + 0.3 * (1 - sq))), 40)
        shape = top + bot[::-1]
    else:  # the grin: a broad D, the top nearly straight, the bottom deep, the corners up
        top = _pts(lambda t: lip(t, -Ho * 0.3, -Ho * 0.05), 40)
        bot = _pts(lambda t: lip(t, -Ho * 0.3, Ho * 1.0), 40)
        shape = top + bot[::-1]
    m = cv.mask(lambda d, s: d.polygon([(x * s, y * s) for x, y in shape], fill=255))
    cv.paint(MOUTH_IN, m)
    ys = np.array([p[1] for p in shape])
    y0, y1 = ys.min(), ys.max()
    yy = np.mgrid[0:N, 0:N][0].astype(np.float32)
    if kind in ("teeth", "grin", "open"):
        upper = (yy < y0 + (y1 - y0) * (0.4 if kind == "teeth" else 0.34 if kind == "grin" else 0.22)).astype(np.float32)
        teeth_m = ndimage.gaussian_filter(upper, 0.8) * m
        cv.paint(TEETH, teeth_m)
        if kind == "teeth":  # gritted: the lower teeth against the upper, a dark line between
            lower = (yy > y0 + (y1 - y0) * (0.47 + 0.15 * opened)).astype(np.float32)
            cv.paint((0.9, 0.88, 0.82), ndimage.gaussian_filter(lower, 0.8) * m)
        # the gaps between the teeth, faint
        xx = np.mgrid[0:N, 0:N][1].astype(np.float32)
        gaps = (np.abs(((xx - cx) / (W * 0.17)) % 1.0 - 0.5) > 0.47).astype(np.float32)
        cv.multiply((0.8, 0.77, 0.75), ndimage.gaussian_filter(gaps, 0.7) * m * 0.35)
    if kind == "grin":
        tongue = cv.mask(lambda d, s: d.ellipse([(cx - W * 0.22) * s, (y1 - Ho * 0.42) * s, (cx + W * 0.22) * s,
                                                 (y1 + Ho * 0.1) * s], fill=255))
        cv.paint(TONGUE, tongue * m)
    # the lips' line round it, heavier at the top and the corners
    edge = m - ndimage.binary_erosion(m > 0.5, iterations=4).astype(np.float32)
    cv.paint(LIP, np.clip(edge, 0, 1) * 0.95)
    if smile > 0.3:  # dimples at the corners
        for sgn in (-1, 1):
            c0 = shape[0] if sgn < 0 else shape[39]
            pts = _pts(lambda t: (c0[0] + sgn * W * 0.05 * t, c0[1] - W * 0.08 + W * 0.12 * t), 12)
            cv.paint((0.36, 0.16, 0.1), cv.mask(lambda d, s: stroke(d, s, pts, [W * 0.02 * math.sin(math.pi * i / 11) + 1 for i in range(12)])), 0.7)
    under = _pts(lambda t: (cx + (t - 0.5) * W * 0.38, y1 + W * 0.09 + W * 0.02 * math.sin(math.pi * t)), 20)
    cv.paint((0.42, 0.2, 0.12), cv.mask(lambda d, s: stroke(d, s, under, [W * 0.03 * math.sin(math.pi * i / 19) + 1 for i in range(20)])), 0.4)


def paint(cv):
    """His face paint: on each cheek, under the outer half of the eye, a red stripe with a white one over it, swept
    out and down; a red line and two white dots on his chin."""
    for (cx, cy), side in zip(EYES, (-1, 1)):
        for k, (colour, dy, w) in enumerate(((PAINT_WHITE, 70.0, 13.0), (PAINT_RED, 96.0, 17.0))):
            pts = _pts(lambda t: (cx + side * (EYE_W * (0.02 + 0.5 * t)), cy + dy + 26.0 * t), 24)
            cv.paint(colour, cv.mask(lambda d, s: stroke(d, s, pts, [w * (0.55 + 0.45 * math.sin(math.pi * (0.15 + 0.7 * i / 23))) for i in range(24)])))
    mx, my = MOUTH
    chin = _pts(lambda t: (mx, my + 62.0 + 42.0 * t), 12)
    cv.paint(PAINT_RED, cv.mask(lambda d, s: stroke(d, s, chin, [12.0 - 5.0 * i / 11 for i in range(12)])))
    for dx in (-26.0, 26.0):
        cv.paint(PAINT_WHITE, cv.mask(lambda d, s: d.ellipse([(mx + dx - 7) * s, (my + 80 - 7) * s, (mx + dx + 7) * s, (my + 80 + 7) * s], fill=255)))


def tear(cv):
    """(Dazed) a clean, bright tear under his right eye."""
    cx, cy = EYES[0]
    x, y = cx - EYE_W * 0.18, cy + EYE_W * 0.3
    m = cv.mask(lambda d, s: d.polygon([((x + 13 * math.sin(a)) * s, (y + 16 * (1 - math.cos(a)) - 18 * (a > math.pi / 2 and a < 3 * math.pi / 2)) * s)
                                         for a in np.linspace(0, 2 * math.pi, 40)], fill=255))
    m = cv.mask(lambda d, s: (d.ellipse([(x - 11) * s, (y) * s, (x + 11) * s, (y + 24) * s], fill=255),
                              d.polygon([((x - 9) * s, (y + 8) * s), ((x + 9) * s, (y + 8) * s), (x * s, (y - 16) * s)], fill=255)))
    cv.paint((0.72, 0.88, 1.0), m)
    cv.paint((1, 1, 1), cv.mask(lambda d, s: d.ellipse([(x - 6) * s, (y + 6) * s, (x - 1) * s, (y + 12) * s], fill=255)))


def make(name, e, base, base_a):
    cv = Canvas()
    cv.rgb[:] = base
    cv.a[:] = base_a
    for i, (c, side) in enumerate(zip(EYES, (-1, 1))):
        gaze = e.get("gaze_each", (e["gaze"], e["gaze"]))[i]
        tilt = e.get("brow_tilt", (0.0, 0.0))[i]
        eye(cv, c, side, e["lids"][i], gaze, e.get("iris", 1.0), e["brow"], tilt)
    paint(cv)
    mouth(cv, *e["mouth"])
    if name == "dazed":
        tear(cv)
    out = np.concatenate([np.clip(cv.rgb, 0, 1), np.clip(cv.a, 0, 1)[..., None]], -1)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(DIR / f"face_{name}.png", optimize=True)
    print("face", name)


def main():
    base, base_a, _ = clean_skin()
    for name, e in EXPRESSIONS.items():
        make(name, e, base, base_a)


if __name__ == "__main__":
    main()
