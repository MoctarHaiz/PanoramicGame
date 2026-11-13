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
    tree_*.png           ten trees (+ tree_info.json: the foot of each trunk)
    fg_props.png         six plants and rocks near the camera
    home_fire.png        the cooking fire's hearth at home; home_flames.png its flames, four frames (HomeView.Fire)
    home_sign.png        the HOME signpost (sign); home_hut.png's doorway repainted dark, in place (door)
    fx_impact.png        a blow's burst, three frames (impact: Fx.hit_spark)
    sky_clouds.png       the sky's cumulus alone, off the finished sky.png (clouds): drawn again higher up
    spires.png           three rock pinnacles, each in a cell (spires: TerrainView's stacks in the river)
    earth.png            the cut bank of the main ground under the turf (terrain.gdshader), repeating
    lane.png             the ground they run on, seen a little from above: its far fringe, its top, its near edge and the
                         top of its cut bank (lane: TerrainView._lane), repeating
    canopy.png           the boughs the liana hangs from, along the top of the level (canopy: CanopyView)

    python3 tools/art/kie/world.py [sky wall mesas plain river grass trees front fire earth | sign door clouds impact spires canopy lane]
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
PLAIN_BREAK = (23, (20.0, 58.0), 0.46, 118)  # (seed, px a cloud shadow is across (down, along), the share of the shafts they take, the first row they may: under the far band)
PLAIN_INK = ((0.13, 0.17, 0.25), 0.75)  # the plain's ink line: this deep blue-green and no darker, by this much (the fighters' line alone is black)
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
    # (blind round 22, of the shader's shade over plain3: "a grey-olive veil ... a desaturating overlay, not painted
    # shade, and meets the sunlit yellow band on a ruled horizontal line": "real shade with a clear hue from the dusk
    # sky, crisp drawn forms at readable contrast, and broken cast-shadow edges into the sun band": plain4, plain3
    # repainted at dusk, every drawn thing where it was: the near plain in blue-green and slate shade with lavender
    # lights, its rocks mauve, its trail lilac; the far band alone in the last gold, the acacias' long slanted shadows
    # breaking the shade's edge)
    # (blind round 23, of the fight: "a herd on the left drawn as pale pink unfilled outlines (reads as an unfinished
    # sketch) and a pen of scratchy pale lines on the right exactly behind the enemy's flung arm", "the sunlit yellow
    # band above their heads is the brightest, most saturated shape": "calm the plain behind the fighters to a dark,
    # low-detail mass (move the herd and pen out of the band behind their bodies), take the far band down a step":
    # plain5, plain4 repainted without its kraal and its herd, the shade's lavender swells fewer and broader, the far
    # band a deep amber, its tongues of light fewer and shorter. Round 23 had drawn the kraal quieter (PLAIN_QUIET:
    # paler, and worse) and laid grass over two slips of plain4's painter (PLAIN_SLIPS): neither is in plain5)
    # (round 24's checks, of plain5 behind the fight and the throw: "a large flat, empty area (about 30% of the frame)
    # with only a trail and a few firefly dots", "a flat teal-green bowl ... empty and soft"; the throw lost to round
    # 23's: plain6, plain4 repainted without its kraal and its herd but with all the shade's drawn grass, its lit crests
    # and its hollows; a termite mound and a bush where the kraal stood; the far band the deep amber, about half of
    # its tongues of light, the nearest ground a value down)
    a = load("plain6")[:, PLAIN_ENDS:-PLAIN_ENDS]
    first = top_edge(a, 0.004)  # (the acacias' crowns)
    line = top_edge(a, 0.97)  # the horizon
    # (low down the join keeps to the right: the right end's bushes whole, the left end's aloe, which they would cut, out)
    out = seam(a[first - 8:line + PLAIN_ROWS], PLAIN_JOIN, feather=2.5, reach=3, lean=(line - first + 8 + 320, PLAIN_JOIN - 34), match=300)
    # (round 23's check, of the throw: "evenly spaced parallel yellow bands … look ruled", "vary their widths, angles and
    # spacing … break them with tree shadows": cloud shadows lie across the sun's shafts on the shaded ground, hard-edged
    # cel shapes in the ground's own shade beside them (PLAIN_BREAK); the far band keeps all its gold)
    rgb = out[..., :3]
    warm = rgb[..., 0] - rgb[..., 2]  # (the shafts' gold; the shade, the rocks and the trail are cool)
    # (a shaft with its pale rim: whatever is warm within a few px of its gold; the rim alone was left as a thin line)
    lit = ndi.maximum_filter((warm > 0.3).astype(np.float32), size=11, mode=("nearest", "wrap")) * np.clip((warm - 0.02) / 0.05, 0.0, 1.0)
    shade = (warm < 0.04).astype(np.float32)
    share = ndi.gaussian_filter(shade, (16.0, 44.0), mode=("nearest", "wrap"))
    near = ndi.gaussian_filter(rgb * shade[..., None], (16.0, 44.0, 0.0), mode=("nearest", "wrap", "nearest")) / np.maximum(share, 1e-3)[..., None]
    field = ndi.gaussian_filter(np.random.default_rng(PLAIN_BREAK[0]).random(out.shape[:2]).astype(np.float32), PLAIN_BREAK[1], mode=("nearest", "wrap"))
    cut = ndi.gaussian_filter((field > np.quantile(field, 1.0 - PLAIN_BREAK[2])).astype(np.float32), 1.3, mode=("nearest", "wrap"))
    cut *= np.clip((np.arange(out.shape[0], dtype=np.float32)[:, None] - PLAIN_BREAK[3]) / 16.0, 0.0, 1.0)
    cut = (cut * lit)[..., None]
    out[..., :3] = rgb * (1 - cut) + near * cut
    # (the same check: the bandit against the fence, the rocks and the smoke "at the same value": the plain's line is a
    # deep blue-green, not the fighters' black: PLAIN_INK)
    dark = np.clip((0.24 - out[..., :3] @ np.array([0.3, 0.59, 0.11])) / 0.16, 0.0, 1.0)[..., None] * PLAIN_INK[1]
    out[..., :3] = out[..., :3] * (1 - dark) + np.maximum(out[..., :3], np.array(PLAIN_INK[0])) * dark
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


DOOR_LAMP = 0.62  # of the doorway's height: how far down the lamp's light inside reaches (to his shoulders)
DOOR_LAMP_AT = (0.78, 0.2)  # of the doorway's width and height: where the lamp hangs (right of his head, clear of his raised fist)
# The planes of its light on the back wall: [reach (of the doorway's height from the lamp), colour], the last the rest.
DOOR_TONES = [(0.33, (0.97, 0.87, 0.62)), (0.64, (0.74, 0.61, 0.48)), (0.93, (0.5, 0.39, 0.38)), (9.0, (0.34, 0.25, 0.32))]  # (straw, then dusty browns: lighter and yellower than his skin behind his head, darker and greyer than it lower down)
DOOR_JAMB = (13.0, 0.56)  # px of the wall's thickness seen inside the doorway's edge, and its tone (of the light behind it: it is in shade)
DOOR_FLOOR = (0.8, 7.0)  # of the doorway's height: where the back wall meets the floor, and the px that line bows down at its middle (a round hut)
DOOR_POTS = [(0.4, 0.94, 0.09, 0.075), (0.6, 0.89, 0.052, 0.045)]  # clay pots on the floor: [of the doorway's width, its foot (of its height), its half width (of the width), its half height (of the height)]
DOOR_LINE = (0.2, 0.1, 0.16)  # its ink line


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
    kept = GEN / "door_mask.png"  # (the doorway's shape, kept: once its inside is drawn it is no smooth region)
    if kept.exists():
        inside = np.asarray(Image.open(kept).convert("L")) > 127
    else:
        grey = img[..., :3].mean(axis=2)
        gy, gx = np.gradient(ndi.gaussian_filter(grey, 1.0))
        smooth = (np.hypot(gx, gy) < 0.012) & (img[..., 3] > 0.9)
        lab, _ = ndi.label(smooth)
        cx = int(info["door_x"] * 2)
        cy = h - int(info["base"] * 2) - int(info["door_h"])  # the doorway's middle (px)
        inside = ndi.binary_fill_holes(ndi.binary_dilation(lab == lab[cy, cx], iterations=3))
        Image.fromarray((inside * 255).astype(np.uint8), "L").save(kept)
    soft = ndi.gaussian_filter(inside.astype(np.float32), 1.2)[..., None]
    ys = np.nonzero(inside.any(axis=1))[0]
    xs = np.nonzero(inside.any(axis=0))[0]
    t = np.clip((np.arange(h) - ys.min()) / max(ys.max() - ys.min(), 1), 0, 1)[:, None, None]
    # (blind round 22, again: "his black hair sits on the dark doorway": a lamp's light high inside, a dusty rose-lilac
    # behind his head, falling fast to the dusk's deep violet behind his chest and legs; it was (0.42, 0.33, 0.56) by 1.5)
    # (blind round 23: "a flat lilac-pink blob with a soft gradient: a foggy portal, not lamplight ... it has no interior shapes": the hut's inside is drawn, in the
    # fighters' line: its back wall in flat planes of a hanging lamp's light (DOOR_TONES: amber round the lamp, behind his
    # head, down to the dusk's violet-brown behind his chest and legs), the wall's laths bowed across it, three roof
    # poles, the lamp on its cord)
    dh, dw = ys.max() - ys.min(), xs.max() - xs.min()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    lamp_at = (xs.min() + DOOR_LAMP_AT[0] * dw, ys.min() + DOOR_LAMP_AT[1] * dh)
    ang = np.arctan2(yy - lamp_at[1], xx - lamp_at[0])
    r = np.hypot(xx - lamp_at[0], (yy - lamp_at[1]) * 0.82) / dh + 0.005 * np.sin(ang * 9.0) + 0.003 * np.sin(ang * 17.0 + 1.0)
    tone = np.empty((h, w, 3), np.float32)
    tone[:] = DOOR_TONES[-1][1]
    for reach, colour in reversed(DOOR_TONES[:-1]):
        k = np.clip((reach - r) * dh / 1.5, 0.0, 1.0)[..., None]
        tone = tone * (1 - k) + np.array(colour, np.float32) * k
    # (round 24's check, of that drawing: "a flat dark brown-maroon slab ... the lamp-lit interior is missing": its laths
    # and poles read as a door of planks, shut. Now a room seen into: the lamp's light broad on the back wall, the
    # wall's thickness in shade inside the doorway's edge (DOOR_JAMB), a floor the back wall meets on a bowed line
    # (DOOR_FLOOR), the lamp's light pooled on it, two clay pots standing on it (DOOR_POTS))
    u = (xx - (xs.min() + dw / 2.0)) / (dw / 2.0)
    line = np.array(DOOR_LINE, np.float32)
    join = ys.min() + DOOR_FLOOR[0] * dh + DOOR_FLOOR[1] * (1.0 - u * u)
    floor = np.clip(yy - join, 0.0, 1.0)[..., None]
    pool = np.clip((1.0 - np.hypot((xx - lamp_at[0] + 0.2 * dw) / (0.36 * dw), (yy - join - 0.1 * dh) / (0.07 * dh))) * 9.0, 0.0, 1.0)[..., None]
    mat = np.array([0.42, 0.31, 0.33], np.float32) * (1 - pool) + np.array([0.68, 0.55, 0.43], np.float32) * pool
    tone = tone * (1 - floor) + mat * floor
    tone = tone * (1 - np.clip(1.5 - np.abs(yy - join), 0.0, 1.0)[..., None]) + line * np.clip(1.5 - np.abs(yy - join), 0.0, 1.0)[..., None]
    for at, foot, wide, tall in DOOR_POTS:
        cx, cy = xs.min() + at * dw, ys.min() + (foot - tall) * dh
        body = np.hypot((xx - cx) / (wide * dw), (yy - cy) / (tall * dh))
        neck = np.maximum(np.abs(xx - cx) / (wide * dw * 0.5), np.abs(yy - (cy - tall * dh * 1.08)) / (tall * dh * 0.3))
        d = np.minimum(body, neck)  # under 1: the pot
        cast = np.clip((1.0 - np.hypot((xx - cx + wide * dw * 0.5) / (wide * dw * 1.3), (yy - cy - tall * dh) / (tall * dh * 0.22))) * 7.0, 0.0, 1.0)[..., None]
        tone = tone * (1 - cast * 0.38)
        clay = np.where(((yy - cy) / (tall * dh) - (xx - cx) / (wide * dw) * 0.5 < -0.28)[..., None], np.array([0.84, 0.52, 0.33], np.float32), np.array([0.47, 0.25, 0.24], np.float32))
        band = (np.abs((yy - cy) / (tall * dh) + 0.34) < 0.09)[..., None]  # a painted band round its shoulder
        clay = np.where(band, clay * np.array([0.62, 0.5, 0.6], np.float32), clay)
        k = np.clip((1.0 - d) * wide * dw / 1.2, 0.0, 1.0)[..., None]
        edge = np.clip((1.0 - np.abs(1.0 - d) * wide * dw / 2.6), 0.0, 1.0)[..., None]
        tone = tone * (1 - k) + clay * k
        tone = tone * (1 - edge) + line * edge
    depth = ndi.distance_transform_edt(inside).astype(np.float32)
    jamb = np.clip(DOOR_JAMB[0] - depth + 0.5, 0.0, 1.0)[..., None]
    tone = tone * (1.0 - jamb * (1.0 - DOOR_JAMB[1]))
    edge = np.clip(1.4 - np.abs(depth - DOOR_JAMB[0]), 0.0, 1.0)[..., None]
    tone = tone * (1 - edge) + line * edge
    cord = np.clip(1.2 - np.abs(xx - lamp_at[0]), 0.0, 1.0) * (yy < lamp_at[1] - 4.0)
    tone = tone * (1.0 - cord[..., None] * 0.6)
    bowl = np.clip((1.0 - np.hypot((xx - lamp_at[0]) / 15.0, (yy - lamp_at[1] - 7.0) / 8.0)) * 6.0, 0.0, 1.0)[..., None]
    tone = tone * (1 - bowl) + np.array([0.6, 0.42, 0.33], np.float32) * bowl  # (round 24's check: "a dark brown blob (an oval or pot) beside his head": a clay bowl in the lamp's own light)
    flame = np.clip((1.0 - np.hypot((xx - lamp_at[0]) / 7.0, (yy - lamp_at[1] + 9.0) / 12.0)) * 5.0, 0.0, 1.0)[..., None]
    tone = tone * (1 - flame) + np.array([1.0, 0.95, 0.72], np.float32) * flame
    img[..., :3] = img[..., :3] * (1 - soft) + tone * soft
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("home_hut.png: doorway %d px repainted, rows %d to %d" % (int(inside.sum()), ys.min(), ys.max()))
    # (round 23's check, a third time: "his black hair sits on the dark doorway": the hut is drawn in the dusk's shade,
    # which keeps any painted light under a middle value: the lamp's light is its own picture, the doorway's shape from
    # its top down to his shoulders (DOOR_LAMP of its height), which HomeView adds over the hut: home_door_light.png,
    # its place in the hut's picture in home.json (light_x, light_base: units from the hut's left and from its foot))
    light = soft[..., 0] * np.clip(1.0 - t[..., 0] / DOOR_LAMP, 0.0, 1.0) ** 1.25
    rows = np.nonzero(light.max(axis=1) > 0.004)[0]
    cols = np.nonzero(light.max(axis=0) > 0.004)[0]
    box = (cols.min(), rows.min(), cols.max() + 1, rows.max() + 1)
    lamp = np.ones((box[3] - box[1], box[2] - box[0], 4), np.float32)
    lamp[..., 3] = light[box[1]:box[3], box[0]:box[2]]
    Image.fromarray((lamp * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "home_door_light.png")
    whole = json.loads((OUT / "home.json").read_text())
    whole["home_hut"]["light_x"] = box[0] / 2.0
    whole["home_hut"]["light_base"] = (h - box[3]) / 2.0
    (OUT / "home.json").write_text(json.dumps(whole, indent=1))
    print("home_door_light.png: %d x %d px at %d, %d of the hut" % (lamp.shape[1], lamp.shape[0], box[0], box[1]))


IMPACT_NOSE = 44  # px from the crescent's nose to the point of contact


IMPACT_TONES = [(0.0, (0.84, 0.3, 0.1)), (0.5, (0.99, 0.58, 0.15)), (0.72, (1.0, 0.84, 0.36)), (0.9, (1.0, 0.97, 0.88))]
IMPACT_INK = (0.33, 0.1, 0.07)
IMPACT_LINE = 5  # px of the painting (half that in the game's picture)


def cel(f: np.ndarray) -> np.ndarray:
    """A painted effect in the sprites' language (blind round 21, of the blow's burst: "a smooth airbrushed
    white-yellow-orange gradient, a vector effect in another language from the inked sprites"): its fire in four flat
    tones with hard edges between them (IMPACT_TONES: from this value up, this colour), its silhouette hard, an ink
    line round it (IMPACT_INK, a warm dark under a character's black: IMPACT_LINE px). Its chips and its dust keep
    their paint. `f`: premultiplied RGBA; the same back."""
    al = f[..., 3]
    rgb = f[..., :3] / np.maximum(al[..., None], 1e-4)
    shape = ndi.gaussian_filter(al, 1.0) > 0.42
    lum = ndi.gaussian_filter((rgb * np.array([0.3, 0.59, 0.11], np.float32)).sum(axis=2) * shape, 1.4) \
        / np.maximum(ndi.gaussian_filter(shape.astype(np.float32), 1.4), 1e-3)
    # its dust (pale, little colour, not white-hot) keeps its paint: where most of what is drawn round a place is dust
    pale = shape & (rgb.max(axis=2) - rgb.min(axis=2) < 0.42) & (rgb.min(axis=2) < 0.8) & (lum > 0.3)
    dust = ndi.gaussian_filter(pale.astype(np.float32), 9.0) / np.maximum(ndi.gaussian_filter(shape.astype(np.float32), 9.0), 1e-3) > 0.45
    fire = shape & ~dust & ((rgb[..., 0] > rgb[..., 2] + 0.18) | (rgb.min(axis=2) > 0.85))
    fire = ndi.binary_opening(fire, iterations=1)
    out = rgb.copy()
    for edge, colour in IMPACT_TONES:
        out[fire & (lum >= edge)] = colour
    line = ndi.binary_dilation(shape, iterations=IMPACT_LINE) & ~shape
    out[line] = IMPACT_INK
    alpha = ndi.gaussian_filter((shape | line).astype(np.float32), 0.8)
    # (the fill's colours run out under the line and the soft edge: no pale fringe)
    return np.dstack([out * alpha[..., None], alpha]).astype(np.float32)


def impact() -> None:
    """A blow's burst (fx_impact.png: Fx.hit_spark): three painted frames in a row (the contact, the burst, the
    break-up; the blow goes right), each in a cell of the same size with the point of contact, the middle of its
    white-hot heart, at the same place (printed: Fx.IMPACT_CELL, IMPACT_AT), at half the painting's size."""
    # blind round 21 ("a flat white eight-point star with orange wedges, clip-art comic style, and it hides the ring
    # and the contact point": "a painted directional impact (slash arc, dust and debris in the scene's palette)"):
    # impact2: a white-hot crescent whose nose is the contact, opening the blow's way, sparks and chips flying on,
    # a puff of the path's dust in the dusk's cream and lilac. The contact: a little inside its nose.
    a = load("impact2")
    # (each frame is cut where nothing is drawn between it and the next: cut at the thirds, the burst's nose was left in
    # the contact's cell and its heart cut square)
    empty = a[..., 3].max(axis=0) < 0.03
    runs, x = [], 0
    while x < empty.size:
        if empty[x]:
            x1 = x
            while x1 < empty.size and empty[x1]:
                x1 += 1
            runs.append((x, x1))
            x = x1
        else:
            x += 1
    cuts = [0]
    for third in (a.shape[1] / 3.0, a.shape[1] * 2.0 / 3.0):
        near = min(runs, key=lambda r: abs((r[0] + r[1]) / 2.0 - third))
        cuts.append((near[0] + near[1]) // 2)
    cuts.append(a.shape[1])
    print("impact2 cut at", cuts)
    frames = []
    for i in range(3):
        part = a[:, cuts[i]:cuts[i + 1]]
        f = cel(part)
        al = part[..., 3]
        rgb = part[..., :3] / np.maximum(al[..., None], 1e-4)
        lab, n = ndi.label((al > 0.9) & (rgb.min(axis=2) > 0.93))
        heart = 1 + int(np.argmax(ndi.sum(np.ones_like(al), lab, np.arange(1, n + 1))))
        cy = ndi.center_of_mass(lab == heart)[0]
        band = al[int(cy) - 12:int(cy) + 12].max(axis=0)
        cx = int(np.nonzero(band > 0.5)[0].min()) + IMPACT_NOSE
        ys, xs = np.nonzero(f[..., 3] > 0.03)
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


LANE_ROWS = (566, 684, 752)  # px of the painting: its far edge, the line they walk on (the worn track's near side), its near edge
LANE_ABOVE = 160  # px of the game's picture over the walking line (40 units at 4 px a unit, the painting's own size)
LANE_BANK = (56, 36)  # px of its cut bank kept under the near edge, and the px it fades out over (the ground's own earth under it)
LANE_JOIN = 256  # px of each end its join may wander in
LANE_CELLS = 27  # cells of 128 px it is long, joined


def lane() -> None:
    """The ground they run on (lane.png: TerrainView._lane), from lane: a level ribbon of trodden grass with a worn
    track along it, seen from the side and a little from above, painted in the plain's ink and cel planes (blind round
    23: "both figures float on a thin tile ... give them a real lit ground of about 15% of the frame"). Cut from the
    tips of its far tussocks to the top of its cut bank, which fades into the ground's own earth (terrain.gdshader);
    repeating; its length brought to a whole number of cells (a hair: 3444 px to 3456)."""
    a = load("lane")[:, PLAIN_ENDS:-PLAIN_ENDS]
    far, walk, near = LANE_ROWS
    top = walk - LANE_ABOVE
    a = seam(a[top:near + sum(LANE_BANK)], LANE_JOIN, feather=2.0, reach=2)
    a = resize(a, (LANE_CELLS * 128, a.shape[0]))
    v = np.arange(a.shape[0], dtype=np.float32)[:, None, None]
    a *= 1.0 - np.clip((v - (near - top + LANE_BANK[0])) / LANE_BANK[1], 0.0, 1.0)
    save(a, OUT / "lane.png")
    print("lane.png: far edge at %.4f of its height, walking line at %.4f, near edge at %.4f" % (
            (far - top) / a.shape[0], (walk - top) / a.shape[0], (near - top) / a.shape[0]))


CROC_W = 640  # px wide in the game (its picture: 2048)


def croc() -> None:
    """The river's crocodile lunging out of the water (croc.png: SavannaView._draw_croc), from croc: cropped to what is
    drawn, its foot the waterline (the lowest row its splash and ripples reach), CROC_W px wide."""
    a = load("croc")
    ys, xs = np.nonzero(a[..., 3] > 0.03)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    a = resize(a, (CROC_W, round(a.shape[0] * CROC_W / a.shape[1])))
    save(a, OUT / "croc.png")
    print("croc.png: %dx%d" % (a.shape[1], a.shape[0]))


if __name__ == "__main__":
    todo = sys.argv[1:] or ["sky", "wall", "mesas", "plain", "river", "trees", "front", "fire", "earth"]
    for name in todo:
        globals()[name]()
