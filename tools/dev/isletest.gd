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
			# moving on: at the first island, the next layer is built and the other side of a fork freed
			var c = world.chain()
			var at: int = c.start_next[0]
			set_meta("left", c.start_next.filter(func(id): return id != at))
			gm.chain_at = at
			world.sync_chain_islands()
			wait = 0.2
			step = 2
		2:
			var c = world.chain()
			var at: int = gm.chain_at
			if world.chain_islands.size() < c.next_of(at).size() + 1:
				world.sync_chain_islands()
				return false
			var left: Array = get_meta("left")
			check("moving on frees the island not taken", left.all(func(id): return not world.chain_islands.has(id)))
			check("...keeps the one we're at and builds the next", world.chain_islands.has(at) and c.next_of(at).all(func(id): return world.chain_islands.has(id)))
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
			gm.chain_at = -1
			finish()
	return false
