extends "res://scripts/player_states/technique_state.gd"
## Crew techniques (CrewTechniques: C in combat stance). Entered with {"id", "role", "mate"}; `role` is "lead" (you
## opened the zone and a crewmate joined), "partner" (you joined: your own machine runs your side, cued by the lead's
## Net.crew_signal), "solo" (the weapon's self version) or "counter" (Guardian Stance: a blow on your ward). The
## TechniqueState helpers (_once, _rooted, _hd, _ring, _strike...) run the timelines. A launch ends in "flight": a
## little steering, attack for a free plunge, a crater instead of fall damage, and the move's landing ("slash", "slam")
## or a plough through foes on the way (Human Cannonball).
##   launches   lead: the crewmate stands on PERCH (foot, blade, pole top, hammer head, cupped hands) or is swung round
##              (Hurl); at LAUNCH[id][0] s the lead sends "launch" with LAUNCH[id]'s velocity along its aim.
##              partner: perched (or swung) until the signal, then flight. Skyward Kick's arc follows the lead's pitch.
##   Guardian Stance  lead: the guard settles (the marks on both are CrewTechniques'); "counter": blink to the
##              attacker, one iai cut. solo: Counter Stance (a 3 s guard, the blow answered by the katana's riposte).
##   Shield Wall  lead/solo: the greatsword planted as a wall for WALL_SECS (solo WALL_SOLO); C, attack or dodge drops it.
##   Pincer     lead/solo: mark the foe ahead (the crewmate's mark rides the signal).
##   Covering Fire  lead/solo: a volley at the foes ahead, then a fresh reload; "covered" on both.

const KICK_PITCH := Vector2(42.0, 80.0)
const KICK_PITCH_DEF := 60.0
const KICK_SPEED := 22.0
## Per launch move: [when the lead throws (s), the move's length (s), forward speed, up speed, the landing, plough].
const LAUNCH := {
	"skyward_kick": [0.42, 0.9, 0.0, 0.0, "", false],
	"crossed_blades": [0.5, 1.0, 9.0, 12.0, "slash", false],
	"hurl": [0.75, 1.1, 16.0, 7.0, "slam", false],
	"pole_vault": [0.42, 0.9, 14.0, 13.0, "", false],
	"anvil": [0.42, 0.9, 4.0, 22.0, "", false],
	"human_cannonball": [0.35, 0.75, 24.0, 6.0, "", true],
	"cannon_ride": [0.27, 0.9, 18.0, 9.0, "slam", false],
	"sling_launch": [0.5, 1.0, 11.0, 17.0, "", false],
}
## Where a partner stands on the lead (m ahead, up, to the lead's right).
const PERCH := {"skyward_kick": Vector3(0.75, 0.62, 0.0), "crossed_blades": Vector3(0.55, 1.25, 0.0), "pole_vault": Vector3(0.9, 1.7, 0.0),
	"anvil": Vector3(0.9, 0.35, -0.3), "human_cannonball": Vector3(0.7, 0.45, 0.0), "cannon_ride": Vector3(0.55, 1.55, 0.25),
	"sling_launch": Vector3(0.9, 0.3, 0.0)}
## The lead's pose per launch move (Crossed Blades: its guard, then the cut at the throw, by style).
const LEAD_POSE := {"skyward_kick": "ct_kick_launch", "hurl": "ct_hurl", "pole_vault": "pole_land", "anvil": "ham_upper",
	"human_cannonball": "ct_cup", "cannon_ride": "cn_fire", "sling_launch": "sl_shot"}
## Hurl: the crewmate swung round once at this radius and height before the throw.
const HURL_R := 1.4
const HURL_Y := 0.6
## How long a partner waits on the lead before giving up (s).
const PARTNER_WAIT := 1.6
## Self versions: [when it goes (s), its length, forward, up, landing, plough, pose, the pose's length].
const SOLO := {
	"skyward_kick": [0.16, 0.32, 6.5, 15.0, "", false, "ct_wall_kick", 0.55],
	"crossed_blades": [0.16, 0.32, 8.0, 10.0, "slash", false, "ct_wall_kick", 0.55],
	"hurl": [0.16, 0.32, 9.0, 10.0, "slam", false, "ct_wall_kick", 0.55],
	"pole_vault": [0.2, 0.36, 11.0, 12.0, "", false, "pole_vault", 0.9],
	"anvil": [0.42, 0.6, 3.0, 16.0, "", false, "ham_smash", 0.8],
	"human_cannonball": [0.16, 0.32, 18.0, 5.0, "", true, "ct_wall_kick", 0.55],
	"cannon_ride": [0.2, 0.36, 6.0, 15.0, "slam", false, "cn_air", 0.8],
	"sling_launch": [0.22, 0.38, 10.0, 12.0, "", false, "sl_skid", 0.6],
}
## Wall Kick: a wall this close ahead (m) kicks you up it: [forward, up].
const WALL_REACH := 2.2
const WALL_KICK_V := Vector2(3.0, 18.0)
## Steering in flight (m/s^2 toward the stick) and the longest flight before it's an ordinary fall.
const FLIGHT_STEER := 7.0
const FLIGHT_MAX := 6.0
## Landings: the leaping slash and the slam [reach m, damage, knockback].
const LAND_SLASH := [2.8, 30.0, 7.0]
const LAND_SLAM := [3.5, 40.0, 10.0]
## Human Cannonball's plough: foes this close to you in flight are bowled over.
const PLOW_R := 1.4
const PLOW_DAMAGE := 25.0
## Anvil's self version: the hammer's slam round you before the rebound.
const REBOUND_DAMAGE := 20.0
const GUARD_SETTLE := 0.7
const COUNTER_DUR := 0.6
const COUNTER_DAMAGE := 45.0
const COUNTER_SOLO := 3.0
const WALL_SECS := 8.0
const WALL_SOLO := 4.0
const MARK_REACH := 14.0
const MARK_SECS := 10.0
const VOLLEY := 2.0
const VOLLEY_EVERY := 0.25
const VOLLEY_REACH := 18.0
const VOLLEY_DAMAGE := 8.0

