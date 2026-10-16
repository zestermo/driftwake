class_name DesertPlaces
extends RefCounted
## The desert's own places (DesertTheme's place hooks): on each of the island's oases a pool in date
## palms and reeds with a camp on its bank; standing in for the chain's landmarks a caravan's camp (for
## the waterfall), an obelisk (the great tree) and the twin guardians (the totem grove). Planned on the
## worker, built a step each through KitLandmarks' helpers. The models (camel, long_tent, shaduf, obelisk,
## guardian) stand alone: front +Z, origin on the ground.

## The chain's kinds the desert stands its own in for: landmarks, then set pieces.
const KINDS := {"waterfall": "caravan_camp", "great_tree": "obelisk", "totem_grove": "guardians",
	"volcano_vent": "ruined_skyline", "sunken_village": "buried_city", "cenote": "tomb"}
const SAND := Color(0.95, 0.85, 0.66)
const HIDE := Color(0.82, 0.62, 0.42)
const CLOTH := Color(0.56, 0.45, 0.36)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _stone() -> Material:
	return PSXMat.lit("sandstone")


## Heaped sand (untextured: the sand texture pinwheels on a blob's cap), the dunes' colour.
static func _sand() -> Material:
	return PSXMat.flat(Color(0.88, 0.73, 0.5))


