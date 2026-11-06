"""Renders Panoramic's animations from the user's Blender scene, re-lit for the savanna.

The user's file (ROOT/Making/Animation.blend) is only read: this script sets up the light, picks an
action or a pose for every frame and renders it; the edited scene can be saved as a copy (--save).

- Light: the user's own (their lights, world, materials and AgX: deep brown skin, crisp muscles,
  specular boots and armour), plus the savanna's: a warm rim from the game's sun (upper left on
  screen, behind him) and a faint warm bounce from the ground; the menu gets a sunset rim instead.
- Animations: the user's four actions (run, idle, jump, die) and new ones posed here from them
  (hang, catch, throw, climb, crouch, hurt, cheer); see ANIMS.
- Per frame, the projected positions (render pixels, y down) of the hips, the head, both toes and
  both hands go in DIR/<anim>/points.json: the game places airborne frames by the hips and finds the
  planted foot with them.

The hero comes from ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend (the AAA rebuild of the user's model: welded,
calmer muscles, the fringe off his eyes, rigid armour, joint smoothing, the scarf's tail and hair on their
own bones, a cleaned base colour, one material per region, its own actions: see hero3d/AUDIT.md and
hero3d/render/render_all.sh). The bandit renders from the same file (--character bandit, round 9: the hero's
bold cel regions in his own colours); the user's ROOT/Making/Animation.blend still renders as before.

Usage:
  Blender -b ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend --python tools/art/blender/hero_render.py -- \
      --out DIR [--anims run,jump] [--size 768] [--test] [--save ROOT/_agents/AAA/blender/hero.blend]
  (the bandit: ... -- --character bandit --out ROOT/_agents/AAA/blender/bandit_r9 --size 1024, then
  python3 tools/art/bandit_sheet.py)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Quaternion, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    if name in ARGS:
        i = ARGS.index(name)
        return ARGS[i + 1] if i + 1 < len(ARGS) and not ARGS[i + 1].startswith("--") else True
    return default


OUT = arg("--out", "/tmp/hero_render")
SIZE = int(arg("--size", 768))
TEST = bool(arg("--test", False))

SC = bpy.context.scene
ARM = bpy.data.objects["1_Run"]
MESH = max((o for o in ARM.children if o.type == "MESH"), key=lambda o: len(o.data.vertices))  # (the body, not a prop)
ACTIONS = {"run": "mixamo.com", "idle": "mixamo.com.001", "jump": "mixamo.com.002", "die": "mixamo.com.003"}
# ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend (the AAA hero): its own actions (the run authored at the
# game's cadence, the landing flowing into it, the hair and scarf's follow-through keyed in)
AAA = bool(ARM.get("aaa"))
if ARM.get("aaa_actions"):
    ACTIONS = dict(json.loads(ARM["aaa_actions"]), user_run=ACTIONS["run"])
P = "mixamorig:"


# ------------------------------------------------------------------ scene

COSTUME = ("AAA_Underwrap", "AAA_Bracer")  ## (key art k4: no fur cuffs, "a knotted bandage" on one leg only)  ## (round 15) his
## costume's new pieces in the AAA file: the leather underwrap, the boots' fur cuffs, the right bracer (round 16: the
## panels between his legs gone, "a holster, a codpiece"; their pattern on the belt)


def setup_scene():
    """The user's scene as they lit it (their lights, world, materials and AgX), plus the savanna:
    a warm rim from the game's sun (behind him, upper left on screen) and a faint warm bounce from
    the ground. Only the added lights turn with the camera."""
    user_lights = [ob for ob in bpy.data.objects if ob.type == "LIGHT"]
    for ob in bpy.data.objects:
        if ob.type in ("ARMATURE", "MESH"):
            show = ob in (ARM, MESH) or (ob.name in COSTUME and arg("--character") != "bandit")
            ob.hide_render = not show
            ob.hide_viewport = not show
    r = SC.render
    r.resolution_x = r.resolution_y = SIZE
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    SC.eevee.taa_render_samples = 16 if TEST else int(os.environ.get("HERO_SAMPLES", "64"))
    # New (round 3, "a vinyl action figure"): no plastic sheen on the skin (rougher, less
    # specular), a little warm light under it (subsurface), the muscle grooves of the normal map
    # flattened; the user's colours, model and proportions unchanged
    for m in MESH.data.materials:
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Roughness"].default_value = 0.68
                n.inputs["Specular IOR Level"].default_value = 0.28
                n.inputs["Subsurface Weight"].default_value = 0.12
                n.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
                n.inputs["Subsurface Scale"].default_value = 0.02
            elif n.type == "NORMAL_MAP":
                n.inputs["Strength"].default_value = 0.6
    rig = bpy.data.objects.new("LightRig", None)
    SC.collection.objects.link(rig)
    if arg("--light", "day") == "sunset":
        # the interface pictures, in their screens' own light: the low sun behind him wraps his
        # edges in orange, the warm ground bounces up; the user's front lights dimmed and warmed
        # (a cool neutral front light read as "composited"), the muscle grooves softer
        # backlit: his front falls into a warm dark shade, a strong orange rim on every edge facing
        # the sun
        for ob in user_lights:
            ob.data.energy *= 0.25
            ob.data.color = (1.0, 0.72, 0.55)
        for m in MESH.data.materials:
            for n in m.node_tree.nodes:
                if n.type == "NORMAL_MAP":
                    n.inputs["Strength"].default_value = 0.45
        add_sun("Rim", (1.0, 0.52, 0.2), 14.0, aim_from=(0.62, 0.72, 0.3), angle=2.0)
        add_sun("RimFront", (1.0, 0.6, 0.35), 6.0, aim_from=(0.55, -0.78, 0.3), angle=2.0)
        add_area("Bounce", (0.95, 0.48, 0.22), 50.0, at=(-0.5, -0.1, -0.6), size=2.0)
    else:
        # the level: the golden-hour sun high on the left (behind him): a warm rim on his back,
        # shoulders and hair; the grass below: a faint warm bounce
        add_sun("Rim", (1.0, 0.78, 0.5), float(os.environ.get("HERO_RIM", "3.0")), aim_from=(0.55, 0.7, 0.45), angle=2.0)
        add_area("Bounce", (0.85, 0.65, 0.35), float(os.environ.get("HERO_BOUNCE", "6.0")), at=(-0.5, -0.1, -0.6), size=2.0)
    for ob in bpy.data.objects:
        if ob.type == "LIGHT" and ob not in user_lights:
            ob.parent = rig


def look_rotation(direction):
    """A rotation pointing an object's -Z (lights, cameras) along `direction`."""
    return Vector(direction).normalized().to_track_quat("-Z", "Y").to_euler()


def add_sun(name, colour, strength, aim_from, angle):
    data = bpy.data.lights.new(name, "SUN")
    data.color = colour
    data.energy = strength
    data.angle = math.radians(angle)
    ob = bpy.data.objects.new(name, data)
    SC.collection.objects.link(ob)
    ob.rotation_euler = look_rotation(-Vector(aim_from))
    return ob


def add_area(name, colour, power, at, size, target=(0.0, 0.0, 0.5)):
    data = bpy.data.lights.new(name, "AREA")
    data.color = colour
    data.energy = power
    data.size = size
    ob = bpy.data.objects.new(name, data)
    SC.collection.objects.link(ob)
    ob.location = at
    ob.rotation_euler = look_rotation(Vector(target) - Vector(at))
    return ob


def camera(view):
    """Cam_Side (he faces right), Cam_Front, or Cam_Back_Side (the side camera from his left)."""
    if view == "front":
        return bpy.data.objects["Cam_Front"]
    if view == "side":
        return bpy.data.objects["Cam_Side"]
    cam = bpy.data.objects.get("Cam_Other_Side")
    if cam is None:
        src = bpy.data.objects["Cam_Side"]
        cam = src.copy()
        cam.name = "Cam_Other_Side"
        SC.collection.objects.link(cam)
        cam.location = Vector((-src.location.x, src.location.y, src.location.z))
        cam.rotation_euler = (src.rotation_euler.x, src.rotation_euler.y, -src.rotation_euler.z)
    return cam


# ------------------------------------------------------------------ poses

def set_action(name):
    ad = ARM.animation_data
    action = bpy.data.actions[ACTIONS[name]]
    ad.action = action
    if hasattr(ad, "action_slot") and ad.action_slot is None and len(action.slots):
        ad.action_slot = action.slots[0]


def sample(action, frame):
    """The rig's pose (bone -> location, rotation) at a frame (fractions blend the two keys)."""
    set_action(action)
    f = int(math.floor(frame))
    SC.frame_set(f, subframe=frame - f)
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in ARM.pose.bones}


HEAD_SCALE = float(os.environ.get("HEAD_SCALE", "1.5"))  ## (round 17: 1.3 -> 1.5, "the face is a few pixels at phone size")  ## (round 15, "about 8 heads tall: the face never reads at
## phone size; mobile heroes are 5-6 heads") his head (face and hair) this much bigger, from the top of his neck


def apply(pose):
    ARM.animation_data.action = None
    for pb in ARM.pose.bones:
        loc, rot = pose[pb.name]
        pb.location = loc
        pb.rotation_quaternion = rot
        pb.scale = (1.0, 1.0, 1.0)
    ARM.pose.bones[P + "Head"].scale = (HEAD_SCALE if arg("--character") != "bandit" else 1.0,) * 3
    copy_fingers()
    bpy.context.view_layer.update()


FINGERS = ("Index", "Middle", "Ring", "Pinky")


def copy_fingers():
    """(Round 15: the AAA file's middle, ring and little fingers have their own bones now, ROOT/_agents/AAA/hero3d/
    scripts: the animations only move the index finger) every finger bends as the index finger does."""
    for side in ("Left", "Right"):
        for name in FINGERS[1:]:
            for k in (1, 2, 3):
                pb = ARM.pose.bones.get(f"{P}{side}Hand{name}{k}")
                if pb is not None:
                    pb.rotation_quaternion = ARM.pose.bones[f"{P}{side}HandIndex{k}"].rotation_quaternion.copy()


HANDS = {  # (round 15, "mittens") per hand shape: the bend at each joint (degrees), the spread, the thumb's bend
    "fist": ((88, 100, 75), 0.0, 70.0),  # (key art k3: tighter, the thumb wrapped over, "a mitten")
    "open": ((4, 6, 3), 9.0, -8.0),
    "release": ((6, 9, 7), 20.0, -26.0),  # (k11: wider open, "a small mitten with a stubby pointing finger")  # (key art k10) the fingers opening as the ring leaves the palm, the thumb out
    "relaxed": ((24, 32, 20), 3.0, 12.0),
    "brace": ((10, 12, 6), 7.0, 0.0),
}
CURL = float(os.environ.get("CURL_SIGN", "1"))  ## the way the finger bones bend (their local x)


def hand(side, shape):
    """His hand in a shape: every finger bent at its three joints, spread from the middle, the thumb in."""
    if P + side + "HandMiddle1" not in ARM.pose.bones:
        return
    bend, spread, thumb = HANDS[shape]
    for fi, name in enumerate(FINGERS):
        for k in (1, 2, 3):
            q = Quaternion((1.0, 0.0, 0.0), math.radians(bend[k - 1] * CURL))
            if k == 1:
                q = q @ Quaternion((0.0, 0.0, 1.0), math.radians(spread * (fi - 1.2)))
            ARM.pose.bones[f"{P}{side}Hand{name}{k}"].rotation_quaternion = q
    for k in (2, 3):
        ARM.pose.bones[f"{P}{side}HandThumb{k}"].rotation_quaternion = Quaternion((1.0, 0.0, 0.0), math.radians(thumb * CURL))
    bpy.context.view_layer.update()


def mix(a, b, t):
    out = {}
    for k in a:
        la, ra = a[k]
        lb, rb = b[k]
        out[k] = (la.lerp(lb, t), ra.slerp(rb, t))
    return out


def current():
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in ARM.pose.bones}


def _world3():
    return ARM.matrix_world.to_3x3().normalized()


def turn(bone, deg, axis=(1.0, 0.0, 0.0)):
    """Rotates a bone about a world axis through its head. About +X (the default) a positive angle
    turns it clockwise as the side camera sees it."""
    pb = ARM.pose.bones[P + bone]
    m = pb.matrix.copy()
    w = _world3()
    r = w.inverted() @ Matrix.Rotation(math.radians(deg), 3, Vector(axis)) @ w
    new = (r @ m.to_3x3()).to_4x4()
    new.translation = m.translation
    pb.matrix = new
    bpy.context.view_layer.update()


def aim(bone, sx, sy, depth=0.0):
    """Points a bone along a screen direction of the side view (x right, y up; depth towards the
    camera), keeping its twist as far as possible."""
    pb = ARM.pose.bones[P + bone]
    m = pb.matrix.copy()
    w = _world3()
    now = (w @ m.to_3x3().col[1]).normalized()
    target = Vector((-depth, -sx, sy)).normalized()
    r = w.inverted() @ now.rotation_difference(target).to_matrix() @ w
    new = (r @ m.to_3x3()).to_4x4()
    new.translation = m.translation
    pb.matrix = new
    bpy.context.view_layer.update()


def shift_hips(dx=0.0, dy=0.0):
    """Moves the whole body on screen (side view units: metres, x right, y up)."""
    pb = ARM.pose.bones[P + "Hips"]
    m = pb.matrix.copy()
    w = ARM.matrix_world.to_3x3()
    m.translation += w.inverted() @ Vector((0.0, -dx, dy))
    pb.matrix = m
    bpy.context.view_layer.update()


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ the new animations
# (turn(): + is clockwise on screen, so + leans him forward; aim(): x right (his front), y up)

def bone_z(name, end="head"):
    pb = ARM.pose.bones[P + name]
    return (ARM.matrix_world @ (pb.head if end == "head" else pb.tail)).z


def plant(z=0.0, knees=False):
    """Moves him up or down so his lowest foot (or knee) is on the ground at z."""
    names = ["RightToe_End", "LeftToe_End", "RightFoot", "LeftFoot"] + (["RightLeg", "LeftLeg"] if knees else [])
    low = min(bone_z(n) for n in names)
    shift_hips(0.0, z + 0.035 - low)


STRIDE = 0.6  ## the run's leg swing kept for the game's jog (233 units/s is a jog for his size)
STRIDE_ARMS = 0.85
LEGS = [P + s + b for s in ("Left", "Right") for b in ("UpLeg", "Leg", "Foot", "ToeBase")]
ARMS = [P + s + b for s in ("Left", "Right") for b in ("Arm", "ForeArm")]


def sample_jog(frame, user=False):
    """The run with shorter strides (STRIDE of its leg swing), so his feet keep pace with the game's
    ground; its flight and bounce shrink with it, the planted foot stays on the ground.
    (The AAA file's run is authored at the game's cadence and ground speed: used as it is.)"""
    if AAA and not user:
        return sample("run", frame)
    run = sample("user_run" if AAA else "run", frame)
    low_run = min(bone_z("RightToe_End"), bone_z("LeftToe_End"))
    stand = sample("idle", 1)
    pose = dict(run)
    for name in LEGS + ARMS:
        k = STRIDE if name in LEGS else STRIDE_ARMS
        pose[name] = (run[name][0], stand[name][1].slerp(run[name][1], k))
    apply(pose)
    low = min(bone_z("RightToe_End"), bone_z("LeftToe_End"))
    shift_hips(0.0, max(low_run, 0.0) * STRIDE - low)
    return current()


HANG_TURN = -32.0  ## degrees: hanging, he turns a little towards us (both arms and his face show)
HANG_TOP = 1.06  ## metres: where his hands grip, near the top of the frame


def pose_hang(t, turn_k=1.0):
    """Hanging from the vine by both hands, legs dangling and swaying (t: 0..1 around the loop)."""
    apply(sample("idle", 1 + t * 59))
    ARM.rotation_euler.z = math.radians(HANG_TURN * turn_k)
    bpy.context.view_layer.update()
    s = math.sin(t * math.tau)
    c = math.cos(t * math.tau)
    turn("Spine", -2 + 2 * s)
    aim("RightArm", 0.22, 1.0, 0.1)
    aim("RightForeArm", 0.12, 1.0, 0.02)
    aim("RightHand", 0.08, 1.0)
    aim("LeftArm", -0.04, 1.0, -0.1)
    aim("LeftForeArm", 0.04, 1.0, -0.02)
    aim("LeftHand", 0.0, 1.0)
    # (round 13, "stiff: straight legs, no swing") knees bent, the legs swinging under him as one
    aim("RightUpLeg", 0.62 + 0.24 * s, -1.0)
    aim("RightLeg", -0.62 + 0.2 * c, -1.0)
    aim("RightFoot", 0.45, -1.0)
    aim("LeftUpLeg", 0.3 + 0.24 * s, -1.0)
    aim("LeftLeg", -0.85 + 0.2 * c, -1.0)
    aim("LeftFoot", 0.3, -1.0)
    top = max(bone_z("RightHand", "tail"), bone_z("LeftHand", "tail"))
    shift_hips(0.0, HANG_TOP - top)


def pose_catch(t):
    """From the rising jump into the hang: arms sweep up to the vine (t 0..1)."""
    pose_hang15(0.0)
    hang = current()
    a = sample("jump", 6 + 2 * t)
    apply(mix(a, hang, ease(t)))
    ARM.rotation_euler.z = math.radians(HANG_TURN * ease(t))
    bpy.context.view_layer.update()


def throw_arm(stage):
    """The near (right) arm: 0 drawn back behind his head, 1 the release reaching forward.
    (AAA: with the body in it: the chest coils back on the wind-up, the right shoulder back and the
    armoured arm forward for balance; on the release the chest whips through, the shoulder leads, the
    armoured arm swings back; the head stays on the target.)"""
    if stage == 0:
        turn("Spine1", -9)
        if AAA:
            turn("Spine1", -16, axis=(0.0, 0.0, 1.0))  # coiled: the right shoulder back
            turn("Spine", -5)
        turn("Head", 4)
        aim("RightArm", -1.0, 0.25, 0.3)
        aim("RightForeArm", 0.35, 1.0, 0.15)
        aim("RightHand", 0.8, 0.5)
        if AAA:
            aim("LeftArm", 0.75, -0.35, -0.3)
            aim("LeftForeArm", 0.9, 0.3, -0.1)
            turn("Head", 10, axis=(0.0, 0.0, 1.0))  # eyes stay on the target
    else:
        turn("Spine1", 8)
        if AAA:
            turn("Spine1", 14, axis=(0.0, 0.0, 1.0))  # through: the right shoulder leads
            turn("Spine", 6)
        aim("RightArm", 1.0, 0.1, 0.18)
        aim("RightForeArm", 1.0, 0.05, 0.05)
        aim("RightHand", 1.0, -0.15)
        if AAA:
            aim("LeftArm", -0.8, -0.45, -0.3)
            aim("LeftForeArm", -0.55, -0.1, -0.1)
            turn("Head", -8, axis=(0.0, 0.0, 1.0))


