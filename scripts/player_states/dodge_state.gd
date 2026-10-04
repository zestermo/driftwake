extends PlayerState
## Sidestep dash: a quick burst in the input direction (relative to the
## camera) while the body keeps facing where it was, or the camera when the
## weapon is drawn. No input = backstep. Fast at push-off, easing out.

@export var dodge_speed: float = 13.0
@export var dodge_duration: float = 0.3
@export var iframes_duration: float = 0.22

var timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var iframes_ended: bool = false
var _trail_timer: float = 0.0


func enter(_data: Dictionary) -> void:
	timer = 0.0
	iframes_ended = false

	if player.armed:
		face_direction(get_camera_forward(), 1.0)
	var move_input := get_movement_input()
	if move_input.length() > 0.1:
		dodge_direction = get_camera_relative_direction(move_input)
	else:
		dodge_direction = player.player_model.global_basis.z.normalized()  # backstep
		dodge_direction.y = 0.0

	player.hurtbox.monitorable = false

	# dash direction in the model's frame picks sidestep / forward / backstep
	var local := player.player_model.global_basis.orthonormalized().inverse() * dodge_direction
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	player.body_model.play("dash", dodge_duration)
	player.squash(-2.2)
	CombatManager.apply_camera_shake(player.DASH_SHAKE)
	FX.dust(player.global_position - dodge_direction * 0.3 + Vector3(0, 0.05, 0), 7, 0.6)
	FX.sfx("whoosh", player.global_position, -9.0, 0.1, 1.15)
	_trail_timer = 0.0


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	timer += delta

	# burst then ease out (average ~0.85x dodge_speed)
	var u := clampf(timer / dodge_duration, 0.0, 1.0)
	var spd := dodge_speed * (1.4 - 1.1 * u)
	player.velocity.x = dodge_direction.x * spd
	player.velocity.z = dodge_direction.z * spd
	player.move_and_slide()
	if player.armed:
		face_camera(delta)
	_trail_timer -= delta
	if _trail_timer <= 0.0 and player.is_on_floor():
		_trail_timer = 0.05
		FX.dust(player.global_position + Vector3(0, 0.05, 0), 2, 0.4)

	if timer >= iframes_duration and not iframes_ended:
		iframes_ended = true
		player.hurtbox.monitorable = true

	if timer >= dodge_duration:
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})


func exit() -> void:
	player.hurtbox.monitorable = true
