#!/usr/bin/env python3
"""The Red Bob, the game's mascot collectible: a glossy red ball with a cute face, drawn as SVG and
rendered by headless Chrome (tools/svg_to_png.py), then reduced (premultiplied) to the game size.

    python3 tools/art/bob.py        # assets/art/bob/bob.png (a row of faces) + bob.json

Frames, left to right: 0 smile (looking a little left, at Panoramic), 1 blink, 2 joy (collected:
eyes squeezed happy, mouth open), 3 wink. Lit from the upper left like every character: a deep
red sphere, a soft white gloss, a warm reflected light low on the right, a dark red ink outline.
The game draws it 30 units wide in a 32-unit tile; the texture is 4x (sharp in the HUD and on the
results screen, mipmapped in the level).
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/bob"
SVG_TOOL = ROOT / "tools/svg_to_png.py"

SIZE = 128  # one frame in the texture (px)
DRAW = 2  # rendered at 2x then halved
R = 54  # body radius (px of a 128 frame)
FRAMES = ["smile", "blink", "joy", "wink"]

INK = "#4a0806"


def defs() -> str:
    return f'''
<radialGradient id="body" cx="0.36" cy="0.30" r="0.78" fx="0.32" fy="0.24">
  <stop offset="0" stop-color="#ff8a5e"/>
  <stop offset="0.28" stop-color="#ff3a16"/>
  <stop offset="0.68" stop-color="#e01e06"/>
  <stop offset="1" stop-color="#8c0a04"/>
</radialGradient>
<radialGradient id="bounce" cx="0.78" cy="0.86" r="0.5">
  <stop offset="0" stop-color="#ffb070" stop-opacity="0.85"/>
  <stop offset="1" stop-color="#ffb070" stop-opacity="0"/>
</radialGradient>
<radialGradient id="cheek" cx="0.5" cy="0.5" r="0.5">
  <stop offset="0" stop-color="#ff9aa8" stop-opacity="0.9"/>
  <stop offset="1" stop-color="#ff9aa8" stop-opacity="0"/>
</radialGradient>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ffffff" stop-opacity="0.95"/>
  <stop offset="1" stop-color="#ffffff" stop-opacity="0.05"/>
</linearGradient>
<clipPath id="ball"><circle cx="64" cy="64" r="{R}"/></clipPath>
<filter id="blur2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter>
<filter id="blur1" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="0.8"/></filter>
'''


def eye(cx: float, cy: float, kind: str) -> str:
    """An eye at (cx, cy): open (tall glossy oval), closed (a happy arc), or squeezed (^)."""
    if kind == "open":
        return (f'<ellipse cx="{cx}" cy="{cy}" rx="8.6" ry="12.6" fill="#2a0806"/>'
                f'<ellipse cx="{cx - 2.4}" cy="{cy - 4.8}" rx="3.6" ry="4.8" fill="#ffffff"/>'
                f'<circle cx="{cx + 3}" cy="{cy + 5.2}" r="1.9" fill="#ffffff" opacity="0.85"/>')
    if kind == "closed":
        return (f'<path d="M{cx - 8},{cy + 1} Q{cx},{cy + 7} {cx + 8},{cy + 1}" fill="none" stroke="#2a0806" '
                f'stroke-width="4.2" stroke-linecap="round"/>')
    # squeezed with joy: ^
    return (f'<path d="M{cx - 8},{cy + 4} Q{cx},{cy - 8} {cx + 8},{cy + 4}" fill="none" stroke="#2a0806" '
            f'stroke-width="4.4" stroke-linecap="round"/>')


def frame(kind: str) -> str:
    s = f'<circle cx="64" cy="64" r="{R + 3.2}" fill="{INK}"/>'  # ink outline
    s += f'<circle cx="64" cy="64" r="{R}" fill="url(#body)"/>'
    s += '<g clip-path="url(#ball)">'
    s += f'<circle cx="64" cy="64" r="{R}" fill="url(#bounce)"/>'
    # a soft core shadow down the right, under the face
    s += f'<circle cx="54" cy="52" r="{R + 4}" fill="none" stroke="#5a0604" stroke-opacity="0.35" stroke-width="12" filter="url(#blur2)"/>'
    s += '</g>'
    # face (looking a little left)
    ex, ey = 50, 56
    if kind == "smile":
        s += eye(ex - 10, ey, "open") + eye(ex + 16, ey, "open")
    elif kind == "blink":
        s += eye(ex - 10, ey, "closed") + eye(ex + 16, ey, "closed")
    elif kind == "joy":
        s += eye(ex - 10, ey, "joy") + eye(ex + 16, ey, "joy")
    else:  # wink
        s += eye(ex - 10, ey, "open") + eye(ex + 16, ey, "joy")
    s += f'<ellipse cx="{ex - 18}" cy="{ey + 14}" rx="7" ry="4.5" fill="url(#cheek)"/>'
    s += f'<ellipse cx="{ex + 26}" cy="{ey + 14}" rx="7" ry="4.5" fill="url(#cheek)"/>'
    if kind == "joy":  # a big open smile with a tongue
        s += (f'<path d="M{ex - 9},{ey + 13} Q{ex + 3},{ey + 34} {ex + 17},{ey + 13} Z" fill="#3a0604"/>'
              f'<path d="M{ex - 3},{ey + 23} Q{ex + 3},{ey + 18} {ex + 10},{ey + 23} Q{ex + 5},{ey + 29} {ex - 1},{ey + 27} Z" fill="#ff6a7a"/>')
    else:  # a small smile, open a little
        s += (f'<path d="M{ex - 6},{ey + 14} Q{ex + 3},{ey + 26} {ex + 13},{ey + 14} Q{ex + 3},{ey + 19} {ex - 6},{ey + 14} Z" '
              f'fill="#3a0604" stroke="#3a0604" stroke-width="2.6" stroke-linejoin="round"/>')
    # gloss: a soft band on the upper left and a sharp spark
    s += (f'<ellipse cx="44" cy="31" rx="20" ry="11" fill="url(#gloss)" transform="rotate(-28 44 31)" filter="url(#blur1)"/>'
          f'<circle cx="36" cy="27" r="4.2" fill="#ffffff"/>'
          f'<path d="M{64 + R * 0.62},{64 + R * 0.5} A{R - 6},{R - 6} 0 0 1 {64 + R * 0.05},{64 + R * 0.86}" fill="none" '
          f'stroke="#ffd0a0" stroke-opacity="0.55" stroke-width="3" stroke-linecap="round"/>')
    return s


def sheet_svg() -> str:
    w, h = SIZE * len(FRAMES), SIZE
    cells = "".join(f'<g transform="translate({i * SIZE},0)">{frame(k)}</g>' for i, k in enumerate(FRAMES))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f"<defs>{defs()}</defs>{cells}</svg>")


def render(svg: str, out: Path, scale: float) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp, "art.svg")
        src.write_text(svg)
        subprocess.run([sys.executable, str(SVG_TOOL), str(src), str(out), "--scale", str(scale)], check=True,
                       stdout=subprocess.DEVNULL)
    return Image.open(out).convert("RGBA")


def reduce(img: Image.Image, size: tuple) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255.0
    pre = np.dstack([a[..., :3] * a[..., 3:4], a[..., 3:4]])
    small = np.asarray(Image.fromarray((pre * 255 + 0.5).astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)).astype(np.float32) / 255
    al = small[..., 3:4]
    col = np.where(al > 1e-4, small[..., :3] / np.maximum(al, 1e-4), 0)
    return Image.fromarray((np.dstack([np.clip(col, 0, 1), al]) * 255 + 0.5).astype(np.uint8), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build = ROOT / "build/art"
    build.mkdir(parents=True, exist_ok=True)
    big = render(sheet_svg(), build / "bob_2x.png", DRAW)
    sheet = reduce(big, (SIZE * len(FRAMES), SIZE))
    sheet.save(OUT / "bob.png", optimize=True)
    (OUT / "bob.json").write_text(json.dumps({"frame": SIZE, "frames": FRAMES, "radius": R + 3.2}, indent=1))
    print("bob sheet", sheet.size)


if __name__ == "__main__":
    main()
