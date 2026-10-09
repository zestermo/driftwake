class_name TraderShips
extends RefCounted
## Peaceful ships tied up in Brinehollow's harbour: the hull is HullBuilder's
## (so they sit and collide like the others), the rigs are their own. Each
## builds its model under `parent` (a MooredHull) and the hull's collision.

const CREAM := Color(0.95, 0.9, 0.78)


static func _mats(hull: Color, trim: Color) -> Dictionary:
	return {
		"hull": PSXMat.lit("planks_dark", hull, {"affine": 0.6}),
		"deck": PSXMat.lit("planks", Color(0.95, 0.9, 0.82), {"affine": 0.6}),
		"trim": PSXMat.lit("planks", trim),
		"wood": PSXMat.lit("bark"),
		"rope": PSXMat.lit("rope"),
	}


static func _finish(parent: CollisionObject3D, mb: MeshBuilder) -> void:
	parent.add_child(mb.to_instance("PSXModel"))
	HullBuilder.collide(parent, false)


static func _mast(mb: MeshBuilder, wood: Material, z: float, base_y: float, top: float, r: float = 0.24) -> void:
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, base_y, z)), r, r * 0.55, top - base_y, 7, 0.8)


## Shrouds from a mast head down to both rails.
static func _shrouds(mb: MeshBuilder, rope: Material, z: float, head_y: float, rail_y: float, half_w: float) -> void:
	for s in [-1.0, 1.0]:
		for dz in [-0.6, 0.6]:
			mb.add_tube(rope, PackedVector3Array([Vector3(s * 0.15, head_y, z), Vector3(s * half_w, rail_y, z + dz)]), 0.03, -1.0, 4)


## The junk-rigged trader: two masts of battened fan sails, a high stern.
static func junk(parent: CollisionObject3D) -> void:
	var m := _mats(Color(0.62, 0.42, 0.28), Color(0.7, 0.25, 0.15))
	var mb := MeshBuilder.new()
	HullBuilder.hull(mb, m, false)
	var canvas := PSXMat.lit("canvas", Color(0.96, 0.88, 0.72), {"affine": 0.6})
	var batten: Material = m["wood"]
	for spec in [[-1.8, 15.0, 9, 3.6, 1.0], [-8.0, 11.0, 7, 2.6, 0.75]]:
		var z: float = spec[0]
		var top: float = spec[1]
		_mast(mb, m["wood"], z, HullBuilder.DECK_Y, top + 0.6)
		# panels between battens, fanning out aft as they go up
		var n: int = spec[2]
		var base_w: float = spec[3]
		var k: float = spec[4]
		var y0 := 2.4 * k + 0.8
		var dy := (top - y0) / n
		for i in range(n):
			var ya := y0 + i * dy
			var yb := ya + dy
			var fa := z - 0.8 * k + 0.04 * i
			var fb := z - 0.8 * k + 0.04 * (i + 1)
			var ba := z + base_w + 0.32 * i * k
			var bb := z + base_w + 0.32 * (i + 1) * k
			# the top panel peaks forward
			if i == n - 1:
				bb = ba - 1.0 * k
			var a := Vector3(0.12, ya, fa); var b := Vector3(0.12, ya, ba); var c := Vector3(0.12, yb, bb); var d := Vector3(0.12, yb, fb)
			mb.add_quad(canvas, a, b, c, d, Vector2(fa, ya) * 0.3, Vector2(ba, ya) * 0.3, Vector2(bb, yb) * 0.3, Vector2(fb, yb) * 0.3, Color.WHITE, Vector3.RIGHT)
			mb.add_quad(canvas, a - Vector3(0.02, 0, 0), d - Vector3(0.02, 0, 0), c - Vector3(0.02, 0, 0), b - Vector3(0.02, 0, 0), Vector2(fa, ya) * 0.3, Vector2(fb, yb) * 0.3, Vector2(bb, yb) * 0.3, Vector2(ba, ya) * 0.3, Color(0.82, 0.82, 0.82), Vector3.LEFT)
			mb.add_box(batten, Transform3D(Basis(), Vector3(0.12, ya, (fa + ba) * 0.5)), Vector3(0.08, 0.07, ba - fa + 0.2), 1.0, Color.WHITE, false)
		mb.add_tube(m["rope"], MeshBuilder.sag_points(Vector3(0, top + 0.4, z), Vector3(0, HullBuilder.DECK_Y + 1.0, z + base_w + 0.32 * n * k), 0.4), 0.03, -1.0, 4)
	_shrouds(mb, m["rope"], -1.8, 14.5, HullBuilder.DECK_Y + 0.9, 3.9)
	# lanterns at the stern rail, a pennant
	var glow := PSXMat.glow(Color(1.0, 0.75, 0.4), 2.0)
	for s in [-1.0, 1.0]:
		mb.add_box(glow, Transform3D(Basis(), Vector3(s * 3.0, HullBuilder.QD_Y + 1.0, HullBuilder.QD_BACK - 0.3)), Vector3(0.26, 0.34, 0.26), 1.0)
	mb.add_card(PSXMat.lit("cloth_red"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 15.4, -1.5)), 1.4, 0.35, Rect2(0, 0, 0.5, 0.25))
	mb.add_card(PSXMat.lit("cloth_red"), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 15.4, -1.5)), 1.4, 0.35, Rect2(0, 0, 0.5, 0.25))
	_finish(parent, mb)


