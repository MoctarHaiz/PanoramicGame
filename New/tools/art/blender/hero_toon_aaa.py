"""The AAA hero's cel shading (ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend): one material per region
(m["toon"] = skin, face, hair, fur, armour_blue, armour_silver, scarf, belt, eye, hand), each rebuilt here
for a light mode ("day": the level; "sunset": the interface pictures, the sun behind him).

Form shading, not a sticker (hero pass 2, after the blind judges: "one flat mid-brown with thin orange marker
edges", "a white sticker outline", "torn paper", "plastic blue", "a black blob"):
- four bands with a soft terminator: a deep cool core, a cool shade, a warm half-tone, a warm light;
- a THICK HOT RIM only where the sun reaches an edge (the lit side's silhouette): no light line on the
  shadow side's edges, so in play the dark ink meets the lit form with no pale fringe;
- a cool bounce on the front faces that are in shade (their centres, never their edges);
- a soft sheen on the sun side (skin, scarf, belt), crisp broken glints on the armour;
- occlusion between the locks and under the fur;
- the hair in strand groups: a deep blue-black, the locks parted by occlusion, a broken highlight band;
- the fur: strands, darker roots and underside, a stepped edge (displacement) and a warm cream;
- the boots and gloves: the user's blue, a little warmer and less saturated, matte, scuffed.

build(m, mode) rebuilds the material's nodes (idempotent: the base colour and normal pictures are kept).
A material may carry its own flat albedo (m["flat"], linear) and rim (m["rim"], m["rim_k"]): the bandit wears
the hero's regions in his own colours (hero_render.py --character bandit).
"""
import bpy

# band multipliers (of the albedo; hair: absolute colours): deep, shade, mid, lit
BANDS = {
    "day": {
        "skin": ((0.33, 0.25, 0.4), (0.5, 0.37, 0.5), (0.88, 0.74, 0.67), (1.1, 0.99, 0.87)),
        "face": ((0.5, 0.38, 0.5), (0.62, 0.48, 0.56), (0.9, 0.77, 0.7), (1.1, 0.99, 0.88)),
        "hand": ((0.4, 0.3, 0.44), (0.55, 0.42, 0.52), (0.88, 0.75, 0.68), (1.08, 0.98, 0.87)),
        "hair": ((0.005, 0.006, 0.011), (0.011, 0.013, 0.022), (0.026, 0.029, 0.046), (0.062, 0.064, 0.085)),
        "fur": ((0.42, 0.36, 0.42), (0.6, 0.54, 0.56), (0.9, 0.84, 0.76), (1.04, 0.99, 0.9)),
        "armour_blue": ((0.3, 0.27, 0.42), (0.48, 0.44, 0.58), (0.84, 0.8, 0.78), (1.04, 1.0, 0.93)),
        "armour_silver": ((0.28, 0.26, 0.36), (0.46, 0.44, 0.54), (0.82, 0.8, 0.79), (1.06, 1.03, 0.97)),
        "scarf": ((0.38, 0.2, 0.32), (0.55, 0.32, 0.42), (0.88, 0.7, 0.66), (1.08, 0.96, 0.86)),
        "belt": ((0.36, 0.26, 0.36), (0.52, 0.4, 0.46), (0.86, 0.74, 0.68), (1.08, 0.98, 0.88)),
        "eye": ((0.85, 0.85, 0.9), (0.9, 0.9, 0.95), (1.0, 1.0, 1.0), (1.04, 1.04, 1.04)),
        "chakram": ((0.18, 0.2, 0.3), (0.34, 0.38, 0.5), (0.75, 0.8, 0.88), (1.1, 1.1, 1.1)),
    },
    "sunset": {
        "skin": ((0.22, 0.14, 0.17), (0.35, 0.23, 0.24), (0.7, 0.48, 0.38), (1.18, 0.86, 0.6)),
        "face": ((0.46, 0.32, 0.38), (0.56, 0.4, 0.44), (0.82, 0.62, 0.54), (1.15, 0.9, 0.68)),
        "hand": ((0.32, 0.21, 0.29), (0.46, 0.31, 0.37), (0.75, 0.54, 0.47), (1.12, 0.86, 0.63)),
        "hair": ((0.004, 0.004, 0.008), (0.009, 0.009, 0.015), (0.02, 0.019, 0.03), (0.05, 0.046, 0.06)),
        "fur": ((0.34, 0.25, 0.3), (0.5, 0.38, 0.41), (0.8, 0.64, 0.57), (1.08, 0.9, 0.72)),
        "armour_blue": ((0.24, 0.19, 0.32), (0.4, 0.32, 0.45), (0.74, 0.62, 0.62), (1.06, 0.9, 0.78)),
        "armour_silver": ((0.22, 0.18, 0.27), (0.4, 0.33, 0.42), (0.74, 0.64, 0.63), (1.1, 0.94, 0.82)),
        "scarf": ((0.32, 0.15, 0.24), (0.48, 0.25, 0.32), (0.78, 0.52, 0.46), (1.12, 0.86, 0.66)),
        "belt": ((0.3, 0.19, 0.27), (0.45, 0.3, 0.36), (0.75, 0.55, 0.5), (1.1, 0.88, 0.68)),
        "eye": ((0.8, 0.78, 0.84), (0.86, 0.84, 0.9), (0.98, 0.96, 0.98), (1.04, 1.0, 1.0)),
        "chakram": ((0.14, 0.13, 0.22), (0.3, 0.27, 0.4), (0.7, 0.62, 0.7), (1.15, 0.95, 0.8)),
    },
}
## (round 16, "traffic-cone / tangerine orange, not a skin tone"; "abs drawn as lines: a plastic toy") one clean brown
## (linear; sRGB (0.52, 0.31, 0.2)) in three bands: a cool plum shade, a mid, a warm orange light, soft between
SKIN = (0.237, 0.0757, 0.0331)  ## (key art k4: round 16's warm brown again; k2's cooler one "lit by a different light")  ## (key art k2: deeper and cooler, sRGB (0.45, 0.27, 0.19), "the same orange as the sky")
SKIN_BANDS = {"day": ((0.62, 0.45, 0.62), (0.9, 0.82, 0.8), (1.16, 1.0, 0.82)),
              "sunset": ((0.56, 0.47, 0.66), (1.0, 0.96, 0.92), (1.28, 1.22, 1.13))}  ## (k10: three bands, a soft cool
## shade, his base and a bright lit plane where the key faces him: "darker and muddier than his surroundings")  ## (k9, the user: "professional, AAA": a clean
## key on his true colours: a near-white light, a soft, slightly cool shade, no sunset tint)  ## (k9 first, "no cool shade on the camera side:
## pasted on": a mauve shade, the light warm; k7 ((0.62, 0.37, 0.4), (1.14, 0.9, 0.7)))  ## (k7: a warm red-brown shade, "olive,
## muddy": was (0.56, 0.4, 0.56))  ## (key art k2: two tones, a plum shade
## and a cool-warm light, "two tones with clean, designed shadow shapes")
SKIN_STOPS = (0.0, 0.07, 0.15, 0.27, 0.36, 1.0)
SKIN_REGIONS = ("skin", "hand", "face")
# (pass 4) "bold": two clear cel bands with a crisp terminator, the rim on the back edges (screen space, the
# sun's side strongest), no bounce or sheen on the skin, flat red scarf, deeper blue armour: the UI's toy-like
# language ("semi-realistic anatomy with fine muscle rendering ... pasted in from another game")
import os as _os
KEY_SKIN_STOPS = (0.0, 0.26, 0.295, 0.62, 0.65, 1.0)  ## (key art k25, "flat and sticker-like", "no core shadow on the
## ribcage or under the pecs": a third of the skin in shade, a warm lit plane on the arms, flank and thigh fronts) the
## pictures' skin (torso, arms, legs): three tones, one crisp terminator and a crisp lit edge over clean designed forms
## (hero_render.py key_skin_normals()); k24 (0.13, 0.165, 0.745, 0.775) read flat; k11-k23 (0.0, 0.06, 0.24, 0.74, 0.8, 1.0)
## a soft core-shadow blend over the sculpt's bumps ("fuzzy brush grain"). The face and hands keep k11's.
BOLD = _os.environ.get("HERO_TOON", "bold") == "bold"
BOLD_BANDS = {  # shade, lit (albedo multipliers; hair: absolute)
    "day": {"skin": ((0.6, 0.47, 0.5), (1.08, 0.98, 0.88)), "face": ((0.72, 0.58, 0.58), (1.1, 1.0, 0.9)),
            "hand": ((0.64, 0.5, 0.52), (1.08, 0.98, 0.88)), "hair": ((0.004, 0.0035, 0.004), (0.016, 0.012, 0.011)),
            "fur": ((0.5, 0.43, 0.42), (0.74, 0.68, 0.58)), "armour_blue": ((0.5, 0.48, 0.62), (0.9, 0.9, 0.92)),
            "armour_silver": ((0.4, 0.38, 0.42), (0.64, 0.6, 0.54)), "scarf": ((0.34, 0.16, 0.26), (1.05, 0.98, 0.92)),
            "belt": ((0.55, 0.42, 0.45), (1.05, 0.96, 0.88)), "eye": ((0.9, 0.9, 0.95), (1.03, 1.03, 1.03)),
            "chakram": ((0.4, 0.45, 0.58), (1.1, 1.1, 1.1))},
    "sunset": {"skin": ((0.55, 0.4, 0.42), (1.08, 0.9, 0.76)), "face": ((0.68, 0.52, 0.52), (1.12, 0.95, 0.82)),
               "hand": ((0.58, 0.43, 0.45), (1.08, 0.9, 0.76)), "hair": ((0.004, 0.0035, 0.004), (0.018, 0.012, 0.011)),
               "fur": ((0.6, 0.5, 0.52), (1.0, 0.9, 0.8)), "armour_blue": ((0.45, 0.4, 0.55), (0.95, 0.9, 0.92)),
               "armour_silver": ((0.45, 0.42, 0.5), (0.86, 0.8, 0.76)), "scarf": ((0.5, 0.32, 0.38), (1.05, 0.92, 0.82)),
               "belt": ((0.5, 0.36, 0.4), (1.05, 0.9, 0.8)), "eye": ((0.88, 0.86, 0.9), (1.02, 1.0, 1.0)),
               "chakram": ((0.36, 0.38, 0.52), (1.1, 1.05, 1.0))},
}
## (round 11, "in play his dark orange skin shares the value of the rock and the haze: a brown smudge") the lit band
## of his skin lighter and warmer in the level's light (linear multipliers on top of BOLD_BANDS; the shade kept, so
## the light-shade split widens); the interface pictures and the bandit (flat colours) unchanged
_LIFT = float(_os.environ.get("HERO_LIT_LIFT", "1.0"))  ## (round 16: 1.3 -> 1.0, "traffic-cone orange")
DAY_LIT = {r: (_LIFT * 1.04, _LIFT, _LIFT * 0.9) for r in ("skin", "face", "hand")}
BOLD_STOPS = (0.0, 0.155, 0.185, 1.0)
## (round 12, "the key art below the UI in finish: skin blotchy, orange-to-brown patches with hard muddy transitions;
## the face small, dark, blank; the ring a flat grey donut") the interface pictures (sunset): the skin and hands one
## clean colour (the albedo's mean; the face keeps its painted features), a warm shade (not a muddy purple-brown) and
## a slightly softer step, the face lit, the steel ring dark at its core and bright on its polish
UI_FLAT = {"skin": SKIN, "hand": SKIN, "face": SKIN, "fur": (0.78, 0.7, 0.56), "belt": (0.12, 0.011, 0.012),
           "armour_blue": (0.025, 0.075, 0.3), "armour_silver": (0.36, 0.33, 0.29)}  ## (k2: the blue desaturated, "royal-blue plastic stickers")  ## (round 14: flat, "mottled noise on the boots")  ## (linear: the albedo picture's mean skin, sRGB (0.588, 0.325, 0.189))
