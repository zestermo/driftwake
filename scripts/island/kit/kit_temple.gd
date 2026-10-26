class_name KitTemple
extends RefCounted
## The ruined temple, a set piece rolled on some generated islands (KitDungeons):
## a stone platform half swallowed by the jungle, stairs up to a carved doorway
## flanked by guardian statues, and inside:
##   hall     - a hall of pillars, its roof fallen in at one end, bugs in the rubble
##   shrines  - one either side, each with a lever on its altar and raiders
##              who came for the treasure
##   sanctum  - behind a gate that sinks once both levers are pulled: the warden
##              and his guards, the hoard on the altar under the oculus
## Its own space: the hall's floor at the origin, +Z out through the door (toward
## the village give or take), +X to the east shrine.

const H := 6.5
const WT := 1.0
const GATE_W := 3.6
const GATE_H := 4.4
const GATE_SINK := 4.8
## Rooms [x0, x1, z0, z1].
const HALL := [-6.0, 6.0, -8.0, 8.0]
const SHRINE_W := [-14.0, -6.0, -4.0, 4.0]
const SHRINE_E := [6.0, 14.0, -4.0, 4.0]
const SANCTUM := [-7.0, 7.0, -22.0, -8.0]
## The platform [x0, x1, z0, z1] (its front is the porch the stairs come up to).
const PLINTH := [-16.0, 16.0, -24.0, 12.0]
const STAIR_W := 6.0
const LIGHTS := 4


static func local(room: Dictionary) -> Vector3:
	var r: Array = room["rect"]
	return Vector3((float(r[0]) + float(r[1])) * 0.5, 0.0, (float(r[2]) + float(r[3])) * 0.5)


static func door_local() -> Vector3:
	return Vector3(0.0, 0.0, HALL[3])


# ==========================================================================
# The plan (data, a worker thread)
# ==========================================================================
static func plan(isl: GenIsland, rng: RandomNumberGenerator, taken: Array) -> Dictionary:
	for relax in [1.0, 0.8, 0.62]:
		for attempt in range(40):
			var c := Vector2.from_angle(rng.randf() * TAU) * isl.radius * rng.randf_range(0.2, 0.68)
			if not KitDungeons.site_clear(isl, c, 36.0, relax, taken):
				continue
			var f: Vector2 = (isl.sites["village"] - c).normalized().rotated(rng.randf_range(-0.4, 0.4))
			var s := Vector2(f.y, -f.x)
			var hi := -INF
			var lo := INF
			var ok := true
			var x := float(PLINTH[0]) - 1.0
			while x <= float(PLINTH[1]) + 1.0 and ok:
				var z := float(PLINTH[2]) - 1.0
				while z <= float(PLINTH[3]) + 1.0:
					var q := c + s * x + f * z
					var h := isl.hv(q)
					if h < 1.5 or isl.path_dist(q) < 2.0 or isl.excluded(q, 0.5):
						ok = false
						break
					hi = maxf(hi, h)
					lo = minf(lo, h)
					z += 4.0
				x += 4.0
			if not ok or hi - lo > 5.0:
				continue
			var floor_y := hi + 0.5
			var length := 3.0
			for k in range(3):
				length = clampf((floor_y - isl.hv(c + f * (float(PLINTH[3]) + length))) / 0.55, 2.5, 11.0)
			var foot := c + f * (float(PLINTH[3]) + length)
			var front_drop := floor_y - isl.hv(foot)
			if isl.hv(foot) < 1.2 or front_drop / length > 0.62 or front_drop < 0.2:
				continue
			return _finish(isl, rng, c, f, floor_y, lo, length, foot, taken.size())
	return {}


