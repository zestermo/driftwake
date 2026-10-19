extends SceneTree
## A jellyfish field stings a swimmer who touches a jelly (damage, a slower stroke for a moment, not again
## at once), and leaves one who keeps clear alone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var threats
var field
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			sw = p.get_node("StateMachine/Swim")
			threats = load("res://scripts/swim/sea_threats.gd").new()
			threats.name = "SeaThreats"
			stage.add_child(threats)
			threats._add_field(stage, Vector3(stage.SHORE_X + 30.0, stage.SEA_FLOOR, 0), 77)
			field = threats._fields[0]
			# clear of the field first
			p.global_position = Vector3(stage.SHORE_X + 6.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
		1:
			hp0 = p.health_component.current_health
			until = TK.wait_secs(1.5)
		2:
			check("clear of the field: not stung", is_equal_approx(p.health_component.current_health, hp0))
			# right into a jelly
			var j: Vector3 = threats.jelly_at(field, 0)
			p.global_position = Vector3(j.x, p.global_position.y, j.z)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(12)
		3:
			check("touching a jelly stings (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			check("...and slows the stroke for a moment", sw.stung > 0.5)
			hp0 = p.health_component.current_health
			until = TK.wait_ticks(20)
		4:
			check("...not stung again at once", p.health_component.current_health >= hp0 - 0.01)
			return TK.done(fails)
	step += 1
	return false
