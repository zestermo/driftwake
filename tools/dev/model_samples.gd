extends RefCounted
## Worked examples for the modeling skill (.claude/skills/driftwake-modeling):
## props built the way new detailed models should be (a silhouette first, then
## the parts that give it scale, then dressing; one MeshBuilder; a few shared
## materials; vertex colour for shade; a simple collider). Not used in game.
## Render: modelshot.gd -- <out> 'S.cannon() | S.anchor() | S.lantern()'
## Origins on the ground, fronts toward +Z.


## The captain (1.86 m), to stand in a modelshot row for scale: 'S.body() | Buildings.smithy()'.
static func body() -> Node3D:
	return Humanoid.make(CharacterLook.default_look())


static func _body(n: String, size: Vector3, centre: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = centre
	b.add_child(cs)
	return b


## A ship's anchor stood on its crown, rope from the ring: extruded shank and
## flukes, tube arms on a curve, a lathe crown, a tube ring, a banded stock.
static func anchor() -> Node3D:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.42, 0.42, 0.45))
	var wood := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	mb.add_extrude(iron, Transform3D.IDENTITY, PackedVector2Array([
		Vector2(-0.075, 0.3), Vector2(0.075, 0.3), Vector2(0.05, 1.86), Vector2(-0.05, 1.86)]), 0.1, 2.0)
	mb.add_loft(iron, Transform3D.IDENTITY, [[0.2, 0.05, 0.05], [0.26, 0.11, 0.11], [0.4, 0.11, 0.11], [0.47, 0.06, 0.06]],
		MeshBuilder.profile_circle(8), 2.0, Color.WHITE, true, true)
	var fluke := PackedVector2Array([Vector2(0, 0.3), Vector2(0.17, 0.03), Vector2(0.1, -0.1), Vector2(0, -0.03), Vector2(-0.1, -0.1), Vector2(-0.17, 0.03)])
	for s in [-1.0, 1.0]:
		var a := Vector3(0, 0.34, 0)
		var ctrl := Vector3(s * 0.62, 0.22, 0)
		var tip := Vector3(s * 0.78, 0.78, 0)
		mb.add_tube(iron, MeshBuilder.curve_points(a, ctrl, tip, 8), 0.07, 0.045, 6, 2.0)
		var d := (tip - ctrl).normalized()
		mb.add_extrude(iron, Transform3D(Basis(Vector3.BACK, atan2(-d.x, d.y)), tip + d * 0.02), fluke, 0.045, 2.0, Color(0.9, 0.9, 0.9))
	var ring := PackedVector3Array()
	for i in range(13):
		var a := TAU * i / 12.0
		ring.append(Vector3(sin(a) * 0.15, 2.0 - cos(a) * 0.15, 0))
	mb.add_tube(iron, ring, 0.028, -1.0, 5, 2.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 1.7, 0)), Vector3(0.13, 0.13, 1.6), 1.0)
	for z in [-0.14, 0.14]:
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, 1.7, z)), Vector3(0.15, 0.15, 0.05), 2.0)
	for z in [-0.8, 0.8]:
		mb.add_blob(iron, Transform3D(Basis(), Vector3(0, 1.7, z)), Vector3.ONE * 0.085, RandomNumberGenerator.new(), 0.0, 3, 6)
	var line := MeshBuilder.curve_points(Vector3(0.12, 1.9, 0.02), Vector3(0.75, 1.7, 0.5), Vector3(0.95, 0.04, 0.75), 10)
	line.append_array(MeshBuilder.curve_points(Vector3(0.95, 0.04, 0.75), Vector3(1.1, 0.03, 1.2), Vector3(0.6, 0.03, 1.5), 6).slice(1))
	mb.add_tube(rope, line, 0.03, -1.0, 5, 4.0, Color.WHITE, false, true)
	var b := _body("Anchor", Vector3(1.7, 2.2, 0.4), Vector3(0, 1.1, 0))
	b.add_child(mb.to_instance())
	return b


## A ship's lantern: lathed base, glowing glass and cap, cage bars, a handle.
static func lantern() -> Node3D:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var glass := PSXMat.glow(Color(1.0, 0.78, 0.4), 2.4)
	var circle := MeshBuilder.profile_circle(8)
	mb.add_loft(iron, Transform3D.IDENTITY, [[0.0, 0.14, 0.14], [0.035, 0.14, 0.14], [0.05, 0.11, 0.11]], circle, 2.0, Color.WHITE, true, true, true, true)
	mb.add_loft(glass, Transform3D.IDENTITY, [[0.05, 0.1, 0.1], [0.18, 0.115, 0.115], [0.3, 0.1, 0.1]], circle, 2.0)
	mb.add_loft(iron, Transform3D.IDENTITY, [[0.3, 0.13, 0.13], [0.34, 0.13, 0.13], [0.44, 0.06, 0.06], [0.48, 0.035, 0.035], [0.5, 0.035, 0.035]],
		circle, 2.0, Color.WHITE, true, true, true, true)
	for i in range(4):
		var a := TAU * (i + 0.5) / 4.0
		var o := Vector3(cos(a), 0, sin(a))
		Buildings.beam_between(mb, iron, o * 0.135 + Vector3.UP * 0.045, o * 0.15 + Vector3.UP * 0.18, 0.018)
		Buildings.beam_between(mb, iron, o * 0.15 + Vector3.UP * 0.18, o * 0.135 + Vector3.UP * 0.305, 0.018)
	var handle := PackedVector3Array()
	for i in range(9):
		var a := PI * i / 8.0
		handle.append(Vector3(cos(a) * 0.08, 0.5 + sin(a) * 0.09, 0))
	mb.add_tube(iron, handle, 0.012, -1.0, 4, 2.0)
	var b := _body("Lantern", Vector3(0.3, 0.6, 0.3), Vector3(0, 0.3, 0))
	b.add_child(mb.to_instance())
	return b