## (1.26, WeaponPlus) The second crew techniques (CrewTechniques.ALL "kind"):
##   setup     lead: up to the foe aimed at and its pinning blow ("flags"), then the cue; partner: waiting, then out
##             beside it in a blink and the finisher ("burst", "fin" flags). solo: the lead plays both.
##   combined  lead: up to the foe, the cue, a blow ("dmg") as the partner's lands from its far side, and the merged
##             burst on everyone round it ("burst", "flags"). solo: a blow from each side, the burst at SOLO_K.
##   support   CrewTechniques.support on both captains (the partner's from go()).
## [pose, length, when its blow lands (s)] for the lead's side and the partner's (the solo's second half).
const DUETS := {
	"crossed_cutlass": {"lead": ["riposte_cut", 0.5, 0.16], "mate": ["riposte_cut", 0.5, 0.16], "dmg": 26.0, "burst": 30.0, "flags": "down unblock"},
	"blade_sheath": {"lead": ["iai_slash", 0.5, 0.14], "mate": ["iai_slash", 0.5, 0.12], "dmg": 16.0, "burst": 55.0, "flags": "pin down", "fin": "down unblock sever"},
	"double_course": {"lead": ["bl_cleave", 0.5, 0.18], "mate": ["bl_cleave", 0.5, 0.18], "dmg": 24.0, "burst": 26.0, "flags": "launch2 unblock"},
	"ground_pin": {"lead": ["pole_legsweep", 0.6, 0.22], "mate": ["pole_vstrike", 0.6, 0.3], "dmg": 16.0, "burst": 52.0, "flags": "pin down", "fin": "down unblock"},
	"lift_cleave": {"lead": ["gs_updraft", 0.6, 0.24], "mate": ["gs_guardbreak", 0.6, 0.3], "dmg": 18.0, "burst": 52.0, "flags": "launch2 pin", "fin": "spike down unblock"},
	"powder_share": {"lead": ["smoke_throw", 0.5, 0.2]},
	"blade_wall": {"lead": ["cross_guard", 0.6, 0.2]},
	"smoke_mirrors": {"lead": ["smoke_throw", 0.5, 0.2]},
	"pouch_pass": {"lead": ["smoke_throw", 0.5, 0.2]},
	"fc_ember": {"lead": ["smoke_throw", 0.5, 0.2]}, "fc_storm": {"lead": ["smoke_throw", 0.5, 0.2]}, "fc_gust": {"lead": ["smoke_throw", 0.5, 0.2]},
	"fc_wolf": {"lead": ["smoke_throw", 0.5, 0.2]}, "fc_bear": {"lead": ["cross_guard", 0.6, 0.2]}, "fc_vine": {"lead": ["smoke_throw", 0.5, 0.2]},
	"fc_iron": {"lead": ["cross_guard", 0.6, 0.2]}, "fc_bubble": {"lead": ["smoke_throw", 0.5, 0.2]}, "fc_clockwork": {"lead": ["smoke_throw", 0.5, 0.2]},
	"fc_echo": {"lead": ["smoke_throw", 0.5, 0.2]},
	"chopping_block": {"lead": ["axe_kick", 0.5, 0.18], "mate": ["axe_split", 0.6, 0.3], "dmg": 16.0, "burst": 56.0, "flags": "pin down", "fin": "down unblock"},
	"twin_viper": {"lead": ["viper_flurry", 0.6, 0.3], "mate": ["viper_flurry", 0.6, 0.3], "dmg": 20.0, "burst": 22.0, "flags": "down bleed unblock"},
	"hammer_anvil": {"lead": ["ham_smash", 0.6, 0.3], "mate": ["ham_upper", 0.6, 0.3], "dmg": 26.0, "burst": 32.0, "flags": "down unblock"},
	"hook_hew": {"lead": ["dx_gallows", 0.6, 0.25], "mate": ["dx_heavy", 0.6, 0.3], "dmg": 16.0, "burst": 54.0, "flags": "pin down", "fin": "down unblock"},
	"steady_bind": {"lead": ["sp_cut", 0.5, 0.18], "mate": ["parley_shot", 0.6, 0.3], "dmg": 16.0, "burst": 50.0, "flags": "pin", "fin": "down unblock"},
	"pin_shoot": {"lead": ["lg_kneel_fire", 0.6, 0.25], "mate": ["lg_fire", 0.5, 0.2], "dmg": 18.0, "burst": 52.0, "flags": "pin ranged", "fin": "down unblock ranged", "stay": true},
	"double_barrel": {"lead": ["cn_fire", 0.6, 0.25], "mate": ["cn_fire", 0.6, 0.25], "dmg": 24.0, "burst": 36.0, "flags": "down unblock", "stay": true},
	"hold_down": {"lead": ["fs_catch", 0.5, 0.2], "mate": ["fs_hay", 0.6, 0.3], "dmg": 10.0, "burst": 56.0, "flags": "pin", "fin": "down unblock"},
}
const DUET_REACH := 8.0
const DUET_BURST_R := 2.8
const SOLO_K := 0.75
## The solo's second half starts this long after the first blow.
const SOLO_GAP := 0.3

