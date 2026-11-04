extends SceneTree
## 1.30 "Boss space" (BossReset.clear): a beast boss crowded for CROWD_S rears up and roars a ring that throws the
## captain out (a little damage, blows still land on it); pinned out at its arena's edge it leaps back to the middle
## instead; a burst of blows sets it off too.
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
var bhp := 0.0
var waited := 0


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


## No moves of its own: only the clearing move can start.
func _hush() -> void:
	for k in b._cd.keys():
		b._cd[k] = 999.0


func _blow() -> HitData:
	var h := HitData.new()
	h.damage = 5.0
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
			var th = load("res://scripts/island/themes/island_themes.gd").of("snow")
			centre = p.global_position + Vector3(0, 0, -12.0)
			b = load(th.beasts["great_bear"]["script"]).new()
			b.setup({"post": centre, "yaw": 0.0, "level": 6, "name": "The Bear King"})
			stage.add_child(b)
			b.add_to_group("bosses")
			b.global_position = centre + Vector3.UP * 0.3
			b.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			b.alert()
			b.end_move()
			b.bp.chain_over()
			_hush()
			b._space()._cd = 0.0
			p.global_position = b.global_position + Vector3(0, 0, 3.0)
			p.reset_physics_interpolation()
			hp0 = _hp()
			until = TK.wait_secs(BR.CROWD_S - 1.0)
		2:
			_hush()
			check("crowded under %.0f s: no clearing move yet ('%s')" % [BR.CROWD_S, b.move], b.move != "clear_ring")
			waited = 0
			until = TK.wait_ticks(1)
		3:
			# (it comes within a couple of seconds more: the crowding clock and its free moment)
			_hush()
			waited += 1
			if b.move != "clear_ring" and waited < 180:
				until = TK.wait_ticks(1)
				return false
			check("crowded ~%.0f s: it rears up for a roar ring where it stands" % BR.CROWD_S, b.move == "clear_ring" and b.reset.active() and not b.reset.guarding())
			bhp = b.health.current_health
			b._on_hit(_blow(), p)
			check("...blows still land through it", b.health.current_health < bhp)
			until = TK.wait_secs(BR.RING_WIND + 0.4)
		4:
			check("the ring hurts a little (%.1f)" % (hp0 - _hp()), hp0 - _hp() > 0.0 and hp0 - _hp() < 15.0)
			check("...and throws the captain out (%.1f m from it)" % _flat(p.global_position - b.reset.to), _flat(p.global_position - b.reset.to) > 6.5)
			until = TK.wait_secs(BR.CLEAR_ROAR)
		5:
			check("then it fights on", not b.reset.active())
			# pinned out at the edge, crowded: it leaps back to the middle instead
			b.global_position = centre + Vector3(12.0, 0.3, 0.0)
			b.reset_physics_interpolation()
			p.global_position = b.global_position + Vector3(2.5, 0, 0)
			p.reset_physics_interpolation()
			b.end_move()
			b.mv_t = 0.0
			b._space()._cd = 0.0
			b._space()._crowd = BR.CROWD_S
			until = TK.wait_ticks(3)
		6:
			check("pinned at the edge: it leaps for the middle", b.move == "leap_home" and not b.reset.guarding())
			until = TK.wait_secs(BR.WIND + BR.AIR + 0.15)
		7:
			check("...and lands there (%.2f m off)" % _flat(b.global_position - centre), _flat(b.global_position - centre) < 1.0)
			until = TK.wait_secs(BR.CLEAR_ROAR + 0.2)
		8:
			# a burst of blows: the same
			_hush()
			b.end_move()
			b.mv_t = 0.0
			b._space()._cd = 0.0
			b._space()._crowd = 0.0
			p.global_position = b.global_position + Vector3(0, 0, 12.0)
			p.reset_physics_interpolation()
			for i in range(BR.BURST_N):
				b._on_hit(_blow(), p)
			until = TK.wait_ticks(3)
		9:
			check("%d blows in a burst: it makes space ('%s')" % [BR.BURST_N, b.move], b.move in ["clear_ring", "leap_home"] and b.reset.active())
			return TK.done(fails)
	step += 1
	return false
