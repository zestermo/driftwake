extends State
class_name PlayerState

var player: Player
var input_buffer: InputBuffer


func _ready() -> void:
	await owner.ready
	player = owner as Player
	input_buffer = player.input_buffer


func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_camera_relative_direction(input: Vector2) -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	# Use the CameraRig's Y rotation to derive forward/right on XZ plane
	# CameraRig is Camera3D -> SpringArm3D -> CameraRig
	var rig := camera.get_parent().get_parent() as Node3D
	var yaw := rig.global_rotation.y

	# In Godot, rotation.y = 0 means facing -Z. So forward = -Z direction rotated by yaw.
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))

	return (forward * -input.y + right * input.x).normalized()


func get_camera_forward() -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	if not camera:
		return -player.player_model.global_basis.z
	var rig := camera.get_parent().get_parent() as Node3D
	var yaw := rig.global_rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
		player.velocity.y = maxf(player.velocity.y, -30.0)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_angle := atan2(-direction.x, -direction.z)
	player.player_model.rotation.y = lerp_angle(player.player_model.rotation.y, target_angle, 12.0 * delta)
