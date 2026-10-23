class_name KitLandmarks
extends RefCounted
## Things you see from far off and walk to: the lighthouse with its keeper's
## cottage, a ring of ruins round a standing stone, a lookout tower, the harbour
## tower, the dock crane, the chapel. Each wants its own levelled ground (the
## island's flat zones) and reserves what it stands on.
##
## A generated island's landmarks (rolled per island by the chain: a waterfall
## with a pool you swim in, a beached wreck, a great tree with platforms and rope
## bridges, a stepped temple with its idol) and its signature set piece
## (KitSetPieces) are planned on the worker by `plan_gen` (sites, ground, trails,
## Island.places) and built a step a frame by `steps`.

const FLOW_SHADER := preload("res://shaders/psx/psx_flow.gdshader")


## The lighthouse at c (its door toward `face`, sunk `sink` m), the keeper's
## cottage at c + `hut_off` facing `hut_face`, and `stores` (barrel, then crates)
## at c + each offset. Returns the cottage.
static func lighthouse(ctx: KitContext, c: Vector2, face: Vector2, hut: Dictionary, hut_off: Vector2, hut_face: Vector2, stores: Array = [], sink := -0.3) -> Node3D:
	ctx.place(Props.lighthouse(), c, KitContext.face_yaw(face), 3.5, sink)
	var cottage := ctx.house(hut, c + hut_off, hut_face)
	for i in range(stores.size()):
		ctx.place(Props.barrel() if i == 0 else Props.crate(0.7), c + stores[i])
	return cottage


## A ring of old pillars (`n`, two of them fallen) round slabs and a standing
## stone you can examine (`dialogue`, "" for none). Returns the stone (or null).
static func ruins(ctx: KitContext, c: Vector2, rng: RandomNumberGenerator, dialogue := "driftstone", stone_face := Vector2(0.6, -0.8), n := 9, r := 7.5, clear := 9.5) -> Node3D:
	ctx.reserve(c, clear)
	for i in range(n):
		var a := TAU * i / n + 0.2
		var p := c + Vector2(cos(a), sin(a)) * r
		if i == 3 or i == 7:
			var fp := Props.fallen_pillar(rng.randf_range(3.5, 4.5))
			ctx.place(fp, p + Vector2(cos(a), sin(a)) * 1.5, a + PI * 0.5 + rng.randf_range(-0.3, 0.3))
			continue
		var broken := i % 2 == 0
		ctx.place(Props.ruin_pillar(rng.randf_range(2.0, 4.2) if broken else 4.4, broken, i), p, rng.randf() * TAU)
	# floor slabs
	var slab_m := PSXMat.lit("stone_brick", Color(0.75, 0.8, 0.75))
	var mb := MeshBuilder.new()
	for i in range(14):
		var p := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		var y := ctx.hv(c + p) + 0.02
		mb.add_box(slab_m, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), Vector3(p.x, y - ctx.hv(c) + 0.05, p.y)),
			Vector3(rng.randf_range(1.2, 2.0), 0.2, rng.randf_range(1.2, 2.0)), 0.6, Color.WHITE, true, false)
	ctx.put(mb.to_instance("Slabs"), Vector3(c.x, ctx.hv(c), c.y))
	if dialogue == "":
		return null
	var stone := ctx.place(Props.driftstone(), c, KitContext.face_yaw(stone_face), 1.5, -0.2)
	var inter := Interactable.new()
	inter.name = "Examine"
	inter.collision_layer = 512
	inter.collision_mask = 0
	inter.prompt_text = "Examine the Driftstone"
	inter.gesture = "reach"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.8
	cs.shape = sph
	cs.position = Vector3(0, 1.5, 0)
	inter.add_child(cs)
	stone.add_child(inter)
	inter.interacted.connect(func(_p): Dialogue.start(dialogue, stone))
	return stone


