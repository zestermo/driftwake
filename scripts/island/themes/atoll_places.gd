extends RefCounted
## The coral atoll's own places for the chain's set pieces (AtollTheme.place_kind / plan_place / place_steps): its reef
## and lagoon to dive for pearls, wrecks and treasure.
##   wreck   a trader driven up onto the reef flat outside the ring and broken there, half out of the water at low
##           tide: her chest on the canted deck, another gone over the side to the bottom, cargo strewn over the reef;
##           wreckers camped on the islet's beach above her (a GruntCamp) picking her clean
##   pearls  a pearl bed in the lagoon's shallows: oysters on the bottom to pry open (a pearl in each, each captain's
##           own), buoys marking the bed, the divers' raft anchored over it with a diver resting on it, spear fish round it
##   hole    the blue hole dressed: coral gardens round its lip to gather from, and on its floor fifteen metres down the
##           drowned shrine of whoever lived here before the sea came up, its coffer still sealed

const KINDS := {"giant_skeleton": "atoll_wreck", "fallen_colossus": "atoll_wreck", "sea_arch": "atoll_wreck", "old_fort": "atoll_wreck",
	"sunken_village": "atoll_pearls", "cenote": "atoll_pearls", "hot_springs": "atoll_pearls",
	"volcano_vent": "atoll_hole", "crystal_grove": "atoll_hole", "giant_nest": "atoll_hole"}
const D := preload("res://scripts/island/themes/atoll_data.gd")
const L := preload("res://scripts/island/themes/atoll_land.gd")
const DIVE := preload("res://scripts/swim/dive_sites.gd")
const VIS := 420.0


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	match kind:
		"atoll_wreck":
			return _plan_wreck(isl, rng, avoid)
		"atoll_pearls":
			return _plan_pearls(isl, rng, avoid)
		"atoll_hole":
			var hole: Array = isl.land_plan["hole"]
			var c: Vector2 = hole[0]
			return {"kind": kind, "at": c, "y": 0.0, "face": (-c).normalized() if c.length() > 1.0 else Vector2(0, 1), "r": D.HOLE_PLACE_R, "keep": [[Vector2.ZERO, 4.0]]}
	return {}