var role := ""
var mate: Node3D
## "" the move itself, "perch" waiting on the lead, "swung" being swung (Hurl), "flight" in the air after a launch.
var _phase := ""
var _flight_t := 0.0
## What the flight lands in ("" the crater only, "slash", "slam") and whether it ploughs through foes.
var _land := ""
var _plow := false
var _shots := 0
var _swing_f := Vector3.FORWARD


func enter(data: Dictionary) -> void:
	id = str(data["id"])
	role = str(data["role"])
	mate = data.get("mate") as Node3D
	_pc = player.power
	t = 0.0
	_hits = 0
	_shots = 0
	_done = {}
	_target = data.get("target") as Node3D
	_victims = []
	_hit = []
	_phase = ""
	_flight_t = 0.0
	_land = ""
	_plow = false
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
	match role:
		"partner":
			if DUETS.has(id):
				_duet_wait()
			else:
				_partner_enter()
		"counter":
			_counter_enter()
		_:
			match id:
				"guardian_stance":
					_guard_enter()
				"shield_wall":
					_wall_enter()
				"pincer":
					_mark_enter()
				"covering_fire":
					_volley_enter()
				_:
					if DUETS.has(id):
						_duet_enter()
					else:
						_launcher_enter()


func physics_update(delta: float) -> void:
	t += delta
	match _phase:
		"flight":
			_flight(delta)
			return
		"perch":
			_perch()
		"swung":
			_swung()
	if DUETS.has(id):
		_duet_update(delta)
	elif role == "counter":
		_counter_update(delta)
	elif role != "partner":
		match id:
			"guardian_stance":
				_rooted(delta, 0.0)
				if role == "lead" and _once("glint", 0.15):
					Net.fx("glint", [_hilt(), _col(FX.CORE), 0.9])
			"shield_wall":
				if _wall_update(delta):
					return
			"pincer":
				_rooted(delta, 0.3)
			"covering_fire":
				_volley_update(delta)
			_:
				_launcher_update(delta)
		if _phase == "flight":
			return
	if t >= dur:
		_finish()


## A crewmate's message for our side of the move (CrewTechniques.signal_in). True when it was ours.
func on_signal(what: String, args: Array) -> bool:
	match what:
		"launch":
			if role != "partner" or not _phase in ["perch", "swung"]:
				return false
			_launch(args[0], str(args[1]), bool(args[2]))
			return true
		"duet", "finish":
			if role != "partner" or _phase != "wait":
				return false
			_duet_cued(Net.node_of(str(args[0])) as Node3D, what == "finish")
			return true
		"duet_off":
			if role == "partner" and _phase == "wait":
				dur = 0.0
			return role == "partner"
	return false


func exit() -> void:
	super.exit()
	if player.body_model.current_action().begins_with("ct_") or player.body_model.current_action() in ["gs_gate", "iai_ready", "riposte_guard", "cross_guard"]:
		player.body_model.stop_action()
	match id:
		"guardian_stance":
			if role == "solo":
				_pc.buffs["riposte"] = 0.0
		"shield_wall":
			player.crew_tech.marks.erase("wall")


func _tree() -> String:
	return CrewTechniques.tree_of(id)


func _elem() -> bool:
	return player.progression.elemental(_tree())


# --------------------------------------------------------------------------
# Launches: the lead's throw, the partner perched or swung, the self versions
# --------------------------------------------------------------------------
func _launcher_enter() -> void:
	if role == "solo":
		var so: Array = SOLO[id]
		dur = float(so[1])
		player.body_model.play(str(so[6]), float(so[7]))
		return
	var l: Array = LAUNCH[id]
	dur = float(l[1])
	if id == "crossed_blades":
		# the blade braced at shoulder height to be stepped on; the cut at the throw flings them off it
		player.body_model.hold("cross_guard" if player.style() == "dual_sword" else "riposte_guard", 0.15)
	else:
		player.body_model.play(str(LEAD_POSE[id]), dur)
	Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.05, 0.8])


