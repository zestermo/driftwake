class_name CapitalHalls
extends RefCounted
## The capital's walk-in halls (1.27, docs/v1_27_plan.md C2): the library on the cathedral's forecourt (rows of shelves,
## reading tables, lamps, and behind the last shelf a gap into a hidden back room with a chest) and the theatre on the
## arena street (a raised stage with curtains and footlights, raked seats facing it). Each a hall on its CapitalPlan.
## SPECIAL rect: facade outside, plaster inside, a door in the face toward its floor, steps up, a hip roof; its people
## and caches come with C4. Frame coordinates, into the district's Specials piece.

const M := preload("res://scripts/island/capital_models.gd")
const P := preload("res://scripts/island/capital_plan.gd")
const WALL := 0.6
const DOOR_W := 2.4
const DOOR_H := 3.6
const RISE := 0.6


## A hall's frame (+z toward its floor, the door in that face), its width (along x) and depth (along z).
static func frame(key: String, plan = null) -> Array:
	var sp: Array = (plan if plan else P).SPECIAL[key]
	var r: Rect2 = sp[0]
	var face: Vector2 = sp[1]
	var w := r.size.x if absf(face.y) > 0.5 else r.size.y
	var d := r.size.y if absf(face.y) > 0.5 else r.size.x
	return [M.xf(M.v3(r.get_center(), 0.0), M.yaw_of(face)), w, d]


## The ground at the door and the hall's floor over it.
static func ground(key: String, plan = null) -> float:
	var fr := frame(key, plan)
	var t: Transform3D = fr[0]
	var door := t * Vector3(0, 0, float(fr[2]) * 0.5 + 1.5)
	return (plan if plan else P).ground(Vector2(door.x, door.z))


## Where someone inside would stand (frame, on the floor).
static func inside(key: String, plan = null) -> Vector3:
	var fr := frame(key, plan)
	var ix := float(fr[1]) * 0.5 - WALL
	var iz := float(fr[2]) * 0.5 - WALL
	# (the library: an aisle between a shelf row and the tables; the theatre: the floor before the stage, under the rows)
	var q := Vector3(ix * 0.3, 0, iz * 0.25) if key == "library" else (Vector3(0, 0, iz * 0.4) if key == "doge" else Vector3(0, 0, -iz + 5.5 + 1.2))
	return (fr[0] as Transform3D) * Vector3(q.x, ground(key, plan) + RISE, q.z)


static func build(mb: MeshBuilder, cols: Array, key: String, h: float, plan = null) -> void:
	var fr := frame(key, plan)
	var t: Transform3D = fr[0]
	var w: float = fr[1]
	var d: float = fr[2]
	var gy := ground(key, plan)
	var fy := gy + RISE
	_shell(mb, cols, t, w, d, gy, fy, h, Color(0.98, 0.82, 0.78) if key == "doge" else Color(0.97, 0.94, 0.88))
	match key:
		"library":
			_library(mb, cols, t, w, d, fy, h)
		"theatre":
			_theatre(mb, cols, t, w, d, fy, h)
		"doge":
			_council(mb, cols, t, w, d, fy, h)


