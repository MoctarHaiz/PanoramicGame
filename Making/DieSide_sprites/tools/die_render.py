"""Renders the hero's death (4_Die, action mixamo.com.003) from the user's Making/Animation.blend as data
passes for a cel-shaded repaint (tools/toon_paint.py). The .blend is only read, never saved.

Passes, one PNG per frame in OUT/<pass>/NNNN.png (all 8-bit, transparent background):
  albedo  the model's painted colours, unlit
  light   white clay lit by three coloured lights, one per channel: R = key sun (upper left, in front,
          shadows on), G = fill (from the camera, soft, no shadows), B = rim sun (upper right, behind)
  normal  camera-space normal (x right, y up, z towards the camera), * 0.5 + 0.5
  misc    R = depth (0 near .. 1 far, over the hero's range), G = ambient occlusion

Usage:
  Blender -b Making/Animation.blend --python tools/die_render.py -- --out DIR [--frames 1,6,9] \
      [--size 1024] [--camera side|video] [--passes albedo,light,normal,misc] [--mirror-lights]

--mirror-lights puts the key on the right and the rim on the left: for frames that will be flipped
(the game shows this death mirrored, falling back to the left, with its sun on the left).
OUT/points.json: per frame, where the hips, head, toes and hands fall (render px, y down), and the
world origin (the ground under his hips at rest): what tools/art/hero_atlas.py reads.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGS:
        i = ARGS.index(name)
        return ARGS[i + 1]
    return default


OUT = arg("--out", "/tmp/die_render")
SIZE = int(arg("--size", "1024"))
FRAMES = [int(f) for f in arg("--frames", "1,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,60,78").split(",")]
PASSES = arg("--passes", "albedo,light,normal,misc").split(",")
CAMERA = arg("--camera", "side")
MIRROR = "--mirror-lights" in ARGS

SC = bpy.context.scene
ARM = bpy.data.objects["4_Die"]
MESH = next(o for o in ARM.children if o.type == "MESH")
MAT = MESH.data.materials[0]

# ------------------------------------------------------------------ scene
for ob in bpy.data.objects:
    if ob.type in ("MESH", "ARMATURE"):
        ob.hide_render = ob not in (ARM, MESH)
    if ob.type == "LIGHT":
        ob.hide_render = True  # the user's lights: replaced by the three pass lights
r = SC.render
r.engine = "BLENDER_EEVEE"
r.resolution_x = r.resolution_y = SIZE
r.resolution_percentage = 100
r.film_transparent = True
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
r.image_settings.color_depth = "8"
SC.view_settings.view_transform = "Standard"  # the passes are data: no tone mapping
SC.view_settings.look = "None"
SC.view_settings.exposure = 0.0
SC.view_settings.gamma = 1.0
SC.eevee.taa_render_samples = 16
if SC.world:
    bg = SC.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Strength"].default_value = 0.0  # no world light: only the pass lights count

cam = bpy.data.objects["Cam_Side"]
SC.camera = cam
if CAMERA == "video":
    # the DieSide capture was a perspective viewport a little in front of the side camera
    cam.data.type = "PERSP"
    cam.data.lens = float(arg("--lens", "50"))

# ------------------------------------------------------------------ lights (one per channel)
cm = cam.matrix_world.to_3x3()
RIGHT, UP, BACK = cm.col[0].normalized(), cm.col[1].normalized(), cm.col[2].normalized()  # BACK: towards the camera


def sun(name, colour, toward_light, strength, shadow=True, angle=0.05):
    d = bpy.data.lights.new(name, "SUN")
    d.color = colour
    d.energy = strength
    d.angle = angle
    d.use_shadow = shadow
    ob = bpy.data.objects.new(name, d)
    SC.collection.objects.link(ob)
    ob.rotation_euler = (-toward_light).to_track_quat("-Z", "Y").to_euler()  # the sun shines along its -Z
    return ob


SIDE = -1.0 if MIRROR else 1.0
KEY_DIR = (-0.55 * SIDE * RIGHT + 0.65 * UP + 0.55 * BACK).normalized()
FILL_DIR = (0.15 * UP + 1.0 * BACK).normalized()
RIM_DIR = (0.75 * SIDE * RIGHT + 0.45 * UP - 0.5 * BACK).normalized()
# a sun of strength s on white diffuse facing it gives s / pi... here strength pi -> 1.0 at full facing
sun("PassKey", (1.0, 0.0, 0.0), KEY_DIR, math.pi)
sun("PassFill", (0.0, 1.0, 0.0), FILL_DIR, math.pi, shadow=False)
sun("PassRim", (0.0, 0.0, 1.0), RIM_DIR, math.pi)

# ------------------------------------------------------------------ pass materials (built on the user's)
nt = MAT.node_tree
N = nt.nodes
L = nt.links
bsdf = next(n for n in N if n.type == "BSDF_PRINCIPLED")
out = next(n for n in N if n.type == "OUTPUT_MATERIAL")
base_link = bsdf.inputs["Base Color"].links[0]
base_socket = base_link.from_socket
nmap = next((n for n in N if n.type == "NORMAL_MAP"), None)
if nmap:
    nmap.inputs["Strength"].default_value = 0.55
normal_socket = nmap.outputs["Normal"] if nmap else None


def node(kind, **inputs):
    n = N.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def emit(socket):
    e = node("ShaderNodeEmission", Strength=1.0)
    L.new(socket, e.inputs["Color"])
    return e.outputs["Emission"]


# albedo
albedo_out = emit(base_socket)
# light: white diffuse -> shader to rgb (EEVEE) -> emission
dif = node("ShaderNodeBsdfDiffuse", Color=(1, 1, 1, 1))
if normal_socket:
    L.new(normal_socket, dif.inputs["Normal"])
s2r = N.new("ShaderNodeShaderToRGB")
L.new(dif.outputs["BSDF"], s2r.inputs["Shader"])
light_out = emit(s2r.outputs["Color"])
# normal: camera space
geo = N.new("ShaderNodeNewGeometry")
vt = N.new("ShaderNodeVectorTransform")
vt.vector_type = "NORMAL"
vt.convert_from = "WORLD"
vt.convert_to = "CAMERA"
L.new(normal_socket if normal_socket else geo.outputs["Normal"], vt.inputs["Vector"])
mul = N.new("ShaderNodeVectorMath")
mul.operation = "MULTIPLY_ADD"
mul.inputs[1].default_value = (0.5, 0.5, -0.5)  # camera space looks down -z: flip z so towards the camera is +
mul.inputs[2].default_value = (0.5, 0.5, 0.5)
L.new(vt.outputs["Vector"], mul.inputs[0])
normal_out = emit(mul.outputs["Vector"])
# misc: R depth, G ambient occlusion
camd = N.new("ShaderNodeCameraData")
mr = N.new("ShaderNodeMapRange")
mr.inputs["From Min"].default_value = 0.6
mr.inputs["From Max"].default_value = 1.8
L.new(camd.outputs["View Z Depth"], mr.inputs["Value"])
ao = N.new("ShaderNodeAmbientOcclusion")
ao.inputs["Distance"].default_value = 0.035
if normal_socket:
    L.new(normal_socket, ao.inputs["Normal"])
comb = N.new("ShaderNodeCombineColor")
L.new(mr.outputs["Result"], comb.inputs["Red"])
L.new(ao.outputs["AO"], comb.inputs["Green"])
misc_out = emit(comb.outputs["Color"])

OUTS = {"albedo": albedo_out, "light": light_out, "normal": normal_out, "misc": misc_out}


def use(pass_name):
    for lk in list(out.inputs["Surface"].links):
        L.remove(lk)
    L.new(OUTS[pass_name], out.inputs["Surface"])
    for ob in bpy.data.objects:
        if ob.name.startswith("Pass") and ob.type == "LIGHT":
            ob.hide_render = pass_name != "light"


# ------------------------------------------------------------------ render
ARM.animation_data.action = bpy.data.actions["mixamo.com.003"]
ad = ARM.animation_data
if hasattr(ad, "action_slot") and ad.action_slot is None and len(ad.action.slots):
    ad.action_slot = ad.action.slots[0]
from bpy_extras.object_utils import world_to_camera_view

POINTS = {"hips": "Hips", "head": "HeadTop_End", "toe_r": "RightToe_End", "toe_l": "LeftToe_End",
          "hand_r": "RightHand", "hand_l": "LeftHand"}


def project(co):
    v = world_to_camera_view(SC, cam, co)
    return [round(v.x * SIZE, 2), round((1.0 - v.y) * SIZE, 2)]


for p in PASSES:
    os.makedirs(os.path.join(OUT, p), exist_ok=True)
pts = {"view": "side", "size": SIZE, "origin": project(Vector((0.0, 0.0, 0.0))), "frames": []}
for f in FRAMES:
    SC.frame_set(f)
    bpy.context.view_layer.update()
    pts["frames"].append({k: project(ARM.matrix_world @ ARM.pose.bones["mixamorig:" + b].head) for k, b in POINTS.items()})
    for p in PASSES:
        use(p)
        r.filepath = os.path.join(OUT, p, f"{f:04d}.png")
        bpy.ops.render.render(write_still=True)
    print("frame", f, "done", flush=True)
pts["source_frames"] = FRAMES
with open(os.path.join(OUT, "points.json"), "w") as fh:
    json.dump(pts, fh, indent=1)
