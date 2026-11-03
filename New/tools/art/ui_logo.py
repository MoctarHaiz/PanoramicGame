#!/usr/bin/env python3
"""The CHAKA ZULU logo, rendered (numpy + Pillow): letters and emblem with real bevels, lit from the
upper left like the 3D hero, so the title belongs with him.

    python3 tools/art/ui_logo.py      # assets/art/ui/logo.png (replaces the flat SVG one of logo.py)

- An isihlangu shield of cowhide (cream, dark brown patches, dark leather laces threaded down its
  middle, its stick through it with a tuft of fur at the top) stands whole at the left of the words,
  one long assegai leaning behind it; the shield's rim is bevelled and catches the light.
- CHAKA over ZULU in Fredoka (assets/fonts, SIL OFL) at its boldest and a little wide: a gold face
  (pale yellow at the top to deep orange at the foot) with a rounded bevel (normals from the letters'
  distance field: lit top-left edges, shaded bottom-right ones, a hot specular), a thin light line
  inside a thick dark brown outline, an extruded depth, and a soft drop shadow under the whole.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui/logo.png"
FONT = ROOT / "assets/fonts/Fredoka.ttf"
SS = 2  # drawn at twice the size, then halved (smooth edges)
W, H = 1560, 760  # final size in px: the emblem beside the words, one mark
LIGHT = np.array([-0.5, -0.7, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
INK = np.array([46, 13, 4], float)


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def ramp(t, stops):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    pos = [p for p, _ in stops]
    cols = [hexc(c) for _, c in stops]
    for ch in range(3):
        out[..., ch] = np.interp(t, pos, [c[ch] for c in cols])
    return out


def dist_in(mask: np.ndarray) -> np.ndarray:
    return ndimage.distance_transform_edt(mask > 0.5)


def grow(mask: np.ndarray, r: float) -> np.ndarray:
    """The mask grown by r px (soft edge)."""
    d = ndimage.distance_transform_edt(mask < 0.5)
    return np.clip(r + 0.5 - d, 0, 1)


def shade(mask: np.ndarray, bevel: float, strength: float = 1.0) -> tuple:
    """Lighting of a rounded bevel `bevel` px wide: (diffuse 0..1, specular 0..1)."""
    d = np.minimum(dist_in(mask), bevel) / bevel
    h = np.sqrt(1 - (1 - d) ** 2) * bevel * strength
    h = ndimage.gaussian_filter(h, 1.0)
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    diffuse = np.clip(n @ LIGHT, 0, 1)
    half = LIGHT + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    spec = np.clip(n @ half, 0, 1) ** 40
    return diffuse, spec


def text_mask(text: str, size: int, width_axis: float = 112) -> np.ndarray:
    font = ImageFont.truetype(str(FONT), size)
    font.set_variation_by_axes([700, width_axis])
    box = font.getbbox(text)
    img = Image.new("L", (box[2] - box[0] + 40, box[3] - box[1] + 40), 0)
    ImageDraw.Draw(img).text((20 - box[0], 20 - box[1]), text, font=font, fill=255)
    return np.asarray(img, float) / 255.0


def paste(canvas: np.ndarray, mask: np.ndarray, cx: float, cy: float) -> None:
    h, w = mask.shape
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    canvas[y0:y0 + h, x0:x0 + w] = np.maximum(canvas[y0:y0 + h, x0:x0 + w], mask)


def poly(points, w, h) -> np.ndarray:
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in points], fill=255)
    return np.asarray(img, float) / 255.0


def over(dst_rgb, dst_a, src_rgb, src_a):
    a = src_a[..., None]
    out_a = src_a + dst_a * (1 - src_a)
    rgb = (src_rgb * a + dst_rgb * dst_a[..., None] * (1 - a)) / np.maximum(out_a[..., None], 1e-6)
    return rgb, out_a


def shield_layers(w: int, h: int, cx: float, cy: float, sh: float):
    """The shield, its stick and an assegai behind it: [(rgb, alpha), ...] back to front."""
    layers = []
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # one long assegai behind, leaning right: a wooden shaft, a bound grip, a long iron leaf blade
    # with a ridge down its middle (one, not two: two blades either side read as ears)
    ang = -0.42  # leaning left, away from the words
    d = np.array([np.sin(ang), -np.cos(ang)])
    n = np.array([d[1], -d[0]])
    u = (xx - cx) * d[0] + (yy - cy) * d[1]
    v = (xx - cx) * n[0] + (yy - cy) * n[1]
    shaft = (np.abs(v) < sh * 0.02) & (u > -sh * 0.62) & (u < sh * 0.42)
    blade_u = (u - sh * 0.42) / (sh * 0.3)
    leaf = np.sin(np.clip(blade_u, 0, 1) ** 0.55 * np.pi)  # widest near its foot, a sharp point
    blade = (blade_u >= 0) & (blade_u <= 1) & (np.abs(v) < sh * 0.05 * leaf)
    m = ndimage.gaussian_filter((shaft | blade).astype(float), 1.0)
    diff, spec = shade(m, sh * 0.03)
    wood = ramp((v / (sh * 0.04)) * 0.5 + 0.5, [(0, "d8995a"), (0.5, "a8622e"), (1, "6a3414")])
    iron = ramp((v / (sh * 0.1)) * 0.5 + 0.5, [(0, "ffffff"), (0.48, "c4ccd8"), (0.52, "6a7280"), (1, "8a94a2")])
    rgb = np.where(blade[..., None], iron, wood) * (0.55 + 0.6 * diff[..., None]) + spec[..., None] * 255
    grip = shaft & (np.abs(u - sh * 0.42) < sh * 0.07) & (np.sin(u * 0.8) > 0)
    rgb = np.where(grip[..., None], hexc("e8d8b0") * (0.6 + 0.5 * diff[..., None]), rgb)
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(m, sh * 0.014)))
    layers.append((rgb, m))
    # the shield's stick, through it from top to bottom, a tuft of fur at its top
    stick = (np.abs(xx - cx) < sh * 0.022) & (yy > cy - sh * 0.62) & (yy < cy + sh * 0.58)
    tuft_r = np.hypot((xx - cx) / (sh * 0.05), (yy - (cy - sh * 0.64)) / (sh * 0.07))
    tuft = tuft_r < 1 + 0.25 * np.sin(np.arctan2(yy - (cy - sh * 0.64), xx - cx) * 7)
    m = ndimage.gaussian_filter((stick | tuft).astype(float), 1.0)
    diff, spec = shade(m, sh * 0.025)
    stick_rgb = ramp(((xx - cx) / (sh * 0.044)) * 0.5 + 0.5, [(0, "c88a50"), (0.5, "8a4e24"), (1, "4a2410")])
    rgb = np.where(tuft[..., None], hexc("2a1a14"), stick_rgb) * (0.55 + 0.6 * diff[..., None]) + spec[..., None] * 160
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(m, sh * 0.014)))
    layers.append((rgb, m))
    # the shield: a tall oval of cowhide, pointed at both ends
    t = (yy - cy) / (sh * 0.5)
    half_w = sh * 0.25 * np.clip(1 - np.abs(t) ** 1.6, 0, 1) ** 0.72
    oval = ndimage.gaussian_filter(((np.abs(xx - cx) < half_w) & (np.abs(t) < 1)).astype(float), 1.0)
    diff, spec = shade(oval, sh * 0.08, 1.3)
    rng = np.random.default_rng(3)
    hide = ramp(t * 0.5 + 0.5, [(0, "fff8ea"), (0.6, "f2e2c4"), (1, "dcc096")])
    patches = np.zeros((h, w))
    for px, py, r in ((-0.6, -0.42, 0.44), (0.62, -0.02, 0.4), (-0.5, 0.42, 0.38), (0.55, 0.64, 0.3), (0.6, -0.64, 0.28)):
        ex, ey = cx + px * sh * 0.25, cy + py * sh * 0.5
        rr = np.hypot((xx - ex) / (r * sh * 0.28), (yy - ey) / (r * sh * 0.4))
        wob = 1 + 0.18 * np.sin(np.arctan2(yy - ey, xx - ex) * 5 + px * 7)
        patches = np.maximum(patches, np.clip((wob - rr) * 8, 0, 1))
    hair = ndimage.gaussian_filter(rng.standard_normal((h, w)), (6, 0.8)) * 6
    hide = hide * (1 - patches[..., None]) + hexc("3a1c10")[None, None] * patches[..., None]
    hide += hair[..., None]
    # the lacing down the middle: a band of darker hide, dark leather laces threaded across it
    band = np.abs(xx - cx) < sh * 0.05
    hide = np.where(band[..., None], hexc("c9a272"), hide)
    row = (yy - cy) / (sh * 0.07)
    lace = band & (np.abs(row - np.round(row)) < 0.16) & (np.abs(xx - cx) < sh * 0.042)
    lace_lit = band & (np.abs(row - np.round(row) + 0.12) < 0.05) & (np.abs(xx - cx) < sh * 0.036)
    hide = np.where(lace[..., None], hexc("4a2210"), hide)
    hide = np.where(lace_lit[..., None], hexc("9a6038"), hide)
    edge = band & (np.abs(np.abs(xx - cx) - sh * 0.05) < 2.0)
    hide = np.where(edge[..., None], hexc("6a3a1c"), hide)
    rgb = hide * (0.5 + 0.62 * diff[..., None]) + spec[..., None] * 180
    # the rim: a darker hide edge, as if the skin were folded over a frame
    rim = np.clip(1 - dist_in(oval) / (sh * 0.025), 0, 1)
    rgb = rgb * (1 - rim[..., None] * 0.45)
    layers.append((np.broadcast_to(INK, rgb.shape).copy(), grow(oval, sh * 0.018)))
    layers.append((rgb, oval))
    return layers


def text_layers(w: int, h: int, lines: list, cx: float) -> tuple:
    """CHAKA over ZULU, centred on x = cx: (layers back to front, the letters' mask)."""
    m = np.zeros((h, w))
    tops = []
    for text, size, cy in lines:
        tm = text_mask(text, size)
        paste(m, tm, cx, cy)
        tops.append((cy, size))
    m = ndimage.gaussian_filter(m, 0.7)
    ow = h * 0.022  # the outline's width
    depth = h * 0.034
    outline = grow(m, ow)
    layers = []
    # the drop shadow and the extruded depth under the outline
    shadow = ndimage.gaussian_filter(ndimage.shift(outline, (depth + h * 0.02, h * 0.006)), h * 0.012)
    layers.append((np.zeros((h, w, 3)), shadow * 0.45))
    steps = int(depth)
    for s in range(steps, 0, -1):
        sm = ndimage.shift(outline, (s, 0), order=1)
        k = s / steps
        layers.append((np.broadcast_to(INK * (0.9 + 0.5 * (1 - k)) + np.array([30, 6, 0]) * (1 - k), (h, w, 3)).copy(), sm))
    layers.append((np.broadcast_to(INK, (h, w, 3)).copy(), outline))
    # a thin warm light line just inside the outline
    layers.append((np.broadcast_to(hexc("ffe9b0"), (h, w, 3)).copy(), grow(m, ow * 0.28)))
    # the gold face: each line its own gradient, a bevel, a hot specular, a gloss band on top
    yy = np.mgrid[0:h, 0:w][0].astype(float)
    grad = np.zeros((h, w))
    for cy, size in tops:
        top, bottom = cy - size * 0.36, cy + size * 0.36
        band = (yy > top - size * 0.2) & (yy < bottom + size * 0.2)
        grad = np.where(band, (yy - top) / (bottom - top), grad)
    face = ramp(grad, [(0.0, "fff7b0"), (0.35, "ffd84a"), (0.62, "ffab1c"), (1.0, "e8600c")])
    diff, spec = shade(m, h * 0.022, 1.6)
    rgb = face * (0.62 + 0.5 * diff[..., None]) + spec[..., None] * 230
    gloss = (grad < 0.36) & (dist_in(m) > h * 0.009)
    rgb = np.where(gloss[..., None], rgb * 0.88 + 255 * 0.12, rgb)
    layers.append((rgb, m))
    return layers, m


def main() -> None:
    w, h = W * SS, H * SS
    rgb = np.zeros((h, w, 3))
    a = np.zeros((h, w))
    cx, cy = w * 0.21, h * 0.54  # the emblem stands whole at the left of the words
    for lr, la in shield_layers(w, h, cx, cy, h * 0.78):
        rgb, a = over(rgb, a, lr, la)
    layers, _ = text_layers(w, h, [("CHAKA", int(h * 0.31), h * 0.33), ("ZULU", int(h * 0.38), h * 0.71)], w * 0.63)
    for lr, la in layers:
        rgb, a = over(rgb, a, lr, la)
    img = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8), "RGBA")
    img = img.resize((W, H), Image.LANCZOS)
    box = img.getchannel("A").getbbox()
    img = img.crop((max(box[0] - 6, 0), max(box[1] - 6, 0), min(box[2] + 6, W), min(box[3] + 6, H)))
    # colour under the clear pixels: the nearest painted one (no dark halo when scaled)
    arr = np.asarray(img).astype(float)
    solid = arr[..., 3] > 2
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    arr[..., :3] = np.where(solid[..., None], arr[..., :3], arr[..., :3][iy, ix])
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(OUT, optimize=True)
    print(f"{OUT.relative_to(ROOT)} {img.size}")


if __name__ == "__main__":
    main()