static func harbour_tower(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	return ctx.place(Buildings.harbor_tower(), p, KitContext.face_yaw(face), 3.4)


static func crane(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	return ctx.place(Buildings.dock_crane(), p, KitContext.face_yaw(face), 1.2)


static func chapel(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	# (the plinth down to the lowest ground under it: on a slope its base stood clear of the grass, 2026-10-22)
	return ctx.place(Buildings.chapel(maxf(ctx.ground_max(p, 6.2) - ctx.ground_min(p, 6.2) + 0.6, 1.4)), p, KitContext.face_yaw(face), 6.2)


## A lookout tower: four posts, a railed platform at `h` m (6 by default), a
## ladder up the +Z side. A tall one (over 8 m) gets a landing half way up on
## its +X side: a ladder from the ground to the landing, another on to the top.
static func lookout_tower(h := 6.0) -> StaticBody3D:
	var H := h
	const W := 1.4
	var body := StaticBody3D.new()
	body.name = "LookoutTower"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var planks := PSXMat.lit("planks_dark")
	for sx in [-W, W]:
		for sz in [-W, W]:
			mb.add_cylinder(wood, Transform3D(Basis(), Vector3(sx, -0.6, sz)), 0.14, 0.12, H + 1.8, 5, 1.0)
			cyl_col(body, 0.14, H + 1.8, Vector3(sx, H * 0.5 + 0.3, sz))
	# cross bracing on the sides
	for side in range(4):
		var b := Basis(Vector3.UP, side * PI * 0.5)
		mb.add_box(wood, Transform3D(b * Basis(Vector3.BACK, atan2(W * 2.0, 4.5)), b * Vector3(0, 2.8, W)), Vector3(0.1, Vector2(W * 2.0, 4.5).length(), 0.1), 1.0)
		if H > 8.0:
			mb.add_box(wood, Transform3D(b * Basis(Vector3.BACK, -atan2(W * 2.0, 4.5)), b * Vector3(0, H - 3.2, W)), Vector3(0.1, Vector2(W * 2.0, 4.5).length(), 0.1), 1.0)
	mb.add_box(planks, Transform3D(Basis(), Vector3(0, H, 0)), Vector3(W * 2 + 0.6, 0.18, W * 2 + 0.6), 0.6)
	box_col(body, Vector3(W * 2 + 0.6, 0.2, W * 2 + 0.6), Vector3(0, H, 0))
	# rail on three sides, the ladder side open above the rungs
	var e := W + 0.3
	var open := 1 if H > 8.0 else 0
	for k in range(4):
		var b := Basis(Vector3.UP, k * PI * 0.5)
		var top := b * Vector3(0, H + 1.0, e)
		if k == open:
			for x in [-e, e]:
				mb.add_box(wood, Transform3D(b, b * Vector3(x, H + 0.5, e)), Vector3(0.1, 1.0, 0.1), 1.0)
			mb.add_box(wood, Transform3D(b, b * Vector3(0, H + 1.0, e)), Vector3(e * 2, 0.08, 0.08), 1.0)
			continue
		mb.add_box(planks, Transform3D(b, b * Vector3(0, H + 0.5, e)), Vector3(e * 2, 1.0, 0.08), 0.6)
		box_col(body, (b * Vector3(e * 2, 1.0, 0.1)).abs(), b * Vector3(0, H + 0.5, e))
		mb.add_box(wood, Transform3D(b, top), Vector3(e * 2 + 0.1, 0.1, 0.14), 1.0)
	# a little roof against the sun
	mb.add_pyramid_roof(PSXMat.lit("thatch"), Transform3D(Basis(), Vector3(0, H + 2.3, 0)), e * 2 + 0.5, e * 2 + 0.5, 1.1)
	for x in [-e, e]:
		for z in [-e, e]:
			mb.add_box(wood, Transform3D(Basis(), Vector3(x, H + 1.65, z)), Vector3(0.08, 1.3, 0.08), 1.0)
	var lad := Ladder.new()
	if H > 8.0:
		var mid := H * 0.5
		var out := 3.2
		mb.add_box(planks, Transform3D(Basis(), Vector3((W + out) * 0.5, mid, 0)), Vector3(out - W + 0.3, 0.16, W * 2 + 0.3), 0.6, Color.WHITE, false)
		box_col(body, Vector3(out - W + 0.3, 0.2, W * 2 + 0.3), Vector3((W + out) * 0.5, mid, 0))
		for z in [-W - 0.1, W + 0.1]:
			mb.add_box(wood, Transform3D(Basis(), Vector3((W + out) * 0.5, mid + 1.0, z)), Vector3(out - W, 0.08, 0.08), 1.0)
			box_col(body, Vector3(out - W, 1.0, 0.1), Vector3((W + out) * 0.5, mid + 0.5, z))
			mb.add_box(wood, Transform3D(Basis(), Vector3(out, mid + 0.5, z)), Vector3(0.1, 1.0, 0.1), 1.0)
			# struts under the landing back to the posts
			beam(mb, wood, Vector3(out - 0.1, mid - 0.1, z), Vector3(W, mid - 1.8, z), 0.1)
		var low := Ladder.new()
		low.length = mid
		low.rail = 0.0
		low.deck_depth = 0.9
		low.position = Vector3(out, mid + 0.08, 0)
		low.rotation.y = PI * 0.5
		body.add_child(low)
		lad.length = H - mid
		lad.position = Vector3(e, H + 0.09, 0)
		lad.rotation.y = PI * 0.5
	else:
		lad.length = H
		lad.position = Vector3(0, H + 0.09, e)
	lad.rail = 1.0
	lad.deck_depth = 1.0
	body.add_child(mb.to_instance("TowerMesh"))
	body.add_child(lad)
	return body


## A cylinder collider centred at `at`.
static func cyl_col(body: Node3D, r: float, h: float, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


static func box_col(body: Node3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


## A box collider turned to `basis`.
static func box_col_xf(body: Node3D, size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


## A beam from a to b, closed all round (seen from below too).
static func beam(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, t: float, col := Color.WHITE) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
	mb.add_box(mat, Transform3D(basis, (a + b) * 0.5), Vector3(t, t, d.length()), 0.8, col, false)


# ==========================================================================
# Generated islands: where the landmarks and the set piece go (worker thread)
# ==========================================================================
## The landmarks' pool (this file's four, KitWilds' the rest). The chain rolls each
## island's order of them and how many it gets (LANDMARK_COUNTS), so islands run
## from sparse to packed; each takes the first that find ground.
const KINDS := ["waterfall", "wreck", "great_tree", "temple", "watchtower", "sky_wreck", "totem_grove",
	"hermit_hut", "mine", "aqueduct", "gorge_bridge"]
## [count, weight]
const LANDMARK_COUNTS := [[1, 10], [2, 20], [3, 28], [4, 24], [5, 12], [6, 6]]
## NightLights the landmarks and the set piece may take.
const LIGHTS := 5
## The summit's lookout: ground cleared round it (at least), and a taller tower (at least).
const SUMMIT_CLEAR := 18.0
const SUMMIT_TOWER := 12.0
## The biggest a tree is scattered (GenIsland._scatter_vegetation's scale at the thickest cover).
const TREE_SCALE_MAX := 1.55
## The biggest a canopy giant is scattered (GenIsland._add_giant's scale).
const GIANT_SCALE_MAX := 1.15
## Big trees that tower over the canopy by design (emergents, kapoks): a landmark needn't top them.
const OVER_CANOPY := ["emergent", "kapok"]
## Today's jungle canopy: what the landmarks' sizes were drawn against.
const CANOPY_REF := 15.0


## How high the theme's canopy stands (m): its plants' tops at their biggest scale, but
## for the few that tower over it. The theme's meshes must be made (IslandTheme.meshes).
static func canopy(theme: String) -> float:
	var top := 0.0
	var m := IslandTheme.meshes(theme)
	for k in m.keys():
		if OVER_CANOPY.has(k):
			continue
		for e in m[k]:
			# (the big trees are [body, detail, lean])
			if e is Array:
				top = maxf(top, (e[0] as Mesh).get_aabb().end.y * GIANT_SCALE_MAX)
			else:
				top = maxf(top, (e as Mesh).get_aabb().end.y * TREE_SCALE_MAX)
	return top


## How much bigger than drawn a landmark is made to stand over the theme's canopy (1 = today's jungle).
static func canopy_k(theme: String) -> float:
	return maxf(1.0, canopy(theme) / CANOPY_REF)


## The summit lookout's platform height: over the canopy round its clearing.
static func summit_h(theme: String) -> float:
	return maxf(SUMMIT_TOWER, canopy(theme) * 0.8)
## Metres between each site's middle and a place's edge.
const KEEP_OFF := {"village": 58.0, "dock": 46.0, "camp": 40.0, "lair": 34.0, "ruins": 26.0, "boss": 40.0, "summit": 22.0}
## Close-up dressing (rails, ladders, planks, props) drawn this far; the big shapes always.
const DETAIL_RANGE := 260.0


## Plans the island's set piece and landmarks (GenIsland.prepare, after the
## paths, before the terrain's arrays): picks their ground, levels it or digs
## it, keeps it clear of plants, runs a trail to each, fills Island.places.
static func plan_gen(isl: GenIsland) -> void:
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "places"])
	isl.reserve_area(isl.sites["summit"], maxf(SUMMIT_CLEAR, canopy(isl.theme) * 1.2))
	var avoid: Array = []
	for site in KEEP_OFF.keys():
		avoid.append([isl.dock_shore if site == "dock" else isl.sites[site], float(KEEP_OFF[site])])
	var theme := IslandThemes.of(isl.theme)
	for pl in theme.plan_places(isl, avoid):
		_add_place(isl, _theme_place(pl, rng), avoid, rng)
	var piece := str(isl.node["setpiece"])
	if theme.place_kind(piece) != "":
		var pl := theme.plan_place(isl, theme.place_kind(piece), rng, avoid)
		if pl.is_empty():
			push_error("KitLandmarks: %s's %s found no ground on %s" % [isl.theme, theme.place_kind(piece), isl.node["name"]])
		_add_place(isl, _theme_place(pl, rng), avoid, rng)
	else:
		_add_place(isl, KitSetPieces.plan(isl, piece, rng, avoid), avoid, rng)
	var n := 0
	for kind in isl.node["landmarks"]:
		if n >= int(isl.node["landmark_count"]):
			break
		var pl: Dictionary
		match str(kind):
			_ when theme.place_kind(kind) != "":
				pl = _theme_place(theme.plan_place(isl, theme.place_kind(kind), rng, avoid), rng)
			"waterfall":
				pl = _plan_waterfall(isl, rng, avoid)
			"wreck":
				pl = _plan_wreck(isl, rng, avoid)
			"great_tree":
				pl = _plan_tree(isl, rng, avoid)
			"temple":
				pl = _plan_temple(isl, rng, avoid)
			_:
				pl = KitWilds.plan(isl, str(kind), rng, avoid)
		if pl.is_empty():
			continue
		_add_place(isl, pl, avoid, rng)
		n += 1
	isl.build_ms["places"] = int((Time.get_ticks_usec() - t0) / 1000)


static func _theme_place(pl: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not pl.is_empty():
		pl["role"] = "theme"
		pl["seed"] = rng.randi()
	return pl


static func _add_place(isl: GenIsland, pl: Dictionary, avoid: Array, rng: RandomNumberGenerator) -> void:
	if pl.is_empty():
		return
	pl["yaw"] = KitContext.face_yaw(pl["face"])
	pl["k"] = canopy_k(isl.theme)
	# its footprint: discs given place-local, kept in island space (and clear of plants)
	var keep: Array = []
	for e in pl["keep"]:
		var c: Vector2 = e[0]
		keep.append([lp(pl, c.x, c.y), float(e[1])])
		isl.reserve_area(keep[-1][0], float(e[1]))
	pl["keep"] = keep
	isl.places.append(pl)
	avoid.append([pl["at"], pl["r"]])
	if pl.has("door"):
		_trail(isl, pl["door"], rng)


## A trail from the nearest path to `door` (unless one passes close already).
static func _trail(isl: GenIsland, door: Vector2, rng: RandomNumberGenerator) -> void:
	var best := Vector2.ZERO
	var bd := INF
	for path in isl.paths:
		for q in path:
			var d := (q as Vector2).distance_to(door)
			if d < bd:
				bd = d
				best = q
	var side := (door - best).orthogonal().normalized()
	var mid := best.lerp(door, 0.5) + side * rng.randf_range(-0.18, 0.18) * bd
	if bd < 10.0:
		return
	isl._add_path([best, mid, door], 1.1)


## Is a place of radius `r` at p clear of every [centre, radius] in `avoid` and of
## everything reserved so far (the village's houses, hamlets and streets)?
static func clear_of(isl: GenIsland, p: Vector2, r: float, avoid: Array) -> bool:
	for e in avoid:
		if p.distance_to(e[0]) < r + float(e[1]):
			return false
	return not isl.reserved_in(p, r)


## A random point inland, `lo`..`hi` of the island's radius out.
static func rand_inland(isl: GenIsland, rng: RandomNumberGenerator, lo: float, hi: float) -> Vector2:
	var a := rng.randf() * TAU
	return Vector2.from_angle(a) * isl.radius * rng.randf_range(lo, hi)


## The ground's rise per metre at p (uphill), measured `e` m either side.
static func grad(isl: GenIsland, p: Vector2, e: float) -> Vector2:
	return Vector2(isl.hv(p + Vector2(e, 0)) - isl.hv(p - Vector2(e, 0)), isl.hv(p + Vector2(0, e)) - isl.hv(p - Vector2(0, e))) / (2.0 * e)


## Where the coast is along bearing `a`: {"shore" (the waterline), "out" (to sea)}, or {} for none.
static func coast(isl: GenIsland, a: float) -> Dictionary:
	var dir := Vector2.from_angle(a)
	var r := isl.radius + 30.0
	while r > 20.0:
		if isl.hv(dir * r) > 0.3:
			var s := dir * r
			var g := grad(isl, s, 4.0)
			return {"shore": s, "out": -g.normalized() if g.length() > 0.02 else dir}
		r -= 1.5
	return {}


## Runs every terrain vertex within `reach` of c through fn(h, distance, point) -> h.
static func shape(isl: GenIsland, c: Vector2, reach: float, fn: Callable) -> void:
	var hs := isl.heights
	var n := isl.res + 1
	var x0 := clampi(int(floor((c.x - reach + isl.half) / GenIsland.CELL)), 0, isl.res)
	var x1 := clampi(int(ceil((c.x + reach + isl.half) / GenIsland.CELL)), 0, isl.res)
	var z0 := clampi(int(floor((c.y - reach + isl.half) / GenIsland.CELL)), 0, isl.res)
	var z1 := clampi(int(ceil((c.y + reach + isl.half) / GenIsland.CELL)), 0, isl.res)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var p := Vector2(-isl.half + ix * GenIsland.CELL, -isl.half + iz * GenIsland.CELL)
			var d := p.distance_to(c)
			if d <= reach:
				hs[iz * n + ix] = fn.call(hs[iz * n + ix], d, p)
	isl.heights = hs


## Ground within `r_in` of c to height y, blending out to `r_out`.
static func level(isl: GenIsland, c: Vector2, y: float, r_in: float, r_out: float) -> void:
	shape(isl, c, r_out, func(h: float, d: float, _p: Vector2) -> float:
		return lerpf(h, y, 1.0 - GenIsland._smooth(r_in, r_out, d)))


# ==========================================================================
# Building them (main thread, a step each)
# ==========================================================================
## The landmarks' and the set piece's build steps ([name, Callable]), in plan order.
static func steps(isl: GenIsland) -> Array:
	var ctx := KitContext.make(isl, hash([int(isl.node["seed"]), "places"]), isl.theme, LIGHTS, isl.build_ms)
	var out: Array = []
	for pl in isl.places:
		var built: Array
		match str(pl["role"]):
			"landmark":
				built = _landmark_steps(isl, ctx, pl)
			"setpiece":
				built = KitSetPieces.steps(isl, ctx, pl)
			"theme":
				built = IslandThemes.of(isl.theme).place_steps(isl, ctx, pl)
			_:
				continue
		built.append(func(): overgrow(ctx, pl))
		for s in built:
			out.append([str(pl["kind"]), s])
	return out


static func _landmark_steps(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> Array:
	if not ["waterfall", "wreck", "great_tree", "temple"].has(pl["kind"]):
		return KitWilds.steps(isl, ctx, pl)
	match str(pl["kind"]):
		"waterfall":
			return [func(): _waterfall(ctx, pl, place_node(ctx, pl)), func(): _waterfall_dressing(ctx, pl)]
		"wreck":
			return [func(): _wreck(ctx, pl, place_node(ctx, pl)), func(): _wreck_dressing(isl, ctx, pl)]
		"great_tree":
			return [func(): _tree(ctx, pl, place_node(ctx, pl)), func(): _tree_decks(isl, ctx, pl)]
		"temple":
			return [func(): _temple(ctx, pl, place_node(ctx, pl)), func(): _temple_top(isl, ctx, pl)]
	push_error("KitLandmarks: no landmark %s" % pl["kind"])
	return []


## The node a place's things go under ("Place_<kind>", at its middle on its ground, turned to face).
static func place_node(ctx: KitContext, pl: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Place_" + str(pl["kind"])
	var at: Vector2 = pl["at"]
	ctx.put(n, Vector3(at.x, float(pl["y"]), at.y), float(pl["yaw"]))
	return n


static func node_of(ctx: KitContext, pl: Dictionary) -> Node3D:
	return ctx.isl.get_node("Place_" + str(pl["kind"]))


## Place-local (x, z) of island point q, for a place at `at` facing `face` (in a plan, before its yaw is set).
static func local_of(at: Vector2, face: Vector2, q: Vector2) -> Vector2:
	var v := Basis(Vector3.UP, -KitContext.face_yaw(face)) * Vector3(q.x - at.x, 0, q.y - at.y)
	return Vector2(v.x, v.z)


## Island point of place-local (x, z).
static func lp(pl: Dictionary, x: float, z: float) -> Vector2:
	var v := Basis(Vector3.UP, float(pl["yaw"])) * Vector3(x, 0.0, z)
	return (pl["at"] as Vector2) + Vector2(v.x, v.z)


## The ground's height at place-local (x, z), relative to the place's own.
static func gy(ctx: KitContext, pl: Dictionary, x: float, z: float) -> float:
	return ctx.hv(lp(pl, x, z)) - float(pl["y"])


static func body(node_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = 1
	b.collision_mask = 0
	return b


static func far_off(mi: GeometryInstance3D, range_end := DETAIL_RANGE) -> GeometryInstance3D:
	mi.visibility_range_end = range_end
	return mi


## The jungle crowding back in over a place: the theme's bushes, ferns, grass and
## young trees on its ground up to its edge, off its footprint (`keep`) and its
## trail, a MultiMesh per mesh (the low plants unshadowed, ranged), the trees solid.
static func overgrow(ctx: KitContext, pl: Dictionary) -> void:
	var node := node_of(ctx, pl)
	var m := IslandTheme.meshes(str(ctx.isl.get("theme")))
	var theme := IslandThemes.of(str(ctx.isl.get("theme")))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 7
	var reach := float(pl["r"]) * 1.05
	var keep: Array = pl["keep"]
	var inv := node.transform.affine_inverse()
	var groups := {}
	var trees := body("Overgrowth")
	var n := int(reach * reach * 0.5)
	for i in range(n):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * reach
		var roll := rng.randf()
		var s := rng.randf_range(0.7, 1.3)
		var yaw := rng.randf() * TAU
		var ip := (pl["at"] as Vector2) + Vector2(cos(a), sin(a)) * d
		var h := ctx.hv(ip)
		if h < 0.6 or ctx.isl.path_dist(ip) < 1.2 or keep.any(func(e): return ip.distance_to(e[0]) < float(e[1])):
			continue
		var g := theme.growth(ctx.isl, ip).x
		if g < 1.0 and fposmod(i * 0.618034, 1.0) >= g:
			continue
		var kind := "tree" if roll < 0.07 and h > 2.5 else ("bush" if roll < 0.4 else ("fern" if roll < 0.75 else "grass"))
		var list: Array = m[kind]
		var mesh: Mesh = list[rng.randi() % list.size()]
		var at := inv * Vector3(ip.x, h - 0.08, ip.y)
		var key := [mesh, kind]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(Transform3D(Basis(Vector3.UP, yaw - node.rotation.y).scaled(Vector3.ONE * s * (0.75 if kind == "tree" else 1.0) / node.scale.x), at))
		if kind == "tree":
			cyl_col(trees, 0.35 * s, 3.0, at + Vector3(0, 1.5, 0))
	for key in groups.keys():
		var xs: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = key[0]
		mm.instance_count = xs.size()
		for i in range(xs.size()):
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if key[1] != "tree":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 150.0
		trees.add_child(mmi)
	node.add_child(trees)


## A strongbox at place-local `at` (on whatever's there: a deck, a ledge), turned `yaw` (place-local).
static func chest(ctx: KitContext, pl: Dictionary, at: Vector3, yaw: float, key: String, items: Array, size := 1.0) -> LootBag:
	var p := lp(pl, at.x, at.z)
	return KitCamps.strongbox(ctx.under(node_of(ctx, pl)), p, yaw + float(pl["yaw"]), key, items, size, float(pl["y"]) + at.y - ctx.hv(p))


## What a landmark's chest holds, by the island's loot tier.
static func loot(isl: GenIsland, rng: RandomNumberGenerator, rich: bool) -> Array:
	var t := IslandContent.tier(isl)
	var items: Array = [["gold", rng.randi_range(14, 26) + t * (7 if rich else 4)], ["treasure", rng.randi_range(1, 3) + (1 if rich else 0)]]
	if rich:
		items.append([ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], t), 1])
	else:
		items.append(["rum", rng.randi_range(1, 2)])
	return items


static var _flows := {}


## Running water (or lava): the psx surface with its texture sliding `flow`
## tiles a second, `tint.a` its opacity, glowing `glow` (0 = not).
static func flow_mat(tex: String, tint: Color, flow: Vector2, glow := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%f" % [tex, tint.to_html(), str(flow), glow]
	if _flows.has(key):
		return _flows[key]
	var m := ShaderMaterial.new()
	m.shader = FLOW_SHADER
	m.set_shader_parameter("albedo_tex", PSXMat.tex(tex))
	m.set_shader_parameter("albedo_color", tint)
	m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("affine_amount", 0.4)
	if glow > 0.0:
		m.set_shader_parameter("emission_tex", PSXMat.tex(tex))
		m.set_shader_parameter("emission_color", Color(tint.r, tint.g, tint.b))
		m.set_shader_parameter("emission_energy", glow)
	_flows[key] = m
	return m


## A strip through `pts` (u across, v along), `w0` wide at the start to `w1` at
## the end, its width along `side`, facing `face`.
static func ribbon(mb: MeshBuilder, mat: Material, pts: PackedVector3Array, w0: float, w1: float, side: Vector3, face: Vector3, uv := 0.5, col := Color.WHITE) -> void:
	var v := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var t0 := float(i) / (pts.size() - 1)
		var t1 := float(i + 1) / (pts.size() - 1)
		var ha := lerpf(w0, w1, t0) * 0.5
		var hb := lerpf(w0, w1, t1) * 0.5
		var dv := a.distance_to(b) * uv
		mb.add_quad(mat, a - side * ha, a + side * ha, b + side * hb, b - side * hb,
			Vector2(0, v), Vector2(ha * 2.0 * uv, v), Vector2(hb * 2.0 * uv, v + dv), Vector2(0, v + dv), col, face)
		v += dv


## A flat disc of water (or foam) at local `c`.
static func water_disc(mb: MeshBuilder, mat: Material, c: Vector3, r: float, sides := 18, uv := 0.25) -> void:
	for i in range(sides):
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		mb.add_tri(mat, c, p0, p1, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(c.x, c.z) * uv, Vector2(p0.x, p0.z) * uv, Vector2(p1.x, p1.z) * uv, Color.WHITE, Vector3.UP)


## A looping sound at `at` (an Ambience bus loop).
static func loop_sound(parent: Node3D, file: String, at: Vector3, unit := 8.0, reach := 60.0, db := -6.0, pitch := 1.0) -> void:
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/" + file)
	snd.unit_size = unit
	snd.max_distance = reach
	snd.volume_db = db
	snd.pitch_scale = pitch
	snd.autoplay = true
	snd.bus = "Ambience"
	snd.position = at
	parent.add_child(snd)


## Soft puffs rising (mist at a waterfall's foot, steam, smoke), tinted.
static func puffs(parent: Node3D, at: Vector3, col: Color, amount: int, size: float, rise: float, spread := 0.6) -> CPUParticles3D:
	var p := FX.chimney_smoke(parent, at)
	p.amount = amount
	p.emission_sphere_radius = spread
	p.gravity = Vector3(0.15, rise, 0.05)
	p.color_ramp = FX._fade_to_clear(col)
	p.mesh = FX._quad(size, FX._dust_mat)
	p.visibility_range_end = 180.0
	return p


# --------------------------------------------------------------------------
# Rock (BroodCave's way: every facet its own normal, material by slope)
# --------------------------------------------------------------------------
static func rock_tuv(p: Vector3, n: Vector3, s: float, off: Vector2) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * s + off
	if an.x >= an.z:
		return Vector2(p.z, -p.y) * s + off
	return Vector2(p.x, -p.y) * s + off


static func rock_facet(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, hint: Vector3, pick: Callable, uv: float, noise: FastNoiseLite) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	var m := (a + b + c) / 3.0
	var band := 0.5 + 0.5 * sin(m.y * 1.9 + 2.0 * noise.get_noise_2d(m.x * 4.0, m.z * 4.0))
	var col := Color(1, 1, 1) * (0.78 + 0.22 * band)
	col.a = 1.0
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	mb.add_tri(pick.call(n, m), a, b, c, n, n, n, rock_tuv(a, n, uv, off), rock_tuv(b, n, uv, off), rock_tuv(c, n, uv, off), col, n)


## A rock on a polar grid: pts[i][j] (bearing i, row j from the foot up; the
## bearings wrap), closed at the top by a fan to `top` (unless it's INF). Faces
## out, or into the middle (`inward`: a hole's walls).
static func rock_grid(mb: MeshBuilder, pts: Array, top: Vector3, pick: Callable, uv: float, noise: FastNoiseLite, inward := false, skip := Callable()) -> void:
	var na := pts.size()
	var nt: int = (pts[0] as Array).size()
	for i in range(na):
		var i1 := (i + 1) % na
		for j in range(nt - 1):
			if skip.is_valid() and skip.call(i, j):
				continue
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i1][j]
			var c: Vector3 = pts[i1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			var hint := (d - a).cross(b - a)
			if inward:
				hint = -hint
			if (i + j) % 2 == 0:
				rock_facet(mb, a, b, c, hint, pick, uv, noise)
				rock_facet(mb, a, c, d, hint, pick, uv, noise)
			else:
				rock_facet(mb, a, b, d, hint, pick, uv, noise)
				rock_facet(mb, b, c, d, hint, pick, uv, noise)
		if top != Vector3.INF:
			rock_facet(mb, pts[i][nt - 1], pts[i1][nt - 1], top, Vector3.UP, pick, uv, noise)


## Grass on the flats, moss on the gentler slopes, bare rock on the steep.
static func rock_pick(noise: FastNoiseLite, rock: Material, moss: Material, turf: Material) -> Callable:
	return func(n: Vector3, m: Vector3) -> Material:
		var patch := noise.get_noise_3dv(m * 2.5)
		return turf if n.y > 0.86 and patch > -0.15 else (moss if n.y > 0.6 and patch > -0.35 else rock)


static func rock_noise(seed_value: int, freq := 0.18) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.seed = seed_value
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = freq
	nz.fractal_octaves = 2
	return nz


## The theme's rock, moss and turf materials.
static func rock_mats(ctx: KitContext) -> Array:
	return [PSXMat.lit("rock", ctx.style["rock_tint"], {"affine": 0.6}), PSXMat.lit("rock", ctx.style["moss_tint"], {"affine": 0.6}),
		PSXMat.lit("grass", Color(0.9, 1.0, 0.88), {"affine": 0.6})]


## Boulders: a mossy lump each (into `mb`), local positions given.
static func boulders(mb: MeshBuilder, mats: Array, at: Array, rng: RandomNumberGenerator, s0 := 0.6, s1 := 1.6) -> void:
	for p in at:
		var s := rng.randf_range(s0, s1)
		mb.add_blob(mats[1] if rng.randf() < 0.5 else mats[0], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p + Vector3(0, s * 0.2, 0)),
			Vector3(s, s * rng.randf_range(0.55, 0.8), s * rng.randf_range(0.8, 1.1)), rng, 0.25, 3, 6, 0.4, Color.WHITE, -0.5)


## A vine hanging from `a`, `length` m, swaying out a little (into `mb`).
static func vine(mb: MeshBuilder, mat: Material, a: Vector3, length: float, out: Vector3, rng: RandomNumberGenerator) -> void:
	var b := a + Vector3.DOWN * length + out * rng.randf_range(0.2, 0.7)
	mb.add_tube(mat, MeshBuilder.curve_points(a, a.lerp(b, 0.5) + out * rng.randf_range(0.3, 0.9), b, 5), 0.06, 0.03, 4, 1.0)


# ==========================================================================
# The waterfall and its pool
# ==========================================================================
## The crag's middle, uphill of the pool's (m).
const CRAG_OFF := 9.5
## Its cliff face over the pool, out from the crag's middle at the foot.
const CRAG_FACE := 4.2
const POOL_R := 5.9
const POOL_DEPTH := 2.9


static func _plan_waterfall(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var best := {}
	var best_s := -INF
	for k in range(70):
		var p := rand_inland(isl, rng, 0.18, 0.75)
		var h := isl.hv(p)
		var g := grad(isl, p, 6.0)
		var s := g.length()
		if h < 5.0 or s < 0.06 or s > 0.6:
			continue
		var u := g / s
		var crag := p + u * CRAG_OFF
		if not clear_of(isl, p + u * 3.0, 16.0, avoid) or isl.path_dist(p) < 9.0 or isl.path_dist(crag) < 7.0:
			continue
		# steep, and its face turned out to sea so it shows from a ship
		var score := s + 0.004 * h + 0.25 * (-u).dot(p.normalized())
		if score > best_s:
			best_s = score
			best = {"at": p, "u": u, "y": h, "crag": crag}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var h: float = best["y"]
	var u: Vector2 = best["u"]
	var rise := isl.hv(best["crag"]) - h
	var lip := maxf(rng.randf_range(10.5, 13.0), rise + rng.randf_range(8.0, 10.0)) * canopy_k(isl.theme)
	level(isl, p, h, 7.0, 12.0)
	level(isl, p, h - POOL_DEPTH, 3.0, 6.4)
	return {"kind": "waterfall", "role": "landmark", "at": p, "y": h, "face": -u, "r": 16.0,
		"keep": [[Vector2.ZERO, POOL_R + 1.4], [Vector2(0, -CRAG_OFF), 7.5]], "door": p - u * 11.0, "water": h - 0.35,
		"lip": lip, "seed": rng.randi()}


static func _waterfall(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var noise := rock_noise(int(pl["seed"]))
	var mats := rock_mats(ctx)
	var wet := PSXMat.lit("rock", (ctx.style["rock_tint"] as Color).darkened(0.35), {"affine": 0.6})
	var pick_out := rock_pick(noise, mats[0], mats[1], mats[2])
	var lip: float = pl["lip"]
	var wy := float(pl["water"]) - float(pl["y"])
	var cz := -CRAG_OFF
	var front := PI * 0.5
	# the crag: a cliff face over the pool, rearing to a crest round a basin the stream runs from
	var na := 36
	var nt := 7
	var pts: Array = []
	var noise_r := []
	for i in range(na):
		var a := TAU * i / na
		var f := 1.0 - GenIsland._smooth(0.35, 1.1, absf(angle_difference(a, front)))
		var rr := lerpf(rng.randf_range(6.2, 7.6) + 1.2 * noise.get_noise_1d(a * 9.0), CRAG_FACE, f)
		var hh := lerpf(lip + 2.0 + 1.8 * noise.get_noise_1d(a * 7.0 + 40.0), lip + 0.6, f)
		if absf(angle_difference(a, front)) < 0.2:
			hh = lip
		var top_k := lerpf(0.5, 0.94, f)
		var dir := Vector3(cos(a), 0, sin(a))
		var foot := Vector3(0, 0, cz) + dir * rr * 1.04
		var fy := gy(ctx, pl, foot.x, foot.z) - 1.4
		var col: Array = []
		for j in range(nt):
			var t := float(j) / (nt - 1)
			var r := rr * lerpf(1.04, top_k, pow(t, 0.75))
			var q := Vector3(0, 0, cz) + dir * r + Vector3(0, lerpf(fy, hh, pow(t, 0.9)), 0)
			var sh := noise.get_noise_3dv(q * 0.7) * (0.7 if j > 0 and j < nt - 1 else 0.25) * (1.0 - f * 0.6)
			col.append(q + dir * sh)
		# the basin on top: in from the crest and a little down
		col.append(Vector3(0, 0, cz) + dir * rr * top_k * 0.45 + Vector3(0, lip + 0.35, 0))
		pts.append(col)
		noise_r.append(rr)
	var mb := MeshBuilder.new()
	var pick := func(n: Vector3, m: Vector3) -> Material:
		if m.z > cz + CRAG_FACE * 0.6 and absf(m.x) < 3.0 and n.y < 0.5:
			return wet
		return pick_out.call(n, m)
	rock_grid(mb, pts, Vector3(0, lip + 0.2, cz), pick, 0.32, noise)
	# boulders fallen round its foot (not in front)
	var at: Array = []
	for k in range(9):
		var a := TAU * k / 9.0 + rng.randf_range(-0.15, 0.15)
		if absf(angle_difference(a, front)) < 0.9:
			continue
		var q := Vector3(0, 0, cz) + Vector3(cos(a), 0, sin(a)) * (float(noise_r[int(a / TAU * na) % na]) + rng.randf_range(0.3, 1.2))
		at.append(Vector3(q.x, gy(ctx, pl, q.x, q.z), q.z))
	boulders(mb, mats, at, rng, 1.0, 2.2)
	var crag := body("Crag")
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = "CragMesh"
	mi.mesh = mesh
	crag.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	crag.add_child(cs)
	node.add_child(crag)
	# the falls: a curtain off the lip, a brighter sheet in front, the stream across the top
	var w := MeshBuilder.new()
	var back := flow_mat("water", ctx.style["falls_tint"], Vector2(0.05, -1.1), 0.5)
	var sheet := flow_mat("canvas", ctx.style["falls_tint"], Vector2(-0.04, -1.9), 0.35)
	var z0 := cz + CRAG_FACE - 0.1
	var curve := PackedVector3Array()
	for k in range(11):
		var s := float(k) / 10.0
		curve.append(Vector3(0, lerpf(lip + 0.1, wy, s), z0 + 1.25 * sqrt(s)))
	ribbon(w, back, curve, 2.3, 3.2, Vector3.RIGHT, Vector3.BACK, 0.45)
	var front_curve := PackedVector3Array()
	for q in curve:
		front_curve.append(q + Vector3(0.1, 0, 0.12))
	ribbon(w, sheet, front_curve, 1.5, 2.4, Vector3.RIGHT, Vector3.BACK, 0.6)
	var stream := PackedVector3Array([Vector3(0, lip + 0.32, cz - 2.2), Vector3(0, lip + 0.28, cz), Vector3(0, lip + 0.18, z0 - 0.4), Vector3(0, lip + 0.12, z0)])
	ribbon(w, flow_mat("water", ctx.style["water_tint"], Vector2(0, -0.6)), stream, 1.4, 2.0, Vector3.RIGHT, Vector3.UP, 0.5)
	# the pool, the foam where the falls land, lily pads
	water_disc(w, flow_mat("water", ctx.style["water_tint"], Vector2(0.02, 0.05)), Vector3(0, wy, 0), POOL_R + 0.9, 20, 0.22)
	water_disc(w, flow_mat("water", Color(0.95, 0.98, 1.0, 0.75), Vector2(0.15, 0.32)), Vector3(0, wy + 0.04, z0 + 1.3), 2.1, 10, 0.5)
	var pad := PSXMat.flat(Color(0.32, 0.55, 0.22))
	for k in range(6):
		var a := rng.randf_range(0.6, PI - 0.6) + (PI if k % 2 == 1 else 0.0) * 0.0
		var q := Vector3(cos(a), 0, sin(a)) * rng.randf_range(2.6, POOL_R - 0.8)
		w.add_cylinder(pad, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, wy + 0.02, q.z)), rng.randf_range(0.3, 0.5), rng.randf_range(0.3, 0.5), 0.03, 7, 1.0)
	var wmi := w.to_instance("Water")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	var pool := InlandPool.make(POOL_R + 0.7)
	pool.position = Vector3(0, wy, 0)
	node.add_child(pool)
	puffs(node, Vector3(0, wy + 0.4, z0 + 1.3), Color(0.92, 0.96, 1.0, 0.35), 12, 1.6, 0.6, 1.0)
	loop_sound(node, "hull_rush_loop.wav", Vector3(0, wy + 1.0, z0 + 1.0), 7.0, 55.0, -3.0, 0.7)


## The ledge behind the falls and its chest, vines down the face, stones round the pool.
static func _waterfall_dressing(ctx: KitContext, pl: Dictionary, items := []) -> void:
	var node := node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var mats := rock_mats(ctx)
	var wy := float(pl["water"]) - float(pl["y"])
	var lip: float = pl["lip"]
	var z0 := -CRAG_OFF + CRAG_FACE
	var mb := MeshBuilder.new()
	var ledge := body("Ledge")
	mb.add_blob(mats[0], Transform3D(Basis(), Vector3(0.3, wy - 0.6, z0 + 0.2)), Vector3(1.7, 1.25, 1.0), rng, 0.12, 3, 7, 0.4, Color(0.75, 0.75, 0.75), -0.6)
	box_col(ledge, Vector3(2.8, 1.2, 1.4), Vector3(0.3, wy + 0.0, z0 + 0.3))
	node.add_child(ledge)
	chest(ctx, pl, Vector3(0.3, wy + 0.6, z0 + 0.35), 0.0, "falls_chest", loot(ctx.isl as GenIsland, rng, true) if items.is_empty() else items, 0.9)
	var at: Array = []
	for k in range(13):
		var a := TAU * k / 13.0 + rng.randf_range(-0.1, 0.1)
		if absf(angle_difference(a, -PI * 0.5)) < 0.75:
			continue
		var q := Vector3(cos(a), 0, sin(a)) * (POOL_R + rng.randf_range(0.2, 1.4))
		at.append(Vector3(q.x, gy(ctx, pl, q.x, q.z) - 0.2, q.z))
	boulders(mb, mats, at, rng, 0.5, 1.1)
	var vine_m := PSXMat.lit("leaves", Color(0.55, 0.75, 0.4))
	for k in range(7):
		var x := rng.randf_range(1.7, 3.6) * (1.0 if k % 2 == 0 else -1.0)
		vine(mb, vine_m, Vector3(x, lip + rng.randf_range(0.0, 1.5), z0 - 0.3 + absf(x) * -0.15), rng.randf_range(3.0, 7.0), Vector3(0, 0, 1), rng)
	node.add_child(far_off(mb.to_instance("PoolDressing")))


# ==========================================================================
# The beached wreck
# ==========================================================================
## Ship-local (HullBuilder): the breach in her side, and the deck broken over it.
const BREACH_Z := [-8.25, -3.0]


static func _plan_wreck(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var dock_a := isl.dock_dir.angle()
	var a0 := rng.randf() * TAU
	for k in range(48):
		var a := a0 + TAU * k / 48.0
		if absf(angle_difference(a, dock_a)) < 0.55:
			continue
		var c := coast(isl, a)
		if c.is_empty():
			continue
		var s: Vector2 = c["shore"]
		var out: Vector2 = c["out"]
		var inland := isl.hv(s - out * 12.0)
		if s.distance_to(isl.dock_shore) < 70.0 or inland < 0.8 or inland > 4.2 or isl.hv(s + out * 14.0) > -0.3:
			continue
		var at := s - out * 1.5
		if not clear_of(isl, at, 14.0, avoid):
			continue
		var stern := out.rotated(rng.randf_range(-0.6, 0.6))
		return {"kind": "wreck", "role": "landmark", "at": at, "y": isl.hv(at), "face": stern, "r": 14.0, "keep": [[Vector2(0, -1.0), 12.5]],
			"door": at - out * 13.0, "heel": rng.randf_range(0.3, 0.42) * (1.0 if rng.randf() < 0.5 else -1.0),
			"pitch": rng.randf_range(0.05, 0.1), "seed": rng.randi()}
	return {}


## The hull in place: heeled over, bow up the beach, stern in the surf; her side stove in.
static func _wreck_xf(pl: Dictionary) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(float(pl["pitch"]), 0.0, float(pl["heel"]))), Vector3(0, 0.25, 0))


static func _wreck(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var side := signf(float(pl["heel"]))
	var hull_c: Color = ctx.style["wreck_hull"]
	var mats := {
		"hull": PSXMat.lit("planks_dark", hull_c, {"affine": 0.6}),
		"deck": PSXMat.lit("planks", hull_c.lightened(0.15), {"affine": 0.6}),
		"trim": PSXMat.lit("planks", hull_c.darkened(0.1)),
		"wood": PSXMat.lit("bark"),
		"rope": PSXMat.lit("rope"),
	}
	var mb := MeshBuilder.new()
	HullBuilder.hull(mb, mats, false)
	# stove in on the low side amidships: her planking and the deck above gone
	var z0: float = BREACH_Z[0]
	var z1: float = BREACH_Z[1]
	mb.cut(func(m: Vector3) -> bool:
		return m.z > z0 and m.z < z1 and (m.x * side > 1.0 or absf(m.y - HullBuilder.DECK_Y) < 0.06))
	mb.add_backfaces(mats["hull"], 0.5)
	mb.add_backfaces(mats["deck"], 0.55)
	var wood: Material = mats["trim"]
	# ribs bared in the breach, broken plank ends round it
	for z in [-7.4, -6.2, -5.0, -3.8]:
		var hw := HullBuilder.half_width(z)
		var pts := MeshBuilder.curve_points(Vector3(side * 1.6, -2.75, z), Vector3(side * (hw + 0.4), -2.4, z), Vector3(side * (hw - 0.05), 0.4 + 0.3 * absf(sin(z * 3.0)), z), 6)
		mb.add_tube(wood, pts, 0.13, 0.1, 5, 1.0, Color(0.7, 0.7, 0.7), false, true, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	for k in range(14):
		var z := lerpf(z0, z1, rng.randf())
		var y := rng.randf_range(-2.4, 0.2)
		var edge := z0 if k % 2 == 0 else z1
		var hw := HullBuilder.half_width(edge) - 0.15
		mb.add_box(mats["hull"], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(side * hw, y, edge + (0.4 if edge == z0 else -0.4) * rng.randf_range(0.5, 1.6))),
			Vector3(0.08, 0.24, rng.randf_range(0.6, 1.4)), 1.0, Color(0.8, 0.8, 0.8), false)
		if k < 6:
			# the deck's planks snapped off over the hold
			mb.add_box(mats["deck"], Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.1) * side), Vector3(-side * rng.randf_range(0.2, 2.5), HullBuilder.DECK_Y - 0.06, z)),
				Vector3(rng.randf_range(1.2, 3.4), 0.08, 0.26), 0.6, Color(0.85, 0.85, 0.85), false)
	# the mast snapped short, its stump splintered
	mb.add_cylinder(mats["wood"], Transform3D(Basis(), Vector3(0, HullBuilder.DECK_Y, HullBuilder.MAST_Z)), 0.3, 0.26, 2.6, 7, 0.8)
	for k in range(5):
		var a := TAU * k / 5.0
		mb.add_cone(mats["wood"], Transform3D(Basis(), Vector3(cos(a) * 0.14, HullBuilder.DECK_Y + 2.55, HullBuilder.MAST_Z + sin(a) * 0.14)), 0.12, rng.randf_range(0.3, 0.8), 4, 0.8)
	var hull := body("WreckHull")
	hull.transform = _wreck_xf(pl)
	var mesh := mb.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = mesh
	hull.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	hull.add_child(cs)
	node.add_child(hull)


## Her mast and torn sail on the sand, cargo spilled from the breach, the bones
## of someone who stayed with her, and the chest in her hold.
static func _wreck_dressing(isl: GenIsland, ctx: KitContext, pl: Dictionary, items := []) -> void:
	var node := node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var side := signf(float(pl["heel"]))
	var xf := _wreck_xf(pl)
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var canvas := PSXMat.lit("canvas", Color(0.82, 0.78, 0.66), {"affine": 0.6})
	var rope := PSXMat.lit("rope")
	# the fallen top mast with its yard, across the sand off the low side
	var foot := xf * Vector3(side * 5.8, 0, -1.0)
	var top := foot + Vector3(side * 2.0, 0, -11.0)
	foot.y = gy(ctx, pl, foot.x, foot.z) + 0.15
	top.y = gy(ctx, pl, top.x, top.z) + 0.1
	mb.add_tube(wood, PackedVector3Array([foot, foot.lerp(top, 0.5) + Vector3(0, 0.08, 0), top]), 0.24, 0.15, 7, 0.8, Color.WHITE, true, true)
	var yard_c := foot.lerp(top, 0.55)
	var yd := (top - foot).normalized().cross(Vector3.UP).normalized()
	var ya := yard_c - yd * 4.0
	var yb := yard_c + yd * 4.0
	ya.y = gy(ctx, pl, ya.x, ya.z) + 0.15
	yb.y = gy(ctx, pl, yb.x, yb.z) + 0.15
	mb.add_tube(wood, PackedVector3Array([ya, yard_c + Vector3(0, 0.3, 0), yb]), 0.12, 0.12, 6, 0.8, Color.WHITE, true, true)
	# the sail draped from the yard over the sand, torn
	var back := (foot - top).normalized()
	for k in range(4):
		var s0 := -3.4 + k * 1.75
		var s1 := s0 + 1.55
		var a := yard_c + yd * s0 + Vector3(0, 0.3, 0)
		var b := yard_c + yd * s1 + Vector3(0, 0.3, 0)
		var c := b + back * rng.randf_range(2.0, 3.6)
		var d := a + back * rng.randf_range(2.0, 3.6)
		c.y = gy(ctx, pl, c.x, c.z) + 0.05
		d.y = gy(ctx, pl, d.x, d.z) + 0.05
		mb.add_quad(canvas, a, b, c, d, Vector2(0, 0), Vector2(0.8, 0), Vector2(0.8, 1.2), Vector2(0, 1.2), Color(0.95, 0.95, 0.95), Vector3.UP)
		mb.add_quad(canvas, a, d, c, b, Vector2(0, 0), Vector2(0, 1.2), Vector2(0.8, 1.2), Vector2(0.8, 0), Color(0.7, 0.7, 0.7), Vector3.DOWN)
	# rope trailing from the hull
	var r0 := xf * Vector3(side * 3.6, 1.0, -9.0)
	var r1 := r0 + Vector3(side * 2.5, 0, -2.5)
	r1.y = gy(ctx, pl, r1.x, r1.z) + 0.05
	mb.add_tube(rope, MeshBuilder.sag_points(r0, r1, 0.6, 6), 0.04, 0.04, 4, 1.0)
	# planks and splinters strewn round
	var planks := PSXMat.lit("planks_dark", ctx.style["wreck_hull"])
	for k in range(12):
		var q := xf * Vector3(side * rng.randf_range(4.5, 9.0), 0, rng.randf_range(-10.0, 4.0))
		q.y = gy(ctx, pl, q.x, q.z) + 0.04
		mb.add_box(planks, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15)), q),
			Vector3(rng.randf_range(0.6, 2.2), 0.06, 0.24), 0.8, Color(0.85, 0.85, 0.85), false)
	# the one who stayed: a skull and ribs by the hold
	var bone := PSXMat.lit("plaster", ctx.style["bone"])
	var bp := xf * Vector3(-side * 0.4, 0, -5.0)
	bp.y = gy(ctx, pl, bp.x, bp.z)
	mb.add_blob(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), bp + Vector3(0.9, 0.12, 0.3)), Vector3(0.13, 0.12, 0.16), rng, 0.05, 3, 6, 1.0)
	for k in range(4):
		var rz := bp + Vector3(0.2, 0.05, -0.1 + k * 0.12)
		mb.add_tube(bone, MeshBuilder.curve_points(rz, rz + Vector3(0.15, 0.18, 0), rz + Vector3(0.35, 0.02, 0), 4), 0.02, 0.015, 4, 1.0)
	node.add_child(far_off(mb.to_instance("WreckDressing")))
	# cargo spilled out of the breach and up the beach, half in the sand
	for k in range(7):
		var q := xf * Vector3(side * rng.randf_range(3.5, 7.5), 0, rng.randf_range(-8.0, -2.0))
		var pr := Props.barrel() if k % 3 == 0 else Props.crate(rng.randf_range(0.6, 0.9))
		var p2 := lp(pl, q.x, q.z)
		ctx.under(node).place(pr, p2, rng.randf() * TAU, 0.0, -rng.randf_range(0.1, 0.3))
		pr.rotation.z = rng.randf_range(-0.3, 0.3)
	# the chest in her hold, on the sand that's drifted in
	var cp := xf * Vector3(side * 1.2, 0, -5.6)
	chest(ctx, pl, Vector3(cp.x, gy(ctx, pl, cp.x, cp.z) + 0.05, cp.z), rng.randf_range(-0.4, 0.4), "wreck_chest", loot(isl, rng, true) if items.is_empty() else items, 1.0)


