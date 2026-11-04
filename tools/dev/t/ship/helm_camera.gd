extends SceneTree
## (1.30) The helm camera: taking the wheel eases in from where the captain's camera was (no cut, no snap to the
## stern), settles up behind her and above the sea, the scroll wheel sets its distance, and leaving hands the view
## back where it was. On foot with a weapon out, the scroll wheel moves the stance's own distance at once.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var rig
var step := 0
var until := 0
var fails := 0
var from := Vector3.ZERO
var yaw_off := 0.0
var len0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func wheel(up: bool, n: int) -> void:
	for i in n:
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
			e.pressed = pressed
			Input.parse_input_event(e)


func ship_cam() -> Camera3D:
	return ship.ship_camera.get_node("SpringArm3D/Camera3D")


func rig_cam() -> Camera3D:
	return rig.get_node("SpringArm3D/Camera3D")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			rig = stage.camera_rig
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 2.0)
			p.reset_physics_interpolation()
			# looking off the starboard beam, not down the stern
			yaw_off = 1.2
			rig.global_rotation.y = ship._cam_heading + yaw_off
			until = TK.wait_ticks(20)
		1:
			from = rig_cam().global_position
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			until = TK.wait_ticks(1)
		2:
			var d: float = ship_cam().global_position.distance_to(from)
			check("taking the wheel starts where the captain's camera was (%.2f m off)" % d, ship_cam().current and d < 1.5)
			check("...looking the same way, not snapped to the stern (cam_yaw %.2f)" % ship.cam_yaw, absf(wrapf(ship.cam_yaw - yaw_off, -PI, PI)) < 0.1)
			until = TK.wait_secs(1.5)
		3:
			var arm: SpringArm3D = ship.ship_camera.get_node("SpringArm3D")
			var cp := ship_cam().global_position
			var surf: float = root.get_node("Ocean").surface_at(cp)
			check("settled: above the sea (%.1f m over)" % (cp.y - surf), cp.y > surf + 0.5)
			check("...up behind her, looking down (pitch %.2f)" % arm.rotation.x, arm.rotation.x < 0.0)
			check("...at the ship's distance (%.1f of %.1f)" % [arm.spring_length, ship.layout.cam_arm], absf(arm.spring_length - ship.layout.cam_arm) < 1.0)
			len0 = arm.spring_length
			wheel(true, 3)
			until = TK.wait_secs(0.8)
		4:
			var arm: SpringArm3D = ship.ship_camera.get_node("SpringArm3D")
			check("the scroll wheel brings the helm camera in (%.1f -> %.1f)" % [len0, arm.spring_length], arm.spring_length < len0 * 0.8)
			wheel(false, 6)
			until = TK.wait_secs(0.8)
		5:
			var arm: SpringArm3D = ship.ship_camera.get_node("SpringArm3D")
			check("...and out past where it was (%.1f)" % arm.spring_length, arm.spring_length > len0 * 1.15)
			from = ship_cam().global_position
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(1)
		6:
			var d: float = rig_cam().global_position.distance_to(from)
			check("leaving the wheel hands the view back where it was (%.2f m off)" % d, rig_cam().current and d < 2.0)
			until = TK.wait_secs(2.0)
		7:
			var arm: SpringArm3D = rig.get_node("SpringArm3D")
			check("...then eases in to the captain's distance (%.1f of %.1f)" % [arm.spring_length, rig.current_zoom], absf(arm.spring_length - rig.current_zoom) < 1.0)
			p.draw_weapon(true)
			until = TK.wait_secs(1.0)
		8:
			var arm: SpringArm3D = rig.get_node("SpringArm3D")
			len0 = arm.spring_length
			check("weapon out: the stance's distance (%.1f)" % len0, absf(len0 - rig.combat_zoom) < 0.4)
			wheel(false, 4)
			until = TK.wait_secs(0.6)
		9:
			var arm: SpringArm3D = rig.get_node("SpringArm3D")
			check("in stance the scroll wheel moves the camera at once (%.1f -> %.1f)" % [len0, arm.spring_length], arm.spring_length > len0 + 1.5)
			var foot: float = rig.current_zoom
			p.sheathe_weapon(true)
			until = TK.wait_secs(1.2)
			len0 = foot
		10:
			var arm: SpringArm3D = rig.get_node("SpringArm3D")
			check("...and sheathed, the on-foot distance is as it was (%.1f of %.1f)" % [arm.spring_length, len0], absf(arm.spring_length - len0) < 0.6)
			return TK.done(fails)
	step += 1
	return false
