# Env track log (environment, lighting, camera), AAA pass round 2

Worktree: `_agents/wt/env/New`. Captures: `_agents/AAA/env/round_<n>/`. Owns `world_view.gd`,
`terrain_view.gd`, `savanna_view.gd`, `prop_view.gd`, `home_view.gd`, `vine_view.gd`, the world shaders,
`assets/art/world/`, `tools/art/{terrain,savanna,trees,props,home,vine,material}.py`,
`tools/import_settings.py`, `tools/art/texture_budget.py`, and `_place_camera` + the camera constants in
`game_screen.gd`.

## Findings (start of round 2)

- The hero is drawn 150 units tall (GameArt.HERO_DRAW_HEIGHT): 23 % of the screen height standing, ~20 %
  in a tuck, on every phone (keep_height). The judge reads him as "~12 %": he is thin, pale and alone in
  a wide frame, so the fix is the frame (closer, less sky) and the light, not only his size.
- A bot run: on the main ground (row 18) 43 % of the time, airborne ~25 %, hanging 14 %, on the high
  ledges (rows 6 and 8) 13 %. Hanging, he must see the ground and the pools under him to let go; on a
  high ledge, the drop at its end. A camera that pans up and loses the bottom is unfair there.
- Level open: `WorldView.setup()` ~110 ms headless, of it the ground 60 ms (its depth picture 38 ms).

## Round 2 work

### 1. Camera (`game_screen.gd`: `_place_camera`, `base_zoom`, `follow_zoom`, constants)

- Closes in on wide screens as far as still shows VIEW_AHEAD = 1040 play units right of the play
  window's left edge (the 2017 game showed 960; a bandit starts running as it crosses 960), at most
  ZOOM_MAX 1.26: iPhone 15 1.24, 720p 1.09, Pixel 20:9 1.26; a 4:3 iPad draws back (0.89) to show the
  whole 960 (it showed 853).
- The bottom of the level stays on the bottom of the screen (ground, pools, bandits always in view).
  Vertical follow by drawing back: just enough that his head stays HEAD_ROOM (132 of 640) under the top
  of the screen, in a jump from take-off (the top of the jump is known), and the vine stays under the
  HUD band (78) while he hangs, rises to it, or stands where a jump reaches it. Draws back fast (5/s),
  closes in slowly (1.4/s); a ground jump on an iPhone 15 doesn't move the camera at all.
- Kept: gameplay's push-in when caught (about where he falls), art's centred home push (now to an
  absolute zoom HOME_PUSH 1.4 on every screen, as before).
- Result, iPhone 15: standing he is 29 % of the screen height (was 23 %); the sky above the mesas from
  ~47 % to ~35 % on the ground shots. Climb and hang frame the whole height, as they must.

### 2. One light

- The sun now sits low on the left over the escarpments (SavannaView.SUN_AT y 200, was 64, hidden by
  the hearts): a tighter golden glow (savanna.py `sun()`); the light grade (light_grade.gdshader)
  follows it, and darkens the top and a foreground band along the bottom more (depth).
- Sky: a deeper zenith (SKY_STOPS), clouds quieter (alpha 0.82).
- Cast shadows: every wall throws a long shadow along the ground away from the sun (TerrainView
  `cast` layer, 0.75 x its height, over the grass blades too, never over a pool).
- Foreground: fg_grass.png denser, with a continuous dark band along the bottom edge.
- Mesas (savanna.py `mesas()`): two planes: a far stepped escarpment deep in the haze, nearer landmarks
  (a tall flat butte, twin chimneys, a stepped mesa, a lone butte, kopjes); sun-facing cliffs warm
  sandstone with a hot rim on their lit edges and tops, the far sides violet, gullies and beds, the
  feet melting into the horizon's haze.

### 3. Materials and shapes

- Pillars (terrain.gdshader): no visible repeat (each texture read twice at two scales, turned, blended
  by noise), big soft patches and wobbling beds of rock, lit from above, deeper slower erosion (chunky
  breaks), a hot rim on the sun-side eroded edge (dark line only on the far side).
- Wall feet: the ground's grass and soil now run on across a wall's foot (`_wall_foot`, `_find_feet`):
  the pillar no longer stands on a hard dark rectangle.
- Floating ledges: masses of earth and rock hang under them (hanging.png, `mass` layer), deepest
  under the middle, smaller to the ends, roots dangling: a floating island, not a tiled strip.
- River poles: sandstone spires painted like the buttes on the horizon (material.py `spire()`: a cap
  rock, a wavering column with soft waists, beds of stone across it, a flared foot, the mesas'
  palette and light), 96 x 560 units (no more stretching), mirrored by hash (no twins).