# ==========================================================================
# The great tree: platforms round its trunk, ladders up, rope bridges across
# ==========================================================================
## Deck heights over its foot as shares of the tree's height (7, 14.5 and 22 m
## on the least, 30 m), and their outer radii (each smaller than the one below,
## so a ladder's foot stands on the deck under it).
const DECK_AT := [0.233, 0.483, 0.733]
const DECK_R := [6.2, 4.9, 3.7]
## The least the tree stands; over a taller canopy it stands this much clear of it.
const TREE_TOP := 30.0
const TREE_CLEAR := 14.0


static func deck_heights(pl: Dictionary) -> Array:
	var top: float = pl["top"]
	return DECK_AT.map(func(k: float) -> float: return snappedf(top * k, 0.1))


## The trunk's radius at height y (a tree `top` m tall).
static func trunk_r(y: float, top: float) -> float:
	return lerpf(2.5, 1.0, clampf(y / top, 0.0, 1.0)) * sqrt(top / TREE_TOP) + 0.5 * exp(-y * 0.8)


static func _plan_tree(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var best := {}
	var best_s := INF
	for k in range(60):
		var p := rand_inland(isl, rng, 0.15, 0.7)
		var h := isl.hv(p)
		var s := grad(isl, p, 10.0).length()
		var b0 := rng.randf() * TAU
		var b1 := b0 + rng.randf_range(1.8, 2.5)
		var d0 := rng.randf_range(15.0, 17.5)
		var d1 := rng.randf_range(15.0, 17.5)
		if h < 4.0 or s > 0.16 or not clear_of(isl, p, 18.0, avoid) or isl.path_dist(p) < 10.0:
			continue
		var sats := [[p + Vector2.from_angle(b0) * d0, b0, d0], [p + Vector2.from_angle(b1) * d1, b1, d1]]
		var ok := true
		for e in sats:
			var sh := isl.hv(e[0])
			if sh < h - 4.0 or sh > h + 3.0 or isl.path_dist(e[0]) < 3.0:
				ok = false
		if ok and s < best_s:
			best_s = s
			best = {"at": p, "y": h, "sats": sats}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	level(isl, p, float(best["y"]), 4.0, 9.0)
	var face := Vector2.from_angle(rng.randf() * TAU)
	var res: Array = [[Vector2.ZERO, 7.5]]
	for e in best["sats"]:
		var v := Basis(Vector3.UP, -KitContext.face_yaw(face)) * Vector3((e[0] as Vector2).x - p.x, 0, (e[0] as Vector2).y - p.y)
		res.append([Vector2(v.x, v.z), 3.0])
	return {"kind": "great_tree", "role": "landmark", "at": p, "y": best["y"], "face": face, "r": 19.0,
		"keep": res, "door": p + face * 8.0, "sats": best["sats"], "lad": rng.randf() * TAU, "seed": rng.randi(),
		"top": maxf(TREE_TOP, canopy(isl.theme) + TREE_CLEAR)}


## Place-local direction of island bearing `b`.
static func _local_dir(pl: Dictionary, b: float) -> Vector3:
	return Basis(Vector3.UP, -float(pl["yaw"])) * Vector3(cos(b), 0, sin(b))


static func _tree(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var bark := PSXMat.lit("bark", Color(0.9, 0.86, 0.8))
	var leaves := PSXMat.lit("leaves", Color(0.88, 1.0, 0.86), {"affine": 0.5})
	var moss := PSXMat.lit("leaves", Color(0.6, 0.78, 0.45))
	var mb := MeshBuilder.new()
	var top: float = pl["top"]
	var dk := deck_heights(pl)
	var ks := top / TREE_TOP
	# the trunk: a lumpy lathe leaning a little, buttress fins and roots at its foot
	var rings: Array = []
	var lean := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
	for k in range(9):
		var y := -1.0 + (top + 1.0) * k / 8.0
		var r := trunk_r(y, top) * rng.randf_range(0.94, 1.06)
		var t := clampf(y / top, 0.0, 1.0)
		rings.append([y, r, r * rng.randf_range(0.9, 1.0), lean.y * t * t, lean.x * t * t])
	mb.add_loft(bark, Transform3D(), rings, MeshBuilder.profile_circle(11), 0.35, Color.WHITE, false, true, true, true)
	for k in range(7):
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var reach := rng.randf_range(2.2, 3.6)
		var hgt := rng.randf_range(2.6, 4.2)
		var outline := PackedVector2Array([Vector2(0, -0.5), Vector2(reach, -0.5), Vector2(reach * 0.55, hgt * 0.22), Vector2(0.2, hgt)])
		mb.add_extrude(bark, Transform3D(Basis(Vector3.UP, -a), d * (trunk_r(0.0, top) - 0.5)), outline, 0.42, 0.5)
		var r0 := d * (trunk_r(0.0, top) + reach * 0.8)
		var r1 := d * (trunk_r(0.0, top) + reach + rng.randf_range(3.0, 6.0))
		r0.y = gy(ctx, pl, r0.x, r0.z) + 0.1
		r1.y = gy(ctx, pl, r1.x, r1.z) - 0.3
		mb.add_tube(bark, MeshBuilder.curve_points(r0, r0.lerp(r1, 0.5) + Vector3(0, 0.35, 0), r1, 5), 0.28, 0.08, 5, 0.5)
	# limbs from high up, canopy lumps on them and over the top, vines hanging
	var crowns: Array = []
	for k in range(6):
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var y0 := rng.randf_range(0.78, 0.9) * top
		var d := Vector3(cos(a), 0, sin(a))
		var base := Vector3(lean.x, y0, lean.y) * Vector3(0.6, 1, 0.6) + d * trunk_r(y0, top) * 0.6
		var tip := base + d * rng.randf_range(7.0, 10.0) * ks + Vector3(0, rng.randf_range(2.0, 4.5), 0)
		mb.add_tube(bark, MeshBuilder.curve_points(base, base.lerp(tip, 0.5) + Vector3(0, -1.2, 0), tip, 5), 0.55 * ks, 0.2, 6, 0.5)
		var r := rng.randf_range(4.2, 5.6) * ks
		mb.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tip + Vector3(0, 0.8, 0)), Vector3(r, r * 0.6, r), rng, 0.22, 3, 7, 0.4, Color.WHITE.darkened(rng.randf_range(0.0, 0.2)))
		crowns.append(tip + Vector3(0, 0.5, 0))
		for v in range(3):
			var vp := base.lerp(tip, rng.randf_range(0.3, 0.9))
			vine(mb, moss, vp, rng.randf_range(4.0, 9.0), d, rng)
	mb.add_blob(leaves, Transform3D(Basis(), Vector3(lean.x, top + 1.5, lean.y)), Vector3(6.5, 4.0, 6.5) * ks, rng, 0.2, 3, 8, 0.4)
	var trunk := body("GreatTree")
	trunk.add_child(mb.to_instance("TreeMesh"))
	cyl_col(trunk, trunk_r(0.0, top), top * 0.47, Vector3(0, top * 0.235, 0))
	cyl_col(trunk, trunk_r(top * 0.53, top), top * 0.4, Vector3(lean.x * 0.2, top * 0.67, lean.y * 0.2))
	node.add_child(trunk)
	# the satellites: lesser giants either side, each with a deck at the middle deck's height
	for i in range((pl["sats"] as Array).size()):
		var e: Array = pl["sats"][i]
		var sd := _local_dir(pl, float(e[1]))
		var sc := sd * float(e[2])
		var sy := gy(ctx, pl, sc.x, sc.z)
		var stop := float(dk[1]) + 7.0
		var smb := MeshBuilder.new()
		var srings: Array = []
		for k in range(5):
			var y := sy - 0.8 + (stop - sy + 0.8) * k / 4.0
			var r := lerpf(1.25, 0.6, float(k) / 4.0)
			srings.append([y, r, r])
		smb.add_loft(bark, Transform3D(Basis(), sc), srings, MeshBuilder.profile_circle(8), 0.4, Color.WHITE, false, true, true, true)
		for k in range(4):
			var a := TAU * k / 4.0 + rng.randf_range(0, 1.0)
			var d := Vector3(cos(a), 0, sin(a))
			var tip := sc + d * rng.randf_range(3.0, 4.5) + Vector3(0, stop + rng.randf_range(0.0, 2.0), 0)
			smb.add_tube(bark, MeshBuilder.curve_points(sc + Vector3(0, stop - 2.0, 0), sc + Vector3(0, stop, 0) + d, tip, 4), 0.3, 0.12, 5, 0.5)
			var r := rng.randf_range(2.8, 3.8)
			smb.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tip + Vector3(0, 0.6, 0)), Vector3(r, r * 0.65, r), rng, 0.22, 3, 6, 0.45)
			crowns.append(tip + Vector3(0, 0.4, 0))
		var sb := body("Sapling%d" % i)
		sb.add_child(smb.to_instance("TrunkMesh"))
		cyl_col(sb, 1.1, stop - sy + 0.8, sc + Vector3(0, (sy + stop) * 0.5, 0))
		node.add_child(sb)
	# a vine swing can latch on any of the crowns
	for c in crowns:
		GrapplePoints.add(ctx.isl, ctx.isl.to_local(node.to_global(c)))


