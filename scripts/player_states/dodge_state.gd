extends PlayerState
## Sidestep dash: a quick burst in the input direction (relative to the
## camera) while the body keeps facing where it was, or the camera when the
## weapon is drawn. No input = backstep. Fast at push-off, easing out.
## Skill map: Slip Step goes further and stays untouchable longer; mastered
## Soru (Shadow Step) vanishes you for about a second.
## Logia: the body dematerializes into its element for the whole dash (full
## i-frames, passing through enemies and gunfire) and re-forms at the end.
## Acrobatics' dodge style (a variant, docs/progression_plan.md): Roll turns you into a tumbling roll the way you go
## (further, untouchable longer, slower to come up); Sidestep is a short slip aside that keeps you facing (cheaper,
## quick to strike out of; slipping a blow as it lands makes the next hit a sure crit, PowerComponent buff "slipped").
## Afterimage leaves a Decoy where you stood that the foes after you swing at.

@export var dodge_speed: float = 13.0
@export var dodge_duration: float = 0.3
@export var iframes_duration: float = 0.22

const ROLL_DUR := 0.5
const ROLL_DIST := 4.6
const ROLL_IFRAMES := 0.34
const SIDE_DUR := 0.22
const SIDE_DIST := 2.1
const SIDE_IFRAMES := 0.18
## Heavy armour's hop (GearStats load HEAVY): short, a little off the ground, briefly untouchable.
const HOP_DUR := 0.3
const HOP_DIST := 1.7
const HOP_IFRAMES := 0.13
const HOP_UP := 2.6
## Out of a sidestep this soon you can strike.
const SIDE_STRIKE := 0.1
## A foe's blow live this close while you're untouchable in a sidestep: slipped.
const SLIP_REACH := 2.8
const SLIP_SECS := 1.2
const CROWD_SECS := 4.0
const DECOY_LIFE := 1.6
const DECOY_EVERY := 6.0

var timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var iframes_ended: bool = false
var _trail_timer: float = 0.0
## Ember Fruit (Smoldering Body): the dodge is a flash of fire that leaves
## burning embers behind.
var _ember: bool = false
var _ember_dist: float = 0.0
var _ember_prev := Vector3.ZERO
var _logia: bool = false
var _dur: float = 0.3
var _iframes: float = 0.22
var _speed: float = 13.0
## Vine Fruit: little vines sprout along the ground where you dash.
var _vine: bool = false
var _vine_dist: float = 0.0
## Skyward Dash (Acrobatics): the air dash after a mid-air recovery, level through the air, AIR_DASH_DIST m
## (input's way, or the camera's forward) in AIR_DASH_DUR s.
const AIR_DASH_DIST := 6.5
const AIR_DASH_DUR := 0.32
var _air: bool = false
## "dash", "roll", "sidestep" or "hop".
var mode: String = "dash"
## The load's distance (GearStats.LOAD_DODGE_K).
var _wk := 1.0
var _slipped: bool = false
var _perfect: bool = false
var _side_sign: float = 1.0
var _decoy_at: float = -100.0


