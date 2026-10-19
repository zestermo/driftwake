extends SceneTree
## Breath on a dive: Ctrl takes you under and holds you deeper, breath drains only while the head's under,
## Space kicks you back up through the surface, and breath comes back there. Treading water never spends it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var b0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func head_under() -> float:
	var h: Vector3 = p.body_model.head.global_position
	return p.water_surface(h) - h.y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			sw = p.get_node("StateMachine/Swim")
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(3.0)
		1:
			check("treading water for 3 s: breath full (%.1f / %.1f)" % [sw.breath, sw.breath_max()], is_equal_approx(sw.breath, sw.breath_max()))
			y0 = p.global_position.y
			TK.press("dodge")
			until = TK.wait_secs(1.5)
		2:
			print("   dove to ", snappedf(p.global_position.y - y0, 0.01), " m, head ", snappedf(head_under(), 0.01), " m under")
			check("Ctrl held: well under (%.2f m down)" % (y0 - p.global_position.y), p.global_position.y < y0 - 2.0 and head_under() > 1.0)
			check("...breath going while under (%.1f)" % sw.breath, sw.breath < sw.breath_max() - 1.0 and sw.breath > sw.breath_max() - 2.5)
			check("...the camera follows under the waves", sw.camera_under())
			TK.release("dodge")
			y0 = p.global_position.y
			until = TK.wait_secs(1.0)
		3:
			check("let go: stops going down, drifting slowly up (%.2f m, %.2f m/s)" % [p.global_position.y - y0, p.velocity.y], p.global_position.y > y0 + 0.1 and p.global_position.y < y0 + 1.2 and p.velocity.y > 0.5)
			b0 = sw.breath
			TK.press("jump")
			until = TK.wait_secs(2.5)
		4:
			TK.release("jump")
			check("Space: kicked back up to the surface (head %.2f m under)" % head_under(), head_under() < 0.05 and p.current_state_name() == "Swim")
			check("...not still diving", not p.body_model.diving)
			until = TK.wait_secs(2.5)
		5:
			check("breath back at the surface (%.1f)" % sw.breath, is_equal_approx(sw.breath, sw.breath_max()))
			check("no harm done (%.0f hp)" % p.health_component.current_health, is_equal_approx(p.health_component.current_health, p.health_component.max_health))
			return TK.done(fails)
	step += 1
	return false