## A three-masted merchantman: square sails on fore and main, a gaff sail on the
## mizzen over the quarterdeck, a jib off the bowsprit.
static func merchantman(parent: CollisionObject3D) -> void:
	var m := _mats(Color(0.5, 0.36, 0.24), Color(0.85, 0.7, 0.3))
	var mb := MeshBuilder.new()
	HullBuilder.hull(mb, m, false)
	var canvas := PSXMat.lit("canvas", CREAM, {"affine": 0.6})
	var wood: Material = m["wood"]
	var rope: Material = m["rope"]
	# [z, base y, top, yards: [y, half span, sail drop]]
	var masts := [[-7.0, HullBuilder.DECK_Y, 15.5, [[12.0, 3.6, 3.4], [15.0, 2.6, 2.6]]],
		[-1.0, HullBuilder.DECK_Y, 18.5, [[13.5, 4.4, 4.2], [17.4, 3.2, 3.2]]]]
	for ms in masts:
		var z: float = ms[0]
		_mast(mb, wood, z, ms[1], float(ms[2]) + 0.8, 0.27)
		for yd in ms[3]:
			var y: float = yd[0]
			var hw: float = yd[1]
			var drop: float = yd[2]
			mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(hw + 0.3, y, z + 0.25)), 0.09, 0.09, hw * 2.0 + 0.6, 6, 0.8)
			_square_sail(mb, canvas, z + 0.35, y - 0.1, hw, drop)
		_shrouds(mb, rope, z, float(ms[2]) - 1.0, HullBuilder.DECK_Y + 0.9, 3.9)
	# mizzen with a gaff sail
	var mz := 6.8
	_mast(mb, wood, mz, HullBuilder.QD_Y, 14.0, 0.2)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.35), Vector3(0, 12.0, mz)), 0.07, 0.06, 3.4, 5, 0.8)
	var g0 := Vector3(0.1, HullBuilder.QD_Y + 1.6, mz + 0.2)
	var g1 := Vector3(0.1, HullBuilder.QD_Y + 1.6, mz + 3.4)
	var g2 := Vector3(0.1, 12.0 + 3.2 * sin(0.35), mz + 3.2 * cos(0.35))
	var g3 := Vector3(0.1, 11.9, mz + 0.2)
	for s in [1.0, -1.0]:
		var o := Vector3(0.02 * s, 0, 0)
		if s > 0.0:
			mb.add_quad(canvas, g0 + o, g1 + o, g2 + o, g3 + o, Vector2(0, 2), Vector2(1, 2), Vector2(1, 0), Vector2(0, 0), Color.WHITE, Vector3.RIGHT)
		else:
			mb.add_quad(canvas, g0 + o, g3 + o, g2 + o, g1 + o, Vector2(0, 2), Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Color(0.82, 0.82, 0.82), Vector3.LEFT)
	# jib: bowsprit tip to the fore mast head
	var jt := Vector3(0, 15.0, -7.1)
	var jb := Vector3(0, 2.6, -15.8)
	var jc := Vector3(0, 2.2, -10.0)
	mb.add_tri(canvas, jt, jb, jc, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2(0, 0), Vector2(1, 2), Vector2(0, 2), Color.WHITE, Vector3.RIGHT)
	mb.add_tri(canvas, jt, jc, jb, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector2(0, 0), Vector2(0, 2), Vector2(1, 2), Color(0.82, 0.82, 0.82), Vector3.LEFT)
	mb.add_tube(rope, PackedVector3Array([Vector3(0, 18.6, -1.0), Vector3(0, 15.6, -7.0), jb]), 0.035, -1.0, 4)
	# a painted band along the hull, stern lanterns, colours at the main top
	var band := PSXMat.lit("planks", Color(0.85, 0.7, 0.3))
	for s in [-1.0, 1.0]:
		mb.add_box(band, Transform3D(Basis(), Vector3(s * 4.42, -0.35, 1.0)), Vector3(0.05, 0.35, 12.0), 1.0)
		mb.add_box(PSXMat.glow(Color(1.0, 0.75, 0.4), 2.0), Transform3D(Basis(), Vector3(s * 2.8, HullBuilder.QD_Y + 1.1, HullBuilder.QD_BACK - 0.2)), Vector3(0.28, 0.36, 0.28), 1.0)
	var flag := PSXMat.lit("cloth_blue")
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 19.0, -0.7)), 1.6, 0.9, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 19.0, -0.7)), 1.6, 0.9, Rect2(0, 0, 0.5, 0.5))
	_finish(parent, mb)


