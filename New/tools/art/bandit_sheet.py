#!/usr/bin/env python3
"""The masked raider's sheet (assets/art/bandit/bandit.png + bandit.json, club.png) from his 3D renders
(tools/art/blender/hero_render.py --character bandit): the hero's mesh and rig in violet wraps, a
mask with amber eyes, a teal crest and a club, in the same light as Panoramic.

Grid of COLS x 3 cells, each frame placed so the ground under his hips (the render's origin) is
the anchor:
  row 0  the run (16 frames, at the pace that keeps the planted boot on the ground)
  row 1  the dazed run after a ring (16)
  row 2  the blow and the tumble when knocked out (0, 1), waiting to pounce (2, 3), the swing of
         the club (4-11: drawn back 4-7, the blow smeared 8-9, the follow-through 10-11)

    python3 tools/art/bandit_sheet.py [RENDER_DIR]   # default ROOT/_agents/AAA/blender/bandit
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, inked, premultiplied_resize  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())
RENDER = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/AAA/blender/bandit"
OUT = NEW / "assets/art/bandit"
COLS = 16
CELL = (200, 260)
ANCHOR = (100, 246)  ## the ground under his hips, in each cell
STAND_PX = 160.0  ## his standing height in the sheet (round 8: smaller in the sheet, so his raised club fits the cell; drawn bigger)
SCALE = STAND_PX / 690.0  ## render px -> sheet px (he stands ~690 px in a 1024 render)
TEXTURE_SCALE = 2.0
BANDIT_SPEED = 10.0 * 960.0 / 1320.0 * 40.0  ## units a second against the ground (World.BANDIT_RUN)
DRAW_SCALE = 1.52  ## BanditView.DRAW_SCALE


def frame(anim: str, i: int):
    folder = RENDER / anim
    points = json.loads((folder / "points.json").read_text())
    img = Image.open(folder / f"{i:03d}.png")
    k = SCALE * 1024.0 / points["size"]
    arr = inked(premultiplied_resize(img, k), 1.6)  # a strong outline: he reads on the grass
    origin = np.array(points["origin"]) * k
    pts = {key: np.array(v) * k for key, v in points["frames"][i].items()}
    return arr, origin, pts


def place(sheet, cell, arr, origin):
    """Puts a frame in its cell with its origin on the anchor (what overflows the cell is cut)."""
    cx, cy = (cell % COLS) * CELL[0], (cell // COLS) * CELL[1]
    ox, oy = int(round(ANCHOR[0] - origin[0])), int(round(ANCHOR[1] - origin[1]))
    h, w = arr.shape[:2]
    x0, y0 = max(ox, 0), max(oy, 0)
    x1, y1 = min(ox + w, CELL[0]), min(oy + h, CELL[1])
    if x1 > x0 and y1 > y0:
        sheet[cy + y0:cy + y1, cx + x0:cx + x1] = arr[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    return np.array([ox, oy])


def main() -> None:
    sheet = np.zeros((CELL[1] * 3, CELL[0] * COLS, 4), np.float32)
    heads = []
    steps = []
    ground = None
    for i in range(16):
        arr, origin, pts = frame("b_run", i)
        off = place(sheet, i, arr, origin)
        heads.append([round(float(v), 1) for v in pts["head"] + off])
        lowest = max(pts["toe_r"][1], pts["toe_l"][1])
        steps.append((pts, origin))
        arr, origin, _ = frame("b_daze", i)
        place(sheet, COLS + i, arr, origin)
    # the pace: the lower toe's travel while it is on the ground (faces left: it moves right)
    ground = max(max(p["toe_r"][1], p["toe_l"][1]) - o[1] for p, o in steps)
    moves = []
    for i in range(16):
        (a, oa), (b, ob) = steps[i], steps[(i + 1) % 16]
        for toe in ("toe_r", "toe_l"):
            if a[toe][1] - oa[1] > ground - 2 and b[toe][1] - ob[1] > ground - 2:
                moves.append(abs((b[toe][0] - ob[0]) - (a[toe][0] - oa[0])))
    px = sum(moves) / len(moves)
    units = px * DRAW_SCALE / TEXTURE_SCALE
    fps = BANDIT_SPEED / units
    ko = []
    for k in range(2):
        arr, origin, pts = frame("b_ko", k)
        off = place(sheet, 2 * COLS + k, arr, origin)
        ko.append([round(float(v), 1) for v in pts["hips"] + off])
    for k in range(2):
        arr, origin, _ = frame("b_wait", k)
        place(sheet, 2 * COLS + 2 + k, arr, origin)
    swing = [frame("b_swing", i) for i in range(8)]
    for i, (arr, origin, _) in enumerate(swing):
        if i in (4, 5):  # the blow, smeared: the pose before it shows through, fainter
            prev, porigin, _ = swing[i - 1]
            canvas = np.zeros((CELL[1] * 3, CELL[0] * COLS, 4), np.float32)
            place(canvas, 0, prev, porigin)
            place(canvas, 1, arr, origin)
            ghost = canvas[:CELL[1], :CELL[0]]
            now = canvas[:CELL[1], CELL[0]:CELL[0] * 2]
            a, ga = now[..., 3:4], ghost[..., 3:4] * 0.45
            out_a = a + ga * (1.0 - a)  # the blow over its ghost
            rgb = (now[..., :3] * a + ghost[..., :3] * ga * (1.0 - a)) / np.maximum(out_a, 1e-4)
            mixed = np.concatenate([rgb, out_a], -1)
            cell = 2 * COLS + 4 + i
            cx, cy = (cell % COLS) * CELL[0], (cell // COLS) * CELL[1]
            sheet[cy:cy + CELL[1], cx:cx + CELL[0]] = mixed
        else:
            place(sheet, 2 * COLS + 4 + i, arr, origin)
    al = sheet[..., 3:4]
    out = bleed(np.concatenate([np.clip(sheet[..., :3], 0, 1), al], -1))
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "bandit.png", optimize=True)
    data = {
        "cell": list(CELL), "columns": COLS, "rows": 3, "anchor": list(ANCHOR), "texture_scale": TEXTURE_SCALE,
        "run_frames": 16, "run_fps": round(fps, 2), "hurt_row": 1, "ko_row": 2, "swing_from": 4, "swing_frames": 8,
        "head": heads, "ko_centres": ko,
    }
    (OUT / "bandit.json").write_text(json.dumps(data, indent=1))
    # the club alone, trimmed, for its flight when he is knocked out
    arr, _, _ = frame("b_club", 0)
    ys, xs = np.nonzero(arr[..., 3] > 0.01)
    club = bleed(arr[max(ys.min() - 3, 0):ys.max() + 4, max(xs.min() - 3, 0):xs.max() + 4])
    Image.fromarray((club * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "club.png", optimize=True)
    print(f"bandit.png {sheet.shape[1]} x {sheet.shape[0]}, run {fps:.1f} frames/s, club {club.shape[1]} x {club.shape[0]}")


if __name__ == "__main__":
    main()
