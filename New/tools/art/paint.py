"""Shared painting helpers for the world art generators (numpy + scipy + Pillow, all free and local).

The look of the world follows the hero sheet: soft painted forms, a warm key light from the upper
left, a warm rim, cool violet shade, and air (haze) between the layers. These helpers give every
generator the same tools: tileable value noise, blurs that wrap left to right (for strips that
repeat), supersampled masks, lighting from a blurred height field, colour ramps, and dithered
saving (no banding in the big soft gradients).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "assets/art/world"
LIGHT = np.array([-0.55, -0.75, 0.62])  # towards the light: upper left, a little in front
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def ramp(t: np.ndarray, stops: list) -> np.ndarray:
    """Colour of t (any shape, 0..1) along stops [(pos, '#hex' or rgb), ...]."""
    t = np.clip(np.asarray(t, float), 0, 1)
    pos = np.array([p for p, _ in stops])
    cols = np.array([hexc(c) if isinstance(c, str) else np.asarray(c, float) for _, c in stops])
    out = np.empty(t.shape + (3,))
    for ch in range(3):
        out[..., ch] = np.interp(t, pos, cols[:, ch])
    return out


def mix(a, b, t):
    """a + (b - a) * t; a scalar field t is applied to every colour channel."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    t = np.asarray(t, float)
    colour = a.shape[-1:] == (3,) or b.shape[-1:] == (3,)
    if t.ndim and colour and t.shape[-1] not in (1, 3):
        t = t[..., None]
    return a + (b - a) * t


