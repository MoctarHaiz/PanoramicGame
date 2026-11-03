# Art track log (AAA pass, round 1)

Worktree: `_agents/wt/art/New`. Captures: `_agents/AAA/art/round_<n>/`. Blender copies and renders:
`_agents/AAA/blender/`.

## Findings (start of round 1)

- `ROOT/Making/Animation.blend`: one scene (EEVEE, 64 samples, AgX, 1024 x 1024, film transparent), two
  orthographic cameras (`Cam_Side`, `Cam_Front`, ortho scale 1.39), three white lights, four copies of the
  same Mixamo character (41-bone `mixamorig:` rig, 749k-vertex mesh, one material: 4K base colour + 4K normal
  map), one action each: run 1-17, idle 1-60, jump 1-27, die 1-78 (all the same rest pose, so any action
  plays on any copy).
- Side view: screen right = world -Y (he faces it), up = +Z, the camera at -X: we see his right side (the
  bare arm is the near arm, the blue armoured arm is his left, the far one).
- The run is in place (16 unique frames, frame 17 = frame 1). The jump is a running jump with root
  motion (hips rise and fall): frames 1-2 take-off, 3-9 rise, 10-14 tuck at the apex, 15-19 legs down,
  20-27 landing into the run. Die: a hit, a twist and a fall onto his back, lying still from ~frame 50.
- The 3D model has no staff (the painted hero had one): he hangs from the vine by his hands now.
- UI uses only `assets/art/hero/portrait.png` (menu, share card, the win card); `stand_front.png` and
  `stand_side.png` are loaded only by HeroView.
- Texture estimate of `assets/art/` (without ui/), RGBA8 + mipmaps: 86 MB.

## Plan

1. `tools/art/blender/hero_render.py`: re-light (warm key from the upper left, rim, ground bounce, cool
   sky fill) and render every animation, plus new ones posed with bpy (hang, catch, throw, climb, crouch,
   hurt, cheer); per frame, the projected positions of the hips, feet and hands go in a JSON.
2. `tools/art/hero_atlas.py`: trim, downsize, pack into atlases, write `assets/art/hero/hero_frames.json`.
3. HeroView: play frames by state (run synced to the ground speed, jump by vertical speed).
4. World toward the lit look; texture memory under 80 MB.

## Log

### 1. The new hero in the game (done, being refined)

- `tools/art/blender/hero_render.py` (Blender 5.2, EEVEE): re-lit (AgX Punchy; warm key sun from the upper
  left, a warm-white rim on his front edge, an orange rim on his back, a cool sky fill, an ochre bounce
  from below); the user's actions plus new posed ones: `run` is the user's run with 60 % of its leg swing
  (the game's ground moves 233 units/s, a jog for his size: at full stride the planted boot slid at any
  frame rate; now 19.6 frames/s keep it planted, measured by `hero_atlas.py`), `hang` (turned 32° to us,
  both hands up, legs swaying), `catch`, `throw` (the wind-up and the release over each of the 16 run
  frames, so his legs keep running), `crouch`, `hurt`, `climb`, `win` (stops, turns to us, fists up,
  cheering loop), `die` (rendered from his other side, so he falls back to the left, away from the
  bandit), plus `menu_hero` (sunset light), `win_front`, `idle_front`. Renders in
  `_agents/AAA/blender/render/`, the lit scene saved as `_agents/AAA/blender/hero_render.blend`.
- `tools/art/hero_atlas.py`: premultiplied downsizing (x0.41: he stands 283 px), trim, shelf-pack into
  3 pages (2048 wide, 9.6 Mpx), colour bled under transparent pixels, `hero_frames.json` (regions, the
  ground origin and the projected hips/hands/toes per frame, `run_fps`). Also writes `portrait.png` (same
  file name and size, now the 3D model, head to hips, sunset-lit), `hero_menu.png` (new: full length,
  fighting stance, for the menu), `hero_win.png` (new: both arms up), `stand_front.png`, `stand_side.png`.
- `src/game/hero_view.gd` rewritten: frames by state (run paced by the ground's speed, the jump by his
  vertical speed: push-off, rise, top, fall, then the landing played out into the run's first frame;
  catch, hang from the hands with a pendulum, climb, mantle, crouch, throw, hurt, die, win); anchors:
  the ground origin at his feet, the hips in the air, the hands on the vine; a soft shadow cast a little
  right of him. No more painted outline, halo, scarf ribbon or stance warp.
