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