def pose_throw(i, stage):
    apply(sample_jog(1 + i))
    throw_arm(stage)


def pose_kneel():
    apply(sample("idle", 1))
    turn("Spine", 14)
    turn("Spine1", 6)
    turn("Head", -10)
    aim("RightUpLeg", 1.0, -0.12)
    aim("RightLeg", 0.05, -1.0)
    aim("RightFoot", 1.0, -0.25)
    aim("LeftUpLeg", 0.12, -1.0)
    aim("LeftLeg", -1.0, -0.08)
    aim("LeftFoot", -1.0, -0.3)
    aim("RightArm", 0.5, -0.85, 0.25)
    aim("RightForeArm", 0.9, -0.3)
    aim("LeftArm", 0.25, -0.95, -0.2)
    aim("LeftForeArm", 0.7, -0.6)
    plant(0.0, knees=True)


def pose_crouch(t):
    """Down on one knee from the run (t 0..1), then held."""
    run = sample_jog(1)
    pose_kneel()
    apply(mix(run, current(), ease(t)))


def pose_hurt(t):
    """A blow from the front: snapped back, arms flung, then gathering himself (t 0..1)."""
    apply(sample_jog(1 + (6 * t) % 16))
    k = math.sin(min(t / 0.3, 1.0) * math.pi / 2) * (1.0 - ease((t - 0.45) / 0.55))
    if k <= 0.01:
        return
    base = current()
    turn("Spine", -18)
    turn("Spine1", -10)
    turn("Neck", -14)
    turn("Head", -12)
    aim("RightArm", 0.6, 0.55, 0.3)
    aim("RightForeArm", 0.35, 0.95)
    aim("LeftArm", -0.35, 0.65, -0.3)
    aim("LeftForeArm", 0.15, 1.0)
    aim("RightUpLeg", 0.9, -0.5)
    aim("RightLeg", 0.25, -1.0)
    apply(mix(base, current(), k))


def pose_climb(t):
    """Up over a ledge (t 0..1): reaching up and forward, a knee onto the top, standing."""
    pose_hang(0.25, turn_k=0.0)
    aim("RightArm", 0.75, 1.0, 0.12)
    aim("RightForeArm", 0.6, 1.0)
    aim("LeftArm", 0.55, 1.0, -0.12)
    aim("LeftForeArm", 0.5, 1.0)
    reach = current()
    knee = sample("jump", 12)
    land = sample("jump", 21)
    if t < 0.45:
        apply(mix(reach, knee, ease(t / 0.45)))
    else:
        apply(mix(knee, land, ease((t - 0.45) / 0.55)))


def pose_win(t, face_turn=-90.0):
    """Home (t 0..1): he stops, turns to us and throws both fists up; from t 0.4 a cheering loop
    (fists pumping, a little bounce)."""
    turn_t = ease(t / 0.3)
    run = sample_jog(1)
    apply(sample("idle", 1 + t * 30))
    ARM.rotation_euler.z = math.radians(face_turn * turn_t)
    bpy.context.view_layer.update()
    up = ease((t - 0.1) / 0.3)
    pump = 0.5 + 0.5 * math.sin((t - 0.4) / 0.6 * math.tau * 2) if t > 0.4 else 1.0
    # his right is screen left once he faces us (x is still the side view's screen x)
    # (round 13, "stiff symmetrical arms-up": one fist punched high, the other pumping at his chest, a lean)
    aim("RightArm", -0.3 + 0.1 * up, -0.95 + 1.95 * up, 0.15)
    aim("RightForeArm", -0.05 - 0.1 * (1 - up), 0.1 + 0.9 * up, 0.25 * (1 - up))
    aim("RightHand", -0.05, 1.0)
    # (round 14: "the bent second arm overlaps his chest") pumped out to the side, the fist up at shoulder height
    aim("LeftArm", 0.3 + 0.65 * up, -0.95 + 1.0 * up, 0.15 - 0.05 * up)
    aim("LeftForeArm", 0.05 + 0.2 * up, 0.1 + 0.85 * up * (0.6 + 0.4 * pump), 0.25 - 0.15 * up)
    aim("LeftHand", 0.15, 1.0)
    turn("Spine1", 6.0 * up)  # (a lean towards the raised fist, as the side camera sees him)
    turn("Spine", 12.0 * up, (0.0, 0.0, 1.0))  # (round 14: the body twisting to the viewer)
    turn("Head", -8.0 * up)
    if t > 0.4:
        shift_hips(0.0, 0.03 * pump)
    if t < 0.15:
        cheer = current()
        apply(mix(run, cheer, ease(t / 0.15)))


def pose_menu(kind):
    """Title-screen poses, three-quarters towards us."""
    if kind == 0:  # the fighting stance he takes before the blow (die, first frame), fists up
        apply(sample("die", 1))
        ARM.rotation_euler.z = math.radians(25.0)
    elif kind == 1:  # mid-leap
        apply(sample("jump", 7))
        ARM.rotation_euler.z = math.radians(-50.0)
    elif kind == 2:  # running at us
        apply(sample("run", 3))
        ARM.rotation_euler.z = math.radians(-40.0)
    else:  # standing tall, the armoured fist raised
        apply(sample("idle", 1))
        ARM.rotation_euler.z = math.radians(-25.0)
        bpy.context.view_layer.update()
        aim("LeftArm", 0.25, 0.95, 0.2)
        aim("LeftForeArm", 0.1, 1.0)
        aim("RightArm", 0.15, -1.0, 0.25)
        aim("RightForeArm", 0.35, -0.9, 0.2)
    bpy.context.view_layer.update()


def pose_menu_throw():
    """The title screen: mid-throw, a ring leaving his hand, three-quarters towards us."""
    reset_turn()
    apply(sample_jog(3, user=True))  # (the key art keeps the user's lunge)
    throw_arm(1)
    aim("LeftArm", -0.8, -0.25, -0.3)
    aim("LeftForeArm", -0.55, 0.35)
    turn("Spine", 6)
    turn("Head", -4)
    ring = bpy.data.objects.get("MenuRing")
    if ring is None:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.055, minor_radius=0.009, major_segments=64, minor_segments=24)
        ring = bpy.context.object
        ring.name = "MenuRing"
        bpy.ops.object.shade_smooth()
        m = bpy.data.materials.new("RingSteel")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (0.08, 0.25, 0.6, 1)  # blue steel
        b.inputs["Metallic"].default_value = 1.0
        b.inputs["Roughness"].default_value = 0.12
        b.inputs["Emission Color"].default_value = (0.3, 0.75, 1.0, 1)
        b.inputs["Emission Strength"].default_value = 0.25
        ring.data.materials.append(m)
        if arg("--style", "toon") == "toon":  # steel in the cel look: light and dark bands, inked
            b.inputs["Base Color"].default_value = (0.22, 0.45, 0.88, 1)
            toon_material(m, "sunset" if arg("--light", "day") == "sunset" else "day")
            ink_hull(ring, INK_WIDTH * 0.5)
    ring.hide_render = False
    hand = ARM.matrix_world @ ARM.pose.bones[P + "RightHand"].tail
    ring.location = hand + Vector((-0.02, -0.06, 0.02))
    ring.rotation_euler = (math.radians(70), math.radians(20), 0)
    ARM.rotation_euler.z = math.radians(50.0)
    bpy.context.view_layer.update()
    # the ring turns with him (it was placed before the turn): put it at his hand again
    hand = ARM.matrix_world @ ARM.pose.bones[P + "RightHand"].tail
    ring.location = hand + Vector((0.05, -0.03, 0.02))


def pose_defeat():
    """Game over: down on one knee, one hand on the ground, the other on his knee, looking up at us,
    dazed but unbeaten (a clear silhouette: the knee, the arm to the ground, the raised head)."""
    reset_turn()
    pose_kneel()
    aim("RightArm", 0.15, -1.0, 0.35)
    aim("RightForeArm", 0.35, -0.95, 0.15)
    aim("RightHand", 0.5, -0.85)
    aim("LeftArm", 0.6, -0.6, -0.25)
    aim("LeftForeArm", 0.9, -0.2, -0.1)
    turn("Spine", -16)
    turn("Spine1", -6)
    turn("Neck", -12)
    turn("Head", -14)
    plant(0.0, knees=True)
    ARM.rotation_euler.z = math.radians(-40.0)  # seen from the side, turned to us
    bpy.context.view_layer.update()


def _ring_in_hand(hand_bone="RightHand"):
    """The menu's steel ring, held in his hand, facing us."""
    ring = bpy.data.objects.get("MenuRing")
    if ring is None:  # made (with its material) by pose_menu_throw(): this pose kept
        keep, turned = current(), ARM.rotation_euler.z
        pose_menu_throw()
        apply(keep)
        ARM.rotation_euler.z = turned
        bpy.context.view_layer.update()
        ring = bpy.data.objects["MenuRing"]
    ring.hide_render = False
    pb = ARM.pose.bones[P + hand_bone]
    hand = ARM.matrix_world @ ((pb.head + pb.tail) / 2)
    ring.location = hand + Vector((0.0, -0.03, 0.035))
    ring.rotation_euler = (math.radians(78), math.radians(-14), 0.0)


def pose_authored(name, chakram=False, stars=False):
    """An interface pose authored by hand in the live window (ROOT/_agents/AAA/hero3d/scripts/p2_pose.py),
    kept as a one-frame action; the chakram (bone-parented to his right hand) shown for the title screen."""
    reset_turn()
    apply(sample(name, 1))
    ring = bpy.data.objects.get("AAA_Chakram")
    if ring is not None:
        ring.hide_render = not chakram
    for ob in bpy.data.objects:  # (pass 3) the dizzy stars over his head in the defeat picture
        if ob.name.startswith(("AAA_DizzyStar", "AAA_DizzyTrail", "AAA_DizzySwirl")):
            ob.hide_render = not stars
    bpy.context.view_layer.update()


def _aim_world(bone, d):
    """aim() with a world direction (the side view's frame: x right = -y, y up = z, depth = -x)."""
    aim(bone, -d.y, d.z, -d.x)


def ik_leg(side, ankle, pole):
    """Two-bone IK: his thigh and shin reach `ankle` (world), the knee bending towards `pole` (a direction)."""
    hip = bone_world(side + "UpLeg")
    l1 = (bone_world(side + "Leg") - hip).length
    l2 = (bone_world(side + "Foot") - bone_world(side + "Leg")).length
    d = ankle - hip
    dist = min(d.length, (l1 + l2) * 0.999)
    u = d.normalized()
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    y = math.sqrt(max(l1 * l1 - x * x, 0.0))
    perp = (pole - u * pole.dot(u)).normalized()
    knee = hip + u * x + perp * y
    _aim_world(side + "UpLeg", knee - hip)
    _aim_world(side + "Leg", hip + u * dist - knee)


LUNGE_DROP = float(os.environ.get("LUNGE_DROP", "0.04"))  ## metres the key art's hips sink (round 12: "back leg locked")


def pose_key_lunge():
    """The title screen's throw (the authored AAA_key_menu) in a deeper lunge (round 12: "stiff pose: back leg locked,
    fist foreshortened into a blob"): the hips lower with the boots where they stood (both knees bend), the throwing
    forearm turned across the picture instead of at us."""
    pose_authored("key_menu", chakram=True)
    feet = {}
    for side in ("Left", "Right"):
        feet[side] = (bone_world(side + "Foot"), bone_world(side + "Foot", "tail") - bone_world(side + "Foot"),
                      bone_world(side + "ToeBase", "tail") - bone_world(side + "ToeBase"))
    shift_hips(0.0, -LUNGE_DROP)
    for side, (ankle, foot, toe) in feet.items():
        hip, knee = bone_world(side + "UpLeg"), bone_world(side + "Leg")
        u = (ankle - hip).normalized()
        ik_leg(side, ankle, (knee - hip) - u * (knee - hip).dot(u))
        _aim_world(side + "Foot", foot)
        _aim_world(side + "ToeBase", toe)
    fore = bone_world("RightForeArm", "tail") - bone_world("RightForeArm")
    _aim_world("RightForeArm", Vector((fore.x * 1.25, fore.y * 0.45, fore.z)))
    # (round 14, the character judge: "a closed fist punching forward while the ring trails behind: the throw doesn't
    # make sense") the hand opened in the release, the wrist flicked, the ring ahead of it on the throw's arc
    fore = (bone_world("RightForeArm", "tail") - bone_world("RightForeArm")).normalized()
    up = Vector((0.0, 0.0, 1.0))
    _aim_world("RightHand", (fore + up * 0.35).normalized())
    for bone in ("RightHandIndex1", "RightHandIndex2", "RightHandIndex3"):
        _aim_world(bone, (fore + up * 0.25).normalized())
    for bone in ("RightHandThumb1", "RightHandThumb2", "RightHandThumb3"):
        _aim_world(bone, (fore * 0.6 + up * 0.8).normalized())
    ring = bpy.data.objects.get("AAA_Chakram")
    if ring is not None:
        hand = bone_world("RightHand", "tail")
        m = ring.matrix_world.copy()
        m.translation = hand + (fore * 0.85 + up * 0.5).normalized() * 0.2
        ring.matrix_world = m
        bpy.context.view_layer.update()


def pose_idle(i):
    """The idle (round 14, the character judge: "the head bowed so far the face is invisible: reads dejected", "a
    stiff scissor stance"): chin up, the face turned three-quarters to us, the chest lifted."""
    apply(sample("idle", 1 + i * 3))
    turn("Spine1", -4.0)
    turn("Neck", -6.0)
    turn("Head", -10.0)
    turn("Head", -22.0, (0.0, 0.0, 1.0))


def pose_jump(i):
    """The jump as authored, its flight (round 14, the character judge: "no arms visible, one leg straight forward and
    the other knee down: reads as kneeling in mid-air"): a split leap, the near arm up and forward, the other back for
    balance (the far arm forward, so the near one never covers his face), the head up and three-quarters to us."""
    apply(sample("jump", 1 + i))
    w = ease((i - 2) / 4.0) * (1.0 - ease((i - 15) / 4.0))  # the flight, frames 3-18
    if w <= 0.0:
        return
    base = current()
    aim("LeftArm", 0.55, 0.65, -0.3)  # the far arm up and forward (behind his head: his face stays clear)
    aim("LeftForeArm", 0.8, 0.5, -0.2)
    aim("RightArm", -0.6, 0.25, 0.3)  # the near arm back for balance
    aim("RightForeArm", -0.85, 0.05, 0.2)
    aim("RightUpLeg", 0.85, -0.3)
    aim("RightLeg", 0.3, -0.95)
    aim("LeftUpLeg", -0.45, -0.85)
    aim("LeftLeg", -0.85, -0.4)
    turn("Head", -12.0)
    turn("Head", -20.0, (0.0, 0.0, 1.0))
    apply(mix(base, current(), w))


DEFEAT_TURN = float(os.environ.get("DEFEAT_TURN", "32"))  ## degrees (round 12: "legs splay towards the camera")


def pose_defeat_turned():
    """The game over's dazed slump (the authored AAA_key_defeat, its chunky stars) turned so his legs go across the
    picture instead of at us (round 12: "huge foreshortened boots, the torso looks small"), his face kept to us."""
    pose_authored("key_defeat", stars=True)
    chunky_stars()
    ARM.rotation_euler.z = math.radians(DEFEAT_TURN)
    bpy.context.view_layer.update()
    turn("Neck", -DEFEAT_TURN * 0.35, (0.0, 0.0, 1.0))
    turn("Head", -DEFEAT_TURN * 0.35, (0.0, 0.0, 1.0))


WIN_LEAP = os.environ.get("WIN_LEAP", "trail")  ## "pass4": as authored; "tuck"; "trail"; "kick" (round 14: "trail",
## the character judge: "a clean fist-pump jump, one knee up, the other leg trailing"; the kick "splayed the legs")


def pose_win_tuck():
    """The win's leap (the authored AAA_key_win); round 12 ("the tucked leg and boot read as a tangle"): the legs
    apart, so neither boot crosses the other: the front knee up with its shin hanging under it, the other leg
    trailing behind, its toes pointed."""
    pose_authored("key_win")
    down = Vector((0.0, 0.0, -1.0))
    if WIN_LEAP == "tuck":
        thigh = (bone_world("RightLeg") - bone_world("RightUpLeg")).normalized()
        shin = (-thigh * 0.55 + down * 0.75 + Vector((0.0, 0.12, 0.0))).normalized()
        _aim_world("RightLeg", shin)
        _aim_world("RightFoot", (shin * 0.6 + down * 0.4).normalized())
    elif WIN_LEAP == "trail":
        _aim_world("RightArm", Vector((-0.12, 0.05, 1.0)).normalized())  # (round 14: the fist punched straight up,
        _aim_world("RightForeArm", Vector((-0.05, 0.02, 1.0)).normalized())  # "the raised arm curls over the head like a hook")
        _aim_world("RightHand", Vector((0.0, 0.0, 1.0)))
        _aim_world("RightLeg", Vector((-0.12, 0.05, -1.0)).normalized())  # the front shin under its knee
        _aim_world("RightFoot", Vector((0.15, -0.05, -1.0)).normalized())
        _aim_world("LeftUpLeg", Vector((-0.45, 0.12, -0.88)).normalized())  # the other leg trailing behind
        _aim_world("LeftLeg", Vector((-0.62, 0.16, -0.77)).normalized())
        _aim_world("LeftFoot", Vector((-0.55, 0.12, -0.83)).normalized())
    elif WIN_LEAP == "kick":  # the front knee up as authored, the other foot kicked up behind him (a leap of joy)
        _aim_world("LeftUpLeg", Vector((-0.32, 0.1, -0.94)).normalized())
        _aim_world("LeftLeg", Vector((-0.86, 0.14, 0.48)).normalized())
        _aim_world("LeftFoot", Vector((-0.72, 0.1, 0.68)).normalized())


