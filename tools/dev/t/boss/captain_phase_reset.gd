extends SceneTree
## 1.30 boss phase resets on a captain-style AI boss (the drowned captain, the stronghold officers: their BossLeap
## state runs BossReset): it leaps to the middle, the landing's shockwave throws a captain out, no blow hurts it until the
## roar's over, then it's back on its feet to fight.
const TK := preload("res://tools/dev/test_kit.gd")
var BR
var stage
var p
var r
var centre := Vector3.ZERO
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


func _blow() -> HitData:
	var h := HitData.new()
	h.damage = 30.0
	h.unblockable = true
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			BR = load("res://scripts/enemies/boss_reset.gd")
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			r = load("res://scripts/ai/rival_duel.gd").spawn(p, 0.5, "cutlass")
			r.get_node("Brain").order = "hold"
			centre = p.global_position + Vector3(0, 0, -10.0)
			r.global_position = centre + Vector3(7.0, 0.3, 0.0)
			r.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			p.global_position = centre + Vector3(0, 0.1, 2.5)
			p.reset_physics_interpolation()
			hp0 = _hp()
			r.state_machine.force_state("BossLeap", {"reset": BR.new(r).start(BR.floor_at(r, centre))})
			check("it crouches to leap home", r.current_state_name() == "BossLeap")
			until = TK.wait_secs(BR.WIND + BR.AIR * 0.5)
		2:
			check("mid-leap it's up in the air (%.1f m)" % (r.global_position.y - centre.y), r.global_position.y > centre.y + 2.5)
			until = TK.wait_secs(BR.AIR * 0.5 + 0.15)
		3:
			check("it lands on the middle (%.2f m off)" % _flat(r.global_position - centre), _flat(r.global_position - centre) < 0.6)
			check("the shockwave hurts a little (%.1f)" % (hp0 - _hp()), hp0 - _hp() > 0.0 and hp0 - _hp() < 20.0)
			var hp: float = r.health_component.current_health
			r.get_node("Hurtbox").take_hit(_blow(), p)
			check("no blow hurts it while it roars", is_equal_approx(r.health_component.current_health, hp))
			until = TK.wait_secs(0.7)
		4:
			check("the shockwave threw the captain out (%.1f m from the middle)" % _flat(p.global_position - centre), _flat(p.global_position - centre) > 6.0)
			until = TK.wait_secs(BR.ROAR_S)
		5:
			check("the roar over, it's back on its feet (%s)" % r.current_state_name(), r.current_state_name() != "BossLeap")
			var hp: float = r.health_component.current_health
			r.get_node("Hurtbox").take_hit(_blow(), p)
			check("...and blows land again", r.health_component.current_health < hp)
			return TK.done(fails)
	step += 1
	return false
