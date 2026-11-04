extends SceneTree
## 1.30 the Bulwark: it blocks most blows from the front (far more than a plain grunt's quarter), never from behind; a
## heavy or a kick breaks the guard (the blow lands and it reels long), and so do enough blows piled on it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var G
var P
var step := 0
var until := 0
var fails := 0
var n := 0
var blocks := 0
var behind := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -3.0), "role": "sword", "seed": 31, "personality": "bulwark"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(poise: float) -> HitData:
	var h := HitData.new()
	h.damage = 1.0
	h.poise = poise
	h.knockback_force = 0.5
	h.impact = "slice"
	return h


func reset(front: bool) -> float:
	g.global_position = Vector3(0, g.global_position.y, -3.0)
	g._set_state(G.S.CIRCLE)
	g._cooldown = 99.0
	g._guard_load = 0.0
	var to: Vector3 = stage.player.global_position - g.global_position
	g.facing.rotation.y = atan2(-to.x, -to.z) + (0.0 if front else PI)
	g.health.current_health = g.health.max_health
	return g.health.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			P = load("res://scripts/enemies/personality.gd")
			g = stage.camp.grunts[0]
			g.alert()
			stage.player.hurtbox.monitorable = false
			until = TK.wait_secs(1.0)
		1:
			var hp := reset(true)
			g._on_hit(blow(0.1), stage.player)
			if g.health.current_health == hp and g.state == G.S.BLOCK:
				blocks += 1
			n += 1
			until = TK.wait_secs(0.5)
			if n < 50:
				return false
		2:
			check("it blocks most front blows (%d of %d)" % [blocks, n], float(blocks) / n > 0.45)
			n = 0
		3:
			var hp := reset(false)
			g._on_hit(blow(0.1), stage.player)
			if g.health.current_health == hp:
				behind += 1
			n += 1
			until = TK.wait_secs(0.3)
			if n < 12:
				return false
		4:
			check("never from behind (%d)" % behind, behind == 0)
			var hp := reset(true)
			g._on_hit(blow(25.0), stage.player)
			check("a heavy breaks the guard: it lands", g.health.current_health < hp)
			check("and it reels long", g.state == G.S.STAGGER and g._stagger_len >= P.GUARD_BROKEN)
			until = TK.wait_secs(2.0)
		5:
			var hp := reset(true)
			g._guard_load = P.GUARD_BREAK - 3.0
			g._on_hit(blow(6.0), stage.player)
			check("blows piled on the guard break it", g.health.current_health < hp and g.state == G.S.STAGGER)
			return TK.done(fails)
	step += 1
	return false