STAR_GOLD = (1.0, 0.8, 0.16)  ## sRGB: the dizzy stars, the game's own gold (the results' stars)


def chunky_stars():
    """The defeat's dizzy stars in the game's own language (round 10: "stock clip-art"): thick, bevelled,
    cel-shaded gold with a hot rim and an ink line, like the stars of the results panel; the spiral over his
    head gone, the orbit trail kept."""
    tools = _aaa_toon()
    trail = bpy.data.materials.get("AAA_star_trail")
    if trail is not None:  # the orbit's streak warm, the stars' light (it was a cold white)
        for n in trail.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = (*_lin(1.0, 0.9, 0.6), 1.0)
                n.inputs["Emission Color"].default_value = (*_lin(1.0, 0.86, 0.5), 1.0)
                n.inputs["Emission Strength"].default_value = 1.6
    for ob in bpy.data.objects:
        if ob.name.startswith("AAA_DizzySwirl"):
            ob.hide_render = True
        if ob.name.startswith("AAA_DizzyTrail") and ob.type == "CURVE" and not ob.get("bold"):
            ob["bold"] = True  # (round 14, "the star halo a thin yellow line: a placeholder") a bold ring of light
            ob.data.bevel_depth *= 2.2
        if not ob.name.startswith("AAA_DizzyStar") or ob.get("chunky"):
            continue
        ob["chunky"] = True
        ob.scale = ob.scale * 1.25  # (round 14: bigger, they read at card size)
        bevel = ob.modifiers.new("Round", "BEVEL")  # (an 8 cm star, 2.4 cm thick: its edges rounded, puffy)
        bevel.width = 0.007
        bevel.segments = 3
        bevel.limit_method = "ANGLE"
        m = bpy.data.materials.get("AAA_star_toon")
        if m is None:
            m = bpy.data.materials.new("AAA_star_toon")
            m.use_nodes = True
            m["toon"] = "belt"
            m["flat"] = _lin(*STAR_GOLD)
            m["rim"] = _lin(1.0, 0.97, 0.7)
            m["rim_k"] = 0.9
            m["aaa_base"] = "AAA_albedo"
            m["aaa_normal"] = ""
            tools.build(m, "sunset")
        ob.data.materials.clear()
        ob.data.materials.append(m)
        ink_hull(ob, 0.0025)
        bpy.context.view_layer.update()


def pose_key_art():
    """The title screen (round 7): the throw, caught as the ring leaves his hand (round 4's dynamic
    pose), turned three-quarters to us, his head turned to us and lifted so his face shows; the ring
    a hand's breadth out from his fingers, flying."""
    pose_menu_throw()
    turn("Neck", -8)
    turn("Head", -14)
    turn("Head", -KEY_LOOK, axis=(0.0, 0.0, 1.0))  # his face turned to us
    bpy.context.view_layer.update()
    ring = bpy.data.objects["MenuRing"]
    hand = ARM.matrix_world @ ARM.pose.bones[P + "RightHand"].tail
    away = (hand - ARM.matrix_world @ ARM.pose.bones[P + "RightForeArm"].head).normalized()
    ring.location = hand + away * 0.11 + Vector((0.0, -0.02, 0.0))
    ring.rotation_euler = (math.radians(62), math.radians(28), 0.0)


KEY_LOOK = 30.0  ## degrees his head turns from the throw towards us on the title screen


def pose_celebrate():
    """The win card: his armoured fist punched up, the other pumped at his chest, chin up, feet on
    the ground, three-quarters towards us."""
    reset_turn()
    apply(sample("idle", 1))
    aim("LeftArm", 0.1, 1.0, -0.3)
    aim("LeftForeArm", 0.05, 1.0, -0.05)
    aim("LeftHand", 0.0, 1.0)
    aim("RightArm", 0.25, -0.55, 0.65)
    aim("RightForeArm", 0.7, 0.65, -0.15)
    turn("Spine", -5)
    turn("Neck", -8)
    turn("Head", -16)  # chin up: his face out from under his hair
    ARM.rotation_euler.z = math.radians(-22.0)
    bpy.context.view_layer.update()


SEAT_TURN = 40.0  ## degrees: his knees a little across the picture
SEAT_TWIST = -25.0  ## degrees: his chest and face turned back to us


def pose_seated():
    """Game over: sat on the ground, dazed, both knees drawn up (compact: nothing reaching out), his
    forearms resting on his knees, his head tilted, his face turned up to us (no arm across it)."""
    reset_turn()
    apply(sample("idle", 1))
    for side, lean in (("Right", 0.12), ("Left", -0.12)):
        aim(side + "UpLeg", 0.6, 0.8, lean)
        aim(side + "Leg", 0.25, -1.0, lean * 0.5)
        aim(side + "Foot", 1.0, -0.15)
    turn("Spine", -10)
    for side, lean in (("Left", -1.0), ("Right", 1.0)):  # both forearms resting on his knees
        aim(side + "Arm", 0.45, -0.55, 0.45 * lean)
        aim(side + "ForeArm", 0.9, 0.1, -0.15 * lean)
        aim(side + "Hand", 0.6, -0.8)
    turn("Spine1", SEAT_TWIST * 0.4, axis=(0.0, 0.0, 1.0))
    turn("Head", SEAT_TWIST, axis=(0.0, 0.0, 1.0))
    turn("Head", 12, axis=(0.0, 1.0, 0.0))  # tilted, dazed
    turn("Neck", -6)
    turn("Head", -14)  # looking up at us, his face clear
    seat = bone_z("Hips") - 0.09
    low = min(seat, bone_z("RightToe_End"), bone_z("LeftToe_End"))
    shift_hips(0.0, 0.0 - low)
    ARM.rotation_euler.z = math.radians(SEAT_TURN)
    bpy.context.view_layer.update()


def pose_turn(k):
    """The turnaround (reviews only, not in the game): standing, turned k quarters."""
    apply(sample("idle", 1))
    ARM.rotation_euler.z = math.radians(-90.0 * k)
    bpy.context.view_layer.update()


def reset_turn():
    ARM.rotation_euler.z = 0.0
    _grip[0] = None
    front = bpy.data.objects.get("AAA_PanelFront")
    if front is not None and arg("--character") != "bandit":
        front.hide_render = not front.get("shown", True)
    for ob in bpy.data.objects:  # only the title screen's picture holds a ring, only the defeat has stars
        if ob.name in ("MenuRing", "AAA_Chakram") or ob.name.startswith(("AAA_DizzyStar", "AAA_DizzyTrail", "AAA_DizzySwirl")):
            ob.hide_render = True
    bpy.context.view_layer.update()


# ------------------------------------------------------------------ round 15: the poses acted
# (the character judges, round 14: the throw "very wide with both feet flat: no weight over the front knee, no torso
# twist"; the jump "a starfish falling backwards"; the run "bent 90 degrees, an old man shuffling"; the hang "a
# plank"; the idle "stiff, arms hang straight"; the win "the fist buried in the hair, broken at the waist"; home
# "square, knees locked, hailing a taxi"; game over "resting, not knocked out")

def shift_world(v):
    """Moves the whole body by a world vector (metres)."""
    pb = ARM.pose.bones[P + "Hips"]
    m = pb.matrix.copy()
    m.translation += ARM.matrix_world.to_3x3().inverted() @ v
    pb.matrix = m
    bpy.context.view_layer.update()


def _feet():
    return {side: (bone_world(side + "Foot"), bone_world(side + "Foot", "tail") - bone_world(side + "Foot"),
                   bone_world(side + "ToeBase", "tail") - bone_world(side + "ToeBase")) for side in ("Left", "Right")}


def _replant(feet, sides=("Left", "Right")):
    """The legs reach their feet again (where `feet` held them), the knees bending the way they were."""
    for side in sides:
        ankle, foot, toe = feet[side]
        hip, knee = bone_world(side + "UpLeg"), bone_world(side + "Leg")
        u = (ankle - hip).normalized()
        pole = (knee - hip) - u * (knee - hip).dot(u)
        ik_leg(side, ankle, pole if pole.length > 1e-4 else Vector((0.0, -1.0, 0.0)))
        _aim_world(side + "Foot", foot)
        _aim_world(side + "ToeBase", toe)


def heel_up(side, k=0.5):
    """His heel lifted off the ground, the ball of his foot where it was (a pushing-off back foot)."""
    ball = bone_world(side + "ToeBase")
    foot = bone_world(side + "Foot", "tail") - bone_world(side + "Foot")
    level = Vector((foot.x, foot.y, 0.0)).normalized()
    d = (level * (1.0 - k) + Vector((0.0, 0.0, -1.0)) * k).normalized()
    ankle = ball - d * foot.length
    hip, knee = bone_world(side + "UpLeg"), bone_world(side + "Leg")
    u = (ankle - hip).normalized()
    ik_leg(side, ankle, (knee - hip) - u * (knee - hip).dot(u))
    _aim_world(side + "Foot", d)
    _aim_world(side + "ToeBase", level)


THROW_TWIST = float(os.environ.get("THROW_TWIST", "18"))  ## degrees his shoulders turn against his hips at the release
THROW_HIPS = float(os.environ.get("THROW_HIPS", "0.05"))  ## metres his hips drive towards the throw
THROW_STANCE = float(os.environ.get("THROW_STANCE", "0.68"))  ## (key art k11: 0.8, "the lunge so wide the back leg looks over-long")  ## the lunge's width, a share of the authored one
THROW_RING = float(os.environ.get("THROW_RING", "0.19"))  ## (key art k10: 0.14, "pinches the chakram at its rim": the ring just left the open hand)  ## metres the ring has flown from his hand (the title screen
## keeps it inside its left two fifths, where the close-ups are cut)


KEY_BUILD = {  # (key art k9, "a stringy, narrow torso and thin upper arms against heavy thighs and big boots") the key
    # art's build: bone scales across the bone (x, z; y runs along it), the children not inheriting them
    # (key art k31, "narrow shoulders barely wider than the head plus hair, a short narrow torso, a pinched waist, very long
    # legs: a lanky teen, not a warrior"; "no neck") a heroic V: the chest and lats ~20% wider and deeper, the waist less
    # pinched, the spine 6% longer (the legs read less long; legs and feet where they were), a thicker neck, the collarbones
    # longer (the throwing side's thicker too: on the fist side a thicker one pushed a jagged edge into the silhouette),
    # thicker forearms; the hands, head, pose and costume unchanged
    # (k9-k30: "Spine1": (1.12, 1.0, 1.05), "Spine2": (1.26, 1.0, 1.1), "Neck": (1.18, 1.0, 1.18), forearms (1.1, 1.0, 1.1))
    "Spine": (1.15, 1.06, 1.08), "Spine1": (1.35, 1.06, 1.18), "Spine2": (1.5, 1.06, 1.25), "Neck": (1.5, 1.3, 1.4),
    "LeftShoulder": (1.0, 1.35, 1.0), "RightShoulder": (1.25, 1.6, 1.25),
    # (key art k32, "the armlet a flat vertical gold rectangle stuck on the bicep like a plaster": the upper arms back to their own
    # thickness (k31 1.2), which keeps k27's curved band; the forearms a little thicker than k27's (k31 1.32: swollen against them))
    "LeftForeArm": (1.15, 1.0, 1.15), "RightForeArm": (1.15, 1.0, 1.15),
    "LeftUpLeg": (0.92, 1.0, 0.92), "RightUpLeg": (0.92, 1.0, 0.92), "LeftLeg": (0.94, 1.0, 0.94), "RightLeg": (0.94, 1.0, 0.94),
    "LeftFoot": (0.95, 0.95, 0.95), "RightFoot": (0.95, 0.95, 0.95)}


def key_build():
    if os.environ.get("KEY_BUILD", "1") != "1":
        return
    for name, sc in KEY_BUILD.items():
        pb = ARM.pose.bones.get(P + name)
        if pb is None:
            continue
        for child in pb.bone.children:
            child.inherit_scale = "NONE"
        k = HEAD_SCALE if name == "Head" else 1.0
        pb.scale = tuple(c * k for c in sc)
    bpy.context.view_layer.update()


HAIR_LOCKS = int(os.environ.get("HAIR_LOCKS", "6"))  ## (key art k39) the big locks his hair's shading is grouped into
HAIR_SMOOTH_IT = int(os.environ.get("HAIR_SMOOTH_IT", "200"))  ## (key art k41) how far the hair's own normals are smoothed
## for its highlight (iterations over its edges)
HAIR_ROUND = float(os.environ.get("HAIR_ROUND", "0.6"))  ## how much each lock shades as a round clump round its own axis (the
## rest: the head's own roundness)


def key_hair_normals():
    """(Key art k39, "a dark noisy blob with scratchy strands: design it as 5-7 big clumps with a light side, a shadow side
    and a clean highlight") his hair's shading grouped into HAIR_LOCKS big locks, its geometry and silhouette untouched: the
    hair's vertices clustered by their way out from the middle of his head (rest), and each given a designed normal in the
    posed picture, a round clump about its lock's axis blended with the head's roundness. The toon shader lights the hair
    by it (attribute "hair_n", world space): each lock one clean mass with its own light and shadow side, crisp between."""
    if not (AAA and arg("--light", "day") == "sunset") or os.environ.get("KEY_HAIR", "1") != "1":
        return
    me = MESH.data
    names = [m.name if m else "" for m in me.materials]
    if "AAA_hair" not in names:
        return
    n = len(me.vertices)
    mi = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", mi)
    lt = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_total", lt)
    lv = np.zeros(len(me.loops), np.int64); me.loops.foreach_get("vertex_index", lv)
    hair = np.zeros(n, bool); hair[lv[np.repeat(mi, lt) == names.index("AAA_hair")]] = True
    rc = np.zeros(n * 3, np.float32); me.attributes["rest_co"].data.foreach_get("vector", rc); rc = rc.reshape(-1, 3)
    centre_rest = np.array([0.0, 0.0, 0.4], np.float32)
    idx = np.nonzero(hair)[0]
    u = rc[idx] - centre_rest
    u /= np.maximum(np.linalg.norm(u, axis=1, keepdims=True), 1e-6)
    # k-means on the directions, seeded spread over them (deterministic)
    rng = np.random.default_rng(7)
    cen = u[rng.choice(len(u), HAIR_LOCKS, replace=False)]
    for _ in range(25):
        lab = np.argmax(u @ cen.T, 1)
        for k in range(HAIR_LOCKS):
            m = lab == k
            if m.any():
                c = u[m].mean(0)
                cen[k] = c / max(np.linalg.norm(c), 1e-6)
    lab = np.argmax(u @ cen.T, 1)
    # the posed positions
    dg = bpy.context.evaluated_depsgraph_get()
    ev = MESH.evaluated_get(dg).data
    co = np.zeros(len(ev.vertices) * 3, np.float32); ev.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    mw = np.array(MESH.matrix_world, np.float32)
    wco = co[idx] @ mw[:3, :3].T + mw[:3, 3]
    hb = ARM.pose.bones[P + "Head"]
    head = np.array(ARM.matrix_world @ hb.head, np.float32)
    tail = np.array(ARM.matrix_world @ hb.tail, np.float32)
    c0 = head + (tail - head) * 0.45  # (the middle of his head, posed)
    d = wco - c0
    sph = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
    out = np.zeros_like(wco)
    for k in range(HAIR_LOCKS):
        m = lab == k
        if not m.any():
            continue
        a = sph[m].mean(0)
        a /= max(np.linalg.norm(a), 1e-6)
        perp = d[m] - (d[m] @ a)[:, None] * a[None, :]
        perp /= np.maximum(np.linalg.norm(perp, axis=1, keepdims=True), 1e-6)
        out[m] = HAIR_ROUND * perp + (1.0 - HAIR_ROUND) * sph[m]
    out /= np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-6)
    full = np.zeros((n, 3), np.float32)
    full[idx] = out
    att = me.attributes.get("hair_n") or me.attributes.new("hair_n", "FLOAT_VECTOR", "POINT")
    att.data.foreach_set("vector", full.ravel())
    lk = me.attributes.get("hair_lock") or me.attributes.new("hair_lock", "FLOAT", "POINT")
    lock_full = np.zeros(n, np.float32); lock_full[idx] = (lab + 1) / float(HAIR_LOCKS)
    lk.data.foreach_set("value", lock_full)
    # (key art k41, judge: "the highlights are radial streaks ... painterly and smudged: each big lock one crisp hard-edged
    # highlight shape") the hair's own normals smoothed across each spike (never through it: only between vertices facing
    # the same way), so its highlight band is one clean shape per spike group, not a streak per strand: attribute "hair_s"
    if HAIR_SMOOTH_IT > 0:
        vn = np.zeros(len(ev.vertices) * 3, np.float32); ev.vertex_normals.foreach_get("vector", vn); vn = vn.reshape(-1, 3)
        wn = vn[idx] @ mw[:3, :3].T
        wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-9)
        loc = np.full(n, -1, np.int64); loc[idx] = np.arange(len(idx))
        ed = np.zeros(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", ed); ed = loc[ed.reshape(-1, 2)]
        ed = ed[(ed[:, 0] >= 0) & (ed[:, 1] >= 0)]
        ed = ed[np.einsum("ij,ij->i", wn[ed[:, 0]], wn[ed[:, 1]]) > 0.3]
        sn = wn.copy()
        for _ in range(HAIR_SMOOTH_IT):
            acc = sn.copy()
            np.add.at(acc, ed[:, 0], sn[ed[:, 1]])
            np.add.at(acc, ed[:, 1], sn[ed[:, 0]])
            sn = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-9)
        full_s = np.zeros((n, 3), np.float32); full_s[idx] = sn
        hs = me.attributes.get("hair_s") or me.attributes.new("hair_s", "FLOAT_VECTOR", "POINT")
        hs.data.foreach_set("vector", full_s.ravel())
    bpy.context.view_layer.update()
    print("KEY_HAIR locks", np.bincount(lab).tolist())


