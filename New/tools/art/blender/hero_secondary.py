"""Panoramic's secondary rig (ROOT/_agents/AAA/hero3d/Panoramic_AAA.blend): the loincloth's six flaps, the
scarf's tail and the hair mass.

- fit(arm): after any pose (an action's frame or a pose built in hero_render.py), each loincloth flap
  swings out just as far as it must to stay clear of the thighs, knees and shins (a body point may
  move out from the flap no further than it sits at rest; the flap hinges at the belt), the side
  flaps follow their thigh a little, and the lower bone of each flap keeps its keyed follow-through
  unless that would cut into a leg. The cloth hangs between the hips' "down" and gravity.
- spring_bake(arm, action, frames, loop): the follow-through of the lower flaps, the scarf's tail and
  the hair, simulated over an action (verlet tips on springs to the pose, drag, the run's wind) and
  keyed into it: overlap and drag on every move; loops are simulated three times over and the last
  pass kept, so they loop seamlessly.

Without the secondary bones (the user's own file, the bandit) fit() does nothing.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

P = "mixamorig:"
FLAPS = ("F", "L", "R", "BL", "BR", "B")
SIDE = {"L": "Left", "R": "Right", "BL": "Left", "BR": "Right"}  # the thigh a side flap follows
FOLLOW = {"L": 1.0, "R": 1.0, "BL": 0.85, "BR": 0.85}
GRAVITY = 0.55  ## how much the cloth hangs to the world's down rather than the hips' (lying down: it drapes)
MARGIN = math.radians(4.0)


def has_rig(arm):
    return arm is not None and "cloth_F" in arm.pose.bones


def _w(arm, v):
    return arm.matrix_world @ v


def _rest_world(arm, name, end="head"):
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.head_local if end == "head" else b.tail_local)


def _leg_points(arm, side, rest):
    """Points along a thigh, the knee and the top of the shin (world), with their radii."""
    if rest:
        hip, knee, foot = (_rest_world(arm, P + side + n) for n in ("UpLeg", "Leg", "Foot"))
    else:
        pb = arm.pose.bones
        hip, knee, foot = (_w(arm, pb[P + side + n].head) for n in ("UpLeg", "Leg", "Foot"))
    out = []
    for t, r in ((0.35, 0.055), (0.6, 0.05), (0.85, 0.046), (1.0, 0.045)):
        out.append((hip.lerp(knee, t), r))
    out.append((knee.lerp(foot, 0.25), 0.042))
    out.append((knee.lerp(foot, 0.5), 0.038))
    return out


def _hips_rot(arm):
    """The hips' rotation from rest (world)."""
    pb = arm.pose.bones[P + "Hips"]
    m_rest = arm.matrix_world @ pb.bone.matrix_local
    m_now = arm.matrix_world @ pb.matrix
    return (m_now.to_3x3().normalized() @ m_rest.to_3x3().normalized().inverted()).to_quaternion()


def _set_dir(arm, name, d):
    """Points a bone (its Y axis) along world direction d, from its rest relation to its parent."""
    pb = arm.pose.bones[name]
    par = pb.parent
    rest_rel = par.bone.matrix_local.inverted() @ pb.bone.matrix_local
    m = par.matrix @ rest_rel  # where it would be unposed (armature space)
    mw3 = arm.matrix_world.to_3x3()
    y_now = (mw3 @ m.to_3x3().col[1]).normalized()
    rot_w = y_now.rotation_difference(d.normalized())
    rot_a = (mw3.inverted() @ rot_w.to_matrix() @ mw3)
    new = (rot_a @ m.to_3x3()).to_4x4()
    new.translation = m.translation
    pb.matrix = new


def _angle_out(d, down, out):
    return math.atan2(d.dot(out), d.dot(down))


