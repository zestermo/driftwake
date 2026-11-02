extends RefCounted
## The coral atoll's stilt town (AtollTheme.plan_places / place_steps; docs/v1_28_plan.md "Islands"): from the village's
## lagoon shore a boardwalk on palm-trunk piles walks out over the water, huts on piles off short spurs either side,
## a big platform at its end (the town's square over the lagoon, a pearl trader's stall on it), fishing platforms off
## it and at the spurs' ends (each a line-fishing spot: AtollSpots, group "fishing_spots", where "pier"), outrigger canoes
## tied along it, nets and fish drying, lamps. A theme place, so it gets its own trail from the village and its ground kept.
## The rest of the town (the inn, the store, the shops, the harbour) is the village's own (the style's stilts layout).

const KIND := "atoll_stilts"
const D := preload("res://scripts/island/themes/atoll_data.gd")
const Shops := preload("res://scripts/game/shops.gd")
## The fishing platforms' size, the big platform's half size, a spur's length, the gap between spurs along the walk.
const PLAT := 1.9
const SQUARE := 4.6
const SPUR := [4.5, 6.5]
const SPUR_GAP := 6.5
const HUT := [3.4, 4.2]
const VIS := 340.0
const PEARLS_BASE := 70


## The town's water (GenIsland.prepare, worker): off the village's lagoon shore to one side of the causeway, over water
## deep enough the whole way. [] when there's none (nothing guaranteed).
static func plan_places(isl, _avoid: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), KIND])
	var vil: Vector2 = isl.sites["village"]
	var into := (-vil).normalized()
	var side := -float(isl.land_plan["side"])
	for k in range(10):
		var turn := rng.randf_range(0.3, 0.6) * side * (1.0 if k % 2 == 0 else -1.0)
		var dir := into.rotated(turn)
		var s := vil
		while isl.hv(s) > D.TOWN_DECK_Y - 0.2 and s.distance_to(vil) < 140.0:
			s += dir * 2.0
		if isl.hv(s) > D.TOWN_DECK_Y - 0.2:
			continue
		var L := rng.randf_range(D.TOWN_WALK[0], D.TOWN_WALK[1])
		if not _water(isl, s, dir, L + SQUARE * 2.0 + 4.0):
			continue
		var looks: Array = []
		var st := KitStyle.of(isl.theme)
		for i in range(4):
			var lk := KitStyle.folk_look(st, rng)
			var hm := Humanoid.new()
			hm.setup(lk)
			Humanoid.stock(hm, lk)
			looks.append(lk)
		var spurs: Array = []
		var z := L * 0.5 - 7.0
		var sd := 1.0 if rng.randf() < 0.5 else -1.0
		var huts := rng.randi_range(D.TOWN_HUTS[0], D.TOWN_HUTS[1])
		while z > -L * 0.5 + 2.0:
			for sx in [sd, -sd]:
				if spurs.size() < huts + 2:
					spurs.append({"z": z, "x": sx, "len": rng.randf_range(SPUR[0], SPUR[1]), "hut": true, "seed": rng.randi()})
			z -= SPUR_GAP
			sd = -sd
		# (the two furthest out end in a fishing platform instead of a hut)
		for i in range(mini(2, spurs.size())):
			spurs[spurs.size() - 1 - i]["hut"] = false
		var at := s + dir * (L * 0.5 - 3.0)
		return [{"kind": KIND, "at": at, "y": 0.0, "face": -dir, "r": L * 0.5 + SQUARE * 2.0, "door": s - dir * 3.0,
			"keep": [[Vector2.ZERO, 6.0]], "looks": looks, "len": L, "spurs": spurs}]
	return []


## Water under the whole walk and its spurs (none of the village or anything else in it).
static func _water(isl, s: Vector2, dir: Vector2, L: float) -> bool:
	var side := dir.orthogonal()
	var d := 12.0
	while d < L:
		for off in [-8.0, 0.0, 8.0]:
			var q: Vector2 = s + dir * d + side * off
			if isl.hv(q) > -0.4:
				return false
		if isl.reserved_in(s + dir * d, 1.0):
			return false
		d += 4.0
	return true


