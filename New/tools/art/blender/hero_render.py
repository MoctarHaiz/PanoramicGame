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

Usage:
  Blender -b ROOT/Making/Animation.blend --python tools/art/blender/hero_render.py -- \
      --out DIR [--anims run,jump] [--size 768] [--test] [--save ROOT/_agents/AAA/blender/hero.blend]
"""
import json
import math
import os
import sys

import bpy
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
MESH = next(o for o in ARM.children if o.type == "MESH")
ACTIONS = {"run": "mixamo.com", "idle": "mixamo.com.001", "jump": "mixamo.com.002", "die": "mixamo.com.003"}
P = "mixamorig:"


# ------------------------------------------------------------------ scene

def setup_scene():
    """The user's scene as they lit it (their lights, world, materials and AgX), plus the savanna:
    a warm rim from the game's sun (behind him, upper left on screen) and a faint warm bounce from
    the ground. Only the added lights turn with the camera."""
    user_lights = [ob for ob in bpy.data.objects if ob.type == "LIGHT"]
    for ob in bpy.data.objects:
        if ob.type in ("ARMATURE", "MESH"):
            show = ob in (ARM, MESH)
            ob.hide_render = not show
            ob.hide_viewport = not show
    r = SC.render
    r.resolution_x = r.resolution_y = SIZE
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    SC.eevee.taa_render_samples = 16 if TEST else 64
    rig = bpy.data.objects.new("LightRig", None)
    SC.collection.objects.link(rig)
    if arg("--light", "day") == "sunset":
        # the menu: the low sun behind him on the left, its light wrapping his edges in orange
        add_sun("Rim", (1.0, 0.55, 0.25), 6.0, aim_from=(0.62, 0.72, 0.3), angle=2.0)
        add_sun("RimFront", (1.0, 0.7, 0.5), 2.0, aim_from=(0.55, -0.78, 0.3), angle=2.0)
        add_area("Bounce", (0.8, 0.45, 0.3), 25.0, at=(-0.5, -0.1, -0.6), size=2.0)
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


def apply(pose):
    ARM.animation_data.action = None
    for pb in ARM.pose.bones:
        loc, rot = pose[pb.name]
        pb.location = loc
        pb.rotation_quaternion = rot
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


def sample_jog(frame):
    """The run with shorter strides (STRIDE of its leg swing), so his feet keep pace with the game's
    ground; its flight and bounce shrink with it, the planted foot stays on the ground."""
    run = sample("run", frame)
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
    aim("RightUpLeg", 0.4 + 0.12 * s, -1.0)
    aim("RightLeg", -0.38 + 0.14 * c, -1.0)
    aim("RightFoot", 0.4, -1.0)
    aim("LeftUpLeg", 0.08 - 0.1 * s, -1.0)
    aim("LeftLeg", -0.55 - 0.12 * c, -1.0)
    aim("LeftFoot", 0.25, -1.0)
    top = max(bone_z("RightHand", "tail"), bone_z("LeftHand", "tail"))
    shift_hips(0.0, HANG_TOP - top)


def pose_catch(t):
    """From the rising jump into the hang: arms sweep up to the vine (t 0..1)."""
    pose_hang(0.0)
    hang = current()
    a = sample("jump", 6 + 2 * t)
    apply(mix(a, hang, ease(t)))
    ARM.rotation_euler.z = math.radians(HANG_TURN * ease(t))
    bpy.context.view_layer.update()


def throw_arm(stage):
    """The near (right) arm: 0 drawn back behind his head, 1 the release reaching forward."""
    if stage == 0:
        turn("Spine1", -9)
        turn("Head", 4)
        aim("RightArm", -1.0, 0.25, 0.3)
        aim("RightForeArm", 0.35, 1.0, 0.15)
        aim("RightHand", 0.8, 0.5)
    else:
        turn("Spine1", 8)
        aim("RightArm", 1.0, 0.1, 0.18)
        aim("RightForeArm", 1.0, 0.05, 0.05)
        aim("RightHand", 1.0, -0.15)


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
    aim("RightArm", -0.3 - 0.25 * up, -0.95 + 1.9 * up, 0.15)
    aim("RightForeArm", -0.15 * up - 0.05, 0.1 + 0.9 * up * (0.75 + 0.25 * pump), 0.25 * (1 - up))
    aim("RightHand", -0.1, 1.0)
    aim("LeftArm", 0.3 + 0.25 * up, -0.95 + 1.9 * up, 0.15)
    aim("LeftForeArm", 0.15 * up + 0.05, 0.1 + 0.9 * up * (0.75 + 0.25 * (1 - pump)), 0.25 * (1 - up))
    aim("LeftHand", 0.1, 1.0)
    turn("Head", 0.0)
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


def reset_turn():
    ARM.rotation_euler.z = 0.0
    bpy.context.view_layer.update()


# name -> (camera view, frames: callables or (action, frame), camera lift in metres)
def anims():
    out = {}
    out["run"] = ("side", [lambda i=i: apply(sample_jog(1 + i)) for i in range(16)])
    out["jump"] = ("side", [("jump", 1 + i) for i in range(27)])
    out["idle"] = ("side", [("idle", 1 + i * 3) for i in range(20)])
    out["idle_front"] = ("front", [("idle", 1 + i * 2) for i in range(30)])
    out["die"] = ("other_side", [("die", f) for f in list(range(1, 50, 2)) + [62, 78]])
    out["hang"] = ("side", [lambda i=i: pose_hang(i / 12.0) for i in range(12)])
    out["catch"] = ("side", [lambda i=i: pose_catch((i + 1) / 4.0) for i in range(4)])
    out["throw"] = ("side", [lambda i=i, s=s: pose_throw(i, s) for s in (0, 1) for i in range(16)])
    out["crouch"] = ("side", [lambda i=i: pose_crouch((i + 1) / 4.0) for i in range(4)])
    out["hurt"] = ("side", [lambda i=i: pose_hurt(i / 9.0) for i in range(10)])
    out["climb"] = ("side", [lambda i=i: pose_climb(i / 7.0) for i in range(8)])
    out["win"] = ("side", [lambda i=i: pose_win(i / 23.0) for i in range(24)], 0.2)
    out["menu"] = ("front", [lambda k=k: pose_menu(k) for k in range(4)], 0.1)
    out["menu_hero"] = ("front", [lambda: pose_menu(0)], 0.1)
    out["win_front"] = ("side", [lambda: pose_win(0.62, face_turn=-100.0)], 0.2)
    return out


# ------------------------------------------------------------------ render

POINTS = {"hips": ("Hips", "head"), "head": ("HeadTop_End", "head"), "toe_r": ("RightToe_End", "head"),
          "toe_l": ("LeftToe_End", "head"), "hand_r": ("RightHand", "head"), "hand_l": ("LeftHand", "head")}


def points(cam):
    out = {}
    mw = ARM.matrix_world
    for key, (bone, end) in POINTS.items():
        pb = ARM.pose.bones[P + bone]
        co = mw @ (pb.head if end == "head" else pb.tail)
        v = world_to_camera_view(SC, cam, co)
        out[key] = [round(v.x * SIZE, 2), round((1.0 - v.y) * SIZE, 2)]
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


def render(name, view, frames, lift=0.0):
    SC.camera = camera(view)
    if view == "other_side":
        mirror_user_lights()
    # the light keeps its place on screen whichever side the camera looks from
    bpy.data.objects["LightRig"].rotation_euler.z = math.radians({"side": 0.0, "front": 90.0, "other_side": 180.0}[view])
    base_z = 0.471
    SC.camera.location.z = base_z + lift
    folder = os.path.join(OUT, name)
    os.makedirs(folder, exist_ok=True)
    # where the world's origin (on the ground, under his hips at rest) falls in the picture
    o = world_to_camera_view(SC, SC.camera, Vector((0.0, 0.0, 0.0)))
    data = {"view": view, "size": SIZE, "origin": [round(o.x * SIZE, 2), round((1.0 - o.y) * SIZE, 2)], "frames": []}
    for i, f in enumerate(frames):
        if TEST and i not in (0, len(frames) // 2):
            continue
        reset_turn()
        if callable(f):
            f()
        else:
            apply(sample(*f))
        SC.render.filepath = os.path.join(folder, f"{i:03d}.png")
        bpy.ops.render.render(write_still=True)
        data["frames"].append(points(SC.camera))
    with open(os.path.join(folder, "points.json"), "w") as fh:
        json.dump(data, fh, indent=1)
    if view == "other_side":
        mirror_user_lights()
    print("RENDERED", name, len(data["frames"]))


def main():
    setup_scene()
    table = anims()
    wanted = arg("--anims", ",".join(table)).split(",")
    for name in wanted:
        render(name, *table[name])
    save = arg("--save")
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=save, copy=True)


main()
