class_name SwarmMite
extends Creature
## Red mites, fist-sized, that live in a mound and come boiling out of it
## together. Each is nothing - one cut and it's gone - but a pack skitters at
## you from every side, darting in for nips and hopping onto you. Sweeping
## blows and heavy hits clear them. They don't go far from the mound.

const NOTICE := 9.0
const LEASH := 18.0
const COLORS := [
	[Color(0.72, 0.1, 0.06), Color(0.3, 0.04, 0.03)],
	[Color(0.12, 0.12, 0.1), Color(0.75, 0.6, 0.12)],
	[Color(0.85, 0.5, 0.1), Color(0.35, 0.15, 0.05)],
]

var morph: int = 0
var _side: float = 1.0
var _gait: float = 0.0
var _body: Node3D
var _legs: Node3D


func _setup(args: Dictionary) -> void:
	kind = "mite"
	morph = int(args.get("morph", 0))
	max_hp = 10.0
	xp = 8
	coins = Vector2i(0, 1)
	drops = [["chitin_shard", 0.08, 1]]
	flips = true


func _body_shape() -> Array:
	return [0.14, 0.28, Vector3(0.5, 0.45, 0.55)]


func _moves() -> Array:
	return [[4.0, 1.5, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.25, -0.3), false, 0.12]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var skin := _skin()
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3(0, 0.14, 0), m + "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.13, 0.1, 0.16), rng, 0.08, 3, 7, 2.0, c[0])
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.15)), Vector3(0.06, 0.05, 0.05), rng, 0.05, 2, 5, 2.0, c[1])
		for k in range(3):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.05, 0.05), 0.09, rng.randf_range(-0.08, 0.1))), Vector3(0.04, 0.02, 0.04), 2.0, c[1], false, false)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * 0.025, -0.02, -0.2)), Vector3(0.015, 0.015, 0.05), 2.0, c[1], false, false))
	_legs = _part(_body, "Legs", Vector3.ZERO, m + "legs", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for i in range(4):
			var z := lerpf(-0.09, 0.09, i / 3.0)
			for s in [-1.0, 1.0]:
				Creature.seg(mb, skin, Vector3(s * 0.1, 0.0, z), Vector3(s * 0.2, 0.05, z * 1.4), 0.02, c[1])
				Creature.seg(mb, skin, Vector3(s * 0.2, 0.05, z * 1.4), Vector3(s * 0.25, -0.13, z * 1.7), 0.016, c[1]))


func _start() -> void:
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_set_state(S.WANDER)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(1.4, Vector2(0.5, 3.0))
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, Vector3.ZERO, NOTICE) and _cool <= 0.0:
				_set_state(S.CHASE)
				Net.fx("sfx", ["chitter", global_position, -8.0, 0.15, 1.8])
		S.CHASE:
			if not _player_ok(p) or flat(global_position - home).length() > LEASH:
				_cool = 2.5
				_wander_to = home
				_set_state(S.WANDER)
				return
			# circle in, then dart
			var tangent := to_p.normalized().cross(Vector3.UP) * _side
			var k := clampf((dist - 1.2) / 3.0, 0.0, 1.0)
			_face(to_p)
			_want = (to_p.normalized() * (1.0 - k * 0.4) + tangent * k * 0.8).normalized() * 5.2
			_turn = 16.0
			if dist < 1.4 and _cool <= 0.0:
				_set_state(S.ATTACK)
				_strike(0)
				velocity = to_p.normalized() * 4.5 + Vector3.UP * 3.0
		S.ATTACK:
			_want = flat(velocity)
			_accel = 4.0
			if st_t > 0.12 and is_on_floor():
				_cool = _rng.randf_range(0.6, 1.2)
				if _rng.randf() < 0.3:
					_side = -_side
				_set_state(S.CHASE)
			elif st_t > 0.25 and hitbox.active:
				hitbox.deactivate()


func _after_daze() -> void:
	_set_state(S.CHASE)


func _cry_death() -> void:
	Net.fx("sfx", ["chitter", global_position, -6.0, 0.15, 2.0])
	Net.fx("poison", [global_position + Vector3(0, 0.2, 0), 3, 0.25])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	_gait += hs * 22.0 * delta
	var kick := clampf(hs / 0.5, 0.0, 1.0)
	if state == S.DOWN:
		kick = 1.0
		_gait += 30.0 * delta
	_body.position.y = 0.14 + absf(sin(_gait)) * 0.02 * kick
	_body.rotation = Vector3(-0.3 if state == S.ATTACK else 0.0, 0, sin(_gait) * 0.08 * kick)
	_legs.rotation = Vector3(sin(_gait * 1.3) * 0.25 * kick, 0, 0)
	_legs.scale = Vector3(1.0 + sin(_gait) * 0.15 * kick, 1.0, 1.0)
