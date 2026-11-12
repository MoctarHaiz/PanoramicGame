# Chaka Zulu 2.0

The 2017 Android game, rebuilt with **Godot 4.7.2** (GDScript) for **Google Play and the App Store**:
the same level and rules (run at the old 40 updates a second, so every jump reaches exactly as far as
in 2017), Panoramic rendered from the user's 3D model, a painted savanna, new sounds, a real
ending with stars, English and French, AdMob with Google's consent form and Apple's tracking prompt,
and the phone's share sheet.

To publish, follow [docs/RELEASE.md](docs/RELEASE.md). The plan is [docs/PLAN.md](docs/PLAN.md).

## Requirements

| What | Version | Used for |
| --- | --- | --- |
| Godot | 4.7.2, with the Android and iOS export templates | everything |
| OpenJDK | 17 (`brew install openjdk@17`), set in Editor Settings › Export › Android | Android builds |
| Android SDK | platform 36, build-tools 36 | Android builds |
| Xcode | 27 | iOS builds and the Simulator |
| Python | 3.10+ with Pillow, numpy, scipy, onnxruntime | art and sound tools |

## Playing and testing on a computer

Open `project.godot` in Godot and press Play. Mouse drags stand in for swipes; on a keyboard:
arrows or WASD to move, space to throw, P or Esc to pause.

- `Godot --headless --path . res://tests/run_tests.tscn` runs the checks (every script compiles, the
  2017 numbers, the 10-tile climb, hanging, bandits, rings, the same game at 30/60/120/144 Hz, saves,
  every text in English and French, release settings), then the release checks: every screen at the
  six device sizes in English and French (no error, buttons and texts inside the safe area, nothing cut,
  no raw key), sounds, the save round trip, no node left after a run, pausing at random moments, the
  bot's recorded run through the real game screen. About 40 s; exit code 1 if anything fails.
  - `-- --quick` leaves out the checks that open screens (a few seconds, while working).
  - `-- --bot` also lets the bot play the whole level (a few minutes; it gets home with 3 lives) and
    records its run in `build/qa/` for the tools below (again only when the rules, level or bot change).
- `Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tests/capture.tscn -- --out=DIR [--devices=…] [--shots=…] [--lang=fr|en,fr] [--ads=off]`
  renders screens at exact phone and tablet sizes, with simulated notches (`DEVICES` in `tests/capture.gd`):
  every screen and level moment a store release needs (shots listed in its header). `--lang=en,fr`
  takes both languages in one run (`DIR/en`, `DIR/fr`); `--shots=share` saves the card a player shares.
- `… res://tests/strip.tscn -- --out=FILE.png [--moment="…"] [--act=jump@2] …` saves a contact sheet of
  frames (a motion strip). `--film=DIR` saves every frame instead (`DIR/0001.png…`) and makes `DIR.mp4`
  with ffmpeg (`--frames=900 --every=2 --size=2868x1320 --bot`: a 30 s store preview at 30 fps);
  `--layers=1` builds one frame up layer by layer (depth, z-order). Options in its header.
