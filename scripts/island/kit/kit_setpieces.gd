class_name KitSetPieces
extends RefCounted
## Each generated island's signature set piece: one from POOL, given by the
## chain (`assign`, from the chain's seed) so no two islands on a route share
## one and the sea uses the whole pool; every co-op machine makes
## the same chain, so the same pick. Planned on the worker (`plan`: ground,
## shaping, its data in Island.places) and built a step a frame (`steps`),
## through KitLandmarks' helpers.

const POOL := ["sunken_village", "volcano_vent", "giant_skeleton", "fallen_colossus", "sea_arch",
	"hot_springs", "cenote", "giant_nest", "crystal_grove", "old_fort"]


## Gives every chain node its "setpiece", its landmarks' order ("landmarks") and
## how many of them it gets ("landmark_count", weighted: sparse to packed).
## A route meets one island a layer, so each layer has its own set piece; a fork's
## second island takes the one left over (the pool is a layer longer than the
## sea), then shares its sibling's: no route repeats one, the sea uses them all.
static func assign(chain: Chain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([chain.seed_value, "setpieces"])
	var order := _shuffled(POOL, rng)
	var spare := Chain.SEA_LAYERS
	for n in chain.nodes:
		var pick: String = order[int(n["layer"]) - 1]
		if int(n["branch"]) == 1 and spare < order.size():
			pick = order[spare]
			spare += 1
		n["setpiece"] = pick
		n["landmarks"] = _shuffled(KitLandmarks.KINDS, rng)
		var total := 0
		for e in KitLandmarks.LANDMARK_COUNTS:
			total += int(e[1])
		var roll := rng.randi() % total
		for e in KitLandmarks.LANDMARK_COUNTS:
			roll -= int(e[1])
			if roll < 0:
				n["landmark_count"] = int(e[0])
				break


static func _shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var out := list.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The set piece's place (data), its ground shaped; {} (with an error) if the island has nowhere for it.
static func plan(isl: GenIsland, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var pl: Dictionary
	match kind:
		"sunken_village":
			pl = _plan_sunken(isl, rng, avoid)
		"volcano_vent":
			pl = _plan_inland(isl, rng, avoid, 25.0, 0.25, 6.0, 14.0, true)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 17.0, 25.0)
		"giant_skeleton":
			pl = _plan_inland(isl, rng, avoid, 24.0, 0.18, 3.0, 12.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 15.0, 22.0)
		"fallen_colossus":
			pl = _plan_inland(isl, rng, avoid, 22.0, 0.18, 3.0, 12.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 14.0, 21.0)
		"sea_arch":
			pl = _plan_arch(isl, rng, avoid)
		"hot_springs":
			pl = _plan_springs(isl, rng, avoid)
		"cenote":
			pl = _plan_inland(isl, rng, avoid, 15.0, 0.15, 4.0, 12.0, false)
			if not pl.is_empty():
				var y: float = pl["y"]
				KitLandmarks.level(isl, pl["at"], y, 12.0, 16.0)
				KitLandmarks.level(isl, pl["at"], y - CENOTE_DEPTH, 8.8, 10.4)
		"giant_nest":
			pl = _plan_inland(isl, rng, avoid, 13.0, 0.3, 8.0, 8.0, true)
		"crystal_grove":
			pl = _plan_inland(isl, rng, avoid, 16.0, 0.2, 3.0, 10.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 10.0, 16.0)
		"old_fort":
			pl = _plan_fort(isl, rng, avoid)
	if pl.is_empty():
		push_error("KitSetPieces: %s found no ground on %s" % [kind, isl.node["name"]])
		return {}
	match kind:
		"volcano_vent":
			pl["keep"] = [[Vector2.ZERO, 20.5]]
		"giant_skeleton":
			pl["keep"] = [[Vector2(0, -21), 7.0], [Vector2(0, -11), 10.0], [Vector2(0, 1), 10.0], [Vector2(0, 12), 8.0]]
		"fallen_colossus":
			pl["keep"] = [[Vector2.ZERO, 15.0]]
		"cenote":
			pl["keep"] = [[Vector2.ZERO, 13.0]]
		"giant_nest":
			pl["keep"] = [[Vector2.ZERO, 7.0]]
		"crystal_grove":
			pl["keep"] = [[Vector2.ZERO, 12.5]]
	pl["kind"] = kind
	pl["role"] = "setpiece"
	pl["seed"] = rng.randi()
	return pl


## An inland spot of radius r: the flattest (or, `high`, the highest) of the
## tries at least `min_h` up, no steeper than `max_s`, `path_gap` off the paths.
static func _plan_inland(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array, r: float, max_s: float, min_h: float, path_gap: float, high: bool) -> Dictionary:
	var best := {}
	var best_s := -INF
	for k in range(60):
		var p := KitLandmarks.rand_inland(isl, rng, 0.15, 0.72)
		var h := isl.hv(p)
		var s := KitLandmarks.grad(isl, p, r * 0.6).length()
		if h < min_h or s > max_s or not KitLandmarks.clear_of(p, r, avoid) or isl.path_dist(p) < path_gap:
			continue
		var score := h if high else -s
		if score > best_s:
			best_s = score
			best = {"at": p, "y": h}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var near := _nearest_path(isl, p)
	var face := (near - p).normalized()
	best.merge({"face": face, "r": r, "keep": [[Vector2.ZERO, r * 0.6]], "door": p + face * (r * 0.85)})
	return best


static func _nearest_path(isl: GenIsland, p: Vector2) -> Vector2:
	var near := Vector2.ZERO
	var nd := INF
	for path in isl.paths:
		for q in path:
			if (q as Vector2).distance_to(p) < nd:
				nd = (q as Vector2).distance_to(p)
				near = q
	return near


## A beach (gentle, sea off it) away from the dock: {"shore", "out"} or {}.
static func _beach(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array, r: float, back: float, inland_lo: float, inland_hi: float) -> Dictionary:
	var dock_a := isl.dock_dir.angle()
	var a0 := rng.randf() * TAU
	for k in range(48):
		var a := a0 + TAU * k / 48.0
		if absf(angle_difference(a, dock_a)) < 0.55:
			continue
		var c := KitLandmarks.coast(isl, a)
		if c.is_empty():
			continue
		var s: Vector2 = c["shore"]
		var out: Vector2 = c["out"]
		var inland := isl.hv(s - out * back)
		if s.distance_to(isl.dock_shore) < 70.0 or inland < inland_lo or inland > inland_hi or isl.hv(s + out * 16.0) > -1.0:
			continue
		if not KitLandmarks.clear_of(s, r, avoid):
			continue
		return c
	return {}


static func steps(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"sunken_village":
			return [func(): _sunken(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _sunken_walks(isl, ctx, pl)]
		"volcano_vent":
			return [func(): _vent(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _vent_dressing(isl, ctx, pl)]
		"giant_skeleton":
			return [func(): _skeleton(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"fallen_colossus":
			return [func(): _colossus(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _colossus_head(isl, ctx, pl)]
		"sea_arch":
			return [func(): _arch(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"hot_springs":
			return [func(): _springs(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"cenote":
			return [func(): _cenote(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"giant_nest":
			return [func(): _nest(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"crystal_grove":
			return [func(): _grove(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"old_fort":
			return [func(): _fort(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _fort_guns(isl, ctx, pl)]
	push_error("KitSetPieces: no set piece %s" % pl["kind"])
	return []


## A rock on a polar grid round local `c`: `prof`(bearing, row) -> Vector2(r, y),
## each point shoved out by noise (less at the first and last rows).
static func _grid(c: Vector3, na: int, rows: int, prof: Callable, noise: FastNoiseLite, shove: float) -> Array:
	var pts: Array = []
	for i in range(na):
		var a := TAU * i / na
		var d := Vector3(cos(a), 0, sin(a))
		var col: Array = []
		for j in range(rows):
			var ry: Vector2 = prof.call(a, j)
			var q := c + d * ry.x + Vector3(0, ry.y, 0)
			var k := shove * (0.35 if j == 0 or j == rows - 1 else 1.0)
			col.append(q + d * noise.get_noise_3dv(q * 0.6) * k)
		pts.append(col)
	return pts


static func _mesh_body(node_name: String, mb: MeshBuilder, trimesh: bool) -> StaticBody3D:
	var b := KitLandmarks.body(node_name)
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = node_name + "Mesh"
	mi.mesh = mesh
	b.add_child(mi)
	if trimesh:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		b.add_child(cs)
	return b


# ==========================================================================
# The sunken village: stilt huts sinking into a lagoon, broken walks between
# ==========================================================================
const LAGOON := -1.7


static func _plan_sunken(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var c := _beach(isl, rng, avoid, 24.0, 10.0, 0.6, 4.5)
	if c.is_empty():
		return {}
	var s: Vector2 = c["shore"]
	var out: Vector2 = c["out"]
	var mid := s + out * 15.0
	# (only the seabed rises to the lagoon: the land and the surf stay as they were)
	KitLandmarks.shape(isl, mid, 24.0, func(h: float, d: float, _p: Vector2) -> float:
		if h > -0.4:
			return h
		return maxf(h, lerpf(h, LAGOON, 1.0 - GenIsland._smooth(15.0, 24.0, d))))
	var huts: Array = []
	for k in range(6):
		var a := TAU * k / 6.0 + rng.randf_range(-0.35, 0.35)
		var q := Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 11.0)
		huts.append([q, rng.randf_range(0, TAU), k % 3, rng.randi()])
	return {"at": mid, "y": 0.0, "face": -out, "r": 24.0, "keep": [[Vector2.ZERO, 13.0]], "door": s - out * 5.0, "huts": huts, "shore": s}


## A thatched stilt hut gone to ruin: posts down into the lagoon, a plank floor,
## walls missing boards, its roof holed. `state` 0 standing, 1 sunk to the eaves, 2 a bare frame.
static func _ruin_hut(rng: RandomNumberGenerator, state: int, floor_y: float, ctx: KitContext) -> StaticBody3D:
	var b := KitLandmarks.body("SunkenHut")
	var mb := MeshBuilder.new()
	var w := rng.randf_range(3.8, 5.0)
	var d := rng.randf_range(3.4, 4.4)
	var h := 2.3
	var post := PSXMat.lit("bark", Color(0.75, 0.72, 0.65))
	var planks := PSXMat.lit("planks_weathered", ctx.style["wreck_hull"])
	var thatch := PSXMat.lit("thatch", Color(0.78, 0.74, 0.6), {"affine": 0.8})
	for x in [-w * 0.5, 0.0, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.add_cylinder(post, Transform3D(Basis(), Vector3(x, floor_y - 4.0, z)), 0.13, 0.11, 4.0 + h + 0.2, 5, 0.8)
	if state != 2:
		mb.add_box(planks, Transform3D(Basis(), Vector3(0, floor_y - 0.08, 0)), Vector3(w + 0.3, 0.16, d + 0.3), 0.5, Color.WHITE, false)
		KitLandmarks.box_col(b, Vector3(w + 0.3, 0.2, d + 0.3), Vector3(0, floor_y - 0.1, 0))
	for side in range(4):
		var bs := Basis(Vector3.UP, side * PI * 0.5)
		var half := (w if side % 2 == 0 else d) * 0.5
		var depth := (d if side % 2 == 0 else w) * 0.5
		var x := -half + 0.15
		while x < half - 0.1:
			var gone := rng.randf() < (0.25 if state == 0 else 0.55) or (side == 0 and absf(x) < 0.55)
			if not gone:
				var hh := h * rng.randf_range(0.7, 1.0) if rng.randf() < 0.3 else h
				mb.add_box(planks, Transform3D(bs, bs * Vector3(x, floor_y + hh * 0.5, depth)), Vector3(0.28, hh, 0.06), 0.8, Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25)), false)
			x += 0.3
		if state == 0:
			KitLandmarks.box_col_xf(b, Vector3(half * 2.0 if side != 0 else 0.1, h, 0.1), Transform3D(bs, bs * Vector3(0, floor_y + h * 0.5, depth)))
	var ridge := floor_y + h + 1.5
	var rows := 5
	for s in [-1.0, 1.0]:
		for r in range(rows):
			if state == 2 or rng.randf() < 0.22:
				continue
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			var y0 := lerpf(floor_y + h - 0.2, ridge, t0)
			var y1 := lerpf(floor_y + h - 0.2, ridge, t1)
			var x0: float = s * lerpf(w * 0.5 + 0.5, 0.0, t0)
			var x1: float = s * lerpf(w * 0.5 + 0.5, 0.0, t1)
			var a := Vector3(x0, y0, -d * 0.5 - 0.4)
			var bb := Vector3(x0, y0, d * 0.5 + 0.4)
			var c := Vector3(x1, y1, d * 0.5 + 0.4)
			var e := Vector3(x1, y1, -d * 0.5 - 0.4)
			mb.add_quad(thatch, a, bb, c, e, Vector2(0, t0 * 2.0), Vector2(d * 0.6, t0 * 2.0), Vector2(d * 0.6, t1 * 2.0), Vector2(0, t1 * 2.0), Color.WHITE, Vector3(s, 1.4, 0).normalized())
			mb.add_quad(thatch, a, e, c, bb, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.55, 0.55, 0.55), Vector3(-s, -1.4, 0).normalized())
		for z in [-d * 0.5, 0.0, d * 0.5]:
			KitLandmarks.beam(mb, post, Vector3(s * (w * 0.5 + 0.3), floor_y + h - 0.1, z), Vector3(0, ridge, z), 0.1)
	KitLandmarks.beam(mb, post, Vector3(0, ridge, -d * 0.5 - 0.4), Vector3(0, ridge, d * 0.5 + 0.4), 0.12)
	b.add_child(mb.to_instance("HutMesh"))
	return b


static func _sunken(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var at: Vector2 = pl["at"]
	for e in pl["huts"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(e[3])
		var state: int = e[2]
		var q: Vector2 = e[0]
		var floor_y := rng.randf_range(0.9, 1.4) if state == 0 else (rng.randf_range(-1.6, -1.1) if state == 1 else rng.randf_range(0.2, 0.9))
		var hut := _ruin_hut(rng, state, floor_y, ctx)
		node.add_child(hut)
		var tilt := rng.randf_range(0.06, 0.2) if state != 0 else rng.randf_range(0.02, 0.08)
		hut.transform = Transform3D(Basis(Vector3.UP, float(e[1])) * Basis(Vector3.BACK, tilt * (1.0 if rng.randf() < 0.5 else -1.0)) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)),
			Vector3(q.x, 0.0, q.y))
	var tint: Color = ctx.style["water_tint"]
	tint.a = 1.0
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var planks := PSXMat.lit("planks_weathered", ctx.style["wreck_hull"])
	for k in range(10):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 15.0)
		mb.add_box(planks, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, 0.05, q.y)), Vector3(rng.randf_range(0.8, 2.0), 0.06, 0.25), 0.8, Color(0.85, 0.85, 0.85), false)
	node.add_child(KitLandmarks.far_off(mb.to_instance("Driftwood")))
	var _a := at


## The walks out from the beach and between the huts (broken in places), a
## leaning totem, a sunk canoe, nets, the chest on the best-kept hut's floor.
static func _sunken_walks(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var b := KitLandmarks.body("Boardwalk")
	var mb := MeshBuilder.new()
	var planks := PSXMat.lit("planks_weathered", Color(0.85, 0.82, 0.74))
	var post := PSXMat.lit("bark", Color(0.7, 0.68, 0.6))
	var shore: Vector2 = pl["shore"]
	var at: Vector2 = pl["at"]
	var to_local := func(p: Vector2) -> Vector3:
		var v := Basis(Vector3.UP, -float(pl["yaw"])) * Vector3(p.x - at.x, 0, p.y - at.y)
		return v
	var huts: Array = pl["huts"]
	var stops: Array = [to_local.call(shore)]
	var order := [0, 1, 2, 3, 4, 5]
	order.sort_custom(func(i, j): return (huts[i][0] as Vector2).distance_to(Vector2(stops[0].x, stops[0].z)) < (huts[j][0] as Vector2).distance_to(Vector2(stops[0].x, stops[0].z)))
	for i in order.slice(0, 4):
		var q: Vector2 = huts[i][0]
		stops.append(Vector3(q.x, 0, q.y))
	var walk_y := 0.95
	for k in range(stops.size() - 1):
		var a: Vector3 = stops[k]
		var e: Vector3 = stops[k + 1]
		var dir := (e - a)
		dir.y = 0.0
		var length := dir.length() - 3.0
		dir = dir.normalized()
		var side := dir.cross(Vector3.UP)
		var start := a + dir * (1.0 if k == 0 else 2.5)
		var gap0 := rng.randf_range(0.35, 0.65)
		var n := int(length / 0.4)
		for s in range(n):
			var t := float(s) / n
			if absf(t - gap0) < 0.08 and k > 0:
				continue
			var p := start + dir * (t * length) + Vector3(0, walk_y + (0.04 * sin(s * 1.7)), 0)
			mb.add_box(planks, Transform3D(Basis.looking_at(side, Vector3.UP) * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06)), p), Vector3(0.3, 0.06, 1.4), 1.0, Color(1, 1, 1).darkened(rng.randf_range(0, 0.25)), false)
		var pp := 0.0
		while pp < length:
			for sd in [-0.7, 0.7]:
				var fp: Vector3 = start + dir * pp + side * sd
				mb.add_cylinder(post, Transform3D(Basis(), fp + Vector3(0, -2.5, 0)), 0.09, 0.08, 2.5 + walk_y + (0.6 if rng.randf() < 0.3 else 0.0), 5, 0.8)
			pp += 2.2
		var t_cuts := [[0.0, gap0 - 0.08], [gap0 + 0.08, 1.0]] if k > 0 else [[0.0, 1.0]]
		for tc in t_cuts:
			var p0 := start + dir * (float(tc[0]) * length)
			var p1 := start + dir * (float(tc[1]) * length)
			if p0.distance_to(p1) < 0.3:
				continue
			KitLandmarks.box_col_xf(b, Vector3(1.4, 0.12, p0.distance_to(p1)), Transform3D(Basis.looking_at(dir, Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, walk_y - 0.05, 0)))
	var tp := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	var totem := Transform3D(Basis(Vector3.BACK, 0.18) * Basis(Vector3.UP, rng.randf() * TAU), tp + Vector3(0, -1.5, 0))
	var wood := PSXMat.lit("planks_dark", Color(0.8, 0.7, 0.6))
	mb.add_cylinder(wood, totem, 0.32, 0.28, 6.5, 7, 0.6)
	var paint := PSXMat.flat(Color(0.75, 0.25, 0.18))
	for k in range(3):
		var y := 3.2 + k * 1.3
		mb.add_box(wood, totem * Transform3D(Basis(), Vector3(0, y, 0.25)), Vector3(0.7, 0.9, 0.25), 0.8)
		mb.add_box(paint, totem * Transform3D(Basis(), Vector3(0, y + 0.15, 0.39)), Vector3(0.5, 0.1, 0.04), 1.0)
		mb.add_box(PSXMat.flat(Color(0.1, 0.1, 0.08)), totem * Transform3D(Basis(), Vector3(0, y - 0.2, 0.39)), Vector3(0.3, 0.12, 0.04), 1.0)
	mb.add_box(wood, totem * Transform3D(Basis(), Vector3(0, 6.6, 0)), Vector3(1.6, 0.18, 0.2), 0.8)
	var cp := Vector3(rng.randf_range(-9, 9), -0.35, rng.randf_range(-9, 9))
	mb.add_loft(wood, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 0.25), cp),
		[[-2.4, 0.05, 0.05], [-1.6, 0.4, 0.3], [0.0, 0.5, 0.35], [1.6, 0.4, 0.3], [2.4, 0.05, 0.05]], MeshBuilder.profile_circle(8), 1.0, Color(0.85, 0.85, 0.85), false, false)
	b.add_child(KitLandmarks.far_off(mb.to_instance("WalksMesh")))
	node.add_child(b)
	for e in huts:
		if int(e[2]) == 0:
			var hut: Node3D = node.get_child(huts.find(e))
			var cp2 := hut.transform * Vector3(0.6, 0, -0.5)
			var hrng := RandomNumberGenerator.new()
			hrng.seed = int(e[3])
			hrng.randf_range(3.8, 5.0)
			hrng.randf_range(3.4, 4.4)
			var fy := hrng.randf_range(0.9, 1.4)
			var p := hut.transform * Vector3(0.6, fy, -0.5)
			KitLandmarks.chest(ctx, pl, p, float(e[1]), "sunken_chest", KitLandmarks.loot(isl, rng, true), 0.9)
			var _c := cp2
			break


# ==========================================================================
# The volcano vent: a cone of black rock round a lava pool, smoking
# ==========================================================================
static func _vent_prof(a: float, j: int, noise: FastNoiseLite, rim_n: float) -> Vector2:
	var foot := 18.0 + 2.5 * noise.get_noise_1d(a * 6.0)
	match j:
		0: return Vector2(foot, -1.3)
		1: return Vector2(foot * 0.74, 3.2)
		2: return Vector2(foot * 0.52, 7.4)
		3: return Vector2(7.6, 10.4 + rim_n)
		4: return Vector2(6.3, 11.2 + rim_n)
		5: return Vector2(5.0, 8.8)
		_: return Vector2(4.1, VENT_LAVA - 0.2)


## The lava's surface in the crater (over the cone's foot).
const VENT_LAVA := 6.6


static func _vent(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.2)
	var basalt := PSXMat.lit("rock", ctx.style["basalt"], {"affine": 0.6})
	var ash := PSXMat.lit("rock", (ctx.style["basalt"] as Color).lightened(0.35), {"affine": 0.6})
	var sulphur := PSXMat.lit("rock", Color(0.9, 0.82, 0.35), {"affine": 0.6})
	var pick := func(n: Vector3, m: Vector3) -> Material:
		if m.y > VENT_LAVA and m.length() < 7.0 and noise.get_noise_3dv(m * 3.0) > 0.25:
			return sulphur
		return ash if n.y > 0.75 else basalt
	var pts := _grid(Vector3.ZERO, 40, 7, func(a: float, j: int) -> Vector2:
		return _vent_prof(a, j, noise, 1.6 * noise.get_noise_1d(a * 4.0 + 20.0)), noise, 0.8)
	var mb := MeshBuilder.new()
	KitLandmarks.rock_grid(mb, pts, Vector3(0, VENT_LAVA - 0.3, 0), pick, 0.3, noise)
	var lava := KitLandmarks.flow_mat("rock", ctx.style["lava"], Vector2(0.0, 0.25), 2.2)
	for k in range(5):
		var a := TAU * k / 5.0 + 0.4
		var line := PackedVector3Array()
		for j in [4, 3, 2, 1]:
			var ry := _vent_prof(a, j, noise, 1.6 * noise.get_noise_1d(a * 4.0 + 20.0))
			line.append(Vector3(cos(a) * (ry.x + 0.15), ry.y + 0.12, sin(a) * (ry.x + 0.15)))
		mb.add_tube(lava, line, 0.3, 0.15, 4, 0.6, Color.WHITE, false, false, true)
	var cone := _mesh_body("Volcano", mb, true)
	node.add_child(cone)
	var w := MeshBuilder.new()
	KitLandmarks.water_disc(w, KitLandmarks.flow_mat("rock", ctx.style["lava"], Vector2(0.04, 0.07), 2.6), Vector3(0, VENT_LAVA, 0), 4.6, 14, 0.35)
	var wmi := w.to_instance("LavaPool")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	KitLights.light(ctx, node, Vector3(0, VENT_LAVA + 1.6, 0), 2.2, 24.0)
	KitLandmarks.puffs(node, Vector3(0, VENT_LAVA + 1.6, 0), Color(0.42, 0.4, 0.4, 0.5), 16, 3.6, 1.6, 2.0)
	KitLandmarks.puffs(node, Vector3(0, VENT_LAVA + 0.5, 0), Color(1.0, 0.55, 0.2, 0.7), 8, 0.25, 2.2, 2.5)
	KitLandmarks.loop_sound(node, "campfire_loop.wav", Vector3(0, VENT_LAVA + 0.5, 0), 6.0, 45.0, -2.0, 0.45)
	# (each machine scorches only its own captain: the lava isn't a host event)
	var heat := Area3D.new()
	heat.name = "Lava"
	heat.collision_layer = 0
	heat.collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 4.3
	cyl.height = 1.2
	cs.shape = cyl
	heat.add_child(cs)
	heat.position = Vector3(0, VENT_LAVA + 0.2, 0)
	node.add_child(heat)
	heat.body_entered.connect(func(bd: Node3D):
		if bd is Player and (bd as Player).is_local:
			var p := bd as Player
			p.health_component.take_damage(15.0)
			var out := Vector3(p.global_position.x - heat.global_position.x, 0, p.global_position.z - heat.global_position.z).normalized()
			p.velocity = out * 7.0 + Vector3.UP * 9.0
			Net.fx("embers", [p.global_position, Vector3.UP, 14])
			Net.fx("sfx", ["fire_burst", p.global_position, -4.0, 0.1]))


## Dead trees and obsidian round the foot, the chest of someone who didn't make it out.
static func _vent_dressing(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var mb := MeshBuilder.new()
	var dead := PSXMat.lit("bark", Color(0.35, 0.32, 0.3))
	var glass := PSXMat.lit("metal", Color(0.12, 0.1, 0.14))
	for k in range(7):
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(20.0, 24.0)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		base.y = KitLandmarks.gy(ctx, pl, base.x, base.z) - 0.3
		var top := base + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(4.0, 7.0), rng.randf_range(-0.8, 0.8))
		mb.add_tube(dead, MeshBuilder.curve_points(base, base.lerp(top, 0.5) + Vector3(0.3, 0, 0.2), top, 4), 0.28, 0.06, 5, 0.6)
		for bi in range(3):
			var bp := base.lerp(top, rng.randf_range(0.45, 0.85))
			var bd := Vector3(cos(rng.randf() * TAU), rng.randf_range(0.2, 0.7), sin(rng.randf() * TAU)).normalized()
			mb.add_tube(dead, PackedVector3Array([bp, bp + bd * rng.randf_range(1.0, 2.2)]), 0.08, 0.02, 4, 0.8)
	for k in range(16):
		var a := rng.randf() * TAU
		var r := rng.randf_range(19.0, 23.5)
		var q := Vector3(cos(a) * r, 0, sin(a) * r)
		var outline := PackedVector2Array([Vector2(-0.3, 0), Vector2(0.3, 0), Vector2(0.1, rng.randf_range(0.6, 1.4)), Vector2(-0.15, 0.9)])
		mb.add_extrude(glass, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.4, 0.4)), q + Vector3(0, KitLandmarks.gy(ctx, pl, q.x, q.z) - 0.1, 0)), outline, 0.35, 1.0)
	node.add_child(KitLandmarks.far_off(mb.to_instance("Scorched")))
	var a := rng.randf() * TAU
	var cp := Vector3(cos(a) * 20.5, 0, sin(a) * 20.5)
	KitLandmarks.chest(ctx, pl, cp + Vector3(0, KitLandmarks.gy(ctx, pl, cp.x, cp.z), 0), a, "vent_chest", KitLandmarks.loot(isl, rng, true), 0.95)


# ==========================================================================
# The giant skeleton: a sea king's bones run aground in the jungle
# ==========================================================================
static func _skeleton(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var bone := PSXMat.lit("plaster", ctx.style["bone"], {"affine": 0.6})
	var old := PSXMat.lit("plaster", (ctx.style["bone"] as Color).darkened(0.25), {"affine": 0.6})
	var moss := PSXMat.lit("leaves", Color(0.55, 0.72, 0.42))
	var dark := PSXMat.flat(Color(0.08, 0.08, 0.07))
	var b := KitLandmarks.body("Skeleton")
	var mb := MeshBuilder.new()
	var spine := PackedVector3Array()
	var n := 26
	for k in range(n):
		var t := float(k) / (n - 1)
		var z := lerpf(-17.0, 19.0, t)
		var x := 2.6 * sin(t * 4.2 + 0.5)
		var y := lerpf(1.6, -0.9, pow(t, 1.6))
		spine.append(Vector3(x, KitLandmarks.gy(ctx, pl, x, z) + y, z))
	for k in range(n):
		var p := spine[k]
		var t := float(k) / (n - 1)
		var s := lerpf(1.3, 0.55, t)
		var fwd := (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var bs := Basis.looking_at(fwd, Vector3.UP)
		mb.add_box(bone if k % 3 else old, Transform3D(bs, p), Vector3(s * 1.3, s, s * 0.95), 0.6, Color.WHITE, false)
		mb.add_box(bone, Transform3D(bs * Basis(Vector3.RIGHT, -0.35), p + Vector3(0, s * 1.1, 0)), Vector3(s * 0.25, s * 1.4, s * 0.5), 0.6, Color(0.9, 0.9, 0.9))
		for sd in [-1.0, 1.0]:
			mb.add_box(bone, Transform3D(bs, p + bs.x * sd * s * 0.95), Vector3(s * 0.7, s * 0.22, s * 0.3), 0.6, Color(0.85, 0.85, 0.85))
		if k % 2 == 0:
			KitLandmarks.box_col_xf(b, Vector3(s * 1.3, s, 1.9), Transform3D(bs, p))
		if k >= 3 and k <= 18 and k % 2 == 1:
			var tall := sin(PI * (k - 3) / 15.0)
			for sd in [-1.0, 1.0]:
				var out: Vector3 = bs.x * sd
				var root := p + out * s * 0.8
				var reach := 5.0 + 2.5 * tall
				var up := 5.5 + 3.0 * tall
				var foot := root + out * reach * 1.15 + fwd * rng.randf_range(-0.4, 0.4)
				foot.y = KitLandmarks.gy(ctx, pl, foot.x, foot.z) - 0.6
				var ctrl := root + out * reach + Vector3(0, up * 1.4, 0)
				var pts := MeshBuilder.curve_points(root, ctrl, foot, 9)
				if rng.randf() < 0.18:
					pts = pts.slice(0, rng.randi_range(4, 6))
				mb.add_tube(bone, pts, 0.32, 0.14, 6, 0.6, Color.WHITE, false, true)
				if pts.size() == 10:
					KitLandmarks.cyl_col(b, 0.35, 3.0, foot + Vector3(0, 1.2, 0))
				if rng.randf() < 0.3:
					KitLandmarks.vine(mb, moss, pts[4], rng.randf_range(2.0, 4.5), bs.x * sd, rng)
	var fr := spine[12] + Vector3(7.0, 0, 2.0)
	fr.y = KitLandmarks.gy(ctx, pl, fr.x, fr.z) + 0.2
	mb.add_tube(old, MeshBuilder.curve_points(fr, fr + Vector3(2.5, 0.8, 1.5), fr + Vector3(5.5, 0.0, 0.5), 7), 0.3, 0.15, 6, 0.6)
	var head := spine[0] + Vector3(0, 0.6, -5.0)
	var hb := Basis.looking_at((spine[0] - spine[2]).normalized(), Vector3.UP)
	var hx := Transform3D(hb, head)
	mb.add_loft(bone, hx * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), [[-4.0, 1.6, 1.4], [-2.0, 2.2, 1.9], [0.5, 2.0, 1.7], [3.0, 1.2, 1.0], [5.2, 0.7, 0.6], [5.6, 0.4, 0.3]],
		MeshBuilder.profile_oct(0.55), 0.5, Color.WHITE, true, true, true, true)
	for sd in [-1.0, 1.0]:
		mb.add_box(dark, hx * Transform3D(Basis(), Vector3(sd * 1.65, 0.9, 1.2)), Vector3(0.3, 1.0, 1.4), 1.0)
		mb.add_box(bone, hx * Transform3D(Basis(Vector3.UP, sd * 0.2), Vector3(sd * 1.6, 1.6, 1.0)), Vector3(0.4, 0.4, 2.4), 0.6, Color(0.9, 0.9, 0.9), false)
		mb.add_tube(bone, MeshBuilder.curve_points(hx * Vector3(sd * 1.2, 1.8, -2.5), hx * Vector3(sd * 2.6, 4.2, -4.0), hx * Vector3(sd * 2.2, 5.4, -6.5), 6), 0.45, 0.06, 6, 0.6)
	var jaw := hx * Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, -1.6, 0.6))
	mb.add_extrude(bone, jaw * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), PackedVector2Array([Vector2(-4.5, 0), Vector2(5.2, 0.3), Vector2(5.4, 0.9), Vector2(-4.0, 1.1)]), 2.8, 0.4)
	for k in range(9):
		var tz := lerpf(-2.0, 4.8, float(k) / 8.0)
		for sd in [-1.0, 1.0]:
			var w := lerpf(1.3, 0.4, float(k) / 8.0)
			mb.add_cone(bone, hx * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(sd * w, -0.9, tz)), 0.16, 0.9, 4, 1.0, Color(0.95, 0.95, 0.9))
			mb.add_cone(bone, jaw * Transform3D(Basis(), Vector3(sd * w, 1.0, tz * 0.95)), 0.15, 0.75, 4, 1.0, Color(0.95, 0.95, 0.9))
	KitLandmarks.box_col_xf(b, Vector3(4.0, 3.4, 9.0), hx * Transform3D(Basis(), Vector3(0, 0.7, 0.5)))
	b.add_child(mb.to_instance("BonesMesh"))
	node.add_child(b)
	var cp := jaw * Vector3(0, 1.2, 1.5)
	KitLandmarks.chest(ctx, pl, cp, float(rng.randf_range(-0.3, 0.3)), "skeleton_chest", KitLandmarks.loot(isl, rng, true), 1.0)


# ==========================================================================
# The fallen colossus: a giant's statue broken off at the knees
# ==========================================================================
static func _colossus(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var stone := PSXMat.lit("stone_brick", ctx.style["temple_stone"], {"affine": 0.6})
	var smooth := PSXMat.lit("plaster", (ctx.style["temple_stone"] as Color).darkened(0.05), {"affine": 0.6})
	var moss := PSXMat.lit("plaster", ctx.style["moss_tint"], {"affine": 0.6})
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.72, 0.38))
	var b := KitLandmarks.body("Colossus")
	var mb := MeshBuilder.new()
	var py := 2.4
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, py * 0.5 - 0.6, -3.0)), Vector3(9.0, py + 1.2, 7.0), 0.4)
	KitLandmarks.box_col(b, Vector3(9.0, py + 1.2, 7.0), Vector3(0, py * 0.5 - 0.6, -3.0))
	for k in range(5):
		mb.add_box(stone, Transform3D(Basis(), Vector3(0, (k + 0.5) * py / 5.0 - 0.1, 0.5 + 0.5 * (5 - k))), Vector3(4.0, py / 5.0 + 0.2, 0.5), 0.4, Color(0.9, 0.9, 0.9))
	KitLandmarks.box_col_xf(b, Vector3(4.0, 0.3, Vector2(2.6, py).length()), Transform3D(Basis(Vector3.RIGHT, -atan2(py, 2.6)), Vector3(0, py * 0.5 - 0.1, 1.9)))
	for sd in [-1.0, 1.0]:
		var foot := Vector3(sd * 2.0, py, -3.0)
		mb.add_box(smooth, Transform3D(Basis(), foot + Vector3(0, 0.45, 0.8)), Vector3(1.9, 0.9, 3.6), 0.4)
		for t in range(4):
			mb.add_box(smooth, Transform3D(Basis(), foot + Vector3(-0.66 + t * 0.44, 0.35, 2.75)), Vector3(0.38, 0.6, 0.6), 0.6, Color(0.92, 0.92, 0.92))
		var knee := 5.0 + rng.randf_range(-0.8, 1.2)
		mb.add_loft(moss if sd > 0 else smooth, Transform3D(Basis(), foot + Vector3(0, 0.6, 0)), [[0.0, 0.85, 0.85], [1.0, 0.75, 0.8], [2.5, 1.0, 1.05], [knee - 0.6, 0.95, 1.0], [knee, 1.1, 1.1]],
			MeshBuilder.profile_circle(9), 0.4, Color.WHITE, false, true, true, true)
		for k in range(5):
			var a := TAU * k / 5.0 + rng.randf()
			mb.add_cone(smooth, Transform3D(Basis(), foot + Vector3(cos(a) * 0.6, 0.6 + knee - 0.05, sin(a) * 0.6)), 0.35, rng.randf_range(0.3, 1.0), 4, 0.6)
		KitLandmarks.cyl_col(b, 1.0, knee + 0.6, foot + Vector3(0, (knee + 0.6) * 0.5, 0))
		for v in range(3):
			KitLandmarks.vine(mb, vine_m, foot + Vector3(rng.randf_range(-0.9, 0.9), knee + 0.4, rng.randf_range(-0.9, 0.9)), rng.randf_range(1.5, knee - 0.5), Vector3(sd, 0, 0), rng)
	var tx := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, PI * 0.5 - 0.08), Vector3(rng.randf_range(-1.5, 1.5), 1.3, 9.0))
	mb.add_loft(smooth, tx, [[-4.2, 2.0, 1.4], [-2.5, 2.6, 1.7], [0.0, 3.0, 1.9], [2.5, 3.2, 2.0], [3.6, 2.0, 1.5], [4.2, 1.2, 1.0]],
		MeshBuilder.profile_oct(0.6), 0.35, Color.WHITE, true, true, true, true)
	KitLandmarks.box_col_xf(b, Vector3(5.6, 3.2, 8.2), tx * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO))
	var sh := tx * Vector3(2.9, 2.6, 0)
	var hand := sh + Vector3(4.5, -0.6, 3.5)
	hand.y = maxf(KitLandmarks.gy(ctx, pl, hand.x, hand.z) + 0.5, 0.4)
	mb.add_tube(moss, MeshBuilder.curve_points(sh, sh.lerp(hand, 0.5) + Vector3(0, 0.6, 0), hand, 6), 0.95, 0.7, 8, 0.4, Color.WHITE, true, false, true)
	for f in range(4):
		var fd := Vector3(cos(f * 0.35 - 0.5), 0.0, sin(f * 0.35 - 0.5))
		var tip := hand + fd * 1.6 + Vector3(0, 0.9 if f < 3 else 0.3, 0)
		mb.add_tube(smooth, MeshBuilder.curve_points(hand + fd * 0.6, hand + fd * 1.3 + Vector3(0, 0.3, 0), tip, 4), 0.25, 0.18, 6, 0.6, Color.WHITE, false, true)
	KitLandmarks.cyl_col(b, 1.1, 2.0, hand + Vector3(0, 0.3, 0))
	b.add_child(mb.to_instance("ColossusMesh"))
	node.add_child(b)


