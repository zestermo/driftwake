extends RefCounted
## The coral atoll's deep basin (1.30, Zach: "a deep huge section in the center with large coral structures and huge
## reefs with lots to see"): the blue hole grown into a great sink beside the lagoon's middle (AtollLand.basin_y: a reef
## crest round its lip, the upper wall down to a ledge twelve metres down, the lower wall to its floor near thirty).
## In it: towering coral pillars from the floor, crowned with table corals; table corals on the ledge; giant sea fans;
## arches on the floor; overhangs jutting off the upper wall; a swim-through cave or two; breathing vents (a column of
## gas from the reef: a diver in it gets their breath back, so the floor is reachable) and dense reef over its walls.
## Its rock is merged meshes in the basin's own frame (a draw or two each, ranged from its middle), solid where you'd
## bump it (cylinders and boxes); the walls' corals are AtollReef's gardens. Everything from the island's seed.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const REEF := preload("res://scripts/island/themes/atoll_reef.gd")
const SHOALS := preload("res://scripts/island/themes/atoll_shoals.gd")

## How far its rock is drawn past its rim (m), and the walls' corals.
const SEE := 170.0
const WALL_CORALS := 2600
const LEDGE_CORALS := 1100
const FLOOR_CORALS := 900
## (the coral rock's texture reads dark under the water: lifted)
const ROCK := Color(1.3, 1.24, 1.18)
const CRUST := [Color(1.0, 0.55, 0.62), Color(0.75, 0.35, 0.85), Color(1.0, 0.6, 0.25), Color(1.0, 0.85, 0.3), Color(0.35, 0.8, 0.75), Color(0.9, 0.3, 0.3)]
const TABLE_COLS := [Color(0.62, 0.7, 0.45), Color(0.82, 0.7, 0.5), Color(0.95, 0.6, 0.65), Color(0.5, 0.72, 0.78)]
const FAN_COLS := [Color(0.75, 0.35, 0.85), Color(1.0, 0.45, 0.3), Color(1.0, 0.8, 0.3), Color(0.95, 0.35, 0.5)]


## [step name, Callable]: the plan, then the pillars, the rest of its rock, the walls' reef, the vents.
static func steps(isl) -> Array:
	var st := {}
	return [["atoll basin", func(): _plan(isl, st)], ["atoll basin", func(): await _pillars(isl, st)], ["atoll basin", func(): await _rock(isl, st)],
		["atoll basin", func(): await _walls(isl, st)], ["atoll basin", func(): _vents(isl, st)]]


