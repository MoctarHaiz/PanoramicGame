#!/usr/bin/env python3
"""The Red Bob sheet (assets/art/bob/bob.png + bob.json): the 2017 Red Bob's face on a ruby, bold enough to
read at phone size: big dark eyes with a white glint, a thick smile, rosy cheeks. Four faces side by side:
smile, blink, joy, wink. The face is squeezed towards the ball's edge as it curves away.

Round 9 ("still tomatoes at phone size"): the ball is painted as a cut ruby seen from above, in the hero's
cel language, not a glossy fruit: a ruby crimson (not tomato orange-red); an octagonal table in the middle
(the face sits on it, glowing where the light comes back out of the stone); round it a brilliant's crown
of star, kite and girdle facets in crisp flat tones (the sun on the near facets, the stone's fire on the
far ones, neighbours never alike), the facet that mirrors the sun a sharp white triangle, a pin-point
glint (hard edges: a gem; soft: plastic). The round outline stays: it is still the 2017 Red Bob. BobView
adds the rose glow round it and the twinkles.

    python3 tools/art/bob_sheet.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, inked, premultiplied_resize  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
OUT = NEW / "assets/art/bob"
FRAME = 128
S = 512  # drawn at the render's size, then reduced
INK = (40, 6, 8, 255)


def face(kind: str) -> Image.Image:
    """The face layer (RGBA, S x S), centred a little low on the ball."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S * 0.5, S * 0.53
    ex, ey, ew, eh = S * 0.115, S * 0.47, S * 0.062, S * 0.095  # eye centre offset and half size

    def eye(x, open_):
        if open_:
            d.ellipse([x - ew, ey - eh, x + ew, ey + eh], fill=INK)
            d.ellipse([x - ew * 0.15, ey - eh * 0.75, x + ew * 0.55, ey - eh * 0.1], fill=(255, 255, 255, 255))
        else:  # closed, happy: an arc
            d.arc([x - ew * 1.2, ey - eh * 0.6, x + ew * 1.2, ey + eh * 0.9], 200, 340, fill=INK, width=int(S * 0.028))

    eye(cx - ex, kind in ("smile", "wink"))
    eye(cx + ex, kind == "smile")
    if kind == "joy":  # an open laugh
        d.chord([cx - S * 0.1, cy, cx + S * 0.1, cy + S * 0.14], 0, 180, fill=INK)
        d.ellipse([cx - S * 0.05, cy + S * 0.07, cx + S * 0.05, cy + S * 0.13], fill=(230, 80, 90, 255))
    else:
        d.arc([cx - S * 0.09, cy - S * 0.02, cx + S * 0.09, cy + S * 0.1], 20, 160, fill=INK, width=int(S * 0.03))
    blush = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    for side in (-1, 1):
        x = cx + side * S * 0.2
        bd.ellipse([x - S * 0.06, cy - S * 0.01, x + S * 0.06, cy + S * 0.05], fill=(255, 140, 150, 120))
    blush = blush.filter(ImageFilter.GaussianBlur(S * 0.012))
    return Image.alpha_composite(blush, img)


