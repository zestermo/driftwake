extends PlayerState
## Airborne and descending. Coyote time lets you still jump just after
## running off a ledge; a jump pressed just before landing is buffered.


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() > 0.1:
		var direction := get_camera_relative_direction(input)
		var spd := air_speed()
		player.velocity.x = direction.x * spd
		player.velocity.z = direction.z * spd
		if player.armed:
			face_camera(delta)
		else:
			face_direction(direction, delta)

	player.move_and_slide()

	# ran off a ledge and coyote time is over: the ground jump is gone, only
	# air jumps (double jump, once unlocked) are left
	if not player.can_coyote_jump() and player.jumps_remaining == player.max_jumps:
		player.jumps_remaining -= 1

	if Input.is_action_just_pressed("jump"):
		if player.can_coyote_jump():
			transitioned.emit(self, "Jump", {"coyote": true})
			return
		if player.jumps_remaining > 0:
			transitioned.emit(self, "Jump", {})
			return

	if player.is_on_floor():
		player.jumps_remaining = player.max_jumps
		player.air_speed = 0.0
		if player.consume_jump_buffer():
			transitioned.emit(self, "Jump", {})
			return
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})
