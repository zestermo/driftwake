extends SceneTree
## Generated villages (IslandVillage, VillageLayouts): every layout in the pool built on
## one chain island in turn (town, hamlets, post, stilts, ruins). Each keeps its services
## (the inn and its rest, a walk-in store and cookhouse with their keepers behind the
## counter, the elder, the job board), has houses and dressing, lights within the budget,
## the data villagers' routines read (streets, buildings, work spots, seats), and its own
## pieces: the post's palisade and gates, the raised deck you can stand on, the ruins'
## burrows and caches, the hamlets apart. The same node plans the same village twice.
var t := 0.0
var step := 0
var wait := 0
var fails := 0
var world
var n: Dictionary
var layouts: Array = []
var li := 0
var isl
const L := "res://scripts/island/village_layouts.gd"


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	load(L).force = ""
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func _process(d: float) -> bool:
	t += d
	if t > 220.0:
		check("timed out at step %d (%s)" % [step, layouts[li] if li < layouts.size() else "-"], false)
		finish()
		return true
	if wait > 0:
		wait -= 1
		return false
	match step:
		0:
			world = root.get_node_or_null("World/Islands")
			if t < 1.5 or world == null or not world.chain_ready():
				return false
			world.set_process(false)
			var c = world.chain()
			n = c.node(c.start_next[0])
			layouts = load(L).POOL.keys()
			# the same node plans the same village (a guest builds what the host does)
			var a = load("res://scripts/island/gen_island.gd").new()
			var b = load("res://scripts/island/gen_island.gd").new()
			a.prepare(n)
			b.prepare(n)
			check("the same node plans the same village (%s)" % a.village_plan["layout"], str(a.village_plan) == str(b.village_plan) and a.paths == b.paths)
			a.free()
			b.free()
			step = 1
		1:
			if li >= layouts.size():
				finish()
				return true
			load(L).force = layouts[li]
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "VillageTestIsle"
			isl.position = Vector3(n["pos"].x, 0.0, n["pos"].y)
			world.add_child(isl)
			isl.build(n)
			wait = 3
			step = 2
		2:
			_check_layout(layouts[li])
			isl.queue_free()
			isl = null
			li += 1
			wait = 2
			step = 1
	return false