static func _finish(isl: GenIsland, rng: RandomNumberGenerator, c: Vector2, f: Vector2, floor_y: float, lo: float, length: float, foot: Vector2, idx: int) -> Dictionary:
	var s := Vector2(f.y, -f.x)
	var rooms: Array = []
	for e in [["hall", HALL], ["shrine_w", SHRINE_W], ["shrine_e", SHRINE_E], ["sanctum", SANCTUM]]:
		var r: Array = e[1]
		var mid := Vector2((float(r[0]) + float(r[1])) * 0.5, (float(r[2]) + float(r[3])) * 0.5)
		# free floor slots for creatures placed later: the room's quarter points
		var slots: Array = []
		for q in [Vector2(0.27, 0.3), Vector2(0.73, 0.3), Vector2(0.27, 0.7), Vector2(0.73, 0.7)]:
			var lp := Vector2(lerpf(r[0], r[1], q.x), lerpf(r[2], r[3], q.y))
			var ip := c + s * lp.x + f * lp.y
			slots.append(Vector3(ip.x, floor_y, ip.y))
		rooms.append({"role": e[0], "rect": r, "c": c + s * mid.x + f * mid.y, "y": floor_y,
			"r": minf(float(r[1]) - float(r[0]), float(r[3]) - float(r[2])) * 0.5, "h": H, "slots": {"floor": slots, "roof": []}})
	# kept clear: the platform, the stairs and a forecourt in front of them
	var z := float(PLINTH[2])
	while z <= float(PLINTH[3]) + length + 8.0:
		var x := float(PLINTH[0])
		while x <= float(PLINTH[1]):
			isl.reserve(c + s * x + f * z, 4.0)
			x += 5.0
		z += 5.0
	KitDungeons.path_to(isl, rng, foot + f * 2.0)
	var pick: Array = KitDungeons.TITLES["temple"][rng.randi() % KitDungeons.TITLES["temple"].size()]
	var name := "Temple%d" % idx
	var corner := Vector2(PLINTH[1], PLINTH[2]).length()
	var bs := c - f * 14.5
	return {"kind": "temple", "name": name, "title": pick[0], "subtitle": pick[1], "at": c, "radius": corner + 2.0,
		"boss": "captain", "boss_slot": Vector3(bs.x, floor_y, bs.y),
		"mouth": foot, "mouth_dir": f, "mouth_y": isl.hv(foot), "floor_y": floor_y, "base": lo - 0.6 - floor_y,
		"stair_len": length, "rooms": rooms, "seed": rng.randi(), "level": int(isl.node["level"]),
		"reward": isl.save_key(name.to_lower() + "_hoard"), "flag": isl.save_key(name.to_lower() + "_cleared")}


# ==========================================================================
# The stone (main thread)
# ==========================================================================
static func _box(mb: MeshBuilder, mat: Material, at: Vector3, size: Vector3, body: StaticBody3D = null, col := Color.WHITE, uv := 0.5) -> void:
	mb.add_box(mat, Transform3D(Basis(), at), size, uv, col, true, false)
	if body:
		KitLandmarks.box_col(body, size, at)


## A wall from a to b (axis-aligned, on the floor), a doorway `gap` wide in its
## middle (0: none) up to `gap_h`, a lintel over it; a footing course and a cap.
static func _wall(mb: MeshBuilder, mat: Material, body: StaticBody3D, a: Vector2, b: Vector2, gap: float, gap_h: float, col: Color) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var at := a.y if along_x else a.x
	var mid := (lo + hi) * 0.5
	var runs: Array = [[lo, hi]] if gap <= 0.0 else [[lo, mid - gap * 0.5], [mid + gap * 0.5, hi]]
	var put := func(u0: float, u1: float, y0: float, y1: float, thick: float, collide: bool) -> void:
		var c := Vector3((u0 + u1) * 0.5, (y0 + y1) * 0.5, at) if along_x else Vector3(at, (y0 + y1) * 0.5, (u0 + u1) * 0.5)
		var size := Vector3(u1 - u0, y1 - y0, thick) if along_x else Vector3(thick, y1 - y0, u1 - u0)
		_box(mb, mat, c, size, body if collide else null, col)
	for r in runs:
		put.call(r[0], r[1], 0.0, H, WT, true)
		put.call(r[0], r[1], 0.0, 0.45, WT + 0.25, false)
	put.call(lo - 0.15, hi + 0.15, H - 0.35, H + 0.05, WT + 0.3, false)
	if gap > 0.0:
		put.call(mid - gap * 0.5, mid + gap * 0.5, gap_h, H, WT, true)
		put.call(mid - gap * 0.5 - 0.3, mid + gap * 0.5 + 0.3, gap_h - 0.35, gap_h, WT + 0.2, false)


