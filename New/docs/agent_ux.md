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

## Round 2

Judged round 1: UX 0/8 (ours 6, settings 7, boot 2); merged 0/12. Critiques: `AAA/judge/j01_ux`,
`AAA/judge/j01`, motion `AAA/judge/m01`; QA `AAA/qa/round_2/bugs.md`.

Done:
- Merge failures: StartCard is a plain Control now, centred and scaled by hand (a container reset the
  scale; it measured itself, not the screen); the start card is freed when a run ends.
- Panels (GamePanel): behind them the game is taken once as a picture (`Ui.blurred_snapshot`: 1/16
  size by 2x2 averaging, drawn back stretched: a soft blur, no shader, no screen copy kept), tinted
  and vignetted, so the HUD and scene step back; the card pops in opaque (0.7 -> 1.06 -> 1), the
  ribbon drops in, the character slides in; the group (character + card) is centred; a tall
  character lifts the group down; his shadow under his feet.
- Card material: paper grain (`assets/art/ui/paper.png`, `tools/art/ui_kit.py`) under the cream,
  bevelled frame, gold studs, side inner shadows, a deeper drop shadow.
- Results: sequenced (stars slam 0.32 s apart with a burst and their note, the third shakes the card;
  coins and confetti in front of everything; the count rolls 0.7 s with ticks; a NEW BEST stamp slams
  on the count's corner last); buttons shown at once; Share in gold (no blue); the bandit stat and
  hearts dropped (mixed styles); the way-home bar fills after the count and ends on a gold house
  disc drawn into it (not a button); total out of World.BOBS_REACHABLE (what the stars count); the
  art track's `hero_win.png` (arms up), `hero_lose.png` when it exists, else my `hero_down.png`.
- Empty stars: cool grey recessed sockets.
- Pause: big RESUME, one aligned row of four tiles (Music, Sounds with ON/OFF tabs and a red strike
  when off, Controls, Home), the controls (animated gesture tiles) behind the Controls tile.
- Menu: the art track's fighting-stance render, the sun low between him and the title (bloomed,
  soft-edged, strong shafts, a warm horizon band), long rose-gold clouds, no specks or twinkles, a
  new rock (soft granite masses, cracks with lit lips, grain, clefts in shade), cream settings
  button, the title column further right.
- Logo: a slimmer pointed shield with its stick and a fur tuft, dark leather laces (no red-white
  "candy cane"), one long assegai (no symmetric blades reading as ears).
- Settings: the hero at the left where there is room, tan board with raised cream rows, tiles tinted
  by kind, distinct shake and reduce-motion glyphs, bold headers with icons and a gold rule ("Game"
  instead of "More"), the back button nailed to the panel's corner, glossy knobs, ticks over the
  whole slider.
- HUD: glossy hearts vs dark sockets; a lost heart flashes, cracks in two and falls, the plate
  flashes red; the counter counts on pickup, punches and flashes; plates never fade (QA: the
  progress plate vanished for seconds); a soft shade along the top sets the HUD apart from the vine;
  stronger plate shadows. The ×N combo pops beside the hero, warmer and bigger per streak, one font
  size scaled (QA: each size cached ~4 MB); the resume countdown uses the 64 px size scaled 1.5
  (no 96 px atlas).
- Boot: a dusk title card, the studio logo on a cream plaque in the kit's frame, a gold bar filling.
- Start: "Tap to start" on dark glass, a chunkier hand.

## Round 3

Judged round 2: whole game 0/12, ours 6.17 (pause 7.5, game over 7, win 7, settings 7). Critique
`AAA/judge/j02a/critique.md`; QA `AAA/qa/round_3/bugs.md` section 4.

Done:
- Panels: the HUD, the flying Red Bobs and the effects layer are hidden for the frame the picture
  behind is taken from, and stay hidden while the panel is up (some effects draw over everything);
  they come back when it goes (QA UX-4: no "+1", no ghost HUD). Darker scrim (0.6-0.66) and vignette;
  blur at 1/32. Bigger ribbon (54).
- Card: deeper parchment gradient, inner shadow on all four sides, stronger light in its middle; wells
  are a GlossStyle gradient (shade at the top, lit lip below), not a flat tan box.
- Pause: tiles 108 with two-line captions under all four (name; On/Off in green or grey for music and
  sounds, an empty line for the others: aligned, nothing overlapping the tiles); Home in red, Controls
  in gold.
- Results: one sunburst (the stars'); the outer stars tilted, each slams with an overshoot and a glow
  that blooms and breathes; no corner confetti "bristles"; NEW BEST in its own row under the count
  (QA UX-1: it covered the score and left the iPad screen); the defeat hero against the card (one
  group), upright; the way-home bar has milestones every quarter. The art track's renders (menu, win,
  defeat) carry their own light: my hero.gdshader only lights my fallback crops now.
- Menu: the sun right behind Panoramic (backlit), the horizon lower (0.8), the logo a horizontal lockup
  with the whole emblem at the left of the words, the ribbon under the words, a chunky 8-tooth gear
  (`assets/icons/gear-chunky.svg`, not a flower), BEST bigger, darker empty-star sockets.