static func steps(isl, ctx, pl: Dictionary) -> Array:
	return [func(): _town(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _dressing(isl, ctx, pl), func(): _details(isl, ctx, pl),
		func(): _people(isl, ctx, pl)]


## Place-local (x, z) to an island point.
static func _ip(pl: Dictionary, x: float, z: float) -> Vector2:
	return KitLandmarks.lp(pl, x, z)


static func _v3(pl: Dictionary, x: float, z: float, y: float) -> Vector3:
	var q := _ip(pl, x, z)
	return Vector3(q.x, y, q.y)


## The boardwalk, its spurs, the square and the platforms (one deck mesh, one collider of their tops), the piles under
## them, and the huts on theirs.
static func _town(isl, ctx, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var st: Dictionary = ctx.style
	var y := D.TOWN_DECK_Y
	var L: float = pl["len"]
	var deck := PSXMat.lit(st["harbour_deck"], Color.WHITE, {"affine": 0.5})
	var dark := PSXMat.lit("planks_dark")
	var palm := PSXMat.lit(st["harbour_pile"])
	var mb := MeshBuilder.new()
	var top := MeshBuilder.new()
	var piles: Array = []
	var strip := func(pts: PackedVector3Array, hw: float) -> void:
		HarbourModels.deck_strip(mb, top, deck, dark, pts, hw, rng)
		for smp in GenHarbour._samples(pts, 2.4):
			var q: Vector3 = smp[0]
			var lft := Vector2(-(smp[1] as Vector2).y, (smp[1] as Vector2).x)
			for sgn: float in [1.0, -1.0]:
				var e: Vector2 = Vector2(q.x, q.z) + lft * sgn * (hw - 0.14)
				var g := float(isl.hv(e))
				if g < q.y - 0.45:
					piles.append([Vector3(e.x, g - 0.6, e.y), Vector3(e.x, q.y - 0.1, e.y), 0.13])
	# the main walk from the shore to the square
	strip.call(PackedVector3Array([_v3(pl, 0, L * 0.5 + 3.0, y), _v3(pl, 0, -L * 0.5 + 0.5, y)]), D.TOWN_HW)
	# the square, three fishing platforms off its far side
	var sq_z := -L * 0.5 - SQUARE + 0.5
	strip.call(PackedVector3Array([_v3(pl, 0, sq_z + SQUARE, y), _v3(pl, 0, sq_z - SQUARE, y)]), SQUARE)
	for e in _square_plats(L):
		strip.call(PackedVector3Array([_v3(pl, e.x, e.y + PLAT, y), _v3(pl, e.x, e.y - PLAT, y)]), PLAT)
	# spurs: a hut's deck or a platform at the end of each
	for sp in pl["spurs"]:
		var sx: float = sp["x"]
		var sl: float = sp["len"]
		var z: float = sp["z"]
		strip.call(PackedVector3Array([_v3(pl, sx * D.TOWN_HW * 0.8, z, y), _v3(pl, sx * (D.TOWN_HW + sl), z, y)]), 0.75)
		var c := sx * (D.TOWN_HW + sl + PLAT)
		strip.call(PackedVector3Array([_v3(pl, c, z + PLAT, y), _v3(pl, c, z - PLAT, y)]), PLAT)
	HarbourModels.piles(mb, palm, piles, rng, false, 0.06)
	var body := KitLandmarks.body("AtollTown")
	var mi := mb.to_instance("Boardwalk")
	mi.visibility_range_end = 900.0
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = top.commit().create_trimesh_shape()
	body.add_child(cs)
	body.transform = node.transform.affine_inverse()
	node.add_child(body)
	# the huts, each on its own piles at the end of its spur, its door onto the spur
	var hrng := RandomNumberGenerator.new()
	var i := 0
	for sp in pl["spurs"]:
		if not sp["hut"]:
			continue
		hrng.seed = int(sp["seed"])
		var spec := KitStyle.house_spec(st, hrng)
		var w := hrng.randf_range(HUT[0], HUT[1])
		spec.merge({"w": w, "d": w * hrng.randf_range(0.85, 1.0), "h": 2.4, "porch": 0.0, "steps": false, "chimney": false, "name": "StiltHut%d" % i}, true)
		var sx: float = sp["x"]
		var c := Vector2(sx * (D.TOWN_HW + float(sp["len"]) + PLAT), float(sp["z"]))
		var q := _ip(pl, c.x, c.y)
		var floor_y := float(isl.hv(q))
		spec["stilts"] = y - 0.3 - floor_y
		spec["foundation"] = 0.4
		var hut := Buildings.house(spec)
		node.add_child(hut)
		# (its door, the house's +Z, turned to face back along the spur to the walk)
		hut.position = Vector3(c.x, floor_y, c.y)
		hut.rotation.y = -PI * 0.5 * sx
		i += 1


## The square's three fishing platforms (place-local middles).
static func _square_plats(L: float) -> Array:
	var sq_z := -L * 0.5 - SQUARE + 0.5
	return [Vector2(0, sq_z - SQUARE - PLAT + 0.3), Vector2(SQUARE + PLAT - 0.3, sq_z - 1.5), Vector2(-SQUARE - PLAT + 0.3, sq_z - 1.5)]


## The town's things: canoes tied along the walk, the square's stalls, nets and fish drying, pots and baskets, lamps, and
## the fishing spots' markers.
static func _dressing(isl, ctx, pl: Dictionary) -> void:
	var node: Node3D = isl.get_node("Place_" + KIND)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 3
	var st: Dictionary = ctx.style
	var y := D.TOWN_DECK_Y
	var L: float = pl["len"]
	var sq_z := -L * 0.5 - SQUARE + 0.5
	var put := func(n: Node3D, x: float, z: float, up: float, yaw: float) -> void:
		node.add_child(n)
		n.position = Vector3(x, up, z)
		n.rotation.y = yaw
	# canoes tied up beside the walk, afloat
	for k in range(rng.randi_range(3, 5)):
		var z := L * 0.5 - 4.0 - k * rng.randf_range(5.0, 8.0)
		var sx := 1.0 if k % 2 == 0 else -1.0
		var canoe := HarbourModels.canoe(rng.randi(), true)
		canoe.name = "Canoe%d" % k
		put.call(canoe, sx * (D.TOWN_HW + 1.4), z, -0.2, rng.randf_range(-0.15, 0.15))
	# the square: a stall or two, the pearl trader's under an awning, a net rack, traps, pots
	var mb := MeshBuilder.new()
	var cloth := PSXMat.lit("cloth_blue", Color.WHITE)
	var palm := PSXMat.lit("palm_bark")
	var thatch := PSXMat.lit("palm_thatch", Color.WHITE, {"affine": 0.8})
	var wood := PSXMat.lit("planks", Color(0.86, 0.76, 0.62))
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (SQUARE - 1.6)
		for px in [-1.1, 1.1]:
			for pz in [-0.9, 0.9]:
				mb.add_cylinder(palm, Transform3D(Basis(), Vector3(cx + px, y, sq_z + pz)), 0.07, 0.06, 2.3, 5, 0.8)
		mb.add_box(wood, Transform3D(Basis(), Vector3(cx, y + 0.85, sq_z - 0.4 * sx)), Vector3(2.0, 0.08, 0.7))
		mb.add_box(wood, Transform3D(Basis(), Vector3(cx, y + 0.42, sq_z - 0.4 * sx)), Vector3(1.9, 0.84, 0.06))
		var roof := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, y + 2.3, sq_z))
		mb.add_gable_roof(thatch if sx < 0.0 else cloth, roof, 2.6, 2.6, 0.6)
	# wares: shells and pearls on one, dried fish on the other
	var shell := PSXMat.flat(Color(0.95, 0.88, 0.82))
	for k in range(9):
		mb.add_blob(shell, Transform3D(Basis(), Vector3(-(SQUARE - 1.6) + rng.randf_range(-0.8, 0.8), y + 0.95, sq_z + 0.4 + rng.randf_range(-0.2, 0.2))), Vector3.ONE * rng.randf_range(0.06, 0.12), rng, 0.2, 2, 5)
	var pearl := PSXMat.glow(Color(1.0, 0.97, 0.9), 0.5)
	for k in range(5):
		mb.add_blob(pearl, Transform3D(Basis(), Vector3(-(SQUARE - 1.6) + rng.randf_range(-0.6, 0.6), y + 0.93, sq_z + 0.4)), Vector3.ONE * 0.04, rng, 0.0, 2, 5)
	var fish := PSXMat.lit("scales", Color(0.75, 0.78, 0.82))
	var rope := PSXMat.lit("rope")
	# fish drying on lines between poles along the walk
	for k in range(2):
		var z := L * 0.5 - 10.0 - k * 14.0
		var sx := -1.0 if k % 2 == 0 else 1.0
		var a := Vector3(sx * (D.TOWN_HW - 0.2), y, z - 1.8)
		var b := Vector3(sx * (D.TOWN_HW - 0.2), y, z + 1.8)
		for p in [a, b]:
			mb.add_cylinder(palm, Transform3D(Basis(), p), 0.05, 0.05, 1.9, 5, 0.8)
		mb.add_tube(rope, MeshBuilder.sag_points(a + Vector3.UP * 1.8, b + Vector3.UP * 1.8, 0.15, 6), 0.02, -1.0, 3)
		for j in range(6):
			var f := a.lerp(b, (j + 0.5) / 6.0) + Vector3.UP * (1.45 - 0.08 * sin(PI * (j + 0.5) / 6.0))
			mb.add_blob(fish, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), f), Vector3(0.09, 0.32, 0.04), rng, 0.1, 2, 5)
	var mi := mb.to_instance("Wares")
	mi.visibility_range_end = 200.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var stalls := KitLandmarks.body("Stalls")
	for sx in [-1.0, 1.0]:
		KitLandmarks.box_col(stalls, Vector3(2.0, 0.9, 0.8), Vector3(sx * (SQUARE - 1.6), y + 0.45, sq_z - 0.4 * sx))
	node.add_child(stalls)
	var rack := HarbourModels.net_rack(rng.randi(), "palm_bark", st["harbour_floats"])
	put.call(rack, 0.0, sq_z + SQUARE - 1.0, y, 0.0)
	var traps := HarbourModels.fish_traps(rng.randi(), 3)
	traps.visibility_range_end = 160.0
	put.call(traps, SQUARE - 1.2, sq_z + SQUARE - 1.2, y, 0.4)
	for k in range(3):
		var pot := KitStyle.prop(st, "barrel", rng, 0.7)
		put.call(pot, -SQUARE + 0.8 + k * 0.7, sq_z + SQUARE - 0.7, y, rng.randf() * TAU)
	# lamps: one at the shore end, one on the square, from the budget
	for e in [[D.TOWN_HW + 0.2, L * 0.5 - 1.0], [SQUARE - 0.4, sq_z - SQUARE + 0.6], [-SQUARE + 0.4, sq_z + SQUARE - 0.6]]:
		var lamp := KitStyle.prop(st, "lamp", rng, 1.0)
		put.call(lamp, float(e[0]), float(e[1]), y, 0.0)
		KitLights.light(ctx, lamp, lamp.get_node("Flame").position, 1.6)
	# the fishing spots: the square's three platforms and the spurs' platforms
	var spots := Node3D.new()
	spots.name = "Spots"
	node.add_child(spots)
	var n := 0
	for e in _square_plats(L):
		AtollSpots.add_marker(spots, {"at": Vector3(e.x, y, e.y), "kind": "line", "where": "pier", "depth": -float(isl.hv(_ip(pl, e.x, e.y))), "r": 6.0}, n)
		n += 1
	for sp in pl["spurs"]:
		if sp["hut"]:
			continue
		var c := float(sp["x"]) * (D.TOWN_HW + float(sp["len"]) + PLAT)
		AtollSpots.add_marker(spots, {"at": Vector3(c, y, float(sp["z"])), "kind": "line", "where": "pier", "depth": -float(isl.hv(_ip(pl, c, float(sp["z"])))), "r": 5.0}, n)
		n += 1


