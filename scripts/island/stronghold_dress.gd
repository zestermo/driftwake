class_name StrongholdDress
extends RefCounted
## The stronghold's set dressing (1.30 round 7, docs/v1_30_plan.md: Marineford / Enies Lobby, "much more detail and more
## models, lived in"): what the shell's districts are for, on its existing shapes. Built on the worker in prepare after
## StrongholdShell, in its frame:
##   pieces  one merged mesh per district's dressing (CapitalShell._piece: colliders on what a captain walks into)
##   props   the repeated things as MultiMeshes, one per district and kind (StrongholdIsland makes the nodes): cannons,
##           crates, barrels, kegs, shot stacks, sandbags, racks, lamps, braziers, flags, bollards, tents, carts, boards
## Everything keeps clear of the run's anchors (clear_at(): posts, patrols, bells, doors, winch, lever, ledges, the perch,
## the locks, the hoists, the arenas, the ways and the berth).

const P := preload("res://scripts/island/stronghold_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const S := preload("res://scripts/island/stronghold_shell.gd")
const RANGE := 260.0
const PROP_RANGE := 170.0

## [kind -> Array of [district, Transform3D]] from the last build.
static var _placed: Dictionary = {}
static var _cols: Array = []
static var _anchors: Array = []


static func build(build_ms: Dictionary) -> Dictionary:
	var out: Array = []
	_placed = {}
	_anchors = _anchor_list()
	for step in [["dress landing", _landing], ["dress foundry", _foundry], ["dress prison", _prison], ["dress keep", _keep],
			["dress halls", _halls], ["dress batteries", _batteries], ["dress ward", _ward], ["dress galleries", _galleries]]:
		var t0 := Time.get_ticks_usec()
		step[1].call(out)
		build_ms[step[0]] = (Time.get_ticks_usec() - t0) / 1000.0
	var t1 := Time.get_ticks_usec()
	var props := _prop_specs()
	build_ms["dress props"] = (Time.get_ticks_usec() - t1) / 1000.0
	return {"pieces": out, "props": props}


# --------------------------------------------------------------------------
# Keeping clear of the run
# --------------------------------------------------------------------------
## [point, radius] and ["seg", a, b, r] the dressing keeps off.
static func _anchor_list() -> Array:
	var a: Array = []
	for d in StrongholdGarrison.POSTS:
		for e: Array in StrongholdGarrison.POSTS[d]:
			if str(e[0]) == "patrol":
				var pts: Array = e[1]
				for i in range(pts.size()):
					a.append(["seg", pts[i], pts[(i + 1) % pts.size()] if pts.size() > 2 else pts[mini(i + 1, pts.size() - 1)], 1.6])
			else:
				a.append([e[1], 4.0 if str(e[0]) == "post" else 2.2])
	for d in StrongholdGarrison.SOURCES:
		for e: Array in StrongholdGarrison.SOURCES[d]:
			a.append([e[1], 4.5])
	for d in StrongholdBell.BELLS:
		for q: Vector2 in StrongholdBell.BELLS[d]:
			a.append([q, 3.0])
	for d in StrongholdMuster.AT:
		a.append([StrongholdMuster.AT[d], 3.0])
	for q: Vector2 in [StrongholdActs.WINCH, StrongholdActs.LEVER, StrongholdActs.SUPPLY_AT, StrongholdActs.RACK_AT, StrongholdActs.HOIST_DOWN,
			StrongholdActs.HOIST_UP]:
		a.append([q, 3.0])
	for q: Vector2 in StrongholdActs.LOCKS:
		a.append([q, 3.0])
	for l: Vector3 in StrongholdActs.LEDGES:
		a.append([Vector2(l.x, l.z), 4.0])
	for k in StrongholdBoss.BOSSES:
		a.append([StrongholdBoss.BOSSES[k]["checkpoint"], 3.0])
	var ar: Array = StrongholdBoss.BOSSES["marrow"]["arena"]
	a.append([ar[0], float(ar[1]) + 0.5])
	a.append([P.BERTH, 13.0])
	a.append([Vector2(0.0, -100.4), 3.5])
	a.append(["seg", StrongholdActs.PERCH_STAIR[0] + Vector2(-1, 0), StrongholdActs.PERCH_STAIR[1], 2.4])
	a.append(["seg", StrongholdActs.PERCH.position, StrongholdActs.PERCH.end, 2.4])
	# the stealth test's sneak behind the ward's west sentry, the act jumps' spots
	a.append(["seg", Vector2(-44.0, -12.0), Vector2(-30.0, -12.0), 2.0])
	for e: Array in StrongholdActs.ACTS:
		a.append([e[1], 3.0])
	# the rooms' doors: an apron out from each
	for rm in P.ROOMS:
		var r: Rect2 = rm[2]
		var door: Vector2 = rm[5]
		var dc := r.get_center() + Vector2(door.x * r.size.x * 0.5, door.y * r.size.y * 0.5)
		a.append(["seg", dc - door * 2.0, dc + door * 6.0, float(rm[6]) * 0.5 + 1.6])
	return a


## Is frame point q clear of the run's anchors (by pad) and the ways, on a district's floor?
static func clear_at(q: Vector2, pad: float) -> bool:
	if P.district_at(q) < 0 or S._near_way(q, pad + 1.0):
		return false
	for e: Array in _anchors:
		if e[0] is String:
			var a: Vector2 = e[1]
			var b: Vector2 = e[2]
			var ab := b - a
			var u := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if q.distance_to(a + ab * u) < float(e[3]) + pad:
				return false
		elif q.distance_to(e[0]) < float(e[1]) + pad:
			return false
	return true


## A repeated prop: kind at frame point q on floor y (yaw: its +Z to that heading), its collider a box of `box` (zero: none).
static func _put(district: String, kind: String, q: Vector2, y: float, yaw: float, box := Vector3.ZERO, scale := 1.0) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), M.v3(q, y))
	if not _placed.has(kind):
		_placed[kind] = []
	(_placed[kind] as Array).append([district, t])
	if box != Vector3.ZERO:
		M.box(_cols, Transform3D(Basis(Vector3.UP, yaw), M.v3(q, y + box.y * 0.5)), box * scale)


## A cluster of cargo at q: crates and barrels and kegs stacked, from rng (clear of anchors by its radius).
static func _cargo(district: String, q: Vector2, y: float, rng: RandomNumberGenerator, n := 5) -> void:
	if not clear_at(q, 2.0):
		return
	for k in range(n):
		var o := Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.2, 1.2))
		var kind: String = ["crate", "crate", "barrel", "keg", "crate"][rng.randi() % 5]
		var yaw := rng.randf_range(-0.4, 0.4)
		match kind:
			"crate":
				_put(district, "crate", q + o, y, yaw, Vector3(1.0, 1.0, 1.0))
				if rng.randf() < 0.5:
					_put(district, "crate", q + o + Vector2(rng.randf_range(-0.1, 0.1), 0.05), y + 1.0, yaw + rng.randf_range(-0.3, 0.3), Vector3.ZERO, 0.8)
			"barrel":
				_put(district, "barrel", q + o, y, yaw, Vector3(0.72, 1.0, 0.72))
			_:
				_put(district, "keg", q + o, y, yaw, Vector3(0.56, 0.7, 0.56))


# --------------------------------------------------------------------------
# The Landing and the docks
# --------------------------------------------------------------------------
## The quay: lamp posts and flags along it, bollards and coiled ropes at its edge, gangplanks and fenders on the docks,
## nets and cargo by the cranes, a harbourmaster's lean-to; boards with the wanted posters at the stair's foot.
static func _landing(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var y := P.QUAY_Y
	var rng := _rng(7101)
	var x := -54.0
	while x <= 54.0:
		var q := Vector2(x, P.FRONT_Z - 1.2)
		if clear_at(q, 0.6) and absf(x - P.BERTH.x) > 10.0:
			_put("landing", "bollard", q, y, 0.0, Vector3(0.5, 0.7, 0.5))
			if rng.randf() < 0.4 and clear_at(q + Vector2(1.0, -0.6), 0.2):
				_put("landing", "coil", q + Vector2(1.0, -0.6), y, rng.randf() * TAU)
		x += 6.0
	# lamp posts and flags in a line down the quay's middle and up the stair's foot
	for lx: float in [-50.0, -38.0, -26.0, -14.0, 14.0, 26.0, 38.0, 50.0]:
		var q := Vector2(lx, 49.0)
		if clear_at(q, 0.6):
			_put("landing", "lamp", q, y, 0.0, Vector3(0.6, 3.6, 0.6))
	for s: float in [-1.0, 1.0]:
		if clear_at(Vector2(s * 12.0, 37.5), 0.4):
			_put("landing", "flag", Vector2(s * 12.0, 37.5), y, 0.0, Vector3(0.6, 9.0, 0.6))
		if clear_at(Vector2(s * 15.0, 38.4), 1.0):
			_put("landing", "board", Vector2(s * 15.0, 38.4), y, PI, Vector3(2.0, 2.4, 0.4))
	# cargo by the cranes and along the back of the quay
	for q: Vector2 in [Vector2(-24.0, 50.0), Vector2(-46.0, 44.0), Vector2(32.0, 50.0), Vector2(46.0, 42.0), Vector2(-52.0, 51.0), Vector2(16.0, 40.0)]:
		_cargo("landing", q, y, rng, 6)
	for q: Vector2 in [Vector2(-40.0, 56.0), Vector2(36.0, 41.0)]:
		if clear_at(q, 1.5):
			_put("landing", "cart", q, y, rng.randf_range(-0.6, 0.6), Vector3(1.4, 1.2, 2.4))
	# the docks: fenders down their sides, a gangplank from each, nets heaped at their roots
	var wood := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	for dx: float in [-36.0, 42.0]:
		for z: float in [P.FRONT_Z + 2.0, P.FRONT_Z + 5.0, P.FRONT_Z + 8.0]:
			for s: float in [-1.0, 1.0]:
				mb.add_cylinder(rope, M.xf(M.v3(Vector2(dx + s * 2.15, z), y - 1.2)), 0.22, 0.22, 0.8, 6, 1.0, Color(0.6, 0.55, 0.45))
		for k in range(3):
			mb.add_blob(PSXMat.lit("rope", Color(0.55, 0.6, 0.5)), M.xf(M.v3(Vector2(dx - 1.0 + k * 0.9, P.FRONT_Z - 2.4), y + 0.15)), Vector3(0.7, 0.3, 0.5), rng, 0.15, 3, 6, 1.0)
		mb.add_box(wood, M.xf(M.v3(Vector2(dx, P.FRONT_Z + 10.5), y - 0.3)) * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3.ZERO), Vector3(1.2, 0.1, 3.0), 0.8)
	# the harbourmaster's lean-to against the quay tower: a desk, a ledger, a lantern, a navy awning
	var hq := Vector2(-50.0, 58.0)
	if clear_at(hq, 1.0):
		_lean_to(mb, hq, y, Vector2(1, 0))
	CapitalShell._piece(out, "DressLanding", mb, _cols, RANGE, false)