# ==========================================================================
# Planning (worker)
# ==========================================================================
## A pool in each oasis hollow that has room (off the sites, the places and the paths): its bed dug, its
## banks levelled, a camp on the bank where the land round it is lowest ("camp", place-local); none where
## it rises steeply on every side.
static func plan_oases(isl, avoid: Array) -> Array:
	var out: Array = []
	for o in isl.land_plan["oases"]:
		var c: Vector2 = o[0]
		var pr := clampf(float(o[1]) * 0.3, 6.0, 9.5)
		var w: float = isl.hv(c)
		if w < 2.0 or not KitLandmarks.clear_of(isl, c, pr + 9.0, avoid) or isl.path_dist(c) < pr + 5.0:
			continue
		var best := Vector2.ZERO
		var rise := INF
		for k in range(12):
			var d := Vector2.from_angle(TAU * k / 12.0)
			var r := maxf(isl.hv(c + d * (pr + 7.0)), isl.hv(c + d * (pr + 13.0))) - w
			if r < rise and isl.path_dist(c + d * (pr + 6.5)) > 4.0:
				rise = r
				best = d
		if rise > 2.5:
			continue
		var face := (KitSetPieces._nearest_path(isl, c) - c).normalized()
		var camp := KitLandmarks.local_of(c, face, c + best * (pr + 6.5))
		KitLandmarks.level(isl, c, w + 0.35, pr + 1.0, pr + 11.0)
		KitLandmarks.level(isl, c + best * (pr + 6.5), w + 0.35, 5.0, 9.0)
		# (where the land falls away past the bank, the bank still stands over the water)
		KitLandmarks.shape(isl, c, pr + 8.0, func(h: float, d: float, _p: Vector2) -> float:
			return maxf(h, lerpf(w + 0.35, w - 1.0, GenIsland._smooth(pr + 4.0, pr + 8.0, d))))
		KitLandmarks.level(isl, c, w - 1.5, pr - 1.6, pr + 0.2)
		out.append({"kind": "oasis" if out.is_empty() else "oasis_%d" % (out.size() + 1), "at": c, "y": w + 0.35, "face": face,
			"r": pr + 12.0, "keep": [[Vector2.ZERO, pr + 1.2], [camp, 5.5]], "door": c + face * (pr + 9.0), "pool": pr, "water": w, "camp": camp})
	return out


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var pl: Dictionary
	match kind:
		"caravan_camp":
			pl = KitWilds._spot(isl, rng, avoid, 15.0, 0.18, 3.0, 6.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 11.0, 16.0)
				pl["keep"] = [[Vector2.ZERO, 11.5]]
		"obelisk":
			pl = KitWilds._spot(isl, rng, avoid, 10.0, 0.25, 5.0, 6.0, true)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 6.0, 10.0)
				pl["keep"] = [[Vector2.ZERO, 6.0], [Vector2(5.5, -3.0), 3.0]]
				pl["h"] = rng.randf_range(13.0, 19.0)
		"guardians":
			pl = KitWilds._spot(isl, rng, avoid, 15.0, 0.2, 3.0, 8.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 10.0, 15.0)
				pl["keep"] = [[Vector2(-6.0, -1.0), 4.2], [Vector2(6.0, -1.0), 4.2], [Vector2(0.0, -7.5), 4.0]]
		"ruined_skyline":
			pl = KitSetPieces._plan_inland(isl, rng, avoid, 28.0, 0.22, 6.0, 12.0, true)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 22.0, 30.0)
				pl["keep"] = [[Vector2.ZERO, 24.0]]
		"buried_city":
			pl = KitSetPieces._plan_inland(isl, rng, avoid, 26.0, 0.2, 3.0, 10.0, false)
			if not pl.is_empty():
				_plan_buried(isl, pl, rng)
		"tomb":
			pl = KitSetPieces._plan_inland(isl, rng, avoid, 20.0, 0.15, 4.0, 10.0, false)
			if not pl.is_empty():
				KitLandmarks.level(isl, pl["at"], pl["y"], 15.0, 21.0)
				pl["keep"] = [[Vector2(0, -TOMB_OFF), TOMB_R + 1.5], [Vector2(0, 4.0), 5.0]]
				pl["top"] = rng.randf_range(12.0, 16.0)
				pl["door"] = (pl["at"] as Vector2) + (pl["face"] as Vector2) * 9.0
	if pl.is_empty():
		return {}
	pl["kind"] = kind
	return pl


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	var k := str(pl["kind"])
	if k.begins_with("oasis"):
		return [func(): _oasis(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _oasis_camp(isl, ctx, pl)]
	match k:
		"caravan_camp":
			return [func(): _caravan(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"obelisk":
			return [func(): _obelisk_place(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"guardians":
			return [func(): _guardians(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"ruined_skyline":
			return [func(): _skyline(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _skyline_dome(ctx, pl)]
		"buried_city":
			return [func(): _buried(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"tomb":
			return [func(): _tomb_rock(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _tomb_hall(isl, ctx, pl)]
	push_error("DesertPlaces: no place %s" % k)
	return []


static func _gy(ctx: KitContext, pl: Dictionary, x: float, z: float) -> float:
	return KitLandmarks.gy(ctx, pl, x, z)


## Instances of the meshes in `by_mesh` (mesh -> [Transform3D]), one MultiMesh each.
static func _multi(parent: Node3D, by_mesh: Dictionary, shadow: bool, range_end: float) -> void:
	for mesh in by_mesh.keys():
		var xs: Array = by_mesh[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in range(xs.size()):
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if not shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = range_end
		parent.add_child(mmi)


static func _add(by_mesh: Dictionary, mesh: Mesh, xf: Transform3D) -> void:
	if not by_mesh.has(mesh):
		by_mesh[mesh] = []
	by_mesh[mesh].append(xf)


# ==========================================================================
# The oasis: still water in palms and reeds, a well-sweep on the bank
# ==========================================================================
static func _oasis(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var pr: float = pl["pool"]
	var wy := float(pl["water"]) - float(pl["y"])
	var w := MeshBuilder.new()
	KitLandmarks.water_disc(w, KitLandmarks.flow_mat("water", ctx.style["water_tint"], Vector2(0.01, 0.015)), Vector3(0, wy, 0), pr + 0.4, 22, 0.25)
	var pad := PSXMat.flat(Color(0.3, 0.52, 0.26))
	for k in range(rng.randi_range(6, 12)):
		var a := rng.randf() * TAU
		KitLandmarks.water_disc(w, pad, Vector3(cos(a), 0, sin(a)) * rng.randf_range(pr * 0.4, pr * 0.85) + Vector3(0, wy + 0.025, 0), rng.randf_range(0.25, 0.45), 6, 1.0)
	var wmi := w.to_instance("OasisWater")
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(wmi)
	var pool := InlandPool.make(pr)
	pool.position = Vector3(0, wy, 0)
	node.add_child(pool)
	var m := IslandTheme.meshes(str(ctx.isl.get("theme")))
	var low := {}
	var palms := {}
	var b := KitLandmarks.body("OasisPalms")
	var ca := (pl["camp"] as Vector2).angle()
	# reeds in clumps round the water's edge, the camp's side left open
	for k in range(rng.randi_range(16, 24)):
		var a := rng.randf() * TAU
		if absf(angle_difference(a, ca)) < 0.45:
			continue
		var c := Vector3(cos(a), 0, sin(a)) * (pr + rng.randf_range(-0.7, 0.8))
		for j in range(rng.randi_range(2, 4)):
			var q := c + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			var list: Array = m["mangrove"] if rng.randf() < 0.6 else m["bamboo"]
			_add(low, list[rng.randi() % list.size()], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), Vector3(q.x, maxf(_gy(ctx, pl, q.x, q.z), wy) - 0.05, q.z)))
	# date palms leaning out over the pool, kept off the camp and the way in
	var n := rng.randi_range(8, 13)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.2, 0.2)
		if absf(angle_difference(a, ca)) < 0.5 or absf(angle_difference(a, PI * 0.5)) < 0.3:
			continue
		var d := Vector3(cos(a), 0, sin(a))
		var q := d * (pr + rng.randf_range(2.0, 8.5))
		q.y = _gy(ctx, pl, q.x, q.z) - 0.1
		var lean := Basis(d.cross(Vector3.UP).normalized(), rng.randf_range(0.04, 0.16))
		var list: Array = m["beach_tree"]
		_add(palms, list[rng.randi() % list.size()], Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), q))
		KitLandmarks.cyl_col(b, 0.3, 4.0, q + Vector3(0, 2.0, 0))
	_multi(node, low, false, 160.0)
	_multi(b, palms, true, 900.0)
	node.add_child(b)
	# flat stones at the water's edge, and a well-sweep reaching out over it
	var stones := MeshBuilder.new()
	var stone := _stone()
	for k in range(rng.randi_range(5, 8)):
		var a := rng.randf() * TAU
		var q := Vector3(cos(a), 0, sin(a)) * (pr + rng.randf_range(0.3, 1.2))
		stones.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, maxf(_gy(ctx, pl, q.x, q.z), wy) + 0.05, q.z)), Vector3(rng.randf_range(0.6, 1.1), 0.18, rng.randf_range(0.5, 0.9)), 0.6, Color.WHITE.darkened(rng.randf() * 0.2), true, false)
	node.add_child(KitLandmarks.far_off(stones.to_instance("OasisStones")))
	var sa := ca + 0.75
	var sq := Vector3(cos(sa), 0, sin(sa)) * (pr + 1.1)
	var sw := shaduf(int(pl["seed"]) + 3)
	sw.position = Vector3(sq.x, _gy(ctx, pl, sq.x, sq.z), sq.z)
	sw.rotation.y = atan2(-sq.x, -sq.z)
	node.add_child(sw)


## The camp on the bank: a long tent, its rugs and cushions, a fire, water jars, a couched camel, a lamp, a cache.
static func _oasis_camp(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 11)
	var node := KitLandmarks.node_of(ctx, pl)
	var c := ctx.under(node)
	var camp: Vector2 = pl["camp"]
	var u := camp.normalized()
	var v := u.orthogonal()
	var at := func(a: float, b: float) -> Vector3:
		var q := camp + u * a + v * b
		return Vector3(q.x, _gy(ctx, pl, q.x, q.y), q.y)
	var isle := func(a: float, b: float) -> Vector2:
		var q := camp + u * a + v * b
		return KitLandmarks.lp(pl, q.x, q.y)
	var to_pool := atan2(-u.x, -u.y)
	var tent := long_tent(int(pl["seed"]), rng.randf_range(5.0, 6.2), rng.randf_range(3.6, 4.2))
	tent.position = at.call(1.6, -0.5)
	tent.rotation.y = to_pool
	node.add_child(tent)
	KitCamps.campfire(c, isle.call(-2.2, 2.2), 1.0)
	for k in range(rng.randi_range(3, 5)):
		c.place(DesertProps.urn(rng.randf_range(0.7, 1.0), rng.randi()), isle.call(-0.4 + k * 0.6, -3.9 + rng.randf_range(-0.3, 0.3)), rng.randf() * TAU)
	var cam := camel(rng.randi())
	cam.position = at.call(1.0, 4.6)
	cam.rotation.y = to_pool + rng.randf_range(-0.6, 0.6)
	node.add_child(cam)
	KitLights.post(c, isle.call(-2.6, -2.4), float(pl["yaw"]))
	KitLandmarks.chest(ctx, pl, at.call(2.9, -3.9), atan2(-v.x, -v.y), str(pl["kind"]) + "_cache", KitLandmarks.loot(isl, rng, false), 0.8)


# ==========================================================================
# The caravan's camp: long tents round a fire, camels couched at the line, the loads stacked
# ==========================================================================
static func _caravan(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var c := ctx.under(node)
	var a0 := rng.randf() * TAU
	var tents := rng.randi_range(2, 3)
	for k in range(tents):
		var a := PI + (k - (tents - 1) * 0.5) * 0.95 + rng.randf_range(-0.1, 0.1)
		var q := Vector3(sin(a), 0, cos(a)) * rng.randf_range(7.0, 8.0)
		var t := long_tent(int(pl["seed"]) + k, rng.randf_range(5.0, 7.0), rng.randf_range(3.6, 4.4))
		t.position = Vector3(q.x, _gy(ctx, pl, q.x, q.z), q.z)
		t.rotation.y = atan2(-q.x, -q.z)
		t.name = "LongTent%d" % k
		node.add_child(t)
	KitCamps.campfire(c, KitLandmarks.lp(pl, 0, 0), 1.2)
	# the camel line: two posts, a rope, the camels couched along it
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var lx := rng.randf_range(5.5, 7.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var p0 := Vector3(lx, _gy(ctx, pl, lx, -3.5), -3.5)
	var p1 := Vector3(lx, _gy(ctx, pl, lx, 4.0), 4.0)
	for p in [p0, p1]:
		mb.add_cylinder(wood, _xf(p + Vector3(0, -0.3, 0)), 0.08, 0.07, 1.5, 5, 1.0)
	mb.add_tube(PSXMat.lit("rope"), MeshBuilder.sag_points(p0 + Vector3(0, 1.1, 0), p1 + Vector3(0, 1.1, 0), 0.35, 8), 0.025, 0.025, 3, 1.0)
	var camels := rng.randi_range(3, 5)
	for k in range(camels):
		var z := lerpf(-2.6, 3.2, (k + 0.5) / camels)
		var cm := camel(rng.randi())
		var x := lx + signf(lx) * rng.randf_range(1.2, 1.8)
		cm.position = Vector3(x, _gy(ctx, pl, x, z), z)
		cm.rotation.y = -signf(lx) * PI * 0.5 + rng.randf_range(-0.35, 0.35)
		cm.name = "Camel%d" % k
		node.add_child(cm)
	# the loads: bales, sacks and crates stacked by the line, rugs by the fire
	var bale := PSXMat.lit("canvas", Color(0.82, 0.74, 0.58))
	var rope := PSXMat.lit("rope")
	for k in range(rng.randi_range(5, 8)):
		var q := Vector3(lx - signf(lx) * rng.randf_range(1.0, 2.2), 0, rng.randf_range(-3.0, 3.5))
		q.y = _gy(ctx, pl, q.x, q.z)
		var s := Vector3(rng.randf_range(0.8, 1.1), rng.randf_range(0.5, 0.7), rng.randf_range(0.6, 0.8))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), q + Vector3(0, s.y * 0.5, 0))
		mb.add_box(bale, xf, s, 1.0, Color.WHITE.darkened(rng.randf() * 0.2))
		mb.add_box(rope, xf, s + Vector3(0.02, 0.02, -s.z + 0.06), 1.0)
		if rng.randf() < 0.4:
			mb.add_box(bale, xf * _xf(Vector3(0, s.y, 0), rng.randf_range(-0.5, 0.5)), s * 0.85, 1.0, Color.WHITE.darkened(0.1))
	var rug := PSXMat.lit("rug_kilim")
	for k in range(3):
		var a := a0 + TAU * k / 3.0
		var q := Vector3(cos(a), 0, sin(a)) * 2.4
		mb.add_box(rug, Transform3D(Basis(Vector3.UP, a + PI * 0.5), q + Vector3(0, _gy(ctx, pl, q.x, q.z) + 0.02, 0)), Vector3(2.2, 0.03, 1.2), 0.5, Color.WHITE, true, false)
	var b := KitLandmarks.body("CaravanLine")
	b.add_child(KitLandmarks.far_off(mb.to_instance("CaravanMesh")))
	KitLandmarks.box_col(b, Vector3(2.4, 1.0, 7.0), Vector3(lx - signf(lx) * 1.6, _gy(ctx, pl, lx, 0) + 0.5, 0.25))
	node.add_child(b)
	c.place(DesertTown.brazier(1.3), KitLandmarks.lp(pl, -lx * 0.5, -5.0), 0.0, 0.6)
	KitLights.light(ctx, node, Vector3(0, _gy(ctx, pl, 0, 0) + 1.2, 0), 1.6, 12.0)
	for k in range(rng.randi_range(2, 4)):
		c.place(DesertProps.urn(rng.randf_range(0.8, 1.1), rng.randi()), KitLandmarks.lp(pl, -lx * 0.35 + rng.randf_range(-1.0, 1.0), 5.5 + rng.randf_range(-0.6, 0.6)), rng.randf() * TAU)
	KitLandmarks.chest(ctx, pl, Vector3(-lx * 0.6, _gy(ctx, pl, -lx * 0.6, 2.5), 2.5), 0.0, "caravan_chest", KitLandmarks.loot(isl, rng, true), 0.9)


# ==========================================================================
# The obelisk: a needle of carved stone on its stepped plinth, its fallen twin in pieces
# ==========================================================================
static func _obelisk_place(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var ob := obelisk(int(pl["seed"]), float(pl["h"]))
	ob.position = Vector3(0, _gy(ctx, pl, 0, 0) - 0.15, 0)
	node.add_child(ob)
	var mb := MeshBuilder.new()
	var stone := _stone()
	var b := KitLandmarks.body("FallenTwin")
	# the twin: its shaft broken in three and half sunk, its tip in the sand further on
	var base := Vector3(5.5, 0, -3.0)
	var dir := Vector3(cos(rng.randf_range(-0.6, 0.6)), 0, sin(rng.randf_range(-0.6, 0.6))).normalized()
	var at := base
	var r := 0.62
	for k in range(3):
		var length := rng.randf_range(2.6, 3.6)
		var mid := at + dir * (length * 0.5)
		mid.y = _gy(ctx, pl, mid.x, mid.z) + r * 0.35
		var yaw := atan2(dir.x, dir.z) + rng.randf_range(-0.12, 0.12)
		mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.25), mid - Basis(Vector3.UP, yaw) * Vector3(0, 0, length * 0.5)), r, r * 0.92, length, 4, 0.6, Color.WHITE.darkened(0.05 * k), true, true, false)
		KitLandmarks.box_col_xf(b, Vector3(r * 1.3, r * 1.3, length), Transform3D(Basis(Vector3.UP, yaw), mid))
		at += dir * (length + rng.randf_range(0.3, 0.9))
		r *= 0.88
	var sand := _sand()
	var tip := at + dir * 0.6
	mb.add_cylinder(PSXMat.lit("metal", Color(1.1, 0.85, 0.4)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.9), Vector3(tip.x, _gy(ctx, pl, tip.x, tip.z) + 0.1, tip.z)), 0.5, 0.0, 0.8, 4, 1.0, Color.WHITE, false, true, false)
	for k in range(3):
		var q := base + dir * (k * 2.4 + 1.0) + dir.cross(Vector3.UP) * rng.randf_range(-0.8, 0.8)
		mb.add_blob(sand, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, _gy(ctx, pl, q.x, q.z) - 0.2, q.z)), Vector3(1.6, 0.6, 1.2), rng, 0.15, 3, 7, 0.25, Color.WHITE, 0.0)
	# its plinth's blocks scattered
	for k in range(rng.randi_range(4, 7)):
		var q := base + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
		var s := rng.randf_range(0.5, 0.9)
		mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), Vector3(q.x, _gy(ctx, pl, q.x, q.z) + s * 0.3, q.z)), Vector3(s * 1.4, s, s), 0.6, Color.WHITE.darkened(rng.randf() * 0.15))
	b.add_child(KitLandmarks.far_off(mb.to_instance("FallenTwinMesh")))
	node.add_child(b)
	KitLandmarks.chest(ctx, pl, Vector3(0, _gy(ctx, pl, 0, 2.9), 2.9), 0.0, "obelisk_offering", KitLandmarks.loot(isl, rng, true), 0.85)


