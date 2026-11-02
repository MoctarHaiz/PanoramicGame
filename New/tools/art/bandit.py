#!/usr/bin/env python3
"""The bandit: an original masked raider in the painted style of the hero sheet, posed in code.

A 2D skeleton (hips, spine, hooded head, arms, legs, a club, a scarf) is posed for every frame and
drawn as SVG shapes. Each body part is a flat-coloured group; one SVG filter per part paints it in
world space, like the hero's cel-shaded art: a soft core shadow away from the light (upper left),
a lit edge towards it, a warm sunset rim on the back edge and a dark ink outline. Headless Chrome
renders the sheet (tools/svg_to_png.py); it is then halved (smooth edges) into the game texture.

    python3 tools/art/bandit.py            # assets/art/bandit/bandit.png + bandit.json + club.png
    python3 tools/art/bandit.py --preview  # also a large preview on a sky colour in build/

The raider: a violet hood with hyena ears and a teal crest (the 2017 bandit's teal hair), glowing
amber eyes, a mustard face wrap with a black zigzag (the 2017 black and yellow), a leather vest,
an iron shoulder guard, white wrist and shin wraps, a studded wooden club raised to strike. All
skin is covered: a costume, not a people.

Frames (8 columns): row 0 the run (8), row 1 the hurt run (dazed, one ear flopped, a plaster),
row 2 the knock-out (hit, tumble). The figure faces left (bandits run at Panoramic).
bandit.json gives the cell size, the anchor (feet on the ground line, the middle of the hips), the
texture scale and the playback speed that keeps the planted foot still on the ground.
"""
import cmath
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/bandit"
SVG_TOOL = ROOT / "tools/svg_to_png.py"

UNITS = 4.0  # design px per game unit (the figure is drawn 4x, rendered, then halved to 2x)
TEXTURE_SCALE = 2.0
# Proportions, matched to the hero sheet's build (about six heads tall rather than a mascot's three):
# the hooded head smaller, legs, arms and torso longer. Every part placed from the head uses HEAD.
HEAD = 0.62
LEG = 1.3
ARM = 1.25
BODY = 1.25
CELL_W, CELL_H = 380, 560
GROUND_Y = 528  # ground line in the cell
HIP_X = 196  # the hips' x in the cell (the figure faces left: the club sticks out to the right)
COLS = 8
RUN_FRAMES = 8
KO_SHIFT = (-10, 48)  # the knocked-out poses moved left in their cells (design px) to fit
BANDIT_RUN_SPEED = 290.9  # World.BANDIT_RUN in units/s (relative to the ground)

# Palette (the hero sheet's saturation; violet so the raider stands out on the gold savanna).
INK = "#1a0d24"
HOOD = "#5b3a93"
HOOD_DARK = "#3f2870"
HOOD_SPOT = "#432a74"
EAR_IN = "#d7965e"
CREST = "#2ccfc4"
CREST_DARK = "#14958f"
FACE_HOLE = "#160b1f"
EYE = "#fff2a0"
EYE_GLOW = "#ffb21e"
WRAP = "#eba52c"
WRAP_DARK = "#2a1610"
VEST = "#4c3226"
VEST_TRIM = "#e9b04a"
SASH = "#1fa39b"
SLEEVE = "#6a4aa0"
PANTS = "#40305f"
PANTS_FOLD = "#271c3d"
WHITE_WRAP = "#f1e8d8"
WRAP_LINE = "#b9a993"
GLOVE = "#2b2232"
BOOT = "#2c2236"
BOOT_CAP = "#e2a43a"
IRON = "#7d8aa3"
IRON_DARK = "#4b5670"
WOOD = "#9a6234"
WOOD_DARK = "#5f3a1d"
PLASTER = "#f6efe2"


# ------------------------------------------------------------------ geometry (complex numbers, y down)

def rot(a: float) -> complex:
    return cmath.exp(1j * a)


def down(angle_deg: float) -> complex:
    """Unit vector pointing down, swung forward (towards +x, the way he runs before the mirror)."""
    return 1j * rot(-math.radians(angle_deg))


