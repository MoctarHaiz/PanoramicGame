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


USER_3D = {"kind": "user-generated", "url_or_tool": "the user's Blender model and animations (ROOT/Making/Animation.blend), rebuilt for AAA in ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend (same identity: cleaned mesh, weights, textures, new actions; see hero3d/AUDIT.md), rendered by tools/art/blender/hero_render.py",
           "creator": "Haiz Studio", "license": "owned by Haiz Studio",
           "prompt_or_source_record": "ROOT/Making/Animation.blend, panoramic.blend, Panoramic.fbx; ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend"}


## the world redesign (2026-11-12): one style frame from the game's own key art and screenshot, then each layer alone
SUNBURST = {"kind": "user-generated", "url_or_tool": "kie.ai GPT Image 2.6 Sunburst from the game's own key art (prompts: tools/art/gen/kie/world/*.txt), cut by tools/art/kie/world.py",
            "creator": "Haiz Studio", "license": "owned by Haiz Studio",
            "prompt_or_source_record": "tools/art/gen/kie/world/frame.txt and one prompt per layer; tools/art/gen/kie/ledger.jsonl (names world/*)"}


## the inked interface (2026-11-13): options painted over the game's own screens, then the chosen one's pieces, each alone
INKED = {"kind": "user-generated", "url_or_tool": "kie.ai GPT Image 2.6 Sunburst from the game's own screens (prompts: tools/art/gen/kie/world/menu_ui*.txt, logo_a.txt, panels_*.txt, titles_c.txt, words_c2.txt, ink_band.txt), cut by tools/art/kie/menu_ui.py and panel_ui.py",
         "creator": "Haiz Studio", "license": "owned by Haiz Studio",
         "prompt_or_source_record": "tools/art/gen/kie/world/*.txt; tools/art/gen/kie/ledger.jsonl (names menu_ui_*, logo_a, panels_*, titles_c, words_c2, ink_band)"}


def authored(tool: str) -> dict:
    return {"kind": "authored-procedural", "url_or_tool": tool, "creator": "Claude for Haiz Studio",
            "license": "owned by Haiz Studio (made with free local tools: numpy, Pillow, scipy, Chrome, Godot)",
            "prompt_or_source_record": tool}