## A needle of sandstone `h` tall on a stepped plinth: four tapering faces carved with columns of
## glyphs, a gilded cap, an offering niche in the plinth's front, sand drifted against its back.
static func obelisk(seed_value: int, h: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("Obelisk")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var dark := PSXMat.flat(Color(0.22, 0.15, 0.1))
	var y := 0.0
	for e in [[4.6, 0.5], [3.7, 0.5], [2.8, 0.6]]:
		var s: float = e[0]
		var sh: float = e[1]
		mb.add_box(stone, _xf(Vector3(0, y + sh * 0.5, 0)), Vector3(s, sh, s), 0.5, Color(0.9, 0.86, 0.8).darkened(y * 0.05))
		mb.add_box(stone, _xf(Vector3(0, y + sh - 0.04, 0)), Vector3(s + 0.12, 0.08, s + 0.12), 0.8, Color(0.96, 0.93, 0.88))
		DesertTown._box(body, Vector3(s, sh, s), Vector3(0, y + sh * 0.5, 0))
		y += sh
	mb.add_box(dark, _xf(Vector3(0, 0.55, 2.31)), Vector3(0.9, 0.7, 0.04), 1.0)
	var hb := 0.95
	var ht := 0.62
	mb.add_cylinder(stone, _xf(Vector3(0, y, 0), PI * 0.25), hb * sqrt(2.0), ht * sqrt(2.0), h, 4, 0.5, Color(0.98, 0.94, 0.88), false, false, false)
	DesertTown._box(body, Vector3(hb * 2.0, h, hb * 2.0), Vector3(0, y + h * 0.5, 0))
	mb.add_cylinder(PSXMat.lit("metal", Color(1.1, 0.85, 0.4)), _xf(Vector3(0, y + h, 0), PI * 0.25), ht * sqrt(2.0), 0.0, ht * 1.6, 4, 1.0, Color.WHITE, false, false, false)
	# the glyphs: a column down each face's middle, cut into the stone, framed by two grooves; a band round the foot
	var cut := PSXMat.lit("sandstone", Color(0.62, 0.5, 0.4))
	for f in range(4):
		var fb := Basis(Vector3.UP, f * PI * 0.5)
		var gy := y + 1.4
		while gy < y + h * 0.82:
			var t := (gy - y) / h
			var off := lerpf(hb, ht, t) + 0.012
			var gs := Vector3(rng.randf_range(0.18, 0.34), rng.randf_range(0.16, 0.3), 0.03)
			mb.add_box(cut, Transform3D(fb, fb * Vector3(rng.randf_range(-0.05, 0.05), gy, off)), gs, 1.0)
			gy += gs.y + rng.randf_range(0.2, 0.45)
		for s in [-1.0, 1.0]:
			var a := Vector3(s * hb * 0.42, y + 1.1, hb + 0.012)
			var b2 := Vector3(s * ht * 0.42, y + h * 0.84, lerpf(hb, ht, 0.84) + 0.012)
			mb.add_box(cut, Transform3D(fb * Basis.looking_at((b2 - a).normalized(), Vector3.BACK), fb * (a + b2) * 0.5), Vector3(0.05, 0.03, a.distance_to(b2)), 1.0)
		mb.add_box(dark, Transform3D(fb, fb * Vector3(0, y + 0.55, hb + 0.01)), Vector3(hb * 1.6, 0.06, 0.03), 1.0)
	var sand := _sand()
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-0.8, 0.8), 0.0, -2.6)), Vector3(2.6, 1.1, 1.4), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	body.add_child(mb.to_instance("ObeliskMesh"))
	return body


# ==========================================================================
# The twin guardians: two seated colossi either side of a processional way, a gate behind
# ==========================================================================
static func _guardians(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var broken := rng.randi() % 3
	for s in [-1, 1]:
		var g := guardian(int(pl["seed"]) + s, broken == (0 if s < 0 else 1))
		g.position = Vector3(s * 6.0, _gy(ctx, pl, s * 6.0, -1.0) - 0.4, -1.0)
		g.rotation.y = -s * 0.08
		g.name = "Guardian%d" % (s + 1)
		node.add_child(g)
	var mb := MeshBuilder.new()
	var stone := _stone()
	var b := KitLandmarks.body("GuardianGate")
	# the way between them: worn slabs, some missing
	for k in range(9):
		var z := 6.0 - k * 1.6
		for x in [-0.8, 0.8]:
			if rng.randf() < 0.2:
				continue
			mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(x + rng.randf_range(-0.05, 0.05), _gy(ctx, pl, x, z) + 0.04, z)), Vector3(1.5, 0.2, 1.45), 0.6, Color(0.9, 0.86, 0.8).darkened(rng.randf() * 0.15), true, false)
	# the gate: two battered towers and the lintel between, the sand over its foot
	var gz := -7.5
	var gy := _gy(ctx, pl, 0, gz) - 0.6
	for s in [-1.0, 1.0]:
		var outline := PackedVector2Array([Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(1.15, 7.2), Vector2(-1.15, 7.2)])
		mb.add_extrude(stone, _xf(Vector3(s * 2.6, gy, gz)), outline, 2.0, 0.5, Color(0.92, 0.88, 0.82))
		mb.add_box(stone, _xf(Vector3(s * 2.6, gy + 7.35, gz)), Vector3(2.7, 0.3, 2.3), 0.6, Color(0.96, 0.93, 0.88))
		DesertTown._box(b, Vector3(2.8, 7.2, 2.0), Vector3(s * 2.6, gy + 3.6, gz))
		for k in range(4):
			mb.add_box(PSXMat.flat(Color(0.22, 0.15, 0.1)), _xf(Vector3(s * 2.6, gy + 2.0 + k * 1.2, gz + 1.01)), Vector3(1.2 - k * 0.1, 0.08, 0.03), 1.0)
	mb.add_box(stone, _xf(Vector3(0, gy + 5.6, gz)), Vector3(3.4, 1.0, 1.7), 0.5, Color(0.94, 0.9, 0.84), false)
	mb.add_extrude(PSXMat.lit("metal", Color(1.1, 0.85, 0.4)), _xf(Vector3(0, gy + 5.6, gz + 0.86)), PackedVector2Array([Vector2(-0.9, -0.1), Vector2(-0.2, 0.05), Vector2(0, 0.3), Vector2(0.2, 0.05), Vector2(0.9, -0.1), Vector2(0, -0.2)]), 0.04, 1.0)
	var sand := _sand()
	for k in range(5):
		var q := Vector3(rng.randf_range(-7.0, 7.0), 0, rng.randf_range(-9.5, -5.0))
		mb.add_blob(sand, _xf(Vector3(q.x, _gy(ctx, pl, q.x, q.z) - 0.3, q.z), rng.randf() * TAU), Vector3(rng.randf_range(2.0, 3.2), rng.randf_range(0.8, 1.4), rng.randf_range(1.3, 2.0)), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	for k in range(rng.randi_range(5, 8)):
		var q := Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(-6.0, 6.0))
		var s := rng.randf_range(0.4, 0.8)
		mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), Vector3(q.x, _gy(ctx, pl, q.x, q.z) + s * 0.3, q.z)), Vector3(s * 1.5, s, s * 1.1), 0.6, Color.WHITE.darkened(rng.randf() * 0.15))
	b.add_child(KitLandmarks.far_off(mb.to_instance("GateMesh"), 900.0))
	node.add_child(b)
	KitLandmarks.chest(ctx, pl, Vector3(0, _gy(ctx, pl, 0, gz + 1.6), gz + 1.6), 0.0, "guardians_offering", KitLandmarks.loot(isl, rng, true), 0.9)


## A seated colossus about 10 m tall on its throne (sandstone, hands on its knees, a striped headcloth,
## a long beard), weathered; `broken` takes its head and an arm (the head lies in the sand before it).
static func guardian(seed_value: int, broken: bool) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("Guardian")
	var mb := MeshBuilder.new()
	var stone := _stone()
	var carved := _stone()
	var dark := PSXMat.flat(Color(0.2, 0.14, 0.1))
	var paint := PSXMat.lit("sandstone", Color(0.72, 0.74, 0.82))
	var worn := func() -> Color: return Color.WHITE.darkened(rng.randf() * 0.1)
	# the base and the throne (blocks), reliefs down its sides
	mb.add_box(stone, _xf(Vector3(0, 0.4, 0.6)), Vector3(4.8, 0.8, 7.0), 0.4, worn.call())
	DesertTown._box(body, Vector3(4.8, 0.8, 7.0), Vector3(0, 0.4, 0.6))
	mb.add_box(stone, _xf(Vector3(0, 2.45, -1.6)), Vector3(4.0, 3.3, 3.2), 0.4, worn.call())
	mb.add_box(stone, _xf(Vector3(0, 5.4, -2.95)), Vector3(4.0, 2.6, 0.5), 0.4, worn.call())
	DesertTown._box(body, Vector3(4.0, 3.3, 3.2), Vector3(0, 2.45, -1.6))
	for s in [-1.0, 1.0]:
		for k in range(3):
			mb.add_box(dark, _xf(Vector3(s * 2.01, 1.6 + k * 0.8, -1.6), PI * 0.5), Vector3(2.2 - k * 0.3, 0.07, 0.03), 1.0)
	# the figure, carved from one rock: shins with a gap between, thighs on the seat, the hands on the knees
	for s in [-1.0, 1.0]:
		mb.add_loft(carved, _xf(Vector3(s * 0.8, 0.8, 2.15)), [[0.0, 0.5, 0.55], [2.2, 0.42, 0.5], [3.1, 0.55, 0.62]], MeshBuilder.profile_oct(0.55), 0.35, worn.call(), false, true)
		mb.add_box(carved, _xf(Vector3(s * 0.8, 1.0, 2.75)), Vector3(0.95, 0.42, 1.6), 0.35, worn.call())
		DesertTown._box(body, Vector3(1.1, 3.1, 1.4), Vector3(s * 0.8, 2.35, 2.2))
		mb.add_loft(carved, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.8, 4.3, -1.3)), [[0.0, 0.68, 0.6], [2.4, 0.62, 0.56], [3.75, 0.58, 0.58]], MeshBuilder.profile_oct(0.55), 0.35, worn.call(), false, true)
	# the torso narrowing to the waist, a broad painted collar on the chest
	mb.add_loft(carved, _xf(Vector3(0, 3.9, -1.3)), [[0.0, 1.3, 0.85], [1.0, 1.1, 0.75], [2.3, 1.5, 0.8], [3.2, 1.75, 0.78], [3.65, 1.3, 0.62]], MeshBuilder.profile_oct(0.62), 0.35, worn.call(), false, true)
	DesertTown._box(body, Vector3(3.2, 3.8, 1.7), Vector3(0, 5.8, -1.3))
	for k in range(3):
		var r := 1.05 - k * 0.22
		var arc := PackedVector2Array()
		for i in range(9):
			var a := PI + PI * i / 8.0
			arc.append(Vector2(cos(a) * r, sin(a) * r * 0.8))
		mb.add_extrude(paint if k % 2 == 0 else carved, Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 7.25, -0.5 + k * 0.012)), arc, 0.08, 1.0, Color.WHITE.darkened(0.1 * k))
	for s in [-1.0, 1.0]:
		var sh := Vector3(s * 1.85, 7.05, -1.3)
		var el := Vector3(s * 1.95, 4.9, -0.85)
		var hand := Vector3(s * 0.85, 4.95, 1.8)
		if broken and s > 0.0:
			Buildings.beam_between(mb, carved, sh, sh.lerp(el, 0.55), 0.9, 0.85)
			continue
		Buildings.beam_between(mb, carved, sh, el, 0.95, 0.85)
		Buildings.beam_between(mb, carved, el, hand, 0.8, 0.72)
		mb.add_box(carved, _xf(hand + Vector3(0, 0.1, 0.2)), Vector3(0.95, 0.38, 1.05), 0.4, worn.call())
	if broken:
		mb.add_blob(carved, _xf(Vector3(0, 7.55, -1.3)), Vector3(0.95, 0.35, 0.7), rng, 0.3, 3, 6, 0.4, worn.call())
		_head(mb, Transform3D(Basis(Vector3.FORWARD, 1.3) * Basis(Vector3.UP, 0.6), Vector3(-3.4, 0.7, 5.4)), carved, dark, rng)
	else:
		mb.add_cylinder(carved, _xf(Vector3(0, 7.45, -1.25)), 0.55, 0.5, 0.6, 8, 0.4, worn.call())
		_head(mb, _xf(Vector3(0, 8.0, -1.2)), carved, dark, rng)
	var sand := _sand()
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-1.6, 1.6), 0.2, 3.6)), Vector3(2.2, 1.0, 1.4), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-1.0, 1.0), 0.2, -3.6)), Vector3(3.0, 2.2, 1.8), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	body.add_child(mb.to_instance("GuardianMesh"))
	return body


