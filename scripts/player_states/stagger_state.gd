extends PlayerState

@export var default_stagger_duration: float = 0.4

var timer: float = 0.0
var stagger_duration: float = 0.4


func enter(data: Dictionary) -> void:
	timer = 0.0
	stagger_duration = data.get("stagger_duration", default_stagger_duration)
	# a light hit is a quick flinch (hitstun); a real stagger reels
	if data.get("flinch", false):
		player.body_model.play("hit", 0.32)
		player.squash(-1.5)
	else:
		player.body_model.play("stagger", stagger_duration)

	# Apply knockback if provided
	var knockback_dir: Vector3 = data.get("knockback_dir", Vector3.ZERO)
	var knockback_force: float = data.get("knockback_force", 0.0)
	if knockback_dir.length_squared() > 0.01:
		player.velocity.x = knockback_dir.x * knockback_force
		player.velocity.z = knockback_dir.z * knockback_force


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	player.move_and_slide()

	timer += delta
	if timer >= stagger_duration:
		transitioned.emit(self, "Idle", {})
