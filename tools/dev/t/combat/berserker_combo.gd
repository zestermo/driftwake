extends SceneTree
## 1.30 the Berserker: a three-cut combo (a plain grunt's is two), a short breather between attacks, it never steps
## back after one, and it runs in faster.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var G
var step := 0
var until := 0
var fails := 0
var third := false
var attacks := 0
var cools: Array = []
var backoff := false
var last_state := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -6.0), "role": "sword", "seed": 51, "personality": "berserker"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if g and G and step == 2:
		if g.state == G.S.SWING and g._attack in ["combo", "flurry"] and g._swing_i == 2:
			third = true
		if g.state != last_state and last_state == G.S.RECOVER:
			attacks += 1
			cools.append(g._cooldown)
		if g._backoff_t > 0.0:
			backoff = true
		last_state = g.state
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			g = stage.camp.grunts[0]
			stage.player.hurtbox.monitorable = false
			g._peril_cd = 99.0
			g.alert()
			until = TK.wait_secs(0.3)
		1:
			until = TK.wait_secs(14.0)
		2:
			check("a three-cut combo", third)
			check("it attacked a few times (%d)" % attacks, attacks >= 3)
			var most := 0.0
			for c in cools:
				most = maxf(most, float(c))
			check("short breathers (at most %.2f s)" % most, most <= 0.81)
			check("it never steps back", not backoff)
			return TK.done(fails)
	step += 1
	return false
