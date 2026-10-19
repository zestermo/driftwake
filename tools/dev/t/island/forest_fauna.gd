extends SceneTree
## The forest's wildlife and folklore on the light stage. By day: a herd of red deer 12 m off throws up its
## heads and bounds away; a red fox bolts; a treantling 3 m off wakes, raises its branches and slams the captain,
## and its bark turns a blow from the front but not from behind; a wood sprite 18 m off lies hidden under the
## leaves. Struck, the stag turns on you and charges. At night: a will-o'-wisp near the captain draws off ahead
## of them, glowing (faint by day), and a wood sprite is up, notices and pounces. Every forest kind in its roster
## has its script.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var S: Dictionary
var stag
var hinds: Array = []
var fox
var tree
var sprite
var wisp
var d0 := {}
var seen := {}
var hp0 := 0.0
var looks := 0


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


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _hour(h: float) -> void:
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(h))
	# (the stage's Weather doesn't run its sky: night as the hour has it)
	wx.night = 1.0 if h > 20.0 or h < 5.0 else 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	var F := "res://scripts/enemies/fauna/"
	match step:
		0:
			S = load(F + "creature.gd").S
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			_hour(11.0)
			stag = _spawn(F + "deer.gd", ground + Vector3(0, 0, -12.0), {"lead": true, "morph": 0})
			for i in range(2):
				hinds.append(_spawn(F + "deer.gd", ground + Vector3(2.0 + i * 1.5, 0, -13.0), {"morph": 0}))
			fox = _spawn(F + "red_fox.gd", ground + Vector3(6.0, 0, 3.0), {"morph": 0})
			tree = _spawn(F + "treant.gd", ground + Vector3(-2.0, 0, -2.0), {"morph": 0})
			sprite = _spawn(F + "wood_sprite.gd", ground + Vector3(-18.0, 0, 6.0), {"morph": 0})
			wisp = _spawn(F + "wisp.gd", ground + Vector3(30.0, 0, 30.0), {"morph": 0})
			d0 = {"hind": hinds[0].global_position.distance_to(p.global_position), "fox": fox.global_position.distance_to(p.global_position)}
			seen = {"tell": false, "slam": false, "hidden": true}
			hp0 = _hp()
			looks = 0
			step = 1
			until = TK.wait_ticks(2)
		1:
			# 7 s in 0.25 s looks, by day
			looks += 1
			if tree.state == S.TELL:
				seen["tell"] = true
			if tree.state == S.ATTACK:
				seen["slam"] = true
			if sprite.state != S.HIDE:
				seen["hidden"] = false
			if looks < 28:
				until = TK.wait_secs(0.25)
				return false
			var hd: float = hinds[0].global_position.distance_to(p.global_position)
			var fd: float = fox.global_position.distance_to(p.global_position)
			check("the herd threw up its heads and bounded off (%.1f -> %.1f m)" % [d0["hind"], hd], hd > d0["hind"] + 6.0)
			check("the fox bolted (%.1f -> %.1f m)" % [d0["fox"], fd], fd > d0["fox"] + 4.0)
			check("the treantling woke, raised its branches and slammed the captain (%.0f hp)" % (hp0 - _hp()), seen["tell"] and seen["slam"] and _hp() < hp0)
			var fwd: Vector3 = tree._fwd()
			tree.state = S.CHASE
			check("its bark turns a blow from the front, not from behind", tree._armor(HitData.new(), -fwd) < 0.6 and tree._armor(HitData.new(), fwd) == 1.0)
			check("by day the sprite lies hidden under the leaves", seen["hidden"] and sprite.state == S.HIDE)
			tree.queue_free()
			# struck, the stag turns and charges
			stag.global_position = p.global_position + Vector3(0, 0, -5.0)
			stag.reset_physics_interpolation()
			var hit := HitData.new()
			hit.damage = 1.0
			# the stag turns on 3 blows in 4 (its rng is seeded by its auto-numbered node name, which moves with every node made before it)
			stag._rng.seed = 7
			stag._on_hit(hit, p)
			seen = {"charge": false}
			looks = 0
			step = 2
			until = TK.wait_ticks(2)
		2:
			looks += 1
			if stag.state == S.ATTACK:
				seen["charge"] = true
			if looks < 12 and not seen["charge"]:
				until = TK.wait_secs(0.2)
				return false
			check("struck, the stag turned on the captain and charged", seen["charge"])
			_hour(23.5)
			wisp.global_position = p.global_position + Vector3(5.0, 0, 0)
			wisp.home = wisp.global_position
			wisp.reset_physics_interpolation()
			sprite.global_position = p.global_position + Vector3(-8.0, 0, 0)
			sprite.home = sprite.global_position
			sprite.reset_physics_interpolation()
			d0 = {"wisp": 5.0}
			seen = {"fled": false, "sprite": false, "pounce": false}
			hp0 = _hp()
			looks = 0
			step = 3
			until = TK.wait_ticks(2)
		3:
			# 8 s at night
			looks += 1
			if wisp.state == S.FLEE:
				seen["fled"] = true
			if sprite.state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK]:
				seen["sprite"] = true
			if sprite.state == S.ATTACK:
				seen["pounce"] = true
			if looks < 32:
				until = TK.wait_secs(0.25)
				return false
			var wd: float = wisp.global_position.distance_to(p.global_position)
			check("at night the wisp drew off ahead of the captain (5.0 -> %.1f m), glowing (%.2f)" % [wd, wisp.anim_a], seen["fled"] and wd > 7.0 and wisp.anim_a > 0.8)
			check("at night the sprite was up, noticed the captain and pounced", seen["sprite"] and seen["pounce"])
			var f = load("res://scripts/island/themes/island_themes.gd").of("forest")
			check("the roster: deer, boar, fox, wolf, wisp, sprite, treant, bat, crab, each with its script; caves get sprites and treants",
				f.fauna.keys().all(func(k): return f.creatures.has(k) and ResourceLoader.exists(f.creatures[k]))
				and ["deer", "wisp", "sprite", "treant", "fox"].all(func(k): return f.fauna.has(k)) and f.cave_fauna["floor"].has("sprite"))
			return TK.done(fails)
	return false
