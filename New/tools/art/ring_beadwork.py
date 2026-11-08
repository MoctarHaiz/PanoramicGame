#!/usr/bin/env python3
"""Panoramic's chakram, ONE design everywhere (round 20, the judges: "the chakram has FOUR designs: a blue disc with a
"D", a thin silver bangle, a spoked steering wheel, a hula hoop: one weapon, with blades and thickness"): a thick
blue-steel ring whose face carries a band of Zulu beadwork (red and black triangles on white, round 19), a steel grip
bar across its middle (where his hand holds it: the victory still's grip, the key art's crossbar) and four hooked
silver blades on its rim (the key art's silhouette: a weapon, not a wheel). The menu key art, the end screens' stills
(hero_atlas_ai.py stills(), with chakram_blades() / chakram_flat() below) and the flying ring in play all carry it.

- assets/art/fx/ring_spin.png (RingView): 8 frames of a half turn about its upright axis, side by side, 96 px each:
  face-on, turning, edge-on (its steel rim), then its other face.
- `design(px)`: the face-on design, any size (the kie.ai reference for the key art's edit: ROOT/_agents/AAA/...).

Painted in numpy at 4x and reduced (no aliasing on the triangles): each frame is the ring as a flat disc with a hole
and a thickness, turned by the frame's angle, drawn back to front (the far face, the rim's slices, the near face).

    python3 tools/art/ring_beadwork.py [DESIGN_OUT.png DESIGN_PX]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

NEW = Path(__file__).resolve().parents[2]
OUT = NEW / "assets/art/fx/ring_spin.png"
FRAMES, PX, SS = 8, 96, 4
# radii in shares of half the frame
R_TIP = 0.97  # the blades' tips
R_OUT = 0.71  # the ring's outer edge
RIM = 0.635  # the silver-steel rim outside the beadwork
BEAD_IN = 0.475  # the beadwork band: BEAD_IN .. RIM
R_IN = 0.4  # the hole (the inner blue-steel lip: R_IN .. BEAD_IN)
TRIANGLES = 14  # beadwork triangles round the band, each red or black in turn
THICK = 0.12  # the ring's thickness
BAR = 0.07  # the grip bar's half width (upright, across the hole)
BLADES = 4
BLADE_AT = np.radians(45.0)  # the first blade's root (between the bar's ends)
BLADE_SWEEP = 0.78  # radians the hook's tip runs ahead of its root's middle (the way it spins)
BLADE_ROOT = 0.42  # radians: half the root's width on the rim
INK = np.array([0.17, 0.085, 0.06])  # the characters' ink (HeroView.LINE): a dark warm brown
NAVY = np.array([0.06, 0.2, 0.42])
BLUE = np.array([0.16, 0.38, 0.7])
STEEL = np.array([0.66, 0.78, 0.9])
SILVER = np.array([0.88, 0.92, 0.96])
BLUE_EDGE = np.array([0.22, 0.45, 0.76])
WHITE = np.array([0.95, 0.92, 0.85])
RED = np.array([0.8, 0.12, 0.12])
BLACK = np.array([0.1, 0.07, 0.08])
SIDE = np.array([0.12, 0.3, 0.56])
GRIP = np.array([0.4, 0.22, 0.12])  # the leather wrap round the bar's middle
INK_W = 0.02


def _wrap(a):
    return (a + np.pi) % (2 * np.pi) - np.pi


def blades(rho, phi):
    """Where the hooked blades are (a 0/1 mask) and how far across each (0 at its leading edge .. 1 at its trailing,
    concave edge) and along it (0 at the root, 1 at the tip)."""
    on = np.zeros(rho.shape, bool)
    across = np.zeros(rho.shape)
    t = np.clip((rho - (R_OUT - 0.03)) / (R_TIP - (R_OUT - 0.03)), 0, 1)
    out = rho >= R_OUT - 0.03
    for k in range(BLADES):
        root = BLADE_AT + k * 2 * np.pi / BLADES
        lead = root + BLADE_ROOT + (BLADE_SWEEP - BLADE_ROOT) * t ** 1.6  # the convex leading edge
        trail = root - BLADE_ROOT + (BLADE_SWEEP + BLADE_ROOT) * t ** 0.85  # the concave trailing edge
        d_lead = _wrap(lead - phi)
        d_trail = _wrap(phi - trail)
        width = np.maximum(_wrap(lead - trail), 1e-4)
        inside = out & (rho <= R_TIP) & (d_lead >= 0) & (d_trail >= 0) & (d_lead + d_trail <= width + 1e-6)
        on |= inside
        across = np.where(inside, d_lead / width, across)
    return on, across, t


def face(rho, phi, lit, xx=None, yy=None):
    """The colour of the ring's face at polar (rho, phi) (and, for the bar, the face's own x, y), and whether it is
    there."""
    col = np.zeros(rho.shape + (3,))
    ring = (rho >= R_IN) & (rho <= R_OUT)
    if xx is None:
        xx, yy = rho * np.cos(phi), rho * np.sin(phi)
    bar = (np.abs(xx) <= BAR) & (rho < R_IN + 0.02)
    bl, across, t = blades(rho, phi)
    on = ring | bar | bl
    shine = 0.5 + 0.5 * np.cos(phi - np.radians(225))  # the light from the upper left
    # the blades: silver, their concave trailing side blue-steel
    blade = SILVER * (0.8 + 0.2 * shine[..., None])
    blade = np.where((across > 0.6)[..., None], BLUE_EDGE * (0.85 + 0.3 * shine[..., None]), blade)
    col[bl] = blade[bl]
    # the silver-steel rim, brighter towards the upper left
    rim = STEEL * (0.78 + 0.3 * shine ** 2)[..., None]
    col[ring] = np.clip(rim, 0, 1)[ring]
    lip = ring & (rho < BEAD_IN)  # the inner lip: blue steel
    col[lip] = (NAVY + (BLUE - NAVY) * (0.4 + 0.6 * shine[..., None]))[lip]
    # the beadwork: triangles standing on the band's inner edge, red and black in turn, white between
    band = (rho >= BEAD_IN) & (rho <= RIM)
    u = (phi / (2 * np.pi) * TRIANGLES) % 1.0
    k = np.floor(phi / (2 * np.pi) * TRIANGLES).astype(int) % 2
    v = (rho - BEAD_IN) / (RIM - BEAD_IN)
    tri = np.abs(u - 0.5) * 2.0 < (1.0 - v) * 0.92
    bead = np.where(tri[..., None], np.where((k == 0)[..., None], RED, BLACK), WHITE)
    col[band] = bead[band]
    # the grip bar (upright): blue steel lit on its left edge, a leather wrap round its middle
    barc = NAVY + (BLUE - NAVY) * np.clip(0.9 - (xx + BAR) / (2 * BAR) * 0.9, 0.1, 1.0)[..., None]
    wrap = (np.abs(yy) < R_IN * 0.45) & ((np.abs(yy) / 0.05) % 1.0 > 0.2)
    barc = np.where(wrap[..., None], GRIP * (1.15 - 0.4 * (xx + BAR) / (2 * BAR))[..., None], barc)
    bar_only = bar & ~ring
    col[bar_only] = barc[bar_only]
    # the drawn ink: round the zones, the bar's edges, the blades' edges (a drawn weapon, like the world's props)
    d = np.minimum.reduce([np.abs(rho - R_OUT), np.abs(rho - RIM), np.abs(rho - BEAD_IN)])
    d = np.where(bar & (rho < R_IN), np.inf, np.minimum(d, np.abs(rho - R_IN)))  # (no line across the bar's ends)
    d = np.where(bar_only, np.minimum(d, BAR - np.abs(xx)), d)
    ink = np.clip(1.0 - d / INK_W, 0, 1)  # (the blades' outline: the silhouette's, frame())
    col = col * (1 - ink[..., None]) + INK * ink[..., None]
    return col * lit, on


def _outline(rgb, alpha, px):
    """The figure's outer ink: `px` pixels round the silhouette (drawn at 4x, reduced)."""
    from scipy import ndimage as ndi
    solid = alpha > 0.5
    inner = ndi.binary_erosion(solid, iterations=max(1, int(round(px))))
    edge = solid & ~inner
    rgb[edge] = INK
    return rgb


