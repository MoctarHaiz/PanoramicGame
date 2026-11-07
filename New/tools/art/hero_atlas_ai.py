#!/usr/bin/env python3
"""Packs the hero's animations into the atlas the game reads (hero_atlas_N.png + hero_frames.json, the layout of
New/tools/art/hero_atlas.py). Every animation keeps the game's slot count; each slot is a picture at the scale of the cut
kie.ai stills: from a Seedance clip (anim/final/<anim>/NN.png, one file per slot, video/vframes.py) or a still
(anim/cut/<sheet>/NN.png). Identical pictures share one atlas region. Anchors are measured on the pictures: the origin
on the ground under the hips, the hips at the top of the fur loincloth, the hands at the top of the figure (hanging),
the run's planted boot tracked from frame to frame.

    python3 tools/art/hero_atlas_ai.py [OUT_DIR] [RUN_FPS]   # default assets/art/hero, run_fps 16 (HeroView.RUN_FPS)
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[2]
ROOT = NEW.parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else NEW / "assets/art/hero"
RUN_FPS = float(sys.argv[2]) if len(sys.argv) > 2 else 16.0
PAGE, PAD = 2048, 3
STAND_ATLAS = 345.0  # standing height in the atlas (150 units at 0.43478 units/px)
STAND_GEN = 675.0    # standing height in the cut stills
UNITS = 150.0 / STAND_ATLAS
GROUND_SPEED = 8.0 * 960.0 / 1320.0 * 40.0
GRIP_UP = 14.0
FINAL = ROOT / "_agents/kie/anim/final"  # one picture per slot from the Seedance clips (video/vframes.py)
CUT = ROOT / "_agents/kie/anim/cut"  # the cut kie.ai stills (grid_cut.py)


def slots(seq):
    return [f for f, n in seq for _ in range(n)]


def final(anim, idx=None, factor=None):
    """The slot pictures of a clip (all, or those numbered idx); with a factor, each as (path, factor)."""
    paths = sorted(str(p) for p in (FINAL / anim).glob("*.png"))
    if idx is not None:
        paths = [paths[i] for i in idx]
    return [(p, factor) for p in paths] if factor else paths


def cut(sheet, seq):
    return [str(CUT / sheet / f"{i:02d}.png") for i in seq]


# animation -> (slot pictures, size factor, fps, loop, ground rule); a picture given as (path, factor) has its own size
# factor (the jump borrows the hang clip's frames, drawn at the hang's size)
# ground rule: "first" = slot 0 stands on the ground, "last" = the last slot lies on it, "max" = the lowest boot of the
# whole cycle (a run filmed with a level camera: the flight frames keep their height above it), None = never on the
# ground (hanging)
ANIMS = {
    "run": (final("run"), 1.0, 30.0, True, "max"),
    # the jump: the clip's takeoff (0-1), in the air the hang clip's leap with the arms up (the user's choice,
    # 2026-11-07: the clip's own tuck drew a third leg), its fall reaching down (16-18) and landing (19-26)
    "jump": (final("jump", [0, 1]) + final("hang", list(range(12)) + [0, 1], 1.15) + final("jump", range(16, 27)),
             1.0, 30.0, False, "first"),
    "idle": (final("idle"), 1.0, 10.0, True, "first"),
    "die": (final("die"), 1.0, 20.0, False, "last"),
    "win": (final("win"), 1.0, 20.0, False, "first"),
    "climb": (cut("climb", range(8)), 1.0, 30.0, False, "last"),  # the stills: 8 drawings for its 8 slots
    "hang": (final("hang"), 1.15, 10.0, True, None),
    "catch": (cut("catch_hang", [0, 1, 2, 3]), 1.15, 30.0, False, None),
    "crouch": (cut("hurt_crouch", [4, 5, 6, 7]), 1.0, 24.0, False, "first"),
    "hurt": (cut("hurt_crouch", slots([(0, 3), (1, 3), (2, 2), (3, 2)])), 1.0, 30.0, False, "first"),
    # the throw (a Seedance 2.5 clip from run slot 3, video/throw_match.py): 0-15 the chakram cocked overhead, 16-31 the
    # arm thrown forward, each drawn over the legs of the run slot with the same number (matched in the clip's holds)
    "throw": (final("throw_v2"), 1.0, 30.0, False, "max"),
}

_cache = {}


def load(path, factor):
    keyp = (path, factor)
    if keyp in _cache:
        return _cache[keyp]
    im = Image.open(path).convert("RGBA")
    k = STAND_ATLAS / STAND_GEN * factor
    a = np.asarray(im).astype(np.float32) / 255.0
    pm = a.copy(); pm[..., :3] *= pm[..., 3:4]
    w, h = round(im.width * k), round(im.height * k)
    ch = [np.asarray(Image.fromarray(pm[..., c]).resize((w, h), Image.LANCZOS)) for c in range(4)]
    r = np.clip(np.dstack(ch), 0, 1)
    al = r[..., 3:4]
    rgb = np.where(al > 1e-4, r[..., :3] / np.maximum(al, 1e-4), 0)
    out = np.dstack([np.clip(rgb, 0, 1), al[..., 0]])
    _cache[keyp] = out
    return out


def fig(a):
    al = a[..., 3] > 0.5
    ys, xs = np.where(al)
    return al, ys, xs


def hips_of(a):
    al, ys, xs = fig(a)
    rgb = a[..., :3] * 255
    mn, mx = rgb.min(axis=2), rgb.max(axis=2)
    white = al & (mn > 150) & (mx - mn < 45) & ~(rgb[..., 2] > rgb[..., 0] + 12)
    lab, n = ndi.label(white)
    if n:
        sz = ndi.sum(white, lab, range(1, n + 1))
        comp = lab == (1 + int(np.argmax(sz)))
        cy, cx = np.where(comp)
        top = cy.min(); band = cy < top + max(4, (cy.max() - top) * 0.25)
        return [float(cx[band].mean()), float(top + 2)]
    return [float(xs.mean()), float(ys.min() + (ys.max() - ys.min()) * 0.5)]


def contacts(a, g, tol=3.0):
    al, ys, xs = fig(a)
    sel = ys >= g - tol
    if not sel.any():
        return []
    xg = np.sort(np.unique(xs[sel]))
    groups, cur = [], [xg[0]]
    for x in xg[1:]:
        if x - cur[-1] > 8:
            groups.append(cur); cur = [x]
        else:
            cur.append(x)
    groups.append(cur)
    return [float(np.mean(gp)) for gp in groups]


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = {}   # (path, factor) -> measured picture
    entries = {}  # anim -> list of (path, factor) per slot
    for anim, (paths, factor, fps, loop, rule) in ANIMS.items():
        if not paths:
            raise SystemExit(f"no pictures for {anim}")
        items = [(p, factor) if isinstance(p, str) else (p[0], p[1]) for p in paths]
        paths = [p for p, _ in items]
        pics = [load(p, f) for p, f in items]
        lows = [fig(a)[1].max() for a in pics]
        if rule == "first":
            ground = float(lows[0])
        elif rule == "last":
            ground = float(lows[-1])
        elif rule == "max":
            ground = float(max(lows))
        else:
            ground = None
        entries[anim] = []
        for (p, f_), a, low in zip(items, pics, lows):
            k = (p, f_, anim)
            al, ys, xs = fig(a)
            hips = hips_of(a)
            on_ground = ground is not None and low >= ground - 4.0
            g = float(low) if on_ground else (ground if ground is not None else float(low))
            top = int(ys.min()); tx = xs[ys <= top + 3]
            bot = int(ys.max()); bx = xs[ys >= bot - 4]
            frames[k] = dict(img=a, origin=[hips[0], g], hips=hips, head=[float(tx.mean()), float(top)],
                             toe_r=[float(bx.min()), float(bot)], toe_l=[float(bx.max()), float(bot)],
                             hand_r=[float(tx.mean()), float(top + GRIP_UP)], hand_l=[float(tx.mean()), float(top + GRIP_UP)],
                             contacts=contacts(a, g) if on_ground else [])
            entries[anim].append(k)
    # run and throw: one origin for the whole cycle, where the clip's level camera framed him (the mean hips x, the
    # lowest boot): the drawing moves as filmed, without the loincloth's flutter in a per-frame anchor. The throw
    # frames are on the run's canvas (the clip started from a run frame, at its scale and place).
    k = STAND_ATLAS / STAND_GEN
    run_x = float(np.mean([frames[q]["hips"][0] for q in entries["run"]]))
    run_g = max(fig(frames[q]["img"])[1].max() for q in entries["run"])
    for anim, dy in (("run", 0.0), ("throw", 0.0)):
        for q in entries[anim]:
            f = frames[q]
            f["origin"] = [run_x, float(run_g + dy)]
            low = fig(f["img"])[1].max()
            f["contacts"] = contacts(f["img"], float(low)) if low >= run_g + dy - 4.0 else []
    # the planted boots: a stance is a run of frames with a boot on the ground; each stance is one foot, the feet
    # alternate (toe_r, toe_l, ...). In a stance the planted boot is the contact nearest the last one (it travels back).
    for anim in ("run", "throw"):
        ks = entries[anim]
        n = len(ks)
        start = next((i for i in range(n) if not frames[ks[i]]["contacts"]), 0)  # begin after a flight frame
        foot, prev, stance = 1, None, False
        for j in range(n):
            f = frames[ks[(start + j) % n]]
            for t in ("toe_r", "toe_l"):
                f[t] = [f[t][0], f["origin"][1] - 40.0]  # lifted unless planted below
            if not f["contacts"]:
                stance, prev = False, None
                continue
            if not stance:
                foot, stance = 1 - foot, True
                c = max(f["contacts"])  # the landing boot is the front one
            else:
                c = min(f["contacts"], key=lambda v: abs(v - prev))
            prev = c
            f[("toe_r", "toe_l")[foot]] = [c, f["origin"][1]]
    # unique pictures -> atlas regions (shelves, tallest first)
    uniq = {}
    for k, f in frames.items():
        h = hashlib.sha1(f["img"].tobytes()).hexdigest()
        uniq.setdefault(h, []).append(k)
    order = sorted(uniq, key=lambda h: -frames[uniq[h][0]]["img"].shape[0])
    placed = {}
    x = y = shelf = page = 0
    for h in order:
        a = frames[uniq[h][0]]["img"]
        al = a[..., 3] > 0.004
        ys, xs = np.where(al)
        x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, a.shape[1])
        y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, a.shape[0])
        crop = a[y0:y1, x0:x1]; hh, ww = crop.shape[:2]
        if x + ww > PAGE:
            x, y, shelf = 0, y + shelf, 0
        if y + hh > PAGE:
            page += 1; x = y = shelf = 0
        placed[h] = (page, x, y, ww, hh, x0, y0, crop)
        x += ww; shelf = max(shelf, hh)
    pages = []
    for p in range(page + 1):
        hmax = max(v[2] + v[4] for v in placed.values() if v[0] == p)
        canvas = np.zeros((hmax, PAGE, 4), np.float32)
        for pg, px, py, ww, hh, x0, y0, crop in placed.values():
            if pg == p:
                canvas[py:py + hh, px:px + ww] = crop
        solid = canvas[..., 3] > 0.5
        idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
        out = np.dstack([canvas[..., :3][idx[0], idx[1]], canvas[..., 3]])
        Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / f"hero_atlas_{p}.png", optimize=True)
        pages.append(f"hero_atlas_{p}.png")
    hash_of = {k: h for h, ks in uniq.items() for k in ks}

    def entry(k):
        pg, px, py, ww, hh, x0, y0, _ = placed[hash_of[k]]
        f = frames[k]
        rel = lambda pt: [round(pt[0] - x0, 1), round(pt[1] - y0, 1)]
        return {"page": pg, "region": [px, py, ww, hh], "origin": rel(f["origin"]), "hips": rel(f["hips"]),
                "head": rel(f["head"]), "toe_r": rel(f["toe_r"]), "toe_l": rel(f["toe_l"]),
                "hand_r": rel(f["hand_r"]), "hand_l": rel(f["hand_l"])}

    anims = {a: {"fps": ANIMS[a][2], "loop": ANIMS[a][3], "frames": [entry(k) for k in entries[a]]} for a in ANIMS}
    run = anims["run"]["frames"]
    gmax = max(max(f["toe_r"][1] - f["origin"][1], f["toe_l"][1] - f["origin"][1]) for f in run)
    steps = []
    for i in range(len(run)):
        a, b = run[i], run[(i + 1) % len(run)]
        for t in ("toe_r", "toe_l"):
            if a[t][1] - a["origin"][1] > gmax - 2.5 and b[t][1] - b["origin"][1] > gmax - 2.5:
                steps.append((a[t][0] - a["origin"][0]) - (b[t][0] - b["origin"][0]))
    per_slot = float(np.mean(steps)) if steps else 0.0
    matched = GROUND_SPEED / (per_slot * UNITS) if per_slot > 0 else 0.0
    data = {"units_per_px": round(UNITS, 5), "run_fps": round(RUN_FPS or matched, 2), "pages": pages, "anims": anims}
    (OUT / "hero_frames.json").write_text(json.dumps(data, separators=(",", ":")))
    print("pages", len(pages), "unique pictures", len(uniq), "run steps", [round(s, 1) for s in steps],
          "per slot %.1f px -> matched run fps %.1f" % (per_slot, matched))


if __name__ == "__main__":
    build()