class Frame:
    """Collects SVG for one cell. Points are designed facing right; emit() mirrors them to face left."""

    def __init__(self, ox: float, oy: float):
        self.ox, self.oy = ox, oy  # cell origin on the sheet (the hip x / ground line point)
        self.parts: list[str] = []

    def p(self, z: complex) -> str:
        return f"{self.ox - z.real:.2f},{self.oy + z.imag:.2f}"

    def xy(self, z: complex) -> tuple[float, float]:
        return self.ox - z.real, self.oy + z.imag

    # shapes -------------------------------------------------------------
    def circle(self, c: complex, r: float, fill: str, extra: str = "") -> str:
        x, y = self.xy(c)
        return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="{fill}" {extra}/>'

    def ellipse(self, c: complex, rx: float, ry: float, angle: float, fill: str, extra: str = "") -> str:
        x, y = self.xy(c)
        # mirrored: angles flip sign
        return (f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rx:.2f}" ry="{ry:.2f}" fill="{fill}" '
                f'transform="rotate({-math.degrees(angle):.2f} {x:.2f} {y:.2f})" {extra}/>')

    def poly(self, pts: list, fill: str, extra: str = "") -> str:
        return f'<polygon points="{" ".join(self.p(z) for z in pts)}" fill="{fill}" {extra}/>'

    def smooth(self, pts: list, fill: str, extra: str = "", closed: bool = True, tension: float = 1.0) -> str:
        return f'<path d="{self.smooth_d(pts, closed, tension)}" fill="{fill}" {extra}/>'

    def smooth_d(self, pts: list, closed: bool = True, tension: float = 1.0) -> str:
        """Catmull-Rom through the points, as cubic Beziers."""
        n = len(pts)
        P = [complex(*self.xy(z)) for z in pts]
        d = f"M{P[0].real:.2f},{P[0].imag:.2f} "
        rng = range(n) if closed else range(n - 1)
        for i in rng:
            p0 = P[(i - 1) % n] if closed or i > 0 else P[i]
            p1 = P[i]
            p2 = P[(i + 1) % n]
            p3 = P[(i + 2) % n] if closed or i + 2 < n else P[(i + 1) % n]
            c1 = p1 + (p2 - p0) / 6 * tension
            c2 = p2 - (p3 - p1) / 6 * tension
            d += f"C{c1.real:.2f},{c1.imag:.2f} {c2.real:.2f},{c2.imag:.2f} {p2.real:.2f},{p2.imag:.2f} "
        return d + ("Z" if closed else "")

    def line(self, pts: list, stroke: str, width: float, extra: str = "") -> str:
        return (f'<path d="{self.smooth_d(pts, closed=False)}" fill="none" stroke="{stroke}" '
                f'stroke-width="{width:.2f}" stroke-linecap="round" stroke-linejoin="round" {extra}/>')

    def capsule(self, a: complex, b: complex, ra: float, rb: float, fill: str) -> str:
        """Two circles joined by their outer tangents (a tapered limb)."""
        d = b - a
        L = abs(d)
        if L < 1e-3:
            return self.circle(a, max(ra, rb), fill)
        u = d / L
        th = math.acos(max(-1.0, min(1.0, (ra - rb) / L)))
        pts = [a + ra * u * rot(th), b + rb * u * rot(th), b + rb * u * rot(-th), a + ra * u * rot(-th)]
        return self.circle(a, ra, fill) + self.circle(b, rb, fill) + self.poly(pts, fill)

    def tube(self, pts: list, radii: list, fill: str) -> str:
        return "".join(self.capsule(pts[i], pts[i + 1], radii[i], radii[i + 1], fill) for i in range(len(pts) - 1))

    def part(self, body: str, filt: str = "celM") -> None:
        self.parts.append(f'<g filter="url(#{filt})">{body}</g>')

    def raw(self, body: str) -> None:
        self.parts.append(body)


def local(origin: complex, angle: float, scale: float = 1.0, flip: float = 1.0):
    """Maps head- or hand-local points (x forward, y down) into the figure."""
    r = rot(angle) * scale
    return lambda x, y: origin + complex(x, y * flip) * r


# ------------------------------------------------------------------ filters (world space)

def cel_filter(fid: str, shade: float, lit: float, rim: float, outline: float, blur: float,
               shade_alpha: float = 0.66, lit_alpha: float = 0.42, rim_alpha: float = 0.8) -> str:
    """Paints a flat group: core shadow (down right), lit edge (up left), warm rim (right edge), ink."""
    sx, sy = -shade * 0.62, -shade * 0.78  # the shape shifted towards the light leaves its shadow side
    lx, ly = lit * 0.62, lit * 0.78
    return f'''
<filter id="{fid}" x="-40%" y="-40%" width="180%" height="180%" color-interpolation-filters="sRGB">
  <feOffset in="SourceAlpha" dx="{sx:.2f}" dy="{sy:.2f}" result="sA"/>
  <feComposite in="SourceAlpha" in2="sA" operator="out" result="shRaw"/>
  <feGaussianBlur in="shRaw" stdDeviation="{blur:.2f}" result="shSoft"/>
  <feFlood flood-color="#26104a" flood-opacity="{shade_alpha}"/>
  <feComposite in2="shSoft" operator="in" result="shade"/>
  <feOffset in="SourceAlpha" dx="{lx:.2f}" dy="{ly:.2f}" result="lA"/>
  <feComposite in="SourceAlpha" in2="lA" operator="out" result="liRaw"/>
  <feGaussianBlur in="liRaw" stdDeviation="{blur * 0.7:.2f}" result="liSoft"/>
  <feFlood flood-color="#fff0d2" flood-opacity="{lit_alpha}"/>
  <feComposite in2="liSoft" operator="in" result="lit"/>
  <feOffset in="SourceAlpha" dx="{-rim:.2f}" dy="{rim * 0.25:.2f}" result="rA"/>
  <feComposite in="SourceAlpha" in2="rA" operator="out" result="rimRaw"/>
  <feGaussianBlur in="rimRaw" stdDeviation="0.5" result="rimSoft"/>
  <feFlood flood-color="#ffb066" flood-opacity="{rim_alpha}"/>
  <feComposite in2="rimSoft" operator="in" result="rim"/>
  <feMerge result="painted"><feMergeNode in="SourceGraphic"/><feMergeNode in="shade"/><feMergeNode in="lit"/><feMergeNode in="rim"/></feMerge>
  <feComposite in="painted" in2="SourceAlpha" operator="in" result="inside"/>
  <feMorphology in="SourceAlpha" operator="dilate" radius="{outline:.2f}" result="dil"/>
  <feFlood flood-color="{INK}"/>
  <feComposite in2="dil" operator="in" result="ink"/>
  <feMerge><feMergeNode in="ink"/><feMergeNode in="inside"/></feMerge>
</filter>'''