def fit(arm, update=True):
    if not has_rig(arm):
        return
    vl = bpy.context.view_layer
    if update:
        vl.update()
    q = _hips_rot(arm)
    mw3 = arm.matrix_world.to_3x3()
    g_down = Vector((0.0, 0.0, -1.0))
    h_down = q @ Vector((0.0, 0.0, -1.0))  # (rest: he stands along world z)
    down = (h_down * (1 - GRAVITY) + g_down * GRAVITY).normalized()
    legs = {s: (_leg_points(arm, s, True), _leg_points(arm, s, False)) for s in ("Left", "Right")}
    hips_pb = arm.pose.bones[P + "Hips"]
    hips_rest = arm.matrix_world @ hips_pb.bone.matrix_local
    hips_now = arm.matrix_world @ hips_pb.matrix
    to_now = hips_now @ hips_rest.inverted()
    for f in FLAPS:
        up_name, lo_name = "cloth_" + f, "cloth_" + f + "2"
        b = arm.data.bones[up_name]
        h_rest = arm.matrix_world @ b.head_local
        t_rest = arm.matrix_world @ b.tail_local
        h_now = to_now @ h_rest
        out_rest = Vector((h_rest.x - 0.02, h_rest.y, 0.0)).normalized()
        out = (q @ out_rest)
        out = (out - down * out.dot(down)).normalized()
        # the angle out the flap needs: no body point further out (relative to its depth below the
        # hinge) than at rest
        need = 0.0
        for side, (rest_pts, now_pts) in legs.items():
            for (pr, r), (pn, _) in zip(rest_pts, now_pts):
                rr, rn = pr - h_rest, pn - h_now
                a0, b0 = rr.dot(out_rest), -rr.z
                a, bb = rn.dot(out), rn.dot(down)
                lat = rn - out * a - down * bb
                if bb < 0.02 or lat.length > 0.09 + r:
                    continue
                if a - a0 > 0.0:
                    need = max(need, math.atan2(a - a0, bb) + MARGIN)
        theta = min(need, math.radians(85))
        d = down * math.cos(theta) + out * math.sin(theta)
        if f in SIDE:  # the side flaps follow their thigh forwards and back
            pb = arm.pose.bones
            hip = _w(arm, pb[P + SIDE[f] + "UpLeg"].head)
            knee = _w(arm, pb[P + SIDE[f] + "Leg"].head)
            fwd = (q @ Vector((1.0, 0.0, 0.0)))
            fwd = (fwd - down * fwd.dot(down)).normalized()
            leg = (knee - hip).normalized()
            swing = math.atan2(leg.dot(fwd), leg.dot(down))
            s = FOLLOW[f] * max(-1.2, min(1.2, swing))
            d = (d * math.cos(s) + fwd * math.sin(s)).normalized()
        _set_dir(arm, up_name, d)
        vl.update()
        # the lower bone: its keyed follow-through, pushed out if it would cut into a leg
        lo = arm.pose.bones[lo_name]
        h2 = _w(arm, lo.head)
        d2 = (_w(arm, lo.tail) - h2).normalized()
        h2_rest = t_rest
        need2 = -9.0
        for side, (rest_pts, now_pts) in legs.items():
            for (pr, r), (pn, _) in zip(rest_pts, now_pts):
                rr, rn = pr - h2_rest, pn - h2
                a0 = rr.dot(out_rest)
                a, bb = rn.dot(out), rn.dot(down)
                lat = rn - out * a - down * bb
                if bb < 0.015 or lat.length > 0.09 + r:
                    continue
                if a - a0 > 0.0:
                    need2 = max(need2, math.atan2(a - a0, bb) + MARGIN)
        cur = _angle_out(d2, down, out)
        if need2 > cur:
            side_c = d2 - down * d2.dot(down) - out * d2.dot(out)
            k = max(0.0, 1.0 - side_c.length ** 2) ** 0.5
            d2 = (down * math.cos(need2) + out * math.sin(need2)) * k + side_c
            _set_dir(arm, lo_name, d2)
            vl.update()


# ------------------------------------------------------------------ follow-through (baked into actions)