## Where everything goes (data): each thing [kind, island point, ...].
static func _plan(isl, st: Dictionary) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var hole: Array = lp["hole"]
	var c: Vector2 = hole[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_basin"])
	var node := Node3D.new()
	node.name = "AtollBasin"
	isl.add_child(node)
	node.position = Vector3(c.x, 0.0, c.y)
	var body := StaticBody3D.new()
	body.name = "Rock"
	node.add_child(body)
	st["node"] = node
	st["body"] = body
	st["rng"] = rng
	st["c"] = c
	var taken: Array = []
	var at := func(a: float, u: float) -> Vector2: return c + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * u
	var free := func(q: Vector2, r: float) -> bool: return taken.all(func(t): return q.distance_to(t[0]) > r + float(t[1]))
	var pick := func(u0: float, u1: float, r: float) -> Vector2:
		for k in range(40):
			var q: Vector2 = at.call(rng.randf() * TAU, rng.randf_range(u0, u1))
			if free.call(q, r):
				taken.append([q, r])
				return q
		return Vector2.INF
	var things: Array = []
	for i in range(rng.randi_range(D.CAVES[0], D.CAVES[1])):
		var q: Vector2 = pick.call(0.36, 0.5, 9.0)
		if q != Vector2.INF:
			things.append(["cave", q, (q - c).normalized().orthogonal().angle(), rng.randf_range(12.0, 16.0)])
	for i in range(rng.randi_range(D.PILLARS[0], D.PILLARS[1])):
		var q: Vector2 = pick.call(0.05, 0.5, 6.5)
		if q != Vector2.INF:
			things.append(["pillar", q, rng.randf_range(D.PILLAR_TOP[1], D.PILLAR_TOP[0])])
	for i in range(rng.randi_range(D.BIG_ARCHES[0], D.BIG_ARCHES[1])):
		var q: Vector2 = pick.call(0.1, 0.48, 7.0)
		if q != Vector2.INF:
			things.append(["arch", q, rng.randf() * TAU])
	var ledge: Vector2 = L.basin_ledge(lp)
	for i in range(rng.randi_range(D.TABLES[0], D.TABLES[1])):
		var q: Vector2 = pick.call(ledge.x - 0.03, ledge.x + 0.03, 3.5) if i % 3 != 2 else pick.call(0.1, 0.5, 3.5)
		if q != Vector2.INF:
			things.append(["table", q, rng.randf_range(1.6, 3.2)])
	for i in range(rng.randi_range(D.FANS[0], D.FANS[1])):
		var q: Vector2 = pick.call(0.1, 0.84, 2.0)
		if q != Vector2.INF:
			things.append(["fan", q, (q - c).angle() + rng.randf_range(-0.6, 0.6), rng.randf_range(3.0, 5.0)])
	for i in range(rng.randi_range(D.OVERHANGS[0], D.OVERHANGS[1])):
		var a := TAU * i / float(D.OVERHANGS[1]) + rng.randf_range(-0.3, 0.3)
		things.append(["overhang", at.call(a, 0.93), a, rng.randf_range(6.0, 9.0)])
	var vents: Array = []
	for i in range(rng.randi_range(D.VENTS[0], D.VENTS[1])):
		var q: Vector2 = pick.call(ledge.x - 0.02, ledge.x + 0.02, 3.0) if i % 2 == 0 else pick.call(0.15, 0.45, 3.0)
		if q != Vector2.INF:
			vents.append(q)
	st["things"] = things
	st["vents"] = vents
	node.set_meta("caves", things.filter(func(t): return t[0] == "cave").map(func(t): return t[1]))
	node.set_meta("vents", vents)
	node.set_meta("pillars", things.filter(func(t): return t[0] == "pillar").map(func(t): return t[1]))


## Basin-local (its middle at the origin) from an island point at height y.
static func _local(st: Dictionary, q: Vector2, y: float) -> Vector3:
	var c: Vector2 = st["c"]
	return Vector3(q.x - c.x, y, q.y - c.y)


static func _pillars(isl, st: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("atoll_coral")
	var coral := PSXMat.lit("", Color.WHITE)
	for t in st["things"]:
		if t[0] != "pillar":
			continue
		var base := _local(st, t[1], float(isl.hv(t[1])) - 0.5)
		var h: float = float(t[2]) - base.y
		var rb := rng.randf_range(2.6, 4.2)
		var rt := rb * rng.randf_range(0.5, 0.75)
		var lean := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 2.2)
		var n := maxi(int(h / 3.0), 3)
		var spine := PackedVector3Array()
		for i in range(n + 1):
			var k := float(i) / n
			spine.append(base + Vector3(lean.x * k + rng.randf_range(-0.3, 0.3), h * k, lean.y * k + rng.randf_range(-0.3, 0.3)))
		mb.add_tube(rock, spine, rb * 0.82, rt * 0.82, 8, 0.25, ROCK)
		for i in range(n + 1):
			var k := float(i) / n
			var r := lerpf(rb, rt, k) * rng.randf_range(0.6, 0.9)
			var a0 := rng.randf() * TAU
			var p := spine[i] + Vector3(cos(a0), 0.0, sin(a0)) * lerpf(rb, rt, k) * 0.35
			mb.add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(r, 2.0, r * rng.randf_range(0.8, 1.1)), rng, 0.25, 3, 7, 0.5, ROCK)
			for j in range(6):
				var a := rng.randf() * TAU
				var o := p + Vector3(cos(a) * r * 0.95, rng.randf_range(-1.2, 1.2), sin(a) * r * 0.95)
				var col: Color = CRUST[rng.randi() % CRUST.size()]
				if j % 3 == 2:
					_branches_at(mb, coral, rng, rng.randf_range(0.8, 1.4), col, Transform3D(Basis(Vector3(-sin(a), 0, cos(a)), -1.1), o))
				else:
					mb.add_blob(coral, Transform3D(Basis(), o), Vector3(1.0, 0.7, 1.0) * rng.randf_range(0.35, 0.8), rng, 0.2, 3, 7, 0.5, col)
		var top := base + Vector3(lean.x, h + 0.9, lean.y)
		if rng.randf() < 0.6:
			_table_mesh(mb, coral, top, rt * rng.randf_range(1.3, 1.8), TABLE_COLS[rng.randi() % TABLE_COLS.size()], rng)
			_col(st["body"], Transform3D(Basis(), top + Vector3(0, 0.6, 0)), rt * 1.5, 0.4)
		else:
			for k in range(5):
				var o := top + Vector3(rng.randf_range(-rt, rt) * 0.6, -0.4, rng.randf_range(-rt, rt) * 0.6)
				_branches_at(mb, coral, rng, rng.randf_range(1.4, 2.4), CRUST[rng.randi() % CRUST.size()], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), o))
		_col(st["body"], Transform3D(Basis(), base + Vector3(lean.x * 0.5, h * 0.5, lean.y * 0.5)), (rb + rt) * 0.42, h)
		await GenIsland.breathe()
	_mesh(st, mb, "Pillars")