def grad(gid: str, light: str, base: str, dark: str) -> str:
    return (f'<radialGradient id="{gid}" cx="0.3" cy="0.22" r="0.95" fx="0.28" fy="0.18">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="0.45" stop-color="{base}"/>'
            f'<stop offset="1" stop-color="{dark}"/></radialGradient>')


DEFS = "".join([
    grad("gHood", "#8a64c8", HOOD, "#3a2468"),
    grad("gVest", "#7a5340", VEST, "#2c1a14"),
    grad("gWrap", "#ffd77a", WRAP, "#b9741a"),
    grad("gWood", "#c78a4e", WOOD, "#5e3a1d"),
    grad("gIron", "#e6ecf5", IRON, "#3e4760"),
    grad("gEar", "#f1bd85", EAR_IN, "#a96a3c"),
    grad("gBoot", "#5a4a6a", BOOT, "#140c1a"),
    cel_filter("celL", shade=16, lit=6, rim=3.2, outline=3.0, blur=2.6),
    cel_filter("celM", shade=10, lit=4, rim=2.6, outline=3.0, blur=1.8),
    cel_filter("celS", shade=6, lit=3, rim=2.0, outline=2.6, blur=1.2),
    cel_filter("celT", shade=3.5, lit=2, rim=1.6, outline=2.4, blur=0.9, shade_alpha=0.45),
    cel_filter("celFar", shade=8, lit=2, rim=1.6, outline=2.6, blur=1.6, shade_alpha=0.38, lit_alpha=0.14, rim_alpha=0.35),
    '''<filter id="glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="5"/></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.2"/></filter>''',
])


def far(colour: str, k: float = 0.78) -> str:
    """The far side of the body, in the shade of the near side."""
    c = colour.lstrip("#")
    r, g, b = (int(c[i:i + 2], 16) for i in (0, 2, 4))
    # darker and a little towards violet (the ambient of the shadow)
    r, g, b = r * k + 30 * (1 - k), g * k + 14 * (1 - k), b * k + 60 * (1 - k)
    return "#%02x%02x%02x" % (int(r), int(g), int(b))


# ------------------------------------------------------------------ the run (8 keys, right leg first)

# Leg keys: (thigh angle forward of vertical, knee bend, foot angle: 0 flat, + toe down)
LEG_KEYS = [
    (34, 12, -12),   # 0 contact: heel reaches forward
    (18, 44, 0),     # 1 down: the knee takes the weight
    (-6, 34, 6),     # 2 passing: under the body
    (-30, 16, 34),   # 3 push off: toes drive back
    (-44, 62, 46),   # 4 the other foot lands: this one rises behind
    (-22, 112, 40),  # 5 heel kicks up
    (24, 108, 20),   # 6 passing forward, folded
    (50, 58, -4),    # 7 reaching forward
]
SUPPORT = {0, 1, 2, 3}  # frames where the right leg carries him (the left: +4)
LIFT = [0, 0, 0, 7, 0, 0, 0, 7]  # flight after each push-off


def leg(fr: Frame, hip: complex, key: tuple, near: bool, scale: float = 1.0) -> tuple[str, complex, complex]:
    """Returns the SVG of a leg and its knee and ankle."""
    thigh, bend, foot_a = key
    knee = hip + down(thigh) * 60 * LEG * scale
    ankle = knee + down(thigh - bend) * 58 * LEG * scale
    pants = PANTS if near else far(PANTS)
    wrap = WHITE_WRAP if near else far(WHITE_WRAP, 0.68)
    boot = BOOT if near else far(BOOT, 0.8)
    cap = BOOT_CAP if near else far(BOOT_CAP)
    s = ""
    # baggy trousers: a full thigh, gathered at the knee
    mid = (hip + knee) / 2 + down(thigh + 90) * 3
    s += fr.tube([hip, mid, knee], [19 * scale, 21 * scale, 15 * scale], pants)
    t_dir = (knee - hip) / abs(knee - hip)
    fold = PANTS_FOLD if near else far(PANTS_FOLD)
    s += fr.line([knee - t_dir * 6 + t_dir * 1j * 8, knee - t_dir * 22 + t_dir * 1j * 2], fold, 2.0)
    s += fr.line([knee - t_dir * 10 - t_dir * 1j * 9, knee - t_dir * 30 - t_dir * 1j * 4], fold, 1.8)
    shin_top = knee + down(thigh - bend) * 4
    s += fr.tube([knee, shin_top], [15 * scale, 13 * scale], pants)
    # shin wraps (white, banded)
    s += fr.capsule(shin_top, ankle, 12 * scale, 9.5 * scale, wrap)
    d = down(thigh - bend)
    n = d * 1j
    for k in (0.25, 0.5, 0.75):
        c = shin_top + (ankle - shin_top) * k
        w = (12 - 2.5 * k) * scale
        s += fr.line([c - n * w + d * 3, c + n * w - d * 3], WRAP_LINE if near else far(WRAP_LINE), 1.6)
    # boot: a rounded wedge, toe forward
    fa = math.radians(foot_a)
    f = local(ankle, fa, scale)
    boot_pts = [f(-10, -8), f(4, -10), f(18, -4), f(34, 4), f(36, 12), f(24, 15), f(-8, 15), f(-14, 6)]
    s += fr.smooth(boot_pts, "url(#gBoot)" if near else boot)
    s += fr.smooth([f(22, -1), f(34, 4), f(36, 12), f(26, 14), f(20, 6)], cap)
    s += fr.line([f(-12, 11), f(33, 13)], "#140a1a", 1.8)  # sole
    if near:
        s += fr.line([f(24, 1), f(31, 4)], "#fff1c8", 1.6, 'opacity="0.85"')
        s += fr.line([f(-6, -4), f(6, -6)], "#8a7aa0", 1.4, 'opacity="0.8"')
    return s, knee, ankle


