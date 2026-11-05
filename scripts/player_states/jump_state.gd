extends PlayerState
## Jump / double jump. Hold jump for full height, tap for a short hop.
## A sprint's long bound costs stamina; too winded for it and you jump anyway,
## as a plain running jump without the sprint's carry.

const SPRINT_JUMP_COST := 10.0
## The polearm's vault (Pole Vault): x the jump's height speed, x the sprint's carry.
const VAULT_UP := 1.3
const VAULT_FAR := 1.3

## Moonstep (Acrobatics): how high the burst carries you (m), and when its feet meet the air (s into the action).
const MOON_UP := 3.0
const MOON_STAMP := 0.13
const MOON_COL := Color(1.0, 0.97, 0.82, 0.9)

## (1.30) An air step's push (x the jump; was 0.92), and Spring Heels' extra bounce on air steps, wall jumps and jumps
## off a slide.
const AIR_STEP_UP := 1.0
const SPRING := 1.12
## A wall jump: up (x the jump) and out off the wall (m/s); the stick can't steer you back into it for WALL_LOCK s.
const WALL_UP := 1.05
const WALL_PUSH := 6.5
const WALL_LOCK := 0.2
## Wall Run: sprint into a wall at a slant (along it at WALLRUN_MIN m/s or more) and jump: WALLRUN_S s of three quick
## steps along it at WALLRUN_SPEED, rising a little, then the kick off it.
const WALLRUN_MIN := 4.0
const WALLRUN_S := 0.42
const WALLRUN_SPEED := 8.5
const WALLRUN_RISE := 1.8

var _stamp_at := -1.0
var _moon_at := -1.0
var _run_until := -1.0
var _run_n := Vector3.ZERO
var _run_t := Vector3.ZERO


func enter(data: Dictionary) -> void:
	_stamp_at = -1.0
	_moon_at = -1.0
	_run_until = -1.0
	player.freefall_from = now_s()
	if data.get("moon", false):
		player.air_speed = maxf(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed)
		_moonstep()
		return
	if data.has("wall"):
		_wall(data["wall"])
		return
	# (out of a tumble: an air step, and the ground jump is long gone)
	if data.get("air", false) and player.jumps_remaining == player.max_jumps:
		player.jumps_remaining -= 1
	# (Skyward Dash's extra steps put you over max_jumps: still air steps)
	var double: bool = (player.jumps_remaining < player.max_jumps or data.get("air", false) or not player.is_on_floor()) and not data.get("coyote", false)
	player.air_speed = maxf(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed)
	_launch(double)
	# (out of a slide: Spring Heels launches you higher)
	if data.get("slide", false) and player.progression.has_flag("spring_heels"):
		player.velocity.y *= SPRING
	# (Sky Leap's tap: the jump fires on release, so it's a full one)
	if data.get("full", false):
		player.variable_jump_active = false


func _launch(double: bool) -> void:
	player.jumps_remaining -= 1
	var spring := SPRING if double and player.progression.has_flag("spring_heels") else 1.0
	player.velocity.y = player.jump_force * (AIR_STEP_UP * spring if double else 1.0)
	player.variable_jump_active = true
	player.squash(4.5 if not double else 4.5 * spring)
	var kind := take_off(double)
	var pr := player.progression
	if kind == "jump_sprint" and not player.spend_stamina(SPRINT_JUMP_COST * (1.0 - pr.stat("sprint_jump_pct"))):
		kind = "jump_run"
		player.air_speed = player.move_speed
	if double:
		pr.add_life("acrobatics", Progression.ACRO_XP["air_jump"])
	else:
		pr.on_jump()
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
		_chase()
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


## The air step toward a juggled foe (Juggle) carries you up to it: CHASE_S s to arm's length beside its chest.
const CHASE_S := 0.3
const CHASE_MAX := 26.0


