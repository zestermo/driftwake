extends RefCounted
## The snow island's own places (SnowTheme's place hooks, through KitLandmarks like the chain's): standing in for
## the chain's totem grove a field of ruined ice-block towers with barred windows (the fields ref); for the great
## tree a buried town of stone houses and arches drowned in drifts, a strongbox in it (the buried-town ref); and,
## on most islands, a castle round the summit's lookout (curtain walls, round towers under green tiered roofs, a
## gate to the trail). Planned on the worker (KitWilds' spots, off the ice), built a step each in place-local
## coordinates (+Z the face).

const KINDS := {"totem_grove": "snow_ruins", "great_tree": "snow_buried"}
const RUIN_R := 20.0
const TOWN_R := 24.0
const CASTLE_R := 12.5
const CASTLE_CHANCE := 0.75
const VIS := 600.0
const LAND := preload("res://scripts/island/themes/snow_land.gd")


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


# ==========================================================================
# Planning (worker)
# ==========================================================================
## The castle on the summit, on most islands (its own stream: the island's seed).
static func plan_castle(isl, _avoid: Array) -> Array:
	var rng := _rng(hash([int(isl.node["seed"]), "snow castle"]))
	if rng.randf() >= CASTLE_CHANCE:
		return []
	var c: Vector2 = isl.sites["summit"]
	var face := Vector2(0, 1)
	for path in isl.paths:
		var pts: PackedVector2Array = path
		if pts[pts.size() - 1].distance_to(c) < 3.0:
			face = (pts[maxi(pts.size() - 6, 0)] - c).normalized()
	return [{"kind": "snow_castle", "at": c, "y": isl.hv(c), "face": face, "r": CASTLE_R + 3.0, "keep": [], "door": c + face * (CASTLE_R + 2.0)}]


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var r := RUIN_R if kind == "snow_ruins" else TOWN_R
	var pl := {}
	for k in range(4):
		pl = KitWilds._spot(isl, rng, avoid, r, 0.3, 4.0, 6.0, false)
		if pl.is_empty() or LAND._ice_at(isl.land_plan, pl["at"], r) < 0.01:
			break
		pl = {}
	if pl.is_empty():
		return {}
	KitLandmarks.level(isl, pl["at"], pl["y"], r * 0.45, r * 0.8)
	pl["keep"] = [[Vector2.ZERO, r * 0.85]]
	pl["kind"] = kind
	return pl


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"snow_ruins":
			return [func(): _ruins(ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"snow_buried":
			return [func(): _buried(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"snow_castle":
			return [func(): _castle(ctx, pl, KitLandmarks.place_node(ctx, pl))]
	push_error("SnowPlaces: no place %s" % pl["kind"])
	return []


# ==========================================================================
# Building (main thread)
# ==========================================================================
static func _mats() -> Dictionary:
	return {"ice": PSXMat.lit("ice_block", Color.WHITE, {"affine": 0.6}), "snow": PSXMat.lit("snow", Color.WHITE, {"affine": 0.5}),
		"stone": PSXMat.lit("stone_brick", Color(0.82, 0.84, 0.9), {"affine": 0.6}), "dark": PSXMat.flat(Color(0.06, 0.07, 0.09)),
		"iron": PSXMat.lit("metal", Color(0.22, 0.22, 0.25)), "roof": PSXMat.lit("roof_green", Color.WHITE, {"affine": 0.7})}


static func _box_col(body: StaticBody3D, size: Vector3, at: Vector3, yaw := 0.0) -> void:
	KitLandmarks.box_col_xf(body, size, Transform3D(Basis(Vector3.UP, yaw), at))


static func _finish(node: Node3D, body: StaticBody3D, mb: MeshBuilder) -> void:
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)


## Ruined towers of stacked ice-stone blocks, a barred window high in some, snow on every ledge, blocks tumbled off.
static func _ruins(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var m := _mats()
	var mb := MeshBuilder.new()
	var body := KitLandmarks.body("Towers")
	var spots: Array = []
	for k in range(rng.randi_range(3, 6)):
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, RUIN_R * 0.75)
		if spots.any(func(q): return at.distance_to(q) < 5.0):
			continue
		spots.append(at)
		var y := KitLandmarks.gy(ctx, pl, at.x, at.y) - 0.6
		var yaw := rng.randf() * TAU
		var w := rng.randf_range(2.8, 3.8)
		var n := rng.randi_range(3, 7)
		var b := Basis(Vector3.UP, yaw)
		var top := y
		for j in range(n):
			var bh := rng.randf_range(1.4, 2.0)
			var bw := w * rng.randf_range(0.85, 1.05) * (1.0 - j * 0.06)
			var off := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
			var xf := Transform3D(b * Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(at.x, top + bh * 0.5, at.y) + b * off)
			mb.add_box(m["ice"], xf, Vector3(bw, bh, bw * rng.randf_range(0.85, 1.0)), 0.5, Color.WHITE.darkened(rng.randf() * 0.12), false)
			if j == n - 2 and rng.randf() < 0.7:
				var face := xf * Transform3D(Basis(), Vector3(0, 0.1, bw * 0.5 + 0.01))
				mb.add_box(m["dark"], face, Vector3(0.8, 0.7, 0.04), 1.0)
				for q in range(4):
					mb.add_box(m["iron"], face * Transform3D(Basis(), Vector3(-0.3 + q * 0.2, 0, 0.04)), Vector3(0.05, 0.75, 0.05), 1.0)
			top += bh
		mb.add_blob(m["snow"], Transform3D(b, Vector3(at.x, top + 0.05, at.y)), Vector3(w * 0.5, 0.25, w * 0.45), rng, 0.15, 2, 6, 0.5, Color.WHITE, 0.0)
		mb.add_blob(m["snow"], Transform3D(b, Vector3(at.x, y + 0.6, at.y)), Vector3(w * 0.9, 0.6, w * 0.8), rng, 0.2, 2, 7, 0.5, Color.WHITE, 0.0)
		_box_col(body, Vector3(w, top - y, w), Vector3(at.x, (top + y) * 0.5, at.y), yaw)
		# a block tumbled off, half sunk in the snow
		var fall := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.5, 4.5)
		mb.add_box(m["ice"], Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.6)), Vector3(fall.x, KitLandmarks.gy(ctx, pl, fall.x, fall.y) + 0.2, fall.y)),
			Vector3(w * 0.8, 1.4, w * 0.7), 0.5, Color(0.9, 0.9, 0.92), false)
	_finish(node, body, mb)