SPRINGS = {  # bone: (stiffness 1/s^2, damping 1/s, share of the air's push, share of gravity)
    "scarf_1": (160.0, 14.0, 0.5, 0.3), "scarf_2": (120.0, 11.0, 0.6, 0.3), "scarf_3": (90.0, 9.0, 0.7, 0.3),
    "hair": (650.0, 30.0, 0.15, 0.0),
}
MAXDEG = {"scarf_1": 10.0, "scarf_2": 16.0, "scarf_3": 22.0, "hair": 6.0}  ## the furthest each may leave its pose
## (the generated mesh welds the scarf's tail to his back: more than this and the join stretches)
CHAINS = [["scarf_1", "scarf_2", "scarf_3"], ["hair"]]


def spring_bake(arm, action, frames, loop=True, wind=None, fps=30.0, passes=3):
    """Simulates the tips of the secondary bones (the scarf's tail, the hair) over `frames` of `action` and
    keys their rotations into it: overlap, drag and follow-through. wind(frame) -> world velocity of the
    air relative to him (the run: the air comes from the front at his speed). Loops run `passes` times
    and keep the last pass (seamless); one-shot moves settle on their first pose first."""
    sc = bpy.context.scene
    vl = bpy.context.view_layer
    ad = arm.animation_data
    ad.action = action
    if len(action.slots):
        ad.action_slot = action.slots[0]
    dt = 1.0 / fps
    wind = wind or (lambda f: Vector((0.0, 0.0, 0.0)))
    names = [n for ch in CHAINS for n in ch if n in arm.pose.bones]
    for n in names:  # the bones start from the pose (no keys of their own yet)
        pb = arm.pose.bones[n]
        pb.rotation_mode = "QUATERNION"
        for c in list(_fcurves(action)):
            if c.data_path.startswith('pose.bones["%s"]' % n):
                _fcurves(action).remove(c)
    tips, prev, out = {}, {}, {}
    seq = list(frames) * passes if loop else [frames[0]] * 10 + list(frames)
    keep_from = len(frames) * (passes - 1) if loop else 10
    for step, fr in enumerate(seq):
        sc.frame_set(int(fr))
        for n in names:
            arm.pose.bones[n].matrix_basis = Matrix.Identity(4)
        vl.update()
        air = Vector(wind(fr))
        for ch in CHAINS:
            for n in ch:
                if n not in arm.pose.bones:
                    continue
                pb = arm.pose.bones[n]
                pb.matrix_basis = Matrix.Identity(4)
                vl.update()
                head = _w(arm, pb.head)
                want = _w(arm, pb.tail)
                L = (want - head).length
                k, damp, wk, gk = SPRINGS[n]
                if n not in tips:
                    tips[n], prev[n] = want.copy(), want.copy()
                x, xp = tips[n], prev[n]
                vel = (x - xp) / dt
                acc = (want - x) * k - vel * damp + air * wk * 2.0 + Vector((0.0, 0.0, -9.8)) * gk * 0.15
                nx = x + vel * dt + acc * dt * dt
                d = nx - head
                if d.length < 1e-6:
                    d = want - head
                nx = head + d.normalized() * L
                wd, nd = (want - head).normalized(), (nx - head).normalized()
                ang = wd.angle(nd) if wd.length and nd.length else 0.0
                lim = math.radians(MAXDEG.get(n, 30.0))
                if ang > lim:  # held within its limit (the joint, not the spring, stops it)
                    nd = wd.slerp(nd, lim / ang) if hasattr(wd, "slerp") else (wd * (1 - lim / ang) + nd * (lim / ang)).normalized()
                    nx = head + nd * L
                prev[n], tips[n] = x, nx
                _set_dir(arm, n, nx - head)
                vl.update()
        if step >= keep_from:
            out[fr] = {n: arm.pose.bones[n].matrix_basis.to_quaternion() for n in names}
    for fr, rots in out.items():
        for n, q in rots.items():
            pb = arm.pose.bones[n]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=fr, group=n)
    if loop:  # the loop's closing key (frame after the last) = the first
        last = frames[-1] + 1
        for n, q in out[frames[0]].items():
            pb = arm.pose.bones[n]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=last, group=n)
    return out


def _fcurves(action):
    return action.layers[0].strips[0].channelbags[0].fcurves