## The colossus's head on its neck's top at `xf`: the face, a striped headcloth with lappets down to the
## chest, a long plaited beard.
static func _head(mb: MeshBuilder, xf: Transform3D, stone: Material, dark: Material, rng: RandomNumberGenerator) -> void:
	var paint := PSXMat.lit("sandstone", Color(0.72, 0.74, 0.82))
	mb.add_blob(stone, xf * _xf(Vector3(0, 0.75, 0.05)), Vector3(0.68, 0.85, 0.72), rng, 0.04, 4, 8, 0.6, Color(0.96, 0.92, 0.86))
	mb.add_box(stone, xf * _xf(Vector3(0, 0.95, 0.66)), Vector3(0.95, 0.14, 0.2), 0.8, Color(0.9, 0.86, 0.8))
	mb.add_extrude(stone, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.62, 0.72)), PackedVector2Array([Vector2(-0.12, 0.3), Vector2(0.12, -0.1), Vector2(-0.14, -0.12)]), 0.22, 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(dark, xf * _xf(Vector3(s * 0.25, 0.82, 0.7)), Vector3(0.22, 0.08, 0.04), 1.0)
	mb.add_box(dark, xf * _xf(Vector3(0, 0.38, 0.72)), Vector3(0.36, 0.06, 0.04), 1.0)
	mb.add_box(stone, xf * _xf(Vector3(0, -0.05, 0.55)), Vector3(0.28, 0.75, 0.28), 0.8, Color(0.85, 0.8, 0.74))
	var cloth := [[Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.78, 1.45), Vector2(0.4, 1.75), Vector2(-0.4, 1.75), Vector2(-0.78, 1.45)]]
	mb.add_extrude(stone, xf * _xf(Vector3(0, 0.15, -0.15)), PackedVector2Array(cloth[0]), 1.15, 0.6, Color(0.95, 0.9, 0.82))
	for k in range(6):
		var sy := 0.25 + k * 0.28
		if sy > 1.45:
			mb.add_box(paint, xf * _xf(Vector3(0, sy, 0.43)), Vector3(1.2, 0.1, 0.04), 1.0, Color.WHITE.darkened(rng.randf() * 0.4))
			continue
		for s in [-1.0, 1.0]:
			mb.add_box(paint, xf * _xf(Vector3(s * 0.84, sy, 0.43)), Vector3(0.3, 0.1, 0.04), 1.0, Color.WHITE.darkened(rng.randf() * 0.4))
	for s in [-1.0, 1.0]:
		mb.add_box(stone, xf * Transform3D(Basis(Vector3.FORWARD, s * 0.12), Vector3(s * 0.78, -0.25, 0.25)), Vector3(0.42, 1.3, 0.3), 0.6, Color(0.95, 0.9, 0.82), false)
		for k in range(3):
			mb.add_box(paint, xf * Transform3D(Basis(Vector3.FORWARD, s * 0.12), Vector3(s * 0.78, -0.6 + k * 0.35, 0.41)), Vector3(0.4, 0.08, 0.02), 1.0, Color.WHITE.darkened(rng.randf() * 0.4))