## A navy awning on two posts over a clerk's desk and stool, a ledger and a lantern on it, a crate of papers.
static func _lean_to(mb: MeshBuilder, q: Vector2, y: float, f: Vector2) -> void:
	var wood := PSXMat.lit("planks_dark")
	var yaw := M.yaw_of(f)
	var t := M.xf(M.v3(q, y), yaw)
	for s: float in [-1.0, 1.0]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(s * 1.4, 1.2, 1.4)), Vector3(0.14, 2.4, 0.14), 1.0)
	mb.add_box(PSXMat.lit("canvas", Color(0.24, 0.32, 0.62)), t * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 2.5, 0.6)), Vector3(3.2, 0.06, 2.0), 0.5)
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.78, 0.3)), Vector3(1.6, 0.08, 0.8), 1.0)
	for s: float in [-1.0, 1.0]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(s * 0.7, 0.38, 0.3)), Vector3(0.08, 0.76, 0.7), 1.0)
	mb.add_box(PSXMat.lit("canvas", Color(0.95, 0.92, 0.8)), t * Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.2, 0.84, 0.25)), Vector3(0.5, 0.04, 0.36), 1.0)
	mb.add_box(PSXMat.lit("leather", Color(0.45, 0.25, 0.15)), t * Transform3D(Basis(), Vector3(0.35, 0.86, 0.3)), Vector3(0.3, 0.08, 0.4), 1.0)
	mb.add_box(S._window_m(), t * Transform3D(Basis(), Vector3(0.6, 1.0, 0.4)), Vector3(0.2, 0.3, 0.2), 1.0)
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.25, 1.2)), Vector3(0.4, 0.5, 0.4), 1.0)
	M.box(_cols, t * Transform3D(Basis(), Vector3(0, 0.4, 0.3)), Vector3(1.6, 0.8, 0.8))


# --------------------------------------------------------------------------
# The Arsenal's foundry (Kesh)
# --------------------------------------------------------------------------
## The yard and the Casting Hall: soot up the hall's walls and round its door, the yard's slag heaps glowing in their
## cracks, coal and ore piles, a tramway with ore carts, a cooling crucible on a frame, chains down from the gantry, a
## quench trough, anvils, stacked moulds and ingots; inside, along the walls, the tools, moulds, ingot racks and a
## workbench (the floor kept clear for Kesh's pours and channels).
static func _foundry(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var y := 14.0
	var rng := _rng(7201)
	var cr: Rect2 = P.ROOMS[2][2]
	var soot := S._soot_m()
	var iron := S._iron_m()
	var fire := PSXMat.glow(Color(1.0, 0.42, 0.12), 2.6)
	# soot: dark streaks up the hall's outer walls from its vents and round its door
	for f: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * cr.size.x + absf(al.y) * cr.size.y
		var e := cr.get_center() + Vector2(f.x * cr.size.x * 0.5, f.y * cr.size.y * 0.5)
		for k in range(int(L / 5.0)):
			var u := -L * 0.5 + (k + 0.5) * L / int(L / 5.0) + rng.randf_range(-0.8, 0.8)
			var hh := rng.randf_range(4.0, 9.0)
			mb.add_box(soot, M.xf(M.v3(e + al * u + f * 0.4, y + 14.0 + 1.0 - hh * 0.5), M.yaw_of(al)), Vector3(0.05, hh, rng.randf_range(1.0, 2.4)), 0.5, Color(0.8, 0.8, 0.8))
	var door := Vector2(cr.position.x, cr.get_center().y)
	mb.add_box(soot, M.xf(M.v3(door + Vector2(-0.42, 0), y + 6.0), M.yaw_of(Vector2(0, 1))), Vector3(0.05, 6.0, 9.0), 0.5, Color(0.7, 0.7, 0.7))
	# vents with glow along the hall's top
	for k in range(5):
		var q := Vector2(cr.position.x + 4.0 + k * 5.5, cr.position.y - 0.45)
		mb.add_box(iron, M.xf(M.v3(q, y + 11.0)), Vector3(1.6, 1.0, 0.3), 0.5)
		mb.add_box(fire, M.xf(M.v3(q + Vector2(0, -0.17), y + 11.0)), Vector3(1.2, 0.5, 0.04), 1.0)
	# slag heaps along the yard's east wall, cracks glowing
	for q: Vector2 in [Vector2(103.0, -42.0), Vector2(106.0, -6.0), Vector2(100.5, -44.0)]:
		if clear_at(q, 2.0):
			mb.add_blob(soot, M.xf(M.v3(q, y)), Vector3(2.4, 1.3, 1.8), rng, 0.25, 4, 8, 0.8, Color(0.5, 0.48, 0.5), true)
			for j in range(4):
				var o := Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.0, 1.0))
				mb.add_box(fire, M.xf(M.v3(q + o, y + 0.5 + rng.randf() * 0.5), rng.randf() * TAU), Vector3(0.6, 0.05, 0.08), 1.0)
			M.box(_cols, M.xf(M.v3(q, y + 0.6)), Vector3(3.6, 1.2, 2.6))
	# coal and ore piles
	for e in [[Vector2(60.0, -33.0), Color(0.18, 0.18, 0.2)], [Vector2(60.0, -17.0), Color(0.55, 0.38, 0.3)], [Vector2(104.0, 2.0), Color(0.18, 0.18, 0.2)]]:
		var q: Vector2 = e[0]
		if clear_at(q, 2.0):
			mb.add_blob(PSXMat.lit("black_rock", e[1]), M.xf(M.v3(q, y)), Vector3(2.0, 1.0, 1.6), rng, 0.3, 4, 8, 1.0, Color.WHITE, true)
			M.box(_cols, M.xf(M.v3(q, y + 0.5)), Vector3(3.0, 1.0, 2.4))
			if clear_at(q + Vector2(2.2, 0.8), 0.8):
				_put("arsenal", "barrow", q + Vector2(2.2, 0.8), y, rng.randf_range(-1.0, 1.0), Vector3(0.8, 0.8, 1.6))
	# the tramway from the coal to the hall's door: rails, sleepers, two ore carts
	var ra := Vector2(60.0, -28.0)
	var rb := Vector2(66.0, -28.0)
	var wood := PSXMat.lit("planks_dark")
	for s: float in [-0.5, 0.5]:
		mb.add_box(iron, M.xf(M.v3((ra + rb) * 0.5 + Vector2(0, s), y + 0.06)), Vector3(rb.x - ra.x, 0.08, 0.08), 1.0)
	for k in range(int(rb.x - ra.x) + 1):
		mb.add_box(wood, M.xf(M.v3(Vector2(ra.x + k, ra.y), y + 0.02)), Vector3(0.2, 0.06, 1.4), 1.0)
	if clear_at(Vector2(62.0, -28.0), 0.8):
		_put("arsenal", "orecart", Vector2(62.0, -28.0), y, PI * 0.5, Vector3(1.6, 1.2, 1.1))
	# a cooling crucible on its iron frame, chains down from the gantry with hooks, a quench trough, anvils
	var cc := Vector2(88.0, 2.0)
	if clear_at(cc, 2.0):
		for s: float in [-1.0, 1.0]:
			mb.add_box(iron, M.xf(M.v3(cc + Vector2(s * 1.6, 0), y + 1.2)), Vector3(0.25, 2.4, 0.25), 1.0)
		mb.add_box(iron, M.xf(M.v3(cc, y + 2.3)), Vector3(3.4, 0.2, 0.2), 1.0)
		mb.add_cylinder(iron, M.xf(M.v3(cc, y + 0.6)), 0.7, 1.0, 1.3, 10, 0.5, Color(0.6, 0.6, 0.6), false)
		mb.add_cylinder(fire, M.xf(M.v3(cc, y + 1.8)), 0.85, 0.85, 0.06, 10, 1.0)
		M.box(_cols, M.xf(M.v3(cc, y + 1.0)), Vector3(3.4, 2.0, 2.0))
	for gx: float in [66.0, 74.0, 90.0, 98.0]:
		var top := Vector3(gx, 27.7, 2.0)
		var low := Vector3(gx, 18.0 + float(int(gx) % 3), 2.0)
		_chain(mb, iron, top, low)
		mb.add_box(iron, Transform3D(Basis(), low + Vector3(0, -0.35, 0)), Vector3(0.12, 0.5, 0.4), 1.0)
	var tq := Vector2(96.0, 6.0)
	if clear_at(tq, 1.5):
		mb.add_box(wood, M.xf(M.v3(tq, y + 0.4)), Vector3(3.0, 0.8, 1.2), 0.8, Color(0.7, 0.62, 0.5))
		mb.add_box(PSXMat.lit("water", Color(0.4, 0.5, 0.55)), M.xf(M.v3(tq, y + 0.72)), Vector3(2.8, 0.04, 1.0), 0.5)
		M.box(_cols, M.xf(M.v3(tq, y + 0.4)), Vector3(3.0, 0.8, 1.2))
	for q: Vector2 in [Vector2(92.0, -2.0), Vector2(72.0, 6.0)]:
		if clear_at(q, 1.0):
			_put("arsenal", "anvil", q, y, rng.randf() * TAU, Vector3(0.8, 0.9, 0.5))
	for q: Vector2 in [Vector2(100.0, -16.0), Vector2(66.0, 8.0), Vector2(102.0, -30.0)]:
		_cargo("arsenal", q, y, rng, 5)
	for q: Vector2 in [Vector2(58.0, -10.0), Vector2(84.0, -2.0)]:
		if clear_at(q, 1.0):
			_put("arsenal", "moulds", q, y, rng.randf_range(-0.3, 0.3), Vector3(1.6, 0.9, 1.2))
	# inside the hall, along its walls (clear of the channels and pours)
	var iy := float(P.ROOMS[2][3])
	var ir := cr.grow(-1.2)
	for k in range(5):
		var x := ir.position.x + 4.0 + k * 4.6
		for f: float in [-1.0, 1.0]:
			var q := Vector2(x, ir.get_center().y + f * (ir.size.y * 0.5 - 0.5))
			match (k + int(f > 0.0)) % 3:
				0:
					_put("arsenal", "moulds", q, iy, 0.0 if f < 0.0 else PI, Vector3(1.6, 0.9, 1.0))
				1:
					_put("arsenal", "toolrack", q, iy, 0.0 if f < 0.0 else PI, Vector3(1.8, 2.0, 0.3))
				_:
					_put("arsenal", "ingots", q, iy, 0.0 if f < 0.0 else PI, Vector3(1.2, 0.7, 0.8))
	_bench(mb, Vector2(ir.end.x - 0.6, ir.position.y + 2.4), iy, Vector2(-1, 0))
	# the hall's walls blackened inside by the furnaces, darkest low down, the ceiling's beams sooted
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * ir.size.x + absf(al.y) * ir.size.y
		var e := ir.get_center() + Vector2(f.x * ir.size.x * 0.5, f.y * ir.size.y * 0.5) - f * 0.03
		var runs: Array = [[-L * 0.5, L * 0.5]]
		if f.x < 0.0:
			runs = [[-L * 0.5, -3.4], [3.4, L * 0.5]]
		for rr: Array in runs:
			var u := (float(rr[0]) + float(rr[1])) * 0.5
			var ln := float(rr[1]) - float(rr[0])
			mb.add_box(soot, M.xf(M.v3(e + al * u, iy + 2.5), M.yaw_of(al)), Vector3(0.04, 5.0, ln), 0.5, Color(0.75, 0.72, 0.7))
			mb.add_box(soot, M.xf(M.v3(e + al * u - f * 0.01, iy + 7.0), M.yaw_of(al)), Vector3(0.04, 4.0, ln), 0.5, Color(1.6, 1.55, 1.5))
	for k in range(6):
		mb.add_box(wood, M.xf(M.v3(Vector2(ir.position.x + 2.0 + k * (ir.size.x - 4.0) / 5.0, ir.get_center().y), iy + 13.2)), Vector3(0.5, 0.6, ir.size.y), 0.5, Color(0.4, 0.38, 0.36))
	CapitalShell._piece(out, "DressFoundry", mb, _cols, RANGE, false)


