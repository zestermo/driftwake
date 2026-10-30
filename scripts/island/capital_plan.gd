class_name CapitalPlan
extends RefCounted
## The royal capital's fixed layout (docs/capital_plan.md), as data: the same city in every world. Everything is
## in the city's frame (Vector2 x along the harbour front, y = z, +z out to sea, -z inland up to the palace);
## CapitalIsland turns the frame to face the way the crew sails in. Pure functions and constants: safe on a worker.
##
## From the sea in: the harbour basin between two moles (a lighthouse and a fort on their heads), the quay, the
## harbour wall with its sea gate, the market street climbing to the plaza, the avenue on to the palace gate at the
## foot of the hill, the palace on top; the arena east of the plaza; the slum alley west of the street; the docks east
## of the street (warehouses, the wharf and the capital's shipwright) and the noble quarter's terrace under the palace
## wall (1.21). The rest of the city is houses as massing behind the streets' own fronts, walled off.

const QUAY_Y := 2.0
## The quay's face (the harbour's edge), and the harbour wall's line behind the quay.
const FRONT_Z := 122.0
const WALL_Z := 80.0
const WALL_T := 3.0
## The land: a disc cut by the harbour front.
const LAND_C := Vector2(0.0, -40.0)
const LAND_R := 230.0
## The sea wall runs this far inside the coast.
const SEA_WALL_IN := 6.0
## The harbour basin (between the moles) and its floor.
const BASIN := Rect2(-150.0, FRONT_Z, 300.0, 84.0)
const BASIN_Y := -8.0
const SEAFLOOR := -30.0
## The moles' lines (each from the quay out and round to the harbour mouth) and their top.
const MOLE_E := [Vector2(150.0, 118.0), Vector2(150.0, 190.0), Vector2(48.0, 206.0)]
const MOLE_W := [Vector2(-150.0, 118.0), Vector2(-150.0, 190.0), Vector2(-48.0, 206.0)]
const MOLE_HW := 4.5
const MOLE_Y := 2.2
## The cross walls closing the quay's ends (the moles start just inside them).
const QUAY_END_X := 156.0
## The palace hill: its plateau and where its slope meets the town.
const HILL_C := Vector2(0.0, -165.0)
const HILL_TOP := 42.0
const HILL_R0 := 50.0
const HILL_R1 := 112.0
## The palace grounds' wall (round the hill) and its gate at the avenue's end.
const GROUNDS_R := 98.0
const PALACE_GATE := Vector2(0.0, -67.0)
## The throne hall (1.21: walked into): its middle, size, wall height and door's width.
const HALL_C := Vector2(0.0, -171.0)
const HALL_W := 38.0
const HALL_D := 22.0
const HALL_H := 15.0
const HALL_DOOR := 4.0
## The arena (outer walls only in 1.18.1): centre and radii.
const ARENA_C := Vector2(108.0, 0.0)
const ARENA_R := Vector2(40.0, 32.0)
## (1.21: walked in) its rings of seats, the cut through them to the west gate (half its width, m), and the sand's
## podium wall as a share of ARENA_R (the sand inside it).
const ARENA_SEATS := 9
const ARENA_CUT := 2.6
const PLAZA := Rect2(-26.0, -22.0, 52.0, 44.0)
const PLAZA_Y := 5.0
const FLOOR_DROP := 0.6
## Where the crew's ship lies, alongside the quay (frame), bow along +x.
const BERTH := Vector2(22.0, 127.5)