- Removed the old painted poses (`crouch/kneel/leap/leap_up/run_a/run_b/tuck.png`, `hero.json`).

### 2. Texture memory

- `tools/art/texture_report.tscn` (menu, then 10 s of play at 2556 x 1179: Godot's total) and
  `tools/art/texture_budget.py` (per picture, from size and import settings).
- Before (with the hero atlas lossless): menu 133 MB, run 157 MB. VRAM compression (S3TC / ETC2) of the
  hero atlases, the world layers (not terrain_shape.png: its channels are data; not the skies) and the
  bandit sheet; the old poses gone; the sky stored at half size: menu 53.6 MB, run 82.7 MB (before the
  sky). The menu's `const LOGO := preload(logo.png)` (ux) keeps a 5 MB logo in memory during play.

### 3. After the orchestrator's review of the renders

- Light: the user's own lights, world, materials and AgX are kept (their deep brown skin, crisp
  muscles, specular boots); I only add a warm rim from the game's sun (3.0, behind him on the upper
  left) and a faint warm bounce (6 W). Measured on IdleSide frame 1: the user's mean colour
  (148, 119, 109), mine without additions (149, 119, 110), with rim and bounce (155, 124, 114).
- Every animation re-rendered in one run with the same settings (no pop between moves); the menu
  picture alone gets the sunset rim.
- Framing: the renders are intermediates; `hero_atlas.py` trims each frame to what it shows and
  scales it to the size it is drawn at, so the atlas spends no pixels on empty canvas.

### 4. QA's art bugs

- ART-1: `BobView.flier()` no longer draws two faded copies of the ball; a short tapered additive
  streak follows it.
- ART-3: the terrain is built lazily, chunk by chunk (`TerrainView.ensure()` for what is on screen,
  `build_ahead()` one more chunk each frame): the level opened in ~150 ms (ground 73 ms of it).
- ART-4: the hit flash counts frames, not the wall clock.

### 5. The world toward the lit look

- `tools/art/material.py`: lit reliefs that tile both ways (spectral noise, wrapped Voronoi, cast
  shadows by marching towards the sun, occlusion, cool sky and warm bounce): `soil.png` (packed
  laterite with half-buried stones) and `rock.png` (rounded weathered sandstone blocks, no brick
  rows). `spires.png`: three sandstone stacks, wider at the foot, eroded, lit as columns: walls one
  or two cells wide (the river's poles, the stacks on the plain) are drawn as stacks.
- `terrain.gdshader`: stronger form (warm lit side, cool core shadow), a deep occlusion under the
  grass lip, softer soil grain, and the open sides of walls eroded (deepest under the lip, little at
  the foot: the lip overhangs, the foot stands wide) with a dark rim on the new edge. The jutting
  chunks (`rock_edges.png`, "a zipper") are gone.
- `water.gdshader`: the banks slope down into the pools (earth seen through the water, further out
  the deeper), no more vertical cuts.
- `form.gdshader` (new): the huts, the granary and the sign lit as rounded forms (sun side, shade
  side, dark foot, warm rim).
- `tools/art/blender/ring_render.py`: the ring is a 3D blue-steel torus with a glowing inner edge,
  8 frames of a half turn (`fx/ring_spin.png`); RingView plays them as it flies.

### 6. More, and the end of round 1

- Ledges: their underside in shade, their ends tapered under the grass (were cut square).
- The savanna rows: stronger aerial perspective (the hill strips and tree rows sink into the cool
  distance), tree heights 0.65-1.35 and wider spacing jitter.
- ART-11: at home the camera push draws the hut and him to the middle of the screen as it goes in
  (`GameScreen._place_camera`, presentation): the iPad no longer loses the hut's right half.
- The die render: from his other side the user's lights are mirrored too (it was dark).
- `_test_art()` in tests/run_tests.gd: the frames, the planted boot's pace, each state's animation,
  the ring frames, the stacks.

Results: tests 341 checks, 0 failed (exit 0); with `-- --bot`: 344 checks, 0 failed, the bot gets
home (state 2, 3 lives, 82 Red Bobs). QA's perf at 2556 x 1179: menu 51.5 MB, play 80.8 MB until
the first pause, then +15.3 MB (the pause's frosted veil, ux) and +8 MB (the resume countdown's
digits, ux): 105.8 MB; results 114 MB; worst frame of play 15.7 ms of work (pass); the level opens
in 241 ms (was 277-302). Art in memory during play: hero 12.2 MB, world ~13 MB, bandit 1.6 MB.

Next: the bandits are still the flat 2D cartoon (a 3D model would end the last style clash); the
Red Bobs; the sky takes ~45 % of the level shots; the HOME sign; the props and the bank cells' faces.

## Round 2 (characters and effects art; env owns the world, light and camera)

Plan: (1) a 3D bandit from the hero's mesh and rig (violet wraps, hood with amber eyes, a club),
same pipeline and lights, in bandit.png's grid so BanditView keeps its logic; (2) Red Bobs
rendered in Blender (bob.png's four faces); (3) rings: slimmer glow, ask audio for a short motion
streak; (4) HeroView on gameplay's hooks (move_phase, air_progress, phase_time, DYING_TIME,
HOME_*), a warm rim and thin outline that read at phone size, a darker contact shadow, hurt as an
additive flicker (no alpha ghost), a stumble, states held >= 6 frames, run_frame(); (5) menu,
win and defeat renders; (6) the studio logo; (7) the null texture on the first boot.

### Round 2 progress

- HeroView now runs on gameplay's hooks: `move_phase()` / `phase_time()` pick the animation (idle,
  run, land, takeoff, rise/apex/fall by `air_progress()`, climb as hand-over-hand pulls then a knee
  over and the mantle, catch then hang, crouch, dead by `death_reason` over DYING_TIME / the pit
  flail, home: the landing to HOME_LAND, the cheer to HOME_CHEER, the walk into the doorway to
  HOME_TIME). Ducks under the tunnel roof (`ceiling_above`). A warm rim (2.5 px) and a thin dark
  edge in actor.gdshader; the mercy after a hit is a warm red flicker 4 frames on / 4 off (no alpha
  ghost), then a short stumble; the death stays on screen (DIE_MIN_X). `run_frame()` for the
  footsteps.
