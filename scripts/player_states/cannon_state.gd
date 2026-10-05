extends PlayerState
## Manning a ship's swivel cannon. You stand at the breech with both hands
## on it; the view goes to the gun's own camera, the mouse swings the barrel
## and a dotted arc shows where the ball will come down. Left click fires
## (a reload bar fills back up), F or Space steps away. A hit that knocks
## you down knocks you off the gun too.

const SENS := 0.0022

var cannon: ShipCannon
var camera_rig: Node3D
var _cooldown: float = 0.0


func enter(data: Dictionary) -> void:
	cannon = data.get("cannon") as ShipCannon
	if cannon == null or not is_instance_valid(cannon):
		transitioned.emit(self, "Idle", {})
		return
	player.context = Player.Context.CANNON
	player.sheathe_weapon(true)
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.current_ship = cannon.ship as Ship if cannon.ship is Ship else player.current_ship
	cannon.aiming_locally = true
	player.body_model.manning = true
	_pin()
	player.reset_physics_interpolation()
	_cooldown = 0.3
	camera_rig = _find_camera_rig()
	if camera_rig:
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if cannon.camera:
		cannon.camera.current = true
	player.call("_toast", "Mouse: aim   Left click: fire   F: leave the gun")


## Stand at the breech, facing along the barrel.
func _pin() -> void:
	var yb := cannon.global_basis * Basis(Vector3.UP, cannon.yaw)
	var back := (yb * Vector3(0, 0, 1)).normalized()
	var spot := cannon.global_position + back * 0.95
	player.global_position = Vector3(spot.x, cannon.global_position.y + 0.02, spot.z)
	var fwd := -back
	player.player_model.rotation.y = atan2(-fwd.x, -fwd.z)


func physics_update(delta: float) -> void:
	if cannon == null or not is_instance_valid(cannon):
		transitioned.emit(self, "Idle", {})
		return
	_pin()
	player.velocity = Vector3.ZERO
	var f := cannon.reload_frac()
	get_tree().call_group("hud", "show_prompt", "Left click: fire   F: leave" if cannon.loaded() else "Reloading...", f)
	if _cooldown > 0.0:
		_cooldown -= delta
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		transitioned.emit(self, "Idle", {})
		return
	if Input.is_action_just_pressed("light_attack") and not player.input_locked:
		if cannon.fire(player):
			player.body_model.play("hit", 0.25)


func handle_input(event: InputEvent) -> void:
	if cannon and event is InputEventMouseMotion and not player.input_locked:
		cannon.yaw -= event.screen_relative.x * SENS
		cannon.pitch -= event.screen_relative.y * SENS * 0.7


func exit() -> void:
	player.context = Player.Context.ON_FOOT
	player.body_model.manning = false
	get_tree().call_group("hud", "show_prompt", "", -1.0)
	if cannon and is_instance_valid(cannon):
		cannon.aiming_locally = false
		Net.release_seat(cannon)
		var yb := cannon.global_basis * Basis(Vector3.UP, cannon.yaw)
		var back := (yb * Vector3(0, 0, 1)).normalized()
		var spot := cannon.global_position + back * 1.1
		player.global_position = Vector3(spot.x, cannon.global_position.y + 0.08, spot.z)
		player.reset_physics_interpolation()
	if camera_rig:
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
		if cannon and is_instance_valid(cannon) and cannon.camera:
			camera_rig.global_rotation.y = cannon.camera.global_rotation.y
		var cam := camera_rig.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
		if cam:
			cam.current = true
	camera_rig = null
	cannon = null


func _find_camera_rig() -> Node3D:
	var parent := player.get_parent()
	if parent:
		for child in parent.get_children():
			if child.has_method("shake"):
				return child as Node3D
	return null
