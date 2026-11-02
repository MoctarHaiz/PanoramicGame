# Characters, interface and feel pass (agent log)

Private copy: `_agents/characters/New`. Nothing committed. No paid generator: every asset comes from
a re-runnable script in `tools/art/` (SVG rendered by headless Chrome, or Pillow).

## Review tools

- `tests/strip.gd` + `tests/strip.tscn` (new): plays the game off screen at a phone size and saves a
  contact sheet of frames (motion review). Options: `--out`, `--frames`, `--every`, `--crop=x,y,w,h`
  (design units), `--cols`, `--size=WxH`, `--bandit=N` (a bandit N units ahead), `--hurt=1`,
  `--act=throw@4,jump@10` (also hurt, win, die, fall), `--moment="..."` with `--bot`, `--warm`.
  Strips go to `build/strips/`.
- Captures: `build/caps/` (latest), `build/caps0/` (before this pass).

## Milestone 1: the bandit (done)

- `tools/art/bandit.py` (new): an original masked raider posed by a 2D skeleton in Python and drawn
  as SVG. Each body part is a flat group; one SVG filter per part paints it in world space like the
  hero's cel-shaded art (core shadow away from the upper-left light, lit edge, warm sunset rim on the
  back, dark ink outline); big shapes have world-aligned radial gradients. Rendered 4x by Chrome and
  halved with premultiplied alpha.
  - Design: violet hood with hyena ears and a teal crest (the 2017 bandit's teal hair), glowing amber
    angry eyes in the shade of the cowl, a mustard face wrap (the 2017 yellow and black), leather
    vest, iron shoulder guard, white wrist and shin wraps, a studded club raised behind the head.
    All skin covered (a costume, not a people). Faces left.
  - Sheet `assets/art/bandit/bandit.png` (8 columns x 3 rows, 2x texture): run (8 frames, auto-grounded
    planted foot, flight lift), dazed run (ear flopped, plaster, far eye squeezed), knock-out (blow,
    tumble), idle crouch (2 breathing frames for bandits waiting outside the 960 play window).
    `bandit.json`: cell, anchor (feet), `run_fps` computed so the planted boot stays still on the
    ground (27.5 fps at 291 u/s), per-frame head positions, knock-out centres. `club.png`: the club
    alone (it flies off on a knock-out).
- `src/game/bandit_view.gd` (new, `BanditView`): plays the sheet on the world's clock (pause and
  hit-stop freeze it), a contact shadow, a white flash + jolt + squash on each ring, dazed stars
  orbiting the hood (those behind drawn under the sprite), knock-out: frozen on the blow 0.09 s,
  then thrown up and back spinning while the club spins away on its own arc.
- `src/game/actor.gdshader` (new): flash, optional outline and rim light for characters. (The old
  `flash.gdshader` multiplies the texture twice: in Godot 4 `COLOR` already holds texture x modulate;
  it is no longer used by characters.)
- `world_view.gd`: only `_place_bandits` and `_on_bandit_hit` changed (BanditView), plus the comment
  of `_bandits`.

## Milestone 2: the Red Bob (done)

- `tools/art/bob.py` (new): glossy red ball with a cute face (SVG): smile (looking a little left at
  Panoramic), blink, joy (collected), wink. `assets/art/bob/bob.png` (4 x 128 px) + `bob.json`.
- `src/game/bob_view.gd` (new, `BobView`): floats with a ripple along each row, squash at the bottom
  of its float, random blinks and a rare wink, an additive glint star on its gloss.
  `BobView.texture()` for the HUD/results/share card, `BobView.flier()`: on pickup a copy pops with
  joy and flies on a curve to the HUD counter, which counts it on arrival and pops.
- `world_view.gd`: the bob creation loop and `_on_bob` (warm glow, ring, sparks, `bob_popped`).
- `game_screen.gd`: `_on_bob` combo: quick pickups climb the A major scale (pitch steps 0-12
  semitones); `_on_bob_popped` launches the flier.
- `hud.gd`, `share_card.gd`: use `BobView.texture()` (GameArt's 2017 bob frames are no longer used by
  my code; `game_art.gd` untouched).

## Milestone 3: Panoramic's motion (done, first pass)

- `src/game/hero_view.gd` rewritten (same API): world-clock animation; run: each stride lands into a
  squash and rises into a stretch with a bob and a lean (0.18 s strides, slower against a wall);
  on his marks before the start (crouch, breathing); air: leap stretched by speed, tuck, pop on
  ground/air pose changes, tilt with vertical speed; hang: damped pendulum (momentum swing, wind of
  the run); throw: lean and lunge; hurt: flash, knock back up and back, then flicker; caught: thrown
  up and tumbling out of the picture; home: a hop with the staff raised, then he turns to the player
  (stand_front, scaled 0.58: the turnaround is drawn twice as big on the sheet).
