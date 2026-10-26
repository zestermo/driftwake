extends SceneTree
## 1.23 smarter enemies, group tactics: a tier-3 camp sends three at a captain at once (a low one two); a horn-blower
## left alive 8 s into a fight calls the nearest other camp, whose men come running; a camp captain in the fight gives
## the men near him +15% damage (gone once he's down).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var G
var GC
var step := 0
var until := 0
var fails := 0
var far
var horn
var cap
var man
var base := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0.0, 0, -6.0), "role": "sword", "seed": 111, "horn": true},
		{"post": Vector3(3.0, 0, -6.0), "role": "sword", "seed": 112, "captain": true, "title": "Cap"},
		{"post": Vector3(5.0, 0, -7.0), "role": "sword", "seed": 113}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 3:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			GC = load("res://scripts/enemies/grunt_camp.gd")
			var c3 = GC.new()
			c3.level = 19
			var c1 = GC.new()
			c1.level = 6
			check("a tier-3 camp sends three at once, a tier-1 two (%d, %d)" % [c3.attackers_for(), c1.attackers_for()],
				c3.attackers_for() == 3 and c1.attackers_for() == 2)
			c3.free()
			c1.free()
			# another camp 40 m off, idle
			far = GC.new()
			far.add_grunt({"post": Vector3.ZERO, "role": "sword", "seed": 121})
			far.add_grunt({"post": Vector3(2, 0, 0), "role": "sword", "seed": 122})
			stage.add_child(far)
			far.global_position = stage.camp.global_position + Vector3(40, 0, 0)
			stage.player.hurtbox.monitorable = false
			until = TK.wait_secs(1.0)
		1:
			horn = stage.camp.grunts[0]
			cap = stage.camp.grunts[1]
			man = stage.camp.grunts[2]
			base = man._hit_light.damage
			for g in stage.camp.grunts:
				g.alert()
			until = TK.wait_secs(2.5)
		2:
			check("men near their captain in a fight hit 15%% harder (%.1f -> %.1f)" % [base, man._hit_light.damage], absf(man._hit_light.damage - base * 1.15) < 0.05)
			until = TK.wait_secs(6.5)
		3:
			var coming := 0
			for g in far.grunts:
				if g.state != G.S.IDLE:
					coming += 1
			check("the horn-blower called the other camp after 8 s (%d coming)" % coming, horn.state != G.S.DEAD and coming == far.grunts.size())
			cap.health.take_damage(99999.0)
			until = TK.wait_secs(1.5)
		4:
			check("with the captain down the bonus goes (%.1f)" % man._hit_light.damage, absf(man._hit_light.damage - base) < 0.05)
			return TK.done(fails)
	step += 1
	return false