def pose_key_throw():
    """The title screen (round 15): the release with the body behind it: the hips driven over the bent front knee,
    the back heel up, the shoulders turned through against the hips, the free arm pulled back hard (his armoured fist
    clear of his body), the throwing hand open, the ring away ahead of it; a gritted shout."""
    pose_key_lunge()
    feet = _feet()
    mid = (feet["Left"][0] + feet["Right"][0]) / 2  # (round 17: a narrower lunge, about 1.5 shoulder widths)
    feet = {k: (mid + (a - mid) * THROW_STANCE, f, t) for k, (a, f, t) in feet.items()}
    turn("Hips", 10.0, (0.0, 0.0, 1.0))  # the hips turned into the throw
    toward = Vector((1.0, -0.25, 0.0)).normalized()  # the throw: picture right, a little towards us
    shift_world(toward * THROW_HIPS + Vector((0.0, 0.0, -0.025)))
    _replant(feet)
    heel_up("Left", 0.55)
    turn("Spine1", THROW_TWIST * 0.5, (0.0, 0.0, 1.0))
    turn("Spine2", THROW_TWIST * 0.5, (0.0, 0.0, 1.0))
    turn("Spine", 5.0, (0.0, 1.0, 0.0))  # the chest leaning into the throw
    _aim_world("LeftArm", Vector((-0.8, 0.25, -0.35)).normalized())  # the free arm back, out from his side
    _aim_world("LeftForeArm", Vector((-0.55, 0.05, 0.1)).normalized())
    hand("Left", "fist")  # (k1's open palm lost: "a flat stop gesture that fights the throw")
    hand("Right", "release")
    ARM.pose.bones[P + "RightHand"].scale = (1.4,) * 3  # (key art k11: "hands about the size of the face"; k10 1.25)
    ARM.pose.bones[P + "LeftHand"].scale = (1.2,) * 3
    turn("Spine2", -16.0, (0.0, 0.0, 1.0))  # (key art k9: -10, "the head turns 3/4 on a profile body: the thin neck looks
    # twisted": the chest further to us, the head less)  # (key art k2: the chest a little to us, so the neck doesn't twist)
    turn("Neck", -6.0)  # (key art k1, kept: his face to us, chin up: "a stern profile, the face too small")
    turn("Head", -10.0)
    turn("Head", -9.0, (0.0, 0.0, 1.0))
    key_build()
    ring = bpy.data.objects.get("AAA_Chakram")
    if ring is not None:  # the ring well ahead of the hand on the throw's line
        fore = (bone_world("RightHand", "tail") - bone_world("RightForeArm")).normalized()
        at = bone_world("RightHand", "tail") + (fore * 0.8 + Vector((0.0, 0.0, 0.45))).normalized() * THROW_RING
        # (round 16) its blades turned to us (edge-on it read as a thin ring), tipped a little up the throw
        face = Vector((0.3, -1.0, 0.35)).normalized()
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(face).to_matrix().to_4x4()
        m = Matrix.Translation(at) @ rot @ Matrix.Diagonal((*ring.matrix_world.to_scale(), 1.0))
        ring.matrix_world = m
        bpy.context.view_layer.update()
    key_fringe_lift()
    key_hair_normals()
    key_fringe()


JUMP_LEAN = float(os.environ.get("JUMP_LEAN", "16"))  ## degrees forward his body leans in the flight


def pose_jump15(i):
    """The jump (round 16, round 14's won the A/B): round 14's split leap, stretched clear, but led by his chest and
    his near arm reaching to the ledge, the far arm back for balance, the trailing foot's toes pointed back (no sole
    to us), the head up and three-quarters to us."""
    apply(sample("jump", 1 + i))
    w = ease((i - 2) / 4.0) * (1.0 - ease((i - 15) / 4.0))  # the flight, frames 3-18
    turn("Head", -14.0 * (1.0 - w))  # (round 17: his face to us on every frame, take-off and landing too)
    turn("Head", -26.0 * (1.0 - w), (0.0, 0.0, 1.0))
    if w <= 0.0:
        hand("Right", "relaxed")
        hand("Left", "relaxed")
        return
    base = current()
    turn("Spine", 6.0)  # the chest leading
    turn("Spine1", 4.0)
    aim("RightArm", 0.9, 0.0, 0.3)  # the near arm ahead to the ledge, under his face (round 17: raised, it hid it)
    aim("RightForeArm", 0.95, 0.15, 0.1)
    aim("LeftArm", -0.55, 0.2, -0.3)  # the far arm back for balance
    aim("LeftForeArm", -0.85, 0.05, -0.2)
    aim("RightUpLeg", 0.85, -0.3)  # round 14's split
    aim("RightLeg", 0.3, -0.95)
    aim("LeftUpLeg", -0.45, -0.85)
    aim("LeftLeg", -0.85, -0.4)
    aim("LeftFoot", -0.95, -0.15)
    turn("Head", -30.0)  # chin up
    turn("Head", -42.0, (0.0, 0.0, 1.0))  # three-quarters to us (round 17: further, the hair hid his face mid-flight)
    apply(mix(base, current(), w))
    hand("Right", "open")
    hand("Left", "relaxed")


RUN_LEAN = float(os.environ.get("RUN_LEAN", "14"))  ## degrees forward his body leans in the run (round 14: ~45)


def _lean():
    """Degrees his back leans forward from upright, as the side camera sees it (hips to neck)."""
    d = bone_world("Neck") - bone_world("Hips")
    return math.degrees(math.atan2(-d.y, d.z))  # (side view: screen x is -y)


def pose_run15(i):
    """The run (round 15): the authored stride with his chest up (a forward lean of RUN_LEAN, not a stoop), the head
    up, a higher knee drive and a bigger arm pump; fists."""
    apply(sample_jog(1 + i))
    over = _lean() - RUN_LEAN
    turn("Spine", -over * 0.45)
    turn("Spine1", -over * 0.35)
    turn("Spine2", -over * 0.2)
    turn("Neck", -6.0)
    turn("Head", -8.0)
    for side in ("Right", "Left"):  # the knee in front drives higher
        d = bone_world(side + "Leg") - bone_world(side + "UpLeg")
        if -d.y > 0.02:  # (side view: x is -y) this thigh is in front
            turn(side + "UpLeg", -14.0)
            turn(side + "Leg", 8.0)
        a = bone_world(side + "ForeArm") - bone_world(side + "Arm")  # the arms swing further
        turn(side + "Arm", 16.0 if -a.y < 0 else -16.0)
        turn(side + "ForeArm", -12.0)
    hand("Right", "fist")
    hand("Left", "fist")


_grip = [None]  ## the hand he hangs by (both hand points of the frame are put at it: the game hangs him from them)


def pose_hang15(t, turn_k=1.0):
    """Hanging (round 15): by his far hand, the near arm out, his hips swung forward and his knees bent, swinging."""
    apply(sample("idle", 1 + t * 59))
    ARM.rotation_euler.z = math.radians(HANG_TURN * turn_k)
    bpy.context.view_layer.update()
    s = math.sin(t * math.tau)
    c = math.cos(t * math.tau)
    turn("Spine", -6 + 3 * s)  # (his back arched a little: the hips forward)
    aim("LeftArm", 0.05, 1.0, -0.1)  # the far hand on the vine
    aim("LeftForeArm", 0.08, 1.0, -0.02)
    aim("LeftHand", 0.05, 1.0)
    aim("RightArm", 0.9, 0.25 + 0.1 * s, 0.35)  # the near arm out, open
    aim("RightForeArm", 0.95, 0.4 + 0.1 * s, 0.2)
    aim("RightUpLeg", 0.95, -0.35 + 0.25 * s)  # the hips swung forward, the thighs up, both knees bent
    aim("RightLeg", 0.12 + 0.2 * c, -1.0)
    aim("RightFoot", 0.7, -0.7)
    aim("LeftUpLeg", 0.8, -0.6 + 0.25 * s)
    aim("LeftLeg", -0.15 + 0.2 * c, -1.0)
    aim("LeftFoot", 0.5, -0.85)
    turn("Head", -10.0)
    hand("Left", "fist")
    hand("Right", "open")
    top = bone_world("LeftHand", "tail").z
    shift_hips(0.0, HANG_TOP - top)
    _grip[0] = "LeftHand"


def pose_idle15(i):
    """The start (round 16, round 14's won the A/B): round 14's upright stance (chin up, his face three-quarters to us)
    with a forward lean, ready; the arms loose, the hands relaxed (no boxing guard)."""
    apply(sample("idle", 1 + i * 3))
    b = math.sin(i / 20.0 * math.tau)
    # (round 17, "a T-pose that hasn't been animated") contrapposto: his weight on the far leg, the near knee bent and
    # forward, the hips tilted and the shoulders against them, the chakram held at his side
    turn("Hips", 4.0, (0.0, 1.0, 0.0))
    turn("Spine1", -7.0, (0.0, 1.0, 0.0))
    aim("RightUpLeg", 0.32, -0.95, 0.06)
    aim("RightLeg", -0.12, -1.0)
    aim("RightFoot", 1.0, -0.3)
    aim("LeftUpLeg", -0.05, -1.0, -0.04)
    aim("LeftLeg", 0.0, -1.0)
    turn("Spine", 4.0 + 0.8 * b)
    turn("Neck", -6.0)
    turn("Head", -12.0)  # chin up
    turn("Head", -26.0, (0.0, 0.0, 1.0))
    aim("RightArm", 0.12, -1.0, 0.25)  # the ring hand low at his side, the other on his hip
    aim("RightForeArm", 0.4, -0.9, 0.15)
    aim("LeftArm", -0.35, -0.9, -0.3)
    aim("LeftForeArm", 0.6, 0.3, -0.25)
    plant(0.0)
    hand("Right", "relaxed")
    hand("Left", "fist")
    ring = bpy.data.objects.get("AAA_Chakram")
    if ring is not None:
        ring.hide_render = False
        at = (bone_world("RightHand") + bone_world("RightHand", "tail")) / 2
        face = Vector((0.0, 1.0, 0.25)).normalized()  # (side view: its flat to the camera)
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(Vector((1.0, 0.0, 0.15)).normalized()).to_matrix().to_4x4()
        ring.matrix_world = Matrix.Translation(at + Vector((-0.03, 0.0, -0.05))) @ rot @ Matrix.Diagonal((*ring.matrix_world.to_scale(), 1.0))
        bpy.context.view_layer.update()


def pose_win15():
    """The win picture (round 15): the leap of joy with its finish: the whole body turned three-quarters (hips and
    shoulders together), the front knee tucked high, the trailing leg driven long behind, his right fist punched up
    and out clear of his head, the armoured arm swung up on the other side; an open grin."""
    pose_authored("key_win")
    ARM.rotation_euler.z = math.radians(WIN_TURN)
    bpy.context.view_layer.update()
    # (front camera: x picture right, -y towards us, z up; facing us his right is picture left)
    _aim_world("RightArm", Vector((-0.35, -0.25, 0.9)).normalized())
    _aim_world("RightForeArm", Vector((-0.25, -0.3, 0.92)).normalized())
    _aim_world("RightHand", Vector((-0.15, -0.25, 0.95)).normalized())
    _aim_world("LeftArm", Vector((0.88, -0.1, 0.45)).normalized())  # (round 17: wide out, nothing across his chest)
    _aim_world("LeftForeArm", Vector((0.7, -0.15, 0.7)).normalized())
    _aim_world("RightUpLeg", Vector((-0.4, -0.6, 0.35)).normalized())  # the front knee up, towards us
    _aim_world("RightLeg", Vector((-0.4, 0.15, -0.9)).normalized())  # (round 16: the shin down and out, "a stump")
    _aim_world("RightFoot", Vector((-0.3, -0.4, -0.86)).normalized())
    _aim_world("LeftUpLeg", Vector((0.5, 0.42, -0.75)).normalized())  # the trailing leg long behind him
    _aim_world("LeftLeg", Vector((0.55, 0.55, -0.6)).normalized())
    _aim_world("LeftFoot", Vector((0.5, 0.45, -0.72)).normalized())
    turn("Neck", -6.0)
    turn("Head", -8.0)
    hand("Right", "fist")
    hand("Left", "open")


WIN_TURN = float(os.environ.get("WIN_TURN", "-28"))  ## degrees the win picture's body turns from facing us


def pose_home15(t):
    """Home (round 15): he stops, turns three-quarters to us and cheers: his weight on one leg, the other knee bent
    and lifted on the beat (a hop), the hips shifted, his back arched, one fist punched up, the other arm waving;
    a big smile."""
    turn_t = ease(t / 0.3)
    run = sample_jog(1)
    apply(sample("idle", 1 + t * 30))
    ARM.rotation_euler.z = math.radians(HOME_TURN * turn_t)
    bpy.context.view_layer.update()
    up = ease((t - 0.1) / 0.3)
    beat = 0.5 + 0.5 * math.sin((t - 0.4) / 0.6 * math.tau * 2) if t > 0.4 else 1.0
    aim("RightArm", -0.2 + 0.1 * up, -0.95 + 1.95 * up, 0.3 * up)
    aim("RightForeArm", -0.1, 0.1 + 0.9 * up, 0.25 * up)
    aim("LeftArm", 0.45 + 0.4 * up, -0.95 + 1.35 * up, -0.1)
    aim("LeftForeArm", 0.2 + 0.25 * beat * up, 0.2 + 0.8 * up, -0.1)
    turn("Spine", -7.0 * up)  # the back arched
    turn("Spine1", -5.0 * up)
    turn("Spine", 8.0 * up, (1.0, 0.0, 0.0))
    turn("Head", -12.0 * up)
    turn("Head", -18.0 * up, (0.0, 0.0, 1.0))  # (round 16) his face to us, chin up
    aim("LeftUpLeg", 0.8 * up * (0.6 + 0.4 * beat), -1.0 + 0.6 * up * beat, -0.3 * up)  # (round 17: the knee driven up
    aim("LeftLeg", -0.1 * up, -1.0)  # and forward, out to his side, never in)
    aim("RightUpLeg", -0.08 * up, -1.0, 0.08 * up)
    aim("RightLeg", 0.05 * up, -1.0)
    plant(0.0)
    if t > 0.4:
        shift_hips(0.0, 0.025 * beat)
    hand("Right", "fist")
    hand("Left", "open")
    if t < 0.15:
        cheer = current()
        apply(mix(run, cheer, ease(t / 0.15)))


HOME_TURN = float(os.environ.get("HOME_TURN", "-62"))  ## degrees he turns to us at home (round 14: -90, "his back turned")


DIZZY_R = 0.15  ## metres: the radius of the stars' circle round his head


def _dizzy_round_head(drop):
    """The dizzy stars orbiting his head wherever the pose put it (round 16, "one star like a hair clip": five, evenly
    round a level ring at his brow, tipped to us so all five show); the authored trail (placed for the authored slump,
    it stood on its edge beside him) left out."""
    obs = [ob for ob in bpy.data.objects if ob.name.startswith(("AAA_DizzyStar", "AAA_DizzyTrail")) and not ob.hide_render]
    for ob in obs:
        if ob.name.startswith("AAA_DizzyTrail"):
            ob.hide_render = True
    stars = sorted((ob for ob in obs if ob.name.startswith("AAA_DizzyStar")), key=lambda ob: ob.name)
    if not stars:
        return
    while len(stars) < 5:  # copies of the authored stars (render only, never saved)
        extra = stars[len(stars) % 3].copy()
        extra.name = f"AAA_DizzyStarCopy{len(stars)}"
        for col in stars[0].users_collection:
            col.objects.link(extra)
        stars.append(extra)
    head, top = bone_world("Head"), bone_world("HeadTop_End")
    centre = head + (top - head) * 0.85 + Vector((0.0, 0.0, -drop))
    a = Vector((1.0, 0.0, 0.0))  # (picture right)
    b = Vector((0.0, -0.5, 0.35)).normalized()  # (towards us and up: the ring tipped so its back rises over his hair)
    for k, ob in enumerate(stars):
        ang = math.radians(90.0 + 72.0 * k + 36.0)
        m = ob.matrix_world.copy()
        m.translation = centre + (a * math.cos(ang) - b * math.sin(ang)) * DIZZY_R
        ob.matrix_world = m
    bpy.context.view_layer.update()


def pose_defeat15():
    """Game over (round 15): knocked out, not resting: sat back on the ground, his spine sagging, his head lolling to
    one side, one arm braced behind him, the other limp over his knee, one leg out along the ground and the other
    knee up: four clear shapes; the dizzy ring round his head."""
    pose_authored("key_defeat", stars=True)
    chunky_stars()
    ARM.rotation_euler.z = math.radians(DEFEAT_TURN)
    bpy.context.view_layer.update()
    # (round 17, "one clear KO silhouette, no sole pancake at the camera") both legs out along the ground to the
    # picture's left, side by side, toes up; the near knee a little raised
    _aim_world("RightUpLeg", Vector((-0.9, -0.3, -0.05)).normalized())
    _aim_world("RightLeg", Vector((-0.92, -0.25, -0.2)).normalized())
    _aim_world("RightFoot", Vector((-0.3, -0.1, 0.95)).normalized())
    _aim_world("LeftUpLeg", Vector((-0.8, -0.35, 0.3)).normalized())
    _aim_world("LeftLeg", Vector((-0.85, -0.2, -0.45)).normalized())
    _aim_world("LeftFoot", Vector((-0.25, -0.1, 0.96)).normalized())
    turn("Spine", -14.0, (1.0, 0.0, 0.0))  # leaning back on the braced arm, sagging
    turn("Spine1", 10.0, (1.0, 0.0, 0.0))
    turn("Spine1", 8.0, (0.0, 1.0, 0.0))
    _aim_world("RightArm", Vector((-0.55, 0.4, -0.73)).normalized())  # braced behind him
    _aim_world("RightForeArm", Vector((-0.35, 0.3, -0.89)).normalized())
    _aim_world("RightHand", Vector((-0.5, 0.0, -0.86)).normalized())
    _aim_world("LeftArm", Vector((0.35, -0.2, -0.92)).normalized())  # limp at his side, the hand on the ground
    _aim_world("LeftForeArm", Vector((0.2, -0.45, -0.87)).normalized())
    turn("Neck", 10.0, (0.0, 1.0, 0.0))
    turn("Head", 24.0, (0.0, 1.0, 0.0))  # lolling
    turn("Head", -12.0, (1.0, 0.0, 0.0))
    hand("Right", "brace")
    hand("Left", "relaxed")
    for panel in ("AAA_PanelFront", "AAA_PanelBack"):  # (sat on the ground, the panels stiff with his hips would
        ob = bpy.data.objects.get(panel)  # stand down through it)
        if ob is not None:
            ob.hide_render = True
    seat = bone_z("Hips") - 0.085
    low = min(seat, bone_z("RightToe_End"), bone_z("LeftToe_End"), bone_z("RightHand", "tail"))
    shift_hips(0.0, 0.0 - low)
    _dizzy_round_head(DIZZY_DROP)


