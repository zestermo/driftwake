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
	var kind := take_off(double)
	player.body_model.play(kind, ActionSpecs.length(kind))
	var at := player.global_position
	if double:
		# a kick off the air itself: a flat ring of wind under the feet
		Net.fx("ring", [at + Vector3(0, 0.05, 0), Vector3.UP, 0.85, Color(1.0, 0.98, 0.9, 0.8), 0.28, 0.08])
		Net.fx("motes", [at + Vector3(0, 0.1, 0), Vector3.DOWN, 8, Color(1.0, 0.97, 0.88), 4.0])
		Net.fx("sfx", ["jump", at, -8.0, 0.05, 1.15])
		Net.fx("sfx", ["whoosh", at, -12.0, 0.08, 1.3])
	elif kind == "jump_sprint":
		Net.fx("dust", [at + Vector3(0, 0.05, 0), 9, 0.7])
		Net.fx("sfx", ["jump", at, -7.0, 0.06, 0.92])
		Net.fx("sfx", ["whoosh", at, -14.0, 0.08, 0.9])
	else:
		Net.fx("dust", [at + Vector3(0, 0.05, 0), 6, 0.6])
		Net.fx("sfx", ["jump", at, -8.0, 0.06, 1.05 if kind == "jump_stand" else 1.0])


## Which take-off: the double jump, or by how fast you were going on the ground.
func take_off(double: bool) -> String:
	if double:
		return "double_jump"
	var h := Vector2(player.velocity.x, player.velocity.z).length()
	if h < 1.5:
		return "jump_stand"
	# (Move's exit has already cleared `sprinting`: go by the speed)
	return "jump_sprint" if h > (player.move_speed + player.sprint_speed) * 0.5 else "jump_run"


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