static func _chain(mb: MeshBuilder, m: Material, a: Vector3, b: Vector3) -> void:
	var n := int(a.distance_to(b) / 0.35)
	for k in range(n):
		var p := a.lerp(b, (k + 0.5) / n)
		mb.add_box(m, Transform3D(Basis(Vector3.UP, k * PI * 0.5), p), Vector3(0.06, 0.3, 0.16), 1.0)


## A smith's workbench against a wall: a heavy top on legs, a vice, tongs and hammers on it, a rack of files over it.
static func _bench(mb: MeshBuilder, q: Vector2, y: float, f: Vector2) -> void:
	var wood := PSXMat.lit("planks_dark")
	var iron := S._iron_m()
	var t := M.xf(M.v3(q, y), M.yaw_of(f))
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(2.4, 0.12, 0.8), 1.0)
	for sx: float in [-1.1, 1.1]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(sx, 0.42, 0)), Vector3(0.12, 0.84, 0.7), 1.0)
	mb.add_box(iron, t * Transform3D(Basis(), Vector3(-0.8, 1.0, 0.2)), Vector3(0.2, 0.2, 0.3), 1.0)
	for k in range(4):
		mb.add_box(iron, t * Transform3D(Basis(Vector3.UP, 0.3 * k), Vector3(-0.2 + k * 0.3, 0.93, 0.0)), Vector3(0.05, 0.04, 0.5), 1.0)
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 1.8, -0.35)), Vector3(2.0, 0.6, 0.06), 1.0)
	for k in range(6):
		mb.add_box(iron, t * Transform3D(Basis(), Vector3(-0.8 + k * 0.32, 1.7, -0.3)), Vector3(0.04, 0.5, 0.04), 1.0)
	M.box(_cols, t * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.4, 0.9, 0.8))


# --------------------------------------------------------------------------
# The prison (Marrow's riot)
# --------------------------------------------------------------------------
## The cell block raised into a real one: two more tiers of barred cells over the yard's block (StrongholdActs.CELLS),
## each with a catwalk on iron brackets along its front and a stair up from the tier below at its north end, the upper
## catwalk meeting Marrow's (StrongholdBoss's square walk at the same height); bunks, buckets and straw in the cells.
## An iron gate in the drum's east face, chains and shackles on the yard's walls, a searchlight on a post.
static func _prison(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var r: Rect2 = StrongholdActs.CELLS
	var iron := S._iron_m()
	var wood := PSXMat.lit("planks_dark")
	var straw := PSXMat.lit("straw", Color(0.8, 0.72, 0.5))
	var stone := S._wall_m()
	var tier_h := 4.8
	var y1 := 14.0 + StrongholdActs.CELLS_H + 0.6
	var cells := 4
	var cw := r.size.y / cells
	for tier in range(2):
		var fy := y1 + tier * tier_h
		var top := fy + tier_h - 0.4
		# back and end walls, the dividers, the floor over (the ceiling of this tier)
		_slab(mb, stone, M.xf(M.v3(Vector2(r.position.x + 0.3, r.get_center().y), (fy + top) * 0.5)), Vector3(0.6, top - fy, r.size.y))
		for z: float in [r.position.y + 0.3, r.end.y - 0.3]:
			_slab(mb, stone, M.xf(M.v3(Vector2(r.get_center().x, z), (fy + top) * 0.5)), Vector3(r.size.x, top - fy, 0.6))
		_slab(mb, S._dark_m(), M.xf(M.v3(r.get_center(), top + 0.2)), Vector3(r.size.x + 0.4, 0.4, r.size.y + 0.4))
		mb.add_box(S._trim_m(), M.xf(M.v3(r.get_center(), top + 0.2)), Vector3(r.size.x + 0.5, 0.2, r.size.y + 0.5), 0.5)
		for k in range(1, cells):
			var z := r.position.y + k * cw
			mb.add_box(stone, M.xf(M.v3(Vector2(r.get_center().x, z), (fy + top) * 0.5)), Vector3(r.size.x - 0.6, top - fy, 0.3), 0.5)
		# the barred fronts: a solid face for the collider, bars and a door frame in each cell
		var fx := r.end.x - 0.3
		M.box(_cols, M.xf(M.v3(Vector2(fx, r.get_center().y), (fy + top) * 0.5)), Vector3(0.3, top - fy, r.size.y))
		for k in range(cells):
			var z0 := r.position.y + k * cw
			for j in range(int(cw / 0.32)):
				mb.add_box(iron, M.xf(M.v3(Vector2(fx, z0 + 0.2 + j * 0.32), (fy + top) * 0.5)), Vector3(0.07, top - fy, 0.07), 1.0)
			for yy: float in [fy + 0.1, fy + 2.2, top - 0.1]:
				mb.add_box(iron, M.xf(M.v3(Vector2(fx, z0 + cw * 0.5), yy)), Vector3(0.12, 0.1, cw), 1.0)
			# what's in the cell: a bunk, its straw, a bucket
			var cz := z0 + cw * 0.5
			mb.add_box(wood, M.xf(M.v3(Vector2(r.position.x + 1.5, cz), fy + 0.5)), Vector3(1.8, 0.1, 0.8), 1.0)
			mb.add_box(straw, M.xf(M.v3(Vector2(r.position.x + 1.5, cz), fy + 0.6)), Vector3(1.6, 0.1, 0.7), 1.0)
			for cn: Vector2 in [Vector2(-0.8, -0.3), Vector2(0.8, 0.3)]:
				mb.add_box(wood, M.xf(M.v3(Vector2(r.position.x + 1.5 + cn.x, cz + cn.y), fy + 0.25)), Vector3(0.08, 0.5, 0.08), 1.0)
			mb.add_cylinder(wood, M.xf(M.v3(Vector2(r.position.x + 3.2, cz + 0.6), fy)), 0.2, 0.22, 0.4, 6, 1.0, Color(0.7, 0.6, 0.5))
			mb.add_blob(straw, M.xf(M.v3(Vector2(r.position.x + 3.6, cz - 0.4), fy)), Vector3(0.6, 0.15, 0.5), _rng(k + tier * 10), 0.2, 2, 5, 1.0, Color.WHITE, true)
		# the tier's catwalk: grating on brackets out front, a rail, the stair up from the tier below at the north end
		var cx := r.end.x + 0.75
		_slab(mb, iron, M.xf(M.v3(Vector2(cx, r.get_center().y), fy - 0.1)), Vector3(1.5, 0.2, r.size.y))
		for k in range(cells + 1):
			var z := r.position.y + k * cw
			var a := Vector3(r.end.x, fy - 1.2, z)
			var b := Vector3(r.end.x + 1.4, fy - 0.2, z)
			mb.add_box(iron, Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5), Vector3(0.1, 0.1, a.distance_to(b)), 1.0)
			mb.add_box(iron, M.xf(Vector3(r.end.x + 1.45, fy + 0.5, z)), Vector3(0.08, 1.0, 0.08), 1.0)
		mb.add_box(iron, M.xf(Vector3(r.end.x + 1.45, fy + 1.0, r.get_center().y)), Vector3(0.08, 0.08, r.size.y), 1.0)
		if tier == 1:
			M.box(_cols, M.xf(Vector3(r.end.x + 1.45, fy + 0.5, r.get_center().y + 1.5)), Vector3(0.1, 1.0, r.size.y - 3.0))
			# the stair up from the lower tier's catwalk at the north end (a slope collider under iron treads)
			var sa := Vector3(r.end.x + 0.75, fy - tier_h, r.end.y - 0.4)
			var sb := Vector3(r.end.x + 0.75, fy, r.end.y - 0.4 - tier_h * 1.25)
			sa.z = r.position.y + 0.6 + tier_h * 1.25
			sb.z = r.position.y + 0.6
			var run := absf(sa.z - sb.z)
			var slope := atan2(tier_h, run)
			M.box(_cols, Transform3D(Basis(Vector3.RIGHT, slope), (sa + sb) * 0.5), Vector3(1.2, 0.2, sqrt(run * run + tier_h * tier_h)))
			for j in range(int(tier_h / 0.24)):
				var u := (j + 0.5) / int(tier_h / 0.24)
				mb.add_box(iron, M.xf(sa.lerp(sb, u) + Vector3(0, 0.05, 0)), Vector3(1.2, 0.06, run / int(tier_h / 0.24) + 0.02), 1.0)
	# the roof's parapet and a lamp over the block
	var ry := y1 + tier_h * 2.0
	for z: float in [r.position.y, r.end.y]:
		_slab(mb, stone, M.xf(M.v3(Vector2(r.get_center().x, z), ry + 0.5)), Vector3(r.size.x, 0.8, 0.4))
	# the drum's iron gate (where the garrison's gate comes out)
	var gq := Vector2(P.PRISON.x + 13.05, -18.0)
	mb.add_box(S._dark_m(), M.xf(M.v3(gq, 14.0 + 2.2)), Vector3(0.4, 4.4, 4.2), 0.5)
	for j in range(9):
		mb.add_box(iron, M.xf(M.v3(gq + Vector2(0.25, -1.6 + j * 0.4), 14.0 + 1.8)), Vector3(0.08, 3.6, 0.08), 1.0)
	for yy: float in [15.0, 16.6, 17.6]:
		mb.add_box(iron, M.xf(M.v3(gq + Vector2(0.27, 0), yy)), Vector3(0.1, 0.12, 3.4), 1.0)
	mb.add_box(S._trim_m(), M.xf(M.v3(gq + Vector2(0.1, 0), 18.7)), Vector3(0.6, 0.6, 4.8), 0.5)
	# shackles and chains on the yard's north wall, a searchlight post over the yard
	var rng := _rng(7301)
	for k in range(6):
		var q := Vector2(-104.0 + k * 3.4, -44.4 + 1.2)
		if clear_at(q, 0.0):
			_chain(mb, iron, M.v3(q, 16.4), M.v3(q + Vector2(rng.randf_range(-0.3, 0.3), 0.1), 15.0))
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), M.v3(q + Vector2(0, 0.1), 14.9)), 0.12, 0.12, 0.06, 6, 1.0)
	var lq := Vector2(-58.0, -30.0)
	if clear_at(lq, 1.0):
		mb.add_box(iron, M.xf(M.v3(lq, 14.0 + 3.0)), Vector3(0.3, 6.0, 0.3), 1.0)
		mb.add_cylinder(iron, Transform3D(Basis(Vector3.UP, -0.6) * Basis(Vector3.RIGHT, 1.1), M.v3(lq, 20.2)), 0.5, 0.6, 0.9, 8, 1.0, Color.WHITE, true)
		mb.add_cylinder(S._window_m(), Transform3D(Basis(Vector3.UP, -0.6) * Basis(Vector3.RIGHT, 1.1), M.v3(lq, 20.2)), 0.45, 0.45, 0.95, 8, 1.0, Color.WHITE, true)
		M.box(_cols, M.xf(M.v3(lq, 17.0)), Vector3(0.4, 6.0, 0.4))
	for q: Vector2 in [Vector2(-104.0, -30.0), Vector2(-60.0, -24.0), Vector2(-92.0, -42.0)]:
		_cargo("prison", q, 14.0, rng, 4)
	for q: Vector2 in [Vector2(-90.0, 11.0), Vector2(-60.0, -42.0)]:
		if clear_at(q, 1.0):
			_put("prison", "board", q, 14.0, PI, Vector3(2.0, 2.4, 0.4))
	CapitalShell._piece(out, "DressPrison", mb, _cols, RANGE, true)


