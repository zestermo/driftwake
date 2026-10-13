class_name Snake
extends Creature
## A snake lying coiled in the brush, hard to see among the ferns. Walk by
## within a few steps and it REARS (the tell: head up in an S, a rattling hiss)
## and STRIKES: a lunge with a venomous bite that poisons. It strikes again
## while you're close, then slithers off to coil up somewhere else. Morphs:
## green tree viper, coral-banded, brown with pale diamonds.

const AMBUSH := 3.4
const SEGS := 7
const SEG_LEN := 0.2
const COLORS := [
	[Color(0.22, 0.55, 0.15), Color(0.5, 0.75, 0.2), Color(0.85, 0.9, 0.4)],
	[Color(0.75, 0.15, 0.08), Color(0.08, 0.07, 0.06), Color(0.95, 0.85, 0.3)],
	[Color(0.36, 0.25, 0.14), Color(0.62, 0.5, 0.32), Color(0.85, 0.72, 0.45)],
]

var morph: int = 0
var _strikes: int = 0
var _hide_at := Vector3.ZERO
var _segs: Array[Node3D] = []
var _head: Node3D
var _slither: float = 0.0


func _setup(args: Dictionary) -> void:
	kind = "snake"
	morph = int(args.get("morph", 0))
	max_hp = 34.0
	xp = 30
	coins = Vector2i(0, 2)
	drops = [["snakeskin", 0.5, 1]]
	venom = [5.0, 3.0]
	skin_tex = "leather"


func _body_shape() -> Array:
	return [0.2, 0.4, Vector3(0.8, 0.6, 0.9)]


func _moves() -> Array:
	return [[8.0, 2.5, Vector3(0.6, 0.7, 0.8), Vector3(0, 0.45, -0.9), false, 0.3]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var skin := _skin()
	var m := "m%d_" % morph
	for i in range(SEGS):
		var band := i % 2
		var r := lerpf(0.065, 0.03, float(i) / SEGS)
		var pivot := _part(model, "Seg%d" % i, Vector3.ZERO, m + "seg%d" % i, func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), r, r * 0.9, SEG_LEN + 0.02, 6, 2.0, c[band], true, true)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, r * 0.85, SEG_LEN * 0.5)), Vector3(r * 0.9, 0.012, SEG_LEN * 0.4), 2.0, c[2] if morph != 1 else c[1 - band], false, false))
		_segs.append(pivot)
	_head = _part(model, "Head", Vector3.ZERO, m + "head", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.02))
		mb.add_loft(skin, xf, [[0.0, 0.055, 0.045], [0.07, 0.075, 0.045, 0.004], [0.14, 0.05, 0.03, 0.0], [0.17, 0.02, 0.015]],
			MeshBuilder.profile_circle(6), 2.0, c[0], true, true)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, -0.025, -0.07)), Vector3(0.018, 0.02, 0.02), 2.0, c[2], false, false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.058, -0.025, -0.07)), Vector3(0.006, 0.012, 0.008), 2.0, Color(0.02, 0.02, 0.02), false, false)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.005, -0.19)), Vector3(0.008, 0.004, 0.06), 2.0, Color(0.85, 0.15, 0.2), false, false), true)


func _start() -> void:
	_hide_at = home
	_set_state(S.HIDE)


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, 1.0 if state in [S.TELL, S.ATTACK, S.RECOVER, S.CHASE] else 0.0, delta * 4.0)
	anim_b = move_toward(anim_b, 1.0 if state == S.ATTACK and st_t < 0.22 else 0.0, delta * (12.0 if state == S.ATTACK else 4.0))


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.HIDE:
			if _player_ok(p) and dist < AMBUSH and _cool <= 0.0:
				_strikes = 0
				_set_state(S.TELL)
				Net.fx("sfx", ["hiss", global_position, 0.0, 0.1, 1.0])
		S.TELL:
			_face(to_p)
			_turn = 14.0
			if st_t >= (0.45 if _strikes == 0 else 0.3):
				_strikes += 1
				_set_state(S.ATTACK)
				_strike(0)
				velocity = _fwd() * 6.5
				Net.fx("sfx", ["whoosh", global_position, -6.0, 0.1, 1.7])
		S.ATTACK:
			_want = _fwd() * (6.5 if st_t < 0.2 else 0.0)
			_accel = 40.0
			if st_t > 0.3:
				_daze_len = 0.55
				_set_state(S.RECOVER)
		S.CHASE:
			# coiled up, watching you: strike again or slip away
			_face(to_p)
			if _player_ok(p) and dist < AMBUSH + 0.6 and _strikes < 3:
				_set_state(S.TELL)
				Net.fx("sfx", ["hiss", global_position, -3.0, 0.1, 1.1])
			elif st_t > 0.6:
				var a := _rng.randf() * TAU
				_hide_at = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 6.0)
				_set_state(S.FLEE)
		S.FLEE:
			var d := flat(_hide_at - global_position)
			if d.length() < 0.5 or st_t > 6.0:
				_cool = 2.5
				_set_state(S.HIDE)
				return
			_face(d)
			_want = d.normalized() * 2.6
			_turn = 5.0


func _after_daze() -> void:
	_set_state(S.CHASE)


func _after_stun() -> void:
	_strikes = maxi(_strikes - 1, 0)
	_set_state(S.TELL)


func _cry_death() -> void:
	Net.fx("sfx", ["hiss", global_position, -2.0, 0.1, 0.7])


## The spine, head first, in model space: coiled, slithering, reared, striking.
func _spine() -> Array:
	var pts: Array = []
	var coiled := state == S.HIDE
	var rear := anim_a
	var lunge := anim_b
	for i in range(SEGS + 1):
		var t := float(i)
		var p: Vector3
		if coiled:
			var a := t * 0.95 + 0.4
			var r := 0.1 + t * 0.028
			p = Vector3(cos(a) * r, 0.06 + maxf(0.0, 2.0 - t) * 0.04, sin(a) * r - 0.05)
		else:
			var wave := sin(_slither - t * 1.1) * 0.13 * clampf(t / 2.0, 0.3, 1.0)
			p = Vector3(wave, 0.06, -0.55 + t * SEG_LEN)
			# reared: the front of the body lifts into an S, the head back, cocked
			var lift := maxf(0.0, 3.0 - t) / 3.0
			p.y += lift * lift * 0.5 * rear
			p.z += lift * 0.25 * rear - lift * 1.0 * lunge
			p.x *= 1.0 - rear * 0.7
		pts.append(p)
	return pts


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	_slither += delta * (2.0 + hs * 6.0)
	var pts := _spine()
	var head_at: Vector3 = pts[0]
	var fwd: Vector3 = (pts[0] - pts[1]).normalized()
	_head.position = head_at
	_head.basis = Basis.looking_at(fwd, Vector3.UP if absf(fwd.y) < 0.95 else Vector3.BACK)
	if state == S.TELL:
		_head.position += Vector3(sin(_t * 40.0) * 0.01, 0, 0)
	for i in range(SEGS):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := (a - b)
		(_segs[i] as Node3D).position = a
		if d.length() > 0.001:
			var dn := d.normalized()
			(_segs[i] as Node3D).basis = Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.95 else Vector3.BACK)
			(_segs[i] as Node3D).scale = Vector3(1, 1, d.length() / SEG_LEN)
