class_name DesertPlaces
extends RefCounted
## The desert's own places (DesertTheme's place hooks): on each of the island's oases a pool in date
## palms and reeds with a camp on its bank; standing in for the chain's landmarks a caravan's camp (for
## the waterfall), an obelisk (the great tree) and the twin guardians (the totem grove). Planned on the
## worker, built a step each through KitLandmarks' helpers. The models (camel, long_tent, shaduf, obelisk,
## guardian) stand alone: front +Z, origin on the ground.

## The chain's kinds the desert stands its own in for.
const KINDS := {"waterfall": "caravan_camp", "great_tree": "obelisk", "totem_grove": "guardians"}
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
	var sand := PSXMat.lit("desert_sand")
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
	var sand := PSXMat.lit("desert_sand")
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
	var sand := PSXMat.lit("desert_sand")
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
	var carved := PSXMat.lit("plaster", Color(0.96, 0.84, 0.66), {"affine": 0.6})
	var dark := PSXMat.flat(Color(0.2, 0.14, 0.1))
	var paint := PSXMat.lit("sandstone", Color(0.55, 0.68, 0.95))
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
	var sand := PSXMat.lit("desert_sand")
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-1.6, 1.6), 0.2, 3.6)), Vector3(2.2, 1.0, 1.4), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	mb.add_blob(sand, _xf(Vector3(rng.randf_range(-1.0, 1.0), 0.2, -3.6)), Vector3(3.0, 2.2, 1.8), rng, 0.15, 3, 8, 0.25, Color.WHITE, 0.0)
	body.add_child(mb.to_instance("GuardianMesh"))
	return body


## The colossus's head on its neck's top at `xf`: the face, a striped headcloth with lappets down to the
## chest, a long plaited beard.
static func _head(mb: MeshBuilder, xf: Transform3D, stone: Material, dark: Material, rng: RandomNumberGenerator) -> void:
	var paint := PSXMat.lit("sandstone", Color(0.55, 0.68, 0.95))
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
