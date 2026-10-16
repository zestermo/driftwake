class_name SnowHare
extends Creature
## Snow hares, a few to a meadow under the pines: white as the snow but for black ear
## tips, they hop about nibbling and freeze with ears up when you come near; closer and
## they bolt in long zigzag bounds, a puff of snow at each. Harmless, quick, worth a
## haunch to whoever catches one. Morphs: white, brown-grey (moulting), grey.

const HOP := 7.5
const BODY_Y := 0.2

var morph: int = 0

var _flee_from := Vector3.ZERO
var _hop: float = 0.0
var _zig: float = 1.0
var _zig_t: float = 0.0
var _body: Node3D
var _head: Node3D
var _ears: Array = []
var _hind: Array = []
var _fore: Array = []


func _setup(args: Dictionary) -> void:
	kind = "snow_hare"
	morph = int(args.get("morph", 0))
	hostile = false
	skin_tex = "fur_white"
	size_k = 0.9
	max_hp = 14.0
	xp = 6
	coins = Vector2i(0, 1)
	drops = [["boar_haunch", 0.4, 1]]


func _body_shape() -> Array:
	return [0.16, 0.35, Vector3(0.35, 0.4, 0.55)]


func _build() -> void:
	var coats := [[Color(0.95, 0.95, 0.96), Color(1.0, 1.0, 1.0)], [Color(0.62, 0.55, 0.48), Color(0.9, 0.88, 0.84)], [Color(0.6, 0.6, 0.62), Color(0.85, 0.85, 0.86)]]
	var c: Array = coats[morph % 3]
	var coat: Color = c[0]
	var belly: Color = c[1]
	var tip := Color(0.08, 0.07, 0.07)
	var v := str(morph % 3)
	var skin := _skin()
	var eye := _glow(Color(0.25, 0.12, 0.08))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.04)), Vector3(0.14, 0.14, 0.22), rng, 0.08, 3, 7, 1.0, coat)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.1)), Vector3(0.1, 0.1, 0.12), rng, 0.08, 3, 6, 1.0, belly)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0.25)), Vector3(0.05, 0.05, 0.05), rng, 0.1, 2, 5, 1.0, belly), true)
	_head = _part(_body, "Head", Vector3(0, 0.1, -0.2), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.04)), Vector3(0.07, 0.07, 0.09), rng, 0.08, 3, 6, 1.0, coat)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.13)), Vector3(0.03, 0.025, 0.02), 1.0, Color(0.75, 0.55, 0.55), false, false)
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.02, -0.07)), Vector3(0.02, 0.02, 0.02), 1.0, Color.WHITE, false, false))
	for s in [-1.0, 1.0]:
		var ear := _part(_head, "Ear%d" % int(s + 1.0), Vector3(s * 0.03, 0.05, 0.0), v + "_ear", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), Vector3(0.035, 0.16, 0.015), 1.0, coat, false, false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)), Vector3(0.036, 0.03, 0.017), 1.0, tip, false, false))
		_ears.append([ear, s])
	for s in [-1.0, 1.0]:
		var hind := _part(_body, "Hind%d" % int(s + 1.0), Vector3(s * 0.09, -0.04, 0.12), v + "_hind", func(mb: MeshBuilder, rng: RandomNumberGenerator):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0.02)), Vector3(0.05, 0.09, 0.09), rng, 0.08, 2, 5, 1.0, coat)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.14, -0.05)), Vector3(0.04, 0.03, 0.14), 1.0, belly, false, false))
		_hind.append(hind)
		var fore := _part(_body, "Fore%d" % int(s + 1.0), Vector3(s * 0.06, -0.06, -0.12), v + "_fore", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0)), Vector3(0.03, 0.12, 0.03), 1.0, belly, false, false))
		_fore.append(fore)


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			var wary := Stealth.range_for(p, global_position, _fwd(), 11.0) if _player_ok(p) else 0.0
			if dist < wary * 0.55:
				_bolt(p.global_position)
				return
			if dist < wary:
				_set_state(S.NOTICE)
				return
			_wander(0.9, Vector2(1.0, 5.0))
		S.NOTICE:
			if not _player_ok(p):
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 6.0
			if dist < Stealth.range_for(p, global_position, _fwd(), 6.5):
				_bolt(p.global_position)
			elif st_t > 2.5:
				_set_state(S.WANDER)
		S.FLEE:
			_zig_t -= delta
			if _zig_t <= 0.0:
				_zig_t = _rng.randf_range(0.35, 0.7)
				_zig = -_zig
			var away := _flee_dir(_flee_from).rotated(Vector3.UP, _zig * 0.6)
			_face(away)
			_want = away * HOP
			_accel = 30.0
			_turn = 14.0
			if p and dist < 10.0:
				_flee_from = p.global_position
			if st_t > 3.5 and dist > 18.0:
				_set_state(S.WANDER)
				_wander_to = home


func _bolt(from: Vector3) -> void:
	_flee_from = from
	_set_state(S.FLEE)


func _after_stun() -> void:
	var p := _target()
	_bolt(p.global_position if p else global_position + _fwd())


func _after_daze() -> void:
	_after_stun()


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, 1.0 if state == S.NOTICE else 0.0, delta * 8.0)


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	_hop += hs * 2.4 * delta
	var bound := absf(sin(_hop)) if hs > 0.3 else 0.0
	var alert := anim_a
	_body.position.y = BODY_Y + bound * 0.22 + alert * 0.05
	_body.rotation = Vector3(-alert * 0.35 + (cos(_hop) * 0.25 if hs > 0.3 else 0.0), 0, 0)
	_head.rotation = Vector3(alert * 0.3 + (sin(_t * 9.0) * 0.06 if hs < 0.1 and alert < 0.1 else 0.0), 0, 0)
	for e in _ears:
		(e[0] as Node3D).rotation = Vector3(0.6 - alert * 0.5 + bound * 0.4, 0, float(e[1]) * (0.15 + alert * 0.1))
	for h in _hind:
		(h as Node3D).rotation = Vector3(-cos(_hop) * 0.8 if hs > 0.3 else 0.0, 0, 0)
	for f in _fore:
		(f as Node3D).rotation = Vector3(cos(_hop) * 0.7 if hs > 0.3 else 0.0, 0, 0)
	if hs > 3.0 and bound < 0.1 and lod == LOD_FULL and fmod(_t, 0.25) < delta:
		FX.puff(global_position, "snow", 1, 0.35, 0.45, Color.WHITE, 0.25, Vector3.UP)