func _chase() -> void:
	var foe := Juggle.near(player.get_tree(), player.global_position, Juggle.CHASE_REACH, get_camera_forward())
	if foe == null:
		return
	var to := foe.global_position - player.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var side := flat.normalized() if flat.length() > 0.05 else get_camera_forward()
	var goal := foe.global_position - side * 1.0 - player.global_position
	var v := goal / CHASE_S
	v.y += 0.5 * player.gravity * CHASE_S
	player.velocity = v.limit_length(CHASE_MAX)
	player.air_speed = Vector2(player.velocity.x, player.velocity.z).length()
	player.variable_jump_active = false
	player.player_model.rotation.y = atan2(-side.x, -side.z)
	player.set_meta("chase_until", now_s() + CHASE_S)
	Net.fx("afterimage", [player.body_model, Color(1.0, 0.97, 0.88), 0.25])
	Net.fx("streak", [player.global_position + Vector3(0, 0.9, 0), foe.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.98, 0.9), 0.1, 0.2])


## The air step's foot meets the air: a flat ring of wind and a puff under it, and the thump.
func _stamp() -> void:
	_stamp_at = -1.0
	var side := player.player_model.global_basis.x * (-0.12 * player.body_model.air_foot)
	var at := player.global_position + side + Vector3(0, 0.04, 0)
	Net.fx("ring", [at, Vector3.UP, 0.75, Color(1.0, 0.98, 0.9, 0.85), 0.26, 0.07])
	Net.fx("puff_ring", [at - Vector3(0, 0.12, 0), "mist", 7, 0.15, 0.55, 0.45, Color(1.0, 0.98, 0.94, 0.7), 2.2])
	Net.fx("motes", [at, Vector3.DOWN, 6, Color(1.0, 0.97, 0.88), 3.5])
	Net.fx("sfx", ["jump", at, -8.0, 0.05, 1.15])


## Moonstep: both knees drawn up, both feet stamped down on the air together, and up you go (no air step spent; the
## kicks come for MOON_WINDOW s from the first).
func _moonstep() -> void:
	if not player.air_uses.has("moonstep"):
		player.air_uses["moonstep"] = now_s()
	player.freefall_from = now_s()
	player.velocity.y = sqrt(2.0 * player.gravity * MOON_UP)
	player.variable_jump_active = false
	player.squash(5.5)
	player.body_model.play("moonstep", ActionSpecs.length("moonstep"))
	player.progression.add_life("acrobatics", Progression.ACRO_XP["moonstep"])
	_moon_at = now_s() + MOON_STAMP
	Net.fx("sfx", ["whoosh_big", player.global_position, -9.0, 0.05, 0.8])


## The Moonstep's stamp: a pale crescent ring of air under both feet, a wider one racing out, mist and motes
## driven down, a streak below, and the thump.
func _moon_fx() -> void:
	_moon_at = -1.0
	var at := player.global_position + Vector3(0, 0.04, 0)
	Net.fx("ring", [at, Vector3.UP, 1.3, MOON_COL, 0.3, 0.12])
	Net.fx("ring", [at - Vector3(0, 0.1, 0), Vector3.UP, 2.6, Color(1.0, 1.0, 0.95, 0.6), 0.38, 0.05])
	Net.fx("puff_ring", [at - Vector3(0, 0.15, 0), "mist", 10, 0.2, 0.7, 0.55, Color(1.0, 0.98, 0.92, 0.75), 3.4])
	Net.fx("motes", [at, Vector3.DOWN, 10, MOON_COL, 5.0])
	Net.fx("streak", [at, at - Vector3(0, 2.2, 0), Color(1.0, 0.98, 0.9), 0.14, 0.25])
	Net.fx("sfx", ["jump", at, -5.0, 0.05, 0.75])
	Net.fx("sfx", ["thud", at, -10.0, 0.05, 1.2])
	player.cam_shake(0.08)


## Against a wall in mid-air, jump: Wall Run along it if you came in at a slant (and have it), else the kick off it.
func _wall(n: Vector3) -> void:
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var along := hv - n * hv.dot(n)
	if player.progression.has_flag("wall_run") and not player.air_uses.has("wall_run") and along.length() >= WALLRUN_MIN:
		player.air_uses["wall_run"] = 1
		_run_until = now_s() + WALLRUN_S
		_run_n = n
		_run_t = along.normalized()
		player.player_model.rotation.y = atan2(-_run_t.x, -_run_t.z)
		# (which side the wall is on, for the pose: dash_dir travels to the other screens)
		player.body_model.dash_dir = Vector2(signf(_run_t.cross(n).y), 0.0)
		player.body_model.hold("wall_run")
		Net.fx("sfx", ["whoosh", player.global_position, -10.0, 0.06, 1.2])
		return
	_wall_jump(n)


