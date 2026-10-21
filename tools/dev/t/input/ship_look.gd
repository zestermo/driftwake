extends SceneTree
## The right stick aboard: at the helm it looks round the ship camera, at a cannon it lays the gun (slower
## than the camera turns).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var gun
var step := 0
var until := 0
var fails := 0
var v0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 2.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			until = TK.wait_ticks(5)
		2:
			v0 = ship.cam_yaw
			axis(JOY_AXIS_RIGHT_X, 1.0)
			until = TK.wait_secs(0.3)
		3:
			check("at the helm the stick looks round (cam_yaw %.2f -> %.2f)" % [v0, ship.cam_yaw], ship.cam_yaw < v0 - 0.4)
			axis(JOY_AXIS_RIGHT_X, 0.0)
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(5)
		4:
			gun = ship.cannons[0]
			p.state_machine.force_state("Cannon", {"cannon": gun})
			until = TK.wait_ticks(5)
		5:
			check("manning a gun (%s)" % p.current_state_name(), p.current_state_name() == "Cannon")
			v0 = gun.yaw
			axis(JOY_AXIS_RIGHT_X, 0.6)
			until = TK.wait_secs(0.3)
		6:
			var d: float = v0 - gun.yaw
			check("at a cannon the stick lays the gun (yaw %.3f -> %.3f)" % [v0, gun.yaw], d > 0.01 and d < 0.4)
			axis(JOY_AXIS_RIGHT_X, 0.0)
			return TK.done(fails)
	step += 1
	return false
