#!/usr/bin/env python3
"""(2026-11-12, the user: "the animations are not full: the hero's running cycle is not good enough") The hero's atlas
with this round's kie.ai animations (assets/art/hero/hero_atlas_N.png + hero_frames.json, the layout HeroView reads):

  run     12 drawings, one whole stride (both steps): the motion from a Kling 4.0 clip started and ended on one
          Nano Banana 2 still (clip.py: keyed, the backdrop's pink light taken out, each drawing the median of the
          clip's five repeats), each drawing then redrawn crisp by Nano Banana 2 without moving a limb (sheet.py: the
          clip's fast fists and back boot were smears); the 16 before were half a stride played twice, in two
          different drawings of him;
  jump    the air poses of one Nano Banana 2 sheet (cells.py): 0-1 the push-off, 2 the rise, 3 the tuck at the top,
          4 opening, 5 the fall, 6 braced for the ground, 7 a throw in the air (the leap before borrowed the vine's
          reach: both arms up all the way);
  throw   0-11 the chakram cocked, 12-23 the arm thrown, each over the legs of the run drawing with the same number
          (throw.py: two Nano Banana 2 edits of the run's sheet, only what they changed laid over the run's drawing);
  land    the old jump's landing (its frames 21-26): at home, into his victory.
The other animations (idle, die, win, climb, hang, catch, crouch, hurt) are read back from the atlas of commit
1146f61, as they were (their sources went in the 2026-11-08 clean-up):

    mkdir -p tools/art/gen/kie/atlas_src
    for f in hero_frames.json hero_atlas_{0,1,2,3}.png; do git show 1146f61:New/assets/art/hero/$f > tools/art/gen/kie/atlas_src/$f; done
    python3 tools/art/kie/hero_pack.py          # then tools/art/hero_contacts.py (run from here) measures soles and fists
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[3]
GEN = NEW / "tools/art/gen/kie"
SRC = GEN / "atlas_src"
OUT = NEW / "assets/art/hero"
PAGE, PAD = 2048, 3
UNITS = 150.0 / 345.0  # units an atlas px: he stands 345 px, 150 units
GROUND_SPEED = 8.0 * 960.0 / 1320.0 * 40.0  # units a second (World.SCROLL_SPEED a tick)
K_RUN = 0.66  # the clip's px -> atlas px: his run as tall as it was (337 px), his head the idle's
UP = 2  # sheet.py keeps the redrawn frames at twice the clip's size
RUN_FPS = 16.0  # HeroView.RUN_FPS: the run's drawings a second (the user's 16 of 2026-11-07; the ground's pace is printed)
K_AIR = 0.61  # the air sheet's
KEEP = ["idle", "die", "win", "climb", "hang", "catch", "crouch", "hurt"]
## (the user, 2026-11-12, on the two runs side by side over the moving ground: "the hero before run animation was better
## and smoother") "before": his run (16 drawings) and the throw over it (32) are the atlas's of commit 1146f61 again,
## rendered from his 3D model's own motion: even from drawing to drawing. "clip": the 12 drawings of the Kling clip,
## redrawn (crisper one by one, but unevenly spaced and with no flight; kept for reference, not used).
RUN = "before"
AIR_SHEET = "hero_air_2"  # the sheet of his air poses (cells.py)
AIR = [0, 0, 1, 2, 3, 4, 5, 7]  # the jump's slots: the air sheet's cells
LAND = range(21, 25)  # the old jump's landing: its crouch (HeroView.LAND_CROUCH drawings; the two after are not shown)


def rgba(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def resized(a: np.ndarray, k: float) -> np.ndarray:
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    size = (max(1, round(a.shape[1] * k)), max(1, round(a.shape[0] * k)))
    r = np.clip(np.dstack([np.asarray(Image.fromarray(pm[..., c]).resize(size, Image.LANCZOS)) for c in range(4)]), 0, 1)
    al = r[..., 3:4]
    return np.dstack([np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]])


def hips_of(a: np.ndarray) -> list:
    """The top middle of his white fur loincloth."""
    al = a[..., 3] > 0.5
    rgb = a[..., :3]
    mn, mx = rgb.min(axis=2), rgb.max(axis=2)
    white = al & (mn > 0.59) & (mx - mn < 0.18) & ~(rgb[..., 2] > rgb[..., 0] + 0.05)
    lab, n = ndi.label(ndi.binary_opening(white, iterations=1))
    ys, xs = np.nonzero(al)
    if n:
        sz = ndi.sum(white, lab, range(1, n + 1))
        cy, cx = np.nonzero(lab == 1 + int(np.argmax(sz)))
        top = cy.min()
        band = cy < top + max(4, (cy.max() - top) * 0.25)
        return [float(cx[band].mean()), float(top + 2)]
    return [float(xs.mean()), float(ys.min() + (ys.max() - ys.min()) * 0.5)]


def frame(a: np.ndarray, origin=None, hips=None) -> dict:
    """A drawing on its canvas -> trimmed, with its anchors (the atlas' keys) in the trimmed picture's px."""
    ys, xs = np.nonzero(a[..., 3] > 0.5)
    hips = hips or hips_of(a)
    top, bot = int(ys.min()), int(ys.max())
    tx, bx = xs[ys <= top + 3], xs[ys >= bot - 4]
    origin = origin or [hips[0], float(bot)]
    pts = dict(origin=origin, hips=hips, head=[float(tx.mean()), float(top)], toe_r=[float(bx.min()), float(bot)],
               toe_l=[float(bx.max()), float(bot)], hand_r=[float(tx.mean()), float(top + 14)],
               hand_l=[float(tx.mean()), float(top + 14)])
    ys, xs = np.nonzero(a[..., 3] > 0.004)
    x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, a.shape[1])
    y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, a.shape[0])
    out = {k: [round(v[0] - x0, 1), round(v[1] - y0, 1)] for k, v in pts.items()}
    out["img"] = a[y0:y1, x0:x1]
    return out


def old_frames() -> dict:
    data = json.loads((SRC / "hero_frames.json").read_text())
    pages = [rgba(SRC / p) for p in data["pages"]]
    out = {}
    for anim, entry in data["anims"].items():
        out[anim] = []
        for f in entry["frames"]:
            x, y, w, h = f["region"]
            g = {k: f[k] for k in ("origin", "hips", "head", "toe_r", "toe_l", "hand_r", "hand_l")}
            g["img"] = pages[f["page"]][y:y + h, x:x + w]
            out[anim].append(g)
    return out, {a: (e["fps"], e["loop"]) for a, e in data["anims"].items()}


def planted(pics: list, ground: float) -> list:
    """Each drawing's planted boot: (its x, which foot) or None in the air. A boot is planted while the lowest of him
    is near the ground line (the stride bobs: he is lowest as his weight comes onto the boot); a new stance begins
    when the lowest boot is suddenly far ahead of the last one (the other foot has come down in front)."""
    out, foot, last = [], 0, None
    lows = []
    for a in pics:
        ys, xs = np.nonzero(a[..., 3] > 0.5)
        low = ys.max()
        lows.append((float(xs[ys >= low - 3].mean()), low))
    start = int(np.argmax([x for x, _ in lows]))  # (from a boot far ahead: a stance's first drawing)
    n = len(pics)
    res = [None] * n
    for j in range(n):
        i = (start + j) % n
        x, low = lows[i]
        if low < ground - 12.5:
            last = None
            continue
        if last is None or x > last + 30:
            foot = 1 - foot
        last = x
        res[i] = (x, foot)
    return res


def run_frames() -> tuple:
    pics = [resized(rgba(p), K_RUN / UP) for p in sorted((GEN / "hero_run_clean").glob("[0-9][0-9].png"))]
    ground = float(max(np.nonzero(a[..., 3] > 0.5)[0].max() for a in pics))
    hips = [hips_of(a) for a in pics]
    hips = [float(np.mean([h[0] for h in hips])), float(np.median([h[1] for h in hips]))]
    return pics, [hips[0], ground], hips


def build() -> None:
    old, meta = old_frames()
    anims = {a: old[a] for a in KEEP}
    if RUN == "before":
        anims["run"], anims["throw"] = old["run"], old["throw"]
        air = {c: frame(resized(rgba(GEN / AIR_SHEET / ("%02d.png" % c)), K_AIR)) for c in set(AIR)}
        anims["jump"] = [air[c] for c in AIR]
        anims["land"] = [old["jump"][i] for i in LAND]
        pack(anims, dict(meta, jump=(30.0, False), land=(30.0, False)))
        return
    pics, origin, hips = run_frames()
    n = len(pics)
    anims["run"] = [frame(a, origin, hips) for a in pics]
    # the planted boots (toe_r, toe_l: on the ground line while planted, lifted otherwise) and the pace that holds
    # them on the ground
    boots = planted(pics, origin[1])
    steps = []
    for i, f in enumerate(anims["run"]):
        dx, dy = f["origin"][0] - origin[0], f["origin"][1] - origin[1]  # (the trim's offset)
        for t in ("toe_r", "toe_l"):
            f[t] = [f["origin"][0], round(f["origin"][1] - 40.0, 1)]
        if boots[i]:
            f[("toe_r", "toe_l")[boots[i][1]]] = [round(boots[i][0] + dx, 1), f["origin"][1]]
            nxt = boots[(i + 1) % n]
            if nxt and nxt[1] == boots[i][1]:
                steps.append(boots[i][0] - nxt[0])
    per = float(np.mean(steps))
    print("run: boots planted", [None if b is None else (round(b[0]), "rl"[b[1]]) for b in boots],
          "back %.1f px a drawing: the ground's pace is %.1f drawings/s (played at %.0f: x%.2f)"
          % (per, GROUND_SPEED / (per * UNITS), RUN_FPS, RUN_FPS * per * UNITS / GROUND_SPEED))
    # (hero_air_2: drawn from three of the run's own drawings as the model; hero_air_1, from the older key picture, was
    # "a leaner, paler model with rounder, browner hair: a swap at take-off and landing", the blind judge, 2026-11-12)
    air = {c: frame(resized(rgba(GEN / AIR_SHEET / ("%02d.png" % c)), K_AIR)) for c in set(AIR)}
    anims["jump"] = [air[c] for c in AIR]
    anims["land"] = [old["jump"][i] for i in LAND]
    throw = sorted((GEN / "hero_throw").glob("[0-9][0-9].png"))
    if len(throw) == 2 * n:  # (throw.py: on the run's canvas)
        anims["throw"] = [frame(resized(rgba(p), K_RUN / UP), origin, hips) for p in throw]
        for i, f in enumerate(anims["throw"]):
            dx = f["origin"][0] - origin[0]
            for t in ("toe_r", "toe_l"):
                f[t] = [f["origin"][0], round(f["origin"][1] - 40.0, 1)]
            if boots[i % n]:
                f[("toe_r", "toe_l")[boots[i % n][1]]] = [round(boots[i % n][0] + dx, 1), f["origin"][1]]
    else:
        print("no throw drawings yet: the run's stand in")
        anims["throw"] = anims["run"] * 2
    pack(anims, dict(meta, run=(24.0, True), jump=(30.0, False), land=(30.0, False), throw=(24.0, False)))


def pack(anims: dict, fps: dict) -> None:
    """The atlas pages and hero_frames.json from the animations' frames."""
    # unique pictures -> atlas regions (shelves, tallest first)
    uniq, order = {}, []
    for a in anims.values():
        for f in a:
            f["hash"] = hashlib.sha1(f["img"].tobytes()).hexdigest()
            if f["hash"] not in uniq:
                uniq[f["hash"]] = f["img"]
                order.append(f["hash"])
    order.sort(key=lambda h: -uniq[h].shape[0])
    placed = {}
    x = y = shelf = page = 0
    for h in order:
        hh, ww = uniq[h].shape[:2]
        if x + ww > PAGE:
            x, y, shelf = 0, y + shelf, 0
        if y + hh > PAGE:
            page += 1
            x = y = shelf = 0
        placed[h] = (page, x, y)
        x += ww
        shelf = max(shelf, hh)
    names = []
    for old_page in OUT.glob("hero_atlas_*.png"):
        if int(old_page.stem.rsplit("_", 1)[1]) > page:
            old_page.unlink()
            Path(str(old_page) + ".import").unlink(missing_ok=True)
    for p in range(page + 1):
        hmax = max(v[2] + uniq[h].shape[0] for h, v in placed.items() if v[0] == p)
        canvas = np.zeros(((hmax + 3) // 4 * 4, PAGE, 4), np.float32)
        for h, (pg, px, py) in placed.items():
            if pg == p:
                canvas[py:py + uniq[h].shape[0], px:px + uniq[h].shape[1]] = uniq[h]
        solid = canvas[..., 3] > 0.5
        idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
        out = np.dstack([canvas[..., :3][idx[0], idx[1]], canvas[..., 3]])
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / f"hero_atlas_{p}.png", optimize=True)
        names.append(f"hero_atlas_{p}.png")
    data = {"units_per_px": round(UNITS, 5), "run_fps": RUN_FPS, "pages": names, "anims": {}}
    for a, fr in anims.items():
        rows = []
        for f in fr:
            pg, px, py = placed[f["hash"]]
            row = {"page": pg, "region": [px, py, f["img"].shape[1], f["img"].shape[0]]}
            row.update({k: f[k] for k in ("origin", "hips", "head", "toe_r", "toe_l", "hand_r", "hand_l")})
            rows.append(row)
        data["anims"][a] = {"fps": fps[a][0], "loop": fps[a][1], "frames": rows}
    (OUT / "hero_frames.json").write_text(json.dumps(data, separators=(",", ":")))
    print("pages", len(names), "pictures", len(uniq), {a: len(f) for a, f in anims.items()})
    subprocess.run([sys.executable, str(NEW / "tools/art/hero_contacts.py")], check=True)


if __name__ == "__main__":
    build()
