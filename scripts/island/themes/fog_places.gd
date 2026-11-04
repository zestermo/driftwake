extends RefCounted
## The fog isle's own pieces (FogTheme.steps, after the land's): the old lantern posts along its ways, cold till a
## captain lights them; the village's graveyard with its crypt; the haunts where the dead walk (ghosts in the dead
## wood, the drowned up out of the graves).
##
## Lanterns (docs/v1_20_plan.md "Its mechanic"): F lights one (Net.world_flag "isle<id>_lantern_<n>": every machine,
## saved, a late joiner sees it lit). Lit, it burns warm, the fog thins round it (FogClear tells Weather how near the
## camera is to the nearest lit one: Weather.lantern_clear) and the dead keep out of its glow (lit_near(): Drowned and
## Ghost steer out of LIGHT_R; a ghost caught in it burns).

## Lanterns along the ways: one every SPACING m of path, this far off its edge; the first ones at the village's end.
const SPACING := 48.0
const OFF := 2.2
const MAX_LANTERNS := 22
## The glow the dead keep out of, and the fog's thinning round a lit lantern (full inside CLEAR_IN, none past CLEAR_OUT).
const LIGHT_R := 7.0
const CLEAR_IN := 6.0
const CLEAR_OUT := 18.0
const LAMP := Color(1.0, 0.76, 0.42)

const Lantern := preload("res://scripts/island/themes/fog_lantern.gd")


static func steps(isl) -> Array:
	return [["lanterns", func(): lanterns(isl)], ["haunts", func(): haunts(isl)]]


## Is a lit lantern within `r` of `p` (world)? (the dead ask: they keep out)
static func lit_near(tree: SceneTree, p: Vector3, r := LIGHT_R) -> bool:
	for n in tree.get_nodes_in_group("fog_lanterns"):
		if n.lit and (n as Node3D).global_position.distance_squared_to(p) < r * r:
			return true
	return false


## The way out of the nearest lit lantern's glow from `p` (flat, unit), or zero outside every glow.
static func away_from_light(tree: SceneTree, p: Vector3, r := LIGHT_R) -> Vector3:
	var best := r * r
	var out := Vector3.ZERO
	for n in tree.get_nodes_in_group("fog_lanterns"):
		if not n.lit:
			continue
		var d: Vector3 = p - (n as Node3D).global_position
		d.y = 0.0
		if d.length_squared() < best:
			best = d.length_squared()
			out = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	return out