## The head, rolled off on its side: a helmeted face, calm, half sunk in the
## grass, a sapling growing from the crest. The chest lies in the plinth's lee.
static func _colossus_head(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var smooth := PSXMat.lit("plaster", (ctx.style["temple_stone"] as Color).darkened(0.05), {"affine": 0.6})
	var bronze := PSXMat.lit("metal", Color(0.45, 0.62, 0.5))
	var dark := PSXMat.flat(Color(0.12, 0.12, 0.1))
	var b := KitLandmarks.body("ColossusHead")
	var mb := MeshBuilder.new()
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var hp := Vector3(side * rng.randf_range(9.0, 11.0), 0, rng.randf_range(3.0, 7.0))
	hp.y = KitLandmarks.gy(ctx, pl, hp.x, hp.z) + 1.4
	var hx := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.8, 0.8)) * Basis(Vector3.BACK, side * (PI * 0.5 - 0.25)), hp)
	mb.add_loft(smooth, hx, [[-2.6, 1.8, 2.0], [-1.0, 2.1, 2.3], [1.0, 2.0, 2.2], [2.4, 1.6, 1.8], [3.0, 0.9, 1.0]], MeshBuilder.profile_oct(0.62), 0.4, Color.WHITE, true, true, true, true)
	mb.add_loft(bronze, hx, [[0.2, 2.25, 2.4], [1.6, 2.15, 2.35], [2.8, 1.75, 2.0], [3.4, 1.0, 1.3]], MeshBuilder.profile_oct(0.62), 0.5, Color.WHITE, false, true, true, true)
	mb.add_extrude(bronze, hx * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 3.2, 0)), PackedVector2Array([Vector2(-2.6, 0), Vector2(2.2, 0), Vector2(1.6, 1.4), Vector2(-1.2, 1.8), Vector2(-2.8, 0.8)]), 0.5, 0.5)
	var f := hx * Transform3D(Basis(), Vector3(0, 0, 2.15))
	for sd in [-1.0, 1.0]:
		mb.add_box(dark, f * Transform3D(Basis(), Vector3(sd * 0.75, 0.9, 0.0)), Vector3(0.7, 0.32, 0.12), 1.0)
		mb.add_box(smooth, f * Transform3D(Basis(), Vector3(sd * 0.75, 1.25, 0.1)), Vector3(0.9, 0.18, 0.3), 0.6)
	mb.add_extrude(smooth, f * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, -0.4, 0.15)), PackedVector2Array([Vector2(0, 0), Vector2(0.55, 0), Vector2(0, 1.2)]), 0.55, 0.6)
	mb.add_box(dark, f * Transform3D(Basis(), Vector3(0, -1.1, 0.0)), Vector3(1.1, 0.12, 0.1), 1.0)
	KitLandmarks.box_col_xf(b, Vector3(4.0, 5.6, 4.2), hx * Transform3D(Basis(), Vector3(0, 0.3, 0)))
	b.add_child(mb.to_instance("HeadMesh"))
	node.add_child(b)
	var sap := MeshInstance3D.new()
	sap.name = "Sapling"
	var trees: Array = IslandTheme.meshes(isl.theme)["tree"]
	sap.mesh = trees[rng.randi() % trees.size()]
	node.add_child(sap)
	sap.position = hx * Vector3(0, 0.5, -1.0) + Vector3(0, 2.0, 0)
	sap.scale = Vector3.ONE * 0.55
	var cp := Vector3(rng.randf_range(-3.0, 3.0), 0, -7.5)
	KitLandmarks.chest(ctx, pl, cp + Vector3(0, KitLandmarks.gy(ctx, pl, cp.x, cp.z), 0), PI, "colossus_chest", KitLandmarks.loot(isl, rng, true), 1.0)


