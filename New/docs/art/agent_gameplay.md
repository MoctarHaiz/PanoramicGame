# Gameplay builder log (AAA pass)

Track: how the game plays and feels (rules, input, camera, hit-stop, shake, haptics, sound).
Files: world.gd, level.gd + level data, game_screen.gd (not its presentation functions), audio.gd,
haptics.gd, assets/audio/**, tools/sfx_synth.py, tests/**, config/game_config.cfg.

## Round 1

- Baseline: 277 checks pass; level mapped (pits: water at cols 75-80, 105-118, 138-145 gap, 162-205
  stairs, 205-215 gap, 264-268, 281-285, 403-418 tunnel, 480-503 water + platforms, 537-695 pillars
  and water, 676-735 pools).
- Climb: the old rules lifted him 168 units (5 tiles) in one 25 ms tick onto a ledge his body
  touched (a teleport in the picture). world.gd: `climbing`, CLIMB_SNAP/CLIMB_SPEED: the same
  ledges, climbed over 6 ticks (<= 36 u/tick, easing onto the top), one landing, no flicker.
- Fall: cost the whole run with 3 hearts showing. Now a life (World.fell/sprang): splash, red flash,
  0.45 s beat (game_screen FALL_BEAT), he leaps out of the pool to the vine flickering (mercy until
  1 s after he hangs). Last life: the old game over. Tests: _test_fall.
- Pits: every bare pit is a pool (level.gd _flood_pits, at load; level.txt untouched): the savanna
  behind the bare holes read as ground at ground height (judge r0 item 10). Test in _test_level.
- Sound: phone-weighted mastering in sfx_synth.py (negative level = dB RMS through a 350 Hz
  high-pass). Landing thud was -40 dB on a phone (bass only): new boots-on-earth land. Ring hit was
  quieter than the throw: new ting2 -16, knock-out -13, throw -21, fatal fall -14 (was -7).
  New: splash (2), spring, fell. Landing volume/pitch/shake/haptic follow World.land_speed.
- Hit-stop: KO 60 ms + shake 0.3; last hit 0.2 s; the view holds during hit-stops (refresh(0)).
  Music ducks at the end of a run; Audio.play_music restores it on Play again.
- Minimal edits in views (visual track): hero_view.gd landed() squash scales with land_speed,
  flicker follows world.mercy; world_view.gd landing dust scales with land_speed, a splash when he
  springs out of a pool.
- Bandit club reach (world.gd CLUB_REACH 34): the hit fired 0.13 s after the drawn bandit was
  already in his legs; now as its club reaches him. Jump-over window still 450 ms. Test.
- Vine: the old let-go dropped him from y 1 while he is drawn hanging ~92 lower: the picture jumped
  up half a body. LET_GO_Y = VINE_DRAW_Y = 92 (lands ~2 ticks sooner); draw_hero eases a rise that
  ends on the vine into the hanging picture (rising_to_vine, VINE_EASE 200, monotonic).
- Ending: the screen eased to a stop over its last 60 units (he keeps his level pace), then he runs
  home at up to HOME_PACE 9 (was a swipe step, 11, every tick) and slows into the doorway (4).
- Shake: the stage zooms in just enough to cover the shake offset (edges were bared at the top and
  left). Caught: no mercy flicker on the tumble (hero_view, one condition).
- Bot (club reach, pits, falls, climb): home with 80 bobs, 3 lives; seed 2: 82 bobs, 2 lives.
- Swipe right now answers with the step sound (it had no feedback at all). A spring out of a pool
  also splashes (sound). Music measured through a phone: median -27 dB in game; SFX sit 3-12 dB over.
- Probes: tests/probes.gd (climb tick by tick, bandit jump window, bot seeds with every life lost
  and every landing's drop). Strip tool: --at, --y, --lives to stage moments anywhere in the level.
- Next (not done): Red Bob rows as arcs along the jump (judge r0 item 5), bandit density curve
  (one every 512 units from start to end: no ramp), the hero's hit tint looks like transparency
  (visual), bandits run through him after a hit.
- Seed 3 (final rules but contention-killed run): fell once at col 490 (water with 3-tile platforms
  at row 16, cols 483-503): the tightest hops in the level. Next round: measure that window.
- Hanging over the pillars his drawn boots (to y ~189) sweep through the pillar caps (160): asked
  the visual builder (tuck the legs over a TOP below, or a shorter hang). Letting go there now
  lands him on the cap almost at once, as the picture suggests.
- Hanging, he throws from his drawn hand (y = VINE_DRAW_Y), not along the top through the HUD
  (judge r0 item 10: "a row of rings inside the HUD band"). Test in _test_hang.
- Probes (round_1/probes.txt): climb 6 ticks; bandit jump window 450 ms; small-platform hops
  500 ms each; the last long pool's two hops 300 / 325 ms (the hardest, at 91 %); bots seeds 1-3
  home with 80-83 Red Bobs, 3/2/1 lives (falls only, at cols 490 and 730).
- Frame cost over the new 60-tile river: 0.68 ms CPU a frame (old pool 0.69); texture memory
  unchanged (70 MB world at 2400x1080).
- Round 1 evidence: _agents/gameplay/rounds/round_1/ (strips, screens/, world_pits_*, probes.txt,
  sfx_spectra.png).

## Round 2 (critique r1: items 10, 30-35; copy synced to the merged state)

- falls_cost_life switch: config/game_config.cfg [rules], default false (the 2017 rule: a fall
  ends the run). World.falls_cost_life, set by GameScreen from the config; strip --falls=1 forces it.
  Tests for both.
- Strip tool: the "Tap to start" card is removed at once (it faded over every strip, item 35).
- Camera (game_screen _place_camera): draws back (FRAME_TOP 78 units of sky) as he goes up high, so
  the vine and the hanging hero sit under the HUD (item 10); pushes in to the doorway at home
  (HOME_PUSH 1.4); the shake zoom. SavannaView/WorldView: view_top (sky and grade above y 0).
- Ending: HUD fades, he ducks (crouch) 110 units before the low doorway, a light burst from the
  doorway once he is inside, the panel after 1.9 s (HOME_DELAY).
- Hero (hero_view): push-off crouch rising out of the ground (TAKEOFF 0.07 s), stronger stretch on
  the rise, the tuck turns in from the leap (settle), squash at the apex, stretch as the fall speeds
  up, flail and fade into the water when nothing is below, climb pose (leap_up by its feet,
  scrabbling), mantle (crouch leaning in), recoil (tuck) and a 2-frame white flash on a hit, smooth
  8 Hz mercy pulse after the knock, throw wind-up (run_b) then follow-through (run_a).
- Hit: CLUB_REACH 56 (first contact with the 1.25x drawn bodies; never through a wall: test),
  jump-over window 400 ms; HURT_STOP 0.12 s; a 40 ms real-time white flash; red edge vignette
  (Fx.vignette_texture) instead of the full-screen tint; the bandit vaults over him after the blow
  (bandit_view, drawing only).
- KO: KO_STOP 0.1 s, shake, "+1" (Fx.plus_one), the bandit launched fast (bandit_view KO_*), the hero
  stretches proudly (HeroView.cheer); ring streak longer and brighter with a white core, the ring
  hidden through the 40 ms wind-up (ring_view).
- Fall (switch on): FALL_BEAT 0.3 s, SPRING_X 230 (clear of the hearts), a glow, ring and light trail
  where he breaks the surface (world_view), flail and fade under the surface (hero_view).
- Climb: reach pose from a blocked jump, grit off the wall when the climb starts, the mantle;
  stepping off an edge leans into a crouch instead of running on air.
- Round 2 tests: 315 checks, 0 failed; bot state 2 (107 s, 82 Red Bobs, 3 lives, 32 KOs) with
  falls_cost_life off. Probes: bandit hit at a 76-unit centre gap, jump-over window 400 ms; hops
  unchanged (500 ms; last pool 300 / 325 ms).
- Caught: thrown mostly up (-55, -760) so the tumble plays on screen, not off the left edge.
- Evidence: _agents/gameplay/rounds/round_2/ (strips, screens/, probes.txt).