# ==========================================================================
# The lanterns
# ==========================================================================
static func lanterns(isl) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "lanterns"])
	var spots: Array = []
	var vil: Vector2 = isl.sites.get("village", Vector2.ZERO)
	for path in isl.paths:
		var pts: PackedVector2Array = path
		var run := SPACING * 0.5
		for i in range(1, pts.size()):
			run += pts[i].distance_to(pts[i - 1])
			if run < SPACING:
				continue
			var along := (pts[i] - pts[i - 1]).normalized()
			var side := Vector2(-along.y, along.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var q: Vector2 = pts[i] + side * (OFF + rng.randf_range(0.0, 0.6))
			if isl.excluded(q, 0.8, 30.0) or q.distance_to(vil) < 18.0 or spots.any(func(s): return (s as Vector2).distance_to(q) < SPACING * 0.6):
				continue
			run = 0.0
			spots.append(q)
	# the nearest the village first (the route lights outward from home), as many as the budget holds
	spots.sort_custom(func(a, b): return (a as Vector2).distance_to(vil) < (b as Vector2).distance_to(vil))
	var host := _host(isl)
	for i in range(mini(spots.size(), MAX_LANTERNS)):
		var q: Vector2 = spots[i]
		var l := Lantern.new()
		l.name = "Lantern%d" % i
		l.key = isl.save_key("lantern_%d" % i)
		host.add_child(l)
		l.position = Vector3(q.x, isl.hv(q), q.y)
		l.rotation.y = rng.randf() * TAU
	var clear := FogClear.new()
	clear.name = "FogClear"
	host.add_child(clear)


## How much a lit lantern near the camera thins the fog, for Weather (0 none .. 1 inside a lantern's glow), every
## screen its own (the lanterns' lit state is the world's).
class FogClear extends Node:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		_t = 0.25
		var cam := get_viewport().get_camera_3d()
		var w := get_node_or_null("/root/Weather")
		if cam == null or w == null:
			return
		var best := INF
		for n in get_tree().get_nodes_in_group("fog_lanterns"):
			if n.lit:
				best = minf(best, (n as Node3D).global_position.distance_to(cam.global_position))
		var k := 1.0 - smoothstep(CLEAR_IN, CLEAR_OUT, best) if best < INF else 0.0
		if "lantern_clear" in w:
			w.set("lantern_clear", k)

	func _exit_tree() -> void:
		var w := get_node_or_null("/root/Weather")
		if w and "lantern_clear" in w:
			w.set("lantern_clear", 0.0)


# ==========================================================================
# The graveyard
# ==========================================================================
## The graveyard's reach (1.30: grown from 9 m); a smaller one where no ground that big is free.
const GRAVE_R := 15.0
const GRAVE_R_SMALL := 11.0
## Fresh graves with a zombie under each.
const ZOMBIES := [4, 6]


## The graveyard's ground (GenIsland.prepare, on the worker: FogTheme.plan_places): a flat-ish spot 30-90 m out of the
## village, off the paths, a trail run to its gate (KitLandmarks), the plants kept off it.
static func plan_places(isl, avoid: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "graveyard"])
	var vil: Vector2 = isl.sites.get("village", Vector2.ZERO)
	for r in [GRAVE_R, GRAVE_R_SMALL]:
		for k in range(60):
			var p := vil + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 90.0)
			var h: float = isl.hv(p)
			if h < 1.5 or KitLandmarks.grad(isl, p, r * 0.6).length() > 0.2 or not KitLandmarks.clear_of(isl, p, r, avoid) or isl.path_dist(p) < r * 0.55:
				continue
			var face := (KitSetPieces._nearest_path(isl, p) - p).normalized()
			return [{"kind": "fog_graveyard", "at": p, "y": h, "face": face, "r": r, "door": p + face * (r * 0.9),
				"keep": [[Vector2.ZERO, r]]}]
	return []