def foot_bottom(ankle: complex, foot_a: float, scale: float = 1.0) -> float:
    """The lowest point of a boot (largest y)."""
    f = local(ankle, math.radians(foot_a), scale)
    return max(z.imag for z in [f(-8, 15), f(24, 15), f(36, 12), f(-14, 6)])


def arm(fr: Frame, shoulder: complex, upper: float, bend: float, near: bool, fist: bool = True,
        hand_angle: float | None = None) -> tuple[str, complex, complex]:
    """An arm: upper angle (forward of vertical), elbow bend (forward). Returns svg, elbow, wrist."""
    elbow = shoulder + down(upper) * 50 * ARM
    wrist = elbow + down(upper + bend) * 44 * ARM
    sleeve = SLEEVE if near else far(SLEEVE)
    wrap = WHITE_WRAP if near else far(WHITE_WRAP, 0.68)
    glove = GLOVE if near else far(GLOVE, 0.85)
    s = fr.tube([shoulder, elbow], [14, 11.5], sleeve)
    cuff = elbow + (wrist - elbow) * 0.45
    s += fr.capsule(elbow, cuff, 11.5, 10.5, sleeve)
    fold = far(SLEEVE, 0.55) if near else far(SLEEVE, 0.45)
    u = down(upper)
    s += fr.line([elbow - u * 18 + u * 1j * 7, elbow - u * 6 + u * 1j * 2], fold, 1.8)
    s += fr.line([elbow - u * 26 - u * 1j * 6, elbow - u * 14 - u * 1j * 9], fold, 1.5)
    s += fr.capsule(cuff, wrist, 10, 8.5, wrap)
    d = down(upper + bend)
    for k in (0.35, 0.7):
        c = cuff + (wrist - cuff) * k
        s += fr.line([c - d * 1j * 9 + d * 2, c + d * 1j * 9 - d * 2], WRAP_LINE if near else far(WRAP_LINE), 1.4)
    hand = wrist + d * 9
    if fist:
        s += fr.circle(hand, 11.5, glove)
        ha = math.radians(upper + bend) if hand_angle is None else hand_angle
        h = local(hand, -ha)
        s += fr.line([h(-6, 4), h(6, 5)], "#0e0814", 1.4)
    else:
        # an open, clawing hand
        s += fr.circle(hand, 9.5, glove)
        for k, a in enumerate((-30, 0, 30)):
            tip = hand + down(upper + bend + a) * 17
            s += fr.capsule(hand + down(upper + bend + a) * 6, tip, 4.2, 3.0, glove)
    return s, elbow, hand


def club(fr: Frame, hand: complex, angle: float) -> str:
    """The studded club: handle in the fist, head out along `angle` (radians, 0 = forward)."""
    c = local(hand, angle)
    s = fr.capsule(c(-14, 0), c(30, 0), 5.5, 7.5, WOOD)
    s += fr.smooth([c(24, -9), c(48, -16), c(76, -18), c(92, -11), c(95, 2), c(87, 15), c(60, 17), c(28, 9)], "url(#gWood)")
    s += fr.line([c(42, -8), c(80, -10)], WOOD_DARK, 2.0)
    s += fr.line([c(50, 3), c(84, 5)], WOOD_DARK, 1.6)
    s += fr.poly([c(30, -11), c(41, -14), c(41, 12), c(30, 10)], IRON_DARK)
    for x, y in ((58, -16), (77, -18), (91, -6), (68, 16)):
        s += fr.poly([c(x - 4.5, y), c(x, y - 8 if y < 0 else y + 8), c(x + 4.5, y)], "#c9d2e0")
    return s


def ribbon(fr: Frame, root: complex, angle: float, phase: float, count: int, seg: float, width: float,
           amp: float, colour: str, stripe: str | None, waves: float = 2.0, droop: float = 3.0) -> str:
    """A strip of cloth streaming from `root` along `angle` (degrees), a wave running down it."""
    pts = [root]
    z = root
    for k in range(1, count + 1):
        wave = amp * math.sin(phase * 2 * math.pi * waves - k * 0.95) * (0.4 + k / count)
        z = z + rot(math.radians(angle + wave + k * droop)) * seg
        pts.append(z)
    left, right = [], []
    for k, z in enumerate(pts):
        t = pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]
        n = t / abs(t) * 1j
        w = width * (1 - 0.55 * k / len(pts))
        left.append(z + n * w)
        right.append(z - n * w)
    end = pts[-1] + (pts[-1] - pts[-2]) * 0.35
    n = (pts[-1] - pts[-2]) / abs(pts[-1] - pts[-2]) * 1j
    # a swallow-tail end
    shape = left + [end + n * width * 0.5, pts[-1] + (pts[-1] - pts[-2]) * -0.1, end - n * width * 0.5] + right[::-1]
    s = fr.smooth(shape, colour)
    if stripe:
        s += fr.line(pts[1:-2], stripe, width * 0.22)
    return f'<g filter="url(#celT)">{s}</g>'


