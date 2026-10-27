extends PlayerState
## Blocking: keep holding parry after the parry window and you stay behind
## your guard. Blows from the front glance off (no damage, a little push)
## at a stamina cost; run out of stamina and the guard breaks. Hits from
## behind, and unblockable attacks (an enemy flashing red), get through.
## You can shuffle while blocking, and dodge or attack straight out of it.
## Defense's guard style (a variant): Rolling Guard makes the dodge a roll with the guard still up (this state goes
## on through it, so blows from the front still glance off); Planted sinks the guard into a rooted stance (no
## push-back, cheaper blocks, a slower shuffle).

const MOVE_SPEED := 2.2
const COST_PER_DAMAGE := 1.1
const MIN_COST := 8.0
const ROLL_DUR := 0.42
const ROLL_DIST := 3.0
## The guarded roll costs this share of a dodge.
const ROLL_COST := 0.6
const PLANTED_COST := 0.7
const PLANTED_MOVE := 0.5
## Heavy armour's guarded hop.
const HOP_DUR := 0.3
const HOP_DIST := 1.5

var t: float = 0.0
var _roll_t: float = -1.0
var _roll_dur := ROLL_DUR
var _roll_dist := ROLL_DIST
var _roll_dir := Vector3.ZERO
var _planted: bool = false


func enter(_data: Dictionary) -> void:
	t = 0.0
	_roll_t = -1.0
	player.is_blocking = true
	player.sprinting = false
	_planted = player.progression.has_flag("guard_planted")
	player.body_model.planted = _planted
	player.body_model.hold("guard_block")


func physics_update(delta: float) -> void:
	t += delta
	apply_gravity(delta)
	if _roll_t >= 0.0:
		_roll_update(delta)
		return
	var mi := get_movement_input()
	var spd := MOVE_SPEED * (1.0 + player.progression.stat("block_move_pct")) * (PLANTED_MOVE if _planted else 1.0)
	var want := get_camera_relative_direction(mi) * spd if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
	player.move_and_slide()
	face_camera(delta)
	player.body_model.ground_speed = Vector2(player.velocity.x, player.velocity.z).length()
	if not player.inp.pressed("parry"):
		transitioned.emit(self, "Idle" if mi.length() < 0.1 else "Move", {})
		return
	var heavy: bool = player.gear_load() == GearStats.HEAVY
	if player.progression.has_flag("rolling_guard") or heavy:
		if input_buffer.consume_action("dodge") and player.spend_stamina(player.dodge_cost() * ROLL_COST):
			_roll(mi, heavy and not player.progression.has_flag("rolling_guard"))
			return
	elif wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return
	var next := combat_input()
	if next != "" and next != "Parry":
		transitioned.emit(self, next, {})
		return
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})


## Rolling Guard: over and up with the guard kept up, still facing them (input's way, or back out of reach).
## In heavy armour (GearStats) without it: a short hop instead, the guard still up.
func _roll(mi: Vector2, hop: bool) -> void:
	_roll_t = 0.0
	_roll_dur = HOP_DUR if hop else ROLL_DUR
	_roll_dist = HOP_DIST if hop else ROLL_DIST
	_roll_dir = get_camera_relative_direction(mi) if mi.length() > 0.1 else -get_camera_forward()
	var local := player.player_model.global_basis.orthonormalized().inverse() * _roll_dir
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	if hop:
		player.velocity.y = 2.2
		player.body_model.play("sidestep", HOP_DUR + 0.1)
	else:
		player.body_model.play("guard_roll", ROLL_DUR)
	player.squash(-2.5)
	player.progression.add_life("defense", 3)
	var at := player.global_position
	Net.fx("dust", [at - _roll_dir * 0.3 + Vector3(0, 0.05, 0), 6, 0.55])
	Net.fx("sfx", ["whoosh", at, -10.0, 0.08, 1.0])


func _roll_update(delta: float) -> void:
	_roll_t += delta
	var u := clampf(_roll_t / _roll_dur, 0.0, 1.0)
	var spd := _roll_dist / (0.8 * _roll_dur) * (1.0 if u < 0.6 else lerpf(1.0, 0.5, (u - 0.6) / 0.4))
	player.velocity.x = _roll_dir.x * spd
	player.velocity.z = _roll_dir.z * spd
	player.move_and_slide()
	face_camera(delta)
	if _roll_t >= 0.16 and _roll_t - delta < 0.16:
		Net.fx("puff_ring", [player.global_position + Vector3(0, 0.05, 0), "dust_low", 4, 0.22, 0.4, 0.4, Color(0.8, 0.74, 0.64, 0.7), 1.4])
	if _roll_t < _roll_dur:
		return
	_roll_t = -1.0
	if not player.inp.pressed("parry"):
		transitioned.emit(self, "Idle" if get_movement_input().length() < 0.1 else "Move", {})
		return
	player.body_model.hold("guard_block")


func rolling() -> bool:
	return _roll_t >= 0.0


## A blocked blow (called by the player when a frontal hit lands on the
## guard). Returns false when the guard breaks instead.
func absorb(hit: HitData, dir: Vector3) -> bool:
	var cost := maxf(hit.damage * COST_PER_DAMAGE, MIN_COST) * maxf(1.0 - player.progression.stat("block_cost_pct"), 0.1)
	if _planted:
		cost *= PLANTED_COST
	if player.stamina < cost * 0.5:
		return false
	player.progression.add_life("defense", 5)
	player.stamina = maxf(player.stamina - cost, 0.0)
	player.stamina_changed.emit(player.stamina, player.max_stamina)
	var at := player.global_position + Vector3(0, 1.25, 0) - dir * 0.5
	if _planted:
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 5, 0.5])
	else:
		player.velocity += dir * minf(hit.knockback_force * 0.5, 3.0)
	Net.fx("impact", [at, Color(1.0, 0.95, 0.75)])
	Net.fx("sparkle", [at, 5, Color(1.0, 0.9, 0.55)])
	CombatManager.guard(hit, player.armed and player.weapon_class() == "sword", at, -2.0, 0.08, 1.0)
	CombatManager.apply_hitstop(0.04, [player])
	player.cam_shake(0.06)
	if rolling():
		return true
	player.body_model.play("guard_block_hit", 0.2)
	get_tree().create_timer(0.2).timeout.connect(func():
		if player.is_blocking and player.current_state_name() == "Block" and not rolling():
			player.body_model.hold("guard_block"))
	return true


func exit() -> void:
	player.is_blocking = false
	player.body_model.planted = false
	player.body_model.stop_action()