## The village's graveyard (place-local: +z toward its gate, 1.30): a stone plinth carrying an iron railing round it
## (spear-tipped bars, piers, a run of it fallen), the gate under an iron arch with its leaves hanging open, a gravel
## walk up the middle to the crypt at its back (columns, a pediment, a black door behind a grille), a mausoleum in each
## back corner, rows of headstones either side of the walk (slabs, crosses, obelisks, broken ones with their tops
## lying beside them, a few fallen flat), stone tombs, dead trees, and the fresh graves the zombies are under (their
## spots go to the FaunaSpawner). Two lanterns at the gate. One mesh (a draw call a material), static colliders.
static func graveyard(isl, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var g := {
		"stone": PSXMat.lit("moss_stone", Color(0.6, 0.62, 0.62), {"affine": 0.6}),
		"wall": PSXMat.lit("stone_brick", Color(0.56, 0.58, 0.58), {"affine": 0.6}),
		"iron": PSXMat.flat(Color(0.12, 0.12, 0.13)),
		"mud": PSXMat.lit("fog_mud", Color.WHITE),
		"bark": FogPlants.bark(),
		"black": PSXMat.flat(Color(0.03, 0.03, 0.03)),
	}
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Walls"
	var y0 := float(pl["y"])
	var r := float(pl.get("r", GRAVE_R))
	var W := r * 1.45
	var D := r * 1.2
	var gy := func(x: float, z: float) -> float: return float(isl.hv(KitLandmarks.lp(pl, x, z))) - y0
	var put := func(m: Material, b: Basis, x: float, z: float, up: float, size: Vector3, col := true) -> void:
		var xf := Transform3D(b, Vector3(x, gy.call(x, z) + up, z))
		mb.add_box(m, xf, size, 0.6, Color.WHITE.darkened(rng.randf() * 0.18))
		if col:
			KitLandmarks.box_col_xf(body, size, xf)
	_railing(mb, body, g, put, gy, rng, W, D)
	_gate(mb, g, put, gy, rng, D)
	# the gravel walk up the middle
	for k in range(int(D / 1.1)):
		var z := D * 0.5 - 0.6 - k * 1.1
		mb.add_box(g["mud"], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), Vector3(rng.randf_range(-0.08, 0.08), gy.call(0.0, z) + 0.02, z)), Vector3(1.8, 0.06, 1.05), 0.6, Color(0.7, 0.7, 0.68))
	_crypt(mb, body, g, put, gy, -D * 0.5 + 2.4)
	var mz := -D * 0.5 + 2.2
	for s in [-1.0, 1.0]:
		_mausoleum(mb, g, put, gy, rng, s * (W * 0.5 - 2.4), mz, rng.randi() % 2 == 0)
	# the rows either side of the walk; the graves left fresh are the zombies'
	var fresh: Array = []
	var cols := int((W * 0.5 - 2.2) / 1.6)
	var rows := int((D - 7.5) / 2.0)
	var spots: Array = []
	for row in range(rows):
		for k in range(cols):
			for s in [-1.0, 1.0]:
				var x: float = s * (1.9 + k * 1.6 + rng.randf_range(-0.2, 0.2))
				var z := mz + 3.0 + row * 2.0 + rng.randf_range(-0.2, 0.2)
				if absf(x) > W * 0.5 - 1.0 or z > D * 0.5 - 1.6:
					continue
				spots.append(Vector2(x, z))
	var nz := mini(rng.randi_range(ZOMBIES[0], ZOMBIES[1]), spots.size())
	var order := range(spots.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	for i in range(spots.size()):
		var q: Vector2 = spots[order[i]]
		if rng.randf() < 0.08 and i >= nz:
			continue
		_headstone(mb, g, put, gy, rng, q.x, q.y, i < nz)
		if i < nz:
			fresh.append(q + Vector2(0, 0.85))
	# stone tombs and dead trees among them
	for k in range(rng.randi_range(2, 3)):
		var x := (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(2.4, W * 0.5 - 2.0)
		var z := rng.randf_range(mz + 3.0, D * 0.5 - 2.5)
		if fresh.any(func(f): return (f as Vector2).distance_to(Vector2(x, z)) < 1.6):
			continue
		var tb := Basis(Vector3.UP, rng.randf_range(-0.1, 0.1))
		put.call(g["stone"], tb, x, z, 0.35, Vector3(0.95, 0.7, 2.0))
		put.call(g["stone"], tb * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)), x, z, 0.78, Vector3(1.1, 0.14, 2.15), false)
	for k in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		var q := Vector2(cos(a) * (W * 0.5 - 1.2), sin(a) * (D * 0.5 - 1.2))
		_dead_tree(mb, g, body, gy, rng, q.x, q.y)
	var mi := mb.to_instance("Stones")
	mi.visibility_range_end = 280.0
	node.add_child(mi)
	node.add_child(body)
	var host := _host(isl)
	for s in [0, 1]:
		var x := -2.4 if s == 0 else 2.4
		var l := Lantern.new()
		l.name = "GateLantern%d" % s
		l.key = isl.save_key("lantern_gate_%d" % s)
		host.add_child(l)
		var q := KitLandmarks.lp(pl, x, D * 0.5 + 1.0)
		l.position = Vector3(q.x, isl.hv(q), q.y)
	var fauna = FaunaSpawner.of(isl)
	if fauna and not fresh.is_empty():
		var pts: Array = []
		for f in fresh:
			var q := KitLandmarks.lp(pl, f.x, f.y)
			pts.append(isl.to_global(Vector3(q.x, isl.hv(q), q.y)))
		fauna.add_spots("zombie", pts)