func _launcher_update(delta: float) -> void:
	_rooted(delta, 0.0)
	if role == "solo":
		var so: Array = SOLO[id]
		if _once("go", float(so[0])):
			_self_launch(so)
		return
	var at := float(LAUNCH[id][0])
	if t < at:
		# (the aim follows the camera until the throw)
		_dir = get_camera_forward()
		if id == "hurl":
			# round once with them, ending facing the throw
			player.player_model.rotation.y = atan2(-_dir.x, -_dir.z) - TAU * (1.0 - t / at)
		else:
			face_direction(_dir, delta)
	if _once("glint", at - 0.08):
		Net.fx("glint", [_chest() + _dir * 0.6, _col(FX.CORE), 0.9])
	if _once("throw", at):
		face_direction(_dir, 1.0)
		_throw()


## The throw: the crewmate goes along the aim (Skyward Kick's elevation from the camera's pitch).
func _throw() -> void:
	var l: Array = LAUNCH[id]
	var v := _kick_v() if id == "skyward_kick" else _dir * float(l[2]) + Vector3.UP * float(l[3])
	if mate and is_instance_valid(mate):
		Net.crew_signal(mate, "launch", [v, str(l[4]), bool(l[5])])
	var at := player.global_position + Vector3(0, 1.0, 0) + _dir * 0.7
	Net.fx("ring", [at, v.normalized(), 1.4, _col(), 0.3, 0.14])
	Net.fx("ring", [player.global_position, Vector3.UP, 2.6, _col(FX.CORE), 0.35, 0.12])
	Net.fx("puff_ring", [player.global_position + Vector3(0, 0.05, 0), "dust_low", 8, 0.4, 1.1, 0.8, Color(0.85, 0.8, 0.7, 0.85), 6.0])
	Net.fx("impact", [at, _col(FX.CORE)])
	Net.fx("sfx", ["thud", at, -2.0, 0.05, 0.8])
	Net.fx("sfx", ["whoosh_big", at, -3.0, 0.05, 0.75])
	match id:
		"skyward_kick":
			Net.fx("kick_swoosh", [player.body_model, 0.25, _col()])
			if _elem():
				Net.fx("hot_leg", [player.body_model, true, 0.5, _col(FX.ACCENT)])
		"crossed_blades", "anvil":
			if id == "crossed_blades":
				player.body_model.play("dual_cross" if player.style() == "dual_sword" else "riposte_cut", 0.5)
			Net.fx("blade_swoosh", [player.body_model, 0.2, _col()])
			_spray(at, v.normalized(), 10, 5.0)
		"hurl":
			Net.fx("dust_ring", [player.global_position, 14, 0.9])
			if _elem():
				Net.fx("embers", [at, v.normalized(), 10, _col(FX.ACCENT), 5.0])
		"pole_vault":
			Net.fx("debris", [player.global_position + _dir * 0.9, Vector3.UP, 5, Color(0.42, 0.36, 0.3), 4.0])
		"human_cannonball":
			Net.fx("punch_wind", [at, v.normalized(), 1.6, _col(), true])
		"cannon_ride", "sling_launch":
			GunKinds.art(player.style()).crew_throw(player, at, v)
	player.squash(-4.0)
	player.cam_shake(0.18)
	player.cam_kick(0.2, 0.35)


func _kick_v() -> Vector3:
	var pitch := KICK_PITCH_DEF
	var cam := player.get_viewport().get_camera_3d()
	if cam and not player.is_ai:
		var look := -cam.global_basis.z
		# (the game camera looks ~10 deg down at rest: that's the default arc; up steepens it, down flattens it)
		pitch = clampf(KICK_PITCH_DEF + rad_to_deg(asin(clampf(look.y, -1.0, 1.0))) + 10.0, KICK_PITCH.x, KICK_PITCH.y)
	var e := deg_to_rad(pitch)
	return _dir * cos(e) * KICK_SPEED + Vector3.UP * sin(e) * KICK_SPEED


## A self version's go: Wall Kick off a wall ahead (or the ground), the rest along their table; Rebound slams first.
func _self_launch(so: Array) -> void:
	var v := _dir * float(so[2]) + Vector3.UP * float(so[3])
	var at := player.global_position
	var normal := Vector3.UP
	if id == "skyward_kick":
		var from := player.global_position + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + _dir * WALL_REACH, 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.5:
			v = _dir * WALL_KICK_V.x + Vector3.UP * WALL_KICK_V.y
			at = hit["position"]
			normal = hit["normal"]
			Net.fx("debris", [at, normal, 5, Color(0.42, 0.36, 0.3), 4.0])
	if id == "anvil":
		_ring(3.0, REBOUND_DAMAGE, 6.0, false, false)
		Net.fx("ground_crack", [player.global_position + _dir * 1.0, _dir, 2.5, Color(0, 0, 0, 0), randi() % 1000, 0.12])
		Net.fx("sfx", ["rock_crash", player.global_position, -4.0, 0.06, 1.0])
	if id in ["cannon_ride", "sling_launch"]:
		GunKinds.art(player.style()).crew_throw(player, player.global_position, v)
	_launch(v, str(so[4]), bool(so[5]), "pole_vault" if id == "pole_vault" else "ct_launched")
	Net.fx("ring", [at, normal, 1.6, _col(), 0.3, 0.14])
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 6, 0.3, 0.9, 0.7, Color(0.85, 0.8, 0.7, 0.85), 4.5])
	Net.fx("sfx", ["thud", at, -4.0, 0.05, 0.9])
	Net.fx("sfx", ["whoosh_big", at, -5.0, 0.05, 0.9])
	player.cam_shake(0.12)


