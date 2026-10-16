class_name DesertFox
extends Creature
## Fennec foxes: small, sand-coloured, ears bigger than their heads. They trot about their
## den in twos and threes, sit up to listen, and bolt when a captain comes near, zigzagging
## off across the sand; cornered (hit), one snaps once and runs. Morphs: pale sand, red, grey.

const RUN := 7.5
const BODY_Y := 0.26
const SHY := 9.0

var morph: int = 0
var _gait: float = 0.0
var _zig: float = 1.0
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _ears: Array = []
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "fox"
	morph = int(args.get("morph", 0))
	size_k = 0.75 if bool(args.get("calf", false)) else 1.0
	max_hp = 22.0
	xp = 18
	coins = Vector2i(0, 1)
	drops = [["plume", 0.3, 1]]
	hostile = false
	skin_tex = "fur_white"


func _body_shape() -> Array:
	return [0.16, 0.42, Vector3(0.3, 0.45, 0.7)]


func _moves() -> Array:
	return [[6.0, 2.5, Vector3(0.45, 0.4, 0.45), Vector3(0, 0.25, -0.4), false, 0.2]]


func _build() -> void:
	var coats := [[Color(0.92, 0.8, 0.58), Color(1.0, 0.95, 0.85)], [Color(0.85, 0.5, 0.25), Color(0.98, 0.9, 0.8)], [Color(0.62, 0.6, 0.55), Color(0.9, 0.88, 0.84)]]
	var c: Array = coats[morph % 3]
	var coat: Color = c[0]
	var belly: Color = c[1]
	var dark := Color(0.12, 0.1, 0.08)
	var skin := _skin()
	var v := "m%d" % (morph % 3)
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[-0.22, 0.05, 0.06, 0.0], [-0.15, 0.09, 0.1, 0.0], [0.08, 0.1, 0.11, 0.01], [0.2, 0.07, 0.08, 0.0]],
			MeshBuilder.profile_circle(7), 1.5, coat, true, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, -0.02)), Vector3(0.07, 0.05, 0.16), rng, 0.05, 2, 6, 1.5, belly), true)
	_head = _part(_body, "Head", Vector3(0, 0.09, -0.22), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.075, 0.07, 0.08), rng, 0.03, 3, 7, 1.5, coat)
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.02, -0.06))
		mb.add_loft(skin, xf, [[0.0, 0.045, 0.04], [0.08, 0.025, 0.022], [0.11, 0.012, 0.012]], MeshBuilder.profile_circle(6), 1.5, belly, false, true)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.175)), Vector3(0.025, 0.02, 0.02), 1.5, dark, false, false)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.04, 0.02, -0.06)), Vector3(0.015, 0.015, 0.015), rng, 0.0, 2, 5, 1.5, dark))
	for s in [-1.0, 1.0]:
		var ear := _part(_head, "Ear", Vector3(s * 0.04, 0.05, 0.0), v + ("_ear_l" if s < 0.0 else "_ear_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var shape := PackedVector2Array([Vector2(-0.045, 0), Vector2(0.045, 0), Vector2(0.0, 0.17)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.35), Vector3.ZERO), shape, 0.015, 1.5, coat)
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.35), Vector3(0, 0.01, -0.009)), PackedVector2Array([Vector2(-0.03, 0.01), Vector2(0.03, 0.01), Vector2(0.0, 0.13)]), 0.004, 1.5, Color(0.95, 0.75, 0.7)))
		_ears.append([ear, s])
	_tail = _part(_body, "Tail", Vector3(0, 0.02, 0.2), v + "_tail", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var pts := MeshBuilder.curve_points(Vector3.ZERO, Vector3(0, -0.05, 0.15), Vector3(0, -0.12, 0.3), 5)
		mb.add_tube(skin, pts, 0.04, 0.05, 5, 1.0, coat)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.13, 0.32)), Vector3(0.04, 0.04, 0.05), rng, 0.1, 2, 5, 1.0, dark))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var leg := _part(_body, "Leg%d" % i, Vector3(s * 0.05, -0.05, -0.12 if front else 0.13), v + "_leg", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.21, 0)), 0.018, 0.028, 0.22, 5, 1.0, coat, false))
		_legs.append({"pivot": leg, "front": front, "pair": i % 2})


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(1.6, Vector2(1.5, 7.0))
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), SHY):
				_zig = 1.0 if _rng.randf() < 0.5 else -1.0
				_set_state(S.FLEE)
				Net.fx("sfx", ["squeal", global_position, -6.0, 0.15, 1.9])
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			if fmod(st_t, 0.7) < get_physics_process_delta_time():
				_zig = -_zig
			var dir := (away + away.cross(Vector3.UP) * _zig * 0.45).normalized()
			_face(dir)
			_turn = 12.0
			_want = dir * RUN
			if st_t > 3.0 and dist > SHY * 1.8:
				_wander_to = home
				_set_state(S.WANDER)
		S.TELL:
			_face(to_p)
			if st_t > 0.25:
				_set_state(S.ATTACK)
				_strike(0)
				velocity = _fwd() * 4.0
		S.ATTACK:
			if st_t > 0.25:
				_set_state(S.FLEE)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	if _rng.randf() < 0.4 and state != S.ATTACK:
		_set_state(S.TELL)
		return true
	return false


func _after_stun() -> void:
	_set_state(S.FLEE)


func _after_daze() -> void:
	_set_state(S.FLEE)


func _cry_death() -> void:
	Net.fx("sfx", ["squeal", global_position, -5.0, 0.1, 2.1])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 3.2 * delta / size_k
	var listen := 1.0 if state == S.WANDER and _wander_wait > 1.0 else 0.0
	_body.rotation = Vector3(-0.35 * listen, 0, 0)
	_body.position.y = BODY_Y + listen * 0.06 + absf(sin(_gait)) * 0.04 * moving
	_head.rotation = Vector3(0.35 * listen, sin(_t * 0.9) * 0.4 * (1.0 - moving), 0)
	for e in _ears:
		(e[0] as Node3D).rotation = Vector3(-0.2 + sin(_t * 3.0 + float(e[1])) * 0.1 * listen, 0, 0)
	_tail.rotation = Vector3(0.4 * moving - 0.2, sin(_t * 2.0) * 0.2, 0)
	for leg in _legs:
		var ph := _gait + (PI if int(leg["pair"]) == 1 else 0.0) + (0.0 if leg["front"] else PI * 0.6)
		var swing := sin(ph) * 0.7 * moving
		if state in [S.DOWN, S.DEAD]:
			swing = sin(_t * 15.0) * 0.5 * (1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t))
		(leg["pivot"] as Node3D).rotation = Vector3(swing, 0, 0)
