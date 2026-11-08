#!/usr/bin/env python3
"""Round 23 (the judges, j19: "the far mesas are see-through: where two overlap the sky shows through, double-exposed"):
makes every landform of far_mesa_pieces.png opaque.

world_mesas.py cut the strip's five landforms with their sides fading out over FADE px (alpha), and its painted pieces
carry soft, speckled alpha at their edges. Overlapping in savanna_view.gd, those half-transparent sides let the sky
and the landform behind show through. Here each piece gets a solid silhouette: the pale far range the strip carried
behind each of its landforms is cut away (made opaque it stood in front of its neighbours as a pale card), and where a
side faded out the landform's flank runs down to the floor of its cell as a talus slope (a little rough), so it ends as
a shape, not a fade; everywhere else the alpha is its silhouette with a one-pixel antialiased edge. Distance is done in the shader by
mixing the colour toward the sky (haze.gdshader), never with alpha.

Run once on world_mesas.py's output (it reads the faded alpha). Rewrites assets/art/world/far_mesa_pieces.png in place.

    python3 tools/art/mesa_solid.py [--sheet out.png]   (--sheet: the pieces on a sky colour, to review)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

WORLD = Path(__file__).resolve().parents[2] / "assets/art/world"
# the strip's five pieces (the first row): the landform's own px range in each (measured on world_mesas.py's output);
# the rest of each was the pale far range behind it, faded out at the cell's sides
MAIN = {0: (37, 132), 1: (45, 205), 2: (144, 259), 3: (34, 132), 4: (45, 587)}


def solid_piece(rgba: np.ndarray, seed: int, main_range=None) -> np.ndarray:
    """The piece's alpha (0..1) made solid: its pale far band cut away, faded sides turned into sloping talus ends."""
    a = rgba[..., 3] / 255.0
    h, w = a.shape
    colmax = a.max(axis=0)
    norm = a / np.maximum(colmax, 1e-3)[None, :]
    core = ndimage.binary_fill_holes(norm > 0.5)
    ys = np.arange(h)[:, None]
    xs = np.arange(w)
    has = core.any(axis=0)
    top = np.where(has, core.argmax(axis=0), h)
    # the strip's pieces: only the landform (`main`, its px range in the piece) is kept; the pale far range the strip
    # carried behind it is cut away, its flank running down to the floor as a talus slope over it
    main = has.copy()
    if main_range is not None:
        main &= (xs >= main_range[0]) & (xs <= main_range[1])
    rng = np.random.default_rng(seed)
    lumps = ndimage.gaussian_filter1d(rng.normal(0.0, 1.0, w), 5.0) * 14.0 + rng.normal(0.0, 1.0, w) * 1.2
    fade = np.clip(colmax, 0.0, 1.0)
    new_top = top.astype(float).copy()
    if main.any():
        for x in range(w):
            if main[x]:
                continue
            # the nearest landform column, its top and how far from it this column is
            d = np.abs(xs - x) + np.where(main, 0, 10 ** 6)
            e = int(d.argmin())
            dist = abs(x - e)
            span = h - top[e]
            start = top[e] + span * 0.5  # (the talus leaves the flank half way down)
            reach = span * 0.85  # (it reaches the floor this far out)
            u = min(dist / max(reach, 1.0), 1.0)
            new_top[x] = max(start + (h - start) * u ** 0.8 + lumps[x] * u * (1.0 - u) * 2.0, top[x])
    # a faded side still fading inside the landform's columns: its top drops to the floor too
    drop = np.where(fade < 0.985, (1.0 - fade) ** 0.75, 0.0)
    new_top = np.maximum(new_top, top + (h - top) * drop)
    new_top = np.where(fade < 0.06, h + 1, new_top)
    mask = core & (ys >= new_top[None, :])
    # one body: specks the slope cut off are dropped
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        mask = mask & np.isin(lab, 1 + np.flatnonzero(sizes >= 60))
    # a one-pixel antialiased edge
    soft = ndimage.gaussian_filter(mask.astype(float), 0.8)
    return np.clip((soft - 0.5) * 1.6 + 0.5, 0.0, 1.0) * (soft > 0.02)


def main() -> None:
    path = WORLD / "far_mesa_pieces.png"
    info = json.loads((WORLD / "far_mesa_pieces.json").read_text())
    img = np.array(Image.open(path).convert("RGBA")).astype(float)
    h = int(info["height"])
    out = img.copy()
    for i, (x, y, w, _kind) in enumerate(info["pieces"]):
        cell = img[y:y + h, x:x + w]
        alpha = solid_piece(cell, 23 + i * 7, MAIN.get(i))
        out[y:y + h, x:x + w, 3] = alpha * 255.0
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)
    a = out[..., 3]
    inside = a > 0
    print(f"{path.name}: partial alpha now {(((a > 8) & (a < 247)).sum() / max(inside.sum(), 1)) * 100:.1f} % of its pixels (edges only)")
    if "--sheet" in sys.argv:
        sheet = Path(sys.argv[sys.argv.index("--sheet") + 1])
        bg = Image.new("RGBA", (out.shape[1], out.shape[0]), (150, 160, 205, 255))
        bg.alpha_composite(Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA"))
        bg.convert("RGB").save(sheet)


if __name__ == "__main__":
    main()
