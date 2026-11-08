#!/usr/bin/env python3
"""Round 19 (the judges: "the hut thatch identical stacked tiers"; "the HOME sign a generic font stamped on the
plank"): the homestead's huts and its sign repainted with kie.ai from the game's own pictures laid out on a
green sheet, then cut back to the same sizes. The big hut keeps its doorway exactly: the original door frame
and the inside of the doorway are laid back over the new thatch (HomeView, World.HOME_X and home.json depend on
it), and home_hut_front.png (the wall right of the doorway, drawn over him) is cut again from the new hut.

    python3 tools/art/world_home.py layout   -> _agents/kie/world19/layout/home.png + home.json
    python3 tools/art/world_home.py build    -> assets/art/world/home_hut.png, home_hut_front.png,
                                               home_hut_small.png, home_hut_low.png, home_sign.png
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).parent))
from world_rock import K, ART, KEY, key_green, region, resize, bleed, save  # noqa: E402

LW, LH = 1376, 768
# piece -> (x, y, scale) in the layout (px), its picture at that scale
PLACE = {
    "home_hut": (24, 60, 1.0),
    "home_hut_small": (800, 40, 0.74),
    "home_sign": (1112, 40, 0.94),
    "home_hut_low": (820, 470, 0.62),
}
OLD = K / "home_before"  ## the pictures before this round (the door and the jamb's fade are taken from them)
FRONT_CROP = 305  ## px: home_hut_front.png is the hut from this column (home.json front_crop_x 152.5 units)
DOOR = (245.0, 407.0, 127.0, 118, 372)  ## px in home_hut.png: the arch's centre x, y, its outer radius, the frame's x span


def layout() -> None:
    img = Image.new("RGBA", (LW, LH), KEY + (255,))
    boxes = {}
    for name, (x, y, k) in PLACE.items():
        pic = Image.open(ART / (name + ".png")).convert("RGBA")
        pic = pic.resize((round(pic.width * k), round(pic.height * k)), Image.LANCZOS)
        img.alpha_composite(pic, (x, y))
        boxes[name] = [x / LW, y / LH, pic.width / LW, pic.height / LH]
    (K / "layout").mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(K / "layout/home.png")
    (K / "layout/home.json").write_text(json.dumps(boxes, indent=1))
    print("layout", K / "layout/home.png")


def door_mask(h: int, w: int) -> np.ndarray:
    """The doorway with its frame (1 inside), feathered: kept from the old picture."""
    cx, cy, r, x0, x1 = DOOR
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    inside = ((xx >= x0) & (xx <= x1) & (yy >= cy)) | ((xx - cx) ** 2 + (yy - cy) ** 2 <= r * r)
    return np.clip(ndi.gaussian_filter(inside.astype(np.float32), 1.6) * 1.3 - 0.15, 0, 1)


def build(sheet: str) -> None:
    keyed = key_green(np.asarray(Image.open(sheet).convert("RGBA")).astype(np.float32))
    save(keyed, K / "out/home_keyed.png")
    boxes = json.loads((K / "layout/home.json").read_text())
    for name in PLACE:
        old = np.asarray(Image.open(OLD / (name + ".png")).convert("RGBA")).astype(np.float32)
        piece = region(keyed, boxes[name], 0.012, 0.012)
        new = resize(piece, (old.shape[1], old.shape[0]))  # (its box fitted to the old picture's: the same footprint)
        if name == "home_hut":
            m = door_mask(*old.shape[:2])[..., None]
            new = new * (1 - m) + old * m
            front_old = np.asarray(Image.open(OLD / "home_hut_front.png").convert("RGBA")).astype(np.float32)
            front = new[:, FRONT_CROP:].copy()
            # the doorway stays open in the front piece (he stands in it): over the door's span the old front's
            # alpha (its jamb fades in from the doorway), the new hut's elsewhere
            span = np.arange(front.shape[1])[None, :] < DOOR[4] - FRONT_CROP + 2
            front[..., 3] = np.where(span, np.minimum(front[..., 3], front_old[..., 3]), front[..., 3])
            save(bleed(front), ART / "home_hut_front.png")
        save(bleed(new), ART / (name + ".png"))
        print(name, new.shape)


if __name__ == "__main__":
    if sys.argv[1] == "layout":
        layout()
    elif sys.argv[1] == "build":
        build(sys.argv[2] if len(sys.argv) > 2 else str(K / "gen/world_home_0.png"))
