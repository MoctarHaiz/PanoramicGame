#!/usr/bin/env python3
"""(2026-11-12, the user: "the enemies' running animation: the cycle is not good enough") Both bandits' sheets
(assets/art/bandit/<kind>.png + .json, the layout BanditView reads) with a new run: one whole stride in twelve clean
drawings. Six are the keys (a flight, a passing and a push-off for each leg) of a Kling 4.0 clip at 720p started and
ended on one Nano Banana 2 still of him (clip.py: keyed, each drawing the median of its ten repeats in the clip; the
video model animates him on twos, in slow motion too: bandit_run_v2); six are the in-betweens Nano Banana 2 drew on
the keys' chart (between.py: the landing, the roll over the planted foot and the lift-off of each leg), all twelve
redrawn crisp at four times the clip's size. The runs before were 16 and 14 frames of a 480p clip: soft and blocky at
the size they are drawn.

His other poses (waiting, the fist drawn back and thrown, hit, the leap, the jump's four) are read back from the sheet
of commit 1146f61, as they were (their sources went in the 2026-11-08 clean-up); the new run is brought to the old
run's height on the same ground, so he keeps his size from pose to pose:

    for f in bandit.png bandit.json bandit_strong.png bandit_strong.json; do git show 1146f61:New/assets/art/bandit/$f > tools/art/gen/kie/atlas_src/$f; done
    python3 tools/art/kie/bandit_pack.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[3]
GEN = NEW / "tools/art/gen/kie"
SRC = GEN / "atlas_src"
OUT = NEW / "assets/art/bandit"
KINDS = {"bandit": "bandit_run_v1", "bandit_strong": "strong_run_v1"}
PAD = 3
VANISH = [0, 1, 3, 5, 6, 7, 6, 7, 6, 7]  # banditMort1-10: run frames under the glaze, then the twirl
BANDIT_SPEED = 10.0 * 960.0 / 1320.0 * 40.0  # units a second against the ground (World.BANDIT_RUN)


def rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def resized(a: np.ndarray, k: float) -> np.ndarray:
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    size = (max(1, round(a.shape[1] * k)), max(1, round(a.shape[0] * k)))
    r = np.clip(np.dstack([np.asarray(Image.fromarray(pm[..., c]).resize(size, Image.LANCZOS)) for c in range(4)]), 0, 1)
    al = r[..., 3:4]
    return np.dstack([np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]])


def no_ground_line(a: np.ndarray, s: int = 1) -> np.ndarray:
    """The generators draw a thin dark stroke of ground (or a flat shadow) under a boot: what is thinner than a sole
    in the lowest rows of the figure goes (`s`: the drawing's size, times the clip's)."""
    out = a.copy()
    for _ in range(2):  # (a shadow lying apart under a boot in the air, then a stroke under the boot itself)
        al = out[..., 3] > 0.3
        bottom = np.nonzero(al.any(axis=1))[0].max()
        thick = ndi.binary_opening(al, structure=np.ones((7 * s, 5 * s), bool))
        thick = ndi.binary_dilation(thick, iterations=3 * s) & al
        rows = np.zeros(al.shape, bool)
        rows[bottom - 9 * s:] = True
        out[..., 3] = np.where(rows & ~thick, 0.0, out[..., 3])
    return out


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
    if len(hy) < 20:
        hy, hx = np.nonzero(al[: int(top)])
    return float(hx.mean()), float(hy.mean())


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
    """Px the planted boot moves back (to the right: he runs left) a drawing, while it stays on the ground: read off
    the clip's own drawings (the even ones: from the passing pose to the push-off, two drawings on), the true pace of
    the stride; the in-betweens were drawn one by one, their boot a few px either side of that line."""
    at = []
    for a in run:
        ys, xs = np.nonzero(a[..., 3] > 0.5)
        low = ys.max()
        at.append(float(xs[ys >= low - 3].mean()) if low >= ground - 10 else None)
    n = len(at)
    steps = [(at[(i + 2) % n] - at[i]) / 2.0 for i in range(0, n, 2) if at[i] is not None and at[(i + 2) % n] is not None]
    good = [s for s in steps if s > 0]
    print("   boots on the ground:", [None if v is None else round(v) for v in at], "back a drawing", [round(s, 1) for s in good])
    return float(np.mean(good)) if good else 0.0


def build(kind: str) -> None:
    old = json.loads((SRC / f"{kind}.json").read_text())
    sheet = rgba(SRC / f"{kind}.png")
    scale = float(old["texture_scale"])
    n_old = int(old["run_frames"])
    olds = []
    for (x, y, w, h, px, py), hd in zip(old["frames"], old["head"]):
        olds.append((sheet[y:y + h, x:x + w], np.array([px, py]), hd))
    # the old run: how tall he runs (his feet's ground to the top of him)
    tall_old = float(np.median([p[1] - np.nonzero(a[..., 3] > 0.5)[0].min() for a, p, _ in olds[:n_old]]))
    run = [no_ground_line(rgba(p), 2) for p in sorted((GEN / KINDS[kind] / "cycle12").glob("*.png"))]  # (twice the clip's size)
    ground = float(max(np.nonzero(a[..., 3] > 0.5)[0].max() for a in run))
    tall_new = float(np.median([ground - np.nonzero(a[..., 3] > 0.5)[0].min() for a in run]))
    k = tall_old / tall_new
    run = [resized(a, k) for a in run]
    ground = float(max(np.nonzero(a[..., 3] > 0.5)[0].max() for a in run))
    mid = float(np.mean([middle_x(a) for a in run]))
    frames, heads = [], []
    for a in run:
        pivot = np.array([mid, ground])
        hx, hy = head(a)
        heads.append([round(hx - pivot[0], 1), round(hy - pivot[1], 1)])
        frames.append(trimmed(a, pivot))
    for a, pivot, hd in olds[n_old:]:
        frames.append((a, pivot))
        heads.append(hd)
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
    solid = page[..., 3] > 0.02
    idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    out = np.dstack([page[..., :3][idx[0], idx[1]], page[..., 3]])
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / f"{kind}.png", optimize=True)
    n = len(run)
    step = planted_step(run, ground) / scale  # units a drawing
    fps = BANDIT_SPEED / step if step > 0 else 12.0
    data = {"texture_scale": scale, "frames": rects, "run": 0, "wait": n, "swing": n + 1, "hit": n + 3,
            "leap": n + 4, "jump": [n + 5, n + 6, n + 7, n + 8], "run_frames": n, "swing_frames": 2, "run_fps": round(fps, 2),
            "head": heads, "vanish": [v % n for v in VANISH]}
    (OUT / f"{kind}.json").write_text(json.dumps(data, indent=1))
    print(f"{kind}.png {width} x {height}: {len(frames)} frames ({n} run, x{k:.3f} of the clip), he runs {tall_old / scale:.0f} units tall, "
          f"planted boot {step:.1f} units a drawing -> run {fps:.1f} drawings/s")


if __name__ == "__main__":
    for kind in KINDS:
        build(kind)
