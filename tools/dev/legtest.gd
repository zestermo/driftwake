extends SceneTree
## Sea legs (SeaLegs): once the log pose points on, each leg to the next
## island(s) gets a pirate fleet for that island's level, hazards, finds and
## sometimes a Sea King, laid out the same from the same seed and kept off the
## islands; the hazards answer SeaFeatures' queries and keep enemy ships off;
## finds opened stay opened; arriving lets the legs go, the log pose setting
## there lays out the next ones; a new chain lays out its own.
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var legs
var fails := 0
func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


## Every spot a leg's plan puts something.
func spots(lay: Dictionary) -> Array:
	var out: Array = []
	for k in ["zones", "reefs", "fogs", "whirls", "storms", "wrecks"]:
		for e in lay[k]:
			out.append(e[0])
	for k in ["bottles", "islets"]:
		out.append_array(lay[k])
	if lay["king"] != Vector2.INF:
		out.append(lay["king"])
	return out


## Every leg of the chain, planned.
func all_plans() -> Array:
	var c = world.chain()
	var out: Array = []
	for id in c.start_next:
		out.append(legs.plan(-1, id))
	for n in c.nodes:
		for id in n["next"]:
			out.append(legs.plan(int(n["id"]), id))
	return out


func _process(d: float) -> bool:
	t += d
	if t > 150.0:
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
			legs = get_first_node_in_group("sea_legs")
			var c = world.chain()
			if legs.built.size() < c.start_next.size():
				return false
			# the fleets' first ships wait for their crews' bodies
			for leg in legs.built.values():
				var fl = leg.get_node("Fleet")
				if fl.ships().size() < fl.zones.size() and t < 60.0:
					return false
			var want: Array = c.start_next.map(func(id): return Vector2i(-1, id))
			check("from Brinehollow, a leg to each island the log pose points at (%d)" % legs.built.size(), legs.built.keys().size() == want.size() and want.all(func(k): return legs.built.has(k)))
			var levels_ok := true
			var kinds_ok := true
			var ships_ok := true
			var zones_ok := true
			for k in legs.built.keys():
				var leg = legs.built[k]
				var lay: Dictionary = leg.get_meta("plan")
				var lvl := int(c.node(k.y)["level"])
				var fl = leg.get_node("Fleet")
				print("   leg %s (Lv %d, %.0f m): %d fleet zones %s, %d reefs, %d fogs, %d whirlpools, %d storms, king %s, %d wrecks, %d bottles, %d islets" % [k, lvl,
					world.starter_center.distance_to(c.node(k.y)["pos"]), fl.zones.size(), fl.zones.map(func(z): return z["kinds"]), lay["reefs"].size(), lay["fogs"].size(),
					lay["whirls"].size(), lay["storms"].size(), lay["king"] != Vector2.INF, lay["wrecks"].size(), lay["bottles"].size(), lay["islets"].size()])
				if fl.zones.size() < 1 or fl.zones.size() > 2:
					zones_ok = false
				for i in range(fl.zones.size()):
					if int(fl.zones[i]["level"]) != lvl:
						levels_ok = false
					if not legs._kinds(lvl).has(fl.zones[i]["kinds"]):
						kinds_ok = false
				if fl.ships().size() != fl.zones.size():
					ships_ok = false
				for s in fl.ships():
					if int(s.level) != lvl:
						levels_ok = false
				check("leg %s is laid out the same again from the same seed" % k, legs.plan(k.x, k.y) == lay)
			check("each leg has 1-2 pirate fleet zones", zones_ok)
			check("...each and its ship carrying the next island's level", levels_ok)
			check("...with ships of the kinds for that level", kinds_ok)
			check("...and a ship sailing each zone", ships_ok)
			# every leg of the chain: off the islands and Brinehollow, on deep water
			var plans := all_plans()
			var off := true
			var deep := true
			var empty := 0
			var bare := 0
			var kings := 0
			var hazards := 0
			var finds := 0
			for lay in plans:
				var a: Vector2 = world.starter_center if int(lay["from"]) < 0 else c.node(lay["from"])["pos"]
				print("   %d -> %d: %.0f m, Lv %d: %d zones, %d hazards, %d finds, king %s" % [lay["from"], lay["to"], a.distance_to(c.node(lay["to"])["pos"]), lay["level"], lay["zones"].size(),
					lay["reefs"].size() + lay["fogs"].size() + lay["whirls"].size() + lay["storms"].size(), lay["wrecks"].size() + lay["bottles"].size() + lay["islets"].size(), lay["king"] != Vector2.INF])
				if lay["zones"].is_empty():
					empty += 1
				if spots(lay).size() == lay["zones"].size():
					bare += 1
				if lay["king"] != Vector2.INF:
					kings += 1
				hazards += lay["reefs"].size() + lay["fogs"].size() + lay["whirls"].size() + lay["storms"].size()
				finds += lay["wrecks"].size() + lay["bottles"].size() + lay["islets"].size()
				for q in spots(lay):
					if q.distance_to(world.starter_center) < legs.HOME_CLEAR:
						off = false
					for n in c.nodes:
						if q.distance_to(n["pos"]) < legs.ISLE_CLEAR:
							off = false
					if world.height_at(q.x, q.y) > -12.0:
						deep = false
			print("   the chain's %d legs: %d without a fleet, %d hazards, %d finds, %d Sea Kings" % [plans.size(), empty, hazards, finds, kings])
			check("every leg of the chain has pirates", empty == 0)
			check("...hazards and finds along them (%d, %d), something besides the pirates on each (%d bare)" % [hazards, finds, bare], hazards >= plans.size() and finds >= plans.size() * 3 / 2 and bare == 0)
			check("...and a Sea King on some (%d of %d)" % [kings, plans.size()], kings > 0 and kings < plans.size())
			check("everything on them keeps %.0f m from every chain island's centre and %.0f m from Brinehollow's" % [legs.ISLE_CLEAR, legs.HOME_CLEAR], off)
			check("...on deep water", deep)
			# the hazards count in SeaFeatures' queries and keep the pirates off
			var sf = get_first_node_in_group("sea_features")
			var lay_all: Array = legs.built.values().map(func(l): return l.get_meta("plan"))
			var reef_ok := true
			var whirl_ok := true
			var fog_ok := true
			var nogo_ok := true
			var NG = load("res://scripts/ship/enemy_ship.gd")
			for lay in lay_all:
				for r in lay["reefs"]:
					var q: Vector2 = r[0]
					reef_ok = reef_ok and sf.reef_at(Vector3(q.x, 0, q.y)) and NG.no_go.any(func(z): return z[0] == q)
				for w in lay["whirls"]:
					var q: Vector2 = w[0]
					whirl_ok = whirl_ok and sf.current_at(Vector3(q.x + 15.0, 0, q.y)).length() > 1.0 and NG.no_go.any(func(z): return z[0] == q)
				for f in lay["fogs"]:
					var q: Vector2 = f[0]
					fog_ok = fog_ok and sf.local_weather(Vector3(q.x, 0, q.y)).y > 0.5
				for i in range(lay["wrecks"].size()):
					nogo_ok = nogo_ok and NG.no_go.any(func(z): return z[0] == lay["wrecks"][i][0])
			check("its reefs scrape a hull (SeaFeatures.reef_at) and ships keep off them", reef_ok)
			check("its whirlpools pull and ships keep off them", whirl_ok)
			check("its fog banks close in", fog_ok)
			check("its wrecks are kept clear by enemy ships", nogo_ok)
			# the finds: chests with save keys, bottles to fish out
			var bags: Array = []
			var bottles: Array = []
			for leg in legs.built.values():
				bags.append_array(leg.find_children("*", "LootBag", true, false))
				bottles.append_array(leg.get_meta("bottles"))
			var lay_wrecks := 0
			var lay_islets := 0
			for lay in lay_all:
				lay_wrecks += lay["wrecks"].size()
				lay_islets += lay["islets"].size()
			check("a chest on each wreck and islet (%d), kept in the save by its leg" % bags.size(), bags.size() == lay_wrecks + lay_islets and bags.all(func(b): return str(b.save_id).begins_with("leg-1_")))
			var islet_ok := true
			for leg in legs.built.values():
				for isl in leg.find_children("Islet*", "StaticBody3D", false, false):
					var ch = isl.get_node("Chest")
					islet_ok = islet_ok and ch.global_position.y > 1.0 and isl.find_children("*", "CollisionShape3D", false, false).size() == 1
			check("an islet stands out of the sea with its chest on top", islet_ok)
			if not bottles.is_empty():
				var b = bottles[0]
				var g0: int = p.inventory_component.count("gold")
				b.get_node("Grab").interacted.emit(p)
				check("a bottle fished out gives its coins (%d) and is read" % (p.inventory_component.count("gold") - g0), p.inventory_component.count("gold") > g0 and gm.opened.has(b.get_meta("save_id")) and not b.visible)
			set_meta("plans", lay_all)
			# a chest opened stays opened when its leg is laid out again
			if not bags.is_empty():
				set_meta("box", bags[0].save_id)
				gm.opened[bags[0].save_id] = true
			set_meta("bottle", bottles[0].get_meta("save_id") if not bottles.is_empty() else "")
			for k in legs.built.keys():
				legs._free_leg(k)
			legs.sync_legs()
			wait = 0.2
			step = 1
		1:
			var c = world.chain()
			if has_meta("box"):
				var again: Array = []
				for leg in legs.built.values():
					again.append_array(leg.find_children("*", "LootBag", true, false).filter(func(b): return not b.is_queued_for_deletion()))
				check("a chest opened before is gone when its leg is laid out again", not again.any(func(b): return b.save_id == get_meta("box")))
				gm.opened.erase(get_meta("box"))
			if get_meta("bottle") != "":
				var left: Array = []
				for leg in legs.built.values():
					left.append_array(leg.get_meta("bottles"))
				check("...and a bottle read is gone", not left.any(func(b): return b.get_meta("save_id") == get_meta("bottle")))
			# arriving at the first island: the legs behind go
			var at: int = c.start_next[0]
			gm.apply_chain(at, false, root.get_node("Weather").world_time())
			legs.sync_legs()
			var NG = load("res://scripts/ship/enemy_ship.gd")
			var gone := true
			for lay in get_meta("plans"):
				for r in lay["reefs"] + lay["whirls"]:
					if NG.no_go.any(func(z): return z[0] == r[0]):
						gone = false
			check("arrived: the legs there are let go (%d left)" % legs.built.size(), legs.built.is_empty() and legs.reefs.is_empty() and legs.whirls.is_empty() and legs.storms.is_empty() and legs.fogs.is_empty())
			check("...their hazards no longer kept clear by enemy ships", gone)
			check("...and nothing laid out ahead while the log pose hasn't set", legs.wanted().is_empty())
			wait = 0.3
			step = 2
		2:
			check("...their nodes freed (fleets, ships, finds)", legs.get_child_count() == 0 and get_nodes_in_group("enemy_ships").all(func(s): return not str(s.get_path()).contains("SeaLegs")))
			# 15 minutes on, the log pose sets: the legs on are laid out
			gm.chain_since = root.get_node("Weather").world_time() - gm.LOG_SET_TIME - 1.0
			legs.sync_legs()
			var c = world.chain()
			var at: int = gm.chain_at
			var want: Array = c.next_of(at).map(func(id): return Vector2i(at, id))
			check("the log pose set: a leg to each island on (%d)" % want.size(), legs.built.size() == want.size() and want.all(func(k): return legs.built.has(k)))
			var lv := true
			for k in legs.built.keys():
				for z in legs.built[k].get_node("Fleet").zones:
					if int(z["level"]) != int(c.node(k.y)["level"]):
						lv = false
			check("...their fleets at the level of the islands they lead to (%s)" % str(c.next_of(at).map(func(id): return c.node(id)["level"])), lv)
			# a new chain: its own legs
			set_meta("old", legs.built.values()[0].get_meta("plan"))
			gm.chain_seed = int(gm.chain_seed) + 1
			gm.apply_chain(-1, false, 0.0)
			legs.sync_legs()
			var c2 = world.chain()
			check("another chain loads: its own legs from Brinehollow", legs.built.size() == c2.start_next.size() and c2.start_next.all(func(id): return legs.built.has(Vector2i(-1, id))))
			check("...laid out differently", legs.built.values()[0].get_meta("plan")["zones"] != get_meta("old")["zones"])
			finish()
	return false
