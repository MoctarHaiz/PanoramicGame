# UX track log (AAA pass)

Track: menus, tutorial, controls, safe areas, readability, EN/FR. Brief: `ROOT/_agents/AAA/BRIEF.md`.
Captures: `ROOT/_agents/AAA/ux/round_<n>/`.

## Round 1

Baseline (round 0, `AAA/round_0/ours/`): menu with the old painted portrait cropped at the chest; settings
are white iOS rows on the sunset (34 pt rows, plain); start card a dark brown slab with the diamond strip
the judge called "marquee lights" three times; HUD pause button 60 units (37 pt on an iPhone 15, under the
44 pt minimum); French strings use plain spaces before ! ? : (should be non-breaking).

Plan, in order of what the judge sees:
1. Menu around a full-body 3D render of Panoramic (the user's `Making/IdleFront` render).
2. Results (win / game over) with the 3D hero (standing for a win, on one knee for a defeat), big stars.
3. Pause and settings as one kit (framed candy panels, cream interiors, big touch targets).
4. First-run tutorial in context (hold the world at the moment a move is needed, animated hand).
5. Accessibility options (volumes, haptics, screen shake, reduced motion, replay tutorial).
6. Safe areas on the six capture devices; French typography (U+00A0 before ! ? : ; and inside « »;
   Fredoka and Quicksand have no U+202F).

Progress notes follow.

### Done so far (round 1)

- Kit: `GlossStyle` gets a lit ring (`set_frame`) and a darker lip at the face's foot; every candy
  button (`Ui.candy_button`, `icon_button`, `round_button`) is now a chunky rounded slab in a gold ring
  (`Ui.FRAMES`), the Royal Match look. `Ui.plaque_style()`: cream plaque in a gold ring (menu records).
  `Card` rebuilt: lacquered wood frame, gold trim, cream body with inner shadow; the bead strips and
  planks are gone (judge: "marquee lights", "template"). Wells are sand insets. `JuicyButton` takes
  touches over at least `Ui.MIN_TOUCH` (86 units = 48 dp on a 360 dp phone) via `_has_point`; idle and
  shine stop with reduced motion. `Ui.label` no longer auto-translates (keys like BEST were being
  re-translated: "BEST".to_upper() showed "Best").
- Menu: Panoramic full length from the user's 3D render (`assets/art/ui/hero_stand.png`, made by
  `tools/art/ui_hero.py` from `Making/IdleFront/0001.png`) on the left, standing on a backlit granite
  kopje (`menu_rock.png`, same script), the sun moved behind him (`SunsetBackdrop.sun_at`), rim light
  (`src/ui/hero.gdshader`); logo, PLAY, cream Best plaque and a blue settings button on the right.
- Pause / results / start card / tutorial moved out of `game_screen.gd` into `src/ui/`:
  `game_panel.gd` (veil dimmed + vignette, card centred, character on a pool of light overlapping the
  card), `pause_panel.gd` (the five moves with their gestures, music/sound switches with a tick or a
  cross, Home, RESUME), `results_panel.gd` (win: big stars over a sunburst, confetti from the corners,
  hero standing; loss: GAME OVER + what happened, distance bar to the house, hero on one knee),
  `start_card.gd` ("Tap to start" + tapping hand; later runs add the five moves), `gesture.gd` (one
  drawn gesture per move, animated hand), `tutorial.gd` (lessons when needed, world held, skippable,
  saved, replayable).
- Settings rebuilt in the kit (one framed panel, sliders, toggles with tick/cross, buttons, Credits
  popup). New options: music/sound volumes (`Prefs.apply_volumes`, bus volumes), screen shake, reduce
  motion, replay the tutorial.
- Strings: new keys, French typography (U+00A0 before ! ? : ;, typographic apostrophes).
- HUD: the way home redrawn (sandy dashed path, gold fill, halfway flag, glowing house, the 3D face);
  pieces under the hero fade fully out (never held half-faded); pause hit area 86.

