# QA track log (AAA pass)

Worktree `_agents/wt/qa/New`. Output `_agents/AAA/qa/round_<n>/`.

## Round 1

Baseline: `run_tests.tscn` 314 checks, 0 failed, exit 0 (3346 ObjectDB instances leaked at exit: worlds
kept alive by test lambdas that capture them).

### Done

- `tests/bot_replay.gd` (BotReplay): the bot's run recorded once (input per tick) into `build/qa/`, keyed on
  world.gd, level.gd, bot.gd and the level file; replayed for free. The bot's look-ahead costs ~70 ms a tick,
  so capture moments took ~280 s every run; now once.
- `tests/capture.gd`: moments come from the replay; `--lang=en,fr` takes both languages in one run (DIR/en,
  DIR/fr); new shots for a store release: first_menu, throw, hurt, resume, fell, settings_end.

- `tests/perf.gd` + `perf.tscn`: the level at a device size with the recorded bot; per phase (menu, load,
  run, paused, results, menu_again): wall ms per frame (vsync off, --fixed-fps 60), scripts and render CPU
  p99, texture/video memory, draw calls, objects, primitives, nodes; texture memory every 5 s, pictures
  first loaded mid-run, frames over 16 ms, texture jumps with the nodes added that frame; pass/fail; JSON.
  Lesson: `Performance.TIME_PROCESS` is the worst process time of the LAST SECOND (updated once a second),
  not a frame's time: the first version reported 250-400 ms "frames". Now the frame's wall time and a
  first/last process_priority pair.
- `tests/strip.gd`: `--film=DIR` (every kept frame as DIR/0001.png..., then DIR.mp4 via ffmpeg) and
  `--layers=1` (one frame built up layer by layer, names in a .txt).
