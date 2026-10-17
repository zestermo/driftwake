extends SceneTree
## The desert's own places on a desert island (a chain node made desert, its landmarks forced to the
## waterfall, the great tree and the totem grove): the desert stands its caravan camp, obelisk and twin
## guardians in for them (the jungle keeps the chain's); an oasis with room gets its pool (the bed under the
## water, the banks over it, swimmable) and its camp on the bank; the same node plans the same places; each
## builds, with its colliders and its cache. Then the set pieces it stands in for the volcano vent, the
## sunken village and the cenote: the ruined skyline, the buried city and the tomb, each built.
const TK := preload("res://tools/dev/test_kit.gd")
var KL
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _make(n: Dictionary):
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.prepare(n.duplicate(true))
	return isl


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	KL = load("res://scripts/island/kit/kit_landmarks.gd")
	var d = IT.of("desert")
	var j = IT.of("jungle")
	check("the jungle keeps the chain's places; the desert stands its own in", j.place_kind("waterfall") == "" and d.place_kind("waterfall") == "caravan_camp"
		and d.place_kind("great_tree") == "obelisk" and d.place_kind("totem_grove") == "guardians" and d.place_kind("wreck") == "")
	load("res://scripts/island/island_theme.gd").meshes("desert")
	var c = load("res://scripts/world/chain.gd").make(7, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n["theme"] = "desert"
	n.merge({"beast": d.bosses[0], "beast_look": 0, "beast_name": d.beasts[d.bosses[0]]["names"][0], "minis": [d.minis[0]], "roamer": d.roamers[0],
		"landmarks": ["waterfall", "great_tree", "totem_grove"], "landmark_count": 3}, true)
	var isl = _make(n)
	var kinds: Array = isl.places.map(func(pl): return str(pl["kind"]))
	print("places %s" % [isl.places.map(func(pl): return "%s:%s" % [pl["role"], pl["kind"]])])
	check("the caravan camp, the obelisk and the guardians stand in for the waterfall, the great tree and the totem grove %s" % [kinds],
		kinds.has("caravan_camp") and kinds.has("obelisk") and kinds.has("guardians") and not kinds.has("waterfall") and not kinds.has("great_tree"))
	var oases: Array = isl.places.filter(func(pl): return str(pl["kind"]).begins_with("oasis"))
	check("an oasis with room has its pool (%d of %d)" % [oases.size(), (isl.land_plan["oases"] as Array).size()], not oases.is_empty())
	for pl in oases:
		var at: Vector2 = pl["at"]
		var w: float = pl["water"]
		var pr: float = pl["pool"]
		var bed: float = isl.hv(at)
		var banks := INF
		for k in range(12):
			banks = minf(banks, isl.hv(at + Vector2.from_angle(TAU * k / 12.0) * (pr + 2.5)))
		var camp: Vector2 = KL.lp(pl, (pl["camp"] as Vector2).x, (pl["camp"] as Vector2).y)
		var lo := INF
		var hi := -INF
		for k in range(8):
			var h: float = isl.hv(camp + Vector2.from_angle(TAU * k / 8.0) * 4.0)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		check("%s: its bed %.1f m under the water, its banks over it (%.2f m), its camp's ground level (%.2f m), off the paths" % [pl["kind"], w - bed, banks - w, hi - lo],
			w - bed > 1.0 and banks > w + 0.1 and hi - lo < 1.0 and isl.path_dist(at) > pr and isl.path_dist(camp) > 3.0)
	var again = _make(n)
	check("the same node plans the same places and ground", str(again.places) == str(isl.places) and again.heights == isl.heights)
	again.free()
	# built: each place's node, the pool swimmable, the tents, the camels, the monuments solid, the caches
	isl.name = "DesertIsland"
	stage.add_child(isl)
	for s in KL.steps(isl):
		s[1].call()
	for pl in oases:
		var node: Node3D = isl.get_node("Place_" + str(pl["kind"]))
		check("%s built: its pool, its palms solid, its tent, a camel, a lamp, its cache" % pl["kind"], node.get_node_or_null("Pool") != null and float(node.get_node("Pool").radius) > 4.0
			and node.get_node("OasisPalms").get_child_count() > 3 and node.find_children("LongTent*", "", false, false).size() == 1
			and not node.find_children("Camel*", "", false, false).is_empty() and not node.find_children("*", "LootBag", true, false).is_empty())
	var cc: Node3D = isl.get_node("Place_caravan_camp")
	check("the caravan's camp: tents, camels couched at the line, its chest", cc.find_children("LongTent*", "", false, false).size() >= 2
		and cc.find_children("Camel*", "", false, false).size() >= 3 and not cc.find_children("*", "LootBag", true, false).is_empty())
	var ob: Node3D = isl.get_node("Place_obelisk")
	var obb: StaticBody3D = ob.get_node("Obelisk")
	check("the obelisk stands, solid, its fallen twin about", obb.find_children("*", "CollisionShape3D", false, false).size() >= 4 and ob.get_node_or_null("FallenTwin") != null)
	var gd: Node3D = isl.get_node("Place_guardians")
	check("the twin guardians, solid, their gate behind", gd.find_children("Guardian?", "", false, false).size() == 2 and gd.get_node_or_null("GuardianGate") != null)
	isl.queue_free()
	# the set pieces the desert stands in: the ruined skyline, the buried city, the tomb
	for e in [["volcano_vent", "ruined_skyline"], ["sunken_village", "buried_city"], ["cenote", "tomb"]]:
		var n2 := n.duplicate(true)
		n2.merge({"setpiece": e[0], "landmarks": [], "landmark_count": 0}, true)
		var si = _make(n2)
		var pls: Array = si.places.filter(func(pl): return pl["kind"] == e[1])
		check("the desert's %s stands in for the chain's %s %s" % [e[1], e[0], si.places.map(func(pl): return pl["kind"])], pls.size() == 1 and pls[0]["role"] == "theme"
			and not si.places.any(func(pl): return pl["kind"] == e[0]))
		si.name = "SetPieceIsland"
		stage.add_child(si)
		for s in KL.steps(si):
			s[1].call()
		var node: Node3D = si.get_node("Place_" + str(e[1]))
		var solid := node.find_children("*", "CollisionShape3D", true, false).size()
		var chest := not node.find_children("*", "LootBag", true, false).is_empty()
		match e[1]:
			"ruined_skyline":
				check("the skyline: broken towers, a minaret, the great dome torn open, a cache (%d colliders)" % solid, node.get_node_or_null("Skyline") != null
					and node.get_node_or_null("Minaret") != null and node.get_node_or_null("GreatDome") != null and solid > 40 and chest)
			"buried_city":
				var houses := node.find_children("BuriedHouse*", "", false, false)
				var planned: Array = pls[0]["houses"]
				var sunk := houses.size() == planned.size() and planned.all(func(h): return float(h[5]) >= 0.9)
				check("the buried city: %d houses sunk in the sand, a colonnade, a chest" % houses.size(), houses.size() >= 5 and sunk and node.get_node_or_null("BuriedCity") != null and chest)
			"tomb":
				var hall: Node3D = node.get_node("TombHall")
				check("the tomb: its crag solid, its carved front, the hall inside with the treasure and a light", node.get_node_or_null("TombRock") != null
					and node.get_node_or_null("TombFacade") != null and hall.find_children("*", "CollisionShape3D", false, false).size() >= 8 and chest
					and not node.find_children("*", "OmniLight3D", true, false).is_empty())
		si.queue_free()
	return TK.done(fails)
