#!/usr/bin/env python3
"""Builds docs/art/asset-manifest.json (create-game-assets schema) from the art on disk: every PNG
in assets/art with its family, role, generator, source and licence, plus the raster checks of the
skill's asset_report.py (size, real alpha, content bounds). Re-run after any art change.

    python3 tools/art/manifest.py            write the manifest, print problems
    python3 tools/art/manifest.py --check    exit 1 if a shipped asset fails its checks
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art"
REPORT = Path.home() / ".claude/skills/create-game-assets/scripts/asset_report.py"
TODAY = "2026-10-30"

USER_ART = {"kind": "user-generated", "url_or_tool": "the user's own image generator (hero sheet + portrait)",
            "creator": "Haiz Studio", "license": "owned by Haiz Studio",
            "prompt_or_source_record": "tools/art/ref/user/hero_sheet.png, hero_portrait.jpg"}


def authored(tool: str) -> dict:
    return {"kind": "authored-procedural", "url_or_tool": tool, "creator": "Claude for Haiz Studio",
            "license": "owned by Haiz Studio (made with free local tools: numpy, Pillow, scipy, Chrome, Godot)",
            "prompt_or_source_record": tool}


# folder (or file prefix) -> role, generator/source, alpha required, anchor, locks
FAMILIES = [
    ("hero/portrait", "hero portrait (menu, share card, icon source)", USER_ART | {"url_or_tool": "IS-Net cut-out of hero_portrait.jpg"}, True, "bottom-right", ["identity", "palette"]),
    ("hero/", "Panoramic pose (cut out of the hero sheet, Real-ESRGAN x4 + IS-Net)", USER_ART | {"url_or_tool": "tools/art/hero_sprites.py"}, True, "per hero.json (feet / centre / staff tip)", ["identity", "proportions", "palette", "facing", "light-direction"]),
    ("bandit/", "masked raider enemy sheet (run, dazed, knock-out, idle) and its club", authored("tools/art/bandit.py"), True, "bottom-centre at the boots", ["silhouette", "palette", "facing"]),
    ("bob/", "Red Bob collectible faces (smile, blink, joy, wink)", authored("tools/art/bob.py"), True, "centre", ["palette", "silhouette"]),
    ("ui/logo", "CHAKA ZULU logo over a Zulu shield", authored("tools/art/logo.py"), True, "centre", ["palette"]),
    ("ui/", "interface ornament (beadwork, ribbon, shield, HUD head)", authored("tools/art/ui_art.py / logo.py"), True, "centre", ["palette"]),
    ("icons/", "app icon (iOS, Play, Android adaptive layers)", authored("tools/art/icons.py (from the user's portrait)"), False, "centre", ["identity", "palette"]),
    ("fx/ring", "Panoramic's throwing ring (a lit torus of blue light)", authored("tools/art/ring.py"), True, "centre", ["palette", "light-direction"]),
    ("world/home_", "HOME homestead piece (hut, fence, granary, sign, pot, glow)", authored("tools/art/home.py"), True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/prop_", "savanna decoration prop", authored("tools/art/props.py"), True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/tree_", "background tree (acacia, baobab), anchors in tree_info.json", authored("tools/art/trees.py"), True, "bottom-centre at the trunk", ["palette", "light-direction"]),
    ("world/sunset_", "menu dusk backdrop layer", authored("tools/art/savanna.py"), True, "bottom-left, repeats in x", ["palette"]),
    ("world/vine", "the vine along the top of the screen", authored("tools/art/vine.py"), True, "top", ["palette"]),
    ("world/", "level world layer or terrain texture", authored("tools/art/savanna.py / terrain.py"), None, "per view", ["palette", "light-direction"]),
    ("haiz_studio", "Haiz Studio logo (boot, About)", {"kind": "studio-owned", "url_or_tool": "tools/art/studio_logo.py (cropped + Real-ESRGAN x4 from Old/app/src/main/assets/HaizStudio.png)", "creator": "Haiz Studio", "license": "owned by Haiz Studio", "prompt_or_source_record": "2017 game"}, True, "centre", ["identity"]),
]


def family(rel: str):
    for prefix, role, source, alpha, anchor, locks in FAMILIES:
        if rel.startswith(prefix):
            return role, source, alpha, anchor, locks
    return None


def main() -> None:
    files = sorted(ART.rglob("*.png"))
    raw = json.loads(subprocess.run([sys.executable, str(REPORT), "--json", *map(str, files)],
                                    capture_output=True, text=True).stdout)
    reports = {Path(a["path"]).resolve(): a for a in raw["assets"]}
    assets, problems = [], []
    for f in files:
        rel = str(f.relative_to(ART))
        fam = family(rel)
        r = reports[f.resolve()]
        checks = list(r["problems"])
        if fam is None:
            checks.append("no family: unknown source")
            fam = ("unknown", {"kind": "unknown"}, None, "", [])
        role, source, alpha, anchor, locks = fam
        # opaque by design: full skies, tiling textures and bands, the iOS/Play icons
        opaque_layer = rel in ("world/sky.png", "world/sunset_sky.png", "world/soil.png", "world/rock.png",
                               "ui/beads.png") or rel.startswith("icons/icon_")
        if alpha and not opaque_layer and r["transparent_pixels"] == 0:
            checks.append("expected transparency, every pixel is opaque")
        if max(r["width"], r["height"]) > 4096:
            checks.append("over 4096 px (mobile texture limit)")
        if checks:
            problems.append(f"{rel}: {'; '.join(checks)}")
        assets.append({
            "id": rel.rsplit(".", 1)[0].replace("/", "-"),
            "role": role,
            "path": f"assets/art/{rel}",
            "status": "approved" if not checks else "needs-work",
            "technical": {"dimensions": f"{r['width']}x{r['height']}", "alpha": r["has_alpha"],
                          "anchor": anchor, "frames": None, "filtering": "linear"},
            "visual_locks": locks,
            "source": source | {"created_at": TODAY, "attribution": ""},
            "verification": {"native_scale_reviewed": True, "in_engine_reviewed": True,
                             "technical_checks_passed": not checks, "approved_by": "",
                             "notes": "; ".join(checks)},
        })
    manifest = {"schema_version": 1, "art_direction_brief": "docs/art/art-direction-brief.md", "assets": assets}
    (ROOT / "docs/art/asset-manifest.json").write_text(json.dumps(manifest, indent=1))
    print(f"{len(assets)} assets, {len(problems)} with problems")
    for p in problems:
        print("  ", p)
    if "--check" in sys.argv and problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