static func build(isl: GenIsland, e: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e["seed"]) + 101
	var d := Dungeon.new()
	d.name = e["name"]
	d.isl = isl
	d.info = e
	var f: Vector2 = e["mouth_dir"]
	d.position = Vector3(e["at"].x, e["floor_y"], e["at"].y)
	d.rotation.y = atan2(f.x, f.y)
	var stone := PSXMat.lit("stone_brick", Color(0.72, 0.78, 0.7))
	var moss := PSXMat.lit("stone_brick", Color(0.56, 0.7, 0.5))
	var floor_m := PSXMat.lit("cobbles", Color(0.62, 0.66, 0.6))
	var carved := PSXMat.lit("driftstone", Color(0.8, 0.86, 0.8), {"emission_tex": "driftstone_glow", "emission": Color(0.4, 0.95, 0.9), "emission_energy": 1.4})
	var body := StaticBody3D.new()
	body.name = "Stone"
	body.collision_layer = 1
	body.collision_mask = 0
	isl._unparented.append_array([d, body])
	var mb := MeshBuilder.new()
	var base: float = e["base"]
	# the platform, a step round its foot, the stairs up to the porch
	var px0: float = PLINTH[0]
	var px1: float = PLINTH[1]
	var pz0: float = PLINTH[2]
	var pz1: float = PLINTH[3]
	_box(mb, moss, Vector3((px0 + px1) * 0.5, base * 0.5, (pz0 + pz1) * 0.5), Vector3(px1 - px0, -base, pz1 - pz0), body)
	_box(mb, floor_m, Vector3((px0 + px1) * 0.5, 0.01, (pz0 + pz1) * 0.5), Vector3(px1 - px0 - 0.1, 0.02, pz1 - pz0 - 0.1))
	if base < -1.2:
		_box(mb, moss, Vector3((px0 + px1) * 0.5, base * 0.5 - 0.5, (pz0 + pz1) * 0.5), Vector3(px1 - px0 + 2.0, -base - 1.0, pz1 - pz0 + 2.0), null, Color.WHITE * 0.85)
	var length: float = e["stair_len"]
	var drop: float = float(e["floor_y"]) - float(e["mouth_y"])
	var n := maxi(2, ceili(drop / 0.3))
	for k in range(n):
		var y_top := -drop * (k + 1) / n
		var z0 := pz1 + length * k / n
		_box(mb, stone, Vector3(0.0, (y_top + base - 0.5) * 0.5, (z0 + pz1 + length) * 0.5), Vector3(STAIR_W, y_top - base + 0.5, pz1 + length - z0), null, Color.WHITE * (0.92 + 0.08 * (k % 2)))
	for sx in [-1.0, 1.0]:
		_box(mb, moss, Vector3(sx * (STAIR_W * 0.5 + 0.4), (base - 0.2) * 0.5 + 0.3, pz1 + length * 0.5), Vector3(0.8, -base + 0.6, length), body)
	var ramp := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	var slope := Vector2(length, drop)
	rs.size = Vector3(STAIR_W, 0.4, slope.length())
	ramp.shape = rs
	ramp.position = Vector3(0.0, -drop * 0.5 - 0.2, pz1 + length * 0.5)
	ramp.rotation.x = atan2(drop, length)
	body.add_child(ramp)
	# walls with their doorways
	var wc := Color(0.95, 0.95, 0.95)
	_wall(mb, stone, body, Vector2(HALL[0], HALL[3]), Vector2(HALL[1], HALL[3]), 3.2, 4.4, wc)
	_wall(mb, stone, body, Vector2(HALL[0], HALL[2]), Vector2(HALL[0], HALL[3]), 2.8, 3.6, wc)
	_wall(mb, stone, body, Vector2(HALL[1], HALL[2]), Vector2(HALL[1], HALL[3]), 2.8, 3.6, wc)
	_wall(mb, stone, body, Vector2(SANCTUM[0], SANCTUM[3]), Vector2(SANCTUM[1], SANCTUM[3]), GATE_W, GATE_H, wc)
	for sh in [SHRINE_W, SHRINE_E]:
		var outer_x: float = sh[0] if float(sh[0]) < 0.0 else sh[1]
		var inner_x: float = sh[1] if float(sh[0]) < 0.0 else sh[0]
		_wall(mb, stone, body, Vector2(outer_x, sh[2]), Vector2(outer_x, sh[3]), 0.0, 0.0, wc)
		_wall(mb, stone, body, Vector2(outer_x, sh[2]), Vector2(inner_x, sh[2]), 0.0, 0.0, wc)
		_wall(mb, stone, body, Vector2(outer_x, sh[3]), Vector2(inner_x, sh[3]), 0.0, 0.0, wc)
	_wall(mb, stone, body, Vector2(SANCTUM[0], SANCTUM[2]), Vector2(SANCTUM[0], SANCTUM[3]), 0.0, 0.0, wc)
	_wall(mb, stone, body, Vector2(SANCTUM[1], SANCTUM[2]), Vector2(SANCTUM[1], SANCTUM[3]), 0.0, 0.0, wc)
	_wall(mb, stone, body, Vector2(SANCTUM[0], SANCTUM[2]), Vector2(SANCTUM[1], SANCTUM[2]), 0.0, 0.0, wc)
	await GenIsland.breathe()
	# roofs of slabs: fallen in over the hall's back, an oculus over the sanctum's altar
	var holes := {}
	var hx := rng.randi_range(-3, 1)
	for k in range(3):
		holes[Vector2i(hx + k % 2, -3 - k / 2)] = true
	holes[Vector2i(-1, -9)] = true
	holes[Vector2i(0, -9)] = true
	for r in [HALL, SHRINE_W, SHRINE_E, SANCTUM]:
		_roof(mb, moss, body, r, holes)
		await GenIsland.breathe()
	# a stepped crown over the sanctum and a lower one over the hall, the temple's silhouette
	for t in range(3):
		var inset := 1.0 + t * 1.6
		_box(mb, moss if t == 0 else stone, Vector3(0.0, H + 0.7 + t * 1.3 + 0.65, (SANCTUM[2] + SANCTUM[3]) * 0.5), Vector3(SANCTUM[1] - SANCTUM[0] + 2.0 - inset * 2.0, 1.3, SANCTUM[3] - SANCTUM[2] + 2.0 - inset * 2.0) - Vector3(0, 0, 0), null, Color.WHITE * (0.9 + 0.05 * t))
	_box(mb, stone, Vector3(0.0, H + 0.7 + 3.9 + 1.2, (SANCTUM[2] + SANCTUM[3]) * 0.5), Vector3(3.2, 2.4, 3.2))
	_box(mb, carved, Vector3(0.0, H + 0.7 + 3.9 + 1.2, (SANCTUM[2] + SANCTUM[3]) * 0.5 + 1.61), Vector3(1.6, 1.4, 0.02))
	_box(mb, moss, Vector3(0.0, H + 0.7 + 0.5, 0.0), Vector3(HALL[1] - HALL[0] + 0.6, 1.0, HALL[3] - HALL[2] - 2.0) - Vector3(0, 0, 0))
	# the doorway: a carved panel over it, guardian statues either side of the porch
	_box(mb, carved, Vector3(0.0, 5.45, HALL[3] + WT * 0.5 + 0.02), Vector3(3.6, 1.6, 0.04))
	for sx in [-1.0, 1.0]:
		_guardian(mb, stone, carved, Vector3(sx * 4.2, 0.0, pz1 - 1.6), body)
	await GenIsland.breathe()
	_hall(mb, stone, moss, carved, body, rng)
	await GenIsland.breathe()
	_shrines(d, mb, stone, carved, body, rng)
	await GenIsland.breathe()
	_sanctum(d, mb, stone, carved, body, rng)
	await GenIsland.breathe()
	_vines(mb, rng, pz1)
	await GenIsland.breathe()
	var mesh := mb.to_instance("Masonry")
	body.add_child(mesh)
	d.add_child(body)
	isl.add_child(d)
	_lights(isl, e, d)


