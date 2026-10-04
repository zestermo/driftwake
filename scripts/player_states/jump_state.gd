extends PlayerState
## Jump / double jump. Hold jump for full height, tap for a short hop.


func enter(data: Dictionary) -> void:
	var double: bool = player.jumps_remaining < player.max_jumps and not data.get("coyote", false)
	player.air_speed = maxf(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed)
	_launch(double)


func _launch(double: bool) -> void:
	player.jumps_remaining -= 1
	player.velocity.y = player.jump_force * (0.92 if double else 1.0)
	player.variable_jump_active = true
	player.squash(4.5 if not double else 3.5)
	if double:
		player.body_model.play("flip", 0.45)
		Net.fx("sparkle", [player.global_position + Vector3(0, 0.8, 0), 10, Color(1.0, 0.95, 0.7)])
		Net.fx("sfx", ["jump", player.global_position, -8.0, 0.05, 1.15])
	else:
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 6, 0.6])
		Net.fx("sfx", ["jump", player.global_position, -8.0, 0.06])


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

	var air := air_attack_input()
	if air != "":
		transitioned.emit(self, air, {})
		return

	# Double jump
	if Input.is_action_just_pressed("jump") and player.jumps_remaining > 0:
		_launch(true)
		return

	if player.velocity.y < 0.0:
		transitioned.emit(self, "Fall", {})
