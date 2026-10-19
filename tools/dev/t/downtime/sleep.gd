extends SceneTree
## Sleeping aboard (anchored): you lie down in the cabin's bunk; hurt, you heal as you sleep, and (solo) the
## hours pass quickly; getting up puts you on the floor beside the bunk.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var DT
var hp0 := 0.0
var wt0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func local() -> Vector3:
	return ship.global_transform.affine_inverse() * p.global_position


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			p.health_component.current_health = 30.0
			DT.start(p, "sleep")
			until = TK.wait_secs(0.6)
		2:
			var l := local()
			check("sleeping: lying in the bunk (%s)" % str(l), Vector2(l.x - ship.BED_AT.x, l.z - ship.BED_AT.z).length() < 0.6 and l.y > ship.BED_AT.y + 0.4 \
				and p.body_model.current_action() == "dt_sleep")
			hp0 = p.health_component.current_health
			wt0 = root.get_node("/root/Weather").world_time()
			until = TK.wait_secs(2.0 * DT.every(p, "sleep") + 0.2)
		3:
			var slept: float = root.get_node("/root/Weather").world_time() - wt0
			check("asleep, hurt: you heal (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health >= hp0 + 2.0 * DT.SLEEP_HEAL * p.health_component.max_health - 0.5)
			check("...and the hours pass quickly (%.0f s of the day in %.1f s)" % [slept, 2.0 * DT.every(p, "sleep")], slept > 10.0 * 2.0 * DT.every(p, "sleep"))
			TK.press("move_forward")
			until = TK.wait_ticks(4)
		4:
			TK.release("move_forward")
			var l := local()
			check("up again: on the floor beside the bunk (%s)" % str(l), p.current_state_name() != "Downtime" and absf(l.y - ship.DECK_Y) < 0.3 \
				and Vector2(l.x - ship.BED_AT.x, l.z - ship.BED_AT.z).length() < 1.6)
			return TK.done(fails)
	step += 1
	return false
