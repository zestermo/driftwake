extends PlayerState


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() < 0.1:
		player.sprinting = false
		transitioned.emit(self, "Idle", {})
		return

	var direction := get_camera_relative_direction(input)
	var was_sprinting := player.sprinting
	player.sprinting = Input.is_action_pressed("sprint") and not player.is_using_item() and player.can_sprint()
	if player.sprinting:
		player.drain_sprint(delta)
		if not was_sprinting:
			player.on_sprint_start()
	var speed := player.sprint_speed if player.sprinting else player.move_speed
	if player.armed and not player.sprinting:
		speed *= player.combat_speed_mult
	if player.is_using_item():
		speed *= 0.5
	speed *= player.wade_mult()

	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.move_and_slide()

	# Combat stance strafes (faces the camera); otherwise face where we run.
	if player.armed and not player.sprinting:
		face_camera(delta)
	else:
		face_direction(direction, delta)

	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return

	if wants_jump():
		transitioned.emit(self, "Jump", {})
		return

	if wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return

	var next := combat_input()
	if next != "":
		transitioned.emit(self, next, {"combo_index": 0})
		return


func exit() -> void:
	player.sprinting = false
