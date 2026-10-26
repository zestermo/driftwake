extends SceneTree
## 1.23 (Zach: enemies "leaving their arena and getting their health reset"): a pirate boss follows a fight further
## than his men (a knockback past a grunt's leash doesn't send him home), and walking back to his post he keeps his
## wounds: hit him on the way and the fight goes on where it was. Only back at his post does the fight start over.
const TK := preload("res://tools/dev/test_kit.gd")
const BOSS := "res://scripts/enemies/pirate_boss.gd"
var stage
var b
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -30.0), "yaw": PI, "mode": "stand", "seed": 3, "captain": true,
		"script": BOSS, "title": "Test Boss"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var G = load("res://scripts/enemies/pirate_grunt.gd")
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			b = stage.camp.grunts[0]
			check("a boss's leash is longer than his men's (%.0f vs %.0f m)" % [b._leash(), G.LEASH], b._leash() > G.LEASH * 1.5)
			b.health.current_health = b.health.max_health * 0.9
			# (knocked well away from his post, past a grunt's leash)
			b.global_position = b.post + Vector3(G.LEASH + 6.0, 0.5, 0)
			b.reset_physics_interpolation()
			b._set_state(G.S.RETURN)
			until = TK.wait_ticks(6)
		1:
			check("walking home he keeps his wounds (%.0f of %.0f)" % [b.health.current_health, b.health.max_health],
				b.health.current_health < b.health.max_health * 0.95)
			b._set_state(G.S.IDLE)
			until = TK.wait_ticks(6)
		2:
			check("back at his post the fight starts over (%.0f)" % b.health.current_health, is_equal_approx(b.health.current_health, b.health.max_health))
			return TK.done(fails)
	step += 1
	return false
