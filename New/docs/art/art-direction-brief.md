# Chaka Zulu 2.0: art direction brief

The contract every asset is checked against (create-game-assets skill). The approved visual target is
the user's own hero art; everything else is made to sit next to it.

## Game frame

- Player fantasy: Panoramic, a young savanna warrior with a hand-tipped staff and glowing rings, runs home
  across the savanna at golden hour, outsmarting masked raiders and hanging from vines over chasms.
- Core verbs: run (auto-scroll), jump, hang from the top vine, let go, throw a ring, collect Red Bobs.
- Engine and renderer: Godot 4.7.2, GDScript, Compatibility (GLES3) renderer on every platform.
- Target platforms: Android phones and tablets (target SDK 36), iPhone and iPad (iOS 16+), landscape.
- Camera/view/facing: orthographic 2D side view; the hero faces right; enemies come from the right facing left.
- Native viewport and common display scale: design 960 x 640, `canvas_items` + `keep_height` (always 640
  units tall, 853 to 1490 units wide); 1 unit = 1.69 px on a 1080 px-tall phone, 3.2 px on an iPad 13".
- Typical asset size on screen: hero 150 units tall (head to boots), bandit 92, Red Bob 32, ring 26,
  terrain cell 32, trees 90 to 260, HUD row 46.

## Visual system

- Shape language: organic and rounded for the world (pads, domes, thatch), sharp angles kept for danger
  (raider club, crest, hood ears) and for the hero's wild hair; the interface is rounded candy with a
  Zulu shield and beadwork trim.
- Silhouette priorities: hero > bandits > Red Bobs > walkable grass tops > walls > background. Grass tops
  must read as walkable, sheer walls as blocking, water as deadly; nothing in the background may look like
  a platform or an enemy.
- Value structure: playfield mid-to-dark with bright accents; sky and far layers light and low contrast;
  three value bands per layer, the darkest values reserved for the actors' outlines.
- Palette roles and exact swatches:
  - Hero anchors (never change): skin `#583818` / `#785828`, red scarf `#f83808`, armour `#284878` /
    `#4888a8`, white-silver fringe, chrome boots, ring glow `#3fa2ff`.
  - Danger: raider violet `#5a3a8a` family, teal crest, amber eyes; nothing else in the game is violet
    and saturated at once.
  - Reward: Red Bob `#e82808` with warm highlights; gold `#ffd36b` for stars and counts.
  - World: savanna grass `#a8c808` to `#6e9a1e`, laterite soil `#9a5228`, sandstone, sky `#78b8f8` to
    peach and gold at the horizon; shadows cool violet, never grey.
  - Interface: sunset `#f2662e`, deep brown ink `#3a1206`, cream, green for the main action.
- Materials and surface cues: painted soft shading (no hard cel bands), skin with warm rim, cloth with
  folds, metal (armour, boots) with crisp specular, foliage in clumps of lit pads, soil with strata and
  pebbles, thatch in shaggy tiers, water clear turquoise to deep blue.
- Edge/line treatment: actors keep a thin dark warm outline (as in the hero art) plus a warm rim on the
  right; the world has soft painterly edges with an outline only on the playable terrain edge.
- Lighting direction and contrast: one key light, upper left, warm (golden hour); warm rim on the right;
  cool violet ambient in shade; light grade warm wash from the sun corner, soft vignette.
- Detail density and focal hierarchy: detail concentrated on the actors and the path edge; background
  simplified by distance (aerial perspective), no texture noise behind the hero's head height band.
- Motion character: snappy and elastic for the hero (squash and stretch, quick lean), heavy and jolting
  for raiders, floaty and joyful for Red Bobs, slow and breathing for the world (sway, drift).
- Explicit exclusions: no stock or third-party art, no photographic textures, no ethnic caricature, no
  text baked into art except the HOME sign and the logo, no paid generators (fal.ai is out of credits;
  every asset comes from a free local re-runnable script or from the user's own generated images).

## Technical contract

- Asset dimensions/aspect: textures at 2x their drawn size in units (sharp on 1080 px phones); world
  strips at 1x to 2x; every PNG at most 4096 px on a side (mobile GPU limit).
- Alpha/background: actors, props and FX on transparent PNG with colour bled under transparent pixels
  (no halos); backgrounds opaque; verified with `asset_report.py --require-alpha`.
- Grid/tile/frame size: terrain cell 32 units, drawn by `TerrainView` from shape masks; animation frames
  on one shared canvas per character.
- Anchor/pivot/baseline: bottom-centre at the boots for ground poses (`hero.json` anchors), centre for
  airborne poses, staff tip for hanging; props bottom-centre at the ground line.
- Filtering/mipmaps/compression: linear filtering project-wide; mipmaps on sprites drawn smaller than
  their pixels (`tools/import_settings.py`); VRAM compression ETC2/ASTC for opaque large layers.
- Color space: sRGB everywhere.
- Texture budget: art resident during a run at most 55 MB (measured 48 MB on 2026-10-30: the menu-only
  sunset layers and portrait are not kept, the soft rays are stored at half size); all texture memory
  (`Performance.RENDER_TEXTURE_MEM_USED`) at most 128 MB on a 2400 x 1080 phone (measured 97 MB, of
  which about 50 MB are screen-sized buffers: the frame, and the copies read by the frosted pause veil
  and the soft UI shadows). No frame over 16 ms on desktop for setup work that runs during play.
- Naming and folders: `assets/art/<family>/<name>.png`; generators in `tools/art/<family>.py`; raw or
  large sources in `tools/art/gen/` (git-ignored); manifest `docs/art/asset-manifest.json`.

## Visual target

- Approved seed/reference paths: `tools/art/ref/user/hero_sheet.png`, `tools/art/ref/user/hero_portrait.jpg`
  (the user generated these and approved them on 2026-10-30; the hand-made samples in
  `docs/art/samples/` were rejected and are never reused).
- Required do/don't examples: do match the hero's soft painted shading and warm rim; don't use flat vector
  fills with uniform black strokes, don't add grey shadows, don't let background trees out-contrast actors.
- Native-scale gameplay capture: `build/final_assets/` (every screen on a 2400 x 1080 phone and a 13" iPad,
  2026-10-30); before/after board `docs/art/before_after.png` (`tools/art/before_after.py`).
- Approval owner/date: the user (Haiz Studio), 2026-10-30 for the hero; world and interface accepted by the
  user as "already fine" on 2026-10-30.
