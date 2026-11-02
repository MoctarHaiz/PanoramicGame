extends Node3D
## Panoramic as a "3D toy" style sample, built from primitives (render with tools/render_3d.gd).
## Facing +x, origin at the feet. Colours from the 2017 icon: skin #583818/#785828,
## scarf #f83808, shoulder guard #284878/#4888a8, ring blue, hide skirt cream with brown spots.

const SKIN := Color("#4a2a12")
const SKIN_DARK := Color("#3a200c")
const HAIR := Color("#141418")
const SCARF := Color("#f2400e")
const GUARD := Color("#3f7fae")
const HIDE := Color("#d9cfbd")
const SPOT := Color("#5a3a1c")
const WOOD := Color("#a8743c")
const WHITE := Color("#e8e2d6")
const RING := Color("#3a7fb8")


func _ready() -> void:
	# legs: front leg forward (rotation around z), back leg pushing off
	_leg(Vector3(0.05, 0.0, 0.14), 28.0)
	_leg(Vector3(-0.05, 0.0, -0.14), -32.0)
	# skirt and belt
	var skirt := _mesh(_cyl(0.30, 0.40, 0.32), HIDE, Vector3(0, 0.82, 0))
	skirt.scale = Vector3(1.0, 1.0, 0.92)
	for p in [Vector3(0.22, 0.80, 0.28), Vector3(0.36, 0.74, -0.05), Vector3(-0.1, 0.78, 0.33), Vector3(0.05, 0.72, 0.36)]:
		var spot := _mesh(_sphere(0.07), SPOT, p)
		spot.scale = Vector3(1.0, 0.8, 0.35)
		spot.look_at_from_position(p, p * Vector3(2, 1, 2), Vector3.UP)
	_mesh(_torus(0.27, 0.34), Color("#c8280a"), Vector3(0, 0.98, 0))
	# torso
	var torso := _mesh(_capsule(0.30, 0.78), SKIN, Vector3(0.02, 1.28, 0))
	torso.scale = Vector3(1.0, 1.0, 0.86)
	torso.rotation_degrees.z = -8.0
	# bead necklace
	for i in 9:
		var a := deg_to_rad(-80.0 + i * 20.0)
		var c: Color = [RING, WHITE, SCARF][i % 3]
		_mesh(_sphere(0.04), c, Vector3(0.12 + cos(a) * 0.2, 1.50 - absf(sin(a)) * 0.02 - (1.0 - absf(a) / 1.4) * 0.08, sin(a) * 0.24))
	# scarf: wrap + two tails blown back
	_mesh(_torus(0.13, 0.24), SCARF, Vector3(0.04, 1.62, 0))
	for t in [[Vector3(-0.50, 1.66, 0.06), 10.0, 0.80], [Vector3(-0.42, 1.52, 0.10), -12.0, 0.62]]:
		var tail := _mesh(_box(Vector3(t[2], 0.16, 0.04)), SCARF, t[0])
		tail.rotation_degrees = Vector3(12, 0, t[1])
	# arms: back arm swings back with a ring, front arm forward with the staff
	_arm(Vector3(-0.04, 1.48, -0.30), -40.0, 30.0)
	var ring := _mesh(_torus(0.09, 0.13), RING, Vector3(-0.42, 1.02, -0.36))
	ring.rotation_degrees = Vector3(90, 0, 20)
	_arm(Vector3(0.08, 1.48, 0.30), 55.0, 45.0)
	# shoulder guard on the near shoulder
	var g1 := _mesh(_sphere(0.21), GUARD, Vector3(0.08, 1.54, 0.30), 0.3)
	g1.scale = Vector3(1.05, 0.75, 1.0)
	var g2 := _mesh(_sphere(0.17), GUARD.darkened(0.12), Vector3(0.12, 1.40, 0.34), 0.3)
	g2.scale = Vector3(1.0, 0.6, 0.9)
	# staff with a white tuft, gripped by the front hand
	var tilt := deg_to_rad(16.0)
	var centre := Vector3(0.70, 1.15, 0.32)
	var staff := _mesh(_cyl(0.035, 0.035, 2.1), WOOD, centre)
	staff.rotation.z = -tilt
	var top := centre + Vector3(sin(tilt), cos(tilt), 0) * 1.0
	for i in 8:
		var a := i * TAU / 8.0
		var tuft := _mesh(_cone(0.07, 0.34), WHITE, top + Vector3(cos(a) * 0.05, -0.08, sin(a) * 0.05), 0.8)
		tuft.rotation = Vector3(sin(a) * 0.45, 0, PI + cos(a) * 0.45 - tilt)
	var band := _mesh(_cyl(0.055, 0.055, 0.07), Color("#c8280a"), top + Vector3(0, 0.02, 0))
	band.rotation.z = -tilt
	_head(Vector3(0.10, 1.98, 0))


