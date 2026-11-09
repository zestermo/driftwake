extends SceneTree
## Where a big fight's frame goes (2026-11-08, Zach's co-op fights at 26-34 fps: 9-21 ms physics ticks with 10-22
## enemies awake). The light stage, N sword grunts all after an untouchable captain, then phases of `secs` each:
##   fight      everyone fighting
##   noai       the grunts' _physics_process off (no thinking, no move_and_slide)
##   nobody     ...and their bodies' _process off too (no posing, no hair or cloth)
##   ragdolls   all back on, half of them knocked down
## Per phase: ms a physics tick (Godot's physics process time), ms of process, ticks a frame and the ms spent posing
## the rigs posed (anim). Args: [n grunts = 16] [secs = 5]. Headless is fine (no GPU numbers).
const TK := preload("res://tools/dev/test_kit.gd")
const PHASES := ["warm", "fight", "noai", "nobody", "ragdolls", "ragnoscript", "end"]
var stage
var n := 16
var secs := 5.0
var phase := 0
var t := 0.0
var acc := {}
var ticks0 := 0
var frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	if args.size() > 1:
		secs = float(args[1])
	TK.seed_of(self)
	var gs: Array = []
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var r := 5.0 + float(i % 3) * 2.0
		gs.append({"post": Vector3(cos(a) * r, 0, sin(a) * r), "role": "sword", "seed": 500 + i})
	stage = TK.stage(self, {"hud": false, "grunts": gs})


func _grunts() -> Array:
	return stage.camp.grunts if stage.camp else []


func _process(delta: float) -> bool:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or _grunts().size() < n:
		return false
	if phase == 0 and t == 0.0:
		stage.player.hurtbox.monitorable = false
		stage.player.health_component.max_health = 1e9
		stage.player.health_component.current_health = 1e9
		for g in _grunts():
			g.alert()
		_begin()
	t += delta
	frames += 1
	_sample("phys", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_sample("proc", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var anim := 0
	for g in _grunts():
		if is_instance_valid(g) and g.humanoid:
			anim += g.humanoid.anim_us
			g.humanoid.anim_us = 0
	_sample("anim", anim / 1000.0)
	var pm = root.get_node("/root/Perf")
	_sample("move", pm._cat_us[pm.MOVE] / 1000.0)
	_sample("ai", pm._cat_us[pm.AI] / 1000.0)
	if t < (2.0 if phase == 0 else secs):
		return false
	if phase > 0:
		var tk := Engine.get_physics_frames() - ticks0
		print("%-11s phys %5.2f ms/tick  proc %5.2f ms  ticks/frame %.2f  frame %5.2f ms  anim %4.2f ms  grunts moved %4.2f, thought %4.2f ms/tick  awake %d" % [
			PHASES[phase], _avg("phys"), _avg("proc"), float(tk) / frames, 1000.0 * t / frames, _avg("anim"),
			_avg("move") * frames / maxf(tk, 1), _avg("ai") * frames / maxf(tk, 1), _awake()])
	phase += 1
	match PHASES[phase]:
		"noai":
			for g in _grunts():
				g.set_physics_process(false)
		"nobody":
			for g in _grunts():
				g.humanoid.set_process(false)
				for sc in g.humanoid.find_children("*", "", true, false):
					sc.set_process(false)
					sc.set_physics_process(false)
		"ragdolls":
			var k := 0
			for g in _grunts():
				g.set_physics_process(true)
				g.humanoid.set_process(true)
				for sc in g.humanoid.find_children("*", "", true, false):
					sc.set_process(true)
					sc.set_physics_process(true)
				if k % 2 == 0:
					g._knock_down(Vector3(0, 3, 4))
				k += 1
		"ragnoscript":
			for g in _grunts():
				if g.humanoid.ragdoll:
					g.humanoid.ragdoll.set_physics_process(false)
		"end":
			print("RESULT OK")
			quit()
			return true
	_begin()
	return false


func _awake() -> int:
	var k := 0
	for g in _grunts():
		if is_instance_valid(g) and g.state != 0:
			k += 1
	return k


func _begin() -> void:
	t = 0.0
	frames = 0
	acc = {}
	ticks0 = Engine.get_physics_frames()


func _sample(k: String, v: float) -> void:
	var a: Array = acc.get(k, [0.0, 0])
	acc[k] = [a[0] + v, a[1] + 1]


func _avg(k: String) -> float:
	var a: Array = acc.get(k, [0.0, 1])
	return a[0] / maxf(a[1], 1)