func enter(data: Dictionary) -> void:
	timer = 0.0
	# (Storm Edy: attacks quicken for a moment after a dodge)
	player.set_meta("edy_dodge_tick", Engine.get_physics_frames())
	iframes_ended = false
	_slipped = false
	_perfect = false
	var pr := player.progression
	_air = bool(data.get("air", false))
	_logia = player.power.fruit_type() == "logia" and not player.power.suppressed()
	mode = "dash"
	if not _air and not _logia:
		if pr.has_flag("dodge_roll"):
			mode = "roll"
		elif pr.has_flag("dodge_sidestep"):
			mode = "sidestep"
	# what you wear (GearStats): all cloth rolls long, plate hops short; an Acrobatics style keeps its own, longer or shorter
	var wt: int = player.gear_load()
	_wk = float(GearStats.LOAD_DODGE_K[wt])
	if mode == "dash" and not _air and not _logia:
		mode = str(GearStats.LOAD_DODGE[wt])
	_speed = dodge_speed * (1.0 + pr.stat("dodge_dist_pct"))
	_dur = dodge_duration
	_iframes = iframes_duration * (1.0 + pr.stat("dodge_iframe_pct"))
	pr.add_life("acrobatics", 5)
	if _logia:
		_iframes = _dur + 0.05
		player.set_collision_mask_value(12, false)  # through enemies

	if player.armed and mode != "roll":
		face_direction(get_camera_forward(), 1.0)
	var move_input := get_movement_input()
	if move_input.length() > 0.1:
		dodge_direction = get_camera_relative_direction(move_input)
	elif _air:
		dodge_direction = get_camera_forward()
	elif mode == "sidestep":
		_side_sign = -_side_sign
		dodge_direction = player.player_model.global_basis.x.normalized() * _side_sign
		dodge_direction.y = 0.0
	else:
		dodge_direction = player.player_model.global_basis.z.normalized()  # backstep
		dodge_direction.y = 0.0
	if _air:
		_air_dash()

	player.hurtbox.set_deferred("monitorable", false)
	if not _air and pr.has_flag("afterimage") and now_s() - _decoy_at >= DECOY_EVERY:
		_decoy_at = now_s()
		Net.fx("decoy", [player.body_model, DECOY_LIFE])
	match mode:
		"roll":
			_roll()
			return
		"sidestep":
			_sidestep()
			return
		"hop":
			_hop()
			return

	# dash direction in the model's frame picks sidestep / forward / backstep
	var local := player.player_model.global_basis.orthonormalized().inverse() * dodge_direction
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	player.body_model.play("dash", dodge_duration)
	player.squash(-2.2)
	player.cam_shake(player.DASH_SHAKE)
	Net.fx("dust", [player.global_position - dodge_direction * 0.3 + Vector3(0, 0.05, 0), 7, 0.6])
	Net.fx("sfx", ["whoosh", player.global_position, -9.0, 0.1, 1.15])
	_trail_timer = 0.0
	_ember = _logia and player.power.fruit == "ember" and player.progression.has_flag("smoldering")
	_ember_dist = 0.6
	_ember_prev = player.global_position
	_vine = player.power.fruit == "vine" and not player.power.suppressed()
	_vine_dist = 0.5
	TraitMoves.on_dodge(player)
	if player.power.shadow_step():
		Net.fx("afterimage", [player.body_model, Color(0.6, 0.85, 1.0)])
		Net.fx("sfx", ["whoosh_big", player.global_position, -5.0, 0.05, 1.5])
		player.vanish(0.9)
	elif _logia:
		# dematerialize
		player.body_model.visible = false
		var col: Color = player.power.fruit_data().get("color", Color(1.0, 0.5, 0.15))
		Net.fx("flame", [player.global_position + Vector3(0, 0.9, 0), 18, 0.9, 0.45, 0.5])
		Net.fx("afterimage", [player.body_model, col, 0.25])
		Net.fx("sfx", ["fire_burst", player.global_position, -8.0, 0.1, 1.4])


## Roll: turned into the roll, a dive onto the shoulder, over and up onto the feet.
func _roll() -> void:
	var pr := player.progression
	_dur = ROLL_DUR
	_iframes = ROLL_IFRAMES * (1.0 + pr.stat("dodge_iframe_pct"))
	_speed = ROLL_DIST * _wk * (1.0 + pr.stat("dodge_dist_pct")) / (0.75 * ROLL_DUR)
	face_direction(dodge_direction, 1.0)
	player.body_model.dash_dir = Vector2(0, 1)
	player.body_model.play("dodge_roll", ROLL_DUR)
	player.squash(-3.0)
	player.cam_shake(player.DASH_SHAKE)
	var at := player.global_position
	Net.fx("dust", [at - dodge_direction * 0.3 + Vector3(0, 0.05, 0), 8, 0.6])
	Net.fx("sfx", ["whoosh", at, -9.0, 0.1, 0.9])
	_trail_timer = 0.0
	TraitMoves.on_dodge(player)


