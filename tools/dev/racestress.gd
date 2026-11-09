extends SceneTree
## The worker-body race (2026-11-08, Zach's co-op crashes): a grunt camp prebuilds its next crew's bodies on a worker
## (Humanoid.prebuild) while the main thread rebuilds the captain's body (an equip: apply_look). Keeps both going for
## `secs` seconds (fresh looks every round, the ready bodies freed) and prints how many of each it did; a crash or a
## script error is the race. Args: [secs] [main: "look" (apply_look each frame when Humanoid.main_may_build, as the gear does; default), "raw" (every frame regardless), "none", "two" (two crews building on workers at once, no main builds)]
const TK := preload("res://tools/dev/test_kit.gd")
const COATS := ["longcoat", "none", "greatcoat", "none"]
var stage
var secs := 40.0
var main_mode := "look"
var t := 0.0
var started := false
var rounds := 0
var looks := 0
var seed_n := 1000
var frame := 0
var waits := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		secs = float(args[0])
	if args.size() > 1:
		main_mode = args[1]
	TK.seed_of(self)
	stage = TK.stage(self, {})


func _process(delta: float) -> bool:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up:
		return false
	frame += 1
	t += delta
	if not started:
		started = true
		print("racestress: %0.0f s, main %s" % [secs, main_mode])
	# the worker: a crew of 6 fresh looks whenever the last crew's done
	Humanoid._reap()
	if Humanoid._tasks.is_empty():
		_free_ready()
		var crew: Array = []
		for i in range(6):
			seed_n += 1
			crew.append(load("res://scripts/enemies/pirate_grunt.gd").look_for({"seed": seed_n}))
		Humanoid.prebuild(crew)
		if main_mode == "two":
			var crew2: Array = []
			for i in range(6):
				seed_n += 1
				crew2.append(load("res://scripts/enemies/pirate_grunt.gd").look_for({"seed": seed_n}))
			Humanoid.prebuild(crew2)
		rounds += 1
	# the main thread: the captain's body rebuilt (an equip)
	if main_mode == "look":
		var body = stage.player.body_model
		var lk: Dictionary = body.look.duplicate()
		lk["coat"] = COATS[frame % COATS.size()]
		if Humanoid.main_may_build():
			body.apply_look(lk)
			Humanoid.main_built()
			looks += 1
		else:
			waits += 1
	elif main_mode == "raw":
		var body = stage.player.body_model
		var lk: Dictionary = body.look.duplicate()
		lk["coat"] = COATS[frame % COATS.size()]
		body.apply_look(lk)
		looks += 1
	if t >= secs:
		Humanoid.main_built()
		for id in Humanoid._tasks:
			WorkerThreadPool.wait_for_task_completion(id)
		Humanoid._tasks.clear()
		_free_ready()
		print("racestress: %d crews built on workers, %d main-thread rebuilds, %d frames waited for a worker" % [rounds, looks, waits])
		print("RESULT OK")
		quit()
	return false


func _free_ready() -> void:
	Humanoid._pool_lock.lock()
	var lists: Array = Humanoid._ready_bodies.values()
	Humanoid._ready_bodies.clear()
	Humanoid._pool_lock.unlock()
	for list in lists:
		for h in list:
			(h as Node).free()
