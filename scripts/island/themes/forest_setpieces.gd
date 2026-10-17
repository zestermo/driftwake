class_name ForestSetPieces
extends RefCounted
## The forest's set pieces (ForestPlaces through the theme place hooks; nothing guaranteed: the chain gives each island
## its set piece and landmarks):
##   forest_gorge       the waterfall gorge (for the chain's cenote or sunken village): the big falls a river drops over
##                      (forest_land.gd forces one on the first river), the pool at their foot, a cave in the gorge wall
##                      beside the curtain with its hoard and its keepers, rope bridges across the gorge downstream
##   forest_castle      a ruined castle in the woods (for the volcano vent or the old fort): a broken curtain wall of
##                      mossy stone round a courtyard, round towers, the gatehouse, a roofless keep you climb inside to its
##                      parapet and its chest, and the outlaws camped in the courtyard
##   forest_hollow_tree the hollow giant tree (for the chain's great tree): an oak 30 m tall, its trunk hollow, a doorway
##                      between its roots, bracket fungus spiralling up its side to a perch in its fork; through the back
##                      of the hollow a cavern among its roots (three chambers in a mound of earth and roots) with what
##                      lives there and the hoard in the end chamber
## Plans are numbers (the worker; a cave's rock is meshed there too, CaveMesher); steps build under the place's node
## in place-local coordinates (+Z its face).

const LAND := preload("res://scripts/island/themes/forest_land.gd")
const VIS := 600.0
const CASTLE_R := 21.0
const TREE_R := 5.6
const TREE_Z := 3.0


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _gy(ctx: KitContext, pl: Dictionary, x: float, z: float) -> float:
	return KitLandmarks.gy(ctx, pl, x, z)


static func _at(ctx: KitContext, pl: Dictionary, x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, _gy(ctx, pl, x, z) + up, z)


