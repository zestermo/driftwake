class_name Treantling
extends Creature
## Treantlings: young treants, stumps that walk. Standing still they're a mossy stump with a
## couple of leafy branches; come close (closer by day, from further at night) and the face in
## the bark opens its ember eyes and it heaves up on its roots. Slow and tough - its bark turns
## blows from the front, so get round it - it raises its branch-arms (the tell) and brings them
## down in a slam that knocks you flat, or sweeps one wide. Morphs: oak, birch, a burnt black one.

const WALK := 2.4
const NOTICE_DAY := 4.0
const NOTICE_NIGHT := 11.0

var morph: int = 0
var _provoked: float = 0.0
var _sweep := false
var _gait: float = 0.0
var _trunk: Node3D
var _eyes: Node3D
var _arms: Array = []
var _roots: Array = []


func _setup(args: Dictionary) -> void:
	kind = "treant"
	morph = int(args.get("morph", 0))
	hostile = true
	size_k = 1.15 if bool(args.get("lead", false)) else 1.0
	max_hp = 120.0
	xp = 55
	coins = Vector2i(1, 3)
	drops = [["plume", 0.1, 1]]
	skin_tex = "bark"


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.45, 1.6, Vector3(0.9, 1.7, 0.9)]


func _moves() -> Array:
	return [[22.0, 8.0, Vector3(1.4, 1.2, 1.6), Vector3(0, 0.6, -1.2), true, 0.5],
		[15.0, 6.0, Vector3(2.6, 1.0, 1.4), Vector3(0, 0.9, -0.8), false, 0.4]]


