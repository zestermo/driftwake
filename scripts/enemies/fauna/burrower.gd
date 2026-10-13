class_name Burrower
extends Creature
## Burrower grub: it lives under the jungle floor (or the beach). All you see
## is a hump of earth that shifts about - until it turns your way and the hump
## comes for you, fast. Under your feet it stops and the ground RUMBLES (the
## tell: a ring of dust, a shudder), then it ERUPTS straight up, pincers wide,
## and throws you. It stays up a few seconds, swaying and snapping - that's
## your chance - then dives back down.

const NOTICE := 15.0
const DIG := 3.8
const UP_FOR := 2.8
const COLORS := [
	[Color(0.88, 0.8, 0.62), Color(0.42, 0.28, 0.14), Color(0.16, 0.1, 0.06)],
	[Color(0.75, 0.55, 0.68), Color(0.35, 0.18, 0.3), Color(0.12, 0.06, 0.1)],
	[Color(0.8, 0.72, 0.42), Color(0.5, 0.3, 0.08), Color(0.2, 0.12, 0.04)],
]

var morph: int = 0
var _fx_t: float = 0.0
var _bites: int = 0
var _grub: Node3D
var _jaws: Array = []
var _mound: Node3D


func _setup(args: Dictionary) -> void:
	kind = "burrower"
	morph = int(args.get("morph", 0))
	max_hp = 80.0
	xp = 55
	coins = Vector2i(2, 4)
	drops = [["chitin_shard", 0.5, 1]]
	skin_tex = "dirt"


func _body_shape() -> Array:
	return [0.32, 1.2, Vector3(0.9, 1.6, 0.9)]


func _moves() -> Array:
	return [[16.0, 5.0, Vector3(1.6, 1.8, 1.6), Vector3(0, 0.8, 0), true, 0.5],
		[10.0, 4.0, Vector3(0.9, 0.8, 1.0), Vector3(0, 1.0, -0.7), false, 0.3]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var pale: Color = c[0]
	var plate: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var eye := _glow(Color(0.85, 0.3, 0.15))
	var m := "m%d_" % morph
	_grub = _part(model, "Grub", Vector3.ZERO, m + "grub", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		# fat ringed segments, upright, curling forward at the top; dark plates down the back
		for i in range(7):
			var t := i / 6.0
			var y := 0.15 + t * 1.25
			var z := -t * t * 0.35
			var r := lerpf(0.36, 0.22, t)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, y, z)), Vector3(r, 0.13, r * 0.95), rng, 0.05, 3, 8, 1.2, pale if i % 2 == 0 else pale.darkened(0.1))
			mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, y + 0.02, z + r * 0.75)), Vector3(r * 0.8, 0.1, 0.08), rng, 0.05, 2, 6, 1.2, plate)
		# the head: a dark capsule, eyes, the pincers
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 1.48, -0.42)), Vector3(0.2, 0.16, 0.2), rng, 0.05, 3, 7, 1.2, dark)
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.13, 1.54, -0.55)), Vector3(0.04, 0.035, 0.035), 1.0, Color.WHITE, false, false), true)
	for s in [-1.0, 1.0]:
		var jaw := _part(_grub, "Jaw", Vector3(s * 0.1, 1.42, -0.56), m + ("jaw_l" if s < 0.0 else "jaw_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_tube(skin, MeshBuilder.curve_points(Vector3.ZERO, Vector3(s * 0.18, -0.05, -0.12), Vector3(-s * 0.02, -0.06, -0.28), 5), 0.04, 0.008, 4, 1.0, dark, true, false))
		_jaws.append([jaw, s])
	_mound = _part(self, "Mound", Vector3.ZERO, m + "mound", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.75, 0.3, 0.75), rng, 0.2, 3, 8, 0.8, Color(0.5, 0.38, 0.26), 0.0)
		for k in range(5):
			var a := TAU * k / 5.0 + rng.randf()
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.8, 0.0, sin(a) * 0.8)), Vector3(0.22, 0.12, 0.2), rng, 0.25, 2, 5, 0.8, Color(0.42, 0.3, 0.2), 0.0))


func _start() -> void:
	_hide_now()


func _hide_now() -> void:
	anim_a = 0.0
	_set_state(S.HIDE)
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)