## The tables, fans, arches, overhangs and caves.
static func _rock(isl, st: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("atoll_coral")
	var coral := PSXMat.lit("", Color.WHITE)
	var body: StaticBody3D = st["body"]
	for t in st["things"]:
		var q: Vector2 = t[1]
		var p := _local(st, q, float(isl.hv(q)))
		match str(t[0]):
			"table":
				var hh := rng.randf_range(0.8, 1.6)
				var col: Color = TABLE_COLS[rng.randi() % TABLE_COLS.size()]
				mb.add_cylinder(coral, Transform3D(Basis(), p + Vector3(0, hh * 0.5, 0)), 0.35, 0.22, hh, 6, 0.5, col.darkened(0.35))
				_table_mesh(mb, coral, p + Vector3(0, hh, 0), float(t[2]), col, rng)
				_col(body, Transform3D(Basis(), p + Vector3(0, hh + 0.1, 0)), float(t[2]), 0.35)
			"fan":
				_fan(mb, coral, Transform3D(Basis(Vector3.UP, float(t[2])).scaled(Vector3.ONE * float(t[3])), p - Vector3(0, 0.1, 0)), FAN_COLS[rng.randi() % FAN_COLS.size()])
			"arch":
				_arch(mb, rock, coral, body, Transform3D(Basis(Vector3.UP, float(t[2])), p - Vector3(0, 0.4, 0)), rng)
			"overhang":
				_overhang(isl, st, mb, rock, coral, body, t, rng)
			"cave":
				_cave(mb, rock, coral, body, Transform3D(Basis(Vector3.UP, float(t[2])), p - Vector3(0, 0.3, 0)), float(t[3]), rng)
		await GenIsland.breathe()
	_mesh(st, mb, "Reefwork")


## The basin's walls, ledge and floor under reef: AtollReef's corals, bigger on the walls.
static func _walls(isl, st: Dictionary) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var rng: RandomNumberGenerator = st["rng"]
	var c: Vector2 = st["c"]
	var lists := {}
	var ledge: Vector2 = L.basin_ledge(lp)
	for band in [[WALL_CORALS, 0.86, 1.08, 3, 1.2, 3.2], [LEDGE_CORALS, D.LEDGE[0], D.LEDGE[1], 1, 0.9, 2.6], [WALL_CORALS / 2, D.FLOOR_U, D.LEDGE[0], 3, 1.0, 2.8],
			[FLOOR_CORALS, 0.0, D.FLOOR_U, 2, 0.8, 2.2]]:
		for i in range(int(band[0])):
			var a := rng.randf() * TAU
			var q: Vector2 = c + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * rng.randf_range(float(band[1]), float(band[2]))
			var h: float = isl.hv(q)
			if h > -0.9:
				continue
			REEF._put(lists, rng, int(band[3]), q, h, rng.randf_range(float(band[4]), float(band[5])))
			if i % 100 == 0:
				await GenIsland.breathe()
	var reef: Node3D = isl.get_node("AtollReef")
	for key in lists:
		var parts: PackedStringArray = (key as String).split("_")
		var mid := Vector3((int(parts[2]) + 0.5) * REEF.CELL, 0.0, (int(parts[3]) + 0.5) * REEF.CELL)
		REEF._garden(reef, REEF._meshes["%s_%s" % [parts[0], parts[1]]], lists[key], mid)
		await GenIsland.breathe()
	st["ledge_y"] = ledge.y


## The breathing vents: a ring of crusted rock round a crack, bubbles streaming up the column (GPU), and the Vent that
## gives a diver in it their breath.
static func _vents(isl, st: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var node: Node3D = st["node"]
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("atoll_coral")
	var crust := PSXMat.lit("", Color.WHITE)
	var i := 0
	for q in st["vents"]:
		var y: float = isl.hv(q)
		var p := _local(st, q, y)
		for k in range(7):
			var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
			mb.add_blob(rock, Transform3D(Basis(), p + Vector3(cos(a) * 0.9, 0.15, sin(a) * 0.9)), Vector3(0.45, 0.3, 0.4), rng, 0.25, 2, 6, 0.5, ROCK)
		mb.add_blob(crust, Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Vector3(0.7, 0.06, 0.7), rng, 0.1, 2, 7, 0.5, Color(1.0, 0.96, 0.75))
		var v := Vent.new()
		v.name = "Vent%d" % i
		node.add_child(v)
		v.position = p
		v.depth = -y
		var bub := _bubble_mesh()
		SHOALS._add(v, bub, 2, Vector3(0, -y * 0.5, 0), 70, D.VENT_R * 0.8, -y * 0.5, Color(0.85, 0.96, 1.0), rng, 120.0)
		i += 1
	_mesh(st, mb, "Vents")


# --------------------------------------------------------------------------
# Models (basin-local)
# --------------------------------------------------------------------------
static func _table_mesh(mb: MeshBuilder, mat: Material, at: Vector3, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	mb.add_cylinder(mat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), r * 0.82, r, 0.24, 10, 0.5, col, true, true)
	for k in range(10):
		var a := TAU * k / 10.0 + rng.randf_range(-0.15, 0.15)
		mb.add_blob(mat, Transform3D(Basis(), at + Vector3(cos(a) * r * 0.95, 0.14, sin(a) * r * 0.95)), Vector3(0.22, 0.1, 0.22), rng, 0.2, 2, 5, 0.5, col.lightened(0.2))
	if rng.randf() < 0.5:
		mb.add_cylinder(mat, Transform3D(Basis(), at + Vector3(r * 0.2, 0.5, 0)), r * 0.45, r * 0.55, 0.18, 8, 0.5, col.lightened(0.1), true, true)


## A giant sea fan (unit size: `xf` scales it): a lattice of branches spread in one plane from a short stalk.
static func _fan(mb: MeshBuilder, mat: Material, xf: Transform3D, col: Color) -> void:
	var s := xf.basis.get_scale().x
	var pts := func(arr: Array) -> PackedVector3Array:
		var out := PackedVector3Array()
		for v in arr:
			out.append(xf * (v as Vector3))
		return out
	mb.add_tube(mat, pts.call([Vector3(0, 0, 0), Vector3(0, 0.22, 0)]), 0.05 * s, 0.035 * s, 4, 1.0, col.darkened(0.3))
	for t in range(13):
		var a := lerpf(-1.25, 1.25, t / 12.0)
		var tip := Vector3(sin(a) * 0.7, 0.25 + cos(a) * 0.8, 0.0)
		mb.add_tube(mat, pts.call([Vector3(0, 0.22, 0), tip * 0.5 + Vector3(0, 0.1, 0.03), tip]), 0.016 * s, 0.008 * s, 3, 1.0, col)
	for r in [0.35, 0.55, 0.75, 0.92]:
		var arc: Array = []
		for t in range(9):
			var a := lerpf(-1.15, 1.15, t / 8.0)
			arc.append(Vector3(sin(a) * 0.7 * r, 0.25 + cos(a) * 0.8 * r, 0.0))
		mb.add_tube(mat, pts.call(arc), 0.009 * s, 0.009 * s, 3, 1.0, col.lightened(0.15))


## A great arch on the floor: two crusted pillars and a span, tall enough to swim through standing.
static func _arch(mb: MeshBuilder, rock: Material, coral: Material, body: StaticBody3D, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.0, 9.0)
	var gap := rng.randf_range(3.5, 5.0)
	for sx in [-1.0, 1.0]:
		for k in range(3):
			var y := h * (0.18 + k * 0.32)
			mb.add_blob(rock, xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sx * (gap + 1.2), y, 0)), Vector3(1.5, h * 0.22, 1.6), rng, 0.22, 3, 7, 0.5, ROCK)
		_box(body, xf * Transform3D(Basis(), Vector3(sx * (gap + 1.2), h * 0.5, 0)), Vector3(2.4, h, 2.6))
	mb.add_blob(rock, xf * Transform3D(Basis(), Vector3(0, h, 0)), Vector3(gap + 2.4, 1.1, 1.6), rng, 0.2, 3, 9, 0.5, ROCK)
	_box(body, xf * Transform3D(Basis(), Vector3(0, h, 0)), Vector3(gap * 2.0 + 4.0, 1.6, 2.6))
	for k in range(18):
		var o := Vector3(rng.randf_range(-gap - 2.0, gap + 2.0), h + 0.9, rng.randf_range(-1.0, 1.0))
		mb.add_blob(coral, xf * Transform3D(Basis(), o), Vector3.ONE * rng.randf_range(0.25, 0.55), rng, 0.15, 2, 6, 0.5, CRUST[k % CRUST.size()])
	for k in range(6):
		_branches_at(mb, coral, rng, rng.randf_range(1.0, 1.8), CRUST[rng.randi() % CRUST.size()],
			xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-gap, gap), h + 0.7, rng.randf_range(-0.8, 0.8))))