- Water: a grazing-angle reflection of the warm sky under the surface broken by ripples, a deeper
  body; the submerged banks murky, not glass panels (water.gdshader, water_front.gdshader).
- Mid-ground: tree rows in groves and open plain (a second smaller tree beside each in a grove);
  distant giraffes, an elephant and a grazing herd among the rows (animals.png).

### 4. Home (home.py, home_view.gd)

- Thatch in five chunky tiers whose fringes jut out (a stepped silhouette, not an egg), shadow under
  each fringe, lit from above, the fringe at the foot blown by the breeze; the rondavel's cone roof in
  the same tiers (one style). The hut is bigger and its doorway 176 units tall: he stands in it at
  HOME_X (DOOR_RIGHT 840), and the hut's front layer (the wall right of the doorway, with its post) is
  drawn over the actors, so walking on in he goes behind the jamb. The HOME letters are cut with a
  chisel and painted, worn; the fence's tops wander more. The door light spills further along the
  ground.

### 5. The vine (vine.py, vine_view.gd)

- A ~10-unit liana (16 px on an iPhone 15) with a sunlit top edge, bigger leaves, tendrils hanging.
  Drawn in slices: it dips under him where he hangs (a damped spring: ~11 units on the catch, 2-3
  bounces, settles at 5), springs back when he lets go, stirs in the breeze. WorldView hangs him from
  it (his y follows the dip).

### QA items

- ENV-1 (level open): the ground's depth picture is computed as running counts (one pass each way,
  identical output, checked against the old count in `_test_env`), the solid-cell cache read straight
  from the map: TerrainView.build 60 -> ~25 ms headless.
- ENV-2: the two delayed calls in world_view.gd are tweens on their nodes (no timer outlives the
  screen).

## Numbers

- Tests: `_test_env()` added (camera widths, follow, vine framing, depth picture, wall feet, cast
  shadow, hanging masses, vine spring, doorway). Quick suite 627 checks, 0 failed; full suite: 797
  checks, 2 failed, both UX-1 (French start card on iPad, ux).
- Bandit warning (seconds a bandit is in view before its club reaches him, bot seed 1, the probe's
  bandits 3 / 13 / 26; a waiting bandit counts as in view): iPad 4:3 1.20 / 0.58 / 0.58 -> 1.43 / 0.80 /
  0.80; 720p 2.18 / 1.55 / 1.55 -> 1.78 / 1.15 / 1.15; iPhone 15 2.85 / 2.23 / 2.23 -> 1.78 / 1.15 /
  1.15. Never less than the 2017 game's 960 units (the iPad's numbers now). `probes.gd --probe=warning`
  itself is unchanged (fixed widths: 853 and the activation edge): 1.15 / 0.53 / 0.53 (iPad), 1.38 /
  0.75 / 0.75 (wide), before and after.