## Walkable floors: [name, rect, texture], tiling without overlaps. The ground under them is dropped FLOOR_DROP
## and the floor laid over it.
const FLOORS := [
	["quay", Rect2(-QUAY_END_X, 81.0, QUAY_END_X * 2.0, 39.5), "capital_slabs"],
	["gate", Rect2(-3.0, 76.0, 6.0, 5.0), "capital_slabs"],
	["street", Rect2(-6.0, 22.0, 12.0, 54.0), "cobbles"],
	["plaza", Rect2(-26.0, -22.0, 52.0, 44.0), "capital_slabs"],
	["avenue", Rect2(-7.0, -64.0, 14.0, 42.0), "capital_slabs"],
	["arena_st", Rect2(26.0, -6.0, 41.5, 12.0), "cobbles"],
	["alley", Rect2(-48.0, 50.0, 42.0, 4.0), "cobbles"],
	["yard", Rect2(-78.0, 36.0, 30.0, 34.0), "dirt"],
	["postern", Rect2(-70.0, 70.0, 5.0, 11.0), "cobbles"],
	# 1.21 (docs/v1_21_plan.md): the docks east off the market street to the wharf and its postern to the quay; the
	# noble quarter's terrace east off the avenue's top under the palace wall (its step round the palace gatehouse)
	["docks", Rect2(6.0, 50.0, 120.0, 15.0), "cobbles"],
	["wharf", Rect2(126.0, 38.0, 22.0, 38.0), "capital_slabs"],
	["e_postern", Rect2(130.5, 76.0, 5.0, 5.0), "cobbles"],
	["terrace", Rect2(9.2, -65.0, 92.8, 15.0), "capital_slabs"],
	["terrace_step", Rect2(7.0, -60.0, 2.2, 10.0), "capital_slabs"],
	# 1.21 piece 2: the palace court between the wings, from the ring wall's gate to the foot of the porch's steps
	["palace_court", Rect2(-10.0, -151.8, 20.0, 33.8), "capital_slabs"],
	# 1.21 piece 3: the arena's gate, paved through the arch (no barrier across the arena street's end)
	["arena_gate", Rect2(67.5, -2.0, 4.0, 4.0), "cobbles"],
	# 1.27 C2: the bell yard, off the plaza's north-east corner to the bell tower's door (CapitalBellTower)
	["bell_yard", Rect2(26.0, -27.75, 18.0, 9.75), "capital_slabs"],
	# 1.27 C2: the cathedral's forecourt on its east front, and the walk from it to the avenue (CapitalCathedral)
	["forecourt", Rect2(-73.0, -48.0, 25.0, 24.0), "capital_slabs"],
	["temple_walk", Rect2(-48.0, -48.0, 41.0, 4.0), "cobbles"],
]
## Ground round the plaza, the avenue and the arena street kept for the district's own buildings (the inn, the
## treasure merchant, the guild hall...: piece 2): its lots are marked "keep"; and the temple's, which has none.
const KEEP := [
	Rect2(-48.0, -40.0, 22.0, 62.0),
	Rect2(26.0, -40.0, 20.0, 34.0),
	Rect2(26.0, 6.0, 20.0, 16.0),
	Rect2(-26.0, -44.0, 19.0, 22.0),
	Rect2(7.0, -44.0, 19.0, 22.0),
	Rect2(-32.0, 22.0, 26.0, 6.0),
	Rect2(6.0, 22.0, 26.0, 6.0),
	Rect2(-26.0, -64.0, 19.0, 20.0),
	Rect2(7.0, -64.0, 19.0, 20.0),
	Rect2(46.0, -16.0, 20.0, 10.0),
	Rect2(46.0, 6.0, 20.0, 10.0),
]
const TEMPLE := Rect2(-112.0, -60.0, 44.0, 52.0)
## The plaza's own buildings: [rect, the way their front faces] (CapitalDistrict builds them; no house on them).
const SPECIAL := {
	"inn": [Rect2(-46.0, -6.0, 20.0, 22.0), Vector2(1, 0)],
	"curio": [Rect2(26.0, 6.0, 14.0, 16.0), Vector2(-1, 0)],
	"guild": [Rect2(-26.0, -44.0, 19.0, 22.0), Vector2(0, 1)],
	"bank": [Rect2(7.0, -44.0, 19.0, 22.0), Vector2(0, 1)],
	"bell": [Rect2(34.0, -35.0, 8.0, 8.0), Vector2(-1, 0)],
	# 1.21: the capital shipwright's hall on the wharf, the outfitter on the terrace
	"yardhall": [Rect2(148.0, 44.0, 16.0, 22.0), Vector2(-1, 0)],
	"outfitter": [Rect2(46.0, -50.0, 16.0, 11.0), Vector2(0, -1)],
	# 1.27 C2: the library on the cathedral's forecourt (its door west onto it), the theatre on the arena street (CapitalHalls)
	"library": [Rect2(-48.0, -44.0, 20.0, 20.0), Vector2(-1, 0)],
	"theatre": [Rect2(46.0, -28.0, 20.0, 22.0), Vector2(0, 1)],
}


## The throne hall's floor (and the porch's), over the hilltop.
static func arena_inner() -> float:
	return 0.97 - 0.05 * ARENA_SEATS


