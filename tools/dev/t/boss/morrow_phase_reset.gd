extends SceneTree
## 1.30 boss phase resets (BossReset) on a humanoid boss: Morrow's phase 2 starts with a leap back to the fight's middle,
## a landing shockwave that throws a captain out (a little damage), then a roar no blow hurts him through.
const TK := preload("res://tools/dev/test_kit.gd")
var BR
const BOSS := "res://scripts/enemies/pirate_boss.gd"
var stage
var p
var b
var centre := Vector3.ZERO
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -14.0), "yaw": 0.0, "mode": "stand", "seed": 3, "captain": true,
		"script": BOSS, "title": "Test Boss"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			BR = load("res://scripts/enemies/boss_reset.gd")
			if stage.camp.grunts.is_empty():
				return false
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			b = stage.camp.grunts[0]
			centre = b.post
			b.global_position = centre + Vector3(8.0, 0.3, 0.0)
			b.reset_physics_interpolation()
			b.alert()
			until = TK.wait_ticks(10)
		1:
			p.global_position = centre + Vector3(0, 0.1, 2.5)
			p.reset_physics_interpolation()
			hp0 = _hp()
			b.health.current_health = b.health.max_health * 0.55
			until = TK.wait_ticks(2)
		2:
			check("below 60%: phase 2, and he crouches to leap home", b.phase == 2 and b.reset.active())
			until = TK.wait_secs(BR.WIND + BR.AIR * 0.5)
		3:
			check("mid-leap he's up in the air (%.1f m)" % (b.global_position.y - centre.y), b.global_position.y > centre.y + 2.5)
			until = TK.wait_secs(BR.AIR * 0.5 + 0.15)
		4:
			check("he lands on the fight's middle (%.2f m off)" % _flat(b.global_position - centre), _flat(b.global_position - centre) < 0.6)
			check("the shockwave hurts a little (%.1f)" % (hp0 - _hp()), hp0 - _hp() > 0.0 and hp0 - _hp() < 20.0)
			var hp: float = b.health.current_health
			var h := HitData.new()
			h.damage = 50.0
			b._on_hit(h, p)
			check("no blow hurts him while he roars", is_equal_approx(b.health.current_health, hp))
			until = TK.wait_secs(0.7)
		5:
			check("the shockwave threw the captain out (%.1f m from the middle)" % _flat(p.global_position - centre), _flat(p.global_position - centre) > 6.0)
			until = TK.wait_secs(BR.ROAR_S)
		6:
			check("the roar over, he fights on", not b.reset.active() and b._special == "")
			var hp: float = b.health.current_health
			var h := HitData.new()
			h.damage = 20.0
			h.dot = true
			b._on_hit(h, p)
			check("...and blows land again", b.health.current_health < hp)
			return TK.done(fails)
	step += 1
	return false
