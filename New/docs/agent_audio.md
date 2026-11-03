# Audio and game-feel track: log

Brief: `_agents/AAA/BRIEF.md`. Worktree `_agents/wt/audio/New`. Captures and measurements:
`_agents/AAA/audio/round_<n>/`.

## Round 1 (2026-11-02)

### Findings so far
- Run cycle (`Making/RunSide/0001..0017.png`): frame 17 is a copy of frame 1, so the loop is 16 frames.
  Foot contacts (lowest foot reaches the ground, planted foot then travels back): frames 6 and 14
  (1-based), i.e. 0-based 5 and 13 of a 16-frame loop: two steps per loop, 8 frames apart (even).
  If all 17 frames are played the steps come 8 and 9 frames apart (uneven): drop frame 17.
- The current 2-pose run (hero_view.gd, STRIDE 0.16 s per pose): a foot lands at each pose change.

### Next
- measure every sound (tools/audio_report.py), new synth, music, buses, haptics, feel, strips.

### Done (session 1, after the interruption)
- `tools/audio_report.py`: measures every sound (peak, true peak 4x, BS.1770 LUFS checked against
  pyloudnorm within 0.05 dB, M max, DC, clicks, centroid, roll-off, top Hz, < 200 Hz) + spectrograms.
  Baseline in `AAA/audio/round_1/before/`.
- The theme that played (`music_game.ogg`) is `Old/.../chaka.mp3` decoded and re-encoded (same
  130.176 s, correlation 0.987 below 7.5 kHz, +1 dB): a 16 kHz / 32 kb/s MP3, nothing above 5.6 kHz
  (dull), licence unknown. ~111 BPM, centred on A (A, G, E, D strongest: A mixolydian). Replaced by
  original music; to bring the 2017 theme back: `ffmpeg -i ../Old/app/src/main/assets/audio/chaka.mp3
  -c:a libvorbis -q:a 4 assets/audio/music_game.ogg`.