def hood(fr: Frame, head: complex, tilt: float, hurt: bool, ko: bool, phase: float, ear_lag: float) -> None:
    """The hooded head: ears, a teal crest, the hood with its brim, glowing eyes in the shade under
    the brim, and the face wrap."""
    h = local(head, tilt, HEAD)
    # far ear, behind the hood
    ef = local(h(-16, -34), tilt + math.radians(-58 + ear_lag * 0.6), HEAD)
    fr.part(fr.smooth([ef(0, -12), ef(22, -14), ef(44, -6), ef(50, 2), ef(30, 11), ef(2, 12)], far(HOOD, 0.75)), "celFar")
    # crest: teal spikes through a slit along the top of the hood
    spikes = ""
    for k, (x, y, a, L) in enumerate(((26, -40, -62, 20), (12, -48, -84, 27), (-4, -50, -106, 25), (-19, -45, -128, 20))):
        base = h(x, y)
        tip = base + rot(tilt + math.radians(a + 7 * math.sin(phase * 4 * math.pi - k * 0.8))) * L * HEAD
        side = rot(tilt + math.radians(a + 90)) * 7.5 * HEAD
        spikes += fr.smooth([base - side, base + (tip - base) * 0.55 - side * 0.35, tip, base + (tip - base) * 0.5 + side * 0.45, base + side], CREST, tension=0.6)
    fr.part(spikes, "celS")
    # the hood: round at the back, a cowl point over the face
    s = fr.smooth([h(-44, 10), h(-46, -16), h(-32, -40), h(-6, -52), h(24, -49), h(48, -34), h(62, -18),
                   h(68, -8), h(64, 8), h(60, 26), h(46, 40), h(18, 48), h(-16, 46), h(-36, 32)], "url(#gHood)")
    for x, y, r in ((-30, -14, 6.5), (-20, 10, 5), (-36, 16, 4.5), (-10, -32, 5.5), (-38, -2, 3.5), (0, 32, 4)):
        s += fr.circle(h(x, y), r * HEAD, HOOD_SPOT)
    s += fr.line([h(4, -50), h(-12, -24), h(-20, 4), h(-24, 34)], "#2c1a52", 1.5, 'stroke-dasharray="4 4" opacity="0.8"')
    s += fr.line([h(12, -24), h(30, -30), h(52, -24), h(66, -10), h(64, 10), h(56, 30)], "#3a2468", 4.0, 'opacity="0.7"')
    if hurt:  # a plaster crossed on the hood
        s += fr.poly([h(-30, -32), h(-6, -42), h(-3, -34), h(-27, -24)], PLASTER)
        s += fr.poly([h(-22, -46), h(-12, -22), h(-19, -20), h(-29, -43)], PLASTER)
    fr.part(s, "celL")
    # the face: a deep shade inside the hood, its top edge dipping into a frown between the eyes
    dip = 4 if ko else (-2 if hurt else 6)
    fr.raw(fr.smooth([h(16, -12), h(28, -17), h(42, -8 + dip), h(56, -18), h(65, -12), h(64, 6), h(56, 22),
                      h(36, 28), h(18, 22), h(12, 6)], FACE_HOLE, tension=0.8))
    # eyes: angled slits, inner corners down
    eyes = ""
    for ex, ey, sz, side in ((53, -6, 1.2, 1), (31, -6, 1.0, -1)):
        c = h(ex, ey)
        e = local(c, tilt, sz * HEAD)
        if ko:
            for a in (45, -45):
                d = rot(tilt + math.radians(a)) * 6.5 * sz * HEAD
                eyes += f'<path d="M{fr.p(c - d)} L{fr.p(c + d)}" stroke="{EYE}" stroke-width="{3.4 * sz:.2f}" stroke-linecap="round"/>'
            continue
        if hurt and side < 0:  # the far eye squeezed shut
            eyes += (f'<path d="{fr.smooth_d([e(-7, -2), e(0, 2), e(7, -2)], closed=False)}" stroke="{EYE_GLOW}" '
                     'stroke-width="3" fill="none" stroke-linecap="round"/>')
            continue
        if hurt:
            shape = [e(-7, -1), e(0, -3), e(7, -1), e(5, 3), e(-5, 3)]
        else:  # side 1: inner corner at -x; side -1: inner corner at +x
            shape = [e(-9 * side, 2), e(-2 * side, -2), e(9 * side, -7), e(8 * side, 1), e(0, 4)]
        halo = fr.circle(c, 9 * sz * HEAD, EYE_GLOW, 'opacity="0.55"')
        eyes += f'<g filter="url(#glow)">{fr.smooth(shape, EYE_GLOW, "", True, 0.5)}{halo}</g>'
        eyes += fr.smooth(shape, EYE, "", True, 0.5)
        eyes += fr.circle(e(1.5 * side, -1), 1.6 * sz * HEAD, "#ffffff")
    fr.raw(eyes)
    # the face wrap, pulled up over the nose
    w = [h(12, 8), h(30, 8), h(50, 6), h(64, 4), h(69, 12), h(64, 26), h(46, 38), h(24, 38), h(12, 26)]
    folds = (fr.line([h(16, 18), h(36, 22), h(60, 16)], "#b06d14", 2.2) + fr.line([h(22, 30), h(38, 33), h(54, 28)], "#b06d14", 1.8))
    band = fr.smooth([h(12, 8), h(30, 8), h(50, 6), h(64, 4), h(66, 9), h(50, 12), h(30, 14), h(12, 13)], WRAP_DARK)
    fr.part(fr.smooth(w, "url(#gWrap)") + folds + band, "celM")
    # near ear: up and back, flopped when hurt
    ear_a = tilt + math.radians(-104 + ear_lag)
    if hurt:
        ear_a = tilt + math.radians(-170 + ear_lag * 0.5)
    if ko:
        ear_a = tilt + math.radians(-140 + ear_lag)
    e = local(h(-18, -36), ear_a, HEAD)
    ear = [e(0, -13), e(24, -15), e(46, -6), e(54, 2), e(34, 12), e(2, 13)]
    inner = [e(8, -6), e(26, -7), e(44, -1), e(30, 6), e(8, 6)]
    fr.part(fr.smooth(ear, "url(#gHood)") + fr.smooth(inner, "url(#gEar)"), "celM")


