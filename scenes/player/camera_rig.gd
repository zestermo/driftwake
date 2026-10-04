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
## 0 = exploring, 1 = combat stance (over-the-shoulder, closer).
var _combat_blend: float = 0.0
## Camera shoulder offset and max distance while the weapon is drawn.
@export var combat_shoulder: float = 0.55
@export var combat_max_zoom: float = 3.8

## Showcase (inventory open): the camera swings around in front of the player
## and frames them on the left of the screen, beside the inventory panel.
@export var showcase_zoom: float = 2.4
@export var showcase_offset: float = 1.65
@export var showcase_pitch: float = -0.06
var _show: float = 0.0
var _show_target: float = 0.0
var _saved_yaw: float = 0.0
var _saved_pitch: float = 0.0
var _show_yaw: float = 0.0
var _saved_mask: int = -1

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	# The rig is moved every rendered frame (in _process), so it must not be
	# physics-interpolated itself; it follows the player's interpolated transform.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_zoom = spring_length
	spring_arm.spring_length = current_zoom
	camera.add_to_group("player_camera")
	camera.make_current()
	camera.fov = float(Settings.get_value("video", "fov"))
	Settings.changed.connect(func(section: String, key: String, value: Variant):
		if section == "video" and key == "fov":
			camera.fov = float(value))
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	if target:
		global_position = target.get_global_transform_interpolated().origin + Vector3(0, 1.2, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative ignores the low-res viewport scaling, so sensitivity
		# stays the same at every PSX resolution preset.
		var sens := mouse_sensitivity * float(Settings.get_value("controls", "mouse_sensitivity"))
		var inv_y := -1.0 if Settings.get_value("controls", "invert_y") else 1.0
		rotate_y(-event.screen_relative.x * sens)
		spring_arm.rotate_x(-event.screen_relative.y * sens * inv_y)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	# Clicking back into the window recaptures the mouse (Esc opens the menu).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var menu := get_node_or_null("/root/GameMenu")
		if menu == null or not menu.is_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Scroll wheel zoom
	if event is InputEventMouseButton and _show_target == 0.0:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_zoom = maxf(current_zoom - zoom_speed, min_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_zoom = minf(current_zoom + zoom_speed, max_zoom)


func _process(delta: float) -> void:
	# Combat stance pulls the camera in over the right shoulder
	var in_combat := target is Player and (target as Player).armed and not (target as Player).sprinting
	_combat_blend = move_toward(_combat_blend, 1.0 if in_combat else 0.0, delta * 3.0)
	var zoom := lerpf(current_zoom, minf(current_zoom, combat_max_zoom), _combat_blend)
	_show = move_toward(_show, _show_target, delta * 2.6)
	var e := smoothstep(0.0, 1.0, _show)
	if _show > 0.0 or _show_target > 0.0:
		rotation.y = lerp_angle(_saved_yaw, _show_yaw, e)
		spring_arm.rotation.x = lerpf(_saved_pitch, showcase_pitch, e)
		zoom = lerpf(zoom, showcase_zoom, e)
	elif process_mode == Node.PROCESS_MODE_ALWAYS:
		process_mode = Node.PROCESS_MODE_INHERIT
		if _saved_mask >= 0:
			spring_arm.collision_mask = _saved_mask
			_saved_mask = -1
	spring_arm.spring_length = lerpf(spring_arm.spring_length, zoom, minf(10.0 * delta, 1.0))
	var shoulder := combat_shoulder * _combat_blend

	if target:
		# Use the interpolated transform: the player moves at the physics rate
		# (60 Hz), the camera at the display rate. Reading the raw position here
		# makes everything judder on high-refresh monitors.
		var target_pos := target.get_global_transform_interpolated().origin + Vector3(0, lerpf(1.2, 0.88, e), 0)
		# Clamp the weight: at low framerates (delta > 1/follow_speed) an
		# unclamped lerp overshoots and the camera flies away.
		global_position = global_position.lerp(target_pos, minf(follow_speed * delta, 1.0))
		# keep the camera above the waves (swimming, diving, falling in)
		var ocean := get_node_or_null("/root/Ocean")
		if ocean and camera:
			var cam_p := camera.global_position
			var wy := float(ocean.call("get_wave_height", cam_p)) + 0.35
			if cam_p.y < wy:
				global_position.y += wy - cam_p.y

	shoulder += showcase_offset * e
	if shake_intensity > 0.0:
		camera.h_offset = shoulder + randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = 0.15 * _combat_blend - 0.3 * e + randf_range(-shake_intensity, shake_intensity)
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera.h_offset = shoulder
		camera.v_offset = 0.15 * _combat_blend - 0.3 * e


## Swing around to face the character (`facing_yaw` = their model's yaw) and
## frame them to the left, or swing back to where the camera was.
func set_showcase(on: bool, facing_yaw: float = 0.0) -> void:
	if on:
		if _show_target == 0.0 and _show == 0.0:
			_saved_yaw = rotation.y
			_saved_pitch = spring_arm.rotation.x
		_show_yaw = facing_yaw + PI - 0.42
		_show_target = 1.0
		process_mode = Node.PROCESS_MODE_ALWAYS
		# frame the character even if a post or palm is behind the camera
		if _saved_mask < 0:
			_saved_mask = spring_arm.collision_mask
			spring_arm.collision_mask = 0
	else:
		_show_target = 0.0


func is_showcasing() -> bool:
	return _show_target > 0.0


func shake(intensity: float, _duration: float = 0.2) -> void:
	if not Settings.get_value("gameplay", "camera_shake"):
		return
	shake_intensity = maxf(shake_intensity, intensity)