## A square sail hung from a yard at (y, z): bellied a little forward (both faces).
static func _square_sail(mb: MeshBuilder, canvas: Material, z: float, y: float, hw: float, drop: float) -> void:
	var belly := Vector3(0, 0, -0.5)
	var tl := Vector3(-hw, y, z); var tr := Vector3(hw, y, z)
	var ml := Vector3(-hw * 0.95, y - drop * 0.5, z) + belly; var mr := Vector3(hw * 0.95, y - drop * 0.5, z) + belly
	var bl := Vector3(-hw * 0.9, y - drop, z) + belly * 0.4; var br := Vector3(hw * 0.9, y - drop, z) + belly * 0.4
	for half in [[tl, tr, mr, ml, 0.0], [ml, mr, br, bl, 1.0]]:
		var a: Vector3 = half[0]; var b: Vector3 = half[1]; var c: Vector3 = half[2]; var d: Vector3 = half[3]
		var v0: float = half[4]
		mb.add_quad(canvas, a, b, c, d, Vector2(0, v0), Vector2(2, v0), Vector2(2, v0 + 1), Vector2(0, v0 + 1), Color.WHITE, Vector3.FORWARD)
		mb.add_quad(canvas, a, d, c, b, Vector2(0, v0), Vector2(0, v0 + 1), Vector2(2, v0 + 1), Vector2(2, v0), Color(0.82, 0.82, 0.82), Vector3.BACK)


## A peaceful sloop (HullBuilder's own rig, a trader's colours, no skull).
static func sloop(parent: CollisionObject3D) -> void:
	var model := Node3D.new()
	parent.add_child(model)
	HullBuilder.build(model, {"hull": Color(0.7, 0.62, 0.5), "sail": Color(0.95, 0.88, 0.7), "trim": Color(0.3, 0.45, 0.6), "flag": Color(0.4, 0.6, 0.9)})
	HullBuilder.collide(parent)


## An oared longboat (bow -Z), its oars shipped across the thwarts.
static func longboat(parent: CollisionObject3D) -> void:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.6})
	var dark := PSXMat.lit("planks_dark")
	var rings := []
	for r in [[3.2, 0.12, 0.05], [2.4, 0.75, 0.35], [0.0, 1.0, 0.5], [-2.4, 0.75, 0.35], [-3.4, 0.08, 0.04]]:
		rings.append(r)
	# a shallow hull from strips: sides and bottom between cross-sections
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for s in [-1.0, 1.0]:
			var p0 := Vector3(s * float(a[1]), 0.55, float(a[0])); var p1 := Vector3(s * float(b[1]), 0.55, float(b[0]))
			var p2 := Vector3(s * float(b[2]), -0.25, float(b[0])); var p3 := Vector3(s * float(a[2]), -0.25, float(a[0]))
			mb.add_quad(wood, p0, p1, p2, p3, Vector2(p0.z, 0) * 0.5, Vector2(p1.z, 0) * 0.5, Vector2(p2.z, 0.6) * 0.5, Vector2(p3.z, 0.6) * 0.5, Color.WHITE, Vector3(s, -0.3, 0).normalized())
			mb.add_quad(wood, p0, p3, p2, p1, Vector2(p0.z, 0) * 0.5, Vector2(p3.z, 0.6) * 0.5, Vector2(p2.z, 0.6) * 0.5, Vector2(p1.z, 0) * 0.5, Color(0.75, 0.75, 0.75), Vector3(-s, 0.3, 0).normalized())
			mb.add_box(dark, Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, 0.04, 0)), Vector3(0.1, 0.08, p0.distance_to(p1) + 0.05), 1.0, Color.WHITE, false)
		mb.add_quad(wood, Vector3(-float(a[2]), -0.2, float(a[0])), Vector3(float(a[2]), -0.2, float(a[0])), Vector3(float(b[2]), -0.2, float(b[0])), Vector3(-float(b[2]), -0.2, float(b[0])),
			Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.7, 0.7, 0.7), Vector3.UP)
	for z in [-1.6, -0.5, 0.6, 1.7]:
		var hw := 0.8 if absf(z) < 1.0 else 0.65
		mb.add_box(dark, Transform3D(Basis(), Vector3(0, 0.3, z)), Vector3(hw * 2.0, 0.07, 0.3), 1.0, Color.WHITE, false)
	for k in range(4):
		var z := -1.4 + k * 0.9
		mb.add_box(wood, Transform3D(Basis(Vector3.UP, 0.12 * (k % 2 * 2 - 1)), Vector3(0, 0.42, z)), Vector3(3.6, 0.05, 0.08), 1.0, Color.WHITE, false)
	parent.add_child(mb.to_instance("PSXModel"))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.8, 6.4)
	cs.shape = box
	cs.position = Vector3(0, 0.15, 0)
	parent.add_child(cs)