- Perf (QA's perf.tscn, iPhone 15, whole level): worst own work in play 9.47 ms, wall p99 7.39 ms
  (pass); level open worst frame 269 ms (QA's round 1: 272-303); texture memory in play before the
  first pause 86-88 MB (round 1: 84.5-86.5; this round's world art +~1.5 MB), 111.6 MB overall with the
  pause panel, the countdown digits and the combo chip's font sizes (UX-2): fail, mostly ux's.
- Value pass at the end: clouds warm and quieter, thinner haze bands, a warmer mid-ground plain.

## Next

- The hero's own readability is art's (rim, contact shadow, size of the white skirt).
- The level opens in ~70 ms of setup headless; PropView builds the whole level's props (17 ms) and
  SavannaView is drawn in 16 canvas items (draw calls, ENV-3): to spread and batch.
- The climb and hang shots must frame the whole height (fairness): their composition rests on the
  backdrop; more landmarks and a stronger lit lane would help there.

## Round 3

- Framing for the full-height shots (climb, hang): acacia boughs hang in along the top of the screen,
  near the camera (canopy.png, SavannaView.top): dark, out of focus, a warm rim, the same size on screen
  whatever the zoom, under the HUD and above the vine (72 units at most). Vultures circle over the
  plain in the middle of the sky.
- Values: the sun lower (y 255: its glow off the HUD, half behind the far cliffs); the light grade's
  edges and bottom deeper, but not over the play lane (60-90 % down: a dark threat never sinks into a
  dark corner) and the bottom band only under the ground line; a warm light on the grass behind the
  runners (the lit lane): art's crimson-and-black bandit reads against it (hurt, throw, game shots).
- Home: a cooking fire in the yard (drawn: flames, stones, a pot, its light, smoke) and three of the
  family (a woman with a pot on her head, a child, an elder with a staff: drawn silhouettes with a warm
  rim and a coloured wrap) who raise their arms when he is home; the palisade in stretches of
  different height, wear and gaps; the jamb and wall right of the doorway drawn over him only from
  World.HOME_CHEER (art: his walk in passes behind it). No new pictures (memory).
- Water: the reeds at the banks are mirrored in the pools.
- ENV-1, the level open (QA: 300-317 ms worst frame): props are found and drawn a chunk at a time as
  the camera gets there (each chunk one canvas item: no more 400 sprites); the ground's picture of the
  map is worked out on the frame after the rest (both frames are under the wipe's cover); the world's
  shaders are compiled in the menu (WorldView.warm_up(), unseen); the level's scripts load on a
  thread in the menu (GameArt.preload_art: a 3-line edit in art's file, they took ~160 ms in the open
  frame). Worst frame of the open: 279-385 -> 83 ms (iPhone 15, perf.tscn). The world's part of the
  open frame: 58 -> 15 ms.
- Memory: canopy.png stored at half size (0.1 MB); home_hut_front.png cropped to what is drawn (0.63
  -> 0.37 MB): world art 19.2 -> 19.0 MB.
- Timer lambdas: none left in world_view.gd (its two delayed calls became tweens on their nodes in
  round 2); the one in base is in src/ui/results_panel.gd:175 (ux).

## Round 4

- The seam (a dark purple rectangle with a hard left edge right of the pillar): my cast shadow,
  opaque at the wall's cell edge while the eroded wall stands further in. The shadow now fades in
  from the wall (cast_shade()), softer and less purple, lighter over the front blades.
- Values: haze only on the far layers (mesas, far hills, the far tree row); the mid hills, the nearer
  tree rows and the tall grass darker and richer (haze.gdshader `tint`); haze bands thinned.
- Sun: a smaller hot disc, a golden bloom, a wide orange halo (it read as a grey-white smudge).
- Earth forms: walls in beds of rock (a dark crack under each bed, its top face lit, each bed its own
  tone), darker where they meet the ground; banks muddy at the waterline with a wandering edge.
- The vine hangs between knots tied at different heights, each span its own sag (not a straight
  stripe under the HUD); his hands follow it (WorldView adds sag_at()).
- Clouds flatter and longer, lavender shade and peach-gold light (the mesas' palette), painted marks.
- Acacias: each leans its own way (a skew about its foot), on top of the size, width and grove changes.
- Home: the family shaded and lit (a shadow tone, a lit mid-tone, a rim; the pot round, lit, a glint);
  the hut's long shadow on the yard's grass.
- Camera: on a high ledge (feet above y ~300) it stays close and rises with him (his feet 74 % down,
  never above the vine under the HUD), only where all of World.camera_must_see() fits and stays
  fitting a further ~1.4 s of run ahead (it is down again before a drop ahead must show); clamped to
  that rect every frame. Gameplay's camera checks pass (1015 checks). The climb shot's moment is at
  the top of the steps over the pool, which must show: that shot keeps the whole height.
- Memory: world art 19.0 MB (clouds smaller; nothing added).
- QA round 4: the seam (ENV-1) fixed as above, front_cast trimmed to the blades' lower half at 45 %;
  the island's hard cut (ENV-2): the hanging masses stay 44 units inside the ledge's ends, a ledge's
  ends taper rounder and deeper, and the old strip of earth under a ledge's cells (it stopped square
  a cell before the end) is no longer drawn (underside.png no longer loaded); the Red Bobs at the bottom
  of the climb shot: the foreground clumps are lower (24-40 units, rarely 44-62), none hides them;
  GP-1: the camera draws back faster (9/s); the world effects node lost its z_index 10 (it drew over
  the HUD): it stays over the level by being WorldView's last child.
- Perf (iPhone 15, whole level): texture memory in play 77.2 MB (under 80), 92.8 after a pause,
  113.6 back on the menu; worst own work in play 7.55 ms; level open worst frame 119 ms (81 in my
  round 3 run; the merge now adds the warm-up deferred, and the machine was shared).

## Round 5: the playfield in the hero's style

- Earth forms: done as a shader that reproduces cel modules (the brief's alternative to Blender
  renders): terrain.gdshader no longer reads the soil/rock noise textures. Flat cel colours, soil
  near the top and sandstone deeper; rock in chunky blocks set in beds of uneven thickness with
  slanted joints, each block its own tone, its top face lit, its underside shaded, ink in the cracks;
  soil in wavy strata with lit stones; three light bands (lit, mid, shade) from the low sun; a crisp
  shadow under the grass lip, the foot of a wall darker, a ledge's underside in shade; thick ink round
  the silhouette and the eroded edges. Before/after: AAA/env/round_5/before_after_r4_r5.jpg.
- Spires, hanging masses, thatch: the same style in their generators (paint.py `cel()`, `ink_edge()`):
  flat light bands, ink outlines, ink bedding lines.
- Props inked like the hero (ink.gdshader on PropView).
- Mesas: the vertical streaks were my own gullies (a horizontal gradient of vertically blurred noise:
  fine vertical stripes, stretched on screen); gone; the light in flat bands.
- Water: flat bands (the warm sky's light band, mid teal, deep blue), ripple dashes, a foam line, foam
  curling at the banks, the banks' earth sloping in under an ink edge.
- Hang: the vine framed 30 units further under the HUD (VINE_GAP): his hands never touch it.
- Home: the family figures gone (read as placeholders twice); the doorway glow dimmer and lower behind
  him; the dark grass along the bottom edge clears at home (his feet on the ground line); thatch in
  flat bands with crisp shade under each tier and an ink outline.
- QA round 5: the HUD band now adds the screen's top inset (GameScreen.hud_band(): the camera's
  framing, its fit test and gameplay's _keep_fair area; QA's _test_hud_band and gameplay's camera test
  read it too): on an iPad his hands on the vine stay clear of the progress plate. Far mesas imported
  lossless (no 4x4 blocks; +2.8 MB, play was at 53 MB). An island's upper row tapers at its ends with
  the row under it, and a ledge's underside is a wavy inked line (no square box). At home the patch
  of trodden earth is gone: his boots on the grass line, not in the dirt under it.
- Perf (iPhone 15, before the lossless mesas): texture memory 64.1 MB overall (play 53.2), frames
  pass (worst own work 13.7 ms), level open worst frame 112 ms.

## Round 6

- The black rectangle at home: the cooking fire's pot (a flat dark trapezoid) over hearth stones
  that read as tyres. Now a campfire: flat lit stones, two crossed logs with glowing ends, flame
  tongues.
- Light depth: a deeper, wider shade under every grass lip with a soft fall-off; a dark contact where
  a wall meets the ground; the walls' cast shadows stronger (still soft-started: no seam); each
  floating ledge's shadow on the ground below it, away from the sun; a warm rim on an island's end on
  the sun's side.
- Values: the mid-ground darker and warmer (mid hills, the two nearer tree rows); the mesas less
  lavender (warm sandstone lit, dusky rose-brown shade) and less hazed.
- Hang: the near tree row lower (no acacia rising between the pillars); each river pole its own width;
  rocks heaped at each pole's foot.
- The vine sags deeper between its knots (9-17 units).
- Pools: narrower sky band, saturated shallows, darker with depth.
- Home: the camera pushes in to 1.6 (he is bigger); the sign casts a shadow; the rondavel and the
  granary inked like the main hut.
- Before/after: AAA/env/round_6/before_after_r5_r6.jpg.
- Round 6, second pass: distinct tree silhouettes (acacias: umbrella x2, tall, windswept, a low
  flat-top, a double trunk; baobabs: bottle x2, squat, slim; trees.py `style`); the grass strip read
  from a different place every 24 cells and its tone drifting along the ground (its 1024-unit repeat
  showed); the fence in stakes of varied width, tip and lean, braces across, lashings, inked; the HOME
  sign's letters painted by hand (Fredoka, each tilted and set its own height, brush edges, worn paint,
  a dark painted outline) on weathered wood (scratches, a knot). Captures: AAA/env/round_6b/.
- What is left in the level-open frame (117 ms; measured in round 3): the swap frame builds the world
  (~15 ms, the ground's map data waits a frame) and draws the whole screen for the first time (HUD
  texts and their glyph pages, the hero atlas pages, ~45-60 ms); the next frame builds the ground's
  data (~22 ms). Next: the ground's data on a worker thread, and the HUD's text warmed in the menu.

## Round 7

- The HOME sign's "faint duplicate arrow": my round 6 shadow copy of the sign; removed.
- The sun softer (its disc and bloom dimmer and warmer, the rays and the grade's wash fainter).
- Trees: the two nearer rows lower (their flat crowns sat at jump height and read as platforms);
  the nearest row fades where it passes behind him (SavannaView.hero_x): no tree cuts his silhouette.
- Mesas: not all flat-topped (a heap of boulders, a slanted cuesta, a pinnacle), and each landmark
  its own stone colour along the strip.
- Spires: rock stacks, not chimneys (stronger bulges and waists, a broken top, inside their cells).
- The vine sags 15-26 units between knots tied ±5 units off the line.
- Pools: each bank slopes in, a wedge of wet earth over the soil's face, inked (water_front.gdshader).
- Home: the thatch clearly lit from the left; the campfire moved by the hut (it was cropped).
- Before/after: AAA/env/round_7/before_after_r6_r7.jpg.