## The railing: a stone plinth round three sides and the front either side of the gate, piers every few metres, iron
## bars with spear tips between; a run of it fallen in, bars bent or gone.
static func _railing(mb: MeshBuilder, body: StaticBody3D, g: Dictionary, put: Callable, gy: Callable, rng: RandomNumberGenerator, W: float, D: float) -> void:
	var sides := [[Vector2(-W * 0.5, D * 0.5), Vector2(-1.7, D * 0.5)], [Vector2(1.7, D * 0.5), Vector2(W * 0.5, D * 0.5)],
		[Vector2(W * 0.5, D * 0.5), Vector2(W * 0.5, -D * 0.5)], [Vector2(W * 0.5, -D * 0.5), Vector2(-W * 0.5, -D * 0.5)],
		[Vector2(-W * 0.5, -D * 0.5), Vector2(-W * 0.5, D * 0.5)]]
	var fallen := rng.randi_range(2, 4)
	var fall_at := rng.randf_range(0.25, 0.75)
	for si in range(sides.size()):
		var a: Vector2 = sides[si][0]
		var b: Vector2 = sides[si][1]
		var len := a.distance_to(b)
		var dir := (b - a) / len
		var yaw := atan2(-dir.y, dir.x)
		var n := maxi(int(len / 3.6), 1)
		for k in range(n):
			var p0 := a + dir * (len * k / n)
			var p1 := a + dir * (len * (k + 1) / n)
			var m := (p0 + p1) * 0.5
			var down: bool = si == fallen and absf(float(k) / n - fall_at) < 0.2
			put.call(g["wall"], Basis(Vector3.UP, yaw), m.x, m.y, 0.15, Vector3(len / n, 0.5, 0.42))
			put.call(g["wall"], Basis(), p0.x, p0.y, 0.6, Vector3(0.48, 1.6 if not down else 0.7, 0.48))
			put.call(g["stone"], Basis(), p0.x, p0.y, 1.45 if not down else 0.98, Vector3(0.6, 0.12, 0.6), false)
			if down:
				# fallen in: the bars lying in the grass inside
				var inward := Vector2(-dir.y, dir.x) * (1.0 if (Vector2.ZERO - m).dot(Vector2(-dir.y, dir.x)) > 0.0 else -1.0)
				for j in range(3):
					var q := m + inward * (0.8 + j * 0.25) + dir * rng.randf_range(-0.8, 0.8)
					var lb := Basis(Vector3.UP, yaw + rng.randf_range(-0.3, 0.3)) * Basis(Vector3.BACK, PI * 0.5)
					mb.add_box(g["iron"], Transform3D(lb, Vector3(q.x, gy.call(q.x, q.y) + 0.05, q.y)), Vector3(0.05, len / n * 0.8, 0.05), 1.0)
				continue
			var bars := int(len / n / 0.32)
			var tilt := rng.randf_range(-0.05, 0.05)
			for j in range(1, bars):
				if rng.randf() < 0.06:
					continue
				var q := p0 + dir * (len / n * j / bars)
				var bend := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt + (rng.randf_range(-0.3, 0.3) if rng.randf() < 0.05 else 0.0))
				var base := Vector3(q.x, gy.call(q.x, q.y) + 0.4, q.y)
				mb.add_box(g["iron"], Transform3D(bend, base + bend.y * 0.65), Vector3(0.035, 1.3, 0.035), 1.0)
				mb.add_cone(g["iron"], Transform3D(bend, base + bend.y * 1.3), 0.045, 0.16, 4)
			for h in [0.55, 1.15]:
				var y0: float = gy.call(m.x, m.y) + 0.4 + h
				mb.add_box(g["iron"], Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt), Vector3(m.x, y0, m.y)), Vector3(len / n, 0.04, 0.03), 1.0)
			# (one collider for the run of bars)
			KitLandmarks.box_col_xf(body, Vector3(len / n, 1.4, 0.12), Transform3D(Basis(Vector3.UP, yaw), Vector3(m.x, gy.call(m.x, m.y) + 1.1, m.y)))


