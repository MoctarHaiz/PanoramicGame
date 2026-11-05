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

## Round 3

- Hero skin no longer plastic: roughness 0.68, specular 0.28, a little warm subsurface, normal map
  at 0.6 (in play) / 0.45 (interface): softer muscle grooves; the user's colours and model kept.
- Interface pictures backlit: the user's front lights at 25 % and warmed, an orange rim (14) from
  behind, a warm bounce; a soft warm-dark contact shadow under his feet (`grounded()` in
  hero_atlas.py). New defeat: sat down hard, dazed, a hand to his head, knees up.
- The ring is blue steel (metallic 1, roughness 0.1, a thinner tube, a glint light, a glowing inner
  edge): in-game (`fx/ring_spin.png`) and in the menu picture. RingView draws it leaving from his
  hand (30 units back) over 4 frames.
- In play: rim 1.35 at 3 px, a 1.8 px near-black edge at 90 %: his white wraps no longer melt into
  the pale sky. Hand steps while hanging (a lift and lean every 0.2 s).
- Bandit recoloured: near-black skin, crimson wraps, a red mask band with amber eyes, a black crest,
  a bone-white club. The swing now runs on gameplay's `strike(b)` (drawn back, then the blow over
  World.STRIKE_TICKS); its white flash decays on real time (2 frames, also inside a hit-stop).
- Red Bobs: a bigger, fully opaque specular hotspot, a stronger glow, a slight size pulse.
- Knock-back: audio's Feel.APPLY_KNOCKS kept (hit_dir / hit_strength not duplicated here).
- Results: tests 959 checks, 0 failed (exit 0). Captures `_agents/AAA/art/round_3/` (menu, win,
  gameover, game, climb, hang, home), strips `round_3/strips/` (bandit_swing, hurt, run, home).
- Short: the sitting defeat reads as falling at card size (UX shows it tilted); at phone size the
  bandit's swing is still small; the hero in play is still small (env's zoom).

## Round 4: one rendering language (cel shading, ink)

- `hero_render.py` `toon_setup()` (default; `--style pbr` keeps the old look): every material
  becomes a cel shader (Diffuse -> Shader to RGB -> 3 soft bands: cool violet shade, warm mid, warm
  lit; times the albedo; an emission, so no specular sheen at all), a warm rim on the edges facing
  the sun (view-space normal, upper left on screen), the hair blue-black with a painted highlight
  band; one key sun in the world's direction (upper left; behind him for `--light sunset`), no
  other light, Standard view transform. The base colour picture's painted muscle grooves are
  softened (`flatten_textures()`: a box-blurred copy mixed in at 60 %). An ink line: an inverted
  hull (Solidify, flipped, backface-culled dark emission, 0.0042 units), also on the bandit's mask,
  club and crest and on the menu's ring.
- `hero_atlas.py` / `bandit_sheet.py`: `inked()` thickens the ink round the outer silhouette (1.6
  atlas px; 2.0 for the bandit; scaled for the interface pictures); the inside lines stay thin.
- In-game: the shader's own outline is off (the render carries it), its rim a light touch.
- The ring: no pale halo or launch disc in RingView; the 3D ring's inner glow thinner and bluer,
  inked (`fx/ring_spin.png`).
- The Red Bob "white ring face": it is the pickup's glow (`Fx.glow(... 0.25 ...)` in
  `WorldView._on_bob`, env's file; and audio's `Fx.bob_pop`) drawn as a small disc over the
  flying Bob's face: asked env/audio to start it bigger than the ball or draw it behind.
- The interface pictures (`--light sunset`): the bands lifted (the backlit front read as a black
  shape on the win card), the orange rim kept. Defeat: on one knee, a hand to the ground, head up,
  seen from the side turned to us (the sitting pose read as a fall).