## Slab roof tiles 2 m square over a room (skipping `holes`), colliders in runs along x.
static func _roof(mb: MeshBuilder, mat: Material, body: StaticBody3D, r: Array, holes: Dictionary) -> void:
	var x0: float = float(r[0]) - WT * 0.5
	var x1: float = float(r[1]) + WT * 0.5
	var z0: float = float(r[2]) - WT * 0.5
	var z1: float = float(r[3]) + WT * 0.5
	var z := z0
	while z < z1 - 0.01:
		var zt := minf(z + 2.0, z1)
		var run_start := INF
		var x := x0
		while x < x1 + 0.01:
			var xt := minf(x + 2.0, x1)
			var key := Vector2i(floori(x / 2.0), floori(z / 2.0))
			var solid := x < x1 - 0.01 and not holes.has(key)
			if solid:
				mb.add_box(mat, Transform3D(Basis(), Vector3((x + xt) * 0.5, H + 0.35, (z + zt) * 0.5)), Vector3(xt - x - 0.04, 0.7, zt - z - 0.04), 0.5,
					Color.WHITE * (0.85 + 0.15 * float((key.x + key.y) % 2)), false, false)
				if run_start == INF:
					run_start = x
			elif run_start != INF:
				KitLandmarks.box_col(body, Vector3(x - run_start, 0.7, zt - z), Vector3((run_start + x) * 0.5, H + 0.35, (z + zt) * 0.5))
				run_start = INF
			x = xt if x < x1 - 0.01 else x1 + 1.0
		z = zt