## The gate: tall piers with stone balls, an iron arch over the way in with a cross in it, both leaves hanging open.
static func _gate(mb: MeshBuilder, g: Dictionary, put: Callable, gy: Callable, rng: RandomNumberGenerator, D: float) -> void:
	var z := D * 0.5
	for s in [-1.0, 1.0]:
		put.call(g["wall"], Basis(), s * 1.7, z, 1.3, Vector3(0.6, 2.8, 0.6))
		put.call(g["stone"], Basis(), s * 1.7, z, 2.75, Vector3(0.75, 0.14, 0.75), false)
		mb.add_blob(g["stone"], Transform3D(Basis(), Vector3(s * 1.7, gy.call(s * 1.7, z) + 3.05, z)), Vector3(0.2, 0.2, 0.2), rng, 0.05, 3, 6)
		# a leaf of the gate swung in and hanging off its lower hinge
		var hinge := Vector3(s * 1.4, gy.call(s * 1.4, z) + 0.15, z)
		var lb := Basis(Vector3.UP, s * rng.randf_range(1.0, 1.5)) * Basis(Vector3.BACK, s * 0.06)
		for j in range(6):
			var x: float = -s * (0.12 + j * 0.22)
			mb.add_box(g["iron"], Transform3D(lb, hinge + lb * Vector3(x, 0.9, 0)), Vector3(0.035, 1.8, 0.035), 1.0)
		for h in [0.2, 1.0, 1.75]:
			mb.add_box(g["iron"], Transform3D(lb, hinge + lb * Vector3(-s * 0.65, h, 0)), Vector3(1.35, 0.05, 0.03), 1.0)
	var top: float = gy.call(0.0, z) + 2.85
	var arch := PackedVector3Array()
	for k in range(9):
		var a := PI * k / 8.0
		arch.append(Vector3(cos(a) * 1.7, top + sin(a) * 0.8, z))
	mb.add_tube(g["iron"], arch, 0.045, 0.045, 4, 1.0)
	mb.add_box(g["iron"], Transform3D(Basis(), Vector3(0, top + 1.0, z)), Vector3(0.05, 0.6, 0.05), 1.0)
	mb.add_box(g["iron"], Transform3D(Basis(), Vector3(0, top + 1.1, z)), Vector3(0.32, 0.05, 0.05), 1.0)


## The crypt across the back: a stone house half sunk in the bank, two columns each side of its door under a pediment,
## steps down to a black doorway behind an iron grille, a cross on the ridge.
static func _crypt(mb: MeshBuilder, body: StaticBody3D, g: Dictionary, put: Callable, gy: Callable, cz: float) -> void:
	var cy: float = gy.call(0.0, cz)
	put.call(g["wall"], Basis(), 0.0, cz - 0.4, 1.5, Vector3(4.6, 3.2, 3.6))
	mb.add_gable_roof(g["stone"], Transform3D(Basis(), Vector3(0, cy + 3.1, cz - 0.4)), 4.6, 3.6, 1.3, 0.35, 0.6)
	for x in [-1.6, -0.9, 0.9, 1.6]:
		mb.add_cylinder(g["stone"], Transform3D(Basis(), Vector3(x, cy - 0.1, cz + 1.75)), 0.2, 0.17, 3.05, 7, 0.6)
		KitLandmarks.box_col_xf(body, Vector3(0.35, 3.0, 0.35), Transform3D(Basis(), Vector3(x, cy + 1.4, cz + 1.75)))
	put.call(g["stone"], Basis(), 0.0, cz + 1.75, 3.05, Vector3(4.0, 0.3, 0.6), false)
	mb.add_extrude(g["stone"], Transform3D(Basis(), Vector3(0, cy + 3.2, cz + 1.5)), PackedVector2Array([Vector2(-2.1, 0), Vector2(2.1, 0), Vector2(0, 1.0)]), 0.5, 0.6)
	for k in range(3):
		put.call(g["stone"], Basis(), 0.0, cz + 2.4 + k * 0.4, 0.12 - k * 0.04, Vector3(2.0, 0.24, 0.4), false)
	var door := Vector3(0, cy + 1.05, cz + 1.42)
	mb.add_box(g["black"], Transform3D(Basis(), door), Vector3(1.2, 2.1, 0.05))
	for k in range(6):
		mb.add_box(g["iron"], Transform3D(Basis(), door + Vector3(-0.5 + k * 0.2, 0, 0.08)), Vector3(0.04, 2.1, 0.04))
	mb.add_box(g["iron"], Transform3D(Basis(), door + Vector3(0, 0.3, 0.08)), Vector3(1.1, 0.05, 0.04))
	mb.add_box(g["stone"], Transform3D(Basis(), Vector3(0, cy + 4.85, cz - 0.4)), Vector3(0.14, 0.9, 0.14))
	mb.add_box(g["stone"], Transform3D(Basis(), Vector3(0, cy + 5.0, cz - 0.4)), Vector3(0.55, 0.12, 0.14))


