#!/usr/bin/env python3
"""The CHAKA ZULU logo and the interface ornaments, drawn as SVG and rendered by headless Chrome.

    python3 tools/art/logo.py      # assets/art/ui/logo.png, ribbon.png, beads.png, shield.png

- logo.png: the title in two lines, gold lettering with a dark brown outline, a lit bevel and an
  extruded depth; at its left, whole, a Zulu isihlangu shield (cowhide patches, the laced strip
  down its middle, the stick behind it) with strings of beads, crossed with an assegai. Fredoka (assets/fonts, SIL OFL) is embedded in the
  SVG, so Chrome draws the same letters as the game.
- ribbon.png: the banner under the title (the subtitle is written on it by the game, translated):
  deep red cloth with a beadwork border; drawn 9-sliced.
- beads.png: a strip of beadwork (triangles in red, white, blue, gold and black) that tiles
  sideways: trims of panels and cards.
- shield.png: the small shield alone (the start card, the results).
"""
import base64
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/ui"
SVG_TOOL = ROOT / "tools/svg_to_png.py"
FONT = ROOT / "assets/fonts/Fredoka.ttf"

INK = "#2e0d04"
BEAD = ["#d8261a", "#f6efe2", "#2f6fd0", "#f2b52a", "#1c1410"]  # red, white, blue, gold, black


def font_face() -> str:
    data = base64.b64encode(FONT.read_bytes()).decode()
    return ("<style>@font-face{font-family:'Fredoka';src:url(data:font/ttf;base64," + data + ") format('truetype');"
            "font-weight:300 700;}</style>")


def shield(cx: float, cy: float, h: float, tilt: float = 0.0, beads: bool = True) -> str:
    """An isihlangu: a tall oval of cowhide, a laced strip down the middle, the stick behind."""
    w = h * 0.52
    top, bot = cy - h / 2, cy + h / 2
    oval = (f"M{cx},{top} C{cx + w * 0.62},{top + h * 0.08} {cx + w * 0.56},{bot - h * 0.1} {cx},{bot} "
            f"C{cx - w * 0.56},{bot - h * 0.1} {cx - w * 0.62},{top + h * 0.08} {cx},{top} Z")
    s = f'<g transform="rotate({tilt} {cx} {cy})">'
    # the stick, out of both ends, with a tuft at the top
    s += (f'<rect x="{cx - h * 0.018}" y="{top - h * 0.16}" width="{h * 0.036}" height="{h * 1.28}" rx="{h * 0.018}" '
          f'fill="url(#wood)" stroke="{INK}" stroke-width="{h * 0.022}"/>')
    s += (f'<path d="M{cx},{top - h * 0.15} c{-h * 0.07},{-h * 0.03} {-h * 0.06},{-h * 0.11} {-h * 0.01},{-h * 0.14} '
          f'c{h * 0.02},{h * 0.04} {h * 0.07},{h * 0.02} {h * 0.06},{h * 0.1} c{0},{h * 0.04} {-h * 0.03},{h * 0.05} {-h * 0.05},{h * 0.04} Z" '
          f'fill="#1e1410" stroke="{INK}" stroke-width="{h * 0.008}"/>')
    # the hide: cream, dark patches, shaded at the rim
    s += f'<path d="{oval}" fill="{INK}" transform="translate(0 {h * 0.012})" opacity="0.5"/>'
    s += f'<path d="{oval}" fill="url(#hide)" stroke="{INK}" stroke-width="{h * 0.032}"/>'
    s += f'<clipPath id="oval{int(cx)}{int(cy)}"><path d="{oval}"/></clipPath>'
    s += f'<g clip-path="url(#oval{int(cx)}{int(cy)})">'
    for px, py, r, rot in ((-0.62, -0.28, 0.42, 20), (0.58, 0.05, 0.38, -30), (-0.48, 0.42, 0.34, 40),
                           (0.5, -0.5, 0.26, 10), (0.66, 0.5, 0.3, -10), (-0.7, -0.62, 0.22, 0)):
        ex, ey = cx + px * w * 0.5, cy + py * h * 0.5
        s += (f'<ellipse cx="{ex}" cy="{ey}" rx="{r * w * 0.55}" ry="{r * w * 0.42}" fill="#3b1f12" '
              f'transform="rotate({rot} {ex} {ey})"/>')
    s += f'<path d="{oval}" fill="url(#rimShade)"/>'
    s += '</g>'
    # the laced strip down the middle
    sw = w * 0.16
    s += (f'<rect x="{cx - sw / 2}" y="{top + h * 0.1}" width="{sw}" height="{h * 0.8}" rx="{sw / 2}" fill="#e9dcc6" '
          f'stroke="{INK}" stroke-width="{h * 0.016}"/>')
    n = 9
    for i in range(n):
        y = top + h * 0.14 + i * h * 0.72 / (n - 1)
        col = "#3b1f12" if i % 2 == 0 else "#b8261a"
        s += (f'<rect x="{cx - sw * 0.95}" y="{y - h * 0.016}" width="{sw * 1.9}" height="{h * 0.032}" rx="{h * 0.012}" '
              f'fill="{col}" stroke="{INK}" stroke-width="{h * 0.011}"/>')
    if beads:  # strings of beads hanging from the rim
        for side in (-1, 1):
            bx = cx + side * w * 0.47
            for k in range(7):
                by = cy + h * 0.06 + k * h * 0.045
                s += (f'<circle cx="{bx + side * k * h * 0.004}" cy="{by}" r="{h * 0.022}" fill="{BEAD[k % 4]}" '
                      f'stroke="{INK}" stroke-width="{h * 0.01}"/>')
    s += "</g>"
    return s


