extends Creature
## A shark that patrols its water (a wreck, a reef) and goes for anyone swimming in it. Never a surprise:
## it noticed you when its fin rises out of the water with a sting of music, then it circles you, closing in,
## for a few seconds (time to make for a ladder or the beach); then it turns square on, a lane on the water
## shows its line for TELL s, and it charges along that line and bites. It swims on past and away before it
## comes round again. Out of the water you're safe; hit it hard and it breaks off. Captains on deck or
## ashore can shoot or cut at it like any creature. The host runs it (Creature's co-op); far from every captain
## SeaThreats puts it to sleep (Creature.set_lod, as FaunaSpawner does the island's wildlife).

const CRUISE := 3.0
const STALK := 4.4
const CHARGE := 10.5
const CHARGE_TIME := 0.7
const TELL := 0.85
## Notices a swimmer this close, and keeps to this far from home.
const NOTICE := 22.0
const LEASH := 48.0
## Circles at STALK_R.x, closing to STALK_R.y; the first time for STALK_FIRST s, after a bite for STALK_AGAIN.
const STALK_R := Vector2(10.0, 5.5)
const STALK_FIRST := 4.5
const STALK_AGAIN := 2.6
## Swims off after a charge for this long before coming round again.
const AWAY := 3.5
## Patrol depth (the body's middle under the surface), and the depth that puts the dorsal fin out.
const DEEP := 2.8
const FIN := 0.5
const PATROL_R := 13.0

var _circle_a := 0.0
var _stalk_len := STALK_FIRST
var _charge_dir := Vector3.ZERO
var _depth := DEEP
var _floor_y := -INF
var _floor_t := 0.0
var _wake_t := 0.0
var _broke_off := false
var _body: Node3D
var _tail: Node3D
var _jaw: Node3D


func _setup(args: Dictionary) -> void:
	kind = "shark"
	size_k = float(args.get("size", 1.0))
	max_hp = 150.0
	xp = 90
	coins = Vector2i(0, 0)
	drops = [["fish", 0.9, 2]]
	flying = true
	skin_tex = "leather"


func _start() -> void:
	_circle_a = _rng.randf() * TAU
	_set_state(S.WANDER)


func in_combat() -> bool:
	return state in [S.NOTICE, S.TELL, S.ATTACK, S.RECOVER, S.HITSTUN]


func _body_shape() -> Array:
	return [0.5, 1.0, Vector3(1.0, 1.0, 3.0)]


func _moves() -> Array:
	return [[16.0, 6.0, Vector3(1.3, 1.3, 1.4), Vector3(0, 0.5, -1.8), false, 0.45]]


func _can_knock() -> bool:
	return false


## Fair game: alive, in the water, not on a ladder or a deck.
func _player_ok(p: Node3D) -> bool:
	if not super(p):
		return false
	return p.has_method("current_state_name") and str(p.call("current_state_name")) == "Swim"


