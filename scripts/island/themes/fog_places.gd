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
const GRAVE_R := 9.0


## The graveyard's ground (GenIsland.prepare, on the worker: FogTheme.plan_places): a flat-ish spot 30-80 m out of the
## village, off the paths, a trail run to its gate (KitLandmarks), the plants kept off it.
static func plan_places(isl, avoid: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "graveyard"])
	var vil: Vector2 = isl.sites.get("village", Vector2.ZERO)
	for k in range(60):
		var p := vil + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 80.0)
		var h: float = isl.hv(p)
		if h < 1.5 or KitLandmarks.grad(isl, p, GRAVE_R * 0.6).length() > 0.2 or not KitLandmarks.clear_of(isl, p, GRAVE_R, avoid) or isl.path_dist(p) < 5.0:
			continue
		var face := (KitSetPieces._nearest_path(isl, p) - p).normalized()
		return [{"kind": "fog_graveyard", "at": p, "y": h, "face": face, "r": GRAVE_R, "door": p + face * (GRAVE_R * 0.9),
			"keep": [[Vector2.ZERO, GRAVE_R]]}]
	return []


## The village's graveyard (place-local: +z toward its gate): a low wall round rows of leaning headstones and crosses,
## a gap for its gate under an iron arch, a crypt at its back (stone, a black door behind a grille); two lanterns at the
## gate. Where the drowned come up (haunts).
static func graveyard(isl, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var stone := PSXMat.lit("moss_stone", Color(0.6, 0.62, 0.62), {"affine": 0.6})
	var wall := PSXMat.lit("stone_brick", Color(0.56, 0.58, 0.58), {"affine": 0.6})
	var iron := PSXMat.flat(Color(0.12, 0.12, 0.13))
	var mud := PSXMat.lit("fog_mud", Color.WHITE)
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Walls"
	var y0 := float(pl["y"])
	var gy := func(x: float, z: float) -> float: return float(isl.hv(KitLandmarks.lp(pl, x, z))) - y0
	var put := func(m: Material, b: Basis, x: float, z: float, up: float, size: Vector3, col := true) -> void:
		var xf := Transform3D(b, Vector3(x, gy.call(x, z) + up, z))
		mb.add_box(m, xf, size, 0.6, Color.WHITE.darkened(rng.randf() * 0.18))
		if col:
			KitLandmarks.box_col_xf(body, size, xf)
	var W := 10.0
	var D := 9.0
	# the wall (the front's gap for the gate)
	put.call(wall, Basis(), -W * 0.25 - 0.7, D * 0.5, 0.35, Vector3(W * 0.5 - 1.4, 0.9, 0.45))
	put.call(wall, Basis(), W * 0.25 + 0.7, D * 0.5, 0.35, Vector3(W * 0.5 - 1.4, 0.9, 0.45))
	put.call(wall, Basis(), 0.0, -D * 0.5, 0.35, Vector3(W, 0.9, 0.45))
	for s in [-1.0, 1.0]:
		put.call(wall, Basis(), s * W * 0.5, 0.0, 0.35, Vector3(0.45, 0.9, D))
		# the gate's piers and a lantern beside each
		put.call(wall, Basis(), s * 1.4, D * 0.5, 1.2, Vector3(0.5, 2.6, 0.5))
	put.call(iron, Basis(), 0.0, D * 0.5, 2.55, Vector3(3.3, 0.12, 0.12), false)
	# headstones in rows, leaning, a cross now and then, mounds before them
	for row in range(3):
		for k in range(5):
			if rng.randf() < 0.15:
				continue
			var x := -3.4 + k * 1.7 + rng.randf_range(-0.2, 0.2)
			var z := -2.6 + row * 2.0 + rng.randf_range(-0.2, 0.2)
			var h := rng.randf_range(0.6, 1.2)
			var tb := Basis(Vector3.BACK, rng.randf_range(-0.22, 0.22)) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.15))
			if rng.randf() < 0.25:
				put.call(stone, tb, x, z, h * 0.5, Vector3(0.12, h + 0.3, 0.12), false)
				put.call(stone, tb, x, z, h * 0.75, Vector3(0.55, 0.1, 0.12), false)
			else:
				put.call(stone, tb, x, z, h * 0.4, Vector3(rng.randf_range(0.5, 0.75), h, 0.15))
			mb.add_blob(mud, Transform3D(Basis(), Vector3(x, gy.call(x, z + 0.8) - 0.05, z + 0.8)), Vector3(0.4, 0.14, 0.75), rng, 0.2, 2, 5)
	# the crypt at the back
	var cz := -D * 0.5 - 2.4
	put.call(wall, Basis(), 0.0, cz, 1.3, Vector3(3.4, 2.8, 3.2))
	var cy: float = gy.call(0.0, cz)
	mb.add_box(stone, Transform3D(Basis(Vector3.BACK, 0.6), Vector3(-0.85, cy + 3.0, cz)), Vector3(2.2, 0.2, 3.4), 0.6)
	mb.add_box(stone, Transform3D(Basis(Vector3.BACK, -0.6), Vector3(0.85, cy + 3.0, cz)), Vector3(2.2, 0.2, 3.4), 0.6)
	var door := Vector3(0, cy + 0.95, cz + 1.62)
	mb.add_box(PSXMat.flat(Color(0.03, 0.03, 0.03)), Transform3D(Basis(), door), Vector3(1.1, 1.9, 0.05))
	for k in range(5):
		mb.add_box(iron, Transform3D(Basis(), door + Vector3(-0.44 + k * 0.22, 0, 0.06)), Vector3(0.04, 1.9, 0.04))
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, cy + 3.9, cz + 1.4)), Vector3(0.14, 0.9, 0.14))
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, cy + 4.05, cz + 1.4)), Vector3(0.55, 0.12, 0.14))
	var mi := mb.to_instance("Stones")
	mi.visibility_range_end = 260.0
	node.add_child(mi)
	node.add_child(body)
	var host := _host(isl)
	for s in [0, 1]:
		var x := -2.2 if s == 0 else 2.2
		var l := Lantern.new()
		l.name = "GateLantern%d" % s
		l.key = isl.save_key("lantern_gate_%d" % s)
		host.add_child(l)
		var q := KitLandmarks.lp(pl, x, D * 0.5 + 0.9)
		l.position = Vector3(q.x, isl.hv(q), q.y)


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
			groups.append([KitLandmarks.lp(pl, 0.0, 0.0), ["drowned", "drowned", "ghost"]])
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