## Walls (facade out, plaster in, the front round its door), the plinth and floor, the ceiling, roof, steps, cornice.
static func _shell(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, gy: float, fy: float, h: float, col := Color(0.97, 0.94, 0.88)) -> void:
	var lime := M.mat("lime")
	var hw := w * 0.5
	var hd := d * 0.5
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, (gy - 2.0 + fy) * 0.5, 0)), Vector3(w + 0.4, fy - gy + 2.0, d + 0.4), 0.5, Color(0.9, 0.88, 0.84), true, false)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, (gy - 2.0 + fy) * 0.5, 0)), Vector3(w, fy - gy + 2.0, d))
	var fac := M.mat("facade_a")
	M.facade_quad(mb, fac, t * Vector3(hw, fy, -hd), t * Vector3(-hw, fy, -hd), h, (t.basis * Vector3.FORWARD).normalized(), col)
	M.facade_quad(mb, fac, t * Vector3(-hw, fy, -hd), t * Vector3(-hw, fy, hd), h, (t.basis * Vector3.LEFT).normalized(), col)
	M.facade_quad(mb, fac, t * Vector3(hw, fy, hd), t * Vector3(hw, fy, -hd), h, (t.basis * Vector3.RIGHT).normalized(), col)
	var out := (t.basis * Vector3.BACK).normalized()
	for sg in [[-hw, -DOOR_W * 0.5], [DOOR_W * 0.5, hw]]:
		var a: float = sg[0]
		var b: float = sg[1]
		mb.add_quad(lime, t * Vector3(a, fy, hd), t * Vector3(b, fy, hd), t * Vector3(b, fy + h, hd), t * Vector3(a, fy + h, hd),
			Vector2(0, h * 0.3), Vector2((b - a) * 0.3, h * 0.3), Vector2((b - a) * 0.3, 0), Vector2(0, 0), col * 0.98, out)
	mb.add_quad(lime, t * Vector3(-DOOR_W * 0.5, fy + DOOR_H, hd), t * Vector3(DOOR_W * 0.5, fy + DOOR_H, hd), t * Vector3(DOOR_W * 0.5, fy + h, hd), t * Vector3(-DOOR_W * 0.5, fy + h, hd),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), col * 0.98, out)
	# colliders: three walls whole, the front round the doorway
	var wy := fy + h * 0.5
	M.box(cols, t * Transform3D(Basis(), Vector3(0, wy, -hd + WALL * 0.5)), Vector3(w, h, WALL))
	for s in [-1.0, 1.0]:
		M.box(cols, t * Transform3D(Basis(), Vector3(s * (hw - WALL * 0.5), wy, 0)), Vector3(WALL, h, d))
	var pw := (w - DOOR_W) * 0.5
	for s in [-1.0, 1.0]:
		M.box(cols, t * Transform3D(Basis(), Vector3(s * (DOOR_W * 0.5 + pw * 0.5), wy, hd - WALL * 0.5)), Vector3(pw, h, WALL))
	M.box(cols, t * Transform3D(Basis(), Vector3(0, fy + DOOR_H + (h - DOOR_H) * 0.5, hd - WALL * 0.5)), Vector3(DOOR_W, h - DOOR_H, WALL))
	for s in [-1.0, 1.0]:
		Occluders.box(cols, t * Transform3D(Basis(), Vector3(s * (hw - WALL * 0.5), wy, 0)), Vector3(0.3, h - 1.0, d - 2.0))
	# inside: plaster walls, the floor, a beamed ceiling
	var plaster := PSXMat.lit("plaster_wash")
	var ix := hw - WALL
	var iz := hd - WALL
	var inner := Color(0.9, 0.86, 0.78)
	for wl in [[Vector3(ix, 0, -iz), Vector3(-ix, 0, -iz), Vector3.BACK], [Vector3(-ix, 0, -iz), Vector3(-ix, 0, iz), Vector3.RIGHT], [Vector3(ix, 0, iz), Vector3(ix, 0, -iz), Vector3.LEFT]]:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		mb.add_quad(plaster, t * (a + Vector3(0, fy, 0)), t * (b + Vector3(0, fy, 0)), t * (b + Vector3(0, fy + h, 0)), t * (a + Vector3(0, fy + h, 0)),
			Vector2(0, h * 0.4), Vector2(a.distance_to(b) * 0.4, h * 0.4), Vector2(a.distance_to(b) * 0.4, 0), Vector2(0, 0), inner, (t.basis * (wl[2] as Vector3)).normalized())
	for sg in [[-ix, -DOOR_W * 0.5], [DOOR_W * 0.5, ix]]:
		var a: float = sg[0]
		var b: float = sg[1]
		mb.add_quad(plaster, t * Vector3(b, fy, iz), t * Vector3(a, fy, iz), t * Vector3(a, fy + h, iz), t * Vector3(b, fy + h, iz),
			Vector2(0, h * 0.4), Vector2((b - a) * 0.4, h * 0.4), Vector2((b - a) * 0.4, 0), Vector2(0, 0), inner, (t.basis * Vector3.FORWARD).normalized())
	mb.add_quad(PSXMat.lit("planks"), t * Vector3(-ix, fy + 0.01, -iz), t * Vector3(ix, fy + 0.01, -iz), t * Vector3(ix, fy + 0.01, iz), t * Vector3(-ix, fy + 0.01, iz),
		Vector2(0, 0), Vector2(ix, 0), Vector2(ix, iz * 2.0), Vector2(0, iz * 2.0), Color(0.78, 0.66, 0.52), (t.basis * Vector3.UP).normalized())
	mb.add_quad(plaster, t * Vector3(-ix, fy + h - 0.05, iz), t * Vector3(ix, fy + h - 0.05, iz), t * Vector3(ix, fy + h - 0.05, -iz), t * Vector3(-ix, fy + h - 0.05, -iz),
		Vector2(0, 0), Vector2(ix * 0.4, 0), Vector2(ix * 0.4, iz * 0.8), Vector2(0, iz * 0.8), Color(0.72, 0.66, 0.58), (t.basis * Vector3.DOWN).normalized())
	var z := -iz + 1.5
	while z < iz:
		mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(0, fy + h - 0.25, z)), Vector3(ix * 2.0, 0.35, 0.3), 0.6, Color.WHITE, false)
		z += 2.4
	# the roof, its slab solid, the cornice; steps up to the door; a portico frame round it
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, fy + h + 0.15, 0)), Vector3(w + 0.5, 0.3, d + 0.5), 0.6, Color(0.9, 0.88, 0.84), false)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, fy + h + 0.15, 0)), Vector3(w, 0.3, d))
	M._hip(mb, t * Transform3D(Basis(), Vector3(0, fy + h + 0.3, 0)), w + 0.4, d + 0.4, minf(w, d) * M.ROOF_PITCH, 0.3, M.ROOFS[0])
	for k in range(2):
		var sy := gy + RISE * (k + 1) / 2.0
		var st := t * Transform3D(Basis(), Vector3(0, (sy + gy - 1.0) * 0.5, hd + 0.3 + (1 - k) * 0.4))
		mb.add_box(lime, st, Vector3(DOOR_W + 1.6, sy - gy + 1.0, 0.45), 0.6, Color(0.9, 0.88, 0.84))
		M.box(cols, st, Vector3(DOOR_W + 1.6, sy - gy + 1.0, 0.45))
	for s in [-1.0, 1.0]:
		mb.add_box(lime, t * Transform3D(Basis(), Vector3(s * (DOOR_W * 0.5 + 0.35), fy + DOOR_H * 0.5 + 0.3, hd + 0.18)), Vector3(0.5, DOOR_H + 0.6, 0.36), 0.6, Color(0.92, 0.9, 0.86))
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, fy + DOOR_H + 0.45, hd + 0.2)), Vector3(DOOR_W + 1.4, 0.5, 0.4), 0.6, Color(0.9, 0.88, 0.84))


