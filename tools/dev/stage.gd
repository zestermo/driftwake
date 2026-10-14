extends Node3D
## The light test stage (TK.stage): flat ground, a sun, the captain with the camera and HUD, and only
## what a test asks for. No world generation. Ground top at GROUND_Y (well above the waves, so it's dry).
## opts (a spot is true for the default or a Vector3 on the ground, relative to the captain at the origin):
##   hud (default true), dummy (spot), grunts ([GruntCamp.add_grunt cfg], posts relative to the ground),
##   weapon (item id: given, equipped and drawn), npc (NPC.setup cfg, "at" a spot), bench (spot: Props.bench),
##   chest ([[item id, qty]]), storage (the ship's storage chest, on GameManager.storage),
##   water (sea past x = SHORE_X), ship (riding in that sea), weather (named "World" so Weather attaches).

const GROUND_Y := 3.0
const SHORE_X := 24.0
const SEA_FLOOR := -9.0
## Where things stand by default (relative to the captain at the origin, facing -Z).
const DUMMY_AT := Vector3(0, 0, -3)
const BENCH_AT := Vector3(-3, 0, 0)
const CHEST_AT := Vector3(3, 0, 0)
const STORAGE_AT := Vector3(3, 0, 3)
const NPC_AT := Vector3(-3, 0, -3)
## The ship rides at sea level off the shore.
const SHIP_AT := Vector3(SHORE_X + 16.0, 0, 0)

var opts: Dictionary = {}
var player
var camera_rig: Node3D
var hud
var dummy
var camp
var ship
var bench
var chest
var storage
var npc
## True once the captain is built and registered and the camera has found them: tests wait for it.
var up := false
var _frames := 0
var _t0 := 0
var _drawn := false


func build(o: Dictionary) -> void:
	opts = o
	_t0 = Time.get_ticks_msec()
	# a fresh game in a save folder of its own: the default captain (not whatever look a run left on disk), nothing loaded
	SaveGame.use_test_dir("user://test_stage")
	SaveGame.begin(1, true)
	name = "World" if opts.get("weather", false) else "Stage"
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.58, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.transform = Transform3D(Basis(Vector3(0.866, 0, -0.5), Vector3(-0.433, 0.5, -0.75), Vector3(0.25, 0.866, 0.433)), Vector3(0, 100, 0))
	add_child(sun)
	var wg := Node.new()
	wg.name = "NoIslands"
	wg.set_script(load("res://tools/dev/stage_islands.gd"))
	add_child(wg)
	var water: bool = opts.get("water", false) or opts.get("ship", false)
	if water:
		_box("Ground", Vector3(SHORE_X + 60.0, 2.0, 120.0), Vector3((SHORE_X - 60.0) * 0.5, GROUND_Y - 1.0, 0))
		_box("SeaFloor", Vector3(120.0, 2.0, 120.0), Vector3(SHORE_X + 60.0, SEA_FLOOR - 1.0, 0))
	else:
		_box("Ground", Vector3(120.0, 2.0, 120.0), Vector3(0, GROUND_Y - 1.0, 0))
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector3(0, GROUND_Y + 0.05, 0)
	add_child(player)
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scenes/player/camera_rig.gd"))
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.966, -0.259), Vector3(0, 0.259, 0.966)), Vector3.ZERO)
	arm.spring_length = 5.0
	camera_rig.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.far = 1200.0
	arm.add_child(cam)
	add_child(camera_rig)
	if opts.get("hud", true):
		hud = (load("res://scenes/ui/player_hud.tscn") as PackedScene).instantiate()
		hud.name = "PlayerHUD"
		add_child(hud)
	if opts.has("dummy"):
		dummy = (load("res://scenes/enemies/dummy_target.tscn") as PackedScene).instantiate()
		dummy.name = "DummyTarget"
		dummy.position = _at(opts["dummy"], DUMMY_AT)
		add_child(dummy)
	if opts.has("grunts"):
		camp = GruntCamp.new()
		camp.name = "Camp"
		camp.position = Vector3(0, GROUND_Y, 0)
		for cfg in opts["grunts"]:
			camp.add_grunt(cfg)
		add_child(camp)
	if opts.has("npc"):
		var cfg: Dictionary = {"name": "Stage Villager", "barks": ["Fine day."]}
		cfg.merge(opts["npc"] if opts["npc"] is Dictionary else {}, true)
		npc = NPC.new().setup(cfg)
		npc.position = _at(cfg.get("at"), NPC_AT)
		add_child(npc)
	if opts.has("bench"):
		bench = Props.bench()
		bench.position = _at(opts["bench"], BENCH_AT)
		add_child(bench)
	if opts.has("chest"):
		chest = _bag("Chest", opts["chest"])
		chest.save_id = "stage_chest"
		chest.position = _at(null, CHEST_AT)
		add_child(chest)
	if opts.get("storage", false):
		storage = _bag("Storage", [])
		storage.persistent = true
		storage.label = "Ship's storage"
		storage.contents = (Engine.get_main_loop() as SceneTree).root.get_node("GameManager").storage
		storage.position = _at(null, STORAGE_AT)
		add_child(storage)
	if opts.get("ship", false):
		ship = (load("res://scenes/ship/ship.tscn") as PackedScene).instantiate()
		ship.name = "Ship"
		add_child(ship)
		ship.place(SHIP_AT, 0.0)


## A loot bag holding [[item id, qty], ...].
func _bag(n: String, items: Array) -> LootBag:
	var b := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	b.name = n
	var stacks: Array[ItemStack] = []
	for e in items:
		var s := ItemStack.new()
		s.item = ItemDB.get_item(e[0])
		s.quantity = int(e[1])
		stacks.append(s)
	b.setup(stacks)
	return b


func _enter_tree() -> void:
	get_tree().current_scene = self
	# (the music picks its track from Brinehollow's streets and the chain's islands: there are none here)
	get_node("/root/Music").process_mode = Node.PROCESS_MODE_DISABLED


func _process(_d: float) -> void:
	if up:
		return
	_frames += 1
	# (GameManager loads the save two frames after the captain registers; the camera finds them a frame in)
	if _frames < 4:
		return
	if opts.has("weapon") and not _drawn:
		_drawn = true
		var it = ItemDB.get_item(opts["weapon"])
		if player.inventory_component.count(opts["weapon"]) == 0:
			player.inventory_component.add_item(it, 1)
		player.equip_weapon(it, true)
	# (up once the draw is over and the captain is free to act)
	if player.body_model.current_action() != "" or not player.is_free():
		return
	up = true
	print("STAGE UP %.2f s" % ((Time.get_ticks_msec() - _t0) / 1000.0))


## A position from an option: true/null = the default spot, a Vector3 = that spot (both relative to the ground).
func _at(v, def: Vector3) -> Vector3:
	return (v if v is Vector3 else def) + Vector3(0, GROUND_Y, 0)


func _box(n: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.position = at
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	b.add_child(mi)
	add_child(b)
	return b
