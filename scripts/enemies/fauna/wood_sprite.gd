class_name WoodSprite
extends Creature
## Wood sprites: little spirits of twig and leaf, eyes like embers. By day they lie under the leaf
## litter, a mound you might step on (do, and one bursts out at you). At night they're up and about
## in twos and threes, skittering; one that sees you crouches with a chitter, eyes flaring (the tell),
## and pounces, raking with its claws, then skips back out of reach and comes again. Morphs: maple red,
## oak gold, a pale ghostly one.

const RUN := 6.5
const POUNCE := 10.0
const NOTICE_DAY := 2.8
const NOTICE_NIGHT := 13.0
const BODY_Y := 0.62

var morph: int = 0
var _provoked: float = 0.0
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _mound: Node3D
var _arms: Array = []
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "sprite"
	morph = int(args.get("morph", 0))
	hostile = true
	size_k = 1.35
	max_hp = 45.0
	xp = 28
	coins = Vector2i(0, 2)
	drops = [["plume", 0.15, 1]]


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.22, 0.9, Vector3(0.5, 1.0, 0.5)]


func _moves() -> Array:
	return [[11.0, 4.0, Vector3(0.8, 0.8, 0.9), Vector3(0, 0.6, -0.6), false, 0.3],
		[7.0, 2.5, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.6, -0.5), false, 0.2]]


func _build() -> void:
	var leaf_cols := [[Color(0.78, 0.2, 0.1), Color(0.95, 0.45, 0.15)], [Color(0.85, 0.6, 0.15), Color(0.95, 0.8, 0.3)], [Color(0.75, 0.8, 0.7), Color(0.92, 0.95, 0.9)]]
	var lc: Array = leaf_cols[morph % 3]
	var twig := Color(0.32, 0.22, 0.14) if morph % 3 != 2 else Color(0.62, 0.62, 0.58)
	var skin := _skin()
	var eye := _glow(Color(1.0, 0.62, 0.2) if morph % 3 != 2 else Color(0.6, 0.95, 1.0))
	var v := "m%d" % (morph % 3)
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_tube(skin, PackedVector3Array([Vector3(0, -0.15, 0.03), Vector3(0, 0.08, 0.0), Vector3(0, 0.3, -0.05)]), 0.07, 0.05, 5, 1.0, twig)
		for k in range(5):
			var a := rng.randf() * TAU
			mb.add_tube(skin, PackedVector3Array([Vector3(0, 0.05 * k, 0), Vector3(cos(a) * 0.12, 0.05 * k + 0.08, sin(a) * 0.12)]), 0.02, 0.008, 3, 1.0, twig)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0.02)), Vector3(0.12, 0.14, 0.09), rng, 0.35, 3, 6, 1.0, lc[0]))
	_head = _part(_body, "Head", Vector3(0, 0.38, -0.06), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.13, 0.12, 0.12), rng, 0.25, 3, 7, 1.0, twig.lerp(lc[0], 0.3))
		# a crown of leaves and two twig horns
		for k in range(7):
			var a := TAU * k / 7.0
			mb.add_blob(skin, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.12, 0.1, sin(a) * 0.12 + 0.02)), Vector3(0.09, 0.03, 0.06), rng, 0.3, 2, 5, 1.0, lc[k % 2])
		for s in [-1.0, 1.0]:
			mb.add_tube(skin, MeshBuilder.curve_points(Vector3(s * 0.06, 0.08, 0.0), Vector3(s * 0.16, 0.2, 0.05), Vector3(s * 0.12, 0.34, 0.12), 4), 0.02, 0.006, 3, 1.0, twig)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.01, -0.11)), Vector3(0.04, 0.025, 0.02), 1.0)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.11)), Vector3(0.07, 0.015, 0.02), 1.0, Color(0.05, 0.03, 0.02)))
	for s in [-1.0, 1.0]:
		var arm := _part(_body, "Arm", Vector3(s * 0.1, 0.27, -0.02), v + ("_arm_l" if s < 0.0 else "_arm_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_tube(skin, PackedVector3Array([Vector3.ZERO, Vector3(s * 0.08, -0.2, -0.04), Vector3(s * 0.1, -0.42, -0.1)]), 0.025, 0.015, 4, 1.0, twig)
			for f in range(3):
				var o := Vector3(s * 0.1 + (f - 1) * 0.02, -0.42, -0.1)
				mb.add_tube(skin, PackedVector3Array([o, o + Vector3((f - 1) * 0.03, -0.1, -0.06)]), 0.01, 0.003, 3, 1.0, twig.darkened(0.3)))
		_arms.append([arm, s])
		var leg := _part(_body, "Leg", Vector3(s * 0.05, -0.14, 0.02), v + "_leg", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_tube(skin, PackedVector3Array([Vector3.ZERO, Vector3(0, -0.25, -0.05), Vector3(0, -0.48, 0.02)]), 0.025, 0.018, 4, 1.0, twig))
		_legs.append([leg, s])
	_mound = _part(model, "Mound", Vector3.ZERO, v + "_mound", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var tex := PSXMat.lit("leaves_maple", Color.WHITE, {"affine": 0.5})
		mb.add_blob(tex, Transform3D.IDENTITY, Vector3(0.6, 0.22, 0.5), rng, 0.25, 2, 6, 0.6, Color.WHITE, 0.0)
		mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(0.08, 0.17, -0.38)), Vector3(0.03, 0.02, 0.02), 1.0))


