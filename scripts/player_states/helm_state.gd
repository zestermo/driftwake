extends PlayerState

var camera_rig: Node3D  # The player's CameraRig
var ship_camera: Node3D  # The ship's ShipCamera
var mouse_sensitivity: float = 0.002
var enter_cooldown: float = 0.0


func enter(_data: Dictionary) -> void:
	player.context = Player.Context.HELM
	var ship := player.current_ship
	if not ship:
		transitioned.emit(self, "Idle", {})
		return

	# Lock player at helm
	player.global_position = ship.helm_position.global_position
	player.set_collision_layer_value(2, false)
	player.player_model.visible = false
	ship.is_player_steering = true

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


func physics_update(delta: float) -> void:
	if player.current_ship:
		player.global_position = player.current_ship.helm_position.global_position
		player.velocity = Vector3.ZERO
		player.move_and_slide()

	if enter_cooldown > 0.0:
		enter_cooldown -= delta
		return

	if Input.is_action_just_pressed("interact"):
		transitioned.emit(self, "Idle", {})


func handle_input(event: InputEvent) -> void:
	# Mouse look for ship camera
	if event is InputEventMouseMotion and ship_camera:
		ship_camera.rotate_y(-event.relative.x * mouse_sensitivity)
		var spring_arm := ship_camera.get_node("SpringArm3D") as SpringArm3D
		if spring_arm:
			spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(30))


func exit() -> void:
	player.context = Player.Context.ON_FOOT
	player.player_model.visible = true
	if player.current_ship:
		player.current_ship.is_player_steering = false
		player.global_position = player.current_ship.disembark_position.global_position
		player.set_collision_layer_value(2, true)

	# Restore player camera
	if camera_rig:
		camera_rig.set_process(true)
		camera_rig.set_process_unhandled_input(true)
		var player_cam := camera_rig.get_node("SpringArm3D/Camera3D") as Camera3D
		if player_cam:
			player_cam.current = true

	# Reset ship camera rotation
	if ship_camera:
		ship_camera.rotation = Vector3.ZERO
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
