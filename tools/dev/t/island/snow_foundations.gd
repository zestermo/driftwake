extends SceneTree
## The snow theme's foundations (scripts/island/themes/snow_theme.gd): registered right after the jungle;
## every mesh slot the scatter reads is filled (big trees as [body, detail, lean]) and built the same twice
## from its seed; the ice crystals carry their own glow; the forest stands about as tall as the jungle's
## canopy; its style (packed-snow paving, its own lamp with a Flame, pink brick and green tier roofs), its
## music and bed are registered, its wildlife and beasts are its own, and its people have their names, roles and text.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var KS = load("res://scripts/island/kit/kit_style.gd")
	var LP = load("res://scripts/island/kit/life_pools.gd")
	var KL = load("res://scripts/island/kit/kit_landmarks.gd")
	var SP = load("res://scripts/props/snow_plants.gd")
	var names: Array = IT.all().map(func(t): return t.name)
	check("snow is registered right after the jungle %s" % [names], names.size() >= 2 and names[0] == "jungle" and names[1] == "snow")
	var m: Dictionary = load("res://scripts/island/island_theme.gd").meshes("snow")
	var bad: Array = []
	for k in ["tree", "beach_tree", "bush", "fern", "grass", "rock", "mangrove", "bamboo", "broadleaf", "shrub"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Mesh):
			bad.append(k)
	for k in ["giant", "fig", "kapok", "emergent", "roof"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Array and e[0] is Mesh and e[1] is Mesh and e[2] is Vector3):
			bad.append(k)
	check("every mesh slot the scatter reads is filled, big trees as [body, detail, lean] %s" % [bad], bad.is_empty())
	var a: Array = SP.spruce(761)
	var b: Array = SP.spruce(761)
	check("a spruce is the same from the same seed, another from another",
		(a[0] as Mesh).get_aabb() == (b[0] as Mesh).get_aabb() and (a[0] as ArrayMesh).surface_get_array_len(0) == (b[0] as ArrayMesh).surface_get_array_len(0)
		and (a[0] as Mesh).get_aabb() != (SP.spruce(762)[0] as Mesh).get_aabb())
	var glow := false
	var cl: ArrayMesh = m["bamboo"][0]
	for i in range(cl.get_surface_count()):
		var mat := cl.surface_get_material(i) as ShaderMaterial
		var col = mat.get_shader_parameter("emission_color")
		if col != null and (col as Color).b > 0.8 and float(mat.get_shader_parameter("emission_energy")) > 0.0:
			glow = true
	check("the ice crystals glow blue of themselves (emission, no light)", glow)
	var canopy: float = KL.canopy("snow")
	check("the forest stands about as tall as a canopy (%.1f m)" % canopy, canopy > 15.0 and canopy < 30.0)
	var st: Dictionary = KS.of("snow")
	var lamp: Node3D = KS.prop(st, "lamp", RandomNumberGenerator.new())
	var mark: Node3D = KS.prop(st, "marker", RandomNumberGenerator.new())
	check("the snow style: packed-snow paving, pink brick houses under green roofs, its own lamp with a Flame and a waymark",
		st["paving"] == "snow_packed" and (st["house"]["walls"] as Array).has("brick_pink") and (st["house"]["roof_tex"] as Array).has("roof_green")
		and lamp != null and lamp.get_node_or_null("Flame") != null and mark != null)
	lamp.free()
	mark.free()
	var hut: Node3D = KS.model(st["village_models"]["hut"], RandomNumberGenerator.new(), 5.6)
	var tall: Node3D = KS.model(st["village_models"]["tall"], RandomNumberGenerator.new(), 5.6)
	var tall_top: float = (tall.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).get_aabb().end.y
	var hut_top: float = (hut.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).get_aabb().end.y
	check("the village's huts are round houses with a door and a wall to bump into, the tall ones a storey higher (%.1f, %.1f m)" % [hut_top, tall_top],
		hut is StaticBody3D and hut.get_node_or_null("Door") != null and hut.find_children("*", "CollisionShape3D", false, false).size() >= 1 and tall_top > hut_top + 1.5)
	hut.free()
	tall.free()
	var ws: Node3D = KS.model(st["village_models"]["workshop"], RandomNumberGenerator.new(), 7.5)
	var sh: Node3D = KS.model(st["village_models"]["shrine"], RandomNumberGenerator.new(), 4.6)
	var store: Node3D = KS.model(st["village_models"]["storehouse"], RandomNumberGenerator.new(), 3.6)
	var crate: Node3D = KS.prop(st, "crate", RandomNumberGenerator.new())
	check("its workshop, shrine and store shed are its own, with the kit's work spots (Worker, Bench, Keeper, Pray); snow on its crates",
		ws.get_node_or_null("Worker") != null and ws.get_node_or_null("Bench") != null and sh.get_node_or_null("Keeper") != null
		and sh.get_node_or_null("Pray") != null and store is StaticBody3D and crate.get_node_or_null("Snow") != null)
	for n in [ws, sh, store, crate]:
		n.free()
	var music = load("res://scripts/game/music.gd")
	var amb = load("res://scripts/world/ambience.gd")
	check("its music (day, night, the town's) and its bed are registered",
		music.TRACKS.has(st["music"]) and music.TRACKS.has(st["music"] + "_night") and music.TRACKS.has(st["music_town"]) and amb.LOOPS.has(st["ambience"]))
	var FS = load("res://scripts/island/fauna_spawner.gd")
	var snow = IT.of("snow")
	var made: Array = []
	for k in snow.fauna:
		var c = FS.make("snow", k)
		if c != null and c.get_script().resource_path == snow.creatures[k]:
			made.append(k)
		c.free()
	var own: Array = []
	for k in snow.bosses + snow.minis + snow.roamers:
		if str(snow.beasts[k]["script"]).contains("/beasts/") and not ["serpent"].has(k):
			own.append(k)
	check("its wildlife (%s) are its own creatures, wolves and walruses in packs; its beasts its own (%s)" % [made, own],
		made.size() == snow.fauna.size() and made.has("wolf") and snow.fauna["wolf"]["pack"][1] >= 3 and snow.fauna["walrus"]["zones"] == ["shore"]
		and own.has("great_bear") and own.has("frost_alpha") and own.has("rimeback") and snow.beasts["great_bear"].has("banner"))
	var life: Dictionary = LP.of("snow")
	var works := {}
	for r in life["roles"].values():
		works[r["work"]] = true
	check("its people: 36 names, 7 roles at the jungle's kinds of work, the elder's two lines, every quest kind",
		(life["first"] as Array).size() == 36 and life["roles"].size() == 7 and works.keys().all(func(w): return (LP.of("jungle")["where"] as Dictionary).has(w))
		and (life["elder_about"] as Array).size() == 2 and life["quests"].keys() == ["lost", "scout", "deliver", "fetch", "clear"])
	return TK.done(fails)
