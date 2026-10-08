extends PlayerState
## Swimming at the surface. You float with your head above the waves and
## stroke around (Shift: faster but hungrier on stamina). Ctrl ducks you under
## for a few seconds. Space pulls you up onto a low ledge in front of you, or
## up a ladder; F also uses a ladder.
## Swimming slowly drains stamina and treading water lets it creep back; run
## the bar dry and you tire, losing a little health every second until you
## get out of the water.
##
## Devil Fruit users can't swim at all: the sea drags them under. They sink,
## struggling weakly, can trudge along the bottom, and drown (health drains
## fast once the head is under) unless they reach shallow water or a ladder.

const SWIM_SPEED := 3.2
const FAST_SPEED := 4.6
const TIRED_SPEED := 2.0
const ACCEL := 9.0
const DRAIN := 3.5
const FAST_DRAIN := 13.0
const DIVE_COST := 12.0
const DIVE_DRAIN := 8.0
const DIVE_MIN := 0.5
const DIVE_MAX := 2.6
const DIVE_DEPTH := 1.7
const TREAD_REGEN := 0.15
const EXHAUST_DAMAGE := 5.0
const EXHAUST_TICK := 1.0
## Exhausted until stamina is back to this.
const RECOVER := 25.0
## Ledges you can pull yourself onto: top this high above the water at most.
const LEDGE_MAX := 1.5

var _vy: float = 0.0
var _diving: bool = false
var _dive_t: float = 0.0
var _tick: float = 0.0
var _warned: bool = false
var _ripple_t: float = 0.0
var _stroke_t: float = 0.0
var _move_blend: float = 0.0
var _exhausted: bool = false
var _prev_target: float = INF
# the sea's curse
const SINK_SPEED := 1.6
const SEABED_SPEED := 1.5
const DROWN_GRACE := 1.0
const DROWN_DPS := 10.0
var _cursed: bool = false
var _under_t: float = 0.0
var _bubble_t: float = 0.0


func enter(data: Dictionary) -> void:
	player.sheathe_weapon(true)
	player.sprinting = false
	player.is_parrying = false
	player.reset_combo()
	player.sword_hitbox.deactivate()
	player.jumps_remaining = player.max_jumps
	player.body_model.stop_action()
	player.body_model.swimming = true
	player.body_model.diving = false
	var vy_in := float(data.get("entry_vy", 0.0))
	_vy = minf(vy_in, 0.0) * 0.45
	_diving = false
	_tick = 0.0
	_warned = false
	_exhausted = player.stamina <= 0.0
	_move_blend = 0.0
	_prev_target = INF
	_cursed = player.power.has_fruit()
	_under_t = 0.0
	if _cursed:
		player.call("_toast", "The sea drags you under! Get to shallow water")
	var surf := player.water_surface()
	var at := Vector3(player.global_position.x, surf, player.global_position.z)
	if data.get("quiet", false):
		Net.fx("splash", [at, 3, 0.5])
	elif vy_in < -5.0:
		Net.fx("splash", [at, 12, 1.0])
		Net.fx("dust_ring", [at, 10, 0.8])
		Net.fx("sfx", ["splash", at, -2.0, 0.08, 0.85])
	else:
		Net.fx("splash", [at, 5, 0.7])
		Net.fx("sfx", ["splash", at, -8.0, 0.1, 1.1])


