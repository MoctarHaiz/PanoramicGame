#!/usr/bin/env python3
"""Packs Panoramic's rendered animations (tools/art/blender/hero_render.py) into atlases for the game.

Each frame is reduced to the game's size (premultiplied, so the edges stay clean), trimmed to what it
shows, packed into 2048-wide pages, and its transparent pixels take the colour of the nearest
opaque one (no dark fringe under filtering and mipmaps). assets/art/hero/hero_frames.json lists,
for every animation, its frames: the page, the region, where the world's origin falls (on the
ground under his hips at rest: the anchor of ground frames) and the projected points of the
hips, head, toes and hands (airborne frames hang from the hips, hanging ones from the hands).
Also writes the interface pictures (hero_menu.png, hero_win.png, hero_defeat.png) and portrait.png (the
source of the HUD badge, the icons and the store art: tools/art/ui_art.py, icons.py, tools/store_art.py).

    python3 tools/art/hero_atlas.py [RENDER_DIR]   # default ROOT/_agents/AAA/hero3d/render/r14/game

(The AAA hero: rendered by hero_render.py from ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend, see
ROOT/_agents/AAA/hero3d/render/render_all.sh; the interface pictures come from RENDER_DIR/../render_ui.)
"""
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())  # the folder with the user's Blender files
RENDER = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/AAA/hero3d/render/r17/game"  # (round 17: hero3d/render/render_r17.sh)
GROUND_SPEED = 8.0 * 960.0 / 1320.0 * 40.0  ## units a second the ground scrolls (World.SCROLL_SPEED)
OUT = NEW / "assets/art/hero"
SCALE = 0.50  ## render px -> atlas px (round 17: 0.4 drew him upscaled up to 1.26x in play, 1.6x at home: "a low-res
## sprite on a high-res backdrop"; at 0.5 he is at most 1.0x in play) (1024 renders: he stands ~690 px, ~276 px in the atlas; the ink line costs a little room)
DRAW_HEIGHT = 150.0  ## units he stands in the game (GameArt.HERO_DRAW_HEIGHT)
STAND_PX = 690.0  ## his standing height (boots to hair) in a 1024 render
PAGE = 2048
PAD = 3  ## transparent pixels around each frame (and between frames)

# name -> frames to keep (indices into the render folder; None: all), frames a second, loop
ANIMS = {
    "run": (None, 30.0, True),
    "throw": (None, 30.0, False),  # 0-15: the wind-up over each run frame, 16-31: the release
    "jump": (None, 30.0, False),
    "idle": (None, 10.0, True),
    "die": (None, 20.0, False),
    "hang": (None, 10.0, True),
    "catch": (None, 30.0, False),
    "crouch": (None, 24.0, False),
    "hurt": (None, 30.0, False),
    "climb": (None, 30.0, False),
    "win": (None, 20.0, False),
}


def premultiplied_resize(img: Image.Image, k: float) -> np.ndarray:
    a = np.asarray(img.convert("RGBA"), np.float32) / 255.0
    size = (max(1, round(img.width * k)), max(1, round(img.height * k)))
    alpha = a[..., 3]
    chans = [Image.fromarray(a[..., i] * alpha) for i in range(3)] + [Image.fromarray(alpha)]
    small = np.stack([np.asarray(c.resize(size, Image.LANCZOS)) for c in chans], -1)
    small = np.clip(small, 0.0, 1.0)
    al = small[..., 3:4]
    rgb = np.where(al > 1e-4, small[..., :3] / np.maximum(al, 1e-4), 0.0)
    return np.concatenate([np.clip(rgb, 0, 1), al], -1)


INK = np.array([0.1, 0.045, 0.035])  ## the ink of the outline: a warm near-black brown (pass 3: darker, for the pale sky)
INK_PX = 3.1  ## atlas px of ink round his outer silhouette, on the shadow side (pass 3: 1.6 -> 2.2, "almost no value contrast against the sky"; round 11: 2.8 -> 3.2, "a brown smudge on the rock"; round 15: 2.7, "thinner ink", and INK_LIT of it on the lit side)
INK_PX_UI = 2.4  ## the same, scaled to the interface pictures (round 15: 2.8 -> 2.4)


SUN = np.array([-0.6, -0.8])  ## towards the sun on screen (x right, y down): upper left, as in the world
RIM_PX = 2.6  ## atlas px of the hot rim on the sun side (hero pass 2: "a thick hot band, not a thin line"; round 11: 3.4 -> 4.2; round 14: round 13's 5.0 reverted;
## round 15, "a paler band just inside the outline: a die-cut sticker": thinner, hot orange, falling into the form)
RIM_PX_UI = 2.4  ## the same, scaled to the interface pictures (round 11: 3.4 -> 2.4, "a lighter halo" inside the line)
RIM_DAY = (np.array([1.0, 0.56, 0.2]), 0.5)  ## colour, strength (round 11: lighter and stronger, to part him from the rock;
## round 14: round 13's warm white band read "a whitish edge, a cut-out sticker": back to round 12's warm orange)
RIM_DAY_DARK = 0.0  ## how much of it his black hair takes in the level (round 15: none, "grey hair")
RIM_DAY_FALL = 1.6  ## a line at the edge falling into the form
INK_DAY = np.array([0.075, 0.032, 0.038])  ## (round 14) the level's ink darker, a little purple: "a dark ink outline so he sits inside the world"
RIM_SUNSET = (np.array([1.0, 0.55, 0.2]), 0.0)  ## (round 13: warmer white, the rim against the sky; on the sun side only;
## round 15: none: the pictures' hot rim is the 3D render's, on the form, not a band along the line)


