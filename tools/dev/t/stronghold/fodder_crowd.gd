extends SceneTree
## A crowd of 25 fodder marines (1.30, FodderMarine) on one captain: all of them join the fight, only a few swing at
## once (the district's turns, the rest circle), their rigs stay on the lod path. What they and as many full grunts cost
## a frame is printed (a light measure, no bench): the runner steps one physics tick a frame as fast as the machine
## goes, so the wall time between frames is the whole frame's cost (scripts, physics, posing, the scene's transforms).
## Each crowd is measured against the empty stage before and after it.
const TK := preload("res://tools/dev/test_kit.gd")
const N := 25
const FRAMES := 300
var stage
var p
var camp
var step := 0
var until := 0
var fails := 0
## phase -> [us, frames]
var cost := {}
var phase := ""
var _last_us := 0
var most_swinging := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


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


func _begin(nm: String) -> void:
	phase = nm
	cost[nm] = [0, 0]
	_last_us = 0


func _ms(nm: String) -> float:
	return float(cost[nm][0]) / maxf(float(cost[nm][1]), 1.0) / 1000.0


func _end() -> void:
	print("CROWD %s: %.2f ms a frame" % [phase, _ms(phase)])
	phase = ""


func _process(_d: float) -> bool:
	if stage.up and phase != "":
		var now := Time.get_ticks_usec()
		if _last_us > 0:
			cost[phase][0] += now - _last_us
			cost[phase][1] += 1
		_last_us = now
		if camp and is_instance_valid(camp) and phase == "fodder":
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
			until = TK.wait_secs(2.0)
		1:
			_begin("empty")
			until = TK.wait_ticks(FRAMES)
		2:
			_end()
			_crowd(true)
			until = TK.wait_secs(3.0)
		3:
			var up: Array = camp.grunts.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			check("all %d fodder marines join the fight on the captain (%d)" % [N, up.filter(func(g): return g.in_combat()).size()], up.size() == N and up.all(func(g): return g.in_combat()))
			check("...their rigs on the crowd path in the fight (all but those swinging)", up.all(func(g): return g.humanoid.lod and (g.humanoid.crowd or g.state in [g.S.WIND, g.S.SWING, g.S.GRAB])))
			_begin("fodder")
			until = TK.wait_ticks(FRAMES)
		4:
			_end()
			check("only a few swing at once (%d)" % most_swinging, most_swinging <= 8)
			for g in camp.grunts:
				g.humanoid.process_mode = Node.PROCESS_MODE_DISABLED
			_begin("fodder_unposed")
			until = TK.wait_ticks(FRAMES)
			step = 40
			return false
		40:
			_end()
			step = 4
			camp.queue_free()
			camp = null
			until = TK.wait_secs(1.0)
		5:
			_crowd(false)
			until = TK.wait_secs(1.0)
		6:
			for g in camp.grunts:
				g.alert()
			until = TK.wait_secs(2.0)
		7:
			_begin("grunts")
			until = TK.wait_ticks(FRAMES)
		8:
			_end()
			camp.queue_free()
			camp = null
			until = TK.wait_secs(1.0)
		9:
			_begin("empty_after")
			until = TK.wait_ticks(FRAMES)
		10:
			_end()
			var base := (_ms("empty") + _ms("empty_after")) * 0.5
			# (printed, not checked: other tests share the machine, and their load swings these several-fold)
			print("FODDER CROWD %d: +%.2f ms a frame (posing %.2f, the rest %.2f; full grunts +%.2f), on an empty stage's %.2f" % [N, _ms("fodder") - base,
				_ms("fodder") - _ms("fodder_unposed"), _ms("fodder_unposed") - base, _ms("grunts") - base, base])
			return TK.done(fails)
	step += 1
	return false