## Island point of place-local (x, z) for a place at `at` facing `face`, before its yaw is set.
static func _isl(at: Vector2, face: Vector2, x: float, z: float) -> Vector2:
	var v := Basis(Vector3.UP, KitContext.face_yaw(face)) * Vector3(x, 0.0, z)
	return at + Vector2(v.x, v.z)


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	match kind:
		"forest_gorge":
			return _plan_gorge(isl, rng, avoid)
		"forest_castle":
			return _plan_castle(isl, rng, avoid)
		"forest_hollow_tree":
			return _plan_tree(isl, rng, avoid)
	push_error("ForestSetPieces: no place %s" % kind)
	return {}


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"forest_gorge":
			return [func(): _gorge(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _gorge_cave(isl, ctx, pl)]
		"forest_castle":
			return [func(): _castle_walls(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _castle_keep(isl, ctx, pl), func(): _castle_camp(isl, ctx, pl)]
		"forest_hollow_tree":
			return [func(): _tree(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _tree_cavern(isl, ctx, pl)]
	push_error("ForestSetPieces: no place %s" % pl["kind"])
	return []


## Rock from a CaveMesher mesh (its plan's "cave"): the outside's rock, moss and turf, the inside's walls and floor, one
## trimesh collider, a body under `node` (KitDungeons' surfaces with the forest's cave look).
static func _cave_body(isl, node: Node3D, cave: Dictionary, body_name: String) -> StaticBody3D:
	var look: Dictionary = (KitDungeons.LOOK["root_cavern"] as Dictionary).merged(KitStyle.of(isl.theme)["cave_look"], true)
	var body := KitLandmarks.body(body_name)
	var outside := MeshInstance3D.new()
	outside.name = "Outside"
	outside.mesh = KitDungeons._surfaces(cave["surfaces"], ["rock", "moss", "turf"], look)
	outside.visibility_range_end = VIS
	body.add_child(outside)
	var inside := MeshInstance3D.new()
	inside.name = "Inside"
	inside.mesh = KitDungeons._surfaces(cave["surfaces"], ["wall", "floor"], look)
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside.visibility_range_end = 120.0
	body.add_child(inside)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(cave["faces"])
	cs.shape = shape
	body.add_child(cs)
	node.add_child(body)
	return body


## Glowing bracket fungus on rock or bark: a cluster of shelves at `at`, out along `out`.
static func _fungus(mb: MeshBuilder, at: Vector3, out: Vector3, rng: RandomNumberGenerator, glow: Material) -> void:
	var yaw := atan2(out.x, out.z)
	for k in range(rng.randi_range(2, 4)):
		var p := at + Vector3(0, k * 0.22 + rng.randf_range(-0.05, 0.05), 0) + out * 0.08
		mb.add_cylinder(glow, Transform3D(Basis(Vector3.UP, yaw), p), rng.randf_range(0.12, 0.24), rng.randf_range(0.08, 0.14), 0.05, 6, 1.0)


# ==========================================================================
# The waterfall gorge
# ==========================================================================
static func _plan_gorge(isl, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var L: Dictionary = isl.land_plan
	var best := {}
	var bd := -INF
	for fl in LAND.falls_of(L):
		var foot: Vector2 = fl["foot"]
		var near_site: bool = isl.sites.values().any(func(q): return (q as Vector2).distance_to(foot) < 45.0)
		var score: float = float(fl["drop"]) - (100.0 if near_site else 0.0) - (50.0 if not KitLandmarks.clear_of(isl, foot, 10.0, avoid) else 0.0)
		if score > bd:
			bd = score
			best = fl
	if best.is_empty():
		return {}
	var foot: Vector2 = best["foot"]
	var dir: Vector2 = best["dir"]
	var w: float = best["w"]
	var face := -dir
	var side := Vector2(-dir.y, dir.x)
	var y: float = best["y"]
	# the cave: in the gorge's wall beside the curtain, its floor a little over the pool
	var cs := 1.0 if rng.randf() < 0.5 else -1.0
	var cave_c := foot - dir * (w + 1.5) + side * cs * (w + 4.5)
	KitLandmarks.shape(isl, cave_c, 5.5, func(h: float, d: float, _p: Vector2) -> float:
		return minf(h, lerpf(y + 0.3, h, GenIsland._smooth(3.6, 5.5, d))))
	KitLandmarks.shape(isl, foot.lerp(cave_c, 0.6), 3.0, func(h: float, d: float, _p: Vector2) -> float:
		return minf(h, lerpf(y + 0.35, h, GenIsland._smooth(1.8, 3.0, d))))
	var lc := KitLandmarks.local_of(foot, face, cave_c)
	var rooms := [[lc.x, lc.y, 0.3, 3.4, 3.2]]
	var mouth := KitLandmarks.local_of(foot, face, foot.lerp(cave_c, 0.45))
	var segs := [[mouth.x, mouth.y, 0.3, lc.x, lc.y, 0.3, 1.3, 2.6, 0.0]]
	var cave := CaveMesher.make(rooms, segs, rng.randi()).mesh(1.5, -3.0)
	# rope bridges across the gorge downstream, rim to rim
	var bridges: Array = []
	for rv in [L["rivers"][int(best["river"])]]:
		var pts: PackedVector2Array = rv["pts"]
		var f: int = best["k"]
		for k in [f + 1, f + 3, f + 5]:
			if k >= pts.size() - 1:
				continue
			var along := (pts[k + 1] - pts[k - 1]).normalized()
			var sd := Vector2(-along.y, along.x)
			var sf: float = rv["surf"][k]
			var ends: Array = []
			for s in [-1.0, 1.0]:
				var q := pts[k]
				var found := false
				for j in range(2, 20):
					q = pts[k] + sd * s * (w + j)
					if float(isl.hv(q)) > sf + minf(float(best["drop"]) * 0.5, 4.0):
						found = true
						break
				if found:
					ends.append(q + sd * s * 1.2)
			if ends.size() == 2 and (ends[0] as Vector2).distance_to(ends[1]) < 34.0 and not bridges.any(func(b): return (b[0] as Vector2).distance_to(ends[0]) < 8.0):
				bridges.append(ends)
	var keep: Array = [[Vector2.ZERO, w + 3.0], [lc, 4.5]]
	for b in bridges:
		for e in b:
			keep.append([KitLandmarks.local_of(foot, face, e), 2.5])
	var door: Vector2 = bridges[0][0] if not bridges.is_empty() else foot + face * (w + 8.0) + side * (w + 6.0)
	return {"kind": "forest_gorge", "at": foot, "y": y, "face": face, "r": 26.0, "keep": keep, "door": door,
		"falls": best, "cave": cave, "cave_c": lc, "mouth": mouth, "bridges": bridges}


## The gorge: mist rising off the pool, ferns and moss on the walls, the rope bridges rim to rim.
static func _gorge(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var fl: Dictionary = pl["falls"]
	KitLandmarks.puffs(node, Vector3(0, 0.6, float(fl["w"]) + 1.0), Color(0.92, 0.96, 1.0, 0.3), 14, 2.4, 0.9, 2.0)
	var body := KitLandmarks.body("GorgeBridges")
	var mb := MeshBuilder.new()
	var planks := PSXMat.lit("planks_weathered", Color(0.9, 0.84, 0.76))
	var rope := PSXMat.lit("rope")
	for b in pl["bridges"]:
		var a2 := KitLandmarks.local_of(pl["at"], pl["face"], b[0])
		var e2 := KitLandmarks.local_of(pl["at"], pl["face"], b[1])
		var a := _at(ctx, pl, a2.x, a2.y, 0.15)
		var e := _at(ctx, pl, e2.x, e2.y, 0.15)
		KitLandmarks.bridge(mb, body, planks, rope, a, e, a.distance_to(e) * 0.06)
		var post := PSXMat.lit("planks_dark")
		var side := (e - a).normalized().cross(Vector3.UP).normalized()
		for q in [a, e]:
			for s in [-1.0, 1.0]:
				mb.add_cylinder(post, Transform3D(Basis(), q + side * s * 0.75 + Vector3.DOWN * 0.4), 0.1, 0.09, 1.9, 5, 1.0)
	# ferns and moss down the walls, where they're steep
	var fern := PSXMat.cutout("bracken", Color.WHITE, 0.05, 1.0)
	var moss := PSXMat.lit("leaves_late", Color(0.62, 0.8, 0.5), {"affine": 0.5})
	for k in range(30):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, float(pl["r"]) * 0.8)
		var g := _gy(ctx, pl, q.x, q.y)
		var slope := absf(_gy(ctx, pl, q.x + 1.0, q.y) - g) + absf(_gy(ctx, pl, q.x, q.y + 1.0) - g)
		if slope < 0.8 or g < 0.5:
			continue
		if rng.randf() < 0.5:
			mb.add_cross_cards(fern, Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3(q.x, g - 0.1, q.y)), 1.3, 0.9, 2)
		else:
			mb.add_blob(moss, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, g, q.y)), Vector3(0.9, 0.25, 0.7), rng, 0.25, 2, 5, 0.6)
	if not mb.is_empty():
		var mi := mb.to_instance("Gorge")
		mi.visibility_range_end = VIS
		body.add_child(mi)
	node.add_child(body)
	KitLandmarks.loop_sound(node, "hull_rush_loop.wav", Vector3(0, 2.0, float(fl["w"]) + 1.0), 12.0, 90.0, 0.0, 0.6)


## The cave beside the falls: its rock, glowing fungus, the hoard, and what guards it.
static func _gorge_cave(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 1)
	var node := KitLandmarks.node_of(ctx, pl)
	var holder := Node3D.new()
	holder.name = "GorgeCave"
	node.add_child(holder)
	_cave_body(isl, holder, pl["cave"], "CaveRock")
	var c: Vector2 = pl["cave_c"]
	var glow := PSXMat.glow(Color(0.5, 1.0, 0.7), 1.1)
	var mb := MeshBuilder.new()
	for k in range(6):
		var a := rng.randf() * TAU
		_fungus(mb, Vector3(c.x + cos(a) * 3.0, 0.6 + rng.randf() * 1.6, c.y + sin(a) * 3.0), -Vector3(cos(a), 0, sin(a)), rng, glow)
	holder.add_child(KitLandmarks.far_off(mb.to_instance("Fungus"), 120.0))
	KitLights.light(ctx, holder, Vector3(c.x, 2.2, c.y), 1.0, 7.0)
	var back := (c - (pl["mouth"] as Vector2)).normalized()
	var chest_at := c + back * 1.6
	KitLandmarks.chest(ctx, pl, Vector3(chest_at.x, 0.3, chest_at.y), atan2(-back.x, -back.y), "gorge_cave_hoard", KitLandmarks.loot(isl, rng, true), 0.95)
	var fauna = FaunaSpawner.of(isl)
	if fauna:
		fauna.fill_slots(holder, [[Vector3(c.x - back.y * 1.5, 0.3, c.y + back.x * 1.5), "floor"], [Vector3(c.x + back.y * 1.5, 0.3, c.y - back.x * 1.5), "floor"]], 71)


# ==========================================================================
# The ruined castle
# ==========================================================================
static func _plan_castle(isl, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var pl := KitSetPieces._plan_inland(isl, rng, avoid, CASTLE_R + 6.0, 0.2, 5.0, 10.0, true)
	if pl.is_empty():
		return {}
	KitLandmarks.level(isl, pl["at"], pl["y"], CASTLE_R + 2.0, CASTLE_R + 8.0)
	pl["kind"] = "forest_castle"
	pl["keep"] = [[Vector2.ZERO, CASTLE_R + 2.5]]
	pl["door"] = (pl["at"] as Vector2) + (pl["face"] as Vector2) * (CASTLE_R + 5.0)
	# which of the eight stretches of wall are breached (never the gate's), how tall each tower stands
	var breach: Array = []
	for k in range(8):
		breach.append(k != 0 and rng.randf() < 0.3)
	var towers: Array = []
	for k in range(8):
		towers.append(rng.randf_range(8.0, 11.5) if rng.randf() < 0.75 else rng.randf_range(4.0, 6.0))
	pl["breach"] = breach
	pl["towers"] = towers
	return pl


## A stretch of crenellated wall from a to b (place-local, on the ground), its merlons and its colliders.
static func _wall(mb: MeshBuilder, body: StaticBody3D, stone: Material, a: Vector3, b: Vector3, h: float, t: float, rng: RandomNumberGenerator, broken := false) -> void:
	var d := b - a
	d.y = 0.0
	var L := d.length()
	var yaw := atan2(d.x, d.z)
	var bs := Basis(Vector3.UP, yaw)
	var n := maxi(int(L / 3.0), 1)
	for k in range(n):
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p := a.lerp(b, (t0 + t1) * 0.5)
		var hh := h * (rng.randf_range(0.25, 0.6) if broken else 1.0)
		var base := minf(a.lerp(b, t0).y, a.lerp(b, t1).y) - 1.0
		var top := p.y + hh
		var xf := Transform3D(bs, Vector3(p.x, (base + top) * 0.5, p.z))
		var size := Vector3(t, top - base, L / n + 0.05)
		mb.add_box(stone, xf, size, 0.5, Color.WHITE.darkened(rng.randf() * 0.12))
		KitLandmarks.box_col_xf(body, size, xf)
		if not broken:
			for m in range(2):
				var mp := a.lerp(b, t0 + (t1 - t0) * (0.25 + 0.5 * m))
				mb.add_box(stone, Transform3D(bs, Vector3(mp.x, top + 0.4, mp.z)), Vector3(t, 0.8, (L / n) * 0.3), 0.5, Color.WHITE.darkened(rng.randf() * 0.1))
		else:
			for j in range(3):
				var rp := p + bs * Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-1.0, 1.0))
				var s := rng.randf_range(0.4, 0.9)
				mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)), Vector3(rp.x, rp.y + s * 0.3, rp.z)), Vector3(s * 1.4, s, s), 0.5)


