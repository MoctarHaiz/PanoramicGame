"""The level editor's brushes in the game's current look: level_editor/brushes.png, one 32 px icon a
thing the game draws, in one row, in the order of BRUSHES in level_editor/level_editor.gd (each icon
writes that thing's 2017 id into level.txt). Made from the game's own pictures; the water is drawn
by a shader in the game, so its two icons are painted here in its colours.

    python3 tools/art/level_brushes.py   (from New/)
"""
from pathlib import Path

from PIL import Image, ImageDraw

NEW = Path(__file__).resolve().parents[2]
WORLD = NEW / "assets/art/world"
BOB = NEW / "assets/art/bob/bob.png"
OUT = NEW / "level_editor/brushes.png"
CELL = 32


def fit(pic: Image.Image, box: int = CELL) -> Image.Image:
    """The picture shrunk to fit a cell, standing on its bottom edge, centred."""
    pic = pic.convert("RGBA")
    pic = pic.crop(pic.getbbox() or (0, 0, *pic.size))
    k = min(box / pic.width, box / pic.height)
    pic = pic.resize((max(1, round(pic.width * k)), max(1, round(pic.height * k))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL))
    cell.alpha_composite(pic, ((CELL - pic.width) // 2, CELL - pic.height))
    return cell


def earth() -> Image.Image:
    """A cell of the painted bank of the ground (earth.png, its middle)."""
    pic = Image.open(WORLD / "earth.png").convert("RGBA")
    side = pic.height // 2
    return pic.crop((pic.width // 2, side // 2, pic.width // 2 + side, side // 2 + side)).resize((CELL, CELL), Image.LANCZOS)


def grass_top() -> Image.Image:
    """The bank with the turf along its top (grass_cap.png: blades, then the band)."""
    cell = earth()
    cap = Image.open(WORLD / "grass_cap.png").convert("RGBA")
    cap = cap.crop((0, 0, cap.height, cap.height)).resize((CELL, CELL), Image.LANCZOS)
    cell.alpha_composite(cap, (0, -6))
    return cell


def water(surface: bool) -> Image.Image:
    """The pools' colours (water.gdshader): a deep teal body, the surface a lighter band with a white line."""
    cell = Image.new("RGBA", (CELL, CELL))
    d = ImageDraw.Draw(cell)
    for y in range(CELL):
        t = y / (CELL - 1)
        d.line([(0, y), (CELL, y)], fill=(int(70 - 40 * t), int(140 - 60 * t), int(160 - 50 * t), 255))
    if surface:
        d.rectangle([0, 0, CELL, 7], fill=(150, 205, 215, 255))
        d.line([(0, 7), (CELL, 7)], fill=(240, 250, 250, 255), width=2)
    return cell


def bob() -> Image.Image:
    sheet = Image.open(BOB).convert("RGBA")
    return fit(sheet.crop((0, 0, sheet.height, sheet.height)), 28).transform(
        (CELL, CELL), Image.AFFINE, (1, 0, 0, 0, 1, 2))  # (lifted to the middle of the cell)


def main() -> None:
    icons = [
        grass_top(),  # grass top
        earth(),  # wall / soil
        water(True),  # water surface
        water(False),  # deep water
        bob(),  # Red Bob
        fit(Image.open(WORLD / "tree_acacia_1.png")),  # tree
        fit(Image.open(WORLD / "prop_stump.png")),  # stump
        fit(Image.open(WORLD / "prop_aloe.png")),  # aloe
        fit(Image.open(WORLD / "prop_rock_a.png")),  # rock
        fit(Image.open(WORLD / "prop_reeds.png")),  # reeds
        fit(Image.open(WORLD / "prop_bush_a.png")),  # bush
    ]
    sheet = Image.new("RGBA", (CELL * len(icons), CELL))
    for i, icon in enumerate(icons):
        sheet.alpha_composite(icon, (i * CELL, 0))
    sheet.save(OUT)
    print(f"{OUT} ({len(icons)} brushes)")


if __name__ == "__main__":
    main()