## The library: two rows of tall shelves down the room, reading tables between, lamps; across the back a shelf wall with
## a narrow gap at one end into the hidden room behind it (a chest, a lamp, scrolls).
static func _library(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, fy: float, h: float) -> void:
	var wood := PSXMat.lit("planks_dark")
	var ix := w * 0.5 - WALL
	var iz := d * 0.5 - WALL
	var spines: Array = [Color(0.5, 0.18, 0.14), Color(0.16, 0.26, 0.46), Color(0.24, 0.38, 0.22), Color(0.58, 0.44, 0.2), Color(0.32, 0.2, 0.34)]
	var back := -iz + 3.2
	var rng := RandomNumberGenerator.new()
	rng.seed = 818181
	var shelf := func(c: Vector3, along_x: bool, length: float) -> void:
		var size := Vector3(length, 3.2, 0.6) if along_x else Vector3(0.6, 3.2, length)
		var st := t * Transform3D(Basis(), c + Vector3(0, 1.6, 0))
		mb.add_box(wood, st, size, 0.6, Color.WHITE)
		M.box(cols, st, size)
		for k in range(4):
			var n := int(length / 0.22)
			for i in range(n):
				if rng.randf() < 0.15:
					continue
				var o := -length * 0.5 + 0.11 + i * 0.22
				var bh := rng.randf_range(0.42, 0.58)
				for sd in [-1.0, 1.0]:
					var bp := Vector3(o, 0.15 + k * 0.78 + bh * 0.5, sd * 0.31) if along_x else Vector3(sd * 0.31, 0.15 + k * 0.78 + bh * 0.5, o)
					mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), c + bp), Vector3(0.18, bh, 0.04) if along_x else Vector3(0.04, bh, 0.18), 1.0, spines[rng.randi() % spines.size()], false)
	# the shelf wall across the back, with the gap at one end
	var gap := 0.9
	shelf.call(Vector3(-gap * 0.5, fy, back), true, ix * 2.0 - gap)
	# the hidden room behind it: a chest, a lamp, scrolls
	var chest_at := t * Transform3D(Basis(), Vector3(-ix * 0.4, fy, (-iz + back) * 0.5 - 0.3))
	var chest := MeshBuilder.from_mesh(Props.treasure_chest_mesh())
	chest.rebind(chest_at, 0)
	mb.merge(chest)
	M.box(cols, chest_at * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(1.0, 0.8, 0.7))
	mb.add_box(PSXMat.glow(Color(1.0, 0.75, 0.35), 2.0), t * Transform3D(Basis(), Vector3(ix * 0.4, fy + 1.2, -iz + 0.3)), Vector3(0.12, 0.18, 0.12), 1.0, Color.WHITE, false)
	for i in range(5):
		mb.add_cylinder(M.mat("cloth"), t * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(ix * 0.2 + i * 0.12, fy + 0.08, -iz + 0.8 + (i % 2) * 0.2)), 0.06, 0.06, 0.5, 6, 0.5, Color(0.92, 0.88, 0.76))
	# two rows of shelves down the room, reading tables between
	var row_x := ix * 0.55
	for s in [-1.0, 1.0]:
		shelf.call(Vector3(s * row_x, fy, (back + iz - 2.0) * 0.5 + 0.6), false, iz - back - 3.0)
	var z := back + 2.0
	while z < iz - 2.5:
		var tt := t * Transform3D(Basis(), Vector3(0, fy, z))
		mb.add_box(wood, tt * Transform3D(Basis(), Vector3(0, 0.78, 0)), Vector3(1.0, 0.06, 2.0), 0.6, Color.WHITE, false)
		mb.add_box(wood, tt * Transform3D(Basis(), Vector3(0, 0.38, 0)), Vector3(0.6, 0.76, 1.6), 0.6, Color.WHITE, false)
		M.box(cols, tt * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(1.0, 0.8, 2.0))
		mb.add_box(PSXMat.glow(Color(1.0, 0.8, 0.45), 1.8), tt * Transform3D(Basis(), Vector3(0, 0.95, 0.6)), Vector3(0.14, 0.24, 0.14), 1.0, Color.WHITE, false)
		mb.add_box(M.mat("cloth"), tt * Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 0.83, -0.3)), Vector3(0.4, 0.04, 0.3), 1.0, Color(0.92, 0.88, 0.76), false)
		z += 3.4