## A family's mausoleum: a small stone house on a plinth, pilasters at its corners, a pyramid roof (or a pitched one),
## an urn on top, its door sealed with a slab.
static func _mausoleum(mb: MeshBuilder, g: Dictionary, put: Callable, gy: Callable, rng: RandomNumberGenerator, x: float, z: float, pyramid: bool) -> void:
	var y: float = gy.call(x, z)
	put.call(g["stone"], Basis(), x, z, 0.1, Vector3(3.0, 0.45, 3.0))
	put.call(g["wall"], Basis(), x, z, 1.3, Vector3(2.4, 2.2, 2.4))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mb.add_box(g["stone"], Transform3D(Basis(), Vector3(x + sx * 1.2, y + 1.3, z + sz * 1.2)), Vector3(0.36, 2.3, 0.36), 0.6)
	put.call(g["stone"], Basis(), x, z, 2.5, Vector3(2.8, 0.22, 2.8), false)
	if pyramid:
		mb.add_pyramid_roof(g["stone"], Transform3D(Basis(), Vector3(x, y + 2.6, z)), 2.6, 2.6, 1.3, 0.1, 0.6)
	else:
		mb.add_gable_roof(g["stone"], Transform3D(Basis(), Vector3(x, y + 2.6, z)), 2.6, 2.6, 0.9, 0.1, 0.6)
	mb.add_cylinder(g["stone"], Transform3D(Basis(), Vector3(x, y + (3.9 if pyramid else 3.5), z)), 0.1, 0.22, 0.35, 6, 0.6)
	mb.add_blob(g["stone"], Transform3D(Basis(), Vector3(x, y + (4.35 if pyramid else 3.95), z)), Vector3(0.2, 0.16, 0.2), rng, 0.05, 3, 6)
	mb.add_box(g["stone"], Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)), Vector3(x, y + 1.0, z + 1.23)), Vector3(1.0, 1.7, 0.08), 0.6, Color(0.8, 0.8, 0.78))
	mb.add_box(g["black"], Transform3D(Basis(), Vector3(x + 0.52, y + 1.0, z + 1.21)), Vector3(0.06, 1.7, 0.04))


