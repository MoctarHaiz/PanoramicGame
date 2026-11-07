#!/usr/bin/env python3
"""The bandit's sheet (assets/art/bandit/bandit.png + bandit.json): the 2017 bandit, the user's own drawing
(Old/app/src/main/assets/bandit/bandit1-10.png: teal crest of hair, red scarf, golden vest with its round
steel emblem, charcoal trousers, golden shin guards), redrawn clean at high resolution with kie.ai
(Nano Banana 2) from those frames: his 10-frame run exactly as he ran in 2017, plus five poses the new
rules need (waiting to pounce, the punch drawn back and thrown, hit, the leap) drawn in the same hand.
The prompts and the inputs are in ROOT/_agents/kie/bandit/ (p/, in/); the ledger in ROOT/_agents/kie/.

The source is one 5 x 3 sheet on chroma green. Each cell is keyed here (the ink kept: the generator's
dark outline is tinted green), scaled to PX_PER_UNIT and trimmed; the frames are packed into the
smallest sheet that holds them. bandit.json lists each frame's rectangle and its pivot (the ground under
his body), in this order:
  run      the 2017 run (10 frames), drawn as the 2017 frames were: his head steady, the feet lifting
  wait     waiting to pounce (1)
  swing    the punch: drawn back, thrown (2)
  hit      a ring's blow (1)
  leap     the leap (1: over a wall, or over Panoramic once he has struck)
and `vanish`, the run frames his 2017 disappearance played (banditMort1-10 are bandit 1, 2, 4, 6, 7, 8,
7, 8, 7, 8 glazed, then twirled away: BanditView draws the glaze and the twirl, bandit.gdshader).

    python3 tools/art/bandit_sheet.py [SHEET]   # default ROOT/_agents/kie/bandit/gen/bandit_poses_0.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, premultiplied_resize  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "_agents/kie").is_dir())  # (the main checkout, from a worktree too)
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/kie/bandit/gen/bandit_poses_0.png"
OUT = NEW / "assets/art/bandit"
COLS, ROWS = 5, 3
## cells in the order of bandit.json: the run (cells 0-9), wait (10), swing (11, 12), hit (14), leap (13)
CELLS = list(range(10)) + [10, 11, 12, 14, 13]
MARKS = {"run": 0, "wait": 10, "swing": 11, "hit": 13, "leap": 14}
VANISH = [0, 1, 3, 5, 6, 7, 6, 7, 6, 7]  ## banditMort1-10: the run frames under the glaze, then the twirl
STAND_UNITS = 120.0  ## on screen, game units from the tip of his crest to his lowest boot in the run
PX_PER_UNIT = 2.2  ## sheet px per unit (the hero's atlas: 2.3)
PAD = 3  ## transparent pixels round each frame
RUN_X = 234.0  ## cell x of his body's middle in the run (the 2017 frames' middle: the rules' box)
BOB = 0.35  ## of each run frame's lift off the ground drawn as a drop of the body (the rest: the feet lift)
LEAP_LIFT = 30.0  ## cell px his boots are drawn above the ground in the leap
## where the action poses stand (cell x of his body's middle): his vest over the run's
POSE_X = {10: 255.0, 11: 244.0, 12: 262.0, 13: 262.0, 14: 236.0}
BANDIT_SPEED = 10.0 * 960.0 / 1320.0 * 40.0  ## units a second against the ground (World.BANDIT_RUN)
STEP_UNITS = 19.0  ## units his planted boot moves back a frame in the 2017 run (a stride of ~95 in 5 frames)


def keyed(cell: np.ndarray) -> np.ndarray:
    """RGBA 0..1 from a cell on chroma green: alpha from how green a pixel is beyond its red and blue, the
    colour unmixed from the green, dark ink kept whole (the generator tints it green)."""
    rgb = cell.astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = g - np.maximum(r, b)
    a = 1.0 - np.clip((d - 40.0) / 190.0, 0.0, 1.0)
    solid = a > 0.5
    lab, n = ndi.label(solid)
    if n:
        sizes = ndi.sum(solid, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.where(sizes >= sizes.max() * 0.004)[0])
        a = np.where(ndi.binary_dilation(keep, iterations=2), a, 0.0)
    am = np.maximum(a, 1e-3)[..., None]
    bg = np.array([0.0, 255.0, 0.0])
    out = (rgb - (1.0 - a[..., None]) * bg) / am
    out[..., 1] = np.minimum(out[..., 1], np.maximum(out[..., 0], out[..., 2]) + 18.0)  # no green fringe
    return np.concatenate([np.clip(out / 255.0, 0, 1), a[..., None]], -1)


def trimmed(arr: np.ndarray, pivot: np.ndarray):
    ys, xs = np.nonzero(arr[..., 3] > 0.004)
    y0, y1 = max(ys.min() - PAD, 0), ys.max() + PAD + 1
    x0, x1 = max(xs.min() - PAD, 0), xs.max() + PAD + 1
    return arr[y0:y1, x0:x1], pivot - np.array([x0, y0])


def shelf(sizes, width):
    """Shelf packing (tallest first) `width` wide: ([(x, y)] in the sizes' order, height)."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    at = [None] * len(sizes)
    x = y = row = 0
    for i in order:
        w, h = sizes[i]
        if x + w > width:
            x, y, row = 0, y + row, 0
        at[i] = (x, y)
        x += w
        row = max(row, h)
    return at, y + row


def main() -> None:
    sheet = np.asarray(Image.open(SRC).convert("RGB"))
    H, W = sheet.shape[:2]
    cw, ch = W / COLS, H / ROWS
    cells = []
    for c in range(COLS * ROWS):
        x0, y0 = round((c % COLS) * cw), round((c // COLS) * ch)
        cells.append(keyed(sheet[y0:round(y0 + ch), x0:round(x0 + cw)]))
    bottoms = [np.nonzero(cells[c][..., 3] > 0.5)[0].max() for c in range(15)]
    tops = [np.nonzero(cells[c][..., 3] > 0.5)[0].min() for c in range(10)]
    ground = float(max(bottoms[:10]))
    units_per_cell_px = STAND_UNITS / (ground - min(tops))
    k = PX_PER_UNIT * units_per_cell_px
    frames, heads = [], []
    for c in CELLS:
        a = cells[c]
        if c < 10:
            pivot = np.array([RUN_X, ground - BOB * (ground - bottoms[c])])
        else:
            pivot = np.array([POSE_X[c], bottoms[c] + (LEAP_LIFT if c == 13 else 0.0)])
        # the middle of his hair: the dazed stars circle over it
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        hy, hx = np.nonzero((al > 0.5) & (b > r + 0.1) & (g > r + 0.1))
        heads.append([round(float((hx.mean() - pivot[0]) * k), 1), round(float((hy.mean() - pivot[1]) * k), 1)])
        small = premultiplied_resize(Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA"), k)
        frames.append(trimmed(small, pivot * k))
    sizes = [(f.shape[1], f.shape[0]) for f, _ in frames]
    best = None
    for width in range((max(s[0] for s in sizes) + 3) // 4 * 4, 2049, 4):  # (blocks of 4 for VRAM compression)
        at, height = shelf(sizes, width)
        height = (height + 3) // 4 * 4
        if best is None or width * height < best[0] * best[1]:
            best = (width, height, at)
    width, height, at = best
    page = np.zeros((height, width, 4), np.float32)
    rects = []
    for (arr, pivot), (x, y) in zip(frames, at):
        h, w = arr.shape[:2]
        page[y:y + h, x:x + w] = arr
        rects.append([x, y, w, h, round(float(pivot[0]), 2), round(float(pivot[1]), 2)])
    out = bleed(np.concatenate([np.clip(page[..., :3], 0, 1), page[..., 3:4]], -1))
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "bandit.png", optimize=True)
    fps = BANDIT_SPEED / STEP_UNITS
    reach = (RUN_X - min(np.nonzero(cells[c][..., 3] > 0.5)[1].min() for c in range(10))) * units_per_cell_px
    data = {"texture_scale": PX_PER_UNIT, "frames": rects, **MARKS, "run_frames": 10, "swing_frames": 2,
            "run_fps": round(fps, 2), "head": heads, "vanish": VANISH}
    (OUT / "bandit.json").write_text(json.dumps(data, indent=1))
    print(f"bandit.png {width} x {height}: {len(frames)} frames, {STAND_UNITS:.0f} units tall at {PX_PER_UNIT} px a unit "
          f"(source x {k:.3f}), run {fps:.1f} frames/s, his front {reach:.0f} units ahead of his middle")


if __name__ == "__main__":
    main()