DIZZY_DROP = float(os.environ.get("DIZZY_DROP", "-0.02"))  ## metres the dizzy ring comes down, round his brow


def pose_portrait():
    """The HUD badge's and the cards' portrait (round 16: the new face): standing, a little turned, his face
    three-quarters to us, chin up."""
    reset_turn()
    apply(sample("idle", 1))
    ARM.rotation_euler.z = math.radians(-18.0)
    bpy.context.view_layer.update()
    turn("Neck", -4.0)
    turn("Head", -8.0)
    turn("Head", -8.0, (0.0, 0.0, 1.0))
    hand("Right", "relaxed")
    hand("Left", "relaxed")


# name -> (camera view, frames: callables or (action, frame), camera lift in metres)
def anims():
    out = {}
    out["run"] = ("side", [lambda i=i: pose_run15(i) for i in range(16)])
    out["jump"] = ("side", [lambda i=i: pose_jump15(i) for i in range(27)])
    out["idle"] = ("side", [lambda i=i: pose_idle15(i) for i in range(20)])
    out["idle_front"] = ("front", [("idle", 1 + i * 2) for i in range(30)])
    out["die"] = ("other_side", [("die", f) for f in list(range(1, 50, 2)) + [62, 78]])
    out["hang"] = ("side", [lambda i=i: pose_hang15(i / 12.0) for i in range(12)])
    out["catch"] = ("side", [lambda i=i: pose_catch((i + 1) / 4.0) for i in range(4)])
    out["throw"] = ("side", [lambda i=i, s=s: pose_throw(i, s) for s in (0, 1) for i in range(16)])
    out["crouch"] = ("side", [lambda i=i: pose_crouch((i + 1) / 4.0) for i in range(4)])
    out["hurt"] = ("side", [lambda i=i: pose_hurt(i / 9.0) for i in range(10)])
    out["climb"] = ("side", [lambda i=i: pose_climb(i / 7.0) for i in range(8)])
    out["win"] = ("side", [lambda i=i: pose_home15(i / 23.0) for i in range(24)], 0.2)
    out["menu"] = ("front", [lambda k=k: pose_menu(k) for k in range(4)], 0.1)
    # the interface pictures: front camera, looking a little up at him (his face under his hair)
    out["menu_hero"] = ("front", [lambda: pose_key_art()], 0.1, 7.0)
    out["defeat"] = ("front", [lambda: pose_seated()], -0.15, 3.0)
    out["win_front"] = ("front", [lambda: pose_celebrate()], 0.15, 7.0)
    if "key_menu" in ACTIONS:  # (hero pass 2: the poses authored by hand on the timeline)
        out["menu_hero"] = ("front", [lambda: pose_key_throw()], -0.06, 6.0)
        out["win_front"] = ("front", [lambda: pose_win15()], -0.03, 7.0)
        out["defeat"] = ("front", [lambda: pose_defeat15()], 0.03, float(os.environ.get("DEFEAT_TILT", "-4")))  # (looking down a little: he sits on the ground)
    out["portrait"] = ("front", [lambda: pose_portrait()], 0.1, 7.0)
    if arg("--hands"):  # the hand shapes, for reviews (--anims hands --hands)
        out["hands"] = ("front", [lambda k=k: (apply(sample("idle", 1)), hand("Right", k), hand("Left", k)) for k in HANDS], 0.0)
    if arg("--turn"):  # the turnaround, for reviews (--anims turn --turn)
        out["turn"] = ("front", [lambda k=k: pose_turn(k) for k in range(4)], 0.0)
    return out



# ------------------------------------------------------------------ the bandit (--character bandit)
# The masked raider, built from the hero's own mesh and rig so he sits in the same light. Round 9 ("an indigo
# blob mid-cartwheel, unreadable as a threat"): rendered from the AAA file in the hero's bold cel language (his
# regions rebuilt by hero_toon_aaa.py in the raider's flat colours, the same inner ink), his hair taken off
# under a hooded mask: a round dark cowl, a red band at the eyes with two tails streaming back, slanted
# glowing eyes, a heavy studded club raised over his shoulder, and a cold cyan rim on the sun's side (the
# hero's is hot orange): a dark, simple silhouette with one red accent, never mistaken for Panoramic.
# Rendered from the other side (he runs left, at Panoramic). The user's file still renders the round 8 colours.


def _lin(*c):
    """sRGB -> linear (the toon materials are emissions: their colours are linear)."""
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


BANDIT_ALBEDO = {  # the AAA regions in the raider's colours (sRGB; flat, no texture)
    "skin": (0.2, 0.17, 0.27), "face": (0.2, 0.17, 0.27), "hand": (0.2, 0.17, 0.27),
    "hair": (0.1, 0.09, 0.14), "eye": (0.1, 0.09, 0.14),
    "fur": (0.33, 0.29, 0.62),  # the wraps: torn indigo cloth (the fur's strands and stepped edge kept)
    "scarf": (0.2, 0.17, 0.27),  # the scarf: as dark as his skin (the red is the mask's alone)
    "armour_blue": (0.22, 0.18, 0.24), "armour_silver": (0.62, 0.46, 0.27),  # dark leather, dull bronze
    "belt": (0.32, 0.2, 0.13),
}
BANDIT_PROPS_ALBEDO = {"hood": (0.24, 0.21, 0.4), "band": (0.92, 0.12, 0.1), "club": (0.88, 0.8, 0.64)}
BANDIT_RIM = (0.35, 0.95, 1.0)  ## sRGB: his cold rim on the sun side (the hero's is hot orange)
BANDIT_RIM_K = 0.35  ## (in 3D a light touch: bandit_sheet.py draws the strong band round his outline)


def _material(name, colour, rough=0.7, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*colour, 1.0)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    return m


def _toon_prop(name, region, srgb):
    """A prop's material for the AAA cel shading (hero_toon_aaa.py builds it): a region's bands, a flat colour."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m["toon"] = region
    m["flat"] = _lin(*srgb)
    m["rim"] = _lin(*BANDIT_RIM)
    m["rim_k"] = BANDIT_RIM_K
    m["aaa_base"] = "AAA_albedo"  # (no picture: the flat colour)
    m["aaa_normal"] = ""
    return m


def _basis(x, z, y=None):
    """A rotation (Euler) whose local z is `z` and local x is as close to `x` as it can be (or local y given)."""
    z = Vector(z).normalized()
    if y is not None:
        y = Vector(y).normalized()
        x = y.cross(z).normalized()
        y = z.cross(x)
    else:
        x = (Vector(x) - z * Vector(x).dot(z)).normalized()
        y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_euler()


def _attach(ob, bone):
    """Parents an object to a bone, keeping where it is now."""
    mw = ob.matrix_world.copy()
    ob.parent = ARM
    ob.parent_type = "BONE"
    ob.parent_bone = P + bone
    bpy.context.view_layer.update()
    ob.matrix_world = mw


def bone_world(name, end="head"):
    pb = ARM.pose.bones[P + name]
    return ARM.matrix_world @ (pb.head if end == "head" else pb.tail)


BANDIT_PROPS = []


def _smooth(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth()


def _bandit_colours_user():
    """The user's file (round 8): his picture's light and dark mapped to blue-black skin and indigo wraps."""
    for m in MESH.data.materials:
        nodes, links = m.node_tree.nodes, m.node_tree.links
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        tex = next(l.from_node for l in links if l.to_socket == bsdf.inputs["Base Color"])
        bw = nodes.new("ShaderNodeRGBToBW")
        ramp = nodes.new("ShaderNodeValToRGB")
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.05, (0.03, 0.015, 0.03, 1)
        el[1].position, el[1].color = 0.72, (0.16, 0.2, 0.75, 1)  # the wraps: deep indigo
        mid = el.new(0.3)
        mid.color = (0.05, 0.04, 0.09, 1)  # the skin: blue-black
        links.new(tex.outputs["Color"], bw.inputs["Color"])
        links.new(bw.outputs["Val"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.62


def _bandit_colours_aaa():
    """The AAA file: every region in the raider's flat colour and cold rim; the hair masked off (the cowl
    covers his head: only the vertices no other region uses go)."""
    hair = None
    for i, m in enumerate(MESH.data.materials):
        region = m.get("toon")
        m["flat"] = _lin(*BANDIT_ALBEDO[region])
        m["rim"] = _lin(*BANDIT_RIM)
        m["rim_k"] = BANDIT_RIM_K
        if region == "hair":
            hair = i
    me = MESH.data
    mi = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", mi)
    total = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_total", total)
    vi = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", vi)
    of_loop = np.repeat(mi, total)
    keep = np.zeros(len(me.vertices), bool)
    keep[vi[of_loop != hair]] = True
    vg = MESH.vertex_groups.new(name="bandit_keep")
    vg.add(np.nonzero(keep)[0].tolist(), 1.0, "REPLACE")
    md = MESH.modifiers.new("BanditNoHair", "MASK")
    md.vertex_group = vg.name
    print("BANDIT hair masked:", int((~keep).sum()), "vertices")


def make_bandit():
    if AAA:
        _bandit_colours_aaa()
    else:
        _bandit_colours_user()
    apply(sample("idle", 1))
    head = bone_world("Head")
    top = bone_world("HeadTop_End")
    up = (top - head).normalized()
    size = (top - head).length
    fwd = Vector((0.0, -1.0, 0.0))  # he faces -y
    fwd = (fwd - up * fwd.dot(up)).normalized()  # (the head's own frame: it leans a little at rest)
    side = up.cross(fwd).normalized()  # his left: towards the other-side camera
    centre = head + up * size * 0.5 + fwd * size * 0.06
    rot = _basis(side, up)  # the head's frame: x across, y back, z up
    hood_m = _toon_prop("BanditHood", "scarf", BANDIT_PROPS_ALBEDO["hood"]) if AAA else _material("Hood", (0.05, 0.04, 0.12), 0.6)
    band_m = _toon_prop("BanditBand", "scarf", BANDIT_PROPS_ALBEDO["band"]) if AAA else _material("Mask", (0.95, 0.04, 0.03), 0.5)
    # the cowl: a round hood over his whole head (the hair masked off), a little egg-shaped, a soft peak at the back
    bpy.ops.mesh.primitive_uv_sphere_add(radius=size * 0.6, location=centre, segments=48, ring_count=24)
    hood = bpy.context.object
    hood.rotation_euler = rot
    hood.scale = (0.9, 1.04, 1.06)
    hood.data.materials.append(hood_m)
    back_up = (up * 0.3 - fwd).normalized()  # the cowl's point: back and a little up (a hood, not a ball)
    bpy.ops.mesh.primitive_cone_add(radius1=size * 0.34, depth=size * 0.75, vertices=32,
                                    location=centre + back_up * size * 0.58)
    peak = bpy.context.object
    peak.rotation_euler = _basis(side, back_up)
    peak.data.materials.append(hood_m)
    # the mask: a red band round the cowl at the eyes, knotted at the back with two tails streaming back
    eyes_at = centre + up * size * 0.06
    bpy.ops.mesh.primitive_cylinder_add(radius=size * 0.6, depth=size * 0.2, location=eyes_at, vertices=48)
    band = bpy.context.object
    band.rotation_euler = rot
    band.scale = (0.93, 1.07, 1.0)
    band.data.materials.append(band_m)
    parts = [hood, peak, band]
    for k, (length, lift) in enumerate(((size * 1.15, 0.38), (size * 0.9, 0.05))):
        bpy.ops.mesh.primitive_cone_add(radius1=size * 0.13, radius2=size * 0.03, depth=length, vertices=4)
        tail = bpy.context.object
        d = (-fwd + up * lift).normalized()
        tail.rotation_euler = _basis(side, d)
        tail.scale = (0.3, 1.0, 1.0)  # a flat ribbon, broad to the camera
        tail.location = eyes_at - fwd * size * 0.55 + d * length * 0.5 + side * size * (0.04 - 0.08 * k)
        tail.data.materials.append(band_m)
        parts.append(tail)
    # slanted glowing eyes on the band, on its front quarters (he is seen in profile: the near one shows)
    eye_mat = bpy.data.materials.new("Eyes")
    eye_mat.use_nodes = True
    nt = eye_mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    em = _node(nt, "ShaderNodeEmission", Color=(*_lin(1.0, 0.93, 0.45), 1), Strength=1.0)
    nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
    for sgn in (-1.0, 1.0):
        a = math.radians(42)
        n = (fwd * math.cos(a) + side * sgn * math.sin(a)).normalized()
        bpy.ops.mesh.primitive_uv_sphere_add(radius=size * 0.11, location=eyes_at + n * size * 0.6)  # (big: they read in play)
        eye = bpy.context.object
        tangent = up.cross(n).normalized()
        eye.rotation_euler = (Matrix.Rotation(sgn * math.radians(18), 3, n) @ _basis(tangent, up, n).to_matrix()).to_euler()
        eye.scale = (1.6, 0.6, 0.55)  # long across the band, thin
        eye.data.materials.append(eye_mat)
        parts.append(eye)
    for ob in parts:
        _smooth(ob)
        _attach(ob, "Head")
    # the club, in the hand nearer the other-side camera (his left), carried on from his forearm: a heavy
    # knobkerrie, the knob studded (a weapon at phone size, not a bone)
    apply(sample("run", 1))
    hand = bone_world("LeftHand")
    shaft = (bone_world("LeftHand", "tail") - bone_world("LeftForeArm")).normalized()
    length = 0.36
    bpy.ops.mesh.primitive_cone_add(radius1=0.019, radius2=0.03, depth=length, vertices=24, location=hand + shaft * length * 0.45)
    club = bpy.context.object
    club.rotation_euler = shaft.to_track_quat("Z", "Y").to_euler()
    knob_at = hand + shaft * length * 0.95
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.062, location=knob_at, segments=32, ring_count=16)
    knob = bpy.context.object
    knob.scale = (1.0, 1.0, 1.15)
    knob.rotation_euler = club.rotation_euler
    pieces = [club, knob]
    q = shaft.to_track_quat("Z", "Y")
    for k in range(7):  # studs round the knob and one on its crown
        a = k * math.tau / 6.0
        d = (q @ Vector((math.cos(a), math.sin(a), 0.25)).normalized()) if k < 6 else shaft
        bpy.ops.mesh.primitive_cone_add(radius1=0.02, depth=0.05, vertices=12, location=knob_at + d * 0.064)
        stud = bpy.context.object
        stud.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        pieces.append(stud)
    wood = _toon_prop("BanditClub", "belt", BANDIT_PROPS_ALBEDO["club"]) if AAA else _material("Club", (0.85, 0.8, 0.68), 0.45)
    for ob in pieces:
        _smooth(ob)
        ob.data.materials.append(wood)
        _attach(ob, "LeftHand")
    BANDIT_PROPS.extend(pieces)


def club_visible(on):
    for ob in BANDIT_PROPS:
        ob.hide_render = not on


def bandit_run(frame):
    """The user's sprint (full stride: the bandits run 291 units/s against the ground), his lowest foot on the
    ground (its hips' root motion is muted)."""
    apply(sample("user_run" if AAA else "run", frame))
    plant(0.0)


def run_full(i):
    """The run, the club raised over his shoulder (round 6: a bigger, readable threat silhouette)."""
    bandit_run(1 + i)
    turn("Spine", -7)  # (round 8: less crouched, a taller silhouette)
    turn("Spine1", -4)
    # the club cocked high behind his head, ready to strike (round 9: the arm no longer crosses the cowl)
    aim("LeftArm", -0.5, 0.55, -0.35)
    aim("LeftForeArm", -0.62, 0.78, -0.1)  # (the knob up behind his head, inside the sheet's cell)
    club_visible(True)


def pose_daze(i):
    """Running dazed after a ring: head lolling, the club arm hanging."""
    run_full(i)
    turn("Head", 18)
    turn("Spine1", 8)
    aim("LeftArm", -0.15, -1.0, -0.2)
    aim("LeftForeArm", 0.25, -1.0)


def pose_swing(i):
    """The club over his head (0-3, drawn back further each frame), the blow (4-5), the follow
    through (6-7); the legs keep running."""
    run_full(i * 2)
    if i < 4:
        k = (i + 1) / 4.0
        turn("Spine", -8 * k)
        aim("LeftArm", -0.5 - 0.15 * k, 0.55 + 0.25 * k, -0.35)  # (from the run's cocked club)
        aim("LeftForeArm", -0.62 - 0.3 * k, 0.78 - 0.35 * k, -0.1)
    elif i < 6:
        k = (i - 3) / 2.0
        turn("Spine", 10 * k)
        aim("LeftArm", 0.9, 0.5 - 0.7 * k, -0.25)
        aim("LeftForeArm", 1.0, 0.3 - 0.9 * k, -0.1)
    else:
        turn("Spine", 12)
        aim("LeftArm", 0.5, -0.9, -0.25)
        aim("LeftForeArm", 0.6, -0.8, -0.1)


def pose_bandit_ko(k):
    """Knocked out (round 9: no cartwheel; one readable shape): 0 the blow, snapped back, head whipped back;
    1 flung back through the air, a C opening towards the ring: back first, head back, arms and legs
    thrown forward."""
    club_visible(False)  # it flies off on its own (club.png)
    if k == 0:
        bandit_run(3)
        turn("Spine", -22)
        turn("Spine1", -12)
        turn("Neck", -16)
        turn("Head", -18)
        aim("RightArm", 0.75, 0.6, 0.3)
        aim("RightForeArm", 0.55, 0.85)
        aim("LeftArm", 0.55, 0.75, -0.3)
        aim("LeftForeArm", 0.4, 0.95)
        aim("RightUpLeg", 0.55, -0.85)
        aim("RightLeg", 0.2, -1.0)
        plant(0.0)
    else:
        apply(sample("idle", 1))
        turn("Spine", -26)
        turn("Spine1", -16)
        turn("Neck", -18)
        turn("Head", -20)
        aim("RightArm", 0.95, 0.45, 0.35)
        aim("RightForeArm", 0.9, 0.55)
        aim("RightHand", 0.9, 0.4)
        aim("LeftArm", 0.8, 0.75, -0.35)
        aim("LeftForeArm", 0.65, 0.85)
        aim("RightUpLeg", 0.95, -0.4, 0.1)
        aim("RightLeg", 0.85, -0.6)
        aim("LeftUpLeg", 0.6, -0.8, -0.1)
        aim("LeftLeg", 0.15, -1.0)
        aim("LeftFoot", 0.9, -0.3)
        aim("RightFoot", 1.0, 0.1)


def pose_leap():
    """Leaping (over a wall, over Panoramic once he has struck): knees tucked, the club raised high."""
    apply(sample("jump", 12))
    turn("Spine", 8)
    aim("LeftArm", 0.25, 0.95, -0.3)
    aim("LeftForeArm", -0.35, 0.95, -0.1)
    club_visible(True)


def pose_wait(k):
    """Waiting to pounce: crouched low, breathing (k 0 or 1)."""
    pose_kneel()
    aim("RightUpLeg", 0.9, -0.3)
    aim("RightLeg", -0.3, -1.0)
    plant(0.0)
    turn("Spine", 4 * k)
    club_visible(True)


def club_alone():
    """The club by itself (it flies off when he is knocked out): the body hidden."""
    run_full(0)
    MESH.hide_render = True
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent == ARM and ob.parent_bone == P + "Head":
            ob.hide_render = True


def bandit_anims():
    out = {}
    out["b_run"] = ("other_side", [lambda i=i: run_full(i) for i in range(16)])
    out["b_daze"] = ("other_side", [lambda i=i: pose_daze(i) for i in range(16)])
    out["b_ko"] = ("other_side", [lambda k=k: pose_bandit_ko(k) for k in range(2)])
    out["b_wait"] = ("other_side", [lambda k=k: pose_wait(k) for k in range(2)])
    out["b_swing"] = ("other_side", [lambda i=i: pose_swing(i) for i in range(8)])
    out["b_leap"] = ("other_side", [lambda: pose_leap()])
    out["b_club"] = ("other_side", [lambda: club_alone()])
    return out


# ------------------------------------------------------------------ the toon look (round 4)
# One rendering language with the painted world (like PoP: The Lost Crown's characters): flat cel
# bands from the world's sun (no specular sheen, no normal-map muscle grooves), a cool violet shade
# band (a warm-dark one when backlit), a warm rim on the edges facing the sun, the hair as a dark
# blue-black mass with a painted highlight band, and an ink line: an inverted hull (thin, on every
# contour and where one limb crosses another); tools/art/hero_atlas.py thickens it round the
# silhouette.

TOON = {
    # shade, mid, lit (multipliers of the albedo), rim colour, rim strength, rim width
    "day": ((0.5, 0.43, 0.62), (0.8, 0.72, 0.7), (1.06, 0.98, 0.88), (1.0, 0.8, 0.5), 1.3, 0.48),
    "sunset": ((0.5, 0.36, 0.4), (0.7, 0.52, 0.5), (1.0, 0.82, 0.64), (1.0, 0.5, 0.15), 2.3, 0.38),
}
TOON_CLOTH = {  # the cloth's bands: shade, mid, lit (warm cream, never grey)
    "day": ((0.78, 0.66, 0.55), (0.93, 0.85, 0.74), (1.04, 1.0, 0.93)),
    "sunset": ((0.6, 0.44, 0.38), (0.8, 0.62, 0.5), (1.0, 0.86, 0.7)),
}
INK = (0.022, 0.006, 0.003)  ## linear (an emission): the warm dark brown sRGB (0.16, 0.07, 0.04).
## (Round 6: it was given as sRGB values, so it rendered as a light grey-brown line round him, the
## "grey / silver outline" the judge saw; hero_atlas.py's INK is sRGB and was right.)
INK_WIDTH = 0.003  ## scene units (about 0.9 px in the game's atlas)


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def _math(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def toon_material(m, mode):
    if m.get("toon") and AAA:  # the AAA hero's regions: their own form shading (hero_toon_aaa.py)
        _aaa_toon().build(m, mode)
        return
    nt = m.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    emit = bsdf.inputs["Emission Strength"].default_value
    if emit > 0.5:  # glowing eyes stay as they are
        return
    base_link = next((l for l in nt.links if l.to_socket == bsdf.inputs["Base Color"]), None)
    if base_link:
        albedo = base_link.from_socket
    else:
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = bsdf.inputs["Base Color"].default_value
        albedo = rgb.outputs[0]
    shade, mid, lit, rim_c, rim_k, rim_w = TOON[mode]
    diffuse = _node(nt, "ShaderNodeBsdfDiffuse", Color=(1, 1, 1, 1))
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(diffuse.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs["Color"], bw.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "LINEAR"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (*shade, 1)
    el[1].position, el[1].color = 1.0, (*lit, 1)
    for pos, col in ((0.16, shade), (0.22, mid), (0.5, mid), (0.56, lit)):
        e = el.new(pos)
        e.color = (*col, 1)
    nt.links.new(bw.outputs[0], ramp.inputs["Fac"])
    # the cloth (a light, unsaturated albedo: the loincloth, the wraps): its folds from the normal
    # map and a warm cream shade (round 5: it read as grey jagged paper); the blue boots and arm
    # (the user's design) kept, a little warmer and less saturated in the light
    hsv = nt.nodes.new("ShaderNodeSeparateColor")
    hsv.mode = "HSV"
    nt.links.new(albedo, hsv.inputs[0])
    clamp01 = lambda v: _math(nt, "MAXIMUM", _math(nt, "MINIMUM", v, 1.0), 0.0)  # noqa: E731
    cloth = _math(nt, "MULTIPLY", clamp01(_math(nt, "MULTIPLY", _math(nt, "SUBTRACT", hsv.outputs[2], 0.55), 6.0)),
                  clamp01(_math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 0.3, hsv.outputs[1]), 6.0)))
    blue = _math(nt, "MULTIPLY", clamp01(_math(nt, "MULTIPLY", _math(nt, "SUBTRACT", hsv.outputs[1], 0.35), 5.0)),
                 clamp01(_math(nt, "SUBTRACT", 1.0, _math(nt, "MULTIPLY", _math(nt, "ABSOLUTE", _math(nt, "SUBTRACT", hsv.outputs[0], 0.6)), 8.0))))
    nm = next((n for n in nt.nodes if n.type == "NORMAL_MAP"), None)
    if nm is not None:
        nm.inputs["Strength"].default_value = 1.0
        geo_n = nt.nodes.new("ShaderNodeNewGeometry")
        mix_n = nt.nodes.new("ShaderNodeMix")
        mix_n.data_type = "VECTOR"
        nt.links.new(cloth, mix_n.inputs["Factor"])
        nt.links.new(geo_n.outputs["Normal"], mix_n.inputs[4])
        nt.links.new(nm.outputs["Normal"], mix_n.inputs[5])
        nt.links.new(mix_n.outputs[1], diffuse.inputs["Normal"])
    warm = TOON_CLOTH[mode]
    ramp_c = nt.nodes.new("ShaderNodeValToRGB")
    elc = ramp_c.color_ramp.elements
    elc[0].position, elc[0].color = 0.0, (*warm[0], 1)
    elc[1].position, elc[1].color = 1.0, (*warm[2], 1)
    for pos, col in ((0.16, warm[0]), (0.22, warm[1]), (0.5, warm[1]), (0.56, warm[2])):
        e = elc.new(pos)
        e.color = (*col, 1)
    nt.links.new(bw.outputs[0], ramp_c.inputs["Fac"])
    bands = nt.nodes.new("ShaderNodeMix")
    bands.data_type = "RGBA"
    nt.links.new(cloth, bands.inputs["Factor"])
    nt.links.new(ramp.outputs["Color"], bands.inputs["A"])
    nt.links.new(ramp_c.outputs["Color"], bands.inputs["B"])
    lit_colour = nt.nodes.new("ShaderNodeMix")
    lit_colour.data_type = "RGBA"
    lit_colour.blend_type = "MULTIPLY"
    lit_colour.inputs["Factor"].default_value = 1.0
    nt.links.new(albedo, lit_colour.inputs["A"])
    nt.links.new(bands.outputs["Result"], lit_colour.inputs["B"])
    colour = nt.nodes.new("ShaderNodeMix")
    colour.data_type = "RGBA"
    colour.blend_type = "MULTIPLY"
    nt.links.new(_math(nt, "MULTIPLY", blue, 0.6), colour.inputs["Factor"])
    nt.links.new(lit_colour.outputs["Result"], colour.inputs["A"])
    colour.inputs["B"].default_value = (1.05, 0.86, 0.68, 1)
    # view-space normal: how much it faces away from us (the edge), and towards the sun's side
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vt = nt.nodes.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"
    vt.convert_from, vt.convert_to = "WORLD", "CAMERA"
    nt.links.new(geo.outputs["Normal"], vt.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(vt.outputs[0], sep.inputs[0])
    facing = _math(nt, "ABSOLUTE", sep.outputs["Z"])
    edge = _math(nt, "SUBTRACT", 1.0, facing)
    edge_k = _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", edge, rim_w), 5.0), 1.0), 0.0)
    toward = _math(nt, "ADD", _math(nt, "MULTIPLY", sep.outputs["X"], -0.7), _math(nt, "MULTIPLY", sep.outputs["Y"], 0.7))
    toward = _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", toward, 2.2), 1.0), 0.0)
    rim = _math(nt, "MULTIPLY", _math(nt, "MULTIPLY", edge_k, toward), rim_k * float(os.environ.get("RIM_K", "1")))
    rim_rgb = nt.nodes.new("ShaderNodeMix")
    rim_rgb.data_type = "RGBA"
    rim_rgb.blend_type = "ADD"
    nt.links.new(rim, rim_rgb.inputs["Factor"])
    nt.links.new(colour.outputs["Result"], rim_rgb.inputs["A"])
    rim_rgb.inputs["B"].default_value = (*rim_c, 1)
    # the hair (the darkest of the albedo): blue-black, with a painted highlight band across it
    luma = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(albedo, luma.inputs[0])
    hair = _math(nt, "SUBTRACT", 1.0, _math(nt, "MINIMUM", _math(nt, "MAXIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", luma.outputs[0], 0.07), 12.0), 0.0), 1.0))
    band = _math(nt, "MULTIPLY",
                 _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", sep.outputs["Y"], 0.32), 10.0), 1.0), 0.0),
                 _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 0.62, sep.outputs["Y"]), 10.0), 1.0), 0.0))
    hair_hi = nt.nodes.new("ShaderNodeMix")
    hair_hi.data_type = "RGBA"
    hair_hi.blend_type = "ADD"
    nt.links.new(_math(nt, "MULTIPLY", _math(nt, "MULTIPLY", band, hair), 0.2 if mode == "day" else 0.12), hair_hi.inputs["Factor"])
    nt.links.new(rim_rgb.outputs["Result"], hair_hi.inputs["A"])
    hair_hi.inputs["B"].default_value = (0.55, 0.62, 0.85, 1)
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "ADD"
    nt.links.new(_math(nt, "MULTIPLY", hair, 0.05), tint.inputs["Factor"])
    nt.links.new(hair_hi.outputs["Result"], tint.inputs["A"])
    tint.inputs["B"].default_value = (0.2, 0.25, 0.6, 1)
    final = tint.outputs["Result"]
    region = m.get("toon")
    if region:  # the AAA file: one material per region (ROOT/_agents/AAA/hero3d), each its own treatment
        final = _region_toon(nt, m, mode, region, final, ramp, edge_k, toward, lit_colour)
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(final, em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])