static func hall_floor() -> float:
	return HILL_TOP + 0.8


## The floor of a raised building at frame point q (what its people stand on), or -INF: the throne hall's (its dais
## 0.9 higher), the porch's, the shipwright's hall's plinth (1.21).
static func raised(q: Vector2) -> float:
	var hall := Rect2(HALL_C - Vector2(HALL_W, HALL_D) * 0.5, Vector2(HALL_W, HALL_D))
	if hall.has_point(q):
		var dais := Rect2(HALL_C.x - 6.0, hall.position.y + 0.8, 12.0, 2.4)
		return hall_floor() + (0.9 if dais.has_point(q) else 0.0)
	if Rect2(HILL_C.x - 9.0, HILL_C.y + 5.0, 18.0, 3.4).has_point(q):
		return hall_floor()
	var yh: Rect2 = SPECIAL["yardhall"][0]
	if yh.has_point(q):
		var top := -INF
		for p in [yh.position, yh.end, Vector2(yh.position.x, yh.end.y), Vector2(yh.end.x, yh.position.y), yh.get_center()]:
			top = maxf(top, ground(p))
		return top
	return -INF


static func special_hit(r: Rect2) -> bool:
	for k in SPECIAL:
		if (SPECIAL[k][0] as Rect2).intersects(r):
			return true
	return false


static func smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## The town's ground by how far in from the sea: the quay, the market street's climb, the plaza, the avenue's.
static func base(z: float) -> float:
	if z >= 78.0:
		return QUAY_Y
	if z >= 22.0:
		return lerpf(PLAZA_Y, QUAY_Y, (z - 22.0) / 56.0)
	if z >= -22.0:
		return PLAZA_Y
	if z >= -64.0:
		return lerpf(8.0, PLAZA_Y, (z + 64.0) / 42.0)
	return 8.0


static func hill(q: Vector2) -> float:
	return HILL_TOP * (1.0 - smooth(HILL_R0, HILL_R1, q.distance_to(HILL_C)))


static func ellipse(q: Vector2, c: Vector2, r: Vector2) -> float:
	var d := (q - c) / r
	return d.length()


## The designed ground (where the floors, buildings and walls stand).
static func ground(q: Vector2) -> float:
	var g := maxf(base(q.y), hill(q))
	var a := 1.0 - smooth(1.2, 1.45, ellipse(q, ARENA_C, ARENA_R))
	return lerpf(g, PLAZA_Y, a)


## Signed distance from the coast (- inland).
static func land_t(q: Vector2) -> float:
	return maxf(q.distance_to(LAND_C) - LAND_R, q.y - FRONT_Z)


## Is the coast here the quay (rather than the shore under the sea wall)?
static func quay_coast(q: Vector2) -> bool:
	return absf(q.x) < 150.0 and q.y - FRONT_Z > q.distance_to(LAND_C) - LAND_R - 8.0


static func in_floor(q: Vector2, grow := 0.0) -> bool:
	for f in floors():
		if (f[1] as Rect2).grow(grow).has_point(q):
			return true
	return false


static func floor_of(q: Vector2) -> int:
	var all := floors()
	for i in range(all.size()):
		if (all[i][1] as Rect2).has_point(q):
			return i
	return -1


# --------------------------------------------------------------------------
# The rolled streets (1.27, docs/v1_27_plan.md "the cities pass"): the landmarks and FLOORS stay put; between them the
# gaps of the house grid open as lanes (a connected set rolled from the world's seed), alleys cut through blocks' middles
# (some dead ends), and courtyards clear at some crossings. Everything else (the houses facing them, the walls across
# what's left open) follows from floors().
# --------------------------------------------------------------------------
## The world's seed (CapitalIsland.prepare sets it; 0 for tools and tests that don't).
static var world_seed := 0
static var _floors_for := -1
static var _floors: Array = []
static var _lots_for := -1
static var _lots: Array = []
## The house grid's gaps, the lanes' centre lines: x of the gap columns (each side of the market street) and z of the
## gap rows (between blocks; _spans' blocks are 26 x 22 with 4 m lanes).
const GAP_X := [34.0, 64.0, 94.0, 124.0]
const GAP_Z := [52.0, 26.0, 0.0, -26.0, -52.0, -78.0]
const LANE_W := 4.0
const ALLEY_W := 2.4
## How many lanes open (graph edges), alleys and courtyards: [lo, hi].
const LANES := [18, 24]
const ALLEYS := [6, 9]
const COURTS := [3, 5]
const COURT := 10.0


