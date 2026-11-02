## Prints what a .blend holds: scenes, cameras, lights, armatures (bones), actions and their
## frame ranges, render settings. Run: Blender -b file.blend --python inspect.py
import bpy

for sc in bpy.data.scenes:
    r = sc.render
    print("SCENE", sc.name, "frames", sc.frame_start, sc.frame_end, "fps", r.fps, "engine", r.engine,
          "res", r.resolution_x, r.resolution_y, r.resolution_percentage, "film_transparent", r.film_transparent,
          "camera", sc.camera.name if sc.camera else None, "world", sc.world.name if sc.world else None)
    if r.engine == "CYCLES":
        print("  cycles samples", sc.cycles.samples)
    elif hasattr(sc, "eevee"):
        print("  eevee samples", sc.eevee.taa_render_samples)
    print("  view_transform", sc.view_settings.view_transform, sc.view_settings.look)
for ob in bpy.data.objects:
    extra = ""
    if ob.type == "CAMERA":
        c = ob.data
        extra = f"type={c.type} ortho_scale={c.ortho_scale} lens={c.lens}"
    elif ob.type == "LIGHT":
        l = ob.data
        extra = f"light={l.type} energy={l.energy} color={tuple(l.color)}"
    elif ob.type == "ARMATURE":
        extra = f"bones={len(ob.data.bones)} action={ob.animation_data.action.name if ob.animation_data and ob.animation_data.action else None}"
    elif ob.type == "MESH":
        extra = f"verts={len(ob.data.vertices)} mats={[m.name for m in ob.data.materials if m]}"
    print("OBJ", ob.name, ob.type, "parent", ob.parent.name if ob.parent else None, "loc", tuple(round(v, 3) for v in ob.location),
          "rot", tuple(round(v, 3) for v in ob.rotation_euler), "scale", tuple(round(v, 3) for v in ob.scale), extra,
          "hide_render", ob.hide_render, "collections", [c.name for c in ob.users_collection])
for a in bpy.data.actions:
    print("ACTION", a.name, "range", tuple(a.frame_range), "users", a.users, "fake", a.use_fake_user)
for ob in bpy.data.objects:
    if ob.type == "ARMATURE":
        print("BONES", ob.name, [b.name for b in ob.data.bones])
        if ob.animation_data:
            ad = ob.animation_data
            print("NLA", [(t.name, [(s.name, s.action.name if s.action else None, s.frame_start, s.frame_end) for s in t.strips]) for t in ad.nla_tracks])
for m in bpy.data.materials:
    print("MAT", m.name, "nodes", [n.type for n in m.node_tree.nodes] if m.use_nodes and m.node_tree else None)
for w in bpy.data.worlds:
    print("WORLD", w.name, [n.type for n in w.node_tree.nodes] if w.node_tree else None)
