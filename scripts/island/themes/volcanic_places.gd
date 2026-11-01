extends RefCounted
## The volcanic isle's own places for the chain's (VolcanicTheme.place_kind / plan_place / place_steps): what the chain
## would make a waterfall or a great tree is an obsidian quarry; a cenote or a sunken village a smoking vent field.
##   quarry  a pit cut into the ground, its back wall black glass in stepped faces, cut blocks stacked on sledges, a
##           timber crane, the quarrymen's hut; slag-picker bandits working it (a GruntCamp), a strongbox by the hut
##   vents   a field of fumaroles crusted in sulphur, steam rising; every few seconds one vent hisses (its ground glows)
##           and bursts, burning whoever stands on it (volcanic_vents.gd); a chest in the middle for the brave

const KINDS := {"waterfall": "volcanic_quarry", "great_tree": "volcanic_quarry", "cenote": "volcanic_vents", "sunken_village": "volcanic_vents"}
const QUARRY_R := 16.0
const VENTS_R := 15.0
const VIS := 420.0
const Vents := preload("res://scripts/island/themes/volcanic_vents.gd")
const LAND := preload("res://scripts/island/themes/volcanic_land.gd")


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var r := QUARRY_R if kind == "volcanic_quarry" else VENTS_R
	var pl := {}
	for k in range(5):
		pl = KitWilds._spot(isl, rng, avoid, r, 0.3, 4.0, 6.0, false)
		if pl.is_empty():
			return {}
		var near: Array = LAND.flow_near(isl.land_plan, pl["at"])
		if float(near[0]) > float(isl.land_plan["flows"][int(near[1])]["w"]) + r and (pl["at"] as Vector2).distance_to(isl.land_plan["cone"]["c"]) > float(isl.land_plan["cone"]["rim"]) + r:
			break
		pl = {}
	if pl.is_empty():
		return {}
	KitLandmarks.level(isl, pl["at"], pl["y"], r * 0.5, r * 0.85)
	if kind == "volcanic_quarry":
		# the pit: its floor 2.5 m down behind the way in
		KitLandmarks.shape(isl, pl["at"], r * 0.7, func(h: float, d: float, _p: Vector2) -> float:
			return h - 2.5 * (1.0 - smoothstep(r * 0.4, r * 0.7, d)))
	pl["keep"] = [[Vector2.ZERO, r * 0.85]]
	pl["kind"] = kind
	return pl


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"volcanic_quarry":
			return [func(): _quarry(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _quarry_crew(isl, pl)]
		"volcanic_vents":
			return [func(): _vents(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
	push_error("VolcanicPlaces: no place %s" % pl["kind"])
	return []


## The quarry (place-local: +z its way in).
static func _quarry(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var glass := PSXMat.lit("metal", Color(0.16, 0.12, 0.2))
	var basalt := PSXMat.lit("volcanic_basalt", Color.WHITE, {"affine": 0.6})
	var wood := PSXMat.lit("planks_dark", Color(0.75, 0.7, 0.66))
	var rope := PSXMat.lit("rope", Color(0.7, 0.66, 0.6))
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Quarry"
	var y0 := float(pl["y"])
	var gy := func(x: float, z: float) -> float: return float(isl.hv(KitLandmarks.lp(pl, x, z))) - y0
	var put := func(m: Material, b: Basis, x: float, z: float, up: float, size: Vector3, col := true) -> void:
		var xf := Transform3D(b, Vector3(x, float(gy.call(x, z)) + up, z))
		mb.add_box(m, xf, size, 0.5, Color.WHITE.darkened(rng.randf() * 0.15))
		if col:
			KitLandmarks.box_col_xf(body, size, xf)
	# the back wall: stepped faces of black glass and basalt in a horseshoe round the pit's back
	var n := 9
	for k in range(n):
		var a := PI + 0.35 + (PI - 0.7) * k / (n - 1)
		var d := QUARRY_R * 0.62
		var x := cos(a) * d
		var z := sin(a) * d
		var b := Basis(Vector3.UP, -a + PI * 0.5)
		for step in range(3):
			var h := 2.2 + step * 1.6 + rng.randf_range(-0.3, 0.4)
			var out := float(step) * 1.4
			put.call(glass if (k + step) % 3 == 0 else basalt, b, x + cos(a) * out, z + sin(a) * out, h * 0.5 - 0.4, Vector3(4.2, h, 1.6))
	# cut blocks on sledges, a timber crane over the pit, chips of glass everywhere
	for k in range(4):
		var x := rng.randf_range(-5.0, 5.0)
		var z := rng.randf_range(-2.0, 4.0)
		var yaw := rng.randf() * TAU
		put.call(wood, Basis(Vector3.UP, yaw), x, z, 0.12, Vector3(1.6, 0.18, 2.4))
		put.call(glass if k % 2 == 0 else basalt, Basis(Vector3.UP, yaw), x, z, 0.75, Vector3(1.3, 1.1, 1.6))
	for k in range(40):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, QUARRY_R * 0.6)
		var s := rng.randf_range(0.1, 0.3)
		mb.add_cylinder(glass, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.6, 1.5)), Vector3(q.x, gy.call(q.x, q.y), q.y)), s, 0.0, s * 3.0, 3, 1.0)
	var cx := -6.0
	var cz := -3.0
	put.call(wood, Basis(), cx, cz, 3.0, Vector3(0.35, 6.0, 0.35))
	var top := Vector3(cx, float(gy.call(cx, cz)) + 5.8, cz)
	mb.add_tube(wood, PackedVector3Array([top, top + Vector3(4.5, 0.8, 1.0)]), 0.16, 0.12, 5, 0.6)
	mb.add_tube(rope, PackedVector3Array([top + Vector3(4.5, 0.8, 1.0), top + Vector3(4.5, -3.5, 1.0)]), 0.03, 0.03, 3, 1.0)
	mb.add_box(glass, Transform3D(Basis(), top + Vector3(4.5, -4.1, 1.0)), Vector3(0.9, 0.9, 0.9))
	for s in [-1.0, 1.0]:
		mb.add_tube(wood, PackedVector3Array([top + Vector3(0, -1.0, 0), Vector3(cx + s * 1.6, float(gy.call(cx + s * 1.6, cz + 1.2)), cz + 1.2)]), 0.1, 0.1, 4, 0.6)
	# the quarrymen's hut by the way in
	var hx := 7.5
	var hz := 6.0
	put.call(wood, Basis(Vector3.UP, 0.4), hx, hz, 1.2, Vector3(3.2, 2.4, 2.6))
	mb.add_gable_roof(PSXMat.lit("volcanic_slate"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(hx, float(gy.call(hx, hz)) + 2.4, hz)), 3.8, 3.2, 1.0)
	var mi := mb.to_instance("Quarry")
	mi.visibility_range_end = VIS
	node.add_child(mi)
	node.add_child(body)
	KitLandmarks.chest(ctx, pl, Vector3(hx - 2.4, float(gy.call(hx - 2.4, hz - 0.5)), hz - 0.5), 0.4, "quarry_chest", KitLandmarks.loot(isl, rng, true), 0.9)


