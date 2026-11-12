#!/usr/bin/env python3
"""The bandits' palette (2026-11-12, the redesign with the user's yes; the blind judges, round after round: "a second
kid hero: his red scarf, bright teal hair; their yellow shirts melt into the gold grass").

The night raiders: cold and dark against Panoramic's warm red, white and brown, and against the gold of the plain.
Each colour of their drawings is moved by its hue, the drawing's own light and shade kept (the value and the
saturation of each pixel scaled, never flattened), so every frame of both sheets changes the same way and no line moves:

    their red scarves and capes  -> a vivid violet (their one accent: no red but his)
    their yellow shirts and gold -> a dark slate blue (dark on the gold grass)
    their teal hair              -> pale ash
    the small one's blue wrap    -> charcoal (its zigzag band stays)

    python3 tools/art/bandit_palette.py            assets/art/bandit/{bandit,bandit_strong}.png in place
    (run again after bandit_pack.py or bandit_sheet.py repack a sheet: a sheet already done does not change)
"""
import colorsys
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "assets/art/bandit"
## from hue (degrees), to hue, least saturation, least value -> new hue, saturation x, value x, (saturation at most)
RULES = [
    ("scarf", 344.0, 13.0, 0.5, 0.16, 282.0, 0.82, 1.0, 0.72),
    ("shirt", 24.0, 64.0, 0.64, 0.2, 232.0, 0.5, 0.58, 0.5),  # (their skin, the same hues, is under 0.6 of saturation)
    ("hair", 160.0, 204.0, 0.3, 0.16, 215.0, 0.16, 1.5, 0.14),
    ("wrap", 226.0, 266.0, 0.28, 0.16, 250.0, 0.3, 0.55, 0.3),
]
SOFT = 5.0  # degrees over which a rule fades in at each end of its hues


def hsv(rgb: np.ndarray) -> tuple:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.maximum(d, 1e-6), 0)
    gc = np.where(m, (mx - g) / np.maximum(d, 1e-6), 0)
    bc = np.where(m, (mx - b) / np.maximum(d, 1e-6), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = (h / 6.0) % 1.0 * 360.0
    return h, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0), mx


def rgb_of(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    i = np.floor(h / 60.0) % 6
    f = h / 60.0 - np.floor(h / 60.0)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[m] = np.stack([a[m], b[m], c[m]], axis=-1)
    return out


def recolour(path: Path) -> None:
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    rgb = im[..., :3].copy()
    h, s, v = hsv(rgb)
    out = rgb.copy()
    done = []
    for name, h0, h1, smin, vmin, to_h, ks, kv, smax in RULES:
        span = (h1 - h0) % 360.0
        along = (h - h0) % 360.0
        k = np.clip(along / SOFT, 0, 1) * np.clip((span - along) / SOFT, 0, 1)
        k *= np.clip((s - smin + 0.05) / 0.1, 0, 1) * np.clip((v - vmin + 0.04) / 0.08, 0, 1)
        new = rgb_of(np.full_like(h, to_h), np.minimum(s * ks, smax), np.clip(v * kv, 0, 1))
        out = out * (1 - k[..., None]) + new * k[..., None]
        done.append("%s %.1f%%" % (name, float((k > 0.5).mean() / max((im[..., 3] > 0.5).mean(), 1e-6)) * 100))
    res = np.dstack([out, im[..., 3]])
    Image.fromarray((res.clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print(path.name, "of the drawing:", ", ".join(done))


if __name__ == "__main__":
    for kind in ("bandit", "bandit_strong"):
        recolour(ART / (kind + ".png"))