Other tracks' files touched (smallest edits): `src/autoload/save.gd` (5 new keys),
`src/game/game_screen.gd` (start card/pause/results now call `StartCard`/`PausePanel`/`ResultsPanel`;
`_tutorial` hold in `_process`; `Prefs.shake()` on the shake; `playing()`/`swipe_min()` for the
tutorial; `_start()` no longer marks the tutorial seen).
- New logo (`tools/art/ui_logo.py`, numpy): CHAKA over ZULU, bevelled gold letters with an extruded
  ink depth, over a lit cowhide isihlangu and two crossed assegais (replaces logo.py's flat SVG logo; if
  the art track reruns logo.py it overwrites this one). HUD head (`head.png`) is now the 3D face (also
  made by ui_hero.py; art's ui_art.py would overwrite it).
- Boot: warm paper with a soft light and bouncing sunset dots under the studio logo.
- Share card: the menu's look (hero on the left, sun behind him, logo, cream plaque, red chip).
- Results: win = warm veil + big turning rays + gold ribbon + confetti from both lower corners; loss =
  cold dim veil, crimson GAME OVER, what happened under it, a drawn knocked-out bandit badge for the
  bandits count (no more trophy), the way home as a bar ("21 %" in French, "21%" in English).
- Tutorial probe (bot run, everyone learning each lesson when shown): throw at 0.8 s (first bandit in
  view), jump at 9.3 s (against the first pillar), step at 15 s, let go at 25 s, hang at 44 s. One look
  costs ~1.5 ms on the M2 (clone 0.2 ms + 30 ticks x 43 us), every 4 ticks, only while lessons are left.
- Tests: `_test_ux()` (lessons at the right moment and their move works, learned ones never return,
  replay, comfort options, 86-unit touch areas, French typography, every new text translated):
  375 checks, 0 failed, exit 0.

Next: review round 1 captures at full size and shrunk; ads-on layouts; then the judge's critique.

### QA round 1 (bugs.md) answered
- UX-1: the HUD pieces under him fade fully out and back in a blink (never held at 28 %).
- UX-2: `Hud.leave()` slides the HUD up and out in 0.2 s at home and on the results (was a 0.35 s fade).
- UX-3: results now centre the card (the character overlaps its left edge, both kept in the safe area);
  the menu has the hero on the left (no ribbon over his hair); About moved into a Credits popup (no
  scroll, no grey scrollbar).
- UX-4: no ad banner during play by default (`[ads] banner_in_play`, default false: AdMob placement
  policy); pause and results show it; the world no longer shrinks for it. NEEDS THE USER'S OK (revenue).
- UX-5: the panels' veil is a plain dim + vignette now (no blur: no banding, no screen-sized copy).
- Minors: heart flash with an additive glow (no modulate > 1); no bandit beside a "fell" defeat (the
  hero on one knee for every loss); no halo behind New best; pause hit area 86 units; music/sounds keep
  their own icons with a tick or a cross; ribbon text has room at both ends; `_physical_swipe_min()`
  returns SWIPE_MIN inside SubViewports (no warning in the tools); the step forward is taught.
- QA's `tests/capture.gd` and `tests/bot_replay.gd` copied unchanged (fast replays from `build/qa/`).
- After the first six-device pass: the game over hero (on one knee) is drawn at 72 % of the card's
  height and barely overlaps it (his boots covered Home); result groups are clamped inside the safe area
  (on the iPad the card hugged or crossed the right edge); the menu ribbon shrinks to the column on a
  tablet (it ran off the right edge); the menu column has air above and below (logo at most 300).
- `tools/art/manifest.py`: four rows for the new UI art (logo by ui_logo.py, hero_*, head and
  menu_rock by ui_hero.py from the user's renders); `asset-manifest.json` regenerated (86 assets, 0
  problems).

### Round 1 captures (`AAA/ux/round_1/`)
- `en/` and `fr/`: boot, menu, first_menu, start, game, pause, gameover, fell, win, settings, home on all six
  devices (QA's capture tool; menu/first_menu and gameover/fell/win recaptured after the layout fixes).
- `ads/`: menu, settings, game, pause, gameover with the debug banner on phone_1280x720 and iPhone 15 (the
  capture tool draws its grey banner in every shot; the game itself now hides it during play).
- Not in the shots (checked with a scratch script, deleted): the tutorial's throw and jump lessons, the
  later-run start card with the five moves, the share card.

Still short: the win could be a bigger moment (full-screen confetti rain, hero celebration pose: the
renders have no cheer/victory animation); the menu pose is a calm stance (the judge asked for action);
the boot logo art (art track); the in-game hero is still the old painted sprite (art track).