# ==========================================================================
# The sea arch: a span of rock from the shore out into the sea
# ==========================================================================
static func _plan_arch(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var c := _beach(isl, rng, avoid, 18.0, 10.0, 0.8, 7.0)
	if c.is_empty():
		return {}
	var s: Vector2 = c["shore"]
	var out: Vector2 = c["out"]
	var foot := s - out * 4.0
	return {"at": foot, "y": isl.hv(foot), "face": out, "r": 18.0, "keep": [[Vector2.ZERO, 7.5]], "door": foot - out * 6.0,
		"span": rng.randf_range(24.0, 30.0), "high": rng.randf_range(14.0, 18.0)}


static func _arch(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.15)
	var mats := KitLandmarks.rock_mats(ctx)
	var pick := KitLandmarks.rock_pick(noise, mats[0], mats[1], mats[2])
	var span: float = pl["span"]
	var high: float = pl["high"]
	var y0 := -float(pl["y"])
	var mb := MeshBuilder.new()
	var a := Vector3(0, -1.5, 0)
	var e := Vector3(rng.randf_range(-3, 3), y0 - 4.0, span)
	var pts := MeshBuilder.curve_points(a, Vector3(0, high * 1.9, span * 0.5), e, 14)
	var tube := MeshBuilder.new()
	tube.add_tube(mats[0], pts, 4.8, 4.4, 9, 0.3, Color.WHITE, true, true, true)
	tube.map_vertices(mats[0], func(v: Vector3) -> Vector3:
		return v + Vector3(noise.get_noise_3dv(v * 0.5), noise.get_noise_3dv(v * 0.5 + Vector3(40, 0, 0)) * 0.6, noise.get_noise_3dv(v * 0.5 + Vector3(0, 0, 40))) * 1.4)
	var s := tube._surfaces[mats[0]] as Dictionary
	var vs: PackedVector3Array = s["v"]
	for i in range(0, vs.size(), 3):
		var m := (vs[i] + vs[i + 1] + vs[i + 2]) / 3.0
		var spine := pts[clampi(int(round(m.z / span * 14.0)), 0, 14)]
		KitLandmarks.rock_facet(mb, vs[i], vs[i + 1], vs[i + 2], m - spine, pick, 0.3, noise)
	for leg in [[a, 6.5, high * 0.45], [e, 6.0, high * 0.4 - y0]]:
		var c: Vector3 = leg[0]
		var r: float = leg[1]
		var top: float = leg[2]
		var col := _grid(c + Vector3(0, -2.0, 0), 22, 4, func(an: float, j: int) -> Vector2:
			return Vector2(r * lerpf(1.25, 0.75, j / 3.0) * (1.0 + 0.2 * noise.get_noise_1d(an * 5.0)), lerpf(0.0, top + 2.0, j / 3.0)), noise, 0.9)
		KitLandmarks.rock_grid(mb, col, c + Vector3(0, top + 1.5, 0), pick, 0.3, noise)
	for k in range(3):
		var sp := e + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(4, 14))
		var sr := rng.randf_range(1.8, 3.2)
		var sh := rng.randf_range(4.0, 9.0) - y0
		var st := _grid(Vector3(sp.x, y0 - 6.0, sp.z), 12, 4, func(an: float, j: int) -> Vector2:
			return Vector2(sr * lerpf(1.3, 0.6, j / 3.0) * (1.0 + 0.2 * noise.get_noise_1d(an * 4.0 + k * 10.0)), lerpf(0.0, sh + 6.0, j / 3.0)), noise, 0.5)
		KitLandmarks.rock_grid(mb, st, Vector3(sp.x, y0 + sh + 0.5, sp.z), pick, 0.3, noise)
	var arch := _mesh_body("SeaArch", mb, true)
	node.add_child(arch)
	var crest_t := 0.32
	var q := pts[int(crest_t * 14.0)]
	var ld := Vector3(1, 0, 0)
	var top_y := q.y + 4.6
	var lad_at := Vector3(q.x + 4.0, top_y, q.z)
	var gyl := KitLandmarks.gy(ctx, pl, lad_at.x + 0.6, lad_at.z)
	var lad := Ladder.new()
	lad.length = top_y - gyl + 0.05
	lad.rail = 0.0
	lad.deck_depth = 1.2
	lad.position = lad_at + Vector3(0, 0.1, 0)
	lad.rotation.y = atan2(ld.x, ld.z)
	node.add_child(lad)
	var wood := MeshBuilder.new()
	var planks := PSXMat.lit("planks_weathered")
	wood.add_box(planks, Transform3D(Basis(), lad_at + Vector3(-0.9, -0.05, 0)), Vector3(2.0, 0.12, 1.6), 0.6, Color.WHITE, false)
	var crown := pts[7] + Vector3(0, 4.6, 0)
	for k in range(5):
		wood.add_blob(mats[0], Transform3D(Basis(Vector3.UP, k * 1.3), crown + Vector3(1.4, 0.2 + k * 0.32, 0)), Vector3(0.5 - k * 0.07, 0.2, 0.45 - k * 0.06), rng, 0.15, 2, 6, 0.6)
	var ledge := KitLandmarks.body("ArchLedge")
	KitLandmarks.box_col(ledge, Vector3(2.0, 0.14, 1.6), lad_at + Vector3(-0.9, -0.05, 0))
	ledge.add_child(KitLandmarks.far_off(wood.to_instance("ArchWood")))
	node.add_child(ledge)
	KitLandmarks.chest(ctx, pl, crown + Vector3(-0.6, -0.1, 0), PI * 0.5, "arch_chest", KitLandmarks.loot(isl, rng, true), 0.9)
	GrapplePoints.add(ctx.isl, ctx.isl.to_local(node.to_global(crown + Vector3(0, 2.0, 0))))