## A blocky stone guardian on a plinth, glowing eyes, a spear held upright.
static func _guardian(mb: MeshBuilder, stone: Material, glow: Material, p: Vector3, body: StaticBody3D) -> void:
	_box(mb, stone, p + Vector3(0, 0.5, 0), Vector3(1.6, 1.0, 1.6), body)
	_box(mb, stone, p + Vector3(0, 1.75, 0), Vector3(1.1, 1.5, 0.8), null, Color.WHITE * 0.9)
	_box(mb, stone, p + Vector3(0, 3.0, 0), Vector3(1.4, 1.0, 0.95))
	_box(mb, stone, p + Vector3(0, 3.85, 0.05), Vector3(0.8, 0.75, 0.75), null, Color.WHITE * 0.95)
	_box(mb, stone, p + Vector3(0, 4.35, 0.0), Vector3(1.1, 0.25, 0.9))
	for s in [-1.0, 1.0]:
		_box(mb, glow, p + Vector3(s * 0.17, 3.92, 0.43), Vector3(0.12, 0.08, 0.02))
	_box(mb, stone, p + Vector3(0.75, 2.6, 0.35), Vector3(0.18, 4.4, 0.18))
	_box(mb, stone, p + Vector3(0.75, 4.95, 0.35), Vector3(0.36, 0.6, 0.12))
	KitLandmarks.box_col(body, Vector3(1.4, 3.8, 1.0), p + Vector3(0, 2.9, 0))


static func _pillar(mb: MeshBuilder, stone: Material, p: Vector3, h: float, body: StaticBody3D) -> void:
	_box(mb, stone, p + Vector3(0, 0.2, 0), Vector3(1.3, 0.4, 1.3))
	_box(mb, stone, p + Vector3(0, h * 0.5, 0), Vector3(0.9, h, 0.9), null, Color.WHITE * 0.92)
	if h > H - 0.5:
		_box(mb, stone, p + Vector3(0, h - 0.25, 0), Vector3(1.3, 0.5, 1.3))
	KitLandmarks.box_col(body, Vector3(1.0, h, 1.0), p + Vector3(0, h * 0.5, 0))


static func _brazier(mb: MeshBuilder, p: Vector3) -> void:
	var metal := PSXMat.lit("metal", Color(0.42, 0.4, 0.38))
	var coal := PSXMat.glow(Color(1.0, 0.5, 0.2), 2.6)
	mb.add_cylinder(metal, Transform3D(Basis(), p), 0.18, 0.12, 0.9, 6, 1.0)
	mb.add_cylinder(metal, Transform3D(Basis(), p + Vector3.UP * 0.9), 0.25, 0.5, 0.35, 8, 1.0)
	mb.add_cylinder(coal, Transform3D(Basis(), p + Vector3.UP * 1.2), 0.42, 0.3, 0.08, 8, 1.0, Color.WHITE, false, true)