def _aaa_toon():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import hero_toon_aaa
    return hero_toon_aaa


# per region (AAA file, pass 1; pass 2 uses hero_toon_aaa.py): (cool fill rim strength, metal glint strength)
REGION_TOON = {
    "day": {"cool": (0.42, 0.56, 1.0), "cool_k": 0.16, "glint": 0.42},
    "sunset": {"cool": (0.42, 0.36, 0.95), "cool_k": 0.22, "glint": 0.32},
}


def _mix_rgb(nt, blend, fac, a, b):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    n.blend_type = blend
    if isinstance(fac, (int, float)):
        n.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, n.inputs["Factor"])
    for sock, v in (("A", a), ("B", b)):
        if isinstance(v, tuple):
            n.inputs[sock].default_value = (*v[:3], 1.0)
        else:
            nt.links.new(v, n.inputs[sock])
    return n.outputs["Result"]


def _region_toon(nt, m, mode, region, colour, ramp, edge_k, toward, lit_colour):
    """The AAA hero's regions: a cool sky fill on the edges away from the sun (every region), a face that
    never sinks into the deep shade, painted-metal glints on the armour (a crisp highlight, no plastic
    sheen), fur strands and a root-to-tip value on the loincloth (not flat paper)."""
    cfg = REGION_TOON[mode]
    el = ramp.color_ramp.elements
    if region in ("face", "eye", "hand"):  # readable: the shade lifted towards the mid band
        lift = 0.62 if region == "face" else 0.4
        for e in el:
            c = e.color
            mid = el[2].color if len(el) > 2 else el[-1].color
            if e.position < 0.3:
                e.color = tuple(c[i] * (1 - lift) + mid[i] * lift for i in range(3)) + (1.0,)
    # the cool fill: edges facing away from the sun take a little sky
    away = _math(nt, "SUBTRACT", 1.0, toward)
    cool = _math(nt, "MULTIPLY", _math(nt, "MULTIPLY", edge_k, away), cfg["cool_k"] * (0.4 if region == "hair" else 1.0))
    colour = _mix_rgb(nt, "SCREEN", cool, colour, cfg["cool"])
    if region in ("armour_blue", "armour_silver"):
        # metal: a darker core shade and a crisp glint where the key light reflects (thresholded gloss)
        for e in el:
            if e.position < 0.3:
                e.color = tuple(x * 0.82 for x in e.color[:3]) + (1.0,)
        gl = _node(nt, "ShaderNodeBsdfGlossy", Roughness=0.12)
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        nt.links.new(gl.outputs[0], s2r.inputs[0])
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(s2r.outputs["Color"], bw.inputs[0])
        g = _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", bw.outputs[0], 0.9), 8.0), 1.0), 0.0)
        colour = _mix_rgb(nt, "ADD", _math(nt, "MULTIPLY", g, cfg["glint"] * float(os.environ.get("GLINT_K", "1"))), colour, (1.0, 0.96, 0.88))
    if region == "fur":
        # strands: noise on the rest shape, stretched along his height (it follows the cloth), and
        # the roots under the belt darker than the tips
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = "rest_co"
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (140.0, 140.0, 9.0)
        nt.links.new(at.outputs["Vector"], mp.inputs["Vector"])
        nz = _node(nt, "ShaderNodeTexNoise", Detail=3.0, Roughness=0.55)
        nz.inputs["Scale"].default_value = 1.0
        nt.links.new(mp.outputs[0], nz.inputs["Vector"])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(at.outputs["Vector"], sep.inputs[0])
        tip = _math(nt, "MAXIMUM", _math(nt, "MINIMUM", _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 0.07, sep.outputs["Z"]), 4.0), 1.0), 0.0)
        strand = _math(nt, "ADD", _math(nt, "MULTIPLY", nz.outputs["Fac"], 0.3), 0.82)
        val = _math(nt, "MULTIPLY", strand, _math(nt, "ADD", _math(nt, "MULTIPLY", tip, 0.12), 0.9))
        cr = nt.nodes.new("ShaderNodeCombineColor")
        for i in range(3):
            nt.links.new(val, cr.inputs[i])
        colour = _mix_rgb(nt, "MULTIPLY", 1.0, colour, cr.outputs[0])
        colour = _mix_rgb(nt, "MULTIPLY", 1.0, colour, (1.0, 0.97, 0.9))  # warm cream, never grey paper
    return colour


def ink_hull(ob, width):
    """The ink line: a hull a little larger than the body, its inside faces only (backface culling)."""
    ink = bpy.data.materials.get("Ink")
    if ink is None:
        ink = bpy.data.materials.new("Ink")
        ink.use_nodes = True
        nt = ink.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        em = _node(nt, "ShaderNodeEmission", Color=(*INK, 1))
        nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
        ink.use_backface_culling = True
    ob.data.materials.append(ink)
    md = ob.modifiers.new("Ink", "SOLIDIFY")
    md.thickness = width
    md.offset = 1.0
    md.use_flip_normals = True
    md.use_rim = False
    md.material_offset = len(ob.data.materials) - 1


def _box(a, r):
    """A box blur of radius r (pixels) along both axes, wrapping (cumulative sums)."""
    for axis in (0, 1):
        c = np.cumsum(np.concatenate([a.take(range(-r - 1, 0), axis), a, a.take(range(0, r), axis)], axis), axis)
        n = a.shape[axis]
        a = (c.take(range(2 * r + 1, 2 * r + 1 + n), axis) - c.take(range(0, n), axis)) / (2 * r + 1)
    return a


def flatten_textures(size=2048, r=4, k=0.6):
    """The base colour pictures have the muscles painted in (dark grooves): a softened copy, mixed
    back in, so the cel bands carry the form instead of the painted grooves."""
    done = {}
    for m in MESH.data.materials:
        if not m or not m.node_tree:
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        tex = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and any(
            l.to_node == bsdf or l.to_node.type in ("RGBTOBW",) for l in n.outputs[0].links)), None)
        if tex is None or tex.image is None:
            continue
        if tex.image.name not in done:
            img = tex.image.copy()
            img.scale(size, size)
            px = np.empty(size * size * 4, np.float32)
            img.pixels.foreach_get(px)
            a = px.reshape(size, size, 4)
            soft = _box(_box(a[..., :3], r), r)
            a[..., :3] = a[..., :3] * (1.0 - k) + soft * k
            img.pixels.foreach_set(a.ravel())
            done[tex.image.name] = img
        tex.image = done[tex.image.name]


FRINGE_UP = 0.075  ## metres the fringe in front of his eyes is lifted (round 7: "hair over the eyes")
FRINGE_BACK = 0.055  ## and swept back
FRONT = float(os.environ.get("FRINGE_FRONT", "1"))  ## the way he faces in the mesh's rest shape (+y)