# ==========================================================================
# The hot springs: steaming pools stepping down a slope, rimmed in travertine
# ==========================================================================
static func _plan_springs(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var best := {}
	var best_s := -INF
	for k in range(70):
		var p := KitLandmarks.rand_inland(isl, rng, 0.18, 0.72)
		var h := isl.hv(p)
		var g := KitLandmarks.grad(isl, p, 8.0)
		var s := g.length()
		if h < 4.0 or s < 0.08 or s > 0.4 or not KitLandmarks.clear_of(p, 18.0, avoid) or isl.path_dist(p) < 10.0:
			continue
		if s > best_s:
			best_s = s
			best = {"at": p, "y": h, "dn": -g / s}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var dn: Vector2 = best["dn"]
	var pools: Array = []
	var side := dn.orthogonal()
	var at := p - dn * 6.0
	for i in range(4):
		var r := rng.randf_range(3.2, 4.4) - i * 0.25
		var c := at + side * rng.randf_range(-2.0, 2.0)
		var w := isl.hv(c) + 0.1
		pools.append([c, r, w])
		at = c + dn * (r + rng.randf_range(2.4, 3.4))
	var keep: Array = []
	for e in pools:
		KitLandmarks.level(isl, e[0], float(e[2]) - 1.45, float(e[1]) - 1.4, float(e[1]) + 0.3)
		keep.append([KitLandmarks.local_of(p, dn, e[0]), float(e[1]) + 1.2])
	return {"at": p, "y": isl.hv(p), "face": dn, "r": 18.0, "keep": keep, "door": at + dn * 2.0, "pools": pools}


static func _springs(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var trav := PSXMat.lit("plaster", ctx.style["travertine"], {"affine": 0.6})
	var trav_d := PSXMat.lit("rock", (ctx.style["travertine"] as Color).darkened(0.15), {"affine": 0.6})
	var water := KitLandmarks.flow_mat("water", ctx.style["spring_tint"], Vector2(0.03, 0.04))
	var spill := KitLandmarks.flow_mat("water", (ctx.style["spring_tint"] as Color).lightened(0.35), Vector2(0.0, -0.9))
	var b := KitLandmarks.body("Springs")
	var mb := MeshBuilder.new()
	var w := MeshBuilder.new()
	var y0 := float(pl["y"])
	var inv := Basis(Vector3.UP, -float(pl["yaw"]))
	var pools: Array = pl["pools"]
	for i in range(pools.size()):
		var e: Array = pools[i]
		var c2: Vector2 = e[0]
		var lc := inv * Vector3(c2.x - (pl["at"] as Vector2).x, 0, c2.y - (pl["at"] as Vector2).y)
		var r: float = e[1]
		var wy := float(e[2]) - y0
		lc.y = wy
		var n := 18
		for k in range(n):
			var a0 := TAU * k / n
			var a1 := TAU * (k + 1) / n
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var i0 := lc + d0 * (r - 0.1)
			var i1 := lc + d1 * (r - 0.1)
			var o0 := lc + d0 * (r + 0.55)
			var o1 := lc + d1 * (r + 0.55)
			var top := wy + 0.14
			var g0 := KitLandmarks.gy(ctx, pl, o0.x, o0.z) - 0.25
			var g1 := KitLandmarks.gy(ctx, pl, o1.x, o1.z) - 0.25
			var rim_i0 := Vector3(i0.x, top, i0.z)
			var rim_i1 := Vector3(i1.x, top, i1.z)
			var rim_o0 := Vector3(o0.x, top + 0.02, o0.z)
			var rim_o1 := Vector3(o1.x, top + 0.02, o1.z)
			mb.add_quad(trav, rim_i0, rim_i1, rim_o1, rim_o0, Vector2(i0.x, i0.z) * 0.5, Vector2(i1.x, i1.z) * 0.5, Vector2(o1.x, o1.z) * 0.5, Vector2(o0.x, o0.z) * 0.5, Color.WHITE, Vector3.UP)
			var mid := (d0 + d1).normalized()
			mb.add_quad(trav_d, rim_o0, rim_o1, Vector3(o1.x, minf(g1, top - 0.2), o1.z), Vector3(o0.x, minf(g0, top - 0.2), o0.z),
				Vector2(0, 0), Vector2(0.6, 0), Vector2(0.6, (top - g1) * 0.5), Vector2(0, (top - g0) * 0.5), Color(0.9, 0.9, 0.9), mid)
			mb.add_quad(trav_d, rim_i1, rim_i0, Vector3(i0.x, wy - 1.4, i0.z), Vector3(i1.x, wy - 1.4, i1.z), Vector2(0, 0), Vector2(0.6, 0), Vector2(0.6, 0.7), Vector2(0, 0.7), Color(0.75, 0.75, 0.75), -mid)
			var seg := (o0 + o1) * 0.5
			KitLandmarks.box_col_xf(b, Vector3(0.6, 0.6, o0.distance_to(o1) + 0.05), Transform3D(Basis.looking_at((o1 - o0).normalized(), Vector3.UP), Vector3(seg.x, top - 0.25, seg.z) - mid * 0.25))
		KitLandmarks.water_disc(w, water, lc + Vector3(0, -0.02, 0), r + 0.1, 16, 0.3)
		var pool := InlandPool.make(r)
		pool.position = lc + Vector3(0, -0.02, 0)
		node.add_child(pool)
		KitLandmarks.puffs(node, lc + Vector3(0, 0.3, 0), Color(0.95, 0.97, 1.0, 0.3), 8, 1.8, 0.45, r * 0.6)
		if i + 1 < pools.size():
			var nx: Array = pools[i + 1]
			var nc: Vector2 = nx[0]
			var ln := inv * Vector3(nc.x - (pl["at"] as Vector2).x, 0, nc.y - (pl["at"] as Vector2).y)
			var dd := (ln - Vector3(lc.x, 0, lc.z)).normalized()
			var lip := lc + dd * (r + 0.55) + Vector3(0, 0.16, 0)
			var low := Vector3(ln.x, float(nx[2]) - y0, ln.z) - dd * (float(nx[1]) - 0.2)
			KitLandmarks.ribbon(w, spill, MeshBuilder.curve_points(lip, lip.lerp(low, 0.5) + Vector3(0, -0.1, 0), low, 5), 1.4, 1.8, dd.cross(Vector3.UP).normalized(), Vector3.UP, 0.6)
	b.add_child(mb.to_instance("RimMesh"))
	node.add_child(b)
	var wmi := w.to_instance("SpringWater")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	KitLandmarks.loop_sound(node, "hull_gurgle_loop.wav", Vector3.ZERO, 5.0, 35.0, -6.0, 0.8)
	var dress := MeshBuilder.new()
	var mats := KitLandmarks.rock_mats(ctx)
	var e0: Array = pools[0]
	var c0: Vector2 = e0[0]
	var top_c := inv * Vector3(c0.x - (pl["at"] as Vector2).x, 0, c0.y - (pl["at"] as Vector2).y)
	var at: Array = []
	for k in range(8):
		var a := rng.randf() * TAU
		var q := top_c + Vector3(cos(a), 0, sin(a)) * (float(e0[1]) + rng.randf_range(1.2, 3.0))
		at.append(Vector3(q.x, KitLandmarks.gy(ctx, pl, q.x, q.z), q.z))
	KitLandmarks.boulders(dress, mats, at, rng, 0.5, 1.2)
	node.add_child(KitLandmarks.far_off(dress.to_instance("SpringStones")))
	var up := top_c - Vector3(0, 0, float(e0[1]) + 1.6)
	KitLandmarks.chest(ctx, pl, up + Vector3(0, KitLandmarks.gy(ctx, pl, up.x, up.z), 0), 0.0, "springs_cache", KitLandmarks.loot(isl, rng, false), 0.85)


# ==========================================================================
# The cenote: a sinkhole down to still water, vines and a rope ladder
# ==========================================================================
const CENOTE_DEPTH := 12.5
const CENOTE_WATER := 9.6
const CENOTE_R := 8.4


static func _cenote(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.22)
	var mats := KitLandmarks.rock_mats(ctx)
	var pick := KitLandmarks.rock_pick(noise, mats[0], mats[1], mats[2])
	var wall_pick := func(n: Vector3, m: Vector3) -> Material:
		return mats[1] if m.y > -3.0 and noise.get_noise_3dv(m * 2.0) > 0.0 else mats[0]
	var mb := MeshBuilder.new()
	var na := 32
	var wall := _grid(Vector3.ZERO, na, 6, func(a: float, j: int) -> Vector2:
		var t := j / 5.0
		return Vector2(lerpf(CENOTE_R - 0.4, CENOTE_R + 1.1, t) + 0.8 * noise.get_noise_1d(a * 6.0 + j), lerpf(-CENOTE_DEPTH, 0.4, t)), noise, 0.6)
	KitLandmarks.rock_grid(mb, wall, Vector3.INF, wall_pick, 0.32, noise, true)
	var lip: Array = []
	for i in range(na):
		var a := TAU * i / na
		var d := Vector3(cos(a), 0, sin(a))
		var top: Vector3 = wall[i][5]
		var far := d * 12.8
		far.y = KitLandmarks.gy(ctx, pl, far.x, far.z) - 0.25
		var mid := d * 11.0
		mid.y = maxf(KitLandmarks.gy(ctx, pl, mid.x, mid.z) + 0.1, top.y - 0.2)
		lip.append([top, mid, far])
	for i in range(na):
		var i1 := (i + 1) % na
		for j in range(2):
			var a: Vector3 = lip[i][j]
			var b: Vector3 = lip[i1][j]
			var c: Vector3 = lip[i1][j + 1]
			var d: Vector3 = lip[i][j + 1]
			KitLandmarks.rock_facet(mb, a, b, c, Vector3.UP, pick, 0.3, noise)
			KitLandmarks.rock_facet(mb, a, c, d, Vector3.UP, pick, 0.3, noise)
	var shelf := Vector3(rng.randf_range(-3, 3), -CENOTE_WATER - 0.4, rng.randf_range(-3, 3))
	mb.add_blob(mats[0], Transform3D(Basis(), shelf), Vector3(1.8, 0.9, 1.5), rng, 0.15, 3, 7, 0.4, Color.WHITE, -0.6)
	var sink := _mesh_body("Cenote", mb, true)
	node.add_child(sink)
	KitLandmarks.chest(ctx, pl, shelf + Vector3(0, 0.62, 0), rng.randf() * TAU, "cenote_chest", KitLandmarks.loot(isl, rng, true), 0.9)
	var w := MeshBuilder.new()
	KitLandmarks.water_disc(w, KitLandmarks.flow_mat("water", ctx.style["water_tint"], Vector2(0.01, 0.02)), Vector3(0, -CENOTE_WATER, 0), CENOTE_R + 0.6, 20, 0.22)
	var wmi := w.to_instance("CenoteWater")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	var pool := InlandPool.make(CENOTE_R + 0.5)
	pool.position = Vector3(0, -CENOTE_WATER, 0)
	node.add_child(pool)
	var dress := MeshBuilder.new()
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.75, 0.38))
	for k in range(16):
		var a := TAU * k / 16.0 + rng.randf_range(-0.1, 0.1)
		var d := Vector3(cos(a), 0, sin(a))
		KitLandmarks.vine(dress, vine_m, d * (CENOTE_R + 0.6) + Vector3(0, 0.2, 0), rng.randf_range(3.0, 8.5), -d, rng)
	var la := rng.randf() * TAU
	var ld := Vector3(cos(la), 0, sin(la))
	var lat := ld * (CENOTE_R + 0.15) + Vector3(0, 0.45, 0)
	var lad := Ladder.new()
	lad.length = CENOTE_WATER + 0.45 + 1.0
	lad.rail = 0.0
	lad.deck_depth = 1.6
	lad.position = lat
	lad.rotation.y = atan2(-ld.x, -ld.z)
	node.add_child(lad)
	var post := PSXMat.lit("bark")
	var sd := ld.cross(Vector3.UP)
	for s in [-0.45, 0.45]:
		dress.add_cylinder(post, Transform3D(Basis(Vector3.RIGHT, 0.0), lat + sd * s + ld * 0.6 + Vector3(0, -0.6, 0)), 0.07, 0.06, 1.6, 5, 0.8)
	KitLandmarks.beam(dress, post, lat + sd * 0.55 + ld * 0.6 + Vector3(0, 0.8, 0), lat - sd * 0.55 + ld * 0.6 + Vector3(0, 0.8, 0), 0.09)
	node.add_child(KitLandmarks.far_off(dress.to_instance("CenoteDressing")))
	var lp := KitLandmarks.body("CenoteLedge")
	KitLandmarks.box_col(lp, Vector3(1.6, 0.2, 1.6), lat + ld * 0.7 + Vector3(0, -0.15, 0))
	node.add_child(lp)
	KitLandmarks.loop_sound(node, "hull_gurgle_loop.wav", Vector3(0, -CENOTE_WATER + 0.5, 0), 4.0, 25.0, -12.0, 0.6)


