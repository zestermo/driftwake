extends SceneTree
## 1.30 verticality: an elite grunt jumps at a captain a few metres off (the gather, a telegraph where it lands, up
## off the ground, down onto the captain: it hurts), then waits its cooldown (10-15 s) before another; a plain grunt
## never jumps.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var e
var plain
var G
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var jumped := false
var top := -INF
var plain_jumped := false
var landed_at := Vector3.INF
var cd_after := 0.0
var gathered := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0, 0, -6.0), "role": "sword", "seed": 61, "elite": true, "personality": "none"},
		{"post": Vector3(9, 0, 4.0), "role": "sword", "seed": 62, "personality": "none"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if e and G:
		if plain.state == G.S.POUNCE:
			plain_jumped = true
		if e.state == G.S.WIND and e._attack in G.JUMPS and e.humanoid.current_action() == "fo_leap_wind":
			gathered = true
		if e.state == G.S.POUNCE:
			jumped = true
			top = maxf(top, e.global_position.y - stage.GROUND_Y)
			if e._jump_land >= 0.0 and landed_at == Vector3.INF:
				landed_at = e.global_position
				cd_after = e._jump_cd
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 2:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			e = stage.camp.grunts[0]
			plain = stage.camp.grunts[1]
			for g in [e, plain]:
				g._jump_cd = 0.0
				g._peril_cd = 99.0
				g._pistol_cd = 99.0
			plain.post = plain.global_position
			hp0 = stage.player.health_component.current_health
			e.alert()
			plain.alert()
			until = TK.wait_secs(5.0)
		1:
			check("it gathers for the jump (the wind-up pose)", gathered)
			check("it jumps at the captain", jumped)
			check("up off the ground (%.1f m)" % top, top > 0.8)
			var d := landed_at.distance_to(stage.player.global_position) if landed_at != Vector3.INF else INF
			check("it comes down by the captain (%.1f m)" % d, d < 2.2)
			check("and the blow lands (%.0f -> %.0f)" % [hp0, stage.player.health_component.current_health], stage.player.health_component.current_health < hp0)
			check("then a cooldown before another (%.1f s)" % cd_after, cd_after >= 9.0)
			check("a plain grunt never jumps", not plain_jumped)
			return TK.done(fails)
	step += 1
	return false
