extends SceneTree
## Times the one-off jobs that can stall a frame mid-game: an autosave, a camp
## respawning, a pirate ship respawning, one character being built, each
## island's navmesh parse, a weapon mesh, an FX burst. Prints ms each.
var t := 0.0
var done := false


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func ms(label: String, fn: Callable) -> void:
	var us := Time.get_ticks_usec()
	fn.call()
	print("%-34s %8.2f ms" % [label, (Time.get_ticks_usec() - us) / 1000.0])


func _process(d: float) -> bool:
	t += d
	if t < 3.0 or done:
		return false
	done = true
	for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
	var p = get_first_node_in_group("player")
	var SG = load("res://scripts/game/save_game.gd")
	SG.use_test_dir("res://tools/dev/out/hitch_saves")
	SG.slot = 1
	ms("autosave", func(): SG.save(p))
	var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
	ms("camp respawn (5 grunts, cold)", func(): camp._spawn_all())
	var H = load("res://scripts/npc/humanoid.gd")
	var G = load("res://scripts/enemies/pirate_grunt.gd")
	H.prebuild(camp.specs.map(func(c): return G.look_for(c)))
	ms("   (waiting for the worker)", func():
		while not H._tasks.is_empty():
			H._reap()
			OS.delay_msec(2))
	ms("camp respawn (prebuilt)", func(): camp._spawn_all())
	var fleet = root.find_children("*", "EnemyFleet", true, false)[0]
	ms("pirate ship respawn (cold)", func():
		fleet.zones[0]["gen"] = 50
		fleet._spawn(0))
	var S = load("res://scripts/ship/enemy_ship.gd")
	H.prebuild(S.crew_plan(fleet._seed_of(0, 51), fleet._kind_of(0, 51)).map(func(e): return e[0]))
	ms("   (waiting for the worker)", func():
		while not H._tasks.is_empty():
			H._reap()
			OS.delay_msec(2))
	ms("pirate ship respawn (prebuilt)", func():
		fleet.zones[0]["gen"] = 51
		fleet._spawn(0))
	ms("one villager rig", func():
		var h := Humanoid.new()
		h.setup(load("res://scripts/npc/character_look.gd").default_look())
		root.add_child(h))
	ms("weapon mesh (new design)", func(): Props.weapon_mesh("katana:nodachi:3"))
	ms("weapon mesh (cached)", func(): Props.weapon_mesh("katana:nodachi:3"))
	var fx = root.get_node("FX")
	var cam := root.get_viewport().get_camera_3d()
	ms("splash burst", func(): fx.splash(cam.global_position + Vector3(0, -2, -5), 6, 0.6))
	var baker = root.find_children("NavBaker", "", true, false)[0]
	for z in baker._zones:
		var name: String = (z["node"] as Node).name
		if z["baked"]:
			print("%-34s (already baked)" % ("nav " + name))
			continue
		ms("nav parse " + name, func(): baker._bake(z))
	quit()
	return false
