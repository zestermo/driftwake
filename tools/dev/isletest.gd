extends SceneTree
## Generated chain islands (GenIsland): the islands the log pose points at
## stand at their chain spots (land above the sea in the middle, a coast, deep
## water off the pier's head, the sites on land and apart); a captain stands
## on the ground there; trees with colliders and grapple crowns, the shallows
## sent to the ocean, the island charted and kept clear by enemy ships; the
## same node builds the same island twice; moving on along the chain frees the
## islands left behind and builds the next.
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var fails := 0
func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
func _process(d: float) -> bool:
	t += d
	if t > 90.0:
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
			var c = world.chain()
			if not world.chain_ready():
				return false
			check("the islands the log pose points at stand in the world (%d)" % world.chain_islands.size(), world.chain_islands.size() == c.start_next.size())
			var isl = world.chain_islands[c.start_next[0]]
			var n: Dictionary = c.node(c.start_next[0])
			print("   %s: r %.0f, built %s" % [isl.island_name, isl.radius, isl.build_ms])
			check("at its chain spot", Vector2(isl.position.x, isl.position.z) == n["pos"] and isl.island_name == n["name"])
			check("600-900 m across", isl.radius >= 300.0 and isl.radius <= 450.0)
			var mid_land := false
			for k in range(12):
				var q := Vector2.from_angle(k * TAU / 12.0) * 40.0
				if isl.height_at(q.x, q.y) > 2.0:
					mid_land = true
			check("land above the sea in the middle", mid_land)
			var sea_round := true
			for k in range(16):
				var q: Vector2 = Vector2.from_angle(k * TAU / 16.0) * (isl.radius + 30.0)
				if isl.height_at(q.x, q.y) > -2.0:
					sea_round = false
			check("sea all round past its radius", sea_round)
			var de: Vector2 = isl.sites["dock_end"]
			check("deep water off the pier's head (%.1f m)" % isl.height_at(de.x, de.y), isl.height_at(de.x, de.y) < -3.5)
			check("a pier to board from", isl.find_child("DockingArea", true, false) != null)
			var on_land := true
			var apart := true
			for s in ["village", "boss", "camp", "lair", "ruins", "summit"]:
				var sp: Vector2 = isl.sites[s]
				if isl.height_at(sp.x, sp.y) < 1.5:
					on_land = false
					print("   %s at %s, h %.1f" % [s, sp, isl.height_at(sp.x, sp.y)])
				for s2 in ["village", "boss", "camp", "lair", "ruins"]:
					if s2 != s and sp.distance_to(isl.sites[s2]) < 50.0:
						apart = false
			check("its sites (village, boss, camp, lair, ruins, summit) are on land", on_land)
			check("...and well apart", apart)
			check("paths from the village to each", isl.paths.size() == 6)
			var trees: int = isl.get_node("VegetationColliders").get_child_count()
			check("trees and rocks with colliders (%d)" % trees, trees > 500)
			check("grapple crowns in the trees", load("res://scripts/world/grapple_points.gd").count() > 1000)
			check("the shallows are sent to the ocean", root.get_node("Ocean").isle_shoals.size() == mini(world.chain_islands.size(), 2))
			check("on the chart's list", world.island_infos.any(func(i): return i["name"] == isl.island_name))
			check("enemy ships keep off it", load("res://scripts/ship/enemy_ship.gd").no_go.any(func(z): return z[0] == n["pos"]))
			# the same node builds the same island
			var again = load("res://scripts/island/gen_island.gd").new()
			again.prepare(n)
			check("the same node builds the same island", again.heights == isl.heights and again.sites == isl.sites)
			again.free()
			# the sites' content
			var crew = isl.get_node("Site_camp/Camp")
			var cap = crew.grunts.filter(func(g): return g.captain)
			print("   camp: %d grunts, %s" % [crew.grunts.size(), cap[0].title if not cap.is_empty() else "no captain"])
			check("a pirate camp with a crew of 6 and a named captain", crew.grunts.size() == 6 and cap.size() == 1 and str(cap[0].title).begins_with("Captain "))
			var key: String = isl.save_key("camp_box")
			check("...and his strongbox, kept in the save as %s" % key, isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == key))
			var burrows = isl.get_node("Site_lair/Burrows")
			var roosts = isl.get_node("Site_lair/Roosts")
			print("   lair: %d burrows, %d spitters" % [burrows.spots.size(), roosts.spots.size()])
			check("a bug lair: 7 burrows (some big) and spitters in the trees", burrows.spots.size() == 7 and burrows.spots.any(func(sp): return sp["big"]) and roosts.spots.size() >= 1)
			check("...on their hoard", isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == isl.save_key("lair_hoard")))
			check("ruins with a chest", isl.get_node("Site_ruins").get_child_count() > 8 and isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == isl.save_key("ruins_chest")))
			var summit_box = isl.find_children("*", "LootBag", true, false).filter(func(b): return b.save_id == isl.save_key("summit_chest"))
			var sp: Vector2 = isl.sites["summit"]
			check("a lookout on the summit, a chest on its platform", summit_box.size() == 1 and summit_box[0].global_position.y - isl.to_global(Vector3(sp.x, isl.height_at(sp.x, sp.y), sp.y)).y > 5.0)
			var bk = world.get_node("NavBaker")
			check("the camp gets a navmesh zone", bk._zones.any(func(z): return z["node"] == isl.get_node("Site_camp")))
			var trees_in_camp := 0
			for cs in isl.get_node("VegetationColliders").get_children():
				var q := Vector2(cs.position.x, cs.position.z)
				if q.distance_to(isl.sites["camp"]) < 15.0 or q.distance_to(isl.sites["village"]) < 25.0:
					trees_in_camp += 1
			check("no trees or rocks in the middle of the camp or the village (%d)" % trees_in_camp, trees_in_camp == 0)
			# the village
			var vil = isl.get_node("Site_village/Village")
			var npcs: Array = get_nodes_in_group("npcs").filter(func(x): return x.get_parent() == isl)
			print("   village: %s, %d people, jobs %s" % [vil.elder_name, npcs.size(), vil.jobs.keys()])
			check("a village of stilt huts round a plaza, an inn among them", isl.get_node("Site_village").find_children("*", "StaticBody3D", true, false).size() >= 6 and isl.find_child("Inn", true, false) != null)
			check("its elder, innkeeper, trader, cook and a few villagers", npcs.size() >= 6 and npcs.any(func(x): return x.dialogue_id == isl.save_key("elder")))
			var shops = load("res://scripts/game/shops.gd")
			check("a trader and a cook to buy from (at the island's tier)", shops.extra.has(isl.save_key("trader")) and shops.extra.has(isl.save_key("cook"))
				and npcs.any(func(x): return x.shop_id == isl.save_key("trader")) and str(shops.extra[isl.save_key("trader")]["stock"][2][0]).contains("@"))
			var dlg = root.get_node("Dialogue")
			check("a job board: the camp's captain and the bug lair", dlg._load(isl.save_key("board"))["nodes"].has("camp") and dlg._load(isl.save_key("board"))["nodes"].has("lair"))
			check("the elder's talk: the island, the way on, pay for jobs done", dlg._load(isl.save_key("elder"))["nodes"].has("beyond") and dlg._load(isl.save_key("elder"))["nodes"].has("pay_camp"))
			# take the captain's bounty, then he falls
			dlg.set_flag(vil._flag("camp", "taken"))
			var capt = isl.get_node("Site_camp/Camp").grunts.filter(func(g): return g.captain)[0]
			capt.health.take_damage(999999.0)
			set_meta("gold0", p.inventory_component.count("gold"))
			set_meta("vil", vil)
			# a captain on the ground at the village
			var v: Vector2 = isl.sites["village"]
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.to_global(Vector3(v.x, isl.height_at(v.x, v.y) + 1.5, v.y))
			p.reset_physics_interpolation()
			set_meta("isl", isl)
			wait = 1.5
			step = 1
		1:
			var isl = get_meta("isl")
			var v: Vector2 = isl.sites["village"]
			var ground: float = isl.to_global(Vector3(v.x, isl.height_at(v.x, v.y), v.y)).y
			check("a captain stands on its ground (%.2f m over)" % (p.global_position.y - ground), p.is_on_floor() and absf(p.global_position.y - ground) < 0.6)
			var vil = get_meta("vil")
			var dlg = root.get_node("Dialogue")
			check("the bounty taken and the captain dead: the job's done", dlg.has_flag(vil._flag("camp", "done")))
			dlg.dialogue_event.emit("isle_job:%s:pay" % isl.save_key("camp"))
			var paid: int = p.inventory_component.count("gold") - int(get_meta("gold0"))
			check("the elder pays the bounty (%d gold)" % paid, paid == int(vil.jobs["camp"]["gold"]))
			p.health_component.current_health = 10.0
			isl.find_child("Rest", true, false).interacted.emit(p)
			check("a rest at the inn heals", p.health_component.current_health == p.health_component.max_health)
			# arriving: a captain on the island - the crew's there now
			var c = world.chain()
			var at: int = c.start_next[0]
			check("standing on the island, the crew is there now (the chain moves on)", gm.chain_at == at)
			check("...the fork's other side let go", c.start_next.filter(func(id): return id != at).all(func(id): return not world.chain_islands.has(id)))
			check("...and the log pose hasn't set: nothing ahead yet", gm.log_pose_targets().is_empty() and c.next_of(at).all(func(id): return not world.chain_islands.has(id)))
			check("...the HUD says how long (%.0f s)" % gm.log_pose_wait(), gm.log_pose_wait() > gm.LOG_SET_TIME - 10.0)
			# 15 minutes later it sets by itself and the next island(s) are built
			gm.chain_since = root.get_node("Weather").world_time() - gm.LOG_SET_TIME - 1.0
			step = 2
		2:
			var c = world.chain()
			var at: int = gm.chain_at
			if not world.chain_ready():
				return false
			check("15 minutes on, the log pose sets on the next island(s)", gm.log_pose_targets().size() == c.next_of(at).size())
			check("...which are built ahead, the one we're at kept", world.chain_islands.has(at) and c.next_of(at).all(func(id): return world.chain_islands.has(id)))
			check("...and the chart's list follows", world.island_infos.size() == world.chain_islands.size())
			# a chest opened stays gone when its island is built again
			var isl = world.chain_islands[at]
			set_meta("box", isl.save_key("camp_box"))
			gm.opened[get_meta("box")] = true
			world._free_chain_island(at)
			step = 3
		3:
			var at: int = gm.chain_at
			if not world.chain_islands.has(at):
				world.sync_chain_islands()
				return false
			if wait <= 0.0 and not has_meta("waited"):
				set_meta("waited", true)
				wait = 0.2
				return false
			var isl = world.chain_islands[at]
			check("a chest opened before is gone when its island is built again", not isl.find_children("*", "LootBag", true, false).any(func(b): return b.save_id == get_meta("box") and not b.is_queued_for_deletion()))
			gm.opened.erase(get_meta("box"))
			# freshly arrived again; its beast falls: the log pose sets at once
			gm.apply_chain(at, false, root.get_node("Weather").world_time())
			check("(arrived afresh: unset again)", not gm.log_pose_set())
			isl.get_node("Site_boss/Arena").boss.health.take_damage(999999.0)
			wait = 1.0
			step = 4
		4:
			check("its beast slain, the log pose sets", gm.chain_set and gm.log_pose_set())
			# saved and loaded back
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://isletest")
			SG.slot = 1
			SG.save(p)
			var since: float = gm.chain_since
			gm.chain_set = false
			gm.chain_since = 0.0
			SG.load_into(p)
			check("...kept in the save", gm.chain_set and is_equal_approx(gm.chain_since, since))
			gm.apply_chain(-1, false, 0.0)
			finish()
	return false