def sun_rim(arr: np.ndarray, px: float = RIM_PX, rim=RIM_DAY, dark: float = 0.22, fall: float = 1.6) -> np.ndarray:
    """A thick hot band inside the silhouette, only on the edges that face the sun (the shadow side's
    edges keep the dark of the form: no pale fringe inside the ink). Applied before inked(). `dark`: how
    much of the band the darkest colours take (his black hair: a faint sheen; 1: all, the dark bandit); `fall`: how
    fast it fades into the form (1.6: a line at the edge; under 1: a solid band)."""
    a = arr[..., 3]
    inside = a > 0.5
    if not inside.any():
        return arr
    d, (iy, ix) = ndimage.distance_transform_edt(inside, return_indices=True)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    vy, vx = iy - yy, ix - xx  # towards the nearest outside pixel: the edge's outward direction
    n = np.hypot(vx, vy) + 1e-6
    facing = (vx / n) * SUN[0] + (vy / n) * SUN[1]
    f = np.clip((facing - 0.15) / 0.5, 0.0, 1.0)
    f = f * f * (3 - 2 * f)
    t = np.clip(1.0 - (d - 0.5) / px, 0.0, 1.0)
    band = (t ** fall) * f * inside * rim[1]  # strongest at the edge, a fall into the form
    lum = arr[..., :3] @ np.array([0.3, 0.59, 0.11])
    band = band * (dark + (1.0 - dark) * np.clip(lum / 0.4, 0.0, 1.0))  # the black hair stays black (a faint warm sheen)
    rgb = arr[..., :3]
    # (pass 3) towards the hot colour, not a screen blend: white fur and boot trim turn warm, never paler
    # ("pale whitish edges, halos"); skin and scarf brighten into it
    lit = rgb + (rim[0][None, None, :] - rgb) * band[..., None]
    out = arr.copy()
    out[..., :3] = lit
    return out


INK_SS = 4  ## the outline is drawn at 4x and reduced: a smooth anti-aliased edge (round 11: "a jagged, uneven stroke")
INK_CALM = 0.35  ## its contour calmed over this share of its width (no bumps where a strand of fur pokes out)
## (round 15, every judge: "a thick, even, near-black outline with a paler band just inside it: a die-cut sticker";
## "a thinner outline in a dark shade of the local colour, thinner on the lit side") the line takes the colour it
## edges, darkened, and thins on the edges towards the sun
INK_LUM = 0.12  ## the line's luminance (sRGB): the local colour darkened to it, never lighter than INK_DARK of it
INK_DARK = 0.3
INK_MIX = 0.3  ## share of the plain warm near-black ink in it (one family of lines across his colours)
INK_LIT = 0.45  ## the line's width on the edges towards the sun, a share of its width on the shadow side


def inked(arr: np.ndarray, px: float = INK_PX, ink: np.ndarray = INK, lit: float = INK_LIT, mix: float = INK_MIX) -> np.ndarray:
    """A frame with an ink line round its outer silhouette (anti-aliased), under the figure: the cel look's
    outline reads against the pale sky at phone size, inside lines stay thin. The line follows a calmed contour
    of the silhouette, so it keeps an even width, drawn at INK_SS x and reduced (smooth, no stair steps); round a
    strand too thin for the calmed contour it is three quarters as wide, never missing. Its colour is the colour
    next to it, darkened (black hair: black; skin: a deep brown; the blue boots: a deep blue), and it is
    INK_LIT as wide where the edge faces the sun."""
    a = arr[..., 3].astype(np.float32)
    h, w = a.shape
    ss = INK_SS
    inside = a > 0.5
    if not inside.any():
        return arr
    # the colour a few pixels in from each edge (the rim and the anti-aliased edge left out) and the edge's way out
    soft = ndimage.gaussian_filter(inside.astype(np.float32), 1.5)
    local = ndimage.gaussian_filter(arr[..., :3] * inside[..., None], (1.5, 1.5, 0)) / np.maximum(soft, 1e-4)[..., None]
    _, (iy, ix) = ndimage.distance_transform_edt(~inside, return_indices=True)
    local = local[iy, ix]
    yy, xx = np.mgrid[0:h, 0:w]
    vx, vy = (xx - ix).astype(np.float32), (yy - iy).astype(np.float32)
    n = np.hypot(vx, vy) + 1e-6
    facing = np.where(n > 0.5, (vx / n) * SUN[0] + (vy / n) * SUN[1], 0.0)
    f = np.clip((facing - 0.1) / 0.6, 0.0, 1.0)
    f = ndimage.gaussian_filter(f * f * (3 - 2 * f), 1.0)
    width = 1.0 - (1.0 - lit) * f
    lum = local @ np.array([0.3, 0.59, 0.11])
    k = np.minimum(INK_DARK, INK_LUM / np.maximum(lum, 1e-3))
    colour = local * k[..., None] * (1.0 - mix) + ink * mix
    big = np.asarray(Image.fromarray(a, "F").resize((w * ss, h * ss), Image.BILINEAR))
    wide = np.asarray(Image.fromarray(width.astype(np.float32), "F").resize((w * ss, h * ss), Image.BILINEAR))
    calm = ndimage.gaussian_filter(big, px * INK_CALM * ss)
    cover = ndimage.distance_transform_edt(calm < 0.5) <= px * ss * wide
    cover |= ndimage.distance_transform_edt(big < 0.5) <= px * 0.75 * ss * wide
    ring = cover.astype(np.float32).reshape(h, ss, w, ss).mean((1, 3))
    out = np.zeros_like(arr)
    fa = a[..., None]
    out[..., :3] = arr[..., :3] * fa + colour * (1.0 - fa)
    out[..., 3] = a + ring * (1.0 - a)
    return out


