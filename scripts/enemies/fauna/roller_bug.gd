class_name RollerBug
extends Creature
## Armoured roller: a pill bug the size of a barrel. It trundles about on its
## many little legs; when it spots you it CURLS UP (the tell: it rattles shut
## into a ball) and ROLLS at you, steering a little. Curled, blades skate off
## its plates (sparks, hardly a scratch) and nothing knocks it over. It rolls
## until it hits you, runs out, or smacks into a tree - then it unrolls dazed
## and wide open, and a heavy hit flips it on its back.

const NOTICE := 9.5
const ROLL_MAX := 11.5
const COLORS := [
	[Color(0.3, 0.34, 0.4), Color(0.48, 0.52, 0.58), Color(0.12, 0.12, 0.14)],
	[Color(0.5, 0.25, 0.12), Color(0.72, 0.42, 0.2), Color(0.16, 0.08, 0.05)],
	[Color(0.12, 0.11, 0.1), Color(0.85, 0.68, 0.15), Color(0.08, 0.07, 0.06)],
]

var morph: int = 0
var _roll_dir := Vector3.ZERO
var _roll_speed: float = 0.0
var _rolled: float = 0.0
var _spin: float = 0.0
var _gait: float = 0.0
var _fx_t: float = 0.0
var _body: Node3D
var _ball: Node3D
var _legs: Node3D
var _head: Node3D


func _setup(args: Dictionary) -> void:
	kind = "roller"
	morph = int(args.get("morph", 0))
	max_hp = 70.0
	xp = 50
	coins = Vector2i(1, 3)
	drops = [["chitin_shard", 0.6, 1]]
	flips = true
	skin_tex = "rock"


func _body_shape() -> Array:
	return [0.34, 0.68, Vector3(0.8, 0.75, 1.0)]


func _moves() -> Array:
	return [[15.0, 7.0, Vector3(0.95, 0.85, 0.95), Vector3(0, 0.38, 0), false, 0.4]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var plate: Color = c[0]
	var edge: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var eye := _glow(Color(0.9, 0.85, 0.5))
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3(0, 0.22, 0), m + "shell", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		for i in range(7):
			var z := lerpf(0.42, -0.36, i / 6.0)
			var w := 0.36 - absf(z) * 0.18
			var h := 0.3 - absf(z) * 0.2
			mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, -z * 0.5), Vector3(0, 0.0, z)), Vector3(w, h, 0.09), rng, 0.04, 3, 9, 1.0,
				plate if i % 2 == 0 else plate.lightened(0.08), 0.0)
			mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -z * 0.5), Vector3(0, h * 0.98, z + 0.07)), Vector3(w * 0.9, 0.02, 0.025), 1.0, edge, false, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.0)), Vector3(0.3, 0.05, 0.42), rng, 0.0, 2, 8, 1.0, dark), true)
	_head = _part(_body, "Head", Vector3(0, 0.02, -0.46), m + "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.14, 0.08, 0.08), rng, 0.05, 3, 6, 1.0, dark)
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.08, 0.03, -0.05)), Vector3(0.025, 0.025, 0.025), 1.0, Color.WHITE, false, false)
			mb.add_tube(skin, MeshBuilder.curve_points(Vector3(s * 0.05, 0.04, -0.06), Vector3(s * 0.15, 0.12, -0.18), Vector3(s * 0.22, 0.04, -0.3), 4), 0.012, 0.006, 3, 1.0, edge))
	_legs = _part(_body, "Legs", Vector3(0, -0.05, 0), m + "legs", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for i in range(7):
			var z := lerpf(-0.32, 0.36, i / 6.0)
			for s in [-1.0, 1.0]:
				Creature.seg(mb, skin, Vector3(s * 0.2, 0.02, z), Vector3(s * 0.3, -0.17, z - 0.02), 0.025, dark))
	_ball = _part(model, "Ball", Vector3(0, 0.36, 0), m + "ball", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		for i in range(6):
			var a := TAU * i / 6.0
			var xf := Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
			mb.add_blob(skin, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.2)), Vector3(0.34, 0.24, 0.2), rng, 0.03, 3, 8, 1.0, plate if i % 2 == 0 else plate.lightened(0.08))
			mb.add_box(skin, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.37)), Vector3(0.6, 0.04, 0.03), 1.0, edge, false, false), true)
	_ball.visible = false


