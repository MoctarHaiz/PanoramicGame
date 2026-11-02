#!/usr/bin/env python3
"""Panoramic for the menu and the results, from the user's 3D renders (ROOT/Making/<Anim><View>/),
and the rock he stands on in the menu.

    python3 tools/art/ui_hero.py      # assets/art/ui/hero_stand.png, hero_down.png, head.png, menu_rock.png

- hero_stand.png: standing, full body, facing us (IdleFront, the first frame): the menu and a won run.
- hero_down.png: down on one knee, head bowed (DieFront, frame 26): a lost run.
- head.png: his face in a disc on a warm sky (the HUD's way home, where it runs to the house).
- menu_rock.png: a kopje jutting out into the sunset from the left edge of the menu, backlit: a dark
  plum mass, its top lit by the low sun on its right (a warm rim along every edge that faces it),
  granite facets and cracks. Its flat top (ROCK_STAND, in its pixels) is where his feet go. (Painted
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
ROCK_SIZE = (1400, 520)
ROCK_STAND = (470, 104)  # where his feet stand on the rock before the mirroring, in its pixels


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


def rock() -> Image.Image:
    w, h = ROCK_SIZE
    rng = np.random.default_rng(7)
    sx, sy = ROCK_STAND
    # the silhouette: a cliff face on the left, a flat top where he stands, rising to the right
    ridge = [(150, 156), (205, 126), (290, 112), (sx - 80, sy + 2), (sx + 90, sy + 1), (640, 108), (760, 96),
             (900, 84), (1060, 66), (1220, 58), (1400, 48)]
    face = [(1400, 520), (30, 520), (52, 440), (80, 360), (104, 280), (126, 214)]
    boulders = [(205, 190, 80, 66), (130, 330, 70, 90), (330, 160, 90, 52), (640, 150, 120, 56), (790, 96, 105, 62),
                (1010, 70, 150, 72), (1265, 52, 175, 78), (560, 300, 170, 120), (980, 290, 220, 150),
                (300, 330, 150, 120)]
    mask = poly_mask(w, h, [ridge + face], ellipses=boulders)
    # a ragged edge: the silhouette eaten a little by noise along it
    n = fbm(h, w, 8, 26, 4, rng, wrap_x=False)
    edge = ndimage.distance_transform_edt(mask > 0.5) - ndimage.distance_transform_edt(mask <= 0.5)
    mask = smooth(-1.2, 1.2, edge + (n - 0.5) * 9.0)
    inside = mask > 0.5

    # form: rounded at the edges, a soft dome per boulder
    d = np.minimum(ndimage.distance_transform_edt(inside), 60.0) / 60.0
    height = (1 - (1 - d) ** 2) * 36.0
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    for cx, cy, rx, ry in boulders:
        r = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        height += np.clip(1 - r, 0, 1) ** 2 * 30.0
    height = blur(height, 2.0)
    gy, gx = np.gradient(height)
    # facets: the granite splits into flat planes (each Voronoi cell tilted its own way)
    seeds = np.ones((h, w), bool)
    pts = np.column_stack([rng.integers(0, h, 90), rng.integers(0, w, 90)])
    seeds[pts[:, 0], pts[:, 1]] = False
    _, (iy, ix) = ndimage.distance_transform_edt(seeds, return_indices=True)
    cell = iy * w + ix
    tilt = {}
    for k in np.unique(cell):
        tilt[k] = rng.normal(0, 0.35, 2)
    keys = np.array(list(tilt.keys()))
    tx = np.zeros(h * w)
    ty = np.zeros(h * w)
    lookup = np.searchsorted(keys, cell.ravel())
    vals = np.array(list(tilt.values()))
    tx = vals[lookup, 0].reshape(h, w)
    ty = vals[lookup, 1].reshape(h, w)
    border = (np.abs(np.diff(cell, axis=0, prepend=cell[:1])) + np.abs(np.diff(cell, axis=1, prepend=cell[:, :1]))) > 0
    border = blur(border.astype(float), 0.9)
    rough = fbm(h, w, 14, 38, 5, rng, wrap_x=False)
    rgy, rgx = np.gradient(blur(rough, 1.0) * 30.0)
    nx = -gx + tx * 0.9 - rgx * 0.6
    ny = -gy + ty * 0.9 - rgy * 0.6
    nrm = np.dstack([nx, ny, np.ones_like(height) * 1.4])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    sun = np.array([-0.82, -0.5, 0.3])  # the low sun, left and a little behind
    sun /= np.linalg.norm(sun)
    lit = np.clip(nrm @ sun, 0, 1)
    sky = np.clip(nrm @ np.array([0.1, -0.95, 0.3]), 0, 1)  # the dusk sky above: cool, soft

    # colour: backlit plum, warm and bright on the planes turned towards the sun
    col = ramp(lit, [(0.0, "26111d"), (0.3, "361827"), (0.55, "5e2730"), (0.8, "a9493a"), (1.0, "e48a52")])
    col = mix(col, hexc("6a4a70"), sky * 0.25)
    # the top surface catches the last light
    first = np.where(inside.any(axis=0), inside.argmax(axis=0), h)
    below = yy - first[None, :]
    top = np.where(below >= 0, np.exp(-np.maximum(below, 0) / 30.0), 0.0)
    col = mix(col, hexc("d9744a"), top * 0.45 * (0.4 + 0.6 * lit))
    # cracks along the facets' borders
    col = mix(col, hexc("1a0a12"), border * 0.55)
    # the rim: where the rock's edge faces the sun, a bright warm line
    shifted = ndimage.shift(mask, (5, 8), order=1, cval=0.0)  # the mask moved away from the sun
    rim = np.clip(mask - shifted, 0, 1)
    rim = blur(rim, 0.7) * mask
    col = mix(col, hexc("ffc98a"), np.clip(rim * 1.7, 0, 1))
    # grain, and darker towards the foot (it sinks into the dark grass of the backdrop)
    col += (rough[..., None] - 0.5) * 22.0
    col = mix(col, hexc("1c0c16"), smooth(0.4, 1.0, yy / h) * 0.8)
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
