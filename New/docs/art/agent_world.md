# World art pass (agent "world")

Goal: an AAA look for everything around the hero (sky, parallax, ground, water, props, HOME, light
grade, menu backdrop), consistent with the hero sheet (painted anime, warm key light from the upper
left, warm rim, cool violet shade), calmer than the playfield. Only how things look changes: no
physics, numbers, hitboxes or level data were touched.

All art comes from re-runnable scripts in `tools/art/` (numpy + scipy + Pillow, free, local).

## Before

`build/caps_before/pixel_2400x1080__game.png`, `build/caps_before/pixel_2400x1080__menu.png`:
flat gradient sky, sine hills, stick acacias drawn per frame; the ground a 4 x 4 tiled soil block
with a thin grass line; the 2017 stump and bushes; a plain menu sunset.

## Done so far

### 1. Painting helpers: `tools/art/paint.py` (new)
Tileable value noise / fbm, blurs that wrap in x, supersampled polygon/ellipse masks, Lambert light
from a height field (lit from the upper left), colour ramps, dithered RGBA saving with colour bled
under transparent pixels (no dark halos, no banding).

### 2. Ground: `tools/art/terrain.py` (rewritten), `src/game/terrain_view.gd` + `src/game/terrain.gdshader` (new)
- The TileMapLayer terrain is replaced by `TerrainView`: the ground is drawn once, in level units,
  into chunks of 16 columns (one canvas item per layer per chunk, so the renderer batches it and
  culls what is off screen).
- Soil body: `terrain_shape.png` (per open-side mask x 4 variants: rounded corners, wobbly edges,
  outline, rim, edge light; 4 px extruded borders against filtering seams) + `terrain.gdshader`,
  which paints with `soil.png` (laterite with strata, pebbles, stones) and `rock.png` (sandstone
  blocks, anisotropic Voronoi, bevelled) sampled in level space: no tiling grid, no seams. With depth
  under the open top it darkens, cools to violet and turns to sandstone; a contact shadow sits
  under the grass. The depth per cell comes from a small R8 texture read with texelFetch (the draw
  colour arrived at half its value in the Compatibility renderer, which made seams).
- Grass: `grass_cap.png` strip in level x (blades 18 units above the surface, a lush scalloped band
  with painted blade strokes, a dark cool underside); `grass_ends.png` rounded ends that wrap the
  corners and drape down open sides, fading into the next cell's strip; `roots.png` under inner
  tops; `underside.png` (roots + shade) under floating ledges; `tufts.png` (grass, flowers, seed
  heads) on some tops with `sway.gdshader`; `front_grass.png` blades drawn above the actors so feet
  stand in the grass. Walls with an open top that are not walkable (SIDE) get no grass.
- `GameArt` no longer builds the old terrain TileSet; `terrain.png` was removed.

### 3. Sky and parallax: `tools/art/savanna.py`, `tools/art/trees.py` (new), `src/game/savanna_view.gd` (rewritten), `src/game/haze.gdshader` (new)
- Baked layers instead of per-frame shapes: `sky.png` (warm blue to lavender, peach and gold, brush
  marks, thin lit cirrus, stratus near the horizon), `sun.png` (additive glow) in the upper left,
  where the hero's key light comes from, `rays.png` (soft god rays fanning to the lower right,
  breathing), `cloud_1..4.png` (cumulus with gold rims and lavender undersides), `far_mesas.png`
  (escarpments and kopjes with relief light and aerial perspective), `far_hills.png` and
  `mid_hills.png` (rolling relief with tiny acacias and bushes), `near_grass.png` (tall golden
  grass), `haze.png` bands between layers, `mote.png` (pollen in the light), `bird.png` (4 frames).
- Trees as individual sprites placed by hash at three depths with a haze shader per depth
  (`tree_acacia_1..3.png`, `tree_baobab_1..2.png`, `tree_info.json` anchors): acacias with forked
  trunks and crowns of separate flat pads painted clump by clump; baobabs with a folded bottle trunk,
  massive crooked limbs and sparse leaves.
- `SavannaView` draws each layer as one canvas item (repeat on only for the strips), additive sun,
  rays and motes. Same interface as before (`scroll`, `view_left`, `view_width`).

### 4. Water: `src/game/water.gdshader` (rewritten), `world_view.gd` `_add_water`, `_watch_splashes`
- Turquoise shallows to deep blue, the warm sky reflected under the surface, a wandering foam line,
  a fine web of caustics, sun glitter streaks, twinkling sparkles, darker water and foam at the banks.