# ==========================================================================
# The ruined skyline: a quarter of a fallen city on a rise, broken towers round a square,
# an arcade, a minaret still standing, a great dome torn open
# ==========================================================================
static func _skyline(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var mb := MeshBuilder.new()
	var b := KitLandmarks.body("Skyline")
	var spots: Array = []
	var n := rng.randi_range(10, 13)
	for i in range(n):
		var a := TAU * i / n + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, PI * 0.5)) < 0.42:
			continue
		spots.append(Vector2.from_angle(a) * rng.randf_range(11.0, 19.5))
	pl["dome_at"] = spots[0]
	var mi := 1
	for i in range(2, spots.size()):
		if (spots[i] as Vector2).distance_to(spots[0]) > (spots[mi] as Vector2).distance_to(spots[0]):
			mi = i
	var mq: Vector2 = spots[mi]
	spots.remove_at(mi)
	spots.insert(1, mq)
	var mn := DesertTown.minaret(rng.randi(), rng.randf_range(15.0, 19.0))
	mn.position = Vector3(mq.x, _gy(ctx, pl, mq.x, mq.y) - 0.6, mq.y)
	node.add_child(mn)
	var towers: Array = []
	for i in range(2, spots.size()):
		var q: Vector2 = spots[i]
		if q.distance_to(spots[0]) < 9.5 or q.distance_to(mq) < 5.0:
			continue
		towers.append(q)
		var col: Color = (DesertTown.WASH[rng.randi() % DesertTown.WASH.size()] as Color).lerp(SAND, 0.45)
		_tower(mb, b, rng, Vector3(q.x, _gy(ctx, pl, q.x, q.y), q.y), atan2(-q.x, -q.y), rng.randf_range(4.2, 6.5), rng.randf_range(4.0, 6.0), rng.randf_range(5.0, 11.5), col)
	# the arcade across the back of the square, broken in the middle
	var stone := _stone()
	var az := -rng.randf_range(5.0, 7.0)
	for s in [-1.0, 1.0]:
		var x0: float = s * 4.6
		var wy := _gy(ctx, pl, x0, az) - 0.3
		DesertTown._arched_wall(mb, stone, _xf(Vector3(x0, wy, az)), 6.6, 4.4, [[-2.2, 1.6, 3.4], [0.0, 1.6, 3.4], [2.2, 1.6, 3.4]], 0.6, Color(0.95, 0.9, 0.84))
		mb.add_box(stone, _xf(Vector3(x0, wy + 4.55, az)), Vector3(6.8, 0.3, 0.8), 0.6, Color(0.98, 0.95, 0.9))
		for hx in [-3.3, -1.1, 1.1, 3.3]:
			DesertTown._box(b, Vector3(0.6, 4.4, 0.6), Vector3(x0 + hx, wy + 2.2, az))
		DesertTown._box(b, Vector3(6.6, 1.0, 0.6), Vector3(x0, wy + 3.9, az))
	# rubble, fallen drums and the sand blown in
	var sand := _sand()
	for k in range(rng.randi_range(14, 20)):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 22.0)
		var s := rng.randf_range(0.3, 0.8)
		mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), Vector3(q.x, _gy(ctx, pl, q.x, q.y) + s * 0.3, q.y)), Vector3(s * 1.5, s, s * 1.1), 0.6, Color.WHITE.darkened(rng.randf() * 0.2))
	for k in range(rng.randi_range(3, 5)):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.0, 9.0)
		var yaw := rng.randf() * TAU
		for j in range(3):
			var dq := q + Vector2.from_angle(yaw) * j * 1.1
			mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, -yaw) * Basis(Vector3.BACK, PI * 0.5), Vector3(dq.x, _gy(ctx, pl, dq.x, dq.y) + 0.42, dq.y)), 0.45, 0.43, 1.0, 8, 0.8, Color.WHITE.darkened(0.08 * j), true, true)
	for k in range(rng.randi_range(6, 9)):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 24.0)
		mb.add_blob(sand, _xf(Vector3(q.x, _gy(ctx, pl, q.x, q.y) - 0.3, q.y), rng.randf() * TAU), Vector3(rng.randf_range(2.5, 4.5), rng.randf_range(0.8, 1.8), rng.randf_range(1.5, 2.6)), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	b.add_child(mb.to_instance("SkylineMesh"))
	node.add_child(b)
	var cq: Vector2 = towers[0]
	KitLandmarks.chest(ctx, pl, Vector3(cq.x, _gy(ctx, pl, cq.x, cq.y) + 0.1, cq.y), atan2(-cq.x, -cq.y), "skyline_cache", KitLandmarks.loot(isl, rng, true), 0.9)


## A broken tower of plaster on stone: four walls in courses of different heights (some fallen to stumps), a
## doorway toward the square, dark arched windows high up, its corner course capped.
static func _tower(mb: MeshBuilder, body: Node3D, rng: RandomNumberGenerator, c: Vector3, yaw: float, w: float, d: float, h: float, col: Color) -> void:
	var adobe := PSXMat.lit("adobe")
	var stone := _stone()
	var t := 0.45
	var bs := Basis(Vector3.UP, yaw)
	mb.add_box(stone, Transform3D(bs, c + Vector3(0, -0.4, 0)), Vector3(w + 0.4, 1.0, d + 0.4), 0.5, Color(0.88, 0.84, 0.78))
	DesertTown._box(body, Vector3(w + 0.4, 1.0, d + 0.4), c + Vector3(0, -0.4, 0), bs)
	for side in range(4):
		var sb := bs * Basis(Vector3.UP, side * PI * 0.5)
		var length := w if side % 2 == 0 else d
		var off := (d if side % 2 == 0 else w) * 0.5 - t * 0.5
		var segs := maxi(int(length / 1.3), 2)
		for k in range(segs):
			var x := -length * 0.5 + (k + 0.5) * length / segs
			var sw := length / segs + 0.01
			var sh := h if rng.randf() < 0.3 else h * rng.randf_range(0.45, 0.95)
			if rng.randf() < 0.12:
				sh = rng.randf_range(0.6, 1.6)
			if side == 0 and k == segs / 2:
				if sh > 3.4:
					mb.add_box(adobe, Transform3D(sb, c + sb * Vector3(x, (2.7 + sh) * 0.5, off)), Vector3(sw, sh - 2.7, t), 0.5, col, false)
					DesertTown._box(body, Vector3(sw, sh - 2.7, t), c + sb * Vector3(x, (2.7 + sh) * 0.5, off), sb)
				continue
			mb.add_box(adobe, Transform3D(sb, c + sb * Vector3(x, sh * 0.5 + 0.05, off)), Vector3(sw, sh + 0.1, t), 0.5, col.darkened(rng.randf() * 0.12))
			DesertTown._box(body, Vector3(sw, sh, t), c + sb * Vector3(x, sh * 0.5, off), sb)
			if sh >= h * 0.99:
				mb.add_box(stone, Transform3D(sb, c + sb * Vector3(x, sh + 0.12, off)), Vector3(sw + 0.02, 0.14, t + 0.12), 0.8, DesertTown.STONE_COL)
			if sh > 4.5 and rng.randf() < 0.55:
				DesertTown._arch_recess(mb, Transform3D(sb, c + sb * Vector3(x, 3.4, off + t * 0.5 + 0.01)), 0.6, 1.1, false)


## The great dome torn open: a drum of broken wall and the shell of its dome with a side fallen in, its
## glaze faded, the fallen pieces heaped inside.
static func _skyline_dome(ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := _rng(int(pl["seed"]) + 5)
	var q: Vector2 = pl["dome_at"]
	var c := Vector3(q.x, _gy(ctx, pl, q.x, q.y) - 0.3, q.y)
	var mb := MeshBuilder.new()
	var b := KitLandmarks.body("GreatDome")
	var adobe := PSXMat.lit("adobe")
	var stone := _stone()
	var glaze := PSXMat.lit("glaze", (DesertTown.DOMES[rng.randi() % DesertTown.DOMES.size()] as Color).lerp(SAND, 0.4))
	var r := rng.randf_range(4.5, 5.5)
	var drum := rng.randf_range(4.5, 6.0)
	var col := (DesertTown.WASH[rng.randi() % DesertTown.WASH.size()] as Color).lerp(SAND, 0.4)
	var na := 16
	var gap := rng.randi() % na
	for i in range(na):
		var a := TAU * (i + 0.5) / na
		var bs := Basis(Vector3.UP, -a + PI * 0.5)
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		if i == gap or i == (gap + 1) % na:
			mb.add_box(adobe, Transform3D(bs, p + Vector3(0, 0.4, 0)), Vector3(TAU * r / na + 0.1, 0.8, 0.6), 0.5, col)
			continue
		var sh := drum if absf(angle_difference(a, TAU * (gap + 1) / na)) > 1.2 else drum * rng.randf_range(0.5, 0.85)
		mb.add_box(adobe, Transform3D(bs, p + Vector3(0, sh * 0.5, 0)), Vector3(TAU * r / na + 0.1, sh, 0.6), 0.5, col.darkened(rng.randf() * 0.1))
		DesertTown._box(b, Vector3(TAU * r / na + 0.1, sh, 0.6), p + Vector3(0, sh * 0.5, 0), bs)
		if i % 2 == 0 and sh > 3.0:
			DesertTown._arch_recess(mb, Transform3D(bs, p + Vector3(0, 2.2, 0.31)), 0.7, 1.3, false)
	mb.add_cylinder(stone, _xf(c + Vector3(0, drum, 0)), r + 0.35, r + 0.35, 0.25, na, 0.8, DesertTown.STONE_COL, false, true)
	# the shell: rings up from the drum, a side torn out (both faces drawn, the inside darker)
	var rows := 6
	var hole := TAU * (gap + 1.0) / na
	for j in range(rows):
		var p0 := PI * 0.5 * j / rows
		var p1 := PI * 0.5 * (j + 1) / rows
		for i in range(na):
			var a0 := TAU * i / na
			var a1 := TAU * (i + 1) / na
			if j >= 1 and absf(angle_difference((a0 + a1) * 0.5, hole)) < 0.55 + 0.25 * j:
				continue
			var v := func(a: float, p: float) -> Vector3: return c + Vector3(cos(a) * cos(p) * r, drum + 0.25 + sin(p) * r * 0.95, sin(a) * cos(p) * r)
			var qa: Vector3 = v.call(a0, p0)
			var qb: Vector3 = v.call(a1, p0)
			var qc: Vector3 = v.call(a1, p1)
			var qd: Vector3 = v.call(a0, p1)
			var nrm := ((qa + qc) * 0.5 - (c + Vector3(0, drum, 0))).normalized()
			mb.add_quad(glaze, qa, qb, qc, qd, Vector2(a0 * r, p0 * r) * 0.3, Vector2(a1 * r, p0 * r) * 0.3, Vector2(a1 * r, p1 * r) * 0.3, Vector2(a0 * r, p1 * r) * 0.3, Color.WHITE, nrm)
			mb.add_quad(glaze, qa, qd, qc, qb, Vector2(a0 * r, p0 * r) * 0.3, Vector2(a0 * r, p1 * r) * 0.3, Vector2(a1 * r, p1 * r) * 0.3, Vector2(a1 * r, p0 * r) * 0.3, Color(0.5, 0.48, 0.45), -nrm)
	for k in range(rng.randi_range(6, 9)):
		var s := rng.randf_range(0.5, 1.2)
		var p := c + Vector3(rng.randf_range(-r, r) * 0.6, s * 0.3, rng.randf_range(-r, r) * 0.6)
		mb.add_box(glaze if k % 3 == 0 else adobe, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)), p), Vector3(s * 1.4, s * 0.5, s), 0.5, col)
	b.add_child(mb.to_instance("GreatDomeMesh"))
	node.add_child(b)


# ==========================================================================
# The buried city: houses sunk to their roofs in the dunes, domes and a minaret's top out of the
# sand, a temple's colonnade half drowned in it
# ==========================================================================
## Its houses (place-local, apart, the way in kept open) and the sand heaped over and between them.
static func _plan_buried(isl, pl: Dictionary, rng: RandomNumberGenerator) -> void:
	var at: Vector2 = pl["at"]
	var y: float = pl["y"]
	var yaw := KitContext.face_yaw(pl["face"])
	KitLandmarks.level(isl, at, y, 18.0, 26.0)
	var houses: Array = []
	var keep: Array = []
	var tries := 0
	var n := rng.randi_range(7, 10)
	while houses.size() < n and tries < 90:
		tries += 1
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 19.0)
		if absf(angle_difference(q.angle(), PI * 0.5)) < 0.35:
			continue
		var w := rng.randf_range(4.5, 6.5)
		var d := snappedf(w * rng.randf_range(0.75, 0.95), 0.1)
		var r := Vector2(w, d).length() * 0.5 + 1.0
		if houses.any(func(e): return (e[0] as Vector2).distance_to(q) < r + float(e[6])):
			continue
		var storeys := 2 if rng.randf() < 0.35 else 1
		houses.append([q, PI * 0.5 * rng.randi_range(0, 3) + rng.randf_range(-0.35, 0.35), w, d, storeys, rng.randf_range(1.8, 2.6) + (2.2 if storeys == 2 else 0.0), r, rng.randi()])
		keep.append([q, r])
	for k in range(rng.randi_range(10, 14)):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 22.0)
		var v := Basis(Vector3.UP, yaw) * Vector3(q.x, 0, q.y)
		var mr := rng.randf_range(5.0, 9.0)
		var mh := rng.randf_range(1.0, 2.4)
		KitLandmarks.shape(isl, at + Vector2(v.x, v.z), mr, func(h: float, dd: float, _p: Vector2) -> float:
			return h + mh * (1.0 - GenIsland._smooth(0.0, mr, dd)))
	pl["houses"] = houses
	pl["keep"] = keep