func physics_update(delta: float) -> void:
	var input := get_movement_input()
	var dir := get_camera_relative_direction(input) if input.length() > 0.1 else Vector3.ZERO
	if _cursed:
		_sink_update(delta, dir)
		return
	# run the bar dry and you're exhausted until it's back to a quarter
	if player.stamina <= 0.5:
		_exhausted = true
	elif player.stamina >= RECOVER:
		_exhausted = false
	var tired := _exhausted
	var fast := Input.is_action_pressed("sprint") and not tired and dir != Vector3.ZERO and not _diving
	var spd := TIRED_SPEED if tired else (FAST_SPEED if fast else SWIM_SPEED)
	if _diving:
		spd = SWIM_SPEED * 1.15
	spd *= clampf(input.length(), 0.0, 1.0) * (1.0 + player.progression.stat("swim_pct"))
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z)
	hv = hv.move_toward(dir * spd, ACCEL * delta)

	# duck under (Ctrl): a few seconds, then you bob back up
	if not _diving and Input.is_action_just_pressed("dodge") and not tired and player.spend_stamina(DIVE_COST):
		_diving = true
		_dive_t = 0.0
		var at := _surface_point()
		Net.fx("splash", [at, 6, 0.7])
		Net.fx("sfx", ["splash", at, -6.0, 0.1, 0.9])
	if _diving:
		_dive_t += delta
		if (_dive_t > DIVE_MIN and not Input.is_action_pressed("dodge")) or _dive_t > DIVE_MAX or player.stamina <= 0.0:
			_diving = false
			var at := _surface_point()
			Net.fx("splash", [at, 6, 0.7])
			Net.fx("sfx", ["splash", at, -7.0, 0.1, 1.15])
	player.body_model.diving = _diving

	# stamina: strokes cost a little, treading water lets it creep back
	if dir != Vector3.ZERO or _diving:
		var rate := DIVE_DRAIN if _diving else (FAST_DRAIN if fast else DRAIN)
		player.drain_stamina(rate * delta)
		player.stamina_regen_mult = 0.0
	else:
		player.stamina_regen_mult = TREAD_REGEN

	# exhausted: lose health until you get out (or get your breath back)
	if _exhausted:
		_tick += delta
		if not _warned:
			_warned = true
			player.call("_toast", "Exhausted! Get out of the water")
		if _tick >= EXHAUST_TICK:
			_tick = 0.0
			player.health_component.take_damage(EXHAUST_DAMAGE)
			Net.fx("sfx", ["splash", player.global_position, -10.0, 0.1, 0.7])
			if player.health_component.current_health <= 0.0:
				return  # the death ragdoll takes over
	else:
		_tick = 0.0
		_warned = false

	# float: hips near the surface, head above it (deeper while diving)
	_move_blend = move_toward(_move_blend, clampf(hv.length() / SWIM_SPEED, 0.0, 1.0), delta * 3.0)
	var target := _float_y(tired)
	var y := player.global_position.y
	# ride the swell: follow the surface's own rise and fall (feed-forward)
	# so the head doesn't lag under a rising wave
	var target_v := 0.0 if _prev_target == INF else clampf((target - _prev_target) / maxf(delta, 0.0001), -6.0, 6.0)
	_prev_target = target
	_vy += ((target - y) * 14.0 + (target_v - _vy) * 7.5) * delta
	_vy = clampf(_vy, -12.0, 6.0)
	player.velocity = Vector3(hv.x, _vy, hv.z)
	player.move_and_slide()
	if dir != Vector3.ZERO:
		face_direction(dir, delta * 0.6)

	# ripples and stroke splashes
	_ripple_t -= delta
	if _ripple_t <= 0.0 and not _diving:
		_ripple_t = 0.45 if hv.length() > 0.5 else 1.1
		Net.fx("splash", [_surface_point() + hv.normalized() * 0.4 if hv.length() > 0.5 else _surface_point(), 2 if hv.length() > 0.5 else 1, 0.4])
	_stroke_t -= delta
	if hv.length() > 0.8 and _stroke_t <= 0.0 and not _diving:
		_stroke_t = 0.6 if fast else 0.9
		Net.fx("sfx", ["splash", player.global_position, -20.0, 0.2, 1.5])

	# walked out of the water
	if not _diving and player.is_on_floor() and player.water_depth() < Player.SWIM_EXIT_DEPTH:
		transitioned.emit(self, "Move" if dir != Vector3.ZERO else "Idle", {})
		return

	# climb out: a ladder in reach, or a low ledge in front
	if Input.is_action_just_pressed("jump") and not _diving:
		var ladder := _ladder_in_reach()
		if ladder:
			player.start_climb({"kind": "ladder", "ladder": ladder})
			return
		var ledge := _find_ledge()
		if not ledge.is_empty():
			player.start_climb(ledge)
			return