func _check_layout(kind: String) -> void:
	var vil = isl.get_node("Site_village/Village")
	var b: Array = vil.buildings
	var kinds: Array = b.map(func(x): return x["kind"])
	print("   %s: %d buildings %s, %d streets, %d lanes, %d hamlets, %d work spots, %d seats, %d NightLights" % [kind, b.size(), kinds,
		vil.streets.size(), vil.lanes.size(), vil.hamlets.size(), vil.work_spots.size(), vil.seats.size(), isl.find_children("*", "NightLight", true, false).size()])
	check("%s: the layout asked for" % kind, vil.layout == kind)
	check("%s: the inn, the store, the cookhouse and the elder's house" % kind, ["inn", "trade", "cook", "elder"].all(func(k): return kinds.has(k)))
	check("%s: a rest at the inn and a job board" % kind, isl.find_child("Rest", true, false) != null and isl.get_node("Site_village").find_children("NoticeBoard*", "", true, false).size() >= 1)
	var npcs: Array = get_nodes_in_group("npcs").filter(func(x): return x.get_parent() == isl)
	var trader = npcs.filter(func(x): return x.shop_id == isl.save_key("trader"))
	var cook = npcs.filter(func(x): return x.shop_id == isl.save_key("cook"))
	check("%s: the elder, the innkeeper, the keepers and villagers (%d)" % [kind, npcs.size()], npcs.size() >= 6 and npcs.any(func(x): return x.dialogue_id == isl.save_key("elder")) and trader.size() == 1 and cook.size() == 1)
	var shop = b.filter(func(x): return x["kind"] == "trade")[0]
	var floor_y: float = shop["floor_y"]
	var ground: float = isl.height_at(shop["inside"].x, shop["inside"].y)
	check("%s: the trader stands inside, on the store's floor (%.2f over the ground)" % [kind, floor_y - ground],
		floor_y > ground + 0.3 and absf(trader[0].position.y - floor_y) < 0.05 and Vector2(trader[0].position.x, trader[0].position.z).distance_to(shop["inside"]) < 3.5)
	var space: PhysicsDirectSpaceState3D = isl.get_world_3d().direct_space_state
	var down := func(p: Vector2, from_y: float) -> float:
		var q := PhysicsRayQueryParameters3D.create(isl.to_global(Vector3(p.x, from_y, p.y)), isl.to_global(Vector3(p.x, from_y - 12.0, p.y)), 1)
		var hit := space.intersect_ray(q)
		return isl.to_local(hit["position"]).y if hit else -INF
	var in_y: float = down.call(shop["inside"], floor_y + 0.5)
	check("%s: the store's floor is solid inside (%.2f)" % [kind, in_y - floor_y], absf(in_y - floor_y) < 0.1)
	check("%s: houses enough (%d)" % [kind, b.size()], b.size() >= (10 if kind == "post" or kind == "hamlets" else 14))
	check("%s: its streets, work spots and seats for villagers" % kind, vil.streets.size() >= 2 and vil.work_spots.size() >= 8 and vil.seats.size() >= 2
		and vil.work_spots.all(func(s): return s.has_all(["kind", "at", "face", "y", "taken"])))
	check("%s: NightLights within the budget" % kind, isl.find_children("*", "NightLight", true, false).size() <= vil.LIGHTS)
	check("%s: dressed (cargo instanced, washing, gardens, lamps or torches)" % kind, isl.get_node("Site_village").find_children("Cargo", "", true, false).size() == 1
		and isl.find_children("Torch*", "", true, false).size() + isl.find_children("LanternPost*", "", true, false).size() >= 3)
	match kind:
		"post":
			check("post: a palisade with a gate on every road in and watchtowers", isl.find_children("Palisade", "", true, false).size() == 1
				and isl.find_children("Gate*", "", true, false).size() >= 2 and isl.find_children("LookoutTower*", "", true, false).size() >= 2)
			var market: Dictionary = vil.market
			check("post: the market in the middle of the walls", not market.is_empty() and (market["c"] as Vector2).distance_to(isl.sites["village"]) < 1.0)
		"stilts":
			var c: Vector2 = vil.plaza["c"]
			var deck_y: float = vil.plaza["y"]
			check("stilts: a deck you can stand on over the plaza (%.2f)" % (down.call(c + Vector2(3.0, 2.0), deck_y + 2.0) - deck_y), absf(down.call(c + Vector2(3.0, 2.0), deck_y + 2.0) - deck_y) < 0.1)
			var w: Dictionary = vil.walkways[0]
			var mid: Vector2 = (w["a"] + w["b"]) * 0.5
			check("stilts: walkways out to the houses at the deck's height", vil.walkways.size() >= 5 and absf(down.call(mid, deck_y + 2.0) - deck_y) < 0.1)
			check("stilts: ramps down", isl.find_children("Ramp*", "", true, false).size() >= 1)
		"ruins":
			var nest = isl.get_node("Site_village/Burrows")
			check("ruins: bugs in the old plaza and caches in the houses", nest.spots.size() >= 3 and isl.find_children("*", "LootBag", true, false).any(func(x): return str(x.save_id).begins_with(isl.save_key("village_cache"))))
			check("ruins: the old houses are ruins, the survivors' hamlet apart from them", kinds.count("ruin") >= 8 and vil.hamlets.size() == 1
				and (vil.hamlets[0]["c"] as Vector2).distance_to(isl.sites["village"]) > 40.0)
		"hamlets":
			check("hamlets: two or more hamlets away from the hub", vil.hamlets.size() >= 3 and vil.hamlets.slice(1).all(func(h): return (h["c"] as Vector2).distance_to(isl.sites["village"]) > 60.0))
		"town":
			check("town: lanes off the plaza, a market and a shrine", vil.lanes.size() >= 1 and not vil.market.is_empty() and kinds.has("shrine"))