func _build() -> void:
	var top := Color(0.36, 0.42, 0.48)
	var belly := Color(0.86, 0.86, 0.82)
	var skin := _skin()
	var eye := _glow(Color(0.05, 0.05, 0.06))
	_body = _part(model, "Body", Vector3(0, 0.5, 0), "body", func(mb: MeshBuilder, _rng2: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		# (the loft runs along +y, turned to -z: the snout's the last ring)
		var rings := [[-1.2, 0.1, 0.08, 0.02], [-0.9, 0.2, 0.16, 0.02], [-0.4, 0.34, 0.28, 0.02], [0.2, 0.42, 0.36, 0.02],
			[0.8, 0.36, 0.3, 0.0], [1.25, 0.22, 0.17, -0.02], [1.5, 0.04, 0.03, 0.0]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(10), 1.2, top, true, true)
		# the pale belly under it
		var brings := [[-0.9, 0.14, 0.05, -0.1], [-0.4, 0.28, 0.1, -0.18], [0.2, 0.35, 0.14, -0.22], [0.8, 0.3, 0.12, -0.18], [1.3, 0.16, 0.08, -0.08]]
		mb.add_loft(skin, xf, brings, MeshBuilder.profile_circle(8), 1.2, belly, true, true)
		# the dorsal fin (the one you see cutting the water), pectorals, a small second dorsal
		# (outlines in x/y turned so +x runs back along the body: the fins rake backward)
		mb.add_extrude(skin, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.3, -0.15)), PackedVector2Array([Vector2(-0.45, 0), Vector2(0.25, 0), Vector2(0.5, 0.75)]), 0.06, 1.0, top.darkened(0.15))
		mb.add_extrude(skin, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.22, 0.75)), PackedVector2Array([Vector2(-0.12, 0), Vector2(0.08, 0), Vector2(0.16, 0.2)]), 0.04, 1.0, top.darkened(0.15))
		for s in [-1.0, 1.0]:
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.35) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.3, -0.18, -0.55)), PackedVector2Array([Vector2(0, -0.2), Vector2(0, 0.15), Vector2(s * 0.75, 0.35)]), 0.04, 1.0, top)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.2, 0.06, -1.1)), Vector3(0.05, 0.05, 0.05), 1.0, Color.WHITE, false, false)
			# gill slits
			for k in range(3):
				mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.35, -0.02, -0.8 + k * 0.08)), Vector3(0.02, 0.18, 0.015), 1.0, top.darkened(0.45), false, false))
	# the lower jaw, hinged under the head behind the snout (drops open on the tell and the bite)
	_jaw = _part(_body, "Jaw", Vector3(0, -0.2, -0.7), "jaw", func(mb: MeshBuilder, _rng2: RandomNumberGenerator):
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.2)), Vector3(0.3, 0.07, 0.4), 1.0, belly, false, false)
		for k in range(7):
			var x := -0.12 + k * 0.04
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(x, 0.04, -0.34 + absf(x) * 0.6)), Vector3(0.02, 0.06, 0.02), 1.0, Color(0.97, 0.96, 0.9), false, false))
	_tail = _part(_body, "Tail", Vector3(0, 0.0, 1.15), "tail", func(mb: MeshBuilder, _rng2: RandomNumberGenerator):
		mb.add_extrude(skin, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, 0.0)), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.55, 0.75), Vector2(0.35, 0.05), Vector2(0.45, -0.45)]), 0.05, 1.0, top.darkened(0.1)))


# ==========================================================================
# Thinking
# ==========================================================================
func _tick(delta: float) -> void:
	flying = true
	anim_a = move_toward(anim_a, 1.0 if state in [S.TELL, S.ATTACK] else 0.0, delta * 5.0)
	var want_depth := FIN if state in [S.NOTICE, S.TELL, S.ATTACK] else DEEP
	_depth = move_toward(_depth, want_depth, delta * 1.5)
	_floor_t -= delta
	if _floor_t <= 0.0:
		_floor_t = 0.5
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position + Vector3.DOWN * 30.0, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		_floor_y = (hit["position"] as Vector3).y if not hit.is_empty() else -INF
	# a fin cutting the water leaves a wake
	if _depth < FIN + 0.3 and flat(velocity).length() > 1.5:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = 0.22
			var at := global_position + _fwd() * 0.2 * size_k
			at.y = float(Ocean.surface_at(at))
			Net.fx("splash", [at, 2, 0.45])


