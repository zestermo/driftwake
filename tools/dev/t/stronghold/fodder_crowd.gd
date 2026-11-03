extends SceneTree
## A crowd of 25 fodder marines (1.30, FodderMarine) on one captain: all of them join the fight, only a few swing at
## once (the district's turns), their rigs stay on the lod path. What they and as many full grunts cost a frame
## (process, physics, the rigs' posing, the brains) is printed: a light measure, no bench.
const TK := preload("res://tools/dev/test_kit.gd")
const N := 25
var stage
var p
var camp
var step := 0
var until := 0
var fails := 0
## [process s, physics s, frames, anim us, ai us, physics ticks]
var cost := {}
var phase := ""
var tick0 := 0
var most_swinging := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _sample() -> void:
	var c: Array = cost[phase]
	var perf = root.get_node("Perf")
	c[0] += Performance.get_monitor(Performance.TIME_PROCESS)
	c[1] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	c[2] += 1
	c[3] += int(load("res://scripts/npc/humanoid.gd").anim_us)
	c[4] += perf._cat_us[perf.AI]


func _crowd(fodder: bool) -> void:
	camp = load("res://scripts/enemies/grunt_camp.gd").new()
	camp.max_attackers = 4
	camp.respawn_time = 1.0e9
	camp.level = 14
	for i in range(N):
		var a := TAU * i / N
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["crowd", i])
		var lk = load("res://scripts/enemies/pirate_grunt.gd").crew_look(rng)
		load("res://scripts/ship/enemy_ship.gd").marine_look(lk, rng, false)
		var c := {"post": Vector3(cos(a), 0, sin(a)) * (9.0 + float(i % 3) * 2.0), "yaw": 0.0, "mode": "stand", "look": lk, "seed": hash(["crowd", i]),
			"role": "sword"}
		if fodder:
			c["script"] = "res://scripts/enemies/fodder_marine.gd"
			c["hunt"] = true
		camp.add_grunt(c)
	camp.position = p.global_position
	root.add_child(camp)


func _begin(name: String) -> void:
	phase = name
	cost[name] = [0.0, 0.0, 0, 0, 0, 0]
	tick0 = Engine.get_physics_frames()


func _end() -> String:
	var c: Array = cost[phase]
	c[5] = Engine.get_physics_frames() - tick0
	var f := maxf(c[2], 1)
	var line := "%s: process %.2f ms, physics %.2f ms a frame (%.2f ticks a frame); rigs %.2f ms, brains %.2f ms a frame" % [phase,
		c[0] / f * 1000.0, c[1] / f * 1000.0, c[5] / f, c[3] / f / 1000.0, c[4] / f / 1000.0]
	print("CROWD " + line)
	phase = ""
	return line


func _total(name: String) -> float:
	var c: Array = cost[name]
	return (c[0] + c[1]) / maxf(c[2], 1) * 1000.0


func _process(_d: float) -> bool:
	if stage.up and phase != "":
		_sample()
		if camp and phase == "fodder":
			var sw: int = camp.grunts.filter(func(g): return is_instance_valid(g) and g.state in [g.S.WIND, g.S.SWING, g.S.CLOSE]).size()
			most_swinging = maxi(most_swinging, sw)
	if stage.up:
		var hc = stage.player.health_component
		hc.current_health = hc.max_health
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(1.0)
		1:
			_begin("none")
			until = TK.wait_ticks(180)
		2:
			_end()
			_crowd(true)
			until = TK.wait_secs(3.0)
		3:
			var up: Array = camp.grunts.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			check("all %d fodder marines join the fight on the captain (%d)" % [N, up.filter(func(g): return g.in_combat()).size()], up.size() == N and up.all(func(g): return g.in_combat()))
			check("...their rigs on the lod path in the fight", up.all(func(g): return g.humanoid.lod))
			_begin("fodder")
			until = TK.wait_ticks(300)
		4:
			_end()
			check("only a few swing at once (%d)" % most_swinging, most_swinging <= 8)
			camp.queue_free()
			until = TK.wait_secs(1.0)
		5:
			_crowd(false)
			until = TK.wait_secs(3.0)
		6:
			for g in camp.grunts:
				g.alert()
			until = TK.wait_secs(2.0)
		7:
			_begin("grunts")
			until = TK.wait_ticks(300)
		8:
			_end()
			var df := _total("fodder") - _total("none")
			var dg := _total("grunts") - _total("none")
			# (printed, not checked: other tests share the machine, and their load swings these several-fold)
			print("FODDER CROWD %d: +%.2f ms a frame (full grunts +%.2f)" % [N, df, dg])
			return TK.done(fails)
	step += 1
	return false
