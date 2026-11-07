# DieSide sprites

The hero's side-view death (the `Making/DieSide` capture) as cel-shaded anime sprites in the look of the
key art (`Making/segments.zip`). Made entirely with local tools: Blender renders the user's model, Python
paints it. The same rules on every frame, so the animation is consistent by construction.

## Make them

```sh
cd Making/DieSide_sprites
/Applications/Blender.app/Contents/MacOS/Blender -b ../Animation.blend --python tools/die_render.py -- --out render/r2048 --size 2048
python3 tools/toon_paint.py render/r2048          # -> render/r2048/paint
python3 tools/pack_frames.py render/r2048/paint out
```

| Tool | Does |
|---|---|
| `tools/die_render.py` | Renders `4_Die` (action `mixamo.com.003`) through `Cam_Side`, the video's view, as data passes: albedo, light (key / fill / rim in R / G / B), normal, depth + occlusion. The `.blend` is only read. `--frames` picks the frames (default: 1, 6, 9 … 54, 60, 78). |
| `tools/toon_paint.py` | Paints them: materials from the albedo (skin, hair, scarf, blue and silver armour, fur), four soft cel bands (cool violet shade, warm light), a golden rim, armour glints, a hair shine, ink outlines (silhouette, depth steps, material edges). Colours and bands are the tables at the top. |
| `tools/pack_frames.py` | Shrinks to the 1024 render scale, crops all frames to one shared box, writes the sheet, a half-size sheet, the JSON (fps, pivot), a preview GIF and a comparison with the video. |

## Output (`out/`)

- `frames/die_00.png … die_19.png`: 775 × 721, transparent, registered.
- `die_sheet.png` (5 × 4, full) and `die_sheet_half.png` (the game's atlas scale, 387 × 360 a frame).
- `die_sheet.json`: 12 fps, no loop, hold the last frame; pivot = the ground under his hips.
- `die_preview.gif`, `compare.png`.

He falls with his head to the right of the screen; flip horizontally for a fall to the left.

## In the game

The game's `die` animation (a bandit's blow) is this death, mirrored to fall back to the left, its sun on the
left. `New/tools/art/hero_atlas.py` takes it from `game/die/` (its `SOURCES`) and every other animation from
its usual renders, and draws the game's own outline and sun rim on it, as on the run and the jump:

```sh
cd Making/DieSide_sprites
F=1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33,35,37,39,41,43,45,47,49,62,78   # the old death's frames: same timing in the game
/Applications/Blender.app/Contents/MacOS/Blender -b ../Animation.blend --python tools/die_render.py -- --out render/game2048 --size 2048 --frames $F --mirror-lights
python3 tools/toon_paint.py render/game2048 --game   # no outline or rim of its own
python3 tools/game_export.py render/game2048 game/die
cd ../../New && python3 -c "import sys; sys.argv=['x']; sys.path.insert(0, 'tools/art'); import hero_atlas; hero_atlas.main()"
```

(`hero_atlas.main()` alone: running the file also rebuilds the menu, win and defeat pictures from their renders.)

## Earlier experiments (kept for reference)

- `tools/clean_frames.py`, `make_grid.py`, `process_sheet.py`, `prompt.txt`: removing Blender's overlays from
  the capture and repainting it with an image model (not used: no paid generator).
- `tools/make_reference.py`: the hero cut out of the key art (`work/ref_style.png`).
- `tools/toon_test.py`: a 2D-only recolour of the capture (`out_toon_test/`), rougher than the Blender path.
