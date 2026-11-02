# Gameplay and systems log (AAA pass)

Track `gameplay`: rules (`src/game/world.gd`, `level.gd`, `assets/level/`), saves (`src/autoload/save.gd`),
`config.gd`, `config/`, the bot and probes (`tests/bot.gd`, `probes.gd`, `explore.gd`), and in
`src/game/game_screen.gd` the game flow, input and states. The previous pass's log is
`docs/art/agent_gameplay.md`.

## Round 1

Baseline 314 checks; now 378, 0 failed (379 with `-- --bot`: home, 82 Red Bobs, 3 lives, 3 stars). Bots seeds 1-4 home with 3 lives (80-84 Red Bobs, 3 stars).
Evidence: `_agents/AAA/gameplay/round_1/` (strips/, screens/, probes.txt).

### Audit: what was wrong (fixed unless said)

- Input latency: a move waits for the next 40 Hz tick (0-25 ms), then the picture moves on the next
  frame. Measured (probes --probe=latency): worst 33 ms at 30/60/90/120 Hz, average 18-33 ms. Kept.
- A short flick (lifted before the 4 mm swipe distance) was read as a tap: a ring instead of a jump.
- One swipe per touch: a thumb kept on the glass couldn't jump then let go.
- Two fingers swiping together asked the same move twice: two jumps left a jump buffered that fired
  on the next landing (World._ask: one of each move per tick).
- A swipe up during a climb begun from a fall was eaten by the climb (jump sound, no jump): now
  buffered, he jumps from the top.
- Coyote time: the 2017 rule lets a fall jump once at any time ("a fall can still jump once"), so
  walking off a ledge never steals a jump. Jump buffer 6 ticks (0.15 s). Kept.
- The tunnel (cols 336-405): its roof is a solid-looking slab exactly his height above the floor.
  A jump went up through the roof, stopped the level while he was inside it and hung him from the
  vine above it. A jump now stops at a ceiling (World.ceiling_above: a wall tile with nothing solid
  under it; only this roof is reachable) and he drops back (`bumped`).
- Last screen: a swipe down left him kneeling for good (2017 too); hanging, he hung over the hut for
  good; near the hut taps threw rings at it and swipes made him hop (QA GP-2). Now the run home
  stands him up, over the doorway he lets go, and within HOME_REACH (160 units) of the doorway moves
  are ignored (the last bandit is long past by then).
- Bandits: 18 of the 49 were placed over pools; on a phone wider than the play window each appeared
  at the window's edge (74 % across an iPhone) only to drop into the river. They aren't placed.
  The rest run exactly as in 2017 (moving the in-rock ones out at placement shifted their timing:
  bandit 9 then dropped off the pillar at col 146 onto the bot; reverted). `Bandit.wait_x/wait_y`:
  where views draw one still waiting (world_view.gd uses it).
- Stars (new in the remake, not 2017): 3 stars asked for 80 % of 104 Red Bobs, but only 84 can be
  taken alive (level probe below): every reachable one, without a hit. Now 50 % / 80 % of
  BOBS_REACHABLE (42 / 68).
- World.clone() didn't copy prev_x/prev_y/prev_scroll/alpha: a screen opened on a copy drew its
  first frame from the start of the level (QA GP-1; the "hard cut" of the old end strip).
- The end of a run went to the panel after a fixed 1.1 s timer, whatever was on screen. Now a
  dying phase (below).
- Pause: works at every moment (start card, hit-stop, countdown, background, phone call), tested.
  On desktop debug runs focus loss doesn't pause (by design, for development).
