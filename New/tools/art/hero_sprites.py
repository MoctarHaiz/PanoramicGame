#!/usr/bin/env python3
"""Panoramic's sprites from the hero sheet the user made (tools/art/ref/user/hero_sheet.png).

Each pose is cropped from the sheet, upscaled x4 (Real-ESRGAN, anime model), cut out of the dark
background (IS-Net segmentation + edge un-mixing, tools/art/cutout.py), trimmed, and reduced to one
shared scale: the sheet's running hero (head to boots) becomes 2 x his drawn height in the game, so
every pose has the same size. assets/art/hero/hero.json lists each pose's size and its anchor
(the point the game places: the boots' contact for poses on the ground, the middle for poses in the
air, the top of the staff for hanging).

    python3 tools/art/hero_sprites.py            # every pose
    python3 tools/art/hero_sprites.py run_a leap # some poses

Free models (kept out of git, in tools/art/models/):
  isnet-general-use.onnx  https://github.com/danielgatis/rembg/releases/tag/v0.0.0
  realesrgan-ncnn-vulkan + esrgan/  https://github.com/xinntao/Real-ESRGAN/releases (macos zip)
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
import cutout  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "tools/art/ref/user/hero_sheet.png"
MODELS = ROOT / "tools/art/models"
OUT = ROOT / "assets/art/hero"
GEN = ROOT / "tools/art/gen/hero"  # raw cut-outs at x4, kept out of git

# Sheet boxes (x0, y0, x1, y1) and anchors. Sprites face right like the game.
POSES = {
    "crouch": ((20, 540, 182, 724), "feet"),
    "leap": ((190, 478, 392, 702), "center"),
    "tuck": ((455, 478, 640, 728), "center"),
    "kneel": ((678, 560, 832, 726), "feet"),
    "run_a": ((885, 480, 1075, 728), "feet"),
    "run_b": ((1100, 480, 1295, 728), "feet"),
    "leap_up": ((1310, 478, 1510, 728), "top"),
    "stand_front": ((455, 40, 662, 440), "feet"),
    "stand_side": ((918, 40, 1018, 440), "feet"),
}
REFERENCE = "run_b"  # its head-to-boots height sets the shared scale
REFERENCE_HEIGHT_UNITS = 150.0  # GameArt.HERO_DRAW_HEIGHT
TEXTURE_SCALE = 2.0  # textures at twice the drawn size: sharp on 1080p-tall phones
UPSCALE = 4


def upscale(img: Image.Image) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp, "in.png"), Path(tmp, "out.png")
        img.save(src)
        subprocess.run([str(MODELS / "realesrgan-ncnn-vulkan"), "-i", str(src), "-o", str(dst),
                        "-n", "realesrgan-x4plus-anime", "-m", str(MODELS / "esrgan")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return Image.open(dst).convert("RGB")


def cut(name: str, box: tuple) -> Image.Image:
    sheet = Image.open(SHEET).convert("RGB")
    crop = sheet.crop(box)
    big = upscale(crop)
    rgb = np.asarray(big).astype(np.float32)
    bg = np.median(np.concatenate([rgb[:6].reshape(-1, 3), rgb[:, :6].reshape(-1, 3),
                                   rgb[:, -6:].reshape(-1, 3)]), axis=0)
    alpha = cutout.segment(str(MODELS / "isnet-general-use.onnx"), big)
    alpha = np.clip((alpha - 0.10) / 0.80, 0, 1)
    # The sheet's ground shadows are dark, desaturated and flat. Only under the boots (the bottom
    # tenth of the figure) can a dark grey pixel be shadow: his hair is just as dark and grey.
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    rows = np.where((alpha > 0.5).any(1))[0]
    floor = np.zeros_like(alpha, dtype=bool)
    if len(rows):
        floor[int(rows[-1] - (rows[-1] - rows[0]) * 0.1):] = True
    shadowy = floor & (lum < np.median(lum[alpha < 0.05]) + 14) & (sat < 22)
    alpha = np.where(shadowy, 0.0, alpha)
    colour = cutout.unmix(rgb, alpha, bg)
    out = np.dstack([np.clip(colour + 0.5, 0, 255), alpha * 255 + 0.5]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    # Keep the largest blob only (stray specks of shadow, other sprites or effects).
    arr = np.asarray(img).copy()
    labels, n = ndimage.label(ndimage.binary_dilation(arr[..., 3] > 40, iterations=6))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
        arr[..., 3] = np.where(labels == 1 + int(np.argmax(sizes)), arr[..., 3], 0)
    img = Image.fromarray(arr, "RGBA")
    img = img.crop(img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())
    GEN.mkdir(parents=True, exist_ok=True)
    img.save(GEN / f"{name}.png")
    return img


def body_height(img: Image.Image) -> int:
    """Height of the opaque figure (head to boots), ignoring a staff raised above the head."""
    a = np.asarray(img)[..., 3] > 100
    rows = np.where(a.sum(1) > a.shape[1] * 0.12)[0]  # rows wide enough to be the body, not the staff
    return int(rows[-1] - rows[0]) if len(rows) else img.height


def anchor(img: Image.Image, mode: str) -> list:
    """x: the middle of his torso (rows 30-60 % down the figure), so changing pose doesn't shift
    him sideways. y: the bottom of the boots ("feet"), the torso ("center"), or the top ("top")."""
    a = np.asarray(img)[..., 3] > 100
    h, w = a.shape
    rows = np.where(a.any(1))[0]
    top, bottom = rows[0], rows[-1]
    band = a[int(top + (bottom - top) * 0.30):int(top + (bottom - top) * 0.60)]
    x = float(np.nonzero(band)[1].mean()) if band.any() else w / 2
    if mode == "feet":
        return [x, float(bottom)]
    if mode == "top":
        cols = np.where(a[: max(h // 12, 4)].any(0))[0]
        return [float(cols.mean()), 0.0]
    return [x, float(top + (bottom - top) * 0.5)]


def main(names: list) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "hero.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    cuts = {}
    for name in names or POSES:
        cuts[name] = cut(name, POSES[name][0])
        print("cut", name, cuts[name].size)
    ref = cuts.get(REFERENCE) or Image.open(GEN / f"{REFERENCE}.png")
    k = REFERENCE_HEIGHT_UNITS * TEXTURE_SCALE / body_height(ref)
    for name, img in cuts.items():
        small = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
        small.save(OUT / f"{name}.png", optimize=True)
        ax, ay = anchor(small, POSES[name][1])
        manifest[name] = {"size": list(small.size), "anchor": [round(ax, 1), round(ay, 1)],
                          "mode": POSES[name][1], "texture_scale": TEXTURE_SCALE}
        print(f"{name}: {small.size} anchor ({ax:.0f}, {ay:.0f}) {POSES[name][1]}")
    manifest_path.write_text(json.dumps(manifest, indent=1))


if __name__ == "__main__":
    main(sys.argv[1:])