def _reduce(img, px):
    """4x -> 1x, premultiplied (no dark fringe), straight alpha out."""
    pm = img.copy()
    pm[..., :3] *= pm[..., 3:4]
    ch = [np.asarray(Image.fromarray(pm[..., k].astype(np.float32)).resize((px, px), Image.BOX)) for k in range(4)]
    r = np.clip(np.dstack(ch), 0, 1)
    al = r[..., 3:4]
    r[..., :3] = np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), INK)
    return r


def frame(theta, px=PX, ss=SS):
    n = px * ss
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / (n / 2) - 1.0
    c, s = np.cos(theta), np.sin(theta)
    cc = c if abs(c) > 0.03 else 0.03 * (1 if c >= 0 else -1)
    rgb = np.zeros((n, n, 3))
    alpha = np.zeros((n, n))
    near = THICK / 2 if c >= 0 else -THICK / 2  # the face turned towards us
    slices = np.linspace(-near, near, 24)  # far face first
    for i, depth in enumerate(slices):
        X = (xx - depth * s) / cc
        rho = np.hypot(X, yy)
        phi = np.arctan2(yy, X)
        if i == len(slices) - 1 or i == 0:  # a face
            lit = 0.74 + 0.26 * abs(c)
            col, on = face(rho, phi if c >= 0 else np.pi - phi, lit, X if c >= 0 else -X, yy)
            if i == 0:  # the far face: the blades are thin plates, drawn once (the near face's)
                on = on & (rho <= R_OUT)
        else:  # the rim between the faces: the outer band lit from the left, the hole's wall darker; the blades thin
            ring = (rho >= R_IN) & (rho <= R_OUT)
            bar = (np.abs(X) <= BAR) & (rho < R_IN + 0.02)
            on = ring | (bar & (abs(depth) < THICK * 0.3))
            outer = rho > (R_IN + R_OUT) / 2
            shade = np.where(outer, 0.75 + 0.35 * np.clip(-xx, 0, 1), 0.55)
            col = SIDE * shade[..., None]
            edge = np.clip(1.0 - np.minimum(np.abs(rho - R_OUT), np.abs(rho - R_IN)) / 0.016, 0, 1)
            col = col * (1 - edge[..., None]) + INK * edge[..., None]
        rgb[on] = col[on]
        alpha[on] = 1.0
    rgb = _outline(rgb, alpha, ss * max(0.9, px * 0.0065))  # (the ink's weight: ~1 px in play, the stills' line big)
    return _reduce(np.dstack([rgb, alpha]), px)


