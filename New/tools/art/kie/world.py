#!/usr/bin/env python3
"""The level's backdrop from its painted layers (2026-11-12, the world redesign).

GPT Image 2.6 Sunburst (kie.py --model sunburst: chosen over Seedream 5.5 on one style frame, world/frame.txt) painted
the frame, then each layer of it alone on a transparent background, with the frame as its reference
(tools/art/gen/kie/world/NAME.txt -> NAME.png). This cuts them into the pictures SavannaView draws:

    sky.png              the sky's panorama, repeating left to right
    far_wall.png         the far escarpment (a strip: its top part, the rest is behind the plain)
    far_mesa_pieces.png  twelve landforms, each alone (+ .json: where, what kind)
    far_hills.png        the plain behind the path, one ground from the path to its horizon (a strip)
    river.png            the river under the vine, from its far bank down (a strip)
    near_grass.png       the tall grass behind the path (a strip)
    tree_*.png           ten trees (+ tree_info.json: the foot of each trunk)
    fg_props.png         six plants and rocks near the camera
    home_fire.png        the cooking fire's hearth at home; home_flames.png its flames, four frames (HomeView.Fire)
    home_sign.png        the HOME signpost (sign); home_hut.png's doorway repainted dark, in place (door)
    fx_impact.png        a blow's burst, three frames (impact: Fx.hit_spark)
    sky_clouds.png       the sky's cumulus alone, off the finished sky.png (clouds): drawn again higher up
    spires.png           three rock pinnacles, each in a cell (spires: TerrainView's stacks in the river)
    earth.png            the cut bank of the main ground under the turf (terrain.gdshader), repeating
    canopy.png           the boughs the liana hangs from, along the top of the level (canopy: CanopyView)

    python3 tools/art/kie/world.py [sky wall mesas plain river grass trees front fire earth | sign door clouds impact spires canopy]
    (none: the first ten)

A strip repeats: its right end is laid over its left end along the path where the two differ least (the plain, the
grass), or faded across it (the sky, the far wall: smooth things), and that much is cut off its width.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

GEN = Path(__file__).resolve().parents[1] / "gen/kie/world"
OUT = Path(__file__).resolve().parents[3] / "assets/art/world"
## landform kinds, in the sheet's order (SavannaView.MESA_KINDS: a spire stands taller and sinks at dusk, a low one squats)
MESA_KINDS = ["block", "block", "arch", "spire", "low", "block", "block", "spire", "arch", "low", "spire", "low"]
TREES = ["tree_acacia_1", "tree_acacia_2", "tree_acacia_3", "tree_acacia_4", "tree_acacia_5",
         "tree_baobab_1", "tree_baobab_2", "tree_baobab_3", "tree_acacia_6", "tree_baobab_4"]
## how big each tree is kept (of the sheet's px): the four tall ones stand big behind the tall grass (SavannaView
## .TREE_TALL: 232 units), two are level props too (PropView: 140 to 150 units), the others are small and far
TREE_SCALE = {"tree_acacia_2": 0.9, "tree_acacia_5": 0.9, "tree_baobab_2": 0.9, "tree_baobab_4": 0.9,
              "tree_acacia_1": 0.6, "tree_acacia_3": 0.6}
HEARTH_TIP, HEARTH_SLOPE, HEARTH_STONES = 0.672, 0.55, 0.8  # the hearth's logs: their tips, their lean, the stones' tops (fire)
FLAME_K = 0.46  # the flames, of fire3's px: about 215 px across on the 308 px hearth
FLAME_CELL = (308, 440)  # px, a frame of home_flames.png: the hearth's width
FLAME_FOOT = 52  # px over the cell's bottom the flames stand: behind the logs, on the embers
PLAIN_ENDS = 70  # px cut off each end of a wide painting (plain, river: the painter smears its two ends into level streaks)
PLAIN_ROWS = 545  # px of the plain kept under its horizon (SavannaView: the rest is under the screen)
PLAIN_JOIN = 600  # px of each end its join may wander in (a drawn bush or rock is one end's or the other's, whole)
PLAIN_SLIPS = [((975, 1095), (3250, 3500), 235), ((905, 960), (3350, 3460), 100)]  # (rows, columns, columns to its left the grass is taken from)
RIVER_ROWS = 760  # px of the river kept under its far waterline
RIVER_JOIN = 640
FRONT_CELL = (440, 390)  # px: SavannaView.FRONT_PROP at 1.7 px a unit (dark shapes passing fast: no finer)


def load(name) -> np.ndarray:
    """Premultiplied RGBA, 0..1."""
    a = np.asarray(Image.open(GEN / (name + ".png")).convert("RGBA")).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]
    return a


def save(a: np.ndarray, path: Path, opaque=False) -> None:
    al = a[..., 3:4]
    rgb = np.where(al > 1e-4, a[..., :3] / np.maximum(al, 1e-4), 0.0)
    out = (np.clip(np.dstack([rgb, al[..., 0]]), 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(out, "RGBA").convert("RGB" if opaque else "RGBA").save(path)
    print("%s %dx%d" % (path.name, out.shape[1], out.shape[0]))


def resize(a: np.ndarray, size) -> np.ndarray:
    return np.clip(np.dstack([np.asarray(Image.fromarray(a[..., q]).resize(size, Image.LANCZOS)) for q in range(4)]), 0, 1)


def fade(a: np.ndarray, b: int) -> np.ndarray:
    """Repeats left to right: the last `b` columns faded over the first `b`."""
    t = np.linspace(0.0, 1.0, b, dtype=np.float32)
    t = (t * t * (3 - 2 * t))[None, :, None]
    zone = a[:, -b:] * (1 - t) + a[:, :b] * t
    return np.concatenate([zone, a[:, b:-b]], axis=1)


def seam(a: np.ndarray, b: int, feather=5.0, steer=(), reach=1, lean=None, match=0) -> np.ndarray:
    """Repeats left to right: the last `b` columns joined to the first `b` along the top-to-bottom path where the two
    differ least (a blade of grass is one end's or the other's, never a ghost of both). `steer`: (row, column) pairs:
    from that row down the path runs at that column (open water: round a sandbar's tip, not through it). `reach`: the
    columns the path may step aside in a row (drawn bushes and rocks stand in both ends: it winds between them).
    `lean`: (row, column): from that row down the path is drawn toward that column (which end's things stand there).
    `match`: the two ends' tones are brought to each other over this many px on each side of the path (the painter
    left one end's grass lighter: a faint upright step where the picture repeats)."""
    end, start = a[:, -b:], a[:, :b]
    cost = ((end - start) ** 2).sum(axis=-1)
    cost = ndi.maximum_filter(cost, size=(1, 9)) + 1e-5  # (clear of an object's outline, not along it)
    if lean is not None:
        cost[lean[0]:] += 0.004 * np.abs(np.arange(b) - lean[1])[None, :]
    lo, hi = int(b * 0.04), int(b * 0.96)
    cost[:, :lo] += 10.0
    cost[:, hi:] += 10.0
    acc = cost.copy()
    for y in range(1, acc.shape[0]):
        acc[y] += ndi.minimum_filter1d(acc[y - 1], 2 * reach + 1, mode="nearest")
    path = np.zeros(acc.shape[0], np.int64)
    path[-1] = int(np.argmin(acc[-1]))
    for y in range(acc.shape[0] - 2, -1, -1):
        x = path[y + 1]
        x0, x1 = max(x - reach, 0), min(x + reach + 1, b)
        path[y] = x0 + int(np.argmin(acc[y, x0:x1]))
    seam.path = path
    for row, column in steer:
        path[row:] = column
    m = (np.arange(b)[None, :] > path[:, None]).astype(np.float32)  # 1: the start's side
    m = ndi.gaussian_filter1d(m, feather, axis=1)
    if steer:  # (where the path steps aside, no hard level edge)
        m[steer[0][0] - 40:] = ndi.gaussian_filter1d(m, feather, axis=0)[steer[0][0] - 40:]
    m = m[..., None]
    zone = end * (1 - m) + start * m
    out = np.concatenate([zone, a[:, b:-b]], axis=1)
    if match:
        near = np.clip(path[:, None] + np.arange(-30, 31)[None, :], 0, b - 1)
        d = np.take_along_axis((end - start)[..., :3], near[..., None], axis=1).mean(axis=1)  # the step, row by row
        d = np.clip(ndi.gaussian_filter1d(d, 20.0, axis=0), -0.12, 0.12)[:, None, :] * 0.5
        out = np.roll(out, match, axis=1)  # (the path's left side is the picture's far end)
        off = (np.arange(out.shape[1])[None, :] - (path[:, None] + match)) / float(match)
        w = np.where(off >= 0, np.clip(1 - off, 0, 1) ** 2, -np.clip(1 + off, 0, 1) ** 2)[..., None]
        out[..., :3] = np.clip(out[..., :3] + d * w * out[..., 3:4], 0.0, 1.0)
        out = np.roll(out, -match, axis=1)
    return out


def top_edge(a: np.ndarray, share=0.5) -> int:
    """The first row that is solid across `share` of the width."""
    return int(np.nonzero((a[..., 3] > 0.5).mean(axis=1) > share)[0].min())


def sky() -> None:
    a = load("sky2")
    # its two ends brought to the same colour, row by row, over a long reach (the painter left one end warmer: a faint
    # column where the picture repeats), then faded across each other
    reach = 800
    d = ndi.gaussian_filter1d(a[:, -40:].mean(axis=1) - a[:, :40].mean(axis=1), 14.0, axis=0)
    ramp = np.linspace(1.0, 0.0, reach, dtype=np.float32)
    ramp = (ramp * ramp * (3 - 2 * ramp))[None, :, None]
    a[:, :reach] += 0.5 * d[:, None, :] * ramp
    a[:, -reach:] -= 0.5 * d[:, None, :] * ramp[:, ::-1]
    out = np.clip(fade(a, 300), 0, 1)
    out = resize(out, (3072, round(out.shape[0] * 3072 / out.shape[1])))  # (soft clouds, far away: 1.7 px a unit)
    out[..., 3] = 1.0
    save(out, OUT / "sky.png", opaque=True)


def wall() -> None:
    a = load("wall")
    top = top_edge(a, 0.02)
    out = fade(a[top - 12:top + 300], 256)
    out = resize(out, (out.shape[1] // 2, out.shape[0] // 2))  # (far and faint: 1 px a unit)
    save(out, OUT / "far_wall.png")


def plain() -> None:
    # (blind round 19: "four near-parallel horizontal ridges with identical ragged brown crests ... stacked wallpaper
    # strips": "replace the stack of parallel ridges behind the lane with one receding ground plane built from
    # overlapping diagonal forms": plain2, the whole grassland behind the path painted as one ground in perspective,
    # from right behind the characters to the horizon: interlocking swells, a game trail winding away to one far
    # point, the far band in the last sun with its groves, its herds and a village, the nearer plain in the evening's
    # shade. `plain`, the one before it, was the far plain alone, seen behind three ridges)
    # (blind round 20: "hard black-inked flat cel sprites, while the plain behind them is a soft, lineless, slightly
    # smeared painting ... dark blurred bush blobs": "draw the ground directly behind the lane in the characters' own
    # language (crisp contours, hard-edged shadow shapes, no soft smudges)": plain3, the same one ground drawn in the
    # approved frame's ink and cel planes: bushes, rocks, termite mounds, small acacias, herds, a cattle kraal, its trail,
    # all shrinking to the far sunlit band)
    a = load("plain3")[:, PLAIN_ENDS:-PLAIN_ENDS]
    # (two of the painter's slips near its right end, a rock and a red smudge half painted over the grass: the open
    # grass beside each laid over it)
    for rows, cols, dx in PLAIN_SLIPS:
        mask = np.zeros(a.shape[:2], np.float32)
        mask[rows[0]:rows[1], cols[0] - PLAIN_ENDS:cols[1] - PLAIN_ENDS] = 1.0
        mask = ndi.gaussian_filter(mask, 9.0)[..., None]
        a = a * (1 - mask) + np.roll(a, dx, axis=1) * mask
    first = top_edge(a, 0.004)  # (the acacias' crowns)
    line = top_edge(a, 0.97)  # the horizon
    # (low down the join keeps to the right: the right end's bushes whole, the left end's aloe, which they would cut, out)
    out = seam(a[first - 8:line + PLAIN_ROWS], PLAIN_JOIN, feather=2.5, reach=3, lean=(line - first + 8 + 320, PLAIN_JOIN - 34), match=300)
    save(out, OUT / "far_hills.png")
    print("  horizon at row %d of it" % (line - first + 8))


def river() -> None:
    # (blind round 19, under the vine: "the river is the cheapest element: reflections as regular white horizontal
    # dashes and banded blocks, which read as a procedural shader rather than paint": river2, the river painted: its
    # far bank of reeds, papyrus and sand, the dusk mirrored soft and broken, sandbars and lily pads lying across it)
    # (blind round 20: "a soft pink-lilac gradient with blurred reflections and no drawn form ... the part nearest the
    # camera is the blurriest": river3, drawn as cel water: crisp mirrored shapes cut into slivers, ripple rings,
    # sandbars, wet rocks, lily pads, egrets on its far bank)
    a = load("river3")[:, PLAIN_ENDS:-PLAIN_ENDS]
    first = top_edge(a, 0.004)  # (the papyrus heads)
    water = top_edge(a, 0.995)  # the first row that is water from side to side
    out = seam(a[first - 8:water + RIVER_ROWS], RIVER_JOIN, feather=2.5, reach=3)
    save(out, OUT / "river.png")
    print("  water from row %d of it" % (water - first + 8))


def grass() -> None:
    a = load("grass")
    first = top_edge(a, 0.004)
    line = top_edge(a, 0.97)
    out = seam(a[first - 8:line + 130], 256)  # (solid from y 584: 130 px reach under the screen's bottom edge)
    save(out, OUT / "near_grass.png")
    print("  solid from row %d of it" % (line - first + 8))


def pieces(name: str, cols: int, rows: int) -> list:
    """The figures of a sheet, each whole, in the grid's order (a twig or a cap stone apart from its figure goes with
    the cell its middle is in)."""
    a = load(name)
    h, w = a.shape[:2]
    lab, n = ndi.label(a[..., 3] > 0.3)
    owner = {}
    for i, sl in enumerate(ndi.find_objects(lab), 1):
        piece = lab[sl] == i
        if int(piece.sum()) < 400:
            continue
        cy, cx = ndi.center_of_mass(piece)
        owner[i] = int((cy + sl[0].start) / (h / rows)) * cols + int((cx + sl[1].start) / (w / cols))
    out = []
    for c in range(cols * rows):
        mine = np.isin(lab, [i for i, o in owner.items() if o == c])
        ys, xs = np.nonzero(mine)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        soft = ndi.binary_dilation(mine, iterations=3)[y0:y1, x0:x1]  # (its antialiased edge with it)
        cut = a[y0:y1, x0:x1].copy() * soft[..., None]
        out.append(cut)
    return out


def flat_foot(p: np.ndarray) -> np.ndarray:
    """Its last rows are its foot, cut straight: nothing thinner than half of the foot's width is left under it."""
    full = (p[..., 3] > 0.5).sum(axis=1)
    wide = np.nonzero(full >= 0.5 * full[-40:].max())[0].max()
    return p[:wide + 1]


def mesas() -> None:
    ps = [flat_foot(p) for p in pieces("mesas", 4, 3)]
    ps = [resize(p, (p.shape[1] // 2, p.shape[0] // 2)) for p in ps]
    cell = max(p.shape[0] for p in ps) + 6
    width = 2048
    spots, x, y = [], 0, 0
    for p in ps:
        if x + p.shape[1] > width:
            x, y = 0, y + cell
        spots.append((x, y))
        x += p.shape[1] + 6
    atlas = np.zeros((y + cell, width, 4), np.float32)
    info = []
    for p, (x, y), kind in zip(ps, spots, MESA_KINDS):
        atlas[y + cell - p.shape[0]:y + cell, x:x + p.shape[1]] = p  # (standing on its cell's foot)
        info.append([x, y, p.shape[1], kind])
    save(atlas, OUT / "far_mesa_pieces.png")
    (OUT / "far_mesa_pieces.json").write_text(json.dumps({"pieces": info, "height": cell, "pitch": cell}))
    print("  cells %d px tall; widths %s" % (cell, [p.shape[1] for p in ps]))


def trees() -> None:
    info = {}
    for name, p in zip(TREES, pieces("trees", 5, 2)):
        p = flat_foot(p)
        k = TREE_SCALE.get(name, 0.45)
        p = resize(p, (round(p.shape[1] * k), round(p.shape[0] * k)))
        foot = np.nonzero(p[-6:, :, 3].max(axis=0) > 0.5)[0]
        save(p, OUT / (name + ".png"))
        info[name] = {"size": [p.shape[1], p.shape[0]], "anchor_x": float(foot.min() + foot.max()) / 2}
    (OUT / "tree_info.json").write_text(json.dumps(info, indent=1))


def front() -> None:
    ps = pieces("front", 3, 2)
    cw, ch = FRONT_CELL
    atlas = np.zeros((ch * 2, cw * 3, 4), np.float32)
    for i, p in enumerate(ps):
        k = min((cw - 8) / p.shape[1], (ch - 4) / p.shape[0])
        p = resize(p, (round(p.shape[1] * k), round(p.shape[0] * k)))
        x = (i % 3) * cw + (cw - p.shape[1]) // 2
        y = (i // 3) * ch + ch - p.shape[0]
        atlas[y:y + p.shape[0], x:x + p.shape[1]] = p
    save(atlas, OUT / "fg_props.png")


def earth() -> None:
    """The main ground's bank (terrain.gdshader earth_tex): the top of the painted cut, repeating left to right."""
    a = load("earth")
    out = seam(a[:480], 256, 3.0)
    out = resize(out, (out.shape[1] // 2, out.shape[0] // 2))
    out[..., 3] = 1.0
    save(out, OUT / "earth.png", opaque=True)


def fire() -> None:
    """The cooking fire at home: the hearth (home_fire.png: the ring of stones, the logs and their embers) and its flames
    (home_flames.png: four frames, drawn behind the logs, HomeView.Fire).
    The hearth is fire2's (blind round 12: "a thick-outlined emoji flame": fire.png; fire2 is painted as the hut is), its
    own flame cut off along the tops of its logs. The flames are fire3's (blind round 17: "a flat cartoon flame (three
    hard tones, yellow tongue)": painted alone on black, soft, a white-hot heart, embers): black keyed out by their
    light, so their dark red edges are see-through over the dusk instead of a brown rim."""
    p = pieces("fire2", 4, 1)[0]
    k = 300.0 / p.shape[1]
    p = resize(p, (round(p.shape[1] * k), round(p.shape[0] * k)))
    cw, ch = p.shape[1] + 8, p.shape[0] + 4
    hearth = np.zeros((ch, cw, 4), np.float32)
    foot = np.nonzero(p[-max(p.shape[0] // 4, 1):, :, 3].max(axis=0) > 0.5)[0]  # the ring of stones: its middle
    x = min(max(cw // 2 - int(foot.min() + foot.max()) // 2, 0), cw - p.shape[1])
    hearth[ch - p.shape[0]:, x:x + p.shape[1]] = p
    # the tops of the two leaning logs: a tent from their tips (HEARTH_TIP of the picture's height up) down to the
    # stones; all above it was the old flame
    xs = np.abs(np.arange(cw, dtype=np.float32) - cw / 2.0)
    line = np.minimum(ch * HEARTH_TIP + np.maximum(xs - 5.0, 0.0) * HEARTH_SLOPE, ch * HEARTH_STONES)
    ys = np.arange(ch, dtype=np.float32)[:, None]
    hearth *= np.clip((ys - (line[None, :] - 6.0)) / 8.0, 0.0, 1.0)[..., None]
    save(hearth, OUT / "home_fire.png")
    a = np.asarray(Image.open(GEN / "fire3.png").convert("RGB")).astype(np.float32) / 255.0
    w = a.shape[1] // 4
    fh = round(a.shape[0] * FLAME_K)
    sheet = np.zeros((FLAME_CELL[1], FLAME_CELL[0] * 4, 4), np.float32)
    for i in range(4):
        c = a[:, i * w:(i + 1) * w]
        light = c.max(axis=-1)
        al = np.clip((light - 0.1) / 0.65, 0.0, 1.0)
        al = al * al * (3 - 2 * al)
        rgb = np.clip(c / np.maximum(al[..., None], 0.08), 0.0, 1.0)
        f = resize(np.dstack([rgb * al[..., None], al]), (round(w * FLAME_K), fh))
        body = np.nonzero(f[..., 3] > 0.6)
        base = int(body[0].max())  # the flame's foot, set FLAME_FOOT px over the cell's bottom (behind the logs)
        low = body[1][body[0] > base - 0.12 * fh]
        mid = int((low.min() + low.max()) // 2)
        x0, y0 = i * FLAME_CELL[0] + FLAME_CELL[0] // 2 - mid, FLAME_CELL[1] - FLAME_FOOT - base
        for yy in range(f.shape[0]):
            ty = y0 + yy
            if 0 <= ty < FLAME_CELL[1]:
                sx0, sx1 = max(i * FLAME_CELL[0] - x0, 0), min((i + 1) * FLAME_CELL[0] - x0, f.shape[1])
                sheet[ty, x0 + sx0:x0 + sx1] = f[yy, sx0:sx1]
    save(sheet, OUT / "home_flames.png")


def sign() -> None:
    """The HOME signpost (sign2: a weathered plank arrow lashed to a post, its word cut and burnt in the logo's angular
    capitals, two bands of beadwork, a cowhide shield charm; blind round 12: "chunky casual-game letters"): cut to
    its figure, 420 px tall (HomeView draws it about 140 units tall)."""
    a = load("sign2")
    ys, xs = np.nonzero(a[..., 3] > 0.05)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    k = 420.0 / a.shape[0]
    save(resize(a, (round(a.shape[1] * k), 420)), OUT / "home_sign.png")


def door() -> None:
    """The main hut's doorway (home_hut.png, in place): its inside, a glow from black down to bright orange, was his
    skin's hue and value behind his legs and chest (blind rounds 5, 6, 11 and 12: "his warm torso sits on a warm
    orange doorway"); now the hut's inside in the dusk's violet, a middle value behind his head (blind round 19: "his
    black hair and back shoulder sit on the dark doorway") and deeper low down: well over his black hair's value, well
    under his skin's, and not his hue. Found as the smooth region round the doorway's middle (home.json)."""
    path = OUT / "home_hut.png"
    info = json.loads((OUT / "home.json").read_text())["home_hut"]
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    h, w = img.shape[:2]
    grey = img[..., :3].mean(axis=2)
    gy, gx = np.gradient(ndi.gaussian_filter(grey, 1.0))
    smooth = (np.hypot(gx, gy) < 0.012) & (img[..., 3] > 0.9)
    lab, _ = ndi.label(smooth)
    cx = int(info["door_x"] * 2)
    cy = h - int(info["base"] * 2) - int(info["door_h"])  # the doorway's middle (px)
    inside = ndi.binary_fill_holes(ndi.binary_dilation(lab == lab[cy, cx], iterations=3))
    soft = ndi.gaussian_filter(inside.astype(np.float32), 1.2)[..., None]
    ys = np.nonzero(inside.any(axis=1))[0]
    t = np.clip((np.arange(h) - ys.min()) / max(ys.max() - ys.min(), 1), 0, 1)[:, None, None]
    tone = np.array([0.42, 0.33, 0.56]) * (1 - t) ** 1.5 + np.array([0.26, 0.18, 0.33]) * (1 - (1 - t) ** 1.5)
    img[..., :3] = img[..., :3] * (1 - soft) + tone * soft
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("home_hut.png: doorway %d px repainted, rows %d to %d" % (int(inside.sum()), ys.min(), ys.max()))


IMPACT_NOSE = 44  # px from the crescent's nose to the point of contact


def impact() -> None:
    """A blow's burst (fx_impact.png: Fx.hit_spark): three painted frames in a row (the contact, the burst, the
    break-up; the blow goes right), each in a cell of the same size with the point of contact, the middle of its
    white-hot heart, at the same place (printed: Fx.IMPACT_CELL, IMPACT_AT), at half the painting's size."""
    # blind round 21 ("a flat white eight-point star with orange wedges, clip-art comic style, and it hides the ring
    # and the contact point": "a painted directional impact (slash arc, dust and debris in the scene's palette)"):
    # impact2: a white-hot crescent whose nose is the contact, opening the blow's way, sparks and chips flying on,
    # a puff of the path's dust in the dusk's cream and lilac. The contact: a little inside its nose.
    a = load("impact2")
    w3 = a.shape[1] // 3
    frames = []
    for i in range(3):
        f = a[:, i * w3:(i + 1) * w3]
        al = f[..., 3]
        rgb = f[..., :3] / np.maximum(al[..., None], 1e-4)
        lab, n = ndi.label((al > 0.9) & (rgb.min(axis=2) > 0.93))
        heart = 1 + int(np.argmax(ndi.sum(np.ones_like(al), lab, np.arange(1, n + 1))))
        cy = ndi.center_of_mass(lab == heart)[0]
        band = al[int(cy) - 12:int(cy) + 12].max(axis=0)
        cx = int(np.nonzero(band > 0.5)[0].min()) + IMPACT_NOSE
        ys, xs = np.nonzero(al > 0.03)
        frames.append((f, int(round(cx)), int(round(cy)), xs.min(), xs.max() + 1, ys.min(), ys.max() + 1))
    left = max(cx - x0 for _, cx, cy, x0, x1, y0, y1 in frames) + 4
    right = max(x1 - cx for _, cx, cy, x0, x1, y0, y1 in frames) + 4
    up = max(cy - y0 for _, cx, cy, x0, x1, y0, y1 in frames) + 4
    down = max(y1 - cy for _, cx, cy, x0, x1, y0, y1 in frames) + 4
    left, right, up, down = [v + v % 2 for v in (left, right, up, down)]
    cw, ch = left + right, up + down
    sheet = np.zeros((ch, cw * 3, 4), np.float32)
    for i, (f, cx, cy, x0, x1, y0, y1) in enumerate(frames):
        sheet[up - (cy - y0):up + (y1 - cy), i * cw + left - (cx - x0):i * cw + left + (x1 - cx)] = f[y0:y1, x0:x1]
    sheet = resize(sheet, (cw * 3 // 2, ch // 2))
    save(sheet, OUT / "fx_impact.png")
    print("fx_impact.png: %dx%d, cell %dx%d, the contact at (%d, %d)" % (sheet.shape[1], sheet.shape[0], cw // 2, ch // 2, left // 2, up // 2))


def clouds() -> None:
    """The sky's cumulus alone (sky_clouds.png), lifted off the finished sky.png: SavannaView draws them a second time,
    bigger and higher, where the camera draws back to the vine (blind round 12: "an empty sky band" over the pillars).
    Each row's clear sky is its bluest tenth (a cloud is warmer and lighter than the sky at its height); what stands
    off it is cloud, its colour taken back out of the mix."""
    img = np.asarray(Image.open(OUT / "sky.png").convert("RGB")).astype(np.float32) / 255.0
    clear = np.stack([np.percentile(img[..., 0], 10, axis=1), np.percentile(img[..., 1], 10, axis=1),
                      np.median(img[..., 2], axis=1)], axis=1)
    clear = ndi.gaussian_filter1d(clear, 8.0, axis=0)[:, None, :]
    off = (img - clear)[..., :2].max(axis=2)
    al = np.clip((off - 0.035) / 0.075, 0, 1)
    al = al * al * (3 - 2 * al)
    rows = np.nonzero((al > 0.5).mean(axis=1) > 0.004)[0]
    band = rows[rows < int(img.shape[0] * 0.74)]  # the cumulus (the thin warm streaks over the horizon stay in the sky)
    top, bottom = band.min() - 8, band.max() + 8
    # a cloud: a body with a sunlit top, standing in the cumulus band; the sky's own blotches are none (one hangs off a
    # cloud's side by a thin wedge: the bodies are told apart worn down, then grown back)
    al = al[top:bottom]
    lit = (off[top:bottom] > 0.22) & (img[top:bottom, :, 0] > 0.8)
    lab, n = ndi.label(ndi.binary_erosion(al > 0.5, iterations=7))
    keep = np.zeros(al.shape, bool)
    for i, box in enumerate(ndi.find_objects(lab)):
        body = lab[box] == i + 1
        if box[0].start < 0.6 * al.shape[0] and (lit[box] & body).sum() > 200:
            keep[box] |= body
    al *= ndi.gaussian_filter(ndi.binary_dilation(keep, iterations=11).astype(np.float32), 1.5)
    al = al[..., None]
    rgb = np.clip((img[top:bottom] - clear[top:bottom] * (1 - al)) / np.maximum(al, 0.05), 0, 1)
    save(np.dstack([rgb * al, al[..., 0]]), OUT / "sky_clouds.png")
    print("sky_clouds.png: rows %d to %d of sky.png" % (top, bottom))


def spires() -> None:
    """The stacks of rock standing in the river (spires.png: TerrainView.SPIRES): three painted pinnacles, each in a
    cell of the same size, its small cap rock's middle at the cell's middle and its top at the cell's top (printed: the
    cell, how wide each cap is in px: TerrainView.SPIRE_CELL, SPIRE_CAPS). Blind rounds 12 and 13: "near-copy pillars",
    "plain smooth-gradient posts, far cheaper than the plain behind them", "the play plane barely exists: nothing
    between the rope and the water" (they were slim columns drawn by spire.gdshader)."""
    a = load("pinnacles")
    al = a[..., 3]
    cols = (al > 0.16).sum(axis=0) > 8
    edges = np.flatnonzero(np.diff(np.concatenate([[0], cols.astype(np.int8), [0]])))
    cut = []
    for x0, x1 in zip(edges[::2], edges[1::2]):
        ys = np.flatnonzero((al[:, x0:x1] > 0.16).sum(axis=1) > 4)
        y0, y1 = ys.min(), ys.max() + 1
        xs = np.flatnonzero((al[y0 + 4:y0 + 22, x0:x1] > 0.5).any(axis=0))  # (its cap rock)
        cut.append((x0, x1, y0, y1, x0 + (xs.min() + xs.max() + 1) / 2.0, xs.max() + 1 - xs.min()))
    half = int(max(max(cx - x0, x1 - cx) for x0, x1, y0, y1, cx, cap in cut)) + 6
    high = max(y1 - y0 for x0, x1, y0, y1, cx, cap in cut) + 2
    sheet = np.zeros((high, half * 2 * len(cut), 4), np.float32)
    for i, (x0, x1, y0, y1, cx, cap) in enumerate(cut):
        at = i * half * 2 + half - int(round(cx - x0))
        sheet[0:y1 - y0, at:at + x1 - x0] = a[y0:y1, x0:x1]
    save(sheet, OUT / "spires.png")
    print("spires.png: %d cells of %dx%d, caps %s px wide, feet %s px wide" % (len(cut), half * 2, high,
            [int(c[5]) for c in cut], [int(c[1] - c[0]) for c in cut]))


def canopy() -> None:
    """The canopy over the level (canopy.png: CanopyView): the great boughs the liana hangs from, hanging down from the
    picture's top edge. Blind round 15: "a thin wavy vine that hangs from nothing", "the top half a flat saturated
    blue gradient". Kept whole and at half its size (CanopyView lays it mirrored every other time, each end meeting
    itself: no seam to mend)."""
    a = load("canopy")
    h = a.shape[0]
    # its long hanging strands end a little under the rope (0.63 of its height: 86 units down, CanopyView): longer,
    # their tips hung into the top of the picture from nowhere while he runs on the ground (the boughs are over the
    # screen's top then)
    v = np.arange(h, dtype=np.float32)[:, None, None] / h
    a *= 1.0 - np.clip((v - 0.55) / 0.08, 0.0, 1.0) ** 1.5
    a = resize(a, (a.shape[1] // 2, h // 2))
    save(a, OUT / "canopy.png")
    al = a[..., 3]
    print("canopy.png: %dx%d, solid to row %d, leaves to row %d" % (a.shape[1], a.shape[0],
            int(np.flatnonzero((al > 0.5).mean(axis=1) > 0.97).max()), int(np.flatnonzero((al > 0.5).mean(axis=1) > 0.3).max())))


if __name__ == "__main__":
    todo = sys.argv[1:] or ["sky", "wall", "mesas", "plain", "river", "grass", "trees", "front", "fire", "earth"]
    for name in todo:
        globals()[name]()