static func _hall(mb: MeshBuilder, stone: Material, moss: Material, carved: Material, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var broken := [rng.randi() % 8, (rng.randi() % 7 + 1 + 0) % 8]
	var i := 0
	for z in [-5.0, -1.5, 2.0, 5.5]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * 3.4, 0.0, z)
			if i in broken:
				var h := rng.randf_range(1.6, 3.2)
				_pillar(mb, stone, p, h, body)
				var a := rng.randf() * TAU
				mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, PI * 0.5), p + Vector3(cos(a) * 1.8, 0.45, sin(a) * 1.8)), 0.45, 0.45, 1.2, 6, 0.5)
			else:
				_pillar(mb, stone, p, H, body)
			i += 1
	for sx in [-1.0, 1.0]:
		for z in [6.6, -6.6]:
			_brazier(mb, Vector3(sx * 4.7, 0.0, z))
	# under the fallen roof: slabs, rubble and the jungle getting in
	var rock := PSXMat.lit("rock", Color(0.6, 0.6, 0.55), {"affine": 0.6})
	var leaf := PSXMat.lit("leaves", Color(0.6, 0.85, 0.5))
	for k in range(9):
		var p := Vector3(rng.randf_range(-4.5, 1.5), 0.2, rng.randf_range(-7.0, -3.0))
		if k % 3 == 0:
			mb.add_box(moss, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), p + Vector3.UP * 0.1), Vector3(1.9, 0.6, 1.9), 0.5)
		else:
			mb.add_blob(rock, Transform3D(Basis(), p), Vector3.ONE * rng.randf_range(0.4, 0.9), rng, 0.3, 3, 6)
	for k in range(10):
		var top := Vector3(rng.randf_range(-4.0, 1.0), H + 0.6, rng.randf_range(-6.5, -3.5))
		var l := rng.randf_range(1.5, 4.5)
		var pts := MeshBuilder.curve_points(top, top + Vector3(rng.randf_range(-0.4, 0.4), -l * 0.5, rng.randf_range(-0.4, 0.4)), top + Vector3.DOWN * l, 6)
		mb.add_tube(leaf, pts, 0.04, 0.025, 4, 2.0)
	# carved panels on the hall's walls
	for sx in [-1.0, 1.0]:
		for z in [-5.0, 4.5]:
			_box(mb, carved, Vector3(sx * (HALL[1] - WT * 0.5 - 0.02), 2.4, z), Vector3(0.04, 1.8, 1.4))


static func _shrines(d: Dungeon, mb: MeshBuilder, stone: Material, carved: Material, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var metal := PSXMat.lit("metal", Color(0.4, 0.4, 0.44))
	var wax := PSXMat.lit("", Color(0.92, 0.88, 0.75))
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0)
	var i := 0
	for sh in [SHRINE_W, SHRINE_E]:
		var sx := -1.0 if float(sh[0]) < 0.0 else 1.0
		var back: float = float(sh[0]) + WT * 0.5 + 0.9 if sx < 0.0 else float(sh[1]) - WT * 0.5 - 0.9
		# the altar against the back wall, the lever on it, an idol above
		_box(mb, stone, Vector3(back, 0.5, 0.0), Vector3(1.6, 1.0, 2.6), body)
		_box(mb, carved, Vector3(back + sx * 0.75, 3.0, 0.0), Vector3(0.04, 2.2, 1.6))
		_box(mb, stone, Vector3(back + sx * 0.3, 1.6, 0.9), Vector3(0.7, 1.2, 0.6), null, Color.WHITE * 0.9)
		_box(mb, stone, Vector3(back + sx * 0.3, 1.6, -0.9), Vector3(0.7, 1.2, 0.6), null, Color.WHITE * 0.9)
		for k in range(6):
			var q := Vector3(back + rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-1.1, 1.1))
			if absf(q.z) < 0.5:
				continue
			var h := rng.randf_range(0.1, 0.25)
			mb.add_cylinder(wax, Transform3D(Basis(), q), 0.04, 0.04, h, 5, 1.0)
			mb.add_box(flame, Transform3D(Basis(), q + Vector3.UP * (h + 0.04)), Vector3(0.04, 0.07, 0.04), 1.0)
		var lever := Node3D.new()
		lever.name = "Lever%d" % i
		lever.position = Vector3(back - sx * 0.2, 1.0, 0.0)
		lever.rotation.y = -sx * PI * 0.5
		var lb := MeshBuilder.new()
		lb.add_box(metal, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.6, 0.2, 0.4), 1.0)
		lever.add_child(lb.to_instance("Base"))
		var handle := Node3D.new()
		handle.name = "Handle"
		handle.position = Vector3(0, 0.15, 0)
		handle.rotation.x = -0.6
		var hb := MeshBuilder.new()
		hb.add_box(metal, Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(0.08, 0.8, 0.08), 1.0)
		hb.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(0.14, 0.2, 0.14), 1.0)
		handle.add_child(hb.to_instance("Grip"))
		lever.add_child(handle)
		var area := Interactable.new()
		area.name = "Lever"
		area.collision_layer = 512
		area.collision_mask = 0
		area.prompt_text = "Pull the lever"
		area.gesture = "lever"
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.4
		cs.shape = sph
		area.add_child(cs)
		lever.add_child(area)
		var idx := i
		area.interacted.connect(func(_p: Player): d.net_pull(idx))
		d.add_child(lever)
		d.levers.append(lever)
		i += 1