- Start: a small prompt (44 px on a glass pill, an 84 px hand) at two thirds down the screen.
- Settings: over a scrim and vignette; the hero whole at the left only where there is room (never
  behind the panel, the back button on the panel's corner, clear of him: QA UX-3); four groups (Sound,
  Feel, Game, Help) each a sunken card of rows split by fine lines; group titles in the panel's own
  brown with a coloured icon; slimmer sliders without the dotted ticks; a snail for reduce motion.
- HUD: the moving sheen on the way-home bar removed (QA UX-5: it read as a stray pale rectangle).
- game_screen.gd: `_combo_tag` deleted (QA UX-2: audio's `Fx.streak_pop` is the streak badge).
- Tests: QA's round-3 `tests/run_tests.gd`, `capture.gd`, `perf.gd` copied unchanged (my `_test_ux`
  is the same in them).
- The win's party (confetti, coin shower) runs from a tween owned by the panel, not a SceneTree timer
  lambda that could outlive it (audio: "Lambda capture at index 0 was freed").
- Merge check: base (round 3, with art, env, audio) + my files in a scratch tree: game_screen.gd
  merges clean three-way; results_panel.gd has one conflict at the coin shower (audio's two "New
  (audio)" fireworks lines sit where I removed the corner confetti): resolved by keeping audio's lines.
  On that tree: `run_tests.tscn -- --bot`: 1001 checks, 0 failed, exit 0, the bot home with 3 lives.
  Captures `AAA/ux/round_3/{en,fr}` come from that tree.

## Round 4

Judge j03 and ROUND4.md (ux): a motif tying the panels to this world, a lighter dim, the Resume
gloss, on/off on the tiles, the hero placement on game over and win, the settings back button and
icon colours, the start prompt off the platform, the menu's Best panel.

- Motif: every Card frame carries a band of beadwork top and bottom (Zulu bead colours: white, red,
  blue, black, gold in a mirrored run, on a dark leather strip between the studs); the ribbon's tails
  each hang a short string of three beads (kept short: clear of the content under the ribbon).
- Dim: GamePanel's default scrim is light (0.32 alpha of a warm near-black, vignette 0.55 at the
  corners) over the cheap blurred snapshot, so the level's colour shows through; pause 0.3; the win a
  warm 0.28, the loss a cool 0.42.
- Gloss: JuicyButton's shine is a soft slanted sheen (ten slices fading in and out), no thin stripe;
  GlossStyle's outlined gloss is a faint top light (0.08) and its spark a short soft streak.
- Pause: tiles 116; captions 29 and the state 24 (state line only on Music and Sounds); a lamp on the
  corner of the two switch tiles (green glow when on, a dark socket when off) besides the grey face and
  red slash when off; the panel is full (no empty bottom third).
- Game over: the caught line heavier (36, red with a dark outline and depth); "21%" lives inside the
  way-home bar with a "Way home" label (WAY_HOME, "Vers la maison") so it no longer competes with
  "43 / 84"; the hero beside the card with a little air (overlap -0.05), not across its frame.
- Win: the hero beside the card (overlap 0) so his raised hand is clear of the ribbon; the side stars
  148 (centre 170), with the same slam, glow and tilt; the coin rain behind the card.
- Settings: the back button docked in its own corner slot at the safe-area corner, the panel moved
  clear of it; 78 px under the ribbon before the first group; row icons coloured by meaning (sound
  gold; feel green; language and tutorial sunset; privacy blue; shop sunset; credits ink, no red);
  sliders 250 x 54 with a thicker groove.
- Start: the prompt a gold candy pill with a dark outline under a soft additive glow that pulses, the
  pill breathing; placed at the foot of the screen (above a banner when there is one), off the
  platform.
- Menu: the Best plaque in one type style (BEST 24 over the number 44, both in the panel's browns), a
  bigger bob, roomier margins; the acacia moved behind the plaque (SunsetBackdrop.tree_x, menu 0.37).
- Fixed on the way: a loop variable named like an outer one in Banner._draw was a parse error that
  broke every screen (caught by the capture, fixed before anything else).

### Round 4, QA's audit (qa/round_4/bugs.md, ux)
- UX-1 Resume sheen: the band's light is a smooth gradient (vertex colours following a sine across
  it: clear at both edges, 0.3 in the middle), no flat polygon, no thin second stripe; the first
  sweep comes 1.8 s after the panel opens (the pause picture at 0.6 s has none).
- UX-2 the lesson and the start card ghosting in the pause blur: `_tutorial` and `_start_card` added
  to the hide list in game_screen.gd (pause and results); GamePanel skips entries already freed (a
  finished lesson, the card once tapped). Checked with QA's `lesson_pause` shot.
- UX-3 glyph caches (8 MB per new DisplayText size: a raster font makes a 1024 px glyph page per size
  and per outline size, four per DisplayText): Fredoka is now three static weights (580, 680, 700)
  made from the variable font with the overlaps merged (tools/art/ui_fonts.py: fontTools instancer,
  skia-pathops; then the merge's slivers, the loops at the waist of the "8" and hairline spikes are
  cleaned, or the distance field shows holes), imported as MSDF (range 24, size 48): one glyph cache
  per weight for every size and outline. Ui.title_font() picks the nearest weight. perf.gd, iPhone 15,
  30 s with a pause at 10 s: play 94.5 -> 53.5 MB, paused 86.5 -> 53.5, back on the menu
  102.5 -> 63.5 (budget 80: PASS); no jump at the pause or the countdown any more.