func _partner_enter() -> void:
	dur = PARTNER_WAIT
	if id == "hurl":
		_phase = "swung"
		var f: Vector3 = -mate.player_model.global_basis.z
		f.y = 0.0
		_swing_f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
		dur = float(LAUNCH[id][0]) + PARTNER_WAIT
		_swung()
		player.body_model.hold("ct_swung", 0.12)
	else:
		_phase = "perch"
		_perch()
		player.body_model.hold("ct_perch", 0.12)
	Net.fx("dust", [player.global_position, 4, 0.4])


## On the lead (their raised foot, blade, pole, hammer head, cupped hands), facing where they face.
func _perch() -> void:
	if mate == null or not is_instance_valid(mate):
		return
	var f: Vector3 = -mate.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var o: Vector3 = PERCH[id]
	player.global_position = mate.global_position + f * o.x + Vector3(0, o.y, 0) + f.cross(Vector3.UP) * o.z
	player.velocity = Vector3.ZERO
	face_direction(f, 1.0)


## Hurl: round the lead once on our own clock (their turn on our screen is a beat behind), ending out in front.
func _swung() -> void:
	if mate == null or not is_instance_valid(mate):
		return
	var k := minf(t / float(LAUNCH[id][0]), 1.0)
	var a := atan2(_swing_f.x, _swing_f.z) - TAU * (1.0 - k)
	var out := Vector3(sin(a), 0.0, cos(a))
	player.global_position = mate.global_position + out * HURL_R + Vector3(0, HURL_Y, 0)
	player.velocity = Vector3.ZERO
	face_direction(out.cross(Vector3.UP), 1.0)


# --------------------------------------------------------------------------
# Flight (after a launch): steer a little, attack for a free plunge, land in a crater (and the move's landing)
# --------------------------------------------------------------------------
func _launch(v: Vector3, land: String, plow: bool, pose := "ct_launched") -> void:
	_phase = "flight"
	_flight_t = 0.0
	_land = land
	_plow = plow
	_hit = []
	player.velocity = v
	player.air_speed = Vector2(v.x, v.z).length()
	player.variable_jump_active = false
	player.jumps_remaining = player.max_jumps - 1
	player.sky_leap_fall = true
	player.freefall_from = now_s()
	player.squash(6.0)
	player.body_model.play(pose, 0.6 if pose == "ct_launched" else 0.9)
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
	if _plow:
		_plough()
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


## Human Cannonball: whoever's in the way is bowled over (once each).
func _plough() -> void:
	for e in _pc.enemies_in(_chest() - Vector3(0, 0.3, 0), PLOW_R):
		if e in _hit:
			continue
		_hit.append(e)
		_strike_toward(e, _hd(PLOW_DAMAGE, 10.0, true), player.velocity)
		var at := (e as Node3D).global_position + Vector3(0, 1.0, 0)
		Net.fx("impact", [at, _col(FX.CORE)])
		Net.fx("ring", [at, player.velocity.normalized(), 1.2, _col(), 0.25, 0.16])
		player.cam_shake(0.15)


func _landed() -> void:
	var at := player.global_position
	match _land:
		"slash":
			# a leaping slash as you come down: round you, the blade's trail
			_ring(LAND_SLASH[0], LAND_SLASH[1], LAND_SLASH[2], false, false)
			player.body_model.play("crash_land", 0.4)
			Net.fx("slash", [player.player_model, "spin", 0.2, _col()])
			Net.fx("ring", [at, Vector3.UP, LAND_SLASH[0], _col(), 0.3, 0.14])
			Net.fx("sfx", ["whoosh_big", at, -3.0, 0.05, 1.1])
			_spray(at + Vector3(0, 0.8, 0), Vector3.UP, 10, 4.0)
		"slam":
			# a ground slam: dust and cracks thrown out, everyone round you off their feet
			_ring(LAND_SLAM[0], LAND_SLAM[1], LAND_SLAM[2], true, false)
			player.body_model.play("crash_land", 0.5)
			Net.fx("ring", [at, Vector3.UP, LAND_SLAM[0], _col(), 0.35, 0.18])
			Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, Color(0.42, 0.36, 0.3), 5.0])
			var s := randi()
			for i in 5:
				var a := TAU * float(i) / 5.0
				Net.fx("ground_crack", [at, Vector3(cos(a), 0.0, sin(a)), 2.4, _col(FX.ACCENT) if _elem() else Color(0, 0, 0, 0), s + i, 0.12])
			Net.fx("sfx", ["rock_crash", at, -3.0, 0.06, 0.9])
			player.cam_shake(0.3)