# ==========================================================================
# The giant nest: a rock spire with a great bird's nest on top
# ==========================================================================
const SPIRE_H := 15.0


static func _nest(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.2)
	var mats := KitLandmarks.rock_mats(ctx)
	var pick := KitLandmarks.rock_pick(noise, mats[0], mats[1], mats[2])
	var la := rng.randf() * TAU
	var mb := MeshBuilder.new()
	var sh := SPIRE_H * float(pl["k"])
	var col := _grid(Vector3(0, -1.0, 0), 28, 7, func(a: float, j: int) -> Vector2:
		var t := j / 6.0
		var r := lerpf(5.8, 3.6, pow(t, 0.7)) * (1.0 + 0.18 * noise.get_noise_1d(a * 5.0 + j * 0.3))
		var flat := 1.0 - GenIsland._smooth(0.25, 0.55, absf(angle_difference(a, la)))
		return Vector2(lerpf(r, 3.5, flat), lerpf(0.0, sh + 1.0, t)), noise, 0.7)
	KitLandmarks.rock_grid(mb, col, Vector3(0, sh + 0.6, 0), pick, 0.3, noise)
	var spire := _mesh_body("Spire", mb, true)
	node.add_child(spire)
	var nb := MeshBuilder.new()
	var stick := PSXMat.lit("bark", Color(0.72, 0.62, 0.5))
	var straw := PSXMat.lit("straw", Color(0.9, 0.82, 0.6))
	var shell := PSXMat.lit("plaster", Color(0.92, 0.9, 0.82))
	var top := sh + 0.5
	for k in range(26):
		var r := rng.randf_range(2.6, 4.4)
		var y := top + rng.randf_range(0.0, 1.2) + (r - 2.6) * 0.4
		var a0 := rng.randf() * TAU
		var arc := rng.randf_range(1.2, 2.6)
		var pts := PackedVector3Array()
		for s in range(6):
			var a := a0 + arc * s / 5.0
			pts.append(Vector3(cos(a) * r, y + rng.randf_range(-0.15, 0.15), sin(a) * r))
		nb.add_tube(stick, pts, rng.randf_range(0.1, 0.18), 0.06, 4, 0.8)
	for k in range(14):
		var a := rng.randf() * TAU
		var p0 := Vector3(cos(a) * 3.8, top + 0.6, sin(a) * 3.8)
		nb.add_tube(stick, PackedVector3Array([p0, p0 + Vector3(cos(a + 0.6), rng.randf_range(0.0, 0.8), sin(a + 0.6)) * rng.randf_range(1.2, 2.4)]), 0.07, 0.03, 4, 0.8)
	KitLandmarks.water_disc(nb, straw, Vector3(0, top + 0.15, 0), 3.0, 12, 0.8)
	for k in range(3):
		var a := TAU * k / 3.0 + rng.randf()
		nb.add_blob(shell, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3)), Vector3(cos(a) * 1.2, top + 0.85, sin(a) * 1.2)), Vector3(0.7, 0.95, 0.7), rng, 0.04, 4, 8, 1.0)
	var gold := PSXMat.glow(Color(1.0, 0.82, 0.35), 0.8)
	for k in range(12):
		var a := rng.randf() * TAU
		nb.add_cylinder(gold, Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.5, 2.4) + Vector3(0, top + 0.2, 0)), 0.09, 0.09, 0.02, 6, 1.0)
	var feather := PSXMat.lit("canvas", Color(0.42, 0.36, 0.3))
	for k in range(10):
		var a := rng.randf() * TAU
		nb.add_card(feather, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), Vector3(cos(a) * 3.6, top + 0.8, sin(a) * 3.6)), 0.35, 1.3, Rect2(0, 0, 0.5, 1))
	var nest := KitLandmarks.body("Nest")
	nest.add_child(nb.to_instance("NestMesh"))
	KitLandmarks.cyl_col(nest, 3.2, 0.3, Vector3(0, top + 0.1, 0))
	for k in range(10):
		var a := TAU * k / 10.0
		if absf(angle_difference(a, la)) < 0.4:
			continue
		KitLandmarks.box_col_xf(nest, Vector3(1.6, 1.0, 0.4), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * 3.9, top + 0.8, sin(a) * 3.9)))
	node.add_child(nest)
	var ld := Vector3(cos(la), 0, sin(la))
	var lat := ld * 3.85 + Vector3(0, top + 0.3, 0)
	var lad := Ladder.new()
	lad.length = top + 0.3 - KitLandmarks.gy(ctx, pl, lat.x + ld.x * 0.6, lat.z + ld.z * 0.6) + 0.05
	lad.rail = 0.0
	lad.deck_depth = 1.2
	lad.position = lat
	lad.rotation.y = atan2(ld.x, ld.z)
	node.add_child(lad)
	KitLandmarks.chest(ctx, pl, Vector3(-ld.x * 1.4, top + 0.25, -ld.z * 1.4), la, "nest_hoard", KitLandmarks.loot(isl, rng, true), 0.9)
	GrapplePoints.add(ctx.isl, ctx.isl.to_local(node.to_global(Vector3(0, top + 4.0, 0))))