## On the reef flat outside the ring, away from the dock and the village, the islet's beach above her for the wreckers.
static func _plan_wreck(isl, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var da: float = (isl.sites["dock"] as Vector2).angle()
	for k in range(40):
		var a := rng.randf() * TAU
		if absf(angle_difference(a, da)) < 0.7:
			continue
		var rr := L.ring_r(isl, a)
		var at := Vector2.from_angle(a) * (float(rr[0]) + D.REEF_FLAT * 0.55)
		var beach := L.ring_point(isl, a, 0.3)
		if not KitLandmarks.clear_of(isl, at, D.WRECK_R, avoid) or isl.hv(at) > -0.3 or isl.hv(at) < -2.2 or isl.hv(beach) < 0.8:
			continue
		return {"kind": "atoll_wreck", "at": at, "y": 0.0, "face": -Vector2.from_angle(a), "r": D.WRECK_R, "keep": [[Vector2.ZERO, 6.0]],
			"door": beach, "beach": beach}
	return {}


## Lagoon shallows 1.6-3 m deep, clear of the islets, the causeway, the hole, the boss's flat and the town.
static func _plan_pearls(isl, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	for k in range(60):
		var a := rng.randf() * TAU
		var inner: float = L.ring_r(isl, a)[1]
		var at := Vector2.from_angle(a) * inner * rng.randf_range(0.45, 0.85)
		var h: float = isl.hv(at)
		if h > -1.6 or h < -3.2 or not KitLandmarks.clear_of(isl, at, D.PEARL_R, avoid) or at.distance_to(isl.sites["boss"]) < 60.0:
			continue
		if (isl.land_plan["hole"][0] as Vector2).distance_to(at) < 40.0:
			continue
		# (the diver's body made here on the worker, not in the build step)
		var lk := KitStyle.folk_look(KitStyle.of(isl.theme), rng)
		var hm := Humanoid.new()
		hm.setup(lk)
		Humanoid.stock(hm, lk)
		return {"kind": "atoll_pearls", "at": at, "y": 0.0, "face": (-at).normalized(), "r": D.PEARL_R, "keep": [[Vector2.ZERO, 4.0]], "look": lk}
	return {}


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	match str(pl["kind"]):
		"atoll_wreck":
			return [func(): _wreck(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _wreckers(isl, ctx, pl)]
		"atoll_pearls":
			return [func(): _pearls(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
		"atoll_hole":
			return [func(): _hole(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
	push_error("AtollPlaces: no place %s" % pl["kind"])
	return []


static func _gy(isl, pl: Dictionary, x: float, z: float) -> float:
	return float(isl.hv(KitLandmarks.lp(pl, x, z))) - float(pl["y"])


## The wreck (place-local: +z toward the islet).
static func _wreck(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var body := KitLandmarks.body("Wreck")
	node.add_child(body)
	var floor_y := _gy(isl, pl, 0.0, 0.0)
	body.position = Vector3(0, floor_y + 0.9, 0)
	body.rotation = Vector3(rng.randf_range(0.08, 0.16), rng.randf_range(0.6, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(0.32, 0.48))
	body.scale = Vector3.ONE * 1.25
	var model := Node3D.new()
	body.add_child(model)
	var st: Dictionary = ctx.style
	HullBuilder.build(model, {"hull": st["wreck_hull"], "deck": (st["wreck_hull"] as Color).lightened(0.15), "trim": Color(0.5, 0.46, 0.4), "wreck": true})
	HullBuilder.collide(body, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = VIS
	# her cargo over the reef: stove crates, a barrel or two, spars
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered", Color(0.85, 0.8, 0.72))
	var spar := PSXMat.lit("planks_grey", Color(1.05, 1.0, 0.92))
	for k in range(9):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, D.WRECK_R - 2.0)
		var y := _gy(isl, pl, q.x, q.y)
		if rng.randf() < 0.6:
			var s := rng.randf_range(0.6, 1.0)
			mb.add_box(wood, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))), Vector3(q.x, y + s * 0.3, q.y)), Vector3(s, s * 0.8, s))
		else:
			var a := rng.randf() * TAU
			var ln := rng.randf_range(3.0, 6.0)
			mb.add_cylinder(spar, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(q.x, y + 0.15, q.y)), 0.15, 0.12, ln, 6, 0.6)
	var mi := mb.to_instance("Cargo")
	mi.visibility_range_end = 220.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var deck := body.transform * Vector3(0.0, HullLayout.DECK_Y + 0.2, -2.0)
	KitLandmarks.chest(ctx, pl, deck, rng.randf() * TAU, "atoll_wreck_chest", KitLandmarks.loot(isl, rng, true), 0.95)
	# the second chest went over the side, into the deeper water at her stern
	var q2 := Vector2(rng.randf_range(-6.0, 6.0), -D.WRECK_R + 3.0)
	var ip := KitLandmarks.lp(pl, q2.x, q2.y)
	DIVE.sunken_chest(node, isl.to_global(Vector3(ip.x, isl.hv(ip), ip.y)), rng.randf() * TAU, isl.save_key("atoll_wreck_sunk"), DIVE.roll(DIVE.WRECK_LOOT, rng), rng)
	# the reef's fish shelter in her: a spear spot on the bottom beside her
	var sp := KitLandmarks.lp(pl, 4.0, 0.0)
	AtollSpots.add_marker(node, {"at": Vector3(4.0, isl.hv(sp), 0.0), "kind": "spear", "where": "wreck", "depth": maxf(-float(isl.hv(sp)), 0.0), "r": 10.0}, 0)
	_gone(isl, node)


## Wreckers camped on the beach above her, a fire and their spoils (host-run, a GruntCamp like any crew).
static func _wreckers(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 3
	var beach: Vector2 = pl["beach"]
	KitCamps.campfire(ctx, beach, 1.5)
	var crew := GruntCamp.new()
	crew.name = "WreckCrew"
	crew.respawn_time = 600.0
	crew.respawn_clearance = 70.0
	crew.level = IslandContent.level(isl)
	for i in range(3):
		var a := TAU * i / 3.0 + rng.randf_range(-0.4, 0.4)
		var q := beach + Vector2.from_angle(a) * rng.randf_range(3.0, 5.0)
		var route := []
		for j in range(4):
			var rq := beach + Vector2.from_angle(a + TAU * j / 4.0) * rng.randf_range(4.0, 8.0)
			route.append(Vector3(rq.x, isl.hv(rq), rq.y))
		crew.add_grunt({"post": Vector3(q.x, isl.hv(q), q.y), "yaw": a + PI, "mode": "patrol", "patrol": route, "seed": int(isl.node["seed"]) % 100000 + 760 + i})
	isl.add_child(crew)
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker") if isl.get_parent() else null
	if baker:
		var zone := Node3D.new()
		zone.name = "WreckZone"
		isl.add_child(zone)
		zone.position = Vector3(beach.x, isl.hv(beach), beach.y)
		baker.add_zone(zone, 20.0, false, isl.terrain_faces)


## The pearl bed (place-local).
static func _pearls(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var gm: Node = isl.get_node_or_null("/root/GameManager")
	var n := rng.randi_range(D.PEARL_BEDS[0], D.PEARL_BEDS[1])
	for k in range(n):
		var q := Vector2.from_angle(TAU * k / n + rng.randf_range(-0.3, 0.3)) * rng.randf_range(3.0, D.PEARL_R * 0.8)
		var ip := KitLandmarks.lp(pl, q.x, q.y)
		var key: String = isl.save_key("atoll_pearl_bed_%d" % k)
		var bed: Array = DIVE.oyster_bed(node, isl.to_global(Vector3(ip.x, isl.hv(ip), ip.y)), key, rng)
		if gm and gm.opened.has(key):
			((bed[0] as Node).get_node("Take") as Interactable).enabled = false
			(bed[2] as Node3D).visible = false
	# the divers' raft anchored over the bed: a deck of lashed poles on floats, a basket of shells, a rope down
	var raft := KitLandmarks.body("Raft")
	node.add_child(raft)
	var mb := MeshBuilder.new()
	var bamboo := PSXMat.lit("bamboo")
	var rope := PSXMat.lit("rope")
	for k in range(9):
		mb.add_cylinder(bamboo, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.6 + k * 0.4, 0.32, -1.8)), 0.12, 0.12, 3.6, 6, 1.0)
	for z in [-1.4, 1.4]:
		mb.add_cylinder(bamboo, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(1.8, 0.46, z)), 0.08, 0.08, 3.6, 5, 1.0)
	for c in [Vector3(-1.2, 0.05, -1.2), Vector3(1.2, 0.05, -1.2), Vector3(-1.2, 0.05, 1.2), Vector3(1.2, 0.05, 1.2)]:
		mb.add_cylinder(PSXMat.lit("planks_dark"), Transform3D(Basis(), c), 0.32, 0.32, 0.36, 7, 0.6)
	mb.add_tube(rope, PackedVector3Array([Vector3(1.5, 0.4, 1.5), Vector3(1.9, -0.6, 1.9), Vector3(2.2, _gy(isl, pl, 2.2, 2.2), 2.2)]), 0.03, -1.0, 3)
	var mi := mb.to_instance("RaftMesh")
	mi.visibility_range_end = 260.0
	raft.add_child(mi)
	KitLandmarks.box_col(raft, Vector3(3.6, 0.3, 3.6), Vector3(0, 0.3, 0))
	var basket := KitStyle.prop(ctx.style, "crate", rng, 0.7)
	raft.add_child(basket)
	basket.position = Vector3(-0.9, 0.45, 0.8)
	# buoys round the bed
	var bm := MeshBuilder.new()
	var cols: Array = ctx.style["harbour_floats"]
	for k in range(5):
		var a := TAU * k / 5.0
		var b := Vector3(cos(a), 0.0, sin(a)) * D.PEARL_R
		bm.add_blob(PSXMat.flat(cols[k % cols.size()]), Transform3D(Basis(), b + Vector3.UP * 0.1), Vector3(0.3, 0.26, 0.3), rng, 0.1, 2, 6)
		bm.add_cylinder(PSXMat.lit("planks_dark"), Transform3D(Basis(), b + Vector3.UP * 0.3), 0.04, 0.04, 0.7, 4, 1.0)
	var bmi := bm.to_instance("Buoys")
	bmi.visibility_range_end = 260.0
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(bmi)
	# a pearl diver resting on the raft between dives
	var names: Array = (LifePools.of(isl.theme)["first"] as Array)
	var npc := NPC.new()
	var who := "%s the Pearl Diver" % names[rng.randi() % names.size()]
	npc.setup({"name": who, "voice": 1.05, "look": pl["look"], "yaw": float(pl["yaw"]),
		"barks": ["Count with me. One. Two. Most stop at forty.", "Pry them gently. The greedy ones hold the pearls.", "Morays in the heads. Mind your fingers."]})
	npc.ground_func = func(_x: float, _z: float) -> float: return 0.6
	node.add_child(npc)
	npc.global_position = isl.to_global(Vector3((pl["at"] as Vector2).x, 0.6, (pl["at"] as Vector2).y))
	AtollSpots.add_marker(node, {"at": Vector3(0, _gy(isl, pl, 0.0, 0.0), 0), "kind": "spear", "where": "pearls", "depth": -_gy(isl, pl, 0.0, 0.0), "r": D.PEARL_R}, 0)


## The blue hole dressed (place-local: its middle).
static func _hole(isl, _ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var gm: Node = isl.get_node_or_null("/root/GameManager")
	var r: float = isl.land_plan["hole"][1]
	var n := rng.randi_range(D.HOLE_GARDENS[0], D.HOLE_GARDENS[1])
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var q := Vector2(cos(a), sin(a)) * (r + rng.randf_range(4.0, 8.0))
		var ip := KitLandmarks.lp(pl, q.x, q.y)
		var key: String = isl.save_key("atoll_hole_reef_%d" % k)
		var reef: Array = DIVE.reef_garden(node, isl.to_global(Vector3(ip.x, isl.hv(ip), ip.y)), key, rng)
		if gm and gm.opened.has(key):
			((reef[0] as Node).get_node("Take") as Interactable).enabled = false
	var c: Vector2 = pl["at"]
	DIVE.sunken_ruin(node, isl.to_global(Vector3(c.x, isl.hv(c), c.y)), rng.randf() * TAU, isl.save_key("atoll_hole_coffer"), rng)
	var q2 := Vector2.from_angle(rng.randf() * TAU) * r * 0.45
	var ip2 := KitLandmarks.lp(pl, q2.x, q2.y)
	DIVE.sunken_chest(node, isl.to_global(Vector3(ip2.x, isl.hv(ip2), ip2.y)), rng.randf() * TAU, isl.save_key("atoll_hole_chest"), DIVE.roll(DIVE.CHEST_LOOT, rng), rng)
	_gone(isl, node)


## Sunken chests already opened (this save) don't come back.
static func _gone(isl, node: Node3D) -> void:
	var gm: Node = isl.get_node_or_null("/root/GameManager")
	if gm == null:
		return
	for bag in node.find_children("*", "LootBag", true, false):
		if gm.opened.has((bag as LootBag).save_id):
			bag.queue_free()
