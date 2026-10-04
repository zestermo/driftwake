extends PlayerState

@export var parry_window: float = 0.26
@export var recovery_time: float = 0.4

var timer: float = 0.0
var parry_active: bool = false
var parry_succeeded: bool = false
var _window: float = 0.26


func enter(_data: Dictionary) -> void:
	timer = 0.0
	parry_active = true
	_window = parry_window + (0.05 if player.progression.has_flag("observation") else 0.0)
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

	if parry_active and timer >= _window:
		parry_active = false
		player.is_parrying = false
		# still holding parry: settle into a block
		if not parry_succeeded and Input.is_action_pressed("parry"):
			transitioned.emit(self, "Block", {})
			return

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


func _on_hit_during_parry(_hit_data: HitData, attacker: Node) -> void:
	if parry_active and not _hit_data.unblockable:
		parry_succeeded = true
		var fwd := -player.player_model.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var to_att := fwd
		if attacker is Node3D:
			to_att = (attacker as Node3D).global_position - player.global_position
			to_att.y = 0.0
			to_att = to_att.normalized() if to_att.length() > 0.05 else fwd
		var at := player.global_position + Vector3(0, 1.25, 0) + to_att * 0.6
		Net.fx("parry_sparks", [at, to_att])
		Net.fx("sfx", ["parry", at, -1.0, 0.06, 1.0])
		var combat_mgr := get_node("/root/CombatManager")
		combat_mgr.apply_hitstop(0.1)
		combat_mgr.apply_camera_shake(0.15)
		# TODO: stagger the attacker