- `tests/run_tests.gd` release checks (QA section at the end): translation placeholders and compiled keys,
  save round trip (in memory: Save.PATH is the player's real file) and every lasting Save var in _KEYS,
  determinism (scripted player and the recorded bot at 30/60/120/144 Hz and an uneven rate, every 2.5 s),
  every screen x 6 devices x EN/FR (no error or warning via a Logger, buttons/texts inside the safe area,
  no cut autowrap text, no raw key), no node left after two runs and back to the menu, pause at random
  moments changes nothing, the recorded bot gets home through the real game screen (if recorded).
  314 -> 521 checks, ~40 s (was 1.5 s), exit 0.

- Second pass on the tools after looking at their output:
  - perf: the frame budget is judged on the game's own work (scripts + render CPU, max) and the wall-time p99;
    single long wall frames with ~1 ms of own work are other programs on this shared Mac (load average ~10).
    Records restored before the return to the menu (a new best adds a star node: not a leak).
  - capture `home`: the win + 1.2 s with no autopilot (the old shot caught the HUD's 0.35 s fade: the judge's
    "half-transparent HUD"); each shot seeds `seed()`; `BotReplay.snapshot()` keeps prev_* (World.clone()
    doesn't: strips started on a frame from the level start).
  - strip `--moment` uses the replay (same moments as capture, instant); `--layers` freezes the game and names
    painter layers by their draw function (`_draw_strip(far_mesas)`).
  - run_tests: `_test_sounds` (every played sound and variant file exists, music for both screens).
- Outputs: `AAA/qa/round_1/bugs.md` (by track, severity, repro), `store_readiness.md`, `audit/{en,fr}` (204
  shots), `audit_ads/`, `sheets/`, `strips/` (home_arrival, layers, film_test.mp4), `perf_iphone15.*`.

### Findings (details in AAA/qa/round_1/bugs.md)

- perf at iPhone 15: texture memory 85 MB menu, 87 run start, 115 steady, +15 pause veil, 148 results, 153 back
  on the menu (budget 80). Level load freezes 290-420 ms. Play frames: own work p99 ~6 ms; ok.
- Bugs that look like bugs: ghost Red Bobs (bob_view flier afterimages), HUD held at 28 % (hud.gd fade), HUD
  mid-fade at home, modulate(3,3,3) heart flash, wall-clock hero flash, iPad panels on the screen edge,
  banner under the swipe area, frost banding.
- Store: privacy policy URL 404, AdMob sample ids, no store art, iOS privacy manifest says no tracking.

### End of round 1

- `run_tests.tscn`: 524 checks, 0 failed, exit 0 (~42 s); `-- --quick` 326 checks in ~3 s (no screens);
  `-- --bot` 525 checks, 0 failed, bot home with 3 lives, 82 Red Bobs, 2 stars.
- perf iPhone 15 (whole level): texture FAIL 152.7 MB; frames PASS (own work max 10.1 ms, wall p99 9.8 ms);
  nodes PASS. 720p (40 s): texture 107 MB (pictures dominate). Load 277-302 ms.
- Audit `home` and `hurt` re-captured with the fixed capture (all devices, EN/FR).

### Next round

- Review the builders' merge in wt/base (rerun: run_tests, perf at iphone15 + phone_1280x720, the full
  EN/FR audit, film of a store preview), diff against round 1, recheck every bugs.md item.
- Ask gameplay for `World.clone()` prev_* (GP-1) and maybe a `Save` path override for a real file round trip.

## Round 2 (review of the round 1 merge)

- Merge review: camera, endings, results guard, swipe_min, hero.gdshader, hud.leave, Save path all fine.
  Lost: footsteps (art's hero_view.gd has neither run_frame() nor run_a/run_b, audio's Footsteps needs one:
  0 steps in the real game) and the walk-in at home.
- The 3 failures: (1) "Parameter t is null" = headless dummy renderer + threaded picture loads still running
  (reproduced with a probe; control without threads: 0), fixed in `_test_preload` (waits for every preload);
  (2) FR start card on iPad: `StartCard._fit` measures the overgrown CenterContainer and its scale is reset by
  the container's sort (probe), ux; (3) the win check kept the start card up (my test), fixed.
- Tests: ErrorLog shows where an error came from (script frame, loading thread); save round trip now through the
  real files on a scratch `Save.path`; `_test_contracts` (footsteps vs the real hero view); `--quick` skips it.
  799 checks, 2 failed (UX start card, art/audio footsteps), quick 600, 0 failed.
- Capture: gameover/fell wait DYING_TIME/FALL_DEATH_TIME + 1.5; the ad stand-in only when the game wants a banner.
- Perf: `--jump-mb`; spikes also list frames with 3/4 of the budget of own work. Merge at iPhone 15: menu 51 MB,
  play 85-87 MB before the first pause (combo chip font sizes: +4 MB per size), menu again 110 MB; load 303 ms.
- README testing section: perf.tscn, --quick, --film, --layers, --lang=en,fr.
- Outputs: AAA/qa/round_2/ (bugs.md, audit, audit_ads, sheets, strips, perf_*).

## Round 3 (review of the round 2 merge, 828261b)

- Merge: footsteps fixed (run_frame), bandit flash shared, results pictures fine. Lost: UX's one-size "×N"
  (`_combo_tag`, dead code) under audio's `Fx.streak_pop`, which draws a new font size per streak step:
  +6 MB texture per step (8 steps in the first second: 64 -> 112 MB), the same in RAM.
- Capture: gameover/fell/win wait for `_results_shown` + REVEAL 3.4 s (final counts, stamp). Tests use the same
  REVEAL and force a new best: the stamp now fails on iPad (off screen) and covers the score everywhere (UX).
- The headless "Parameter t is null" came back with the preloads drained: it's the dummy renderer, not the game.
  ErrorLog now counts errors raised in servers/rendering/dummy as harness notes (printed, not failed).
- perf: RAM column (MEMORY_STATIC). Merge: menu 63, run 112 before the pause, menu again 140.6 MB; RAM 143 MB in
  play; draw calls 187 mean / 512 max (down); level open 317 ms; frames pass.
- Outputs: AAA/qa/round_3/ (bugs.md, audit, sheets, crops, perf_*).

## Round 4 (audit of the round 3 merge, d289a14)

- Seam = TerrainView's cast shadow (`cast` + `front_cast`), found by A/B hiding (`strip.gd --hide`, new). The island's
  "hard cut" = the `mass` layer past the island's end. The "white ring face" Bob = WorldView._on_bob's ring/glow in
  view.fx (z 10) drawn over the joy-faced flier in _fliers (z 0).
- Merge points: hide list misses the tutorial and start card (ghosts when paused in a lesson: new capture shots
  `lesson`, `lesson_pause`); warm-up works (level open 102-124 ms wall, 63 ms own, was ~310); fireworks in, but the
  win reveal peaks at 959 draw calls / ~10k objects and the confetti lands on the text.
- Perf iPhone 15: play 77.3 MB until the first pause, then 92.9 (pause panel +9, countdown digit +8); results 105.5;
  menu after a run 113.7 MB; RAM 55-120 MB.
- `_gp_camera` (gameplay) is flaky under load: 1-2 failures per full run, frames 36-39 (camera eases behind a jump in
  camera_must_see). Reported; not my function.
- capture: `throw`/`hurt` bandit placed short of a wall.

## Round 5 (audit of the round 4 merge, 99a1636)

- Perf passes everywhere: texture 53-64 MB, RAM 49-59 MB, frames, nodes. Panels keep the world drawing under them
  (pause 428 draw calls).
- Blocky blur: `blurred_snapshot(vp, 5)` = 1/32 picture stretched 32x (bilinear facets) + the card's 7-band stepped
  shadow. Grey dots = WayBar's quarter studs around the "21%". Hang into the HUD = HUD_BAND (78) ignores the top
  inset (iPad plates reach 93): new `_test_hud_band` fails on iPad. Mesa streaks = savanna.py's gullies
  (noise blurred 22 x 5, its x-gradient lights the cliffs) at 1 px per unit, magnified 1.8-3.2x; not compression
  (decoded import = PNG). Island: the soil band is still a square box (A/B with --hide).
- 1022 checks, 1 failed (the iPad HUD band, a real bug); quick 775, 0 failed.