- Atlas: SCALE 0.41 -> 0.40 so the ink line costs no memory: 9.49 Mpx in 3 pages (round 3: 9.56).
- Tests with the bot: 1012 checks, 0 failed, exit 0; the bot gets home (3 lives, 82 Red Bobs).
- Captures `_agents/AAA/art/round_4/` (iPhone 15, --ads=off) and `before_after.png`.

## Round 5: key art with a face, a lighter in-game line

- New interface poses (front camera looking 7° up, so his face shows under his hair):
  `pose_key_art()` (menu: three-quarters to us, the steel ring held up in his right hand by his
  face, left fist on his hip, chin up), `pose_celebrate()` (win: armoured fist punched up, the
  other pumped at his chest), `pose_seated()` (game over: sat on the ground, one knee up, the other
  leg across the picture, a hand propping him, the other to his head, face turned to us). The model
  has no face rig (no shape keys): no smile possible without editing the user's texture.
- Toon materials: the cloth (light, unsaturated albedo) takes its folds from the normal map and a
  warm cream band ramp (`TOON_CLOTH`); the blue boots and armguard warmed and less saturated in the
  light; ink warm dark brown (0.16, 0.07, 0.04), thinner (hull 0.003; silhouette +1.0 px); sun rim
  stronger (day 0.85; sunset 1.6, darker front bands).
- Bandit signature: magenta wraps, dark plum skin, a gold mask band, the bone-white club.
- In play: darker contact shadows under the hero and the bandit; shader rim 0.7 (hero), 0.75
  (bandit).
- Red Bobs: a sun-side light rim and a crisp white shine on the sheet, a thin warm ink; drawn 28
  units (no overlap), a deeper float staggered along a row as a ripple.
- Seated defeat fixed: the knee drawn up, the other leg along the ground, his seat on it (the
  look-up camera lifts what reaches away: the outstretched leg aimed a little down).
- Results: see `_agents/AAA/art/round_5/` (iPhone 15, --ads=off) and `before_after.png`; tests
  with the bot in `_agents/AAA/art/round_5_tests.log`.

## Round 6

- The grey/silver outline: the Blender ink hull is an emission, so its colour is linear; it was
  given sRGB values (round 4: (0.055, 0.025, 0.035) -> sRGB about (0.26, 0.17, 0.2), a grey-plum;
  round 5: (0.16, 0.07, 0.04) -> a light tan). Now linear (0.022, 0.006, 0.003) = sRGB (0.16, 0.07,
  0.04), the same warm dark brown as hero_atlas.py's 2D ink. (UX's hero.gdshader is not applied
  to the rendered pictures: not the cause.)
- A lit face: a warm fill sun from the front (in play: screen right and towards us, 0.42; the
  interface: 0.3) puts his face and chest in the mid band; the interface pictures also get a
  small point light (`FaceLight`, 0.32 cutoff) placed in front of his face for each pose
  (`face_light()`).
- Armour matte and warm: the blue and silver plates take a stronger warm multiply in the light.
- Game over: `pose_seated()` re-authored compact: both knees drawn up, a forearm on a knee, a hand to
  his head, face up to us; nothing reaching out.
- Bandit: hot orange-red wraps, near-black skin, an ochre-gold mask, the club raised over his
  shoulder in the run (a bigger threat silhouette).
- Red Bobs: each 90-108 % in size and leaning its own way, a deeper staggered float (a ripple in a
  still), a stronger warm additive glow, a twinkling hotspot, a moving glint every 1.2-3 s.
- Ground shadows in play: the hero's and the bandit's shadow nodes are drawn at z 1, over the
  grass blades in front of the runners that hid them.
- Results: captures and before_after.png in _agents/AAA/art/round_6/; tests log _agents/AAA/art/round_6_tests.log.

## Round 7: a face, a bandit that pops

