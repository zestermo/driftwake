class_name CanalPlan
extends RefCounted
## The canal city's fixed layout (docs/v1_21_plan.md: lagoon shipbuilders, the chain's second city), as data: the same
## city in every world, only its name rolled. In its own frame like CapitalPlan's (x along the harbour front, +z out to
## sea, -z inland); CanalIsland turns it to face the way the crew sails in. Pure functions: safe on a worker.
##
## A low island of brick quays on a lagoon cut by canals the sea fills: the Grand Canal straight inland from the
## harbour, two cross canals, the arsenal's basin opening east to the sea. Between them, blocks of tall narrow houses
## with walkways (fondamente) along every canal edge, lanes (calli) through each block meeting at a small square
## (campo) with its well, bridges over the canals. On the harbour front, the riva (the long quay where the ship
## berths) and the piazza with its church and campanile; the market by the Grand Canal under the market bridge; the
## arsenal's yards with their slipways on the basin.

const QUAY_Y := 1.6
## The riva's sea edge (the harbour's), and where the land is: a disc cut by the harbour front.
const FRONT_Z := 110.0
const LAND_C := Vector2(0.0, -40.0)
const LAND_R := 215.0
const CANAL_BED := -4.0
const SEAFLOOR := -16.0
const FLOOR_DROP := 0.5
## Fondamenta width, calli width.
const WALK := 4.0
const CALLE := 3.6
## The ship's berth along the riva (bow along +x).
const BERTH := Vector2(70.0, 117.0)

## The water inside the city: [name, rect].
const CANALS := [
	["grand", Rect2(-12.0, -260.0, 24.0, 370.0)],
	["c1", Rect2(-240.0, 20.0, 480.0, 12.0)],
	["c2", Rect2(-240.0, -90.0, 480.0, 12.0)],
	["basin", Rect2(128.0, -160.0, 140.0, 90.0)],
]
## The land between them: [name, rect, the sides that face water with a walkway ("n" = -z, "s" = +z, "w", "e")].
const BLOCKS := [
	["sw", Rect2(-200.0, 32.0, 188.0, 64.0), "ne"],
	["se", Rect2(12.0, 32.0, 188.0, 64.0), "nw"],
	["mw", Rect2(-200.0, -78.0, 188.0, 98.0), "nse"],
	["me", Rect2(12.0, -78.0, 116.0, 98.0), "nsw"],
	["yard", Rect2(128.0, -70.0, 72.0, 90.0), "ns"],
	["nw", Rect2(-200.0, -180.0, 188.0, 90.0), "se"],
	["ne", Rect2(12.0, -180.0, 116.0, 90.0), "swe"],
]
## The riva either side of the Grand Canal's mouth.
const RIVA := [Rect2(-185.0, 96.0, 173.0, 14.0), Rect2(12.0, 96.0, 173.0, 14.0)]
## The piazza on the harbour front (the se block), the arsenal's open yard.
const PIAZZA := Rect2(24.0, 56.0, 80.0, 40.0)
const ARSENAL := Rect2(128.0, -62.0, 42.0, 68.0)
## Buildings of their own: [rect, the way their front faces].
const SPECIAL := {
	"church": [Rect2(44.0, 36.0, 40.0, 20.0), Vector2(0, 1)],
	"campanile": [Rect2(16.0, 58.0, 7.0, 7.0), Vector2(1, 0)],
	"market": [Rect2(16.0, -24.0, 28.0, 18.0), Vector2(-1, 0)],
	"inn": [Rect2(-38.0, -52.0, 22.0, 20.0), Vector2(1, 0)],
	"masters": [Rect2(136.0, 6.0, 28.0, 10.0), Vector2(0, -1)],
	"sheds": [Rect2(170.0, -40.0, 26.0, 40.0), Vector2(-1, 0)],
	# 1.27 C3: the Doge's palace on the piazza's east side, its door west onto the piazza (CapitalHalls "doge")
	"doge": [Rect2(104.0, 58.0, 28.0, 38.0), Vector2(-1, 0)],
	# 1.27 C3: the glassworks on the me block's north walkway, the fish loggia on the riva (CapitalHalls)
	"glassworks": [Rect2(96.0, -74.0, 26.0, 18.0), Vector2(0, -1)],
	"loggia": [Rect2(140.0, 76.0, 26.0, 20.0), Vector2(0, 1)],
}
## Bridges over the water: [from, to (frame points on the floors either side), width, rise at the middle].
const BRIDGES := [
	[Vector2(-12.0, 103.0), Vector2(12.0, 103.0), 12.0, 2.4],
	[Vector2(-12.0, 66.0), Vector2(12.0, 66.0), 4.0, 2.2],
	[Vector2(-12.0, -30.0), Vector2(12.0, -30.0), 10.0, 3.0],
	[Vector2(-12.0, -132.0), Vector2(12.0, -132.0), 4.0, 2.2],
	[Vector2(-110.0, 20.0), Vector2(-110.0, 32.0), 4.0, 1.8],
	[Vector2(-44.0, 20.0), Vector2(-44.0, 32.0), 4.0, 1.8],
	[Vector2(60.0, 20.0), Vector2(60.0, 32.0), 4.0, 1.8],
	[Vector2(150.0, 20.0), Vector2(150.0, 32.0), 4.0, 1.8],
	[Vector2(-110.0, -90.0), Vector2(-110.0, -78.0), 4.0, 1.8],
	[Vector2(-44.0, -90.0), Vector2(-44.0, -78.0), 4.0, 1.8],
	[Vector2(70.0, -90.0), Vector2(70.0, -78.0), 4.0, 1.8],
]
## The water taxi landings: [name, frame point on the walkway's edge, the way to the water].
const LANDINGS := [
	["The riva", Vector2(-30.0, 108.0), Vector2(0, 1)],
	["The market bridge", Vector2(13.5, -20.0), Vector2(-1, 0)],
	["The arsenal", Vector2(150.0, -68.5), Vector2(0, -1)],
	["The inn", Vector2(-14.5, -56.0), Vector2(1, 0)],
	["The north campo", Vector2(-80.0, -91.5), Vector2(0, 1)],
	["The church", Vector2(70.0, 33.5), Vector2(0, -1)],
]


