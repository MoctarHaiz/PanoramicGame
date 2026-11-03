#!/usr/bin/env python3
"""Panoramic for the menu and the results, from the user's 3D renders (ROOT/Making/<Anim><View>/),
and the rock he stands on in the menu.

    python3 tools/art/ui_hero.py      # assets/art/ui/hero_stand.png, hero_down.png, head.png, menu_rock.png

- hero_stand.png: standing, full body, facing us (IdleFront, the first frame): the menu and a won run.
- hero_down.png: down on one knee, head bowed (DieFront, frame 26): a lost run.
- head.png: his face in a disc on a warm sky (the HUD's way home, where it runs to the house).
- menu_rock.png: a kopje jutting out into the sunset from the left edge of the menu, backlit: a dark
  plum mass, its top lit by the low sun on its right (a warm rim along every edge that faces it),
  rounded granite boulders, cracks with lit lips, mica and feldspar specks, shade in the clefts. Its flat top (ROCK_STAND, in its pixels) is where his feet go. (Painted
  with the cliff on the left and the sun on the left, then mirrored.)

Each hero frame is cut to its figure (a small margin), its colour bled under the transparent pixels
(no dark halo when the game scales it), and kept at the render's size (about 1000 px tall). If the
art track renders better frames (AAA/blender/), point SOURCES at them and run this again.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from paint import blur, dither_rgba, fbm, hexc, mix, poly_mask, ramp, smooth  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MAKING = ROOT.parents[0] / "Making"
if not MAKING.exists():  # a worktree: ROOT/_agents/wt/<track>/New
    MAKING = ROOT.parents[3] / "Making"
OUT = ROOT / "assets/art/ui"

SOURCES = {
    "hero_stand": "IdleFront/0001.png",
    "hero_down": "DieFront/0026.png",
}
MARGIN = 8  # px kept around the figure
HEAD_BOX = (438, 92, 598, 252)  # his face in the standing render (head.png)
ROCK_SIZE = (2000, 720)
ROCK_STAND = (660, 150)  # where his feet stand on the rock before the mirroring, in its pixels


def bleed(img: Image.Image) -> Image.Image:
    """Copies the colour of the nearest opaque pixel under every transparent one."""
    a = np.asarray(img).astype(np.float32)
    alpha = a[..., 3]
    solid = alpha > 8
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    rgb = a[..., :3][iy, ix]
    rgb[solid] = a[..., :3][solid]
    return Image.fromarray(np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8), "RGBA")


def cut(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    box = img.getchannel("A").point(lambda v: 255 if v > 4 else 0).getbbox()
    x0, y0, x1, y1 = box
    box = (max(x0 - MARGIN, 0), max(y0 - MARGIN, 0), min(x1 + MARGIN, img.width), min(y1 + MARGIN, img.height))
    return bleed(img.crop(box))


def head() -> Image.Image:
    """His face, cut from the standing render, in a disc on a warm evening sky (128 px)."""
    src = Image.open(MAKING / SOURCES["hero_stand"]).convert("RGBA")
    face = src.crop(HEAD_BOX).resize((128, 128), Image.LANCZOS)
    yy, xx = np.mgrid[0:128, 0:128].astype(float)
    sky = ramp(yy / 127.0, [(0.0, "ffd27a"), (0.6, "f59a4e"), (1.0, "d8603a")])
    disc = np.clip(63.5 - np.hypot(xx - 63.5, yy - 63.5), 0, 1)
    out = Image.fromarray(np.dstack([sky, np.full((128, 128), 255.0)]).astype(np.uint8), "RGBA")
    out.alpha_composite(face)
    a = np.asarray(out).astype(float)
    a[..., 3] = disc * 255
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _crack(h: int, w: int, rng: np.random.Generator, start: tuple, length: int, heading: float) -> np.ndarray:
    """A jagged crack: a random walk drawn as a thin line, wider at its start (0..1 coverage)."""
    pts = [np.array(start, float)]
    a = heading
    for i in range(length):
        a += rng.normal(0, 0.35)
        a = heading + np.clip(a - heading, -0.9, 0.9)
        pts.append(pts[-1] + np.array([np.cos(a), np.sin(a)]) * rng.uniform(6, 14))
    lines = [((p[0], p[1], q[0], q[1]), max(1.0, 4.5 * (1 - i / len(pts)))) for i, (p, q) in enumerate(zip(pts, pts[1:]))]
    return poly_mask(w, h, [], lines=lines)


def rock() -> Image.Image:
    w, h = ROCK_SIZE
    rng = np.random.default_rng(11)
    sx, sy = ROCK_STAND
    # the silhouette: a cliff face on the left, a flat top where he stands, rising to the right
    ridge = [(214, 222), (290, 180), (410, 160), (sx - 110, sy + 3), (sx + 130, sy + 1), (915, 154), (1085, 136),
             (1285, 118), (1515, 92), (1745, 82), (2000, 70)]
    face = [(2000, 720), (40, 720), (74, 620), (114, 510), (150, 400), (180, 304)]
    boulders = [(292, 270, 115, 95), (186, 470, 100, 128), (470, 230, 128, 74), (915, 214, 172, 80), (1130, 140, 150, 90),
                (1445, 100, 214, 104), (1810, 76, 250, 112), (800, 430, 243, 170), (1400, 415, 314, 214),
                (430, 470, 214, 170)]
    mask = poly_mask(w, h, [ridge + face], ellipses=boulders)
    n = fbm(h, w, 8, 26, 4, rng, wrap_x=False)
    edge = ndimage.distance_transform_edt(mask > 0.5) - ndimage.distance_transform_edt(mask <= 0.5)
    mask = smooth(-1.2, 1.2, edge + (n - 0.5) * 10.0)
    inside = mask > 0.5
    yy, xx = np.mgrid[0:h, 0:w].astype(float)

    # form: rounded at its edges, a smooth dome per boulder, relief at three scales, strata and cracks
    d = np.minimum(ndimage.distance_transform_edt(inside), 90.0) / 90.0
    height = (1 - (1 - d) ** 2) * 50.0
    for cx, cy, rx, ry in boulders:
        r2 = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        dome = np.exp(-r2 * 1.6) * 90.0 + d * 20.0
        height = np.logaddexp(height * 0.12, dome * 0.12) / 0.12  # a smooth max: soft rounded masses
    big = fbm(h, w, 6, 16, 4, rng, wrap_x=False)
    fine = fbm(h, w, 40, 110, 3, rng, wrap_x=False)
    height += big * 24.0 + fine * 3.5
    cracks = np.zeros((h, w))
    for i in range(7):
        top = rng.integers(260, w - 80)
        col = np.nonzero(inside[:, top])[0]
        if col.size == 0:
            continue
        cracks = np.maximum(cracks, _crack(h, w, rng, (top, col[0] + rng.uniform(4, 40)), int(rng.integers(8, 18)),
                                           np.pi / 2 + rng.normal(0, 0.5)))
    for i in range(2):  # a few running along the slabs
        cracks = np.maximum(cracks, _crack(h, w, rng, (rng.uniform(300, w), rng.uniform(220, 600)), int(rng.integers(8, 20)),
                                           rng.choice([0.0, np.pi]) + rng.normal(0, 0.3)))
    cracks *= inside
    height -= cracks * 9.0
    height = blur(height, 1.0)
    gy, gx = np.gradient(height)
    nrm = np.dstack([-gx, -gy, np.ones_like(height) * 1.2])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    sun = np.array([-0.82, -0.45, 0.35])  # the low sun, left and a little behind (mirrored: right)
    sun /= np.linalg.norm(sun)
    lit = np.clip(nrm @ sun, 0, 1)
    sky = np.clip(nrm @ np.array([0.1, -0.95, 0.3]), 0, 1)  # the dusk sky above: cool, soft

    # colour: warm granite against the light, plum in its own shade, the sun's orange on what faces it
    col = ramp(lit, [(0.0, "2c1520"), (0.25, "47252d"), (0.5, "7a4636"), (0.75, "c27450"), (1.0, "ffb27a")])
    col = mix(col, hexc("6c5a86"), sky * 0.22)
    grain = rng.random((h, w))
    col = mix(col, col * 0.7, (grain > 0.93) * 0.6)  # dark mica specks
    col = mix(col, col * 1.25 + 10, (grain < 0.03) * 0.5)  # light feldspar specks
    col += (fine[..., None] - 0.5) * 30.0
    first = np.where(inside.any(axis=0), inside.argmax(axis=0), h)
    below = yy - first[None, :]
    top = np.where(below >= 0, np.exp(-np.maximum(below, 0) / 34.0), 0.0)
    col = mix(col, hexc("e08a58"), top * 0.5 * (0.35 + 0.65 * lit))
    # cracks: dark, a thin lit lip on their lower side
    lip = np.clip(ndimage.shift(cracks, (2.0, 0.0), order=1) - cracks, 0, 1)
    col = mix(col, hexc("150810"), np.clip(cracks * 1.3, 0, 1) * 0.9)
    col = mix(col, hexc("f0a070"), lip * 0.5)
    # the rim where the rock's edge faces the sun
    shifted = ndimage.shift(mask, (4, 7), order=1, cval=0.0)
    rim = np.clip(mask - shifted, 0, 1)
    rim = blur(rim, 1.0) * mask * (0.55 + 0.45 * lit)
    col = mix(col, hexc("ffb46e"), np.clip(rim * 1.4, 0, 1))
    # ambient occlusion in the clefts between boulders, darker towards the foot
    ao = np.clip((blur(height, 18.0) - height) / 14.0, 0, 1)
    col = mix(col, hexc("12060c"), ao * 0.7)
    col = mix(col, hexc("1c0c16"), smooth(0.42, 1.0, yy / h) * 0.8)
    return dither_rgba(np.clip(col, 0, 255), mask, rng)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, rel in SOURCES.items():
        out = cut(MAKING / rel)
        out.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png {out.size}")
    head().save(OUT / "head.png", optimize=True)
    print("head.png (128, 128)")
    r = rock().transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    print(f"his feet at {(ROCK_SIZE[0] - ROCK_STAND[0], ROCK_STAND[1])} (menu_screen.gd ROCK_STAND)")
    r.save(OUT / "menu_rock.png", optimize=True)
    print(f"menu_rock.png {r.size}")


if __name__ == "__main__":
    main()