def word(text: str, x: float, y: float, size: float, spacing: float = 0.0, beads: bool = False) -> str:
    """Display lettering: soft shadow, extruded depth, ink outline, a sunset-gold fill (pale gold
    on top, warming to orange and a rose-red foot, as lit by the low sun), a lit bevel; with
    `beads`, a band of Zulu beadwork (triangles in red, white, blue and black) runs through the
    letters below their middle."""
    t = (f'font-family="Fredoka" font-weight="700" font-size="{size}" text-anchor="middle" '
         f'letter-spacing="{spacing}"')
    d = size * 0.09
    s = f'<text x="{x}" y="{y + d + size * 0.05}" {t} fill="#1a0602" opacity="0.35" stroke="#1a0602" stroke-width="{size * 0.22}" stroke-linejoin="round" filter="url(#blur6)">{text}</text>'
    steps = 10
    for i in range(steps, 0, -1):  # depth
        s += (f'<text x="{x}" y="{y + d * i / steps}" {t} fill="#5a1606" stroke="#3e0e04" stroke-width="{size * 0.16}" '
              f'stroke-linejoin="round">{text}</text>')
    s += f'<text x="{x}" y="{y}" {t} fill="{INK}" stroke="{INK}" stroke-width="{size * 0.16}" stroke-linejoin="round">{text}</text>'
    s += f'<text x="{x}" y="{y}" {t} fill="url(#sunsetGold)" stroke="#fff1c0" stroke-width="{size * 0.035}" stroke-linejoin="round">{text}</text>'
    s += f'<text x="{x}" y="{y}" {t} fill="url(#sunsetGold)">{text}</text>'
    if beads:
        cid = f"letters{int(x)}{int(y)}"
        s += f'<clipPath id="{cid}"><text x="{x}" y="{y}" {t}>{text}</text></clipPath>'
        band_y, band_h = y - size * 0.3, size * 0.11
        s += f'<g clip-path="url(#{cid})">'
        s += f'<rect x="{x - size * 3}" y="{band_y - 3}" width="{size * 6}" height="{band_h + 6}" fill="{INK}"/>'
        cell = band_h
        cols = ["#d8261a", "#f6efe2", "#2f6fd0", "#f6efe2"]
        for i in range(int(size * 6 / cell)):
            bx = x - size * 3 + i * cell
            up = i % 2 == 0
            pts = (f"{bx},{band_y + band_h} {bx + cell},{band_y + band_h} {bx + cell / 2},{band_y}" if up
                   else f"{bx},{band_y} {bx + cell},{band_y} {bx + cell / 2},{band_y + band_h}")
            s += f'<polygon points="{pts}" fill="{cols[i % 4]}"/>'
        s += '</g>'
    return s