static func _sanctum(d: Dungeon, mb: MeshBuilder, stone: Material, carved: Material, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	# the gate: bronze bars in the doorway, sinking into the floor when it opens
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.position = Vector3(0.0, 0.0, SANCTUM[3])
	var gb := MeshBuilder.new()
	var bronze := PSXMat.lit("metal", Color(0.62, 0.5, 0.32))
	for k in range(7):
		gb.add_box(bronze, Transform3D(Basis(), Vector3(-GATE_W * 0.5 + 0.25 + k * (GATE_W - 0.5) / 6.0, GATE_H * 0.5, 0)), Vector3(0.12, GATE_H, 0.12), 1.0)
	for y in [0.6, GATE_H * 0.5, GATE_H - 0.3]:
		gb.add_box(bronze, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(GATE_W, 0.14, 0.16), 1.0)
	gate.add_child(gb.to_instance("Bars"))
	var gbody := StaticBody3D.new()
	gbody.name = "GateBody"
	gbody.collision_layer = 1
	gbody.collision_mask = 0
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(GATE_W, GATE_H, 0.4)
	gcs.shape = gshape
	gcs.position = Vector3(0, GATE_H * 0.5, 0)
	gbody.add_child(gcs)
	gate.add_child(gbody)
	d.add_child(gate)
	d.gate = gate
	d.gate_col = gcs
	# the altar under the oculus, a statue either side, carvings, braziers
	var alt := Vector3(0.0, 0.0, -18.0)
	_box(mb, stone, alt + Vector3(0, 0.2, 0), Vector3(6.0, 0.4, 4.4), body)
	_box(mb, stone, alt + Vector3(0, 0.5, 0), Vector3(4.2, 0.6, 3.0), body)
	_box(mb, carved, alt + Vector3(0, 0.5, 1.51), Vector3(3.0, 0.4, 0.02))
	for sx in [-1.0, 1.0]:
		_guardian(mb, stone, carved, Vector3(sx * 4.6, 0.0, -20.0), body)
		_brazier(mb, Vector3(sx * 3.2, 0.0, -11.0))
		for z in [-12.5, -17.0]:
			_box(mb, carved, Vector3(sx * (SANCTUM[1] - WT * 0.5 - 0.02), 2.6, z), Vector3(0.04, 2.2, 1.6))
	var rock := PSXMat.lit("rock", Color(0.6, 0.6, 0.55), {"affine": 0.6})
	for k in range(8):
		var a := rng.randf() * TAU
		mb.add_blob(rock, Transform3D(Basis(), Vector3(cos(a) * 6.0, 0.15, -15.0 + sin(a) * 6.0)), Vector3.ONE * rng.randf_range(0.3, 0.6), rng, 0.3, 3, 5)


## Vines down the front and the corners.
static func _vines(mb: MeshBuilder, rng: RandomNumberGenerator, pz1: float) -> void:
	var vine := PSXMat.lit("leaves", Color(0.5, 0.78, 0.42))
	var leaf := PSXMat.lit("leaves", Color(0.68, 0.94, 0.58))
	var tops: Array = []
	for k in range(14):
		tops.append(Vector3(rng.randf_range(HALL[0] - 0.4, HALL[1] + 0.4), H + 0.7, HALL[3] + WT * 0.5 + 0.1))
	for c in [Vector3(SHRINE_W[0] - 0.6, H + 0.7, SHRINE_W[3]), Vector3(SHRINE_E[1] + 0.6, H + 0.7, SHRINE_E[3]),
			Vector3(SANCTUM[0] - 0.6, H + 0.7, SANCTUM[2] + 3.0), Vector3(SANCTUM[1] + 0.6, H + 0.7, SANCTUM[2] + 5.0)]:
		for k in range(4):
			tops.append(c + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-1.5, 1.5)))
	for top in tops:
		var t3: Vector3 = top
		if absf(t3.x) < 2.0 and t3.z > HALL[3]:
			t3.x += 2.5 * signf(t3.x + 0.01)
		var l := rng.randf_range(1.5, H - 0.5)
		var out := Vector3(0, 0, 0.25) if t3.z > HALL[3] else Vector3(signf(t3.x) * 0.25, 0, 0)
		var pts := MeshBuilder.curve_points(t3, t3 + out + Vector3.DOWN * l * 0.5, t3 + Vector3.DOWN * l + out * 0.4, 6)
		mb.add_tube(vine, pts, 0.04, 0.025, 4, 2.0)
		for q in range(3):
			mb.add_blob(leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pts[rng.randi_range(1, 6)]), Vector3(0.2, 0.12, 0.15), rng, 0.3, 2, 5, 1.0)