- UX-6 menu: the two thin sticks were the acacia's trunk behind Play and the Best plate (tree_x 0.6):
  the tree is now at 0.37, whole, between him and the column; his feet on the rock (the render's
  ground line, its contact shadow, is at 0.94 of its height, not 0.985).
- UX-7 the banner: `Device.ad_gap()` (40 px when a banner shows) between buttons and the ad on the
  results and pause panels (GamePanel), the menu and settings (SafeArea with the banner).
- UX-4 / UX-5 (round 3 placements) were already reworked this round: the back button in its own
  corner slot, the heroes beside the cards (the defeat with a little air).
- The beadwork first drew three antialiased circles per bead (Compatibility does not batch them:
  paused 1190 draw calls, results 1878). It is now a ten-bead tile (and its mirror) drawn once into an
  ImageTexture at 3x and tiled along each half strip: four textured rects per card, same picture.
- perf.gd, whole level, iPhone 15 (AAA/ux/round_4/perf_iphone15.*): texture menu 61.4, play 53.6,
  paused 53.6, results 56.1, menu again 64.2 MB (QA round 4: 66.2 / 92.9 / 86.9 / 105.5 / 113.7);
  draw calls play 513, paused 446, results 997 (QA: 515 / 390 / 959); worst own work in play 7.3 ms.

## Round 5

Judge j04 (pause 6.5, game over 6) and ROUND5.md (ux): a clean dim, a readable motif, one way to
show state.

- Blur: the snapshot is still taken once at 1/16 (no copy kept, nothing per frame on the CPU), but
  drawn through soft_blur.gdshader: a cubic B-spline sample (four bilinear taps, one draw call), so
  the stretched picture is smooth (no blocks, no stair-stepped edges). Dim: scrim 0.42 (loss 0.48,
  win a warm 0.38), vignette 0.7.
- The card's soft shadow was seven stacked rects (they showed as steps on the dim): one StyleBoxFlat
  shadow now, a smooth falloff in one draw.
- Motif: the beads are gone (they read as dots, the ribbon's strings as fairy lights): a bold Zulu
  band in the frame, red and black diamonds on cream with a dark edge, 22 x 14 px, mirrored from
  the middle, drawn from one tile (one textured rect per half band).
- Pause: one sign of state: off, the tile's icon is dimmed and struck through (no lamp, no "On" text,
  no change of colour); music, sounds and controls in gold, Home in red; tiles 128, Resume 122.
