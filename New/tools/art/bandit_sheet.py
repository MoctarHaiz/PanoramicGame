#!/usr/bin/env python3
"""The bandits' sheets (assets/art/bandit/<kind>.png + <kind>.json), two kinds that attack at random (BanditView):
  bandit         the user's bandit sheet (~/Downloads/bandit.png, 2026-11-07): spiky teal hair, torn red scarf,
                 yellow shirt with the round steel emblem, grey sash, black trousers, golden shin guards;
  bandit_strong  the user's strong bandit (~/Downloads/strong_bandit.png): the leader, muscular, bright-blue hair,
                 dark-red cape-scarf, mustard shirt with the black-and-white emblem and straps, blue wraps.
Both drawn with kie.ai from the user's pictures, with the hero's body proportions (the user, 2026-11-07: the
first ones were chibi, big-headed and stocky next to him; the strong one is as tall as the hero, 147 units in his
run like the hero's run frames, the bandit clearly smaller: about 0.8 of him): six poses on one Nano Banana 2 sheet each (the hero's
picture given for the proportions; cut by ROOT/_agents/kie/bandit2/cut_cells.py into bandit3/cells*/: 0 the run
pose, 1 waiting, 2 the fist drawn back, 3 the punch, 4 hit, 5 the leap, all facing left; the strong run pose's
missing shirt put back with a 1K edit), and the run from a Seedance 2.0 Mini clip started on the run pose
(video/vframes.py keys it into video/<clip>_keyed/; the loop is video/loop_find.py's: its start, its length).

The run's frames keep the clip's framing (its camera is locked): one pivot for the whole cycle, his body's middle
over the lowest boot, so he bobs as filmed. The poses stand on their own lowest pixel (the leap lifted), their
middle (the shirt's) over the same x, each brought to the run pose's head size (the hair's area). Everything at PX_PER_UNIT, the run pose STAND units tall. bandit.json:
frames [x, y, w, h, pivot x, pivot y], the marks (run, wait, swing, hit, leap), run_frames, swing_frames, run_fps
(the pace that keeps the planted boot on the ground at the rules' speed), head (the middle of his hair: the dazed
stars), vanish (the run frames the 2017 disappearance plays under its glaze: bandit.gdshader).

    python3 tools/art/bandit_sheet.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, premultiplied_resize  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "_agents/kie").is_dir())  # (the main checkout, from a worktree too)
KIE = ROOT / "_agents/kie"
OUT = NEW / "assets/art/bandit"
## kind -> (pose cells, keyed run clip, loop start, loop length, the clip's start picture, units tall)
KINDS = {
    "bandit": ("bandit3/cells", "video/bandit3_run_keyed", 47, 16, "bandit3/run_start.png", 112.0),
    "bandit_strong": ("bandit3/cells_strong", "video/strong3_run_keyed", 48, 14, "bandit3/strong_run_start.png", 147.0),
}
## his head and hair drawn this many times their size about his neck (the user, 2026-11-08: the bandit's head read
## bigger than the hero's on a smaller body; his big spiky hair made it so)
HEAD_SCALE = {"bandit": 0.85}
POSES = [1, 2, 3, 4, 5]  ## wait, swing (drawn back, thrown), hit, leap: the cells after the run pose
PX_PER_UNIT = 2.2  ## sheet px a unit (the hero's atlas: 2.3)
PAD = 3
LEAP_LIFT = 24.0  ## canvas px his boots are drawn above the ground in the leap
VANISH = [0, 1, 3, 5, 6, 7, 6, 7, 6, 7]  ## banditMort1-10: run frames under the glaze, then the twirl
BANDIT_SPEED = 10.0 * 960.0 / 1320.0 * 40.0  ## units a second against the ground (World.BANDIT_RUN)


def rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def middle_x(a: np.ndarray) -> float:
    """His body's middle: the shirt's (yellow) columns, else the opaque ones."""
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    shirt = (al > 0.5) & (r > 0.55) & (g > 0.4) & (b < 0.35) & (r - b > 0.3)
    xs = np.nonzero(shirt)[1] if shirt.sum() > 200 else np.nonzero(al > 0.5)[1]
    return float(np.median(xs))


def head(a: np.ndarray) -> tuple:
    """The middle of his hair (teal or blue, in the top 40 % of the figure)."""
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    ys = np.nonzero(al > 0.5)[0]
    top = ys.min() + (ys.max() - ys.min()) * 0.4
    hair = (al > 0.5) & (b > r + 0.15) & (g > r + 0.1)
    hair[int(top):] = False
    hy, hx = np.nonzero(hair)
    return float(hx.mean()), float(hy.mean())


def hair_area(a: np.ndarray) -> float:
    """Pixels of his hair (teal or blue, in the top 40 % of the figure): the measure of his head's size."""
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    ys = np.nonzero(al > 0.5)[0]
    hair = (al > 0.5) & (b > r + 0.15) & (g > r + 0.1)
    hair[int(ys.min() + (ys.max() - ys.min()) * 0.4):] = False
    return float(max(hair.sum(), 1))