def bleed(page: np.ndarray) -> np.ndarray:
    """Transparent pixels take the colour of the nearest visible one (alpha stays 0)."""
    solid = page[..., 3] > 0.02
    if not solid.any():
        return page
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = page.copy()
    out[..., :3] = page[iy, ix, :3]
    return out


class Shelf:
    """Shelf packing into pages PAGE wide."""

    def __init__(self):
        self.pages = []  # list of [height used, shelves]
        self.items = []

    def place(self, w, h):
        for pi, page in enumerate(self.pages):
            for shelf in page["shelves"]:
                if h <= shelf["h"] and shelf["x"] + w <= PAGE:
                    x = shelf["x"]
                    shelf["x"] += w
                    return pi, x, shelf["y"]
            if page["used"] + h <= PAGE:
                shelf = {"y": page["used"], "h": h, "x": w}
                page["shelves"].append(shelf)
                page["used"] += h
                return pi, 0, shelf["y"]
        self.pages.append({"used": h, "shelves": [{"y": 0, "h": h, "x": w}]})
        return len(self.pages) - 1, 0, 0


def run_fps(points: dict, k: float, units: float) -> float:
    """Frames a second at which the planted boot moves back with the ground: the mean speed of the
    lower toe while it is on the ground (within 4 render px of the lowest it gets)."""
    frames = points["frames"]
    ground = max(max(f["toe_r"][1], f["toe_l"][1]) for f in frames)
    steps = []
    for i in range(len(frames)):
        a, b = frames[i], frames[(i + 1) % len(frames)]
        for toe in ("toe_r", "toe_l"):
            if a[toe][1] > ground - 4 and b[toe][1] > ground - 4:
                steps.append(a[toe][0] - b[toe][0])
    px = sum(steps) / len(steps)
    return GROUND_SPEED / (px * k * units)