## The decks, the ladders between them, the rope bridges to the satellites, the
## lean-to on the first deck and the chest in the lookout at the top.
static func _tree_decks(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var planks := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.6})
	var beam := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	var decks := body("TreeDecks")
	var mb := MeshBuilder.new()
	var top: float = pl["top"]
	var dk := deck_heights(pl)
	# where each ladder up to a deck hangs (place-local bearing), spiralling round
	var lad_b: Array = []
	for i in range(dk.size()):
		lad_b.append(float(pl["lad"]) + i * 2.2)
	var bridge_b: Array = []
	for e in pl["sats"]:
		var d := _local_dir(pl, float(e[1]))
		bridge_b.append(atan2(d.z, d.x))
	for i in range(dk.size()):
		var y: float = dk[i]
		var gaps := [lad_b[i]]
		if i + 1 < dk.size():
			gaps.append(lad_b[i + 1])
		if i == 1:
			gaps.append_array(bridge_b)
		_deck_ring(mb, decks, planks, beam, y, trunk_r(y, top) - 0.15, maxf(DECK_R[i], trunk_r(y, top) + 2.2), gaps, i)
	# ladders: the ground to the first deck, then each deck to the next, at the upper deck's edge
	for i in range(dk.size()):
		var y: float = dk[i]
		var a: float = lad_b[i]
		var d := Vector3(cos(a), 0, sin(a))
		var at := d * (maxf(DECK_R[i], trunk_r(y, top) + 2.2) - 0.05)
		var below := gy(ctx, pl, at.x + d.x * 0.5, at.z + d.z * 0.5) if i == 0 else float(dk[i - 1])
		var lad := Ladder.new()
		lad.length = y - below + 0.05
		lad.rail = 0.0
		lad.deck_depth = 0.9
		lad.position = at + Vector3(0, y + 0.1, 0)
		lad.rotation.y = atan2(d.x, d.z)
		decks.add_child(lad)
	# rope bridges from the middle deck to each satellite's deck
	for i in range((pl["sats"] as Array).size()):
		var e: Array = pl["sats"][i]
		var sd := _local_dir(pl, float(e[1]))
		var sc := sd * float(e[2])
		var y: float = dk[1]
		_deck_ring(mb, decks, planks, beam, y, 1.0, 2.9, [atan2(-sd.z, -sd.x)], 3, sc)
		var a := sd * (maxf(DECK_R[1], trunk_r(y, top) + 2.2) - 0.1) + Vector3(0, y, 0)
		var b := sc - sd * 2.8 + Vector3(0, y, 0)
		bridge(mb, decks, planks, rope, a, b, 0.55)
		if i == 0:
			# the first satellite's own ladder down to the ground
			var ld := Vector3(-sd.z, 0, sd.x)
			var lat := sc + ld * 2.85
			var lad := Ladder.new()
			lad.length = y - gy(ctx, pl, lat.x + ld.x * 0.5, lat.z + ld.z * 0.5) + 0.05
			lad.rail = 0.0
			lad.deck_depth = 0.9
			lad.position = lat + Vector3(0, y + 0.1, 0)
			lad.rotation.y = atan2(ld.x, ld.z)
			decks.add_child(lad)
	# a lean-to on the first deck: a thatch roof on posts, a hammock, stores, a lantern
	var la: float = lad_b[0] + PI
	var ld := Vector3(cos(la), 0, sin(la))
	var lc := ld * (trunk_r(dk[0], top) + 1.9) + Vector3(0, float(dk[0]), 0)
	var lt := Vector3(-ld.z, 0, ld.x)
	var thatch := PSXMat.lit("thatch", Color.WHITE, {"affine": 0.8})
	var roof_xf := Transform3D(Basis(Vector3.UP, atan2(ld.x, ld.z)) * Basis(Vector3.RIGHT, -0.35), lc + Vector3(0, 2.3, 0))
	mb.add_box(thatch, roof_xf, Vector3(3.6, 0.12, 2.8), 0.6, Color.WHITE, false)
	for s in [-1.6, 1.6]:
		mb.add_box(beam, Transform3D(Basis(), lc + lt * s + ld * 1.0 + Vector3(0, 0.95, 0)), Vector3(0.12, 1.9, 0.12), 0.8)
	var ha := lc + lt * 1.4 - ld * 0.3 + Vector3(0, 1.3, 0)
	var hb := lc - lt * 1.4 - ld * 0.3 + Vector3(0, 1.3, 0)
	mb.add_tube(PSXMat.lit("canvas", Color(0.7, 0.62, 0.48)), MeshBuilder.sag_points(ha, hb, 0.55, 6), 0.22, 0.22, 5, 1.0)
	mb.add_tube(rope, PackedVector3Array([ha, ha + ld * 0.3 + Vector3(0, 0.6, 0)]), 0.03, 0.03, 4, 1.0)
	mb.add_tube(rope, PackedVector3Array([hb, hb + ld * 0.3 + Vector3(0, 0.6, 0)]), 0.03, 0.03, 4, 1.0)
	decks.add_child(far_off(mb.to_instance("Decks")))
	node.add_child(decks)
	var stores := lc + lt * 1.2 + ld * 0.5
	var crate := Props.crate(0.7)
	node.add_child(crate)
	crate.position = stores
	var lantern := Props.lantern_post(1.6)
	node.add_child(lantern)
	lantern.position = lc - lt * 1.5 + ld * 0.9
	KitLights.light(ctx, lantern, Vector3(0.55, 1.1, 0.0), 1.2, 9.0)
	# the lookout's chest, and a signal flag over the canopy
	var ta: float = lad_b[2] + PI
	var td := Vector3(cos(ta), 0, sin(ta))
	var y2: float = dk[2]
	var cp := td * (trunk_r(y2, top) + 0.9)
	chest(ctx, pl, cp + Vector3(0, y2 + 0.12, 0), atan2(-td.x, -td.z), "tree_chest", loot(isl, rng, true), 0.85)
	var flag := KitCamps.flag("TreeFlag", {"h": top - y2 + 4.0, "cloth": Color(0.85, 0.3, 0.2), "size": Vector2(1.4, 0.8)})
	node.add_child(flag)
	flag.position = td * (maxf(DECK_R[2], trunk_r(y2, top) + 2.2) - 0.3) + Vector3(0, y2, 0)


