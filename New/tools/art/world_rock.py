#!/usr/bin/env python3
"""Round 19 (the judges: "a grid of same-size hexagons, a turtle shell"; "the river pillars the same thin
cardboard column twice with broccoli grass hats, no base"): the rock of the floating ledges' undersides and of
the river's pillars, painted with kie.ai in the key art's style from a layout drawn here, then cut and sized to
TerrainView's contracts.

    python3 tools/art/world_rock.py layout   -> _agents/kie/world19/layout/rock.png + rock.json
    python3 tools/art/world_rock.py build    -> assets/art/world/hanging.png + spires.png from the sheet

hanging.png: MASS_VARIANTS masses side by side, each MASS_PX (its top straight: it joins the ledge's soil).
spires.png: three pillars side by side, each SPIRE_PX (its top the walkable cap, its foot flared on boulders).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

NEW = Path(__file__).resolve().parents[2]
K = Path("/Users/moctar/Documents/Games/PanoramicGame/_agents/kie/world19")  # (the sheets, outside the repo)
ART = NEW / "assets/art/world"
LW, LH = 1376, 768  # the layout's size (the sheet comes back at twice that)
KEY = (0, 255, 0)
MASS_PX = (512, 256)  ## one mass in hanging.png (256 x 128 units at 2 px)
MASS_VARIANTS = 4
SPIRE_PX = (192, 1120)  ## one pillar in spires.png (96 x 560 units)
FOOT_PX = (192, 128)  ## its foot in spire_feet.png (96 x 64 units)
SHAFT_TOP_PX = 84  ## a shaft's top, the walkable cap, 42 units across (the cell is 32)

# boxes (fractions of the sheet): x, y, w, h
BOXES = {
    "mass_0": (0.015, 0.035, 0.29, 0.40),
    "mass_1": (0.32, 0.035, 0.29, 0.40),
    "mass_2": (0.015, 0.53, 0.29, 0.40),
    "mass_3": (0.32, 0.53, 0.29, 0.40),
    "spire_0": (0.645, 0.02, 0.10, 0.96),
    "spire_1": (0.765, 0.02, 0.10, 0.96),
    "spire_2": (0.885, 0.02, 0.10, 0.96),
}
LIT, MID, SHADE, DEEP, INK = (238, 178, 138), (200, 128, 102), (132, 98, 136), (92, 64, 96), (52, 26, 30)


def _box(name):
    x, y, w, h = BOXES[name]
    return x * LW, y * LH, w * LW, h * LH


def _mass(d: ImageDraw.ImageDraw, name: str, bottom: list, splits: list, rng) -> None:
    """A ledge's underside: a straight top across the box, `bottom` the outline's lower points (u, v in the
    box), cut into big planes by lines from the top to the outline (`splits`: pairs of u on the top and an
    index into bottom); planes facing the upper left lit, the rest in shade."""
    x, y, w, h = _box(name)
    pts = [(x, y)] + [(x + u * w, y + v * h) for u, v in bottom] + [(x + w, y)]
    d.polygon(pts, fill=MID)
    tops = [0.0] + [s[0] for s in splits] + [1.0]
    ends = [0] + [s[1] for s in splits] + [len(bottom) - 1]
    for i in range(len(tops) - 1):
        poly = [(x + tops[i] * w, y)] + [(x + bottom[k][0] * w, y + bottom[k][1] * h) for k in range(ends[i], ends[i + 1] + 1)] \
            + [(x + tops[i + 1] * w, y)]
        tone = [LIT, MID, SHADE, MID, DEEP][i % 5] if i < 4 else SHADE
        d.polygon(poly, fill=tone)
    # strata: a few soft bands across, and the line under the ledge's soil
    for k in range(3):
        yy = y + h * (0.12 + 0.13 * k)
        d.line([(x + w * 0.04, yy), (x + w * 0.96, yy + rng.uniform(-6, 6))], fill=INK, width=2)
    d.line(pts + [pts[0]], fill=INK, width=3)
    for _ in range(7):  # roots hanging from it
        u = rng.uniform(0.15, 0.85)
        k = min(range(len(bottom)), key=lambda j: abs(bottom[j][0] - u))
        rx, ry = x + bottom[k][0] * w, y + bottom[k][1] * h - 4
        length = rng.uniform(18, 46)
        d.line([(rx, ry), (rx + rng.uniform(-8, 8), ry + length * 0.5), (rx + rng.uniform(-10, 10), ry + length)], fill=INK, width=2)


def _spire(d: ImageDraw.ImageDraw, name: str, rng, lean: float) -> None:
    """A river pillar: a flat cap rock at the top (a little wider than the shaft under it), a shaft of
    horizontal sandstone beds, a foot flaring out over fallen boulders."""
    x, y, w, h = _box(name)
    cx = x + w / 2
    top_w, cap_h = w * 0.42, h * 0.035
    left, right = [], []
    n = 12
    for i in range(n + 1):
        t = i / n
        half = w * (0.18 + 0.06 * np.sin(t * 7 + lean * 3) + 0.2 * t ** 3)  # flares at its foot
        off = lean * w * 0.12 * np.sin(t * 3.0)
        left.append((cx - half + off, y + cap_h + t * (h - cap_h)))
        right.append((cx + half + off, y + cap_h + t * (h - cap_h)))
    body = left + right[::-1]
    d.polygon(body, fill=MID)
    # its lit face (left), its shade (right)
    lit = left + [((a[0] + b[0]) / 2 - w * 0.03, a[1]) for a, b in zip(left, right)][::-1]
    d.polygon(lit, fill=LIT)
    shade = [((a[0] + b[0]) / 2 + w * 0.05, a[1]) for a, b in zip(left, right)] + right[::-1]
    d.polygon(shade, fill=SHADE)
    # beds: horizontal joints of uneven spacing
    yy = y + cap_h + rng.uniform(30, 50)
    while yy < y + h * 0.86:
        t = (yy - y) / h
        half = w * (0.18 + 0.2 * t ** 3) + 4
        d.line([(cx - half, yy), (cx + half, yy + rng.uniform(-4, 4))], fill=INK, width=2)
        yy += rng.uniform(34, 78)
    # the cap rock
    d.polygon([(cx - top_w / 2 - 6, y), (cx + top_w / 2 + 4, y), (cx + top_w / 2 + 6, y + cap_h * 1.3),
               (cx - top_w / 2 - 8, y + cap_h * 1.3)], fill=LIT)
    d.line([(cx - top_w / 2 - 8, y + cap_h * 1.3), (cx + top_w / 2 + 6, y + cap_h * 1.3)], fill=INK, width=2)
    # boulders at its foot
    for k in range(4):
        bx = cx + (k - 1.5) * w * 0.26 + rng.uniform(-6, 6)
        br = rng.uniform(w * 0.1, w * 0.16)
        by = y + h - br * 0.8
        d.ellipse([bx - br, by - br * 0.8, bx + br, by + br * 0.8], fill=SHADE if k % 2 else LIT, outline=INK, width=2)
    d.polygon(body, outline=INK, width=3)


def _outline(rng, deep_u: float, depth: float, drips: list, lumps: int) -> list:
    """The lower outline of a mass (u, v points): a heavy rounded belly deepest at deep_u, lumpy (boulders
    bulging out of it), a drip or two hanging lower (a stalactite of rock and roots)."""
    pts = []
    n = 26
    phase = rng.uniform(0, 6)
    for i in range(n + 1):
        u = 0.01 + 0.98 * i / n
        side = (u - deep_u) / (deep_u if u < deep_u else 1 - deep_u)
        belly = (1 - abs(side) ** 1.6) ** 0.7
        v = 0.08 + (depth - 0.08) * belly
        v += 0.05 * np.sin(u * lumps * np.pi + phase) * belly  # lumps along it
        for du, dv in drips:
            v += dv * np.exp(-((u - du) / 0.035) ** 2)
        pts.append((u, min(v, 0.98)))
    return pts


def layout() -> None:
    rng = np.random.default_rng(19)
    img = Image.new("RGB", (LW, LH), KEY)
    d = ImageDraw.Draw(img)
    for name, deep_u, depth, drips, lumps in (("mass_0", 0.46, 0.72, [(0.5, 0.22), (0.7, 0.1)], 5),
                                               ("mass_1", 0.6, 0.5, [(0.3, 0.14), (0.64, 0.2)], 7),
                                               ("mass_2", 0.32, 0.78, [(0.3, 0.18)], 4),
                                               ("mass_3", 0.66, 0.66, [(0.2, 0.1), (0.68, 0.24), (0.84, 0.08)], 6)):
        pts = _outline(rng, deep_u, depth, drips, lumps)
        splits = [(0.24, 7), (0.5, 13), (0.76, 19)]
        _mass(d, name, pts, splits, rng)
    for i, lean in enumerate((0.6, -0.4, 0.2)):
        _spire(d, "spire_%d" % i, rng, lean)
    (K / "layout").mkdir(parents=True, exist_ok=True)
    img.save(K / "layout/rock.png")
    (K / "layout/rock.json").write_text(json.dumps(BOXES, indent=1))
    print("layout", K / "layout/rock.png")


def key_green(img: np.ndarray, min_part=0.004) -> np.ndarray:
    """Keys the flat green out (as wlib.key_magenta, for #00FF00): each pixel near the cut a mix of the
    nearest clean painted colour and the key; specks dropped."""
    rgb = img[..., :3]
    R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = G - np.maximum(R, B)
    a0 = np.clip((250.0 - m) / 190.0, 0.0, 1.0)
    solid = a0 > 0.5
    lab, n = ndi.label(solid)
    if n:
        sz = ndi.sum(solid, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.where(sz >= sz.max() * min_part)[0])
        solid = ndi.binary_dilation(keep, iterations=2) & (a0 > 0.03)
    core = solid & ~ndi.binary_dilation(~(solid & (a0 > 0.5)), iterations=3) & (m < 30)
    clean = core & (m < 8)
    if not clean.any():
        clean = solid
    idx = ndi.distance_transform_edt(~clean, return_distances=False, return_indices=True)
    F = rgb[idx[0], idx[1]]
    key = np.array(KEY, np.float32)
    dlt = F - key
    a = ((rgb - key) * dlt).sum(axis=2) / np.maximum((dlt * dlt).sum(axis=2), 1.0)
    a = np.clip(a, 0.0, 1.0)
    a = np.where(core, 1.0, np.where(ndi.binary_dilation(solid, iterations=1), a, 0.0))
    a = np.where(a < 0.03, 0.0, a)
    out = np.where(core[..., None], rgb, F)
    near = ndi.binary_dilation(a < 0.5, iterations=6)  # the key's tint left near the cut: green brought down
    spill = np.clip(out[..., 1] - np.maximum(out[..., 0], out[..., 2]) * 0.92, 0, None) * near
    out[..., 1] -= spill
    return np.dstack([out, a * 255.0])


def region(keyed: np.ndarray, box, mx=0.015, my=0.015) -> np.ndarray:
    """The keyed piece of a box (fractions): the connected parts mostly inside the box grown by a margin."""
    H, W = keyed.shape[:2]
    bx, by, bw, bh = box
    x0, y0 = max(0, int((bx - mx) * W)), max(0, int((by - my) * H))
    x1, y1 = min(W, int((bx + bw + mx) * W)), min(H, int((by + bh + my) * H))
    lab, n = ndi.label(ndi.binary_dilation(keyed[..., 3] > 40, iterations=2))
    total = np.bincount(lab.ravel(), minlength=n + 1)
    within = np.bincount(lab[y0:y1, x0:x1].ravel(), minlength=n + 1)
    ok = (within / np.maximum(total, 1)) > 0.6
    ok[0] = False
    mask = ok[lab] & (keyed[..., 3] > 0)
    out = keyed * mask[..., None]
    ys, xs = np.where(mask)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()


def resize(img: np.ndarray, size) -> np.ndarray:
    """Premultiplied resize (no dark fringes)."""
    a = img[..., 3:4] / 255.0
    pre = np.dstack([img[..., :3] * a, img[..., 3:4]])
    chans = [np.asarray(Image.fromarray(pre[..., i].astype(np.float32), "F").resize(size, Image.LANCZOS)) for i in range(4)]
    out = np.dstack(chans)
    al = np.clip(out[..., 3:4], 0, 255)
    rgb = np.where(al > 0.5, out[..., :3] / np.maximum(al / 255.0, 1e-3), 0)
    return np.dstack([np.clip(rgb, 0, 255), al])


def bleed(img: np.ndarray) -> np.ndarray:
    a = img[..., 3] > 8
    if a.all() or not a.any():
        return img
    idx = ndi.distance_transform_edt(~a, return_distances=False, return_indices=True)
    out = img.copy()
    out[..., :3] = img[idx[0], idx[1], :3]
    return out


def save(arr: np.ndarray, path) -> None:
    Image.fromarray(np.clip(arr, 0, 255).round().astype(np.uint8), "RGBA").save(path, optimize=True)


def build(sheet: str) -> None:
    keyed = key_green(np.asarray(Image.open(sheet).convert("RGBA")).astype(np.float32))
    save(keyed, K / "out/rock_keyed.png")
    boxes = json.loads((K / "layout/rock.json").read_text())
    # the masses: each stretched to its slot, its top row made opaque (it joins the ledge's soil, which
    # the game fades it into), its outline kept
    out = np.zeros((MASS_PX[1], MASS_PX[0] * MASS_VARIANTS, 4), np.float32)
    for i in range(MASS_VARIANTS):
        piece = region(keyed, boxes["mass_%d" % i])
        top = int(np.argmax((piece[..., 3] > 128).mean(axis=1) > 0.9))  # the first row painted all across
        piece = piece[top:]
        m = weathered(resize(piece, MASS_PX), np.random.default_rng(30 + i))
        # in the shade of the grass mat over it: darker and cooler just under its top, as an underside is
        t = np.linspace(0.0, 1.0, MASS_PX[1])[:, None]
        shade = 1.0 - 0.42 * np.clip(1.0 - t / 0.3, 0.0, 1.0) ** 1.6
        m[..., 0] *= shade
        m[..., 1] *= shade * 0.98 + 0.02
        m[..., 2] *= shade * 0.9 + 0.1
        out[:, i * MASS_PX[0]:(i + 1) * MASS_PX[0]] = m
    save(bleed(out), ART / "hanging.png")
    print("hanging.png", out.shape)
    # the pillars (round 19): the model drew each with a slab on top (a Greek column's abacus): cut off, the
    # shaft's own top is the walkable cap (TerrainView lays a slim mat of grass on it); the shaft goes in
    # spires.png, its flared foot on its boulders in spire_feet.png (drawn at the waterline / the ground)
    out = np.zeros((SPIRE_PX[1], SPIRE_PX[0] * 3, 4), np.float32)
    feet = np.zeros((FOOT_PX[1], FOOT_PX[0] * 3, 4), np.float32)
    rng = np.random.default_rng(7)
    lengths = []
    for i in range(3):
        piece = region(keyed, boxes["spire_%d" % i])
        al = piece[..., 3] > 128
        H = piece.shape[0]
        w = al.sum(axis=1).astype(float)
        slab = w[:int(H * 0.08)].max()  # the slab: the widest of the top rows; the shaft starts where it narrows
        r = int(np.argmax(w > 0.9 * slab))
        while r < H * 0.15 and w[r] >= 0.82 * slab:
            r += 1
        cut = r + 6
        foot_h = int(H * 0.13)
        cols = np.where(al[cut + 8])[0]
        top_w, centre = cols.max() - cols.min() + 1, (cols.max() + cols.min()) / 2.0
        widest = w[cut:H - foot_h].max()  # (the whole shaft inside its slot, with room for its outline)
        k = min(SHAFT_TOP_PX / top_w, (SPIRE_PX[0] - 36) / widest)
        shaft = weathered(piece[cut:H - foot_h // 2], rng)
        foot = weathered(piece[H - foot_h:], rng)
        sw = int(round(shaft.shape[1] * k))
        sh = min(SPIRE_PX[1], int(round(shaft.shape[0] * k)))
        m = resize(shaft, (sw, int(round(shaft.shape[0] * k))))[:sh]
        x = int(round(i * SPIRE_PX[0] + SPIRE_PX[0] / 2 - centre * k))
        a0, a1 = max(x, i * SPIRE_PX[0]), min(x + sw, (i + 1) * SPIRE_PX[0])
        out[:sh, a0:a1] = m[:, a0 - x:a1 - x]
        fw, fh = int(round(foot.shape[1] * k)), int(round(foot.shape[0] * k))
        f = resize(foot, (fw, fh))
        fx = int(round(i * FOOT_PX[0] + FOOT_PX[0] / 2 - centre * k))
        b0, b1 = max(fx, i * FOOT_PX[0]), min(fx + fw, (i + 1) * FOOT_PX[0])
        fh = min(fh, FOOT_PX[1])
        feet[FOOT_PX[1] - fh:, b0:b1] = f[f.shape[0] - fh:, b0 - fx:b1 - fx]
        lengths.append(round(sh / 2.0, 1))
        print("spire", i, "slab rows", cut, "of", H, "top", top_w, "px, k", round(k, 3), "shaft", sw, "x", sh)
    save(bleed(out), ART / "spires.png")
    save(bleed(feet), ART / "spire_feet.png")
    # (TerrainView: units of shaft in each picture; a taller pillar stretches its picture to reach)
    (ART / "spires.json").write_text(json.dumps({"length": lengths}))
    print("spires.png", out.shape, "spire_feet.png", feet.shape)


def fbm(h: int, w: int, scale: float, rng, octaves=4) -> np.ndarray:
    """Smooth value noise 0..1 (h x w), features about `scale` px."""
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        s = scale / (2 ** o)
        gh, gw = int(h / s) + 2, int(w / s) + 2
        g = rng.random((gh, gw)).astype(np.float32)
        up = np.asarray(Image.fromarray(g, "F").resize((int(gw * s), int(gh * s)), Image.BICUBIC))[:h, :w]
        out += up * amp
        total += amp
        amp *= 0.5
    return out / total


def weathered(piece: np.ndarray, rng) -> np.ndarray:
    """The model's flat vector fills given a painter's texture: soft mottling, streaks of weathering
    down the stone, a little darker towards the foot (in its own shade)."""
    h, w = piece.shape[:2]
    out = piece.copy()
    mott = fbm(h, w, 40, rng) - 0.5
    streak = np.asarray(Image.fromarray((rng.random((1, max(2, w // 6))) * 255).astype(np.uint8)).resize((w, 1), Image.BICUBIC),
                        np.float32)[0] / 255.0 - 0.5
    k = 1.0 + 0.16 * mott + 0.08 * streak[None, :] * (fbm(h, w, 120, rng) > 0.45)
    out[..., :3] = np.clip(out[..., :3] * k[..., None], 0, 255)
    return out


if __name__ == "__main__":
    if sys.argv[1] == "layout":
        layout()
    elif sys.argv[1] == "build":
        build(sys.argv[2] if len(sys.argv) > 2 else str(K / "gen/world_rock_0.png"))