- The pool reaches 8 units under each bank (no sky between water and soil).
- A splash (droplets and a flat ripple ring) when Panoramic or a bandit drops through the surface.

### 5. Light grade: `src/game/light_grade.gdshader` (rewritten), `world_view.gd` `_add_grade`
- One rectangle over the world, under the effects and the HUD: a warm wash from the sun corner, an
  oval cool-violet vignette, a little shade under the HUD row and along the bottom.

### 6. Props: `tools/art/props.py`, `src/game/prop_view.gd` (new)
- Every 2017 decoration id is mapped to a new prop (`PropView.DECOR`): the trees (5/6/17/18 and
  29/30/41/42) become painted acacias, the trunk (8) a broken stump, mushrooms (7, 19) aloes, the
  boulder (9/10) a sandstone rock, the bushes in the pit under the tower (31-34, 43-46) reeds and a
  shrub. Signs (20, 21) and the crate (22, walkable, drawn as ground) add nothing and are dropped.
- Long grass runs get a few low rocks, shrubs and aloes (fixed hash), set 5 units into the grass and
  a shade darker so they read as standing back from the path; none under Red Bobs or near HOME.
- The 2017 tile set is no longer loaded (`GameArt.tile_set` removed).

### 7. HOME: `tools/art/home.py`, `src/game/home_view.gd` (new)
- A Zulu homestead over the last screen: a beehive hut (iQukwane) of tiered shaggy thatch bound with
  rope, a straw finial, a low arched doorway framed with bent saplings and the hearth glowing
  inside; a palisade bound with withies, a granary on stilts, smaller huts further right (wide
  screens), a carved signpost reading HOME with a border of triangles and a cord of beads, a clay
  pot (ukhamba) by the door, smoke rising from the apex.
- The doorway's right edge is at play x 786: when Panoramic gets home (centre past 790) he stands
  in it; the hut wall right of the doorway and a shade deepening inside it are drawn above him
  (`HomeView.front`), with the flickering firelight (additive) on him.
- The old levelEnd1/2 and HOME sign art are no longer loaded (removed from `GameArt`).

### 8. Menu and settings backdrop: `src/ui/sunset_backdrop.gd` (rewritten), `savanna.py` sunset set
- Dusk sky (indigo, magenta, orange, gold) with lit stratus, a big low sun setting behind dusky
  escarpments with soft rays fanning up, plum hills with tiny acacias, acacia and baobab
  silhouettes (one frames the left edge), backlit swaying grass, glowing pollen, birds. Title and
  buttons on the calm left, the portrait on the right.

### 9. Polish pass 1
- Grass caps warmer (savanna yellow-green), god rays softer, the tall background grass in clumps
  with seed stalks and green shrubs (`savanna.py near_grass`).
- Clouds repainted puff by puff with the trees' clump painter: lit domes, gold rims, lavender bases.
- Aloe rebuilt (spotted lance leaves shaded along the midrib, a raceme of red-orange tubes); stump
  rebuilt (grooved bark, splintered pale top, gripping roots).
- The vine along the top is now painted (`tools/art/vine.py`, `vine.png`: a twisted liana sagging
  between knots, rounded hanging leaves, tendrils; 3 variants); `vine_view.gd` draws the spans.
- Fixed: flipped background trees were drawn one width to the right (a negative-width rect keeps
  its x in Godot).

### 10. Tools
- `tools/art/world_preview.gd/.tscn`: renders the world alone at any scroll (e.g. 24640 for HOME)
  without a bot run.
- Tests: `197 checks, 0 failed`.

## Captures
- `build/caps/pixel_2400x1080__game.png`, `build/caps/pixel_2400x1080__menu.png`: current state.
- `build/world/world_24640_2400x1080.png`: HOME (Panoramic in the doorway).

## Files touched so far
tools/art/paint.py (new), tools/art/terrain.py, tools/art/savanna.py (new, replaces the cloud part of
clouds.py), tools/art/trees.py (new), src/game/terrain_view.gd (new), src/game/terrain.gdshader
(new), src/game/haze.gdshader (new), src/game/savanna_view.gd, src/game/light_grade.gdshader,
src/game/game_art.gd (terrain TileSet removed), src/game/world_view.gd (`_add_ground`, front grass
above the actors, wider water), assets/art/world/* (regenerated).

## Still to do
Water shader and splash, props replacing the 2017 decorations, HOME homestead, light grade wired in,
menu backdrop, terrain polish (warmer grass, stronger edge light), tests, captures on all devices.