## The theatre: a raised stage across the back with its curtains, footlights along its edge, raked rows of seats down
## the room toward the door, a lamp hung over the house.
static func _theatre(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, fy: float, h: float) -> void:
	var wood := PSXMat.lit("planks_dark")
	var ix := w * 0.5 - WALL
	var iz := d * 0.5 - WALL
	var stage_d := 5.5
	var sz := -iz + stage_d * 0.5
	var st := t * Transform3D(Basis(), Vector3(0, fy + 0.6, sz))
	mb.add_box(PSXMat.lit("planks"), st, Vector3(ix * 2.0, 1.2, stage_d), 0.6, Color(0.82, 0.7, 0.56))
	M.box(cols, st, Vector3(ix * 2.0, 1.2, stage_d))
	# the proscenium: two piers and a beam, red curtains drawn back, a backdrop
	var red := Color(0.6, 0.1, 0.12)
	for s in [-1.0, 1.0]:
		mb.add_box(M.mat("lime"), t * Transform3D(Basis(), Vector3(s * (ix - 0.6), fy + h * 0.5, sz + stage_d * 0.5)), Vector3(1.2, h, 0.6), 0.6, Color(0.92, 0.9, 0.86))
		mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), Vector3(s * (ix - 1.8), fy + 1.2 + (h - 2.4) * 0.5, sz + stage_d * 0.5 - 0.4)), Vector3(1.4, h - 2.4, 0.15), 1.0, red, false)
	mb.add_box(M.mat("lime"), t * Transform3D(Basis(), Vector3(0, fy + h - 1.0, sz + stage_d * 0.5)), Vector3(ix * 2.0, 2.0, 0.6), 0.6, Color(0.92, 0.9, 0.86))
	mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), Vector3(0, fy + h - 2.3, sz + stage_d * 0.5 - 0.4)), Vector3(ix * 2.0 - 2.4, 0.8, 0.15), 1.0, red * 0.9, false)
	mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), Vector3(0, fy + 1.2 + (h - 2.4) * 0.5, -iz + 0.1)), Vector3(ix * 2.0, h - 2.4, 0.05), 1.0, Color(0.3, 0.42, 0.58), false)
	var foot := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.0)
	var x := -ix + 1.0
	while x < ix - 0.8:
		mb.add_box(foot, t * Transform3D(Basis(), Vector3(x, fy + 1.28, sz + stage_d * 0.5 - 0.2)), Vector3(0.18, 0.12, 0.12), 1.0, Color.WHITE, false)
		x += 1.2
	# the rows of seats, each a step higher toward the door
	var z := sz + stage_d * 0.5 + 2.5
	var row := 0
	while z < iz - 2.5:
		var ry := fy + row * 0.32
		var rt := t * Transform3D(Basis(), Vector3(0, ry, z))
		if row > 0:
			mb.add_box(wood, rt * Transform3D(Basis(), Vector3(0, -0.16, 0)), Vector3(ix * 2.0 - 2.4, 0.32, 1.1), 0.6, Color(0.8, 0.72, 0.62))
			M.box(cols, rt * Transform3D(Basis(), Vector3(0, -0.16, 0)), Vector3(ix * 2.0 - 2.4, 0.32, 1.1))
		for s in [-1.0, 1.0]:
			var bt := rt * Transform3D(Basis(), Vector3(s * (ix * 0.5 + 0.1), 0, 0))
			mb.add_box(M.mat("cloth"), bt * Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(ix - 1.6, 0.12, 0.5), 1.0, red, false)
			mb.add_box(M.mat("cloth"), bt * Transform3D(Basis(), Vector3(0, 0.75, 0.24)), Vector3(ix - 1.6, 0.6, 0.08), 1.0, red, false)
		z += 1.1
		row += 1
	mb.add_box(M.mat("iron"), t * Transform3D(Basis(), Vector3(0, fy + h - 1.0, iz * 0.3)), Vector3(0.05, 2.0, 0.05), 1.0, Color.WHITE, false)
	mb.add_cylinder(M.mat("gold"), t * Transform3D(Basis(), Vector3(0, fy + h - 2.2, iz * 0.3)), 1.1, 0.6, 0.4, 10)
	mb.add_box(foot, t * Transform3D(Basis(), Vector3(0, fy + h - 2.3, iz * 0.3)), Vector3(0.8, 0.1, 0.8), 1.0, Color.WHITE, false)