# --------------------------------------------------------------------------
# Guardian Stance (katana)
# --------------------------------------------------------------------------
func _guard_enter() -> void:
	if role == "solo":
		# Counter Stance: a long guard, the next blow turned and answered (the riposte path)
		dur = COUNTER_SOLO
		_pc.add_buff("riposte", COUNTER_SOLO + 0.05)
		player.body_model.hold("iai_ready", 0.2)
		Net.fx("sfx", ["blip_high", player.global_position, -10.0, 0.0, 1.0])
		return
	dur = GUARD_SETTLE
	player.body_model.hold("iai_ready", 0.2)
	if mate and is_instance_valid(mate):
		var w := mate.global_position + Vector3(0, 1.0, 0)
		Net.fx("streak", [_chest(), w, _col(), 0.08, 0.35])
		Net.fx("ring", [mate.global_position, Vector3.UP, 1.6, _col(), 0.4, 0.12])
		Net.fx("float_text", [w + Vector3.UP * 0.8, "Guarded", _col(FX.CORE)])
		if _elem():
			Net.fx("sakura", [w, Vector3.UP, 6, 1.5])


## A blow on our ward: out of the stance at the attacker's side, one drawing cut through them.
func _counter_enter() -> void:
	dur = COUNTER_DUR
	if _target == null or not is_instance_valid(_target):
		dur = 0.0
		return
	_dir = _flat_to(_target)
	_blink_side(_target)
	player.body_model.play("iai_slash", dur)
	if player.style() == "katana":
		KatanaFx.slash(player, 0.17, false, 1.2)
	Net.fx("sfx", ["parry", player.global_position, -2.0, 0.05, 1.1])
	CombatManager.apply_hitstop(0.06, [player])
	player.cam_kick(0.2, 0.35)


func _counter_update(delta: float) -> void:
	_rooted(delta, 0.0)
	if _once("cut", 0.11) and _target and is_instance_valid(_target) and _target.get("hurtbox") is Hurtbox:
		var hd := _hd(COUNTER_DAMAGE, 9.0, false)
		hd.stagger_duration = 0.9
		hd.unblockable = true
		hd.sever = true
		_strike(_target, hd)
		var at := _target.global_position + Vector3(0, 1.1, 0)
		Net.fx("afterimage", [player.body_model, _col(), 0.25])
		Net.fx("katana_burst", [at, "katana_slash" if _elem() else "steel_slash", 1.9, 0.35, 180.0])
		Net.fx("impact", [at, _col(FX.ACCENT)])
		Net.fx("ring", [at, _dir, 1.2, _col(), 0.22, 0.2])
		player.cam_shake(0.15)


# --------------------------------------------------------------------------
# Shield Wall (greatsword)
# --------------------------------------------------------------------------
func _wall_enter() -> void:
	dur = WALL_SECS if role == "lead" else WALL_SOLO
	player.crew_tech.mark("wall", dur, "")
	player.body_model.hold("gs_gate", 0.2)
	Net.fx("sfx", ["clash", player.global_position, -6.0, 0.05, 0.7])
	Net.fx("dust_ring", [player.global_position + _dir * 0.8, 10, 0.7])
	Net.fx("ring", [player.global_position + _dir * 0.8 + Vector3(0, 1.0, 0), _dir, 1.3, _col(), 0.35, 0.16])
	player.cam_shake(0.12)


## Held: you turn slowly with the camera; C, an attack or a dodge drops it. True when it ended.
func _wall_update(delta: float) -> bool:
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	face_direction(get_camera_forward(), delta * 0.25)
	if t > 0.3 and (input_buffer.consume_action("dodge") or input_buffer.consume_action("light_attack") \
			or input_buffer.consume_action("heavy_attack")):
		_finish()
		return true
	return false


## C pressed in the move (CrewTechniques.trigger): the Shield Wall comes down.
func on_crouch() -> void:
	if id == "shield_wall" and role != "partner" and t > 0.3:
		_finish()


# --------------------------------------------------------------------------
# Pincer (daggers)
# --------------------------------------------------------------------------
func _mark_enter() -> void:
	dur = 0.6
	player.body_model.play("emote_point", dur)
	var e := _aimed(MARK_REACH)
	if e == null:
		e = _nearest(MARK_REACH, true)
	if e == null:
		player.crew_tech.cooldown = 0.0
		player.call("_toast", "No foe close enough to mark")
		return
	var key := Net.key_of(e)
	var with := Net.key_of(mate) if role == "lead" and mate and is_instance_valid(mate) else ""
	player.crew_tech.mark("pincer", MARK_SECS, key, CrewTechniques.PINCER_SOLO if role == "solo" else 1, with)
	if with != "":
		Net.crew_signal(mate, "pincer", [key, Net.key_of(player)])
	var at := e.global_position + Vector3(0, 2.1, 0)
	Net.fx("ring", [e.global_position, Vector3.UP, 1.2, _col(), 0.4, 0.14])
	Net.fx("glint", [at, _col(FX.CORE), 1.0])
	Net.fx("float_text", [at + Vector3.UP * 0.3, "Marked", _col()])
	Net.fx("sfx", ["blip_high", player.global_position, -8.0, 0.0, 1.3])


