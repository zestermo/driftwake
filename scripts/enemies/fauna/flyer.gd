class_name Flyer
extends Creature
## What bats and birds share: a perch (`anchor`), flying by steering toward a
## goal (no collisions, kept clear of the ground below), and the swoop: a
## hover with a cry (the tell), then a dive through where you stand and back up.
## Knocked out of the air it falls and lies a moment, then takes off again.

## Where it perches or hangs (world).
var anchor := Vector3.ZERO
var speed: float = 6.0
var dive_speed: float = 10.0
## Circles its target this far out and this high up while it waits to dive.
var orbit := Vector2(3.0, 2.6)
## Dives before it gives up and goes home.
var dives_max: int = 3

var _mode := "home"
var _dives: int = 0
var _dive_dir := Vector3.ZERO
var _dive_at := Vector3.ZERO
var _orbit_a: float = 0.0
var _ground_y: float = -INF
var _ray_t: float = 0.0
var _flap: float = 0.0


func _setup_flyer(args: Dictionary) -> void:
	anchor = args.get("anchor", home)
	flying = true


func _start() -> void:
	global_position = _perch_point()
	_set_state(S.PERCH)
	_orbit_a = _rng.randf() * TAU


## Where the body sits when perched (bats hang below the anchor).
func _perch_point() -> Vector3:
	return anchor


func in_combat() -> bool:
	return state in [S.TELL, S.ATTACK] or (state == S.FLY and _mode == "hunt")


## Take off: "hunt" (come for a captain), "roam" (fly about the perch), "home".
func take_off(mode: String) -> void:
	if state in [S.DEAD, S.DOWN]:
		return
	_mode = mode
	if mode == "hunt":
		_dives = 0
	if state == S.PERCH:
		velocity = Vector3.UP * 2.5 + _fwd() * 1.5
		Net.fx("sfx", ["flap", global_position, -6.0, 0.1, 1.0])
	if state in [S.PERCH, S.IDLE, S.WANDER]:
		_set_state(S.FLY)


func _brain(delta: float) -> void:
	var p := _target()
	match state:
		S.PERCH:
			velocity = Vector3.ZERO
			global_position = _perch_point()
			_perched(p, delta)
		S.FLY:
			_flying(p, delta)
		S.TELL:
			velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
			if p:
				_face(flat(p.global_position - global_position))
			_turn = 12.0
			if st_t >= _tell_len():
				_dive_at = (p.global_position if p else global_position + _fwd() * 3.0) + Vector3(0, 1.2, 0)
				if p is CharacterBody3D:
					_dive_at += flat((p as CharacterBody3D).velocity) * 0.25
				_dive_dir = (_dive_at - global_position).normalized()
				_dives += 1
				_set_state(S.ATTACK)
				_strike(0)
				Net.fx("sfx", ["whoosh", global_position, -5.0, 0.1, 1.4])
		S.ATTACK:
			_face(flat(_dive_dir))
			_turn = 14.0
			velocity = velocity.move_toward(_dive_dir * dive_speed, 40.0 * delta)
			var past := (_dive_at - global_position).dot(_dive_dir) < -0.6
			if past or st_t > 1.0 or not hitbox.hit_targets.is_empty() or global_position.y < _ground_y + 0.5:
				hitbox.deactivate()
				_cool = _rng.randf_range(1.2, 2.4)
				velocity = Vector3(_dive_dir.x, 0.0, _dive_dir.z) * dive_speed * 0.5 + Vector3.UP * 5.0
				_set_state(S.FLY)
				if _dives >= dives_max:
					_mode = _after_dives()


func _tell_len() -> float:
	return 0.4


## What to do at the perch (the creature's own triggers).
func _perched(_p: Node3D, _delta: float) -> void:
	pass


## Done diving: "home" or "roam".
func _after_dives() -> String:
	return "home"


func _flying(p: Node3D, delta: float) -> void:
	var goal := anchor
	match _mode:
		"hunt":
			if not _player_ok(p) or flat(p.global_position - anchor).length() > 34.0:
				_mode = "home"
				return
			_orbit_a += delta * 1.4
			goal = p.global_position + Vector3(cos(_orbit_a) * orbit.x, orbit.y + sin(_t * 2.1) * 0.4, sin(_orbit_a) * orbit.x)
			_face(flat(p.global_position - global_position))
			if _cool <= 0.0 and st_t > 0.8 and global_position.distance_to(goal) < 2.5:
				_set_state(S.TELL)
				_cry()
				return
		"roam":
			_orbit_a += delta * 0.7
			goal = anchor + Vector3(cos(_orbit_a) * 7.0, -1.5 + sin(_t * 0.9) * 1.5, sin(_orbit_a * 1.3) * 7.0)
			if _roam_done():
				_mode = "home"
		"home":
			goal = _perch_point()
			if global_position.distance_to(goal) < 0.5:
				velocity = Vector3.ZERO
				_set_state(S.PERCH)
				return
	var to := goal - global_position
	var want := to.normalized() * minf(speed, to.length() * 2.0 + 1.0)
	velocity = velocity.move_toward(want, 9.0 * delta)
	if _mode != "hunt" and flat(velocity).length() > 0.3:
		_face(flat(velocity))


## Roaming ends (dawn, for bats).
func _roam_done() -> bool:
	return true


func _cry() -> void:
	pass


func _fly(delta: float) -> void:
	_ray_t -= delta
	if _ray_t <= 0.0:
		_ray_t = 0.3
		var from := global_position + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 30.0, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		_ground_y = (hit["position"] as Vector3).y if not hit.is_empty() else -INF
	var next := global_position + velocity * delta
	if state != S.PERCH and next.y < _ground_y + 0.7:
		next.y = _ground_y + 0.7
		velocity.y = maxf(velocity.y, 0.0)
	global_position = next


func _walk(delta: float) -> void:
	if flying:
		# (hit in the air: it reels, but stays up)
		velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
		global_position += velocity * delta
		return
	super._walk(delta)


func _after_stun() -> void:
	_set_state(S.FLY)
	_mode = "hunt"


func _after_daze() -> void:
	take_off("hunt")


func _knocked() -> void:
	flying = false


func _got_up() -> void:
	flying = true
	velocity = Vector3.UP * 4.0
	_mode = "hunt"
	_set_state(S.FLY)
	Net.fx("sfx", ["flap", global_position, -6.0, 0.1, 1.0])


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	if state == S.PERCH:
		flying = true
	_mode = "hunt"
	return false


## The wing beat for the pose: fast in the air, still when perched or down.
func _wing_phase(delta: float, rate: float) -> float:
	if state in [S.FLY, S.TELL, S.ATTACK, S.HITSTUN] or (state == S.RECOVER and flying):
		_flap += delta * rate * (1.6 if state == S.TELL else (0.4 if state == S.ATTACK else 1.0))
	return _flap
