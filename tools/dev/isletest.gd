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
			var rocks = isl.get_node_or_null("CoastRocks")
			var rock_faces := 0
			if rocks:
				for cs in rocks.find_children("*", "CollisionShape3D", false, false):
					rock_faces += cs.shape.get_faces().size()
			check("sea cliffs: a rock wall along them with a collider (%d columns, %d faces)" % [isl.coast_cols.size(), rock_faces / 3],
				isl.coast_cols.size() > 10 and rocks != null and rocks.find_children("*", "MeshInstance3D", false, false).size() > 0 and rock_faces > 0)
			var cliff_ok := true
			for col in isl.coast_cols:
				var land: Vector2 = col[0] - col[2] * 3.0
				if isl.height_at(land.x, land.y) < 1.0:
					cliff_ok = false
			check("...along the land's edge", cliff_ok)
			var shelves := 0
			var wade := 0
			var dd: Vector2 = isl.dock_dir
			for k in range(36):
				var a := k * TAU / 36.0
				var dir := Vector2.from_angle(a)
				var q: Vector2 = dir * isl.radius * 0.5 - isl.sites["dock"]
				if isl._cliff(a) > 0.0 or (q.dot(dd) > -30.0 and absf(q.dot(Vector2(-dd.y, dd.x))) < 90.0):
					continue
				var wl: float = isl.radius * 0.5
				while wl < isl.radius and isl.height_at(dir.x * wl, dir.y * wl) > 0.0:
					wl += 1.0
				if wl > isl.radius - 40.0:
					continue
				shelves += 1
				var h9: float = isl.height_at(dir.x * (wl + 9.0), dir.y * (wl + 9.0))
				if h9 > -0.7 and h9 < 0.0:
					wade += 1
				else:
					print("   no shelf at %.0f deg: %.2f m 9 m out (a set piece, a cliff's end?)" % [rad_to_deg(a), h9])
			check("a sandy shelf to wade out on off the beaches (%d of %d bearings knee deep 9 m out)" % [wade, shelves], shelves > 3 and wade >= shelves * 0.7)
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
			check("paths from the village to each (its lanes, on to the interiors and its landmarks)", isl.paths.size() >= 6)
			var trees: int = isl.get_node("VegetationColliders").get_child_count()
			check("trees and rocks with colliders (%d)" % trees, trees > 500)
			check("grapple crowns in the trees", load("res://scripts/world/grapple_points.gd").count() > 1000)
			check("the shallows are sent to the ocean", root.get_node("Ocean").isle_shoals.size() == mini(world.chain_islands.size(), 2))
			check("on the chart's list", world.island_infos.any(func(i): return i["name"] == isl.island_name))
			check("enemy ships keep off it", load("res://scripts/ship/enemy_ship.gd").no_go.any(func(z): return z[0] == n["pos"]))
			# the same node builds the same island
			var again = load("res://scripts/island/gen_island.gd").new()
			again.prepare(n)
			check("the same node builds the same island", again.heights == isl.heights and again.sites == isl.sites and again.coast_cols == isl.coast_cols)
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
			print("   village (%s): %s, %d people, %d buildings, jobs %s" % [vil.layout, vil.elder_name, npcs.size(), vil.buildings.size(), vil.jobs.keys()])
			check("a village of a layout from the pool, an inn among its houses", vil.buildings.size() >= 10 and isl.find_child("Inn", true, false) != null and load("res://scripts/island/village_layouts.gd").POOL.has(vil.layout))
			check("its elder, innkeeper, trader, cook and a few villagers", npcs.size() >= 6 and npcs.any(func(x): return x.dialogue_id == isl.save_key("elder")))
			var shops = load("res://scripts/game/shops.gd")
			check("a trader and a cook to buy from (at the island's tier)", shops.extra.has(isl.save_key("trader")) and shops.extra.has(isl.save_key("cook"))
				and npcs.any(func(x): return x.shop_id == isl.save_key("trader")) and str(shops.extra[isl.save_key("trader")]["stock"][2][0]).contains("@"))
			var dlg = root.get_node("Dialogue")
			check("a job board: the camp's captain and the bug lair", dlg._load(isl.save_key("board"))["nodes"].has("camp") and dlg._load(isl.save_key("board"))["nodes"].has("lair"))
			check("the elder's talk: the island, the way on, pay for jobs done", dlg._load(isl.save_key("elder"))["nodes"].has("beyond") and dlg._load(isl.save_key("elder"))["nodes"].has("pay_camp"))
			# the style tables: every theme has every key the kits read (nested tables too), and its props build
			var ks = load("res://scripts/island/kit/kit_style.gd")
			var missing: Array = []
			var rng := RandomNumberGenerator.new()
			for sn in ks.STYLES.keys():
				var st: Dictionary = ks.of(sn)
				for k in ks.BRINEHOLLOW.keys():
					if not st.has(k):
						missing.append("%s.%s" % [sn, k])
					elif ks.BRINEHOLLOW[k] is Dictionary and k != "rough":
						for k2 in ks.BRINEHOLLOW[k].keys():
							if not st[k].has(k2):
								missing.append("%s.%s.%s" % [sn, k, k2])
				for slot in ks.BRINEHOLLOW["props"].keys():
					var prop: Node3D = ks.prop(st, slot, rng)
					if prop == null or (slot == "lamp" and prop.get_node_or_null("Flame") == null):
						missing.append("%s prop %s" % [sn, slot])
					if prop:
						prop.free()
			check("every theme's style has every key and prop the kits read %s" % [missing], missing.is_empty())
			var lamps: int = 2 + isl.village_plan["items"].filter(func(it): return it["k"] == "lamp").size()
			var flames: int = isl.find_children("Flame", "Marker3D", true, false).size()
			check("its lamps (the camp's two, the village's %d) are its style's %s (%d flames)" % [lamps - 2, ks.of(isl.theme)["props"]["lamp"], flames], flames >= lamps)
			# the jungle floor: thick undergrowth that slows you, clear on the dock road and in the village
			var thick := 0.0
			for crown in isl.forest_crowns:
				thick = maxf(thick, isl.undergrowth_at(isl.to_global(crown)))
			var vg: Vector2 = isl.sites["village"]
			var dock_road: Vector2 = isl.paths[0][isl.paths[0].size() / 2]
			var gi = load("res://scripts/island/gen_island.gd")
			print("   forest: %s, undergrowth up to %.2f" % [isl.forest, thick])
			check("thick undergrowth in the jungle (%.2f), none in the village or on the dock road" % thick, thick > 0.5
				and gi.thicket(self, isl.to_global(Vector3(vg.x, 0, vg.y))) == 0.0 and gi.thicket(self, isl.to_global(Vector3(dock_road.x, 0, dock_road.y))) == 0.0)
			# a canopy arena: a clear floor, giants ringing it, the canopy closed over it
			var ac: Vector2 = Vector2(isl.forest_crowns[0].x, isl.forest_crowns[0].z)
			var ar := 12.0
			var arena = gi.new()
			arena.position = isl.position
			arena.canopy_arena(ac, ar)
			arena.prepare(n)
			var inside := 0
			var ring := 0
			for s in arena._shapes:
				var sd := Vector2(s[2].x, s[2].z).distance_to(ac)
				if sd < ar:
					inside += 1
				elif sd < ar + 8.0 and float(s[0]) > 0.9:
					ring += 1
			var roof: int = arena._crowns.filter(func(c): return Vector2(c.x, c.z).distance_to(ac) < ar and c.y - arena.hv(Vector2(c.x, c.z)) > 10.0).size()
			check("a canopy arena: nothing standing on its floor (%d), giants ringing it (%d), canopy over it (%d), no undergrowth (%.2f)" % [inside, ring, roof, arena.undergrowth_at(arena.position + Vector3(ac.x, 0, ac.y))],
				inside == 0 and ring >= 6 and roof >= 1 and arena.undergrowth_at(arena.position + Vector3(ac.x, 0, ac.y)) == 0.0)
			arena.free()
			# take the captain's bounty, then he falls
			dlg.set_flag(vil._flag("camp", "taken"))
			var capt = isl.get_node("Site_camp/Camp").grunts.filter(func(g): return g.captain)[0]
			capt.health.take_damage(999999.0)
			set_meta("gold0", p.inventory_component.count("gold"))
			set_meta("vil", vil)
			# a captain on the ground at the village (on the road in: the heart may be a deck or a market)
			var road: PackedVector2Array = vil.streets[0]
			var v: Vector2 = road[road.size() - 1]
			for q in road:
				if q.distance_to(isl.sites["village"]) > 22.0:
					v = q
					break
			set_meta("v", v)
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.to_global(Vector3(v.x, isl.height_at(v.x, v.y) + 1.5, v.y))
			p.reset_physics_interpolation()
			set_meta("isl", isl)
			wait = 1.5
			step = 1
		1:
			var isl = get_meta("isl")
			var v: Vector2 = get_meta("v")
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