# ==========================================================================
# The crystal grove: glowing crystals bursting from rock round a great spire
# ==========================================================================
static func _crystal(mb: MeshBuilder, mat: Material, base: Vector3, dir: Vector3, length: float, r: float) -> void:
	var bs := Basis(Quaternion(Vector3.UP, dir.normalized()))
	mb.add_loft(mat, Transform3D(bs, base), [[-0.5, r * 0.9, r * 0.9], [length * 0.78, r, r], [length, 0.02, 0.02]], MeshBuilder.profile_circle(6), 0.6, Color.WHITE, true, false, true, true)


static func _grove(isl: GenIsland, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var tint: Color = ctx.style["crystal"]
	var glow := PSXMat.lit("", tint, {"emission": tint, "emission_energy": 1.1, "affine": 0.3})
	var deep := PSXMat.lit("", tint.darkened(0.35), {"emission": tint.darkened(0.2), "emission_energy": 0.6, "affine": 0.3})
	var mats := KitLandmarks.rock_mats(ctx)
	var b := KitLandmarks.body("Crystals")
	var mb := MeshBuilder.new()
	var cg := KitLandmarks.gy(ctx, pl, 0, 0)
	mb.add_blob(mats[0], Transform3D(Basis(), Vector3(0, cg, 0)), Vector3(3.2, 1.6, 3.0), rng, 0.25, 3, 7, 0.4, Color.WHITE, -0.4)
	_crystal(mb, glow, Vector3(0, cg + 0.5, 0), Vector3(0.12, 1, 0.05), 11.0 * float(pl["k"]), 1.15)
	for k in range(5):
		var a := TAU * k / 5.0 + rng.randf()
		_crystal(mb, deep if k % 2 else glow, Vector3(cos(a) * 1.0, cg + 0.4, sin(a) * 1.0), Vector3(cos(a) * 0.6, 1, sin(a) * 0.6), rng.randf_range(3.5, 6.5), rng.randf_range(0.45, 0.7))
	KitLandmarks.cyl_col(b, 1.6, 6.0, Vector3(0, cg + 3.0, 0))
	for c in range(8):
		var a := TAU * c / 8.0 + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(6.5, 11.0)
		var cc := Vector3(cos(a) * r, 0, sin(a) * r)
		cc.y = KitLandmarks.gy(ctx, pl, cc.x, cc.z)
		mb.add_blob(mats[rng.randi() % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), cc), Vector3(1.6, 0.8, 1.4), rng, 0.25, 3, 6, 0.4, Color.WHITE, -0.4)
		var big := rng.randf_range(2.5, 5.5)
		for k in range(rng.randi_range(3, 5)):
			var d := Vector3(rng.randf_range(-0.6, 0.6), 1, rng.randf_range(-0.6, 0.6)) + Vector3(cos(a), 0, sin(a)) * 0.35
			_crystal(mb, glow if rng.randf() < 0.6 else deep, cc + Vector3(rng.randf_range(-0.6, 0.6), 0.3, rng.randf_range(-0.6, 0.6)), d, big * rng.randf_range(0.5, 1.0), rng.randf_range(0.25, 0.55) * big / 4.0)
		KitLandmarks.cyl_col(b, 1.2, 2.5, cc + Vector3(0, 1.0, 0))
	for k in range(26):
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 13.0)
		var q := Vector3(cos(a) * r, 0, sin(a) * r)
		q.y = KitLandmarks.gy(ctx, pl, q.x, q.z) - 0.1
		_crystal(mb, deep, q, Vector3(rng.randf_range(-0.7, 0.7), 1, rng.randf_range(-0.7, 0.7)), rng.randf_range(0.4, 1.1), rng.randf_range(0.08, 0.16))
	b.add_child(mb.to_instance("CrystalMesh"))
	node.add_child(b)
	KitLights.light(ctx, b, Vector3(0, cg + 4.0, 0), 1.4, 16.0).light_color = tint
	KitLandmarks.puffs(node, Vector3(0, cg + 2.0, 0), Color(tint.r, tint.g, tint.b, 0.45), 10, 0.18, 0.4, 6.0)
	KitLandmarks.loop_sound(node, "rigging_wind_loop.wav", Vector3(0, cg + 3.0, 0), 4.0, 30.0, -14.0, 1.7)
	KitLandmarks.chest(ctx, pl, Vector3(2.4, cg + 0.25, 1.2), rng.randf() * TAU, "crystal_cache", KitLandmarks.loot(isl, rng, true), 0.9)