# --------------------------------------------------------------------------
# Covering Fire (pistols)
# --------------------------------------------------------------------------
func _volley_enter() -> void:
	dur = VOLLEY
	player.crew_tech.mark("covered", CrewTechniques.COVER_SECS, "")
	Net.fx("sfx", ["blip_low", player.global_position, -8.0, 0.0, 0.9])


func _volley_update(delta: float) -> void:
	_rooted(delta, 0.0)
	_dir = get_camera_forward()
	face_direction(_dir, delta)
	if t >= 0.15 + _shots * VOLLEY_EVERY and t < dur - 0.1:
		_shots += 1
		_volley_shot()
	if _once("reload", dur - 0.05):
		player._reset_ammo()
		Net.fx("sfx", ["blip_high", player.global_position, -10.0, 0.0, 1.4])


func _volley_shot() -> void:
	var left := player.style() == "sword_pistol" or (player.style() == "dual_pistol" and _shots % 2 == 0)
	player.body_model.play("lg_fire" if player.style() == "long_gun" else ("shoot_l" if left else "shoot_r"), VOLLEY_EVERY + 0.1)
	var from := player.global_position + Vector3(0, 1.35, 0) + _dir * 0.7
	var e := _aimed(VOLLEY_REACH)
	if e == null:
		e = _nearest(VOLLEY_REACH, true)
	var to := from + _dir * VOLLEY_REACH
	if e:
		to = _body_center(e)
		var hd := _hd(VOLLEY_DAMAGE, 1.0, false)
		hd.ranged = true
		hd.stagger_duration = 0.35
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		_strike(e, hd)
		Net.fx("impact", [to, Color(1.0, 0.75, 0.45)])
	Net.fx("tracer", [from, to])
	Net.fx("muzzle_sparks", [from, (to - from).normalized(), 8])
	Net.fx("sfx", ["gunshot", from, -2.0, 0.08, 1.05])
	player.cam_shake(0.05)


# --------------------------------------------------------------------------
# (1.26) The second crew techniques: setups, combined attacks, support (DUETS)
# --------------------------------------------------------------------------
func _duet_kind() -> String:
	return str(CrewTechniques.def(id)["kind"])


func _duet_enter() -> void:
	var d: Dictionary = DUETS[id]
	var l: Array = d["lead"]
	if _duet_kind() == "support":
		dur = float(l[1])
		player.body_model.play(str(l[0]), dur)
		player.crew_tech.support(id, role)
		if role == "lead" and mate and is_instance_valid(mate):
			Net.fx("streak", [_chest(), mate.global_position + Vector3(0, 1.2, 0), _col(), 0.08, 0.3])
		return
	_target = _aimed(DUET_REACH)
	if _target == null:
		_target = _nearest(DUET_REACH, true)
	if _target == null:
		player.crew_tech.cooldown = 0.0
		player.call("_toast", "No foe close enough")
		if role == "lead" and mate and is_instance_valid(mate):
			Net.crew_signal(mate, "duet_off", [])
		dur = 0.0
		return
	_dir = _flat_to(_target)
	if _target.global_position.distance_to(player.global_position) > 2.4 and not d.get("stay", false):
		_duet_place(-_dir)
	face_direction(_dir, 1.0)
	_phase = "strike"
	dur = float(l[1]) + (SOLO_GAP + float(d["mate"][1]) if role == "solo" else 0.05)
	player.body_model.play(str(l[0]), float(l[1]))
	Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.05, 1.0])


## The partner waits for the lead's cue.
func _duet_wait() -> void:
	_phase = "wait"
	dur = PARTNER_WAIT + 1.0
	player.call("_toast", "%s: ready" % CrewTechniques.name_of(id))
	var c: Array = player.crew_tech.cue
	player.crew_tech.cue = []
	if not c.is_empty():
		_duet_cued(Net.node_of(str(c[1][0])) as Node3D, c[0] == "finish")


## The cue: out beside the foe (a setup's finisher) or at its far side from the lead (combined), and our blow.
func _duet_cued(e: Node3D, finish: bool) -> void:
	if e == null or not is_instance_valid(e):
		dur = 0.0
		return
	_target = e
	var away := (e.global_position - mate.global_position) * Vector3(1, 0, 1) if mate and is_instance_valid(mate) else -_flat_to(e)
	away = away.normalized() if away.length() > 0.1 else -_flat_to(e)
	if finish:
		away = away.cross(Vector3.UP)
	if DUETS[id].get("stay", false):
		_dir = _flat_to(e)
		face_direction(_dir, 1.0)
	else:
		_duet_place(away)
	var m: Array = DUETS[id]["mate"]
	player.body_model.play(str(m[0]), float(m[1]))
	t = 0.0
	_done = {}
	dur = float(m[1]) + 0.05
	_phase = "strike"


