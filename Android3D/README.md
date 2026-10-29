# Chaka Zulu 3D — Android

The Chaka Zulu game rebuilt in full 3D: a third-person runner through a golden-hour
African savanna. Pure Java + OpenGL ES 3.0 (no game engine), so the project stays
small (≈7 MB bundle) and opens directly in Android Studio.

## The game

Panoramic runs along a three-lane savanna track toward the HOME log.

| Action | Gesture |
|---|---|
| Change lane | swipe left / right |
| Jump (and stomp bandits) | swipe up |
| Slide under gates (in the air: slam down) | swipe down |
| Throw the blue ring (smashes crates, rocks, bandits) | tap, or a second finger |

- **Red bobs** to collect (combo sound rises), **golden bob** = 8 s shield.
- **Obstacles**: logs (jump), crate stacks and rocks (dodge or break with a ring),
  bunting gates (slide), rivers (jump), bandits running at you (ring, stomp or dodge).
- 3 lives, then game over. Reaching HOME ends the level with 1–3 stars
  (≥ 50 % and ≥ 80 % of the red bobs). Each level is longer and faster; level 1
  teaches every move once.
- Progress, stars, best score and sound settings are saved on the phone.

## Look

Everything is built from code (no 3D files): flat-shaded low-poly models, real-time
soft shadows from a low sun, a gradient sky with sun glow, fog that melts into the
sky, hazy mountains and clouds, animated water, particles (dust, sparkles, splashes,
debris, confetti), camera swoops and shake, 4x anti-aliasing. The menus and HUD are
Android views drawn over the 3D view.

## Run it

Open this `Android3D/` folder in Android Studio and press Run. Debug builds install
as **Chaka Zulu 3D** (`com.HaizStudio.ChakaZulu.play3d`) next to the Play Store game
and always show Google's test ads.

Testing shortcuts (debug builds only):

```bash
# level 2, start at 300 m, cannot lose lives
adb shell am start -n com.HaizStudio.ChakaZulu.play3d/com.HaizStudio.ChakaZulu.Starting --ei play 2 --ef skip 300 --ez god true
```

`adb logcat -s ChakaZulu3D` then prints where every obstacle of that level is.

## Publish

Release builds use the Play Store id `com.HaizStudio.ChakaZulu`, version **2.0 (4)**,
higher than the 2D update in `../Android` (1.1, code 3) — publish this one as the next
update, or keep the 2D one. Signing, Firebase (`app/google-services.json`) and AdMob
setup are the same as in [`../Android/README.md`](../Android/README.md).

## Code map (`app/src/main/java/com/HaizStudio/ChakaZulu/`)

| Path | What |
|---|---|
| `Starting.java` | the activity: 3D view, menus, HUD, results, saving, ads |
| `game/World.java` | all game rules (runs on the GL thread) |
| `game/LevelGenerator.java` | levels from patterns; tune difficulty here |
| `game/Hero.java`, `game/Level.java` | hero state, level data |
| `render/GameRenderer.java` | frame loop, shadow pass, drawing, lighting constants |
| `render/Models.java` | every 3D model and colour palette |
| `render/ChunkBuilder.java` | terrain, track, rivers and scenery in 40 m chunks |
| `render/Rig.java` | character animation (run, jump, slide, throw, celebrate…) |
| `render/CameraRig.java` | menu orbit, chase cam, finish and game-over shots |
| `gl/` | shaders, meshes, mesh builder, shadow map, particles |
| `platform/` | sounds, saved progress, AdMob + consent |
| `ui/` | swipe input, outlined title text |
| `tools/make_sounds.py` | regenerates the sound effects (`python3 tools/make_sounds.py`) |
