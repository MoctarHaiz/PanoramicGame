#!/usr/bin/env python3
"""The Red Bob sheet (assets/art/bob/bob.png + bob.json): the ball rendered in 3D in the hero's light
(tools/art/blender/bob_render.py) with the 2017 Red Bob's face drawn on it, bold enough to read at
phone size: big dark eyes with a white glint, a thick smile, rosy cheeks. Four faces side by side:
smile, blink, joy, wink. The face is squeezed towards the ball's edge as it curves away.

    python3 tools/art/bob_sheet.py [BALL_PNG]   # default ROOT/_agents/AAA/blender/bob_ball.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from hero_atlas import bleed, premultiplied_resize  # noqa: E402

NEW = Path(__file__).resolve().parents[2]
ROOT = next(p for p in NEW.parents if (p / "Making").is_dir())
BALL = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "_agents/AAA/blender/bob_ball.png"
OUT = NEW / "assets/art/bob"
FRAME = 128
S = 512  # drawn at the render's size, then reduced
INK = (40, 6, 8, 255)


def face(kind: str) -> Image.Image:
    """The face layer (RGBA, S x S), centred a little low on the ball."""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S * 0.5, S * 0.53
    ex, ey, ew, eh = S * 0.115, S * 0.47, S * 0.062, S * 0.095  # eye centre offset and half size

    def eye(x, open_):
        if open_:
            d.ellipse([x - ew, ey - eh, x + ew, ey + eh], fill=INK)
            d.ellipse([x - ew * 0.15, ey - eh * 0.75, x + ew * 0.55, ey - eh * 0.1], fill=(255, 255, 255, 255))
        else:  # closed, happy: an arc
            d.arc([x - ew * 1.2, ey - eh * 0.6, x + ew * 1.2, ey + eh * 0.9], 200, 340, fill=INK, width=int(S * 0.028))

    eye(cx - ex, kind in ("smile", "wink"))
    eye(cx + ex, kind == "smile")
    if kind == "joy":  # an open laugh
        d.chord([cx - S * 0.1, cy, cx + S * 0.1, cy + S * 0.14], 0, 180, fill=INK)
        d.ellipse([cx - S * 0.05, cy + S * 0.07, cx + S * 0.05, cy + S * 0.13], fill=(230, 80, 90, 255))
    else:
        d.arc([cx - S * 0.09, cy - S * 0.02, cx + S * 0.09, cy + S * 0.1], 20, 160, fill=INK, width=int(S * 0.03))
    blush = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush)
    for side in (-1, 1):
        x = cx + side * S * 0.2
        bd.ellipse([x - S * 0.06, cy - S * 0.01, x + S * 0.06, cy + S * 0.05], fill=(255, 140, 150, 120))
    blush = blush.filter(ImageFilter.GaussianBlur(S * 0.012))
    return Image.alpha_composite(blush, img)


def main() -> None:
    ball = Image.open(BALL).convert("RGBA")
    sheet = np.zeros((FRAME, FRAME * 4, 4), np.float32)
    kinds = ["smile", "blink", "joy", "wink"]
    alpha = np.asarray(ball)[..., 3] > 128
    ys, xs = np.nonzero(alpha)
    radius = (xs.max() - xs.min()) / 2.0 * FRAME / S
    for i, kind in enumerate(kinds):
        lit = Image.alpha_composite(ball, face(kind))
        # the face takes the ball's light: darker where the ball is in shade
        a = np.asarray(lit).astype(np.float32) / 255.0
        shade = np.asarray(ball.convert("L")).astype(np.float32) / 255.0
        f = np.asarray(face(kind)).astype(np.float32)[..., 3:4] / 255.0
        a[..., :3] *= 1.0 - f * (1.0 - np.clip(shade[..., None] * 1.6, 0.55, 1.0))
        small = premultiplied_resize(Image.fromarray((a * 255).astype(np.uint8), "RGBA"), FRAME / S)
        sheet[:, i * FRAME:(i + 1) * FRAME] = small[:FRAME, :FRAME]
    out = bleed(sheet)
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT / "bob.png", optimize=True)
    (OUT / "bob.json").write_text(json.dumps({"frame": FRAME, "frames": kinds, "radius": round(radius, 1)}, indent=1))
    print("bob.png", sheet.shape[1], sheet.shape[0], "radius", round(radius, 1))


if __name__ == "__main__":
    main()