static func _slab(mb: MeshBuilder, m: Material, t: Transform3D, size: Vector3) -> void:
	mb.add_box(m, t, size, 0.5, Color.WHITE, false)
	M.box(_cols, t, size)


# --------------------------------------------------------------------------
# The keep (Vane's hall, the roof)
# --------------------------------------------------------------------------
## The Command Hall dressed as the Commodore's: a long navy runner from the door to the dais with a gold edge, navy and
## gold bases and capitals on the pillars, chandeliers hung on chains, banners and flags on stands behind the dais,
## shelves of charts and ledgers, clerks' desks with papers along the side walls, the war table's map and markers;
## the plateau's flags and lamps; the roof terrace's corner braziers and flagstaffs.
static func _keep(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var rm: Array = P.ROOMS[3]
	var r: Rect2 = rm[2]
	var y: float = rm[3]
	var h: float = rm[4]
	var c := r.get_center()
	var gold := S._gold_m()
	var trim := S._trim_m()
	var iron := S._iron_m()
	var wood := PSXMat.lit("planks_dark")
	var rng := _rng(7401)
	# the runner from the door to the dais
	var dz := r.position.y + 4.0
	mb.add_box(PSXMat.lit("fabric", Color(0.2, 0.26, 0.55)), M.xf(M.v3(Vector2(c.x, (dz + 3.0 + r.end.y) * 0.5), y + 0.02)), Vector3(4.0, 0.03, r.end.y - dz - 3.0), 0.5)
	for s: float in [-1.0, 1.0]:
		mb.add_box(gold, M.xf(M.v3(Vector2(c.x + s * 2.0, (dz + 3.0 + r.end.y) * 0.5), y + 0.03)), Vector3(0.18, 0.03, r.end.y - dz - 3.0), 1.0)
	# the pillars' bases and capitals
	for k in range(10):
		var a := TAU * k / 10.0
		var q := c + Vector2(cos(a), sin(a)) * 15.0
		mb.add_box(trim, M.xf(M.v3(q, y + 0.5)), Vector3(2.6, 1.0, 2.6), 0.5)
		mb.add_box(gold, M.xf(M.v3(q, y + 1.05)), Vector3(2.3, 0.12, 2.3), 1.0)
		mb.add_box(trim, M.xf(M.v3(q, y + h - 0.6)), Vector3(2.8, 1.2, 2.8), 0.5)
		mb.add_box(gold, M.xf(M.v3(q, y + h - 1.3)), Vector3(2.4, 0.14, 2.4), 1.0)
	# chandeliers: gold rings of candles on chains from the ceiling
	for q: Vector2 in [c + Vector2(0, 8), c + Vector2(0, -4), c + Vector2(-9, 2), c + Vector2(9, 2)]:
		var cy := y + h - 9.0
		_chain(mb, iron, M.v3(q, y + h), M.v3(q, cy + 0.4))
		for j in range(8):
			var a := TAU * j / 8.0
			mb.add_box(gold, M.xf(M.v3(q + Vector2(cos(a), sin(a)) * 1.3, cy), -a), Vector3(0.12, 0.12, 1.0), 1.0)
			mb.add_box(S._window_m(), M.xf(M.v3(q + Vector2(cos(a), sin(a)) * 1.6, cy + 0.25)), Vector3(0.1, 0.3, 0.1), 1.0)
		mb.add_cylinder(gold, M.xf(M.v3(q, cy - 0.3)), 0.2, 0.4, 0.7, 6, 1.0)
	# flags on stands behind the dais, either side of the seat
	for s: float in [-1.0, 1.0]:
		for j in range(2):
			var q := Vector2(c.x + s * (4.6 + j * 2.2), r.position.y + 1.4)
			mb.add_cylinder(gold, M.xf(M.v3(q, y + 1.2)), 0.07, 0.06, 5.0, 5, 1.0)
			mb.add_cylinder(gold, M.xf(M.v3(q, y + 1.2)), 0.35, 0.3, 0.2, 6, 1.0)
			mb.add_box_unit_uv(S._banner_m(), Transform3D(Basis(Vector3.UP, s * 0.25), M.v3(q + Vector2(s * 0.9, 0.1), y + 5.0)), Vector3(1.7, 1.2, 0.04))
	# shelves of charts and ledgers along the side walls, the clerks' desks between
	for s: float in [-1.0, 1.0]:
		var wx := c.x + s * (r.size.x * 0.5 - 1.6)
		for k in range(4):
			var z := r.position.y + 10.0 + k * 9.0
			if absf(z - r.end.y) < 4.0:
				continue
			if k % 2 == 0:
				_shelf(mb, Vector2(wx, z), y, Vector2(-s, 0), rng)
			else:
				_desk(mb, Vector2(wx - s * 0.6, z), y, Vector2(-s, 0), rng)
	# the war table: the map's coasts, the markers
	var wt := c + Vector2(0, 4)
	for k in range(9):
		var q := wt + Vector2(rng.randf_range(-3.2, 3.2), rng.randf_range(-1.8, 1.8))
		mb.add_cylinder(gold if k % 3 == 0 else trim, M.xf(M.v3(q, y + 1.04)), 0.1, 0.06, 0.22, 5, 1.0)
	for k in range(5):
		mb.add_box(PSXMat.lit("canvas", Color(0.55, 0.62, 0.45)), M.xf(M.v3(wt + Vector2(rng.randf_range(-2.6, 2.6), rng.randf_range(-1.4, 1.4)), y + 1.035), rng.randf() * TAU), Vector3(rng.randf_range(0.6, 1.6), 0.01, rng.randf_range(0.4, 1.0)), 0.5)
	# the plateau before the keep: flags and lamps along its front, braziers by the gate
	var ky: float = P.DISTRICTS[4][2]
	for q: Vector2 in [Vector2(-38.0, -50.6), Vector2(-24.0, -50.6), Vector2(24.0, -50.6), Vector2(38.0, -50.6)]:
		if clear_at(q, 0.6):
			_put("keep", "flag", q, ky, 0.0, Vector3(0.6, 9.0, 0.6))
	for q: Vector2 in [Vector2(-14.0, -54.0), Vector2(14.0, -54.0), Vector2(-38.0, -66.0), Vector2(38.0, -66.0), Vector2(-38.0, -90.0), Vector2(38.0, -90.0)]:
		if clear_at(q, 0.6):
			_put("keep", "lamp", q, ky, 0.0, Vector3(0.6, 3.6, 0.6))
	for q: Vector2 in [Vector2(-34.0, -100.0), Vector2(34.0, -104.0), Vector2(36.0, -76.0)]:
		_cargo("keep", q, ky, rng, 4)
	# the roof terrace's corners: a stone pylon each with a brazier, a flagstaff
	var ty := StrongholdActs.ROOF_Y
	var th := StrongholdActs.TERRACE * 0.5 - 1.0
	for cn: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q := P.KEEP + cn * th
		_slab(mb, S._wall_m(), M.xf(M.v3(q, ty + 0.6)), Vector3(1.6, 1.2, 1.6))
		mb.add_box(trim, M.xf(M.v3(q, ty + 1.3)), Vector3(1.8, 0.2, 1.8), 0.5)
		mb.add_cylinder(iron, M.xf(M.v3(q, ty + 1.4)), 0.5, 0.7, 0.5, 8, 1.0)
		mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.15), 2.0), M.xf(M.v3(q, ty + 2.0)), Vector3(0.7, 0.4, 0.7), 1.0)
		mb.add_cylinder(gold, M.xf(M.v3(q + cn * -0.5, ty + 1.2)), 0.08, 0.06, 7.0, 5, 1.0)
		mb.add_box_unit_uv(S._banner_m(), Transform3D(Basis(Vector3.UP, M.yaw_of(cn) + PI * 0.5), M.v3(q + cn * -0.5, ty + 7.0)) * Transform3D(Basis(), Vector3(1.3, 0, 0)), Vector3(2.6, 1.7, 0.04))
	CapitalShell._piece(out, "DressKeep", mb, _cols, RANGE, false)


## A tall shelf against a wall (its back to -f... it faces f): rows of ledgers and rolled charts, a ladder.
static func _shelf(mb: MeshBuilder, q: Vector2, y: float, f: Vector2, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks_dark")
	var t := M.xf(M.v3(q, y), M.yaw_of(f))
	for sx: float in [-1.4, 1.4]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(sx, 1.6, 0)), Vector3(0.1, 3.2, 0.6), 1.0)
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 1.6, -0.28)), Vector3(2.8, 3.2, 0.04), 1.0)
	var cols := [Color(0.5, 0.2, 0.15), Color(0.2, 0.28, 0.5), Color(0.3, 0.4, 0.25), Color(0.55, 0.45, 0.3)]
	for row in range(4):
		var sy := 0.3 + row * 0.8
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, sy, 0)), Vector3(2.8, 0.06, 0.58), 1.0)
		var x := -1.25
		while x < 1.2:
			var w := rng.randf_range(0.08, 0.16)
			if rng.randf() < 0.2:
				mb.add_cylinder(PSXMat.lit("canvas", Color(0.95, 0.9, 0.75)), t * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x + 0.25, sy + 0.1, 0.05)), 0.07, 0.07, 0.5, 5, 1.0)
				x += 0.55
				continue
			var hh := rng.randf_range(0.4, 0.62)
			mb.add_box(PSXMat.lit("leather", cols[rng.randi() % cols.size()]), t * Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), Vector3(x + w * 0.5, sy + 0.03 + hh * 0.5, 0.0)), Vector3(w, hh, 0.4), 1.0)
			x += w + 0.01
	M.box(_cols, t * Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(2.9, 3.2, 0.6))


## A clerk's desk facing f: its top, drawers, a chair, papers, an inkwell, a lamp, a stack of ledgers.
static func _desk(mb: MeshBuilder, q: Vector2, y: float, f: Vector2, rng: RandomNumberGenerator) -> void:
	var wood := PSXMat.lit("planks_dark")
	var t := M.xf(M.v3(q, y), M.yaw_of(f))
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, 0.76, 0)), Vector3(1.8, 0.08, 0.9), 1.0)
	for sx: float in [-0.75, 0.75]:
		mb.add_box(wood, t * Transform3D(Basis(), Vector3(sx, 0.37, 0)), Vector3(0.3, 0.74, 0.8), 1.0, Color(0.85, 0.85, 0.85))
	for k in range(4):
		mb.add_box(PSXMat.lit("canvas", Color(0.96, 0.94, 0.86)), t * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), Vector3(rng.randf_range(-0.6, 0.5), 0.81 + k * 0.004, rng.randf_range(-0.2, 0.2))), Vector3(0.3, 0.004, 0.4), 1.0)
	mb.add_cylinder(S._iron_m(), t * Transform3D(Basis(), Vector3(0.6, 0.8, -0.25)), 0.05, 0.04, 0.08, 6, 1.0)
	mb.add_box(S._window_m(), t * Transform3D(Basis(), Vector3(-0.7, 0.95, -0.3)), Vector3(0.14, 0.24, 0.14), 1.0)
	for k in range(3):
		mb.add_box(PSXMat.lit("leather", Color(0.4, 0.22, 0.14)), t * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(0.45, 0.84 + k * 0.07, 0.25)), Vector3(0.36, 0.06, 0.26), 1.0)
	# the chair
	var ct := t * Transform3D(Basis(), Vector3(0, 0, 0.8))
	mb.add_box(wood, ct * Transform3D(Basis(), Vector3(0, 0.46, 0)), Vector3(0.5, 0.06, 0.5), 1.0)
	mb.add_box(wood, ct * Transform3D(Basis(), Vector3(0, 0.8, 0.23)), Vector3(0.5, 0.7, 0.06), 1.0)
	for cn: Vector2 in [Vector2(-0.2, -0.2), Vector2(0.2, -0.2), Vector2(-0.2, 0.2), Vector2(0.2, 0.2)]:
		mb.add_box(wood, ct * Transform3D(Basis(), Vector3(cn.x, 0.22, cn.y)), Vector3(0.05, 0.44, 0.05), 1.0)
	M.box(_cols, t * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(1.8, 0.8, 0.9))


