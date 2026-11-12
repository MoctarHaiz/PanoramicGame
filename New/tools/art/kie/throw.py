#!/usr/bin/env python3
"""The hero's throw over his run (gen/kie/hero_throw/NN.png: 00-11 the chakram cocked, 12-23 the arm thrown, each
over the run drawing with the same number; hero_pack.py packs them).

Nano Banana 2 redrew the run's sheet twice with his bare arm changed (sheet.py cut ... legs). A redraw is never the
same drawing twice, so a throw frame is not used whole: only what the edit changed (his arm, where it was and where
it went) is laid over the run's own drawing. His legs, head and scarf are then the run's to the pixel: nothing
shimmers as the throw comes and goes.

Each frame names the sheet whose edit is used and what that sheet was drawn from (the difference to it is the edit):
"clean" = the cleaned run (hero_run_clean), "clip" = the clip's own drawings (hero_run_v1/cycle).

    python3 tools/art/kie/throw.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

sys.path.insert(0, str(Path(__file__).parent))
from sheet import UP  # noqa: E402

GEN = Path(__file__).resolve().parents[1] / "gen/kie"
RUN = GEN / "hero_run_clean"
CLIP = GEN / "hero_run_v1/cycle"
## frame -> (sheet, drawn from): the second edits (from the cleaned run) where they changed his arm, the first elsewhere
COCKED = {i: ("hero_throw_cocked2", "clean") for i in range(12)}
COCKED.update({6: ("hero_throw_cocked", "clip"), 7: ("hero_throw_cocked", "clip")})
RELEASE = {i: ("hero_throw_release2", "clean") for i in (3, 4, 5, 8, 9, 10, 11)}
RELEASE.update({i: ("hero_throw_release", "clip") for i in (1, 2, 6, 7)})
## (neither sheet changed its first frame: a third edit, of four drawings round it; its second is the run's first)
RELEASE[0] = ("hero_release_sub", "clean", 1)


def rgba(path, size=None) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    if size and im.size != size:
        im = im.resize(size, Image.BILINEAR)
    return np.asarray(im).astype(np.float32) / 255.0


def on_canvas(path, size) -> np.ndarray:
    """A drawing of the clip on the cut drawings' canvas (sheet.py: twice the size, a margin round it)."""
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * UP, im.height * UP), Image.BILINEAR)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(im, ((size[0] - im.width) // 2, (size[1] - im.height) // 2))
    return np.asarray(out).astype(np.float32) / 255.0


def pm(a: np.ndarray) -> np.ndarray:
    out = a.copy()
    out[..., :3] *= out[..., 3:4]
    return out


def lay(base: np.ndarray, edit: np.ndarray, was: np.ndarray) -> tuple:
    """`edit` over `base` where `edit` differs from what it was drawn from."""
    b, e, w = pm(base), pm(edit), pm(was)
    d = ndi.gaussian_filter(np.abs(e - w).max(axis=-1), 3.0)
    m = d > 0.11
    lab, n = ndi.label(m)
    if n:
        sizes = ndi.sum(m, lab, range(1, n + 1))
        m = np.isin(lab, 1 + np.nonzero(sizes > 900)[0])
    m = ndi.binary_dilation(m, iterations=9)
    k = ndi.gaussian_filter(m.astype(np.float32), 2.0)[..., None]
    out = b * (1.0 - k) + e * k
    al = out[..., 3:4]
    return np.dstack([np.where(al > 1e-4, out[..., :3] / np.maximum(al, 1e-4), 0.0).clip(0, 1), al[..., 0]]), float(m.mean())


def main() -> None:
    out = GEN / "hero_throw"
    out.mkdir(exist_ok=True)
    for f in out.glob("*.png"):
        f.unlink()
    tiles = []
    for part, table in enumerate((COCKED, RELEASE)):
        for i in range(12):
            base = rgba(RUN / ("%02d.png" % i))
            size = (base.shape[1], base.shape[0])
            sheet, frm = table[i][:2]
            edit = rgba(GEN / sheet / ("%02d.png" % (table[i][2] if len(table[i]) > 2 else i)), size)
            was = base if frm == "clean" else on_canvas(CLIP / ("%02d.png" % i), size)
            res, share = lay(base, edit, was)
            Image.fromarray((res * 255 + 0.5).astype(np.uint8), "RGBA").save(out / ("%02d.png" % (part * 12 + i)))
            tiles.append(res)
            print("%s %2d: %s, %.1f%% of the picture changed%s" % (("cocked", "thrown")[part], i, sheet, share * 100,
                                                                 "  <- nothing changed?" if share < 0.01 else ""))
    tw, th = tiles[0].shape[1] // 2, tiles[0].shape[0] // 2
    prev = Image.new("RGB", (tw * 6, th * 4), (158, 184, 219))
    for i, t in enumerate(tiles):
        im = Image.fromarray((t * 255).astype(np.uint8), "RGBA").resize((tw, th), Image.LANCZOS)
        prev.paste(im, ((i % 6) * tw, (i // 6) * th), im)
    prev.save(GEN / "hero_throw.png")


if __name__ == "__main__":
    main()