## A shelf of reef jutting out over the basin off its upper wall: crusted on top, sponges and weed hanging under it.
static func _overhang(isl, st: Dictionary, mb: MeshBuilder, rock: Material, coral: Material, body: StaticBody3D, t: Array, rng: RandomNumberGenerator) -> void:
	var q: Vector2 = t[1]
	var c: Vector2 = st["c"]
	var inward: Vector2 = (c - q).normalized()
	var w: float = t[3]
	var y: float = float(isl.hv(q)) + 0.4
	var xf := Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.y)), _local(st, q, y))
	mb.add_blob(rock, xf * Transform3D(Basis(), Vector3(0, 0, 2.2)), Vector3(w * 0.5, 0.75, 3.6), rng, 0.25, 3, 9, 0.5, ROCK)
	mb.add_blob(rock, xf * Transform3D(Basis(), Vector3(0, 0.4, -0.5)), Vector3(w * 0.45, 1.3, 2.0), rng, 0.25, 3, 8, 0.5, ROCK)
	_box(body, xf * Transform3D(Basis(), Vector3(0, 0, 2.2)), Vector3(w * 0.85, 1.2, 6.0))
	for k in range(12):
		var o := Vector3(rng.randf_range(-w * 0.4, w * 0.4), 0.7, rng.randf_range(0.0, 4.8))
		mb.add_blob(coral, xf * Transform3D(Basis(), o), Vector3.ONE * rng.randf_range(0.25, 0.6), rng, 0.15, 2, 6, 0.5, CRUST[rng.randi() % CRUST.size()])
	for k in range(9):
		var o := Vector3(rng.randf_range(-w * 0.4, w * 0.4), -0.6, rng.randf_range(1.0, 5.0))
		var hang := rng.randf_range(0.8, 2.2)
		if k % 3 == 0:
			mb.add_cylinder(coral, xf * Transform3D(Basis(), o - Vector3(0, hang * 0.25, 0)), 0.18, 0.12, hang * 0.5, 6, 0.5, CRUST[rng.randi() % CRUST.size()])
		else:
			mb.add_tube(coral, PackedVector3Array([xf * o, xf * (o + Vector3(0.1, -hang * 0.5, 0.05)), xf * (o + Vector3(-0.1, -hang, 0.1))]), 0.05, 0.02, 3, 1.0, Color(0.4, 0.62, 0.3))