- `… res://tests/perf.tscn -- [--device=iphone15_2556x1179] [--seconds=40]` plays the level with the bot's
  recorded run and reports, for the menu, the run, pause and the results: texture and video memory, draw
  calls, frame times (the game's own work and the wall time), nodes, pictures loaded mid-run, against
  the budgets (texture memory under 80 MB, no frame of play over 16 ms, nothing left behind). Exit code 1
  if one fails; JSON in `build/perf/`. It runs the boot screen's warm-up first, as the game does.
  `--textures=12` lists the biggest pictures in memory per phase; `--load-profile=10` shows where the
  level's opening frame goes; `--hide=name,…` hides layers for an A/B of their cost.

## Controls (as in 2017)

| Move | Touch | Keyboard |
| --- | --- | --- |
| Throw a ring | tap | Space |
| Jump (to the top of the screen: hang from the vine) | swipe up | Up / W |
| Let go of the top, or crouch | swipe down | Down / S |
| Step forward | swipe right | Right / D |
| Pause | pause button, Android back | P / Esc |

## Bandits

Two kinds come at random: the bandit (2 rings) and the strong one (3 rings); one in three leaps once over a ring.
Since 2026-11-10 they read the ground ahead of them (`World._sense`):

| What it meets | What it does |
| --- | --- |
| Open grass | runs at him and punches as it reaches him |
| A wall or a step up | one leap onto its top, from far enough to clear the corner |
| A pool up to 6 tiles wide, with a real bank beyond | leaps it |
| A wider pool, or a far bank he is about to reach | holds its bank 6 tiles back from the end, as a guard: ring it or hop it once across |
| A ring that doesn't knock it out | stopped for a quarter of a second; knocked out of a leap (into the pool, if it is over one) |

No leap ever comes down where his run is taking him, and nobody guards a stepping stone. The bot still gets home
with 3 lives (`tests/run_tests.tscn -- --bot`).

## Building

```sh
tools/build_android.sh            # build/android/chakazulu-2.0.0.aab, signed with the 2019 Haiz Studio key
tools/build_android.sh --apk      # also a signed release APK to try on a phone
tools/build_android.sh --debug    # debug APK (Google test ads), no key needed
tools/build_ios.sh                # Xcode project in build/ios/ (team ZUGMSRF5HZ)
tools/build_ios.sh --check        # compiles that project for iPhone without signing
tools/build_ios.sh --simulator "iPhone 18 Pro Max"   # runs it in the Simulator
```

The Android key lives in `signing/` (`upload.jks` + `keystore.properties`, git-ignored). It was recovered
from the 2019 history of this repository; the script reads it without printing passwords and refuses a
bundle whose certificate isn't SHA-256 `08:BE:42:CB:…:85:B2`.

## Settings without code: `config/game_config.cfg`

| Section | What |
| --- | --- |
| `[store]` | Play link, App Store id (once the app exists), privacy policy URL |
| `[ads]` | ads on or off, a full-screen ad every N game overs, live ad units (debug builds always use Google's test units) |
| `[remove_ads]` | the "Remove ads" purchase: off until the product exists in both stores |
| `[leaderboards]` | Play Games and Game Center leaderboard ids: off until they exist |

The AdMob **app** ids are in Project Settings › Admob (Google's sample ids until the Chaka Zulu apps exist).

## Art and sound (all re-runnable)

| Tool | Makes |
| --- | --- |
| `tools/art/blender/hero_render.py` | Panoramic's animations from the user's 3D model (`Making/Animation.blend`), re-lit for the savanna, new moves posed in Blender |
| `tools/art/hero_atlas.py` | packs those frames into `assets/art/hero/hero_atlas_*.png` + `hero_frames.json`; the menu and card pictures |
| `tools/art/blender/ring_render.py` | the throwing ring in 3D (8 frames of a turn) |
| `tools/art/kie/kie.py` | the kie.ai client (Nano Banana 2 stills, GPT Image 2.6 Sunburst and Seedream 5.5 with `--model`, Kling 4.0 clips): the key is read from `~/.config/kie/key`, every task and its credits are logged in `tools/art/gen/kie/` (git-ignored) |
| `tools/art/kie/clip.py`, `sheet.py` | a run clip to clean drawings: the frames keyed, each pose the median of its repeats in the clip, the stride laid on a sheet, redrawn crisp at 4K and cut back onto the clip's canvas |
| `tools/art/kie/throw.py`, `hero_pack.py` | Panoramic's run (12 drawings, his boot held on the ground at 16 a second), his throw laid over the run (24), his jump (8); packs `hero_atlas_*.png` + `hero_frames.json`, his other moves kept from the atlas before |
| `tools/art/kie/between.py`, `bandit_pack.py` | the bandits' runs: the clip's 6 keys and 6 in-betweens drawn on their chart (12 drawings each); packs `assets/art/bandit/<kind>.png` + `.json`, their other poses kept |
| `tools/art/kie/world.py` | the level's backdrop from its painted layers (GPT Image 2.6 Sunburst: one style frame, then each layer alone on a transparent background): cuts and makes repeat `sky.png`, `far_wall.png`, `far_mesa_pieces.png` + `.json`, `far_hills.png`, `mid_hills.png`, `near_grass.png`, `tree_*.png` + `tree_info.json`, `fg_props.png` |
| `tools/art/kie/menu.py` | the menu's key art: Panoramic cut out of the old key art as painted (`kie.py cutout`) over a landscape painted for him in the level's style; then `tools/art/ui_keyart_soft.py` |
| `tools/art/bandit_palette.py`, `tools/art/grass_gold.py` | the bandits' night-raider palette (violet scarves, slate shirts, ash hair) and the turf's gold-green, each by hue on the pictures in place, every pixel's light kept |
| `tools/art/material.py` | lit, tiling soil and sandstone; the sandstone stacks (used by `terrain.py`) |
| `tools/art/terrain.py` | the ground: soil, sandstone, stacks, cell shapes, grass caps and ends, roots, tufts |
| `tools/art/savanna.py` | the sky, sun, god rays, clouds, far escarpments, hills, tall grass, motes, birds; the menu's sunset |
| `tools/art/trees.py` | acacias and baobabs (background and props) |
| `tools/art/props.py` | stump, shrubs, reeds, rocks, aloe, termite mound |
| `tools/art/home.py` | HOME: the beehive hut and its front, granary, fence, carved sign, pot, firelight |
| `tools/art/vine.py` | the liana along the top of the screen |
| `tools/art/world_preview.tscn` | renders the world alone at any scroll, for art review (`-- --at=24640`) |
| `tools/art/icons.py` | app icons from the portrait (iOS, Play, Android adaptive) |
| `tools/sfx_synth.py` | every sound effect, synthesised in A (the key of the theme) |

The models live in `tools/art/models/` (git-ignored; the URLs are in `hero_sprites.py`).
Art still wanted from the image generator: `docs/art/ASSET_REQUESTS.md`.

## Layout

```
src/autoload/   Config, Save, Device (safe area, banner), Audio, Haptics, Services, Nav
src/game/       Level (the 2017 map), World (the rules), WorldView, HeroView, SavannaView, VineView,
                RingView, HUD, effects (Fx, Confetti), the game screen
src/screens/    boot (consent while the logo shows), menu, settings and About
src/services/   ads, analytics, share, store (Remove ads), leaderboards, push: each works without its plugin
src/ui/         the interface kit (candy buttons, display text, chips, toggles, safe area, share card)
assets/         level, art (hero, world, icons, 2017 stand-ins in old/), audio, fonts, icons (Phosphor)
tests/          run_tests, bot, capture
```
