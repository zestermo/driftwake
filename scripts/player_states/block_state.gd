extends PlayerState
## Blocking: keep holding parry after the parry window and you stay behind
## your guard. Blows from the front glance off (no damage, a little push)
## at a stamina cost; run out of stamina and the guard breaks. Hits from
## behind, and unblockable attacks (an enemy flashing red), get through.
## You can shuffle while blocking, and dodge or attack straight out of it.

const MOVE_SPEED := 2.2
const COST_PER_DAMAGE := 1.1
const MIN_COST := 8.0

var t: float = 0.0


func enter(_data: Dictionary) -> void:
	t = 0.0
	player.is_blocking = true
	player.sprinting = false
	player.body_model.play("guard_block", 600.0)


func physics_update(delta: float) -> void:
	t += delta
	apply_gravity(delta)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * MOVE_SPEED if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
	player.move_and_slide()
	face_camera(delta)
	player.body_model.ground_speed = Vector2(player.velocity.x, player.velocity.z).length()
	if not Input.is_action_pressed("parry"):
		transitioned.emit(self, "Idle" if mi.length() < 0.1 else "Move", {})
		return
	if wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return
	var next := combat_input()
	if next != "" and next != "Parry":
		transitioned.emit(self, next, {})
		return
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})


## A blocked blow (called by the player when a frontal hit lands on the
## guard). Returns false when the guard breaks instead.
func absorb(hit: HitData, dir: Vector3) -> bool:
	var cost := maxf(hit.damage * COST_PER_DAMAGE, MIN_COST)
	if player.stamina < cost * 0.5:
		return false
	player.stamina = maxf(player.stamina - cost, 0.0)
	player.stamina_changed.emit(player.stamina, player.max_stamina)
	player.velocity += dir * minf(hit.knockback_force * 0.5, 3.0)
	var at := player.global_position + Vector3(0, 1.25, 0) - dir * 0.5
	Net.fx("impact", [at, Color(1.0, 0.95, 0.75)])
	Net.fx("sparkle", [at, 5, Color(1.0, 0.9, 0.55)])
	Net.fx("sfx", ["block", at, -2.0, 0.08, 1.0])
	CombatManager.apply_hitstop(0.04)
	CombatManager.apply_camera_shake(0.06)
	player.body_model.play("guard_block_hit", 0.2)
	get_tree().create_timer(0.2).timeout.connect(func():
		if player.is_blocking and player.current_state_name() == "Block":
			player.body_model.play("guard_block", 600.0))
	return true


func exit() -> void:
	player.is_blocking = false
	player.body_model.stop_action()