## A swim-through cave: a tunnel of reef rock `ln` m long along its local z, walls and a roof, open at both ends,
## glowing anemones on its walls.
static func _cave(mb: MeshBuilder, rock: Material, coral: Material, body: StaticBody3D, xf: Transform3D, ln: float, rng: RandomNumberGenerator) -> void:
	var hw := 1.9
	var ht := 3.3
	var z := -ln * 0.5
	while z <= ln * 0.5:
		for sx in [-1.0, 1.0]:
			mb.add_blob(rock, xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sx * (hw + 1.2), ht * 0.5, z)), Vector3(1.4, ht * 0.65, 1.5), rng, 0.2, 3, 7, 0.5, ROCK)
		mb.add_blob(rock, xf * Transform3D(Basis(), Vector3(0, ht + 0.8, z)), Vector3(hw + 2.4, 1.1, 1.5), rng, 0.2, 3, 8, 0.5, ROCK)
		mb.add_blob(rock, xf * Transform3D(Basis(), Vector3(rng.randf_range(-1.5, 1.5), ht + 1.8, z)), Vector3(2.0, 1.0, 1.6), rng, 0.25, 2, 7, 0.5, ROCK)
		z += 2.0
	for sx in [-1.0, 1.0]:
		_box(body, xf * Transform3D(Basis(), Vector3(sx * (hw + 1.0), ht * 0.5, 0)), Vector3(1.6, ht + 0.6, ln + 1.0))
	_box(body, xf * Transform3D(Basis(), Vector3(0, ht + 0.7, 0)), Vector3(hw * 2.0 + 3.6, 1.2, ln + 1.0))
	var glow := PSXMat.glow(Color(0.5, 1.0, 0.9), 1.4)
	for k in range(10):
		var sx := -1.0 if k % 2 == 0 else 1.0
		var o := Vector3(sx * (hw - 0.05), rng.randf_range(0.6, ht - 0.4), rng.randf_range(-ln * 0.45, ln * 0.45))
		mb.add_blob(glow, xf * Transform3D(Basis(), o), Vector3(0.12, 0.18, 0.18), rng, 0.2, 2, 5)
	for k in range(14):
		var o := Vector3(rng.randf_range(-hw - 2.0, hw + 2.0), ht + 2.4, rng.randf_range(-ln * 0.5, ln * 0.5))
		mb.add_blob(coral, xf * Transform3D(Basis(), o), Vector3.ONE * rng.randf_range(0.3, 0.6), rng, 0.15, 2, 6, 0.5, CRUST[rng.randi() % CRUST.size()])