# --------------------------------------------------------------------------
# The halls: the Mess and the Barracks lived in
# --------------------------------------------------------------------------
## The Mess Hall: plates, mugs, bread and a pot on its tables, a kitchen along the back wall (a range with pots, a
## counter with sacks and a chopping block, hanging pans), barrels of water and kegs of rum. The Barracks: a footlocker
## at each bunk, blankets, coats on pegs, a card table, a rack of muskets, a notice board of postings.
static func _halls(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var rng := _rng(7501)
	var wood := PSXMat.lit("planks_dark")
	var iron := S._iron_m()
	var pewter := PSXMat.lit("metal", Color(0.7, 0.72, 0.75))
	# the mess
	var mr: Rect2 = (P.ROOMS[0][2] as Rect2).grow(-1.2)
	var my: float = P.ROOMS[0][3]
	var mc := mr.get_center()
	for z: float in [-6.0, 0.0, 6.0]:
		for k in range(8):
			var q := mc + Vector2(-7.0 + k * 1.7 + rng.randf_range(-0.2, 0.2), z + (0.45 if k % 2 == 0 else -0.45))
			mb.add_cylinder(pewter, M.xf(M.v3(q, my + 0.88)), 0.2, 0.22, 0.03, 8, 1.0)
			if rng.randf() < 0.6:
				mb.add_cylinder(pewter, M.xf(M.v3(q + Vector2(0.3, 0), my + 0.88)), 0.06, 0.07, 0.16, 6, 1.0)
			if rng.randf() < 0.3:
				mb.add_blob(PSXMat.lit("straw", Color(0.85, 0.6, 0.35)), M.xf(M.v3(q, my + 0.92)), Vector3(0.14, 0.08, 0.1), rng, 0.1, 2, 5, 1.0)
		mb.add_cylinder(iron, M.xf(M.v3(mc + Vector2(rng.randf_range(-4.0, 3.0), z), my + 0.88)), 0.3, 0.26, 0.35, 8, 1.0)
	# the kitchen along the north wall (the door is east, the hearth west)
	var kz := mr.position.y + 0.6
	var range_q := Vector2(mc.x - 4.0, kz)
	_slab(mb, S._dark_m(), M.xf(M.v3(range_q, my + 0.5)), Vector3(3.6, 1.0, 1.2))
	mb.add_box(PSXMat.glow(Color(1.0, 0.45, 0.15), 2.0), M.xf(M.v3(range_q + Vector2(0, 0.62), my + 0.4)), Vector3(1.2, 0.4, 0.04), 1.0)
	for k in range(3):
		mb.add_cylinder(iron, M.xf(M.v3(range_q + Vector2(-1.1 + k * 1.1, 0), my + 1.0)), 0.3, 0.32, 0.4, 8, 1.0)
	mb.add_box(S._soot_m(), M.xf(M.v3(range_q, my + 3.5)), Vector3(1.4, 5.0, 1.0), 0.5)
	var counter := Vector2(mc.x + 3.0, kz)
	_slab(mb, wood, M.xf(M.v3(counter, my + 0.45)), Vector3(5.0, 0.9, 1.0))
	mb.add_box(wood, M.xf(M.v3(counter + Vector2(1.6, 0), my + 0.98)), Vector3(0.7, 0.15, 0.5), 1.0, Color(0.8, 0.7, 0.55))
	for k in range(3):
		mb.add_blob(PSXMat.lit("canvas", Color(0.8, 0.74, 0.6)), M.xf(M.v3(counter + Vector2(-1.8 + k * 0.6, 0), my + 0.9)), Vector3(0.25, 0.35, 0.22), rng, 0.15, 3, 6, 1.0, Color.WHITE, true)
	mb.add_box(iron, M.xf(M.v3(counter + Vector2(0, -0.4), my + 2.2)), Vector3(4.0, 0.06, 0.06), 1.0)
	for k in range(5):
		var hq := counter + Vector2(-1.6 + k * 0.8, -0.35)
		mb.add_box(iron, M.xf(M.v3(hq, my + 1.95)), Vector3(0.03, 0.4, 0.03), 1.0)
		mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), M.v3(hq, my + 1.6)), 0.18, 0.18, 0.05, 8, 1.0)
	for q: Vector2 in [Vector2(mr.end.x - 1.0, mr.position.y + 1.0), Vector2(mr.end.x - 1.0, mr.end.y - 1.0)]:
		_put("ward", "barrel", q, my, rng.randf() * TAU, Vector3(0.72, 1.0, 0.72))
		_put("ward", "keg", q + Vector2(-1.0, 0), my, rng.randf() * TAU, Vector3(0.56, 0.7, 0.56))
	# the barracks
	var br: Rect2 = (P.ROOMS[1][2] as Rect2).grow(-1.2)
	var by: float = P.ROOMS[1][3]
	var bc := br.get_center()
	var blanket := PSXMat.lit("fabric", Color(0.3, 0.36, 0.6))
	var n := int(br.size.x / 2.6)
	for k in range(n):
		var x := br.position.x + (k + 0.5) * br.size.x / n
		for s: float in [-1.0, 1.0]:
			var b := Vector2(x, bc.y + s * (br.size.y * 0.5 - 1.1))
			for lv: float in [0.5, 1.9]:
				mb.add_box(blanket, M.xf(M.v3(b, by + lv + 0.15)), Vector3(0.9, 0.1, 1.5), 1.0)
				mb.add_box(PSXMat.lit("canvas", Color(0.95, 0.95, 0.92)), M.xf(M.v3(b + Vector2(0, s * 0.75), by + lv + 0.2)), Vector3(0.7, 0.12, 0.35), 1.0)
			# a footlocker at the bunk's foot (inward), a coat on the peg over it
			var lq := b - Vector2(0, s * 1.5)
			if Vector2(lq.x, lq.y).distance_to(StrongholdActs.SUPPLY_AT) > 2.0 and lq.distance_to(Vector2(22.0, 1.0)) > 4.0:
				_put("ward", "locker", lq, by, 0.0 if s < 0.0 else PI, Vector3(0.9, 0.5, 0.5))
			mb.add_box(PSXMat.lit("fabric", Color(0.9, 0.92, 0.96) if k % 2 == 0 else Color(0.25, 0.3, 0.55)), M.xf(M.v3(b + Vector2(0.55, s * 0.95), by + 1.5)), Vector3(0.1, 1.0, 0.55), 1.0)
	var ct := Vector2(bc.x + 2.0, bc.y)
	if ct.distance_to(StrongholdActs.SUPPLY_AT) > 3.0:
		_slab(mb, wood, M.xf(M.v3(ct, by + 0.74)), Vector3(1.6, 0.08, 1.2))
		for cn: Vector2 in [Vector2(-0.7, -0.5), Vector2(0.7, -0.5), Vector2(-0.7, 0.5), Vector2(0.7, 0.5)]:
			mb.add_box(wood, M.xf(M.v3(ct + cn, by + 0.36)), Vector3(0.08, 0.72, 0.08), 1.0)
		for k in range(7):
			mb.add_box(PSXMat.lit("canvas", Color(0.96, 0.95, 0.9)), M.xf(M.v3(ct + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4)), by + 0.79), rng.randf() * TAU), Vector3(0.12, 0.004, 0.18), 1.0)
		for s: float in [-1.0, 1.0]:
			_put("ward", "stool", ct + Vector2(s * 1.2, 0), by, 0.0, Vector3(0.4, 0.45, 0.4))
	# banners high on both halls' long walls inside, a lantern bracket between each pair
	for e in [[mr, my], [br, by]]:
		var r: Rect2 = e[0]
		var fy: float = e[1]
		for f: float in [-1.0, 1.0]:
			var wz := r.get_center().y + f * (r.size.y * 0.5 - 0.02)
			for s: float in [-1.0, 1.0]:
				S._banner(mb, Vector2(r.get_center().x + s * 5.0, wz), fy + 8.6, Vector2(0, -f), 2.6, 4.2)
			mb.add_box(iron, M.xf(M.v3(Vector2(r.get_center().x, wz - f * 0.3), fy + 4.0)), Vector3(0.1, 0.1, 0.6), 1.0)
			mb.add_box(S._window_m(), M.xf(M.v3(Vector2(r.get_center().x, wz - f * 0.6), fy + 3.8)), Vector3(0.26, 0.36, 0.26), 1.0)
	_put("ward", "rack", Vector2(br.end.x - 0.4, bc.y - 4.0), by, -PI * 0.5, Vector3(0.4, 1.8, 1.6))
	_put("ward", "board", Vector2(br.end.x - 0.25, bc.y + 4.0), by, -PI * 0.5)
	CapitalShell._piece(out, "DressHalls", mb, _cols, 140.0, false)