## Devil Fruit user in deep water: sinking, struggling, drowning.
func _sink_update(delta: float, dir: Vector3) -> void:
	var on_floor := player.is_on_floor()
	var spd := SEABED_SPEED if on_floor else 0.9
	var hv := Vector3(player.velocity.x, 0.0, player.velocity.z).move_toward(dir * spd, 4.0 * delta)
	var vy := player.velocity.y
	if on_floor:
		vy = -0.5
	else:
		vy = move_toward(vy, -SINK_SPEED, 6.0 * delta)
	player.velocity = Vector3(hv.x, vy, hv.z)
	player.move_and_slide()
	if dir != Vector3.ZERO:
		face_direction(dir, delta * 0.5)
	player.body_model.swimming = not on_floor
	player.body_model.diving = false
	player.stamina_regen_mult = 0.0
	# drowning once the head is under
	var head := player.body_model.head.global_position
	if player.water_surface(head) - head.y > 0.05:
		_under_t += delta
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = 0.35
			Net.fx("sparkle", [head + Vector3(0, 0.15, 0), 2, Color(0.8, 0.92, 1.0)])
		if _under_t > DROWN_GRACE:
			_tick += delta
			if _tick >= 0.5:
				_tick = 0.0
				player.health_component.take_damage(DROWN_DPS * 0.5)
				if player.health_component.current_health <= 0.0:
					return
	else:
		_under_t = 0.0
	# made it to the shallows
	if on_floor and player.water_depth() < Player.SWIM_EXIT_DEPTH:
		transitioned.emit(self, "Move" if dir != Vector3.ZERO else "Idle", {})
		return
	# a ladder can still save you
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		var ladder := _ladder_in_reach()
		if ladder:
			player.start_climb({"kind": "ladder", "ladder": ladder})


func _surface_point() -> Vector3:
	var p := player.global_position
	return Vector3(p.x, player.water_surface(), p.z)


## Root (feet) height that puts the hips at the right depth below the waves.
func _float_y(tired: bool) -> float:
	var surf := player.water_surface()
	var hip := player.body_model.hip_y * player.body_model.scale.y
	var depth := lerpf(0.42, 0.34, _move_blend) * player.body_model.scale.y
	if tired:
		depth += 0.12
	if _diving:
		depth += DIVE_DEPTH
	return surf - depth - hip


func _ladder_in_reach() -> Ladder:
	for l in get_tree().get_nodes_in_group("ladders"):
		var lad := l as Ladder
		if lad and lad.in_reach(player.global_position):
			return lad
	return null


## A walkable edge just above the water in front of you, with room to stand.
func _find_ledge() -> Dictionary:
	var fwd := -player.player_model.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return {}
	fwd = fwd.normalized()
	var surf := player.water_surface()
	var space := player.get_world_3d().direct_space_state
	for reach in [0.55, 0.8, 1.05]:
		var probe: Vector3 = player.global_position + fwd * float(reach)
		var q := PhysicsRayQueryParameters3D.create(Vector3(probe.x, surf + LEDGE_MAX + 0.4, probe.z), Vector3(probe.x, surf + 0.1, probe.z), 1)
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		var top: Vector3 = hit["position"]
		var h := top.y - surf
		if n.y < 0.7 or h < 0.15 or h > LEDGE_MAX:
			continue
		# room to stand up there
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.7
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.collision_mask = 1
		sq.transform = Transform3D(Basis.IDENTITY, top + fwd * 0.35 + Vector3.UP * 0.95)
		sq.exclude = [player.get_rid()]
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var anchor := hit["collider"] as Node3D
		return {"kind": "ledge", "anchor": anchor, "edge": top, "top": top + fwd * 0.35, "fwd": fwd}
	return {}


func exit() -> void:
	player.body_model.swimming = false
	player.body_model.diving = false
	player.stamina_regen_mult = 1.0
	_diving = false
