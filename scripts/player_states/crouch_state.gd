extends PlayerState
## Sneaking (C toggles it, Player._unhandled_input): low on bent knees at SPEED,
## quieter footsteps, and enemies notice you later (Stealth). C again, sprint or
## jump stands you up; attacks and dodges go straight out of it (from behind, the
## dagger's backstab).

const SPEED := 3.0


func enter(_data: Dictionary) -> void:
	player.sprinting = false
	player.body_model.crouching = true


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	var input := get_movement_input()
	if input.length() > 0.1:
		var dir := get_camera_relative_direction(input)
		var speed := SPEED * (1.0 + player.progression.stat("sneak_pct")) * player.wade_mult()
		player.velocity.x = dir.x * speed
		player.velocity.z = dir.z * speed
		if player.armed:
			face_camera(delta)
		else:
			face_direction(dir, delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
		if player.armed:
			face_camera(delta)
	player.move_and_slide()
	player.progression.sneak(Vector2(player.velocity.x, player.velocity.z).length() * delta)

	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return
	if input.length() > 0.1 and player.inp.pressed("sprint") and player.can_sprint():
		transitioned.emit(self, "Move", {})
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


func exit() -> void:
	player.body_model.crouching = false
