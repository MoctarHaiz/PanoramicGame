#!/usr/bin/env python3
"""Puts a keyed still on a pure magenta canvas for a video's first frame: the figure SHARE of the canvas's height,
centred, with room for its limbs to move.   python3 tools/art/kie/canvas.py IN.png OUT.png [share=0.7] [1920x1080]"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cells import key  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
share = float(sys.argv[3]) if len(sys.argv) > 3 else 0.7
W, H = [int(v) for v in (sys.argv[4] if len(sys.argv) > 4 else "1920x1080").split("x")]
a = key(np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0)
ys, xs = np.nonzero(a[..., 3] > 0.5)
a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
im = Image.fromarray((a * 255).astype(np.uint8), "RGBA")
k = share * H / im.height
im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
canvas = Image.new("RGBA", (W, H), (255, 0, 255, 255))
canvas.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
canvas.convert("RGB").save(out)
print(out, im.size)