## Heavy armour's hop: a short low bound, still facing them, guard kept (held, it lands back in the Block).
func _hop() -> void:
	var pr := player.progression
	_dur = HOP_DUR
	_iframes = HOP_IFRAMES * (1.0 + pr.stat("dodge_iframe_pct"))
	_speed = HOP_DIST * (1.0 + pr.stat("dodge_dist_pct")) / (0.7 * HOP_DUR)
	player.velocity.y = HOP_UP
	var local := player.player_model.global_basis.orthonormalized().inverse() * dodge_direction
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	player.body_model.play("sidestep", HOP_DUR + 0.1)
	player.squash(-2.0)
	player.cam_shake(player.DASH_SHAKE * 0.6)
	Net.fx("dust", [player.global_position - dodge_direction * 0.2 + Vector3(0, 0.05, 0), 5, 0.5])
	Net.fx("sfx", ["whoosh", player.global_position, -10.0, 0.08, 0.85])
	_trail_timer = 0.0
	TraitMoves.on_dodge(player)


## Sidestep: a short sharp slip aside, still facing them.
func _sidestep() -> void:
	var pr := player.progression
	_dur = SIDE_DUR
	_iframes = SIDE_IFRAMES * (1.0 + pr.stat("dodge_iframe_pct"))
	_speed = SIDE_DIST * _wk * (1.0 + pr.stat("dodge_dist_pct")) / (0.72 * SIDE_DUR)
	var local := player.player_model.global_basis.orthonormalized().inverse() * dodge_direction
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	player.body_model.play("sidestep", SIDE_DUR + 0.12)
	player.squash(-1.6)
	Net.fx("dust", [player.global_position - dodge_direction * 0.2 + Vector3(0, 0.05, 0), 4, 0.45])
	Net.fx("sfx", ["whoosh", player.global_position, -11.0, 0.08, 1.45])
	_trail_timer = 0.0
	TraitMoves.on_dodge(player)


func physics_update(delta: float) -> void:
	# Sea King Fist armed: let it go out of the dash, carrying its speed
	if player.fist_armed > 0.0 and input_buffer.consume_action("light_attack"):
		FistArts.unleash(player)
		return
	if _air:
		player.velocity.y = 0.0
	else:
		apply_gravity(delta)
	timer += delta

	var u := clampf(timer / _dur, 0.0, 1.0)
	var spd := _speed * (1.4 - 1.1 * u)   # burst then ease out (average ~0.85x)
	match mode:
		"roll":
			# (rolling along at speed, then up off the ground with what's left)
			spd = _speed * (0.9 if u < 0.62 else lerpf(0.9, 0.1, (u - 0.62) / 0.38))
		"sidestep":
			spd = _speed * maxf(1.5 - 1.55 * u, 0.0)
		"hop":
			spd = _speed * maxf(1.3 - 1.2 * u, 0.1)
	player.velocity.x = dodge_direction.x * spd
	player.velocity.z = dodge_direction.z * spd
	player.move_and_slide()
	if player.armed and mode != "roll":
		face_camera(delta)
	if _logia:
		Net.fx("flame", [player.global_position + Vector3(0, 0.9, 0), 3, 0.8, 0.35, 0.45])
	var step := player.global_position.distance_to(_ember_prev)
	_ember_prev = player.global_position
	if _ember:
		_ember_dist += step
		if _ember_dist > 1.0 and player.is_on_floor():
			_ember_dist = 0.0
			FireZone.spawn(player.get_tree(), player.global_position, 0.75, 1.6, 6.0, player)
	if _vine:
		_vine_dist += step
		if _vine_dist > 0.9 and player.is_on_floor():
			_vine_dist = 0.0
			Net.fx("ground_vines", [player.global_position, dodge_direction])
	_trail_timer -= delta
	if _trail_timer <= 0.0 and player.is_on_floor():
		_trail_timer = 0.05
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 2, 0.4])
	if mode == "roll" and timer >= 0.16 and timer - delta < 0.16:
		Net.fx("puff_ring", [player.global_position + Vector3(0, 0.05, 0), "dust_low", 5, 0.25, 0.45, 0.4, Color(0.8, 0.74, 0.64, 0.75), 1.6])
		Net.fx("sfx", ["thud", player.global_position, -16.0, 0.08, 1.3])

	if not iframes_ended and not _perfect and _blow_near():
		_perfect = true
		_perfect_dodge()
	if mode == "sidestep" and not iframes_ended and not _slipped and _blow_near():
		_slip()
	if timer >= _iframes and not iframes_ended:
		iframes_ended = true
		player.hurtbox.set_deferred("monitorable", true)

	if mode == "sidestep" and timer >= SIDE_STRIKE:
		var next := combat_input()
		if next != "":
			transitioned.emit(self, next, {})
			return
	if timer >= _dur:
		if _air:
			transitioned.emit(self, "Fall", {})
			return
		if mode == "hop" and player.inp.pressed("parry"):
			transitioned.emit(self, "Block", {})
			return
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})