## An octagonal deck round a trunk at local `c` (+ height y): planks on joists
## with braces down to the trunk, a rail round its edge with gaps at `gaps`
## (bearings), and its colliders.
static func _deck_ring(mb: MeshBuilder, b: StaticBody3D, planks: Material, beam: Material, y: float, r_in: float, r_out: float, gaps: Array, salt: int, c := Vector3.ZERO) -> void:
	var o := c + Vector3(0, y, 0)
	var ph := 0.3 * salt
	var n := 8
	var rail_h := 1.0
	for k in range(n):
		var a0 := ph + TAU * k / n
		var a1 := ph + TAU * (k + 1) / n
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var i0 := o + d0 * r_in
		var i1 := o + d1 * r_in
		var e0 := o + d0 * r_out
		var e1 := o + d1 * r_out
		mb.add_quad(planks, i0, i1, e1, e0, Vector2(i0.x, i0.z) * 0.5, Vector2(i1.x, i1.z) * 0.5, Vector2(e1.x, e1.z) * 0.5, Vector2(e0.x, e0.z) * 0.5, Color.WHITE, Vector3.UP)
		var dn := Vector3(0, -0.16, 0)
		mb.add_quad(planks, i0 + dn, e0 + dn, e1 + dn, i1 + dn, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.6, 0.6, 0.6), Vector3.DOWN)
		var mid_out := (d0 + d1).normalized()
		mb.add_quad(beam, e0, e1, e1 + dn, e0 + dn, Vector2(0, 0), Vector2(e0.distance_to(e1) * 0.6, 0), Vector2(e0.distance_to(e1) * 0.6, 0.1), Vector2(0, 0.1), Color.WHITE, mid_out)
		# a joist under each corner, a brace from it down to the trunk
		beam(mb, beam, o + d0 * r_in + Vector3(0, -0.25, 0), o + d0 * (r_out - 0.1) + Vector3(0, -0.25, 0), 0.16)
		beam(mb, beam, o + d0 * (r_out * 0.75) + Vector3(0, -0.3, 0), o + d0 * (r_in + 0.1) + Vector3(0, -2.6, 0), 0.13)
		# (as wide as the outer edge: an average width leaves gaps at the corners, where ladders land)
		box_col_xf(b, Vector3(e0.distance_to(e1), 0.25, (r_out - r_in) * cos(PI / n)), Transform3D(Basis(Vector3.UP, atan2(mid_out.x, mid_out.z)), o + mid_out * (r_in + r_out) * 0.5 * cos(PI / n) + Vector3(0, -0.1, 0)))
		# the rail along this edge, unless a ladder or a bridge comes in here
		mb.add_box(beam, Transform3D(Basis(), e0 + Vector3(0, rail_h * 0.5, 0) - d0 * 0.05), Vector3(0.12, rail_h, 0.12), 0.8)
		var open := false
		for g in gaps:
			if absf(angle_difference(float(g), (a0 + a1) * 0.5)) < PI / n + 0.05:
				open = true
		if open:
			continue
		var ra := e0 + Vector3(0, rail_h, 0) - mid_out * 0.05
		var rb := e1 + Vector3(0, rail_h, 0) - mid_out * 0.05
		beam(mb, beam, ra, rb, 0.1)
		beam(mb, beam, ra - Vector3(0, 0.5, 0), rb - Vector3(0, 0.5, 0), 0.07)
		box_col_xf(b, Vector3(0.12, rail_h, e0.distance_to(e1)), Transform3D(Basis.looking_at((rb - ra).normalized(), Vector3.UP), (ra + rb) * 0.5 - Vector3(0, rail_h * 0.5, 0)))


