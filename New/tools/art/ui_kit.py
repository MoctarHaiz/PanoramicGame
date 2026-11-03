#!/usr/bin/env python3
"""Textures of the interface kit (numpy + Pillow).

    python3 tools/art/ui_kit.py      # assets/art/ui/paper.png

- paper.png: a seamless warm paper/hide grain (256 x 256, tiles both ways), near white: the panels
  multiply their cream by it, so the body reads as a material, not a flat fill. Soft mottling, fine
  fibres running mostly across, a few darker flecks.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from paint import fbm  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui"


def paper(size: int = 256) -> Image.Image:
    rng = np.random.default_rng(5)
    mottle = fbm(size, size, 4, 4, 4, rng, wrap_x=True, wrap_y=True)
    fibres = ndimage.gaussian_filter(rng.standard_normal((size, size)), (0.6, 5.0), mode="wrap")
    fibres /= np.abs(fibres).max()
    flecks = ndimage.gaussian_filter((rng.random((size, size)) > 0.9975).astype(float), 0.8, mode="wrap")
    flecks /= max(flecks.max(), 1e-6)
    v = 0.955 + (mottle - 0.5) * 0.09 + fibres * 0.03 - flecks * 0.16
    v = np.clip(v, 0.0, 1.0)
    rgb = np.dstack([v, v * 0.985, v * 0.96]) * 255.0
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    paper().save(OUT / "paper.png", optimize=True)
    print("paper.png (256, 256)")


if __name__ == "__main__":
    main()