## A naval gun on its truck carriage: a lathed barrel (reinforce rings, muzzle
## swell, cascabel), extruded stepped cheeks, axletrees and trucks, cap
## squares over the trunnions, a breeching rope, a pile of shot.
static func cannon() -> Node3D:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var wood := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	var bore := PSXMat.flat(Color(0.03, 0.03, 0.03))
	var circle := MeshBuilder.profile_circle(10)
	# barrel along +Z (the front), lathed along its own +Y; breech at z -0.55
	var bx := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.6, -0.55))
	mb.add_loft(iron, bx, [[-0.16, 0.05, 0.05], [-0.1, 0.06, 0.06], [-0.07, 0.1, 0.1], [-0.02, 0.19, 0.19], [0.0, 0.21, 0.21],
		[0.07, 0.21, 0.21], [0.09, 0.19, 0.19], [0.62, 0.17, 0.17], [0.64, 0.19, 0.19], [0.7, 0.19, 0.19], [0.72, 0.16, 0.16],
		[1.42, 0.13, 0.13], [1.47, 0.16, 0.16], [1.58, 0.16, 0.16], [1.62, 0.13, 0.13]], circle, 2.0, Color.WHITE, true, true)
	mb.add_cylinder(bore, bx * Transform3D(Basis(), Vector3(0, 1.605, 0)), 0.075, 0.075, 0.02, 8, 1.0)
	mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.3, 0.6, 0.4)), 0.05, 0.05, 0.6, 6, 2.0)
	# the cheeks: one stepped outline (x along the gun, y up) extruded across
	var cheek := PackedVector2Array([Vector2(-0.75, 0.1), Vector2(-0.45, 0.1), Vector2(-0.36, 0.17), Vector2(0.26, 0.17), Vector2(0.35, 0.1),
		Vector2(0.62, 0.1), Vector2(0.62, 0.6), Vector2(0.48, 0.6), Vector2(0.45, 0.55), Vector2(0.35, 0.55), Vector2(0.32, 0.6),
		Vector2(0.2, 0.6), Vector2(0.2, 0.48), Vector2(-0.2, 0.48), Vector2(-0.2, 0.36), Vector2(-0.55, 0.36), Vector2(-0.55, 0.24), Vector2(-0.75, 0.24)])
	for s in [-1.0, 1.0]:
		mb.add_extrude(wood, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(s * 0.25, 0, 0)), cheek, 0.09, 1.0)
		mb.add_box(iron, Transform3D(Basis(), Vector3(s * 0.25, 0.63, 0.4)), Vector3(0.11, 0.04, 0.17), 2.0)
		mb.add_box(iron, Transform3D(Basis(), Vector3(s * 0.25, 0.35, 0.05)), Vector3(0.1, 0.05, 0.05), 2.0, Color(0.8, 0.8, 0.8))
	# axletrees and the four trucks
	for ax in [[0.45, 0.17], [-0.58, 0.15]]:
		var z: float = ax[0]
		var r: float = ax[1]
		mb.add_box(wood, Transform3D(Basis(), Vector3(0, r, z)), Vector3(0.72, 0.1, 0.12), 1.0, Color(0.85, 0.85, 0.85))
		for s in [-1.0, 1.0]:
			mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.38 + 0.035, r, z)), r, r, 0.07, 10, 1.0, Color.WHITE, true, true)
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.38 + s * 0.045 + 0.02, r, z)), 0.03, 0.03, 0.04, 6, 2.0)
	# the quoin under the breech, the breeching rope round the cascabel
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.33, -0.48)), Vector3(0.34, 0.08, 0.36), 1.0, Color(0.9, 0.9, 0.9))
	mb.add_tube(rope, MeshBuilder.curve_points(Vector3(-0.3, 0.42, -0.62), Vector3(0, 0.6, -1.05), Vector3(0.3, 0.42, -0.62), 10), 0.022, -1.0, 5, 4.0)
	# shot piled by the carriage
	var rng := RandomNumberGenerator.new()
	for p in [Vector3(0.62, 0.07, -0.1), Vector3(0.62, 0.07, 0.05), Vector3(0.75, 0.07, -0.02), Vector3(0.66, 0.19, -0.02)]:
		mb.add_blob(iron, Transform3D(Basis(), p), Vector3.ONE * 0.075, rng, 0.0, 3, 6, 2.0, Color(0.75, 0.75, 0.78))
	var b := _body("Cannon", Vector3(0.9, 0.85, 1.9), Vector3(0, 0.42, 0.1))
	b.add_child(mb.to_instance())
	return b