## Its people: the pearl trader at her stall (a shop: pearls and shell, and she buys what the reef gives up), two fishers
## on the platforms, a net-mender on the walk.
static func _people(isl, _ctx, pl: Dictionary) -> void:
	var node: Node3D = isl.get_node("Place_" + KIND)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 7
	var names: Array = (LifePools.of(isl.theme)["first"] as Array)
	var looks: Array = pl["looks"]
	var L: float = pl["len"]
	var sq_z := -L * 0.5 - SQUARE + 0.5
	var who := "%s the Pearl Trader" % names[rng.randi() % names.size()]
	var id: String = isl.save_key("pearl_trader")
	var tier := IslandContent.tier(isl)
	Shops.extra[id] = {"name": who, "line": "White, gold and black. Every one dived from this lagoon. And I'll buy whatever the reef gives you.",
		"trade": "grocer", "stock": [["pearl", 3 + tier], ["oyster", 6], ["sea_urchin", 4], ["seaweed", 6]] + _skimmer_stock(), "buys": {"loot": 1.15, "ingredient": 0.7}}
	_npc(isl, pl, node, who, looks[0], Vector2(-(SQUARE - 1.6), sq_z - 0.4), Vector2(0, 1), {"shop": id,
		"barks": ["Pearls! White, gold and black!", "Dived this morning. Feel the weight.", "Bring me what the reef gives you, Captain."]})
	var fbarks := ["Fish are running in the pass.", "Quiet. You'll scare them.", "Lagoon's like glass. Nothing biting.", "Big one took the bait. Then the bait."]
	var plats := _square_plats(L)
	for i in range(2):
		var e: Vector2 = plats[1 + i]
		_npc(isl, pl, node, "%s the Fisher" % names[rng.randi() % names.size()], looks[1 + i], e, Vector2(signf(e.x), 0), {"barks": fbarks})
	_npc(isl, pl, node, "%s the Net-mender" % names[rng.randi() % names.size()], looks[3], Vector2(D.TOWN_HW - 0.4, L * 0.5 - 12.0), Vector2(-1, 0),
		{"barks": ["Coral tore it again.", "Hand me the needle. The bone one.", "Floats from the old wreck. Glass ones."]})