static func smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Signed distance from the coast (- inland).
static func land_t(q: Vector2) -> float:
	return maxf(q.distance_to(LAND_C) - LAND_R, q.y - FRONT_Z)


static func in_canal(q: Vector2, grow := 0.0) -> bool:
	for c in CANALS:
		if (c[1] as Rect2).grow(grow).has_point(q):
			return true
	return false


## How far into the water a point is from the nearest canal edge (- on land): for the bed's slope.
static func canal_depth(q: Vector2) -> float:
	var best := -INF
	for c in CANALS:
		var r: Rect2 = c[1]
		best = maxf(best, minf(minf(q.x - r.position.x, r.end.x - q.x), minf(q.y - r.position.y, r.end.y - q.y)))
	return best


## The designed ground: the quays everywhere on land.
static func ground(_q: Vector2) -> float:
	return QUAY_Y


# --------------------------------------------------------------------------
# Walkways
# --------------------------------------------------------------------------
## Every walkable floor: [name, rect, texture]. The riva, each block's walkways on its water sides, its lanes and campo,
## the piazza and the arsenal's yard. Built once (a static cache).
static var _floors: Array = []
## (1.27) The world's seed (CanalIsland.prepare sets it): each block's campo sits off its middle and a calle may close.
static var world_seed := 0
static var _floors_for := -1


static func use_seed(s: int) -> void:
	world_seed = s


