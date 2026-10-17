extends SceneTree
## The desert's wildlife on the light stage: a scorpion 5 m off notices the captain, squares up and
## strikes (a pinch or the sting), and its sting poisons; fennec foxes near the captain bolt and get
## away; a monitor lizard 3 m off basks until it notices, hisses and comes on; one far off minds its
## business; every desert creature kind is in the theme's roster with its script.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var scorp
var foxes: Array = []
var liz
var far_liz
var struck := false
var stung := false
var liz_came := false
var fox_d0 := 0.0
var S: Dictionary


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _spawn(script: String, at: Vector3, args: Dictionary) -> Node3D:
	var c = load(script).new()
	c.setup(at, args)
	c.position = at
	stage.add_child(c)
	return c


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	match step:
		0:
			S = load("res://scripts/enemies/fauna/creature.gd").S
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			scorp = _spawn("res://scripts/enemies/fauna/scorpion.gd", ground + Vector3(0, 0, -5.0), {"morph": 0})
			for i in range(2):
				foxes.append(_spawn("res://scripts/enemies/fauna/desert_fox.gd", ground + Vector3(5.0 + i, 0, 4.0), {"morph": i}))
			liz = _spawn("res://scripts/enemies/fauna/monitor_lizard.gd", ground + Vector3(-3.0, 0, 1.0), {"morph": 1})
			far_liz = _spawn("res://scripts/enemies/fauna/monitor_lizard.gd", ground + Vector3(-30.0, 0, 25.0), {"morph": 0})
			fox_d0 = foxes[0].global_position.distance_to(p.global_position)
			until = TK.wait_ticks(2)
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25:
			# 7.5 s in 0.3 s looks
			if is_instance_valid(scorp) and scorp.state == S.ATTACK:
				struck = true
				if not scorp.venom.is_empty():
					stung = true
			if liz.state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK]:
				liz_came = true
			until = TK.wait_secs(0.3)
		26:
			check("the scorpion noticed the captain and struck", struck)
			check("now and then with its sting, which carries poison", stung)
			var fd: float = foxes[0].global_position.distance_to(p.global_position)
			check("the foxes bolted and got away (%.1f -> %.1f m)" % [fox_d0, fd], fd > fox_d0 + 4.0)
			check("the lizard close by noticed, hissed and came on", liz_came)
			check("the lizard far off basked on (%s)" % S.keys()[far_liz.state], far_liz.state in [S.IDLE, S.WANDER])
			var d = load("res://scripts/island/themes/island_themes.gd").of("desert")
			check("the roster: scorpion, lizard, fox, crab, snake, burrower, bat, each with its script",
				d.fauna.keys().all(func(k): return d.creatures.has(k) and ResourceLoader.exists(d.creatures[k]))
				and ["scorpion", "lizard", "fox"].all(func(k): return d.fauna.has(k)) and d.cave_fauna["floor"].has("scorpion"))
			return TK.done(fails)
	step += 1
	return false