static func _buried(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var houses: Array = pl["houses"]
	var mb := MeshBuilder.new()
	var b := KitLandmarks.body("BuriedCity")
	var sand := _sand()
	var stone := _stone()
	for i in range(houses.size()):
		var e: Array = houses[i]
		var q: Vector2 = e[0]
		var hs := DesertTown.house({"w": e[2], "d": e[3], "storeys": e[4], "dome": 0.45, "seed": e[7], "name": "BuriedHouse%d" % i, "lit": 0.0})
		var gy := _gy(ctx, pl, q.x, q.y)
		hs.position = Vector3(q.x, gy - float(e[5]), q.y)
		hs.rotation.y = e[1]
		node.add_child(hs)
		# the sand drifted up its windward wall
		var side := Vector3(cos(float(e[1])), 0, -sin(float(e[1])))
		for s in [-1.0, 1.0]:
			if rng.randf() < 0.4:
				continue
			var dq: Vector3 = Vector3(q.x, 0, q.y) + side * s * float(e[2]) * 0.5
			mb.add_blob(sand, _xf(Vector3(dq.x, _gy(ctx, pl, dq.x, dq.z) - 0.2, dq.z), float(e[1])), Vector3(1.3, rng.randf_range(0.8, 1.6), float(e[3]) * 0.55), rng, 0.15, 3, 7, 0.25, Color.WHITE, 0.0)
	# a temple's colonnade drowned in the sand, two drums still bearing their lintel
	var tq := Vector2.ZERO
	for k in range(40):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 18.0)
		if not houses.any(func(e): return (e[0] as Vector2).distance_to(q) < float(e[6]) + 6.0):
			tq = q
			break
	var tyaw := rng.randf() * TAU
	var tb := Basis(Vector3.UP, tyaw)
	var tops: Array = []
	for k in range(6):
		var p := Vector3(tq.x, 0, tq.y) + tb * Vector3(-5.0 + k * 2.0, 0, 0)
		p.y = _gy(ctx, pl, p.x, p.z) - 0.6
		var h := 4.4 if k == 2 or k == 3 else rng.randf_range(1.2, 3.8)
		tops.append(p + Vector3(0, h, 0))
		mb.add_cylinder(stone, _xf(p, rng.randf() * TAU), 0.46, 0.4, h, 10, 0.6, Color(0.94, 0.9, 0.84))
		if h > 4.0:
			mb.add_box(stone, Transform3D(tb, p + Vector3(0, h + 0.15, 0)), Vector3(1.0, 0.3, 1.0), 0.6, DesertTown.STONE_COL)
		KitLandmarks.cyl_col(b, 0.46, h, p + Vector3(0, h * 0.5, 0))
	var lintel: Vector3 = (tops[2] + tops[3]) * 0.5 + Vector3(0, 0.6, 0)
	mb.add_box(stone, Transform3D(tb, lintel), Vector3(3.4, 0.6, 0.9), 0.5, Color(0.96, 0.92, 0.86), false)
	DesertTown._box(b, Vector3(3.4, 0.6, 0.9), lintel, tb)
	mb.add_extrude(stone, Transform3D(tb * Basis(Vector3.FORWARD, rng.randf_range(0.2, 0.4)), Vector3(tq.x, _gy(ctx, pl, tq.x, tq.y) + 0.2, tq.y) + tb * Vector3(0, 0, 2.4)),
		PackedVector2Array([Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(0, 1.6)]), 0.6, 0.5, Color(0.92, 0.88, 0.82))
	# domes of buried halls, just their tops out of the sand, and a minaret's top
	for k in range(rng.randi_range(1, 2)):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 22.0)
		var dr := rng.randf_range(2.0, 3.0)
		DesertTown.dome(mb, Vector3(q.x, _gy(ctx, pl, q.x, q.y) - 0.5, q.y), dr, (DesertTown.DOMES[rng.randi() % DesertTown.DOMES.size()] as Color).lerp(SAND, 0.45), rng.randf() < 0.3, 0.3)
		KitLandmarks.cyl_col(b, dr * 0.85, dr * 0.8, Vector3(q.x, _gy(ctx, pl, q.x, q.y) + dr * 0.4, q.y))
	var mq := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(12.0, 22.0)
	var mn := DesertTown.minaret(rng.randi(), 16.0)
	mn.position = Vector3(mq.x, _gy(ctx, pl, mq.x, mq.y) - 9.0, mq.y)
	node.add_child(mn)
	b.add_child(mb.to_instance("BuriedMesh"))
	node.add_child(b)
	var cq := tq + Vector2.from_angle(tyaw + PI * 0.5) * 2.2
	KitLandmarks.chest(ctx, pl, Vector3(cq.x, _gy(ctx, pl, cq.x, cq.y) - 0.15, cq.y), rng.randf() * TAU, "buried_city_chest", KitLandmarks.loot(isl, rng, true), 0.9)


# ==========================================================================
# The tomb: a rose sandstone crag with a temple front carved in its face, a pillared hall inside
# ==========================================================================
const TOMB_OFF := 9.0
const TOMB_R := 11.5
const HALL_HW := 3.4
const HALL_H := 5.0
const HALL_LEN := 14.0
const HALL_FLOOR := 0.6
const ROSE := Color(1.0, 0.8, 0.7)