DEFS = '''
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#fff3b8"/><stop offset="0.22" stop-color="#ffe070"/><stop offset="0.5" stop-color="#ffc232"/>
  <stop offset="0.8" stop-color="#ff981c"/><stop offset="1" stop-color="#e86a10"/>
</linearGradient>
<linearGradient id="sunsetGold" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#fff6c8"/><stop offset="0.25" stop-color="#ffe070"/><stop offset="0.52" stop-color="#ffb627"/>
  <stop offset="0.78" stop-color="#ff7a2a"/><stop offset="1" stop-color="#e2384a"/>
</linearGradient>
<linearGradient id="bevel" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#ffffff" stop-opacity="0.85"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
</linearGradient>
<radialGradient id="hide" cx="0.38" cy="0.3" r="0.85">
  <stop offset="0" stop-color="#fffaf0"/><stop offset="0.6" stop-color="#f0e2c8"/><stop offset="1" stop-color="#c9ab84"/>
</radialGradient>
<radialGradient id="rimShade" cx="0.4" cy="0.35" r="0.7">
  <stop offset="0.7" stop-color="#3b1f12" stop-opacity="0"/><stop offset="1" stop-color="#3b1f12" stop-opacity="0.45"/>
</radialGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#c88a4c"/><stop offset="1" stop-color="#6e4120"/>
</linearGradient>
<linearGradient id="cloth" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#e2452c"/><stop offset="0.5" stop-color="#c22816"/><stop offset="1" stop-color="#8e160a"/>
</linearGradient>
<filter id="blur6" x="-20%" y="-50%" width="140%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
'''


def svg(w: int, h: int, body: str, fonts: bool = False) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'{font_face() if fonts else ""}<defs>{DEFS}</defs>{body}</svg>')


def spear(x0: float, y0: float, x1: float, y1: float, size: float) -> str:
    """An assegai from (x0, y0) (the butt) to (x1, y1) (the tip): a wooden shaft bound with sinew
    under a long leaf-shaped iron blade, lit along one edge."""
    import math
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    ln = math.hypot(x1 - x0, y1 - y0)
    blade = ln * 0.24
    t = size * 0.035
    s = f'<g transform="translate({x0} {y0}) rotate({ang})">'
    s += (f'<rect x="0" y="{-t / 2}" width="{ln - blade * 0.9}" height="{t}" rx="{t / 2}" fill="url(#wood)" '
          f'stroke="{INK}" stroke-width="{size * 0.02}"/>')
    for k in range(4):  # sinew binding under the blade
        bx = ln - blade * 0.95 - k * t * 0.9
        s += f'<rect x="{bx}" y="{-t * 0.75}" width="{t * 0.6}" height="{t * 1.5}" rx="{t * 0.2}" fill="#d8c09a" stroke="{INK}" stroke-width="{size * 0.006}"/>'
    bx0 = ln - blade
    s += (f'<path d="M{bx0},0 C{bx0 + blade * 0.3},{-t * 2.6} {bx0 + blade * 0.7},{-t * 2.2} {ln},0 '
          f'C{bx0 + blade * 0.7},{t * 2.2} {bx0 + blade * 0.3},{t * 2.6} {bx0},0 Z" fill="#c9d2dc" stroke="{INK}" stroke-width="{size * 0.02}"/>')
    s += (f'<path d="M{bx0 + blade * 0.08},{-t * 0.3} C{bx0 + blade * 0.35},{-t * 2.0} {bx0 + blade * 0.7},{-t * 1.7} {ln - blade * 0.04},{-t * 0.1} '
          f'L{bx0 + blade * 0.1},{-t * 0.05} Z" fill="#ffffff" opacity="0.75"/>')
    s += "</g>"
    return s


def logo_svg() -> str:
    """The shield and a crossed assegai stand at the title's left, whole: an emblem framing it."""
    w, h = 1560, 820
    cx = w * 0.6
    body = spear(w * 0.08, h * 0.97, w * 0.38, h * 0.02, 560)
    body += shield(w * 0.225, h * 0.5, 620, tilt=-14)
    body += word("CHAKA", cx, h * 0.47, 220, 6)
    body += word("ZULU", cx, h * 0.8, 262, 10, beads=True)
    return svg(w, h, body, fonts=True)


