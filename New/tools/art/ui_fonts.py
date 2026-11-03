"""Static Fredoka weights for multichannel signed distance field (MSDF) text.

The variable Fredoka.ttf draws its letters from overlapping contours; an MSDF of that shows seams (an X
in "+", a crack in "1"). This makes static instances at the weights the game uses (580, 680, 700) with
the overlaps merged, then cleans what the merge leaves (slivers, the tiny loops at the waist of the "8",
hairline spikes in "u", "g", "m"...: a distance field turns them into holes and notches). Ui loads
them; their .import files turn MSDF on, so every size and outline of a weight shares one glyph cache (a
raster font makes a glyph page per size and outline).

Needs fontTools and skia-pathops (pip install fonttools skia-pathops), e.g. in a scratch venv:
    python tools/art/ui_fonts.py assets/fonts/Fredoka.ttf assets/fonts
"""
import array
import math
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates
from fontTools.varLib import instancer

WEIGHTS = (580, 680, 700)


def _area(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts))) / 2


def _set_contours(glyf, g, contours):
    pts = [p for c, _ in contours for p in c]
    flags = [f for _, fl in contours for f in fl]
    ends, n = [], 0
    for c, _ in contours:
        n += len(c)
        ends.append(n - 1)
    g.coordinates = GlyphCoordinates(pts)
    g.flags = array.array("B", flags)
    g.endPtsOfContours = ends
    g.numberOfContours = len(ends)
    g.recalcBounds(glyf)


def _contours(glyf, g):
    coords, ends, flags = g.getCoordinates(glyf)
    out, start = [], 0
    for e in ends:
        out.append(([tuple(coords[i]) for i in range(start, e + 1)], [flags[i] for i in range(start, e + 1)]))
        start = e + 1
    return out


def drop_slivers(font):
    """Contours of a few units left by the overlap merge."""
    glyf = font["glyf"]
    for name in glyf.keys():
        g = glyf[name]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        cs = _contours(glyf, g)
        keep = [(p, f) for p, f in cs if not (abs(_area(p)) < 60 and
                max(x for x, _ in p) - min(x for x, _ in p) < 12 and max(y for _, y in p) - min(y for _, y in p) < 12)]
        if len(keep) != len(cs):
            _set_contours(glyf, g, keep)


def drop_spikes(font):
    """Points where the outline doubles back on itself over a few units (a hairline spike): gone."""
    glyf = font["glyf"]
    for name in glyf.keys():
        g = glyf[name]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        cs = _contours(glyf, g)
        changed = False
        for k, (pts, fl) in enumerate(cs):
            again = True
            while again and len(pts) > 4:
                again = False
                for i in range(len(pts)):
                    a, b, c = pts[i - 1], pts[i], pts[(i + 1) % len(pts)]
                    v1, v2 = (b[0] - a[0], b[1] - a[1]), (c[0] - b[0], c[1] - b[1])
                    l1, l2 = math.hypot(*v1), math.hypot(*v2)
                    if l1 == 0 or l2 == 0:
                        continue
                    if (v1[0] * v2[0] + v1[1] * v2[1]) / (l1 * l2) < -0.85 and min(l1, l2) < 12:
                        del pts[i], fl[i]
                        if not any(f & 1 for f in fl):
                            fl[0] |= 1
                        again = changed = True
                        break
            cs[k] = (pts, fl)
        if changed:
            _set_contours(glyf, g, cs)


def clean_eight_waist(font):
    """The "8": where its two rings meet, the merge leaves zig-zags; one clean notch point instead."""
    glyf = font["glyf"]
    g = glyf["eight"]
    cs = _contours(glyf, g)
    pts, fl = cs[0]
    for side in ("R", "L"):  # right first: its indices are higher, the left's stay valid
        idx = [i for i, p in enumerate(pts) if 355 <= p[1] <= 377 and ((p[0] < 130) if side == "L" else (p[0] > 410))]
        if not idx or idx != list(range(idx[0], idx[-1] + 1)):
            continue
        near = [pts[i] for i in idx if fl[i] & 1 and abs(pts[i][1] - 366) <= 2]
        if not near:
            continue
        x = min(p[0] for p in near) if side == "L" else max(p[0] for p in near)
        pts[idx[0]:idx[-1] + 1] = [(x, 366)]
        fl[idx[0]:idx[-1] + 1] = [1]
    cs[0] = (pts, fl)
    _set_contours(glyf, g, cs)


def main(src, out_dir):
    axes = TTFont(src)["fvar"].axes
    for w in WEIGHTS:
        loc = {a.axisTag: a.defaultValue for a in axes}
        loc["wght"] = w
        font = instancer.instantiateVariableFont(TTFont(src), loc, overlap=instancer.OverlapMode.REMOVE)
        drop_slivers(font)
        clean_eight_waist(font)
        drop_spikes(font)
        font.save(f"{out_dir}/Fredoka-{w}.ttf")
        print(f"{out_dir}/Fredoka-{w}.ttf")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