def main() -> None:
    frames = []  # (anim, index, array, offset of the trimmed box in the scaled frame)
    meta = {}
    for name, (keep, fps, loop) in ANIMS.items():
        folder = RENDER / name
        points = json.loads((folder / "points.json").read_text())
        files = sorted(folder.glob("*.png"))
        idx = keep if keep is not None else range(len(files))
        size = points["size"]
        k = SCALE * 1024.0 / size
        origin = points.get("origin")
        meta[name] = {"fps": fps, "loop": loop, "frames": [], "k": k, "points": points, "origin": origin}
        for i in idx:
            arr = inked(sun_rim(premultiplied_resize(Image.open(files[i]), k), dark=RIM_DAY_DARK, fall=RIM_DAY_FALL), ink=INK_DAY)
            ys, xs = np.nonzero(arr[..., 3] > 0.004)
            x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, arr.shape[1])
            y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, arr.shape[0])
            frames.append((name, i, arr[y0:y1, x0:x1], (x0, y0)))
    # tallest first packs shelves tightly
    order = sorted(range(len(frames)), key=lambda j: -frames[j][2].shape[0])
    shelf = Shelf()
    placed = {}
    for j in order:
        h, w = frames[j][2].shape[:2]
        placed[j] = shelf.place(w + 1, h + 1)
    pages = [np.zeros((p["used"], PAGE, 4), np.float32) for p in shelf.pages]
    for j, (pi, x, y) in placed.items():
        arr = frames[j][2]
        pages[pi][y:y + arr.shape[0], x:x + arr.shape[1]] = arr
    names = []
    for pi, page in enumerate(pages):
        h = (page.shape[0] + 3) // 4 * 4  # a multiple of 4 (block compression)
        full = np.zeros((h, PAGE, 4), np.float32)
        full[:page.shape[0]] = page
        full = bleed(full)
        used_w = max(x + frames[j][2].shape[1] for j, (p, x, y) in placed.items() if p == pi)
        used_w = min((used_w + 3) // 4 * 4, PAGE)
        img = Image.fromarray((full[:, :used_w] * 255.0 + 0.5).astype(np.uint8), "RGBA")
        fn = f"hero_atlas_{pi}.png"
        img.save(OUT / fn, optimize=True)
        names.append(fn)
        same_import(fn)
        print(fn, img.size)
    for j, (name, i, arr, (ox, oy)) in enumerate(frames):
        pi, x, y = placed[j]
        m = meta[name]
        k = m["k"]
        pts = m["points"]["frames"][i]
        # (renders made before the origin was recorded: Cam_Side's, measured)
        origin = m["origin"] or [m["points"]["size"] * 0.48957, m["points"]["size"] * 0.83881]
        rel = lambda p: [round(p[0] * k - ox, 1), round(p[1] * k - oy, 1)]  # noqa: E731
        m["frames"].append({"page": pi, "region": [x, y, arr.shape[1], arr.shape[0]], "origin": rel(origin),
                            **{key: rel(v) for key, v in pts.items()}})
    units = DRAW_HEIGHT / (STAND_PX * SCALE)
    fps = run_fps(meta["run"]["points"], meta["run"]["k"], units)
    print(f"run: {fps:.1f} frames a second keep the planted foot on the ground")
    data = {
        "units_per_px": round(units, 5),
        "run_fps": round(fps, 2),
        "pages": names,
        "anims": {name: {"fps": m["fps"], "loop": m["loop"], "frames": m["frames"]} for name, m in meta.items()},
    }
    (OUT / "hero_frames.json").write_text(json.dumps(data, separators=(",", ":")))
    total = sum(np.prod(p.shape[:2]) for p in pages)
    print(f"{len(frames)} frames, {len(names)} pages, {total / 1e6:.2f} Mpx")


def same_import(fn: str) -> None:
    """A new atlas page imports as the first does (VRAM compressed, mipmaps): round 17's fourth page came in with the
    project's lossless default and cost 13 MB."""
    first, imp = OUT / "hero_atlas_0.png.import", OUT / (fn + ".import")
    if fn == "hero_atlas_0.png" or not first.exists():
        return
    uid = next((l for l in imp.read_text().splitlines() if l.startswith("uid=")), None) if imp.exists() else None
    lines = first.read_text().replace("hero_atlas_0.png", fn).splitlines()
    lines = [l for l in lines if not l.startswith("uid=")] if uid is None else [uid if l.startswith("uid=") else l for l in lines]
    imp.write_text("\n".join(lines) + "\n")


def trimmed(path: Path, height: int, sunset: bool = False, under: np.ndarray | None = None,
            over: np.ndarray | None = None, ink_k: float = 1.0, rim=None, clean: bool = False,
            ink_lit: float = INK_LIT, ink_mix: float = INK_MIX) -> np.ndarray:
    """A render cut to what it shows and reduced to `height` px; `under` and `over` (RGBA 0..1, the render's size):
    layers drawn behind and in front of the figure, cut and reduced with it, with no ink round them (the menu's
    throw trail, the glint on its ring)."""
    img = Image.open(path).convert("RGBA")
    # (round 15, "a faint hard-edged lighter rectangle in the sky behind the hair and the ring": cut to the figure,
    # the trail's glow round the ring was cut straight) cut to everything drawn, the glows too, with room round it
    seen = np.asarray(img.getchannel("A")) > 2
    for layer in (under, over):
        if layer is not None:
            seen |= layer[..., 3] > 0.002
    ys, xs = np.nonzero(seen)
    room = int(img.height * 0.006)  # (none under his soles: the menu stands them on the rock at 0.93 of its height)
    box = (max(xs.min() - room, 0), max(ys.min() - room, 0), min(xs.max() + room + 1, img.width),
           min(ys.max() + 1, img.height))
    img = img.crop(box)
    k = height / img.height
    arr = premultiplied_resize(img, k)
    ink = INK_PX_UI * height / 300.0 * ink_k  # (as thick, for its size, as in the game before pass 3)
    m = int(np.ceil(ink)) + 3  # (round 11: room for the whole line; a 4 px border cut it flat at his boots)
    if clean:  # (key art k9, "dark speckle noise along the hair, boots and kilt hem") no loose specks for the ink to ring:
        # islands under 40 px dropped, faint pixels away from the figure cleared
        solid = arr[..., 3] > 0.5
        lab, n = ndimage.label(solid)
        if n:
            sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
            keep = np.isin(lab, np.nonzero(sizes >= 40)[0] + 1)
            near = ndimage.binary_dilation(keep, iterations=2)
            arr = arr.copy()
            arr[..., 3] = np.where(near, arr[..., 3], 0.0) * np.where(solid & ~keep, 0.0, 1.0)
            # (key art k11, "pale halo pixels along the fist and hem") the soft edge tightened: the ink sits on solid colour
            arr[..., 3] = np.clip((arr[..., 3] - 0.22) / 0.56, 0.0, 1.0)
    pad = np.zeros((arr.shape[0] + 2 * m, arr.shape[1] + 2 * m, 4), np.float32)
    pad[m:-m, m:-m] = arr
    if rim is not None:  # (key art k8) the menu's own: (colour, strength, width k, fall)
        pad = sun_rim(pad, RIM_PX_UI * height / 300.0 * rim[2], (rim[0], rim[1]), fall=rim[3])
    else:
        pad = sun_rim(pad, RIM_PX_UI * height / 300.0, RIM_SUNSET if sunset else RIM_DAY)
    out = inked(pad, ink, lit=ink_lit, mix=ink_mix)
    if under is not None:
        u = premultiplied_resize(Image.fromarray((under * 255 + 0.5).astype(np.uint8), "RGBA").crop(box), k)
        low = np.zeros_like(out)
        low[m:m + u.shape[0], m:m + u.shape[1]] = u[:out.shape[0] - m, :out.shape[1] - m]
        a, b = out[..., 3:4], low[..., 3:4]
        al = a + b * (1.0 - a)
        out = np.concatenate([(out[..., :3] * a + low[..., :3] * b * (1.0 - a)) / np.maximum(al, 1e-4), al], -1)
    if over is not None:
        u = premultiplied_resize(Image.fromarray((over * 255 + 0.5).astype(np.uint8), "RGBA").crop(box), k)
        top = np.zeros_like(out)
        top[m:m + u.shape[0], m:m + u.shape[1]] = u[:out.shape[0] - m, :out.shape[1] - m]
        a, b = top[..., 3:4], out[..., 3:4]
        al = a + b * (1.0 - a)
        out = np.concatenate([(top[..., :3] * a + out[..., :3] * b * (1.0 - a)) / np.maximum(al, 1e-4), al], -1)
    return out


def _ring(folder: Path):
    """The flying ring in a render: the second piece of the picture (centre, radius, in render px)."""
    src = np.asarray(Image.open(folder / "000.png"))
    ring = json.loads((folder / "points.json").read_text())["frames"][0].get("ring")
    if ring:  # (round 15: the ring close to his hand, touching him: hero_render.py writes where it is)
        return np.array(ring[:2]), float(ring[2]), src.shape[:2]
    lab, n = ndimage.label(src[..., 3] > 128)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    ys, xs = np.nonzero(lab == np.argsort(-sizes)[1] + 1)
    return np.array([xs.mean(), ys.mean()]), (xs.max() - xs.min()) / 2.0, src.shape[:2]


def ring_glint(folder: Path) -> np.ndarray:
    """Round 12 ("the ring a flat grey donut, not a weapon"): a four-point star of light on its polished edge, towards
    the sun, at the render's size."""
    centre, radius, (h, w) = _ring(folder)
    at = centre + np.array([-0.62, -0.62]) * radius
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = (xx - at[0]) / radius, (yy - at[1]) / radius
    arm = lambda a, b: np.clip(1.0 - np.abs(a) / 0.55, 0, 1) ** 2 * np.clip(1.0 - np.abs(b) / (0.035 + 0.05 * np.clip(1.0 - np.abs(a) / 0.55, 0, 1)), 0, 1)  # noqa: E731
    star = np.maximum(arm(u, v), arm(v, u) * 0.85)
    core = np.exp(-(u * u + v * v) / 0.004)  # (round 16: smaller, no pale disc)
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = np.array([1.0, 0.9, 0.7])  # (a hot glint)
    out[..., 3] = np.clip(np.maximum(star, core), 0, 1)
    return out


def backed(arr: np.ndarray, k: float = 0.45) -> np.ndarray:
    """A soft warm-dark glow just outside his line (round 12, QA: on the title screen the low sun sits right behind
    him, and its bright disc against his ink read as "a white rim"): it parts him from the sun, under the figure."""
    a = arr[..., 3]
    r = arr.shape[0] * 0.012
    glow = np.clip(ndimage.gaussian_filter(ndimage.grey_dilation(a, size=(3, 3)), r) * 1.6, 0.0, 1.0) * k
    out = arr.copy()
    al = a + glow * (1.0 - a)
    out[..., :3] = (arr[..., :3] * a[..., None] + np.array([0.16, 0.05, 0.04]) * (glow * (1.0 - a))[..., None]) / np.maximum(al, 1e-4)[..., None]
    out[..., 3] = al
    return out


TRAIL = np.array([0.4, 0.82, 1.0])  ## (round 17: a cold cyan again, "a coloured trail with contrast against the sunset")
_TRAIL_R16 = np.array([1.0, 0.62, 0.3])  ## the throw trail's colour (round 16: the sunset's, "a tapered additive trail
## that fades to zero, in sunset colours"; it was the steel's cold blue)


def throw_trail(folder: Path) -> np.ndarray:
    """Round 10 ("the ring floats on its own above the hand: with no motion trail it reads as a UI glitch"): a
    smear of cold light on the arc from his throwing hand to the ring (thin and faint at the hand, as wide as
    the ring and brighter at it) with a bright core and two speed lines, at the render's size."""
    from scipy.spatial import cKDTree
    src = np.asarray(Image.open(folder / "000.png"))
    points = json.loads((folder / "points.json").read_text())
    hand = np.array(points["frames"][0]["hand_r"], np.float64)
    centre, radius, _ = _ring(folder)
    d = centre - hand
    length = np.hypot(*d)
    # (round 15: the ring a hand's breadth out, so the trail is the throw's whole arc) from high behind his hand (the
    # wind-up over his shoulder), sweeping down over his forearm, out to the ring
    start = hand - d * 0.7 + np.array([0.0, -length * 1.1])
    ctrl = hand + np.array([0.0, -length * 0.45])
    t = np.linspace(0.0, 1.0, 400)[:, None]
    curve = (1 - t) ** 2 * start + 2 * (1 - t) * t * ctrl + t ** 2 * centre
    tangent = np.gradient(curve, axis=0)
    side = np.stack([tangent[:, 1], -tangent[:, 0]], -1) / np.maximum(np.hypot(*tangent.T)[:, None], 1e-6)
    h, w = src.shape[:2]
    x0, y0 = np.floor(np.minimum(np.minimum(hand, centre), curve.min(0)) - radius * 2).astype(int).clip(0)
    x1, y1 = np.ceil(np.maximum(np.maximum(hand, centre), curve.max(0)) + radius * 2).astype(int)
    x1, y1 = min(x1, w), min(y1, h)
    yy, xx = np.mgrid[y0:y1, x0:x1]
    pix = np.stack([xx.ravel(), yy.ravel()], -1).astype(np.float64)
    out = np.zeros((h, w, 4), np.float32)

    def stroke(path, width, alpha):
        dist, i = cKDTree(path).query(pix)
        k = i / (len(path) - 1)
        a = np.clip((width(k) - dist) / 2.0 + 0.5, 0.0, 1.0) * alpha(k)
        return a.reshape(yy.shape)

    tt = t[:, 0]
    # (round 14, "a flat grey-blue smear with no speed lines, glow or sharp leading edge: an undo-ghost") a blade of
    # light: needle-thin and faint at his hand, widening to a sharp, bright head at the ring, a white-hot core, a
    # cold glow round the head and three crisp speed lines
    # (round 15, "the trail a thin white hairline: a tapered arc connecting hand to ring") thicker, from the hand on
    band = stroke(curve, lambda k: radius * 0.95 * k ** 0.45, lambda k: 0.9 * k ** 0.5)  # (fading to nothing)
    core = stroke(curve, lambda k: radius * 0.3 * k ** 0.45, lambda k: k ** 0.5)
    glow = np.clip(1.0 - ndimage.distance_transform_edt(band < 0.5) / (radius * 0.35), 0.0, 1.0) ** 2
    head = np.clip(1.0 - np.hypot(xx - centre[0], yy - centre[1]) / (radius * 1.5), 0.0, 1.0)
    glow = glow * head * 0.0  # (round 15: 0.5 read as a pale disc round the ring; round 16, "a soap bubble": none)
    lines = np.zeros_like(band)
    for sgn, off, reach in ((-1.0, 1.15, (0.35, 0.9)), (1.0, 1.15, (0.3, 0.85)), (1.0, 1.75, (0.5, 0.92))):  # (k4: k0's blade streak)
        path = curve + side * (sgn * radius * off * tt ** 1.1)[:, None]
        keep = (tt > reach[0]) & (tt < reach[1])
        lines = np.maximum(lines, stroke(path[keep], lambda k: np.full_like(k, radius * 0.045), lambda k: 0.9 * np.sin(k * np.pi) ** 0.6))
    a = np.maximum(np.maximum(np.maximum(band, core), lines), glow)
    a *= np.clip((np.hypot(xx - centre[0], yy - centre[1]) - radius * 0.98) / 3.0, 0.0, 1.0)  # (not in the ring's hole)
    white = np.clip(np.maximum(core * 1.3, lines * 0.6), 0, 1)
    rgb = TRAIL + (np.array([0.92, 0.98, 1.0]) - TRAIL) * white[..., None]  # the core and the lines run white-hot
    out[y0:y1, x0:x1, :3] = rgb
    out[y0:y1, x0:x1, 3] = a
    return out


def swoosh_trail(folder: Path) -> np.ndarray:
    """(Key art k9, "a flat translucent cyan shard: a rendering glitch") the throw's trail as two spin arcs hugging the
    ring's trailing side: each a curved, tapered stroke, its outer (leading) edge a crisp white-hot line, the light
    fading inwards across it and back along it to nothing. At the render's size."""
    from scipy.spatial import cKDTree
    src = np.asarray(Image.open(folder / "000.png"))
    points = json.loads((folder / "points.json").read_text())
    hand = np.array(points["frames"][0]["hand_r"], np.float64)
    centre, radius, _ = _ring(folder)
    d = centre - hand
    back = np.arctan2(-d[1], -d[0])  # the side it came from
    h, w = src.shape[:2]
    out = np.zeros((h, w, 4), np.float32)
    for rk, wk, span, ak in ((1.28, 0.36, 150.0, 1.0), (1.62, 0.2, 110.0, 0.8)):
        th = np.radians(np.linspace(-span * 0.55, span * 0.45, 500)) + back  # tail (k 0) to head (k 1)
        curve = centre + rk * radius * np.stack([np.cos(th), np.sin(th)], -1)
        tn = np.gradient(curve, axis=0)
        tn = tn / np.maximum(np.hypot(*tn.T)[:, None], 1e-6)
        side = np.stack([tn[:, 1], -tn[:, 0]], -1)
        inner = np.sign(np.sum(side * (centre - curve), 1))  # towards the ring: behind the leading (outer) edge
        lo = np.floor(curve.min(0) - radius).astype(int).clip(0)
        hi = np.ceil(curve.max(0) + radius).astype(int)
        x0, y0 = lo
        x1, y1 = min(hi[0], w), min(hi[1], h)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        pix = np.stack([xx.ravel(), yy.ravel()], -1).astype(np.float64)
        dist, i = cKDTree(curve).query(pix)
        k = i / (len(curve) - 1)
        s_ = np.sum((pix - curve[i]) * side[i], 1) * inner[i]
        width = radius * wk * np.clip(k, 0, 1) ** 0.9 * np.clip((1.0 - k) / 0.1, 0.0, 1.0) ** 0.5
        inside = (k > 0.0) & (k < 1.0)
        outside = np.clip(1.0 + s_ / 1.6, 0.0, 1.0)
        across = np.where(s_ < 0, outside, np.clip(1.0 - s_ / np.maximum(width, 1e-3), 0.0, 1.0) ** 1.6)
        along = np.clip(k, 0, 1) ** 1.2
        a = across * along * (dist < width + 2.0) * inside
        edge = np.where(s_ < 0, outside, np.clip(1.0 - s_ / 3.0, 0.0, 1.0)) * along * (dist < width + 2.0) * inside
        a = np.maximum(a * 0.72, edge * 0.98).reshape(yy.shape) * ak
        hot = edge.reshape(yy.shape)
        a *= np.clip((np.hypot(xx - centre[0], yy - centre[1]) - radius * 0.98) / 3.0, 0.0, 1.0)
        rgb = TRAIL + (np.array([0.95, 0.99, 1.0]) - TRAIL) * np.clip(hot * 1.2, 0, 1)[..., None]
        old = out[y0:y1, x0:x1]
        al = a + old[..., 3] * (1.0 - a)
        old[..., :3] = (rgb * a[..., None] + old[..., :3] * old[..., 3:4] * (1.0 - a[..., None])) / np.maximum(al, 1e-4)[..., None]
        old[..., 3] = al
    return out


def save(arr: np.ndarray, name: str, pad: int = 8) -> None:
    h, w = arr.shape[:2]
    out = np.zeros((h + pad * 2, w + pad * 2, 4), np.float32)
    out[pad:pad + h, pad:pad + w] = arr
    out = bleed(out)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(OUT / name, optimize=True)
    print(name, out.shape[1], out.shape[0])


def grounded(arr: np.ndarray, airborne: bool = False, strength: float = 1.0, tight: float = 1.0) -> np.ndarray:
    """A figure on the ground (hero pass 2: "floats, no contact shadow"): a wide soft pool of warm-dark
    shade under him and a tight dark contact where his boots (or his seat) touch the ground."""
    h, w = arr.shape[:2]
    extra = int(h * (0.1 if airborne else 0.06))
    out = np.zeros((h + extra, w, 4), np.float32)
    a = arr[..., 3]
    rows = np.nonzero(a.max(1) > 0.5)[0]
    bottom = rows.max() if rows.size else h - 1
    band = a[max(0, bottom - int(h * 0.035)):bottom + 1] > 0.5  # what touches the ground
    cols = np.nonzero(band.any(0))[0]
    cx = cols.mean() if cols.size else w / 2
    span = (cols.max() - cols.min()) if cols.size else w * 0.4
    yy, xx = np.mgrid[0:out.shape[0], 0:w]
    gy = bottom + h * (0.05 if airborne else 0.004)  # (a leap: the shadow on the ground below him)
    # (round 14, the character judge: "banded into concentric rings, like a puddle") one soft occlusion blob: a wide
    # gaussian falloff under him and a tighter, darker one where he touches the ground, no edge anywhere
    rx, ry = (span * 0.55 + w * 0.08) * (0.85 + 0.15 * strength), h * 0.028 * strength
    pool = np.exp(-((xx - cx) / rx) ** 2 * 2.2 - ((yy - gy) / ry) ** 2 * 2.2) * min(0.42 * strength, 0.75)
    contact = np.zeros((out.shape[0], w), np.float32)
    foot = band.any(0).astype(np.float32)
    contact[int(gy) - 1:int(gy) + 2, :] = foot[None, :]
    contact = ndimage.gaussian_filter(contact, ((h * 0.008 + 1.5) * tight, (h * 0.016 + 1.5) * tight))
    contact = np.clip(contact / max(contact.max(), 1e-6), 0, 1) * min((0.3 if airborne else 0.62) * strength, 0.9 if tight >= 1.0 else 0.96)
    shade = 1.0 - (1.0 - pool) * (1.0 - contact)
    out[..., :3] = np.array([0.1, 0.045, 0.04])
    out[..., 3] = shade
    fa = a[..., None]
    top = out[:h]
    top[..., :3] = arr[..., :3] * fa + top[..., :3] * (1 - fa)
    top[..., 3:4] = fa + top[..., 3:4] * (1 - fa)
    return out


WIN_AIRBORNE = True  ## (hero pass 4: the win is a leap: his shadow on the ground below, softer)
WIN_SHADOW = False  ## (round 15) none under the leap
MENU_RIM = (np.array([1.0, 0.6, 0.2]), 0.8, 1.15, 0.9)  ## (key art k8, "no hot rim on the sun side, the front the brightest
## part") a hot band inside his silhouette on the edges towards the sun (upper left): colour, strength, width, fall
MENU_INK = 0.78  ## (k10: 0.62, "thin or missing along the torso and arm edges")  ## the menu picture's outline, a share of the others' (key art k6: "a sticker outline")
MENU_PIXELS = 550000  ## the menu picture's pixel budget (with its padding and shadow: no more than round 6's 0.61 Mpx)


def pictures() -> None:
    """The pictures the interface shows, each lit by its screen's own light (the sunset rim from
    behind, the warm bounce: tools/art/blender/hero_render.py --light sunset): the menu's hero (full
    length, mid-throw, a ring leaving his hand on a trail of cold light), the portrait (the same, head to hips, the size the
    menu and cards expect), the win card's cheer, the game over's defeat (down on one knee, a hand
    on the ground). (Round 9: the turnaround stands, drawn nowhere, are gone.)"""
    ui = RENDER.parent / "render_ui"
    hero = trimmed(ui / "menu_hero/000.png", 1100, sunset=True)
    # a wide pose: as many pixels as an upright one, its ink drawn at that size (round 11: reduced after inking,
    # the line went soft and uneven)
    k = min((MENU_PIXELS / (hero.shape[0] * hero.shape[1])) ** 0.5, 1.0)
    menu = trimmed(ui / "menu_hero/000.png", int(round(1100 * k)), sunset=True, under=swoosh_trail(ui / "menu_hero"),
                   ink_k=MENU_INK, clean=True, ink_lit=1.0, ink_mix=0.85)  # (k10, "the outline flickers": one dark line)  # (key art k9, the user: "remove the sun reflect on the
    # character": no rim band, no glint from the sun on the ring, an even line all round)
    save(grounded(menu, strength=2.0, tight=0.4), "hero_menu.png")  # (k11, "a weak contact shadow": darker, tighter)  # (key art k8, "no contact shadow under either boot": a darker, tighter contact)  # (key art k5: no glow round him, "a dark soft halo"; a firmer contact shadow)  # (k2: "no contact shadow under the boots")
    # the portrait: 660 x 752 from his hair to his hips (round 16: from its own render, standing, his face to us)
    if (ui / "portrait/000.png").exists():
        hero = trimmed(ui / "portrait/000.png", 1100, sunset=True)
    h, w = hero.shape[:2]
    crop_h = int(h * 0.56)
    crop_w = int(crop_h * 660 / 752)
    top = np.nonzero(hero[: h // 4, :, 3] > 0.5)[1]  # centred on his head and shoulders
    x0 = max(0, min(w - crop_w, int(top.mean()) - crop_w // 2))
    bust = np.zeros((crop_h, crop_w, 4), np.float32)
    part = hero[:crop_h, x0:x0 + crop_w]
    bust[:part.shape[0], :part.shape[1]] = part
    img = Image.fromarray((bust * 255.0 + 0.5).astype(np.uint8), "RGBA")
    arr = premultiplied_resize(img, 752 / crop_h)
    full = np.zeros((752, 660, 4), np.float32)
    full[:min(752, arr.shape[0]), :min(660, arr.shape[1])] = arr[:752, :660]
    if os.environ.get("PORTRAIT") == "1":  # (round 11: kept as it was unless asked: UX's badge is cut from it)
        save(full, "portrait.png", pad=0)
    # (round 15, "the disc shadow far below his feet": the leap with no shadow at all; the win card's glow is his ground)
    win = trimmed(ui / "win_front/000.png", 900, sunset=True)
    save(grounded(win, airborne=WIN_AIRBORNE) if WIN_SHADOW else win, "hero_win.png")
    save(grounded(trimmed(ui / "defeat/000.png", 640, sunset=True), strength=1.35), "hero_defeat.png")  # (round 14, "floats with no ground or shadow")


if __name__ == "__main__":
    main()
    pictures()