- A red scarf simulated in code (position-based chain, wind of the run with lift, gravity, flutter)
  knotted behind the neck in the poses whose painted scarf is only a knot (run_a, run_b, leap_up);
  a soft contact shadow on the first grass top below him (smaller and lighter with height).
- Poses padded by 4 px at load (outline room) and mipmapped; thin warm outline + sun rim (actor shader).
- `Fx.dust` (new) + world_view `_dust` body only: pale puffs carried by the scrolling ground (the old
  dust was a big brown blob).

## Milestone 4: effects (first pass)

- `fx.gd`: `impact` (Panoramic hurt) is now a jagged hit spark, red glow and ring, a few stars (no
  more stone chips); new `ring_hit`, `knock_out` (blue burst, rays, stars, dust where he stood),
  `hit_spark`, `dust`.

## Milestone 5: interface (in progress)

- `tools/art/logo.py` (new): `assets/art/ui/logo.png` (CHAKA / ZULU in gold display letters with
  depth over a Zulu isihlangu shield: cowhide, laced strip, stick, bead strings; Fredoka embedded
  in the SVG), `ribbon.png` (9-sliced subtitle banner with beadwork), `beads.png` (tiling beadwork
  strip), `shield.png`.
- `tools/art/ui_art.py` (new): `assets/art/ui/head.png` (Panoramic's face badge).
- `src/ui/shine.gdshader` (new): light sweep (logo). `src/ui/motes.gd` (new): drifting dust motes.
- `src/screens/menu_screen.gd` rewritten: logo + ribbon subtitle, PLAY, best plaque, settings;
  hero halo (glow + slow rays), motes, vignette; entrance choreography.
- `src/game/hud.gd` rewritten: lives on glass (a lost heart flies off, the last one beats), the way
  home (gold track, Panoramic's badge running to the house), Bob counter fed by the fliers.
- `src/ui/card.gd` (new, `Card`): the in-game panel (gradient body, ink outline, gold line, beadwork).
- `game_screen.gd`: new start card (gesture badges, a hand tapping beside "Tap to start"), pause
  (Card + Banner, music/sound toggles, Resume/Home), results (Banner title, stars thumping in on the
  A major triad, counts ticking up, NEW BEST chip with burst and confetti, buttons fade in).

- Results reveal timing: stars land 0.2 s apart while the three counts tick up side by side (0.5 s
  each, staggered); buttons usable after 0.45 s; NEW BEST at 1.15 s (chip, burst, confetti rain).
  Game over plays `sfx_game_over` (it was never played before).
- Menu: best plaque (Bob, BEST, count, stars) replaces the counter pill that overlapped the stars.
- `screen.gd` header: the page title is a Banner ribbon; settings About card shows the logo.
- `Card`: the ink edge is a stroke (the see-through start card no longer sits on an opaque fill).
- `world_view._place_bandits`: a bandit still waiting outside the 960 play window with no grass
  under its feet (over a hole, visible on wide phones) is not drawn.

## Milestone 6: sound (first pass)

- `tools/sfx_synth.py`: new `marimba`, `brass`, `fanfare_brass` (win: brass call A-C#-E-A with bells
  and a timpani roll), `lose_marimba` (game over), `bling_same` (Red Bob variants share one pitch so
  the combo ladder in `game_screen` climbs the A major scale), `sfx_star` is one file now (the game
  asked for `sfx_star.wav`, which did not exist: the results stars were silent; the old
  `sfx_star_1..3.wav` removed). Regenerated: sfx_bob_1-3, sfx_game_over, sfx_win, sfx_star.

## Milestone 7: ring (done)

- `ring_view.gd`: two highlights racing round the core, a launch flash, a tapered additive streak and
  fading ghost rings behind it, sparks shed as it flies.

Captures: `build/caps/` pixel_2400x1080 (menu, start, game, pause, gameover, win, hang),
phone_1280x720 / iphone15_2556x1179 / ipad13_2752x2064 (menu, start, pause, settings, with the banner
stand-in). Strips: `build/strips/` (bandit_run, bandit_hit, bandit_ko, pickup, hero_run,
results_win).

Tests: `199 checks, 0 failed` (last run).

## Milestone 8: polish round 2

- Bandit art: stronger cel contrast (shade 0.66, lit 0.42), sleeve folds, stitched seams on the
  vest and the hood, a pouch and buckle glint, a darker band round the face opening, glints on the
  toe caps and the shoulder guard, a painterly mottling pass (`mottle()`), scarf tails streaming
  back instead of up.
- Hero: victory is now gather (crouch) -> hop with the staff raised high (the hanging pose placed by
  its boots) -> landing squash -> turns to the player; hurt flash shorter and warm (no white
  ghost); the code scarf disappears at once on poses whose scarf is painted (no floating ribbon) and
  is re-seeded behind the knot when it comes back.
- Strips: `build/strips/hero_hurt.png`, `hero_die.png`, `hero_win.png`, `hero_jump.png`.

## Milestone 9: motion and finish

- Run between the two painted poses: `actor.gdshader` gained a stance slide (`warp_px`,
  `warp_from`, `opacity`): everything below the hips slides back through each stride, so the planted
  boot travels with the ground instead of freezing for 11 frames; cadence 0.16 s; poses padded 24 px.
  Strip: `build/strips/hero_run60.png` (20 consecutive frames).
- Combo: from the third quick Red Bob a gold "×N" pops under the counter, in step with the notes.
- `Fx.warm_up` also compiles `actor.gdshader` and `shine.gdshader` at boot; the HUD track caches its
  style boxes.
- `wipe.gdshader`: the transition disc has a gold band and an ink line along its edge (the panels'
  trim). Strip: `build/strips/wipe.png`.
- `tests/strip.gd`: `--bobs=N`, act `menu`.
- French checked on the narrowest layout (iPad): `build/caps_fr/` (menu, start, settings).

## Files

New: `src/game/bandit_view.gd`, `src/game/bob_view.gd`, `src/game/actor.gdshader`, `src/ui/card.gd`,
`src/ui/motes.gd`, `src/ui/shine.gdshader`, `tools/art/bandit.py`, `tools/art/bob.py`,
`tools/art/logo.py`, `tools/art/ui_art.py`, `tests/strip.gd`, `tests/strip.tscn`,
`assets/art/bandit/` (bandit.png, bandit.json, club.png), `assets/art/bob/` (bob.png, bob.json),
`assets/art/ui/` (logo.png, ribbon.png, beads.png, shield.png, head.png).
Changed: `src/game/hero_view.gd`, `ring_view.gd`, `hud.gd`, `game_screen.gd`, `fx.gd`,
`world_view.gd` (only `_place_bandits`, `_on_bandit_hit`, the bob creation loop, `_on_bob`, the body
of `_dust`, and the comments of `_bobs`/`_bandits`), `src/screens/menu_screen.gd`,
`settings_screen.gd`, `src/ui/screen.gd`, `share_card.gd`, `wipe.gdshader`, `tools/sfx_synth.py`,
`assets/audio/` (sfx_bob_1-3, sfx_game_over, sfx_win, sfx_star; sfx_star_1-3 removed).
Untouched: `game_art.gd` (its 2017 bandit and bob frames are simply no longer used), savanna, vine,
terrain, sky, home, sunset backdrop, `world.gd`, level data.
- Sound: `ouch_marimba` for `sfx_hurt` (thump, club slap, a falling C#-A marimba "uh-oh"),
  replacing a square-ish distorted buzz.
- Fix: `club.png` was clipped to its handle (the drawing is mirrored and ran off its canvas); the
  whole club now flies off on a knock-out.
- Results: the NEW BEST slot is 54 units and the chip 25 pt (it touched the buttons).

## Final captures

`build/caps_final/` : boot, menu, start, game, climb, hang, home, pause, gameover, win, settings on
pixel_2400x1080, phone_1280x720, iphone15_2556x1179 (notch) and ipad13_2752x2064, with the banner
stand-in. French: `build/caps_fr/`. Motion: `build/strips/`. Before this pass: `build/caps0/`.
Tests: `199 checks, 0 failed`.

## Remaining weaknesses (most visible first)

1. Panoramic still runs on two painted poses (now with a stance slide, bob, squash, lean and a
   physics scarf); a real 6-8 frame run needs new art from the user's generator
   (ASSET_REQUESTS #5 and #6: run cycle, hang, throw, hurt, victory).
2. The bandit is drawn in code: clean, on palette and readable, but simpler and more "vector" than
   the painted hero up close; a painted sheet (ASSET_REQUESTS #1) would close the gap. Its run is 8
   frames; the hurt run reuses them with a different head.
3. The victory pose (stand_front) comes from the turnaround: no staff, red scarf without the blue
   neckerchief of the action poses.
4. Sounds are synthesised and were checked by level and length only, not by ear.
5. In the strip harness the transition disc looks oval (the viewport size it is given); it predates
   this pass and should be checked on a device.
6. The combo tag counts Bobs as they are taken while the counter counts them as they land (0.5 s
   later): briefly out of step.
7. The Haiz Studio logo in About is a low-resolution 2017 picture.