static func _tomb_rock(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var noise := KitLandmarks.rock_noise(int(pl["seed"]), 0.2)
	var rock := PSXMat.lit("desert_rock", ROSE, {"affine": 0.6})
	var rock2 := PSXMat.lit("sandstone", ROSE.darkened(0.08), {"affine": 0.6})
	var top_m := PSXMat.lit("desert_sand", Color.WHITE, {"affine": 0.6})
	var pick := KitLandmarks.rock_pick(noise, rock, rock2, top_m)
	var top: float = pl["top"]
	var cz := -TOMB_OFF
	var front := PI * 0.5
	var na := 40
	var rows := 7
	var pts: Array = []
	for i in range(na):
		var a := TAU * i / na
		var f := 1.0 - GenIsland._smooth(0.25, 0.9, absf(angle_difference(a, front)))
		var rr := lerpf(rng.randf_range(TOMB_R - 0.5, TOMB_R + 1.5) + noise.get_noise_1d(a * 8.0), TOMB_OFF / maxf(sin(a), 0.5), f)
		var hh := top + 1.8 * noise.get_noise_1d(a * 6.0 + 30.0)
		var d := Vector3(cos(a), 0, sin(a))
		var foot := Vector3(0, 0, cz) + d * rr
		var fy := _gy(ctx, pl, foot.x, foot.z) - 1.0
		var col: Array = []
		for j in range(rows):
			var t := float(j) / (rows - 1)
			var r := rr * lerpf(1.03, lerpf(0.55, 1.0, f), pow(t, 0.8))
			var y := fy + (hh - fy) * pow(t, 0.9) if j > 0 else fy
			var q := Vector3(0, 0, cz) + d * r + Vector3(0, y, 0)
			col.append(q + d * noise.get_noise_3dv(q * 0.6) * (0.7 if j > 0 and j < rows - 1 else 0.2) * (1.0 - f * 0.9))
		pts.append(col)
	var opening := func(i: int, j: int) -> bool:
		var m: Vector3 = (pts[i][j] + pts[(i + 1) % na][j] + pts[i][j + 1] + pts[(i + 1) % na][j + 1]) * 0.25
		return absf(m.x) < 5.6 and m.z > -1.5 and m.y < 11.0
	var mb := MeshBuilder.new()
	KitLandmarks.rock_grid(mb, pts, Vector3(0, top + 0.5, cz), pick, 0.3, noise, false, opening)
	var b := KitSetPieces._mesh_body("TombRock", mb, true)
	node.add_child(b)
	var fa := tomb_facade(int(pl["seed"]))
	fa.position = Vector3(0, _gy(ctx, pl, 0, 0.5) - 0.05, 0)
	node.add_child(fa)


## The tomb's front, carved in rose sandstone (+Z out, its face at z 0, the door's sill HALL_FLOOR up):
## a podium of steps with a ramp under them, four columns, an entablature and a pediment; above, a round
## pavilion under a cone and an urn between two broken half-pediments on their own columns.
static func tomb_facade(seed_value: int) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("TombFacade")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("sandstone", ROSE)
	var dark := PSXMat.flat(Color(0.1, 0.06, 0.05))
	var shade := func() -> Color: return Color.WHITE.darkened(rng.randf() * 0.1)
	var door_hw := 1.3
	var door_top := HALL_FLOOR + 3.8
	# the face round the door
	for s in [-1.0, 1.0]:
		var cx: float = s * (door_hw + (5.8 - door_hw) * 0.5)
		mb.add_box(stone, _xf(Vector3(cx, 5.75, 0.15)), Vector3(5.8 - door_hw, 11.5, 0.3), 0.4, shade.call())
		DesertTown._box(body, Vector3(5.8 - door_hw, 11.5, 0.3), Vector3(cx, 5.75, 0.15))
	mb.add_box(stone, _xf(Vector3(0, (door_top + 11.5) * 0.5, 0.15)), Vector3(door_hw * 2.0, 11.5 - door_top, 0.3), 0.4, shade.call(), false)
	DesertTown._box(body, Vector3(door_hw * 2.0, 11.5 - door_top, 0.3), Vector3(0, (door_top + 11.5) * 0.5, 0.15))
	for s in [-1.0, 1.0]:
		mb.add_box(stone, _xf(Vector3(s * (door_hw + 0.12), (HALL_FLOOR + door_top) * 0.5, 0.36)), Vector3(0.24, door_top - HALL_FLOOR, 0.14), 0.8, Color(0.9, 0.85, 0.8))
	mb.add_box(stone, _xf(Vector3(0, door_top + 0.15, 0.38)), Vector3(door_hw * 2.0 + 0.7, 0.3, 0.2), 0.8, Color(0.92, 0.88, 0.84), false)
	# the podium's steps, a ramp under them
	for k in range(3):
		var sh := HALL_FLOOR * (3 - k) / 3.0
		mb.add_box(stone, _xf(Vector3(0, sh * 0.5 - 0.1, 0.3 + 0.55 * k + 0.3)), Vector3(9.0 - k * 0.6, sh + 0.2, 0.6), 0.6, Color(0.88, 0.84, 0.8))
	var run := 2.0
	DesertTown._box(body, Vector3(9.0, 0.12, Vector2(run, HALL_FLOOR).length()), Vector3(0, HALL_FLOOR * 0.5 - 0.06, 0.3 + run * 0.5), Basis(Vector3.RIGHT, atan2(HALL_FLOOR, run)))
	# the lower order: four columns, their capitals, the entablature, the pediment over the middle pair
	for x in [-4.4, -1.9, 1.9, 4.4]:
		mb.add_box(stone, _xf(Vector3(x, HALL_FLOOR + 0.15, 0.75)), Vector3(0.9, 0.3, 0.9), 0.8, Color(0.92, 0.88, 0.84))
		mb.add_cylinder(stone, _xf(Vector3(x, HALL_FLOOR + 0.3, 0.75)), 0.34, 0.3, 4.6, 10, 0.6, shade.call())
		mb.add_box(stone, _xf(Vector3(x, HALL_FLOOR + 5.05, 0.75)), Vector3(0.95, 0.35, 0.95), 0.8, Color(0.95, 0.9, 0.86))
		KitLandmarks.cyl_col(body, 0.34, 5.0, Vector3(x, HALL_FLOOR + 2.6, 0.75))
	mb.add_box(stone, _xf(Vector3(0, HALL_FLOOR + 5.65, 0.7)), Vector3(11.2, 0.85, 0.9), 0.5, shade.call(), false)
	for k in range(9):
		mb.add_box(dark, _xf(Vector3(-4.8 + k * 1.2, HALL_FLOOR + 5.7, 1.16)), Vector3(0.3, 0.32, 0.03), 1.0)
	mb.add_extrude(stone, _xf(Vector3(0, HALL_FLOOR + 6.08, 0.7)), PackedVector2Array([Vector2(-3.4, 0), Vector2(3.4, 0), Vector2(0, 1.5)]), 0.8, 0.5, shade.call())
	# the upper order: the round pavilion, its cone and urn, the half-pediments either side
	var uy := HALL_FLOOR + 7.6
	mb.add_box(stone, _xf(Vector3(0, uy - 0.1, 0.55)), Vector3(11.2, 0.25, 0.7), 0.6, Color(0.95, 0.9, 0.86))
	mb.add_cylinder(stone, _xf(Vector3(0, uy, 0.4)), 1.35, 1.35, 3.2, 12, 0.5, shade.call())
	mb.add_box(dark, _xf(Vector3(0, uy + 0.2, 1.72)), Vector3(0.8, 1.9, 0.04), 1.0)
	mb.add_cylinder(stone, _xf(Vector3(0, uy + 3.2, 0.4)), 1.55, 1.55, 0.25, 12, 0.6, Color(0.95, 0.9, 0.86), true, true)
	mb.add_cone(stone, _xf(Vector3(0, uy + 3.45, 0.4)), 1.35, 1.2, 12, 0.6, shade.call())
	mb.add_blob(stone, _xf(Vector3(0, uy + 4.9, 0.4)), Vector3(0.35, 0.45, 0.35), rng, 0.05, 3, 8, 0.8)
	for s in [-1.0, 1.0]:
		for x in [2.2, 4.8]:
			mb.add_cylinder(stone, _xf(Vector3(s * x, uy, 0.6)), 0.24, 0.22, 3.0, 8, 0.6, shade.call())
		mb.add_box(stone, _xf(Vector3(s * 3.5, uy + 3.15, 0.55)), Vector3(3.4, 0.3, 0.75), 0.6, Color(0.95, 0.9, 0.86))
		mb.add_extrude(stone, _xf(Vector3(s * 3.5, uy + 3.3, 0.55)), PackedVector2Array([Vector2(-1.7 * s, 0), Vector2(1.7 * s, 0), Vector2(1.7 * s, 0.9)]), 0.7, 0.5, shade.call())
		mb.add_box(stone, _xf(Vector3(s * 3.5, uy + 1.3, 0.31)), Vector3(1.4, 2.0, 0.04), 0.6, Color(0.55, 0.45, 0.42))
	body.add_child(mb.to_instance("FacadeMesh"))
	return body


## The hall inside: a stone floor up at the door's sill, plain walls with the burial niches cut in two rows,
## two rows of square pillars, a frieze, the sarcophagus at the back with its lid pushed askew, braziers,
## the treasure, bones and jars, sand blown in at the door.
static func _tomb_hall(isl, ctx: KitContext, pl: Dictionary) -> void:
	var node := KitLandmarks.node_of(ctx, pl)
	var rng := _rng(int(pl["seed"]) + 9)
	var mb := MeshBuilder.new()
	var b := KitLandmarks.body("TombHall")
	var stone := PSXMat.lit("sandstone", ROSE)
	var dark := PSXMat.flat(Color(0.06, 0.04, 0.03))
	var fy := _gy(ctx, pl, 0, 0.5) - 0.05
	var z0 := 0.0
	var z1 := -HALL_LEN
	var zc := (z0 + z1) * 0.5
	var inner := Color(0.62, 0.55, 0.5)
	mb.add_box(stone, _xf(Vector3(0, fy + HALL_FLOOR * 0.5 - 0.6, zc)), Vector3(HALL_HW * 2.0 + 0.8, HALL_FLOOR + 1.2, HALL_LEN), 0.5, inner)
	DesertTown._box(b, Vector3(HALL_HW * 2.0 + 0.8, HALL_FLOOR + 1.2, HALL_LEN), Vector3(0, fy + HALL_FLOOR * 0.5 - 0.6, zc))
	var ft := fy + HALL_FLOOR
	for s in [-1.0, 1.0]:
		mb.add_box(stone, _xf(Vector3(s * (HALL_HW + 0.2), ft + HALL_H * 0.5, zc)), Vector3(0.4, HALL_H, HALL_LEN), 0.5, inner, false)
		DesertTown._box(b, Vector3(0.4, HALL_H, HALL_LEN), Vector3(s * (HALL_HW + 0.2), ft + HALL_H * 0.5, zc))
		# the niches: two rows down the wall, some still sealed
		var x: float = s * (HALL_HW - 0.005)
		var z := -1.6
		while z > z1 + 2.6:
			for ny in [1.0, 2.5]:
				if rng.randf() < 0.3:
					mb.add_box(stone, _xf(Vector3(x, ft + ny, z), PI * 0.5), Vector3(1.0, 0.8, 0.06), 0.8, Color(0.85, 0.78, 0.72))
				else:
					mb.add_box(dark, _xf(Vector3(x, ft + ny, z), PI * 0.5), Vector3(1.0, 0.8, 0.03), 1.0)
			z -= 1.7
		mb.add_box(dark, _xf(Vector3(x, ft + HALL_H - 0.5, zc), PI * 0.5), Vector3(HALL_LEN - 0.4, 0.12, 0.03), 1.0)
	mb.add_box(stone, _xf(Vector3(0, ft + HALL_H * 0.5, z1 - 0.2)), Vector3(HALL_HW * 2.0 + 0.8, HALL_H, 0.4), 0.5, inner)
	DesertTown._box(b, Vector3(HALL_HW * 2.0 + 0.8, HALL_H, 0.4), Vector3(0, ft + HALL_H * 0.5, z1 - 0.2))
	mb.add_box(stone, _xf(Vector3(0, ft + HALL_H + 0.2, zc)), Vector3(HALL_HW * 2.0 + 0.8, 0.4, HALL_LEN + 0.4), 0.5, inner.darkened(0.2), false)
	DesertTown._box(b, Vector3(HALL_HW * 2.0 + 0.8, 0.4, HALL_LEN + 0.4), Vector3(0, ft + HALL_H + 0.2, zc))
	for x in [-1.75, 1.75]:
		for z in [-3.6, -7.2, -10.4]:
			mb.add_box(stone, _xf(Vector3(x, ft + HALL_H * 0.5, z)), Vector3(0.75, HALL_H, 0.75), 0.5, inner.lightened(0.1))
			mb.add_box(stone, _xf(Vector3(x, ft + HALL_H - 0.2, z)), Vector3(1.0, 0.4, 1.0), 0.8, inner.lightened(0.15), false)
			DesertTown._box(b, Vector3(0.75, HALL_H, 0.75), Vector3(x, ft + HALL_H * 0.5, z))
	# the sarcophagus, its lid pushed askew
	var sz := z1 + 1.9
	mb.add_box(stone, _xf(Vector3(0, ft + 0.5, sz)), Vector3(1.2, 1.0, 2.5), 0.6, Color(0.95, 0.9, 0.85))
	for k in range(3):
		mb.add_box(PSXMat.lit("metal", Color(1.1, 0.85, 0.4)), _xf(Vector3(0, ft + 0.25 + k * 0.28, sz)), Vector3(1.22, 0.05, 2.52), 1.0)
	mb.add_box(stone, Transform3D(Basis(Vector3.UP, 0.32), Vector3(0.35, ft + 1.13, sz + 0.2)), Vector3(1.3, 0.26, 2.6), 0.6, Color(0.98, 0.94, 0.9), false)
	DesertTown._box(b, Vector3(1.3, 1.25, 2.6), Vector3(0, ft + 0.62, sz))
	var bone := PSXMat.lit("plaster", Color(0.94, 0.88, 0.76))
	for k in range(rng.randi_range(5, 8)):
		var p := Vector3(rng.randf_range(-HALL_HW + 0.5, HALL_HW - 0.5), ft + 0.05, rng.randf_range(z1 + 1.0, z0 - 2.0))
		mb.add_cylinder(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), p), 0.05, 0.04, rng.randf_range(0.4, 0.8), 5, 1.0, Color.WHITE, true, true)
	mb.add_blob(bone, _xf(Vector3(rng.randf_range(-2.0, 2.0), ft + 0.12, z1 + 4.0)), Vector3(0.14, 0.12, 0.16), rng, 0.05, 3, 6, 1.0)
	mb.add_blob(_sand(), _xf(Vector3(0, ft - 0.25, -1.4)), Vector3(2.4, 0.5, 1.6), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	b.add_child(mb.to_instance("HallMesh"))
	node.add_child(b)
	for s in [-1.0, 1.0]:
		var br := DesertTown.brazier(1.3)
		br.position = Vector3(s * (HALL_HW - 0.8), ft, z1 + 1.0)
		node.add_child(br)
	KitLights.light(ctx, node, Vector3(0, ft + 2.2, z1 + 2.0), 1.8, 14.0)
	for k in range(rng.randi_range(3, 5)):
		var q := Vector2(rng.randf_range(-HALL_HW + 0.6, HALL_HW - 0.6), rng.randf_range(z1 + 1.0, z0 - 3.0))
		if absf(q.x) > 1.2 and absf(q.x) < 2.3:
			continue
		var u := DesertProps.urn(rng.randf_range(0.7, 1.0), rng.randi())
		u.position = Vector3(q.x, ft, q.y)
		node.add_child(u)
	KitLandmarks.chest(ctx, pl, Vector3(1.6, ft, z1 + 1.6), -PI * 0.5, "tomb_treasure", KitLandmarks.loot(isl, rng, true), 1.0)


# ==========================================================================
# Models
# ==========================================================================
## A camel couched on the sand, its neck up, a striped blanket and a pair of saddlebags on its hump.
static func camel(seed_value: int) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("Camel")
	var mb := MeshBuilder.new()
	var hide := PSXMat.lit("leather", HIDE)
	var tone := Color.WHITE.darkened(rng.randf() * 0.25).lerp(Color(1.05, 0.95, 0.85), rng.randf() * 0.4)
	mb.add_blob(hide, _xf(Vector3(0, 0.5, 0)), Vector3(0.7, 0.52, 1.15), rng, 0.08, 4, 8, 0.8, tone, -0.6)
	mb.add_blob(hide, _xf(Vector3(0, 0.98, -0.05)), Vector3(0.42, 0.42, 0.55), rng, 0.08, 3, 7, 0.8, tone)
	for s in [-1.0, 1.0]:
		mb.add_blob(hide, _xf(Vector3(s * 0.62, 0.2, 0.55)), Vector3(0.18, 0.18, 0.45), rng, 0.1, 3, 6, 0.8, tone.darkened(0.08), -0.5)
		mb.add_blob(hide, _xf(Vector3(s * 0.6, 0.25, -0.55)), Vector3(0.22, 0.26, 0.5), rng, 0.1, 3, 6, 0.8, tone.darkened(0.08), -0.5)
	var neck := MeshBuilder.curve_points(Vector3(0, 0.7, 0.95), Vector3(0, 0.75, 1.75), Vector3(0, 1.55, 1.7), 6)
	mb.add_tube(hide, neck, 0.24, 0.14, 6, 0.8, tone)
	var head := Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.25)), Vector3(0, 1.62, 1.86))
	mb.add_blob(hide, head, Vector3(0.15, 0.17, 0.36), rng, 0.06, 3, 6, 0.8, tone)
	for s in [-1.0, 1.0]:
		mb.add_box(hide, head * _xf(Vector3(s * 0.11, 0.17, -0.18)), Vector3(0.05, 0.1, 0.04), 1.0, tone.darkened(0.2))
		mb.add_box(PSXMat.flat(Color(0.08, 0.06, 0.05)), head * _xf(Vector3(s * 0.135, 0.08, -0.02)), Vector3(0.03, 0.04, 0.05), 1.0)
	mb.add_tube(hide, PackedVector3Array([Vector3(0, 0.75, -1.1), Vector3(0, 0.55, -1.25), Vector3(0, 0.3, -1.22)]), 0.05, 0.03, 4, 1.0, tone)
	var rug := PSXMat.lit("rug_kilim")
	mb.add_box(rug, _xf(Vector3(0, 1.4, -0.05)), Vector3(0.7, 0.05, 0.95), 0.8, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(rug, Transform3D(Basis(Vector3.BACK, s * 0.9), Vector3(s * 0.48, 1.2, -0.05)), Vector3(0.5, 0.05, 0.95), 0.8, Color.WHITE, false)
		mb.add_blob(PSXMat.lit("leather", Color(0.5, 0.34, 0.22)), _xf(Vector3(s * 0.75, 0.72, -0.1)), Vector3(0.2, 0.3, 0.32), rng, 0.08, 3, 6, 1.0)
	body.add_child(mb.to_instance("CamelMesh"))
	DesertTown._box(body, Vector3(1.4, 1.2, 2.3), Vector3(0, 0.6, 0.0))
	return body


## A long low tent of woven goat hair (w across its open front, d deep): rows of poles, the cloth sagging
## between them in dark and pale stripes, a back wall and side walls, guy ropes to stakes, rugs and cushions inside.
static func long_tent(seed_value: int, w: float, d: float) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("LongTent")
	var mb := MeshBuilder.new()
	var cloth := PSXMat.lit("canvas", CLOTH)
	var wood := PSXMat.lit("planks_dark")
	var nx := 6
	var nz := 4
	var height := func(x: float, z: float) -> float:
		var u := x / (w * 0.5)
		var v := (z + d * 0.5) / d
		var ridge := lerpf(1.25, 2.15, 1.0 - absf(u) * 0.6) * lerpf(0.72, 1.0, v) - 0.14 * absf(sin(u * PI * 1.5))
		return ridge
	var grid: Array = []
	for i in range(nx + 1):
		var row: Array = []
		for j in range(nz + 1):
			var x := -w * 0.5 + w * i / nx
			var z := -d * 0.5 + d * j / nz
			row.append(Vector3(x, height.call(x, z), z))
		grid.append(row)
	for i in range(nx):
		var stripe := Color.WHITE if i % 2 == 1 else Color(0.6, 0.6, 0.6)
		for j in range(nz):
			var a: Vector3 = grid[i][j]
			var b2: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]
			var e: Vector3 = grid[i][j + 1]
			var n := (b2 - a).cross(e - a).normalized()
			if n.y < 0.0:
				n = -n
			mb.add_quad(cloth, a, b2, c, e, Vector2(a.x, a.z) * 0.5, Vector2(b2.x, b2.z) * 0.5, Vector2(c.x, c.z) * 0.5, Vector2(e.x, e.z) * 0.5, stripe, n)
			mb.add_quad(cloth, a, e, c, b2, Vector2(a.x, a.z) * 0.5, Vector2(e.x, e.z) * 0.5, Vector2(c.x, c.z) * 0.5, Vector2(b2.x, b2.z) * 0.5, stripe * 0.55, -n)
	# the back wall and the sides' back halves down to the sand
	for i in range(nx):
		var a: Vector3 = grid[i][0]
		var b2: Vector3 = grid[i + 1][0]
		mb.add_quad(cloth, Vector3(a.x, 0, a.z), Vector3(b2.x, 0, b2.z), b2, a, Vector2(a.x * 0.5, a.y * 0.5), Vector2(b2.x * 0.5, b2.y * 0.5), Vector2(b2.x * 0.5, 0), Vector2(a.x * 0.5, 0), Color(0.85, 0.85, 0.85), Vector3.FORWARD)
		mb.add_quad(cloth, Vector3(a.x, 0, a.z + 0.02), a + Vector3(0, 0, 0.02), b2 + Vector3(0, 0, 0.02), Vector3(b2.x, 0, b2.z + 0.02), Vector2.ZERO, Vector2(0, 0.6), Vector2(0.6, 0.6), Vector2(0.6, 0), Color(0.5, 0.5, 0.5), Vector3.BACK)
	for s in [0, nx]:
		for j in range(nz / 2):
			var a: Vector3 = grid[s][j]
			var b2: Vector3 = grid[s][j + 1]
			var out := Vector3(-1.0 if s == 0 else 1.0, 0, 0)
			mb.add_quad(cloth, Vector3(a.x, 0, a.z), Vector3(b2.x, 0, b2.z), b2, a, Vector2(a.z * 0.5, a.y * 0.5), Vector2(b2.z * 0.5, b2.y * 0.5), Vector2(b2.z * 0.5, 0), Vector2(a.z * 0.5, 0), Color(0.85, 0.85, 0.85), out)
			mb.add_quad(cloth, Vector3(a.x, 0, a.z) - out * 0.02, a - out * 0.02, b2 - out * 0.02, Vector3(b2.x, 0, b2.z) - out * 0.02, Vector2.ZERO, Vector2(0, 0.6), Vector2(0.6, 0.6), Vector2(0.6, 0), Color(0.5, 0.5, 0.5), -out)
	# poles under the cloth, guy ropes from the front and side edges to stakes
	for i in range(0, nx + 1, 2):
		for j in [nz / 2, nz]:
			var p: Vector3 = grid[i][j]
			mb.add_cylinder(wood, _xf(Vector3(p.x, 0, p.z)), 0.05, 0.04, p.y, 5, 1.0)
			KitLandmarks.cyl_col(body, 0.08, p.y, Vector3(p.x, p.y * 0.5, p.z))
	var rope := PSXMat.lit("rope")
	for i in [0, nx]:
		for j in [0, nz / 2, nz]:
			var p: Vector3 = grid[i][j]
			var stake := Vector3(p.x + signf(p.x) * 1.4, 0.05, p.z + (0.9 if j == nz else 0.0))
			mb.add_tube(rope, PackedVector3Array([p, stake]), 0.015, 0.015, 3, 1.0)
			mb.add_cylinder(wood, _xf(stake + Vector3(0, -0.2, 0)), 0.04, 0.03, 0.35, 4, 1.0)
	DesertTown._box(body, Vector3(w, 1.2, 0.2), Vector3(0, 0.6, -d * 0.5))
	# inside: rugs, cushions, a brass tray
	var rug := PSXMat.lit("rug_kilim")
	mb.add_box(rug, _xf(Vector3(0, 0.02, 0.1), rng.randf_range(-0.1, 0.1)), Vector3(w * 0.7, 0.03, d * 0.6), 0.5, Color.WHITE, true, false)
	var cush := [PSXMat.lit("cloth_red"), PSXMat.lit("awning_gold", Color.WHITE, {"affine": 0.6})]
	for k in range(rng.randi_range(3, 5)):
		var q := Vector3(rng.randf_range(-w * 0.35, w * 0.35), 0.15, -d * 0.5 + rng.randf_range(0.4, 0.8))
		mb.add_blob(cush[k % 2], _xf(q, rng.randf() * TAU), Vector3(0.38, 0.16, 0.26), rng, 0.08, 3, 6, 1.0)
	mb.add_cylinder(DesertTown._brass(), _xf(Vector3(rng.randf_range(-0.5, 0.5), 0.05, 0.1)), 0.42, 0.45, 0.06, 10, 1.0, Color.WHITE, true, false)
	var mi := mb.to_instance("TentMesh")
	mi.visibility_range_end = 400.0
	body.add_child(mi)
	return body