def trimmed(arr: np.ndarray, pivot: np.ndarray):
    ys, xs = np.nonzero(arr[..., 3] > 0.004)
    y0, y1 = max(ys.min() - PAD, 0), ys.max() + PAD + 1
    x0, x1 = max(xs.min() - PAD, 0), xs.max() + PAD + 1
    return arr[y0:y1, x0:x1], pivot - np.array([x0, y0])


def shelf(sizes, width):
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


def planted_step(run: list, ground: float) -> float:
    """Canvas px the planted boot moves back (to the right: he runs left) a frame: over each stance (frames with a
    boot on the ground in a row), from its first contact to its last; the median of the stances."""
    xs_at = []
    for a in run:
        ys, xs = np.nonzero(a[..., 3] > 0.5)
        sel = ys >= ground - 12
        xs_at.append(float(xs[sel].mean()) if sel.sum() > 20 else None)
    stances, cur = [], []
    for x in xs_at + xs_at:  # (twice round: a stance across the loop's seam)
        if x is None:
            if len(cur) > 1:
                stances.append((cur[-1] - cur[0]) / (len(cur) - 1))
            cur = []
        else:
            cur.append(x)
    good = [v for v in stances if v > 0]
    return float(np.median(good)) if good else 0.0

def smaller_head(a: np.ndarray, s: float) -> np.ndarray:
    """His head (hair and face, above the scarf at his neck) drawn `s` times its size about the middle of his neck;
    the rest of him unchanged (the background is transparent: nothing to fill)."""
    if s >= 0.999:
        return a
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    ys = np.nonzero(al > 0.5)[0]
    top, tall = ys.min(), ys.max() - ys.min()
    hair = (al > 0.5) & (b > r + 0.15) & (g > r + 0.1)
    hair[int(top + tall * 0.45):] = False
    hy, hx = np.nonzero(hair)
    x0, x1 = int(hx.min()), int(hx.max())
    red = (al > 0.5) & (r > 0.45) & (g < 0.3) & (b < 0.3) & (r > 1.6 * g)
    ry = np.nonzero(red[:, x0:x1 + 1])[0]
    ry = ry[ry > hy.mean()]
    neck = int(ry.min()) if len(ry) else int(hy.max() + (hy.max() - hy.min()) * 0.4)
    mask = np.zeros(al.shape, bool)
    mask[: neck + 1, x0:x1 + 1] = True
    mask &= (al > 0.004) & ~red
    cx = float(hx[hy > hy.mean()].mean()) if (hy > hy.mean()).any() else (x0 + x1) / 2.0
    pm = a.copy(); pm[..., :3] *= pm[..., 3:4]
    head = np.where(mask[..., None], a, 0.0)  # (straight alpha: premultiplied_resize premultiplies)
    body = np.where(mask[..., None], 0.0, pm)
    h, w = al.shape
    hs = premultiplied_resize(Image.fromarray((np.clip(head, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA"), s)
    hs = hs.astype(np.float32) if hs.dtype != np.float32 else hs
    hs = hs.copy(); hs[..., :3] *= hs[..., 3:4]  # (premultiplied again)
    ox, oy = round(cx - cx * s), round(neck - neck * s)
    hh, ww = hs.shape[:2]
    canvas = np.zeros_like(pm)
    canvas[oy:oy + hh, ox:ox + ww] = hs[: h - oy, : w - ox]
    out = canvas + body * (1.0 - canvas[..., 3:4])
    al2 = out[..., 3:4]
    out[..., :3] = np.where(al2 > 1e-4, out[..., :3] / np.maximum(al2, 1e-4), 0.0)
    return np.clip(out, 0, 1)


def build(kind: str) -> None:
    cells, clip, start, length, start_png, stand = KINDS[kind]
    run_pose = rgba(KIE / cells / "0.png")
    ys = np.nonzero(run_pose[..., 3] > 0.5)[0]
    # the clip's canvas: its start picture holds the run pose at a known height
    sp = rgba(KIE / start_png)
    sp_fig = 1.0 - np.clip((sp[..., 1] - np.maximum(sp[..., 0], sp[..., 2]) - 0.1) / 0.3, 0, 1)
    sys_ = np.nonzero(sp_fig > 0.5)[0]
    canvas_h = float(sys_.max() - sys_.min())
    cell_to_canvas = canvas_h / float(ys.max() - ys.min())
    k = PX_PER_UNIT * stand / canvas_h  # canvas px -> sheet px
    files = sorted((KIE / clip).glob("*.png"))
    hs = HEAD_SCALE.get(kind, 1.0)
    run = [rgba(files[start + i]) for i in range(length)]
    if hs < 0.999:
        # the run's wind-swept hair is far bigger than in his other poses: each run frame's head is brought to the
        # poses' head size (their hair's median area, at their HEAD_SCALE)
        def pose_hair(c: int) -> float:
            im = Image.open(KIE / cells / f"{c}.png").convert("RGBA")
            im = im.resize((round(im.width * cell_to_canvas), round(im.height * cell_to_canvas)), Image.LANCZOS)
            return hair_area(np.asarray(im).astype(np.float32) / 255.0)
        target = float(np.median([pose_hair(c) for c in POSES])) * hs * hs
        run = [smaller_head(a, float(np.clip(np.sqrt(target / hair_area(a)), 0.65, 1.0))) for a in run]
    ground = float(max(np.nonzero(a[..., 3] > 0.5)[0].max() for a in run))
    mid = float(np.mean([middle_x(a) for a in run]))
    frames, heads = [], []

    def add(a: np.ndarray, pivot: np.ndarray) -> None:
        hx, hy = head(a)
        heads.append([round((hx - pivot[0]) * k, 1), round((hy - pivot[1]) * k, 1)])
        small = premultiplied_resize(Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA"), k)
        frames.append(trimmed(small, pivot * k))

    for a in run:
        add(a, np.array([mid, ground]))
    ref_hair = hair_area(run_pose)
    for c in POSES:
        img = Image.open(KIE / cells / f"{c}.png").convert("RGBA")
        # the generator drew some poses bigger than the run pose (the strong one's crouch): those are brought down to
        # the run pose's head size (only down: a pose's hair shows less than the run's, so the measure overshoots up)
        fit = float(np.clip(np.sqrt(ref_hair / hair_area(np.asarray(img).astype(np.float32) / 255.0)), 0.8, 1.0))
        img = img.resize((round(img.width * cell_to_canvas * fit), round(img.height * cell_to_canvas * fit)), Image.LANCZOS)
        a = smaller_head(np.asarray(img).astype(np.float32) / 255.0, hs)
        bottom = float(np.nonzero(a[..., 3] > 0.5)[0].max())
        add(a, np.array([middle_x(a), bottom + (LEAP_LIFT if c == 5 else 0.0)]))
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
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / f"{kind}.png", optimize=True)
    step = planted_step(run, ground) * stand / canvas_h  # units a frame
    fps = BANDIT_SPEED / step if step > 0 else 24.0
    n = length
    data = {"texture_scale": PX_PER_UNIT, "frames": rects, "run": 0, "wait": n, "swing": n + 1, "hit": n + 3,
            "leap": n + 4, "run_frames": n, "swing_frames": 2, "run_fps": round(fps, 2), "head": heads,
            "vanish": [v % n for v in VANISH]}
    (OUT / f"{kind}.json").write_text(json.dumps(data, indent=1))
    print(f"{kind}.png {width} x {height}: {len(frames)} frames ({n} run), {stand:.0f} units tall, "
          f"planted boot {step:.1f} units a frame -> run {fps:.1f} frames/s (the clip: 24)")


if __name__ == "__main__":
    for kind in sys.argv[1:] or KINDS:
        if KINDS[kind][3] > 0:
            build(kind)
        else:
            print(kind, ": no run loop yet (KINDS)")
