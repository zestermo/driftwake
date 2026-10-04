extends PlayerState
## Player is in a conversation: stand still, face the speaker.
## The Dialogue autoload enters/exits this state.

var _face_target: Vector3 = Vector3.ZERO


func enter(data: Dictionary) -> void:
	_face_target = data.get("face", Vector3.ZERO)
	if player.armed:
		player.sheathe_weapon()


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
	player.move_and_slide()
	if _face_target != Vector3.ZERO:
		var dir := _face_target - player.global_position
		dir.y = 0.0
		face_direction(dir.normalized(), delta)