## A well-sweep: a long pole pivoting on a crossbar between two mud pillars, a stone counterweight on its
## short end, a rope and a bucket hanging from its long end out over the water (+Z).
static func shaduf(seed_value: int) -> StaticBody3D:
	var rng := _rng(seed_value)
	var body := DesertTown._body("Shaduf")
	var mb := MeshBuilder.new()
	var adobe := PSXMat.lit("adobe")
	var wood := PSXMat.lit("planks_dark")
	for s in [-1.0, 1.0]:
		mb.add_box(adobe, _xf(Vector3(s * 0.5, 0.85, -0.3)), Vector3(0.35, 1.7, 0.35), 0.6, Color(0.62, 0.5, 0.38))
		DesertTown._box(body, Vector3(0.35, 1.7, 0.35), Vector3(s * 0.5, 0.85, -0.3))
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.6, 1.78, -0.3)), 0.06, 0.06, 1.2, 5, 1.0, Color.WHITE, true, true)
	var tilt := rng.randf_range(0.25, 0.45)
	var dir := Vector3(0, sin(tilt), cos(tilt))
	var pivot := Vector3(0, 1.86, -0.3)
	var tip := pivot + dir * 3.6
	var tail := pivot - dir * 1.5
	mb.add_tube(wood, PackedVector3Array([tail, pivot, tip]), 0.07, 0.05, 5, 1.0)
	mb.add_blob(PSXMat.lit("adobe"), _xf(tail + Vector3(0, -0.1, 0)), Vector3(0.32, 0.28, 0.32), rng, 0.15, 3, 6, 0.8, Color(0.5, 0.42, 0.34))
	var hang := tip + Vector3(0, -tip.y + 0.9, 0)
	mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([tip, hang]), 0.015, 0.015, 3, 1.0)
	mb.add_loft(PSXMat.lit("leather", Color(0.55, 0.38, 0.25)), _xf(hang + Vector3(0, -0.32, 0)), [[0.0, 0.1, 0.1], [0.15, 0.17, 0.17], [0.3, 0.16, 0.16]], MeshBuilder.profile_circle(7), 1.0, Color.WHITE, true)
	body.add_child(mb.to_instance("ShadufMesh"))
	return body
