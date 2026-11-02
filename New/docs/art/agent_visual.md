# Visual track: AAA pass (agent "visual")

Copy: `_agents/visual/New`. Rounds: `_agents/visual/rounds/round_<n>/` (pixel_2400x1080).
Nothing committed. No paid generator.

## Round 0 (baseline)

Captured `_agents/visual/rounds/round_0/` (menu, start, game, climb, hang, home, pause, gameover,
win, settings) from the copy as handed over.

Judge round 0: 2 wins of 11, mean 5.5 (refs 7-8.5). Critique: `_agents/rounds/r0/critique.md` (32 flaws).
Order of work: level screens (water, rock pillars, hero scale/readability, foreground depth, Red Bobs,
clouds, HUD kit, dirt band, vine, hang shot, trees), then results, home, menu.

## Round 1 (in progress)

- `tools/art/world_preview.gd`: draws on demand (force_draw) instead of waiting for frames; a covered
  window on macOS made it take minutes, now 5 s.
- `tools/art/savanna.py`: sky re-graded from milky lavender to deep cerulean -> cream -> gold;
  aerial-perspective haze high up is cool blue (was rosy). Backup of the round-0 world art in the
  scratchpad only.
- Sky/layers (`savanna.py`): far mesas blue-violet, far hills cool, mid hills olive-gold, near grass
  darker at its foot; clouds repainted as soft volumetric cumulus (density field + relief light,
  no outline), stored at half size and drawn 2x (`savanna_view.gd` CLOUD_SCALE); sun warmer;
  rays and haze bands lighter; tree haze per depth (cool far, warm near).
- Foreground (`savanna.py fg_grass`, `SavannaView.front`, added above the actors by WorldView):
  dark out-of-focus tussocks along the bottom edge, scrolling 1.35x, kept low and gappy.
- Terrain: `rock.png` repainted as sandstone beds (lit ledges, undercuts, joints that die out as
  cracks); `terrain.gdshader` form shading from the depth texture's new G/B channels (cells to the
  open side left/right): warm sun side, cool violet shade side, bounce light on narrow pillars;
  `terrain_view.gd` foot shade where walls rise from tops (short occlusion sun side, longer cast
  shadow on the far side); walls' outline wobble 2.2 -> 3.6 units; soil darker, patchy, more and
  bigger stones (lighter pebbles: no more black specks); grass cap and roots strips 2048 px wide
  (no visible repeat), roots clustered.
- Water (`water.gdshader`): depth ramp over the visible 60 units, a bright surface sheet, a dark
  line under it, light shafts, glitter, froth piled against the banks.