func _start() -> void:
	_set_state(S.HIDE if _night() < 0.4 else S.WANDER)


func provoke() -> void:
	_provoked = 10.0
	if state in [S.HIDE, S.IDLE, S.WANDER]:
		_set_state(S.NOTICE)


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var night := _night() > 0.4
	match state:
		S.HIDE:
			if _player_ok(p) and dist < NOTICE_DAY:
				Net.fx("dust", [global_position, 6, 0.6])
				provoke()
			elif night and _rng.randf() < 0.02:
				Net.fx("dust", [global_position, 4, 0.5])
				_set_state(S.WANDER)
		S.IDLE, S.WANDER:
			_wander(1.8, Vector2(1.5, 7.0))
			if not night and st_t > 6.0 and _provoked <= 0.0:
				_set_state(S.HIDE)
			elif _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE_NIGHT if night else NOTICE_DAY * 2.0):
				provoke()
		S.NOTICE:
			_face(to_p)
			if st_t < 0.05:
				Net.fx("sfx", ["chitter", global_position, -3.0, 0.15, 1.6])
			if st_t > 0.5:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 22.0 or flat(global_position - home).length() > 30.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			if dist > 4.2:
				_want = to_p.normalized() * RUN
			elif _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["chitter", global_position, -1.0, 0.1, 2.0])
			else:
				# skip about at a pounce's length, side to side
				_want = to_p.normalized().cross(Vector3.UP) * RUN * 0.5 * (1.0 if int(_t) % 2 == 0 else -1.0)
		S.TELL:
			_face(to_p)
			_turn = 10.0
			if st_t >= 0.45:
				_set_state(S.ATTACK)
				_strike(0 if dist > 1.8 else 1)
				velocity = _fwd() * POUNCE + Vector3.UP * 3.5
		S.ATTACK:
			_want = _fwd() * (POUNCE if st_t < 0.25 else 0.0)
			_accel = 30.0
			_turn = 1.0
			if st_t > 0.5:
				_cool = _rng.randf_range(0.9, 1.8)
				_set_state(S.FLEE)
		S.FLEE:
			# a few skips back out of reach, then in again
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_face(-away)
			_want = away * RUN * 0.8
			if st_t > 0.8:
				_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	provoke()
	return false


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _cry_death() -> void:
	Net.fx("sfx", ["chitter", global_position, -2.0, 0.1, 0.9])
	Net.fx("sparkle", [global_position + Vector3.UP * 0.7, 6, Color(1.0, 0.6, 0.25)])


func _pose(delta: float) -> void:
	var hidden := state == S.HIDE
	_body.visible = not hidden
	_mound.visible = hidden
	if hidden:
		return
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	_gait += hs * 4.0 * delta
	var crouch := 1.0 if state == S.TELL else 0.0
	_body.position.y = BODY_Y - crouch * 0.18 + absf(sin(_gait)) * 0.05 * moving
	_body.rotation = Vector3(-0.35 * moving - crouch * 0.4 + (0.5 if state == S.ATTACK else 0.0), 0, sin(_t * 6.0) * 0.06)
	_head.rotation = Vector3(crouch * 0.4, sin(_t * 2.3) * 0.3 * (1.0 - moving), sin(_t * 1.7) * 0.15)
	for a in _arms:
		var s: float = a[1]
		var reach := -1.6 if state == S.ATTACK else (0.6 if state == S.TELL else 0.0)
		(a[0] as Node3D).rotation = Vector3(reach + sin(_gait + (0.0 if s < 0.0 else PI)) * 0.5 * moving, 0, -s * (0.5 + crouch * 0.4))
	for l in _legs:
		var ph := _gait + (0.0 if float(l[1]) < 0.0 else PI)
		var swing := sin(ph) * 0.8 * moving
		if state in [S.DOWN, S.DEAD]:
			swing = sin(_t * 15.0) * 0.4 * (1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t))
		(l[0] as Node3D).rotation = Vector3(swing + crouch * 0.6, 0, 0)
