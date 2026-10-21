extends SceneTree
## The right stick turns the camera: a full push at about Pad.LOOK_RATE, half a push far slower (the response
## curve), up tilts the view up, and nothing while the captain's input is locked (chat).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rig: Node3D
var step := 0
var until := 0
var fails := 0
var yaw0 := 0.0
var pitch0 := 0.0
var full := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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


func turned() -> float:
	return -angle_difference(yaw0, rig.rotation.y)


func mark() -> void:
	yaw0 = rig.rotation.y
	pitch0 = rig.get_node("SpringArm3D").rotation.x


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			rig = (get_first_node_in_group("player_camera") as Node).get_parent().get_parent()
			mark()
			axis(JOY_AXIS_RIGHT_X, 1.0)
			until = TK.wait_secs(0.4)
		1:
			full = turned()
			check("a full push right turns the view right (%.2f rad in 0.4 s)" % full, full > 0.9 and full < 1.9)
			axis(JOY_AXIS_RIGHT_X, 0.5)
			mark()
			until = TK.wait_secs(0.4)
		2:
			var half := turned()
			check("half a push turns far slower, the curve (%.2f vs %.2f)" % [half, full], half > 0.02 and half < full * 0.35)
			axis(JOY_AXIS_RIGHT_X, 0.0)
			mark()
			axis(JOY_AXIS_RIGHT_Y, -1.0)
			until = TK.wait_secs(0.2)
		3:
			var up: float = rig.get_node("SpringArm3D").rotation.x - pitch0
			check("pushing up tilts the view up (%.2f rad)" % up, up > 0.2)
			axis(JOY_AXIS_RIGHT_Y, 0.0)
			p.input_locked = true
			mark()
			axis(JOY_AXIS_RIGHT_X, 1.0)
			until = TK.wait_secs(0.3)
		4:
			check("not while the captain's input is locked (%.3f)" % turned(), absf(turned()) < 0.001)
			axis(JOY_AXIS_RIGHT_X, 0.0)
			p.input_locked = false
			return TK.done(fails)
	step += 1
	return false
