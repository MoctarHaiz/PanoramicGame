#!/usr/bin/env python3
"""The masked raider's sheet (assets/art/bandit/bandit.png + bandit.json, club.png) from his 3D renders
(tools/art/blender/hero_render.py --character bandit, from the AAA hero file): the hero's mesh and rig in
his bold cel look, a dark hooded cowl, a red mask band with two tails and glowing eyes, a studded club.
Round 9 ("an indigo blob, unreadable as a threat"): the hero's ink weight on screen round his outline and,
inside it on the sun's side, a cold cyan band (the hero's is hot orange): he reads as a dark, sharp shape
against the warm savanna, and never as Panoramic.

The frames, each trimmed to what it shows, are packed into the sheet (round 9: they were in a grid of
200 x 260 cells, mostly empty; packed, the same sheet holds him about 1.4 times sharper, one texel to a
pixel on an iPhone 15 like the hero). bandit.json lists each frame's rectangle and where the ground under
his hips (the render's origin) falls in it, in this order:
  run      the run (16 frames, at the pace that keeps the planted boot on the ground)
  daze     the dazed run after a ring (16)
  ko       the blow and the flight back when knocked out (2)
  wait     waiting to pounce (2)
  swing    the swing of the club (8: drawn back 0-3, the blow smeared 4-5, the follow-through 6-7)
  leap     the leap (1: over a wall, or over Panoramic once he has struck)

    python3 tools/art/bandit_sheet.py [RENDER_DIR]   # default ROOT/_agents/AAA/blender/bandit_r9
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, inked, premultiplied_resize, sun_rim  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())
RENDER = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/AAA/blender/bandit_r9"
OUT = NEW / "assets/art/bandit"
SHEET = (3200, 780)  ## the sheet's size (kept: round 8's grid)
PAD = 3  ## transparent pixels round each frame
RENDER_STAND = 690.0  ## his standing height in a 1024 render
STAND_UNITS = 121.6  ## his standing height on screen, in game units (round 8: 160 sheet px x 1.52 / 2.0)
BANDIT_SPEED = 10.0 * 960.0 / 1320.0 * 40.0  ## units a second against the ground (World.BANDIT_RUN)
DRAW_SCALE = 1.52  ## BanditView.DRAW_SCALE
RIM = (np.array([0.35, 0.95, 1.0]), 0.8)  ## colour, strength: cold cyan (the hero's is hot orange)
ANIMS = [("run", "b_run", 16), ("daze", "b_daze", 16), ("ko", "b_ko", 2), ("wait", "b_wait", 2),
         ("swing", "b_swing", 8), ("leap", "b_leap", 1)]
_points = {}


def points(anim: str) -> dict:
    if anim not in _points:
        _points[anim] = json.loads((RENDER / anim / "points.json").read_text())
    return _points[anim]


def frame(anim: str, i: int, stand_px: float):
    """A render at the sheet's scale, its cold rim and ink (the hero's weights on screen), its origin and points."""
    pts = points(anim)
    k = stand_px / RENDER_STAND * 1024.0 / pts["size"]
    units_px = STAND_UNITS / stand_px  # game units per sheet px (the hero's atlas: 0.543)
    ink_px = 2.8 * 0.543 / units_px  # hero_atlas.INK_PX on screen
    rim_px = 3.4 * 0.543 / units_px  # hero_atlas.RIM_PX on screen
    img = Image.open(RENDER / anim / f"{i:03d}.png")
    arr = inked(sun_rim(premultiplied_resize(img, k), rim_px, RIM, dark=1.0), ink_px)  # (the dark cowl takes it all)
    origin = np.array(pts["origin"]) * k
    p = {key: np.array(v) * k for key, v in pts["frames"][i].items()}
    return arr, origin, p


def smeared(now: np.ndarray, ghost: np.ndarray) -> np.ndarray:
    """The blow over the pose before it, fainter (both rendered by the same camera: the same origin)."""
    a, ga = now[..., 3:4], ghost[..., 3:4] * 0.45
    out_a = a + ga * (1.0 - a)
    rgb = (now[..., :3] * a + ghost[..., :3] * ga * (1.0 - a)) / np.maximum(out_a, 1e-4)
    return np.concatenate([rgb, out_a], -1)


def trimmed(arr: np.ndarray, origin: np.ndarray):
    ys, xs = np.nonzero(arr[..., 3] > 0.004)
    y0, y1 = max(ys.min() - PAD, 0), ys.max() + PAD + 1
    x0, x1 = max(xs.min() - PAD, 0), xs.max() + PAD + 1
    return arr[y0:y1, x0:x1], origin - np.array([x0, y0])


def pack(sizes):
    """Shelf packing (tallest first) into SHEET, or None if they don't fit: [(x, y)] in the sizes' order."""
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    at = [None] * len(sizes)
    x = y = shelf = 0
    for i in order:
        w, h = sizes[i]
        if x + w > SHEET[0]:
            x, y, shelf = 0, y + shelf, 0
        if y + h > SHEET[1]:
            return None
        at[i] = (x, y)
        x += w
        shelf = max(shelf, h)
    return at


def build(stand_px: float):
    frames, marks = [], {}
    for name, anim, n in ANIMS:
        marks[name] = len(frames)
        made = [frame(anim, i, stand_px) for i in range(n)]
        for i, (arr, origin, p) in enumerate(made):
            if name == "swing" and i in (4, 5):  # the blow, smeared
                arr = smeared(arr, made[i - 1][0])
            frames.append((name, i, *trimmed(arr, origin), p, origin))
    return frames, marks


def main() -> None:
    # the largest scale whose frames fit the sheet (sized from the renders' bounds, then built once)
    bounds = []
    for _, anim, n in ANIMS:
        for i in range(n):
            ys, xs = np.nonzero(np.asarray(Image.open(RENDER / anim / f"{i:03d}.png"))[..., 3] > 2)
            bounds.append((xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, points(anim)["size"]))
    stand_px = 260.0
    while stand_px > 100.0:
        k = stand_px / RENDER_STAND * 1024.0
        ink = 2.8 * 0.543 * stand_px / STAND_UNITS + 1.0
        sizes = [(int(w * k / sz + 2 * (ink + PAD)) + 2, int(h * k / sz + 2 * (ink + PAD)) + 2) for w, h, sz in bounds]
        if pack(sizes) is not None:
            break
        stand_px -= 2.0
    while True:
        frames, marks = build(stand_px)
        at = pack([(f[2].shape[1], f[2].shape[0]) for f in frames])
        if at is not None:
            break
        stand_px -= 2.0
    sheet = np.zeros((SHEET[1], SHEET[0], 4), np.float32)
    rects = []
    for (name, i, arr, origin, p, _), (x, y) in zip(frames, at):
        h, w = arr.shape[:2]
        sheet[y:y + h, x:x + w] = arr
        rects.append([x, y, w, h, round(float(origin[0]), 2), round(float(origin[1]), 2)])
    run = [f for f in frames if f[0] == "run"]
    heads = [[round(float(v), 1) for v in f[4]["head"] - f[5]] for f in run]
    ko = [[round(float(v), 1) for v in f[4]["hips"] - f[5]] for f in frames if f[0] == "ko"]
    # the pace: the lower toe's travel while it is on the ground (faces left: it moves right)
    steps = [(f[4], f[5]) for f in run]
    ground = max(max(p["toe_r"][1], p["toe_l"][1]) - o[1] for p, o in steps)
    moves = []
    for i in range(16):
        (a, oa), (b, ob) = steps[i], steps[(i + 1) % 16]
        for toe in ("toe_r", "toe_l"):
            if a[toe][1] - oa[1] > ground - 2 and b[toe][1] - ob[1] > ground - 2:
                moves.append(abs((b[toe][0] - ob[0]) - (a[toe][0] - oa[0])))
    texture_scale = stand_px * DRAW_SCALE / STAND_UNITS
    fps = BANDIT_SPEED / (sum(moves) / len(moves) * DRAW_SCALE / texture_scale)
    out = bleed(np.concatenate([np.clip(sheet[..., :3], 0, 1), sheet[..., 3:4]], -1))
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "bandit.png", optimize=True)
    data = {"texture_scale": round(texture_scale, 4), "frames": rects, **marks, "run_frames": 16, "swing_frames": 8,
            "run_fps": round(fps, 2), "head": heads, "ko_centres": ko}
    (OUT / "bandit.json").write_text(json.dumps(data, indent=1))
    # the club alone, trimmed, for its flight when he is knocked out
    arr, _, _ = frame("b_club", 0, stand_px)
    ys, xs = np.nonzero(arr[..., 3] > 0.01)
    club = bleed(arr[max(ys.min() - 3, 0):ys.max() + 4, max(xs.min() - 3, 0):xs.max() + 4])
    Image.fromarray((club * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "club.png", optimize=True)
    print(f"bandit.png {SHEET[0]} x {SHEET[1]}: {len(frames)} frames, he stands {stand_px:.0f} px "
          f"(texture scale {texture_scale:.3f}), run {fps:.1f} frames/s, club {club.shape[1]} x {club.shape[0]}")


if __name__ == "__main__":
    main()
