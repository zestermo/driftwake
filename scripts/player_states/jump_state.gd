extends PlayerState
## Jump / double jump. Hold jump for full height, tap for a short hop.
## A sprint's long bound costs stamina; too winded for it and you jump anyway,
## as a plain running jump without the sprint's carry.

const SPRINT_JUMP_COST := 10.0
## The polearm's vault (Pole Vault): x the jump's height speed, x the sprint's carry.
const VAULT_UP := 1.3
const VAULT_FAR := 1.3

var _stamp_at := -1.0


func enter(data: Dictionary) -> void:
	_stamp_at = -1.0
	player.freefall_from = now_s()
	# (out of a tumble: an air step, and the ground jump is long gone)
	if data.get("air", false) and player.jumps_remaining == player.max_jumps:
		player.jumps_remaining -= 1
	# (Skyward Dash's extra steps put you over max_jumps: still air steps)
	var double: bool = (player.jumps_remaining < player.max_jumps or data.get("air", false) or not player.is_on_floor()) and not data.get("coyote", false)
	player.air_speed = maxf(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed)
	_launch(double)
	# (Sky Leap's tap: the jump fires on release, so it's a full one)
	if data.get("full", false):
		player.variable_jump_active = false


func _launch(double: bool) -> void:
	player.jumps_remaining -= 1
	player.velocity.y = player.jump_force * (0.92 if double else 1.0)
	player.variable_jump_active = true
	player.squash(4.5 if not double else 3.5)
	var kind := take_off(double)
	var pr := player.progression
	if kind == "jump_sprint" and not player.spend_stamina(SPRINT_JUMP_COST * (1.0 - pr.stat("sprint_jump_pct"))):
		kind = "jump_run"
		player.air_speed = player.move_speed
	pr.add_life("acrobatics", 6 if double else 3)
	# (a polearm drawn: the sprint's bound is a pole vault, higher and further)
	if kind == "jump_sprint" and player.armed and player.style() == "polearm" and pr.has_move("pole_vault"):
		kind = "pole_vault"
		player.velocity.y = player.jump_force * VAULT_UP
		player.air_speed = maxf(player.air_speed, player.sprint_speed) * VAULT_FAR
	player.body_model.play(kind, ActionSpecs.length(kind))
	var at := player.global_position
	if kind == "pole_vault":
		var plant := at - player.player_model.global_basis.z * 1.2
		Net.fx("dust", [plant + Vector3(0, 0.05, 0), 8, 0.6])
		Net.fx("dust", [at + Vector3(0, 0.05, 0), 6, 0.6])
		Net.fx("sfx", ["thud", plant, -10.0, 0.05, 1.3])
		Net.fx("sfx", ["whoosh_big", at, -9.0, 0.06, 0.95])
	elif double:
		_stamp_at = now_s() + MovePoses.STAMP_S
		Net.fx("sfx", ["whoosh", at, -12.0, 0.08, 1.3])
	elif kind == "jump_sprint":
		Net.fx("dust", [at + Vector3(0, 0.05, 0), 9, 0.7])
		Net.fx("sfx", ["jump", at, -7.0, 0.06, 0.92])
		Net.fx("sfx", ["whoosh", at, -14.0, 0.08, 0.9])
	else:
		Net.fx("dust", [at + Vector3(0, 0.05, 0), 6, 0.6])
		Net.fx("sfx", ["jump", at, -8.0, 0.06, 1.05 if kind == "jump_stand" else 1.0])


## Which take-off: the double jump, or by how fast you were going on the ground.
func take_off(double: bool) -> String:
	if double:
		return "double_jump"
	var h := Vector2(player.velocity.x, player.velocity.z).length()
	if h < 1.5:
		return "jump_stand"
	# (Move's exit has already cleared `sprinting`: go by the speed)
	return "jump_sprint" if h > (player.move_speed + player.sprint_speed) * 0.5 else "jump_run"


## The air step's foot meets the air: a flat ring of wind and a puff under it, and the thump.
func _stamp() -> void:
	_stamp_at = -1.0
	var side := player.player_model.global_basis.x * (-0.12 * player.body_model.air_foot)
	var at := player.global_position + side + Vector3(0, 0.04, 0)
	Net.fx("ring", [at, Vector3.UP, 0.75, Color(1.0, 0.98, 0.9, 0.85), 0.26, 0.07])
	Net.fx("puff_ring", [at - Vector3(0, 0.12, 0), "mist", 7, 0.15, 0.55, 0.45, Color(1.0, 0.98, 0.94, 0.7), 2.2])
	Net.fx("motes", [at, Vector3.DOWN, 6, Color(1.0, 0.97, 0.88), 3.5])
	Net.fx("sfx", ["jump", at, -8.0, 0.05, 1.15])


func physics_update(delta: float) -> void:
	if _stamp_at > 0.0 and now_s() >= _stamp_at:
		_stamp()
	apply_gravity(delta)

	var input := get_movement_input()
	if input.length() > 0.1:
		var direction := get_camera_relative_direction(input)
		var spd := air_speed()
		player.velocity.x = direction.x * spd
		player.velocity.z = direction.z * spd
		if player.armed:
			face_camera(delta)
		else:
			face_direction(direction, delta)

	player.move_and_slide()

	var air := air_attack_input()
	if air != "":
		transitioned.emit(self, air, {})
		return

	if player.skyward_dash and wants_dodge():
		transitioned.emit(self, "Dodge", {"air": true})
		return

	# Double jump
	if Input.is_action_just_pressed("jump") and player.jumps_remaining > 0:
		player.freefall_from = now_s()
		_launch(true)
		return

	if player.velocity.y < 0.0:
		transitioned.emit(self, "Fall", {"from_jump": true})
