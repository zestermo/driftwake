extends PlayerState


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() > 0.1:
		var direction := get_camera_relative_direction(input)
		player.velocity.x = direction.x * player.move_speed * 0.8
		player.velocity.z = direction.z * player.move_speed * 0.8
		face_direction(direction, delta)

	player.move_and_slide()

	# Double jump while falling
	if Input.is_action_just_pressed("jump") and player.jumps_remaining > 0:
		transitioned.emit(self, "Jump", {})
		return

	if player.is_on_floor():
		player.jumps_remaining = player.max_jumps
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})
