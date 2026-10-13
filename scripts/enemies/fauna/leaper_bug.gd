class_name LeaperBug
extends Creature
## Stalker mantis: a hunter of the jungle floor, as tall as your waist. It
## stalks you low and slow, then CROUCHES (the tell: wings flare, a hiss, the
## scythes come up) and LEAPS in an arc onto where you're going. Dodge the
## landing and it's left sprawled and open. Up close it slashes twice with its
## scythes. Morphs by island: green, orchid, dead-leaf.

const NOTICE := 11.0
const GIVE_UP := 22.0
const LEAP_MIN := 3.5
const LEAP_MAX := 8.5
const LEAP_T := 0.6
const COLORS := [
	[Color(0.3, 0.58, 0.2), Color(0.17, 0.36, 0.12), Color(0.62, 0.8, 0.42), Color(0.95, 0.9, 0.3)],
	[Color(0.92, 0.72, 0.82), Color(0.75, 0.42, 0.6), Color(0.98, 0.9, 0.95), Color(0.95, 0.3, 0.45)],
	[Color(0.45, 0.32, 0.18), Color(0.28, 0.18, 0.1), Color(0.6, 0.46, 0.28), Color(0.95, 0.65, 0.2)],
]

var morph: int = 0
var _gait: float = 0.0
var _fx_t: float = 0.0
var _slash: int = 0
var _landed_hit := false
var _body: Node3D
var _head: Node3D
var _arms: Array = []
var _legs: Array = []
var _wings: Array = []


func _setup(args: Dictionary) -> void:
	kind = "leaper"
	morph = int(args.get("morph", 0))
	max_hp = 55.0
	xp = 45
	coins = Vector2i(1, 3)
	drops = [["chitin_shard", 0.45, 1]]
	skin_tex = "leaves"


func _body_shape() -> Array:
	return [0.25, 0.9, Vector3(0.6, 1.1, 1.0)]


