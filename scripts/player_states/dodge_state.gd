extends PlayerState

@export var dodge_speed: float = 12.0
@export var dodge_duration: float = 0.4
@export var iframes_duration: float = 0.3

var timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var iframes_ended: bool = false


func enter(_data: Dictionary) -> void:
	timer = 0.0
	iframes_ended = false

	# Determine dodge direction from input, or backward if no input
	var move_input := get_movement_input()
	if move_input.length() > 0.1:
		dodge_direction = get_camera_relative_direction(move_input)
	else:
		# Dodge backward relative to player facing
		dodge_direction = player.player_model.basis.z.normalized()

	# Enable i-frames
	player.hurtbox.monitorable = false

	# Face dodge direction
	face_direction(dodge_direction, 1.0)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	timer += delta

	player.velocity.x = dodge_direction.x * dodge_speed
	player.velocity.z = dodge_direction.z * dodge_speed
	player.move_and_slide()

	# End i-frames
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