## Slag-picker bandits working the quarry (host-run, a GruntCamp like any crew).
static func _quarry_crew(isl, pl: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 3
	var crew := GruntCamp.new()
	crew.name = "QuarryCrew"
	crew.respawn_time = 600.0
	crew.respawn_clearance = 70.0
	crew.level = IslandContent.level(isl)
	var c: Vector2 = pl["at"]
	for i in range(3):
		var a := TAU * i / 3.0 + rng.randf_range(-0.4, 0.4)
		var q := c + Vector2.from_angle(a) * rng.randf_range(3.0, 6.0)
		var route := []
		for j in range(4):
			var rq := c + Vector2.from_angle(a + TAU * j / 4.0) * rng.randf_range(4.0, 8.0)
			route.append(Vector3(rq.x, isl.hv(rq), rq.y))
		crew.add_grunt({"post": Vector3(q.x, isl.hv(q), q.y), "yaw": a + PI, "mode": "patrol", "patrol": route, "seed": int(isl.node["seed"]) % 100000 + 700 + i})
	isl.add_child(crew)
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker") if isl.get_parent() else null
	if baker:
		var zone := Node3D.new()
		zone.name = "QuarryZone"
		isl.add_child(zone)
		zone.position = Vector3(c.x, isl.hv(c), c.y)
		baker.add_zone(zone, 22.0, false, isl.terrain_faces)


## The vent field (place-local).
static func _vents(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var y0 := float(pl["y"])
	var gy := func(x: float, z: float) -> float: return float(isl.hv(KitLandmarks.lp(pl, x, z))) - y0
	var crust := PSXMat.lit("volcanic_ash", Color(1.5, 1.3, 0.6), {"affine": 0.6})
	var sulphur := PSXMat.flat(Color(0.92, 0.8, 0.25))
	var dark := PSXMat.flat(Color(0.06, 0.05, 0.05))
	var hot := PSXMat.glow(Color(1.0, 0.5, 0.15), 1.6)
	var mb := MeshBuilder.new()
	var spots: Array = []
	for k in range(9):
		var q := Vector2.from_angle(TAU * k / 9.0 + rng.randf_range(-0.3, 0.3)) * rng.randf_range(3.0, VENTS_R * 0.75)
		if spots.any(func(o): return (o as Vector2).distance_to(q) < 3.2):
			continue
		spots.append(q)
		var y: float = gy.call(q.x, q.y)
		var r := rng.randf_range(0.8, 1.3)
		mb.add_blob(crust, Transform3D(Basis(), Vector3(q.x, y + 0.05, q.y)), Vector3(r * 1.8, 0.3, r * 1.7), rng, 0.25, 2, 8)
		mb.add_blob(sulphur, Transform3D(Basis(), Vector3(q.x, y + 0.25, q.y)), Vector3(r * 0.9, 0.2, r * 0.9), rng, 0.3, 2, 7)
		mb.add_cylinder(dark, Transform3D(Basis(), Vector3(q.x, y + 0.36, q.y)), r * 0.35, r * 0.3, 0.1, 6)
		mb.add_cylinder(hot, Transform3D(Basis(), Vector3(q.x, y + 0.3, q.y)), r * 0.28, r * 0.28, 0.08, 6)
	for k in range(14):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, VENTS_R * 0.85)
		mb.add_blob(sulphur, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, gy.call(q.x, q.y) + 0.02, q.y)), Vector3(rng.randf_range(0.4, 1.0), 0.05, rng.randf_range(0.3, 0.8)), rng, 0.3, 2, 6)
	var mi := mb.to_instance("Vents")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VIS
	node.add_child(mi)
	for k in range(mini(3, spots.size())):
		var q: Vector2 = spots[k]
		var steam := KitLandmarks.puffs(node, Vector3(q.x, float(gy.call(q.x, q.y)) + 0.4, q.y), Color(0.9, 0.9, 0.86, 0.45), 8, 1.4, 1.4, 0.3)
		steam.visibility_range_end = 200.0
	var v := Vents.new()
	v.name = "VentBursts"
	v.isl = isl
	v.spots = spots.map(func(q): return KitLandmarks.lp(pl, q.x, q.y))
	v.seed_value = int(pl["seed"])
	node.add_child(v)
	KitLandmarks.chest(ctx, pl, Vector3(0, float(gy.call(0.0, 0.0)), 0), rng.randf() * TAU, "vent_chest", KitLandmarks.loot(isl, rng, true), 0.9)