## A rope bridge from a to b: planks on two ropes sagging `droop`, hand ropes
## with hangers, walkable (a box per stretch) with rope-high sides.
static func bridge(mb: MeshBuilder, b: StaticBody3D, planks: Material, rope: Material, a: Vector3, e: Vector3, droop: float) -> void:
	var pts := MeshBuilder.sag_points(a, e, droop, 10)
	var d := e - a
	d.y = 0.0
	var side := d.normalized().cross(Vector3.UP).normalized()
	var hw := 0.65
	for s in [-1.0, 1.0]:
		var foot := PackedVector3Array()
		var hand := PackedVector3Array()
		for q in pts:
			foot.append(q + side * s * hw + Vector3(0, -0.05, 0))
			hand.append(q + side * s * (hw + 0.05) + Vector3(0, 1.0, 0))
		mb.add_tube(rope, foot, 0.04, 0.04, 4, 1.0)
		mb.add_tube(rope, MeshBuilder.sag_points(a + side * s * (hw + 0.05) + Vector3(0, 1.0, 0), e + side * s * (hw + 0.05) + Vector3(0, 1.0, 0), droop * 0.8, 10), 0.04, 0.04, 4, 1.0)
		for k in range(1, pts.size() - 1):
			mb.add_tube(rope, PackedVector3Array([foot[k], hand[k]]), 0.025, 0.025, 3, 1.0)
	var length := a.distance_to(e)
	var steps := int(length / 0.36)
	for k in range(steps):
		var t := (k + 0.5) / steps
		var q := a.lerp(e, t) + Vector3.DOWN * droop * 4.0 * t * (1.0 - t)
		mb.add_box(planks, Transform3D(Basis.looking_at(side, Vector3.UP), q), Vector3(0.24, 0.05, hw * 2.0 + 0.1), 1.0, Color(0.9, 0.9, 0.9).darkened(float(k % 3) * 0.06), false)
	for k in range(pts.size() - 1):
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[k + 1]
		var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		box_col_xf(b, Vector3(hw * 2.0, 0.12, p0.distance_to(p1) + 0.05), Transform3D(basis, (p0 + p1) * 0.5 + Vector3(0, -0.08, 0)))
		for s in [-1.0, 1.0]:
			box_col_xf(b, Vector3(0.08, 1.0, p0.distance_to(p1)), Transform3D(basis, (p0 + p1) * 0.5 + side * s * (hw + 0.05) + Vector3(0, 0.45, 0)))


