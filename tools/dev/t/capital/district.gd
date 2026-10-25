extends SceneTree
## The capital's core district built (CapitalDistrict, piece 2): every town house fronting a floor has a door you can
## walk up to (its doorstep on a floor, nothing solid there), the plaza's own buildings, fountain and stalls, the
## market street's barrows, the quay's cranes and fish market, the slum's shacks stand; the lights stay inside the
## budget and every one is lit only at night; every spot the people need is there and on the ground.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(0, 0, 4000)
const SPOTS := ["innkeeper", "inn_door", "curio", "guild", "bank", "board", "gate_guard0", "gate_guard1", "palace_guard0", "palace_guard1",
	"harbourmaster", "flower", "fire", "ruffian0", "ruffian3", "arena_crier", "stall0", "stall2", "barrow0", "fish0", "bench0",
	"shipwright", "chandler", "fence", "foreman", "manifest", "docker0", "outfitter", "noble0", "terrace_guard",
	"queen", "chamberlain", "hall_guard0", "courtier0", "court_guard0", "signet"]
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var bad: Array = []
			for d in isl.doors:
				var at: Vector3 = d["at"]
				var q := Vector2(at.x, at.z)
				var g: Vector3 = isl.city_global(q, P.ground(q) + 1.0)
				var face: Vector2 = d["face"]
				var hit := _ray(isl.city_global(q + face * 0.6, P.ground(q) + 1.0), isl.city_global(q - face * 0.25, P.ground(q) + 1.0))
				if not P.in_floor(q) or not hit.is_empty():
					bad.append("%s %s" % [q.round(), "off the floors" if not P.in_floor(q) else "blocked"])
				var down := _ray(g + Vector3.UP, g + Vector3.DOWN * 3.0)
				if down.is_empty():
					bad.append("%s no ground" % q.round())
			check("%d town houses, every door on a floor and clear in front (%s)" % [isl.doors.size(), bad.slice(0, 8)], isl.doors.size() > 25 and bad.is_empty())
			for n in ["PlazaHalls", "Plaza", "Street", "Harbour", "Avenue", "Slum", "Town_street", "Town_plaza", "Town_slum"]:
				check("the %s stands" % n, isl.city.get_node_or_null(n) != null)
			var missing: Array = SPOTS.filter(func(s): return not isl.spots.has(s))
			check("every spot the people need (%s missing)" % [missing], missing.is_empty())
			var floating: Array = []
			# (the fire is the barrel's own spot: the toughs stand round it)
			for s in isl.spots.keys().filter(func(k): return k != "fire"):
				var v: Vector3 = isl.spots[s][0]
				var gq := Vector2(v.x, v.z)
				var hit := _ray(isl.city_global(gq, v.y + 1.5), isl.city_global(gq, v.y - 1.5))
				if hit.is_empty() or absf(hit["position"].y - v.y) > 0.6:
					floating.append(s)
			check("every spot on the ground (%s)" % [floating], floating.is_empty())
			var lights: Array = isl.find_children("*", "NightLight", true, false)
			check("the lights inside the budget (%d)" % lights.size(), lights.size() > 8 and lights.size() <= 18)
			check("only the lighthouse and the throne hall lit all day", lights.filter(func(l): return l.always).size() == 2)
			var draws := 0
			var by := {}
			for mi in isl.city.find_children("*", "MeshInstance3D", true, false):
				# (the crowd's real bodies only show by the camera, a few at a time)
				if isl.crowd.is_ancestor_of(mi):
					continue
				draws += (mi as MeshInstance3D).mesh.get_surface_count()
				var key := str(mi.get_parent().name)
				by[key] = int(by.get(key, 0)) + (mi as MeshInstance3D).mesh.get_surface_count()
			print("   surfaces by piece: %s" % by)
			check("the city's surfaces stay few (%d)" % draws, draws < 420)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
