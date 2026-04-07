extends PlayerState


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() < 0.1:
		transitioned.emit(self, "Idle", {})
		return

	var direction := get_camera_relative_direction(input)
	var speed := player.sprint_speed if Input.is_action_pressed("sprint") else player.move_speed

	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.move_and_slide()

	face_direction(direction, delta)

	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return

	if Input.is_action_just_pressed("jump"):
		transitioned.emit(self, "Jump", {})
		return

	if input_buffer.consume_action("light_attack"):
		transitioned.emit(self, "LightAttack", {"combo_index": 0})
		return

	if input_buffer.consume_action("heavy_attack"):
		transitioned.emit(self, "HeavyAttack", {})
		return

	if input_buffer.consume_action("dodge"):
		transitioned.emit(self, "Dodge", {})
		return

	if input_buffer.consume_action("parry"):
		transitioned.emit(self, "Parry", {})
		return