# ==========================================================================
# The old fort: a ruined shore battery, its guns still laid on the sea
# ==========================================================================
static func _plan_fort(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var c := _beach(isl, rng, avoid, 20.0, 22.0, 2.5, 8.0)
	if c.is_empty():
		return {}
	var s: Vector2 = c["shore"]
	var out: Vector2 = c["out"]
	var at := s - out * 16.0
	var y := isl.hv(at)
	KitLandmarks.level(isl, at, y, 12.0, 18.0)
	return {"at": at, "y": y, "face": out, "r": 20.0, "keep": [[Vector2.ZERO, 13.0]], "door": at - out * 15.0}


const FORT_R := 10.5
const WALL_H := 2.4


static func _fort(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var stone := PSXMat.lit("stone_brick", ctx.style["fort_stone"], {"affine": 0.6})
	var moss := PSXMat.lit("stone_brick", ctx.style["moss_tint"], {"affine": 0.6})
	var b := KitLandmarks.body("Fort")
	var mb := MeshBuilder.new()
	var n := 12
	var breaks := [rng.randi_range(1, 3), rng.randi_range(8, 10)]
	for k in range(n):
		var a0 := lerpf(-0.15 * PI, 1.15 * PI, float(k) / n)
		var a1 := lerpf(-0.15 * PI, 1.15 * PI, float(k + 1) / n)
		var p0 := Vector3(cos(a0), 0, sin(a0)) * FORT_R
		var p1 := Vector3(cos(a1), 0, sin(a1)) * FORT_R
		var mid := (p0 + p1) * 0.5
		var len := p0.distance_to(p1) + 0.3
		var bs := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		var h := WALL_H
		if k in breaks:
			h = rng.randf_range(0.6, 1.1)
			for r in range(4):
				var q := mid + (mid.normalized() * rng.randf_range(0.5, 2.5)) + bs.x * rng.randf_range(-1.0, 1.0)
				mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), q + Vector3(0, 0.25, 0)), Vector3(rng.randf_range(0.5, 0.9), 0.4, rng.randf_range(0.4, 0.7)), 0.5, Color(0.9, 0.9, 0.9))
		var gy0 := KitLandmarks.gy(ctx, pl, mid.x, mid.z)
		Buildings.tiled_box(mb, moss if rng.randf() < 0.3 else stone, Vector3(mid.x, gy0 + (h - 1.0) * 0.5, mid.z), Vector3(1.0, h + 1.0, 1.0), 2.4, 0.4)
		mb.map_vertices(stone, func(v: Vector3) -> Vector3: return v)
		mb.add_box(stone, Transform3D(bs, Vector3(mid.x, gy0 + (h - 1.0) * 0.5, mid.z)), Vector3(1.1, h + 1.0, len), 0.4, Color.WHITE)
		KitLandmarks.box_col_xf(b, Vector3(1.1, h + 1.0, len), Transform3D(bs, Vector3(mid.x, gy0 + (h - 1.0) * 0.5, mid.z)))
		if h == WALL_H and k % 2 == 0:
			for s in [-1.0, 1.0]:
				mb.add_box(stone, Transform3D(bs, Vector3(mid.x, gy0 + h + 0.35, mid.z) + bs.z * s * len * 0.33), Vector3(1.15, 0.7, len * 0.3), 0.4, Color(0.92, 0.92, 0.92))
		elif h == WALL_H:
			mb.add_box(stone, Transform3D(bs, Vector3(mid.x, gy0 + h + 0.35, mid.z)), Vector3(1.15, 0.7, len * 0.8), 0.4, Color(0.92, 0.92, 0.92))
	var ta := -0.15 * PI
	var tc := Vector3(cos(ta), 0, sin(ta)) * (FORT_R + 1.0)
	var tg := KitLandmarks.gy(ctx, pl, tc.x, tc.z)
	var tower_h := rng.randf_range(5.5, 7.0)
	for k in range(16):
		var a0 := TAU * k / 16.0
		var a1 := TAU * (k + 1) / 16.0
		var h := tower_h - (rng.randf_range(0.0, 2.5) if k % 3 != 0 else 0.0)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		if absf(angle_difference((a0 + a1) * 0.5, PI * 0.5 + ta * 0.0)) < 0.3:
			h = maxf(h, 3.2)
			mb.add_box(stone, Transform3D(Basis.looking_at((d1 - d0).normalized(), Vector3.UP), tc + (d0 + d1) * 1.6 + Vector3(0, tg + 2.6 + (h - 2.6) * 0.5 - 0.5, 0)), Vector3(0.9, h - 2.6 + 1.0, 1.3), 0.4)
			continue
		for r in [3.2, 2.4]:
			var o0: Vector3 = tc + d0 * r
			var o1: Vector3 = tc + d1 * r
			var nrm := (d0 + d1).normalized() * (1.0 if r > 3.0 else -1.0)
			mb.add_quad(stone, o0 + Vector3(0, tg - 1.0, 0), o1 + Vector3(0, tg - 1.0, 0), o1 + Vector3(0, tg + h, 0), o0 + Vector3(0, tg + h, 0),
				Vector2(a0 * r * 0.4, 0), Vector2(a1 * r * 0.4, 0), Vector2(a1 * r * 0.4, -(h + 1.0) * 0.4), Vector2(a0 * r * 0.4, -(h + 1.0) * 0.4), Color(1, 1, 1) if r > 3.0 else Color(0.6, 0.6, 0.6), nrm)
		mb.add_quad(stone, tc + d0 * 2.4 + Vector3(0, tg + h, 0), tc + d1 * 2.4 + Vector3(0, tg + h, 0), tc + d1 * 3.2 + Vector3(0, tg + h, 0), tc + d0 * 3.2 + Vector3(0, tg + h, 0),
			Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 0.3), Vector2(0, 0.3), Color(0.85, 0.85, 0.85), Vector3.UP)
		var mid := tc + (d0 + d1) * 1.4
		KitLandmarks.box_col_xf(b, Vector3(0.85, h + 1.0, d0.distance_to(d1) * 2.8), Transform3D(Basis.looking_at((d1 - d0).normalized(), Vector3.UP), mid + Vector3(0, tg + (h - 1.0) * 0.5, 0)))
	b.add_child(mb.to_instance("FortMesh"))
	node.add_child(b)
	var flag := KitCamps.flag("FortFlag", {"h": 7.0, "cloth": Color(0.55, 0.5, 0.45), "size": Vector2(1.6, 0.9)})
	node.add_child(flag)
	flag.position = Vector3(-FORT_R * 0.4, KitLandmarks.gy(ctx, pl, -FORT_R * 0.4, 0.0), 0.0)