## The Doge's palace (the canal city): its council chamber. A dais across the back with the Doge's gilded chair under a
## canopy, a long table down each side with its benches, banners of the lagoon's colours on the walls, a lamp hung over
## the floor; crenels along the palace's top outside.
static func _council(mb: MeshBuilder, cols: Array, t: Transform3D, w: float, d: float, fy: float, h: float) -> void:
	var wood := PSXMat.lit("planks_dark")
	var lime := M.mat("lime")
	var gold := M.mat("gold")
	var ix := w * 0.5 - WALL
	var iz := d * 0.5 - WALL
	var dais := t * Transform3D(Basis(), Vector3(0, fy + 0.35, -iz + 2.2))
	mb.add_box(lime, dais, Vector3(ix * 2.0 - 2.0, 0.7, 4.4), 0.6, Color(0.9, 0.86, 0.8))
	M.box(cols, dais, Vector3(ix * 2.0 - 2.0, 0.7, 4.4))
	mb.add_box(M.mat("cloth"), dais * Transform3D(Basis(), Vector3(0, 0.36, 0.6)), Vector3(4.0, 0.02, 2.6), 1.0, Color(0.55, 0.1, 0.12), false)
	var ct := dais * Transform3D(Basis(), Vector3(0, 0.35, -0.9))
	mb.add_box(gold, ct * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(1.2, 0.12, 0.9), 1.0, Color.WHITE)
	mb.add_box(gold, ct * Transform3D(Basis(), Vector3(0, 1.4, -0.42)), Vector3(1.2, 1.8, 0.12), 1.0, Color.WHITE)
	for s in [-1.0, 1.0]:
		mb.add_box(gold, ct * Transform3D(Basis(), Vector3(s * 0.55, 0.75, 0)), Vector3(0.1, 0.5, 0.9), 1.0, Color.WHITE, false)
	M.box(cols, ct * Transform3D(Basis(), Vector3(0, 0.8, 0)), Vector3(1.2, 1.6, 0.9))
	# the canopy over the chair
	mb.add_box(M.mat("cloth"), ct * Transform3D(Basis(), Vector3(0, 3.4, 0.2)), Vector3(2.4, 0.08, 1.8), 1.0, Color(0.55, 0.1, 0.12), false)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(gold, ct * Transform3D(Basis(), Vector3(s * 1.1, 0, 0.95)), 0.06, 0.06, 3.4, 6)
	# the council tables down each side, benches along them
	for s in [-1.0, 1.0]:
		var tl := iz * 2.0 - 8.0
		var tt := t * Transform3D(Basis(), Vector3(s * (ix - 2.6), fy, 1.5))
		mb.add_box(wood, tt * Transform3D(Basis(), Vector3(0, 0.78, 0)), Vector3(1.4, 0.08, tl), 0.6, Color.WHITE)
		mb.add_box(wood, tt * Transform3D(Basis(), Vector3(0, 0.38, 0)), Vector3(0.8, 0.76, tl - 0.6), 0.6, Color.WHITE, false)
		M.box(cols, tt * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(1.4, 0.82, tl))
		for side in [-1.0, 1.0]:
			mb.add_box(wood, tt * Transform3D(Basis(), Vector3(side * 1.1, 0.45, 0)), Vector3(0.4, 0.08, tl - 0.4), 0.6, Color(0.9, 0.85, 0.8), false)
	# banners on the long walls, the lamp over the floor
	var banners: Array = [Color(0.55, 0.1, 0.12), Color(0.9, 0.72, 0.25)]
	var z := -iz + 6.0
	var i := 0
	while z < iz - 3.0:
		for s in [-1.0, 1.0]:
			mb.add_box(M.mat("cloth"), t * Transform3D(Basis(), Vector3(s * (ix - 0.06), fy + h * 0.55, z)), Vector3(0.04, 3.0, 1.2), 1.0, banners[i % 2], false)
			i += 1
		z += 5.0
	mb.add_box(M.mat("iron"), t * Transform3D(Basis(), Vector3(0, fy + h - 1.0, 0)), Vector3(0.05, 2.0, 0.05), 1.0, Color.WHITE, false)
	mb.add_cylinder(gold, t * Transform3D(Basis(), Vector3(0, fy + h - 2.2, 0)), 1.2, 0.6, 0.4, 10)
	mb.add_box(PSXMat.glow(Color(1.0, 0.78, 0.4), 2.0), t * Transform3D(Basis(), Vector3(0, fy + h - 2.3, 0)), Vector3(0.9, 0.1, 0.9), 1.0, Color.WHITE, false)
	# outside: an arcade along the front onto the piazza: columns, their arches, the walk's roof over them
	var ad := 2.6
	var ax := -w * 0.5 + 1.2
	while ax <= w * 0.5 - 1.0:
		if absf(ax) > DOOR_W * 0.5 + 0.6:
			var cq := Vector3(ax, fy, d * 0.5 + ad - 0.3)
			mb.add_cylinder(lime, t * Transform3D(Basis(), cq), 0.28, 0.24, 3.8, 8, 0.5, Color(0.96, 0.94, 0.9))
			mb.add_box(lime, t * Transform3D(Basis(), cq + Vector3(0, 3.95, 0)), Vector3(0.7, 0.3, 0.7), 0.6, Color(0.94, 0.92, 0.88), false)
			M.cyl(cols, t * cq, 0.28, 3.8)
		ax += 2.8
	var arc := t * Transform3D(Basis(), Vector3(0, fy + 4.1, d * 0.5 + ad * 0.5))
	mb.add_box(lime, arc, Vector3(w, 0.5, ad + 0.2), 0.6, Color(0.96, 0.88, 0.84))
	mb.add_box(M.mat("lime"), arc * Transform3D(Basis(), Vector3(0, 0.6, ad * 0.5 - 0.1)), Vector3(w, 0.7, 0.2), 0.6, Color(0.94, 0.84, 0.8), false)
	M.box(cols, arc, Vector3(w, 0.5, ad + 0.2))
	# outside: crenels along the top of every wall
	var x := -w * 0.5 + 0.5
	while x < w * 0.5:
		for s in [-1.0, 1.0]:
			mb.add_box(lime, t * Transform3D(Basis(), Vector3(x, fy + h + 0.9, s * (d * 0.5 - 0.2))), Vector3(0.6, 0.8, 0.4), 0.6, Color(0.96, 0.9, 0.86), false)
		x += 1.4
	z = -d * 0.5 + 0.5
	while z < d * 0.5:
		for s in [-1.0, 1.0]:
			mb.add_box(lime, t * Transform3D(Basis(), Vector3(s * (w * 0.5 - 0.2), fy + h + 0.9, z)), Vector3(0.4, 0.8, 0.6), 0.6, Color(0.96, 0.9, 0.86), false)
		z += 1.4


## The Doge's place on the dais (frame): where the Doge stands, facing the hall.
static func doge_spot(plan) -> Array:
	var fr := frame("doge", plan)
	var t: Transform3D = fr[0]
	var iz := float(fr[2]) * 0.5 - WALL
	var at: Vector3 = t * Vector3(0, ground("doge", plan) + RISE + 0.7, -iz + 3.2)
	var fwd: Vector3 = t.basis * Vector3(0, 0, 1)
	return [at, Vector2(fwd.x, fwd.z).normalized()]
