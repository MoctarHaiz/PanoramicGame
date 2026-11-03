"""The Red Bob's ball in 3D, lit like Panoramic (tools/art/blender/hero_render.py): glossy red with a
clear coat, a warm rim from the game's sun (upper left, behind), a white front light, a warm bounce
from below. The faces are drawn on it afterwards by tools/art/bob_sheet.py.

Usage:
  Blender -b --factory-startup --python tools/art/blender/bob_render.py -- --out FILE.png
"""
import math
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else "/tmp/bob_ball.png"
SIZE = 512

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.render.film_transparent = True
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Punchy"
sc.view_settings.exposure = 0.35
sc.eevee.taa_render_samples = 64
world = bpy.data.worlds.new("Sky")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.58, 0.85, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
sc.world = world

bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=96, ring_count=48)
ball = bpy.context.object
ball.scale = (1.0, 1.0, 0.97)
bpy.ops.object.shade_smooth()
mat = bpy.data.materials.new("RedBob")
mat.use_nodes = True
b = mat.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.95, 0.012, 0.004, 1)
b.inputs["Roughness"].default_value = 0.32
b.inputs["Coat Weight"].default_value = 0.7
b.inputs["Coat Roughness"].default_value = 0.05
b.inputs["Subsurface Weight"].default_value = 0.0
b.inputs["Subsurface Radius"].default_value = (1.0, 0.2, 0.1)
ball.data.materials.append(mat)

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.25
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
cam.location = (0, -5, 0)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam


def sun(name, colour, strength, direction):
    data = bpy.data.lights.new(name, "SUN")
    data.color = colour
    data.energy = strength
    data.angle = math.radians(6)
    ob = bpy.data.objects.new(name, data)
    sc.collection.objects.link(ob)
    ob.rotation_euler = (-Vector(direction)).normalized().to_track_quat("-Z", "Y").to_euler()


sun("Key", (1.0, 0.95, 0.88), 4.0, (-0.45, -0.8, 0.55))
sun("Rim", (1.0, 0.78, 0.48), 6.0, (-0.75, 0.55, 0.55))
sun("Bounce", (0.9, 0.62, 0.32), 1.0, (0.1, -0.3, -1.0))
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("BOB", OUT)