def bead_row(x0: float, y0: float, n: int, cell: float, pattern: list) -> str:
    """Rows of square beads; `pattern` lists rows of colour indices (-1: none)."""
    s = ""
    for r, row in enumerate(pattern):
        for i in range(n):
            c = row[i % len(row)]
            if c < 0:
                continue
            x, y = x0 + i * cell, y0 + r * cell
            s += (f'<rect x="{x + cell * 0.08}" y="{y + cell * 0.08}" width="{cell * 0.84}" height="{cell * 0.84}" '
                  f'rx="{cell * 0.3}" fill="{BEAD[c]}"/>')
            s += (f'<circle cx="{x + cell * 0.36}" cy="{y + cell * 0.34}" r="{cell * 0.14}" fill="#ffffff" '
                  f'opacity="{0.55 if c != 1 else 0.9}"/>')
    return s


# Triangles in rows of beads (8 wide, 4 tall): gold on black with red and white, a blue line.
TRIANGLES = [
    [4, 4, 4, 0, 4, 4, 4, 1],
    [4, 4, 0, 3, 0, 4, 1, 3],
    [4, 0, 3, 2, 3, 0, 3, 2],
    [0, 3, 2, 2, 2, 3, 2, 2],
]


def beads_svg() -> str:
    cell = 12
    n = 32  # four repeats of the 8-bead pattern: the strip tiles sideways
    w, h = n * cell, 4 * cell + 8
    body = f'<rect x="0" y="0" width="{w}" height="{h}" fill="{INK}"/>'
    body += bead_row(0, 4, n, cell, TRIANGLES)
    return svg(w, h, body)


def ribbon_svg() -> str:
    """A banner 9-sliced by the game: the ends fold back, beadwork along the top and bottom."""
    w, h = 720, 120
    cell = 9
    fold = 54
    body = ""
    for side in (-1, 1):  # the folded ends, behind
        x = 0 if side < 0 else w
        sx = 1 if side < 0 else -1
        body += (f'<path d="M{x},{h * 0.2} L{x + sx * fold * 1.3},{h * 0.2} L{x + sx * fold * 1.3},{h * 0.92} '
                 f'L{x},{h * 0.92} L{x + sx * fold * 0.45},{h * 0.56} Z" fill="#7e1208" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    body += (f'<rect x="{fold}" y="{h * 0.08}" width="{w - fold * 2}" height="{h * 0.76}" rx="10" fill="url(#cloth)" '
             f'stroke="{INK}" stroke-width="6"/>')
    # a gold stitched edge inside the cloth (quiet: the words carry the ribbon), a light along its top
    for y in (h * 0.08 + 10, h * 0.84 - 10):
        body += (f'<line x1="{fold + 12}" y1="{y}" x2="{w - fold - 12}" y2="{y}" stroke="#f2b84a" stroke-width="3" '
                 f'stroke-dasharray="14 7" opacity="0.85"/>')
    body += f'<rect x="{fold + 6}" y="{h * 0.08 + 4}" width="{w - fold * 2 - 12}" height="4" rx="2" fill="#ffffff" opacity="0.22"/>'
    return svg(w, h, body)


def shield_svg() -> str:
    return svg(220, 300, shield(110, 156, 236, tilt=0, beads=False))


def render(svg_text: str, out: Path, scale: float = 1.0) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp, "art.svg")
        src.write_text(svg_text)
        subprocess.run([sys.executable, str(SVG_TOOL), str(src), str(out), "--scale", str(scale)], check=True,
                       stdout=subprocess.DEVNULL)
    return Image.open(out).convert("RGBA")


def trim(img: Image.Image, pad: int = 6) -> Image.Image:
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 4)
    return img.crop((max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, img.width), min(ys.max() + pad, img.height)))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    trim(render(logo_svg(), OUT / "logo.png")).save(OUT / "logo.png", optimize=True)
    render(beads_svg(), OUT / "beads.png").save(OUT / "beads.png", optimize=True)
    render(ribbon_svg(), OUT / "ribbon.png").save(OUT / "ribbon.png", optimize=True)
    trim(render(shield_svg(), OUT / "shield.png")).save(OUT / "shield.png", optimize=True)
    for f in ("logo", "beads", "ribbon", "shield"):
        print(f, Image.open(OUT / f"{f}.png").size)


if __name__ == "__main__":
    main()