- The bandit in 3D: `hero_render.py --character bandit` (the hero's mesh and rig, his picture's
  light and dark mapped to violet wraps, a dark mask band with amber eyes, a teal crest, a club in
  his near hand), packed by `tools/art/bandit_sheet.py` into bandit.png (16 x 3 cells: run, dazed
  run, KO blow/tumble + waiting crouch + the club's swing with a smeared blow) and club.png.
  BanditView swings the club as Panoramic comes within SWING_FROM..SWING_HIT ahead.
- Red Bobs: `tools/art/blender/bob_render.py` (glossy red ball, clear coat, the hero's light) +
  `tools/art/bob_sheet.py` (the 2017 faces, bolder: big eyes with a glint, thick smile, cheeks);
  BobView draws them 31 units wide (was 28).
- Rings: RingView's own glow slimmer (2 halo arcs), its streak shorter (6 positions), no white core.
- UI pictures in their screens' own light (`--light sunset`: the user's front lights dimmed and
  warmed, a strong orange rim from behind, a warm bounce, the normal map softened for gentler
  muscle grooves): `hero_menu.png` (mid-throw, a ring leaving his hand), `portrait.png` (its head
  and shoulders), `hero_win.png` (arms up), new `hero_defeat.png` (on one knee, a hand on the
  ground, head bowed).
- The null texture on the first boot (tests): GameArt.preload_art() loads on the main thread when
  headless (the stand-in renderer's texture store isn't thread safe).
- Studio logo: `tools/art/logo_crisp.py` redraws the same design in its own flat colours with clean
  edges (source: the upscale `studio_logo.py` now writes to `tools/art/gen/`).
- Reverted my headless preload change in game_art.gd (QA handles that race in its tests).
- Tests: 796 checks, 2 failed (both the known French iPad start/win text of the ux track).
- Captures: `_agents/AAA/art/round_2/iphone15_2556x1179__*.png`; strips in `round_2/strips/`
  (bandit_swing, bandit_ko, run, jump, hang, hurt, die, home; the climb strip's moment didn't
  trigger).
- Still to do: env to show HomeView.front (the jamb) while he walks in; the climb strip; perf
  numbers (bandit.png grew to 3200 x 780, VRAM-compressed: about +1.7 MB in play).
