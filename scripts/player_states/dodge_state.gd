extends PlayerState
## Sidestep dash: a quick burst in the input direction (relative to the
## camera) while the body keeps facing where it was, or the camera when the
## weapon is drawn. No input = backstep. Fast at push-off, easing out.
## Skill map: Slip Step goes further and stays untouchable longer; mastered
## Soru (Shadow Step) vanishes you for about a second.
## Logia: the body dematerializes into its element for the whole dash (full
## i-frames, passing through enemies and gunfire) and re-forms at the end.

@export var dodge_speed: float = 13.0
@export var dodge_duration: float = 0.3
@export var iframes_duration: float = 0.22

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


func enter(_data: Dictionary) -> void:
	timer = 0.0
	iframes_ended = false
	var pr := player.progression
	_speed = dodge_speed * (1.0 + pr.stat("dodge_dist_pct"))
	_dur = dodge_duration
	_iframes = iframes_duration * (1.0 + pr.stat("dodge_iframe_pct"))
	_logia = player.power.fruit_type() == "logia" and not player.power.suppressed()
	if _logia:
		_iframes = _dur + 0.05
		player.set_collision_mask_value(12, false)  # through enemies

	if player.armed:
		face_direction(get_camera_forward(), 1.0)
	var move_input := get_movement_input()
	if move_input.length() > 0.1:
		dodge_direction = get_camera_relative_direction(move_input)
	else:
		dodge_direction = player.player_model.global_basis.z.normalized()  # backstep
		dodge_direction.y = 0.0

	player.hurtbox.set_deferred("monitorable", false)

	# dash direction in the model's frame picks sidestep / forward / backstep
	var local := player.player_model.global_basis.orthonormalized().inverse() * dodge_direction
	player.body_model.dash_dir = Vector2(local.x, -local.z)
	player.body_model.play("dash", dodge_duration)
	player.squash(-2.2)
	CombatManager.apply_camera_shake(player.DASH_SHAKE)
	Net.fx("dust", [player.global_position - dodge_direction * 0.3 + Vector3(0, 0.05, 0), 7, 0.6])
	Net.fx("sfx", ["whoosh", player.global_position, -9.0, 0.1, 1.15])
	_trail_timer = 0.0
	_ember = _logia and player.power.fruit == "ember" and player.progression.has_flag("smoldering")
	_ember_dist = 0.6
	_ember_prev = player.global_position
	_vine = player.power.fruit == "vine" and not player.power.suppressed()
	_vine_dist = 0.5
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


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	timer += delta

	# burst then ease out (average ~0.85x dodge_speed)
	var u := clampf(timer / _dur, 0.0, 1.0)
	var spd := _speed * (1.4 - 1.1 * u)
	player.velocity.x = dodge_direction.x * spd
	player.velocity.z = dodge_direction.z * spd
	player.move_and_slide()
	if player.armed:
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

	if timer >= _iframes and not iframes_ended:
		iframes_ended = true
		player.hurtbox.set_deferred("monitorable", true)

	if timer >= _dur:
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	if _logia:
		_logia = false
		player.set_collision_mask_value(12, true)
		if not player.vanished():
			player.body_model.visible = true
			Net.fx("flame", [player.global_position + Vector3(0, 0.9, 0), 12, 0.8, 0.4, 0.4])