static func use_seed(s: int) -> void:
	world_seed = s


## Every walkable floor: FLOORS, then the rolled lanes ("lane"), alleys ("alley_r") and courtyards ("court"), each
## [name, rect, texture]. Cached per seed.
static func floors() -> Array:
	if _floors_for == world_seed and not _floors.is_empty():
		return _floors
	_floors = FLOORS.duplicate()
	_floors.append_array(_roll())
	_floors_for = world_seed
	return _floors


## The rolled ones only.
static func rolled() -> Array:
	return floors().slice(FLOORS.size())


## A rect the lanes may open on: dry land inside the harbour wall, clear of the palace grounds, the arena, the temple
## and every building the district builds itself.
static func _clear(r: Rect2) -> bool:
	for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		if land_t(p) > -SEA_WALL_IN - 8.0 or p.y > WALL_Z - WALL_T - 0.5:
			return false
		if p.distance_to(HILL_C) < GROUNDS_R + 4.0 or ellipse(p, ARENA_C, ARENA_R) < 1.15:
			return false
	if r.intersects(TEMPLE.grow(2.0)):
		return false
	for k in KEEP:
		if (k as Rect2).intersects(r):
			return false
	for k in SPECIAL:
		if (SPECIAL[k][0] as Rect2).grow(1.0).intersects(r):
			return false
	return true


static func _roll() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([71329, world_seed])
	var xs: Array = [0.0]
	for x in GAP_X:
		xs.append(x)
		xs.push_front(-x)
	# the graph: nodes at the gaps' crossings (x = 0 is the fixed spine: the market street, the plaza, the avenue);
	# edges along the gaps between neighbours, each a lane's rect
	var edges: Array = []
	for zi in range(GAP_Z.size()):
		var z: float = GAP_Z[zi]
		for xi in range(xs.size() - 1):
			var x0: float = xs[xi]
			var x1: float = xs[xi + 1]
			var r := Rect2(x0 - LANE_W * 0.5, z - LANE_W * 0.5, x1 - x0 + LANE_W, LANE_W)
			edges.append({"a": Vector2i(xi, zi), "b": Vector2i(xi + 1, zi), "r": r})
	for xi in range(xs.size()):
		if xs[xi] == 0.0:
			continue
		for zi in range(GAP_Z.size() - 1):
			var z0: float = GAP_Z[zi + 1]
			var z1: float = GAP_Z[zi]
			var r := Rect2(xs[xi] - LANE_W * 0.5, z0 - LANE_W * 0.5, LANE_W, z1 - z0 + LANE_W)
			edges.append({"a": Vector2i(xi, zi), "b": Vector2i(xi, zi + 1), "r": r})
	# an edge's own ground (between its ends, off the spine's floors where it starts on them) must be clear
	var ok: Array = edges.filter(func(e):
		var r: Rect2 = e["r"]
		var mid := Rect2(r.position + r.size * 0.25, r.size * 0.5)
		return _clear(mid) and _clear(r.grow(-0.5)) or (_clear(mid) and _touches_fixed(r)))
	# the spine's nodes are where the network starts: grown by a random walk out from the connected set, with a few
	# loops kept (a lane meeting one already open) so it isn't a tree
	# (an edge whose middle is on a fixed floor already is one: its nodes join the spine and it costs nothing)
	var spine := {}
	for e in edges:
		var r: Rect2 = e["r"]
		if _on_fixed(r.get_center()):
			spine[e["a"]] = true
			spine[e["b"]] = true
	ok = ok.filter(func(e): return not _on_fixed((e["r"] as Rect2).get_center()))
	for e in ok:
		for k in ["a", "b"]:
			var n: Vector2i = e[k]
			if xs[n.x] == 0.0 or _touches_fixed(e["r"]):
				spine[n] = true
	var joined := spine.duplicate()
	var want := rng.randi_range(LANES[0], LANES[1])
	var picked: Array = []
	var left: Array = ok.duplicate()
	var guard := 0
	while picked.size() < want and not left.is_empty() and guard < 400:
		guard += 1
		var frontier: Array = left.filter(func(e): return joined.has(e["a"]) or joined.has(e["b"]))
		if frontier.is_empty():
			break
		var e: Dictionary = frontier[rng.randi() % frontier.size()]
		left.erase(e)
		if joined.has(e["a"]) and joined.has(e["b"]) and rng.randf() > 0.3:
			continue
		joined[e["a"]] = true
		joined[e["b"]] = true
		picked.append(e)
	var out: Array = []
	for e in picked:
		out.append(["lane", e["r"], "cobbles"])
	# courtyards at some crossings the lanes reach (not on the spine)
	var nodes: Array = joined.keys().filter(func(n): return xs[n.x] != 0.0)
	nodes.sort()
	var courts := 0
	var want_c := rng.randi_range(COURTS[0], COURTS[1])
	for i in range(nodes.size()):
		var n: Vector2i = nodes[(i * 7 + rng.randi() % 3) % nodes.size()]
		var c := Vector2(xs[n.x], GAP_Z[n.y])
		# (the four blocks' corner lots round the crossing, their whole depth: house fronts frame it, no scraps left over)
		var ext := Vector2(LANE_W * 0.5 + COURT * 0.7, LANE_W * 0.5 + 11.0)
		var r := Rect2(c - ext, ext * 2.0)
		if courts >= want_c or not _clear(r) or out.any(func(f): return str(f[0]) == "court" and (f[1] as Rect2).grow(6.0).intersects(r)):
			continue
		out.append(["court", r, "capital_slabs"])
		courts += 1
	# alleys: through a block's middle (between its two rows of lots) from an open lane, through to the next one or a
	# dead end part way
	var want_a := rng.randi_range(ALLEYS[0], ALLEYS[1])
	var alleys := 0
	var lanes_v: Array = picked.filter(func(e): return (e["r"] as Rect2).size.y > (e["r"] as Rect2).size.x)
	lanes_v.shuffle()
	for e in lanes_v:
		if alleys >= want_a:
			break
		var lr: Rect2 = e["r"]
		var zm := lr.get_center().y
		var dir := -1.0 if rng.randf() < 0.5 else 1.0
		var x0 := lr.get_center().x + dir * LANE_W * 0.5
		var run := rng.randf_range(10.0, 26.0)
		var r := Rect2(minf(x0, x0 + dir * run), zm - ALLEY_W * 0.5, run, ALLEY_W)
		if not _clear(r) or out.any(func(f): return (f[1] as Rect2).intersects(r.grow(-0.2)) and str(f[0]) != "lane"):
			continue
		out.append(["alley_r", r, "cobbles"])
		alleys += 1
	return out