## The curtain wall: eight stretches round the courtyard (some breached), a round tower at every other corner, the
## gatehouse arch at +Z toward the trail, ivy down the stones.
static func _castle_walls(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var stone := PSXMat.lit("moss_stone", ctx.style["fort_stone"], {"affine": 0.6})
	var ivy := PSXMat.lit("leaves_late", Color(0.55, 0.72, 0.4), {"affine": 0.5})
	var red_ivy := PSXMat.lit("leaves_maple", Color(0.9, 0.85, 0.8), {"affine": 0.5})
	var body := KitLandmarks.body("CastleWalls")
	var mb := MeshBuilder.new()
	var R := CASTLE_R
	var corners: Array = []
	for k in range(8):
		var a := PI * 0.5 + TAU * (k - 0.5) / 8.0
		corners.append(Vector2(cos(a), sin(a)) * R)
	var breach: Array = pl["breach"]
	for k in range(8):
		var c0: Vector2 = corners[k]
		var c1: Vector2 = corners[(k + 1) % 8]
		var a := _at(ctx, pl, c0.x, c0.y)
		var b := _at(ctx, pl, c1.x, c1.y)
		if k == 0:
			# the gatehouse: wall either side of an arch, a lintel over it, the portcullis long gone
			var gate := (a + b) * 0.5
			var gd := (b - a).normalized()
			_wall(mb, body, stone, a, gate - gd * 2.0, 6.5, 1.8, rng)
			_wall(mb, body, stone, gate + gd * 2.0, b, 6.5, 1.8, rng)
			var bs := Basis(Vector3.UP, atan2(gd.x, gd.z))
			for s in [-1.0, 1.0]:
				var pp: Vector3 = gate + gd * s * 2.6
				mb.add_box(stone, Transform3D(bs, pp + Vector3.UP * 4.2), Vector3(3.0, 9.4, 1.4), 0.5)
				KitLandmarks.box_col_xf(body, Vector3(3.0, 9.4, 1.4), Transform3D(bs, pp + Vector3.UP * 4.2))
			mb.add_box(stone, Transform3D(bs, gate + Vector3.UP * 6.8), Vector3(2.4, 2.4, 4.0), 0.5)
			KitLandmarks.box_col_xf(body, Vector3(2.4, 2.4, 4.0), Transform3D(bs, gate + Vector3.UP * 6.8))
			var arch := PackedVector3Array()
			for j in range(7):
				var t := PI * j / 6.0
				arch.append(gate + gd * cos(t) * 2.0 + Vector3.UP * (4.4 + sin(t) * 1.2))
			mb.add_tube(stone, arch, 0.35, 0.35, 5, 0.5)
		else:
			_wall(mb, body, stone, a, b, 6.0 if k % 2 == 0 else 5.4, 1.6, rng, breach[k])
	# round towers on every other corner
	var towers: Array = pl["towers"]
	for k in range(0, 8, 2):
		var c: Vector2 = corners[k] * 1.03
		var g := _gy(ctx, pl, c.x, c.y)
		var h: float = towers[k]
		mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(c.x, g - 1.0, c.y)), 3.0, 2.7, h + 1.0, 10, 0.5, Color.WHITE.darkened(rng.randf() * 0.1), false)
		# a broken crown of merlons on the tall ones
		if h > 7.0:
			for j in range(10):
				if rng.randf() < 0.65:
					var a := TAU * j / 10.0
					mb.add_box(stone, Transform3D(Basis(Vector3.UP, -a), Vector3(c.x + cos(a) * 2.5, g + h + 0.4, c.y + sin(a) * 2.5)), Vector3(0.6, 0.8 + rng.randf() * 0.4, 0.9), 0.5)
		KitLandmarks.cyl_col(body, 2.9, h + 1.0, Vector3(c.x, g + (h - 1.0) * 0.5, c.y))
		for j in range(2):
			var a := rng.randf() * TAU
			var top := Vector3(c.x + cos(a) * 3.0, g + h * rng.randf_range(0.6, 0.95), c.y + sin(a) * 3.0)
			mb.add_blob(ivy if j == 0 else red_ivy, Transform3D(Basis(Vector3.UP, -a), top - Vector3.UP * h * 0.3), Vector3(0.9, h * 0.32, 0.4), rng, 0.25, 3, 5, 0.6)
	# ivy and moss down the walls
	for k in range(12):
		var a := rng.randf() * TAU
		var q := Vector2(cos(a), sin(a)) * (R - 0.95)
		var g := _gy(ctx, pl, q.x, q.y)
		mb.add_blob(ivy if k % 3 else red_ivy, Transform3D(Basis(Vector3.UP, -a), Vector3(q.x, g + 3.0, q.y)), Vector3(1.4, 2.6, 0.35), rng, 0.3, 3, 5, 0.6)
	var mi := mb.to_instance("CastleWallsMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)


## The keep: a roofless square tower at the back of the courtyard, its doorway toward the gate, a stair of stone
## steps up round its inside walls to a timber floor under the broken parapet, the chest up there, arrow slits.
static func _castle_keep(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 2)
	var node := KitLandmarks.node_of(ctx, pl)
	var stone := PSXMat.lit("moss_stone", ctx.style["fort_stone"], {"affine": 0.6})
	var wood := PSXMat.lit("planks_weathered", Color(0.85, 0.8, 0.72))
	var body := KitLandmarks.body("Keep")
	var mb := MeshBuilder.new()
	var kc := Vector3(0, _gy(ctx, pl, 0.0, -8.0), -8.0)
	var hs := 4.6
	var t := 1.0
	var h := 12.0
	var fy := 8.4
	# four walls, the front's with a doorway
	for side in [[Vector3(0, 0, hs), 0.0], [Vector3(0, 0, -hs), 0.0], [Vector3(hs, 0, 0), PI * 0.5], [Vector3(-hs, 0, 0), PI * 0.5]]:
		var o: Vector3 = kc + (side[0] as Vector3)
		var bs := Basis(Vector3.UP, float(side[1]))
		var full := Vector3(hs * 2.0 + t, h + 1.0, t)
		if (side[0] as Vector3).z > 0.0:
			for s in [-1.0, 1.0]:
				var seg := Vector3((hs * 2.0 + t - 2.0) * 0.5, h + 1.0, t)
				var xf := Transform3D(bs, o + Vector3(s * (1.0 + seg.x * 0.5), (h + 1.0) * 0.5 - 1.0, 0))
				mb.add_box(stone, xf, seg, 0.5)
				KitLandmarks.box_col_xf(body, seg, xf)
			var lx := Transform3D(bs, o + Vector3(0, 3.6 + (h - 3.6) * 0.5, 0))
			mb.add_box(stone, lx, Vector3(2.0, h - 3.6, t), 0.5)
			KitLandmarks.box_col_xf(body, Vector3(2.0, h - 3.6, t), lx)
		else:
			var xf := Transform3D(bs, o + Vector3(0, (h + 1.0) * 0.5 - 1.0, 0))
			mb.add_box(stone, xf, full, 0.5)
			KitLandmarks.box_col_xf(body, full, xf)
		# the broken parapet
		for j in range(5):
			if rng.randf() < 0.7:
				mb.add_box(stone, Transform3D(bs, o + bs * Vector3(-hs + 0.9 + j * 1.9, h + 0.5, 0)), Vector3(0.9, 1.0 + rng.randf() * 0.6, t), 0.5)
		# arrow slits
		for y in [3.5, 7.0, 10.5]:
			mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.05)), Transform3D(bs, o + Vector3(0, y, 0) + bs * Vector3(rng.randf_range(-1.5, 1.5), 0, 0) + (side[0] as Vector3).normalized() * 0.52), Vector3(0.18, 0.9, 0.04), 1.0)
	# the stair: blocks up round the inside walls, back, left, front, to the upper floor
	var inner := hs - t * 0.5 - 0.7
	var n := 22
	for k in range(n):
		var y := (k + 1) * fy / n
		var u := float(k) / n
		var q: Vector3
		if u < 0.33:
			q = Vector3(lerpf(inner, -inner, u / 0.33), y, -inner)
		elif u < 0.66:
			q = Vector3(-inner, y, lerpf(-inner, inner * 0.2, (u - 0.33) / 0.33))
		else:
			q = Vector3(lerpf(-inner, -inner * 0.1, (u - 0.66) / 0.34), y, inner * 0.2)
		var xf := Transform3D(Basis(), kc + q - Vector3(0, y * 0.5, 0))
		mb.add_box(stone, Transform3D(Basis(), kc + q + Vector3(0, -0.2, 0)), Vector3(1.3, 0.4, 1.3), 0.5, Color(0.9, 0.9, 0.9))
		KitLandmarks.box_col(body, Vector3(1.3, 0.4, 1.3), kc + q + Vector3(0, -0.2, 0))
		xf = xf
	# the upper floor: half the keep in planks (a hole where the stair comes up), beams across
	var floor_xf := Transform3D(Basis(), kc + Vector3(inner * 0.35, fy, -inner * 0.1))
	mb.add_box(wood, floor_xf, Vector3(inner * 1.3 + 1.2, 0.2, inner * 2.0 + 1.0), 0.6)
	KitLandmarks.box_col_xf(body, Vector3(inner * 1.3 + 1.2, 0.2, inner * 2.0 + 1.0), floor_xf)
	for z in [-inner, 0.0, inner]:
		mb.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), kc + Vector3(0, fy - 0.25, z)), Vector3(hs * 2.0, 0.25, 0.3), 0.6)
	var mi := mb.to_instance("KeepMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)
	KitLights.light(ctx, node, kc + Vector3(0, 2.5, 0), 1.2, 10.0)
	KitLandmarks.chest(ctx, pl, kc + Vector3(inner * 0.6, fy + 0.1, -inner * 0.4), PI, "castle_keep_chest", KitLandmarks.loot(isl, rng, true), 1.0)


## The outlaws camped in the courtyard: a fire, two tents against the wall, crates, and a crew - two at the fire, one
## walking the walls' foot, one at the gate, one at the keep's door - who hold the castle (their own nav zone).
static func _castle_camp(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 3)
	var node := KitLandmarks.node_of(ctx, pl)
	var c := ctx.under(node)
	var st: Dictionary = ctx.style
	var fire_p := KitLandmarks.lp(pl, 2.0, 4.0)
	KitCamps.campfire(c, fire_p, 1.0)
	for e in [[Vector2(-10.0, 4.0), 0.9], [Vector2(-7.5, 10.0), 1.6], [Vector2(10.0, 6.0), -1.0]]:
		var tp: Vector2 = e[0]
		var tent := KitCamps.tent(st["camp_tent"])
		tent.position = _at(ctx, pl, tp.x, tp.y)
		tent.rotation.y = float(e[1])
		node.add_child(tent)
	for k in range(4):
		var q := Vector2(8.0 + (k % 2) * 1.0, -2.0 + k * 0.9)
		var crate := KitStyle.prop(st, "crate", rng, 1.0)
		crate.position = _at(ctx, pl, q.x, q.y)
		crate.rotation.y = rng.randf() * TAU
		node.add_child(crate)
	var crew := GruntCamp.new()
	crew.name = "Outlaws"
	crew.respawn_time = 300.0
	crew.respawn_clearance = 70.0
	crew.warm_start = true
	crew.level = int(isl.node["level"])
	var seed0 := rng.randi() % 100000
	var v3 := func(x: float, z: float) -> Vector3: return _at(ctx, pl, x, z)
	crew.add_grunt({"post": v3.call(0.5, 5.5), "yaw": atan2(1.5, -1.5), "mode": "stand", "seed": seed0 + 1})
	crew.add_grunt({"post": v3.call(3.6, 2.8), "yaw": atan2(-1.6, 1.2), "mode": "stand", "seed": seed0 + 2})
	var route := [v3.call(-14.0, 6.0), v3.call(-12.0, -10.0), v3.call(12.0, -10.0), v3.call(14.0, 6.0)]
	crew.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": seed0 + 3})
	crew.add_grunt({"post": v3.call(1.5, CASTLE_R - 3.0), "yaw": 0.0, "mode": "stand", "seed": seed0 + 4, "role": "rifle"})
	crew.add_grunt({"post": v3.call(-1.5, -2.5), "yaw": 0.0, "mode": "stand", "seed": seed0 + 5})
	node.add_child(crew)
	var baker = isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(node, CASTLE_R + 6.0, false, isl.terrain_faces)


# ==========================================================================
# The hollow giant tree
# ==========================================================================
static func _plan_tree(isl, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var pl := KitWilds._spot(isl, rng, avoid, 24.0, 0.15, 4.0, 8.0, false)
	if pl.is_empty():
		return {}
	var at: Vector2 = pl["at"]
	var face: Vector2 = pl["face"]
	var y: float = pl["y"]
	# the tree and the cavern behind it on level ground
	KitLandmarks.level(isl, _isl(at, face, 0.0, TREE_Z), y, TREE_R + 3.0, TREE_R + 8.0)
	KitLandmarks.level(isl, _isl(at, face, 0.0, -12.0), y, 15.0, 21.0)
	var rooms := [[0.0, -8.5, 0.15, 5.0, 4.2], [-7.5, -15.5, 0.15, 4.2, 3.8], [4.5, -19.0, 0.15, 5.8, 4.8]]
	var segs := [[0.0, TREE_Z - 1.0, 0.15, 0.0, -5.0, 0.15, 1.4, 2.9, 0.0], [0.0, -8.5, 0.15, -7.5, -15.5, 0.15, 1.6, 3.0, 1.0],
		[0.0, -8.5, 0.15, 4.5, -19.0, 0.15, 1.8, 3.3, 1.0]]
	var cave := CaveMesher.make(rooms, segs, rng.randi()).mesh(1.5, -3.0)
	pl.merge({"kind": "forest_hollow_tree", "keep": [[Vector2(0, TREE_Z), TREE_R + 2.0], [Vector2(0, -12.0), 14.0]], "door": at + face * 14.0,
		"cave": cave, "rooms": rooms, "r": 26.0}, true)
	return pl


## The tree: a trunk 11 m across hollowed to its fork, the doorway between two great roots at +Z, the back open into the
## cavern, buttress roots, limbs into a crown of autumn leaves, bracket fungus spiralling up its side to a perch.
static func _tree(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var bark := PSXMat.lit("bark", Color(0.95, 0.85, 0.72))
	var inner_m := PSXMat.lit("bark", Color(0.6, 0.48, 0.38))
	var body := KitLandmarks.body("HollowTree")
	var mb := MeshBuilder.new()
	var tc := Vector3(0, _gy(ctx, pl, 0.0, TREE_Z), TREE_Z)
	var R := TREE_R
	var ri := 3.7
	var hollow := 7.0
	var h := 22.0
	var sides := 24
	# the wall of the hollow: outer and inner faces round, the doorway (+Z) and the back (-Z) left open
	for i in range(sides):
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var am := (a0 + a1) * 0.5
		var door := absf(angle_difference(am, PI * 0.5)) < 0.28
		var back := absf(angle_difference(am, -PI * 0.5)) < 0.3
		var y_lo := 3.4 if door else (3.0 if back else -0.6)
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		var wob0 := 1.0 + 0.06 * sin(a0 * 5.0)
		var wob1 := 1.0 + 0.06 * sin(a1 * 5.0)
		var y_hi := hollow
		var p0 := tc + o0 * R * wob0
		var p1 := tc + o1 * R * wob1
		mb.add_quad(bark, p0 + Vector3.UP * y_lo, p1 + Vector3.UP * y_lo, p1 + Vector3.UP * y_hi, p0 + Vector3.UP * y_hi,
			Vector2(i * 0.8, y_lo * 0.4), Vector2((i + 1) * 0.8, y_lo * 0.4), Vector2((i + 1) * 0.8, y_hi * 0.4), Vector2(i * 0.8, y_hi * 0.4), Color.WHITE, (o0 + o1).normalized())
		var q0 := tc + o0 * ri
		var q1 := tc + o1 * ri
		mb.add_quad(inner_m, q1 + Vector3.UP * y_lo, q0 + Vector3.UP * y_lo, q0 + Vector3.UP * y_hi, q1 + Vector3.UP * y_hi,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0, 2), Color(0.8, 0.8, 0.8), -(o0 + o1).normalized())
		if y_lo > 0.0:
			# the lintel's underside over an opening
			mb.add_quad(inner_m, q0 + Vector3.UP * y_lo, q1 + Vector3.UP * y_lo, p1 + Vector3.UP * y_lo, p0 + Vector3.UP * y_lo, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.7, 0.7, 0.7), Vector3.DOWN)
		var mid := tc + (o0 + o1).normalized() * (R + ri) * 0.5 + Vector3.UP * (y_lo + y_hi) * 0.5
		KitLandmarks.box_col_xf(body, Vector3(R - ri, y_hi - y_lo, TAU * R / sides + 0.2), Transform3D(Basis(Vector3.UP, -am), mid))
	# the ceiling of the hollow, and the trunk on up from there, tapering, solid
	KitLandmarks.water_disc(mb, inner_m, tc + Vector3.UP * hollow, ri + 0.1, sides, 0.3)
	mb.add_cylinder(bark, Transform3D(Basis(), tc + Vector3.UP * hollow), R * 1.0, R * 0.62, h - hollow, sides, 0.4)
	KitLandmarks.cyl_col(body, R * 0.85, h - hollow, tc + Vector3.UP * (hollow + (h - hollow) * 0.5))
	# buttress roots round its foot, two framing the door
	for k in range(9):
		var a := TAU * k / 9.0 + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, -PI * 0.5)) < 0.45:
			continue
		var d := Vector3(cos(a), 0, sin(a))
		var top := tc + d * (R - 0.5) + Vector3.UP * rng.randf_range(2.2, 3.6)
		var foot := tc + d * (R + rng.randf_range(3.0, 5.0)) + Vector3.DOWN * 0.3
		mb.add_tube(bark, PackedVector3Array([top, tc + d * (R + 1.2) + Vector3.UP * 1.0, foot]), 1.0, 0.25, 6, 0.6)
		KitLandmarks.cyl_col(body, 0.8, 2.0, tc + d * (R + 1.2) + Vector3.UP * 1.0)
	# limbs into the crown, red, copper and gold
	var leaves := [PSXMat.lit("leaves_oak", Color.WHITE, {"affine": 0.5}), PSXMat.lit("leaves_maple", Color.WHITE, {"affine": 0.5}), PSXMat.lit("leaves_beech", Color.WHITE, {"affine": 0.5})]
	var crowns: Array = []
	for k in range(7):
		var a := TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector3(cos(a), 0, sin(a))
		var from := tc + Vector3.UP * (h - rng.randf_range(2.0, 6.0))
		var to := tc + d * rng.randf_range(9.0, 13.0) + Vector3.UP * (h + rng.randf_range(2.0, 6.0))
		mb.add_tube(bark, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3.UP * 1.5, to]), 1.4, 0.4, 6, 0.6)
		crowns.append(to)
	crowns.append(tc + Vector3.UP * (h + 6.0))
	for q in crowns:
		for j in range(3):
			var r := rng.randf_range(3.2, 4.6)
			var c: Vector3 = q + Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(-1.0, 2.0), rng.randf_range(-2.5, 2.5))
			var sh := rng.randf_range(0.8, 1.0)
			mb.add_blob(leaves[(j + int(q.x)) % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.65, r), rng, 0.22, 3, 6, 0.5, Color(sh, sh, sh))
		GrapplePoints.add(node, q + Vector3.UP * 0.5)
	# bracket fungus up its side, big enough to stand on, to a perch in the fork
	var shelf := PSXMat.lit("", Color(0.82, 0.66, 0.42))
	var a0 := PI * 0.5 + 0.6
	for k in range(17):
		var a := a0 + k * 0.42
		var y := 0.9 + k * 0.82
		var r := R * (1.0 - 0.38 * clampf((y - hollow) / (h - hollow), 0.0, 1.0)) + 0.55
		var p := tc + Vector3(cos(a) * r, y, sin(a) * r)
		var xf := Transform3D(Basis(Vector3.UP, -a), p)
		mb.add_cylinder(shelf, xf, 0.85, 0.55, 0.22, 7, 1.0, Color.WHITE.darkened(float(k % 3) * 0.08))
		KitLandmarks.box_col_xf(body, Vector3(1.5, 0.24, 1.2), Transform3D(Basis(Vector3.UP, -a), p + Vector3.UP * 0.11))
	var perch_y := 0.9 + 17 * 0.82
	var perch := tc + Vector3.UP * perch_y
	mb.add_cylinder(PSXMat.lit("planks_weathered"), Transform3D(Basis(), perch), R * 0.75, R * 0.75, 0.2, 10, 0.6)
	KitLandmarks.cyl_col(body, R * 0.75, 0.25, perch + Vector3.UP * 0.1)
	var mi := mb.to_instance("HollowTreeMesh")
	mi.visibility_range_end = 1100.0
	body.add_child(mi)
	node.add_child(body)
	pl["perch"] = perch + Vector3.UP * 0.3