func _moves() -> Array:
	return [[14.0, 5.5, Vector3(0.9, 1.0, 1.0), Vector3(0, 0.5, -0.4), false, 0.35],
		[9.0, 3.5, Vector3(1.0, 0.9, 0.9), Vector3(0, 0.7, -0.75), false, 0.25]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var main: Color = c[0]
	var dark: Color = c[1]
	var pale: Color = c[2]
	var skin := _skin()
	var eye := _glow(c[3])
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3(0, 0.42, 0.05), m + "body", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		# the abdomen: a long tapering loft back, banded
		var xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.15), Vector3(0, 0.0, 0.0))
		mb.add_loft(skin, xf, [[0.0, 0.07, 0.07], [0.15, 0.11, 0.1, 0.0], [0.38, 0.12, 0.1, 0.01], [0.6, 0.08, 0.07, 0.02], [0.72, 0.03, 0.03, 0.02]],
			MeshBuilder.profile_circle(7), 2.0, main, true, true)
		for k in range(4):
			var z := 0.18 + k * 0.12
			mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.09 + z * 0.15, z)), Vector3(0.2, 0.02, 0.025), 1.0, dark, false, false)
		# the long neck (prothorax), reared up
		mb.add_tube(skin, MeshBuilder.curve_points(Vector3(0, 0.02, -0.02), Vector3(0, 0.15, -0.08), Vector3(0, 0.36, -0.16), 4), 0.05, 0.035, 5, 1.0, main, false, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.0)), Vector3(0.08, 0.07, 0.1), _rng, 0.05, 3, 6, 1.0, dark), true)
	_head = _part(_body, "Head", Vector3(0, 0.38, -0.17), m + "head", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var tri := PackedVector2Array([Vector2(-0.11, 0.05), Vector2(0.11, 0.05), Vector2(0.03, -0.1), Vector2(-0.03, -0.1)])
		mb.add_extrude(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.02)), tri, 0.07, 2.0, main)
		for s in [-1.0, 1.0]:
			mb.add_blob(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.1, 0.05, -0.03)), Vector3(0.04, 0.045, 0.04), _rng, 0.0, 2, 5)
			mb.add_tube(skin, MeshBuilder.curve_points(Vector3(s * 0.04, 0.07, -0.04), Vector3(s * 0.08, 0.2, -0.1), Vector3(s * 0.16, 0.24, -0.22), 4), 0.008, 0.004, 3, 1.0, dark)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, -0.03)), Vector3(0.05, 0.03, 0.04), 1.0, dark, false, false))
	for s in [-1.0, 1.0]:
		# the scythes: a spiny femur forward and the tibia folded back up under it
		var arm := _part(_body, "Arm", Vector3(s * 0.06, 0.26, -0.12), m + ("arm_l" if s < 0.0 else "arm_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.04, -0.08, -0.3), 0.05, main)
			Creature.seg(mb, skin, Vector3(s * 0.04, -0.08, -0.3), Vector3(s * 0.03, 0.08, -0.12), 0.035, main)
			for k in range(4):
				var q := Vector3(s * 0.04, -0.08, -0.3) * (0.3 + k * 0.17)
				mb.add_cone(skin, Transform3D(Basis(Vector3.RIGHT, PI), q + Vector3(0, -0.02, 0)), 0.012, 0.05, 3, 1.0, pale))
		_arms.append(arm)
		var wing := _part(_body, "Wing", Vector3(s * 0.03, 0.08, 0.02), m + ("wing_l" if s < 0.0 else "wing_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var leaf := PackedVector2Array([Vector2(0, 0), Vector2(s * 0.07, 0.15), Vector2(s * 0.06, 0.45), Vector2(s * 0.015, 0.55), Vector2(-s * 0.01, 0.3)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.12), Vector3.ZERO), leaf, 0.01, 2.0, pale))
		_wings.append([wing, s])
	for i in range(4):
		var s := -1.0 if i % 2 == 0 else 1.0
		var hind := i >= 2
		var at := Vector3(s * 0.05, -0.01, 0.12 if hind else 0.0)
		var leg := _part(_body, "Leg%d" % i, at, m + "leg%d" % i, func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var knee := Vector3(s * 0.26, 0.12, 0.12 if hind else -0.1)
			var foot := Vector3(s * 0.36, -0.42, 0.3 if hind else -0.2)
			Creature.seg(mb, skin, Vector3.ZERO, knee, 0.03, dark)
			Creature.seg(mb, skin, knee, foot, 0.022, dark))
		_legs.append([leg, s, i])


func _start() -> void:
	_set_state(S.WANDER)


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(0.8, Vector2(2.0, 7.0))
			if _player_ok(p) and dist < NOTICE and _cool <= 0.0:
				_set_state(S.NOTICE)
				Net.fx("sfx", ["chitter", global_position, -3.0, 0.1, 0.8])
		S.NOTICE:
			_face(to_p)
			_turn = 12.0
			if st_t > 0.4:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or dist > GIVE_UP or flat(global_position - home).length() > 30.0:
				_cool = 3.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			if dist < 2.2 and _cool <= 0.0:
				_slash = 0
				_set_state(S.SPECIAL)
			elif dist > LEAP_MAX:
				_want = to_p.normalized() * 2.6
			elif dist < LEAP_MIN:
				_want = -to_p.normalized() * 1.6 + to_p.normalized().cross(Vector3.UP) * 1.2 * sin(_t)
			elif _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["bug_hiss", global_position, -2.0, 0.08, 1.15])
			else:
				_want = to_p.normalized().cross(Vector3.UP) * 1.4 * signf(sin(_t * 0.7))
		S.TELL:
			_turn = 14.0
			if st_t < 0.4:
				_face(to_p + (flat((p as CharacterBody3D).velocity) * 0.35 if p is CharacterBody3D else Vector3.ZERO))
			if st_t >= 0.55:
				var aim := flat(p.global_position - global_position) if p else _fwd() * 5.0
				if p is CharacterBody3D:
					aim += flat((p as CharacterBody3D).velocity) * 0.3
				var d := clampf(aim.length(), 2.0, LEAP_MAX + 1.0)
				_face(aim)
				velocity = aim.normalized() * (d / LEAP_T) + Vector3.UP * GRAVITY * LEAP_T * 0.5
				_landed_hit = false
				_set_state(S.ATTACK)
				_strike(0)
				Net.fx("sfx", ["whoosh", global_position, -4.0, 0.08, 1.3])
				Net.fx("dust", [global_position, 4, 0.4])
		S.ATTACK:
			_want = flat(velocity)
			_accel = 0.0
			_turn = 4.0
			if not hitbox.hit_targets.is_empty():
				_landed_hit = true
			if st_t > 0.15 and is_on_floor():
				hitbox.deactivate()
				Net.fx("dust_ring", [global_position, 8, 0.5])
				Net.fx("sfx", ["thud", global_position, -6.0, 0.08, 1.4])
				velocity = Vector3.ZERO
				_daze_len = 0.45 if _landed_hit else 1.2
				_cool = 1.6
				_set_state(S.RECOVER)
		S.SPECIAL:
			_face(to_p)
			_turn = 10.0
			var hit_at := 0.32 + _slash * 0.3
			if st_t >= hit_at and _slash < 2:
				_slash += 1
				_strike(1)
				_want = _fwd() * 3.0
				Net.fx("sfx", ["whoosh", global_position, -5.0, 0.1, 1.5])
			elif hitbox.active and st_t > hit_at - 0.3 + 0.12:
				hitbox.deactivate()
			if st_t > 1.05:
				hitbox.deactivate()
				_cool = 1.3
				_set_state(S.CHASE)


func _walk(delta: float) -> void:
	# (in the air the leap keeps its own course)
	if state == S.ATTACK:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	super._walk(delta)


func _cry_death() -> void:
	Net.fx("sfx", ["chitter", global_position, 0.0, 0.05, 0.7])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD, S.ATTACK] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 9.0 * delta
	var crouch := 0.0
	var arms_up := 0.0
	var wing := 0.0
	var head_pitch := 0.0
	match state:
		S.WANDER, S.IDLE:
			head_pitch = sin(_t * 1.3) * 0.15
			arms_up = 0.1 + sin(_t * 2.0) * 0.05
		S.NOTICE, S.CHASE:
			crouch = 0.15
			arms_up = 0.25
		S.TELL:
			crouch = minf(st_t / 0.3, 1.0) * 0.55
			arms_up = 0.9
			wing = minf(st_t / 0.25, 1.0)
		S.ATTACK:
			arms_up = 1.3
			wing = 0.6
			crouch = -0.2
		S.SPECIAL:
			var ph := fmod(st_t, 0.3) / 0.3
			arms_up = 1.2 - ph * 1.8 if st_t > 0.02 else 0.8
		S.RECOVER:
			crouch = 0.35
			head_pitch = 0.35 + sin(_t * 5.0) * 0.1
			arms_up = -0.2
		S.DOWN, S.DEAD:
			arms_up = sin(_t * 12.0) * 0.4 if state == S.DOWN else 0.0
	_body.position.y = 0.42 - crouch * 0.18
	_body.rotation.x = -crouch * 0.25 + (sin(_t * 3.0) * 0.04 if state == S.WANDER else 0.0)
	_head.rotation = Vector3(-head_pitch, sin(_t * 0.9) * 0.2, 0)
	for a in _arms:
		(a as Node3D).rotation = Vector3(arms_up, 0, 0)
	for w in _wings:
		(w[0] as Node3D).rotation = Vector3(-wing * 0.5, 0, float(w[1]) * wing * 1.1)
	for l in _legs:
		var ph := _gait + (PI if (int(l[2]) + (0 if float(l[1]) < 0.0 else 1)) % 2 == 1 else 0.0)
		var sw := sin(ph) * 0.4 * moving
		if state in [S.DOWN, S.DEAD]:
			sw = sin(_t * 18.0 + int(l[2])) * 0.5 * (1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t))
		(l[0] as Node3D).rotation = Vector3(0, sw * float(l[1]), crouch * 0.4 * float(l[1]))