# --------------------------------------------------------------------------
# The batteries
# --------------------------------------------------------------------------
## Rows of guns: along the Landing's quay front facing the sea (between the docks, the berth and the boat lanes), on
## the sea walls' tops, along the keep's front wall facing the ward; shot stacks and powder kegs behind them, sandbags.
static func _batteries(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var rng := _rng(7601)
	var y := P.QUAY_Y
	var x := -52.0
	while x <= 52.0:
		var q := Vector2(x, P.FRONT_Z - 2.6)
		if clear_at(q, 1.0) and absf(x - P.BERTH.x) > 13.0 and absf(x + 36.0) > 4.0 and absf(x - 42.0) > 4.0 and absf(x + 30.0) > 5.0 and absf(x - 52.0) > 5.0:
			_put("landing", "cannon", q, y, 0.0, Vector3(1.2, 1.1, 2.4))
			if rng.randf() < 0.6 and clear_at(q + Vector2(1.3, -1.6), 0.4):
				_put("landing", "shot", q + Vector2(1.3, -1.6), y, 0.0, Vector3(0.8, 0.5, 0.8))
		x += 5.0
	# the sea walls' tops: a gun at every other embrasure, pointing out
	var g1 := Vector2(P.BERTH.x - S.SEA_GATE_GAP * 0.5 - 6.0, S.SEA_GATE_Z)
	var g2 := Vector2(P.BERTH.x + S.SEA_GATE_GAP * 0.5 + 6.0, S.SEA_GATE_Z)
	for e in [[g1, Vector2(-58.0, P.FRONT_Z)], [g2, Vector2(58.0, P.FRONT_Z)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var dir := (b - a).normalized()
		var outd := Vector2(-dir.y, dir.x)
		if outd.dot(Vector2(0, 1)) < 0.0:
			outd = -outd
		var L := a.distance_to(b)
		var k := 10.0
		while k < L - 6.0:
			_put("landing", "cannon", a + dir * k + outd * 0.2, P.QUAY_Y + 10.0, M.yaw_of(outd))
			k += 6.0
	# the keep's front wall facing the ward: guns on its walk between the gate and the corner towers
	var ky: float = P.DISTRICTS[4][2]
	for gx: float in [-36.0, -30.0, -22.0, 22.0, 30.0, 36.0]:
		_put("keep", "cannon", Vector2(gx, -49.2), ky + 6.0, 0.0, Vector3(1.2, 1.1, 2.0))
	# sandbag walls round the ward's guns-in-waiting, shot stacks and powder kegs by the arsenal's sheds
	for q: Vector2 in [Vector2(-26.0, -8.0), Vector2(30.0, 16.0), Vector2(-60.0, 10.0), Vector2(70.0, -44.0)]:
		var yy := P.ground(q)
		if clear_at(q, 2.0):
			_put(_district(q), "sandbags", q, yy, rng.randf_range(-0.4, 0.4), Vector3(2.4, 0.9, 0.9))
			_put(_district(q), "shot", q + Vector2(0, 1.4), yy, 0.0, Vector3(0.8, 0.5, 0.8))
	for q: Vector2 in [Vector2(58.0, -44.0), Vector2(104.0, -40.0), Vector2(58.0, 12.0)]:
		if clear_at(q, 1.4):
			_put("arsenal", "keg", q, 14.0, rng.randf() * TAU, Vector3(0.56, 0.7, 0.56))
			_put("arsenal", "keg", q + Vector2(0.6, 0.3), 14.0, rng.randf() * TAU, Vector3(0.56, 0.7, 0.56))
			_put("arsenal", "shot", q + Vector2(-0.8, 0.8), 14.0, 0.0, Vector3(0.8, 0.5, 0.8))
	CapitalShell._piece(out, "DressBatteries", mb, _cols, RANGE, false)


# --------------------------------------------------------------------------
# The Lower Ward's plaza
# --------------------------------------------------------------------------
## The hub lived in: a colonnaded portico along each hall's front (white columns on navy plinths, gold capitals, an
## entablature and a navy tiled lean-to roof back to the hall), lamp posts and flags round the plaza, a drill corner
## (dummies, a rack, a sergeant's board), a marines' tent, laundry strung over the strips behind the halls, cargo.
static func _ward(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var y := 12.0
	var rng := _rng(7701)
	var stone := S._wall_m()
	var trim := S._trim_m()
	var gold := S._gold_m()
	for rm in [P.ROOMS[0], P.ROOMS[1]]:
		var r: Rect2 = rm[2]
		var door: Vector2 = rm[5]
		var fx: float = r.end.x if door.x > 0.0 else r.position.x
		var cx := fx + door.x * 1.6
		var top := y + 6.4
		var z := r.position.y + 1.6
		var cols_at: Array = []
		while z <= r.end.y - 1.0:
			if clear_at(Vector2(cx, z), 0.4):
				cols_at.append(z)
			z += 4.2
		for cz: float in cols_at:
			var q := Vector2(cx, cz)
			mb.add_box(trim, M.xf(M.v3(q, y + 0.35)), Vector3(1.0, 0.7, 1.0), 0.5)
			mb.add_cylinder(stone, M.xf(M.v3(q, y + 0.7)), 0.38, 0.32, top - y - 1.4, 10, 0.5, Color.WHITE, false)
			mb.add_box(gold, M.xf(M.v3(q, top - 0.55)), Vector3(0.9, 0.16, 0.9), 1.0)
			mb.add_box(stone, M.xf(M.v3(q, top - 0.35)), Vector3(1.0, 0.3, 1.0), 0.5)
			M.cyl(_cols, M.v3(q, y), 0.4, top - y)
		if cols_at.is_empty():
			continue
		var z0: float = cols_at[0] - 0.8
		var z1: float = cols_at[-1] + 0.8
		var mid := Vector2((cx + fx) * 0.5, (z0 + z1) * 0.5)
		mb.add_box(stone, M.xf(M.v3(Vector2(cx, mid.y), top + 0.3)), Vector3(1.1, 0.8, z1 - z0), 0.5)
		mb.add_box(trim, M.xf(M.v3(Vector2(cx, mid.y), top + 0.75)), Vector3(1.2, 0.14, z1 - z0 + 0.1), 0.5)
		var run := absf(cx - fx)
		mb.add_box(S._roof_m(), Transform3D(Basis(Vector3.BACK, door.x * -0.3), M.v3(mid, top + 1.15)), Vector3(run + 0.9, 0.12, z1 - z0 + 0.4), 0.5)
		mb.add_box(S._dark_m(), Transform3D(Basis(Vector3.BACK, door.x * -0.3), M.v3(mid, top + 1.05)), Vector3(run + 0.9, 0.06, z1 - z0 + 0.4), 0.5)
		# a bench and a barrel under it, against the hall
		for bz: float in [z0 + 2.2, z1 - 2.2]:
			var bq := Vector2(fx + door.x * 0.75, bz)
			if clear_at(bq, 0.2):
				_put("ward", "bench", bq, y, PI * 0.5, Vector3(1.8, 0.5, 0.4))
	# lamps and flags round the plaza
	for q: Vector2 in [Vector2(-14.0, 17.0), Vector2(14.0, 17.0), Vector2(-14.0, -11.0), Vector2(14.0, -11.0), Vector2(-6.0, 9.0), Vector2(6.0, -2.0)]:
		if clear_at(q, 0.4):
			_put("ward", "lamp", q, y, 0.0, Vector3(0.6, 3.6, 0.6))
	for q: Vector2 in [Vector2(-10.0, 17.4), Vector2(10.0, 17.4), Vector2(-6.0, -11.2), Vector2(6.0, -11.2)]:
		if clear_at(q, 0.4):
			_put("ward", "flag", q, y, 0.0, Vector3(0.6, 9.0, 0.6))
	# the drill corner: straw dummies, a rack, the sergeant's board
	for q: Vector2 in [Vector2(-5.0, 14.0), Vector2(-2.0, 14.6), Vector2(4.0, -5.0)]:
		if clear_at(q, 0.4):
			_put("ward", "dummy", q, y, rng.randf_range(-0.4, 0.4), Vector3(0.5, 1.8, 0.5))
	for q: Vector2 in [Vector2(-8.0, 15.6), Vector2(-14.0, -5.0)]:
		if clear_at(q, 0.6):
			_put("ward", "rack", q, y, 0.0, Vector3(1.6, 1.6, 0.4))
	if clear_at(Vector2(4.0, 15.0), 0.6):
		_put("ward", "board", Vector2(4.0, 15.0), y, PI, Vector3(2.0, 2.4, 0.4))
	for q: Vector2 in [Vector2(-4.0, -6.0), Vector2(16.0, 15.2), Vector2(-16.0, 14.6)]:
		_cargo("ward", q, y, rng, 4)
	# laundry over the strips behind the halls (overhead, nothing in the way below)
	for rm in [P.ROOMS[0], P.ROOMS[1]]:
		var r: Rect2 = rm[2]
		var wz := r.position.y - 0.7
		_laundry(mb, Vector2(r.position.x + 2.0, wz), Vector2(r.end.x - 2.0, wz), y + 4.2, rng)
	# the marines' tent on the Landing's west quay, sandbags in front
	var tq := Vector2(-52.0, 40.0)
	if clear_at(tq, 2.0):
		_put("landing", "tent", tq, P.QUAY_Y, PI * 0.5, Vector3(3.2, 2.4, 4.0))
	CapitalShell._piece(out, "DressWard", mb, _cols, RANGE, false)


## A line strung from a to b at height h: white shirts, navy trousers and caps pegged along it.
static func _laundry(mb: MeshBuilder, a: Vector2, b: Vector2, h: float, rng: RandomNumberGenerator) -> void:
	var rope := PSXMat.lit("rope")
	var pts := PackedVector3Array()
	for k in range(9):
		var u := k / 8.0
		pts.append(M.v3(a.lerp(b, u), h - sin(u * PI) * 0.5))
	mb.add_tube(rope, pts, 0.025, 0.025, 4, 2.0)
	var L := a.distance_to(b)
	var x := 0.8
	while x < L - 0.8:
		var u := x / L
		var p := M.v3(a.lerp(b, u), h - sin(u * PI) * 0.5)
		var white := rng.randf() < 0.6
		var w := rng.randf_range(0.5, 0.8)
		var hh := rng.randf_range(0.5, 0.9)
		mb.add_box(PSXMat.lit("fabric", Color(0.94, 0.95, 0.97) if white else Color(0.22, 0.28, 0.55)), Transform3D(Basis(Vector3.UP, M.yaw_of(b - a) + PI * 0.5), p - Vector3(0, hh * 0.5, 0)), Vector3(w, hh, 0.03), 1.0)
		x += w + rng.randf_range(0.3, 1.0)


# --------------------------------------------------------------------------
# The wall galleries: new ways along the walls
# --------------------------------------------------------------------------
## Timber galleries on iron brackets along the inside of the Arsenal's and the Prison's outer walls, GALLERY_DROP under
## the walk (a captain grappled up onto the wall's top steps down onto one), railed on the open side, each with a stair
## down to the yard at one end: a high way round each yard over the garrison's heads, a sneaking route of their own.
const GALLERY_DROP := 1.4
## [district, the wall's inner face x, inward, from z, to z (clear of the towers on the wall), the stair's foot z].
const GALLERIES := [["arsenal", 107.4, -1.0, -12.4, 8.0, 0.0], ["prison", -107.4, 1.0, -38.0, 8.5, -24.0]]


static func _galleries(out: Array) -> void:
	var mb := MeshBuilder.new()
	_cols = []
	var wood := PSXMat.lit("planks_dark")
	var iron := S._iron_m()
	for g: Array in GALLERIES:
		var district: String = g[0]
		var wx: float = g[1]
		var inn: float = g[2]
		var z0: float = g[3]
		var z1: float = g[4]
		var foot_z: float = g[5]
		var fy: float = float(P.DISTRICTS[P.district_at(Vector2(wx + inn * 3.0, 0.0))][2])
		var gy := fy + 6.0 - GALLERY_DROP
		var w := 1.6
		var gx := wx + inn * w * 0.5
		_slab(mb, wood, M.xf(M.v3(Vector2(gx, (z0 + z1) * 0.5), gy - 0.1)), Vector3(w, 0.2, z1 - z0))
		for k in range(int((z1 - z0) / 0.5)):
			mb.add_box(wood, M.xf(M.v3(Vector2(gx, z0 + (k + 0.5) * 0.5), gy + 0.01)), Vector3(w - 0.1, 0.02, 0.44), 1.0, Color(0.85, 0.8, 0.75) if k % 2 == 0 else Color.WHITE)
		# brackets into the wall, a rail on the open side (solid) with posts
		var rx := wx + inn * (w - 0.08)
		var z := z0
		while z <= z1 + 0.01:
			var a := Vector3(wx, gy - 1.4, z)
			var b := Vector3(rx, gy - 0.2, z)
			mb.add_box(iron, Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5), Vector3(0.12, 0.12, a.distance_to(b)), 1.0)
			mb.add_box(wood, M.xf(Vector3(rx, gy + 0.5, z)), Vector3(0.12, 1.0, 0.12), 1.0)
			z += 2.0
		# (the rail open where the stair comes up)
		var gap0 := foot_z - 1.2 - (gy - fy) / tan(deg_to_rad(36.0))
		for seg in [[z0, gap0 - 1.0], [gap0 + 1.4, z1]]:
			var a0: float = seg[0]
			var a1: float = seg[1]
			if a1 - a0 < 0.5:
				continue
			mb.add_box(wood, M.xf(Vector3(rx, gy + 1.0, (a0 + a1) * 0.5)), Vector3(0.1, 0.1, a1 - a0), 1.0)
			M.box(_cols, M.xf(Vector3(rx, gy + 0.55, (a0 + a1) * 0.5)), Vector3(0.12, 1.1, a1 - a0))
		# the stair: from the yard at foot_z up toward -z along the gallery's open side, onto it
		var sx := wx + inn * (w + 0.75)
		var run := (gy - fy) / tan(deg_to_rad(36.0))
		var sa := Vector3(sx, fy, foot_z)
		var sb := Vector3(sx, gy, foot_z - run)
		var slope := atan2(gy - fy, run)
		M.box(_cols, Transform3D(Basis(Vector3.RIGHT, slope), (sa + sb) * 0.5), Vector3(1.4, 0.2, sqrt(run * run + (gy - fy) * (gy - fy))))
		var steps := int((gy - fy) / 0.22)
		for k in range(steps):
			var u := (k + 0.5) / steps
			var p := sa.lerp(sb, u)
			mb.add_box(wood, M.xf(p + Vector3(0, -0.04, 0)), Vector3(1.4, 0.12, run / steps + 0.03), 1.0)
		for s: float in [-1.0, 1.0]:
			var a := sa + Vector3(s * 0.72, 0.9, 0)
			var b := sb + Vector3(s * 0.72, 0.9, 0)
			mb.add_box(wood, Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5), Vector3(0.08, 0.08, a.distance_to(b)), 1.0)
		for k in range(3):
			var p := sa.lerp(sb, k / 2.0)
			mb.add_box(wood, M.xf(Vector3(sx + inn * 0.72, (fy + p.y) * 0.5 + 0.4, p.z)), Vector3(0.12, p.y - fy + 0.8, 0.12), 1.0)
		# a landing between the stair's head and the gallery
		_slab(mb, wood, M.xf(Vector3((sx + gx) * 0.5, gy - 0.1, sb.z - 0.7)), Vector3(absf(sx - gx) + 1.4, 0.2, 1.4))
		# a lantern on the gallery and a pair of barrels on it
		mb.add_box(S._window_m(), M.xf(Vector3(wx + inn * 0.2, gy + 2.0, (z0 + z1) * 0.5)), Vector3(0.3, 0.4, 0.3), 1.0)
		_put(district, "keg", Vector2(gx, z1 - 1.0), gy, 0.0, Vector3(0.56, 0.7, 0.56))
	CapitalShell._piece(out, "DressGalleries", mb, _cols, RANGE, false)


static func _district(q: Vector2) -> String:
	var i := P.district_at(q)
	return str(P.DISTRICTS[i][0]) if i >= 0 else "landing"


static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


# --------------------------------------------------------------------------
# The repeated props' models (one mesh each; MultiMesh per district)
# --------------------------------------------------------------------------
## [{"name", "mesh", "xforms", "range"}] per kind and district.
static func _prop_specs() -> Array:
	var out: Array = []
	for kind in _placed:
		var mesh := _model(str(kind))
		var by := {}
		for e: Array in _placed[kind]:
			if not by.has(e[0]):
				by[e[0]] = []
			(by[e[0]] as Array).append(e[1])
		for d in by:
			out.append({"name": "Props_%s_%s" % [d, kind], "mesh": mesh, "xforms": by[d], "range": PROP_RANGE if kind != "flag" else 600.0})
	return out


static func _model(kind: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var crate := PSXMat.lit("planks_weathered")
	var iron := S._iron_m()
	var gold := S._gold_m()
	var trim := S._trim_m()
	var stone := S._wall_m()
	var navy := PSXMat.lit("planks", Color(0.3, 0.38, 0.66))
	var rng := _rng(hash(kind))
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	match kind:
		"cannon":
			# a naval gun on a navy-painted truck carriage, muzzle to +Z
			for s: float in [-1.0, 1.0]:
				var cheek := PackedVector2Array([Vector2(-1.0, 0.25), Vector2(0.9, 0.25), Vector2(0.9, 0.62), Vector2(0.3, 0.62), Vector2(0.3, 0.8), Vector2(-0.3, 0.8), Vector2(-0.3, 0.95), Vector2(-1.0, 0.95)])
				mb.add_extrude(navy, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(s * 0.36, 0, 0)), cheek, 0.12, 1.0)
				for wz: float in [-0.75, 0.6]:
					mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.52, 0.26, wz)), 0.26, 0.26, 0.12, 8, 1.0, Color(0.6, 0.5, 0.4), true, true)
			for wz: float in [-0.75, 0.6]:
				mb.add_box(wood, M.xf(Vector3(0, 0.26, wz)), Vector3(1.0, 0.1, 0.1), 1.0)
			mb.add_box(navy, M.xf(Vector3(0, 0.3, -0.05)), Vector3(0.6, 0.12, 1.8), 1.0)
			var bt := Transform3D(along_z, Vector3(0, 0.9, -0.9))
			mb.add_cylinder(iron, bt, 0.26, 0.2, 1.4, 10, 1.0, Color.WHITE, false)
			mb.add_cylinder(iron, bt * Transform3D(Basis(), Vector3(0, 1.4, 0)), 0.2, 0.17, 0.9, 10, 1.0, Color.WHITE, false)
			mb.add_cylinder(iron, bt * Transform3D(Basis(), Vector3(0, 2.3, 0)), 0.22, 0.22, 0.14, 10, 1.0, Color.WHITE, true)
			mb.add_cylinder(PSXMat.flat(Color(0.03, 0.03, 0.03)), bt * Transform3D(Basis(), Vector3(0, 2.3, 0)), 0.1, 0.1, 0.15, 8, 1.0, Color.WHITE, true)
			for ry: float in [0.1, 0.7, 1.4]:
				mb.add_cylinder(gold, bt * Transform3D(Basis(), Vector3(0, ry, 0)), 0.28 - ry * 0.04, 0.28 - ry * 0.04, 0.06, 10, 1.0)
			mb.add_blob(iron, Transform3D(Basis(), Vector3(0, 0.9, -1.05)), Vector3(0.1, 0.1, 0.12), rng, 0.0, 3, 6, 1.0)
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.36, 0.9, -0.3)), 0.06, 0.06, 0.72, 6, 1.0)
		"crate":
			mb.add_box_unit_uv(crate, M.xf(Vector3(0, 0.5, 0)), Vector3(1.0, 1.0, 1.0))
			for e in [Vector3(1.02, 0.08, 0.08), Vector3(0.08, 0.08, 1.02)]:
				for yy: float in [0.06, 0.94]:
					for s: float in [-1.0, 1.0]:
						var o := Vector3(0, yy, s * 0.48) if e.x > 0.5 else Vector3(s * 0.48, yy, 0)
						mb.add_box(wood, M.xf(o), e, 1.0)
			mb.add_box(trim, M.xf(Vector3(0, 0.5, 0.505)), Vector3(0.5, 0.22, 0.01), 1.0)
		"barrel", "keg":
			var dark := kind == "keg"
			var hh := 0.7 if dark else 1.0
			var rr := 0.26 if dark else 0.34
			var bw := PSXMat.lit("planks", Color(0.42, 0.3, 0.22) if dark else Color(0.75, 0.6, 0.45))
			mb.add_cylinder(bw, M.xf(Vector3.ZERO), rr * 0.86, rr, hh * 0.5, 10, 1.0, Color.WHITE, false)
			mb.add_cylinder(bw, M.xf(Vector3(0, hh * 0.5, 0)), rr, rr * 0.86, hh * 0.5, 10, 1.0, Color.WHITE, true)
			for yy: float in [0.12, 0.5, 0.88]:
				mb.add_cylinder(iron, M.xf(Vector3(0, hh * yy - 0.03, 0)), rr * (0.88 if yy != 0.5 else 1.0) + 0.015, rr * (0.88 if yy != 0.5 else 1.0) + 0.015, 0.06, 10, 1.0, Color.WHITE, false)
			if dark:
				mb.add_box(PSXMat.flat(Color(0.9, 0.88, 0.8)), M.xf(Vector3(0, hh * 0.5, rr + 0.005)), Vector3(0.2, 0.14, 0.01), 1.0)
		"shot":
			# cannonballs in a pyramid on a timber frame
			mb.add_box(wood, M.xf(Vector3(0, 0.05, 0)), Vector3(0.8, 0.1, 0.8), 1.0)
			var lv := [[3, 0.0], [2, 0.17], [1, 0.34]]
			for e in lv:
				var nn: int = e[0]
				for i in range(nn):
					for j in range(nn):
						mb.add_blob(iron, M.xf(Vector3((i - (nn - 1) * 0.5) * 0.22, 0.2 + float(e[1]), (j - (nn - 1) * 0.5) * 0.22)), Vector3(0.11, 0.11, 0.11), rng, 0.0, 3, 6, 1.0, Color(0.6, 0.6, 0.65))
		"sandbags":
			for row in range(2):
				for i in range(5 - row):
					mb.add_blob(PSXMat.lit("canvas", Color(0.72, 0.66, 0.5)), M.xf(Vector3((i - (4 - row) * 0.5) * 0.48, 0.16 + row * 0.28, 0), rng.randf_range(-0.1, 0.1)), Vector3(0.26, 0.15, 0.38), rng, 0.12, 3, 6, 1.0, Color(rng.randf_range(0.85, 1.0), 1, 1), true)
		"lamp":
			# a white stone plinth, an iron post, a lantern with a gold cap and its glass lit
			mb.add_box(stone, M.xf(Vector3(0, 0.3, 0)), Vector3(0.6, 0.6, 0.6), 1.0)
			mb.add_box(trim, M.xf(Vector3(0, 0.62, 0)), Vector3(0.66, 0.08, 0.66), 1.0)
			mb.add_cylinder(iron, M.xf(Vector3(0, 0.66, 0)), 0.09, 0.06, 2.6, 6, 1.0)
			mb.add_box(iron, M.xf(Vector3(0, 3.2, 0)), Vector3(0.44, 0.06, 0.44), 1.0)
			mb.add_box(S._window_m(), M.xf(Vector3(0, 3.45, 0)), Vector3(0.32, 0.44, 0.32), 1.0)
			for cn: Vector2 in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(0.19, 0.19), Vector2(-0.19, 0.19)]:
				mb.add_box(iron, M.xf(Vector3(cn.x, 3.45, cn.y)), Vector3(0.04, 0.48, 0.04), 1.0)
			mb.add_pyramid_roof(gold, M.xf(Vector3(0, 3.69, 0)), 0.46, 0.46, 0.22, 0.04, 1.0)
		"flag":
			# a tall white flagstaff on a stepped base, a gold ball, the Admiralty's flag
			mb.add_box(stone, M.xf(Vector3(0, 0.2, 0)), Vector3(1.0, 0.4, 1.0), 1.0)
			mb.add_box(trim, M.xf(Vector3(0, 0.5, 0)), Vector3(0.6, 0.2, 0.6), 1.0)
			mb.add_cylinder(stone, M.xf(Vector3(0, 0.6, 0)), 0.09, 0.06, 8.4, 6, 1.0)
			mb.add_blob(gold, M.xf(Vector3(0, 9.05, 0)), Vector3(0.14, 0.14, 0.14), rng, 0.0, 3, 6, 1.0)
			mb.add_box_unit_uv(S._banner_m(), M.xf(Vector3(1.3, 7.8, 0)), Vector3(2.4, 1.6, 0.04))
		"bollard":
			mb.add_cylinder(iron, M.xf(Vector3.ZERO), 0.22, 0.18, 0.55, 8, 1.0, Color.WHITE, false)
			mb.add_cylinder(iron, M.xf(Vector3(0, 0.55, 0)), 0.28, 0.28, 0.1, 8, 1.0)
		"coil":
			var pts := PackedVector3Array()
			for k in range(26):
				var a := TAU * k / 8.0
				var rr := 0.35 - k * 0.006
				pts.append(Vector3(cos(a) * rr, 0.05 + k * 0.006, sin(a) * rr))
			mb.add_tube(PSXMat.lit("rope"), pts, 0.05, 0.05, 4, 2.0)
		"board":
			# a notice board of wanted posters under a little navy roof
			for s: float in [-1.0, 1.0]:
				mb.add_box(wood, M.xf(Vector3(s * 0.85, 1.1, 0)), Vector3(0.12, 2.2, 0.12), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 1.45, 0)), Vector3(1.8, 1.1, 0.06), 1.0)
			for s: float in [-1.0, 1.0]:
				mb.add_box_unit_uv(PSXMat.lit("admiralty_wanted", Color.WHITE, {"vertex_color": false}), Transform3D(Basis(Vector3.UP, 0.0 if s > 0.0 else PI), Vector3(0, 1.45, s * 0.04)), Vector3(1.6, 0.95, 0.01))
			mb.add_gable_roof(navy, M.xf(Vector3(0, 2.2, 0), PI * 0.5), 0.5, 2.0, 0.2, 0.1, 1.0)
		"cart":
			for s: float in [-1.0, 1.0]:
				mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.62, 0.42, 0.2)), 0.42, 0.42, 0.08, 10, 1.0, Color(0.6, 0.5, 0.4), true, true)
				mb.add_box(wood, M.xf(Vector3(s * 0.3, 0.7, -1.2)), Vector3(0.06, 0.06, 1.2), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 0.72, 0.1)), Vector3(1.1, 0.08, 1.6), 1.0)
			for s: float in [-1.0, 1.0]:
				mb.add_box(wood, M.xf(Vector3(s * 0.54, 0.9, 0.1)), Vector3(0.06, 0.3, 1.6), 1.0)
			mb.add_box_unit_uv(crate, M.xf(Vector3(0.15, 1.06, 0.4)), Vector3(0.6, 0.6, 0.6))
			mb.add_blob(PSXMat.lit("canvas", Color(0.8, 0.74, 0.6)), M.xf(Vector3(-0.2, 0.9, -0.3)), Vector3(0.3, 0.25, 0.4), rng, 0.15, 3, 6, 1.0, Color.WHITE, true)
		"barrow", "orecart":
			var ore := kind == "orecart"
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.45, 0.22, 0.4)), 0.22, 0.22, 0.9, 8, 1.0, Color.WHITE, true, true)
			if ore:
				mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.45, 0.22, -0.4)), 0.22, 0.22, 0.9, 8, 1.0, Color.WHITE, true, true)
			mb.add_box(iron, M.xf(Vector3(0, 0.7, 0)), Vector3(0.9, 0.6, 1.3), 1.0, Color(0.6, 0.6, 0.62))
			mb.add_blob(PSXMat.lit("black_rock", Color(0.5, 0.36, 0.28) if ore else Color(0.2, 0.2, 0.22)), M.xf(Vector3(0, 1.0, 0)), Vector3(0.4, 0.2, 0.6), rng, 0.3, 3, 6, 1.0)
			if not ore:
				for s: float in [-1.0, 1.0]:
					mb.add_box(wood, M.xf(Vector3(s * 0.3, 0.6, -1.0)), Vector3(0.06, 0.06, 0.9), 1.0)
		"anvil":
			mb.add_box(wood, M.xf(Vector3(0, 0.3, 0)), Vector3(0.6, 0.6, 0.6), 1.0, Color(0.7, 0.6, 0.5))
			var av := PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.1), Vector2(0.45, 0.24), Vector2(-0.4, 0.24), Vector2(-0.4, 0.14), Vector2(-0.2, 0.08), Vector2(-0.2, -0.0)])
			mb.add_extrude(iron, M.xf(Vector3(0, 0.62, 0)), PackedVector2Array([Vector2(-0.18, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.12), Vector2(0.32, 0.28), Vector2(0.5, 0.3), Vector2(0.35, 0.38), Vector2(-0.38, 0.38), Vector2(-0.38, 0.28), Vector2(-0.18, 0.12)]), 0.26, 1.0)
			av.clear()
			mb.add_box(iron, M.xf(Vector3(0.2, 0.62, 0.32), 0.3), Vector3(0.05, 0.04, 0.4), 1.0)
		"moulds":
			for i in range(3):
				for j in range(2):
					mb.add_box(PSXMat.lit("black_rock", Color(0.5, 0.45, 0.42)), M.xf(Vector3(-0.5 + i * 0.5, 0.15 + j * 0.3, rng.randf_range(-0.1, 0.1)), rng.randf_range(-0.1, 0.1)), Vector3(0.44, 0.28, 0.9), 1.0)
					mb.add_box(PSXMat.flat(Color(0.12, 0.1, 0.1)), M.xf(Vector3(-0.5 + i * 0.5, 0.3 + j * 0.3, 0)), Vector3(0.24, 0.01, 0.6), 1.0)
		"ingots":
			mb.add_box(wood, M.xf(Vector3(0, 0.05, 0)), Vector3(1.2, 0.1, 0.8), 1.0)
			for row in range(4):
				for i in range(4 - row % 2):
					var o := Vector3(-0.42 + i * 0.28 + (row % 2) * 0.14, 0.15 + row * 0.12, 0)
					mb.add_box(iron, M.xf(o, PI * 0.5 * (row % 2)), Vector3(0.22, 0.11, 0.7) if row % 2 == 0 else Vector3(0.7, 0.11, 0.22), 1.0, Color(0.8, 0.78, 0.76))
		"toolrack":
			mb.add_box(wood, M.xf(Vector3(0, 1.0, -0.1)), Vector3(1.8, 2.0, 0.08), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 1.6, 0.0)), Vector3(1.8, 0.08, 0.2), 1.0)
			for k in range(6):
				var tx := -0.75 + k * 0.3
				mb.add_box(iron, M.xf(Vector3(tx, 1.15, 0.0), 0.0), Vector3(0.04, 0.9, 0.04), 1.0)
				match k % 3:
					0:
						mb.add_box(iron, M.xf(Vector3(tx, 0.68, 0.0)), Vector3(0.18, 0.12, 0.08), 1.0)
					1:
						mb.add_box(iron, M.xf(Vector3(tx, 0.7, 0.0)), Vector3(0.1, 0.06, 0.2), 1.0)
					_:
						mb.add_box(wood, M.xf(Vector3(tx, 0.62, 0.0)), Vector3(0.08, 0.2, 0.08), 1.0)
		"rack":
			# a weapon rack: muskets and pikes upright in a frame
			mb.add_box(wood, M.xf(Vector3(0, 0.1, 0)), Vector3(1.6, 0.12, 0.4), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 1.2, -0.1)), Vector3(1.6, 0.1, 0.2), 1.0)
			for s: float in [-1.0, 1.0]:
				mb.add_box(wood, M.xf(Vector3(s * 0.75, 0.75, 0)), Vector3(0.1, 1.5, 0.3), 1.0)
			for k in range(5):
				var tx := -0.56 + k * 0.28
				mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(tx, 0.85, 0.02)), Vector3(0.06, 1.5, 0.08), 1.0, Color(0.55, 0.4, 0.3))
				mb.add_box(iron, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(tx, 1.4, -0.05)), Vector3(0.04, 0.7, 0.04), 1.0)
		"locker":
			mb.add_box(PSXMat.lit("planks", Color(0.3, 0.38, 0.66)), M.xf(Vector3(0, 0.22, 0)), Vector3(0.9, 0.44, 0.5), 1.0)
			mb.add_box(iron, M.xf(Vector3(0, 0.45, 0)), Vector3(0.94, 0.04, 0.54), 1.0)
			mb.add_box(gold, M.xf(Vector3(0, 0.34, 0.26)), Vector3(0.1, 0.1, 0.02), 1.0)
		"bench":
			mb.add_box(wood, M.xf(Vector3(0, 0.45, 0)), Vector3(1.8, 0.08, 0.4), 1.0)
			for s: float in [-0.75, 0.75]:
				mb.add_box(stone, M.xf(Vector3(s, 0.21, 0)), Vector3(0.2, 0.42, 0.36), 1.0)
		"dummy":
			# a straw drill dummy on a post, a navy sash, a wooden sword arm
			mb.add_box(wood, M.xf(Vector3(0, 0.75, 0)), Vector3(0.1, 1.5, 0.1), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 0.04, 0)), Vector3(0.6, 0.08, 0.6), 1.0)
			mb.add_blob(PSXMat.lit("straw"), M.xf(Vector3(0, 1.25, 0)), Vector3(0.26, 0.38, 0.2), rng, 0.15, 3, 6, 1.0)
			mb.add_blob(PSXMat.lit("canvas", Color(0.85, 0.8, 0.65)), M.xf(Vector3(0, 1.75, 0)), Vector3(0.15, 0.17, 0.15), rng, 0.1, 3, 6, 1.0)
			mb.add_box(trim, Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0, 1.3, 0.02)), Vector3(0.08, 0.7, 0.42), 1.0)
			mb.add_box(wood, M.xf(Vector3(0, 1.45, 0)), Vector3(1.0, 0.08, 0.08), 1.0)
		"tent":
			# a marines' tent: white canvas over a ridge pole, a navy stripe along the ridge, guy ropes, a flap open
			var canvas := PSXMat.lit("canvas", Color(0.95, 0.95, 0.93))
			mb.add_gable_roof(canvas, M.xf(Vector3(0, 0.0, 0)), 3.0, 4.0, 2.2, 0.05, 0.5, Color.WHITE, canvas)
			mb.add_box(trim, M.xf(Vector3(0, 2.18, 0)), Vector3(0.24, 0.08, 4.1), 1.0)
			for s: float in [-1.0, 1.0]:
				mb.add_box(wood, M.xf(Vector3(0, 1.15, s * 2.0)), Vector3(0.08, 2.3, 0.08), 1.0)
				mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([Vector3(0, 2.25, s * 2.0), Vector3(0, 0.0, s * 3.0)]), 0.02, 0.02, 3, 2.0)
			mb.add_extrude(canvas, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.3, 0, -2.0)), PackedVector2Array([Vector2(0, 0), Vector2(0.9, 0), Vector2(0, 1.8)]), 0.03, 0.5)
			mb.add_box(PSXMat.flat(Color(0.1, 0.1, 0.12)), M.xf(Vector3(0, 0.7, -2.03)), Vector3(1.0, 1.4, 0.02), 1.0)
		"stool":
			mb.add_cylinder(wood, M.xf(Vector3(0, 0.42, 0)), 0.2, 0.2, 0.05, 8, 1.0)
			for k in range(3):
				var a := TAU * k / 3.0
				mb.add_box(wood, Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.15), Vector3(cos(a) * 0.12, 0.21, sin(a) * 0.12)), Vector3(0.04, 0.44, 0.04), 1.0)
	mb.fold_tints()
	return mb.commit()