## Inside: glowing fungus on the hollow's walls; through its back the root cavern - its rock, roots down through the roof,
## fungus, lights - what lives there (FaunaSpawner's cave slots: bats overhead, sprites and treantlings), the hoard in the
## end chamber and a chest up on the perch.
static func _tree_cavern(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 1)
	var node := KitLandmarks.node_of(ctx, pl)
	var holder := Node3D.new()
	holder.name = "RootCavern"
	node.add_child(holder)
	_cave_body(isl, holder, pl["cave"], "CavernRock")
	var glow := PSXMat.glow(Color(0.55, 1.0, 0.6), 1.1)
	var root_m := PSXMat.lit("bark", Color(0.9, 0.78, 0.64))
	var mb := MeshBuilder.new()
	var tc := Vector3(0, 0, TREE_Z)
	for k in range(8):
		var a := rng.randf() * TAU
		_fungus(mb, tc + Vector3(cos(a) * 3.5, rng.randf_range(0.6, 3.5), sin(a) * 3.5), -Vector3(cos(a), 0, sin(a)), rng, glow)
	var rooms: Array = pl["rooms"]
	for r in rooms:
		var c := Vector3(float(r[0]), float(r[2]), float(r[1]))
		var rr: float = r[3]
		for k in range(5):
			var a := rng.randf() * TAU
			_fungus(mb, c + Vector3(cos(a) * (rr - 0.4), rng.randf_range(0.5, 2.0), sin(a) * (rr - 0.4)), -Vector3(cos(a), 0, sin(a)), rng, glow)
			# roots down through the roof
			var top := c + Vector3(cos(a + 1.0) * rr * 0.5, float(r[4]) + 0.5, sin(a + 1.0) * rr * 0.5)
			mb.add_tube(root_m, PackedVector3Array([top, top + Vector3(rng.randf_range(-0.5, 0.5), -1.6, rng.randf_range(-0.5, 0.5)), top + Vector3(rng.randf_range(-0.8, 0.8), -float(r[4]) + 0.4, rng.randf_range(-0.8, 0.8))]), 0.22, 0.06, 5, 0.8)
		KitLights.light(ctx, holder, c + Vector3.UP * 2.2, 0.9, rr + 3.0)
	holder.add_child(KitLandmarks.far_off(mb.to_instance("CavernDressing"), 140.0))
	var end: Array = rooms[2]
	KitLandmarks.chest(ctx, pl, Vector3(float(end[0]) + 1.5, 0.15, float(end[1]) - 3.0), 0.3, "hollow_tree_hoard", KitLandmarks.loot(isl, rng, true), 1.05)
	var perch: Vector3 = pl["perch"]
	KitLandmarks.chest(ctx, pl, perch, PI, "hollow_tree_perch", KitLandmarks.loot(isl, rng, false), 0.85)
	var fauna = FaunaSpawner.of(isl)
	if fauna:
		var slots: Array = [[Vector3(float(rooms[0][0]), float(rooms[0][4]) - 0.3, float(rooms[0][1])), "ceiling"]]
		for r in [rooms[1], rooms[2], rooms[2]]:
			var a := rng.randf() * TAU
			slots.append([Vector3(float(r[0]) + cos(a) * float(r[3]) * 0.5, 0.15, float(r[1]) + sin(a) * float(r[3]) * 0.5), "floor"])
		fauna.fill_slots(holder, slots, 72)