- Game over: the caught line a plain deep-red label (no stroke closing the letters); the count on a
  dark leather well (cream numbers stand out); "Way home" 28 in cream on it; the bar without the
  quarter dots; "New best!" a gold chip, upright, a bigger crown; a side margin of at least 6 % of
  the width around the group; the defeat render placed by its shape (a wide, seated render leans
  on the card's edge; an upright one stands beside it).
- Win: the same dark well (no beige on beige); rhythm: stars, count and stamp tight together, 18 px
  of air before the buttons; the sunburst warm orange in normal blend (additive vanished on cream);
  the stars' heavy ink outline a fine warm rim.
- Settings: one tile colour for every row (orange); group titles in the heaviest weight, 34, a gold
  icon and a rule to the column's edge; "Feel" is "Effects" / "Effets" with a sparkle; the back
  button in the panels' wood (Ui.wood_button); the off switch slate grey with a white cross; a
  lighter scrim (0.3, vignette 0.65) so the sunset and Panoramic fill the left; French "Secousses"
  and "Effets réduits" (one line each).
- Start: a compact prompt in the sky (centred at 38 % of the height, above the platforms and the
  ground): gold words on dark glass with a gold rim (reads on yellow grass and blue sky), the hand
  beside the words, a gentle breath.
- HUD: the portrait through lift.gdshader (gamma 0.7: his face reads); the plates deeper (bevel 7,
  more gloss, a thicker gold rim), hearts 37, the count 34.
- Menu: the gear is a plaque button (Ui.plaque_button), the Best plaque's style and height; "Best"
  30 in the heaviest weight; more air in the stack; the empty star socket darker (contrast on cream).

### Round 5, QA's audit (qa/round_5/bugs.md, ux)
- The blocky blur and the banded card shadow: as above (B-spline stretch; one StyleBoxFlat shadow).
- PERF-1: `GamePanel.hide_when_covered(nodes)`: once the picture behind has faded in, the world's clip
  and the soil band under it are hidden (a still picture stands for them) and come back when the
  panel goes (`uncover()`, called by resume before the fade-out, and on exit). Nothing is hidden
  where no picture was taken (headless tests). game_screen.gd: one call after each panel opens and
  one before the pause fades out. perf.gd, whole level, iPhone 15: draw calls paused 446 -> 273,
  results 997 -> 355; texture memory 64.4 MB at its peak (menu again).
- The way-home bar's quarter studs are gone (the "21%" no longer sits between lone dots).
- The start prompt is at most 55 % of the screen's width (iPad), in the sky, never over him or the
  Red Bobs.

## Round 6

Judge j05 (6.08): "the art style and UI style clash ... candy-glossy match-3 template ... theme the
buttons (hide or wood, beadwork trim, ochre or red)"; every panel identical. ROUND6.md (ux): a kit
that belongs to this world.

- The kit (ui.gd): the tones re-skinned in his world's materials, matte (gloss 0.14, no spark):
  OCHRE (new, the main action: Play, Resume, Play again; candy green gone), amber GOLD, terracotta
  SUNSET, indigo BLUE (the beadwork's), Zulu red CRIMSON, bone WHITE; GREEN only for "on" (switches).
  Every button's ring is carved wood (lit along its top, dark at its foot), not a yellow candy rim.
- Panels (card.gd): a tanned hide body that sinks under the frame (stronger shade along its top,
  sides and foot: it curves), a deep shadow cast on the blurred game (0.78, 46 px, 24 down). Moods
  (Card.set_mood): a win gilded (gold frame, bright trim, warm hide), a loss drained (dark cool wood,
  dull bronze trim, a greyer hide; a cooler, darker veil).
- Win (game_panel.gd): the premium step up: a strong sunburst turning behind the card, a shine
  sweeping the panel every 2.8 s and sparkles twinkling along its gold frame (_Gilding, added light;
  sparkles only without motion). Rays.gd draws all its rays in one triangle array (one draw call,
  a polygon each before).
- Ribbon tails (banner.gd): shaded as folded cloth (dark at the fold, lit at the free end), a light
  line along the top, a crease past the fold.
- Pause: the state on the icon in both states (sounds: a speaker with waves, or with a cross; music:
  the notes, or the notes dimmed and struck); Controls a four-arrow icon (assets/icons/
  arrows-cardinal.svg: the swipes); Resume no longer the panel's full width.
- Empty stars (star_badge.gd): the star in dim desaturated gold (an outline over a pale inlay), not
  a dark hole (menu and results).
- Settings: one tile colour per group again (amber sound, red effects, terracotta game, indigo help)
  for scanning; rows on lighter wells than the tanned panel (contrast); the slider's track marked
  with notches every quarter (it reads as a slider at full volume too); the back button a wooden
  boss set into the panel's top-left corner.
- Game over: the caught line 38; the way-home bar 330 wide; a lying defeat render (very wide) lies
  beside the card, his boot at its edge.
- Start: letter spacing 4.5 ("Tap" no longer fused), a warm glow pulsing behind the pill.
- HUD: the dashed path on the way-home track dark and clear; hearts 39, the count 38.
- Logo: left as it is (no clean way to interlock the words with the shield this round).

### Round 6, QA's audit and the budget
- hero.gdshader: no rim on pixels as dark as the ink (luminance under ~0.1-0.24): the ink line around
  him stays dark, the rim starts inside it (the shader lights the fallback crops and the share card;
  art's renders on the menu are drawn without it).
- The defeat figure, whatever its shape (lying, seated, upright), stays clear of the card's frame and
  band (overlap -0.03 / -0.05).
- Pause shows Music and Sounds' state on the icon while on, too (above).
- Texture memory: the fallback hero crops (hero_stand.png, hero_down.png) were preloaded by the
  results panel (and the menu and share card), held in memory all the time though the art track's
  renders are used: they are loaded only when used now (-3 MB in every phase). The paper grain and
  the Controls icon (128 px) have no mipmaps (never drawn smaller); the win's sparkles use the glow
  texture the panel already holds.
- perf.gd, whole level, iPhone 15, the merged round 5 (a scratch copy) against this tree: texture
  58.2 / 53.7 / 53.7 / 56.2 / 62.7 MB -> 55.1 / 50.7 / 50.7 / 53.2 / 59.7 (menu, play, paused,
  results, menu again); draw calls 108 / 369 / 273 / 350 / 108 -> 102 / 361-371 / 265 / 332-338 / 102.

## Round 7

The blind A/B (round 6 vs 5) preferred round 5's menu and pause clearly: the gold-ochre Play didn't
separate from the gold title and the sunset; Resume gold next to gold-brown tiles, "dull, muddy".
ROUND7.md (ux): put the colour back, keep the round-6 build.

- The kit (ui.gd): round 5's clean, saturated faces back (GREEN the main action again: Play, Resume,
  Play again; GOLD the pause's tiles, brighter; SUNSET, CRIMSON, BLUE), still matte in their carved-
  wood rings. OCHRE removed. GlossStyle: the light on an outlined face is a soft band across its whole
  top, clipped to its curve and fading by the middle (no white capsule, no dot).
- Pause: captions 34 in the heaviest weight, darker; Music and Sounds carry a badge on the tile's
  corner, a green "ON" or a red "OFF" pill (SWITCH_ON/OFF, uppercase), besides the icon itself.
- "New best!": a red rubber stamp (a thick red border and a fine one inside, red crown and letters,
  no fill, a little askew), not a pill in a button's colour (results_panel._rubber_stamp).
- Win: the rays sized to the card (1.45 x its larger side) and centred on it: behind the card only,
  not through him or the fireworks.
- Settings: the back button docked just outside the card's top-left corner, level with its top edge
  (it touches neither the corner nor the band); Help's tiles bone with orange icons (on the warm
  palette, no blue); the group wells near-white with a dark outline (real contrast with the tanned
  panel); the card's margins widened for the thicker frame.
- The band: the frame 24 (was 15), the band 22 tall, diamonds 34 apart, bevelled (four facets lit
  from the upper left and a glint); the studs a little bigger, drawn from one picture (Card._stud_
  texture): one draw call for all of them (five circles each before).
- HUD: the way-home track a solid dark groove with the gold fill (no dashed line, no little flag).
- perf.gd, iPhone 15, the merged round 6 (a scratch copy) against this tree: texture 58.9 / 54.5 /
  54.5 / 56.9 / 63.5 MB -> 58.9 / 53.2 / 53.2 / 55.7 / 62.3 (menu, play, paused, results, menu
  again); draw calls 102 / 363 / 265 / 336 / 102 -> 102 / 333-341 / 211 / 279 / 102.

## Round 8

The blind A/B preferred round 7 on menu, pause, game over and win (the green CTA, the stamp, the
hierarchy); settings slightly lost (small text, crowded rows, the back button floating). ROUND8.md
(ux): small fixes.

- Pause: the ON/OFF badges on the tile's top right corner (clear of the icon and the label).
- The green warmer (leaf: d2e874 -> 68aa30, not neon), the soft top light kept.
- NEW BEST!: a heavier stamp: 40 px letters thickened by an outline in the same ink, a 46 px crown,
  borders 7 and 3, and an ink grain (stamp.gdshader: value noise on the screen position knocks specks
  out of the print; the border, the crown and the words share it through use_parent_material).
- Game over: the percentage rides the fill (inside its tip when the gold is long enough, else just
  past it), never over the empty groove's middle.
- HUD: the empty part of the track marked with faint chevrons towards the house (one draw_multiline);
  the groove one solid shape (one draw call fewer, paying for the chevrons).
- Settings: a wide screen (16:9 and wider) takes three columns (Sound and Game, Effects, Help: four
  rows at most), no hero beside them; a narrower one (iPad) two columns, the hero where there is room.
  Rows 76 tall, their text 30 (was 26), more air between the groups; columns 380 (the Effects column
  430, for the long labels beside the switches). The back button docked inside the panel, on the hide
  at its top left under the frame (the card's top margin, 118, makes room), scaled with the panel:
  neither floating beside it nor over its corner or band.
- The lit stars lose their faint "lighter centre" polygon (three draw calls at the results; the face's
  gradient lights its middle already).
- perf.gd, iPhone 15, the merged round 7 (a scratch copy) against this tree: texture the same in every
  phase (56.0 / 50.4 / 50.4 / 52.9 / 59.4 MB); draw calls max 102 / 336 / 211 / 278 / 102 -> 101 /
  337-340 / 211 / 273 / 101, mean 93.0 / 153.7 / 206.3 / 258.5 / 97.2 -> 92.1 / 153.5 / 206.3 /
  254.6 / 96.2 (the run's maximum moves by a few calls from one run to the next).

## Round 9

After the hero phase (fa1545b). ROUND9.md (ux): the kit's frames heavy and dark, the washed-out Best
card and its "missing" grey star, the flat score slab, the cheap NEW BEST stamp, the triangle strips
as noise, no fail mood, gold on gold on the win and three button hues, the progress bar's grey
chevrons, the stock logo beside its shield, empty bands in the panels. QA's round-9 audit (ux): the
stamp placed for a third of its size, the share card's old hero, two contact shadows under the
results pictures, the menu hero 11 % smaller with a boot in the air, the logo and rock held all run.

- The kit's ring (ui.gd): thin bright brass (BRASS; a copper ring on a gold face) 5 % of the
  button's height instead of 8.5 % of carved wood, a thinner ink outline, a deep soft drop shadow
  (0.5 alpha, 18 px, 13 down). The saturated green CTA and the faces kept. The main button's shine
  adds two glints twinkling on its ring between the sweeps (JuicyButton._Shine._glints).
- HUD (hud.gd): slim plates (dark smoked glass, a 3 px edge instead of 7, a 2 px outline, the brass
  ring); the pause a round gold kit button (no black circle); the way home a groove cut into the
  plate (shade under its upper edge, the plate's lit lip under it), no chevrons, the face 54 units in
  its gold ring over the plate's edges (was 42), a bigger house disc.
- Empty stars (star_badge.gd): a dark sunken star in a bright gold rim (menu and results sockets).
- Menu: the Best plaque warmer parchment in the brass ring, a firm ink outline, a deep shadow, the
  count 50; the gear a gold kit tile; the hero 0.29 of the width at most (was 0.26: the lunge picture
  had shrunk him 11 %); the rock scaled from his stance (ROCK_LEDGE, STANCE) and turned level
  (ROCK_TILT) so both boots stand on its ledge; the logo and the rock loaded with the menu (a
  preload held them, 3 + 7 MB, through the whole run).
- Logo (tools/art/ui_logo.py): the letters drawn for it as polygons, not set in Fredoka: chiselled
  (cut corners), blade-cut ends (the C's mouth, the Z's and L's feet run to a point), the A's apex an
  assegai point above the line; CHAKA over a bigger ZULU on one arch, leaning forward; polished gold
  (a crisp horizon between a bright upper half and a deeper lower one); each letter drawn 4x and
  shrunk, the bevel measured on a mask twice as fine (no specular dots along slanted edges). Locked
  up with the shield: the shield leans behind the C and the Z, taller than both lines, the assegai
  crossing behind it; the menu's ribbon crosses its foot.
- Panels (card.gd): no triangle strip; the frame 18 (was 24); a brass bracket over each corner, its
  arms ending in assegai blades, a red bead in the bend (assets/art/ui/corners.png, baked by
  tools/art/ui_kit.py: brass and iron rows, the top and bottom left corners lit from above, the
  right ones mirrored); middle studs only. A loss mood that differs: slate-stained wood, steel trim,
  iron corners and studs, grey hide; behind it the world drained (soft_blur.gdshader `grey` 0.75) and
  a colder vignette; a SLATE ribbon (new tone); the count groove and the way-home bar in slate.
- Results (results_panel.gd): the count in a groove (InsetStyle, src/ui/inset_style.gd: shade under
  the upper edge, the parchment's lit lip under it); NEW BEST a burst badge (src/ui/burst_badge.gd:
  a gold starburst, a glossy red medallion, the words on two lines fitted to it, a crown, a glint)
  slamming into a place kept for it beside the count (no row of its own: no empty band, no stamp
  pushed right; fixed size, so it is centred where it lands: QA UX-1). The win's ribbon red on the
  gold card; Home and Share both in the quiet blue beside the green Play again (two hues, not three).
  The rendered pictures stand on their own baked shadow (meta `ground`: 0.946 for the leap, 0.935
  for the seated defeat) and GamePanel draws no second one (QA).
- Settings: rows grouped so the columns end level (no empty band under two of them): on a wide
  screen three columns of 3, 3 and 4 rows: Sound and feel (music, sounds, vibration), Game (language,
  screen shake, reduced motion), Help (replay the tutorial, rate, privacy, credits); on a narrower one
  (iPad) round 8's two columns of 5: Sound and Effects, Game and Help. More (ad choices, purchases,
  where they apply, in blue) under the first column.
- Share card: the art track's menu render on its own light (was round 1's crop, QA).
- tests/: base's run_tests.gd, capture.gd and perf.gd (QA's round 9) copied in; QA's stamp check
  (`_results_problems`) now finds the BurstBadge (the stamp shader is gone) and checks it centred in
  the place kept for it and clear of the frame. Removed: src/ui/stamp.gdshader.
- Found by the tests on the way: the win picture, now standing on its own shadow, hung its clear
  foot (the shadow's pool) past the bottom of 16:9 screens: GamePanel counts the picture's part under
  the card's foot in the group it centres and shrinks (`below`). The menu column (a bigger logo) ran a
  few units past the Pixel's safe area: the logo is sized from the Best row's real height, and the
  plaque's two lines sit tighter.
- HUD: the way home's groove is a child drawn once behind the track (`_Groove`), not clipped and
  redrawn every frame with the moving face.
- Tests (`run_tests.tscn -- --bot`): 1053 checks, 0 failed, exit 0 (QA's stamp-and-hero check
  included, 24 cases). Captures `AAA/ux/round_9/{en,fr}/` (iPhone 15 every shot and the share card,
  iPad and 1280 x 720 the layouts), the round's start in `round_9/before/`.
- perf.gd, iPhone 15 (AAA/ux/round_9/perf_iphone15.*), against QA's round-9 audit of the same tree
  before my changes: texture menu 55.5 -> 56.2, play 49.9 -> 38.9, paused 49.9 -> 38.9, results
  52.6 -> 41.7, menu again 58.9 -> 59.5 MB (the logo and the rock no longer held through the run);
  draw calls max 101 / 336 / 211 / 271 -> 111 / 344 / 212 / 282 (glints, corners, the badge); worst
  own work in play 12.5 ms (PASS); the wall-time frames over 16 ms (9) came with a load average of
  5-6 on the Mac (another builder's Blender, Spotlight), their script and render work under 1.5 ms.

Still short: the way home is still an empty groove at the start of a run (a mini-map of the level
would give it content); the HUD plates stay dark glass (some may still read as brown wood); the
French badge's two long words are small; the logo's letters are custom but still a gold bevel; the
brass corners are new and untested with the judges; the defeat figure sits on a shadow, not on
ground; head.png is still round 1's crop (art, QA #3).

## Round 10

Round 9 merged (452aa0e): 6.42 against the references (best so far), preferred to round 8 on 10/10
screens. ROUND10.md (ux): the cold steel defeat and its navy well, the blue side buttons, the badge
against the 84, three same-size stars washed by a white burst over wallpaper rays, the pause's tiny ON
tabs, clip-art corners, thin frame, dead margins, faint sparkle and near-black dim, settings' uneven
columns, valueless sliders and desktop feel, the logo's hidden shield and the empty star as a hole, a
tooltip-like "Tap to start", the HUD's dark empty trough, small portrait, stray ">" and dark pause.

- HUD: the ">" was the cheek's ink outline in head.png (art's round-9 crop) against the bright disc:
  tools/art/ui_art.py crops it again (FACE (282, 238), radius 94) on a dark warm disc, so the outline
  melts into it and the lit face pops. The portrait 62 units (over the plate's edges); the way home a
  sandy trail with his footprints leading to the house (drawn once, the gold covers them), 300 wide;
  the pause in the bright brass ring (Ui.icon_button's new `ring`).
- Defeat (card.gd, results_panel.gd): smoked wood, old bronze trim, dark bronze bosses, a dusty hide
  (not cold steel); the count's well a lighter dusty brown (not a navy hole), the way-home bar in it
  warm; a red ribbon; "what happened" a bold red display line with a fine outline; him bigger (0.66
  of the card) on a dim warm patch of light.
- Win and defeat: Home and Share two quiet bone buttons, 34 apart (no blue beside the green); the NEW
  BEST badge 54, its place as tall as it and 26 wider (air before the 84, inside the groove); the
  middle star 204 against 134, raised; the stars' white glow gone, their flares and own glow softer,
  the stage's sunburst a soft deep orange; behind the win card a breathing warm light instead of the
  hard rays (GamePanel `_halo`); the leaping hero 8 % clear of the card.
- Pause: ON/OFF badges 36 (were 27), drawn over the next tile; Resume as wide as the tiles' row; the
  dim 0.2 with a light vignette (0.45): the scene keeps its colour.
- Panels: the frame 26 (was 18), the trim 6; jewelled bosses on the corners instead of the leaf
  brackets (corners.png re-baked by ui_kit.py: a bevelled ring set with beads, a domed cabochon;
  brass and red, dark bronze and garnet), 56 units; middle studs 22. Panel margins 54/68/54/46.
- Glints (juicy_button.gd): twice the size, a soft halo, long and short arms (Play, Resume, Play
  again).
- Settings: three columns of three rows (Sound and feel; Game; Help: tutorial, rate, privacy), the
  credits behind an info button at the header's right, the back button at its left, in their own row
  (top margin 140); icon tiles bigger (42 px icons), rows 82, text 32; shorter words ("Tutorial",
  "Rate us", "Privacy"); the volume written on each slider ("80%", in the gold or past the knob), the
  quarter notches gone. iPad: two columns of five as before.
- Menu: the empty star a light socket pressed into the plaque (outline, shade inside its upper
  edges, sand at its foot, a lit lip); the logo's shield moved left (only its right edge behind the
  C and the Z) and leaning less (-0.1).
- Start: "Tap to start" in big display letters (70, cream to gold, outline 8, depth 7, a slight arch)
  on a soft dark glow, no pill; a big hand (118) tapping with its ripples beside it; a heartbeat.
- Tests: 1068 checks, 0 failed. Captures AAA/ux/round_10/{en,fr}/ (iPhone 15, iPad, 1280 x 720),
  round's start in round_10/before/.
- perf.gd, iPhone 15 (load average 8 on the Mac): texture 58.0 / 40.3 / 40.3 / 43.0 / 61.1 MB (menu,
  play, paused, results, menu again); draw calls max 117 / 390 / 223 / 269 / 117; worst own work in
  play 8.8 ms (PASS).

### Round 10, QA's audit (qa/round_10/bugs.md)
- Perf: the boot's warm-up drew `Ui.frosted_veil()` and a `SoftShadow`, nothing else used them, and
  each kept the window's back buffer for good (+15 MB on iPhone 15, +29 MB on iPad: iPhone 17 Pro
  Max and iPad 13 over budget in the real boot flow). Deleted: `frosted_veil()`, `frost.gdshader`,
  `SoftShadow` and `soft_shadow.gdshader`; in `fx.gd` (audio's) the warm-up's two pieces drawing
  them, the same lines audio removes. QA's new `tests/perf.gd` (it runs the warm-up) copied in.
- Win: the leaping hero already stands clear (overlap -0.08 this round, was 0.0).
- NEW BEST: its place 44 units wider than the badge (was 26): about twice the air before the 84.
- After these: 1067 checks, 0 failed (one script fewer: soft_shadow.gd). perf.gd with the boot's
  warm-up (QA's): texture memory peaks at 61.1 MB on iPhone 15, iPhone 17 Pro Max and iPad 13 (QA's
  audit: 77.7, 81.7 FAIL, 91.3 FAIL); worst own work in play 8.1-8.7 ms (PASS everywhere).

## Round 11

Round 10 merged (9fa30cf). The blind A/B kept round 10's settings, menu and start; pause, game over
and win lost to round 9. ROUND11.md (ux): the pause's straddling ON badges, its weak dim, the sparkle
noise and a dot grid in the blurred background; the defeat's muddy taupe well, cream side buttons
that read as disabled, an edge-to-edge headline, heavy rivets, sepia; the win's lost radiance,
small pale side stars, marquee bulbs; the HUD's sand track reading as filled.

- The dot grid: the blur is a 1/16 picture of the game stretched over the screen; at 16 px texels the
  GPU's bilinear steps showed as a faint grid (FFT of the judged pause: peaks at a 14-16 px period),
  visible once round 10 lightened the dim. Ui.blurred_snapshot now grows the shrunk picture back 4x
  with bicubic interpolation (once, native), so the stretched texels are 4 px. The pause capture's
  energy at that period halved; what is left is 8-bit quantisation.
- Pause: the dim 0.5 with a 0.6 vignette (round 10: 0.2 / 0.45); ON/OFF badges 24 px, pinned inside
  their own tile's top right corner (5 units in), tiles 136; Resume one small glint (JuicyButton.shine
  takes a glint count and size: the menu's Play keeps its two).
- Game over: the count's well dark (241814 to 443226) so the bright numbers stand out, the way-home
  groove darker in it; Home and Share saturated orange (SUNSET), 92; the headline 38 with 34 units of
  air each side; the world behind drained by half (0.5, was 0.75: no sepia).
- Win: a radiance again: soft shafts of light turning slowly behind the card (Rays `soft`: each ray
  fades to its sides and along its length, wide and narrower in turn, neighbours overlapping: no dark
  stripes) in the breathing warm halo; side stars 172 (were 134), the middle 214, raised; their glow
  and flares warmer and brighter; the frame's twinkling dots (marquee bulbs) gone, the sweep kept;
  Home and Share orange as on game over; Play again one small glint.
- Panels: the corner bosses 40 (were 56), the middle studs 16.
- HUD: the way home's empty part dark again (sand read as already filled), the footprints faint on it.
- Tests: 1076 checks, 0 failed. Captures AAA/ux/round_11/{en,fr}/ (iPhone 15, iPad: game, pause, game
  over, win), the round's start in round_11/before/. perf.gd (load average 5-6): texture peak 61.2 MB
  on iPhone 15 and iPad 13; worst own work in play 12.1 / 10.1 ms (PASS); results draw calls 267.

## Round 12

Round 11 merged (c6c8a39): 6.58 against the references (best), preferred to round 9 on 6/10 (the
pause and settings among them); game over and win still lost to round 9 (slight). ROUND12.md (ux).

- Game over: round 9's preferred well back in spirit: deep cool navy (161c30 to 323e60) with gold
  numbers (fff0a0 to ffb21e) in the warm bronze frame; the way-home bar thick (64, its groove 48, the
  house disc 29) in the navy; the headline cream letters in a red outline, spaced (tracking 3).
- Win and game over: Home and Share gold (apart from the red ribbon and the brown wood); the NEW BEST
  seal's words fitted with air (1.42 of the medallion, not 1.62), lines further apart, a little tilt
  (-0.06, was -0.14).
- Win: a thicker polished gold frame (36, radius 44) with an engraved line round its middle and a
  polish along its top (Card `ornate`); the lit stars carry three sparkles each, twinkling, and rock
  gently about their tilt.
- Pause: compact (tiles 112, gap 26, Resume 104/46, captions 28); the dim 35 % with a 0.5 vignette;
  the blur's highlights tamed (soft_blur.gdshader `tame`: the sun's bloom no longer glares); Controls a
  finger and its swipe (assets/icons/hand-swipe.svg, from Phosphor's hand; arrows-cardinal.svg
  removed); no corner bosses on the pause or settings (Card `bosses`: the jewels are the results').
- Settings: the back and info buttons set on the frame's top edge at its two ends, the groups right
  under the ribbon (top margin 98, was 140: no dead band); group titles section heads (capitals,
  spaced, rust, 26) over 32 px rows; every tile orange; the volume's value 25 px in a taller groove.
- Menu: the logo's gold without its deep-orange lower half and with a gentler bevel (no dark streaks);
  the subtitle on a drawn red ribbon (Banner, no baked stitch) in spaced capitals of Quicksand Bold
  (Banner takes a font and spacing); Play's sweep without the glints; Best a small spaced label over
  the big count, one brown family.
- HUD: the gem on an ink disc, its pickup flash under the plates (over them it washed the gem to a
  pink blob); the icon is assets/art/bob/icon.png when art adds it, else the Red Bob's own picture.

### Round 12, QA's audit (qa/round_12/bugs.md)
- The "bright blocky shapes" behind the game over were the world kept with its outlines by a light
  blur (1/16): the end panels now take their picture at 1/64 (6 halvings), the pause keeps 1/16; every
  snapshot is grown back to a quarter of the screen (texels of 4 px: no grid at any depth).
- The gem's "pink blob": its pickup glows washed it; they are under the plates now, dimmer (above).
- Found on the way: Banner filled each strip of its band as 24 separate polygons (about a hundred
  draw calls per title ribbon); it is one triangle array per strip now. The menu's new subtitle
  (a Banner) had taken the menu from 117 to 214 draw calls; now 122; the pause 220 -> 128.
- Tests: 1080 checks, 0 failed. Captures AAA/ux/round_12/{en,fr}/ (iPhone 15 and iPad: every UI
  screen), the round's start in round_12/before/. perf.gd (load average 3-4): texture peak 61.3 MB on
  iPhone 15 and iPad 13; draw calls menu 122, paused 128 (round 11: 117 / 215), results 210 (301);
  worst own work in play 8.1 / 10.8 ms (PASS).
