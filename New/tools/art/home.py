#!/usr/bin/env python3
"""HOME, the end of the level: a Zulu homestead (umuzi) at golden hour, painted in numpy.

  home_hut.png        the main beehive hut (iQukwane): a thatched dome bound with rope rings, a
                      finial of bound straw, a low arched doorway framed with bent saplings, the
                      hearth glowing inside. Panoramic walks into its doorway.
  home_hut_front.png  the part of that hut in front of him: the dome right of the doorway's right
                      post, and a darkness that deepens inside the opening (he goes into the shade)
  home_hut_small.png  a rondavel (round mud walls, a conical thatched roof), at the back
  home_hut_low.png    a squat, wider hut, also at the back
  home_granary.png    a granary basket on stilts under a thatched cone
  home_fence.png      a palisade of stakes bound with withies, tiles in x
  home_sign.png       a carved wooden signpost: an arrow board reading HOME, a border of triangles
  home_pot.png        a clay beer pot (ukhamba) with incised chevrons
  home_glow.png       warm firelight (drawn additively, flickering)
  home_yard.png       trodden earth before the doorway, laid over the grass
home.json gives sizes and the doorway's place in the hut picture (used by src/game/home_view.gd).
2 px per design unit, lit from the upper left like everything else.

    python3 tools/art/home.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
from paint import (ROOT, WORLD, blur, dither_rgba, fbm, hexc, mix, normals_light, poly_mask, ramp, save,  # noqa: E402
                   smooth)

PX = 2
SS = 3
L = np.array([-0.55, 0.75, 0.62])  # towards the light, in (right, up, towards the viewer)
L = L / np.linalg.norm(L)
THATCH = [(0.0, "5a3a2c"), (0.25, "8a5e36"), (0.5, "b78a4a"), (0.75, "dcb366"), (1.0, "f6dc98")]
WOOD = [(0.0, "3a2620"), (0.4, "6a4a34"), (0.75, "9c7450"), (1.0, "d0a676")]


def dome(R: float, H: float, w: int, h: int, cx: float, base: float, tiers: int = 0, step: float = 0.0):
    """Mask, light and surface coordinates of a beehive dome (units -> px handled by caller).
    Round 2: with `tiers`, each tier of thatch juts out `step` px at its fringe over the one below
    (a stepped, shaggy silhouette, not a smooth egg)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    z = np.clip((base - yy) / H, 0, 1.2)  # height share
    half = R * np.clip(1 - np.clip(z, 0, 1) ** 1.9, 0, 1) ** 0.55
    if tiers:
        tz = z * (tiers + 0.6)
        frac = tz - np.floor(tz)
        half = half + step * (1.0 - frac) ** 1.6 * (z < 0.97) * (tz >= 1.0)
    u = np.clip((xx - cx) / np.maximum(half, 1e-3), -1.5, 1.5)
    inside = (np.abs(xx - cx) <= half) & (yy <= base) & (z <= 1)
    # profile tilt: how much the surface faces up at this height
    dz = 1e-3
    h0 = R * (1 - np.clip(z, 0, 0.999) ** 1.9) ** 0.55
    h1 = R * (1 - np.clip(z + dz, 0, 0.999) ** 1.9) ** 0.55
    slope = (h0 - h1) / (dz * H)  # inward run per unit of rise
    tilt = np.arctan(slope)
    uu = np.clip(u, -1, 1)
    nz = np.sqrt(1 - uu * uu)
    n = np.dstack([uu * np.cos(tilt), np.sin(tilt) * np.ones_like(uu), nz * np.cos(tilt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    lam = np.clip(n @ L, 0, 1)
    return inside, lam, u, z


def thatch_strokes(w: int, h: int, inside: np.ndarray, u: np.ndarray, z: np.ndarray, cx: float, base: float,
                   H: float, rng, density: float = 1.0) -> np.ndarray:
    """Tone (-1..1) of straw strokes running down the dome along its meridians."""
    img = Image.new("L", (w * SS, h * SS), 128)
    d = ImageDraw.Draw(img)
    ys, xs = np.nonzero(inside)
    n = int(len(xs) / 14 * density)
    pick = rng.integers(0, len(xs), n)
    for k in pick:
        x, y = xs[k], ys[k]
        uu = np.clip(u[y, x], -1, 1)
        ln = rng.uniform(9, 22) * PX
        dx = uu * 0.45 * ln * (0.4 + z[y, x])
        v = int(np.clip(rng.normal(128, 60), 0, 255))
        d.line([(x * SS, y * SS), ((x + dx) * SS, (y + ln) * SS)], fill=v, width=max(1, int(rng.uniform(0.8, 1.6) * PX * SS)))
    t = np.asarray(img, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 128 - 1
    return t


def hut(R: float, H: float, door: bool, seed: int) -> tuple:
    """A beehive hut. Returns (rgba Image, front Image or None, info)."""
    rng = np.random.default_rng(seed)
    margin = 16
    w = int((2 * R + 2 * margin) * PX)
    h = int((H + 34) * PX)
    cx = w / 2
    base = h - 2 * PX
    Rp, Hp = R * PX, H * PX
    tiers = 5  # round 2: fewer, chunkier tiers (8 thin ones read as noise at phone size)
    inside, lam, u, z = dome(Rp, Hp, w, h, cx, base, tiers, 6.0 * PX)
    cov = inside.astype(float)
    # finial: a knot of bound straw on the apex
    apex_y = base - Hp
    fin = poly_mask(w, h, [[(cx - 5 * PX, apex_y + 6 * PX), (cx + 5 * PX, apex_y + 6 * PX), (cx + 2 * PX, apex_y - 14 * PX),
                            (cx - 2 * PX, apex_y - 14 * PX)]], ellipses=[(cx, apex_y - 15 * PX, 4 * PX, 4 * PX)])
    cov = np.clip(blur(cov, 0.6) * 1.2, 0, 1)
    cov = np.maximum(cov, fin)
    strokes = thatch_strokes(w, h, inside, u, z, cx, base, Hp, rng)
    t = np.clip(lam * 0.95 + strokes * 0.16 + 0.05, 0, 1)
    t = np.clip(t + 0.22 * (np.clip(z, 0, 1) - 0.45), 0, 1)  # round 2: lit from above, darker low down
    col = ramp(t, THATCH)
    # tiers of thatch: each ends in a jagged fringe of straw over the tier below, with a soft shadow
    # under it; a thin rope binds some of them
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    uu = np.clip(u, -1, 1)
    ring_rows = []
    for k in range(1, tiers + 1):
        zk = k / (tiers + 0.6)
        jag = (blur(rng.standard_normal(w)[None, :], (0, 0.8))[0] * 5.0 + rng.uniform(-1, 1)) * PX
        ring_y = base - zk * Hp + jag[None, :]
        dist = yy - ring_y
        shade = np.exp(-np.clip(dist, 0, None) / (8.0 * PX)) * (dist > 0) * inside
        fringe = np.exp(-np.clip(-dist, 0, None) / (5.0 * PX)) * (dist <= 0) * inside
        col = mix(col, col * np.array([0.38, 0.3, 0.4]), shade * 0.92)
        col = mix(col, np.minimum(col * 1.35 + 6, 255), fringe * 0.5)
        if k % 2 == 0:  # a rope ring binding the tier, its twists catching the light
            rope_d = (dist + 7.0 * PX) / (1.3 * PX)
            rope = np.exp(-rope_d ** 2) * inside
            twist = (np.sin(xx * 0.7 + rope_d * 2.0) > 0.4) * rope
            col = mix(col, hexc("3a2418"), rope * 0.85)
            col = mix(col, hexc("a8845a"), twist * (1 - np.clip(uu, 0, 1)) * 0.6)
        ring_rows.append(ring_y)
    # straw hanging over the edge of each tier: short strokes down from its ring line
    hang = Image.new("L", (w * SS, h * SS), 0)
    dh_ = ImageDraw.Draw(hang)
    for ring_y in ring_rows:
        for x in np.arange(cx - Rp, cx + Rp, 1.6):
            xi = int(np.clip(x, 0, w - 1))
            y0 = float(ring_y[0, xi]) if ring_y.ndim == 2 else float(ring_y[xi])
            if not (0 <= y0 < h) or not inside[int(y0), xi]:
                continue
            ln = rng.uniform(2.0, 7.0) * PX
            dh_.line([(x * SS, y0 * SS), ((x + rng.uniform(-1.2, 1.2) * PX) * SS, (y0 + ln) * SS)],
                     fill=int(rng.uniform(140, 255)), width=max(1, int(0.8 * PX * SS)))
    hm = np.asarray(hang, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    col = mix(col, np.minimum(col * 1.28 + 8, 255), hm * inside * 0.8)
    # a net of ropes from the apex down to the foot (meridians), bowing with the dome
    for m in range(7):
        um = -0.8 + 1.6 * m / 6 + rng.uniform(-0.05, 0.05)
        md = np.abs(uu - um) * np.maximum(1 - np.clip(z, 0, 1) ** 1.9, 0.05) ** 0.55 * Rp / (1.1 * PX)
        mrope = np.exp(-md ** 2) * inside * (z < 0.93)
        col = mix(col, hexc("4a3020"), mrope * 0.32 * (1 - 0.5 * np.abs(um)))
    # weathered patches: greyer, darker straw here and there
    patch = smooth(0.55, 0.8, fbm(h, w, 5, 7, 4, rng, False))
    col = mix(col, col * np.array([0.78, 0.76, 0.74]) + 10, patch * 0.65 * inside)
    fresh = smooth(0.6, 0.85, fbm(h, w, 4, 6, 4, rng, False))  # newer golden straw mended in
    col = mix(col, np.minimum(col * np.array([1.18, 1.1, 0.82]), 255), fresh * 0.55 * inside)
    # a shaggy outline: straw ends sticking out of the silhouette and at the foot
    tips = Image.new("L", (w * SS, h * SS), 0)
    dtp = ImageDraw.Draw(tips)
    ys_e, xs_e = np.nonzero(inside & ~np.roll(inside, 3, axis=1) | inside & ~np.roll(inside, -3, axis=1))
    for i in rng.integers(0, len(xs_e), int(len(xs_e) * 0.5)):
        x, y = xs_e[i], ys_e[i]
        side = -1 if x < cx else 1
        ln = rng.uniform(3, 11) * PX
        dtp.line([(x * SS, y * SS), ((x + side * ln * 0.7) * SS, (y + ln) * SS)], fill=255, width=max(1, int(1.0 * PX * SS)))
    for x in np.arange(cx - Rp, cx + Rp, 2.0):  # round 2: the fringe at the foot blown by the breeze
        ln = rng.uniform(3, 9) * PX
        dtp.line([(x * SS, (base - 3 * PX) * SS), ((x + rng.uniform(1.5, 6) * PX) * SS, (base - 3 * PX + ln * 0.8) * SS)], fill=255,
                 width=max(1, int(0.9 * PX * SS)))
    tm = np.asarray(tips, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    tip_col = ramp(np.clip(0.7 - (xx - cx) / Rp * 0.45, 0, 1), THATCH)
    col = np.where((tm > 0.02)[..., None] & ~inside[..., None], tip_col, col)
    cov = np.maximum(cov, tm * (1 - inside))
    # rope twists: light dots along each ring
    twist = (np.sin(xx * 0.9) > 0.75)
    # finial colour
    col = mix(col, ramp(np.clip(0.7 - (xx - cx) / (8 * PX), 0, 1), THATCH), fin)
    # ambient occlusion at the base and the shade side cooler
    col *= (1 - 0.45 * smooth(base - 18 * PX, base, yy))[..., None]
    col = mix(col, col * np.array([0.62, 0.56, 0.8]), smooth(0.0, 1.0, uu) * (1 - lam) * 0.75)
    # a warm sunset rim along the lit upper left edge, a few px wide, fading inwards
    edge = np.clip(cov - np.roll(np.roll(cov, 3, axis=1), 2, axis=0), 0, 1)
    glow = np.clip(cov - np.roll(np.roll(blur(cov, 3.0), 7, axis=1), 5, axis=0), 0, 1)
    col = mix(col, hexc("ffd08a"), np.clip(glow * 0.55 + edge * 0.6, 0, 1) * (1 - smooth(-0.2, 0.6, uu)))
    info = {"size": [w / PX, h / PX], "base": (h - base) / PX}
    front = None
    if door:
        dcx = cx - 0.36 * Rp
        dw, dh = 50 * PX, 176 * PX  # round 2: he is 150 tall and walks in upright
        arch_r = dw
        door_top = base - dh
        # the opening: a rectangle under a half-ellipse arch
        dyy = yy - (door_top + arch_r * 0.9)
        opening = (np.abs(xx - dcx) <= dw) & (yy <= base) & ((dyy >= 0) | (((xx - dcx) / dw) ** 2 + (dyy / (arch_r * 0.9)) ** 2 <= 1))
        op = blur(opening.astype(float), 0.7)
        frame_out = (np.abs(xx - dcx) <= dw + 9 * PX) & (yy <= base) & (
            (dyy >= 0) | (((xx - dcx) / (dw + 9 * PX)) ** 2 + (dyy / (arch_r * 0.9 + 9 * PX)) ** 2 <= 1))
        frame = np.clip(blur(frame_out.astype(float), 0.7) - op, 0, 1)
        # the frame: bent saplings, round section lit from the upper left
        fr_light = np.clip(0.55 - (xx - dcx) / (dw + 9 * PX) * 0.35 - dyy / (dh) * 0.15, 0, 1)
        fr_grain = blur(rng.standard_normal((h, w)), (0.8, 3))
        fr_col = ramp(np.clip(fr_light + fr_grain * 0.05, 0, 1), WOOD)
        # binding on the frame
        bands = (np.sin((yy + xx * 0.2) * 0.35) > 0.85) * frame
        fr_col = mix(fr_col, hexc("2a1a14"), bands * 0.5)
        # inside: dark, the hearth glowing low and deep inside
        g = np.clip(1 - np.hypot((xx - dcx - dw * 0.3) / (dw * 1.5), (yy - base + 10 * PX) / (dh * 0.7)), 0, 1)
        inner = ramp(g ** 1.2, [(0, "160806"), (0.3, "34140a"), (0.62, "8a3412"), (0.85, "d8702a"), (1, "f8b45a")])
        # the curved inner wall: thatch ribs lit by the fire, darker overhead
        ribs = (np.sin((xx - dcx) * 0.35 + (yy - base) * 0.05) > 0.55) * smooth(base - dh * 0.8, base - 20 * PX, yy)
        inner = mix(inner, inner * 0.72, ribs * 0.6)
        # the floor: trodden earth catching the light
        floor_ = smooth(base - 16 * PX, base - 10 * PX, yy)
        inner = mix(inner, mix(hexc("5a2a14"), hexc("c0703a"), g), floor_ * 0.8)
        # the hearth: three stones and the flames, at the back right of the floor
        fx_, fy_ = dcx + dw * 0.32, base - 13 * PX
        flame = np.zeros((h, w))
        for (ox, hh, ww) in ((0, 22, 6), (-6, 14, 4.5), (6, 16, 4.5), (2, 9, 3)):
            ddx = (xx - fx_ - ox * PX) / (ww * PX)
            ddy = (fy_ - yy) / (hh * PX)
            flame = np.maximum(flame, np.clip(1 - ddx ** 2 / np.maximum(1 - ddy, 0.05) ** 1.6 - ddy ** 2, 0, 1) * (ddy > -0.25))
        flame_col = ramp(np.clip(flame * 1.4, 0, 1), [(0, "c2340c"), (0.5, "ff8a1e"), (0.85, "ffd25a"), (1, "fff6c8")])
        inner = mix(inner, flame_col, smooth(0.02, 0.2, flame))
        stones = poly_mask(w, h, [], ellipses=[(fx_ - 9 * PX, fy_ + 1 * PX, 4.5 * PX, 3 * PX), (fx_ + 9 * PX, fy_ + 1 * PX, 4.5 * PX, 3 * PX),
                                              (fx_, fy_ + 3 * PX, 5 * PX, 2.6 * PX)])
        inner = mix(inner, hexc("2a140c"), stones * 0.9)
        # pots against the inner wall on the left, in silhouette with a warm rim
        pots = poly_mask(w, h, [], ellipses=[(dcx - dw * 0.55, base - 20 * PX, 9 * PX, 9 * PX), (dcx - dw * 0.15, base - 16 * PX, 6 * PX, 6 * PX),
                                             (dcx - dw * 0.55, base - 29 * PX, 4 * PX, 2 * PX)])
        pot_rim = np.clip(pots - np.roll(pots, -3, axis=1), 0, 1)
        inner = mix(inner, hexc("1e0c08"), pots * 0.95)
        inner = mix(inner, hexc("f09040"), pot_rim * 0.7)
        col = mix(col, fr_col, frame)
        col = mix(col, inner, op)
        cov = np.clip(np.maximum(cov, np.maximum(frame, op)), 0, 1)
        # glow of the fire on the frame's inner edge and the ground at the door
        spill = np.exp(-np.hypot((xx - dcx) / (dw * 1.5), (yy - base) / (14 * PX)) ** 2) * (1 - op)
        col = mix(col, col * np.array([1.35, 1.05, 0.7]), np.clip(spill, 0, 1) * 0.6 * cov[..., None][..., 0])
        right_post = dcx + dw + 9 * PX
        info.update({"door_x": dcx / PX, "door_w": 2 * dw / PX, "door_h": dh / PX, "front_x": (dcx + dw) / PX})
        # front layer: the dome right of the opening's right edge (with the post) + darkness inside
        keep = (xx >= dcx + dw - 1 * PX).astype(float)
        keep = blur(keep, 0.6)
        f_alpha = cov * keep * (1 - op)
        dark = op * smooth(dcx + dw * 0.55, dcx + dw, xx) * 0.6  # (round 2: only at the jamb's inner edge)
        f_col = np.where(dark[..., None] > f_alpha[..., None], hexc("140806") * np.ones_like(col), col)
        f_a = np.maximum(f_alpha, dark)
        front = dither_rgba(np.clip(f_col, 0, 255), f_a, rng)
    img = dither_rgba(np.clip(col, 0, 255), cov, rng)
    return img, front, info


def rondavel(seed: int = 83) -> Image.Image:
    """A rondavel: round mud walls under a conical thatched roof that overhangs them in a shaggy
    fringe, a band of painted triangles round the wall, a small door, a straw finial. Lit from the
    upper left; a different shape from the beehive huts (it stands at the back of the homestead)."""
    w, h = 220 * PX, 230 * PX
    rng = np.random.default_rng(seed)
    cx, base = w / 2, h - 2 * PX
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    wall_w, wall_h = 82 * PX, 78 * PX
    top = base - wall_h
    wall = (np.abs(xx - cx) <= wall_w) & (yy >= top) & (yy <= base)
    u = np.clip((xx - cx) / wall_w, -1, 1)
    wl = np.clip(0.62 - u * 0.42 - (1 - np.sqrt(np.clip(1 - u * u, 0, 1))) * 0.25, 0, 1)
    mud = ramp(np.clip(wl + (fbm(h, w, 8, 12, 3, rng, False) - 0.5) * 0.2, 0, 1),
               [(0, "5a2e22"), (0.4, "9a5a36"), (0.75, "c8844c"), (1, "e8b070")])
    # a painted band of triangles round the wall (bent with the curve), white and ochre
    band_y = top + wall_h * 0.42
    band = (np.abs(yy - band_y) < 7 * PX) & wall
    tri = ((np.arcsin(u) * 6 + (yy - band_y) / (7 * PX)) % 1.0) < 0.5
    mud = np.where((band & tri)[..., None], mud * 0.4 + np.array([235, 225, 205]) * 0.6 * wl[..., None] + 30, mud)
    mud = np.where((band & ~tri)[..., None], mud * 0.75, mud)
    door = (np.abs(xx - (cx - 24 * PX)) < 13 * PX) & (yy > base - 44 * PX) & wall
    mud = np.where(door[..., None], np.array([40.0, 20.0, 14.0]), mud)
    # the roof: a cone, its eaves overhanging the wall in a shaggy fringe
    eave_y = top + 10 * PX
    apex_y = 18 * PX
    tz = np.clip((yy - apex_y) / (eave_y - apex_y), 0, 1)
    # round 2: thatched in tiers like the beehive huts (one style for the homestead): each tier's
    # fringe juts out over the one below
    tiers = 3
    tk = tz * (tiers + 0.35)
    frac = tk - np.floor(tk)
    roof_half = 104 * PX * tz + 7 * PX * frac ** 1.6 * (tk >= 0.6)
    jag = blur(rng.standard_normal(w)[None, :], (0, 1.0))[0] * 4 * PX
    roof = (np.abs(xx - cx) <= roof_half) & (yy >= apex_y) & (yy <= eave_y + 6 * PX + jag[None, :])
    ru = np.clip((xx - cx) / np.maximum(roof_half, 1), -1, 1)
    rl = np.clip(0.78 - ru * 0.5 - 0.18 * tz, 0, 1)  # lit from the upper left and from above
    straw = Image.new("L", (w, h), 128)
    dst = ImageDraw.Draw(straw)
    for _ in range(2600):
        x0 = cx + rng.uniform(-1, 1) * 100 * PX
        y0 = rng.uniform(apex_y, eave_y)
        lean = (x0 - cx) / (100 * PX) * 6 * PX
        dst.line([(x0, y0), (x0 + lean, y0 + rng.uniform(8, 18) * PX)], fill=int(np.clip(rng.normal(128, 60), 0, 255)), width=2)
    st = np.asarray(straw, float) / 128 - 1
    r_col = ramp(np.clip(rl + st * 0.12, 0, 1), THATCH)
    for k in range(1, tiers + 1):  # under each tier's fringe its shadow, the fringe itself lit
        ring_y = apex_y + (eave_y - apex_y) * k / (tiers + 0.35) + jag[None, :] * 0.6
        dist = yy - ring_y
        r_col = mix(r_col, r_col * np.array([0.38, 0.3, 0.4]), np.exp(-np.clip(dist, 0, None) / (7 * PX)) * (dist > 0) * 0.9)
        r_col = mix(r_col, np.minimum(r_col * 1.35 + 6, 255), np.exp(-np.clip(-dist, 0, None) / (4 * PX)) * (dist <= 0) * 0.5)
    r_col = mix(r_col, hexc("ffd08a"), np.clip(1 - (ru + 0.7) / 0.3, 0, 1) * 0.45)  # sun rim
    fin = poly_mask(w, h, [[(cx - 4 * PX, apex_y + 6 * PX), (cx + 4 * PX, apex_y + 6 * PX), (cx + 1.5 * PX, 2 * PX), (cx - 1.5 * PX, 2 * PX)]])
    # the eaves' shadow on the wall
    mud = mud * (1 - 0.5 * smooth(eave_y + 18 * PX, eave_y + 4 * PX, yy))[..., None]
    mud = mud * (1 - 0.35 * smooth(base - 16 * PX, base, yy))[..., None]
    col = np.where(roof[..., None], r_col, mud)
    col = mix(col, ramp(np.clip(0.7 - (xx - cx) / (6 * PX), 0, 1), THATCH), fin)
    a = np.clip(np.maximum.reduce([wall.astype(float), roof.astype(float), fin]), 0, 1)
    a = blur(a, 0.6)
    return dither_rgba(np.clip(col, 0, 255), np.clip(a * 1.2, 0, 1), rng)


def granary() -> Image.Image:
    w, h = 90 * PX, 150 * PX
    rng = np.random.default_rng(71)
    cx = w / 2
    base = h - 1
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # stilts
    legs = poly_mask(w, h, [[(cx + dx * PX - 2.5 * PX, base), (cx + dx * PX + 2.5 * PX, base), (cx + dx * 0.8 * PX + 2 * PX, base - 52 * PX),
                             (cx + dx * 0.8 * PX - 2 * PX, base - 52 * PX)] for dx in (-24, -8, 10, 25)])
    leg_col = ramp(np.clip(0.55 + blur(rng.standard_normal((h, w)), (4, 0.6)) * 0.2, 0, 1), WOOD) * 0.8
    # basket: woven, round
    bcy = base - 76 * PX
    basket = poly_mask(w, h, [], ellipses=[(cx, bcy, 34 * PX, 28 * PX)])
    bl = np.clip(0.75 - (xx - cx) / (34 * PX) * 0.5 - (yy - bcy) / (28 * PX) * 0.35, 0, 1)
    weave = (np.sin(xx * 0.8 + np.sin(yy * 0.35) * 2) * np.sin(yy * 0.9) > 0.2) * 0.12
    b_col = ramp(np.clip(bl - weave, 0, 1), [(0, "4a3024"), (0.5, "8e6a40"), (1, "d8b070")])
    # roof: a thatched cone
    roof = poly_mask(w, h, [[(cx - 44 * PX, bcy - 12 * PX), (cx + 44 * PX, bcy - 12 * PX), (cx + 3 * PX, 4 * PX), (cx - 3 * PX, 4 * PX)]])
    rl = np.clip(0.8 - (xx - cx) / (44 * PX) * 0.6, 0, 1)
    straw = blur(rng.standard_normal((h, w)), (3, 0.6))
    r_col = ramp(np.clip(rl + straw * 0.06, 0, 1), THATCH)
    r_col *= (1 - 0.35 * smooth(bcy - 22 * PX, bcy - 12 * PX, yy))[..., None]
    col = leg_col * 1.0
    col = mix(col, b_col, basket)
    col = mix(col, r_col, roof)
    a = np.clip(np.maximum.reduce([legs, basket, roof]), 0, 1)
    return dither_rgba(np.clip(col, 0, 255), a, rng)


def fence() -> Image.Image:
    """Stakes of weathered wood, bound by two withies; 512 x 84 units, tiles in x."""
    w, h = 1024, 84 * PX
    rng = np.random.default_rng(73)
    stakes, lit, dark = [], [], []
    x = 0.0
    run = 0.0  # stakes come in runs of similar height, the line of tops wanders
    while x < w:
        sw = rng.uniform(4, 10) * PX
        run += rng.normal(0, 7.5) * PX  # round 2: the line of tops wanders more
        run = float(np.clip(run, -16 * PX, 28 * PX))
        top = float(np.clip(16 * PX + run + rng.uniform(-11, 11) * PX, 0, 52 * PX))
        if rng.random() < 0.08:  # now and then a tall forked post
            top = 0.0
        lean = rng.uniform(-2.5, 2.5) * PX
        tip = rng.uniform(-2, 2) * PX
        pts = [(x, h), (x + sw, h), (x + sw + lean, top + 4 * PX), (x + sw / 2 + tip + lean, top), (x + lean, top + 4 * PX)]
        stakes.append(pts)
        lit.append([(x, h), (x + sw * 0.35, h), (x + sw * 0.35 + lean, top + 3 * PX), (x + lean, top + 4 * PX)])
        if rng.random() < 0.3:  # an old stake, darker
            dark.append(pts)
        x += sw + (rng.uniform(0.3, 2.2) if rng.random() > 0.08 else rng.uniform(5, 12)) * PX  # a gap now and then
    m = poly_mask(w, h, stakes)
    lm = poly_mask(w, h, lit)
    dm = poly_mask(w, h, dark)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    grain = blur(rng.standard_normal((h, w)), (6, 0.5), wrap_x=True)
    tone = fbm(h, w, 2, 40, 3, rng, wrap_x=True)
    col = ramp(np.clip(0.46 + lm * 0.38 - dm * 0.18 + grain * 0.09 + (tone - 0.5) * 0.35, 0, 1),
               [(0, "3a2a26"), (0.4, "74583e"), (0.75, "b08c62"), (1, "e6c896")])
    for wy in (30 * PX, 62 * PX):  # withies
        band = np.exp(-((yy - wy - np.sin(xx * 0.05) * 2) / (2.2 * PX)) ** 2)
        col = mix(col, hexc("4e3a28") * (1 + 0.3 * (np.sin(xx * 0.6) > 0.5))[..., None], band * 0.9)
        m = np.maximum(m, band * 0.95)
    col *= (1 - 0.4 * smooth(h * 0.7, h, yy))[..., None]
    return dither_rgba(np.clip(col, 0, 255), np.clip(m, 0, 1), rng)


def sign() -> Image.Image:
    """A post and an arrow-shaped board pointing right, HOME carved in it, triangles round the edge."""
    w, h = 120 * PX, 130 * PX
    rng = np.random.default_rng(79)
    post = poly_mask(w, h, [[(52 * PX, h), (62 * PX, h), (61 * PX, 30 * PX), (53 * PX, 30 * PX)]])
    by0, by1 = 22 * PX, 62 * PX
    board_pts = [(6 * PX, by0 + 2 * PX), (92 * PX, by0), (114 * PX, (by0 + by1) / 2), (92 * PX, by1), (6 * PX, by1 - 2 * PX)]
    board = poly_mask(w, h, [board_pts])
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    grain = blur(rng.standard_normal((h, w)), (1.0, 14))
    col = ramp(np.clip(0.62 - (yy - by0) / (by1 - by0) * 0.25 + grain * 0.08, 0, 1), WOOD)
    pl = np.clip(0.75 - (xx - 52 * PX) / (10 * PX) * 0.6, 0, 1)
    post_col = ramp(np.clip(pl + blur(rng.standard_normal((h, w)), (6, 0.6)) * 0.1, 0, 1), WOOD)
    # carving: letters and a border of triangles, cut in (dark in the groove, a light lower-right lip)
    carve = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(carve)
    # round 2: the letters cut with a chisel (the rounded font read as a text layer pasted on):
    # wedge strokes, a little uneven, as a hand would cut them
    k = PX * SS
    top_y, bot_y = by0 + 9 * PX, by1 - 9 * PX

    def cut(pts):
        d.polygon([((x + rng.uniform(-0.45, 0.45) * PX) * SS, (y + rng.uniform(-0.45, 0.45) * PX) * SS) for x, y in pts], fill=255)

    def stroke(x0, y0, x1, y1, wd):
        dx, dy = x1 - x0, y1 - y0
        n = np.hypot(dx, dy)
        nx, ny = -dy / n * wd / 2, dx / n * wd / 2
        cut([(x0 + nx * 0.8, y0 + ny * 0.8), (x0 + (x1 - x0) * 0.5 + nx * 1.1, y0 + (y1 - y0) * 0.5 + ny * 1.1),
             (x1 + nx * 0.8, y1 + ny * 0.8), (x1 - nx * 0.8, y1 - ny * 0.8),
             (x0 + (x1 - x0) * 0.5 - nx * 1.1, y0 + (y1 - y0) * 0.5 - ny * 1.1), (x0 - nx * 0.8, y0 - ny * 0.8)])

    sw = 4.6 * PX  # stroke width
    lw = 15 * PX  # letter width
    x = 12 * PX
    hgt = bot_y - top_y
    # H
    stroke(x + sw / 2, top_y, x + sw / 2, bot_y, sw)
    stroke(x + lw - sw / 2, top_y, x + lw - sw / 2, bot_y, sw)
    stroke(x + sw / 2, top_y + hgt * 0.5, x + lw - sw / 2, top_y + hgt * 0.5, sw * 0.9)
    x += lw + 3.5 * PX
    # O: an eight-sided ring
    ocx, ocy, rx, ry = x + lw / 2 + 0.5 * PX, (top_y + bot_y) / 2, lw / 2 + 0.5 * PX, hgt / 2
    ring = [(ocx + rx * np.cos(a), ocy + ry * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 9)[:8] + np.pi / 8]
    cut(ring)
    inner = [(ocx + (rx - sw) * np.cos(a), ocy + (ry - sw * 0.95) * np.sin(a)) for a in np.linspace(0, 2 * np.pi, 9)[:8] + np.pi / 8]
    d.polygon([(px_ * SS, py_ * SS) for px_, py_ in inner], fill=0)
    x += lw + 4.5 * PX
    # M
    stroke(x + sw / 2, top_y, x + sw / 2, bot_y, sw)
    stroke(x + lw + 2 * PX - sw / 2, top_y, x + lw + 2 * PX - sw / 2, bot_y, sw)
    stroke(x + sw * 0.6, top_y + 1 * PX, x + (lw + 2 * PX) / 2, top_y + hgt * 0.62, sw * 0.85)
    stroke(x + lw + 2 * PX - sw * 0.6, top_y + 1 * PX, x + (lw + 2 * PX) / 2, top_y + hgt * 0.62, sw * 0.85)
    x += lw + 2 * PX + 3.5 * PX
    # E
    stroke(x + sw / 2, top_y, x + sw / 2, bot_y, sw)
    stroke(x + sw / 2, top_y + sw * 0.45, x + lw - 2 * PX, top_y + sw * 0.45, sw * 0.9)
    stroke(x + sw / 2, top_y + hgt * 0.5, x + lw - 3.5 * PX, top_y + hgt * 0.5, sw * 0.85)
    stroke(x + sw / 2, bot_y - sw * 0.45, x + lw - 2 * PX, bot_y - sw * 0.45, sw * 0.9)
    for i in range(14):  # small triangles along the top and bottom edges
        x0 = (10 + i * 6) * PX * SS
        d.polygon([(x0, (by0 + 3.5 * PX) * SS), (x0 + 4 * PX * SS, (by0 + 3.5 * PX) * SS), (x0 + 2 * PX * SS, (by0 + 6.5 * PX) * SS)], fill=255)
        d.polygon([(x0, (by1 - 3.5 * PX) * SS), (x0 + 4 * PX * SS, (by1 - 3.5 * PX) * SS), (x0 + 2 * PX * SS, (by1 - 6.5 * PX) * SS)], fill=255)
    cm = np.asarray(carve, float).reshape(h, SS, w, SS).mean(axis=(1, 3)) / 255
    groove = np.clip(cm - np.roll(np.roll(cm, -2, 0), -2, 1) * 0.0, 0, 1)
    lip = np.clip(np.roll(np.roll(cm, 2, 0), 2, 1) - cm, 0, 1)
    shadow_in = np.clip(cm - np.roll(np.roll(cm, 2, 0), 2, 1), 0, 1)
    col = mix(col, col * 0.62, board[..., None][..., 0] * 0.6)  # a darker, oiled board
    # two planks: a seam along the middle, lit on its lower lip
    seam_y = (by0 + by1) / 2
    col = mix(col, hexc("2a140c"), np.exp(-((yy - seam_y) / (0.8 * PX)) ** 2) * board * 0.8)
    col = mix(col, hexc("c89a6a"), np.exp(-((yy - seam_y - 1.6 * PX) / (0.6 * PX)) ** 2) * board * 0.4)
    # nails at both ends of each plank
    for nx in (12 * PX, 86 * PX):
        for ny in (by0 + 6 * PX, by1 - 6 * PX):
            nail = poly_mask(w, h, [], ellipses=[(nx, ny, 1.8 * PX, 1.8 * PX)])
            col = mix(col, hexc("2a2220"), nail)
            col = mix(col, hexc("d8d0c8"), poly_mask(w, h, [], ellipses=[(nx - 0.5 * PX, ny - 0.5 * PX, 0.7 * PX, 0.7 * PX)]))
    # the letters: cut into the wood and painted, the paint worn off here and there; in each cut
    # the wall on its upper left in shadow, the wall on its lower right catching the sun
    lit_in = np.clip(cm - np.roll(np.roll(cm, -2, 0), -2, 1), 0, 1)
    paint = smooth(0.32, 0.42, fbm(h, w, 10, 12, 3, rng, False))  # where the paint holds
    letters = mix(hexc("f4e2b8"), hexc("e8a64a"), np.clip((yy - by0) / (by1 - by0), 0, 1))
    letters = mix(col * 0.45, letters, paint[..., None])  # (worn: the bare cut wood shows)
    letters = mix(letters, hexc("2a1208"), np.clip(shadow_in * 1.6, 0, 1) * 0.85)
    letters = mix(letters, hexc("ffe6b0"), np.clip(lit_in * 1.6, 0, 1) * 0.6)
    col = mix(col, letters, groove)
    col = mix(post_col, col, board)
    edge = np.clip(board - np.roll(np.roll(board, 2, 0), 2, 1), 0, 1)
    col = mix(col, hexc("ffe2a8"), edge * 0.5)
    # a cord of beads tied where the board meets the post
    beads = []
    for i in range(7):
        beads.append((57 * PX + np.sin(i * 0.9) * 2 * PX, by1 + 12 * PX + i * 2.6 * PX, 1.4 * PX, 1.4 * PX))
    bm = poly_mask(w, h, [], ellipses=beads)
    bead_col = np.where((np.floor(yy / (2.6 * PX)) % 3 == 0)[..., None], hexc("d23a28"), np.where((np.floor(yy / (2.6 * PX)) % 3 == 1)[..., None], hexc("f2f0e6"), hexc("2e5aa8")))
    col = mix(col, bead_col, bm)
    # a rope binding the board to the post
    for k in range(5):
        ry = by1 - 3 * PX + k * 2.6 * PX  # (round 2: below the letters)
        band = np.exp(-((yy - ry - (xx - 57 * PX) * 0.25) / (0.9 * PX)) ** 2) * (np.abs(xx - 57 * PX) < 7 * PX)
        col = mix(col, hexc("c8a878") * (1.0 - 0.25 * (k % 2)), np.clip(band, 0, 1))
        post = np.maximum(post, np.clip(band, 0, 1))
    a = np.clip(np.maximum.reduce([post, board, bm]), 0, 1)
    col *= (1 - 0.35 * smooth(h - 12 * PX, h, yy))[..., None]
    return dither_rgba(np.clip(col, 0, 255), a, rng)


def pot() -> Image.Image:
    w, h = 44 * PX, 40 * PX
    rng = np.random.default_rng(83)
    cx, cy = w / 2, h - 18 * PX
    body = poly_mask(w, h, [], ellipses=[(cx, cy, 19 * PX, 17 * PX)])
    neck = poly_mask(w, h, [[(cx - 9 * PX, cy - 18 * PX), (cx + 9 * PX, cy - 18 * PX), (cx + 11 * PX, cy - 10 * PX), (cx - 11 * PX, cy - 10 * PX)]])
    m = np.clip(np.maximum(body, neck) * (np.arange(h)[:, None] < h - 1), 0, 1)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    nx = (xx - cx) / (19 * PX)
    ny = (yy - cy) / (17 * PX)
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    lam = np.clip(-0.55 * nx - 0.75 * ny + 0.62 * nz, 0, 1)
    col = ramp(lam, [(0, "1e1414"), (0.5, "4a302a"), (0.85, "8a5a44"), (1, "d8a07a")])
    chev = (np.abs(((xx * 0.5 + np.abs(((yy - cy + 4 * PX) % (6 * PX)) - 3 * PX) * 1.0) % (5 * PX)) - 2.5 * PX) < 0.8 * PX)
    band = (yy > cy - 9 * PX) & (yy < cy - 1 * PX)
    col = mix(col, col * 0.55, (chev & band) * 0.8)
    edge = np.clip(m - np.roll(np.roll(m, 2, 0), 2, 1), 0, 1)
    col = mix(col, hexc("ffd8a0"), edge * 0.5)
    return dither_rgba(np.clip(col, 0, 255), m, rng)


def yard() -> Image.Image:
    """Trodden earth before the doorway, where the grass has worn away: 220 x 30 units, the surface
    10 units from the top. Feathered ends, a few pebbles, short blades surviving at the edges."""
    w, h = 220 * PX, 30 * PX
    rng = np.random.default_rng(89)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    surface = 10 * PX
    u = (xx - w / 2) / (w / 2)
    edge_noise = blur(rng.standard_normal(w)[None, :], (0, 6))[0] * 3 * PX
    top = surface - 2 * PX + edge_noise[None, :] * 0.3
    m = (yy >= top) & (yy <= surface + 14 * PX + edge_noise[None, :])
    m = blur(m.astype(float), 1.5) * (1 - smooth(0.7, 1.0, np.abs(u)))
    tex = fbm(h, w, 4, 30, 4, rng, False)
    col = ramp(np.clip(0.55 + (tex - 0.5) * 0.5 - (yy - surface) / (14 * PX) * 0.3, 0, 1),
               [(0, "6e3a22"), (0.5, "a0603a"), (1, "d29a64")])
    col = mix(col, hexc("f0c890"), (1 - smooth(0, 3 * PX, yy - top)) * 0.35)  # the lit top edge
    peb = poly_mask(w, h, [], ellipses=[(rng.uniform(0.1, 0.9) * w, rng.uniform(surface + 2 * PX, surface + 10 * PX),
                                         rng.uniform(1.2, 2.5) * PX, rng.uniform(0.8, 1.6) * PX) for _ in range(26)])
    col = mix(col, hexc("c8a080"), peb * 0.8)
    alpha = np.clip(m, 0, 1)
    return dither_rgba(np.clip(col, 0, 255), alpha, rng)


def glow() -> Image.Image:
    s = 256
    yy, xx = np.mgrid[0:s, 0:s].astype(float)
    r = np.hypot(xx - s / 2, yy - s / 2) / (s / 2)
    a = np.exp(-(r / 0.45) ** 2) * (1 - smooth(0.8, 1.0, r))
    return dither_rgba(np.ones((s, s, 3)) * hexc("ff9a40"), a)


def main() -> None:
    info = {}
    img, front, i = hut(168, 300, True, 61)  # round 2: bigger, its doorway taller than him
    save(img, "home_hut.png")
    left = front.getbbox()[0] // 4 * 4  # round 3: only the part drawn (the wall right of the doorway)
    save(front.crop((left, 0, front.width, front.height)), "home_hut_front.png")
    i["front_crop_x"] = left / PX
    info["home_hut"] = i
    img = rondavel()
    save(img, "home_hut_small.png")
    info["home_hut_small"] = {"size": [img.width / PX, img.height / PX]}
    img, _, i = hut(128, 118, False, 71)  # a squat, wider hut: not a copy of the small one
    save(img, "home_hut_low.png")
    info["home_hut_low"] = i
    for name, f in (("home_granary", granary), ("home_fence", fence), ("home_sign", sign), ("home_pot", pot),
                    ("home_glow", glow), ("home_yard", yard)):
        im = f()
        save(im, name + ".png")
        info[name] = {"size": [im.width / PX, im.height / PX]}
    (WORLD / "home.json").write_text(json.dumps(info, indent=1))
    print("home written")


if __name__ == "__main__":
    main()