## A grave: its headstone (a slab, a cross, an obelisk, broken with its top lying beside it, or fallen flat) and the
## mound in front; `fresh`: the earth heaped up dark and loose, a spade-cut rim, the stone new and upright.
static func _headstone(mb: MeshBuilder, g: Dictionary, put: Callable, gy: Callable, rng: RandomNumberGenerator, x: float, z: float, fresh: bool) -> void:
	var h := rng.randf_range(0.7, 1.25)
	var w := rng.randf_range(0.5, 0.75)
	var lean := 0.0 if fresh else rng.randf_range(-0.2, 0.2)
	var tb := Basis(Vector3.BACK, lean) * Basis(Vector3.RIGHT, 0.0 if fresh else rng.randf_range(-0.25, 0.12))
	var kind: String = "slab" if fresh else ["slab", "slab", "cross", "obelisk", "broken", "broken", "fallen"][rng.randi() % 7]
	match kind:
		"slab":
			put.call(g["stone"], tb, x, z, h * 0.4, Vector3(w, h, 0.16))
			mb.add_cylinder(g["stone"], Transform3D(tb * Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, gy.call(x, z) + h * 0.9, z) + tb.z * 0.08), w * 0.5, w * 0.5, 0.16, 8, 0.6)
		"cross":
			put.call(g["stone"], tb, x, z, h * 0.5, Vector3(0.14, h + 0.4, 0.14))
			put.call(g["stone"], tb, x, z, h * 0.8, Vector3(0.6, 0.12, 0.14), false)
			put.call(g["stone"], Basis(), x, z, 0.08, Vector3(0.5, 0.2, 0.4), false)
		"obelisk":
			put.call(g["stone"], Basis(), x, z, 0.12, Vector3(0.55, 0.3, 0.55))
			mb.add_cylinder(g["stone"], Transform3D(tb * Basis(Vector3.UP, PI * 0.25), Vector3(x, gy.call(x, z) + 0.25, z)), 0.24, 0.15, h + 0.6, 4, 0.6, Color.WHITE, false, false, false)
			mb.add_cone(g["stone"], Transform3D(tb * Basis(Vector3.UP, PI * 0.25), Vector3(x, gy.call(x, z) + 0.85 + h, z)), 0.15, 0.25, 4)
		"broken":
			put.call(g["stone"], tb, x, z, h * 0.22, Vector3(w, h * 0.55, 0.16))
			# the jagged break, and the top lying in the grass beside it
			for k in range(3):
				mb.add_box(g["stone"], Transform3D(tb * Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6)), Vector3(x - w * 0.3 + k * w * 0.3, gy.call(x, z) + h * 0.5, z)), Vector3(w * 0.3, 0.12, 0.16), 0.6)
			var fx := x + rng.randf_range(-0.6, 0.6)
			var fz := z + rng.randf_range(0.4, 0.8)
			mb.add_box(g["stone"], Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(fx, gy.call(fx, fz) + 0.07, fz)), Vector3(w, h * 0.45, 0.14), 0.6)
		"fallen":
			mb.add_box(g["stone"], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, -PI * 0.5 + 0.05), Vector3(x, gy.call(x, z + 0.4) + 0.08, z + 0.4)), Vector3(w, h, 0.15), 0.6)
	var mz := z + 0.85
	if fresh:
		mb.add_blob(g["mud"], Transform3D(Basis(), Vector3(x, gy.call(x, mz) - 0.02, mz)), Vector3(0.5, 0.26, 0.95), rng, 0.3, 3, 6, 0.6, Color(0.55, 0.48, 0.42))
		for k in range(4):
			var a := rng.randf() * TAU
			mb.add_blob(g["mud"], Transform3D(Basis(), Vector3(x + cos(a) * 0.65, gy.call(x, mz) + 0.02, mz + sin(a) * 1.0)), Vector3(0.14, 0.08, 0.12), rng, 0.3, 2, 5, 0.6, Color(0.5, 0.44, 0.38))
	else:
		mb.add_blob(g["mud"], Transform3D(Basis(), Vector3(x, gy.call(x, mz) - 0.06, mz)), Vector3(0.42, 0.13, 0.8), rng, 0.2, 2, 5, 0.6, Color(0.8, 0.85, 0.75))


