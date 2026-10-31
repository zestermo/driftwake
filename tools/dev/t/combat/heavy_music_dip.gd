extends SceneTree
## The mix (1.28): a heavy blow (a long hit-stop or a knockdown) dips the music for a beat so it lands over it, and
## the music comes back within a second; a light blow leaves it alone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var music = root.get_node("Music")
	var cm = root.get_node("CombatManager")
	match step:
		0:
			var light = load("res://scripts/combat/hit_data.gd").new()
			light.hitstop_duration = 0.04
			cm.apply_hit_effects(light)
			check("a light blow leaves the music alone (%.1f dB)" % music._punch_db, music._punch_db == 0.0)
			var heavy = load("res://scripts/combat/hit_data.gd").new()
			heavy.hitstop_duration = 0.14
			heavy.knockdown = true
			cm.apply_hit_effects(heavy)
			check("a heavy blow dips it (%.1f dB)" % music._punch_db, music._punch_db >= 3.0)
			until = TK.wait_ticks(2)
		1:
			# (the light stage switches Music off: its recovery stepped by hand, a second of it)
			for i in range(60):
				music.punch_tick(1.0 / 60.0)
			check("and it comes back within a second (%.1f dB)" % music._punch_db, music._punch_db == 0.0)
			return TK.done(fails)
	step += 1
	return false
