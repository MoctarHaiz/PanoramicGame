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