## A dead tree: a bare twisted trunk, its limbs reaching out over the graves.
static func _dead_tree(mb: MeshBuilder, g: Dictionary, body: StaticBody3D, gy: Callable, rng: RandomNumberGenerator, x: float, z: float) -> void:
	var base := Vector3(x, gy.call(x, z) - 0.3, z)
	var h := rng.randf_range(4.5, 7.5)
	var top := base + Vector3(rng.randf_range(-1.0, 1.0), h, rng.randf_range(-1.0, 1.0))
	mb.add_tube(g["bark"], PackedVector3Array([base, base.lerp(top, 0.4) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), top]), 0.38, 0.07, 6, 0.6)
	for j in range(rng.randi_range(3, 5)):
		var aa := rng.randf() * TAU
		var from := base.lerp(top, rng.randf_range(0.45, 0.9))
		var to := from + Vector3(cos(aa), rng.randf_range(0.2, 0.8), sin(aa)) * rng.randf_range(1.4, 2.6)
		mb.add_tube(g["bark"], PackedVector3Array([from, from.lerp(to, 0.5) + Vector3(0, -0.25, 0), to]), 0.11, 0.02, 4, 1.0)
	KitLandmarks.box_col_xf(body, Vector3(0.6, h, 0.6), Transform3D(Basis(), base + Vector3(0, h * 0.5, 0)))


static func _host(isl) -> Node3D:
	var host: Node3D = isl.get_node_or_null("FogLanterns")
	if host == null:
		host = Node3D.new()
		host.name = "FogLanterns"
		isl.add_child(host)
	return host


# ==========================================================================
# The haunts
# ==========================================================================
## Where the dead walk: the drowned up out of the graveyard's graves (and a ghost among them), and ghosts drifting in
## pairs along the ways out in the dead wood, far from the village. Host-run GruntCamps like any crew.
static func haunts(isl) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "haunts"])
	var vil: Vector2 = isl.sites.get("village", Vector2.ZERO)
	var groups: Array = []
	for pl in isl.places:
		if str(pl.get("kind", "")) == "fog_graveyard":
			# (its own dead are the zombies under its graves: a drowned man and a ghost walk it too)
			groups.append([KitLandmarks.lp(pl, 0.0, 0.0), ["drowned", "ghost"]])
	var far: Array = []
	for path in isl.paths:
		for pt in (path as PackedVector2Array):
			if pt.distance_to(vil) > 90.0:
				far.append(pt)
	for k in range(rng.randi_range(2, 3)):
		if far.is_empty():
			break
		var p: Vector2 = far[rng.randi() % far.size()]
		if groups.any(func(e): return (e[0] as Vector2).distance_to(p) < 60.0):
			continue
		groups.append([p, ["ghost", "ghost"] if rng.randf() < 0.6 else ["ghost", "drowned", "ghost"]])
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker") if isl.get_parent() else null
	for gi in range(groups.size()):
		var c: Vector2 = groups[gi][0]
		var crew := GruntCamp.new()
		crew.name = "Haunt%d" % gi
		crew.respawn_time = 600.0
		crew.respawn_clearance = 70.0
		crew.level = IslandContent.level(isl)
		var kinds: Array = groups[gi][1]
		for i in range(kinds.size()):
			var a := TAU * i / kinds.size() + rng.randf_range(-0.4, 0.4)
			var q := c + Vector2.from_angle(a) * rng.randf_range(2.0, 4.5)
			var route := []
			for j in range(4):
				var rq := c + Vector2.from_angle(a + TAU * j / 4.0) * rng.randf_range(5.0, 9.0)
				route.append(Vector3(rq.x, isl.hv(rq), rq.y))
			crew.add_grunt({"post": Vector3(q.x, isl.hv(q), q.y), "yaw": a + PI, "mode": "patrol", "patrol": route,
				"seed": int(isl.node["seed"]) % 100000 + gi * 10 + i, "script": "res://scripts/enemies/%s.gd" % kinds[i]})
		isl.add_child(crew)
		if baker:
			var zone := Node3D.new()
			zone.name = "HauntZone%d" % gi
			isl.add_child(zone)
			zone.position = Vector3(c.x, isl.hv(c), c.y)
			baker.add_zone(zone, 26.0, false, isl.terrain_faces)
