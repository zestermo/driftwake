extends "res://scripts/player_states/technique_state.gd"
## Crew techniques (CrewTechniques: C in combat stance). Entered with {"id", "role", "mate"}; `role` is "lead" (you
## opened the zone and a crewmate joined), "partner" (you joined: your own machine runs your side, cued by the lead's
## Net.crew_signal), or "solo" (the weapon's self version). The TechniqueState helpers (_once, _rooted, _hd, _cone,
## _moment...) run the timelines; a launch ends in "flight" (free plunge on attack, no fall damage: a crater).
##   Skyward Kick  lead: the foot raised, the crewmate steps on (PERCH), the kick at KICK_AT sends them along the aim
##                 (camera pitch, KICK_PITCH..). partner: perched until the "launch" signal, then flight.
##                 solo: Wall Kick, off the wall ahead (WALL_REACH) or the ground.

const KICK_DUR := 0.9
const KICK_AT := 0.42
const KICK_SPEED := 22.0
## The kick's elevation (deg): the lead's camera pitch moves it between these.
const KICK_PITCH := Vector2(45.0, 80.0)
const KICK_PITCH_DEF := 65.0
## Where the partner stands on the raised foot (m ahead of the lead, up).
const PERCH := Vector2(0.75, 0.62)
## How long a partner waits on the lead before giving up (s).
const PARTNER_WAIT := 1.6
const WALL_DUR := 0.32
const WALL_AT := 0.16
const WALL_REACH := 2.2
const WALL_V := Vector2(3.0, 18.0)
const GROUND_V := Vector2(6.5, 15.0)
## Steering in flight (m/s^2 toward the stick) and the longest flight before it's an ordinary fall.
const FLIGHT_STEER := 7.0
const FLIGHT_MAX := 6.0

var role := ""
var mate: Node3D
## "" the move itself, "perch" waiting for the lead, "flight" in the air after a launch.
var _phase := ""
var _flight_t := 0.0
## What the flight lands in: "" (the crater only), "slash", "slam".
var _land := ""


func enter(data: Dictionary) -> void:
	id = str(data["id"])
	role = str(data["role"])
	mate = data.get("mate") as Node3D
	_pc = player.power
	t = 0.0
	_hits = 0
	_done = {}
	_target = data.get("target") as Node3D
	_victims = []
	_hit = []
	_phase = ""
	_flight_t = 0.0
	_land = ""
	_slot = -1
	_hold = -1.0
	player.sprinting = false
	player.is_parrying = false
	player.sword_hitbox.deactivate()
	player.reset_combo()
	_dir = get_camera_forward()
	_dir.y = 0.0
	_dir = _dir.normalized() if _dir.length() > 0.01 else -player.player_model.global_basis.z
	face_direction(_dir, 1.0)
	_from = player.global_position
	match id:
		"skyward_kick":
			_kick_enter()


func physics_update(delta: float) -> void:
	t += delta
	if _phase == "flight":
		_flight(delta)
		return
	match id:
		"skyward_kick":
			_kick_update(delta)
	if _phase == "" and t >= dur:
		_finish()


## A crewmate's message for our side of the move (CrewTechniques.signal_in). True when it was ours.
func on_signal(what: String, args: Array) -> bool:
	match what:
		"launch":
			if role != "partner" or _phase != "perch":
				return false
			_launch(args[0], str(args[1]))
			return true
	return false


func exit() -> void:
	super.exit()
	if player.body_model.current_action().begins_with("ct_"):
		player.body_model.stop_action()


func _tree() -> String:
	return CrewTechniques.tree_of(id)


func _elem() -> bool:
	return player.progression.elemental(_tree())


# --------------------------------------------------------------------------
# Flight (after a launch): steer a little, attack for a free plunge, land in a crater
# --------------------------------------------------------------------------
func _launch(v: Vector3, land: String) -> void:
	_phase = "flight"
	_flight_t = 0.0
	_land = land
	player.velocity = v
	player.air_speed = Vector2(v.x, v.z).length()
	player.variable_jump_active = false
	player.jumps_remaining = player.max_jumps - 1
	player.sky_leap_fall = true
	player.freefall_from = now_s()
	player.squash(6.0)
	player.body_model.play("ct_launched", 0.6)
	var at := player.global_position
	Net.fx("afterimage", [player.body_model, _col(), 0.3])
	Net.fx("streak", [at + Vector3(0, 0.6, 0), at + Vector3(0, 0.6, 0) + v * 0.18, _col(FX.CORE), 0.16, 0.3])
	Net.fx("speed_lines", [at + Vector3(0, 1.0, 0), v.normalized(), _col(), 8, 2.2, 0.3, randi() % 1000])