def torso(fr: Frame, hip: complex, lean: float, breathe: float, phase: float) -> tuple[str, complex, complex, complex]:
    """The hunched body in its vest. Returns svg, the neck, the near shoulder and the far shoulder."""
    base = local(hip, math.radians(lean))
    t = lambda x, y: base(x, y * BODY)  # a longer torso, same width
    b = breathe
    body = [t(-20, 6), t(-26, -22), t(-31, -54 - b), t(-22, -80 - b), t(-6, -92 - b), t(10, -90 - b),
            t(26, -72 - b), t(29, -48), t(24, -24), t(20, 4), t(0, 12)]
    s = fr.smooth(body, "url(#gVest)")
    s += fr.line([t(23, -6), t(28, -40), t(24, -74 - b), t(10, -88 - b)], VEST_TRIM, 3.0)  # front trim
    s += fr.line([t(-16, -84 - b), t(2, -54), t(20, -18)], "#2e1d16", 6.5)  # strap
    s += fr.line([t(-16, -84 - b), t(2, -54), t(20, -18)], VEST_TRIM, 2.2)
    s += fr.circle(t(4, -51), 4.5, VEST_TRIM)
    s += fr.circle(t(3, -52.5), 1.6, "#fff6d8")
    # stitched seams
    s += fr.line([t(-24, -18), t(-28, -50 - b), t(-20, -76 - b)], "#c79a6a", 1.4, 'stroke-dasharray="4 4" opacity="0.7"')
    s += fr.line([t(16, -10), t(20, -40)], "#c79a6a", 1.3, 'stroke-dasharray="4 4" opacity="0.6"')
    # the sash at the waist, a pouch on it
    s += fr.smooth([t(-24, -4), t(0, -8), t(24, -6), t(25, 8), t(0, 10), t(-24, 10)], SASH)
    s += fr.line([t(-20, 2), t(0, -1), t(20, 1)], "#0f6e68", 1.6)
    s += fr.circle(t(-24, 2), 6.5, SASH)
    s += fr.smooth([t(4, 2), t(16, 1), t(18, 16), t(10, 20), t(3, 15)], "#6e4a2c")
    s += fr.line([t(4, 6), t(17, 5)], "#3a2214", 1.6)
    s += fr.circle(t(11, 9), 1.8, VEST_TRIM)
    return s, t(4, -88 - b), t(-4, -72 - b), t(-12, -76 - b)