- Hit boxes: documented over `body_rect()` in world.gd. They are the 2017 ones: the hurt boxes are
  the middle 32 units of his 64-unit body (forgiving: a club brushing a drawn limb doesn't count),
  pickups use the whole body (generous). The new 3D hero must keep his feet on the box bottom and
  his torso within ~24 units of x.

### Saves (save.gd)

Each write goes to `save.cfg.tmp` (flushed), the old save is renamed to `save.cfg.bak` (only if it
is a good save), then the tmp is renamed to `save.cfg`. Every file has `[meta] version=2` and an md5
checksum of its values. Load order: a complete `.tmp` (a write killed between its renames: newer),
`save.cfg`, `.bak`; a recovered save is written back at once; a damaged `save.cfg` is kept as
`.corrupt`. Version 1 (the first release: no meta) migrates with every value kept. Values of the
wrong type or out of range are clamped or dropped one by one. `set_option` writes nothing if the
value didn't change. `Save.path` (and `persist`) let a test do a real round trip elsewhere. Tests
`_gp_saves`: killed mid-write, killed between renames, garbage, cut short, emptied, no backup,
version 1, bad values.

### Input (touch_reader.gd, new; game_screen.gd)

TouchReader (a RefCounted, tested without a screen): each finger on its own; a swipe counts at 4 mm
mid-move, a fast flick (> ~100 mm/s) at 65 % of it; a flick lifted between the tap slop (1.6 mm)
and 4 mm is a swipe; after a swipe the same finger swipes again by turning another way for 1.5 x
the distance (up then down: jump then let go); a long swipe stays one swipe; taps within 0.45 s.
Note: a new `class_name`: run `Godot --headless --path . --import` once after merging.

### Game flow (game_screen.gd)

`Phase` READY, PLAYING, PAUSED, COUNTDOWN, DYING, HOME, RESULTS: `phase`, `phase_time`,
`phase_changed`, derived from the state every frame (no transition can be missed). The run is saved
the moment it ends; the panel waits for `World.end_time` (hit-stops don't count): caught
`DYING_TIME` 2.0 s, a fall `FALL_DEATH_TIME` 1.0 s, home `HOME_TIME` 2.1 s (HOME_LAND 0.25 s, the
victory beat to HOME_CHEER 1.3 s, then he walks in). A fresh tap or key from `SKIP_AFTER` 0.45 s
skips to the panel (not sooner: the player was tapping to throw). Caught, the camera closes in on
him (DEATH_PUSH 1.2).

Stand-ins in hero_view.gd (art's file, until the 3D renders are wired): caught, he is knocked up
onto the grass and lies there for the dying phase (he used to fly out of the picture in 0.7 s,
leaving 1.3 s of empty screen); home, a squash at the door, the staff raised with two bounces on his
feet (no hop: QA's home capture at 1.2 s caught him mid-air), then he runs in, fading.

### For the art track (views): what the rules expose

- Signals: jumped, landed (`land_speed` units/tick), hung, let_go, crouched, stepped, thrown(ring),
  bumped (new), bandit_hit, bob_collected, hurt(bandit, lives), fell, sprang, splashed, died(reason),
  won.
- `move_phase()`: idle (before the first tick: the IdleSide loop), run, land (4 ticks after
  touching down), crouch, takeoff (2 ticks), rise, apex (|vy| < 6), fall, climb, hang, dead, home.
  `phase_time()`: seconds in it (interpolated); after the end, seconds since the end.
- `air_progress()`: 0..1 through the air (0.5 = the top of a hop), from `ticks_to_land()`: map the
  27 JumpSide frames on it (take-off ~0-0.1, rise, apex ~0.45-0.55, fall, reach for the ground at
  ~0.9, land frames on `landed`). -1 when no landing is ahead: a pit (flail) or the vine.
- `ticks_to_land()`: the landing tick, foreseen exactly if nobody touches the screen (a look-ahead
  of up to 60 ticks: ~0.2 ms, worked out once a tick and cached; World.tick itself ~50 us).
- `ground_below(x, y)`: the grass under him (caught in the air, DieSide's 78 frames should fall to
  it), -1 over a pool.
- `ceiling_above(x, head_y, scroll)`: in the tunnel his drawn head and staff poke into the roof
  (he is drawn 1.25 x his box): draw him ducked there.
- `end_time` with DYING_TIME (78 frames over 2.0 s = 39 fps), FALL_DEATH_TIME, HOME_LAND,
  HOME_CHEER, HOME_TIME, SKIP_AFTER: the ending's beats.
- GameScreen `phase` / `phase_changed` for the HUD (UX): READY, PLAYING, PAUSED, COUNTDOWN, DYING,
  HOME, RESULTS.

### Level probe (tests/probes.gd)

- bobs (a bot aimed at each Red Bob from moments of a bot run, plus an exhaustive search for the
  island): 84 of 104 can be taken alive. 16 over the river after the pillars (row 12, cols 596-628)
  only by a fatal drop (falls end the run); with `falls_cost_life` on they would be a fair gamble (a
  life for up to 16). 4 at cols 201-203 (rows 16-17, the left end of the island) need a walk off the
  row-6 platform, then a jump off the island with 8 swipes right inside 0.6 s. Positions kept (the
  2017 level): a decision for the user, or a telegraph for art.
- warning: bandits wake at the play window's edge (960 units) and close at 524 u/s. On an iPad (4:3)
  only 853 units of play show: a bandit is first seen (853 - x - 90) / 524 s before its club reaches
  him: 1.25 s with him at the start x, 0.9 s at x 300, 0.54 s at MAX_X 480. The iPad also hides the
  play window's right 107 units (rings hit bandits there off screen). Phones show bandits waiting
  beyond 960 (1.4 s and more). Suggest (UX/art, _layout): on 4:3 show the whole 960-unit width.
- hops (round 2 numbers, rules unchanged): small platforms 500 ms windows; the last long pool's two
  hops 300 / 325 ms: the tightest jumps in the level.
- latency: see the audit.

### Next

- Wire the art track's renders to move_phase / air_progress / end_time (art), then re-judge the
  jump, death and home strips.
- If the user turns `falls_cost_life` on, re-run the bobs probe (the river becomes a choice).
- QA's capture waits 2.4 s after a death: with the dying phase it should wait
  `World.DYING_TIME + 1.5` (`FALL_DEATH_TIME + 1.5` for "fell") to catch the panel settled.