- Hero (`hero_view.gd`): drawn 1.25x (DRAW_SCALE; the rules' box is unchanged), outline 2.4 px at
  0.92, rim 0.6, bigger darker ground shadow, scarf scaled; shrinks as he walks into the hut.
- Red Bobs (`bob_view.gd`): warm additive halo breathing behind each, bigger float, sway; fliers
  leave at once and shrink as they go (no clump at the pickup).
- HUD (`hud.gd`): one plate family (glazed dark wood GlossStyle, outlined, bevelled); thicker
  progress groove with gold fill, the face in a gold ring, the house on a gold disc; bigger counter,
  a gap before a matching pause plate. Combo tag is a gold chip (`game_screen._combo_tag`).
- Vine (`vine.py`, `vine_view.gd`): thicker rope, deeper sag, bigger leaf clusters, blossoms,
  5 variants picked and mirrored by hash.
- Results/pause: `Card` (framed, lit top edge, inner shadow, soft light, beadwork as big diamonds),
  `Card.well()` sunken area; `StarBadge` (new, src/ui) shiny stars with bright sockets, `StarRow`
  uses it; `_show_results` (stars over a slow sunburst, big Red Bob number in a well, two small
  stats, round Home/Share beside a big Play again, HUD faded, hero portrait or a gloating bandit
  beside the card), `_panel` places from the card's real size, veil darker; `Fx.badge_burst`
  (under the chip), `Fx.confetti_cannons` (from the bottom corners, three sizes) also on the win in
  the world; `frost.gdshader` 5 taps of mip 4 (no blocky grid).
- HOME (`home.py`, `home_view.gd`): thatch tiers deeper with straw hanging over each, rope rings
  with twists and a light rope net, mended golden straw, shaggier silhouette, cooler shade side;
  doorway interior (ribs lit by the fire, floor, hearth stones and flames, pots in silhouette);
  fence stakes vary in height, width, lean and age; sign 1.35x, cream letters on an oiled board;
  `home_hut_low.png` (new) replaces the scaled copy at the back right; a soft ground shadow.
- Menu: logo rebuilt (`logo.py`): the shield, whole and tilted, crossed with an assegai, stands at the
  title's left as an emblem (it used to poke out behind the letters like an egg); ribbon under the
  words; PLAY 390 x 108 (font 56) breathing harder; best plaque, BEST label, stars and settings
  bigger; portrait graded into the sunset (`src/ui/portrait.gdshader`, new: warm rim on the sun
  side, plum in the shadows, chest fading into the grass), bigger halo, placed nearer the edge.
- Trees: each background tree drawn 0.78-1.33x as wide (hash): no two crowns alike.
- `_panel` fits narrow screens (state.k) on top of the pop animation (state.u).
- Measured (temporary scene, deleted): texture memory 82.9 MB in a run, 98.1 MB paused (cap 128);
  62.5 MB over an empty 2400 x 1080 viewport (fonts and buffers included); world art +3.1 MB over
  round 0 (48 -> about 51 MB of the 55 MB art budget); 2.8 ms per drawn frame on desktop.
- Manifest: 78 assets, 0 with problems. Tests: 275 checks, 0 failed.
- Display text gets a small default tracking (3 % of its size, `Ui.display_text`): heavy outlines
  fused "Tap" into one shape.
- Fixes after looking at the round 1 check shots (`rounds/wip4/`): the results art stands behind
  the card's edge (the portrait covered the round Home button); Red Bob fliers shrink from the start
  and trail a warm streak (mid-flight they read as stray Bobs); `hero_screen_rect` measured up from
  the feet with the drawn scale (the HUD didn't fade over his head at the top of a jump).
- The wip1 shots were blank: a new class_name (StarBadge) needs an import pass before a capture
  (`Godot --headless --path . --import` updates the class cache).

- After the first three-device capture (`rounds/wip5/`): the results card ran off the iPad's right
  edge (a CenterContainer grows to its child, so the fit never shrank it): `_panel` now places the
  card by hand in the middle of the safe area and scales it to fit; a lost run gets no confetti
  (only the burst behind NEW BEST: corner poppers on a loss read as rubble); "Tap to start" gets
  4 px tracking; fliers fly at 0.8x; the menu portrait is narrower on tablets (it covered "ZULU").
- Tests: 275 checks, 0 failed; with `--bot`: 276 checks, 0 failed, the bot gets home (state 2,
  3 lives, 70 Red Bobs).

## Round 1 final capture

`_agents/visual/rounds/round_1/` (pixel_2400x1080, phone_1280x720, ipad13_2752x2064).
Files to judge (pixel_2400x1080): menu, start, game, climb, hang, home, pause, gameover, win,
settings. Layout checks: the same on phone_1280x720 and ipad13_2752x2064 (all fit).
Earlier checks, not for judging: `rounds/wip1..wip5`.

## Still short of the references (next)

1. Panoramic still runs on two painted poses (ASSET_REQUESTS #5/#6 for a real cycle).
2. The hang shot: the rules hang him at the very top, so he and his rings sit in the HUD band
   (the plates fade under him); no floor under the poles at that moment (level design).
3. Rock strata on narrow pillars read a little like stacked bricks; the soil band is still one
   material (no grass overhang breaking its top edge, no roots hanging over the water).
4. Mid-distance acacias are still flat-crowned sprites (variety now comes from width only).
5. Bandit is code-drawn (vector-like next to the painted hero); the results' bandit is that sprite.
6. The empty star socket is visible but muted; the NEW BEST burst could be warmer.

## Round 2 (judge r1: 5 wins of 14; level screens lost all 8 pairs)

Copy synced to the merged state (gameplay builder's pools in every pit, rules, sounds). Work so far:
- HOME (item 14): the figure poking out of the hut roof was Panoramic: the hut's `front` (the
  doorway's darkness and the wall right of it) was always drawn over him, so jumping past the door
  greyed him and his raised hand showed over the thatch. `front` now shows only once he is home
  (`HomeView.welcome`); firelight spills on the ground before the doorway (additive, flickering).
- Hero (2): outline 3.2 px at 0.95, sun-side rim (towards the upper left) 0.9 over 5 px, a soft warm
  additive backlight behind him.
- Rings (5): `tools/art/ring.py` (new) paints a lit torus (`assets/art/fx/ring.png`); RingView draws
  it 40 units across (was 26), stronger halo, softer streak, no ghost rings.
- Red Bobs (4, 7): hot specular point, tighter brighter glow rim, golden-angle phase and own pace per
  Bob (no row moves as one), 28 units (gaps in packed groups); fliers trail two afterimages instead
  of the white light ribbon that read as a vector jump trail.
- HUD (6): the empty part of the groove is a pale dusty path, quarter marks are gold pips; the
  combo badge is pinned over the counter's lower right corner (`Hud.counter_rect()`); the vine sits
  7 units higher with fewer leaf clusters.
- Shorelines (1, 13): `grass_drape.png` (terrain.py) hangs over every open side of a grass top
  (tufted lip on pillars, grass over the water at banks); reeds in the water at each bank and pole
  foot (`PropView._bank_reeds`); `water_front.gdshader` (new) tints banks and poles under the
  surface with foam lapping round them (`WorldView._add_water_front`).
- Pillars (3, 11): `rock_edges.png` angular bevelled chunks jutting from every wall's open sides
  below its top two cells, bigger towards the foot (poles taper); deeper falloff (deep_tint);
  `underside.png` hanging earth lumps (ledge thickness varies, overlapping the cell edge); sparser
  roots; rock beds more varied.
- Background (8, 9): mesas taller (strip 300 px), eroded tops, chimneys, banded cliffs, stronger
  light and shade; two more acacia shapes; god rays and the horizon band fainter.
- HOME art (16, 17): `home_hut_small.png` is now a rondavel (mud walls, conical thatch); stronger
  sunset rim and bolder straw on the main hut; sign with planks, nails, rope and outlined letters;
  fence heights and gaps vary more; confetti bursts from the doorway (`Fx.confetti_burst`, new;
  the corner cannons are gone).
- Results (23-29, in progress): wood planks in the card body, quieter gold/cream beadwork, carved
  star sockets, glowing and twinkling stars, NEW BEST burst without rays, win confetti from behind
  the stars after they land.
- Results (23-29): the character stands beside the card, clear of it (the portrait no longer
  sliced by the panel edge), the bandit on a soft ground shadow; the portrait graded and fading out
  at the chest (`portrait.gdshader` fade_to_clear); veil lighter and cooler (the blurred game stays
  colourful); Home and Share are both sunset round buttons 78 px (one family with the green Play
  again); stats line bigger (icons 36, labels 30, values 38); sunburst brighter; NEW BEST burst is
  a glow and a ring only (the rays looked like an artifact).
- Hits (32, 33): `Fx.hit_spark` is now a painted soft burst (`Fx.impact_texture()`, made once at
  boot in `warm_up`: ragged tapering rays, white-hot core, additive) plus speed lines, instead of a
  hard white vector star; the effects layer has z_index 10 so the KO flash is over the Red Bobs.
- Fall (34): `Fx.splash` (new): a water column rising and collapsing, small and big drops, two
  ripple rings, foam spreading on the surface; used for falling in and for springing out.
- Menu (18-22): logo with a sunset-gold fill (pale gold to orange to rose at the foot) and a band
  of beadwork through ZULU; emblem with thick ink lines like the letters, set closer to them;
  subtitle ribbon without the dotted bead border (a gold stitched line), text 31; best plaque and
  settings on the HUD's wood plate (Play is the one bright button); the radial sunburst behind him
  is a faint breath of light; dark backlit grass in front of his chest; the portrait's grade and
  rim stronger.
- HOME: rings still in flight fade once he is home (the judge's "stray ring" in the yard).
- Mesas: taller than round 1 but scaled back after a look (they dominated), top light softer.
- Tests: 310 checks, 0 failed (merged suite). Manifest rebuilt.
- After looking at the first round 2 shots (`rounds/wip6/`): the roof figure was still there. It
  is Panoramic on the win: he walked 64 units past the doorway's right edge, behind the hut's front
  wall, and at 1.25x he is taller than the door, so his raised staff hand showed over the arch (a
  quicker fade still left a ghost in mid-fade frames, `rounds/wip7/`). He no longer walks in: he
  stops before the glowing doorway and hops with his staff raised (the hanging pose by its boots),
  landing in a squash, whole and readable; the hut's front stays hidden, the fire's glow moved
  behind him. Strip: scratchpad strip_win.png. Ledges: the soil's shape loses its bottom outline
  where earth hangs under it, so the two run on as one. The hanging earth
  under ledges had a lit seam and blotchy pebbles (two stacked planks): no lit top, starts in the
  soil's colour and fades in under it. Rock chunks vary cell by cell (they repeated up a pole). The
  ×N chip hangs from the counter's corner (it covered the count). Flier afterimages fainter.
- Measured (temporary scene, deleted): 86.3 MB in a run, 101.5 MB paused (cap 128); 3.2 ms per
  drawn frame on desktop. Manifest: 83 assets, 0 problems. Tests: 310 checks, 0 failed.

## Round 2 final capture

`_agents/visual/rounds/round_2/` (pixel_2400x1080). Earlier checks: `rounds/wip6`, `rounds/wip7`.
Tests: 310 checks, 0 failed; with `--bot`: 311, 0 failed, home (state 2) with 80 Red Bobs, 3 lives.
Manifest: 83 assets, 0 problems.