# ==========================================================================
# The stepped temple and its idol (outside only: its door stays shut)
# ==========================================================================
const TIERS := 5
const TIER_H := 2.7
const BASE_HALF := 10.0
const TIER_STEP := 1.4
## The stair's slope (deg) up the front.
const STAIR_DEG := 40.0
const STAIR_HW := 2.2


static func _plan_temple(isl: GenIsland, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var best := {}
	var best_s := INF
	var ck := canopy_k(isl.theme)
	for k in range(60):
		var p := rand_inland(isl, rng, 0.15, 0.72)
		var h := isl.hv(p)
		var s := grad(isl, p, 14.0 * ck).length()
		if h < 4.0 or s > 0.2 or not clear_of(isl, p, 24.0 * ck, avoid) or isl.path_dist(p) < 18.0 * ck:
			continue
		if s < best_s:
			best_s = s
			best = {"at": p, "y": h}
	if best.is_empty():
		return {}
	var p: Vector2 = best["at"]
	var h: float = best["y"]
	level(isl, p, h, 23.0 * ck, 31.0 * ck)
	var near := Vector2.ZERO
	var nd := INF
	for path in isl.paths:
		for q in path:
			if (q as Vector2).distance_to(p) < nd:
				nd = (q as Vector2).distance_to(p)
				near = q
	var face := (near - p).normalized()
	var run := TIERS * TIER_H / tan(deg_to_rad(STAIR_DEG))
	return {"kind": "temple", "role": "landmark", "at": p, "y": h, "face": face, "r": 24.0 * ck,
		"keep": [[Vector2.ZERO, 14.5 * ck], [Vector2(0, 12.5 * ck), 9.0 * ck]],
		"door": p + face * (BASE_HALF - TIERS * TIER_STEP + run + 3.0) * ck, "seed": rng.randi()}


## Tier k's half-size.
static func tier_half(k: int) -> float:
	return BASE_HALF - k * TIER_STEP


static func _temple(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var stone_c: Color = ctx.style["temple_stone"]
	var stone := PSXMat.lit("stone_brick", stone_c, {"affine": 0.6})
	var moss := PSXMat.lit("stone_brick", ctx.style["moss_tint"], {"affine": 0.6})
	var turf := PSXMat.lit("grass", Color(0.85, 0.95, 0.8), {"affine": 0.6})
	var vine_m := PSXMat.lit("leaves", Color(0.5, 0.72, 0.38))
	# (over a taller canopy the whole temple is drawn bigger: the node's scale)
	node.scale = Vector3.ONE * float(pl["k"])
	var b := body("StepPyramid")
	var mb := MeshBuilder.new()
	var top_y := TIERS * TIER_H
	for k in range(TIERS):
		var s := tier_half(k)
		var y0 := k * TIER_H - (0.8 if k == 0 else 0.0)
		var h := TIER_H + (0.8 if k == 0 else 0.0)
		# the walls in courses of stone (panels, each shaded a touch differently)
		for f in range(4):
			var bs := Basis(Vector3.UP, f * PI * 0.5)
			var nrm := bs * Vector3.BACK
			var along := bs * Vector3.RIGHT
			var n_p := int(ceil(s * 2.0 / 2.6))
			for i in range(n_p):
				var x0 := -s + s * 2.0 * i / n_p
				var x1 := -s + s * 2.0 * (i + 1) / n_p
				for row in range(2):
					var ya := y0 + h * row * 0.5
					var yb := y0 + h * (row + 1) * 0.5
					var p0 := nrm * s + along * x0 + Vector3(0, ya, 0)
					var p1 := nrm * s + along * x1 + Vector3(0, ya, 0)
					var shade := rng.randf_range(0.82, 1.0)
					var m := moss if rng.randf() < 0.25 + 0.1 * k else stone
					mb.add_quad(m, p0, p1, p1 + Vector3(0, yb - ya, 0), p0 + Vector3(0, yb - ya, 0),
						Vector2(x0, -ya) * 0.4, Vector2(x1, -ya) * 0.4, Vector2(x1, -yb) * 0.4, Vector2(x0, -yb) * 0.4, Color(shade, shade, shade), nrm)
			# a cornice round the tier's top
			mb.add_box(stone, Transform3D(bs, nrm * (s + 0.12) + Vector3(0, k * TIER_H + TIER_H - 0.15, 0)), Vector3(s * 2.0 + 0.5, 0.3, 0.3), 0.5, Color(0.9, 0.9, 0.9), false)
		# the terrace on top of it (grassed over at the edges), the next tier stands in its middle
		var t := k * TIER_H + TIER_H
		var s2 := tier_half(k + 1) if k + 1 < TIERS else 0.0
		var ring := [Vector3(-s, t, -s), Vector3(s, t, -s), Vector3(s, t, s), Vector3(-s, t, s)]
		if k + 1 < TIERS:
			var inner := [Vector3(-s2, t, -s2), Vector3(s2, t, -s2), Vector3(s2, t, s2), Vector3(-s2, t, s2)]
			for i in range(4):
				var a0: Vector3 = ring[i]
				var a1: Vector3 = ring[(i + 1) % 4]
				var b1: Vector3 = inner[(i + 1) % 4]
				var b0: Vector3 = inner[i]
				mb.add_quad(turf if rng.randf() < 0.6 else moss, a0, a1, b1, b0, Vector2(a0.x, a0.z) * 0.3, Vector2(a1.x, a1.z) * 0.3, Vector2(b1.x, b1.z) * 0.3, Vector2(b0.x, b0.z) * 0.3, Color.WHITE, Vector3.UP)
		else:
			mb.add_quad(stone, ring[0], ring[1], ring[2], ring[3], Vector2(-s, -s) * 0.35, Vector2(s, -s) * 0.35, Vector2(s, s) * 0.35, Vector2(-s, s) * 0.35, Color(0.95, 0.95, 0.95), Vector3.UP)
		box_col(b, Vector3(s * 2.0, h, s * 2.0), Vector3(0, y0 + h * 0.5, 0))
		# vines down its faces from the cornice
		for v in range(4 + k):
			var f := rng.randi() % 4
			var bs := Basis(Vector3.UP, f * PI * 0.5)
			var at := bs * Vector3(rng.randf_range(-s + 0.5, s - 0.5), t - 0.1, s + 0.2)
			vine(mb, vine_m, at, rng.randf_range(1.2, TIER_H * 0.9), bs * Vector3.BACK, rng)
	# the stair up the front, with its balustrades ending in serpents' heads
	var run := top_y / tan(deg_to_rad(STAIR_DEG))
	var zt := tier_half(TIERS - 1)
	var n_steps := int(top_y / 0.36)
	for i in range(n_steps):
		var y := top_y * (i + 1) / n_steps
		var z := zt + run * (1.0 - float(i + 1) / n_steps)
		var shade := 0.85 + 0.15 * float(i % 2)
		mb.add_box(stone, Transform3D(Basis(), Vector3(0, y - top_y / n_steps * 0.5, z + run / n_steps * 0.5)), Vector3(STAIR_HW * 2.0, top_y / n_steps, run / n_steps + 0.02), 0.6, Color(shade, shade, shade))
	var ang := deg_to_rad(STAIR_DEG)
	var ramp_len := Vector2(run, top_y).length()
	box_col_xf(b, Vector3(STAIR_HW * 2.0, 0.4, ramp_len), Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(0, top_y * 0.5 - 0.2 * cos(ang), zt + run * 0.5 + 0.2 * sin(ang))))
	for s in [-1.0, 1.0]:
		var outline := PackedVector2Array([Vector2(0, 0), Vector2(run + 1.2, 0), Vector2(run + 1.2, 1.4), Vector2(run, 1.0), Vector2(0, top_y + 1.0)])
		mb.add_extrude(stone, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(s * (STAIR_HW + 0.35), 0, zt)), outline, 0.7, 0.4)
		box_col_xf(b, Vector3(0.7, 1.2, ramp_len), Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(s * (STAIR_HW + 0.35), top_y * 0.5 + 0.5, zt + run * 0.5)))
		# the serpent's head at its foot: a snout, the eyes, fangs
		var hp := Vector3(s * (STAIR_HW + 0.35), 0.9, zt + run + 1.3)
		mb.add_box(stone, Transform3D(Basis(), hp), Vector3(0.9, 1.0, 1.1), 0.5, Color(0.9, 0.9, 0.9))
		mb.add_box(stone, Transform3D(Basis(), hp + Vector3(0, -0.25, 0.55)), Vector3(0.8, 0.45, 0.4), 0.5, Color(0.8, 0.8, 0.8))
		mb.add_box(PSXMat.flat(Color(0.12, 0.12, 0.1)), Transform3D(Basis(), hp + Vector3(0, 0.2, 0.56)), Vector3(0.7, 0.14, 0.04), 1.0)
		for fx in [-0.25, 0.25]:
			mb.add_cone(stone, Transform3D(Basis(Vector3.RIGHT, PI), hp + Vector3(fx, -0.02, 0.62)), 0.07, 0.25, 4, 1.0)
	# the sealed door at the back: a lintel, jambs, a slab across it, a glyph panel
	var dz := -BASE_HALF - 0.05
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 3.1, dz)), Vector3(3.6, 0.6, 0.5), 0.5, Color(0.85, 0.85, 0.85), false)
	for s in [-1.0, 1.0]:
		mb.add_box(stone, Transform3D(Basis(), Vector3(s * 1.45, 1.4, dz)), Vector3(0.6, 2.8, 0.45), 0.5, Color(0.88, 0.88, 0.88))
	mb.add_box(moss, Transform3D(Basis(Vector3.BACK, 0.03), Vector3(0, 1.4, dz - 0.12)), Vector3(2.4, 2.8, 0.3), 0.4, Color(0.75, 0.75, 0.75))
	var glyph := PSXMat.flat(stone_c.darkened(0.45))
	for k in range(6):
		mb.add_box(glyph, Transform3D(Basis(), Vector3(-0.8 + (k % 3) * 0.8, 1.0 + (k / 3) * 1.0, dz - 0.28)), Vector3(0.45, 0.45, 0.04), 1.0)
	var door := Marker3D.new()
	door.name = "TempleDoor"
	door.position = Vector3(0, 0, dz)
	door.rotation.y = PI
	b.add_child(door)
	# rubble fallen round the foot
	var at: Array = []
	for k in range(14):
		var a := TAU * k / 14.0 + rng.randf_range(-0.1, 0.1)
		var q := Vector3(cos(a), 0, sin(a)) * BASE_HALF * rng.randf_range(1.05, 1.35)
		if absf(q.x) < STAIR_HW + 1.5 and q.z > 0.0:
			continue
		mb.add_box(stone if k % 2 == 0 else moss, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), Vector3(q.x, gy(ctx, pl, q.x, q.z) + 0.25, q.z)),
			Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 1.2)), 0.5, Color(0.9, 0.9, 0.9))
		at.append(q)
	b.add_child(mb.to_instance("TempleMesh"))
	node.add_child(b)
	# plants rooted on the terraces: a couple of the island's trees and its bushes
	var m := IslandTheme.meshes(ctx.isl.get("theme"))
	for k in range(3):
		var tier := 1 + rng.randi() % (TIERS - 2)
		var f := rng.randi() % 4
		var s := tier_half(tier)
		var bs := Basis(Vector3.UP, f * PI * 0.5)
		var q := bs * Vector3(rng.randf_range(-s + 1.0, s - 1.0), tier * TIER_H, s - 0.6)
		var tree := MeshInstance3D.new()
		tree.name = "TempleTree"
		var tm: Array = m["tree"] if k < 2 else m["bush"]
		tree.mesh = tm[rng.randi() % tm.size()]
		tree.position = q
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.6, 0.85)
		node.add_child(tree)