- The 2017 `old_*.wav` (clipping at +0.4 dBTP, DC offset, unknown licence) were never played (filtered
  out) but shipped: deleted. The admob addon's demo track ("Sour by Safe Soundz") is excluded by the
  export filters (addons/admob/assets/*): OK.
- `tools/audio_dsp.py` (shared DSP), `tools/sfx_synth.py` (rewritten: 29 sounds, 60 takes),
  `tools/music_synth.py` (game theme, menu theme, win/lose stingers, savanna ambience).
- Levels: music -16 LUFS integrated, stingers -14/-15, ambience -30, one-shots by their loudest
  400 ms (footstep -31, jump -22, land -19.5, throw -21, ring hit -16.5, KO -13.5, Bob -18, hurt -13.5,
  death -12.5, UI -21..-26). True peak under -1 dBTP everywhere.
- `audio.gd` rewritten (buses Music/Ambience/SFX/UI, master limiter -1 dB, moods, ducking, stingers,
  priorities, tuned takes, footstep()); `haptics.gd` rewritten (patterns per event, cooldown, record).

### The mix (what plays where)
| Bus | What | Level | Notes |
| --- | --- | --- | --- |
| Music | `music_menu.ogg` (-1 dB), `music_game.ogg` (-3 dB) | files -16 LUFS | low-pass (off unless muffled); moods: play 0 dB, paused -9 dB + 900 Hz low-pass, results -5 dB; dips under big sounds (HOW.duck) and recovers 14 dB/s |
| Ambience | `amb_savanna.ogg` | file -30 LUFS | starts with the first theme, never stops; follows the mood at 60 % (paused -5.4 dB) |
| SFX | the game's sounds, the stingers | one-shots by M max | 16 voices; voice limit steals the oldest of the same sound; a full pool gives way only to equal or higher priority |
| UI | buttons, panels, switches, counts, stars, new best | -21..-26 M max | 6 voices; play over the pause |
| Master | everything | | AudioEffectHardLimiter, ceiling -1 dB, release 80 ms; muted in command-line debug runs (kept) |

Settings: Music off mutes Music; Sounds off mutes SFX, UI and Ambience (the stingers are SFX: they
sound with the music off, they are feedback).

### End-of-run flow
- Death (caught): hurt is silent on the last blow; `death` (boom, -12 dB duck), heavy DEATH buzz,
  full shake, music muffled (mood paused). Results after 1.1 s: `Audio.stinger(&"game_over")` (the
  music fades in 0.25 s, the A-minor sting plays 3.4 s), then the menu theme fades in under the panel
  (mood results). Fall: `fall` (whistle down) + FALL buzz, same flow.
- Win: `Audio.stinger(&"win")` at once: its drum roll lands at 0.45 s exactly when the hop lands and the
  doorway bursts (rescue_burst, SUCCESS buzz); the doorway glow and embers swell (Fx.home_glow); the
  menu theme comes back under the results; stars chime A5, C#6, E6 (STAR buzz each), NEW BEST fanfare.
- Pause: panel_open, music muffled and lowered; Resume: panel_close, counts 3-2-1 (A4, C#5, E5:
  drum + woodblock + kalimba, SELECT buzz each) and GO (A major chord) as the world moves again.

### iOS audio session and Android
- Godot 4.7 default `audio/general/ios/session_category` = Ambient (0), `mix_with_others` = false. Ambient
  is what casual top games use: the game is silenced by the Ring/Silent switch and by screen lock, and it
  mixes with the player's own music/podcast instead of stopping it (Ambient always mixes; the
  mix_with_others option only matters for Playback). Nothing to change in project.godot (QA's file);
  if the user ever wants the game to stop other apps' audio, set the category to Solo Ambient.
  Godot does not expose `secondaryAudioShouldBeSilencedHint`, so the game music still plays over the
  player's music when both are on: the Music switch in Settings/pause covers that.
- Android: no silent switch; the game plays on the media stream (volume keys), Godot does not request
  audio focus (it mixes with other apps). The game pauses itself when the app loses focus.

### Haptics (haptics.gd)
| Event | Pattern | Strength |
| --- | --- | --- |
| button tap | TAP 8 ms | 0.3 (light) |
| switch, countdown number, ring hit (not out) | SELECT 6 ms | 0.22 |
| Red Bob | PICKUP 9 ms | 0.38 (at most one per 70 ms: a streak is a tick each) |
| catch the vine | HANG 12 ms | 0.42 |
| hard landing (long drop only) | LAND 18 ms | 0.5 (medium) |
| knock-out | KNOCK 16 + 10 ms | 0.65 then 0.35 |
| hurt | HURT 45/30/22 ms | 1.0, 0.6, 0.35 (heavy, shaking out) |
| caught (death) | DEATH 60/50/40/30 ms | 1.0 .. 0.25 |
| fall | FALL 30/40/26 ms | 0.6 .. 0.18 |
| star | STAR 14 ms | 0.55 |
| win, new best | SUCCESS 12/14/34 ms | 0.45, 0.7, 1.0 (rising, like iOS's success) |
A lighter pattern never cuts into a heavier one still playing; nothing plays when Vibration is off
(or off a phone). Android pulses under 12 ms are lengthened to 12 ms (shorter don't move most motors).

### Footsteps (footsteps.gd) and the 3D run: contract for the art track
- `Footsteps` (added by the game screen) watches HeroView every frame. If HeroView has
  `run_frame() -> float` (the frame of the 3D run showing, 0..16, fractional, -1 when not running), a
  step sounds when the frame passes 5 or 13 (0-based; renders 0006 and 0014: a foot lands). Drop render
  0017 (a copy of 0001): the loop is 16 frames, the steps exactly half a loop apart.
- Until then: a step at each change between the drawn poses run_a and run_b.
- No step in the air, hanging, during a hit-stop or pause (the animation holds); softer against a wall.

### Game feel (game_screen.gd event handlers, fx.gd, confetti.gd)
- `_jolt(trauma, kick)`: shake + a camera kick that springs back (16/s); both off with reduced motion
  (`Fx.calm()`: reads `Save.reduced_motion` when the UX track adds it; red flash halved too).
- Ring: launch flash at the hand (Fx.ring_launch), flight light following the rules' ring
  (Fx.ring_flight: breathing bloom, tapered blue ribbon with a white core, shed sparks), impact: blue
  bloom, short white-hot spark (2 frames), shockwave ring, light shards thrown the way it flew.
  Ring hit: 2-frame hit-stop + 4-unit kick; KO: 6-frame hit-stop, 9-unit kick, shake 0.5, "+1".
- Hurt: 7-frame hit-stop, kick back 10 units, shake 0.7; landing: camera dips 6 units on firm
  landings, shakes on hard ones.
- Red Bobs: no more ghost copies (BobView.flier's two afterimages): Fx.bob_flight flies the ball with
  a warm comet tail pushed by the same tween (no gap), sparks shed; Fx.bob_pop grows with the streak
  (ring, glow, rays from the 3rd, red to gold).
- Home: Fx.home_glow (warm light swelling and breathing, long rays, embers rising 2.6 s).
- Win results: Fx.coin_shower (34 tumbling gold coins with glints, 90 confetti, twinkles) with the
  confetti burst; Confetti gained a COIN shape (rim, sunken field, embossed star).

### QA round 1 (AU-1..3) and compatibility
- AU-1: old_*.wav deleted. AU-2: `music_menu.ogg` exists now. AU-3: throw raised to -19.5 and the swipe
  step to -23 (M max); footsteps stay the quietest on purpose (-31: six a second at the current run).
- `Audio.SFX` keeps QA's shape (name -> list of WAV names); how each plays is in `Audio.HOW`; the Ogg
  stingers are in `Audio.STINGERS` (played by `stinger()`, not `play_sfx`). QA's `_test_sounds` logic
  checked against it: no unknown, no missing, both themes.
- Copied unchanged from QA: tests/capture.gd, strip.gd, bot_replay.gd (+ .uid); build/qa replay cache.

### Results (round 1)
- Tests: 436 checks, 0 failed, exit 0; with --bot: home, 3 lives, 82 Bobs (438 checks, exit 0).
- Every sound: true peak <= -1.1 dBTP, no clicks, DC 0, loops seamless (seam 0.05-0.31x of a normal
  step), lengths exact. Shipped audio 2.71 MB (QOA WAVs 0.72 MB + Ogg 1.99 MB), was 1.37 MB.
- Perf (QA's perf.tscn, iPhone 15 size, 40 s, a loaded machine): own work worst 13.4 ms (< 16),
  draw calls mean 396 (base 331), nodes mean 1015 (base 944), wall p99 16.7 ms (other builders' load:
  the untouched menu ran 2-4x slower than in QA's baseline too). Trails draw as one polygon + one line.

### Next
- When the art track ships the 3D run: check `run_frame()` and listen for the steps on frames 5/13.
- When the UX track adds reduced motion: confirm the name (`Save.reduced_motion`), the test switches on.
- Listen on a phone (I could only measure): the bass/kick balance on a speaker, the ambience level.
- Maybe: a short slow-motion on the last blow; per-surface footsteps (grass / rock / hut yard).

## Round 2 (2026-11-03): critique AAA/judge/m01, QA AAA/qa/round_2/bugs.md

### Done so far
- Clicks: `audio_dsp.place` now fades a layer where the output buffer cuts it (the 0.75 s line in every
  pickup, count 0.6, hurt 0.7, toggles 0.3 came from layers longer than their buffer). `audio_report`
  checks every file inside, not only its ends: `cuts()` (Hilbert envelope falling >14 dB in 2 ms from a
  held level and staying down) and `spikes()` (an isolated >5 kHz burst with 1-4 kHz content, not
  followed by a louder sound); validated on the round-1 files (finds the critic's cuts). Grit grains
  placed on purpose would show too: `sfx_synth.py DIR --no-grains` renders the set without them and
  `audio_report.py ... --grains-free=DIR` drops what is gone without them. Round 2 set: no cut anywhere.
- SFX v3 (`tools/sfx_synth.py`): three-layer hits (transient 1.5-6 kHz, body 300 Hz-1.5 kHz, sweetener),
  `audio_dsp.phone()` (lows saturated into harmonics, sub cut at 110 Hz), loudness ladder (integrated):
  death -14.7 > hurt -16.4 > KO -17.0 > ring hit -18.5 > streak -19 > pickup -21 > throw -22 > land -23 >
  jump -24 > step -27 > footstep -30; peaks <= -3 dBTP; a fast compressor (PUNCH) makes the hits dense
  enough to reach their loudness under the ceiling. Lengths: pickup 0.25 s, KO 0.5, hurt 0.4, death 0.85,
  fall 0.9 (no whistle). 4-6 takes of the frequent sounds (runtime ±1.2 st, ±1.5 dB). New: streak chord,
  heart break, last-heart heartbeat, ceiling bump, climb grab, mantle, vine creak, door threshold,
  coin tinkles. "How it should sound" is the 4th field of each recipe (for the table).
- Music: game theme 48 bars (97.6 s: + a C section in B minor on marimba, a finale A3 with choir), 2.5 dB
  dip at 3 kHz; drive layer `music_game_drive.ogg` (djembe 16ths, agogo, shaker, toms; -22 LUFS, same
  length, started in the same step as the theme, faded in by `Audio.set_intensity` on the home stretch).
- `audio.gd`: UX's volume sliders own the Music and SFX faders (Prefs.apply_volumes); the mood and dips
  now go through an AudioEffectAmplify on Music; UI and Ambience send into SFX. Game theme at -7 dB
  (-23 LUFS), menu -1. Dips 4-6 dB held 0.3 s (hurt 5, KO 4, death 6, fall 6).
- `fx.gd`: IMPACTS small/medium/fatal (hit-stop 3/4/5 frames, shake 3/4.5/6.5 units, shards 5/8/12,
  knock 16/30/46), `impact_burst` (2-frame white core, then only a thin ring, directional shards),
  `knock()/knock_offset()/advance_knocks()` (out in 30 % of the time, back after), the ring's flight a
  3-frame motion smear (no beam, no core line), Bob fliers capped at 6 on a bezier that accelerates into
  the counter (counted at pickup: no more bob_launched), `streak_pop` ("×N" at the pickup, white to
  red by tier), coins in front of the card, confetti in the scene's palette as petals and beads
  (Confetti PETAL, BEAD), the home light and burst anchored to the doorway, timer lambdas replaced by
  tweens owned by their node (QA AU-1).
- `feel.gd` (new): applies the knocks to the hero and bandit views after they are placed, climb grab and
  mantle sounds, vine creaks while hanging, the drive intensity.
- `footsteps.gd`: reads the 3D hero's run clock (`_run`) while its anim is run or throw, until art adds
  run_frame() (QA AU-2/ART-1).
- `game_screen.gd`: `_impact()`, hurt/KO/ring hit/fatal presets, hero knock on hurt, bandit knock on a
  ring hit, heart break + last-heart warning, bump, door, streak chord and pop; KO_STOP, HURT_STOP,
  CAUGHT_STOP, RING_STOP removed (replaced by Fx.IMPACTS); `_combo_tag` no longer called (UX's).
- Tests: 901 checks, 2 failed (UX French overflow, known).
- Later in round 2: `bandit_view.gd` FLASH_TIME -> Fx.FLASH_TIME (one line, art's file: the bandit was white
  6-8 frames); the ring's own bloom down to 40 px (RingView has its halo); one streak badge at a time; the
  home light spills along the ground from the doorway (flat pool + a softer glow in the doorway), the
  rescue burst's flash softer; coins fall over the card (added to the panel's root by Fx.coin_shower).
- Click check final: on the round-1 files it finds exactly the critic's cuts (pickups 0.749, count 0.6,
  hurt 0.699, toggles 0.299, death 0.779); on round 2: none (grains filtered by the --no-grains render;
  a rise into a spike is a drum's attack, not a cut).
- Real game probe (scratch, 240 frames of bot play): footsteps 13, throw 19, bob 6, streak 1, grab 1,
  mantle 1, KO 2, land 2: footsteps fire on the new hero through `_run`.
- Outputs: AAA/audio/round_2/{sound (sounds.md with the "how it should sound" column), strips, captures}.

### Asks for other tracks (round 2)
- art: `HeroView.run_frame()` (Footsteps reads `_run` meanwhile); decay the bandit's flash in real time
  (`delta`, not the world clock) so it stays 2 frames inside a hit-stop; RingView: no core line in its
  streak, launch from his hand (offset from the hand to the rules' spawn, gone in 4 frames: the rules spawn
  it at his hips, x + 29); the hero's mercy pulse at full alpha (the critic: no 40 % ghost); apply
  `Fx.knock_offset(&"hero")` / `Fx.knock_offset(bandit)` in the views if you prefer (then Feel.APPLY_KNOCKS
  = false).
- ux: `_combo_tag` (the HUD ×N chip) is no longer called: the streak pops at the pickup (Fx.streak_pop);
  keep or delete. The coin shower adds its coins over the card by itself.
- gameplay/env: the death staging (centre, push in, hold on him) and the hero entering the door are theirs.
- qa: `_test_contracts` could accept Footsteps' `_run` fallback until art adds run_frame().
- Camera kicks also respect UX's screen-shake switch (Prefs.shake), not only reduced motion.
- Tests (no bot): 904 checks, 2 failed (UX's French iPad overflow from the merge, not audio).
- Perf (QA's perf.tscn copied in and removed, iPhone 15 size, 40 s): own work worst 9.6 ms, wall p99
  7.4 ms (PASS); draw calls mean 240 (QA's merged run: 198), max 552 (572); script p99 0.57 ms; texture
  memory 124 MB FAIL (env/art).

## Round 3 (2026-11-03): AAA/judge/j02a (ours 6.17)
- Win: the corner bursts were confetti_burst (stick smears) -> `Fx.fireworks` (FireworkShow: three shells rise
  steeply from each lower corner, burst high into a white-gold bloom and 36 additive sparks with short
  tapered trails that fall, fade and crackle; one `sfx_firework` per burst). Drawn behind him and the card
  (the sky): UX's `results_panel.gd` two lines, marked New (audio).
- Home: `confetti_burst` throws big glossy streamers (new STREAMER shape: a satin double curl with a gloss
  band) and ribbons in three sizes (2.0 / 2.9 / 3.9) in a curated palette (gold, sunset red and coral,
  cream, his indigo) plus petals and beads; they tumble (scaleX flip). Confetti's motion blur is now a
  faint stretched copy of the piece along its path (no more thin stick lines: the "broom bristles").
- Ring: drawn leaving his hand (`Fx.RING_HAND` = (-22, -44) units from the rules' spawn, measured on a
  strip; `Fx.launch_offset` closes it in 0.1 s, cubic, most of it in the first frames), applied by Feel to
  RingView and by my RingFlight; the launch flash at his hand; a crisp impact: + a 4-frame metal glint.
- Vocal efforts: skipped. A synthesized voice (voiced grunt) can't be judged convincing without listening;
  the unvoiced breath layers already in hurt and death stay. A recorded voice (the user, 3-4 takes each of
  jump, hurt, death, bandit KO) would be the real fix.
- Tests: 966 checks, 1 failed (QA's known headless boot texture race); a "Lambda capture at index 0 was
  freed" error comes from timer lambdas in env's world_view.gd:193/281 and UX's results_panel.gd:175 (not
  audio's): same fix as fx.gd's (a tween owned by the node).
- After the art track's note: the red of a blow is ~3 frames (1 held, 3 fading) on `Fx.edge_texture()`
  (red only in the outer ring of the screen; the game screen's `_flash` uses it). Art now launches the
  ring from his hand in RingView, so my launch offset (Feel, RING_HAND, launch_offset) and my launch flash
  are gone (they would double it); my flight light follows RingView's drawn position instead of the
  rules' (it stays on the ring whatever RingView does). Home streamers only (short ribbons read as
  letters).
- Final: 967 checks, 0 failed, exit 0; --bot: home, 3 lives, 82 Red Bobs, 3 stars (exit 0).
- Streamers twist across their width (Confetti: turning edge-on along their length made them "Z" glyphs).
- QA AU-1 (major, texture memory): `Fx.streak_pop` drew the "×N" at a new font size per streak step, each
  size caching its glyph pages (+6 MB a step). Now one size (`STREAK_SIZE`, outlines 28/12) grown by the
  node's scale; the "+1" and "×N" glyphs are rasterised as the level loads (`Fx.warm_glyphs`, one line in
  game_screen.enter) and at boot (`Fx.warm_up`), so nothing allocates during play.
  perf.tscn, iPhone 15, 12 s, --jump-mb=0.5 (before = my fx.gd with the old badge put back):
  before: 8 jumps of 6.0 MB at the first streak's pickups (0.12-1.0 s), run 112.6 MB, menu after 122.6 MB;
  after: no jump in play (load +12 MB: the two badges' glyphs), run 76.6 MB (budget 80), menu after
  86.6 MB; frames: worst own work 9.3 ms, wall p99 8.5 ms. The rest over 80 on the menu includes those
  12 MB of glyph pages: an MSDF title font (ux) would serve every size from one atlas.

## Round 4 (2026-11-03): AAA/judge/j03 (effects)
- Fireworks (`Fx.fireworks` / FireworkShow): all soft additive light, no lines: one colour per shell
  (FIREWORK_HUES: gold, rose, teal, orange, violet), a wide bloom of that colour round a white-hot flash,
  40 sparks drawn as glowing comets (a head and four fading glows behind, white-hot then coloured),
  glittering as they die; shells a little lower so the bursts sit in the sky beside the card.
- Confetti off the parchment: `Fx.coin_shower` rains coins, petals and beads only in the margins left and
  right of the card (it reads the panel's `card` rect) and `Confetti.avoid` hides any piece, glint or
  sparkle that drifts over the card (they pass behind it). Glints capped at 22 px (no lens-flare stars).
- Home streamers: wider (54 x 15), shaded across their width (lit edge, glossy band, darker underside,
  darker where the curl turns away), two fading afterimages when fast (motion blur), never edge-on thinner
  than 55 %; sizes 1.5 / 2.1 / 2.8 (the closer home camera of env made the old sizes bury the hut).
- "+1": white letters filled gold (shine_text), a thick dark brown stroke, a warm gold rim, a drop
  shadow, drawn 1.3x; pops 0 -> 1.5 -> 1 in about six frames, rises 80 units, holds, shrinks away. It
  shares the font size and outlines with the streak's "×N" (BADGE_OUTLINES, PLUS_SIZE): one set of glyphs.
- Home light (`Fx.home_glow`): no fill in the doorway (the "flat orange arch"); a broad faint warm halo
  round the doorway, a flat pool on the ground, both breathing, softer longer rays, embers. Satin and
  ribbons no longer glint (the "blue-white lens-flare star" was a streamer's glint).
- Perf (perf.tscn, iPhone 15, 40 s, merged d289a14's fx/confetti vs mine): texture memory load 77.6 ->
  71.6 MB, run 94.9 -> 89.0, paused 86.9 -> 81.0, menu after 103.0 -> 97.0 (-6 MB: one set of badge
  glyphs); worst own frame 8.0 vs 8.2 ms (one 16 ms render reading did not repeat).
- Tests: 1013 checks, 0 failed, exit 0; --bot: home, 3 lives, 82 Red Bobs, 3 stars. No lambda error.

## Round 4b (QA round 4: AU-1 white ring face, AU-2 win reveal)
- The "white ring face": `_fliers.z_index = 11` (game_screen.gd, over view.fx at 10, under OVERLAY_Z 20;
  UX still hides it under panels); the flier wears the row's face for its first frames (then joy) and pops
  to 1.2x, not 1.35x; the "×N" badge is z 2 inside view.fx (12) so the fliers don't cover it.
- The win reveal (perf.tscn full level, results phase, iPhone 15): draw calls max 959 (QA, round 3 merge) ->
  595 (my round 4) -> 468 now; objects ~10 000 -> 2 690 -> 2 673. A scratch probe (removed) showed the
  results screen costs 427 draw calls with no effect at all (the blurred game behind and the panel); the
  effects now add at most ~40 on top (they added ~175): `Confetti` drew each sparkle's halo and star
  alternately (two textures: two draw calls per sparkle) and its motion blur in piece order (a texture
  change per piece). Both now go texture by texture and batch. Play max 515 -> 390.
- Tests: 1012/1012 twice; one --bot run had 1 intermittent failure of a camera check ("stepped right",
  env's camera, phone_1280x720 frame 39) that did not repeat.

## Round 5 (2026-11-03): AAA/judge/j04 (merged round 4: 0/12, 5.62)
- "+1": cream-white (PLUS_FILL) on a thick solid dark stroke (both outline passes dark) and a drop shadow,
  one font size. The gold gloss shader (shine_text) is no longer used on it: UX made the title font MSDF
  (Fredoka), and a custom shader that samples TEXTURE reads the raw distance field (the "+1" came out
  grey with a grey stroke). Godot's own text drawing decodes MSDF; shine_material() removed from fx.gd
  (shine_text.gdshader stays: env's warm-up list loads it). With MSDF every size and outline shares one
  atlas: the badges' single font size no longer matters for memory, kept anyway.
- Win fireworks: peony bursts (speeds spread through the sphere, random angles: no tidy rings or hearts),
  each spark a wide halo of its colour + a 4-glow trail + a white-hot core; each burst leaves a haze of its
  colour in the sky for 1.3 s (BLOOM_TIME), so a still shows glow at any moment of the reveal.
- Home confetti: small two-tone paper strips (new STRIP shape 22 x 8; TWO_TONE back colours: gold/cream,
  red/peach, indigo/sky, cream/gold, coral/cream, deep gold/bronze) flipping about their length (light and
  dark faces alternate), 28/12/5 in three sizes, 6 gold sequins, 24 sparkles; no streamers or petals.
- Home light: the halo in the air over him is gone (it washed out his silhouette); a flat pool on the
  ground and rays fanning from above the doorway (alpha 0.14) remain.
- Perf (perf.tscn, iPhone 15, full level; a9e1ff0's fx/confetti vs mine): texture memory equal (run 53.3,
  results 56.0, menu after 64.1 MB); results draw calls max 516 -> 515; objects 2 758 -> 2 930; play draw
  calls max 429 -> 431 (noise); worst own frame of play 9.0 ms (PASS).
- Tests: 1017 checks, 0 failed, exit 0; --bot: home, 3 lives, 82 Red Bobs, 3 stars.
