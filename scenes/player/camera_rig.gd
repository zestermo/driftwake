extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 60.0
@export var follow_speed: float = 20.0
@export var spring_length: float = 5.0
@export var min_zoom: float = 2.0
@export var max_zoom: float = 25.0
@export var zoom_speed: float = 1.5

var target: Node3D
var shake_intensity: float = 0.0
var shake_decay: float = 8.0
var current_zoom: float = 5.0

var _debug_timer: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_zoom = spring_length
	spring_arm.spring_length = current_zoom
	camera.add_to_group("player_camera")
	camera.make_current()
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	if target:
		global_position = target.global_position + Vector3(0, 1.2, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Scroll wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_zoom = maxf(current_zoom - zoom_speed, min_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_zoom = minf(current_zoom + zoom_speed, max_zoom)


func _process(delta: float) -> void:
	# Smooth zoom
	spring_arm.spring_length = lerpf(spring_arm.spring_length, current_zoom, 10.0 * delta)

	if target:
		var target_pos := target.global_position + Vector3(0, 1.2, 0)
		global_position = global_position.lerp(target_pos, follow_speed * delta)

	if shake_intensity > 0.0:
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

	# Debug logging
	_debug_timer += delta
	if _debug_timer >= 0.5:
		_debug_timer = 0.0
		var tgt_str := "null"
		if target:
			tgt_str = "%.1f,%.1f,%.1f" % [target.global_position.x, target.global_position.y, target.global_position.z]
		print("CAM_RIG: %.1f,%.1f,%.1f | CAM_GLOBAL: %.1f,%.1f,%.1f | TARGET: %s | SPRING: %.1f/%.1f | PITCH: %.1f | YAW: %.1f | CURRENT: %s | PROCESSING: %s" % [
			global_position.x, global_position.y, global_position.z,
			camera.global_position.x, camera.global_position.y, camera.global_position.z,
			tgt_str,
			spring_arm.spring_length, current_zoom,
			rad_to_deg(spring_arm.rotation.x),
			rad_to_deg(rotation.y),
			str(camera.current),
			str(is_processing()),
		])


func shake(intensity: float, _duration: float = 0.2) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