## A blink to the foe's side `side` (a flat direction out from it), facing it.
func _duet_place(side: Vector3) -> void:
	var from := _chest()
	Net.fx("afterimage", [player.body_model, _col(), 0.3])
	_place(_target.global_position + side * 1.3)
	_dir = -side
	face_direction(_dir, 1.0)
	Net.fx("streak", [from, _chest(), _col(), 0.1, 0.25])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 5, 0.5])


func _duet_update(delta: float) -> void:
	_rooted(delta, 0.0)
	if _phase != "strike" or _target == null or not is_instance_valid(_target):
		return
	var d: Dictionary = DUETS[id]
	var setup := _duet_kind() == "setup"
	var at := float((d["mate"] if role == "partner" else d["lead"])[2])
	if role == "lead" and not setup and _once("cue", 0.0) and mate and is_instance_valid(mate):
		Net.crew_signal(mate, "duet", [Net.key_of(_target)])
	if _once("glint", at - 0.08):
		Net.fx("glint", [PlusArts._tip(self), _col(FX.CORE), 0.9])
	if _once("blow", at):
		if role == "partner" and setup:
			_duet_blow(float(d["burst"]), d["fin"])
		elif role == "partner":
			_duet_blow(float(d["dmg"]), "")
		else:
			_duet_blow(float(d["dmg"]), d["flags"] if setup else "")
			if role == "lead" and mate and is_instance_valid(mate) and setup:
				Net.crew_signal(mate, "finish", [Net.key_of(_target)])
	if role == "lead" and not setup and _once("burst", at + 0.06):
		_duet_burst(1.0)
	if role != "solo":
		return
	var m: Array = d["mate"]
	var two := at + SOLO_GAP
	if _once("second", two):
		if not d.get("stay", false):
			_duet_place(_flat_to(_target).cross(Vector3.UP) if setup else _flat_to(_target))
		player.body_model.play(str(m[0]), float(m[1]))
	if _once("blow2", two + float(m[2])):
		if setup:
			_duet_blow(float(d["burst"]) * SOLO_K, d["fin"])
		else:
			_duet_blow(float(d["dmg"]), "")
			_duet_burst(SOLO_K)


func _duet_hd(base: float, knock: float, flags: String) -> HitData:
	return PlusArts.shape(player.melee_hit(base, "skill"), base, knock, flags, false)


func _duet_blow(base: float, flags: String) -> void:
	_strike(_target, _duet_hd(base, 3.0, flags))
	PlusArts._impact(self, _target, flags)
	PlusArts._trail(self, 0.22)
	var at := _target.global_position + Vector3(0, 1.1, 0)
	if DUETS[id].get("stay", false):
		var from := _muzzle()
		Net.fx("tracer", [from, at, _col(FX.CORE)])
		Net.fx("muzzle_sparks", [from, (at - from).normalized(), 10])
		Net.fx("sfx", ["cannon" if _tree() == "cannon" else "gunshot", from, -2.0, 0.06, 1.0])
	Net.fx("ring", [at, _dir, 1.1, _col(), 0.22, 0.16])
	Net.fx("sfx", ["whoosh_big", at, -3.0, 0.05, 1.1])
	_spray(at, _dir + Vector3.UP * 0.5, 10, 4.0)
	CombatManager.apply_hitstop(0.06, [player])
	player.cam_shake(0.14 if base < 40.0 else 0.28)
	if base >= 40.0:
		Net.fx("impact", [at, _col(FX.CORE)])
		Net.fx("ring", [_target.global_position + Vector3(0, 0.15, 0), Vector3.UP, 2.4, _col(), 0.35, 0.16])
		var c := _col(FX.CORE)
		Net.fx("screen_flash", [player.global_position, Color(c.r, c.g, c.b, 0.25), 0.25])


## The merged blow: an X across the foe, and everyone round it struck.
func _duet_burst(k: float) -> void:
	var d: Dictionary = DUETS[id]
	var c := _target.global_position + Vector3(0, 1.1, 0)
	var right := _dir.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		var a: Vector3 = (right * s + Vector3.UP * 0.7).normalized() * 1.6
		Net.fx("streak", [c - a, c + a, _col(), 0.22, 0.4])
	Net.fx("ring", [c, _dir, 2.0, _col(), 0.3, 0.18])
	Net.fx("impact", [c, _col(FX.CORE)])
	Net.fx("sfx", ["thud", c, -1.0, 0.05, 0.9])
	_spray(c, Vector3.UP, 16, 5.0)
	for e in _pc.enemies_in(c, DUET_BURST_R):
		_strike(e, _duet_hd(float(d["burst"]) * k, 4.0, d["flags"]))
		PlusArts._impact(self, e, d["flags"])
	player.cam_shake(0.25)
	player.cam_kick(0.2, 0.35)
