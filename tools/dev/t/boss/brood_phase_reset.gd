extends SceneTree
## 1.30 boss phase resets on the Brood Queen (BossReset): under half health she bounds back onto her nest, the landing's
## shockwave throws a captain off it, nothing hurts her through the shriek, then her second phase.
const TK := preload("res://tools/dev/test_kit.gd")
var BR
var stage
var p
var q
var home := Vector3.ZERO
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			home = p.global_position + Vector3(0, 0, -12.0)
			q = load("res://scripts/enemies/brood_queen.gd").new().queen(home)
			stage.add_child(q)
			q.global_position = home + Vector3(8.0, 0.3, 0.0)
			q.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			q.wake()
			until = TK.wait_secs(1.5)
		2:
			p.global_position = home + Vector3(0, 0.1, 3.0)
			p.reset_physics_interpolation()
			hp0 = _hp()
			q.health.current_health = q.health.max_health * 0.45
			until = TK.wait_ticks(3)
		3:
			check("under half health: phase 2, and she crouches to bound home (%s)" % q._special, q.phase == 2 and q._special == "reset" and q.reset.active())
			until = TK.wait_secs(BR.WIND + BR.AIR + 0.15)
		4:
			check("she lands on her nest (%.2f m off)" % _flat(q.global_position - home), _flat(q.global_position - home) < 0.8)
			check("the shockwave hurts a little (%.1f)" % (hp0 - _hp()), hp0 - _hp() > 0.0 and hp0 - _hp() < 20.0)
			var hp: float = q.health.current_health
			var h := HitData.new()
			h.damage = 40.0
			q._on_hit(h, p)
			check("no blow hurts her through the shriek", is_equal_approx(q.health.current_health, hp))
			until = TK.wait_secs(BR.ROAR_S + 0.2)
		5:
			check("the shockwave threw the captain off the nest (%.1f m)" % _flat(p.global_position - home), _flat(p.global_position - home) > 6.0)
			check("the shriek over, she fights on", not q.reset.active() and q._special != "reset")
			return TK.done(fails)
	step += 1
	return false
