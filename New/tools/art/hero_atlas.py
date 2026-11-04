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

    python3 tools/art/hero_atlas.py [RENDER_DIR]   # default ROOT/_agents/AAA/hero3d/render/p4/game

(The AAA hero: rendered by hero_render.py from ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend, see
ROOT/_agents/AAA/hero3d/render/render_all.sh; the interface pictures come from RENDER_DIR/../render_ui.)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())  # the folder with the user's Blender files
RENDER = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/AAA/hero3d/render/p4/game"
GROUND_SPEED = 8.0 * 960.0 / 1320.0 * 40.0  ## units a second the ground scrolls (World.SCROLL_SPEED)
OUT = NEW / "assets/art/hero"
SCALE = 0.40  ## render px -> atlas px (1024 renders: he stands ~690 px, ~276 px in the atlas; the ink line costs a little room)
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
INK_PX = 2.8  ## atlas px of ink round his outer silhouette (pass 3: 1.6 -> 2.2, "almost no value contrast against the sky")
INK_PX_UI = 2.8  ## the same, scaled to the interface pictures (as before)


SUN = np.array([-0.6, -0.8])  ## towards the sun on screen (x right, y down): upper left, as in the world
RIM_PX = 3.4  ## atlas px of the hot rim on the sun side (hero pass 2: "a thick hot band, not a thin line")
RIM_DAY = (np.array([1.0, 0.6, 0.24]), 0.55)  ## colour, strength (screen blend)
RIM_SUNSET = (np.array([1.0, 0.48, 0.12]), 0.75)


def sun_rim(arr: np.ndarray, px: float = RIM_PX, rim=RIM_DAY, dark: float = 0.22) -> np.ndarray:
    """A thick hot band inside the silhouette, only on the edges that face the sun (the shadow side's
    edges keep the dark of the form: no pale fringe inside the ink). Applied before inked(). `dark`: how
    much of the band the darkest colours take (his black hair: a faint sheen; 1: all, the dark bandit)."""
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
    band = (t ** 1.6) * f * inside * rim[1]  # strongest at the edge, a soft fall into the form
    lum = arr[..., :3] @ np.array([0.3, 0.59, 0.11])
    band = band * (dark + (1.0 - dark) * np.clip(lum / 0.4, 0.0, 1.0))  # the black hair stays black (a faint warm sheen)
    rgb = arr[..., :3]
    # (pass 3) towards the hot colour, not a screen blend: white fur and boot trim turn warm, never paler
    # ("pale whitish edges, halos"); skin and scarf brighten into it
    lit = rgb + (rim[0][None, None, :] - rgb) * band[..., None]
    out = arr.copy()
    out[..., :3] = lit
    return out


def inked(arr: np.ndarray, px: float = INK_PX) -> np.ndarray:
    """A frame with a thicker ink line round its outer silhouette (anti-aliased), under the figure:
    the cel look's outline reads against the pale sky at phone size, inside lines stay thin."""
    a = arr[..., 3]
    d = ndimage.distance_transform_edt(a < 0.5)
    ring = np.clip(px + 0.5 - d, 0.0, 1.0)
    out = np.zeros_like(arr)
    out[..., :3] = INK
    out[..., 3] = ring
    fa = a[..., None]
    out[..., :3] = arr[..., :3] * fa + out[..., :3] * (1.0 - fa)
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
            arr = inked(sun_rim(premultiplied_resize(Image.open(files[i]), k)))
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


def trimmed(path: Path, height: int, sunset: bool = False) -> np.ndarray:
    """A render cut to what it shows and reduced to `height` px."""
    img = Image.open(path).convert("RGBA")
    box = img.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox()
    img = img.crop(box)
    arr = premultiplied_resize(img, height / img.height)
    pad = np.zeros((arr.shape[0] + 8, arr.shape[1] + 8, 4), np.float32)
    pad[4:-4, 4:-4] = arr
    pad = sun_rim(pad, RIM_PX * height / 300.0, RIM_SUNSET if sunset else RIM_DAY)
    return inked(pad, INK_PX_UI * height / 300.0)  # (as thick, for its size, as in the game before pass 3)


def save(arr: np.ndarray, name: str, pad: int = 8) -> None:
    h, w = arr.shape[:2]
    out = np.zeros((h + pad * 2, w + pad * 2, 4), np.float32)
    out[pad:pad + h, pad:pad + w] = arr
    out = bleed(out)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(OUT / name, optimize=True)
    print(name, out.shape[1], out.shape[0])


def grounded(arr: np.ndarray, airborne: bool = False) -> np.ndarray:
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
    rx, ry = span * 0.58 + w * 0.1, h * 0.03
    pool = np.clip(1.0 - ((xx - cx) / rx) ** 2 - ((yy - gy) / ry) ** 2, 0.0, 1.0) ** 1.4 * 0.5
    contact = np.zeros((out.shape[0], w), np.float32)
    foot = band.any(0).astype(np.float32)
    contact[int(gy) - 1:int(gy) + 2, :] = foot[None, :]
    contact = ndimage.gaussian_filter(contact, (h * 0.006 + 1.0, h * 0.01 + 1.0))
    contact = np.clip(contact / max(contact.max(), 1e-6), 0, 1) * (0.3 if airborne else 0.72)
    shade = 1.0 - (1.0 - pool) * (1.0 - contact)
    out[..., :3] = np.array([0.1, 0.045, 0.04])
    out[..., 3] = shade
    fa = a[..., None]
    top = out[:h]
    top[..., :3] = arr[..., :3] * fa + top[..., :3] * (1 - fa)
    top[..., 3:4] = fa + top[..., 3:4] * (1 - fa)
    return out


WIN_AIRBORNE = True  ## (hero pass 4: the win is a leap: his shadow on the ground below, softer)
MENU_PIXELS = 550000  ## the menu picture's pixel budget (with its padding and shadow: no more than round 6's 0.61 Mpx)


def pictures() -> None:
    """The pictures the interface shows, each lit by its screen's own light (the sunset rim from
    behind, the warm bounce: tools/art/blender/hero_render.py --light sunset): the menu's hero (full
    length, mid-throw, a ring leaving his hand), the portrait (the same, head to hips, the size the
    menu and cards expect), the win card's cheer, the game over's defeat (down on one knee, a hand
    on the ground). (Round 9: the turnaround stands, drawn nowhere, are gone.)"""
    ui = RENDER.parent / "render_ui"
    hero = trimmed(ui / "menu_hero/000.png", 1100, sunset=True)
    menu = hero
    if hero.shape[0] * hero.shape[1] > MENU_PIXELS:  # a wide pose: as many pixels as an upright one
        k = (MENU_PIXELS / (hero.shape[0] * hero.shape[1])) ** 0.5
        img = Image.fromarray((np.clip(hero, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
        menu = premultiplied_resize(img, k)
    save(grounded(menu), "hero_menu.png")
    # the portrait: 660 x 752 from his hair to his hips
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
    save(full, "portrait.png", pad=0)
    save(grounded(trimmed(ui / "win_front/000.png", 900, sunset=True), airborne=WIN_AIRBORNE), "hero_win.png")
    save(grounded(trimmed(ui / "defeat/000.png", 640, sunset=True)), "hero_defeat.png")


if __name__ == "__main__":
    main()
    pictures()