def design(px, ss=2):
    """The face-on design, px across (straight alpha, float)."""
    return frame(0.0, px, ss)


# ------------------------------------------------------------------ the end screens' stills (hero_atlas_ai.py stills())

def warp(img, A, c, shape):
    """`img` (a face-on design, N x N, straight alpha, its frame's half = 1) drawn into a canvas of `shape` (h, w) by
    the affine map A (2x2: design units -> canvas px, x right, y down) about `c` (canvas px). Straight alpha out."""
    # A = U S Vt: turned in its own plane (Vt), squashed along the axes (S: a filtered resize, no aliasing on the
    # beadwork), turned again (U); each step on premultiplied colours
    U, S, Vt = np.linalg.svd(np.asarray(A, float))
    if np.linalg.det(U) < 0:  # (a mirror: kept in the squash)
        U[:, 1] *= -1
        S = S * np.array([1.0, -1.0])
    if np.linalg.det(Vt) < 0:
        Vt[1, :] *= -1
        S = S * np.array([1.0, -1.0])
    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").convert("RGBa")
    deg = lambda R: np.degrees(np.arctan2(R[1, 0], R[0, 0]))
    im = im.rotate(-deg(Vt), Image.BICUBIC, expand=True)
    k = abs(S) / (img.shape[0] / 2.0)
    im = im.resize((max(1, round(im.width * k[0])), max(1, round(im.height * k[1]))), Image.LANCZOS)
    if S[1] < 0:
        im = im.transpose(Image.FLIP_TOP_BOTTOM)
    im = im.rotate(-deg(U), Image.BICUBIC, expand=True)
    canvas = Image.new("RGBa", (shape[1], shape[0]), (0, 0, 0, 0))
    canvas.paste(im, (round(c[0] - im.width / 2), round(c[1] - im.height / 2)))
    return np.asarray(canvas.convert("RGBA")).astype(np.float64) / 255.0