## The idol's head on top facing the stair, fire bowls either side, an offering chest at its chin.
static func _temple_top(isl: GenIsland, ctx: KitContext, pl: Dictionary) -> void:
	var node := node_of(ctx, pl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 1
	var top_y := TIERS * TIER_H
	var stone := PSXMat.lit("stone_brick", (ctx.style["temple_stone"] as Color).lightened(0.05), {"affine": 0.6})
	var dark := PSXMat.flat((ctx.style["temple_stone"] as Color).darkened(0.6))
	var gold := PSXMat.lit("metal", Color(0.95, 0.75, 0.3))
	var idol := body("Idol")
	var mb := MeshBuilder.new()
	var c := Vector3(0, top_y, -1.4)
	# plinth, then the head: a block of a face under a flared headdress
	mb.add_box(stone, Transform3D(Basis(), c + Vector3(0, 0.3, 0)), Vector3(4.2, 0.6, 3.6), 0.4)
	var head := c + Vector3(0, 0.6, 0)
	mb.add_loft(stone, Transform3D(Basis(), head), [[0.0, 1.5, 1.3], [1.2, 1.65, 1.4], [2.6, 1.7, 1.45], [3.4, 1.6, 1.35], [3.5, 1.9, 1.6], [4.4, 2.3, 1.7], [4.6, 2.0, 1.5]],
		MeshBuilder.profile_oct(0.62), 0.4, Color.WHITE, false, true, true, true)
	# the brow, deep eyes, the nose, a grim mouth with teeth, ear spools
	var f := head + Vector3(0, 0, 1.38)
	mb.add_box(stone, Transform3D(Basis(), f + Vector3(0, 2.85, 0.12)), Vector3(3.0, 0.42, 0.4), 0.5, Color(0.9, 0.9, 0.9), false)
	for s in [-1.0, 1.0]:
		mb.add_box(dark, Transform3D(Basis(), f + Vector3(s * 0.7, 2.35, 0.05)), Vector3(0.75, 0.42, 0.12), 1.0)
		mb.add_box(gold, Transform3D(Basis(), f + Vector3(s * 0.7, 2.35, 0.1)), Vector3(0.22, 0.22, 0.06), 1.0)
		mb.add_cylinder(stone, Transform3D(Basis(Vector3.BACK, PI * 0.5), head + Vector3(s * 1.9, 1.9, 0.2)), 0.42, 0.42, 0.35 * s, 8, 0.6, Color(0.9, 0.9, 0.9), true, true)
	mb.add_extrude(stone, Transform3D(Basis(Vector3.UP, PI * 0.5), f + Vector3(0, 1.4, 0.05)), PackedVector2Array([Vector2(0, 0), Vector2(0.75, 0), Vector2(0, 1.0)]), 0.6, 0.5)
	mb.add_box(dark, Transform3D(Basis(), f + Vector3(0, 0.75, 0.04)), Vector3(1.6, 0.42, 0.1), 1.0)
	for k in range(6):
		mb.add_box(stone, Transform3D(Basis(), f + Vector3(-0.62 + k * 0.25, 0.86, 0.09)), Vector3(0.16, 0.2, 0.08), 1.0)
	box_col(idol, Vector3(3.6, 5.2, 3.2), c + Vector3(0, 2.6, 0))
	# the fire bowls at the top of the stair
	var s0 := tier_half(TIERS - 1)
	var bowl := PSXMat.lit("metal", Color(0.45, 0.4, 0.35))
	var flame := PSXMat.glow(Color(1.0, 0.55, 0.15), 2.6)
	for s in [-1.0, 1.0]:
		var bp := Vector3(s * (STAIR_HW + 0.6), top_y, s0 - 0.9)
		mb.add_cylinder(stone, Transform3D(Basis(), bp), 0.35, 0.28, 0.9, 6, 0.6)
		mb.add_loft(bowl, Transform3D(Basis(), bp + Vector3(0, 0.9, 0)), [[0.0, 0.2, 0.2], [0.25, 0.55, 0.55], [0.4, 0.62, 0.62]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, false, false)
		for k in range(3):
			mb.add_card(flame, Transform3D(Basis(Vector3.UP, k * PI / 3.0), bp + Vector3(0, 1.2, 0)), 0.75, 0.9, Rect2(0, 0, 1, 1), Color.WHITE)
		box_col(idol, Vector3(0.8, 1.3, 0.8), bp + Vector3(0, 0.65, 0))
	idol.add_child(mb.to_instance("IdolMesh"))
	node.add_child(idol)
	KitLights.light(ctx, idol, Vector3(0, top_y + 1.6, s0 - 0.9), 1.6, 12.0)
	for s in [-1.0, 1.0]:
		puffs(idol, Vector3(s * (STAIR_HW + 0.6), top_y + 1.6, s0 - 0.9), Color(0.4, 0.38, 0.36, 0.35), 6, 0.9, 0.5, 0.2)
	chest(ctx, pl, c + Vector3(0, 0.62, 2.3), 0.0, "temple_offering", loot(isl, rng, true), 0.95)