func _brain(_delta: float) -> void:
	var p := _target()
	var ok := _player_ok(p) and flat(p.global_position - home).length() < LEASH
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_patrol()
			if ok and dist < NOTICE:
				_stalk_len = STALK_FIRST
				_circle_a = atan2(global_position.z - p.global_position.z, global_position.x - p.global_position.x)
				_set_state(S.NOTICE)
				# the tell that it's coming: a sting, and the fin rises
				Net.fx("sfx", ["fin_sting", global_position, 0.0, 0.0])
				Net.fx("splash", [Vector3(global_position.x, float(Ocean.surface_at(global_position)), global_position.z), 6, 0.6])
		S.NOTICE:
			if not ok:
				_give_up()
				return
			var k := clampf(st_t / _stalk_len, 0.0, 1.0)
			var r := lerpf(STALK_R.x, STALK_R.y, k)
			_circle_a += STALK / r * get_physics_process_delta_time()
			var spot := p.global_position + Vector3(cos(_circle_a), 0.0, sin(_circle_a)) * r
			var d := flat(spot - global_position)
			_face(d)
			_want = d.normalized() * minf(STALK * 1.3, d.length() * 3.0)
			if st_t > _stalk_len and dist < STALK_R.x:
				_set_state(S.TELL)
				var from := global_position
				from.y = float(Ocean.surface_at(from)) + 0.25
				var to := from + to_p.normalized() * (CHARGE * CHARGE_TIME + 1.5)
				Net.fx("lane", [from, to, 1.6, TELL, Color(1.0, 0.3, 0.2)])
				Net.fx("sfx", ["splash_big", global_position, -6.0, 0.1, 0.7])
		S.TELL:
			_face(to_p)
			_turn = 10.0
			_want = Vector3.ZERO
			_accel = 8.0
			if st_t >= TELL:
				_charge_dir = _fwd()
				_set_state(S.ATTACK)
				_strike(0)
				Net.fx("sfx", ["whoosh_big", global_position, -2.0, 0.08, 0.6])
		S.ATTACK:
			_want = _charge_dir * CHARGE
			_accel = 60.0
			if st_t > CHARGE_TIME:
				_set_state(S.FLEE)
				_cool = AWAY
		S.FLEE:
			_want = _charge_dir * CRUISE * 1.4
			_turn = 2.5
			_face(_charge_dir)
			if st_t > AWAY:
				if ok:
					_stalk_len = STALK_AGAIN
					_set_state(S.NOTICE)
				else:
					_give_up()


func _patrol() -> void:
	_circle_a += CRUISE / PATROL_R * get_physics_process_delta_time()
	var spot := home + Vector3(cos(_circle_a), 0.0, sin(_circle_a)) * PATROL_R
	var d := flat(spot - global_position)
	_face(d)
	_want = d.normalized() * CRUISE


func _give_up() -> void:
	_broke_off = false
	_set_state(S.WANDER)


## Hurt badly enough, it breaks off and keeps away a while.
func _hurt(_hit: HitData, _attacker: Node, dir: Vector3) -> bool:
	if not _broke_off and health.current_health < health.max_health * 0.5:
		_broke_off = true
		_charge_dir = dir
		_set_state(S.FLEE)
		return true
	return false


func _after_stun() -> void:
	_charge_dir = -_fwd()
	_set_state(S.FLEE)


## It swims: no gravity, held at its depth under the waves, above the seabed.
func _fly(delta: float) -> void:
	var hv := flat(velocity).move_toward(_want, _accel * delta)
	var target_y := float(Ocean.surface_at(global_position)) - _depth * size_k
	if state == S.ATTACK:
		var p := _target()
		if p:
			target_y = minf(target_y, p.global_position.y + 0.5)
	target_y = maxf(target_y, _floor_y + 0.6 * size_k)
	velocity = Vector3(hv.x, clampf((target_y - global_position.y) * 2.5, -3.5, 3.5), hv.z)
	move_and_slide()


func _cry_death() -> void:
	Net.fx("splash", [global_position, 10, 1.0])


## Dead, it rolls belly-up and drifts up to the surface, then sinks away.
func _dead_update(delta: float) -> void:
	_dead_t += delta
	_roll = move_toward(_roll, PI, 2.0 * delta)
	if _dead_t < 5.0:
		var target_y := float(Ocean.surface_at(global_position)) - 0.35
		global_position.y = move_toward(global_position.y, target_y, 1.2 * delta)
		return
	global_position.y -= 0.8 * delta
	if _dead_t > 8.0:
		queue_free()


# ==========================================================================
# Pose
# ==========================================================================
func _pose(_delta: float) -> void:
	var spd := flat(velocity).length()
	var beat := sin(_t * (3.0 + spd * 0.9)) * (0.25 + clampf(spd / CHARGE, 0.0, 1.0) * 0.25)
	if state == S.DEAD:
		beat = 0.0
	_tail.rotation.y = beat
	_body.rotation.y = -beat * 0.25
	_jaw.rotation.x = anim_a * 0.6
	# leans into its turns
	model.rotation.x = clampf(velocity.y * -0.12, -0.35, 0.35)