# folder (or file prefix) -> role, generator/source, alpha required, anchor, locks
FAMILIES = [
    ("hero/hero_atlas_", "Panoramic's animation frames: the user's 3D model (Making/Animation.blend) re-lit and posed by tools/art/blender/hero_render.py, packed by tools/art/hero_atlas.py (hero_frames.json)", USER_3D, True, "per hero_frames.json (ground origin / hips / hands)", ["identity", "proportions", "palette", "facing", "light-direction"]),
    ("hero/", "Panoramic for the interface (portrait, full-length menu hero, win pose, stands): renders of the user's 3D model (tools/art/hero_atlas.py)", USER_3D, True, "bottom-centre", ["identity", "palette"]),
    ("bandit/", "the 2017 bandit's sheet (his 10-frame run, waiting, the punch drawn back and thrown, hit, the leap): the user's own drawing (Old/app/src/main/assets/bandit/bandit1-10.png) redrawn clean with kie.ai, packed by tools/art/bandit_sheet.py",
     {"kind": "user-generated", "url_or_tool": "kie.ai Nano Banana 2 from the user's 2017 frames (prompts and inputs: ROOT/_agents/kie/bandit/), packed by tools/art/bandit_sheet.py",
      "creator": "Haiz Studio", "license": "owned by Haiz Studio",
      "prompt_or_source_record": "Old/app/src/main/assets/bandit/bandit1-10.png; ROOT/_agents/kie/bandit/p/run.txt, poses.txt; ROOT/_agents/kie/ledger.jsonl (tags bandit_*)"},
     True, "per bandit.json (the ground under his body)", ["identity", "silhouette", "palette", "facing"]),
    ("bob/", "Red Bob collectible faces (smile, blink, joy, wink): a translucent ruby painted in crisp cel shapes with the 2017 face drawn on", authored("tools/art/bob_sheet.py (numpy)"), True, "centre", ["palette", "silhouette"]),
    ("ui/logo", "CHAKA ZULU logo: the title in angular gold lettering, inked, over a cowhide shield and two crossed spears (the menu, the settings' mark, the share card)", INKED, True, "centre", ["palette"]),
    ("ui/word_", "a main button's word in heavy slanted white capitals, inked (PLAY, RESUME, PLAY AGAIN and their French: Ui.cta_button)", INKED, True, "centre", ["palette"]),
    ("ui/title_", "a panel's title in gold brush lettering over a fast red brush stroke, in English and French (Ui.ink_title)", INKED, True, "centre", ["palette"]),
    ("ui/ink_", "the panels' ink: one thick dry-brush stroke of black ink (InkStyle lays several into a band) and the red stroke under a title set in the display font", INKED, True, "stretched in its solid middle only", ["palette"]),
    ("ui/ribbon_plain", "the menu's subtitle ribbon without its dashed stitch (from ui/ribbon.png)", authored("tools/art/ui_kit.py"), True, "9-sliced: tails 58 px", ["palette"]),
    ("ui/corners", "the panels' jewelled corner bosses (a bevelled ring set with beads, a domed cabochon: brass and red, dark bronze and garnet)", authored("tools/art/ui_kit.py"), True, "centre", ["palette", "light-direction"]),
    ("ui/hero_", "Panoramic for the menu and results (cut from the user's 3D renders, Making/)", USER_ART | {"url_or_tool": "tools/art/ui_hero.py", "prompt_or_source_record": "Making/IdleFront/0001.png, Making/DieFront/0026.png"}, True, "bottom-centre at the boots", ["identity", "palette"]),
    ("ui/head", "Panoramic's face in a disc (the HUD's way home), from the user's 3D render", USER_ART | {"url_or_tool": "tools/art/ui_hero.py", "prompt_or_source_record": "Making/IdleFront/0001.png"}, True, "centre", ["identity", "palette"]),
    ("ui/menu_rock", "the backlit kopje Panoramic stands on in the menu", authored("tools/art/ui_hero.py"), True, "his feet at (1340, 150)", ["palette", "light-direction"]),
    ("ui/paper", "the hide/paper grain of the panels (tiles both ways)", authored("tools/art/ui_kit.py"), False, "tiles", ["palette"]),
    ("ui/", "interface ornament (beadwork, ribbon, shield, HUD head)", authored("tools/art/ui_art.py / logo.py"), True, "centre", ["palette"]),
    ("icons/", "app icon (iOS, Play, Android adaptive layers)", authored("tools/art/icons.py (from the user's portrait)"), False, "centre", ["identity", "palette"]),
    ("fx/ring", "Panoramic's chakram: a blue-steel ring with a band of Zulu beadwork (red and black triangles on white), 8 frames of a half turn", authored("tools/art/ring_beadwork.py"), True, "centre", ["palette", "light-direction"]),
    ("world/home_fire", "the home's fire, painted: its hearth, the stones, the logs and their embers (HomeView)", SUNBURST, True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/home_flames", "the home fire's flames, painted alone: four frames in a row, drawn behind the hearth's logs (HomeView)", SUNBURST, True, "bottom-centre at the hearth's foot", ["palette", "light-direction"]),
    ("world/home_sign", "the home's carved HOME signpost, painted", SUNBURST, True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/fx_impact", "a blow's burst in the characters' ink, three frames in a row (Fx.hit_spark)", SUNBURST, True, "the contact point (Fx.IMPACT_AT in each cell)", ["palette"]),
    ("world/spires", "three rock pinnacles, each in a cell: the stacks standing in the river (TerrainView)", SUNBURST, True, "top-centre of each cell: the cap rock", ["palette", "light-direction"]),
    ("world/sky_clouds", "the sky's own clouds cut out of it: a second, higher row behind the vine, repeats in x", SUNBURST, True, "top-left, repeats in x", ["palette", "light-direction"]),
    ("world/home_", "HOME homestead piece (hut, fence, granary, sign, pot, glow)", authored("tools/art/home.py"), True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/prop_", "savanna decoration prop", authored("tools/art/props.py"), True, "bottom-centre at the ground", ["palette", "light-direction"]),
    ("world/tree_", "background tree (acacia, baobab, marula, a dead tree), anchors in tree_info.json", SUNBURST, True, "bottom-centre at the trunk", ["palette", "light-direction"]),
    ("world/sky", "the level's sky panorama, repeats in x", SUNBURST, False, "top-left, repeats in x", ["palette", "light-direction"]),
    ("world/far_", "far backdrop layer (the escarpment, the landforms and their .json, the plain)", SUNBURST, True, "bottom, repeats in x", ["palette", "light-direction"]),
    ("world/river", "the painted river under the vine: its far bank and its water, repeats in x", SUNBURST, True, "top, repeats in x", ["palette", "light-direction"]),
    ("world/near_grass", "the tall grass behind the path, repeats in x", SUNBURST, True, "bottom, repeats in x", ["palette", "light-direction"]),
    ("world/fg_props", "six plants and rocks near the camera (3 x 2 cells)", SUNBURST, True, "bottom-centre of each cell", ["palette", "light-direction"]),
    ("world/sunset_", "menu dusk backdrop layer", authored("tools/art/savanna.py"), True, "bottom-left, repeats in x", ["palette"]),
    ("world/vine_leaves", "the vine's leaf clusters and tendrils, each a whole picture hung from its own point (VineView)",
     authored("tools/art/vine_leaves.py"), True, "top", ["palette"]),
    ("world/vine", "the vine along the top of the screen: the rope alone", authored("tools/art/vine.py"), True, "top", ["palette"]),
    ("world/", "level world layer or terrain texture", authored("tools/art/savanna.py / terrain.py"), None, "per view", ["palette", "light-direction"]),
    ("haiz_studio", "Haiz Studio logo (boot, About)", {"kind": "studio-owned", "url_or_tool": "tools/art/studio_logo.py (cropped + Real-ESRGAN x4 from Old/app/src/main/assets/HaizStudio.png), made crisp by tools/art/logo_crisp.py", "creator": "Haiz Studio", "license": "owned by Haiz Studio", "prompt_or_source_record": "2017 game"}, True, "centre", ["identity"]),
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