## A buried town: stone houses with broken gables sunk to their sills in drifts, an arch or two, a strongbox.
static func _buried(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var m := _mats()
	var mb := MeshBuilder.new()
	var body := KitLandmarks.body("Buried")
	var houses: Array = []
	for k in range(rng.randi_range(4, 7)):
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3.0, TOWN_R * 0.8)
		if houses.any(func(h): return at.distance_to(h) < 7.5):
			continue
		houses.append(at)
		var yaw := rng.randf() * TAU
		var b := Basis(Vector3.UP, yaw)
		var w := rng.randf_range(4.0, 5.5)
		var d := rng.randf_range(4.0, 5.0)
		var h := rng.randf_range(3.2, 4.6)
		var g := KitLandmarks.gy(ctx, pl, at.x, at.y)
		var y := g - rng.randf_range(1.0, 2.2)
		var t := 0.4
		for s in [-1.0, 1.0]:
			mb.add_box(m["stone"], Transform3D(b, Vector3(at.x, y + h * 0.5, at.y) + b * Vector3(s * (w - t) * 0.5, 0, 0)), Vector3(t, h, d), 0.5, Color.WHITE, false)
			mb.add_box(m["stone"], Transform3D(b, Vector3(at.x, y + h * 0.5, at.y) + b * Vector3(0, 0, s * (d - t) * 0.5)), Vector3(w, h, t), 0.5, Color(0.92, 0.92, 0.94), false)
			mb.add_box(m["dark"], Transform3D(b, Vector3(at.x, y + h * 0.65, at.y) + b * Vector3(0, 0, s * (d * 0.5 + 0.01))), Vector3(0.7, 0.9, 0.05), 1.0)
			_box_col(body, Vector3(t, h, d), Vector3(at.x, y + h * 0.5, at.y) + b * Vector3(s * (w - t) * 0.5, 0, 0), yaw)
		# a broken gable on one end, the roof long gone
		var gable := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.15, h * 0.4), Vector2(-w * 0.05, h * 0.55), Vector2(-w * 0.3, h * 0.25)])
		mb.add_extrude(m["stone"], Transform3D(b, Vector3(at.x, y + h, at.y) + b * Vector3(0, 0, d * 0.5 - t)), gable, t, 0.5)
		# drifts banked to the sills
		mb.add_blob(m["snow"], Transform3D(b, Vector3(at.x, g - 0.1, at.y)), Vector3(w * 0.7, 0.9, d * 0.7), rng, 0.2, 2, 8, 0.5, Color.WHITE, 0.0)
		mb.add_blob(m["snow"], Transform3D(b, Vector3(at.x, y + h + 0.05, at.y) + b * Vector3(w * 0.5 - t * 0.5, 0, 0)), Vector3(t * 0.8, 0.15, d * 0.5), rng, 0.1, 2, 5, 0.5)
	# an arch standing on its own, half drowned
	for k in range(rng.randi_range(1, 2)):
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, TOWN_R * 0.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var y := KitLandmarks.gy(ctx, pl, at.x, at.y) - 0.8
		var arch := PackedVector2Array([Vector2(-2.2, 0), Vector2(-1.4, 0), Vector2(-1.4, 2.6), Vector2(-1.0, 3.3), Vector2(0, 3.6), Vector2(1.0, 3.3), Vector2(1.4, 2.6),
			Vector2(1.4, 0), Vector2(2.2, 0), Vector2(2.2, 3.4), Vector2(1.2, 4.3), Vector2(0, 4.5), Vector2(-1.2, 4.3), Vector2(-2.2, 3.4)])
		mb.add_extrude(m["stone"], Transform3D(b, Vector3(at.x, y, at.y)), arch, 0.8, 0.5)
		mb.add_blob(m["snow"], Transform3D(b, Vector3(at.x, y + 4.55, at.y)), Vector3(1.8, 0.2, 0.5), rng, 0.15, 2, 6, 0.5)
		for s in [-1.0, 1.0]:
			_box_col(body, Vector3(0.8, 4.0, 0.8), Vector3(at.x, y + 2.0, at.y) + b * Vector3(s * 1.8, 0, 0))
	_finish(node, body, mb)
	if not houses.is_empty():
		var hq := KitLandmarks.lp(pl, houses[0].x, houses[0].y)
		isl.strongbox(node, hq, rng.randf() * TAU, "snow_buried", KitLandmarks.loot(isl, rng, true), 1.2, 0.0)


