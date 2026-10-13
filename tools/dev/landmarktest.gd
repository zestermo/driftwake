extends SceneTree
## Generated islands' landmarks and set pieces (KitLandmarks, KitSetPieces):
## the chain gives every island a set piece that never comes twice down a route
## (and not twice in the sea while the pool lasts), the same from the same seed;
## an island built with a waterfall, a great tree and a wreck and a cenote has
## them standing where Island.places says, kept off the village; a captain
## climbs the great tree from the ground to its first deck, swims in the
## waterfall's pool and the cenote, loots the wreck's chest; the summit's tower
## stands over the canopy; the same node plans the same places twice.
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var isl
var fails := 0
var KL
var SP
func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	Input.action_release("move_forward")
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


## Every route through the chain from Brinehollow's sea to its end.
func routes(c) -> Array:
	var out: Array = []
	var todo: Array = []
	for id in c.start_next:
		todo.append([id])
	while not todo.is_empty():
		var r: Array = todo.pop_back()
		var nx: Array = c.node(r[-1])["next"]
		if nx.is_empty():
			out.append(r)
		for id in nx:
			todo.append(r + [id])
	return out


func _process(d: float) -> bool:
	t += d
	if t > 200.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = get_first_node_in_group("player")
			gm = root.get_node("GameManager")
			world = root.get_node("World/Islands")
			if not world.chain_ready():
				return false
			KL = load("res://scripts/island/kit/kit_landmarks.gd")
			SP = load("res://scripts/island/kit/kit_setpieces.gd")
			var C = load("res://scripts/world/chain.gd")
			var route_ok := true
			var sea_ok := true
			var all_set := true
			for s in [777, 31337, 4242, 9, 123456]:
				var c = C.make(s, Vector2(150, 150), Vector2(1, 0))
				var seen := {}
				for n in c.nodes:
					if not SP.POOL.has(n["setpiece"]) or (n["landmarks"] as Array).size() != KL.KINDS.size() or int(n["landmark_count"]) < 1:
						all_set = false
					seen[n["setpiece"]] = true
				if seen.size() != mini(c.nodes.size(), SP.POOL.size()):
					sea_ok = false
					print("   seed %d: %d islands, %d set pieces" % [s, c.nodes.size(), seen.size()])
				for r in routes(c):
					var kinds := {}
					for id in r:
						kinds[c.node(id)["setpiece"]] = true
					if kinds.size() != r.size():
						route_ok = false
						print("   seed %d route %s repeats" % [s, r])
			check("every island has a set piece from the pool, its landmarks' order and how many", all_set)
			var counts := {}
			for s in [777, 31337, 4242, 9, 123456]:
				for nd in C.make(s, Vector2(150, 150), Vector2(1, 0)).nodes:
					counts[int(nd["landmark_count"])] = true
			check("islands run from sparse to packed (landmark counts %s)" % [counts.keys()], counts.size() >= 4)
			check("no set piece comes twice down any route (5 chain seeds)", route_ok)
			check("...nor twice in a sea while the pool lasts", sea_ok)
			var a = C.make(777, Vector2(150, 150), Vector2(1, 0))
			var b = C.make(777, Vector2(150, 150), Vector2(1, 0))
			check("the same chain seed gives the same set pieces (co-op)", a.nodes.map(func(n): return [n["setpiece"], n["landmarks"]]) == b.nodes.map(func(n): return [n["setpiece"], n["landmarks"]]))
			# the first island again, with a waterfall, the great tree and a wreck, and a cenote
			var id: int = world.chain().start_next[0]
			var n: Dictionary = world.chain().node(id)
			n["setpiece"] = "cenote"
			n["landmarks"] = ["waterfall", "great_tree", "wreck", "temple"]
			n["landmark_count"] = 3
			world._free_chain_island(id)
			world.sync_chain_islands()
			set_meta("id", id)
			step = 1
		1:
			var id: int = get_meta("id")
			if not world.chain_ready() or not world.chain_islands.has(id):
				return false
			isl = world.chain_islands[id]
			if isl.is_queued_for_deletion():
				return false
			var kinds: Array = isl.places.map(func(pl): return pl["kind"])
			print("   %s: places %s, built %s" % [isl.island_name, kinds, isl.build_ms])
			check("the island plans its set piece and three landmarks", kinds == ["cenote", "waterfall", "great_tree", "wreck"])
			var stand := true
			var apart := true
			for pl in isl.places:
				var node = isl.get_node_or_null("Place_" + str(pl["kind"]))
				var main: String = {"cenote": "Cenote", "waterfall": "Crag", "great_tree": "GreatTree", "wreck": "WreckHull"}[pl["kind"]]
				if node == null or node.get_node_or_null(main) == null:
					stand = false
					print("   %s missing" % pl["kind"])
				if (pl["at"] as Vector2).distance_to(isl.sites["village"]) < float(pl["r"]) + 58.0 or (pl["at"] as Vector2).distance_to(isl.dock_shore) < float(pl["r"]) + 46.0:
					apart = false
				if not (pl.has("r") and pl.has("door") and pl.has("role") and (pl["keep"] as Array).size() >= 1):
					stand = false
			check("each stands under its Place_ node, with its data (at, r, kind, role, door)", stand)
			check("...clear of the village and the dock", apart)
			var again = load("res://scripts/island/gen_island.gd").new()
			again.prepare(isl.node)
			check("the same node plans the same places and ground", str(again.places) == str(isl.places) and again.heights == isl.heights)
			again.free()
			var th: float = KL.summit_h(isl.theme)
			check("the summit's tower stands over the canopy (%.1f m, canopy %.1f m)" % [th, KL.canopy(isl.theme)], th >= KL.canopy(isl.theme) * 0.8 and th >= 12.0)
			var tower = isl.get_node("Site_summit").find_child("LookoutTower", true, false)
			check("...and is built that tall", tower != null and tower.find_children("*", "Ladder", true, false).size() == 2)
			# the great tree: from the ground up its first ladder
			var tree = isl.get_node("Place_great_tree")
			var lads: Array = tree.find_children("*", "Ladder", true, false)
			check("the great tree has ladders up its decks and down a satellite (%d)" % lads.size(), lads.size() == 4)
			check("...rope bridges to two satellites and grapple crowns", tree.find_child("Sapling1", true, false) != null)
			var lad = lads[0]
			set_meta("lad", lad)
			p.state_machine.force_state("Idle", {})
			p.global_position = lad.to_global(Vector3(0, -lad.length + 0.3, 0.7))
			p.reset_physics_interpolation()
			wait = 0.8
			step = 2
		2:
			var lad = get_meta("lad")
			check("a captain at the ladder's foot stands on the ground", p.is_on_floor())
			lad.interactable.interacted.emit(p)
			check("...and grabs on from the ground", p.current_state_name() == "Climb")
			Input.action_press("move_forward")
			set_meta("top_y", lad.global_position.y)
			set_meta("t_climb", t)
			step = 7
		7:
			if t - float(get_meta("t_climb")) < 7.0:
				return false
			step = 3
		3:
			Input.action_release("move_forward")
			var top_y: float = get_meta("top_y")
			check("...and climbs up onto the first deck (%.1f m, deck %.1f m)" % [p.global_position.y, top_y], p.current_state_name() != "Climb" and absf(p.global_position.y - top_y) < 0.6)
			# into the waterfall's pool
			var wf: Dictionary = isl.places.filter(func(pl): return pl["kind"] == "waterfall")[0]
			var c: Vector2 = wf["at"]
			var wy: float = isl.to_global(Vector3(0, float(wf["water"]), 0)).y
			var oc = root.get_node("Ocean")
			check("the pool counts as water (surface %.2f, pool %.2f)" % [oc.surface_at(isl.to_global(Vector3(c.x, 0, c.y))), wy], absf(float(oc.surface_at(isl.to_global(Vector3(c.x, 0, c.y)))) - wy) < 0.01)
			p.state_machine.force_state("Fall", {})
			p.global_position = isl.to_global(Vector3(c.x - 1.0, float(wf["water"]) + 1.5, c.y))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			wait = 1.5
			step = 4
		4:
			check("a captain dropped in the waterfall's pool swims", p.is_swimming())
			var cn: Dictionary = isl.places.filter(func(pl): return pl["kind"] == "cenote")[0]
			var c: Vector2 = cn["at"]
			p.state_machine.force_state("Fall", {})
			p.global_position = isl.to_global(Vector3(c.x + 2.0, float(cn["y"]) - 8.0, c.y + 2.0))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			wait = 2.0
			step = 5
		5:
			check("...and in the cenote", p.is_swimming())
			# the wreck's chest
			var key: String = isl.save_key("wreck_chest")
			var bags: Array = isl.find_children("*", "LootBag", true, false).filter(func(b): return b.save_id == key)
			check("the wreck has a chest in her hold, kept in the save as %s" % key, bags.size() == 1)
			if bags.size() == 1:
				var gold0: int = p.inventory_component.count("gold")
				bags[0].take_all(p)
				check("...it opens: gold and treasure into the bag", p.inventory_component.count("gold") > gold0 and gm.opened.has(key))
				gm.opened.erase(key)
			var keys := ["falls_chest", "tree_chest", "cenote_chest"]
			var all := true
			for k in keys:
				if not isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == isl.save_key(k)):
					all = false
			check("chests behind the falls, in the tree's lookout and in the cenote", all)
			check("each place is overgrown round its footprint", isl.places.all(func(pl): return isl.get_node("Place_" + str(pl["kind"])).get_node_or_null("Overgrowth") != null))
			# the island again with the rest of the pool and the giant nest
			var id: int = get_meta("id")
			var n: Dictionary = world.chain().node(id)
			n["setpiece"] = "giant_nest"
			n["landmarks"] = ["watchtower", "sky_wreck", "totem_grove", "hermit_hut", "mine", "aqueduct", "gorge_bridge"]
			n["landmark_count"] = 7
			world._free_chain_island(id)
			world.sync_chain_islands()
			step = 6
		6:
			var id: int = get_meta("id")
			if not world.chain_ready() or not world.chain_islands.has(id) or world.chain_islands[id] == isl:
				return false
			isl = world.chain_islands[id]
			var main := {"giant_nest": "Spire", "watchtower": "Watchtower", "sky_wreck": "SkyGondola", "totem_grove": "Totems",
				"hermit_hut": "HermitHut", "mine": "Mine", "aqueduct": "Aqueduct", "gorge_bridge": "Gorge"}
			var kinds: Array = isl.places.map(func(pl): return pl["kind"])
			print("   %s: places %s, built %s" % [isl.island_name, kinds, isl.build_ms])
			check("the rest of the pool plans on one island (%d of 8)" % kinds.size(), kinds.size() >= 6)
			var stand := true
			for pl in isl.places:
				var node = isl.get_node_or_null("Place_" + str(pl["kind"]))
				if node == null or node.find_child(main[pl["kind"]], true, false) == null:
					stand = false
					print("   %s missing" % pl["kind"])
			check("...and each stands", stand)
			var tw: Array = isl.places.filter(func(pl): return pl["kind"] == "watchtower")
			if not tw.is_empty():
				var tower = isl.get_node("Place_watchtower")
				check("the watchtower has a ladder to every floor", tower.find_children("*", "Ladder", true, false).size() == load("res://scripts/island/kit/kit_wilds.gd").tower_floors(tw[0]).size())
			finish()
	return false