UI_BANDS = {"skin": ((0.62, 0.4, 0.33), (1.12, 0.93, 0.78)), "hand": ((0.64, 0.42, 0.35), (1.12, 0.93, 0.78)),
            "face": ((0.84, 0.66, 0.58), (1.16, 0.98, 0.85)), "chakram": ((0.12, 0.15, 0.3), (1.3, 1.3, 1.36)),
            "fur": ((0.6, 0.5, 0.5), (0.98, 0.92, 0.82))}  ## (k7: a clean warm white; round 13: the loincloth warm white, "flat grey")
## (round 15, "the white loincloth and the white/blue boots are the brightest shapes: they pull the eye to the crotch
## and the feet; keep the brightest values on the face and chest") the whites a warm off-white, a value lower
DAY_PURPLE = (1.556, 0.717, 2.185)  ## the savanna's evening purple (sRGB (0.6, 0.42, 0.7)) at a luminance of 1 (linear)
DAY_PURPLE_K = 0.35  ## how far his shade turns to it in the level (round 14)
UI_MAGENTA = (2.46, 0.61, 0.54)  ## the sunset's warm rose (sRGB (0.85, 0.45, 0.42)) at a luminance of 1 (linear)
CLEAN_LIT = (1.16, 1.12, 1.08)  ## (k10: a brighter key; k9 (1.08, 1.04, 1.0))  ## (key art k9, the user: "light him cleanly": one near-white key, a soft cool shade, the
CLEAN_SHADE = (0.55, 0.47, 0.66)  ## costume's own colours, no sunset wash)
CLEAN_REGIONS = ("fur", "armour_blue", "armour_silver", "scarf", "belt")
UI_MAGENTA_K = 0.0  ## (k9, the user: no sunset colour in his shade)  ## (round 14: "a touch of sunset magenta in his shadows"; round 15, "the sun right behind him, yet no
## warm tint": the sky's warmth in his shade)
UI_FACE_LIFT = 0.22
ARMOUR_GLINT = 0.0  ## (round 14, "glossy blue-and-white plastic boots with hard speculars"): matte, like the skin  ## (round 13, "the face lost in shadow under the hair") light added to the face in the pictures
UI_STOPS = (0.0, 0.14, 0.2, 1.0)  ## the terminator: a crisp step (a pixel or two of softening)
BOLD_RIM = {"day": ((1.0, 0.33, 0.08), 0.6, (-0.6, 0.8)), "sunset": ((1.0, 0.5, 0.12), 0.0, (-0.62, 0.62))}  ## (k9, the user: "remove the sun reflect on the character: it looks dirty": no rim in the pictures)  ## (k7: hotter, "no rim light on the hair, shoulders or arm edges")  ## (k6: the sun up behind his head and upper back: the rim on his upper-left edges)  ## (k4: the sun low behind his back, on the left)  ## (key
## art k2: the menu's sun moved to his upper right, behind the throw: the rim on that side)
## (round 15, "a paler band just inside the outline": the rim was a pale peach, sRGB (1, 0.81, 0.58)) a hot orange,
## sRGB (1, 0.6, 0.31) and (1, 0.58, 0.27)
UI_RIM_BACK = 0.0  ## (key art k7: 0.3 drew "a pale tan halo line between the ink and the body" on every edge)  ## (key art k1: 0.7 lost, a halo; k2: the rim on the sun's side, a trace elsewhere)  ## (round 15, "the sun directly behind his chest, yet no rim") in the pictures the sun is behind
## him: the rim on every edge at this share, on the edges towards the sun in full
SOFT_STOPS = {"day": (0.0, 0.11, 0.26, 1.0), "sunset": (0.0, 0.1, 0.28, 1.0)}  ## (round 15, "abs and chest cut in
## with dark lines of equal strength, muscles printed on": the skin's terminator a soft blend, not a step)
SOFT_REGIONS = ("skin", "hand")
DAY_FLAT_K = 1.0  ## (round 15: 0.55; round 16, "painterly smudges read as dirt": all the way) how far the skin's
## painted albedo goes to its clean colour in the level
CHEST_LIFT = 0.1  ## (round 15, "keep the brightest values on the face and chest") light added to his chest and face
FACE_FRAME = (-0.085, 0.28, 0.17)  ## (round 15) the drawn face's frame in the rest shape: the y and z of its lower left
## corner and its span (tools/art/hero_face.py; m["decal"]: the expression's picture, over the face's own colours)
BOOT_CREAM = (0.33, 0.24, 0.14)  ## (round 17: a tan leather, "white specular streaks: plastic rain boots")  ## linear: the boots' white parts as cream leather, sRGB (0.74, 0.69, 0.59)
BOOT_CORD = (0.09, 0.045, 0.022)  ## the cords crossing them, a dark brown
BOOT_BRASS = (0.45, 0.27, 0.06)  ## the band at their top
BOOT_SOLE = (0.2, 0.11, 0.05)  ## a tan leather sole (round 16: the dark one "merged with the soil")
BOOT_WRAPS = 150.0  ## radians of the cords' wind per rest unit of height (about six crossings up the boot)
CHAKRAM_CORE = (0.35, 0.85, 1.0)  ## linear: the glow round the chakram's grip, the throw trail's cold light
FACE_TO_SKIN = (0.777, 0.876, 1.11)  ## the face picture's mean skin to SKIN (both linear)
HAIR_RIM = (0.55, 0.2, 0.05)  ## (round 16, "a solid black blob") a warm rim on the sun side of every clump (linear)
HAIR_TIPS = (0.05, 0.022, 0.012)  ## and the locks' ends a warm dark brown
HAIR_CENTRE = (0.0, 0.0, 0.4)  ## the middle of his head in the rest shape (the tips lie furthest from it)
## (key art k39, "a dark noisy blob with scratchy strands, a jagged fuzzy edge: 5-7 big clumps with a light side, a shadow side
## and a few clean highlights") in the pictures the hair is lit by its designed lock normals (hero_render.py
## key_hair_normals(): attribute "hair_n"): each big lock one mass, a crisp light and shadow side, one clean warm-brown
## highlight band along it, no strand noise (no lock noise, normal map or deep occlusion)
HAIR_LOCK_K = float(_os.environ.get("HAIR_LOCK_K", "0.55"))  ## the share of the lock's normal in the hair's light
HAIR_HI = (0.11, 0.05, 0.026)  ## the highlight band: his hair's own warm brown (linear), never cool or glossy
HAIR_HI_CUT = (0.5, 0.56)  ## where the lock's sheen turns into the band (a crisp edge)
HAIR_AO_K = 0.3  ## the occlusion kept in the pictures (deep gaps only; was 0.9)
## (key art k7, "the lower body melts into the background: one orange-tan value"; "a generic fighter: one signature
## colour") the kilt a white Nguni cowhide with bold dark patches (the logo shield's hide) and a beaded hem, a red sash
## round his waist, the leather under the kilt dark; the boots: clean blue shin guards over dark glossy leather
COW_DARK = (0.03, 0.018, 0.014)  ## (k9: black-brown; k7 (0.085, 0.032, 0.018)) the spots, lit by the fur's bands
## (key art k9, "random hard-edged blobs": a few designed spots, (y, z, radius y, radius z) in the rest shape: three on the
## front apron, two on the back)
COW_SPOTS_FRONT = ((-0.062, 0.006, 0.042, 0.032), (0.055, 0.045, 0.028, 0.024))  ## (k11: two big designed shapes, "random
COW_SPOTS_BACK = ((0.04, -0.07, 0.04, 0.032),)  ## black blobs")
## (key art k27, "the big black spot sits at the crotch and reads as a hole or stain", "a diaper") the pictures' front
## apron: three irregular spots of different sizes, off the groin, toward the hip edge and the panel's lower half (rest y, z,
## radius y, radius z; no automatic satellites), each with a soft fur edge
COW_SPOTS_KEY = ((-0.1, -0.046, 0.023, 0.027), (-0.127, -0.083, 0.012, 0.015), (-0.093, 0.013, 0.014, 0.011))
## (key art k27, "the maroon underwrap merges with the thigh skin in value: a stain") the wrap's maroon kept, drawn apart from
## the thigh: a dark rolled hem where it ends (HEM_W rest units wide), a crisp cast shadow from it on the skin (HEM_SHADOW wide),
## one clean fold inside it (rest: from x -0.05, z -0.035 to x 0.035, z -0.08 across the thigh, at most WRAP_FOLD_W wide)
WRAP_HEM = (0.028, 0.0028, 0.004)
HEM_W = 0.0024
HEM_SHADOW = 0.0055
WRAP_FOLD = ((-0.05, -0.035), (0.035, -0.08))
WRAP_FOLD_W = 0.0065
## (key art k33, "the back fist a brown lump with fur-like smudges, no finger or knuckle planes: a rock, a mitten"; "four
## clear finger blocks and a thumb wrap, a crisp shadow under the knuckles") the back (left) fist in the skin's clean
## language: its surface smoothed (the proxy), lit through the skin's crisp stops, a dark break where one finger meets the next
## and round the thumb (hero_render.py key_skin_normals(): the "fist_gap" attribute from the skin weights)
FIST_BREAK = (0.5, 0.62)
BACK_KNEE_SHADE = 1.5  ## (key art k36) how far the back knee's light is pushed down: into the shade band
FIST_BREAK_TONE = (0.34, 0.27, 0.3)
WRAP_STRAP = (0.07, 0.032, 0.016)  ## (key art k9, "plastic socks") the shin guards' binding straps, dark leather
GUARD_BLUE = (0.045, 0.12, 0.42)  ## (k11) the shin guard, a lighter blue
BOOT_NAVY = (0.006, 0.016, 0.075)  ## and the boot under it, a dark navy leather
GUARD_CUFF = (0.72, 0.65, 0.52)  ## and their top cuff, white fur (k10; k9 a cream hide (0.5, 0.4, 0.26))
HEM_BEADS = ((0.62, 0.02, 0.015), (0.85, 0.8, 0.68))  ## red, white (linear; k9: no blue, "no clear 2-3 colour identity")
SASH_RED = (0.62, 0.025, 0.018)
BOOT_LEATHER = (0.05, 0.022, 0.011)  ## the foot's leather (sRGB ~ (0.25, 0.16, 0.1)), with a gloss
SCARF_LINES = ((0.02, 0.012, 0.02), (0.85, 0.78, 0.66))  ## (key art k8, kept in k9: "better designed than a red smear")
## the scarf a red shuka: thin dark and white check lines across it, so it reads as cloth
GOLD = (0.78, 0.4, 0.04)  ## (key art k8, kept in k9) a gold armlet round each upper arm
GOLD_SHADE = (0.25, 0.1, 0.012)
ARM_AXIS = ((-0.033, 0.152, 0.237), (0.0, 0.83, -0.555))  ## the upper arm's middle (|y|) and its way to the elbow (rest)
BELT_WHITE = (0.85, 0.8, 0.68)  ## (round 16: the panels' pattern moved to the belt) a white zigzag round it
BELT_BEAD = (0.03, 0.12, 0.55)  ## and blue beads under it
FEET_DIM = 0.18  ## and how much darker everything is at his boots (rest height: -0.5 his soles, 0.5 his hair)
## (round 13, "a pale outline glow rings the hero" on every interface picture: the sunset rim lay on every edge (a 0.3
## floor); now only on the edges towards the sun, upper left as in the level: a rim against the sky, not a halo)
## (sunset: the key lights him from the front-left, the sun's hot rim takes the other edges, upper right)
BOLD_ALBEDO = {"scarf": (0.72, 0.03, 0.02), "armour_blue": None}  ## (k7: brighter, "a small dark sliver that reads like a wound"; was (0.5, 0.02, 0.015))  ## flat linear colours (scarf: no blotches)
# light levels (Shader to RGB of a white diffuse under the key sun 3.2 and the fill) where the bands turn
STOPS = (0.0, 0.055, 0.1, 0.19, 0.26, 0.5, 0.58, 1.0)
LIGHT = {  # rim colour, rim strength, bounce colour, bounce strength, sheen strength
    "day": ((1.0, 0.7, 0.4), 0.5, (0.05, 0.075, 0.16), 0.5, 0.1),
    "sunset": ((1.0, 0.45, 0.1), 1.4, (0.035, 0.045, 0.13), 0.55, 0.13),
}
LOOK = {  # albedo saturation (lit), shade desaturation, shade cool tint (multiplier), sheen scale
    "day": (1.18, 0.12, (0.97, 0.98, 1.04), 1.0),
    "sunset": (1.05, 0.22, (0.86, 0.88, 1.06), 0.0),  # backlit: a cooler, greyer front (hero pass 3)
}
SAT_REGIONS = ("skin", "face", "hand", "scarf", "armour_blue", "belt")
RIM_K = {"chakram": 1.0, "hair": 0.18, "eye": 0.0, "armour_blue": 0.7, "armour_silver": 0.5, "fur": 0.45, "face": 0.8}
RIM_K_SUNSET = {"hair": 0.5, "fur": 0.6, "armour_blue": 0.85, "armour_silver": 0.85}  ## (key art k7) the pictures' rim on
## the hair and the costume too: "no rim light on the hair"
SHEEN_K = {"skin": 1.0, "face": 0.7, "hand": 0.8, "scarf": 0.45, "belt": 0.8}
AO = {"hair": (0.06, 0.9), "fur": (0.08, 0.95), "armour_blue": (0.02, 0.45), "armour_silver": (0.02, 0.45),
      "scarf": (0.05, 0.8), "belt": (0.02, 0.4), }