static func _on_fixed(q: Vector2) -> bool:
	for f in FLOORS:
		if (f[1] as Rect2).has_point(q):
			return true
	return false


## A lane that runs onto one of the fixed floors (it joins the spine there).
static func _touches_fixed(r: Rect2) -> bool:
	for f in FLOORS:
		if (f[1] as Rect2).grow(0.5).intersects(r):
			return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func mole_dist(q: Vector2) -> float:
	var d := INF
	for m in [MOLE_E, MOLE_W]:
		for i in range(m.size() - 1):
			d = minf(d, _seg_dist(q, m[i], m[i + 1]))
	return d


## The terrain grid's height (the floors are laid FLOOR_DROP over it; the quay wall, moles and sea wall hide its edges).
static func terrain(q: Vector2) -> float:
	var t := land_t(q)
	var g := ground(q)
	var h: float
	if quay_coast(q):
		h = lerpf(g, BASIN_Y, smooth(-2.5, 2.5, t))
	elif t < 4.0:
		h = lerpf(g, 0.3, smooth(-3.0, 4.0, t))
	else:
		h = lerpf(0.3, SEAFLOOR, smooth(4.0, 45.0, t))
	if t > 0.0:
		var d := Vector2(maxf(maxf(BASIN.position.x - q.x, q.x - BASIN.end.x), 0.0), maxf(maxf(BASIN.position.y - q.y, q.y - BASIN.end.y), 0.0)).length()
		var sea := lerpf(BASIN_Y, SEAFLOOR, smooth(0.0, 60.0, d))
		h = minf(h, sea) if quay_coast(q) else maxf(h, sea)
		h = maxf(h, lerpf(-10.0, h, smooth(MOLE_HW + 2.0, MOLE_HW + 12.0, mole_dist(q))))
	elif in_floor(q, 4.0):
		h -= FLOOR_DROP
	return h


