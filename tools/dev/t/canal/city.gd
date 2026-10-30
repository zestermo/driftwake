extends SceneTree
## The canal city built (CanalIsland, 1.21 piece 4): the chain's second city is it, named; you stand on the riva and
## the walkways at the quay, the canals' beds lie under the water, the bridges' decks arch over them and the landings'
## steps lead down into the water; every walkway house's door is on a walkway and clear in front; every place its
## people need is on the ground; its people, boatmen, shops, the arsenal's yard and three quests are there; a water
## taxi rows the captain to another landing; the lights and the surfaces stay inside their budgets.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(0, 0, 4000)
var stage
var step := 0
var until := 0
var fails := 0
var w
var isl


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))


func _floor_at(q: Vector2, top: float) -> float:
	var hit := _ray(isl.city_global(q, top), isl.city_global(q, top - 14.0))
	return -INF if hit.is_empty() else isl.to_local(hit["position"]).y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/canal_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			var canal: Array = w.c.nodes.filter(func(n): return n.get("canal", false))
			check("the chain's second city is the canal city (%s)" % [canal.map(func(n): return n["name"])], canal.size() == 1 and int(canal[0]["layer"]) == 6
				and str(canal[0]["name"]) in load("res://scripts/world/chain.gd").CANAL_NAMES)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_canal(AT)
			until = TK.wait_ticks(4)
		2:
			var y: float = P.QUAY_Y
			check("the riva underfoot (%.2f)" % _floor_at(Vector2(-60.0, 104.0), y + 4.0), absf(_floor_at(Vector2(-60.0, 104.0), y + 4.0) - y) < 0.15)
			check("a walkway underfoot", absf(_floor_at(Vector2(-14.0, -100.0), y + 4.0) - y) < 0.15)
			check("the Grand Canal's bed under the water (%.2f)" % _floor_at(Vector2(0.0, -100.0), y + 4.0), _floor_at(Vector2(0.0, -100.0), y + 4.0) < -2.0)
			var br: Array = P.BRIDGES[2]
			var mid: Vector2 = (br[0] as Vector2).lerp(br[1], 0.5)
			check("the market bridge's deck arched over it (%.2f)" % _floor_at(mid, y + 8.0), absf(_floor_at(mid, y + 8.0) - (y + float(br[3]))) < 0.4)
			var l0: Array = P.LANDINGS[0]
			var step_y := _floor_at((l0[1] as Vector2) + (l0[2] as Vector2) * 3.0, y + 4.0)
			check("a landing's steps lead down to the water (%.2f)" % step_y, step_y > -1.2 and step_y < y - 0.3)
			var bad: Array = []
			for d in isl.doors:
				var at: Vector3 = d["at"]
				var q := Vector2(at.x, at.z)
				var face: Vector2 = d["face"]
				var hit := _ray(isl.city_global(q + face * 0.6, y + 1.0), isl.city_global(q - face * 0.25, y + 1.0))
				if not P.in_floor(q) or not hit.is_empty():
					bad.append("%s %s" % [q.round(), "off the floors" if not P.in_floor(q) else "blocked"])
			check("%d walkway houses, every door on a walkway and clear in front (%s)" % [isl.doors.size(), bad.slice(0, 8)], isl.doors.size() > 120 and bad.is_empty())
			var floating: Array = []
			for s in isl.spots.keys():
				var v: Vector3 = isl.spots[s][0]
				var hit := _ray(isl.city_global(Vector2(v.x, v.z), v.y + 1.5), isl.city_global(Vector2(v.x, v.z), v.y - 1.5))
				if hit.is_empty() or absf(isl.to_local(hit["position"]).y - v.y) > 0.6:
					floating.append(s)
			check("every place its people need is on the ground (%s)" % [floating], floating.is_empty())
			var names := {}
			for n in isl.find_children("*", "NPC", true, false):
				names[n.npc_name] = true
			var want: Array = load("res://scripts/island/canal_life.gd").cast().map(func(c): return c["name"])
			var missing: Array = want.filter(func(nm): return not names.has(nm))
			check("its people (%d; missing %s)" % [names.size(), missing], missing.is_empty())
			check("a boatman at every landing", names.keys().filter(func(nm): return str(nm).begins_with("Boatman")).size() == P.LANDINGS.size())
			var SH = load("res://scripts/game/shops.gd")
			check("its shops open", ["grocer", "fish", "glass", "chandler", "inn"].all(func(k): return SH.extra.has(isl.save_key("canal_" + k))))
			check("the glassworker a rare goods merchant", SH.extra[isl.save_key("canal_glass")]["trade"] == "treasure")
			var master: Dictionary = root.get_node("Dialogue")._cache.get(isl.save_key("canal_master"), {})
			check("the Master's yard opens under his name", str(master).contains("shipwright:Grane"))
			check("eight city quests (1.27: the smuggling ring, three jobs, the drowned bell) (%d)" % isl.canal_life.quest_node.quests.size(), isl.canal_life.quest_node.quests.size() == 8)
			var lights: Array = isl.find_children("*", "NightLight", true, false)
			check("the lights inside the budget (%d)" % lights.size(), lights.size() >= 6 and lights.size() <= 16)
			var draws := 0
			for mi in isl.city.find_children("*", "MeshInstance3D", true, false):
				if isl.crowd.is_ancestor_of(mi):
					continue
				# (1.27: the ladders are their own little nodes, one surface each, near the camera only)
				if mi.get_parent() and mi.get_parent().get_script() and (str(mi.get_parent().get_script().resource_path).ends_with("ladder.gd") or str(mi.get_parent().get_script().resource_path).ends_with("loot_bag.gd")):
					continue
				draws += (mi as MeshInstance3D).mesh.get_surface_count()
			check("its surfaces stay few (%d; 1.27: rooms, rooftops and the far fronts add some)" % draws, draws < 560)
			isl.canal_life.ride(2)
			until = TK.wait_secs(1.6)
		3:
			var to: Vector3 = isl.canal_life._spot("landing2")[0]
			var me = stage.player
			check("a water taxi rows the captain to the arsenal's landing (%.1f m off)" % isl.to_local(me.global_position).distance_to(to),
				isl.to_local(me.global_position).distance_to(to) < 1.5)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