def figure(fr: Frame, frame: int, hurt: bool, idle: float | None = None) -> dict:
    """A run frame, or (idle = 0..1) the crouch of a bandit waiting to pounce, breathing."""
    phase = frame / RUN_FRAMES
    right = LEG_KEYS[frame]
    left = LEG_KEYS[(frame + 4) % 8]
    beat = math.sin(phase * 4 * math.pi + 0.6)  # twice a cycle: once per step
    lean = 30 + (8 if hurt else 0) + 3 * beat
    if idle is not None:
        right, left = (20, 46, -2), (-16, 40, 12)
        phase = 0.12 + idle * 0.06
        lean = 24 + 4 * idle
    # place the hips so the planted boot touches the ground (and floats a little in flight)
    _, _, ra = leg(Frame(0, 0), 0j, right, True)
    _, _, la = leg(Frame(0, 0), 0j, left, False)
    lowest = max(foot_bottom(ra, right[2]), foot_bottom(la, left[2]))
    hip = complex(0, -lowest - (0 if idle is not None else LIFT[frame]))
    t_svg, neck, shoulder, shoulder_far = torso(fr, hip, lean, 1.5 * math.sin(phase * 4 * math.pi), phase)
    head = neck + down(180 - lean - 14) * 40 * HEAD + 6 * HEAD
    tilt = math.radians(-4 + 3 * math.sin(phase * 4 * math.pi + 1.4) + (9 if hurt else 0))
    swing = math.sin(phase * 2 * math.pi)
    # the far arm holds the club up and back, ready to strike, bobbing with the steps
    pump = math.sin(phase * 4 * math.pi + 0.3)
    s_far_arm, _, club_hand = arm(fr, shoulder_far, 196 + 6 * pump + (14 if hurt else 0), -30 + 6 * pump, near=False)
    fr.part(club(fr, club_hand, math.radians(-140 + 8 * pump + (22 if hurt else 0))), "celM")
    fr.part(s_far_arm, "celFar")
    s_leg, _, l_ankle = leg(fr, hip + 3, left, near=False)
    fr.part(s_leg, "celFar")
    # the scarf's tails and the sash's tails stream back
    knot = local(head, tilt, HEAD)(-40, 22)
    fr.raw(ribbon(fr, knot, 174, phase, 6, 13, 11, 14, far(WRAP, 0.85), None, droop=2.0))
    fr.raw(ribbon(fr, knot + 2j, 162, phase + 0.25, 7, 14, 13, 12, WRAP, WRAP_DARK, droop=1.5))
    fr.part(t_svg, "celL")
    t = local(hip, math.radians(lean))
    fr.raw(ribbon(fr, t(-26, 2), 170, phase + 0.4, 5, 11, 6.5, 18, SASH, None, waves=2, droop=6))
    s_leg, _, r_ankle = leg(fr, hip, right, near=True)
    fr.part(s_leg, "celM")
    hood(fr, head, tilt, hurt, False, phase, ear_lag=-12 * math.sin(phase * 4 * math.pi - 0.9))
    # the near arm pumps, a fist forward
    s_arm, _, _ = arm(fr, shoulder, 22 - 42 * swing, 62 + 12 * swing, near=True, fist=True)
    # the iron shoulder guard
    g = local(shoulder + down(180 - lean) * 4, math.radians(lean))
    guard = fr.smooth([g(-18, 6), g(-17, -8), g(-4, -17), g(12, -15), g(20, -2), g(16, 10), g(0, 13)], "url(#gIron)")
    guard += fr.poly([g(-10, -13), g(-17, -29), g(-1, -16)], "#d5dbe6") + fr.poly([g(3, -15), g(6, -30), g(13, -12)], "#d5dbe6")
    guard += fr.line([g(-17, 4), g(-2, 8), g(17, 3)], VEST_TRIM, 2.2)
    guard += fr.line([g(-10, -8), g(-2, -12)], "#ffffff", 2.0, 'opacity="0.9"')
    fr.part(s_arm, "celM")
    fr.part(guard, "celS")
    return {"hip_y": hip.imag, "ankles": (r_ankle, l_ankle), "head": head}


def knocked_out(fr: Frame, which: int) -> None:
    """0: the blow lands (thrown back, limbs flung). 1: tumbling, spread out."""
    if which == 0:
        hip = complex(0, -100)
        lean, tilt = -24, math.radians(-30)
        legs = [(64, 40, -20), (36, 76, -10)]
        arms = [(150, -30), (205, -40)]
    else:
        hip = complex(0, -112)
        lean, tilt = -58, math.radians(-62)
        legs = [(82, 20, -30), (16, 96, 10)]
        arms = [(196, -14), (128, 30)]
    phase = 0.3
    t_svg, neck, shoulder, shoulder_far = torso(fr, hip, lean, 0, phase)
    head = neck + down(180 - lean - 10) * 40 * HEAD
    a_svg, _, _ = arm(fr, shoulder_far, arms[1][0], arms[1][1], near=False, fist=False)
    fr.part(a_svg, "celFar")
    s_leg, _, _ = leg(fr, hip + 3, legs[1], near=False)
    fr.part(s_leg, "celFar")
    fr.raw(ribbon(fr, neck - 10, 150 + lean, phase, 7, 13, 10, 20, WRAP, WRAP_DARK))
    fr.part(t_svg, "celL")
    s_leg, _, _ = leg(fr, hip, legs[0], near=True)
    fr.part(s_leg, "celM")
    hood(fr, head, tilt, True, True, phase, ear_lag=34)
    s_arm, _, _ = arm(fr, shoulder, arms[0][0], arms[0][1], near=True, fist=False)
    fr.part(s_arm, "celM")


def sheet_svg() -> tuple[str, list]:
    rows = 3
    w, h = CELL_W * COLS, CELL_H * rows
    cells = []
    meta = []
    for i in range(RUN_FRAMES * 2 + 4):
        col, row = i % COLS, i // COLS
        fr = Frame(col * CELL_W + HIP_X, row * CELL_H + GROUND_Y)
        if i < RUN_FRAMES * 2:
            info = figure(fr, i % RUN_FRAMES, hurt=i >= RUN_FRAMES)
            meta.append(info)
        elif i < RUN_FRAMES * 2 + 2:
            fr.ox -= KO_SHIFT[i - RUN_FRAMES * 2]
            knocked_out(fr, i - RUN_FRAMES * 2)
        else:
            figure(fr, 0, hurt=False, idle=float(i - RUN_FRAMES * 2 - 2))
        cells.append("".join(fr.parts))
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
           f"<defs>{DEFS}</defs>{''.join(cells)}</svg>")
    return svg, meta