static func _npc(isl, pl: Dictionary, node: Node3D, who: String, look: Dictionary, local: Vector2, face: Vector2, extra: Dictionary) -> NPC:
	var q := _ip(pl, local.x, local.y)
	var fw := _ip(pl, local.x + face.x, local.y + face.y) - q
	var cfg := {"name": who, "voice": 0.85 + float(absi(hash(who)) % 30) / 100.0, "look": look, "yaw": KitContext.face_yaw(fw)}
	cfg.merge(extra)
	var npc := NPC.new()
	npc.setup(cfg)
	npc.ground_func = func(x: float, z: float) -> float: return maxf(float(isl.walk_height(x, z)), D.TOWN_DECK_Y)
	node.add_child(npc)
	npc.global_position = isl.to_global(Vector3(q.x, D.TOWN_DECK_Y, q.y))
	return npc


## (1.28.1) The skimmer's: the trader's sea-silk and its blueprint (only once the game has them: GadgetData's).
static func _skimmer_stock() -> Array:
	var out: Array = []
	for e in [["sea_silk", 30], ["bp_skimmer", 400]]:
		if ItemDB.get_item(str(e[0])) != null:
			out.append(e)
	return out


## (1.28.1) The atoll's own touches (Zach: unique village assets per island): shell-bead curtains in the huts' doors,
## coral-stone footings under their stilts, shell wind-chimes under the eaves, outriggers on the canoes, and on the
## platforms without a hut conch shells, pearl divers' baskets and racks of fish drying. One mesh for the lot.
static func _details(isl, ctx, pl: Dictionary) -> void:
	var node: Node3D = isl.get_node("Place_" + KIND)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 11
	var st: Dictionary = ctx.style
	var y := D.TOWN_DECK_Y
	var mb := MeshBuilder.new()
	var plain := PSXMat.lit("", Color.WHITE)
	var coral := PSXMat.lit("driftstone", Color(1.15, 1.0, 0.95))
	var palm := PSXMat.lit("palm_bark")
	var weave := PSXMat.lit("straw", Color(1.0, 0.92, 0.75))
	var beads := [Color(0.98, 0.96, 0.92), Color(1.0, 0.7, 0.72), Color(0.4, 0.85, 0.85), Color(0.95, 0.8, 0.4)]
	for sp in pl["spurs"]:
		var sx: float = sp["x"]
		var c := Vector2(sx * (D.TOWN_HW + float(sp["len"]) + PLAT), float(sp["z"]))
		if not sp["hut"]:
			# a platform: conch shells, a pearl diver's basket or two, a rack of fish drying
			for k in range(rng.randi_range(2, 3)):
				var o := Vector3(c.x + rng.randf_range(-1.2, 1.2), y + 0.05, c.y + rng.randf_range(-1.2, 1.2))
				var b := Basis(Vector3.UP, rng.randf() * TAU)
				mb.add_cone(plain, Transform3D(b * Basis(Vector3.BACK, PI * 0.5), o + Vector3(0, 0.12, 0)), 0.14, 0.4, 6, 0.5)
				mb.add_blob(plain, Transform3D(b, o + Vector3(-0.08, 0.12, 0)), Vector3(0.16, 0.12, 0.13), rng, 0.05, 2, 6, 0.5, Color(1.0, 0.75, 0.65))
			var bk := Vector3(c.x - sx * 1.1, y, c.y + rng.randf_range(-1.0, 1.0))
			mb.add_cylinder(weave, Transform3D(Basis(), bk + Vector3(0, 0.22, 0)), 0.24, 0.3, 0.44, 8, 1.0, Color.WHITE, false, false)
			mb.add_cylinder(palm, Transform3D(Basis(), bk + Vector3(0, 0.47, 0)), 0.25, 0.25, 0.04, 8, 1.0)
			var rk := Vector3(c.x + sx * 0.8, y, c.y)
			for z in [-0.8, 0.8]:
				mb.add_box(palm, Transform3D(Basis(), rk + Vector3(0, 0.75, z)), Vector3(0.06, 1.5, 0.06), 0.5)
			mb.add_box(palm, Transform3D(Basis(), rk + Vector3(0, 1.45, 0)), Vector3(0.05, 0.05, 1.7), 0.5)
			for f in range(5):
				mb.add_box(plain, Transform3D(Basis(), rk + Vector3(0, 1.2, -0.6 + f * 0.3)), Vector3(0.03, 0.4, 0.12), 0.5, Color(0.75, 0.6, 0.45))
			continue
		# a hut: the same spec its house was built from (atoll_town._town), for its size and where its door is
		var hrng := RandomNumberGenerator.new()
		hrng.seed = int(sp["seed"])
		KitStyle.house_spec(st, hrng)
		var w := hrng.randf_range(HUT[0], HUT[1])
		var d := w * hrng.randf_range(0.85, 1.0)
		var q := _ip(pl, c.x, c.y)
		var floor_y := float(isl.hv(q))
		var yaw := -PI * 0.5 * sx
		var hb := Basis(Vector3.UP, yaw)
		var hp := Vector3(c.x, 0.0, c.y)
		# coral-stone footings under its corner stilts
		for cx in [-0.5, 0.5]:
			for cz in [-0.5, 0.5]:
				var f: Vector3 = hp + hb * Vector3(cx * w * 0.9, 0.0, cz * d * 0.9)
				mb.add_blob(coral, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(f.x, floor_y + 0.15, f.z)), Vector3(0.45, 0.35, 0.45), rng, 0.15, 3, 6)
		# a curtain of shell beads in the door (the house's +Z, turned with it)
		var door := hp + hb * Vector3(0.0, 0.0, d * 0.5 + 0.06)
		var across := hb * Vector3.RIGHT
		for k in range(9):
			var x := (k - 4) * 0.1
			for j in range(8):
				var bp: Vector3 = door + across * x + Vector3(0, y + 1.95 - j * 0.2, 0)
				mb.add_box(plain, Transform3D(hb, bp), Vector3(0.05, 0.08, 0.05), 0.5, beads[(k + j) % beads.size()])
		# shell chimes under the eaves by the door
		for side in [-1.0, 1.0]:
			var ch: Vector3 = door + across * side * (w * 0.5 - 0.3) + hb * Vector3(0, 0, 0.5)
			for j in range(5):
				mb.add_box(plain, Transform3D(Basis(Vector3.UP, j * 0.7), ch + Vector3(0, y + 2.3 - j * 0.14, 0)), Vector3(0.09, 0.06, 0.02), 0.5, beads[j % beads.size()])
	# outriggers on the canoes tied along the walk (HarbourModels.canoe lies along its z)
	for cn in node.get_children():
		if not str(cn.name).begins_with("Canoe"):
			continue
		var omb := MeshBuilder.new()
		for z in [-0.7, 0.7]:
			omb.add_box(palm, Transform3D(Basis(), Vector3(0.75, 0.35, z)), Vector3(1.4, 0.05, 0.06), 0.5)
		omb.add_cylinder(palm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.45, 0.12, 0)), 0.08, 0.08, 2.2, 6, 0.5, Color.WHITE, true, true)
		var om := omb.to_instance("Outrigger")
		om.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		om.visibility_range_end = VIS
		cn.add_child(om)
	var mi := mb.to_instance("AtollDetails")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VIS
	node.add_child(mi)