def lift_fringe():
    """Lifts the locks of hair hanging in front of his eyes up and back, in the mesh's rest shape (so in
    every pose): hair is found by its colour in the base colour picture (near black), the fringe by
    where it is (in front of his face, from below his eyes to his brow). The user's file is unchanged."""
    if MESH.get("fringe_lifted"):
        return
    m = MESH.data.materials[0]
    # the base colour picture: the one not feeding the normal map (the bandit's goes through a ramp)
    tex = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and not any(
        l.to_node.type == "NORMAL_MAP" for l in n.outputs[0].links))
    img = tex.image.copy()
    img.scale(1024, 1024)
    px = np.empty(1024 * 1024 * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(1024, 1024, 4)
    # hair: dark and cool (blue-black); his skin is as dark but warm (red over blue)
    hair_px = ((px[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)) < 0.25) & (px[..., 0] - px[..., 2] < 0.012)
    me = MESH.data
    nl, nv = len(me.loops), len(me.vertices)
    uv = np.empty(nl * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(nl, 2)
    vi = np.empty(nl, np.int32)
    me.loops.foreach_get("vertex_index", vi)
    ix = np.clip((uv[:, 0] % 1.0) * 1023, 0, 1023).astype(np.int32)
    iy = np.clip((uv[:, 1] % 1.0) * 1023, 0, 1023).astype(np.int32)
    corner = hair_px[iy, ix].astype(np.float32)
    # by piece of mesh (each lock, the face, the body are separate pieces): a piece is hair if most of
    # its corners are, so a lock moves whole, never torn
    ne = len(me.edges)
    ev = np.empty(ne * 2, np.int32)
    me.edges.foreach_get("vertices", ev)
    ev = ev.reshape(ne, 2)
    label = np.arange(nv, dtype=np.int64)
    for _ in range(400):
        lo = np.minimum(label[ev[:, 0]], label[ev[:, 1]])
        before = label.copy()
        np.minimum.at(label, ev[:, 0], lo)
        np.minimum.at(label, ev[:, 1], lo)
        label = label[label]
        label = label[label]
        if np.array_equal(label, before):
            break
    share = np.bincount(label[vi], weights=corner, minlength=nv) / np.maximum(np.bincount(label[vi], minlength=nv), 1)
    hair = (share[label] > 0.6).astype(np.float32)
    co = np.empty(nv * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(nv, 3)
    head = ARM.matrix_world @ ARM.data.bones[P + "Head"].head_local
    # a smooth field in front of his eyes (the rest shape faces +y): the locks there bend up and back
    # as a whole, nothing is torn (a gaussian, no hard edge)
    centre = np.array([head.x, head.y + FRONT * 0.1, head.z + 0.05], np.float32)
    d2 = (((co - centre) / np.array([0.08, 0.075, 0.065], np.float32)) ** 2).sum(1)
    w = hair * np.exp(-d2)
    co[:, 2] += w * FRINGE_UP
    co[:, 1] -= w * FRINGE_BACK * FRONT
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    MESH["fringe_lifted"] = True
    print("FRINGE", int((w > 0.01).sum()), "vertices lifted")


def face_light():
    """Puts the interface pictures' face light in front of his face (towards the camera)."""
    light = bpy.data.objects.get("FaceLight")
    if light is None:
        return
    head = ARM.pose.bones[P + "Head"]
    mid = ARM.matrix_world @ ((head.head + head.tail) / 2)
    forward = (SC.camera.matrix_world.to_3x3() @ Vector((0.0, 0.0, 1.0))).normalized()  # towards the camera
    light.location = mid + forward * 0.16 + Vector((0.0, 0.0, 0.08))  # front and above: brow, eyes


KEY_SKIN = os.path.join(os.path.dirname(bpy.data.filepath), "key_skin_proxy.npy")  ## (key art k24) the skin's shading
## surface (hero3d/scripts/k24/): his rest mesh with the sculpt's small bumps smoothed away, the limbs keeping their big
## forms, the torso smoothed to its mass and given designed forms (two pec domes over a shelf, six ab cushions, an
## oblique ridge each side), posed by the same armature
KEY_SKIN_W = os.path.join(os.path.dirname(bpy.data.filepath), "key_skin_weights.npz")  ## and its skin weights, blurred
KEY_FIST = os.path.join(os.path.dirname(bpy.data.filepath), "key_fist_gap.npy")  ## (key art k33) the back fist's finger breaks


def key_skin_normals():
    """(Key art k24, "fuzzy brush-grain skin inside a clean outline": the grain was the sculpt's small bumps, stray
    skin weights and a crease the waist bend crushes into the belly, all read by the cel bands; not the light, Fast GI
    or the samples) the pictures' skin (torso, arms, legs) shaded with the normals of a clean copy of his body: the same
    topology posed by the same rig, so the forms stay where they are and the silhouette is unchanged."""
    if not (AAA and arg("--light", "day") == "sunset") or os.environ.get("KEY_SKIN", "1") != "1":
        return
    path = os.environ.get("KEY_SKIN_NPY", KEY_SKIN)
    if not os.path.exists(path):
        return
    co = np.load(path)
    if len(co) != len(MESH.data.vertices):
        print("KEY_SKIN: vertex count differs, skipped")
        return
    proxy = MESH.copy()
    proxy.data = MESH.data.copy()
    proxy.name = proxy.data.name = "AAA_SkinProxy"
    SC.collection.objects.link(proxy)
    proxy.shape_key_clear()
    proxy.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    proxy.data.update()
    for md in list(proxy.modifiers):
        if md.type == "CORRECTIVE_SMOOTH":
            # (its own smoothed rest shape; over the whole body: the rig's kinks where one bone's weight hands over to
            # the next smoothed out of the posed surface)
            md.rest_source = "ORCO"
            md.vertex_group = ""
            md.iterations = 30
            md.factor = 0.5
        elif md.type != "ARMATURE":
            proxy.modifiers.remove(md)
    proxy.hide_render = True
    wpath = os.environ.get("KEY_SKIN_W", KEY_SKIN_W)
    if os.path.exists(wpath):  # its skin weights blurred: each bend spread wider, no crease crushed into his belly
        wz = np.load(wpath)
        idx, wts = wz["idx"], wz["W"].astype(np.float32)
        rm = idx.tolist()
        for k, name in enumerate(wz["names"]):
            vg = proxy.vertex_groups.get(str(name))
            if vg is None:
                continue
            vg.remove(rm)
            q = np.round(wts[:, k] * 255).astype(np.int32)
            for level in np.unique(q[q > 0]):
                vg.add(idx[q == level].tolist(), float(level) / 255.0, "REPLACE")
        print("KEY_SKIN weights", wpath)
    mi = np.zeros(len(MESH.data.polygons), np.int64); MESH.data.polygons.foreach_get("material_index", mi)
    lt = np.zeros(len(MESH.data.polygons), np.int64); MESH.data.polygons.foreach_get("loop_total", lt)
    lv = np.zeros(len(MESH.data.loops), np.int64); MESH.data.loops.foreach_get("vertex_index", lv)
    fid = np.repeat(np.arange(len(MESH.data.polygons)), lt)
    skin = np.zeros(len(MESH.data.vertices), bool); skin[lv[mi[fid] == 0]] = True  # (the skin material only)
    names = [m_.name if m_ else "" for m_ in MESH.data.materials]
    if "AAA_belt" in names:  # (key art k27, "muddy smears") and the wrap on his thighs: its shading surface smoothed too
        rz = np.zeros(len(MESH.data.vertices) * 3, np.float32); MESH.data.attributes["rest_co"].data.foreach_get("vector", rz)
        wrap = np.zeros(len(MESH.data.vertices), bool); wrap[lv[mi[fid] == names.index("AAA_belt")]] = True
        skin |= wrap & (rz.reshape(-1, 3)[:, 2] < 0.03)
    if "AAA_hand" in names:  # (key art k33, "a brown lump with fur-like smudges") and his back (left, rest y > 0) fist: a clean surface
        rz = np.zeros(len(MESH.data.vertices) * 3, np.float32); MESH.data.attributes["rest_co"].data.foreach_get("vector", rz)
        fist = np.zeros(len(MESH.data.vertices), bool); fist[lv[mi[fid] == names.index("AAA_hand")]] = True
        skin |= fist & (rz.reshape(-1, 3)[:, 1] > 0.0)
    gpath = os.environ.get("KEY_FIST", KEY_FIST)
    if os.path.exists(gpath):  # (key art k33) where one finger meets the next on the fist (from the skin weights), for its breaks
        gap = np.load(gpath)
        if len(gap) == len(MESH.data.vertices):
            att = MESH.data.attributes.get("fist_gap") or MESH.data.attributes.new("fist_gap", "FLOAT", "POINT")
            att.data.foreach_set("value", gap.astype(np.float32))
    vg = MESH.vertex_groups.get("AAA_key_skin") or MESH.vertex_groups.new(name="AAA_key_skin")
    vg.add(np.nonzero(skin)[0].tolist(), 1.0, "REPLACE")
    md = MESH.modifiers.new("AAA_key_skin", "DATA_TRANSFER")
    md.object = proxy
    md.use_loop_data = True
    md.data_types_loops = {"CUSTOM_NORMAL"}
    md.loop_mapping = "TOPOLOGY"
    md.vertex_group = vg.name
    bpy.context.view_layer.update()
    print("KEY_SKIN on", int(skin.sum()), path)


def key_hem():
    """(Key art k27, "the maroon underwrap merges with the thigh skin in value") the distance along his surface from where the
    wrap (AAA_belt) meets the skin, as the attribute "hem_d" (rest units: + on the skin, - on the cloth, 0 elsewhere): the toon
    shader draws the wrap's dark hem and the shadow the hem casts on the thigh from it."""
    if not (AAA and arg("--light", "day") == "sunset"):
        return
    me = MESH.data
    names = [m.name if m else "" for m in me.materials]
    if "AAA_belt" not in names or "AAA_skin" not in names:
        return
    n = len(me.vertices)
    rc = np.zeros(n * 3, np.float32); me.attributes["rest_co"].data.foreach_get("vector", rc); rc = rc.reshape(-1, 3)
    ev = np.zeros(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", ev); ev = ev.reshape(-1, 2)
    mi = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", mi)
    lt = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_total", lt)
    lv = np.zeros(len(me.loops), np.int64); me.loops.foreach_get("vertex_index", lv)
    fm = np.repeat(mi, lt)
    on_s = np.zeros(n, bool); on_s[lv[fm == names.index("AAA_skin")]] = True
    on_b = np.zeros(n, bool); on_b[lv[fm == names.index("AAA_belt")]] = True
    inside = on_s | on_b
    e = ev[inside[ev[:, 0]] & inside[ev[:, 1]]]
    ln = np.linalg.norm(rc[e[:, 0]] - rc[e[:, 1]], axis=1)
    d = np.full(n, 1.0, np.float64)
    d[on_s & on_b] = 0.0
    for _ in range(16):  # (about 1.7 cm along the surface: enough for the hem and its shadow)
        np.minimum.at(d, e[:, 1], d[e[:, 0]] + ln)
        np.minimum.at(d, e[:, 0], d[e[:, 1]] + ln)
    val = np.where(on_b & ~on_s, -d, d)
    val[on_s & on_b] = -1e-5
    val[~inside] = 0.0
    att = me.attributes.get("hem_d") or me.attributes.new("hem_d", "FLOAT", "POINT")
    att.data.foreach_set("value", val.astype(np.float32))
    print("KEY_HEM seam", int((on_s & on_b).sum()))


def toon_setup():
    mode = "sunset" if arg("--light", "day") == "sunset" else "day"
    lift_fringe()
    for ob in list(bpy.data.objects):
        if ob.type == "LIGHT":
            bpy.data.objects.remove(ob, do_unlink=True)
    SC.view_settings.view_transform = "Standard"
    SC.view_settings.look = "None"
    SC.view_settings.exposure = 0.0
    SC.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    # (round 8: "hatching on the skin reads as grime": the painted grooves almost gone)
    if not MESH.get("aaa_textures"):  # (the AAA file's base colour is already cleaned)
        flatten_textures(r=int(os.environ.get("FLAT_R", "10")), k=float(os.environ.get("FLAT_K", "0.95")))
    rig = bpy.data.objects["LightRig"]
    # the world's sun: upper left on screen, a little towards us (day) or behind him (sunset)
    # (hero pass 4, the AAA file: "readability beats physically correct backlight": the interface pictures are
    # lit from the front-left like the level, the sun behind him is the shader's hot back rim)
    key_from = (-0.45, 0.65, 0.6) if (mode == "day" or (AAA and os.environ.get("HERO_TOON", "bold") == "bold")) else (0.55, 0.62, 0.45)
    key = add_sun("ToonKey", (1.0, 1.0, 1.0), 3.2, aim_from=key_from, angle=1.0)
    key.parent = rig
    # a warm bounce from the front (screen right and towards us): his face and chest in the mid band,
    # not the shade (round 6: "his face is entirely in shadow")
    fill = add_sun("ToonFill", (1.0, 0.85, 0.7), 0.42 if mode == "day" else 0.3,
                   aim_from=(-0.75, -0.55, 0.15) if mode == "day" else (-0.9, -0.2, 0.3), angle=8.0)
    fill.parent = rig
    if mode == "sunset" and os.environ.get("KEY_SHADOWS", "0") != "1":  # (key art k10, "blotchy dark-brown patches on the
        # abs, chest, thighs: dirt": the pictures' light shapes his forms only, no cast-shadow patches)
        key.data.use_shadow = False
        fill.data.use_shadow = False
    if mode == "sunset":  # and a small light on his face, placed for each pose (face_light())
        data = bpy.data.lights.new("FaceLight", "POINT")
        data.color = (1.0, 0.78, 0.6)
        data.energy = float(os.environ.get("FACE_W", "2.2" if AAA else "1.6"))  # (AAA: a warm face fill; round 12: "the face small, dark, blank")
        data.shadow_soft_size = 0.05
        data.use_custom_distance = True
        data.cutoff_distance = 0.32
        data.use_shadow = os.environ.get("KEY_SHADOWS", "0") == "1"
        ob = bpy.data.objects.new("FaceLight", data)
        SC.collection.objects.link(ob)
    seen = set()
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.hide_render:
            continue
        for m in ob.data.materials:
            if m and m.name not in seen and m.name != "Ink":
                seen.add(m.name)
                toon_material(m, mode)
        if ob == MESH or (ob.parent == ARM and ob.data.materials and ob.data.materials[0].name != "Eyes"):
            # round 8: no ink hull on Panoramic's body: on his carved muscles it drew fine lines over
            # the skin that read as grime at phone size; his outer ink comes from hero_atlas.py's
            # inked(). The bandit (dark skin, the lines don't show) and the props keep theirs.
            if ob != MESH or (arg("--character") == "bandit" and not AAA):
                ink_hull(ob, INK_WIDTH if ob == MESH else INK_WIDTH * 0.6)
    if AAA:  # the props hidden until their pose (the chakram) get their shading too
        _aaa_toon().build_all(bpy.data.objects, mode)
        # (round 12: none in the interface pictures, "abs scribbled ink lines"; the outer line is hero_atlas.py's)
        hull = float(os.environ.get("HERO_HULL", "0.0"))  # (round 14: in the level too, "ragged and brushy")
        if hull > 0:  # (pass 4) inner ink lines (limb over body), the same weight everywhere: the calmed
            ink_hull(MESH, hull)  # muscles no longer catch it (round 8 removed it for "grime")

# ------------------------------------------------------------------ render

POINTS = {"hips": ("Hips", "head"), "head": ("HeadTop_End", "head"), "toe_r": ("RightToe_End", "head"),
          "toe_l": ("LeftToe_End", "head"), "hand_r": ("RightHand", "head"), "hand_l": ("LeftHand", "head")}


def points(cam):
    out = {}
    mw = ARM.matrix_world
    for key, (bone, end) in POINTS.items():
        if key in ("hand_r", "hand_l") and _grip[0]:  # (round 15) hanging by one hand: the game hangs him from it
            bone = _grip[0]
        pb = ARM.pose.bones[P + bone]
        co = mw @ (pb.head if end == "head" else pb.tail)
        v = world_to_camera_view(SC, cam, co)
        out[key] = [round(v.x * SIZE, 2), round((1.0 - v.y) * SIZE, 2)]
    ring = bpy.data.objects.get("AAA_Chakram")
    if ring is not None and not ring.hide_render:  # (round 15) the flying ring: its middle and radius on screen
        c = ring.matrix_world.translation
        edge = c + (cam.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))) * 0.095 * ring.matrix_world.to_scale().x
        v, e = world_to_camera_view(SC, cam, c), world_to_camera_view(SC, cam, edge)
        out["ring"] = [round(v.x * SIZE, 2), round((1.0 - v.y) * SIZE, 2), round((e.x - v.x) * SIZE, 2)]
    return out


def mirror_user_lights():
    """The user's lights mirrored across the side cameras' axis (x -> -x): the other side of him lit
    as they lit this one. Called again, it puts them back."""
    for ob in bpy.data.objects:
        if ob.type == "LIGHT" and ob.parent is None:
            d = ob.matrix_world.to_3x3() @ Vector((0.0, 0.0, -1.0))
            ob.location.x = -ob.location.x
            ob.rotation_euler = look_rotation(Vector((-d.x, d.y, d.z)))
    bpy.context.view_layer.update()


FACES = {"run": "determined", "jump": "focus", "idle": "determined", "die": "hurt", "hang": "effort", "catch": "effort",
         "throw": "shout", "crouch": "determined", "hurt": "hurt", "climb": "effort", "win": "smile",
         "menu_hero": "warcry", "win_front": "grin", "defeat": "dazed", "portrait": "determined"}  ## (round 15) his expression in each
_face = [None]


def set_face(expression):
    """His drawn face for this moment (ROOT/_agents/AAA/hero3d/textures/face/face_<expression>.png, tools/art/hero_face.py)."""
    if not AAA or expression == _face[0] or arg("--character") == "bandit":
        return
    path = os.path.join(os.path.dirname(bpy.data.filepath), "textures", "face", f"face_{expression}.png")
    m = bpy.data.materials.get("AAA_face")
    if m is None or not os.path.exists(path):
        return
    m["decal"] = bpy.data.images.load(path, check_existing=True).name
    _aaa_toon().build(m, "sunset" if arg("--light", "day") == "sunset" else "day")
    _face[0] = expression


FRINGE_GAP = float(os.environ.get("FRINGE_GAP", "20"))  ## (key art k41) picture pixels (2048) of lit forehead kept clear
## above his drawn brows
FRINGE_GAP_FAR = float(os.environ.get("FRINGE_GAP_FAR", "14"))  ## and this many more between his eyes and over the far brow
FRINGE_ON = float(os.environ.get("FRINGE_ON", "0.008"))  ## hair this close to his skin lies on it (the hairline), not a lock
## standing off it (rest units)
FRINGE_Y = 0.028  ## (rest y: beyond it the far temple's locks, at the head's silhouette, stay)
_FRINGE_UNDO = []


def key_fringe():
    """(Key art k41, judge: "the dark underside of the fringe touches the brow and muddies the eye area: a sliver of lit
    forehead between hair and brow would make the scowl read") the hairline over his brows lifted clear of them, in the
    picture: the hair lying on his skin (not the locks standing off it) over his drawn brows and up to FRINGE_GAP pixels
    above them becomes his forehead (the face's material, lit by the skin's own normal there: attribute "fringe_n"), so a
    thin strip of lit skin shows between the fringe and his brows. The locks, the hair's silhouette and the far temple
    are untouched; undone after the picture; the user's file unchanged."""
    if not (AAA and arg("--light", "day") == "sunset") or FRINGE_GAP <= 0.0:
        return
    from mathutils.kdtree import KDTree
    me = MESH.data
    names = [m.name if m else "" for m in me.materials]
    fm = bpy.data.materials.get("AAA_face")
    dec = bpy.data.images.get(fm.get("decal", "")) if fm is not None else None
    if "AAA_hair" not in names or "AAA_face" not in names or dec is None:
        return
    hi, fi = names.index("AAA_hair"), names.index("AAA_face")
    n = len(me.vertices)
    mi = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", mi)
    lt = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_total", lt)
    ls = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_start", ls)
    lv = np.zeros(len(me.loops), np.int64); me.loops.foreach_get("vertex_index", lv)
    rc = np.zeros(n * 3, np.float32); me.attributes["rest_co"].data.foreach_get("vector", rc); rc = rc.reshape(-1, 3)
    lm = np.repeat(mi, lt)
    hair_v = np.zeros(n, bool); hair_v[lv[lm == hi]] = True
    skin_v = np.zeros(n, bool); skin_v[lv[lm != hi]] = True
    skin_v &= ~hair_v
    head = (rc[:, 0] > 0.02) & (rc[:, 2] > 0.33) & (rc[:, 2] < 0.44) & (rc[:, 1] < FRINGE_Y + 0.02)
    # how far each vertex of the front of his head lies off his skin
    near = np.nonzero(skin_v & head)[0]
    kd = KDTree(len(near))
    for i in near:
        kd.insert(rc[i].tolist(), int(i))
    kd.balance()
    dist = np.full(n, 1.0, np.float32)
    nearest = np.arange(n)
    for v in np.nonzero(head & hair_v)[0]:
        _co, j, dd = kd.find(rc[v].tolist())
        dist[v], nearest[v] = dd, j
    dist[skin_v & head] = 0.0
    # where they fall in the picture
    dg = bpy.context.evaluated_depsgraph_get()
    ev = MESH.evaluated_get(dg).data
    co = np.zeros(len(ev.vertices) * 3, np.float32); ev.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
    vn = np.zeros(len(ev.vertices) * 3, np.float32); ev.vertex_normals.foreach_get("vector", vn); vn = vn.reshape(-1, 3)
    mw = np.array(MESH.matrix_world, np.float32)
    wco = co @ mw[:3, :3].T + mw[:3, 3]
    wn = vn @ mw[:3, :3].T
    wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-9)
    # (bpy_extras' world_to_camera_view, for every vertex at once)
    cinv = np.array(SC.camera.matrix_world.normalized().inverted(), np.float64)
    cl = np.c_[wco, np.ones(n)] @ cinv.T
    zz = np.maximum(-cl[:, 2], 1e-6) if SC.camera.data.type != "ORTHO" else -np.ones(n)  # (ortho: the frame as it is)
    fr = [np.array(v[:]) for v in SC.camera.data.view_frame(scene=SC)[:3]]
    if SC.camera.data.type == "ORTHO":
        fr = [v * np.array([1.0, 1.0, -1.0]) for v in fr]  # (so -v.x * zz / v.z is v.x)
    min_x, max_x = -fr[2][0] * zz / fr[2][2], -fr[1][0] * zz / fr[1][2]
    min_y, max_y = -fr[1][1] * zz / fr[1][2], -fr[0][1] * zz / fr[0][2]
    sx = (cl[:, 0] - min_x) / (max_x - min_x) * SIZE
    sy = (1.0 - (cl[:, 1] - min_y) / (max_y - min_y)) * SIZE
    # his drawn brows in the picture: the skin (or skin-hugging hair) under the decal's dark strokes over his eyes
    fy, fz, fs = _aaa_toon().FACE_FRAME
    w, h = dec.size
    px = np.empty(w * h * 4, np.float32); dec.pixels.foreach_get(px); px = px.reshape(h, w, 4)  # (row 0: the bottom)
    zrow = fz + (np.arange(h) + 0.5) / h * fs
    dark = ((px[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)) < 0.3) & (px[..., 3] > 0.5)  # (the picture's own sRGB values)
    dark &= ((zrow > 0.345) & (zrow < 0.42))[:, None]
    stroke = np.zeros_like(dark)  # (each column's topmost dark run only: the brow, not the eye under it)
    for j in np.nonzero(dark.any(0))[0]:
        c = dark[::-1, j]
        r0 = int(np.argmax(c))
        r1 = r0 + (int(np.argmin(c[r0:])) if not c[r0:].all() else len(c) - r0)
        stroke[h - r1:h - r0, j] = True
    dark = stroke
    u = np.clip(((rc[:, 1] - fy) / fs * w).astype(np.int64), 0, w - 1)
    vv = np.clip(((rc[:, 2] - fz) / fs * h).astype(np.int64), 0, h - 1)
    face_v = np.zeros(n, bool); face_v[lv[lm == fi]] = True
    brow = head & (face_v | (hair_v & (dist < FRINGE_ON))) & dark[vv, u] & (rc[:, 2] > 0.345) & (rc[:, 2] < 0.42)
    if not brow.any():
        return
    bx = np.round(sx[brow]).astype(np.int64)
    by = sy[brow]
    lo, hi_x = bx.min(), bx.max()
    top = np.full(hi_x - lo + 1, np.inf); bot = np.full(hi_x - lo + 1, -np.inf)
    np.minimum.at(top, bx - lo, by)
    np.maximum.at(bot, bx - lo, by)
    r = 4
    top = np.array([top[max(0, i - r):i + r + 1].min() for i in range(len(top))])
    bot = np.array([bot[max(0, i - r):i + r + 1].max() for i in range(len(bot))])
    # the hair on his skin over the brows and FRINGE_GAP above them
    cs = np.add.reduceat(np.c_[sx, sy][lv], ls) / lt[:, None]
    pmax = np.maximum.reduceat(dist[lv], ls)
    cen = np.add.reduceat(rc[lv], ls) / lt[:, None]
    ci = np.round(cs[:, 0]).astype(np.int64) - lo
    inside = (ci >= 0) & (ci < len(top))
    ci = np.clip(ci, 0, len(top) - 1)
    sel = (mi == hi) & inside & (pmax < FRINGE_ON) & (cen[:, 0] > 0.03) & (cen[:, 1] < FRINGE_Y) & np.isfinite(top[ci])
    gap = FRINGE_GAP + FRINGE_GAP_FAR * np.clip(cen[:, 1] / 0.012 + 1.0, 0.0, 1.0)  # (more between his eyes and over the far brow)
    sel &= (cs[:, 1] > top[ci] - gap) & (cs[:, 1] < bot[ci] + 1.0)
    sel = np.nonzero(sel)[0]
    if not len(sel):
        return
    # lit as the skin it lies on: the nearest skin vertex's normal (world)
    fn = np.zeros((n, 3), np.float32)
    vs = np.unique(lv[np.repeat(np.isin(np.arange(len(mi)), sel), lt)])
    fn[vs] = wn[nearest[vs]]
    att = me.attributes.get("fringe_n") or me.attributes.new("fringe_n", "FLOAT_VECTOR", "POINT")
    att.data.foreach_set("vector", fn.ravel())
    _FRINGE_UNDO.append((sel, mi[sel].copy()))
    mi[sel] = fi
    me.polygons.foreach_set("material_index", mi)
    me.update()
    bpy.context.view_layer.update()
    print("KEY_FRINGE", len(sel), "polygons; brow columns", lo, hi_x)


FRINGE_LIFT = float(os.environ.get("FRINGE_LIFT", "0.45"))  ## (key art k41) the share of their drop the locks hanging over his
## brows are drawn up by, towards FRINGE_TOP (their roots stay)
FRINGE_TOP = float(os.environ.get("FRINGE_TOP", "0.42"))
FRINGE_SIDE = (-0.015, 0.021)  ## (rest y: the locks between his eyes and over the far brow, not the far temple's)


def key_fringe_lift():
    """(Key art k41) the locks standing off his forehead over his brows (the wedge between his eyes and over the far brow)
    drawn up towards their roots, so they end above his brows: a shape key for the title screen (undone after it). The
    hair lying on his skin and the vertices it shares with his face stay, so his skin never stretches."""
    if not (AAA and arg("--light", "day") == "sunset") or FRINGE_LIFT <= 0.0:
        return
    from mathutils.kdtree import KDTree
    me = MESH.data
    names = [m.name if m else "" for m in me.materials]
    if me.shape_keys is None or "AAA_hair" not in names:
        return
    hi = names.index("AAA_hair")
    n = len(me.vertices)
    mi = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("material_index", mi)
    lt = np.zeros(len(me.polygons), np.int64); me.polygons.foreach_get("loop_total", lt)
    lv = np.zeros(len(me.loops), np.int64); me.loops.foreach_get("vertex_index", lv)
    rc = np.zeros(n * 3, np.float32); me.attributes["rest_co"].data.foreach_get("vector", rc); rc = rc.reshape(-1, 3)
    lm = np.repeat(mi, lt)
    hair_v = np.zeros(n, bool); hair_v[lv[lm == hi]] = True
    skin_v = np.zeros(n, bool); skin_v[lv[lm != hi]] = True
    cand = hair_v & ~skin_v & (rc[:, 0] > 0.035) & (rc[:, 1] > FRINGE_SIDE[0] - 0.01) & (rc[:, 1] < FRINGE_SIDE[1] + 0.01) & (rc[:, 2] < FRINGE_TOP)
    near = np.nonzero(skin_v & (rc[:, 0] > 0.02) & (rc[:, 2] > 0.33) & (rc[:, 2] < 0.45))[0]
    kd = KDTree(len(near))
    for i in near:
        kd.insert(rc[i].tolist(), int(i))
    kd.balance()
    dist = np.zeros(n, np.float32)
    for v in np.nonzero(cand)[0]:
        dist[v] = kd.find(rc[v].tolist())[2]

    def sm(v, a, b):
        t = np.clip((v - a) / (b - a), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    w = cand * sm(dist, 0.006, 0.012) * sm(rc[:, 0], 0.035, 0.05) * sm(rc[:, 1], FRINGE_SIDE[0] - 0.01, FRINGE_SIDE[0]) \
        * sm(rc[:, 1], FRINGE_SIDE[1] + 0.01, FRINGE_SIDE[1])
    dz = w * np.maximum(FRINGE_TOP - rc[:, 2], 0.0) * FRINGE_LIFT / 1.106  # (rest height to the mesh's: 1.106)
    co = np.zeros(n * 3, np.float32); me.shape_keys.key_blocks["Basis"].data.foreach_get("co", co); co = co.reshape(-1, 3)
    co[:, 2] += dz
    kb = me.shape_keys.key_blocks.get("KEY_fringe") or MESH.shape_key_add(name="KEY_fringe", from_mix=False)
    kb.data.foreach_set("co", co.ravel())
    kb.value = 1.0
    me.update()
    bpy.context.view_layer.update()
    _FRINGE_UNDO.append(("key", None))
    print("KEY_FRINGE_LIFT", int((dz > 1e-5).sum()), "vertices, up to", round(float(dz.max()), 4))


def key_fringe_undo():
    while _FRINGE_UNDO:
        sel, old = _FRINGE_UNDO.pop()
        if isinstance(sel, str):
            kb = MESH.data.shape_keys.key_blocks.get("KEY_fringe")
            if kb is not None:
                kb.value = 0.0
            continue
        mi = np.zeros(len(MESH.data.polygons), np.int64); MESH.data.polygons.foreach_get("material_index", mi)
        mi[sel] = old
        MESH.data.polygons.foreach_set("material_index", mi)
        MESH.data.update()


def key_depth_pass(folder):
    """(Key art k36, "the outline the same heavy black everywhere ... nearly absent on inner forms: a consistent outer line
    with tapered inner lines") a quick second render of the key art's depth (view z) and what each pixel is (hair 1, the
    ring 2), 000_depth.npz: tools/art/hero_atlas.py draws the inner lines where one form overlaps another from it."""
    if not (AAA and arg("--light", "day") == "sunset") or os.environ.get("KEY_DEPTH", "1") != "1":
        return
    ring = bpy.data.objects.get("AAA_Chakram")
    ring_mats = {s.material.name for s in ring.material_slots if s.material} if ring is not None else set()
    swapped = []
    for m in bpy.data.materials:
        nt = m.node_tree
        if nt is None:
            continue
        out = nt.get_output_node("EEVEE") or nt.get_output_node("ALL")
        if out is None:
            continue
        old = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        cam = nt.nodes.new("ShaderNodeCameraData")
        comb = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(cam.outputs["View Z Depth"], comb.inputs[0])
        comb.inputs[1].default_value = 2.0 if m.name in ring_mats else (1.0 if "hair" in m.name.lower() else 0.0)
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(comb.outputs[0], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        swapped.append((nt, out, old, (cam, comb, em)))
    r = SC.render
    keep = (r.filepath, r.image_settings.file_format, r.image_settings.color_depth, SC.eevee.taa_render_samples)
    exr = os.path.join(folder, "000_depth.exr")
    r.image_settings.file_format = "OPEN_EXR"
    r.image_settings.color_depth = "32"
    r.filepath = exr
    SC.eevee.taa_render_samples = 1  # (no anti-aliasing: one depth per pixel)
    bpy.ops.render.render(write_still=True)
    r.filepath, r.image_settings.file_format, r.image_settings.color_depth, SC.eevee.taa_render_samples = keep
    for nt, out, old, added in swapped:
        if old is not None:
            nt.links.new(old, out.inputs["Surface"])
        for n in added:
            nt.nodes.remove(n)
    im = bpy.data.images.load(exr)
    w, h = im.size
    px = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    os.remove(exr)
    px = px.reshape(h, w, 4)[::-1]
    np.savez_compressed(os.path.join(folder, "000_depth.npz"), z=px[..., 0].astype(np.float32), id=np.round(px[..., 1]).astype(np.uint8),
                        a=(px[..., 3] > 0.5))
    print("KEY_DEPTH", folder)


def render(name, view, frames, lift=0.0, tilt=0.0):
    set_face(FACES.get(name, "determined"))
    SC.camera = camera(view)
    level = SC.camera.rotation_euler.x
    SC.camera.rotation_euler.x = level + math.radians(tilt)  # + looks up at him
    if view == "other_side":
        mirror_user_lights()
    # the light keeps its place on screen whichever side the camera looks from
    bpy.data.objects["LightRig"].rotation_euler.z = math.radians({"side": 0.0, "front": 90.0, "other_side": 180.0}[view])
    base_z = 0.471
    SC.camera.location.z = base_z + lift
    # New (round 9, QA ART-1): the camera's matrix follows its new height and tilt only after an update; the
    # origin was projected from the unlifted camera (the win's 0.2 m: 147 px, his boots 32 units in the ground)
    bpy.context.view_layer.update()
    folder = os.path.join(OUT, name)
    os.makedirs(folder, exist_ok=True)
    # where the world's origin (on the ground, under his hips at rest) falls in the picture
    o = world_to_camera_view(SC, SC.camera, Vector((0.0, 0.0, 0.0)))
    data = {"view": view, "size": SIZE, "origin": [round(o.x * SIZE, 2), round((1.0 - o.y) * SIZE, 2)], "frames": []}
    # (the leather panels only where they face us: from the side they show edge-on as a thin brown frame)
    for panel, shown in (("AAA_PanelBack", view == "front"), ("AAA_PanelFront", view == "front" or name == "win")):
        ob = bpy.data.objects.get(panel)
        if ob is not None:
            ob.hide_render = not shown or arg("--character") == "bandit"
            ob["shown"] = shown
    for i, f in enumerate(frames):
        if TEST and i not in (0, len(frames) // 2):
            continue
        reset_turn()
        if callable(f):
            f()
        else:
            apply(sample(*f))
        face_light()
        SC.render.filepath = os.path.join(folder, f"{i:03d}.png")
        bpy.ops.render.render(write_still=True)
        if name == "menu_hero" and i == 0:
            key_depth_pass(folder)
        data["frames"].append(points(SC.camera))
    with open(os.path.join(folder, "points.json"), "w") as fh:
        json.dump(data, fh, indent=1)
    key_fringe_undo()  # (key art k41: the hairline over his brows, the title screen's only)
    if view == "other_side":
        mirror_user_lights()
    SC.camera.rotation_euler.x = level
    print("RENDERED", name, len(data["frames"]))


def main():
    setup_scene()
    table = anims()
    if arg("--character") == "bandit":
        make_bandit()
        table = bandit_anims()
    if arg("--style", "toon") == "toon":
        toon_setup()
    key_skin_normals()
    key_hem()
    wanted = arg("--anims", ",".join(table)).split(",")
    for name in wanted:
        render(name, *table[name])
    save = arg("--save")
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=save, copy=True)


if __name__ == "__main__":  # (Blender's --python runs it as __main__; importing it only defines things)
    main()
