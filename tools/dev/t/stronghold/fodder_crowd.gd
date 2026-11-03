extends SceneTree
## A crowd of 25 fodder marines (1.30, FodderMarine) on one captain: all of them join the fight, only a few swing at
## once (the district's turns), and what they cost a frame and a tick (a light measure, printed: no bench). Their rigs stay
## on the lod path in the fight.
const TK := preload("res://tools/dev/test_kit.gd")
const N := 25
var stage
var p
var camp
var step := 0
var until := 0
var fails := 0
var base := [0.0, 0.0, 0]
var crowd := [0.0, 0.0, 0]
var most_swinging := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _sample(into: Array) -> void:
	into[0] += Performance.get_monitor(Performance.TIME_PROCESS)
	into[1] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	into[2] += 1


func _process(_d: float) -> bool:
	if stage.up and step >= 1 and step <= 2:
		_sample(base)
	if stage.up and step >= 4 and step <= 5:
		_sample(crowd)
		var sw: int = camp.grunts.filter(func(g): return is_instance_valid(g) and g.state in [g.S.WIND, g.S.SWING, g.S.CLOSE]).size()
		most_swinging = maxi(most_swinging, sw)
	if not stage.up or TK.ticking(until):
		return false
	var hc = stage.player.health_component
	hc.current_health = hc.max_health
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(1.0)
		1:
			until = TK.wait_ticks(240)
		2:
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
				camp.add_grunt({"post": Vector3(cos(a), 0, sin(a)) * (9.0 + float(i % 3) * 2.0), "yaw": 0.0, "mode": "stand", "look": lk, "seed": hash(["crowd", i]),
					"role": "sword", "script": "res://scripts/enemies/fodder_marine.gd", "hunt": true})
			camp.position = p.global_position
			root.add_child(camp)
			until = TK.wait_secs(3.0)
		3:
			var up: Array = camp.grunts.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			check("all %d marines join the fight on the captain (%d)" % [N, up.filter(func(g): return g.in_combat()).size()], up.size() == N and up.all(func(g): return g.in_combat()))
			check("...their rigs on the lod path in the fight", up.all(func(g): return g.humanoid.lod))
			until = TK.wait_ticks(240)
		4:
			until = TK.wait_ticks(120)
		5:
			var bp: float = base[0] / maxf(base[2], 1) * 1000.0
			var bt: float = base[1] / maxf(base[2], 1) * 1000.0
			var cp: float = crowd[0] / maxf(crowd[2], 1) * 1000.0
			var ct: float = crowd[1] / maxf(crowd[2], 1) * 1000.0
			print("FODDER CROWD %d: process %.2f -> %.2f ms a frame (+%.2f), physics %.2f -> %.2f ms (+%.2f); at most %d swinging at once" % [N, bp, cp, cp - bp, bt, ct, ct - bt, most_swinging])
			check("only a few swing at once (%d)" % most_swinging, most_swinging <= 8)
			check("the crowd's cost is in reason (+%.1f ms a frame)" % (cp + ct - bp - bt), cp + ct - bp - bt < 14.0)
			return TK.done(fails)
	step += 1
	return false