func _head(at: Vector3) -> void:
	var head := Node3D.new()
	head.position = at
	add_child(head)
	_mesh(_sphere(0.42), SKIN, Vector3.ZERO, 0.6, head)
	_mesh(_sphere(0.09), SKIN_DARK, Vector3(-0.10, -0.02, 0.39), 0.6, head)  # ear
	# eyes: placed on the head surface; the near eye turned toward the camera (+z), the far eye near the silhouette
	for e in [[42.0, 0.115], [-12.0, 0.09]]:
		var frame := Node3D.new()
		frame.rotation_degrees.y = -e[0]
		frame.position.y = 0.02
		head.add_child(frame)
		var white := _mesh(_sphere(e[1]), Color("#fbf7f2"), Vector3(0.405, 0, 0), 0.25, frame)
		white.scale = Vector3(0.45, 1.3, 1.0)
		var iris := _mesh(_sphere(e[1] * 0.64), Color("#5a2626"), Vector3(0.438, -0.01, 0.012), 0.2, frame)
		iris.scale = Vector3(0.35, 1.2, 1.0)
		var pupil := _mesh(_sphere(e[1] * 0.32), Color("#100808"), Vector3(0.452, -0.01, 0.014), 0.2, frame)
		pupil.scale = Vector3(0.3, 1.2, 1.0)
		_mesh(_sphere(e[1] * 0.17), Color.WHITE, Vector3(0.462, 0.045, 0.03), 0.1, frame)
		var brow := _mesh(_capsule(0.024, e[1] * 2.5), HAIR, Vector3(0.385, 0.175, 0.0), 0.5, frame)
		brow.rotation_degrees = Vector3(90.0, 0, -10.0)
		brow.rotation_degrees.x = 90.0 + (16.0 if e[0] > 0 else -12.0)
	_mesh(_sphere(0.055), SKIN, Vector3(0.40, -0.07, 0.12), 0.6, head)  # nose
	var mouth := _mesh(_torus(0.07, 0.095), Color("#2a0e08"), Vector3(0.36, -0.19, 0.16), 0.4, head)
	mouth.rotation_degrees = Vector3(0, -24, 90)
	mouth.scale = Vector3(0.4, 1.0, 1.3)
	# hair: spikes swept back and up, plus the brown horn strand
	var spikes := [
		[Vector3(-0.15, 0.30, 0.0), Vector3(0, 0, 60)], [Vector3(-0.25, 0.18, 0.18), Vector3(-25, 0, 75)],
		[Vector3(-0.25, 0.18, -0.18), Vector3(25, 0, 75)], [Vector3(-0.30, 0.0, 0.10), Vector3(-15, 0, 95)],
		[Vector3(-0.30, 0.0, -0.10), Vector3(15, 0, 95)], [Vector3(0.02, 0.36, 0.14), Vector3(-30, 0, 35)],
		[Vector3(0.02, 0.36, -0.14), Vector3(30, 0, 35)], [Vector3(0.18, 0.32, 0.0), Vector3(0, 0, 15)],
		[Vector3(-0.08, 0.34, 0.24), Vector3(-50, 0, 55)], [Vector3(-0.08, 0.34, -0.24), Vector3(50, 0, 55)],
		[Vector3(-0.28, -0.14, 0.0), Vector3(0, 0, 115)]]
	_mesh(_sphere(0.40), HAIR, Vector3(-0.05, 0.10, 0), 0.4, head).scale = Vector3(0.95, 0.85, 1.02)
	for s in spikes:
		var cone := _mesh(_cone(0.13, 0.42), HAIR, s[0], 0.7, head)
		cone.rotation_degrees = s[1]
		cone.translate_object_local(Vector3(0, 0.18, 0))
	var horn := _mesh(_cone(0.06, 0.40), Color("#9a6a36"), Vector3(0.0, 0.46, 0.02), 0.5, head)
	horn.rotation_degrees.z = -18.0
	horn.translate_object_local(Vector3(0, 0.12, 0))
	# fringe over the forehead
	for z in [-0.14, 0.0, 0.14]:
		var f := _mesh(_cone(0.08, 0.26), HAIR, Vector3(0.26, 0.26, z), 0.4, head)
		f.rotation_degrees = Vector3(0, 0, -120)


func _leg(hip: Vector3, swing: float) -> void:
	var leg := Node3D.new()
	leg.position = hip + Vector3(0, 0.78, 0)
	leg.rotation_degrees.z = swing
	add_child(leg)
	_mesh(_capsule(0.13, 0.78), SKIN, Vector3(0, -0.36, 0), 0.6, leg)
	var tuft := _mesh(_cyl(0.16, 0.12, 0.12), WHITE, Vector3(0, -0.40, 0), 0.9, leg)
	tuft.scale = Vector3(1, 1, 1)
	var foot := _mesh(_sphere(0.13), SKIN_DARK, Vector3(0.08, -0.74, 0), 0.6, leg)
	foot.scale = Vector3(1.5, 0.6, 0.9)


func _arm(shoulder: Vector3, swing: float, forearm: float) -> void:
	var arm := Node3D.new()
	arm.position = shoulder
	arm.rotation_degrees.z = swing
	add_child(arm)
	_mesh(_capsule(0.09, 0.42), SKIN, Vector3(0, -0.18, 0), 0.6, arm)
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.36, 0)
	elbow.rotation_degrees.z = forearm
	arm.add_child(elbow)
	_mesh(_capsule(0.08, 0.40), SKIN, Vector3(0, -0.17, 0), 0.6, elbow)
	_mesh(_sphere(0.10), SKIN_DARK, Vector3(0, -0.38, 0), 0.6, elbow)


func _mesh(m: Mesh, c: Color, at: Vector3, rough := 0.55, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = rough
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.6
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(0.0, r, h)


func _torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