def club_svg() -> str:
    fr = Frame(170, 60)  # the figure is mirrored: the club reaches left from the grip
    fr.part(club(fr, 0j, 0.0), "celM")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="200" height="120" viewBox="0 0 200 120">'
            f"<defs>{DEFS}</defs>{''.join(fr.parts)}</svg>")


def render(svg: str, out: Path) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp, "art.svg")
        src.write_text(svg)
        subprocess.run([sys.executable, str(SVG_TOOL), str(src), str(out)], check=True, stdout=subprocess.DEVNULL)
    return Image.open(out).convert("RGBA")


def halve(img: Image.Image) -> Image.Image:
    """Halves with premultiplied alpha (no dark fringes), then un-premultiplies."""
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    pre = np.dstack([rgb, a[..., 3:4]])
    small = np.asarray(Image.fromarray((pre * 255 + 0.5).astype(np.uint8), "RGBA").resize(
        (img.width // 2, img.height // 2), Image.LANCZOS)).astype(np.float32) / 255.0
    alpha = small[..., 3:4]
    col = np.where(alpha > 1e-4, small[..., :3] / np.maximum(alpha, 1e-4), 0)
    return Image.fromarray((np.dstack([np.clip(col, 0, 1), alpha]) * 255 + 0.5).astype(np.uint8), "RGBA")


def mottle(img: Image.Image, amount: float = 0.07) -> Image.Image:
    """A painted surface: soft blotches of light and shade (smooth noise at two scales) and a
    fine grain, so the flat fills read as brushed paint like the hero's."""
    from scipy import ndimage
    a = np.asarray(img).astype(np.float32) / 255.0
    rng = np.random.default_rng(3)
    h, w = a.shape[:2]
    blot = ndimage.gaussian_filter(rng.standard_normal((h, w)), 3.0)
    blot2 = ndimage.gaussian_filter(rng.standard_normal((h, w)), 1.0)
    noise = blot / (np.abs(blot).max() + 1e-6) * 0.75 + blot2 / (np.abs(blot2).max() + 1e-6) * 0.25
    k = 1.0 + amount * noise[..., None]
    rgb = np.clip(a[..., :3] * k, 0, 1)
    return Image.fromarray((np.dstack([rgb, a[..., 3:4]]) * 255 + 0.5).astype(np.uint8), "RGBA")


def run_fps() -> float:
    """Frames per second that keep the planted boot still: it moves back with the ground."""
    xs = []
    for f in range(4):
        _, _, ankle = leg(Frame(0, 0), 0j, LEG_KEYS[f], True)
        xs.append(ankle.real)
    travel_units = (xs[0] - xs[3]) / UNITS  # design px over three frame steps
    return BANDIT_RUN_SPEED * 3 / travel_units


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build = ROOT / "build/art"
    build.mkdir(parents=True, exist_ok=True)
    svg, meta = sheet_svg()
    (build / "bandit_sheet.svg").write_text(svg)
    big = render(svg, build / "bandit_sheet_4x.png")
    sheet = mottle(halve(big))
    sheet.save(OUT / "bandit.png", optimize=True)
    club_big = render(club_svg(), build / "club_4x.png")
    club_img = halve(club_big)
    bbox = club_img.getbbox()
    club_img = club_img.crop(bbox)
    club_img.save(OUT / "club.png", optimize=True)
    k = TEXTURE_SCALE / UNITS
    data = {
        "cell": [CELL_W * k, CELL_H * k],
        "columns": COLS,
        "rows": 3,
        "anchor": [HIP_X * k, GROUND_Y * k],  # feet on the ground, under the hips
        "texture_scale": TEXTURE_SCALE,
        "run_frames": RUN_FRAMES,
        "run_fps": round(run_fps(), 2),
        "hurt_row": 1,
        "ko_row": 2,  # columns 0-1: knocked out; 2-3: idle (breathing in, out)
        # the middle of the hood in each run frame, in cell texture px (dazed stars circle above it)
        "head": [[round((HIP_X - m["head"].real) * k, 1), round((GROUND_Y + m["head"].imag) * k, 1)] for m in meta[:RUN_FRAMES]],
        "club_grip": [170 * k * 2 / 2 - bbox[0], 60 * k * 2 / 2 - bbox[1]],  # the handle end, in club.png px
        "hip_y": [round(m["hip_y"] * k, 2) for m in meta[:RUN_FRAMES]],
    }
    # the middle of each knocked-out pose (what it spins around), in cell texture px
    a = np.asarray(sheet)[..., 3]
    cw, ch = int(CELL_W * k), int(CELL_H * k)
    centres = []
    for col in range(2):
        cell = a[2 * ch:3 * ch, col * cw:(col + 1) * cw]
        ys, xs = np.where(cell > 60)
        centres.append([round(float(xs.mean()), 1), round(float(ys.mean()), 1)])
    data["ko_centres"] = centres
    (OUT / "bandit.json").write_text(json.dumps(data, indent=1))
    print("bandit sheet", sheet.size, "run fps", data["run_fps"])
    if "--preview" in sys.argv:
        bg = Image.new("RGBA", big.size, (120, 176, 232, 255))
        bg.alpha_composite(big)
        bg.convert("RGB").save(build / "bandit_preview.png")


if __name__ == "__main__":
    main()
