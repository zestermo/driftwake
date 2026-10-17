extends SceneTree
## The forest's lumber town (ForestTown through KitStyle village_models / item_models, ForestPlaces): every village
## kind builds solid with its markers (huts and tall houses a Door, the workshop Worker and Bench, the shrine Keeper and
## Pray), the same seed the same building, the tall house a storey over the cabin; its lamp's Flame, fences and woodpiles.
## On a chain island made forest: the sawmill planned on the town's river (58-110 m from the town, beside the water),
## camps and a lodge out in the woods; built, the mill solid with its wheel turning, the flume when it has one, the camps'
## kilns and the lodge's cache.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var step := 0
var until := 0
var isl
var wheel: Node3D
var wheel_z := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func _top(n: Node3D) -> float:
	var t := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		t = maxf(t, (mi as MeshInstance3D).get_aabb().end.y)
	return t


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if TK.ticking(until):
		return false
	match step:
		0:
			_models()
			_island()
			step = 1
			until = TK.wait_ticks(30)
		1:
			check("the sawmill's wheel turns (%.2f rad)" % absf(wheel.rotation.z - wheel_z), absf(wheel.rotation.z - wheel_z) > 0.05)
			isl.queue_free()
			return TK.done(fails)
	return false


func _models() -> void:
	var KS = load("res://scripts/island/kit/kit_style.gd")
	var st: Dictionary = KS.of("forest")
	var vm: Dictionary = st["village_models"]
	var bad: Array = []
	for kind in vm.keys():
		var n: Node3D = KS.model(vm[kind], _seeded(), 5.8)
		var solid := n is StaticBody3D and not n.find_children("*", "CollisionShape3D", true, false).is_empty()
		var marks: Array = {"hut": ["Door"], "tall": ["Door"], "storehouse": ["Door"], "workshop": ["Worker", "Bench"], "shrine": ["Keeper", "Pray"]}[kind]
		if not solid or not marks.all(func(m): return n.get_node_or_null(m) != null):
			bad.append(kind)
		n.free()
	check("every village kind builds solid with its markers %s (bad: %s)" % [vm.keys(), bad], bad.is_empty() and vm.has("hut") and vm.has("tall"))
	var a: Node3D = KS.model(vm["hut"], _seeded(), 5.8)
	var b: Node3D = KS.model(vm["hut"], _seeded(), 5.8)
	var tall: Node3D = KS.model(vm["tall"], _seeded(), 5.8)
	check("the same seed builds the same cabin; the timber-framed house stands a storey over it (%.1f, %.1f m)" % [_top(a), _top(tall)],
		_top(a) == _top(b) and _top(tall) > _top(a) + 1.0)
	for n in [a, b, tall]:
		n.free()
	var lamp: Node3D = KS.model(st["item_models"]["torch"], _seeded(), 1.0)
	var fence: Node3D = KS.model(st["item_models"]["fence"], _seeded(), 1.0)
	var pile: Node3D = KS.model(st["item_models"]["woodpile"], _seeded(), 1.0)
	check("its lamp for the torches with a Flame, split-rail fences, woodpiles, all solid", lamp.get_node_or_null("Flame") != null
		and not fence.find_children("*", "CollisionShape3D", true, false).is_empty() and not pile.find_children("*", "CollisionShape3D", true, false).is_empty())
	for n in [lamp, fence, pile]:
		n.free()


func _island() -> void:
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var KL = load("res://scripts/island/kit/kit_landmarks.gd")
	var FL = load("res://scripts/island/themes/forest_land.gd")
	var f = IT.of("forest")
	load("res://scripts/island/island_theme.gd").meshes("forest")
	var c = load("res://scripts/world/chain.gd").make(5, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n["theme"] = "forest"
	n.merge({"beast": f.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [f.minis[0]], "roamer": f.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	isl = load("res://scripts/island/gen_island.gd").new()
	isl.prepare(n)
	var kinds: Array = isl.places.map(func(pl): return str(pl["kind"]))
	print("places %s" % [kinds])
	var mills: Array = isl.places.filter(func(pl): return pl["kind"] == "forest_sawmill")
	check("a sawmill on the town's river %s" % [kinds], mills.size() == 1)
	var mill: Dictionary = mills[0]
	var v: Vector2 = isl.sites["village"]
	var rd: float = FL.river_dist(isl.land_plan, mill["at"])
	check("the mill 58-110 m from the town (%.0f m) beside the water (%.1f m from the river's middle)" % [v.distance_to(mill["at"]), rd],
		v.distance_to(mill["at"]) >= 58.0 and v.distance_to(mill["at"]) <= 110.0 and rd < 12.0)
	var woods: Array = kinds.filter(func(k): return k.begins_with("forest_charcoal") or k.begins_with("forest_lodge"))
	check("camps or a lodge out in the woods %s" % [woods], not woods.is_empty())
	isl.name = "ForestIsland"
	stage.add_child(isl)
	for s in KL.steps(isl):
		s[1].call()
	var node: Node3D = isl.get_node("Place_forest_sawmill")
	wheel = node.get_node("Wheel")
	wheel_z = wheel.rotation.z
	var sm: Node3D = node.get_node("Sawmill")
	check("the mill solid, its wheel in the stream, its yard built", sm.find_children("*", "CollisionShape3D", false, false).size() >= 6 and node.get_node_or_null("MillYard") != null
		and wheel.position.y < float(mill["water"]) + 3.0)
	for k in woods:
		var w: Node3D = isl.get_node("Place_" + k)
		var ok: bool = not w.find_children("*", "CollisionShape3D", true, false).is_empty()
		if k.begins_with("forest_lodge"):
			ok = ok and not w.find_children("*", "LootBag", true, false).is_empty() and w.get_node_or_null("LogCabin") != null
		check("%s built: solid%s" % [k, ", its cabin and cache" if k.begins_with("forest_lodge") else ", its kilns"], ok)