func _flight(delta: float) -> void:
	_flight_t += delta
	var g := player.gravity * (player.fall_gravity_mult if player.velocity.y < 0.0 else 1.0)
	player.velocity.y = maxf(player.velocity.y - g * delta, -Player.MAX_FALL_SPEED)
	var mi := get_movement_input()
	if mi.length() > 0.1:
		var want := get_camera_relative_direction(mi)
		player.velocity.x += want.x * FLIGHT_STEER * delta
		player.velocity.z += want.z * FLIGHT_STEER * delta
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if hv.length() > 0.5:
		face_direction(hv, delta)
	player.move_and_slide()
	# a free plunge: no stamina, whenever there's height under you
	if (input_buffer.consume_action("light_attack") or input_buffer.consume_action("heavy_attack")) and player.can_attack() \
			and player.height_above_ground() > 1.2:
		player.sky_leap_fall = false
		transitioned.emit(self, "Plunge", {})
		return
	if player.is_on_floor() and _flight_t > 0.1:
		_landed()
		_finish()
		return
	if _flight_t > FLIGHT_MAX:
		transitioned.emit(self, "Fall", {})


func _landed() -> void:
	match _land:
		_:
			pass


# --------------------------------------------------------------------------
# Skyward Kick (black leg)
# --------------------------------------------------------------------------
func _kick_enter() -> void:
	match role:
		"lead":
			dur = KICK_DUR
			player.body_model.play("ct_kick_launch", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.05, 0.8])
		"partner":
			_phase = "perch"
			dur = PARTNER_WAIT
			_perch()
			player.body_model.hold("ct_perch", 0.12)
			Net.fx("dust", [player.global_position, 4, 0.4])
		"solo":
			dur = WALL_DUR
			player.body_model.play("ct_wall_kick", 0.55)


func _kick_update(delta: float) -> void:
	match role:
		"lead":
			_rooted(delta, 0.0)
			if t < KICK_AT:
				# (the aim follows the camera until the kick)
				_dir = get_camera_forward()
				face_direction(_dir, delta)
			if _once("glint", KICK_AT - 0.08):
				Net.fx("glint", [player.global_position + Vector3(0, 0.6, 0) + _dir * 0.6, _col(FX.CORE), 0.9])
			if _once("kick", KICK_AT):
				_kick_mate()
		"partner":
			if _phase == "perch":
				_perch()
				if t >= dur:
					_phase = ""
		"solo":
			_rooted(delta, 0.0)
			if _once("go", WALL_AT):
				_wall_kick()


## On the lead's raised foot, facing where they face.
func _perch() -> void:
	if mate == null or not is_instance_valid(mate):
		return
	var f: Vector3 = -mate.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	player.global_position = mate.global_position + f * PERCH.x + Vector3(0, PERCH.y, 0)
	player.velocity = Vector3.ZERO
	face_direction(f, 1.0)


## The kick: the crewmate goes along the aim (the camera's pitch sets the angle).
func _kick_mate() -> void:
	var pitch := KICK_PITCH_DEF
	var cam := player.get_viewport().get_camera_3d()
	if cam and not player.is_ai:
		var look := -cam.global_basis.z
		pitch = clampf(KICK_PITCH_DEF + rad_to_deg(asin(clampf(look.y, -1.0, 1.0))) * 0.9 + 12.0, KICK_PITCH.x, KICK_PITCH.y)
	var e := deg_to_rad(pitch)
	var v := _dir * cos(e) * KICK_SPEED + Vector3.UP * sin(e) * KICK_SPEED
	if mate and is_instance_valid(mate):
		Net.crew_signal(mate, "launch", [v, ""])
	var foot := player.global_position + Vector3(0, 0.9, 0) + _dir * 0.7
	Net.fx("ring", [foot, v.normalized(), 1.4, _col(), 0.3, 0.14])
	Net.fx("ring", [player.global_position, Vector3.UP, 2.6, _col(FX.CORE), 0.35, 0.12])
	Net.fx("puff_ring", [player.global_position + Vector3(0, 0.05, 0), "dust_low", 8, 0.4, 1.1, 0.8, Color(0.85, 0.8, 0.7, 0.85), 6.0])
	Net.fx("kick_swoosh", [player.body_model, 0.25, _col()])
	Net.fx("impact", [foot, _col(FX.CORE)])
	Net.fx("sfx", ["thud", foot, -2.0, 0.05, 0.8])
	Net.fx("sfx", ["whoosh_big", foot, -3.0, 0.05, 0.75])
	if _elem():
		Net.fx("hot_leg", [player.body_model, true, 0.5, _col(FX.ACCENT)])
	player.squash(-4.0)
	player.cam_shake(0.18)
	player.cam_kick(0.2, 0.35)


## Wall Kick: off the wall ahead if there's one in reach (up and over it), else off the ground (up and forward).
func _wall_kick() -> void:
	var from := player.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + _dir * WALL_REACH, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var wall := not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.5
	var hv: Vector2 = WALL_V if wall else GROUND_V
	_launch(_dir * hv.x + Vector3.UP * hv.y, "")
	var at: Vector3 = hit["position"] if wall else player.global_position
	Net.fx("ring", [at, hit["normal"] if wall else Vector3.UP, 1.6, _col(), 0.3, 0.14])
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 6, 0.3, 0.9, 0.7, Color(0.85, 0.8, 0.7, 0.85), 4.5])
	if wall:
		Net.fx("debris", [at, hit["normal"], 5, Color(0.42, 0.36, 0.3), 4.0])
	Net.fx("sfx", ["thud", at, -4.0, 0.05, 0.9])
	Net.fx("sfx", ["whoosh_big", at, -5.0, 0.05, 0.9])
	player.cam_shake(0.12)