## The castle round the summit's lookout: a ring of curtain wall with crenels, round towers under green tiered
## roofs with snow on each step, a gateway (+Z) where the trail comes up.
static func _castle(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var m := _mats()
	var mb := MeshBuilder.new()
	var body := KitLandmarks.body("Castle")
	var y0 := -1.5
	var gate := PI * 0.5
	var n := 7
	var wall_h := 5.5
	var thick := 1.2
	for k in range(n):
		var a0 := gate + TAU * (k + 0.5) / n
		var a1 := gate + TAU * (k + 1.5) / n
		var p0 := Vector2.from_angle(a0) * CASTLE_R
		var p1 := Vector2.from_angle(a1) * CASTLE_R
		var mid := (p0 + p1) * 0.5
		var L := p0.distance_to(p1)
		var yaw := atan2(p1.x - p0.x, p1.y - p0.y) + PI * 0.5
		var wall_xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, y0 + wall_h * 0.5, mid.y))
		# the stretch facing the trail is the gate: two piers, a lintel and the portcullis drawn up
		if k == n - 1:
			for s in [-1.0, 1.0]:
				var pier := wall_xf * Transform3D(Basis(), Vector3(s * (L * 0.5 - 1.1), 0, 0))
				mb.add_box(m["stone"], pier, Vector3(2.2, wall_h, thick + 0.4), 0.5, Color.WHITE, false)
				_box_col(body, Vector3(2.2, wall_h, thick + 0.4), pier.origin, yaw)
			mb.add_box(m["stone"], wall_xf * Transform3D(Basis(), Vector3(0, wall_h * 0.5 - 0.6, 0)), Vector3(L, 1.2, thick + 0.4), 0.5, Color(0.9, 0.9, 0.92), false)
			for q in range(int((L - 4.4) / 0.5)):
				mb.add_box(m["iron"], wall_xf * Transform3D(Basis(), Vector3(-(L - 4.4) * 0.5 + 0.25 + q * 0.5, wall_h * 0.5 - 1.2, 0)), Vector3(0.08, 0.9, 0.08), 1.0, Color.WHITE, false)
		else:
			mb.add_box(m["stone"], wall_xf, Vector3(L, wall_h, thick), 0.5, Color.WHITE, false)
			_box_col(body, Vector3(L, wall_h, thick), wall_xf.origin, yaw)
			for q in range(int(L / 1.4)):
				var cx := -L * 0.5 + 0.7 + q * 1.4
				mb.add_box(m["stone"], wall_xf * Transform3D(Basis(), Vector3(cx, wall_h * 0.5 + 0.35, 0)), Vector3(0.7, 0.7, thick), 0.5, Color(0.92, 0.92, 0.94), false)
				mb.add_box(m["snow"], wall_xf * Transform3D(Basis(), Vector3(cx, wall_h * 0.5 + 0.74, 0)), Vector3(0.72, 0.08, thick + 0.04), 0.5)
		# a round tower at each corner, its tiered roof
		var tp := Vector2.from_angle(a1) * CASTLE_R
		var tr := rng.randf_range(1.7, 2.2)
		var th := wall_h + rng.randf_range(2.5, 4.5)
		mb.add_cylinder(m["stone"], _xf(Vector3(tp.x, y0, tp.y)), tr, tr * 0.92, th, 10, 0.5, Color.WHITE, false, false, false)
		KitLandmarks.cyl_col(body, tr, th, Vector3(tp.x, y0 + th * 0.5, tp.y))
		var ry := y0 + th
		for t in range(3):
			var r0 := (tr + 0.5) * (1.0 - t * 0.28)
			mb.add_cylinder(m["roof"], _xf(Vector3(tp.x, ry, tp.y)), r0, r0 * 0.7, 1.0, 10, 0.7, Color.WHITE, false, t == 0, false)
			mb.add_cylinder(m["snow"], _xf(Vector3(tp.x, ry + 0.95, tp.y)), r0 * 0.72, r0 * 0.55, 0.12, 10, 0.6, Color.WHITE, false, false, false)
			ry += 1.0
		mb.add_cylinder(m["roof"], _xf(Vector3(tp.x, ry, tp.y)), (tr + 0.5) * 0.3, 0.0, 1.4, 8, 0.7)
		mb.add_box(m["dark"], Transform3D(Basis(Vector3.UP, PI * 0.5 - a1), Vector3(tp.x, y0 + th - 1.5, tp.y) + Vector3(cos(a1), 0, sin(a1)) * (tr - 0.05)), Vector3(0.4, 0.9, 0.12), 1.0)
	_finish(node, body, mb)
