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
# (pass 4) "bold": two clear cel bands with a crisp terminator, the rim on the back edges (screen space, the
# sun's side strongest), no bounce or sheen on the skin, flat red scarf, deeper blue armour: the UI's toy-like
# language ("semi-realistic anatomy with fine muscle rendering ... pasted in from another game")
import os as _os
BOLD = _os.environ.get("HERO_TOON", "bold") == "bold"
BOLD_BANDS = {  # shade, lit (albedo multipliers; hair: absolute)
    "day": {"skin": ((0.6, 0.47, 0.5), (1.08, 0.98, 0.88)), "face": ((0.72, 0.58, 0.58), (1.1, 1.0, 0.9)),
            "hand": ((0.64, 0.5, 0.52), (1.08, 0.98, 0.88)), "hair": ((0.004, 0.0035, 0.004), (0.016, 0.012, 0.011)),
            "fur": ((0.5, 0.43, 0.42), (0.74, 0.68, 0.58)), "armour_blue": ((0.5, 0.48, 0.62), (0.9, 0.9, 0.92)),
            "armour_silver": ((0.4, 0.38, 0.42), (0.64, 0.6, 0.54)), "scarf": ((0.42, 0.24, 0.32), (1.05, 0.98, 0.92)),
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
_LIFT = float(_os.environ.get("HERO_LIT_LIFT", "1.3"))
DAY_LIT = {r: (_LIFT * 1.04, _LIFT, _LIFT * 0.9) for r in ("skin", "face", "hand")}
BOLD_STOPS = (0.0, 0.155, 0.185, 1.0)
## (round 12, "the key art below the UI in finish: skin blotchy, orange-to-brown patches with hard muddy transitions;
## the face small, dark, blank; the ring a flat grey donut") the interface pictures (sunset): the skin and hands one
## clean colour (the albedo's mean; the face keeps its painted features), a warm shade (not a muddy purple-brown) and
## a slightly softer step, the face lit, the steel ring dark at its core and bright on its polish
UI_FLAT = {"skin": (0.305, 0.0864, 0.0298), "hand": (0.305, 0.0864, 0.0298),
           "armour_blue": (0.0175, 0.069, 0.343), "armour_silver": (0.36, 0.33, 0.29)}  ## (round 14: flat, "mottled noise on the boots")  ## (linear: the albedo picture's mean skin, sRGB (0.588, 0.325, 0.189))
UI_BANDS = {"skin": ((0.62, 0.4, 0.33), (1.12, 0.93, 0.78)), "hand": ((0.64, 0.42, 0.35), (1.12, 0.93, 0.78)),
            "face": ((0.84, 0.66, 0.58), (1.16, 0.98, 0.85)), "chakram": ((0.12, 0.15, 0.3), (1.3, 1.3, 1.36)),
            "fur": ((0.56, 0.44, 0.38), (0.8, 0.7, 0.56))}  ## (round 13: the loincloth warm white, "flat grey")
## (round 15, "the white loincloth and the white/blue boots are the brightest shapes: they pull the eye to the crotch
## and the feet; keep the brightest values on the face and chest") the whites a warm off-white, a value lower
DAY_PURPLE = (1.556, 0.717, 2.185)  ## the savanna's evening purple (sRGB (0.6, 0.42, 0.7)) at a luminance of 1 (linear)
DAY_PURPLE_K = 0.35  ## how far his shade turns to it in the level (round 14)
UI_MAGENTA = (2.46, 0.61, 0.54)  ## the sunset's warm rose (sRGB (0.85, 0.45, 0.42)) at a luminance of 1 (linear)
UI_MAGENTA_K = 0.3  ## (round 14: "a touch of sunset magenta in his shadows"; round 15, "the sun right behind him, yet no
## warm tint": the sky's warmth in his shade)
UI_FACE_LIFT = 0.22
ARMOUR_GLINT = 0.0  ## (round 14, "glossy blue-and-white plastic boots with hard speculars"): matte, like the skin  ## (round 13, "the face lost in shadow under the hair") light added to the face in the pictures
UI_STOPS = (0.0, 0.14, 0.2, 1.0)  ## the terminator: a crisp step (a pixel or two of softening)
BOLD_RIM = {"day": ((1.0, 0.33, 0.08), 0.6, (-0.6, 0.8)), "sunset": ((1.0, 0.3, 0.06), 1.0, (-0.6, 0.7))}
## (round 15, "a paler band just inside the outline": the rim was a pale peach, sRGB (1, 0.81, 0.58)) a hot orange,
## sRGB (1, 0.6, 0.31) and (1, 0.58, 0.27)
UI_RIM_BACK = 0.45  ## (round 15, "the sun directly behind his chest, yet no rim") in the pictures the sun is behind
## him: the rim on every edge at this share, on the edges towards the sun in full
SOFT_STOPS = {"day": (0.0, 0.11, 0.26, 1.0), "sunset": (0.0, 0.1, 0.28, 1.0)}  ## (round 15, "abs and chest cut in
## with dark lines of equal strength, muscles printed on": the skin's terminator a soft blend, not a step)
SOFT_REGIONS = ("skin", "hand")
DAY_FLAT_K = 0.55  ## (round 15) how far the skin's painted albedo goes to its mean colour in the level (no drawn lines)
CHEST_LIFT = 0.1  ## (round 15, "keep the brightest values on the face and chest") light added to his chest and face
FACE_FRAME = (-0.085, 0.28, 0.17)  ## (round 15) the drawn face's frame in the rest shape: the y and z of its lower left
## corner and its span (tools/art/hero_face.py; m["decal"]: the expression's picture, over the face's own colours)
BOOT_CREAM = (0.5, 0.42, 0.3)  ## linear: the boots' white parts as cream leather, sRGB (0.74, 0.69, 0.59)
BOOT_CORD = (0.09, 0.045, 0.022)  ## the cords crossing them, a dark brown
BOOT_BRASS = (0.45, 0.27, 0.06)  ## the band at their top
BOOT_SOLE = (0.05, 0.025, 0.013)  ## a dark leather sole (no white sneaker sole)
BOOT_WRAPS = 150.0  ## radians of the cords' wind per rest unit of height (about six crossings up the boot)
CHAKRAM_CORE = (0.35, 0.85, 1.0)  ## linear: the glow round the chakram's grip, the throw trail's cold light
FEET_DIM = 0.18  ## and how much darker everything is at his boots (rest height: -0.5 his soles, 0.5 his hair)
## (round 13, "a pale outline glow rings the hero" on every interface picture: the sunset rim lay on every edge (a 0.3
## floor); now only on the edges towards the sun, upper left as in the level: a rim against the sky, not a halo)
## (sunset: the key lights him from the front-left, the sun's hot rim takes the other edges, upper right)
BOLD_ALBEDO = {"scarf": (0.5, 0.02, 0.015), "armour_blue": None}  ## flat linear colours (scarf: no blotches)
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
SHEEN_K = {"skin": 1.0, "face": 0.7, "hand": 0.8, "scarf": 0.45, "belt": 0.8}
AO = {"hair": (0.06, 0.9), "fur": (0.06, 0.85), "armour_blue": (0.02, 0.45), "armour_silver": (0.02, 0.45),
      "scarf": (0.03, 0.45), "belt": (0.02, 0.4), }
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
    elif BOLD and mode == "sunset" and region in UI_FLAT:  # (round 12) the interface pictures' skin: one clean colour
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
    if nm_img is not None and region in NORMAL_MAP:
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
    # the light (key and fill, with cast shadows) as one value
    dif = g.node("ShaderNodeBsdfDiffuse", Color=(1, 1, 1, 1))
    g.link(N, dif.inputs["Normal"])
    s2r = g.node("ShaderNodeShaderToRGB")
    g.link(dif.outputs[0], s2r.inputs[0])
    bw = g.node("ShaderNodeRGBToBW")
    g.link(s2r.outputs["Color"], bw.inputs[0])
    L = bw.outputs[0]
    if region == "fur":  # strands: the light itself broken along them (a stepped terminator)
        strand = g.noise(P, (38.0, 38.0, 4.0), 1.0, 0.4)  # (round 14: tufts, not scratchy strands)
        L = g.math("ADD", L, g.math("MULTIPLY", g.math("SUBTRACT", strand, 0.5), 0.18))
    if region == "face" and mode == "sunset":  # (round 13) out of the hair's shadow
        L = g.math("ADD", L, UI_FACE_LIFT)
    sepr = g.node("ShaderNodeSeparateXYZ")
    g.link(P, sepr.inputs[0])
    height = sepr.outputs["Z"]  # (rest shape: -0.5 at his soles, 0.5 at the top of his hair)
    if BOLD and not flat and region in ("skin", "face", "hand"):  # (round 15) his chest and face in the most light
        L = g.math("ADD", L, g.math("MULTIPLY", g.smooth(height, 0.0, 0.3), CHEST_LIFT))
    if region == "hair":  # the locks: their own terminator, broken per lock (round 15: big locks, "a fuzzy helmet")
        lock = g.noise(P, (16.0, 16.0, 16.0), 0.0, 0.4)
        L = g.math("ADD", L, g.math("MULTIPLY", g.math("SUBTRACT", lock, 0.5), 0.3))
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
        if not flat and region in SOFT_REGIONS:
            stops = SOFT_STOPS[mode]
        cols = (sh, sh, li, li)
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
            if region == "armour_silver":
                alb = g.mix("MIX", boot, alb, BOOT_CREAM)
                c1 = g.math("SINE", g.math("ADD", wind, g.math("MULTIPLY", ang, 3.0)))
                c2 = g.math("SINE", g.math("SUBTRACT", wind, g.math("MULTIPLY", ang, 3.0)))
                cord = g.math("MAXIMUM", g.smooth(c1, 0.86, 0.95), g.smooth(c2, 0.86, 0.95))
                alb = g.mix("MIX", g.math("MULTIPLY", cord, boot), alb, BOOT_CORD)
            else:
                strip = g.smooth(g.math("SINE", g.math("ADD", g.math("MULTIPLY", wind, 0.5), g.math("MULTIPLY", ang, 1.0))), 0.55, 0.75)
                alb = g.mix("MULTIPLY", g.math("MULTIPLY", g.math("MULTIPLY", strip, boot), 0.35), alb, (0.55, 0.6, 0.75))
            band = g.math("MULTIPLY", g.smooth(height, -0.252, -0.246), g.smooth(height, -0.226, -0.232))
            alb = g.mix("MIX", band, alb, BOOT_BRASS)
            alb = g.mix("MIX", g.smooth(height, -0.466, -0.476), alb, BOOT_SOLE)
        if region == "fur":
            alb = g.mix("MULTIPLY", 1.0, albedo, (1.0, 0.97, 0.9))  # warm cream, never grey paper
        sat, desat, cool, _ = LOOK[mode]
        if region in SAT_REGIONS:
            lum = g.node("ShaderNodeRGBToBW")
            g.link(alb, lum.inputs[0])
            grey = g.grey(lum.outputs[0])
            # in the light: a little more saturated; in the shade: greyer and cooler (no flat orange)
            lit_s = g.mix("MIX", sat, grey, alb)
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
    # occlusion: the locks parted, the fur's folds, the armour's seams
    if region in AO:
        dist, k = AO[region]
        ao = g.node("ShaderNodeAmbientOcclusion", Distance=dist)
        ao.samples = 16
        ao.only_local = True
        g.link(N, ao.inputs["Normal"])
        occ = g.math("ADD", g.math("MULTIPLY", ao.outputs["AO"], k), 1.0 - k)
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(occ))
    if region == "fur":
        # strands in value, darker roots under the belt and a darker underside
        strand2 = g.noise(P, (60.0, 60.0, 5.0), 1.0, 0.4)
        clump = g.noise(P, (24.0, 24.0, 2.5), 1.0, 0.35)  # tufts: big clumps, readable small (round 14: "scratchy dry-brush")
        v = g.math("ADD", g.math("MULTIPLY", strand2, 0.12), 0.88)
        v = g.math("MULTIPLY", v, g.math("ADD", g.math("MULTIPLY", g.smooth(clump, 0.42, 0.5), 0.24), 0.8))
        sepw = g.node("ShaderNodeSeparateXYZ")
        g.link(geo.outputs["Normal"], sepw.inputs[0])
        under = g.math("MULTIPLY", g.smooth(sepw.outputs["Z"], 0.15, -0.5), 0.4)
        sepp = g.node("ShaderNodeSeparateXYZ")
        g.link(P, sepp.inputs[0])
        root = g.math("MULTIPLY", g.smooth(sepp.outputs["Z"], 0.0, 0.075), 0.14)
        v = g.math("MULTIPLY", v, g.math("SUBTRACT", 1.0, g.math("ADD", under, root)))
        colour = g.mix("MULTIPLY", 1.0, colour, g.grey(v))
    if region == "hair":
        # a broken highlight band (an angel ring split into strand groups), only in the light
        off = g.math("MULTIPLY", g.math("SUBTRACT", g.noise(P, (70.0, 70.0, 70.0), 2.0, 0.5), 0.5), 0.5)
        y = g.math("ADD", sep.outputs["Y"], off)
        band = g.math("MULTIPLY", g.smooth(y, 0.18, 0.34), g.smooth(y, 0.62, 0.46))
        band = g.math("MULTIPLY", band, g.math("ADD", g.math("MULTIPLY", lit_k, 0.7), 0.3))
        # (round 15, all three judges: "grey, silver-blue: reads aged") black hair: a warm band of light across the
        # big locks (sRGB (0.42, 0.27, 0.17) at its brightest), no blue-grey sheen, no grey third step
        locks = g.smooth(g.noise(P, (16.0, 16.0, 16.0), 0.0, 0.4), 0.4, 0.6)
        band = g.math("MULTIPLY", band, g.math("ADD", g.math("MULTIPLY", locks, 0.7), 0.3))
        colour = g.mix("ADD", g.math("MULTIPLY", band, 0.5), colour, (0.15, 0.06, 0.022))
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
        toward = g.math("MULTIPLY", g.smooth(toward, -0.1, 0.6), 1.0 if mode == "sunset" else 0.7)
        if mode == "sunset":
            toward = g.math("ADD", g.math("MULTIPLY", toward, 1.0 - UI_RIM_BACK), UI_RIM_BACK)
        e = g.smooth(edge, 0.5, 0.62)  # a band, crisp-edged (cel), on the silhouette's edges
        rim = g.math("MULTIPLY", g.math("MULTIPLY", e, toward), bk * min(RIM_K.get(region, 1.0) * 1.3, 1.0))
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
        disp = g.node("ShaderNodeDisplacement", Midlevel=0.4, Scale=0.0035)
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