NORMAL_MAP = {"armour_blue": 0.75, "armour_silver": 0.75, "fur": 0.5, "belt": 0.6, "scarf": 0.3, "hair": 0.4}


class G:
    """A small node-graph writer."""

    def __init__(self, nt):
        self.nt = nt
        self.x = 0

    def node(self, kind, **inputs):
        n = self.nt.nodes.new(kind)
        n.location = (self.x, 0)
        self.x += 40
        for k, v in inputs.items():
            n.inputs[k].default_value = v
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n.outputs[0]

    def smooth(self, v, lo, hi):
        n = self.node("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.clamp = True
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        self.link(v, n.inputs["Value"])
        return n.outputs["Result"]

    def mix(self, blend, fac, a, b):
        n = self.node("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        n.clamp_result = False
        if isinstance(fac, (int, float)):
            n.inputs["Factor"].default_value = fac
        else:
            self.link(fac, n.inputs["Factor"])
        for sock, v in (("A", a), ("B", b)):
            if isinstance(v, tuple):
                n.inputs[sock].default_value = (*v[:3], 1.0)
            else:
                self.link(v, n.inputs[sock])
        return n.outputs["Result"]

    def grey(self, v):
        c = self.node("ShaderNodeCombineColor")
        for i in range(3):
            self.link(v, c.inputs[i])
        return c.outputs[0]

    def noise(self, vec, scale, detail=2.0, rough=0.5):
        mp = self.node("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = scale
        self.link(vec, mp.inputs["Vector"])
        nz = self.node("ShaderNodeTexNoise", Detail=detail, Roughness=rough)
        nz.inputs["Scale"].default_value = 1.0
        self.link(mp.outputs[0], nz.inputs["Vector"])
        return nz.outputs["Fac"]


def _pictures(m):
    """The base colour and normal map pictures (remembered on the material the first time)."""
    nt = m.node_tree
    base, normal = m.get("aaa_base"), m.get("aaa_normal")
    if not base or base not in bpy.data.images:
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                feeds_nm = any(l.to_node.type == "NORMAL_MAP" for l in n.outputs[0].links)
                if feeds_nm:
                    normal = n.image.name
                elif not n.image.name.startswith("NormalGL"):
                    base = n.image.name
        if "AAA_albedo" in bpy.data.images:
            base = "AAA_albedo"
        m["aaa_base"], m["aaa_normal"] = base, normal or ""
    return bpy.data.images.get(base), bpy.data.images.get(normal) if normal else None


def build(m, mode="day"):
    region = m.get("toon")
    if not region:
        return False
    base_img, nm_img = _pictures(m)
    nt = m.node_tree
    nt.nodes.clear()
    g = G(nt)
    out = g.node("ShaderNodeOutputMaterial")
    uv = g.node("ShaderNodeTexCoord")
    flat = m.get("flat")  # (round 9) a flat albedo (linear) set on the material: the bandit's colours
    if flat:
        rgb = g.node("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*flat, 1.0)
        albedo = rgb.outputs[0]
    elif BOLD and BOLD_ALBEDO.get(region):
        rgb = g.node("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*BOLD_ALBEDO[region], 1.0)
        albedo = rgb.outputs[0]
    elif BOLD and (mode == "sunset" or region == "face") and region in UI_FLAT:  # (round 12) the interface pictures'
        # colours, one clean colour a part (key art k2: every part, "the old painted textures' brush strokes, seams and
        # bleed cut up by the cel ramp"; the face in the level too: its features are the drawn face's)
        rgb = g.node("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*UI_FLAT[region], 1.0)
        albedo = rgb.outputs[0]
    elif region == "chakram":
        rgb = g.node("ShaderNodeRGB")
        rgb.outputs[0].default_value = (0.42, 0.55, 0.78, 1.0)  # blue steel (the game's ring)
        albedo = rgb.outputs[0]
    else:
        tex = g.node("ShaderNodeTexImage")
        tex.image = base_img
        g.link(uv.outputs["UV"], tex.inputs["Vector"])
        albedo = tex.outputs["Color"]
        if BOLD and region in SOFT_REGIONS:  # (round 15) no muscles painted on: the albedo most of the way to its mean
            albedo = g.mix("MIX", DAY_FLAT_K, albedo, UI_FLAT[region])
    geo = g.node("ShaderNodeNewGeometry")
    N = geo.outputs["Normal"]
    if nm_img is not None and region in NORMAL_MAP and not (mode == "sunset" and BOLD and region in ("armour_blue", "armour_silver", "fur", "belt", "hair")):
        # (key art k27: and none on the cowhide and the wrap: "grey speckles in the white", "muddy smears")
        # (key art k11: no painted normal map on the guards and boots in the pictures: "glossy white streaks")
        nt_tex = g.node("ShaderNodeTexImage")
        nt_tex.image = nm_img
        nt_tex.image.colorspace_settings.name = "Non-Color"
        g.link(uv.outputs["UV"], nt_tex.inputs["Vector"])
        nmap = g.node("ShaderNodeNormalMap", Strength=NORMAL_MAP[region])
        g.link(nt_tex.outputs["Color"], nmap.inputs["Color"])
        N = nmap.outputs["Normal"]
    rest = g.node("ShaderNodeAttribute")
    rest.attribute_name = "rest_co"
    P = rest.outputs["Vector"]
    decal = bpy.data.images.get(m.get("decal", "")) if region == "face" else None
    if decal is not None:  # (round 15) the drawn face (eyes, brows, mouth), mapped by the rest shape's y and z
        sepd = g.node("ShaderNodeSeparateXYZ")
        g.link(P, sepd.inputs[0])
        comb = g.node("ShaderNodeCombineXYZ")
        g.link(g.math("DIVIDE", g.math("SUBTRACT", sepd.outputs["Y"], FACE_FRAME[0]), FACE_FRAME[2]), comb.inputs[0])
        g.link(g.math("DIVIDE", g.math("SUBTRACT", sepd.outputs["Z"], FACE_FRAME[1]), FACE_FRAME[2]), comb.inputs[1])
        dt = g.node("ShaderNodeTexImage")
        dt.image = decal
        dt.extension = "CLIP"
        dt.interpolation = "Cubic"
        g.link(comb.outputs[0], dt.inputs["Vector"])
        front = g.smooth(sepd.outputs["X"], -0.01, 0.01)  # the face's front only, never through to the back
        albedo = g.mix("MIX", g.math("MULTIPLY", dt.outputs["Alpha"], front), albedo, dt.outputs["Color"])
    # (key art k2: the face is SKIN flat, its old picture's warm-up no longer needed)
    # the light (key and fill, with cast shadows) as one value
    dif = g.node("ShaderNodeBsdfDiffuse", Color=(1, 1, 1, 1))
    g.link(N, dif.inputs["Normal"])
    s2r = g.node("ShaderNodeShaderToRGB")
    g.link(dif.outputs[0], s2r.inputs[0])
    bw = g.node("ShaderNodeRGBToBW")
    g.link(s2r.outputs["Color"], bw.inputs[0])
    L = bw.outputs[0]
    if region == "fur" and not (mode == "sunset" and BOLD):  # strands: the light itself broken along them (a stepped terminator)
        # (key art k27: not in the pictures, "grey speckles in the white")
        strand = g.noise(P, (38.0, 38.0, 4.0), 1.0, 0.4)  # (round 14: tufts, not scratchy strands)
        L = g.math("ADD", L, g.math("MULTIPLY", g.math("SUBTRACT", strand, 0.5), 0.18))
    if region == "face" and mode == "sunset":  # (round 13) out of the hair's shadow
        L = g.math("ADD", L, UI_FACE_LIFT)
    sepr = g.node("ShaderNodeSeparateXYZ")
    g.link(P, sepr.inputs[0])
    height = sepr.outputs["Z"]  # (rest shape: -0.5 at his soles, 0.5 at the top of his hair)
    if BOLD and not flat and region in ("skin", "face", "hand"):  # (round 15) his chest and face in the most light
        L = g.math("ADD", L, g.math("MULTIPLY", g.smooth(height, 0.0, 0.3), CHEST_LIFT))
    if region == "skin" and mode == "sunset" and BOLD and not flat:
        # (key art k36, "a pale tan patch on the back knee above the sock reads as a hole") his back (rest y < 0) knee and thigh,
        # behind the kilt and above the guard, in the leg's core-shadow tone: the kilt's shadow over them
        back_knee = g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(sepr.outputs["Y"], -0.02, -0.035), g.smooth(height, -0.245, -0.235)),
                           g.smooth(height, -0.1, -0.115))
        L = g.math("SUBTRACT", L, g.math("MULTIPLY", back_knee, BACK_KNEE_SHADE))
    hem_d = None
    if mode == "sunset" and BOLD and not flat and (region == "skin" or (region == "belt" and m.name == "AAA_belt")):
        # (key art k27) the distance from where the wrap ends on the thigh (hero_render.py key_hem(): + on the skin, - on the cloth)
        att_h = g.node("ShaderNodeAttribute")
        att_h.attribute_name = "hem_d"
        legs = g.smooth(height, 0.0, -0.012)  # (the thighs only, not the sash on his belly)
        hem_d = att_h.outputs["Fac"]
        if region == "skin":  # a crisp shadow cast by the hem on the skin just below it
            cast = g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(hem_d, HEM_SHADOW, HEM_SHADOW * 0.85), g.math("GREATER_THAN", hem_d, 0.0)), legs)
            L = g.math("SUBTRACT", L, g.math("MULTIPLY", cast, 1.5))
    hair_n = None
    if region == "hair" and mode == "sunset" and BOLD:  # (key art k39) the light of its big locks, not of every strand
        att_hn = g.node("ShaderNodeAttribute")
        att_hn.attribute_name = "hair_n"
        hn = g.node("ShaderNodeVectorMath")
        hn.operation = "NORMALIZE"
        g.link(att_hn.outputs["Vector"], hn.inputs[0])
        # the lock's normal blended with each spike's own (HAIR_LOCK_K of the lock): the big masses lead, the spikes keep a
        # little form inside them
        bl = g.node("ShaderNodeVectorMath")
        bl.operation = "SCALE"
        g.link(hn.outputs["Vector"], bl.inputs[0])
        bl.inputs["Scale"].default_value = HAIR_LOCK_K
        bg_ = g.node("ShaderNodeVectorMath")
        bg_.operation = "SCALE"
        g.link(geo.outputs["Normal"], bg_.inputs[0])
        bg_.inputs["Scale"].default_value = 1.0 - HAIR_LOCK_K
        sm_ = g.node("ShaderNodeVectorMath")
        sm_.operation = "ADD"
        g.link(bl.outputs["Vector"], sm_.inputs[0])
        g.link(bg_.outputs["Vector"], sm_.inputs[1])
        hn2 = g.node("ShaderNodeVectorMath")
        hn2.operation = "NORMALIZE"
        g.link(sm_.outputs["Vector"], hn2.inputs[0])
        hair_n = hn2.outputs["Vector"]
        dif_h = g.node("ShaderNodeBsdfDiffuse", Color=(1, 1, 1, 1))
        g.link(hair_n, dif_h.inputs["Normal"])
        s2h = g.node("ShaderNodeShaderToRGB")
        g.link(dif_h.outputs[0], s2h.inputs[0])
        bwh = g.node("ShaderNodeRGBToBW")
        g.link(s2h.outputs["Color"], bwh.inputs[0])
        L = bwh.outputs[0]
    elif region == "hair":  # the locks: their own terminator, broken per lock (round 15: big locks, "a fuzzy helmet")
        lock = g.noise(P, (9.0, 9.0, 9.0), 0.0, 0.4)  # (key art k3: 16 -> 9, 5-7 big locks, "a pineapple top")
        L = g.math("ADD", L, g.math("MULTIPLY", g.math("SUBTRACT", lock, 0.5), 0.3))  # (k10: k7's grouped locks back)
    if region == "hand" and mode == "sunset" and BOLD and not flat:
        # (key art k33) on the back fist only, the light remapped so the hand's own (k11) stops cut it where the skin's crisp
        # KEY_SKIN_STOPS do (the front hand untouched)
        left = g.smooth(sepr.outputs["Y"], 0.0, 0.01)
        s_from, s_to = KEY_SKIN_STOPS, (0.0, 0.06, 0.24, 0.74, 0.8, 1.0)
        remap = None
        for i in range(5):
            seg = g.node("ShaderNodeMapRange")
            seg.clamp = True
            seg.inputs["From Min"].default_value = s_from[i]
            seg.inputs["From Max"].default_value = s_from[i + 1]
            seg.inputs["To Min"].default_value = 0.0
            seg.inputs["To Max"].default_value = s_to[i + 1] - s_to[i]
            g.link(L, seg.inputs["Value"])
            remap = seg.outputs["Result"] if remap is None else g.math("ADD", remap, seg.outputs["Result"])
        L = g.math("ADD", L, g.math("MULTIPLY", left, g.math("SUBTRACT", remap, L)))
    deep, shade, mid, lit = BANDS[mode][region]
    ramp = g.node("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "LINEAR"
    el = ramp.color_ramp.elements
    if BOLD:
        sh, li = BOLD_BANDS[mode][region]
        if mode == "day" and not flat and region in DAY_LIT:  # (round 11) his lit skin lighter in play
            li = tuple(x * k for x, k in zip(li, DAY_LIT[region]))
        stops = BOLD_STOPS
        if mode == "sunset" and not flat and region in UI_BANDS:  # (round 12) the interface pictures
            sh, li = UI_BANDS[region]
            stops = UI_STOPS
        if mode == "sunset" and not flat and region in CLEAN_REGIONS:  # (key art k9, the user) true local colours
            sh, li = CLEAN_SHADE, CLEAN_LIT
        if not flat and region in SOFT_REGIONS:
            stops = SOFT_STOPS[mode]
        cols = (sh, sh, li, li)
        if not flat and region in SKIN_REGIONS:  # (round 16) three bands
            b3 = SKIN_BANDS[mode]
            lift = 1.08 if region == "face" else 1.0  # (the face a little lighter: it leads)
            cols = tuple(tuple(c * lift for c in b) for b in (b3[0], b3[0], b3[1], b3[1], b3[2], b3[2]))
            stops = SKIN_STOPS if mode == "day" else (KEY_SKIN_STOPS if region == "skin" else (0.0, 0.06, 0.24, 0.74, 0.8, 1.0))  # (k11, "hard-edged blotches that don't
            # follow one light": a soft core-shadow edge, the lit plane only where the key faces him squarely; k10: crisp edges; k2: one soft turn)
    else:
        stops, cols = STOPS, (deep, deep, shade, shade, mid, mid, lit, lit)
    el[0].position, el[0].color = stops[0], (*cols[0], 1)
    el[1].position, el[1].color = stops[-1], (*cols[-1], 1)
    for pos, col in zip(stops[1:-1], cols[1:-1]):
        e = el.new(pos)
        e.color = (*col, 1)
    g.link(L, ramp.inputs["Fac"])
    if region == "hair":
        colour = ramp.outputs["Color"]
    else:
        alb = albedo
        if region == "armour_blue" and BOLD and not flat:  # (pass 4) a deeper, richer blue: armour, not sneakers
            alb = g.mix("MULTIPLY", 1.0, albedo, (0.62, 0.7, 0.86))
        elif region == "armour_blue":  # the user's blue, a touch warmer and less saturated (matte)
            lum = g.node("ShaderNodeRGBToBW")
            g.link(albedo, lum.inputs[0])
            warm_grey = g.mix("MULTIPLY", 1.0, g.grey(lum.outputs[0]), (1.25, 1.05, 0.85))
            alb = g.mix("MIX", 0.22, albedo, warm_grey)
        if region == "armour_silver":
            alb = g.mix("MULTIPLY", 1.0, albedo, (1.02, 0.99, 0.94))
        if region in ("armour_blue", "armour_silver") and BOLD and not flat:
            # (round 15, "blue-and-white high-top sneakers, modern basketball shoes") below the knee: warrior's
            # footwear: the white parts cream leather laced with crossed brown cords, the blue wrapped in strips, a
            # brass band at the top and a dark leather sole
            ang = g.math("ARCTAN2", sepr.outputs["X"], g.math("SUBTRACT", g.math("ABSOLUTE", sepr.outputs["Y"]), 0.085))
            boot = g.smooth(height, -0.215, -0.24)
            wind = g.math("MULTIPLY", height, BOOT_WRAPS)
            # (round 16, "noise at phone size": two values and one accent; key art k2, "random blue patches on tan
            # leather look like texture errors": the boot's colours in designed bands, not the painted patches) a
            # blue wrap up the shin, tan leather over the foot, brass at the top, a tan sole
            shin = g.math("MULTIPLY", g.smooth(height, -0.415, -0.405), boot)
            if mode == "sunset":  # (key art k7, "ragged white cloth with blue patches clutter the knee"; "skin-coloured
                # socks") one clean blue guard up the whole shin to the knee, the foot dark leather
                shin = g.smooth(height, -0.415, -0.405)
                alb = g.mix("MIX", boot, alb, BOOT_LEATHER)
            else:
                alb = g.mix("MIX", boot, alb, BOOT_CREAM)
            alb = g.mix("MIX", shin, alb, UI_FLAT["armour_blue"])
            if mode == "sunset":  # (key art k9) bound to the shin: two dark straps wound up it, a cream cuff at the top,
                # a thin brass line under it
                guard = g.math("MULTIPLY", shin, g.smooth(height, -0.236, -0.244))
                sp = g.math("FRACT", g.math("DIVIDE", g.math("ADD", g.math("MULTIPLY", height, 52.0), ang), 6.2832))
                strap = g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(sp, 0.0, 0.02), g.smooth(sp, 0.16, 0.13)), guard)
                alb = g.mix("MIX", strap, alb, WRAP_STRAP)
                cuff = g.math("MULTIPLY", g.smooth(height, -0.246, -0.24), g.smooth(height, -0.214, -0.22))
                alb = g.mix("MIX", cuff, alb, WRAP_STRAP)  # (key art k17: a dark leather top edge; the white fur cuff read as "a pale blob on the back knee")
                # (key art k10, "laced brown shoes and blue sports socks: football kit, hiking boots") one designed boot:
                # the foot in the guard's blue, a brass band round the ankle, a dark sole
                foot = g.smooth(height, -0.405, -0.415)
                # (key art k11, "the same saturated blue: plastic football socks and rubber wellingtons") a lighter guard over
                # a darker boot
                alb = g.mix("MIX", g.math("MULTIPLY", guard, 1.0), alb, GUARD_BLUE)
                alb = g.mix("MIX", foot, alb, BOOT_NAVY)
                ankle = g.math("MULTIPLY", g.smooth(height, -0.42, -0.416), g.smooth(height, -0.4, -0.404))
                alb = g.mix("MIX", ankle, alb, BOOT_BRASS)
                band = g.math("MULTIPLY", g.smooth(height, -0.253, -0.25), g.smooth(height, -0.243, -0.246))
            else:
                band = g.math("MULTIPLY", g.smooth(height, -0.252, -0.246), g.smooth(height, -0.226, -0.232))
            alb = g.mix("MIX", band, alb, BOOT_BRASS)
            sole = g.smooth(height, -0.488, -0.494) if mode == "sunset" else g.smooth(height, -0.466, -0.476)
            alb = g.mix("MIX", sole, alb, (0.05, 0.025, 0.013) if mode == "sunset" else BOOT_SOLE)  # (key art k7: in the pictures only its edge; it tanned half the shoe)
        if region == "fur":
            alb = g.mix("MULTIPLY", 1.0, albedo, (1.0, 0.97, 0.9))  # warm cream, never grey paper
        if region == "belt" and mode == "sunset" and BOLD and (not flat or m.name.startswith("AAA_underwrap")):
            # (the underwrap's waistband is the sash too; under the kilt it is the dark leather)
            low = UI_FLAT["belt"] if flat else alb
            alb = g.mix("MIX", g.smooth(height, 0.07, 0.08), low, SASH_RED)
        sat, desat, cool, _ = LOOK[mode]
        if mode == "sunset" and region in SKIN_REGIONS:  # (key art k7) his shade warm, not greyed and cooled
            desat, cool = 0.04, (1.0, 0.95, 0.93)
        if region in SAT_REGIONS:
            lum = g.node("ShaderNodeRGBToBW")
            g.link(alb, lum.inputs[0])
            grey = g.grey(lum.outputs[0])
            # in the light: a little more saturated; in the shade: greyer and cooler (no flat orange)
            lit_s = g.mix("MIX", 1.0 if region in SKIN_REGIONS else sat, grey, alb)
            shade_s = g.mix("MULTIPLY", 1.0, g.mix("MIX", desat, alb, grey), cool)
            alb = g.mix("MIX", g.smooth(L, stops[1], stops[2]) if BOLD else g.smooth(L, STOPS[3], STOPS[5]), shade_s, lit_s)
        colour = g.mix("MULTIPLY", 1.0, alb, ramp.outputs["Color"])
    # view-space normal: the edge (facing away from us) and where it points on screen
    vt = g.node("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from, vt.convert_to = "WORLD", "CAMERA"
    g.link(geo.outputs["Normal"], vt.inputs[0])
    sep = g.node("ShaderNodeSeparateXYZ")
    g.link(vt.outputs[0], sep.inputs[0])
    facing = g.math("ABSOLUTE", sep.outputs["Z"])
    edge = g.math("SUBTRACT", 1.0, facing)
    lit_k = g.smooth(L, STOPS[4], STOPS[6])  # 0 in shade, 1 in the light
    if region in ("armour_blue", "armour_silver") and mode == "sunset" and BOLD and not flat:
        # (key art k9, "flat saturated tubes: plastic socks") the guard's leather: a faint grain and a darker turn at its
        # edges, so it reads round
        gz = g.math("MULTIPLY", g.smooth(height, -0.415, -0.405), g.smooth(height, -0.215, -0.24))
        grain = g.math("ADD", g.math("MULTIPLY", g.noise(P, (90.0, 90.0, 25.0), 2.0, 0.5), 0.12), 0.94)
        colour = g.mix("MULTIPLY", gz, colour, g.grey(grain))
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", g.smooth(edge, 0.35, 0.75), g.math("MULTIPLY", gz, 0.45)), colour, (0.4, 0.42, 0.62))
    # occlusion: the locks parted, the fur's folds, the armour's seams
    if region in AO:
        dist, k = AO[region]
        if region == "fur" and mode == "sunset" and BOLD:  # (key art k7) the white hide clean, not grey with dirt
            k = 0.5
        if region == "hair" and mode == "sunset" and BOLD:  # (key art k39) deep gaps only, not every strand's crevice
            k = HAIR_AO_K
        ao = g.node("ShaderNodeAmbientOcclusion", Distance=dist)
        ao.samples = 48  # (round 17: 16 left a "watercolour noise")
        ao.only_local = True
        g.link(N, ao.inputs["Normal"])
        occ = g.math("ADD", g.math("MULTIPLY", ao.outputs["AO"], k), 1.0 - k)
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(occ))
    if region == "fur" and mode == "sunset" and BOLD:
        # (key art k7, "ragged greyish-beige with dirty smudges: castaway rags") white cowhide: big dark patches, a
        # beaded hem (red, white, blue) across it, a little darker underneath
        wob = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, (14.0, 14.0, 14.0), 0.0, 0.5), 0.5), 0.9)  # (k11: smooth lobes, designed, not ragged)
        front_k = g.smooth(sepr.outputs["X"], -0.005, 0.01)
        spots = None
        # (key art k27) the soft fur edge: fine tufts breaking the outline, a narrow soft step, not a hard decal oval
        fur_e = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, (160.0, 160.0, 160.0), 1.0, 0.5), 0.5), 0.35)
        fur_e = g.math("ADD", fur_e, g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, (42.0, 42.0, 42.0), 0.0, 0.5), 0.5), 0.9))  # (lobes: irregular, not round)
        back_table = [sp_ for c in COW_SPOTS_BACK for sp_ in (c, (c[0] + c[2] * 0.75, c[1] - c[3] * 0.55, c[2] * 0.55, c[3] * 0.6))]
        for side_k, table, edge_ in ((front_k, list(COW_SPOTS_KEY), True), (g.math("SUBTRACT", 1.0, front_k), back_table, False)):
            for cy_, cz_, ry_, rz_ in table:
                dy = g.math("DIVIDE", g.math("SUBTRACT", sepr.outputs["Y"], cy_), ry_)
                dz = g.math("DIVIDE", g.math("SUBTRACT", height, cz_), rz_)
                d = g.math("ADD", g.math("ADD", g.math("MULTIPLY", dy, dy), g.math("MULTIPLY", dz, dz)), wob)
                if edge_:
                    d = g.math("ADD", d, fur_e)
                one = g.math("MULTIPLY", g.smooth(d, 1.1, 0.9) if edge_ else g.smooth(d, 1.04, 0.96), side_k)
                spots = one if spots is None else g.math("MAXIMUM", spots, one)
        colour = g.mix("MIX", spots, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], COW_DARK))
        # the hem's line: on the front apron a V, highest near the middle (rest: z -0.002 at y 0.02, falling 0.95 a unit
        # sideways); behind, level; the beaded band a little above it, a fringe of strands below the band
        hem_f = g.math("SUBTRACT", -0.002, g.math("MULTIPLY", g.math("ABSOLUTE", g.math("SUBTRACT", sepr.outputs["Y"], 0.02)), 0.95))
        hem_z = g.math("ADD", g.math("MULTIPLY", hem_f, front_k), g.math("MULTIPLY", -0.163, g.math("SUBTRACT", 1.0, front_k)))  # (k10: the back cut clean at -0.165)
        rel = g.math("SUBTRACT", height, g.math("ADD", hem_z, 0.028))
        hem = g.math("MULTIPLY", g.smooth(rel, -0.001, 0.001), g.smooth(rel, 0.013, 0.011))
        fringe = g.math("MULTIPLY", g.smooth(rel, 0.0, -0.002), g.smooth(g.math("FRACT", g.math("MULTIPLY", sepr.outputs["Y"], 140.0)), 0.75, 0.85))
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", fringe, 0.0), colour, (0.5, 0.36, 0.3))  # (key art k27: no strand lines, "torn tissue paper")
        # (key art k10, "the red-and-white candy-cane hem looks like barber tape") a calm band: solid red, one white
        # line along its lower edge
        colour = g.mix("MIX", hem, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], HEM_BEADS[0]))
        line = g.math("MULTIPLY", g.smooth(rel, -0.0025, -0.001), g.smooth(rel, 0.0012, 0.0002))
        colour = g.mix("MIX", line, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], HEM_BEADS[1]))
        sepu = g.node("ShaderNodeSeparateXYZ")
        g.link(geo.outputs["Normal"], sepu.inputs[0])
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", g.smooth(sepu.outputs["Z"], 0.1, -0.5), 0.35), colour, (0.7, 0.62, 0.66))
    elif region == "fur" and mode == "sunset":
        # (key art k3, "chalky torn paper": two or three broad fold planes across the cloth and a darker hem)
        fold = g.smooth(g.math("SINE", g.math("MULTIPLY", sepr.outputs["Y"], 34.0)), -0.2, 0.4)
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", g.math("SUBTRACT", 1.0, fold), 0.3), colour, (0.62, 0.55, 0.6))
        hem = g.smooth(height, -0.06, -0.14)
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", hem, 0.45), colour, (0.55, 0.45, 0.42))
    if region == "fur" and not (mode == "sunset" and BOLD):
        # strands in value, darker roots under the belt and a darker underside
        strand2 = g.noise(P, (60.0, 60.0, 5.0), 1.0, 0.4)
        clump = g.noise(P, (24.0, 24.0, 2.5), 1.0, 0.35)  # tufts: big clumps, readable small (round 14: "scratchy dry-brush")
        v = g.math("ADD", g.math("MULTIPLY", strand2, 0.05), 0.95)  # (round 17: fine strands read as dither small)
        v = g.math("MULTIPLY", v, g.math("ADD", g.math("MULTIPLY", g.smooth(clump, 0.42, 0.5), 0.24), 0.8))
        sepw = g.node("ShaderNodeSeparateXYZ")
        g.link(geo.outputs["Normal"], sepw.inputs[0])
        under = g.math("MULTIPLY", g.smooth(sepw.outputs["Z"], 0.15, -0.5), 0.4)
        sepp = g.node("ShaderNodeSeparateXYZ")
        g.link(P, sepp.inputs[0])
        root = g.math("MULTIPLY", g.smooth(sepp.outputs["Z"], 0.0, 0.075), 0.14)
        v = g.math("MULTIPLY", v, g.math("SUBTRACT", 1.0, g.math("ADD", under, root)))
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(v))
    if region == "hair" and hair_n is not None:
        # (key art k39) one clean warm-brown band along each lock where its sheen faces the light and us (crisp), and its tips
        gl_h = g.node("ShaderNodeBsdfGlossy", Roughness=0.35)
        g.link(hair_n, gl_h.inputs["Normal"])
        s2gh = g.node("ShaderNodeShaderToRGB")
        g.link(gl_h.outputs[0], s2gh.inputs[0])
        bwg = g.node("ShaderNodeRGBToBW")
        g.link(s2gh.outputs["Color"], bwg.inputs[0])
        hi = g.smooth(bwg.outputs[0], HAIR_HI_CUT[0], HAIR_HI_CUT[1])
        colour = g.mix("MIX", g.math("MULTIPLY", hi, 0.95), colour, HAIR_HI)
        cen = g.node("ShaderNodeVectorMath")
        cen.operation = "DISTANCE"
        g.link(P, cen.inputs[0])
        cen.inputs[1].default_value = HAIR_CENTRE
        tips = g.smooth(cen.outputs["Value"], 0.11, 0.16)
        colour = g.mix("MIX", g.math("MULTIPLY", tips, 0.6), colour, (0.13, 0.065, 0.035))  # (k10's warm tips, kept)
    elif region == "hair":
        # a broken highlight band (an angel ring split into strand groups), only in the light
        off = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, (70.0, 70.0, 70.0), 2.0, 0.5), 0.5), 0.5 if mode == "day" else 0.08)
        y = g.math("ADD", sep.outputs["Y"], off)
        band = g.math("MULTIPLY", g.smooth(y, 0.18, 0.34), g.smooth(y, 0.62, 0.46))
        band = g.math("MULTIPLY", band, g.math("ADD", g.math("MULTIPLY", lit_k, 0.7), 0.3))
        # (round 15, all three judges: "grey, silver-blue: reads aged") black hair: a warm band of light across the
        # big locks (sRGB (0.42, 0.27, 0.17) at its brightest), no blue-grey sheen, no grey third step
        locks = g.smooth(g.noise(P, (9.0, 9.0, 9.0), 0.0, 0.4), 0.4, 0.6)
        band = g.math("MULTIPLY", band, g.math("ADD", g.math("MULTIPLY", locks, 0.7), 0.3))
        colour = g.mix("ADD", g.math("MULTIPLY", band, 0.85 if mode == "day" else 0.45), colour, (0.15, 0.06, 0.022))  # (k1's 1.2 lost; k5: near-black in the picture)  # (round 17: 0.5, "a smudge")
        sd = BOLD_RIM[mode][2]
        toward_sun = g.math("ADD", g.math("MULTIPLY", sep.outputs["X"], sd[0]), g.math("MULTIPLY", sep.outputs["Y"], sd[1]))
        clump = g.math("MULTIPLY", g.smooth(toward_sun, 0.15, 0.55), g.smooth(edge, 0.25, 0.55))
        colour = g.mix("ADD", g.math("MULTIPLY", clump, 0.6 if mode == "day" else 0.0), colour, HAIR_RIM)  # (k9: no sun on the hair in the pictures)
        cen = g.node("ShaderNodeVectorMath")
        cen.operation = "DISTANCE"
        g.link(P, cen.inputs[0])
        cen.inputs[1].default_value = HAIR_CENTRE
        tips = g.smooth(cen.outputs["Value"], 0.1, 0.16)
        colour = g.mix("MIX", g.math("MULTIPLY", tips, 0.6 if mode == "day" else 0.75), colour, HAIR_TIPS if mode == "day" else (0.13, 0.065, 0.035))  # (k10: "spiky, grouped locks with lighter tips")
    if region == "chakram":
        # engraving: a groove round the blade and a ring of notched marks, darker; a polished outer edge
        oc = uv.outputs["Object"]
        sepo = g.node("ShaderNodeSeparateXYZ")
        g.link(oc, sepo.inputs[0])
        r = g.math("SQRT", g.math("ADD", g.math("MULTIPLY", sepo.outputs["X"], sepo.outputs["X"]),
                                  g.math("MULTIPLY", sepo.outputs["Y"], sepo.outputs["Y"])))
        ang = g.math("ARCTAN2", sepo.outputs["Y"], sepo.outputs["X"])
        groove = g.math("MULTIPLY", g.smooth(r, 0.0505, 0.052), g.smooth(r, 0.0545, 0.053))
        marks = g.math("MULTIPLY", g.smooth(g.math("ABSOLUTE", g.math("SINE", g.math("MULTIPLY", ang, 12.0))), 0.86, 0.95),
                       g.math("MULTIPLY", g.smooth(r, 0.056, 0.0575), g.smooth(r, 0.0625, 0.061)))
        eng = g.math("MAXIMUM", groove, marks)
        if mode == "sunset":  # (round 12, "a flat grey donut, not a weapon") polished steel: its flat face mirrors the
            # sky in two bright lobes across it (upper left, lower right) and dark steel between, crisp like cel bands
            lobe = g.math("COSINE", g.math("MULTIPLY", g.math("SUBTRACT", ang, 2.36), 2.0))
            chrome = g.smooth(lobe, -0.05, 0.25)
            colour = g.mix("MIX", chrome, (0.05, 0.07, 0.14), colour)
            # (round 13, "a plain grey torus") the hot core of each lobe runs white, crisp
            colour = g.mix("MIX", g.math("MULTIPLY", g.smooth(lobe, 0.72, 0.8), 0.85), colour, (1.0, 0.98, 0.95))
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", eng, 0.75), colour, (0.18, 0.2, 0.3))
        edge_band = g.smooth(r, 0.063, 0.068)
        gl = g.node("ShaderNodeBsdfGlossy", Roughness=0.08)
        g.link(N, gl.inputs["Normal"])
        s2g = g.node("ShaderNodeShaderToRGB")
        g.link(gl.outputs[0], s2g.inputs[0])
        gbw = g.node("ShaderNodeRGBToBW")
        g.link(s2g.outputs["Color"], gbw.inputs[0])
        glint = g.smooth(gbw.outputs[0], *((0.3, 0.85) if mode == "sunset" else (0.6, 1.4)))  # (round 12: a steel glint, "a flat grey donut")
        colour = g.mix("ADD", g.math("MULTIPLY", glint, 0.9), colour, (1.0, 0.97, 0.9))
        colour = g.mix("ADD", g.math("MULTIPLY", g.math("MULTIPLY", edge_band, lit_k), 0.6), colour, (1.0, 0.95, 0.85))
        # (round 15, "a grey washer, a donut: an edge, an emissive core and a glint") the bladed ring (ROOT/_agents/
        # AAA/hero3d, live): its ground edge and teeth bright steel, a glowing blue core round the grip's hole
        colour = g.mix("MIX", g.math("MULTIPLY", g.smooth(r, 0.066, 0.071), 0.75), colour, (0.85, 0.92, 1.0))
        colour = g.mix("MIX", g.smooth(r, 0.0485, 0.0445), colour, CHAKRAM_CORE)
    if region == "scarf" and mode == "sunset" and BOLD and not flat:
        # (key art k8) a red shuka: a check of thin dark lines with a white line beside each, in the cloth's own light;
        # (k9, "two or three folds and a shade tone") two broad diagonal folds across it, each a darker trough
        # (key art k10, "the fine tartan check turns to noise at phone size: lumberjack flannel") bold red cloth: one
        # broad black stripe edged in white round it, and big folds, each a darker trough
        fold = g.math("SINE", g.math("MULTIPLY", g.math("ADD", sepr.outputs["Z"], g.math("MULTIPLY", sepr.outputs["Y"], 0.8)), 42.0))
        trough = g.smooth(fold, 0.2, 0.9)
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", trough, 0.6), colour, (0.5, 0.28, 0.38))
        # (key art k11, "a plain flat red wedge": k9's shuka check back at 2.5x its scale, black, white and blue lines)
        for ax, per in (("X", 15.0), ("Z", 15.0)):
            v = g.math("FRACT", g.math("MULTIPLY", sepr.outputs[ax], per))
            dark = g.smooth(g.math("ABSOLUTE", g.math("SUBTRACT", v, 0.5)), 0.42, 0.445)
            white = g.smooth(g.math("ABSOLUTE", g.math("SUBTRACT", v, 0.36)), 0.03, 0.018)
            blue = g.smooth(g.math("ABSOLUTE", g.math("SUBTRACT", v, 0.68)), 0.03, 0.018)
            colour = g.mix("MIX", white, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], SCARF_LINES[1]))
            colour = g.mix("MIX", blue, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], (0.02, 0.08, 0.4)))
            colour = g.mix("MIX", dark, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], SCARF_LINES[0]))
    if region == "hand" and mode == "sunset" and BOLD and not flat:
        # (key art k33) the back fist's finger breaks: a dark line where one finger meets the next and round the thumb
        att_f = g.node("ShaderNodeAttribute")
        att_f.attribute_name = "fist_gap"
        brk = g.math("MULTIPLY", g.smooth(att_f.outputs["Fac"], FIST_BREAK[0], FIST_BREAK[1]), g.smooth(sepr.outputs["Y"], 0.0, 0.01))
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", brk, 0.85), colour, FIST_BREAK_TONE)
    if region in ("skin", "hand") and mode == "sunset" and BOLD and not flat:
        # (key art k8) the gold armlet round each upper arm: a band across the arm, a bright line round its middle
        (c0, c1, c2), (d0, d1, d2) = ARM_AXIS
        ay = g.math("SUBTRACT", g.math("ABSOLUTE", sepr.outputs["Y"]), c1)
        t = g.math("ADD", g.math("ADD", g.math("MULTIPLY", g.math("SUBTRACT", sepr.outputs["X"], c0), d0),
                                 g.math("MULTIPLY", ay, d1)), g.math("MULTIPLY", g.math("SUBTRACT", sepr.outputs["Z"], c2), d2))
        band = g.math("MULTIPLY", g.smooth(t, -0.013, -0.011), g.smooth(t, 0.019, 0.017))  # (k11: wider)
        dx, dz = g.math("SUBTRACT", sepr.outputs["X"], c0), g.math("SUBTRACT", sepr.outputs["Z"], c2)
        r2 = g.math("SUBTRACT", g.math("ADD", g.math("ADD", g.math("MULTIPLY", dx, dx), g.math("MULTIPLY", ay, ay)),
                                        g.math("MULTIPLY", dz, dz)), g.math("MULTIPLY", t, t))
        band = g.math("MULTIPLY", band, g.smooth(r2, 0.0016, 0.0012))  # (only round the arm: within 4 cm of its axis)
        gold = g.mix("MIX", g.smooth(L, 0.16, 0.24), GOLD_SHADE, GOLD)  # its own two values: brown-gold, gold
        # (key art k10, "a sticky note or tape: no form, no metal highlight") brass wrapping the arm: darker as it turns
        # away, a dark line along both edges, one crisp highlight where it faces us
        gold = g.mix("MULTIPLY", g.math("MULTIPLY", g.smooth(edge, 0.2, 0.75), 0.75), gold, (0.3, 0.16, 0.05))
        colour = g.mix("MIX", band, colour, gold)
        # (key art k11, "a flat yellow band with no metal shading") metal: a dark core band below a sharp highlight, a dark
        # line along both edges
        core = g.math("MULTIPLY", band, g.math("MULTIPLY", g.smooth(t, 0.004, 0.006), g.smooth(t, 0.013, 0.011)))
        colour = g.mix("MIX", g.math("MULTIPLY", core, 0.85), colour, (0.16, 0.06, 0.01))
        rims = g.math("MULTIPLY", band, g.math("MAXIMUM", g.smooth(t, -0.009, -0.011), g.smooth(t, 0.015, 0.017)))
        colour = g.mix("MIX", rims, colour, (0.05, 0.02, 0.006))
        mid = g.math("MULTIPLY", band, g.smooth(g.math("ABSOLUTE", g.math("SUBTRACT", t, -0.002)), 0.0026, 0.0012))
        shine = g.math("MULTIPLY", mid, g.smooth(edge, 0.4, 0.1))
        colour = g.mix("MIX", g.math("MULTIPLY", shine, 0.95), colour, (1.0, 0.94, 0.75))
        # (key art k32, "a flat vertical gold rectangle stuck on the bicep like a plaster, no wrap-around") a band round the
        # cylinder: a bright lip just inside its shoulder-side edge where the light falls on it, and the small shadow it casts on
        # the skin past its elbow-side edge
        lip = g.math("MULTIPLY", g.math("MULTIPLY", band, g.math("MULTIPLY", g.smooth(t, -0.0092, -0.0082), g.smooth(t, -0.0058, -0.0068))),
                     g.smooth(L, 0.3, 0.5))
        colour = g.mix("MIX", g.math("MULTIPLY", lip, 0.9), colour, (1.0, 0.82, 0.42))
        near_arm = g.smooth(r2, 0.0016, 0.0012)
        cast = g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(t, 0.0172, 0.0186), g.smooth(t, 0.0252, 0.0238)), near_arm)
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", cast, 0.6), colour, (0.42, 0.36, 0.4))
    if region == "belt" and mode == "sunset" and BOLD and hem_d is None:
        # (key art k11, "the maroon shorts one flat block") folds across the cloth under the kilt
        fold_u = g.math("SINE", g.math("MULTIPLY", g.math("ADD", sepr.outputs["Z"], g.math("MULTIPLY", sepr.outputs["Y"], 0.6)), 55.0))
        under = g.smooth(height, 0.075, 0.065)
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(fold_u, 0.2, 0.9), under), 0.55), colour, (0.45, 0.3, 0.4))
    if region == "belt" and hem_d is not None:
        # (key art k27, "muddy smears") one clean fold across the thigh: a lens of shadow, pointed at both ends, crisp
        (fx0, fz0), (fx1, fz1) = WRAP_FOLD
        flen = ((fx1 - fx0) ** 2 + (fz1 - fz0) ** 2) ** 0.5
        ux, uz = (fx1 - fx0) / flen, (fz1 - fz0) / flen
        px_ = g.math("SUBTRACT", sepr.outputs["X"], fx0)
        pz_ = g.math("SUBTRACT", height, fz0)
        along = g.math("DIVIDE", g.math("ADD", g.math("MULTIPLY", px_, ux), g.math("MULTIPLY", pz_, uz)), flen)
        across = g.math("ABSOLUTE", g.math("SUBTRACT", g.math("MULTIPLY", pz_, ux), g.math("MULTIPLY", px_, uz)))
        half = g.math("MULTIPLY", g.math("SINE", g.math("MULTIPLY", g.math("MINIMUM", g.math("MAXIMUM", along, 0.0), 1.0), 3.14159)), WRAP_FOLD_W)
        fold = g.math("MULTIPLY", g.math("LESS_THAN", across, half), g.smooth(height, 0.0, -0.012))
        colour = g.mix("MULTIPLY", g.math("MULTIPLY", fold, 0.6), colour, (0.45, 0.3, 0.4))
        # the hem: a dark rolled edge where the cloth ends on the thigh
        hem = g.math("MULTIPLY", g.math("MULTIPLY", g.smooth(g.math("MULTIPLY", hem_d, -1.0), HEM_W, HEM_W * 0.8),
                                        g.math("LESS_THAN", hem_d, 0.0)), g.smooth(height, 0.0, -0.012))  # (0: no attribute)
        colour = g.mix("MIX", hem, colour, g.mix("MULTIPLY", 1.0, ramp.outputs["Color"], WRAP_HEM))
    if region == "belt" and BOLD and not flat:
        # (round 16) the belt carries the costume's pattern: a white zigzag round it, a row of blue beads under it
        ang_b = g.math("ARCTAN2", sepr.outputs["Y"], sepr.outputs["X"])
        tri = g.math("ABSOLUTE", g.math("SUBTRACT", g.math("FRACT", g.math("MULTIPLY", ang_b, 9.0 / 6.2832)), 0.5))
        zig = g.math("ADD", 0.112, g.math("MULTIPLY", tri, 0.03))
        line = g.smooth(g.math("ABSOLUTE", g.math("SUBTRACT", height, zig)), 0.0042, 0.0026)
        colour = g.mix("MIX", line, colour, BELT_WHITE)
        bead = g.math("MULTIPLY", g.smooth(g.math("SINE", g.math("MULTIPLY", ang_b, 36.0)), 0.55, 0.8),
                      g.math("MULTIPLY", g.smooth(height, 0.088, 0.092), g.smooth(height, 0.1, 0.096)))
        colour = g.mix("MIX", bead, colour, BELT_BEAD)
    if region in ("armour_blue", "armour_silver"):
        # scuffs and dust: low, broken value changes (wear), matte
        wear = g.noise(P, (22.0, 22.0, 22.0), 1.5, 0.5)
        w = g.math("ADD", g.math("MULTIPLY", g.smooth(wear, 0.45, 0.75), 0.05), 0.975)  # (round 14: matte, barely worn)
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(w))
        # crisp glints where the key reflects, broken by the wear (painted metal, not plastic)
        gl = g.node("ShaderNodeBsdfGlossy", Roughness=0.16)
        g.link(N, gl.inputs["Normal"])
        s2g = g.node("ShaderNodeShaderToRGB")
        g.link(gl.outputs[0], s2g.inputs[0])
        gbw = g.node("ShaderNodeRGBToBW")
        g.link(s2g.outputs["Color"], gbw.inputs[0])
        glint = g.math("MULTIPLY", g.smooth(gbw.outputs[0], 0.9, 1.4), g.smooth(wear, 0.62, 0.38))
        k = (0.45 if region == "armour_silver" else 0.3) * (1.0 if mode == "day" else 0.8) * ARMOUR_GLINT
        colour = g.mix("ADD", g.math("MULTIPLY", glint, k), colour, (1.0, 0.95, 0.86))
        if mode == "sunset" and BOLD and not flat:  # (key art k7) the foot's leather glossy, the guard matte
            shine = g.math("MULTIPLY", g.smooth(gbw.outputs[0], 1.75, 1.95), g.smooth(height, -0.405, -0.415))
            colour = g.mix("ADD", g.math("MULTIPLY", shine, 0.12), colour, (0.8, 0.85, 1.0))  # (k11: matte, one small highlight)
    # a soft sheen on the sun side (skin, the scarf's silk, the belt's leather)
    if region in SHEEN_K and not BOLD:
        gl = g.node("ShaderNodeBsdfGlossy", Roughness=0.32)
        g.link(N, gl.inputs["Normal"])
        s2g = g.node("ShaderNodeShaderToRGB")
        g.link(gl.outputs[0], s2g.inputs[0])
        gbw = g.node("ShaderNodeRGBToBW")
        g.link(s2g.outputs["Color"], gbw.inputs[0])
        sheen = g.math("MULTIPLY", g.smooth(gbw.outputs[0], 2.2, 3.4), LIGHT[mode][4] * SHEEN_K[region] * 0.8 * LOOK[mode][3])
        colour = g.mix("ADD", sheen, colour, (1.0, 0.88, 0.72))
    # the cool bounce: front faces in shade (their centres, never the silhouette)
    rim_c, rim_k, b_c, b_k, _ = LIGHT[mode]
    if region not in ("eye", "hair") and not BOLD:
        front = g.math("POWER", facing, 2.0)
        b = g.math("MULTIPLY", g.math("MULTIPLY", g.math("SUBTRACT", 1.0, lit_k), front), b_k)
        colour = g.mix("ADD", b, colour, b_c)
    # (round 14, the judges' own fix: "tint his shadow side with the scene's purple, a warm rim only on the sun side,
    # a dark ink outline so he sits inside the world") his shade takes the savanna's evening purple, its value kept
    tint_k = DAY_PURPLE_K if mode == "day" else UI_MAGENTA_K
    if BOLD and not flat and region not in ("eye", "hair") and tint_k > 0.0:
        lum_c = g.node("ShaderNodeRGBToBW")
        g.link(colour, lum_c.inputs[0])
        tint = g.mix("MULTIPLY", 1.0, g.grey(lum_c.outputs[0]), DAY_PURPLE if mode == "day" else UI_MAGENTA)
        shade_k = g.math("MULTIPLY", g.smooth(L, BOLD_STOPS[2], BOLD_STOPS[1]), tint_k)
        colour = g.mix("MIX", shade_k, colour, tint)
    if BOLD and not flat and region != "eye":  # (round 15) the light falls off towards his boots
        dim = g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.smooth(height, 0.1, -0.45), FEET_DIM))
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(dim))
    # the thick hot rim: lit edges only (the sun's side of the silhouette)
    rk = rim_k * RIM_K.get(region, 1.0)
    if BOLD and RIM_K.get(region, 1.0) > 0:
        bc, bk, sd = BOLD_RIM[mode]
        if m.get("rim"):  # (round 9) the material's own rim colour and strength (the bandit's cold rim)
            bc, bk = tuple(m["rim"]), m.get("rim_k", bk)
        toward = g.math("ADD", g.math("MULTIPLY", sep.outputs["X"], sd[0]), g.math("MULTIPLY", sep.outputs["Y"], sd[1]))
        toward = g.math("MULTIPLY", g.smooth(toward, 0.0, 0.45) if mode == "sunset" else g.smooth(toward, -0.1, 0.6),
                        1.0 if mode == "sunset" else 0.7)
        if mode == "sunset":
            toward = g.math("ADD", g.math("MULTIPLY", toward, 1.0 - UI_RIM_BACK), UI_RIM_BACK)
        e = g.smooth(edge, 0.16, 0.3) if mode == "sunset" else g.smooth(edge, 0.5, 0.62)  # a band, crisp-edged (cel),
        # (key art k7: 0.26-0.4, "the rim isn't reading at phone size": wider)
        # on the silhouette's edges (round 17: thicker in the pictures, "a rim that reads at phone size")
        rk_r = RIM_K_SUNSET.get(region, RIM_K.get(region, 1.0)) if mode == "sunset" else RIM_K.get(region, 1.0)
        rim = g.math("MULTIPLY", g.math("MULTIPLY", e, toward), bk * min(rk_r * 1.3, 1.0))
        if mode == "sunset" and BOLD and region in ("armour_blue", "armour_silver"):  # (k7) the dark leather feet keep
            rim = g.math("MULTIPLY", rim, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", g.smooth(height, -0.405, -0.415), 0.55)))  # their value
        colour = g.mix("MIX", rim, colour, bc if region != "hair" else tuple(x * 0.55 for x in bc))
        rk = 0
    if rk > 0:
        e = g.smooth(edge, 0.42 if mode == "sunset" else 0.62, 0.72 if mode == "sunset" else 0.86)
        rim = g.math("MULTIPLY", g.math("MULTIPLY", e, g.smooth(L, 0.2, 0.42)), rk)
        rc = rim_c if region != "hair" else tuple(x * 0.7 for x in rim_c)
        colour = g.mix("ADD", rim, colour, rc)
    em = g.node("ShaderNodeEmission")
    g.link(colour, em.inputs["Color"])
    g.link(em.outputs[0], out.inputs["Surface"])
    if region == "fur":  # the stepped fur edge: tufts pushed out along the normal (both faces: thickness)
        tuft = g.noise(P, (28.0, 28.0, 5.0), 1.0, 0.35)
        disp = g.node("ShaderNodeDisplacement", Midlevel=0.4, Scale=0.0 if (mode == "sunset" and BOLD) else 0.006)  # (round 17: thick tufts, "printer paper"; key art k9: none in the pictures, a clean edge)
        g.link(tuft, disp.inputs["Height"])
        g.link(disp.outputs[0], out.inputs["Displacement"])
        m.displacement_method = "DISPLACEMENT"
    else:
        m.displacement_method = "BUMP"
    m["aaa_mode"] = mode
    return True


def build_all(objects, mode="day"):
    done = set()
    for ob in objects:
        if ob.type != "MESH":
            continue
        for m in ob.data.materials:
            if m and m.name not in done and m.get("toon"):
                build(m, mode)
                done.add(m.name)
    return sorted(done)
