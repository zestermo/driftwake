extends PlayerState


func enter(_data: Dictionary) -> void:
	player.jumps_remaining -= 1
	player.velocity.y = player.jump_force


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() > 0.1:
		var direction := get_camera_relative_direction(input)
		player.velocity.x = direction.x * player.move_speed
		player.velocity.z = direction.z * player.move_speed
		face_direction(direction, delta)

	player.move_and_slide()

	# Double jump
	if Input.is_action_just_pressed("jump") and player.jumps_remaining > 0:
		player.jumps_remaining -= 1
		player.velocity.y = player.jump_force
		return

	if player.velocity.y < 0.0:
		transitioned.emit(self, "Fall", {})
