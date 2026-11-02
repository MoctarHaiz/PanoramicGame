# Art to generate (same style as the hero sheet)

Attach `tools/art/ref/user/hero_sheet.png` as the style reference to every request. Rules for every image:

- Plain flat light grey background (#D0D0D0).
- No ground shadow, no text, no frames or panels.
- Generous space between items.

Save the results in `~/Downloads` with the names given; I cut them out and fit them to the game.

Most important first.

## 1. `bandit_sheet.png`: the enemy

```
Same art style as the attached hero sheet. A side-scroller enemy: a masked raider, lean and agile, teal spiky hair, a red scarf covering the lower face, a black and yellow armoured outfit, white wrist wraps, holding a short wooden club. Side view, facing LEFT. One row of 8 frames of a running cycle, same size in every frame, evenly spaced, then one frame recoiling from a hit and one frame falling backwards knocked out. Plain flat light grey background, no shadows, no text.
```

## 2. `sky_far.png`, `hills_mid.png` and `trees_near.png`: the level background

Done in code (no longer needed): `tools/art/savanna.py` and `tools/art/trees.py` paint the sky, the
layers and the trees.

Three separate images, each very wide (3:1) and seamless left to right.

```
Same painted anime style as the attached hero sheet. A seamless, horizontally tileable side-scrolling background layer for a platform game set in the African savanna at golden hour. LAYER: [sky_far: warm sky with a big soft sun and a few clouds, no ground | hills_mid: distant blue-purple hills and flat-topped mountains on a transparent-looking plain light grey background, only the silhouettes and their bottom | trees_near: acacia trees, tall golden grass and a few rocks along the bottom third, the top two thirds plain light grey]. Wide 3:1 format, no characters, no text.
```

## 3. `red_bob.png`: the collectible

```
Same style as the attached hero sheet. A collectible for a platform game: the "Red Bob", a glossy red ball with a cute smiling face (two big eyes, a happy smile), soft highlight on top. Four versions in a row: normal, squashed a little, stretched a little, winking. Plain flat light grey background, no shadow, no text.
```

## 4. `home.png`: the end of the level

Done in code (no longer needed): `tools/art/home.py` paints a Zulu homestead with a beehive hut.

```
Same style as the attached hero sheet. Side view: a cosy house carved into a huge old tree trunk, a round wooden door with warm light inside, a wooden signpost reading HOME in front, two rabbits waving next to it, a few mushrooms at the roots. Plain flat light grey background, no ground, no shadow.
```

## 5. `panoramic_run.png`: a smooth running cycle for the hero

```
Same hero as the attached sheet (same face, red scarf, blue armoured arm, white and silver fringe skirt, chrome boots, white staff ending in a hand). Side view, facing RIGHT, full body. One row of 8 frames of a running cycle holding the staff, same size and same height in every frame, evenly spaced. Plain flat light grey background, no shadows, no text.
```

## 6. `panoramic_moves.png`: more poses for the hero

```
Same hero as the attached sheet, side view, facing RIGHT, full body, same size in every frame. One row of: 1) hanging from his staff raised straight above his head, the staff's hand hooked on something above, legs dangling; 2) the same hanging pose with legs swinging forward; 3) jump take-off; 4) jump peak with knees tucked; 5) falling; 6) throwing a glowing blue ring forward; 7) hurt, recoiling backwards; 8) victory pose, staff raised. Plain flat light grey background, no shadows, no text.
```

## 7. `icon.png` and `key_art.png`: store art

```
Same hero as the attached sheet. App icon: Panoramic's head and shoulders, three-quarter view, determined smile, red scarf, blue shoulder armour, on a warm sunset orange background with a soft glow behind his head. Square 1024x1024, no text, no border, no rounded corners.
```

```
Same hero as the attached sheet. Wide key art 2:1: Panoramic leaping across the African savanna at sunset, staff raised, a glowing blue ring in his other hand, acacia trees and a big sun behind him. He is on the right half; the left half is calmer sky for a title. No text.
```

## Made in code (nothing to generate)

Ground tiles, water, the vine at the top, the ring, sparkles, dust and the interface are drawn in code.