## A foe's blow live within reach right now (you're untouchable, so it's passing through where you were).
func _blow_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		var hb = e.get("hitbox")
		if hb is Hitbox and (hb as Hitbox).active and (e as Node3D).global_position.distance_to(player.global_position) < SLIP_REACH:
			return true
	return false


## A perfect dodge (a blow passing through where you were): Slow Sight slows time, Crowd Read shows every foe for 4 s.
func _perfect_dodge() -> void:
	var pr := player.progression
	var slow := pr.stat("foresight_slow")
	if slow > 0.0:
		CombatManager.apply_slowmo(0.35, slow)
	if pr.has_flag("crowd_read"):
		player.power.add_buff("crowd_sight", CROWD_SECS)


## Slipped a blow: a glint off the shoulder, and the next hit is a sure crit.
func _slip() -> void:
	_slipped = true
	player.power.add_buff("slipped", SLIP_SECS)
	player.progression.add_life("acrobatics", 6)
	var at := player.global_position + Vector3(0, 1.4, 0)
	Net.fx("glint", [at, Color(1.0, 0.97, 0.85), 0.7])
	Net.fx("float_text", [at + Vector3(0, 0.4, 0), "Slipped!", Color(1.0, 0.95, 0.75)])
	Net.fx("sfx", ["whoosh_big", at, -8.0, 0.05, 1.6])
	CombatManager.apply_hitstop(0.05, [player])


## Skyward Dash: one burst the way you're going, level, the body stretched along it, an afterimage left behind.
func _air_dash() -> void:
	player.skyward_dash = false
	_dur = AIR_DASH_DUR
	_speed = AIR_DASH_DIST / (0.85 * AIR_DASH_DUR)
	player.velocity.y = 0.0
	face_direction(dodge_direction, 1.0)
	var at := player.global_position + Vector3(0, 0.9, 0)
	Net.fx("afterimage", [player.body_model, Color(0.8, 0.92, 1.0), 0.3])
	Net.fx("ring", [at - dodge_direction * 0.4, dodge_direction, 0.9, Color(1.0, 0.98, 0.92, 0.8), 0.25, 0.08])
	Net.fx("sfx", ["whoosh_big", at, -6.0, 0.05, 1.35])


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	player.ember_dodge_reflex()
	player.echo_dodge_reflex()
	if _logia:
		_logia = false
		player.set_collision_mask_value(12, true)
		if not player.vanished():
			player.body_model.visible = true
			Net.fx("flame", [player.global_position + Vector3(0, 0.9, 0), 12, 0.8, 0.4, 0.4])
