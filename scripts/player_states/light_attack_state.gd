extends PlayerState

@export var combo_count: int = 3
@export var combo_window: float = 0.35
@export var attack_duration: float = 0.35
@export var hitbox_start: float = 0.05
@export var hitbox_end: float = 0.2
@export var forward_impulse: float = 3.0

var combo_index: int = 0
var timer: float = 0.0
var can_combo: bool = false
var combo_timer: float = 0.0
var hitbox_activated: bool = false
var hitbox_deactivated: bool = false

var combo_damages: Array[float] = [10.0, 12.0, 20.0]
var combo_hitstops: Array[float] = [0.04, 0.04, 0.08]
var combo_shakes: Array[float] = [0.08, 0.08, 0.15]
var combo_swing_angles: Array[float] = [90.0, -90.0, 180.0]


func enter(data: Dictionary) -> void:
	combo_index = data.get("combo_index", 0)
	timer = 0.0
	can_combo = false
	combo_timer = 0.0
	hitbox_activated = false
	hitbox_deactivated = false

	# Snap player to face camera forward direction
	var forward := get_camera_forward()
	var target_angle := atan2(-forward.x, -forward.z)
	player.player_model.rotation.y = target_angle

	# Forward impulse on attack
	var face_dir := forward
	player.velocity.x = face_dir.x * forward_impulse
	player.velocity.z = face_dir.z * forward_impulse

	# Start sword swing tween
	_play_swing_animation()


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 15.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 15.0 * delta)
	player.move_and_slide()

	timer += delta

	# Hitbox timing
	if timer >= hitbox_start and not hitbox_activated:
		hitbox_activated = true
		var hit := HitData.new()
		hit.damage = combo_damages[combo_index] if combo_index < combo_damages.size() else 10.0
		hit.hitstop_duration = combo_hitstops[combo_index] if combo_index < combo_hitstops.size() else 0.04
		hit.camera_shake_intensity = combo_shakes[combo_index] if combo_index < combo_shakes.size() else 0.08
		hit.knockback_force = 8.0 if combo_index == combo_count - 1 else 4.0
		player.sword_hitbox.activate(hit)

	if timer >= hitbox_end and not hitbox_deactivated:
		hitbox_deactivated = true
		player.sword_hitbox.deactivate()

	# Open combo window after attack active frames
	if timer >= attack_duration and not can_combo:
		can_combo = true
		combo_timer = combo_window

	if can_combo:
		combo_timer -= delta
		if input_buffer.consume_action("light_attack"):
			var next_index := (combo_index + 1) % combo_count
			transitioned.emit(self, "LightAttack", {"combo_index": next_index})
			return
		if combo_timer <= 0.0:
			transitioned.emit(self, "Idle", {})
			return

	# Allow dodge cancel during combo window
	if can_combo and input_buffer.consume_action("dodge"):
		transitioned.emit(self, "Dodge", {})
		return


func exit() -> void:
	player.sword_hitbox.deactivate()


func _play_swing_animation() -> void:
	var swing_angle: float = combo_swing_angles[combo_index] if combo_index < combo_swing_angles.size() else 90.0
	var start_angle: float = -swing_angle * 0.5
	var end_angle: float = swing_angle * 0.5

	player.sword_pivot.rotation_degrees.z = start_angle
	var tween := player.create_tween()
	tween.tween_property(player.sword_pivot, "rotation_degrees:z", end_angle, attack_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
