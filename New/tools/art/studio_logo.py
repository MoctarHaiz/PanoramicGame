#!/usr/bin/env python3
"""The Haiz Studio logo (boot screen, About), from the studio's own 2017 file
(Old/app/src/main/assets/HaizStudio.png): cropped to the logo (the file is mostly empty margin),
upscaled x4 with Real-ESRGAN without halos (colour bled under transparent pixels first, alpha
upscaled separately and firmed), then reduced to 1200 px wide: sharp on an iPad's boot screen.

    python3 tools/art/studio_logo.py
"""
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT.parent / "Old/app/src/main/assets/HaizStudio.png"
OUT = ROOT / "assets/art/haiz_studio.png"
MODELS = ROOT / "tools/art/models"
WIDTH = 1200


def bleed(rgba: np.ndarray) -> np.ndarray:
    """Copies the colour of the nearest opaque pixel under every transparent one."""
    solid = rgba[..., 3] > 8
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    out = rgba.copy()
    out[..., :3] = rgba[iy, ix, :3]
    return out


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    l, t, r, b = img.getbbox()
    img = img.crop((max(l - 8, 0), max(t - 8, 0), min(r + 8, img.width), min(b + 8, img.height)))
    a = bleed(np.asarray(img))
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp, "in.png"), Path(tmp, "out.png")
        Image.fromarray(a[..., :3], "RGB").save(src)
        subprocess.run([str(MODELS / "realesrgan-ncnn-vulkan"), "-i", str(src), "-o", str(dst), "-n",
                        "realesrgan-x4plus-anime", "-m", str(MODELS / "esrgan")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rgb = Image.open(dst).convert("RGB")
    alpha = Image.fromarray(a[..., 3], "L").resize(rgb.size, Image.LANCZOS)
    al = np.asarray(alpha).astype(np.float32) / 255.0
    al = np.clip((al - 0.5) * 1.6 + 0.5, 0, 1)  # firm the soft upscaled edge
    big = Image.fromarray(np.dstack([np.asarray(rgb), (al * 255 + 0.5).astype(np.uint8)]), "RGBA")
    k = WIDTH / big.width
    big.resize((WIDTH, round(big.height * k)), Image.LANCZOS).save(OUT, optimize=True)
    print(OUT, WIDTH, round(big.height * k))


if __name__ == "__main__":
    main()