def smooth(e0: float, e1: float, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def value_noise(h: int, w: int, cy: int, cx: int, rng: np.random.Generator,
                wrap_x: bool = True, wrap_y: bool = False) -> np.ndarray:
    """Smooth value noise, cx cells across and cy down; tiles left to right when wrap_x."""
    gx = cx if wrap_x else cx + 1
    gy = cy if wrap_y else cy + 1
    grid = rng.random((gy, gx))
    x = np.arange(w) * cx / w
    y = np.arange(h) * cy / h
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = x - x0
    fy = y - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1 = (x0 + 1) % gx if wrap_x else np.minimum(x0 + 1, gx - 1)
    y1 = (y0 + 1) % gy if wrap_y else np.minimum(y0 + 1, gy - 1)
    x0 = x0 % gx
    y0 = y0 % gy
    a = grid[y0][:, x0] * (1 - fx) + grid[y0][:, x1] * fx
    b = grid[y1][:, x0] * (1 - fx) + grid[y1][:, x1] * fx
    return a * (1 - fy)[:, None] + b * fy[:, None]


def fbm(h: int, w: int, cy: int, cx: int, octaves: int, rng: np.random.Generator,
        wrap_x: bool = True, wrap_y: bool = False, gain: float = 0.5) -> np.ndarray:
    out = np.zeros((h, w))
    amp = total = 0.0
    amp = 1.0
    for o in range(octaves):
        out += value_noise(h, w, max(1, cy * 2 ** o), max(1, cx * 2 ** o), rng, wrap_x, wrap_y) * amp
        total += amp
        amp *= gain
    return out / total


def noise1(n: int, cells: int, rng: np.random.Generator, octaves: int = 4, gain: float = 0.5) -> np.ndarray:
    """1-D periodic fbm over n samples (a skyline, a ridge)."""
    return fbm(1, n, 1, cells, octaves, rng, True, False, gain)[0]


def blur(a: np.ndarray, sigma, wrap_x: bool = False) -> np.ndarray:
    if np.isscalar(sigma):
        sigma = (sigma, sigma)
    if a.ndim == 3:
        return np.dstack([blur(a[..., i], sigma, wrap_x) for i in range(a.shape[2])])
    return ndimage.gaussian_filter(a, sigma, mode=("nearest", "wrap" if wrap_x else "nearest"))


def normals_light(height: np.ndarray, strength: float = 1.0, light: np.ndarray = LIGHT) -> np.ndarray:
    """Lambert lighting (0..1) of a height field seen from the front, lit from the upper left."""
    gy, gx = np.gradient(height * strength)
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return np.clip(n @ light, 0, 1)


def poly_mask(w: int, h: int, polys: list, ss: int = 4, ellipses: list = (), lines: list = ()) -> np.ndarray:
    """Antialiased coverage (0..1) of polygons [(x, y), ...], ellipses (cx, cy, rx, ry) and lines
    ((x0, y0, x1, y1), width) in pixel units, drawn at ss x and averaged."""
    img = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(img)
    for p in polys:
        d.polygon([(x * ss, y * ss) for x, y in p], fill=255)
    for cx, cy, rx, ry in ellipses:
        d.ellipse([(cx - rx) * ss, (cy - ry) * ss, (cx + rx) * ss, (cy + ry) * ss], fill=255)
    for (x0, y0, x1, y1), lw in lines:
        d.line([(x0 * ss, y0 * ss), (x1 * ss, y1 * ss)], fill=255, width=max(1, int(lw * ss)))
    return downsample(np.asarray(img, float) / 255.0, ss)


def downsample(a: np.ndarray, ss: int) -> np.ndarray:
    h, w = a.shape[0] // ss, a.shape[1] // ss
    if a.ndim == 3:
        return a[:h * ss, :w * ss].reshape(h, ss, w, ss, a.shape[2]).mean(axis=(1, 3))
    return a[:h * ss, :w * ss].reshape(h, ss, w, ss).mean(axis=(1, 3))


def dither_rgba(rgb: np.ndarray, alpha: np.ndarray, rng: np.random.Generator | None = None) -> Image.Image:
    """8-bit RGBA with triangular dither (no banding in soft gradients). Colour under fully
    transparent pixels is bled from the nearest painted pixel so filtering shows no dark halo."""
    rng = rng or np.random.default_rng(0)
    a = np.clip(alpha, 0, 1)
    rgb = bleed(rgb, a)
    d = (rng.random(rgb.shape) - rng.random(rgb.shape))
    out = np.clip(rgb + d, 0, 255)
    da = (rng.random(a.shape) - rng.random(a.shape)) * (a > 0.002) * (a < 0.998)
    aa = np.clip(a * 255 + da, 0, 255)
    return Image.fromarray(np.dstack([out, aa]).round().astype(np.uint8), "RGBA")


def bleed(rgb: np.ndarray, alpha: np.ndarray, threshold: float = 0.02) -> np.ndarray:
    """Fills colour under transparent pixels with the colour of the nearest opaque one."""
    solid = alpha > threshold
    if solid.all() or not solid.any():
        return rgb
    idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    filled = rgb[idx[0], idx[1]]
    return np.where(solid[..., None], rgb, filled)


def save(img: Image.Image, name: str) -> Path:
    WORLD.mkdir(parents=True, exist_ok=True)
    p = WORLD / name
    img.save(p, optimize=True)
    return p


def grain(shape, rng: np.random.Generator, amount: float = 3.0) -> np.ndarray:
    """Fine painterly grain in colour units, a little softened."""
    g = blur(rng.standard_normal(shape[:2]), 0.6)
    return (g / (g.std() + 1e-6) * amount)[..., None]


def strokes(h: int, w: int, rng: np.random.Generator, length: float = 40.0, width: float = 3.0,
            angle: float = 0.0, wrap_x: bool = True) -> np.ndarray:
    """A field of soft anisotropic brush marks (-1..1): noise stretched along `angle` (radians)."""
    n = rng.standard_normal((h, w))
    s = ndimage.gaussian_filter(n, (width, width), mode=("nearest", "wrap" if wrap_x else "nearest"))
    if angle == 0.0:
        s = ndimage.gaussian_filter1d(s, length / 2.5, axis=1, mode="wrap" if wrap_x else "nearest")
    else:
        s = ndimage.rotate(s, np.degrees(angle), reshape=False, mode="reflect")
        s = ndimage.gaussian_filter1d(s, length / 2.5, axis=1, mode="reflect")
        s = ndimage.rotate(s, -np.degrees(angle), reshape=False, mode="reflect")
    return s / (np.abs(s).max() + 1e-6)
