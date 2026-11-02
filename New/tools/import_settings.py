#!/usr/bin/env python3
"""Applies the project's import settings to Godot's .import files (safe to run again).

- Sprites, the logo and UI icons get mipmaps: they are drawn smaller than their pixels on
  small phones, and mipmaps keep them smooth instead of shimmering.
(Fonts stay normal dynamic fonts: MSDF clipped thin glyphs such as "!" in Godot 4.7.)

Usage (from New/): python3 tools/import_settings.py && Godot --headless --path . --import
"""
import re
from pathlib import Path

NEW = Path(__file__).resolve().parents[1]


def set_params(path: Path, values: dict) -> bool:
    text = path.read_text()
    new = text
    for key, value in values.items():
        new, n = re.subn(rf"^{re.escape(key)}=.*$", f"{key}={value}", new, flags=re.M)
        if n == 0:
            new = new.rstrip("\n") + f"\n{key}={value}\n"
    if new != text:
        path.write_text(new)
        return True
    return False


# Pictures stored block-compressed in video memory (S3TC on desktops, ETC2/ASTC on phones: a
# quarter of the memory, 1 byte a pixel): Panoramic's atlases and the big painted layers of the
# world and the bandits. Not the pictures whose channels are data (terrain_shape.png), the smooth
# sky gradients (blocks would show), the big menu pictures, nor the interface.
VRAM = ["hero/hero_atlas_", "world/", "bandit/"]
LOSSLESS = ["world/terrain_shape.png", "world/sky.png", "world/sunset_sky.png"]


def compressed(imp: Path) -> bool:
    rel = str(imp.relative_to(NEW / "assets/art"))[: -len(".import")]
    return any(rel.startswith(p) for p in VRAM) and rel not in LOSSLESS


changed = []
for imp in sorted(NEW.glob("assets/art/**/*.png.import")):
    if "/icons/" in str(imp) or imp.name.startswith("boot_splash"):
        continue
    values = {"mipmaps/generate": "true", "compress/mode": "2" if compressed(imp) else "0"}
    if compressed(imp):
        values["compress/high_quality"] = "false"
    if set_params(imp, values):
        changed.append(imp)
for imp in sorted(NEW.glob("assets/icons/*.svg.import")):
    if set_params(imp, {"mipmaps/generate": "true"}):
        changed.append(imp)

# Make Godot re-import what changed: drop the cached results.
cache = NEW / ".godot/imported"
for imp in changed:
    source = imp.name[: -len(".import")]
    for f in cache.glob(source + "-*"):
        f.unlink()
print(f"updated {len(changed)} import files")