func _build() -> void:
	var barks := [[Color(0.75, 0.62, 0.5), "leaves_oak"], [Color(1.25, 1.2, 1.15), "leaves_birch"], [Color(0.32, 0.28, 0.26), "leaves_maple"]]
	var b: Array = barks[morph % 3]
	var bc: Color = b[0]
	var skin := _skin()
	var leaf := PSXMat.lit(str(b[1]), Color.WHITE, {"affine": 0.5})
	var moss := PSXMat.lit("leaves_late", Color(0.7, 0.85, 0.55), {"affine": 0.5})
	var eye := _glow(Color(1.0, 0.6, 0.18))
	var v := "m%d" % (morph % 3)
	_trunk = _part(model, "Trunk", Vector3(0, 0.55, 0), v + "_trunk", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), 0.42, 0.34, 1.25, 8, 0.8, bc, false)
		mb.add_cylinder(PSXMat.flat(Color(0.62, 0.48, 0.32)), Transform3D(Basis.IDENTITY, Vector3(0, 1.15, 0)), 0.34, 0.34, 0.03, 8, 1.0)
		for k in range(4):
			var a := TAU * k / 4.0 + 0.4
			mb.add_cone(skin, Transform3D(Basis.IDENTITY, Vector3(cos(a), 0, sin(a)) * 0.2 + Vector3.UP * 1.15), 0.14, rng.randf_range(0.2, 0.45), 4, 0.8, bc)
		# the face: a dark hollow mouth, a brow ridge
		mb.add_box(PSXMat.flat(Color(0.06, 0.04, 0.03)), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -0.37)), Vector3(0.26, 0.1, 0.06), 1.0)
		mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 0.82, -0.38)), Vector3(0.42, 0.06, 0.1), 1.0, bc.darkened(0.2))
		mb.add_blob(moss, Transform3D(Basis.IDENTITY, Vector3(0.25, 0.9, 0.2)), Vector3(0.22, 0.3, 0.25), rng, 0.2, 2, 5, 0.6)
		mb.add_blob(leaf, Transform3D(Basis.IDENTITY, Vector3(-0.1, 1.45, 0.05)), Vector3(0.45, 0.32, 0.42), rng, 0.25, 3, 6, 0.6))
	_eyes = _part(_trunk, "Eyes", Vector3(0, 0.66, -0.37), v + "_eyes", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.11, 0, 0)), Vector3(0.08, 0.05, 0.04), 1.0))
	for s in [-1.0, 1.0]:
		var arm := _part(_trunk, "Arm", Vector3(s * 0.36, 0.95, 0), v + ("_arm_l" if s < 0.0 else "_arm_r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			var pts := MeshBuilder.curve_points(Vector3.ZERO, Vector3(s * 0.45, 0.25, -0.1), Vector3(s * 0.7, -0.35, -0.35), 5)
			mb.add_tube(skin, pts, 0.12, 0.05, 5, 0.8, bc)
			for t in [2, 4]:
				mb.add_tube(skin, PackedVector3Array([pts[t], pts[t] + Vector3(s * 0.15, 0.25, -0.1)]), 0.05, 0.015, 4, 0.8, bc)
				mb.add_blob(leaf, Transform3D(Basis.IDENTITY, pts[t] + Vector3(s * 0.18, 0.32, -0.12)), Vector3(0.22, 0.16, 0.2), rng, 0.25, 2, 5, 0.6)
			for f in range(3):
				mb.add_tube(skin, PackedVector3Array([pts[5], pts[5] + Vector3(s * 0.05 * (f - 1), -0.22, -0.12 + 0.06 * f)]), 0.035, 0.01, 3, 0.8, bc.darkened(0.15)))
		_arms.append([arm, s])
	for k in range(4):
		var a := TAU * k / 4.0 + PI / 4.0
		var root := _part(model, "Root%d" % k, Vector3(cos(a) * 0.28, 0.55, sin(a) * 0.28), v + "_root", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_tube(skin, PackedVector3Array([Vector3.ZERO, Vector3(0.25, -0.25, 0), Vector3(0.45, -0.58, 0)]), 0.11, 0.04, 5, 0.8, bc))
		root.rotation.y = -a
		_roots.append([root, k])


func provoke() -> void:
	_provoked = 12.0
	if state in [S.IDLE, S.WANDER, S.HIDE]:
		_set_state(S.NOTICE)


func _start() -> void:
	_set_state(S.HIDE)


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	anim_a = move_toward(anim_a, 0.0 if state == S.HIDE else 1.0, delta * 1.5)


func _armor(_hit: HitData, dir: Vector3) -> float:
	# (its bark turns a blow from the front: `dir` points from the attacker to it)
	return 0.45 if dir.dot(_fwd()) < -0.4 and state not in [S.DOWN, S.HIDE] else 1.0


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var notice := NOTICE_NIGHT if _night() > 0.4 else NOTICE_DAY
	match state:
		S.HIDE, S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), notice):
				provoke()
		S.NOTICE:
			_face(to_p)
			_turn = 2.0
			if st_t < 0.05:
				Net.fx("sfx", ["wood_crack", global_position, -3.0, 0.15, 0.7])
				Net.fx("dust", [global_position, 8, 0.8])
			if st_t > 1.0:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 20.0 or flat(global_position - home).length() > 24.0:
				_provoked = 0.0
				_set_state(S.WANDER)
				_wander_to = home
				return
			_face(to_p)
			_turn = 2.5
			if dist > 2.0:
				_want = to_p.normalized() * WALK
			elif _cool <= 0.0:
				_sweep = _rng.randf() < 0.4
				_set_state(S.TELL)
				Net.fx("sfx", ["wood_crack", global_position, -4.0, 0.1, 0.9])
		S.TELL:
			_face(to_p)
			_turn = 3.0
			if st_t >= (0.75 if _sweep else 0.95):
				_set_state(S.ATTACK)
				_strike(1 if _sweep else 0)
				if not _sweep:
					Net.fx("dust", [global_position + _fwd() * 1.2, 10, 1.0])
					Net.fx("sfx", ["thud", global_position, 0.0, 0.1, 0.7])
		S.ATTACK:
			_turn = 0.5
			if st_t > 0.6:
				_cool = _rng.randf_range(1.6, 2.6)
				_set_state(S.CHASE)
	if state == S.WANDER and _provoked <= 0.0:
		var back := flat(home - global_position)
		if back.length() > 1.0:
			_face(back)
			_want = back.normalized() * WALK * 0.8
		else:
			_set_state(S.HIDE)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	provoke()
	return state in [S.TELL, S.ATTACK]


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _cry_death() -> void:
	Net.fx("sfx", ["wood_crack", global_position, 0.0, 0.1, 0.6])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 3.0 * delta
	var up := anim_a
	_trunk.position.y = lerpf(0.2, 0.55, up) + absf(sin(_gait)) * 0.06 * moving
	_trunk.rotation = Vector3(sin(_gait) * 0.04 * moving + (0.2 if state == S.ATTACK and not _sweep else 0.0), (0.7 if state == S.ATTACK and _sweep else 0.0), sin(_gait * 0.5) * 0.05 * moving)
	_eyes.visible = up > 0.3
	for a in _arms:
		var s: float = a[1]
		var lift := 0.0
		if state == S.TELL:
			lift = -2.2 if not _sweep else 0.0
		elif state == S.ATTACK:
			lift = 0.8 if not _sweep else 0.3
		(a[0] as Node3D).rotation = Vector3(lift * up, (s * 1.2 if state == S.TELL and _sweep else 0.0), s * 0.2 * (1.0 - up) - s * 0.15 + sin(_t * 1.3 + s) * 0.05)
	for r in _roots:
		var k: int = r[1]
		var ph := _gait + PI * k * 0.5
		(r[0] as Node3D).rotation.z = lerpf(0.5, sin(ph) * 0.35 * moving, up)
		(r[0] as Node3D).position.y = _trunk.position.y
