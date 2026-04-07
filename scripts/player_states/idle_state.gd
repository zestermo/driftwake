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
