#!/usr/bin/env python3
"""The Red Bob's sheet from its painted design (2026-11-12, the pickup's redesign with the user's yes; the blind judges:
"red smiley coins in a casual-game sticker style that belongs to another game").

GPT Image 2.6 Sunburst painted four options (tools/art/gen/kie/world/bob.txt -> bob.png, a 2 x 2 sheet); the one kept
is the ruby cabochon in a band of Zulu beadwork and a gold rim (top right: it belongs with Panoramic's chakram, and
reads at 60 px by its black and white triangles). The sheet keeps BobView's four frames (bob.json: smile, blink, joy,
wink were the 2017 faces): the medallion, twice; lit up as it is taken (joy); and once more.

    python3 tools/art/kie/bob.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance

GEN = Path(__file__).resolve().parents[1] / "gen/kie/world"
OUT = Path(__file__).resolve().parents[3] / "assets/art/bob"
FRAME = 128
RADIUS = 56.8  # px of its rim in a frame (bob.json: BobView draws it SIZE wide by this)
OPTION = (1, 0)  # column, row of the design kept


def main() -> None:
    sheet = Image.open(GEN / "bob.png").convert("RGBA")
    w = sheet.width // 2
    cell = sheet.crop((OPTION[0] * w, OPTION[1] * w, OPTION[0] * w + w, OPTION[1] * w + w))
    cell = cell.crop(cell.getbbox())
    side = max(cell.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
    a = np.asarray(sq).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:4]  # (premultiplied: no dark fringe when it is made small)
    d = round(RADIUS * 2)
    small = np.dstack([np.asarray(Image.fromarray(a[..., q]).resize((d, d), Image.LANCZOS)) for q in range(4)]).clip(0, 1)
    al = small[..., 3:4]
    rgb = np.where(al > 1e-4, small[..., :3] / np.maximum(al, 1e-4), 0.0)
    bob = Image.fromarray((np.dstack([rgb, al[..., 0]]).clip(0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    lit = Image.merge("RGBA", (*ImageEnhance.Brightness(bob.convert("RGB")).enhance(1.16).split(), bob.getchannel("A")))
    out = Image.new("RGBA", (FRAME * 4, FRAME), (0, 0, 0, 0))
    off = (FRAME - d) // 2
    for i, f in enumerate([bob, bob, lit, bob]):
        out.paste(f, (i * FRAME + off, off))
    out.save(OUT / "bob.png")
    (OUT / "bob.json").write_text(json.dumps({"frame": FRAME, "frames": ["smile", "blink", "joy", "wink"], "radius": RADIUS}, indent=1))
    print(OUT / "bob.png", out.size)


if __name__ == "__main__":
    main()