static func _lights(isl: GenIsland, e: Dictionary, d: Dungeon) -> void:
	var ctx := KitContext.make(isl, int(e["seed"]), isl.theme, LIGHTS, isl.build_ms)
	for at in [Vector3(0, 3.2, -15.0), Vector3(0, 3.0, 0.0), Vector3(-10.0, 2.6, 0.0), Vector3(10.0, 2.6, 0.0)]:
		if not ctx.take_light():
			break
		var l := OmniLight3D.new()
		l.name = "TempleLight"
		l.position = at
		l.light_color = Color(1.0, 0.68, 0.38)
		l.light_energy = 1.2
		l.omni_range = 11.0 if at.z != 0.0 or at.x == 0.0 else 7.0
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 50.0
		l.distance_fade_length = 15.0
		d.add_child(l)
		d.lights.append(l)


# ==========================================================================
# Who's inside, and the hoard
# ==========================================================================
static func populate(isl: GenIsland, e: Dictionary) -> void:
	var d: Dungeon = isl.get_node(str(e["name"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e["seed"]) + 202
	var lv: int = e["level"]
	var t := Levels.tier(lv)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	d.add_child(enemies)
	d.enemies = enemies
	var bugs := ScuttlebugNest.new()
	bugs.name = "Bugs"
	bugs.level = lv
	bugs.respawn_time = 90.0
	for k in range(4):
		bugs.add_spot(Vector3(rng.randf_range(-2.0, 2.0), 0.0, -6.0 + k * 3.6), k == 1)
	enemies.add_child(bugs)
	var raiders := KitDungeons._crew(e, rng, "Raiders", lv)
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * 10.0, 0.0, 0.0)
		raiders.add_grunt({"post": c + Vector3(sx * 0.5, 0, 2.0), "yaw": atan2(sx, 0.0), "mode": "stand", "seed": rng.randi() % 100000})
		raiders.add_grunt({"post": c + Vector3(-sx * 1.5, 0, -2.2), "yaw": atan2(sx, 0.0), "mode": "stand", "seed": rng.randi() % 100000, "role": "rifle"})
	enemies.add_child(raiders)
	var wardens := KitDungeons._crew(e, rng, "Wardens", lv + 1)
	var lk := PirateGrunt.crew_look(rng)
	var C := CharacterLook.CLOTH
	var nm: String = IslandContent.FIRST[rng.randi() % IslandContent.FIRST.size()]
	lk.merge({"name": nm, "build": "broad", "height": 1.15, "hat": "bandana", "hat_color": C[rng.randi() % C.size()], "coat": "captain",
		"coat_color": C[rng.randi() % C.size()], "trim_color": CharacterLook.TRIM[0], "marks": "scar", "pauldron": true}, true)
	wardens.add_grunt({"post": Vector3(0, 0, -14.5), "yaw": 0.0, "mode": "stand", "seed": rng.randi() % 100000,
		"look": lk, "captain": true, "title": "Warden %s" % nm})
	wardens.add_grunt({"post": Vector3(-3.0, 0, -12.5), "yaw": 0.0, "mode": "stand", "seed": rng.randi() % 100000})
	wardens.add_grunt({"post": Vector3(3.0, 0, -16.0), "yaw": 0.0, "mode": "stand", "seed": rng.randi() % 100000, "role": "rifle"})
	enemies.add_child(wardens)
	d.setup_captain(wardens)
	# the hoard on the altar
	var p := Vector3(0.0, 0.8, -18.0)
	var g := isl.to_local(d.to_global(p))
	var key: String = e["reward"]
	var bag := isl.strongbox(d, Vector2(g.x, g.z), d.rotation.y + PI, key.trim_prefix("isle%d_" % int(isl.node["id"])), [
		["gold", 70 + t * 25], ["treasure", 5 + t], ["rum", 2],
		[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], mini(t + 1, 5)), 1],
		[Gear.make("accessory", "pauldron", {"pauldron": true}, "Temple Warden's Pauldron", mini(t + 1, 5)), 1]], 1.5, g.y - isl.hv(Vector2(g.x, g.z)))
	bag.name = "Hoard"
	d._apply_gate(false)
	var baker := isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(d, float(e["radius"]) + 4.0, false, isl.terrain_faces)