func _tick(delta: float) -> void:
	var curl_to := 1.0 if state in [S.TELL, S.ATTACK] else 0.0
	anim_a = move_toward(anim_a, curl_to, delta * (4.0 if curl_to > anim_a else 2.5))


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(0.9, Vector2(2.0, 6.0))
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE) and _cool <= 0.0:
				_set_state(S.NOTICE)
				Net.fx("sfx", ["chitter", global_position, -3.0, 0.1, 0.65])
		S.NOTICE:
			_face(to_p)
			_turn = 10.0
			if st_t > 0.5:
				_set_state(S.TELL)
				Net.fx("sfx", ["bug_hiss", global_position, -3.0, 0.1, 0.7])
		S.CHASE:
			if not _player_ok(p) or dist > 20.0 or flat(global_position - home).length() > 28.0:
				_cool = 3.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			if dist > 9.0:
				_want = to_p.normalized() * 1.6
			elif _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["bug_hiss", global_position, -3.0, 0.1, 0.7])
		S.TELL:
			_face(to_p)
			_turn = 8.0
			if st_t >= 0.6:
				_roll_dir = to_p.normalized() if dist > 0.5 else _fwd()
				_roll_speed = 4.0
				_rolled = 0.0
				_set_state(S.ATTACK)
				_strike(0)
		S.ATTACK:
			_roll_speed = minf(_roll_speed + 14.0 * delta, ROLL_MAX)
			if p and dist > 2.0:
				var want := to_p.normalized()
				var ang := _roll_dir.signed_angle_to(want, Vector3.UP)
				_roll_dir = _roll_dir.rotated(Vector3.UP, clampf(ang, -0.9 * delta, 0.9 * delta))
			_face(_roll_dir)
			_want = _roll_dir * _roll_speed
			_accel = 30.0
			_turn = 12.0
			_rolled += _roll_speed * delta
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.08
				Net.fx("dust", [global_position, 2, 0.4])
			if not hitbox.hit_targets.is_empty():
				velocity = -_roll_dir * 3.0 + Vector3.UP * 3.0
				_daze_len = 0.6
				_cool = 1.6
				_set_state(S.RECOVER)
			elif is_on_wall() and st_t > 0.15:
				velocity = -_roll_dir * 3.5 + Vector3.UP * 3.5
				Net.fx("sfx", ["thud", global_position, 0.0, 0.08, 0.7])
				Net.fx("sparkle", [global_position + Vector3(0, 0.8, 0), 10, Color(1.0, 0.95, 0.6)])
				Net.fx("dust_ring", [global_position, 10, 0.6])
				_daze_len = 2.2
				_cool = 1.5
				_set_state(S.RECOVER)
			elif _rolled > 16.0 or st_t > 3.2:
				_daze_len = 0.8
				_cool = 1.2
				_set_state(S.RECOVER)


func _after_stun() -> void:
	_set_state(S.CHASE)


func _armor(_hit: HitData, _dir: Vector3) -> float:
	return 0.25 if anim_a > 0.5 else 1.0


func _can_knock() -> bool:
	return anim_a < 0.5


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	# rolled up, a blow just glances off: it keeps rolling
	return anim_a > 0.5 and state in [S.TELL, S.ATTACK]


func _cry_death() -> void:
	Net.fx("sfx", ["chitter", global_position, 0.0, 0.05, 0.55])


func _pose(delta: float) -> void:
	var curled := anim_a > 0.5
	_body.visible = not curled
	_ball.visible = curled
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	if curled:
		_spin += hs * delta / 0.36
		_ball.rotation = Vector3(-_spin, 0, 0)
		var sq := 1.0 + sin(_t * 30.0) * 0.03 * (1.0 if state == S.TELL else 0.0)
		_ball.scale = Vector3(sq, 1.0 / sq, sq)
		return
	_gait += hs * 14.0 * delta
	var shrink := clampf(anim_a * 2.0, 0.0, 1.0)
	_body.scale = Vector3.ONE * (1.0 - shrink * 0.2)
	_body.rotation = Vector3(sin(_gait * 2.0) * 0.02, 0, sin(_t * 5.0) * 0.06 if state == S.RECOVER else 0.0)
	_head.rotation = Vector3(0, sin(_t * 1.1) * 0.25, 0)
	var kick := 1.0 if state == S.DOWN else (0.0 if state == S.DEAD else clampf(hs / 0.4, 0.0, 1.0))
	_legs.rotation = Vector3(sin(_gait * 3.0) * 0.12 * kick, 0, 0)
	_legs.scale = Vector3(1.0, 1.0 + sin(_gait * 3.0 + 1.0) * 0.15 * kick, 1.0)