def _smooth(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


RADIUS = 0.444  ## of the picture (round 8's ball: BobView sizes the ball from bob.json's radius)
LIGHT = np.array([-0.5, -0.62, 0.6])  ## towards the sun (x right, y down, z to us): upper left, as in the world
DEEP, BODY, LIT = (0.4, 0.0, 0.08), (0.76, 0.02, 0.14), (1.0, 0.2, 0.28)  ## the ruby's bands (sRGB)
TABLE = 0.56  ## the table's size (of the stone's radius): the face sits on it
STAR, GIRDLE = 0.62, 0.74  ## how far out (0 table, 1 rim) the star facets' points and the girdle facets reach
CORE = (1.0, 0.46, 0.46)  ## the hottest facets (the stone's fire)


def gem() -> tuple[np.ndarray, np.ndarray]:
    """The ruby (RGBA, S x S, colours 0..1) and its lighting value (for the face's shade): seen from above like
    a cut stone, an octagonal table in the middle (the face sits on it) ringed by crown facets that catch the
    sun on the near side and the light coming back out of the stone on the far side."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c, r = S / 2.0, S * RADIUS
    u, v = (xx + 0.5 - c) / r, (yy + 0.5 - c) / r
    rr = np.sqrt(u * u + v * v)
    alpha = np.clip((1.0 - rr) * r + 0.5, 0.0, 1.0)  # anti-aliased disc (the Red Bob's round outline)
    aa = 1.5 / r  # a pixel and a half of softening on every edge (crisp, never jagged)
    edge = lambda d: np.clip(0.5 - d / aa, 0.0, 1.0)  # noqa: E731  inside a shape whose signed distance is d
    light = LIGHT / np.linalg.norm(LIGHT)
    back = np.array([-light[0], -light[1], light[2]])  # the light coming back out of the far side
    th = np.arctan2(v, u)
    sector = np.pi / 4.0
    local = np.mod(th + sector / 2.0, sector) - sector / 2.0  # angle from the middle of an octagon side
    table_r = TABLE * np.cos(sector / 2.0) / np.cos(local)  # the octagon's edge along this ray
    in_table = edge(rr - table_r)
    # the crown, as on a brilliant: a star facet on each side of the table (a triangle, its point outwards), a
    # kite between two stars (from a table corner out to the rim), and small girdle facets round the rim
    side_mid = th - local  # the middle of this side of the octagon
    sr = np.clip((rr - table_r) / np.maximum(1.0 - table_r, 1e-3), 0.0, 1.0)  # 0 at the table, 1 at the rim
    star = edge(sr - STAR * (1.0 - np.abs(local) / (sector / 2.0)))
    girdle = edge(GIRDLE - sr) * (1.0 - star)
    corner = side_mid + np.sign(local) * sector / 2.0  # the kite's corner of the table
    half = np.floor((th + np.pi) / (sector / 2.0))
    gmid = (half + 0.5) * (sector / 2.0) - np.pi
    az = np.where(star > 0.5, side_mid, np.where(girdle > 0.5, gmid, corner))
    tilt = np.where(star > 0.5, np.radians(26.0), np.where(girdle > 0.5, np.radians(66.0), np.radians(44.0)))
    fn = np.stack([np.sin(tilt) * np.cos(az), np.sin(tilt) * np.sin(az), np.cos(tilt)], -1)
    alt = np.where(np.mod(half, 2) == 0, 1.0, -1.0)  # neighbours never alike: every cut shows
    lit_k = np.maximum(fn @ light, 0.7 * (fn @ back))  # the sun on the near facets, the stone's fire on the far ones
    tone = 0.75 * lit_k + 0.25 * (u * light[0] + v * light[1] + 0.6) + 0.09 * alt
    deep, body, lit, hot = (np.array(x, np.float32) for x in (DEEP, BODY, LIT, CORE))
    crown = deep + (body - deep) * _smooth(0.42, 0.44, tone)[..., None]
    crown = crown + (lit - crown) * _smooth(0.66, 0.68, tone)[..., None]
    crown = crown + (hot - crown) * (_smooth(0.84, 0.86, tone) * 0.7)[..., None]
    # the table: the body, glowing where the light comes back out (lower right), a soft hot core
    table = body + (lit - body) * _smooth(0.75, 0.1, np.hypot(u - 0.16, v - 0.2))[..., None] * 0.85
    rgb = crown + (table - crown) * in_table[..., None]
    rgb = rgb * (1.0 - 0.35 * _smooth(0.9, 0.99, rr))[..., None]  # the girdle: a little darker at the rim
    # the flash: the crown facet that mirrors the sun to us turns white (a crisp facet, a gem's highlight)
    refl = 2.0 * fn[..., 2:3] * fn - np.array([0.0, 0.0, 1.0])
    flash = _smooth(0.94, 0.96, refl @ light) * (1.0 - in_table) * edge(rr - 0.93)
    dot = edge(np.hypot(u + 0.2, v + 0.3) - 0.07)  # a pin-point on the table
    glint = edge(np.hypot(u - 0.52, v - 0.47) - 0.045) * 0.9  # and a small one on the far facets
    spec = np.maximum(np.maximum(flash, dot), glint)
    rgb = rgb + (1.0 - rgb) * spec[..., None]
    out = np.concatenate([np.clip(rgb, 0.0, 1.0), alpha[..., None]], -1).astype(np.float32)
    nz = np.sqrt(np.clip(1.0 - rr * rr, 0.0, 1.0))
    shade = np.clip(0.35 + 0.65 * (u * light[0] + v * light[1] + nz * light[2]), 0.0, 1.0) * (alpha > 0)
    return out, shade


def main() -> None:
    sheet = np.zeros((FRAME, FRAME * 4, 4), np.float32)
    kinds = ["smile", "blink", "joy", "wink"]
    ball, shade = gem()
    radius = S * RADIUS * FRAME / S
    for i, kind in enumerate(kinds):
        f = np.asarray(face(kind)).astype(np.float32) / 255.0
        fa = f[..., 3:4] * ball[..., 3:4]
        # the face takes the ball's light: darker where the ball is in shade
        ink = f[..., :3] * np.clip(shade[..., None] * 1.6, 0.55, 1.0)
        a = ball.copy()
        a[..., :3] = ball[..., :3] * (1.0 - fa) + ink * fa
        small = inked(premultiplied_resize(Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA"), FRAME / S), 0.8)
        sheet[:, i * FRAME:(i + 1) * FRAME] = small[:FRAME, :FRAME]
    out = bleed(sheet)
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "bob.png", optimize=True)
    (OUT / "bob.json").write_text(json.dumps({"frame": FRAME, "frames": kinds, "radius": round(radius, 1)}, indent=1))
    print("bob.png", sheet.shape[1], sheet.shape[0], "radius", round(radius, 1))


if __name__ == "__main__":
    main()