## A gun on its carriage (barrel toward +z): cheeks, trucks, the iron barrel.
static func _cannon(mb: MeshBuilder, wood: Material, iron: Material, xf: Transform3D) -> void:
	for s in [-1.0, 1.0]:
		var cheek := PackedVector2Array([Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(0.8, 0.45), Vector2(0.2, 0.45), Vector2(0.2, 0.7), Vector2(-0.4, 0.7), Vector2(-0.4, 0.9), Vector2(-0.8, 0.9)])
		mb.add_extrude(wood, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(s * 0.35, 0.15, 0)), cheek, 0.12, 1.0)
		for z in [-0.55, 0.55]:
			mb.add_cylinder(wood, xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.48, 0.2, z)), 0.2, 0.2, 0.14, 8, 1.0, Color(0.8, 0.8, 0.8), true, true)
	mb.add_box(wood, xf * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.7, 0.12, 1.4), 1.0)
	mb.add_loft(iron, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.06), Vector3(0, 0.95, -0.6)),
		[[-0.25, 0.12, 0.12], [-0.15, 0.24, 0.24], [0.0, 0.26, 0.26], [1.0, 0.22, 0.22], [1.7, 0.18, 0.18], [1.75, 0.22, 0.22], [1.85, 0.2, 0.2]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)


## The guns laid on the sea through the embrasures, shot stacked by them, a powder store, the chest in the tower.
static func _fort_guns(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var wood := PSXMat.lit("planks_dark", Color(0.75, 0.7, 0.62))
	var iron := PSXMat.lit("metal", ctx.style["rust"])
	var b := KitLandmarks.body("FortGuns")
	var mb := MeshBuilder.new()
	for k in [0, 4, 6, 10]:
		var a := lerpf(-0.15 * PI, 1.15 * PI, (k + 0.5) / 12.0)
		var d := Vector3(cos(a), 0, sin(a))
		var p := d * (FORT_R - 2.2)
		p.y = KitLandmarks.gy(ctx, pl, p.x, p.z)
		var xf := Transform3D(Basis(Vector3.UP, atan2(d.x, d.z) + rng.randf_range(-0.15, 0.15)) * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05) if k != 6 else 0.5), p)
		_cannon(mb, wood, iron, xf)
		KitLandmarks.box_col_xf(b, Vector3(1.1, 1.0, 1.8), xf * Transform3D(Basis(), Vector3(0, 0.5, 0)))
		var sp := p + d.cross(Vector3.UP) * 1.4
		for lay in range(3):
			for i in range(3 - lay):
				for j in range(3 - lay):
					mb.add_blob(iron, Transform3D(Basis(), sp + Vector3((i - (2 - lay) * 0.5) * 0.24, 0.12 + lay * 0.2, (j - (2 - lay) * 0.5) * 0.24)), Vector3(0.12, 0.12, 0.12), rng, 0.0, 3, 6, 1.0)
	b.add_child(KitLandmarks.far_off(mb.to_instance("GunsMesh")))
	node.add_child(b)
	for k in range(4):
		var q := Vector3(rng.randf_range(-5.0, 5.0), 0, rng.randf_range(-4.0, 2.0))
		var pr := Props.barrel()
		ctx.under(node).place(pr, KitLandmarks.lp(pl, q.x, q.z), rng.randf() * TAU)
		if k == 3:
			pr.rotation.x = PI * 0.5
	var ta := -0.15 * PI
	var tc := Vector3(cos(ta), 0, sin(ta)) * (FORT_R + 1.0)
	var cp := tc + Vector3(-0.6, 0, 0.4)
	KitLandmarks.chest(ctx, pl, cp + Vector3(0, KitLandmarks.gy(ctx, pl, cp.x, cp.z), 0), PI * 0.5, "fort_chest", KitLandmarks.loot(isl, rng, true), 1.0)