## AtollReef's branching coral, `h` tall, put down at `xf`.
static func _branches_at(mb: MeshBuilder, mat: Material, rng: RandomNumberGenerator, h: float, col: Color, xf: Transform3D) -> void:
	var sub := MeshBuilder.new()
	REEF._branches(sub, mat, rng, h, col)
	sub.map_vertices(mat, func(v: Vector3) -> Vector3: return xf * v)
	mb.merge(sub)


static var _bub: ArrayMesh


static func _bubble_mesh() -> ArrayMesh:
	if _bub == null:
		var mb := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		mb.add_blob(PSXMat.lit("", Color.WHITE), Transform3D(), Vector3.ONE * 0.13, rng, 0.0, 2, 4)
		_bub = mb.commit()
	return _bub


static func _mesh(st: Dictionary, mb: MeshBuilder, name: String) -> void:
	var mi := mb.to_instance(name)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = SEE + 80.0
	(st["node"] as Node3D).add_child(mi)


static func _col(body: StaticBody3D, xf: Transform3D, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = h
	cs.shape = cy
	cs.transform = xf
	body.add_child(cs)


static func _box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = xf
	body.add_child(cs)


## A breathing vent: a diver of this machine's within VENT_R of its column gets their breath back (VENT_REFILL s a
## second); its bubbles are the GPU's. Checks four times a second near a swimmer, once a second otherwise.
class Vent extends Node3D:
	const WAKE := 40.0
	var depth := 30.0
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		var me := get_tree().get_first_node_in_group("player") as Player
		if me == null or not me.is_swimming():
			_t = 1.0
			return
		var off := me.global_position - global_position
		if Vector2(off.x, off.z).length() > WAKE:
			_t = 1.0
			return
		_t = 0.25
		if Vector2(off.x, off.z).length() < D.VENT_R and off.y > -1.0 and off.y < depth:
			var swim := me.get_node("StateMachine/Swim")
			var was: float = swim.breath
			swim.breath = minf(was + D.VENT_REFILL * 0.25, swim.breath_max())
			if swim.breath > was:
				me.get_node("/root/FX").bubbles(me.global_position + Vector3(0, 1.4, 0), 3)
