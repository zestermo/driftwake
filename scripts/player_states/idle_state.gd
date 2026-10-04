extends PlayerState


func enter(_data: Dictionary) -> void:
	if player:
		player.jumps_remaining = player.max_jumps


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
	player.move_and_slide()

	var input := get_movement_input()
	if input.length() > 0.1:
		transitioned.emit(self, "Move", {})
		return

	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return

	if wants_jump():
		transitioned.emit(self, "Jump", {})
		return

	if player.armed:
		face_camera(delta)

	if wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return

	var next := combat_input()
	if next != "":
		transitioned.emit(self, next, {"combo_index": 0})
		return
