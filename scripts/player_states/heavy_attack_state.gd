extends PlayerState

@export var windup_time: float = 0.3
@export var attack_duration: float = 0.2
@export var recovery_time: float = 0.3
@export var forward_impulse: float = 5.0

var timer: float = 0.0
var phase: int = 0  # 0 = windup, 1 = active, 2 = recovery
var hitbox_activated: bool = false


func enter(_data: Dictionary) -> void:
	timer = 0.0
	phase = 0
	hitbox_activated = false

	# Snap to camera forward
	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)

	# Windup animation: raise sword
	player.sword_pivot.rotation_degrees.z = -120.0


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	player.move_and_slide()

	timer += delta

	match phase:
		0:  # Windup
			if timer >= windup_time:
				phase = 1
				timer = 0.0
				# Slam down
				var tween := player.create_tween()
				tween.tween_property(player.sword_pivot, "rotation_degrees:z", 60.0, attack_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

				# Forward lunge
				var face_dir := get_camera_forward()
				player.velocity.x = face_dir.x * forward_impulse
				player.velocity.z = face_dir.z * forward_impulse

				# Activate hitbox
				var hit := HitData.new()
				hit.damage = 35.0
				hit.hitstop_duration = 0.1
				hit.camera_shake_intensity = 0.2
				hit.knockback_force = 10.0
				hit.stagger_duration = 0.5
				player.sword_hitbox.activate(hit)
				hitbox_activated = true

		1:  # Active
			if timer >= attack_duration:
				phase = 2
				timer = 0.0
				player.sword_hitbox.deactivate()

		2:  # Recovery
			if timer >= recovery_time:
				transitioned.emit(self, "Idle", {})

	# Allow dodge cancel during recovery
	if phase == 2 and input_buffer.consume_action("dodge"):
		transitioned.emit(self, "Dodge", {})


func exit() -> void:
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