def over(top, bottom):
    """Straight-alpha `top` over `bottom`."""
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    a = ta + ba * (1 - ta)
    rgb = (top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)) / np.maximum(a, 1e-6)
    return np.dstack([np.where(a > 1e-6, rgb, 0), a])


def rot(phi):
    c, s = np.cos(phi), np.sin(phi)
    return np.array([[c, -s], [s, c]])


def flat(shape, c, ax, ay, phi=0.0, thick=6, light=1.0):
    """The chakram lying flat on the ground (the defeat still): its blade tips' footprint `ax` x `ay` canvas px about
    `c`, turned `phi` in its own plane; its edge `thick` px below its face (the side, then the ink)."""
    from scipy import ndimage as ndi
    n = int(min(1600, max(256, 4 * ax / R_TIP)))
    A = np.diag([ax / R_TIP, ay / R_TIP]) @ rot(phi)
    top = warp(design(n), A, c, shape)
    top[..., :3] *= light
    fa = top[..., 3]
    side = np.zeros_like(fa)
    for d in range(1, thick + 1):
        side = np.maximum(side, ndi.shift(fa, (d, 0), order=1))
    edge = np.clip(ndi.shift(side, (1.5, 0), order=1), 0, 1)  # its lower edge drawn in ink
    under = np.zeros(tuple(shape) + (4,))
    under[..., :3] = INK
    under[..., 3] = edge
    wall = np.zeros_like(under)
    wall[..., :3] = SIDE * 0.85 * light
    wall[..., 3] = side
    return over(top, over(wall, under))


def blades_only(shape, ellipse, phi=0.0, light=1.0):
    """Only the hooked blades of the chakram, in the plane of a ring already drawn (the victory still's), whose outer
    edge is `ellipse` (xc, yc, a, b, theta: skimage's EllipseModel), turned `phi` in its plane. Drawn under the still,
    their roots tucked under its rim."""
    xc, yc, a, b, th = ellipse
    A = np.array([[a * np.cos(th), -b * np.sin(th)], [a * np.sin(th), b * np.cos(th)]]) / R_OUT @ rot(phi)
    n = int(min(1600, max(256, 4 * max(a, b) / R_OUT)))
    img = design(n)
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / (n / 2) - 1.0
    img[..., 3] *= np.hypot(xx, yy) > R_OUT - 0.04  # the ring's own body is the still's
    out = warp(img, A, (xc, yc), shape)
    out[..., :3] *= light
    return out


def save(arr, path):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


def main():
    if len(sys.argv) > 2:
        save(design(int(sys.argv[2])), sys.argv[1])
        print(sys.argv[1])
        return
    strip = np.concatenate([frame(f * np.pi / FRAMES) for f in range(FRAMES)], 1)
    save(strip, OUT)
    print(OUT.name, strip.shape[1], strip.shape[0])


if __name__ == "__main__":
    main()