## How far a point is down the hill road's slope (0 town, 1 the plateau): for the terrain's paint.
static func steep(q: Vector2) -> float:
	var d := q.distance_to(HILL_C)
	return smooth(HILL_R0 - 4.0, HILL_R0 + 6.0, d) * (1.0 - smooth(HILL_R1 - 30.0, HILL_R1, d))


# --------------------------------------------------------------------------
# The massing: blocks of houses behind the streets' fronts
# --------------------------------------------------------------------------
## Block columns out from the market street and rows in from the harbour wall: [lo, hi] spans.
static func _spans(from: float, to: float, size: float, lane: float) -> Array:
	var out: Array = []
	var a := from
	while a < to:
		out.append([a, minf(a + size, to)])
		a += size + lane
	return out


## Every house lot of the city (fixed seed): {"r": Rect2 (frame, inset), "cell": its whole plot, "c", "floors",
## "roof": hip / gable / flat, "face": Vector2 (toward its street), "seed", "front": it fronts a walkable floor,
## "keep": on ground kept for the district's own buildings (piece 2 builds those instead)}.
static func lots() -> Array:
	if _lots_for == world_seed and not _lots.is_empty():
		return _lots
	var rng := RandomNumberGenerator.new()
	rng.seed = 51971 if world_seed == 0 else hash([51971, world_seed])
	var out: Array = []
	var cols := _spans(6.0, 240.0, 26.0, 4.0)
	var rows := _spans(-76.0, 260.0, 22.0, 4.0)
	for sx in [-1.0, 1.0]:
		for col in cols:
			for row in rows:
				var bx0: float = col[0] * sx
				var bx1: float = col[1] * sx
				_block(Rect2(minf(bx0, bx1), -float(row[1]), absf(bx1 - bx0), float(row[1]) - float(row[0])), rng, out, false)
	for k in KEEP:
		_block(k, rng, out, true)
	for sx in [-1.0, 1.0]:
		var r := Rect2(158.0 if sx > 0.0 else -174.0, 82.0, 16.0, 13.0)
		out.append({"r": r, "cell": r, "c": r.get_center(), "floors": 3, "roof": "gable", "face": Vector2(-sx, 0), "seed": 9001 + int(sx), "front": false, "keep": false})
	_lots = out
	_lots_for = world_seed
	return out


static func _block(b: Rect2, rng: RandomNumberGenerator, out: Array, keep: bool) -> void:
	var zm := b.position.y + b.size.y * 0.5
	# (an alley rolled through this block's middle: its two rows of lots stand back from it)
	var cut := 0.0
	for f in rolled():
		if str(f[0]) == "alley_r" and absf((f[1] as Rect2).get_center().y - zm) < 0.5 and (f[1] as Rect2).intersects(b):
			cut = ALLEY_W * 0.5
	for half in [0, 1]:
		var z0: float = b.position.y if half == 0 else zm + cut
		var z1: float = zm - cut if half == 0 else b.end.y
		var x := b.position.x
		while x < b.end.x - 3.0:
			var w := minf(rng.randf_range(6.0, 10.0), b.end.x - x)
			if b.end.x - (x + w) < 4.0:
				w = b.end.x - x
			var inset := rng.randf_range(0.0, 0.4)
			var cell := Rect2(x, z0, w, z1 - z0)
			var r := cell.grow(-inset)
			# (1.27) a courtyard over the lot's corner: the lot keeps the rest of its frontage, or goes if too little is left
			for f in rolled():
				var cr: Rect2 = f[1]
				if str(f[0]) != "court" or not cr.intersects(r) or cr.position.y > r.position.y + 0.5 or cr.end.y < r.end.y - 0.5:
					continue
				if cr.get_center().x < r.get_center().x:
					r = Rect2(cr.end.x + 0.3, r.position.y, r.end.x - cr.end.x - 0.3, r.size.y)
				else:
					r = Rect2(r.position.x, r.position.y, cr.position.x - 0.3 - r.position.x, r.size.y)
				cell = r.grow(inset)
				if r.size.x < 3.5:
					break
			var floors := rng.randi_range(2, 4)
			var roof_roll := rng.randf()
			var sd := rng.randi()
			x += w
			if r.size.x < 3.5:
				continue
			if not _lot_ok(r, keep):
				continue
			if r.get_center().distance_to(HILL_C) < HILL_R1:
				floors = mini(floors, 3)
			elif r.get_center().y > 20.0 and not keep:
				floors += 1
			var face := Vector2(0, -1) if half == 0 else Vector2(0, 1)
			var front := false
			for f in floors():
				var fr: Rect2 = f[1]
				if not fr.grow(1.5).intersects(r):
					continue
				front = true
				if r.end.x <= fr.position.x + 1.5:
					face = Vector2(1, 0)
				elif r.position.x >= fr.end.x - 1.5:
					face = Vector2(-1, 0)
				elif r.end.y <= fr.position.y + 1.5:
					face = Vector2(0, 1)
				else:
					face = Vector2(0, -1)
				break
			out.append({"r": r, "cell": cell, "c": r.get_center(), "floors": floors, "roof": "flat" if roof_roll < 0.32 else ("gable" if roof_roll < 0.6 else "hip"),
				"face": face, "seed": sd, "front": front, "keep": keep})