- `lift_fringe()` (in `toon_setup()`, every render): the locks hanging in front of his eyes are lifted
  7.5 cm and swept back 5.5 cm in the mesh's rest shape (so in every pose). Hair is found by its
  colour in the base colour picture (dark and cool: his skin is as dark but warm), per piece of mesh
  (a lock moves whole: a union-find over the mesh's edges), weighted by a smooth gaussian in front of
  his eyes (the rest shape faces +y). The user's file is unchanged.
- The interface pictures: a stronger face light (1.6 W) in front and above his face; the key art is
  the throw again (round 4's dynamic pose), head turned 30° to us and lifted, the steel ring flying
  a hand's breadth from his fingers; the win pose chin up; the defeat with both forearms on his knees,
  head tilted, looking up (no arm across his face).
- The bandit: deep indigo wraps, blue-black skin, a red mask band, the black crest, the bone-white
  club raised (the toon rim on his sun side). `lift_fringe()` finds the base colour picture by
  elimination (not the normal map's), since the bandit's goes through a ramp.
- Red Bobs: each wears its own face (smile, laugh, wink), one in four a twinkling star glint on its
  gloss all the time, a stronger lean (±0.35 rad) and size spread (88-110 %).
- Results: captures and before_after.png in _agents/AAA/art/round_7/; tests log _agents/AAA/art/round_7_tests.log.

## Round 8

- "Hatching on the skin reads as grime": no ink hull on Panoramic's body (on his carved muscles it
  drew fine lines over the skin); the outer ink only, from hero_atlas.py (`INK_PX` 1.6); the painted
  muscle grooves of the base colour almost gone (`flatten_textures(r=10, k=0.95)`). The bandit and
  the props keep their hull.
- A sun-side rim: the toon rim stronger and wider (day 1.3 / 0.48, sunset 2.3 / 0.38) in every render,
  and HeroView's shader rim 1.0 at 2.6 px.
- The bandit: drawn 1.38x (was 1.25; its box for the rules unchanged; BanditView.REACH 44), the run
  more upright (spine straightened), a darker, wider contact shadow.
- Red Bobs: a big bright shine and a second small one on the sheet, a bigger hotspot sprite, a star
  glint on every other one.
- The bandit's raised club was cut by the top of its sheet cell: he is drawn smaller in the sheet
  (STAND_PX 160) and bigger on screen (DRAW_SCALE 1.52: 10 % bigger than round 7), same sheet size.
- Results: captures and before_after.png in _agents/AAA/art/round_8/; tests log
  _agents/AAA/art/round_8_tests.log. Hero atlas 9.29 Mpx (round 7: 9.49).

## Hero AAA pass (hero3d specialist, live in the user's Blender window)

- The hero now comes from `ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend` (every edit made live through
  `hero3d/scripts/bl.py`; the user's `Making/` files only read). The audit, each fix and its shots:
  `hero3d/AUDIT.md`. In short: one character; welded (the 341 UV-seam pieces creased the shading); the
  muscles calmed into large planes (voxel copy low-passed, the skin shrink-wrapped onto it through a
  faded group; the user's shape kept as the shape key `AAA_original`); the fringe bent up off his eyes;
  custom shading normals (skin in planes, face and hair to the head's sphere); rigid armour; a
  Corrective Smooth on the joints; the loincloth's thigh weights spread along the cloth (no more sheet
  across the forward thigh); new bones for the scarf's tail and the hair; the base colour cleaned of
  baked light (eyes and brows kept as painted); one material per region (`m["toon"]`).
- Actions: `AAA_run` (authored for the game at 26 frames a second: IK foot paths, the planted foot at the
  ground's speed, so `run_fps` is ~26 and `HeroView.RUN_FPS` keeps the boot planted), `AAA_jump` (the
  landing planted and flowing into the run's first frame), `AAA_idle`, `AAA_die`; the scarf's tail and
  the hair simulated and keyed into each (`tools/art/blender/hero_secondary.py`). `ARM["aaa_actions"]`
  maps them; hero_render.py's `sample_jog()` uses the run as authored (the key art keeps the user's lunge).
- `toon_material()` → `_region_toon()` for the AAA regions: a cool sky fill on the edges away from the
  sun, the face lifted out of the deep shade, painted-metal glints on the armour, fur strands on the
  loincloth. The user's file and the bandit render as before.
- Renders: `hero3d/render/render_all.sh` → `hero3d/render/game` and `hero3d/render/render_ui`;
  `tools/art/hero_atlas.py` reads `hero3d/render/game` by default.
- Results: atlas 8.99 Mpx (3 pages), run_fps 25.4; tests with the bot 1023 checks, 0 failed (exit 0,
  `hero3d/tests.log`); captures `hero3d/captures/`; before/after `hero3d/before_after/`.

### Hero pass 2 (after the blind judges' h01 critique)
- `tools/art/blender/hero_toon_aaa.py`: the AAA regions' form shading (4 bands, soft terminator, a cool bounce
  in the front shade, sun-side sheen hotspots, occlusion, hair strand groups with a broken highlight band,
  fur tufts and darker roots and underside with a stepped edge, matte scuffed boots and gloves, the engraved
  steel chakram). `hero_render.py` uses it for every material with `m["toon"]` in the AAA file; importable
  (`main()` guarded), interface unchanged; the body mesh is the rig's largest child (the chakram is a child too).
- The pale inner band in play ("white sticker outline") is gone: HeroView's shader rim is off; the hot sun-side
  rim is drawn into the frames by `hero_atlas.py` `sun_rim()` (inside the silhouette, only on edges facing the
  sun, under the ink; hotter for the interface pictures); `grounded()` is now a soft pool plus a dark contact.
- The interface poses are authored by hand on the timeline (`AAA_key_menu`, `AAA_key_win`, `AAA_key_defeat`;
  `pose_authored()` in hero_render.py): contrapposto with the chakram raised, a joyful knee-up fist pump,
  sat down dazed rubbing his head. Atlas 8.99 Mpx; tests 1023 checks, 0 failed; captures `hero3d/captures_p2/`.

### Hero pass 3 (after h02: first blind wins on win and game over; the menu lost)
- Key art re-authored on the timeline: the menu a lunge-throw (one line from the back foot to the throwing
  hand, the chakram leaving the fingers towards the title, the head lifted and turned to us above the arm);
  the win side-on with a fist punched up and the armoured fist pumped at the chest (no raised knee); the
  defeat a comic slump with three dizzy stars (`AAA_DizzyStar_*`, head-bone children shown only for it).
- Sunset light: a deeper, slightly cooler front, no sunset sheen, a hotter, wider sun-side rim, a small warm
  face fill. Day: a little more saturation in the light.
- `hero_atlas.py`: `sun_rim()` lerps towards a hot orange (no pale halo on white fur and boot trim); in-game
  ink thicker and darker (`INK_PX` 2.2, `INK` (0.10, 0.045, 0.035)); the interface pictures keep 1.6-scaled ink.
- `actor.gdshader`: an optional warm `bounce` from one side (multiply, ink stays dark); HeroView uses it at
  home (the campfire on his left).

### Hero pass 4 (after h03: "readability beats backlight", "style mismatch with the chunky UI")
- Bold cel look (`hero_toon_aaa.py` HERO_TOON=bold, the default): two bands with a crisp terminator, a hot rim
  band on the silhouette (screen space), no skin bounce or sheen, big skin normal planes, inner ink lines on
  the body again, outer ink 2.8 px in play and scaled in the interface pictures; the interface pictures
  front-lit from the front-left (the sunset is the hot back rim); deeper blue boots and gloves; a flat red
  scarf. Key art re-keyed: the throw with the chakram up in the dark sky, a side-on victory leap (shadow on the
  ground below), the dazed slump with bigger stars, an orbit trail and a swirl. Atlas 9.08 Mpx; tests
  1023/0. Every pass's packed set: `ROOT/_agents/AAA/hero3d/passes/` (README there).

## Round 9: a bandit that reads as a threat, Red Bobs that read as treasure (the hero kept as pass 4)

- **The bandit, rebuilt in the hero's language.** `hero_render.py --character bandit` now renders from the AAA
  file (`hero3d/Panoramic_AAA.blend`, headless; the user's window untouched): the hero's regions rebuilt by
  `hero_toon_aaa.py` (bold cel: two bands, a crisp terminator, inner ink lines) in the raider's flat colours
  (a material may carry `m["flat"]` and its own `m["rim"]`, `m["rim_k"]`: the hero is unchanged); his hair
  masked off (a Mask modifier on the vertices only the hair uses) under a hooded cowl with a point at the back,
  a red mask band with two tails streaming back, big slanted glowing eyes, a heavy studded knobkerrie cocked
  high behind his head in the run (it crossed his cowl before); the user's full-stride sprint, his lowest foot
  planted each frame. Dark blue-black skin, torn indigo wraps (the fur's strands and stepped edge), dark leather
  boots with bronze bands: one red accent at the head.
- **A cold rim.** `bandit_sheet.py` draws the hero's ink weight on screen (2.8 x 0.543 units) round his outline
  and, inside it on the sun's side, a cold cyan band as thick as the hero's hot one (`hero_atlas.sun_rim()`,
  new `dark` argument: the dark cowl takes all of it). BanditView's own shader rim is off (as the hero's).
- **Sharper, same sheet.** The frames are trimmed and shelf-packed into the same 3200 x 780 sheet (round 8: a
  16 x 3 grid of mostly empty cells): he stands 214 px in it (was 160), about one texel a pixel on an iPhone 15
  like the hero. `bandit.json` lists each frame's rectangle and its ground point; BanditView draws a region
  (`_show()`), turning round the hips when knocked out.
- **No cartwheel.** The knock-out: frozen on the blow (snapped back, head whipped back), then flung back and up in
  one shape (back first, arms and legs thrown forward), tilting back to 0.55 rad at most, fading out after
  0.36 s (gone 0.65 s after the blow, was about a second of a 15 rad/s spin). A leap frame (knees tucked, club
  high) for hopping a wall and for the vault over Panoramic after the blow (was a run frame tilted 0.5 rad).
- **Red Bobs as rubies.** `bob_sheet.py` paints each as a cut ruby seen from above: crimson (not tomato
  orange-red), an octagonal table carrying the face, a brilliant's crown of star, kite and girdle facets in crisp
  flat tones, the facet mirroring the sun a sharp white triangle, a pin-point glint. `bob_render.py` (the glossy
  ball) is gone. BobView: a rose glow hugging the gem's edge (additive, breathing), the hot pin-point and the
  star glint on the sheet's highlight.
- **QA's art bugs.** ART-1: `render()` updates the view layer before projecting the origin (the win's camera lift
  was missed: his boots 32 units in the ground through the cheer at home); the win's origin in
  `hero3d/render/p4/game/win/points.json` moved down by the lift (147.34 px; the old file kept as
  `points.json.before_r9`), the atlas re-packed: every picture pixel-identical, only the win's origins changed.
  ART-2: `ui_art.py` makes `ui/head.png` (the HUD's way-home badge, 128 px, the HUD draws its ring) from today's
  portrait. ART-4: `stand_front.png` and `stand_side.png` removed (drawn nowhere); `portrait.png` kept on purpose
  (the source of the badge, the icons and the store art). ART-3: the knock-out above.
- Tests: `_test_art_round9()` (the grounded boots, the sheet's size and frames, the leap frame, the knock-out's
  tilt and length, the Bob's ruby hue and glow).

## Round 10 (the hero's model and look kept; the judges' named flaws)

- **Red Bobs** ("soft magenta halos merge into one pink smear along a row; facets too small to read"): no glow
  round them at all (BobView: the additive halo, the soft hot spot and the always-on star are gone; one hard glint
  in the sheet now and then flares into a star). `bob_sheet.py`: eight big crown facets (one per side of the table,
  was 24 star, kite and girdle facets), a bright rim just inside the ink strongest towards the sun and where the
  light comes back out (not a bezel all round), one hard white rhombus glint.
- **Menu: the ring's trail** ("it floats above the hand with no motion trail: a UI glitch"): `hero_atlas.py
  throw_trail()` paints a smear of cold light on the arc from his throwing hand to the ring (thin and faint at the
  hand, ring-wide and brighter at the ring, a white core, two speed lines), drawn behind the figure with no ink
  round it (`trimmed(..., under=)`); the ring found as the render's second piece, the hand from points.json. The
  portrait is cut from the picture without it (it feeds the HUD badge, the icons and the store art).
- **Win** ("the bent leg folds in oddly"): `pose_win_leap()`: the authored AAA_key_win with the bent leg's shin
  hanging down and a little forward from the knee, the toes pointed (it was folded back under the thigh, across the
  other leg). hero_win.png is wider (489 px, was 400).
- **Defeat** ("the stars stock clip-art"): `chunky_stars()`: the dizzy stars bevelled and cel-shaded in the game's
  gold with a hot rim and ink (the results panel's language), the spiral gone, the orbit streak warm.
- **Home** ("front-lit cel rendering ignores the strong orange backlight from inside the hut"): `actor.gdshader`
  back rim: a band just inside the ink on the edges that face up (none below), screened on in warm orange;
  HeroView turns it on with the campfire's bounce at home.
- **Hang** ("pale against the sky"): dropped after QA (his hang frames match the run's values; the camera draws
  back at the vine). A hang with the light turning with him was rendered and set aside
  (`_agents/AAA/blender/r10_hang_lightfollow/`). Kept: HeroView adds 0.8 atlas px of ink outside the baked one
  while he is at the vine (`VINE_INK_PX`), so the ink's weight on screen stays the run's when the camera pulls out.
- Renders: `hero3d/render/render_r10.sh` -> `hero3d/render/r10/` (win_front and defeat re-rendered; everything
  else symlinked to pass 4's p4/); hero_atlas.py reads r10/game. The atlas pages and portrait.png are
  pixel-identical to round 9.
- Tests: `_test_art_round10()` (the vine ink, the home back rim, the menu's trail) and the Bob checks (a bright rim
  on the sun's side, no glow sprite).

## Round 11 (round 10's rubies, trail, stars and home rim kept)

- **The outline** ("a jagged, uneven dark-brown stroke with a lighter halo", menu): `hero_atlas.py inked()` draws
  the line at 4x on a calmed contour of the silhouette and reduces it (an even width, a smooth anti-aliased edge;
  half as wide round a strand too thin for the calmed contour, never missing). `trimmed()` leaves room for the
  whole line (a 4 px border had cut it flat at his boots). The menu picture is inked at its final size (it was
  reduced 0.7x after inking: a soft, uneven line). The interface pictures' hot rim inside the line narrower
  (`RIM_PX_UI` 3.4 -> 2.4).
- **Win**: round 10's opened leg lost the A/B: `pose_win_leap()` removed, the win picture is pass 4's again
  (`r11/render_ui/win_front` -> p4), with the smoother line.
- **In play** ("his dark orange skin shares the value of the rock and the haze: a brown smudge"): every level
  animation re-rendered (`hero3d/render/render_r11.sh` -> `r11/game`) with his skin's lit band lighter and warmer in
  the level's light (`hero_toon_aaa.py DAY_LIT`, x1.3 linear; the shade band kept, so the split widens; the
  interface pictures and the bandit unchanged); a lighter, stronger hot rim on his sun side (`RIM_DAY`
  (1.0, 0.72, 0.36) at 0.75, `RIM_PX` 4.2) and a heavier outline in play (`INK_PX` 2.8 -> 3.2; HeroView's
  `VINE_INK_PX` 0.9 to match).
- `portrait.png` is no longer rewritten unless `PORTRAIT=1` (UX's HUD badge is cut from it).
- Tests: `_test_art_round11()` (the pictures' line never cut at their edge, the win is the upright leap).

## Round 12 (the key art "clearly below the UI and logo in finish")

- **The interface pictures' finish** (`hero_toon_aaa.py`, sunset only; the level and the bandit unchanged): his skin
  and hands one clean colour (the albedo picture's mean, in linear: `UI_FLAT`; "blotchy orange-to-brown patches"),
  a warm shade and a slightly softer step (`UI_BANDS`, `UI_STOPS`; "hard muddy transitions"), the face lit (its
  bands lifted, `FACE_W` 0.9 -> 2.2; "small, dark, blank"); no inner ink hull in these pictures (`HERO_HULL` 0 for
  sunset; QA: "the chest's thin inner lines break into dots"); the steel ring polished: two bright lobes across its
  flat face and dark steel between, a bigger glint ("a flat grey donut").
- **Key art pose** (`pose_key_lunge()`): the authored throw in a deeper lunge, the hips 4 cm lower with both boots
  where they stood (`ik_leg()`, a two-bone IK), the throwing forearm turned across the picture ("back leg locked,
  fist foreshortened into a blob"). `hero_atlas.py`: a four-point glint on the ring (`ring_glint()`, drawn over the
  figure), and a soft warm-dark glow just outside his line (`backed()`; QA: the low sun right behind him against
  his ink read as "a white rim").
- **The ink** (`inked()`): `INK_CALM` 0.35 -> 0.2 (concavities no longer filled: "blobby on the fist"), thin strands
  three quarters of the width (was half: "jagged on the hair").
- **Defeat** (`pose_defeat_turned()`): the slump turned 32° so his legs go across the picture (not at us), his face
  kept to us; the camera looks down less (-4°).
- **Win** (`pose_win_tuck()`, `WIN_LEAP` "kick"): the front knee up as authored, the other foot kicked up behind (a
  leap of joy): the boots no longer cross ("a tangle"). hero_win.png is wider (753 px).
- **In play** ("a mid-brown figure against mesas of the same value"): `actor.gdshader light_gain`: his lit colours
  x1.28 (the shade less, the ink not at all), HeroView `LIGHT_GAIN`.
- Renders: `hero3d/render/render_r12.sh` -> `r12/render_ui` (the level's animations are round 11's, `r12/game` ->
  `r11/game`). The HUD ruby icon was not needed (UX's counter already shows the ruby; QA: its coral comes from a
  pickup glow).
- Tests: `_test_art_round12()` (the light gain in play).

## Round 13 (only art and ux this round)

- **The pale halo** on game over, win and menu (every judge, three rounds): at 100 % zoom it was a light band just
  inside the ink on every edge: the sunset pictures' 3D rim had a 0.3 floor all round (`hero_toon_aaa.py`
  `BOLD_RIM`). Now the rim lies only on the edges towards the sun (upper left, as in the level): a rim against the
  sky, not a ring (the 2D `RIM_SUNSET` a warmer white, on the sun side only). The bleed under the transparent pixels
  was already the ink's colour (checked).
- **In play** ("mid-brown on mid-brown, no rim light"): `hero_atlas.py` `RIM_DAY` a warm white (1.0, 0.94, 0.8) at
  full strength, `RIM_PX` 5.0, a solid band (`sun_rim(fall=0.7)`) and his hair takes more of it (`RIM_DAY_DARK`
  0.55). Measured on the game shot (`/tmp`-style script: his inked silhouette vs the 40 px round him): his mean
  luminance 0.564 -> 0.602, his lit quartile 0.778 -> 0.847 (the sky round him 0.74).
- **Menu key art** (round 12's skin kept): the face lifted out of the hair's shadow (`UI_FACE_LIFT`), the loincloth a
  warm white with shading (`UI_BANDS["fur"]`), the steel ring's lobes with white-hot cores, a stronger trail.
- **Hang**: knees bent and the legs swinging under him (`pose_hang`). **Home**: an asymmetric cheer (one fist punched
  high, the other pumping at his chest, a lean; `pose_win`), his front falling into the hut's backlight
  (HeroView `light_gain` 1.28 -> 0.92 at home, the back rim at full).
- **Red Bobs**: drawn 24 units (was 28; the rules' pickup unchanged), each on its own beat and pace (no smooth
  wave along a row).
- Renders: `hero3d/render/render_r13.sh` -> `r13/` (hang, catch, win; the interface pictures); the other level
  animations round 11's (symlinked).
- Tests: `_test_art_round13()` (the smaller Bobs, their scattered beats, the backlit home).

## Round 14 (the hero first: the judges now score him on his own)

- **In play**: round 13's warm-white band ("a whitish edge, a cut-out sticker") reverted to round 12's warm orange sun
  rim (`RIM_DAY`, `RIM_PX` 4.2, a line at the edge); then the judges' own fix: his shade in the savanna's evening
  purple, its value kept (`hero_toon_aaa.py DAY_PURPLE`, `DAY_PURPLE_K` 0.35, every level animation re-rendered:
  `hero3d/render/render_r14.sh` -> `r14/`), and a darker, slightly purple ink in the level (`hero_atlas.py INK_DAY`).
- **Menu** (it won: kept): a touch of sunset magenta in his shadows (`UI_MAGENTA_K` 0.18); the chakram's trail a blade
  of light (`throw_trail()`: needle-thin and faint at the hand, a sharp bright head at the ring, a white-hot core, a
  cold glow round the head, three crisp speed lines; "an undo-ghost").
- **Game over**: a stronger contact shadow (`grounded(strength=1.35)`, "floats with no ground") and a bold dizzy ring
  (the orbit's streak 2.2x thicker and brighter, the stars 1.25x; "a thin yellow line: a placeholder").
- **Home**: round 12's front light back (HeroView: no darker front; the back rim at 0.9); the cheer's second arm
  pumped out to the side (it crossed his chest).
- **Red Bobs**: 28 units again (24 read "small and pale"); each Bob's glint on its own beat.
- Tests: `_test_art_round13()` updated (28-unit Bobs, the home's front light).
- **The character judge (c13: 0/7, 4.4/10)**, worked in its order:
  - Acting, within the model (no face rig; the face kept as the user made it): the idle's chin up and his face turned
    three-quarters to us (`pose_idle`: "the head bowed so far the face is invisible"); in the jump his head up and
    turned to us, looking at the landing; the key art's head kept on the ring.
  - Poses: the key art's open release hand (index and thumb out, the wrist flicked) with the ring ahead of it on the
    throw's arc ("a fist punching while the ring trails behind"); the jump's flight a split leap, the near arm up and
    forward, the other back ("kneeling in mid-air"; `pose_jump`, blended over frames 3-18); the win's fist punched
    straight up and the other leg trailing (`WIN_LEAP` "trail"; the kick "splayed the legs"); the cheer's body
    twisting to us.
  - Rendering: matte armour (no glints, barely worn; flat colours in the interface pictures: "glossy plastic boots",
    "mottled noise"); the hair in three value steps with clumped locks; the fur in big tufts, not scratchy strands;
    no inner ink hull anywhere (only the smooth outer line: "ragged and brushy"); the contact shadows one soft blob
    (HeroView `_blob()`, `grounded()`: "concentric rings, like a puddle"); the home back rim lighter (0.4).
  - Not done: expressions (a shout, a grin, dazed eyes): the model has no face rig and its face is the user's
    identity; the proportions.
