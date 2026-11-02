#!/usr/bin/env python3
"""What each picture costs in video memory, from its size and its import settings (lossless RGBA8:
4 bytes a pixel; VRAM compressed: 1 byte with alpha (DXT5 / ETC2 / ASTC 4x4), 0.5 without;
mipmaps: a third more). The total Godot measures comes from tools/art/texture_report.tscn.

    python3 tools/art/texture_budget.py [--top 40]
"""
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

NEW = Path(__file__).resolve().parents[2]


def cost(png: Path) -> tuple[float, str]:
    imp = png.with_name(png.name + ".import")
    text = imp.read_text() if imp.exists() else ""
    mode = re.search(r"^compress/mode=(\d)", text, re.M)
    mips = re.search(r"^mipmaps/generate=true", text, re.M) is not None
    img = Image.open(png)
    alpha = img.mode in ("RGBA", "LA", "P") and (np.asarray(img.convert("RGBA"))[..., 3] < 255).any()
    px = img.width * img.height
    vram = mode is not None and mode.group(1) == "2"
    per = (1.0 if alpha else 0.5) if vram else 4.0
    bytes_ = px * per * (4.0 / 3.0 if mips else 1.0)
    return bytes_ / 2 ** 20, ("vram" if vram else "rgba8") + ("+mips" if mips else "")


def main() -> None:
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 40
    rows = []
    for png in sorted((NEW / "assets").rglob("*.png")):
        mb, kind = cost(png)
        rows.append((mb, kind, str(png.relative_to(NEW / "assets"))))
    rows.sort(reverse=True)
    for mb, kind, rel in rows[:top]:
        print(f"{mb:6.2f} MB  {kind:11s} {rel}")
    groups = {}
    for mb, _, rel in rows:
        key = "/".join(rel.split("/")[:2])
        groups[key] = groups.get(key, 0.0) + mb
    print("by folder:", ", ".join(f"{k} {v:.1f}" for k, v in sorted(groups.items(), key=lambda kv: -kv[1])))
    print(f"total {sum(r[0] for r in rows):.1f} MB")


if __name__ == "__main__":
    main()