## The kick off the wall: up and out, facing away from it, one wall jump spent (Rebound: an air step and an air dash
## back), a ring and dust where the foot met it.
func _wall_jump(n: Vector3) -> void:
	var pr := player.progression
	_run_until = -1.0
	player.air_uses["wall_jump"] = int(player.air_uses.get("wall_jump", 0)) + 1
	var spring := SPRING if pr.has_flag("spring_heels") else 1.0
	player.velocity = n * WALL_PUSH * spring + Vector3.UP * player.jump_force * WALL_UP * spring
	player.air_speed = WALL_PUSH * spring
	player.variable_jump_active = false
	player.freefall_from = now_s()
	player.player_model.rotation.y = atan2(-n.x, -n.z)
	player.set_meta("chase_until", now_s() + WALL_LOCK)
	if pr.has_flag("rebound"):
		player.jumps_remaining = mini(player.jumps_remaining + 1, player.max_jumps - 1)
		player.air_uses["air_dash"] = maxi(int(player.air_uses.get("air_dash", 0)) - 1, 0)
	player.squash(4.5 * spring)
	player.body_model.play("wall_kick", ActionSpecs.length("wall_kick"))
	pr.add_life("acrobatics", Progression.ACRO_XP["wall_jump"])
	var at := player.global_position - n * 0.3 + Vector3(0, 0.5, 0)
	Net.fx("ring", [at, n, 0.7, Color(1.0, 0.98, 0.9, 0.85), 0.24, 0.07])
	Net.fx("dust", [at, 6, 0.5])
	Net.fx("sfx", ["jump", at, -7.0, 0.06, 1.15])


## Running along the wall: carried along it and a little up, gravity held off, the wall kept underfoot; the kick at the
## end (or once the wall runs out).
func _wall_run() -> void:
	player.velocity = _run_t * WALLRUN_SPEED + Vector3.UP * WALLRUN_RISE - _run_n * 1.5
	player.move_and_slide()
	if now_s() >= _run_until or player.is_on_floor() or wall_normal() == Vector3.ZERO or player.inp.just_pressed("jump"):
		player.body_model.stop_action()
		_wall_jump(_run_n)
		return
	if Engine.get_physics_frames() % 5 == 0:
		Net.fx("dust", [player.global_position - _run_n * 0.3 + Vector3(0, 0.15, 0), 2, 0.3])


func exit() -> void:
	if player.body_model.current_action() == "wall_run":
		player.body_model.stop_action()


func physics_update(delta: float) -> void:
	if _run_until > 0.0:
		_wall_run()
		return
	if _stamp_at > 0.0 and now_s() >= _stamp_at:
		_stamp()
	if _moon_at > 0.0 and now_s() >= _moon_at:
		_moon_fx()
	apply_gravity(delta)

	var input := get_movement_input()
	# (chasing a juggled foe: the step carries you, the stick doesn't steer)
	if input.length() > 0.1 and now_s() >= float(player.get_meta("chase_until", 0.0)):
		var direction := get_camera_relative_direction(input)
		var spd := air_speed()
		player.velocity.x = direction.x * spd
		player.velocity.z = direction.z * spd
		if player.armed:
			face_camera(delta)
		else:
			face_direction(direction, delta)

	player.move_and_slide()

	if wants_dash_strike():
		transitioned.emit(self, "Plunge", {"dash": player.get_meta("air_dash_dir", get_camera_forward())})
		return

	var air := air_attack_input()
	if air != "":
		transitioned.emit(self, air, {})
		return

	if wants_air_dash():
		transitioned.emit(self, "Dodge", {"air": true})
		return

	var wall := wants_wall_jump()
	if wall != Vector3.ZERO:
		_wall(wall)
		return

	if wants_moonstep():
		_moonstep()
		return

	# Double jump
	if player.inp.just_pressed("jump") and player.jumps_remaining > 0:
		player.freefall_from = now_s()
		_launch(true)
		return

	if player.velocity.y < 0.0:
		transitioned.emit(self, "Fall", {"from_jump": true})
