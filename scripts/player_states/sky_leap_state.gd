extends PlayerState
## Sky Leap (Acrobatics): stand still and hold jump to charge (Will hardens the legs, a ring of dust grows), let go
## to launch straight up and a little forward, height and reach by the charge and the owned nodes. A tap is a normal
## jump. No tumble on the way up (the freefall clock starts at the top), the air steps and Skyward Dash are there at
## the top, and the landing is a crater with no fall damage (Player.sky_leap_fall, crater()).

## Held this long it's a charge, not a jump.
const TAP := 0.2
## A full charge.
const CHARGE := 1.2
const UP := 25.0
const FWD := 5.0
## Haki Legs, a step.
const STEP_UP := 5.0
const STEP_FWD := 2.0
## Heavenward.
const HEAVEN_UP := 20.0
const HEAVEN_FWD := 4.0
const COST := 40.0
const HEAVEN_COST := 50.0
const PULSE := 0.3
const HAKI_LEG := Color(0.55, 0.06, 0.12)

var _from := 0.0
var _rising := false
var _pulse_at := 0.0
var _full := false
var _charging := false
var _g := 20.0


func enter(_data: Dictionary) -> void:
	_from = now_s()
	_rising = false
	_full = false
	_charging = false
	_pulse_at = _from + TAP
	_g = player.gravity


func exit() -> void:
	if player.body_model.current_action() in ["sky_leap_charge", "sky_leap"]:
		player.body_model.stop_action()
	if _charging and not _rising:
		Net.fx("haki_legs", [player.body_model, 0.0, 0.0])


## Full-charge height and forward reach (m) with the nodes owned.
func reach() -> Vector2:
	var pr := player.progression
	var steps := pr.stat("sky_leap_steps")
	var heaven := 1.0 if pr.has_flag("heavenward") else 0.0
	return Vector2(UP + STEP_UP * steps + HEAVEN_UP * heaven, FWD + STEP_FWD * steps + HEAVEN_FWD * heaven)


func cost() -> float:
	return HEAVEN_COST if player.progression.has_flag("heavenward") else COST


func physics_update(delta: float) -> void:
	if _rising:
		_rise(delta)
		return
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
	player.move_and_slide()
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return
	var input := get_movement_input()
	if input.length() > 0.1:
		face_direction(get_camera_relative_direction(input), delta)
	var held := now_s() - _from
	if not Input.is_action_pressed("jump"):
		if held < TAP:
			transitioned.emit(self, "Jump", {"full": true})
		else:
			_launch(clampf(held / CHARGE, 0.0, 1.0))
		return
	if held >= TAP and now_s() >= _pulse_at:
		_charge_fx(held)


func _charge_fx(held: float) -> void:
	var k := clampf(held / CHARGE, 0.0, 1.0)
	var at := player.global_position
	if not _charging:
		_charging = true
		player.body_model.hold("sky_leap_charge", CHARGE)
		Net.fx("haki_legs", [player.body_model, CHARGE, 6.0])
		Net.fx("sfx", ["haki", at, -10.0, 0.04, 0.6])
		Net.fx("gather", [at + Vector3(0, 0.4, 0), 1.4, HAKI_LEG, CHARGE, 12])
	_pulse_at = now_s() + PULSE
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 4 + int(6 * k), 0.3 + 0.6 * k, 0.5 + 0.5 * k, 0.6, Color(0.82, 0.76, 0.66, 0.8), 1.5 + 3.5 * k])
	if k >= 1.0 and not _full:
		_full = true
		Net.fx("ring", [at, Vector3.UP, 2.4, HAKI_LEG, 0.35, 0.1])
		Net.fx("glint", [at + Vector3(0, 0.25, 0), Color(1.0, 0.85, 0.9), 0.9])
		Net.fx("sfx", ["haki", at, -6.0, 0.03, 0.85])


func _launch(k: float) -> void:
	if not player.spend_stamina(cost() * lerpf(0.5, 1.0, k)):
		transitioned.emit(self, "Jump", {"full": true})
		return
	var r := reach() * k
	var v0 := sqrt(2.0 * _g * r.x) + _g / float(Engine.physics_ticks_per_second) * 0.5
	var fwd := -player.player_model.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var h := fwd * (r.y * _g / v0)
	player.velocity = Vector3(h.x, v0, h.z)
	player.air_speed = 0.0
	player.variable_jump_active = false
	player.jumps_remaining = player.max_jumps - 1
	player.sky_leap_fall = true
	player.freefall_from = now_s()
	_rising = true
	player.squash(6.0)
	player.body_model.hold("sky_leap", 0.5)
	player.progression.add_life("acrobatics", 10)
	var at := player.global_position
	Net.fx("haki_legs", [player.body_model, 0.05, 0.6 + v0 / _g])
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 8 + int(6 * k), 0.4, 1.0 + 0.6 * k, 0.9, Color(0.85, 0.8, 0.7, 0.85), 5.0 + 6.0 * k])
	Net.fx("ring", [at, Vector3.UP, 2.0 + 3.0 * k, Color(1.0, 0.96, 0.9, 0.85), 0.35, 0.14])
	Net.fx("ring", [at + Vector3(0, 1.0, 0), Vector3.UP, 1.2 + 1.2 * k, HAKI_LEG, 0.3, 0.08])
	Net.fx("streak", [at + Vector3(0, 0.3, 0), at + Vector3(0, 3.0 + 4.0 * k, 0) + h * 0.15, Color(1.0, 0.95, 0.88), 0.18, 0.35])
	Net.fx("sfx", ["thud", at, -4.0, 0.05, 0.75])
	Net.fx("sfx", ["whoosh_big", at, -6.0, 0.05, 0.8])
	CombatManager.apply_camera_shake(0.12 + 0.18 * k)


func _rise(delta: float) -> void:
	player.velocity.y -= _g * delta
	player.move_and_slide()
	if player.velocity.y > 0.0:
		return
	player.freefall_from = now_s()
	if player.progression.has_flag("skyward_dash"):
		player.skyward_dash = true
	transitioned.emit(self, "Fall", {"from_jump": true})


## Down from a Sky Leap at `speed`: a crater instead of a hurt landing, and straight back on your feet.
func crater(speed: float) -> void:
	var k := clampf((speed - Player.SAFE_FALL_SPEED) / 12.0, 0.3, 1.0)
	var at := player.global_position
	var surf: String = player.ground_surface()
	player.squash(-9.0)
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 8 + int(6 * k), 0.5, 1.2 + 0.6 * k, 1.1, Color(0.85, 0.8, 0.7, 0.9), 7.0 + 5.0 * k])
	Net.fx("ring", [at, Vector3.UP, 3.0 + 3.0 * k, Color(1.0, 0.96, 0.9, 0.8), 0.4, 0.18])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 6 + int(6 * k), Color(0.42, 0.36, 0.3), 5.0 + 3.0 * k])
	if surf not in ["wood", "water"]:
		var s := randi()
		for i in 5:
			var a := TAU * (float(i) + randf_range(-0.25, 0.25)) / 5.0
			Net.fx("ground_crack", [at, Vector3(cos(a), 0.0, sin(a)), 1.6 + 1.4 * k, Color(0, 0, 0, 0), s + i, 0.12])
	Net.fx("sfx", ["rock_crash", at, -5.0, 0.06, 1.1])
	Net.fx("sfx", ["thud", at, -2.0, 0.05, 0.7])
	CombatManager.apply_camera_shake(0.2 + 0.2 * k)
