extends PlayerState

@export var parry_window: float = 0.2
@export var recovery_time: float = 0.4

var timer: float = 0.0
var parry_active: bool = false
var parry_succeeded: bool = false


func enter(_data: Dictionary) -> void:
	timer = 0.0
	parry_active = true
	parry_succeeded = false
	player.is_parrying = true
	player.body_model.play("parry", parry_window + recovery_time)
	player.reset_combo()

	# Connect to hurtbox for parry check
	if not player.hurtbox.hit_received.is_connected(_on_hit_during_parry):
		player.hurtbox.hit_received.connect(_on_hit_during_parry)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
	player.move_and_slide()

	timer += delta

	if parry_active and timer >= parry_window:
		parry_active = false
		player.is_parrying = false

	if parry_succeeded:
		# Brief pause after successful parry, then return
		if timer >= parry_window + 0.15:
			transitioned.emit(self, "Idle", {})
		return

	var total_time := parry_window + recovery_time
	if timer >= total_time:
		transitioned.emit(self, "Idle", {})


func exit() -> void:
	parry_active = false
	player.is_parrying = false
	if player.hurtbox.hit_received.is_connected(_on_hit_during_parry):
		player.hurtbox.hit_received.disconnect(_on_hit_during_parry)


func _on_hit_during_parry(_hit_data: HitData, _attacker: Node) -> void:
	if parry_active:
		parry_succeeded = true
		FX.sparkle(player.global_position + Vector3(0, 1.3, 0) - player.player_model.global_basis.z * 0.7, 14, Color(1.0, 1.0, 0.8))
		FX.sfx("hit", player.global_position, -2.0, 0.05, 1.6)
		var combat_mgr := get_node("/root/CombatManager")
		combat_mgr.apply_hitstop(0.1)
		combat_mgr.apply_camera_shake(0.15)
		# TODO: stagger the attacker