static func floors() -> Array:
	if not _floors.is_empty() and _floors_for == world_seed:
		return _floors
	var out: Array = []
	out.append(["riva_w", RIVA[0], "capital_slabs"])
	out.append(["riva_e", RIVA[1], "capital_slabs"])
	for b in BLOCKS:
		var r: Rect2 = b[1]
		var sides: String = b[2]
		var name := str(b[0])
		var top := r.position.y + (WALK if sides.contains("n") else 0.0)
		var bot := r.end.y - (WALK if sides.contains("s") else 0.0)
		if sides.contains("n"):
			out.append([name + "_n", Rect2(r.position.x, r.position.y, r.size.x, WALK), "cobbles"])
		if sides.contains("s"):
			out.append([name + "_s", Rect2(r.position.x, r.end.y - WALK, r.size.x, WALK), "cobbles"])
		if sides.contains("w"):
			out.append([name + "_w", Rect2(r.position.x, top, WALK, bot - top), "cobbles"])
		if sides.contains("e"):
			out.append([name + "_e", Rect2(r.end.x - WALK, top, WALK, bot - top), "cobbles"])
		if name in ["se", "yard"]:
			continue
		# a lane each way through the block, crossing at its campo (open to the walkways it reaches); (1.27) the campo off
		# the block's middle by the seed, and now and then one of its four calli shut (never two)
		var brng := RandomNumberGenerator.new()
		brng.seed = hash([name, world_seed, 5501])
		var c := _campo_of(r)
		if world_seed != 0:
			var inner_r := r.grow(-(WALK + 14.0))
			if inner_r.size.x > 0.0 and inner_r.size.y > 0.0:
				c = Vector2(roundf(lerpf(inner_r.position.x, inner_r.end.x, brng.randf()) / 2.0) * 2.0, roundf(lerpf(inner_r.position.y, inner_r.end.y, brng.randf()) / 2.0) * 2.0)
				if special_hit(Rect2(c - Vector2(8.0, 8.0), Vector2(16.0, 16.0)).grow(2.0)):
					c = _campo_of(r)
		var shut := brng.randi() % 4 if world_seed != 0 and brng.randf() < 0.4 else -1
		var x0 := r.position.x + (WALK if sides.contains("w") else 0.0)
		var x1 := r.end.x - (WALK if sides.contains("e") else 0.0)
		var cr := Rect2(c - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
		out.append([name + "_campo", cr, "capital_slabs"])
		if sides.contains("n") and shut != 0 and not special_hit(Rect2(c.x - CALLE * 0.5, top, CALLE, cr.position.y - top)):
			out.append([name + "_cn", Rect2(c.x - CALLE * 0.5, top, CALLE, cr.position.y - top), "cobbles"])
		if (sides.contains("s") or name in ["sw"]) and shut != 1 and not special_hit(Rect2(c.x - CALLE * 0.5, cr.end.y, CALLE, bot - cr.end.y)):
			out.append([name + "_cs", Rect2(c.x - CALLE * 0.5, cr.end.y, CALLE, bot - cr.end.y), "cobbles"])
		if shut != 2 and not special_hit(Rect2(x0, c.y - CALLE * 0.5, cr.position.x - x0, CALLE)):
			out.append([name + "_cw", Rect2(x0, c.y - CALLE * 0.5, cr.position.x - x0, CALLE), "cobbles"])
		if shut != 3 and not special_hit(Rect2(cr.end.x, c.y - CALLE * 0.5, x1 - cr.end.x, CALLE)):
			out.append([name + "_ce", Rect2(cr.end.x, c.y - CALLE * 0.5, x1 - cr.end.x, CALLE), "cobbles"])
	out.append(["piazza", PIAZZA, "capital_slabs"])
	# the piazza reaches the walkway along the Grand Canal by a lane past the campanile
	out.append(["piazza_cw", Rect2(16.0, 66.0, 8.0, 30.0), "capital_slabs"])
	# (1.27) the paving from the campanile's door down onto that lane
	out.append(["campanile_door", Rect2(16.5, 65.0, 6.0, 1.0), "capital_slabs"])
	out.append(["arsenal", ARSENAL, "capital_slabs"])
	_floors = _clip(out)
	_floors_for = world_seed
	return _floors


## A block's campo: off its middle, kept clear of the specials.
static func _campo_of(r: Rect2) -> Vector2:
	var c := r.get_center()
	return Vector2(roundf(c.x / 2.0) * 2.0, roundf(c.y / 2.0) * 2.0)


## Floors kept on the land: none whose middle is off the coast, none too thin to walk.
static func _clip(fl: Array) -> Array:
	return fl.filter(func(f): return land_t((f[1] as Rect2).get_center()) < -2.0 and (f[1] as Rect2).size.x >= 1.0 and (f[1] as Rect2).size.y >= 1.0)


static func in_floor(q: Vector2, grow := 0.0) -> bool:
	for f in floors():
		if (f[1] as Rect2).grow(grow).has_point(q):
			return true
	return false


static func special_hit(r: Rect2) -> bool:
	for k in SPECIAL:
		if (SPECIAL[k][0] as Rect2).intersects(r):
			return true
	return false


## The terrain grid's height: the quays on land (floors laid FLOOR_DROP over it), a canal's bed dropping steeply from
## its edges (the quay walls hide them), the lagoon's floor past the coast.
static func terrain(q: Vector2) -> float:
	var t := land_t(q)
	if t > 0.0:
		return lerpf(-1.0, SEAFLOOR, smooth(0.0, 40.0, t))
	if in_canal(q):
		return lerpf(-1.5, CANAL_BED, smooth(0.0, 3.0, canal_depth(q)))
	var h := QUAY_Y
	if t > -3.0:
		h = lerpf(QUAY_Y, -1.0, smooth(-3.0, 0.0, t))
	if in_floor(q, 2.0):
		h -= FLOOR_DROP
	return h


# --------------------------------------------------------------------------
# Houses
# --------------------------------------------------------------------------
## Every house lot: a block's ground inside its walkways cut into bands between its east-west floors (its lanes, its
## campo), each band into rows at most 12 m deep, each row into spans between its north-south floors, each span
## filled edge to edge with narrow lots, so every lane and campo is lined with houses (no gaps to wall off).
## {"r", "cell", "c", "floors", "roof", "face", "seed", "front", "keep": false}.
static var _lots: Array = []
static var _lots_for := -1


static func lots() -> Array:
	# (cached per seed: the district records each walkable roof on its lot, the roofs read them back)
	if _lots_for == world_seed and not _lots.is_empty():
		return _lots
	var rng := RandomNumberGenerator.new()
	rng.seed = 61021 if world_seed == 0 else hash([61021, world_seed])
	var out: Array = []
	var fl := floors()
	for b in BLOCKS:
		var r: Rect2 = b[1]
		var sides: String = b[2]
		var inner := Rect2(r.position + Vector2(WALK if sides.contains("w") else 0.0, WALK if sides.contains("n") else 0.0),
			r.size - Vector2((WALK if sides.contains("w") else 0.0) + (WALK if sides.contains("e") else 0.0),
				(WALK if sides.contains("n") else 0.0) + (WALK if sides.contains("s") else 0.0)))
		var inside: Array = fl.filter(func(f): return (f[1] as Rect2).intersects(inner))
		for band in _cut(inner.position.y, inner.end.y, inside.filter(func(f): return (f[1] as Rect2).size.x > (f[1] as Rect2).size.y and (f[1] as Rect2).size.y < 8.0).map(
				func(f): return Vector2((f[1] as Rect2).position.y, (f[1] as Rect2).end.y))):
			var bh: float = band.y - band.x
			var n_rows := maxi(ceili(bh / 12.0), 1)
			for ri in range(n_rows):
				var y0: float = band.x + bh * ri / n_rows
				var y1: float = band.x + bh * (ri + 1) / n_rows
				var row := Rect2(inner.position.x, y0, inner.size.x, y1 - y0)
				var cross: Array = inside.filter(func(f): return (f[1] as Rect2).intersects(row)).map(func(f): return Vector2((f[1] as Rect2).position.x, (f[1] as Rect2).end.x))
				for span in _cut(inner.position.x, inner.end.x, cross):
					var x: float = span.x
					while x < span.y - 0.5:
						var w := minf(rng.randf_range(5.0, 8.5), span.y - x)
						if span.y - (x + w) < 3.5:
							w = span.y - x
						var cell := Rect2(x, y0, w, y1 - y0)
						x += w
						var lr := cell.grow(-rng.randf_range(0.0, 0.2))
						var floors_n := rng.randi_range(3, 5)
						var roof_roll := rng.randf()
						var sd := rng.randi()
						if w < 2.5 or not _lot_ok(lr, fl):
							continue
						var face := Vector2(0, -1)
						var front := false
						for f in fl:
							var fr: Rect2 = f[1]
							if not fr.grow(1.5).intersects(lr):
								continue
							front = true
							if lr.end.x <= fr.position.x + 1.5:
								face = Vector2(1, 0)
							elif lr.position.x >= fr.end.x - 1.5:
								face = Vector2(-1, 0)
							elif lr.end.y <= fr.position.y + 1.5:
								face = Vector2(0, 1)
							else:
								face = Vector2(0, -1)
							break
						out.append({"r": lr, "cell": cell, "c": lr.get_center(), "floors": floors_n, "roof": "flat" if roof_roll < 0.3 else ("gable" if roof_roll < 0.7 else "hip"),
							"face": face, "seed": sd, "front": front, "keep": false})
	_lots = out
	_lots_for = world_seed
	return out


## The parts of [a, b] outside every [lo, hi] in `holes` (each Vector2(lo, hi)), as Vector2(start, end) spans.
static func _cut(a: float, b: float, holes: Array) -> Array:
	var hs := holes.duplicate()
	hs.sort_custom(func(p, q): return p.x < q.x)
	var out: Array = []
	var at := a
	for h in hs:
		if h.y <= at:
			continue
		if h.x > at:
			out.append(Vector2(at, minf(h.x, b)))
		at = maxf(at, h.y)
		if at >= b:
			break
	if at < b:
		out.append(Vector2(at, b))
	return out.filter(func(s): return s.y - s.x >= 3.0)


static func _lot_ok(r: Rect2, fl: Array) -> bool:
	for p in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		if land_t(p) > -6.0 or in_canal(p, 0.5):
			return false
	for f in fl:
		if (f[1] as Rect2).intersects(r):
			return false
	return not special_hit(r)


## The gaps where a floor's edge opens onto nothing built: each closed by a barrier ([a, b, out]), as CapitalPlan's.
## Water and the bridges' ends are open on purpose (you can jump in; you cross there).
static func openings(all_lots: Array) -> Array:
	var cells: Array = all_lots.map(func(l): return (l["cell"] as Rect2).grow(0.45))
	for k in SPECIAL:
		cells.append((SPECIAL[k][0] as Rect2).grow(0.45))
	var out: Array = []
	for f in floors():
		var r: Rect2 = f[1]
		var edges := [[r.position, Vector2(r.end.x, r.position.y), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), r.end, Vector2(0, 1)],
			[r.position, Vector2(r.position.x, r.end.y), Vector2(-1, 0)], [Vector2(r.end.x, r.position.y), r.end, Vector2(1, 0)]]
		for e in edges:
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
	if in_floor(o) or in_canal(o, 0.3) or land_t(o) > -1.0:
		return false
	for c in cells:
		if (c as Rect2).has_point(o):
			return false
	return true
