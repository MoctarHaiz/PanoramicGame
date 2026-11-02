"""Panoramic's throwing ring in 3D, lit like him (tools/art/blender/hero_render.py): a thick torus of
blue-steel with a glowing inner edge, rendered turning about its vertical axis (face-on, then
edge-on) so the game can spin it as it flies. Writes 8 frames, 192 px each, side by side.

Usage:
  Blender -b --factory-startup --python tools/art/blender/ring_render.py -- --out FILE.png
"""
import math
import os
import sys
import tempfile

import bpy
import numpy as np

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else "/tmp/ring_spin.png"
FRAMES = 8
SIZE = 192

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Punchy"
sc.eevee.taa_render_samples = 64

world = bpy.data.worlds.new("Sky")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.58, 0.85, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
sc.world = world

bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.24, major_segments=96, minor_segments=32)
ring = bpy.context.object
bpy.ops.object.shade_smooth()
ring.rotation_euler = (math.radians(90), 0, 0)  # face the camera (looking along +Y)

mat = bpy.data.materials.new("RingSteel")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
bsdf = nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.1, 0.42, 1.0, 1)
bsdf.inputs["Metallic"].default_value = 0.85
bsdf.inputs["Roughness"].default_value = 0.22
# the inner edge glows: emission by how close the surface is to the ring's axis (object space)
geo = nodes.new("ShaderNodeNewGeometry")
sep = nodes.new("ShaderNodeSeparateXYZ")
tex = nodes.new("ShaderNodeTexCoord")
links.new(tex.outputs["Object"], sep.inputs["Vector"])
length = nodes.new("ShaderNodeVectorMath")
length.operation = "LENGTH"
comb = nodes.new("ShaderNodeCombineXYZ")
links.new(sep.outputs["X"], comb.inputs["X"])
links.new(sep.outputs["Y"], comb.inputs["Y"])
links.new(comb.outputs["Vector"], length.inputs[0])
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.84
ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
ramp.color_ramp.elements[1].position = 0.98
ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
links.new(length.outputs["Value"], ramp.inputs["Fac"])
bsdf.inputs["Emission Color"].default_value = (0.35, 0.8, 1.0, 1)
gain = nodes.new("ShaderNodeMath")
gain.operation = "MULTIPLY"
gain.inputs[1].default_value = 6.0
links.new(ramp.outputs["Color"], gain.inputs[0])
links.new(gain.outputs["Value"], bsdf.inputs["Emission Strength"])
ring.data.materials.append(mat)

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.7
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
cam.location = (0, -5, 0)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam


def sun(name, colour, strength, direction):
    data = bpy.data.lights.new(name, "SUN")
    data.color = colour
    data.energy = strength
    ob = bpy.data.objects.new(name, data)
    sc.collection.objects.link(ob)
    from mathutils import Vector
    ob.rotation_euler = (-Vector(direction)).normalized().to_track_quat("-Z", "Y").to_euler()


# as on the hero: the game's sun from the upper left behind, a white front light, a warm bounce
sun("Key", (1.0, 1.0, 1.0), 2.5, (-0.4, -0.8, 0.5))
sun("Rim", (1.0, 0.78, 0.5), 4.0, (-0.7, 0.6, 0.6))
sun("Bounce", (0.85, 0.65, 0.35), 0.8, (0.2, -0.3, -1.0))

tmp = tempfile.mkdtemp()
strip = np.zeros((SIZE, SIZE * FRAMES, 4), np.float32)
for i in range(FRAMES):
    # a half turn about the vertical axis (the torus is symmetric: 180 degrees loops)
    ring.rotation_euler = (math.radians(90), 0, math.radians(180.0 * i / FRAMES))
    path = os.path.join(tmp, f"{i}.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], np.float32).reshape(SIZE, SIZE, 4)[::-1]
    strip[:, i * SIZE:(i + 1) * SIZE] = px
out = bpy.data.images.new("strip", SIZE * FRAMES, SIZE, alpha=True)
out.pixels = strip[::-1].ravel()
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("RING", OUT)
