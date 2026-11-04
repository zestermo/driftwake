extends PlayerState

@export var default_stagger_duration: float = 0.4

var timer: float = 0.0
var stagger_duration: float = 0.4
## Which way along a wall the throw slides (picked at the first contact, kept).
var _side := 0.0


func enter(data: Dictionary) -> void:
	timer = 0.0
	_side = 0.0
	stagger_duration = data.get("stagger_duration", default_stagger_duration)
	var knockback_dir: Vector3 = data.get("knockback_dir", Vector3.ZERO)
	var knockback_force: float = data.get("knockback_force", 0.0)
	# a light hit is a quick flinch (hitstun); a real stagger reels, both away from the blow
	if data.get("flinch", false):
		player.body_model.react("hit", 0.32, knockback_dir)
		player.squash(-1.5)
	else:
		player.body_model.react("stagger", stagger_duration, knockback_dir)

	# Apply knockback if provided
	if knockback_dir.length_squared() > 0.01:
		player.velocity.x = knockback_dir.x * knockback_force
		player.velocity.z = knockback_dir.z * knockback_force


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	var push := Vector3(player.velocity.x, 0.0, player.velocity.z)
	player.move_and_slide()
	# (1.30) thrown into a wall: the throw carries on along it instead of pinning you there
	if player.is_on_wall() and push.length() > 1.0:
		var n := player.get_wall_normal()
		n.y = 0.0
		n = n.normalized()
		if push.dot(n) < 0.0:
			if _side == 0.0:
				var along := push - n * push.dot(n)
				_side = 1.0 if along.dot(n.cross(Vector3.UP)) >= 0.0 else -1.0
			var slide := n.cross(Vector3.UP) * _side * push.length() * 0.85
			player.velocity.x = slide.x
			player.velocity.z = slide.z

	timer += delta
	if timer >= stagger_duration:
		transitioned.emit(self, "Idle", {})