static func _lot_ok(r: Rect2, keep: bool) -> bool:
	for f in rolled():
		if str(f[0]) == "court" and (f[1] as Rect2).grow(0.3).intersects(r):
			return false
	for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		if land_t(p) > -SEA_WALL_IN - 8.0 or p.y > WALL_Z - WALL_T:
			return false
		if p.distance_to(HILL_C) < GROUNDS_R + 4.0:
			return false
		if ellipse(p, ARENA_C, ARENA_R + Vector2(7.0, 7.0)) < 1.0:
			return false
	for f in FLOORS:
		if (f[1] as Rect2).intersects(r):
			return false
	if keep:
		return true
	if TEMPLE.intersects(r):
		return false
	for k in KEEP:
		if (k as Rect2).intersects(r):
			return false
	return true


## The gaps where a walkable floor's edge opens onto nothing built (a lane between blocks, a missing lot): each
## closed by a wall ([a, b, out]: the barrier's ends just outside the floor, and the way out from the floor).
static func openings(all_lots: Array) -> Array:
	var cells: Array = all_lots.filter(func(l): return not special_hit(l["cell"])).map(func(l): return (l["cell"] as Rect2).grow(0.45))
	for k in SPECIAL:
		cells.append((SPECIAL[k][0] as Rect2).grow(0.45))
	var out: Array = []
	for f in floors():
		var r: Rect2 = f[1]
		var edges := [[r.position, Vector2(r.end.x, r.position.y), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), r.end, Vector2(0, 1)],
			[r.position, Vector2(r.position.x, r.end.y), Vector2(-1, 0)], [Vector2(r.end.x, r.position.y), r.end, Vector2(1, 0)]]
		for e in edges:
			if f[0] == "quay" and (e[2] as Vector2).y > 0.0:
				continue
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var n: Vector2 = e[2]
			var steps := int(roundf(a.distance_to(b)))
			var run_from := -1
			for i in range(steps + 1):
				var open := false
				if i < steps:
					var p := a.lerp(b, (i + 0.5) / steps)
					open = _open(p + n * 0.9, cells)
				if open and run_from < 0:
					run_from = i
				elif not open and run_from >= 0:
					out.append([a.lerp(b, maxf(run_from - 0.5, 0.0) / steps) + n * 0.6, a.lerp(b, minf(i + 0.5, steps) / steps) + n * 0.6, n])
					run_from = -1
	return out


static func _open(o: Vector2, cells: Array) -> bool:
	if in_floor(o):
		return false
	# (1.27: the cathedral's own walls close its front; no wall across its doors)
	if Rect2(TEMPLE.get_center() + Vector2(4.0, 2.0) - Vector2(13.0, 16.0), Vector2(26.0, 32.0)).grow(0.6).has_point(o):
		return false
	# (inside the palace grounds' wall it's open ground: no barriers round the palace's floors)
	if o.distance_to(HILL_C) < GROUNDS_R - 4.0:
		return false
	if absf(o.y - WALL_Z) < WALL_T * 0.5 + 0.6 or absf(absf(o.x) - QUAY_END_X) < 1.8:
		return false
	if ellipse(o, ARENA_C, ARENA_R) < 0.98 or absf(o.distance_to(HILL_C) - GROUNDS_R) < 4.6:
		return false
	if absf(o.x) < 9.5 and o.y > WALL_Z - 5.5 and o.y < WALL_Z + 5.5:
		return false
	for c in cells:
		if (c as Rect2).has_point(o):
			return false
	return true

