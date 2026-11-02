#!/usr/bin/env python3
"""Rasterises hand-written SVG (or HTML/CSS) art to transparent PNGs with headless Google Chrome.

Free and local: no paid service, no extra install on a Mac that has Chrome. Gradients, filters
(blur, drop shadows), masks, clip paths and web fonts all render as in a browser.

Usage:
    python3 svg_to_png.py ART.svg OUT.png [--scale 2]          one file, at scale x its own size
    python3 svg_to_png.py ART.svg OUT.png --size 1024x1024       exact output size
    python3 svg_to_png.py --batch SRC_DIR OUT_DIR [--scale 2]    every .svg in a folder

The SVG needs width and height attributes (or --size). Corners stay transparent
(--default-background-color=00000000), so the PNG is ready for Godot.
"""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def svg_size(svg: Path) -> tuple[float, float]:
    head = svg.read_text()[:2000]
    w = re.search(r'\bwidth="([\d.]+)', head)
    h = re.search(r'\bheight="([\d.]+)', head)
    if not (w and h):
        raise SystemExit(f"{svg}: add width and height attributes, or pass --size")
    return float(w.group(1)), float(h.group(1))


def render(svg: Path, out: Path, width: int, height: int) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp, "page.html")
        page.write_text(
            '<html><body style="margin:0;background:transparent">'
            f'<img src="{svg.resolve().as_uri()}" width="{width}" height="{height}" style="display:block">'
            "</body></html>")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--default-background-color=00000000",
                        f"--window-size={width},{height}", f"--screenshot={out.resolve()}", page.as_uri()],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    print(out, f"{width}x{height}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("out")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--size")
    p.add_argument("--batch", action="store_true")
    a = p.parse_args()
    pairs = ([(s, Path(a.out) / (s.stem + ".png")) for s in sorted(Path(a.src).glob("*.svg"))]
             if a.batch else [(Path(a.src), Path(a.out))])
    for svg, out in pairs:
        if a.size:
            w, h = (int(v) for v in a.size.lower().split("x"))
        else:
            sw, sh = svg_size(svg)
            w, h = round(sw * a.scale), round(sh * a.scale)
        render(svg, out, w, h)


if __name__ == "__main__":
    main()
