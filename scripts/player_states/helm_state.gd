extends PlayerState
## At the ship's wheel. The captain stays visible, standing at the helm with
## hands on the spokes; W/S set the sails a step at a time (they stay set when
## you let go, or leave the wheel), A/D the rudder (the wheel turns and the
## body leans with it). The ship camera follows the hull's heading; the
## mouse looks around. F steps away from the wheel (you stay on deck).

var camera_rig: Node3D  # The player's CameraRig
var ship_camera: Node3D  # The ship's ShipCamera
var mouse_sensitivity: float = 0.002
var enter_cooldown: float = 0.0


func enter(_data: Dictionary) -> void:
	player.context = Player.Context.HELM
	player.sheathe_weapon(true)
	var ship := player.current_ship
	if not ship:
		transitioned.emit(self, "Idle", {})
		return

	player.velocity = Vector3.ZERO
	player.sprinting = false
	_pin(ship)
	player.reset_physics_interpolation()
	player.body_model.at_helm = true
	ship.is_player_steering = true
	ship.cam_yaw = 0.0

	enter_cooldown = 0.3  # Prevent immediate exit from same F press

	# Find and disable player camera rig, enable ship camera
	camera_rig = _find_camera_rig()
	ship_camera = ship.ship_camera
	if camera_rig:
		camera_rig.set_process(false)
		camera_rig.set_process_unhandled_input(false)
	if ship_camera:
		var ship_cam := ship_camera.get_node("SpringArm3D/Camera3D") as Camera3D
		if ship_cam:
			ship_cam.current = true
	player.call("_toast", "W/S: set sails   A/D: rudder   Left click: broadside   F: leave the wheel")


## Stand at the wheel, facing the bow.
func _pin(ship: Ship) -> void:
	player.global_position = ship.helm_position.global_position
	player.player_model.rotation.y = ship.global_rotation.y


func physics_update(delta: float) -> void:
	var ship := player.current_ship
	if ship:
		_pin(ship)
		player.velocity = Vector3.ZERO
		player.body_model.helm_steer = ship.rudder

	if enter_cooldown > 0.0:
		enter_cooldown -= delta
		return

	if Input.is_action_just_pressed("interact"):
		transitioned.emit(self, "Idle", {})
		return
	# a broadside: every loaded gun on the side you're looking at
	if Input.is_action_just_pressed("light_attack") and ship and not player.input_locked:
		_broadside(ship)


func _broadside(ship: Ship) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	var right := ship.global_basis.x
	var side := 1.0 if fwd.dot(right) >= 0.0 else -1.0
	# aim where the view meets the sea (25-90 m out), along the beam
	var from := cam.global_position
	var target := Vector3.INF
	if fwd.y < -0.02:
		var t := -from.y / fwd.y
		target = from + fwd * t
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	if target == Vector3.INF or target.distance_to(ship.global_position) > 90.0:
		target = ship.global_position + flat * 70.0
	elif target.distance_to(ship.global_position) < 25.0:
		target = ship.global_position + flat * 25.0
	target.y = 0.0
	var n := ship.broadside(side, target, player)
	if n == 0:
		player.call("_toast", "Those guns are still reloading")


func handle_input(event: InputEvent) -> void:
	# Mouse look for ship camera
	if event is InputEventMouseMotion and ship_camera and player.current_ship:
		player.current_ship.cam_yaw -= event.screen_relative.x * mouse_sensitivity
		var spring_arm := ship_camera.get_node("SpringArm3D") as SpringArm3D
		if spring_arm:
			spring_arm.rotate_x(-event.screen_relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(30))


func exit() -> void:
	player.context = Player.Context.ON_FOOT
	player.body_model.at_helm = false
	player.body_model.helm_steer = 0.0
	player.velocity = Vector3.ZERO
	if player.current_ship:
		player.current_ship.is_player_steering = false
		player.current_ship.cam_yaw = 0.0
		Net.release_helm()
		# step back from the wheel, onto the deck
		player.global_position = player.current_ship.helm_position.global_position + Vector3.UP * 0.05
		player.reset_physics_interpolation()

	# Restore player camera, looking the way the ship camera was
	if camera_rig:
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
		if ship_camera:
			camera_rig.global_rotation.y = ship_camera.global_rotation.y
		var player_cam := camera_rig.get_node("SpringArm3D/Camera3D") as Camera3D
		if player_cam:
			player_cam.current = true

	# Reset ship camera pitch
	if ship_camera:
		var spring_arm := ship_camera.get_node("SpringArm3D") as SpringArm3D
		if spring_arm:
			spring_arm.rotation.x = deg_to_rad(20)

	camera_rig = null
	ship_camera = null


func _find_camera_rig() -> Node3D:
	# CameraRig is a sibling of the player in the scene tree
	var parent := player.get_parent()
	if parent:
		for child in parent.get_children():
			if child.has_method("shake"):  # CameraRig has this method
				return child as Node3D
	return null