func _surface() -> void:
	collision_layer = 4
	hurtbox.set_deferred("monitorable", true)


func _tick(delta: float) -> void:
	var up := state in [S.ATTACK, S.SPECIAL, S.HITSTUN, S.RECOVER]
	anim_a = move_toward(anim_a, 1.0 if up else 0.0, delta * (5.0 if up else 2.2))


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.HIDE:
			if anim_a > 0.3:
				return
			var hunting := _player_ok(p) and dist < NOTICE and _cool <= 0.0 and flat(global_position - home).length() < 30.0
			if hunting:
				_face(to_p)
				_want = to_p.normalized() * DIG
				_turn = 6.0
				if dist < 1.1 or (st_t > 6.0 and dist < 3.0):
					_set_state(S.TELL)
					Net.fx("sfx", ["thud", global_position, -6.0, 0.1, 0.55])
			else:
				_wander(0.8, Vector2(2.0, 8.0))
			_fx_t -= delta
			if _fx_t <= 0.0 and flat(velocity).length() > 0.5:
				_fx_t = 0.22 if hunting else 0.5
				Net.fx("dust", [global_position, 3 if hunting else 1, 0.45])
		S.TELL:
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.12
				Net.fx("dust_ring", [global_position, 6, 0.4 + st_t])
			if st_t >= 0.7:
				_surface()
				_set_state(S.ATTACK)
				_strike(0)
				Net.fx("sfx", ["crunch", global_position, 0.0, 0.08, 0.7])
				Net.fx("debris", [global_position, Vector3.UP, 12, Color(0.42, 0.32, 0.22), 6.0])
				Net.fx("dust_ring", [global_position, 14, 1.0])
		S.ATTACK:
			if st_t > 0.35:
				_bites = 0
				_set_state(S.SPECIAL)
		S.SPECIAL:
			_face(to_p)
			_turn = 5.0
			if _player_ok(p) and dist < 2.4 and _bites < 2 and st_t > 0.5 + _bites * 0.9:
				_bites += 1
				_strike(1)
				Net.fx("sfx", ["crunch", global_position, -4.0, 0.1, 1.2])
			elif hitbox.active and st_t > 0.5 + (_bites - 1) * 0.9 + 0.2:
				hitbox.deactivate()
			if st_t > UP_FOR:
				_cool = 2.0
				_hide_now()
				Net.fx("dust", [global_position, 8, 0.7])
				Net.fx("sfx", ["thud", global_position, -6.0, 0.1, 0.7])


func _after_stun() -> void:
	_set_state(S.SPECIAL)
	st_t = 1.0


func _after_daze() -> void:
	_set_state(S.SPECIAL)
	st_t = 0.8


func _got_up() -> void:
	_daze_len = 0.8
	_set_state(S.RECOVER)


func _cry_death() -> void:
	Net.fx("sfx", ["chitter", global_position, 0.0, 0.05, 0.45])


func _pose(_delta: float) -> void:
	var e := anim_a * anim_a * (3.0 - 2.0 * anim_a)
	_grub.visible = e > 0.01 or state in [S.DOWN, S.DEAD]
	var lying := state in [S.DOWN, S.DEAD]
	_grub.position.y = 0.0 if lying else lerpf(-1.7, -0.05, e)
	var sway := sin(_t * 2.3) * 0.12 * e
	_grub.rotation = Vector3.ZERO if lying else Vector3(sway * 0.6, 0, sway)
	var snap := 0.0
	if state == S.SPECIAL or state == S.ATTACK:
		snap = 0.5 + sin(_t * (14.0 if hitbox.active else 4.0)) * 0.4
	for j in _jaws:
		(j[0] as Node3D).rotation = Vector3(0, float(j[1]) * snap * 0.7, 0)
	# the hump of earth over it, shuddering on the tell
	var shake := sin(_t * 40.0) * 0.06 if state == S.TELL else 0.0
	_mound.visible = state != S.DEAD and not lying
	_mound.scale = Vector3(1.0 + shake, 1.0 + (0.4 if state == S.TELL else 0.0) - e * 0.5, 1.0 + shake) * size_k
	_mound.position.y = -0.05 + sin(_t * 6.0) * 0.03 * clampf(flat(velocity).length(), 0.0, 1.0)


func _can_knock() -> bool:
	return anim_a > 0.5
