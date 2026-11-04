extends SceneTree
## 1.30 boss phase resets (BossReset): a beast boss's new phase starts with a leap back to its arena's middle, a landing
## shockwave that throws a captain standing there out (a little damage), then a roar no blow hurts it through; then the
## new phase's moves.
const TK := preload("res://tools/dev/test_kit.gd")
var BR
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
	stage = TK.stage(self, {})


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
			var th = load("res://scripts/island/themes/island_themes.gd").of("snow")
			centre = p.global_position + Vector3(0, 0, -12.0)
			b = load(th.beasts["great_bear"]["script"]).new()
			b.setup({"post": centre, "yaw": 0.0, "level": 6, "name": "The Bear King"})
			stage.add_child(b)
			b.add_to_group("bosses")
			b.global_position = centre + Vector3(9.0, 0.3, 0.0)
			b.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			b.alert()
			b.end_move()
			p.global_position = centre + Vector3(0, 0.1, 2.5)
			p.reset_physics_interpolation()
			hp0 = _hp()
			b.health.current_health = b.health.max_health * 0.55
			b._phase_check()
			check("below 60%: phase 2, and it crouches to leap home", b.phase == 2 and b.reset.active() and b.move == "leap_home")
			until = TK.wait_secs(BR.WIND + BR.AIR * 0.5)
		2:
			check("mid-leap it's up in the air (%.1f m)" % (b.global_position.y - centre.y), b.global_position.y > centre.y + 2.5)
			until = TK.wait_secs(BR.AIR * 0.5 + 0.15)
		3:
			check("it lands on the arena's middle (%.2f m off)" % _flat(b.global_position - centre), _flat(b.global_position - centre) < 0.6)
			check("...and roars (its moment's pose)", b.move == "moment")
			check("the shockwave hurts a little (%.1f)" % (hp0 - _hp()), hp0 - _hp() > 0.0 and hp0 - _hp() < 20.0)
			var hp: float = b.health.current_health
			var h := HitData.new()
			h.damage = 50.0
			b._on_hit(h, p)
			check("no blow hurts it while it roars", is_equal_approx(b.health.current_health, hp))
			until = TK.wait_secs(0.7)
		4:
			check("the shockwave threw the captain out (%.1f m from the middle)" % _flat(p.global_position - centre), _flat(p.global_position - centre) > 6.0)
			until = TK.wait_secs(BR.ROAR_S)
		5:
			check("the roar over, it fights on with its phase-2 moves", not b.reset.active() and b.move != "leap_home" and "slam" in b.bp.moves())
			var hp: float = b.health.current_health
			var h := HitData.new()
			h.damage = 50.0
			b._on_hit(h, p)
			check("...and blows land again", b.health.current_health < hp)
			check("its model is put back after the leap's pose", b.model.scale.is_equal_approx(Vector3.ONE))
			return TK.done(fails)
	step += 1
	return false
