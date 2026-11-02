#!/usr/bin/env python3
"""docs/art/before_after.png: the 2019 game (Old/PanoramicGameResources/captures, Android nav bar
cut off) above the same screens of Chaka Zulu 2.0 (tests/capture.tscn on a 2400 x 1080 phone).

    Godot --path . --fixed-fps 60 --resolution 200x200 res://tests/capture.tscn -- \\
        --out=build/final_assets --devices=pixel_2400x1080 --ads=off
    python3 tools/art/before_after.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT.parent / "Old/PanoramicGameResources/captures"
NEW = ROOT / "build/final_assets"
OUT = ROOT / "docs/art/before_after.png"
OLD_WIDTH = 1356  # the old captures end in a black navigation bar
COLUMNS = [  # title, 2019 capture, 2026 capture
    ("Menu", "Screenshot_20191225-145805.png", "pixel_2400x1080__menu.png"),
    ("Level", "Screenshot_20191225-145821.png", "pixel_2400x1080__game.png"),
    ("Home", "Screenshot_20191225-150103.png", "pixel_2400x1080__home.png"),
    ("Game over", "Screenshot_20191225-145852.png", "pixel_2400x1080__gameover.png"),
]
ROWS = [("2019", OLD), ("2026", NEW)]
CELL_W, CELL_H = 720, 324
LABEL_W, HEAD_H, GAP = 120, 56, 12
BG, INK = (38, 18, 10), (255, 236, 200)


def fill(img: Image.Image) -> Image.Image:
    """Scales and centre-crops a capture to the cell's shape."""
    k = max(CELL_W / img.width, CELL_H / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    x, y = (img.width - CELL_W) // 2, (img.height - CELL_H) // 2
    return img.crop((x, y, x + CELL_W, y + CELL_H))


def main() -> None:
    font = ImageFont.truetype(str(ROOT / "assets/fonts/Fredoka.ttf"), 34)
    w = LABEL_W + len(COLUMNS) * (CELL_W + GAP) + GAP
    h = HEAD_H + len(ROWS) * (CELL_H + GAP) + GAP
    board = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(board)
    for c, (title, *_) in enumerate(COLUMNS):
        x = LABEL_W + GAP + c * (CELL_W + GAP)
        draw.text((x + CELL_W / 2, HEAD_H / 2 + 4), title, font=font, fill=INK, anchor="mm")
    for r, (label, folder) in enumerate(ROWS):
        y = HEAD_H + r * (CELL_H + GAP)
        draw.text((LABEL_W / 2 + 4, y + CELL_H / 2), label, font=font, fill=INK, anchor="mm")
        for c, column in enumerate(COLUMNS):
            img = Image.open(folder / column[1 + r]).convert("RGB")
            if folder == OLD:
                img = img.crop((0, 0, OLD_WIDTH, img.height))
            board.paste(fill(img), (LABEL_W + GAP + c * (CELL_W + GAP), y))
    board.save(OUT, optimize=True)
    print(OUT, board.size)


if __name__ == "__main__":
    main()
