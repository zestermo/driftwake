class_name ForestDeer
extends Creature
## Red deer in the autumn woods: a herd of hinds and their spotted fawns round a stag. They graze nose
## down; come near and the nearest throws up its head and stamps (the tell), then the herd bounds away
## through the trees, white tails flagging. Hit one and it bolts - but hit the stag and he turns, lowers
## his antlers and charges (a toss that knocks you down), then bolts after the rest. Morphs: red-brown,
## fallow (paler, spotted), dark.

const RUN := 9.5
const BODY_Y := 0.95
const SHY := 15.0

var lead := false
var calf := false
var morph: int = 0
var _gait: float = 0.0
var _graze: float = 0.0
var _body: Node3D
var _neck: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array = []
var _charge_dir := Vector3.ZERO


func _setup(args: Dictionary) -> void:
	kind = "deer"
	lead = bool(args.get("lead", false))
	calf = bool(args.get("calf", false))
	morph = int(args.get("morph", 0))
	hostile = false
	skin_tex = "fur_white"
	size_k = 1.25 if lead else (0.62 if calf else 1.0)
	max_hp = 110.0 if lead else (30.0 if calf else 60.0)
	xp = 70 if lead else 30
	coins = Vector2i(1, 4) if lead else Vector2i(0, 2)
	drops = [["plume", 0.2, 1]]


func in_combat() -> bool:
	return state in [S.TELL, S.ATTACK] and lead


func _body_shape() -> Array:
	return [0.3, 1.2, Vector3(0.5, 1.4, 1.4)]


func _moves() -> Array:
	return [[16.0, 7.0, Vector3(0.9, 0.9, 1.0), Vector3(0, 1.0, -0.9), true, 0.4]]


func _build() -> void:
	var coats := [[Color(0.62, 0.36, 0.2), Color(0.86, 0.74, 0.58), Color(0.36, 0.22, 0.14)],
		[Color(0.78, 0.6, 0.4), Color(0.95, 0.9, 0.8), Color(0.5, 0.36, 0.22)],
		[Color(0.38, 0.26, 0.18), Color(0.7, 0.6, 0.5), Color(0.2, 0.14, 0.1)]]
	var c: Array = coats[morph % 3]
	var coat: Color = c[0]
	var belly: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var v := "%d%s" % [morph % 3, "_stag" if lead else ("_fawn" if calf else "")]
	var spots := calf or morph % 3 == 1
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[-0.5, 0.12, 0.14, 0.0], [-0.38, 0.2, 0.24, 0.0], [0.0, 0.2, 0.22, -0.02], [0.32, 0.2, 0.22, 0.0], [0.48, 0.13, 0.14, 0.02]],
			MeshBuilder.profile_circle(8), 1.2, coat, true, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), Vector3(0.15, 0.08, 0.38), rng, 0.05, 2, 6, 1.2, belly)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.44)), Vector3(0.14, 0.13, 0.06), rng, 0.05, 2, 6, 1.2, belly.lightened(0.3))
		if spots:
			for k in range(12):
				var a := rng.randf_range(-1.1, 1.1)
				var z := rng.randf_range(-0.35, 0.35)
				mb.add_box(skin, Transform3D(Basis(Vector3.BACK, a), Vector3(sin(a) * 0.2, cos(a) * 0.2, z)), Vector3(0.05, 0.012, 0.05), 1.5, Color(0.96, 0.92, 0.84)))
	_neck = _part(_body, "Neck", Vector3(0, 0.08, -0.42), v + "_neck", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_tube(skin, PackedVector3Array([Vector3.ZERO, Vector3(0, 0.25, -0.12), Vector3(0, 0.48, -0.18)]), 0.14, 0.09, 7, 1.2, coat)
		if lead:
			for k in range(6):
				mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.1 + k * 0.06, -0.12 - k * 0.01)), Vector3(0.12, 0.08, 0.1), rng, 0.3, 2, 5, 1.2, dark))
	_head = _part(_neck, "Head", Vector3(0, 0.5, -0.2), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.08, 0.08, 0.1), rng, 0.03, 3, 7, 1.5, coat)
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.3), Vector3(0, -0.02, -0.07))
		mb.add_loft(skin, xf, [[0.0, 0.06, 0.06], [0.12, 0.04, 0.04], [0.17, 0.025, 0.03]], MeshBuilder.profile_circle(6), 1.5, coat.lerp(belly, 0.3), false, true)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.07, -0.23)), Vector3(0.04, 0.03, 0.03), 1.5, Color(0.08, 0.06, 0.05), false, false)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.06, 0.02, -0.05)), Vector3(0.016, 0.016, 0.016), rng, 0.0, 2, 5, 1.5, Color(0.05, 0.04, 0.04))
			var ear := PackedVector2Array([Vector2(-0.035, 0), Vector2(0.035, 0), Vector2(0.0, 0.14)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 1.0), Vector3(s * 0.06, 0.06, 0.02)), ear, 0.012, 1.5, coat)
			if lead:
				# antlers: a main beam back and up, tines forward off it, a crown at the top
				var bone := Color(0.86, 0.78, 0.62)
				var root := Vector3(s * 0.04, 0.08, 0.0)
				var pts := MeshBuilder.curve_points(root, root + Vector3(s * 0.22, 0.25, 0.1), root + Vector3(s * 0.3, 0.62, -0.02), 6)
				mb.add_tube(skin, pts, 0.025, 0.012, 4, 1.5, bone)
				for t in [1, 3, 5]:
					var at: Vector3 = pts[t]
					mb.add_tube(skin, PackedVector3Array([at, at + Vector3(s * 0.03, 0.12, -0.12)]), 0.016, 0.006, 4, 1.5, bone)
				mb.add_tube(skin, PackedVector3Array([pts[6], pts[6] + Vector3(s * 0.08, 0.1, 0.06)]), 0.014, 0.006, 4, 1.5, bone))
	_tail = _part(_body, "Tail", Vector3(0, 0.12, 0.48), v + "_tail", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.04)), Vector3(0.05, 0.08, 0.04), rng, 0.1, 2, 5, 1.2, Color(0.96, 0.94, 0.9)))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var leg := _part(_body, "Leg%d" % i, Vector3(s * 0.11, -0.05, -0.32 if front else 0.34), v + "_leg", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.45, 0)), 0.03, 0.07, 0.45, 5, 1.0, coat, false)
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.92, 0)), 0.025, 0.03, 0.48, 5, 1.0, coat.lerp(dark, 0.4), false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.93, -0.01)), Vector3(0.05, 0.04, 0.06), 1.0, Color(0.08, 0.06, 0.05), false, false))
		_legs.append({"pivot": leg, "front": front, "pair": i % 2})


func _herd_flee(from: Vector3) -> void:
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is ForestDeer and f != self and (f as ForestDeer).home.distance_to(home) < 12.0 and (f as ForestDeer).state in [S.IDLE, S.WANDER, S.NOTICE]:
			(f as ForestDeer)._bolt(from)


func _bolt(from: Vector3) -> void:
	if state in [S.DEAD, S.DOWN]:
		return
	_charge_dir = _flee_dir(from)
	_set_state(S.FLEE)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(0.9, Vector2(1.5, 8.0))
			_graze = move_toward(_graze, 1.0 if _wander_wait > 0.0 else 0.0, get_physics_process_delta_time() * 1.5)
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), SHY):
				_set_state(S.NOTICE)
				_face(to_p)
		S.NOTICE:
			_face(to_p)
			_graze = 0.0
			if st_t > 0.6:
				Net.fx("sfx", ["thud", global_position, -8.0, 0.1, 1.4])
				_bolt(p.global_position if p else global_position + _fwd())
				_herd_flee(p.global_position if p else global_position + _fwd())
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_charge_dir = _charge_dir.lerp(away, 0.05).normalized()
			_face(_charge_dir)
			_turn = 5.0
			_want = _charge_dir * RUN
			if st_t > 4.0 and dist > SHY * 1.6:
				_wander_to = global_position
				home = global_position.lerp(home, 0.5)
				_set_state(S.WANDER)
		S.TELL:
			_face(to_p)
			_want = Vector3.ZERO
			if st_t > 0.55:
				_charge_dir = to_p.normalized()
				_set_state(S.ATTACK)
				_strike(0)
		S.ATTACK:
			_want = _charge_dir * RUN * 1.1
			_turn = 2.0
			if st_t > 0.6:
				_bolt(p.global_position if p else global_position + _fwd())


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	if lead and state not in [S.TELL, S.ATTACK] and _rng.randf() < 0.75:
		_set_state(S.TELL)
		Net.fx("sfx", ["roar", global_position, -6.0, 0.1, 1.7])
		return true
	if attacker is Node3D:
		_herd_flee((attacker as Node3D).global_position)
	return false


func _after_stun() -> void:
	_bolt(_target().global_position if _target() else global_position + _fwd())


func _after_daze() -> void:
	_bolt(_target().global_position if _target() else global_position + _fwd())


func _cry_death() -> void:
	Net.fx("sfx", ["squeal", global_position, -5.0, 0.1, 0.9])


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, _graze, delta * 2.0)


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	var bound := clampf((hs - 4.0) / 4.0, 0.0, 1.0)
	_gait += hs * 2.0 * delta / size_k
	var graze := anim_a
	_body.position.y = BODY_Y + absf(sin(_gait)) * 0.18 * bound + absf(sin(_gait * 2.0)) * 0.03 * moving * (1.0 - bound)
	_body.rotation = Vector3(sin(_gait) * 0.12 * bound, 0, 0)
	var alert := 1.0 if state in [S.NOTICE, S.TELL] else 0.0
	_neck.rotation = Vector3(-1.0 * graze + 0.25 * alert - (0.9 if state in [S.TELL, S.ATTACK] and lead else 0.0), 0, 0)
	_head.rotation = Vector3(0.6 * graze, sin(_t * 0.7) * 0.25 * (1.0 - moving), 0)
	_tail.rotation = Vector3(-0.9 if state == S.FLEE or alert > 0.0 else 0.2, 0, 0)
	for leg in _legs:
		var ph := _gait + (0.0 if leg["front"] else PI) * bound + (PI if int(leg["pair"]) == 1 else 0.0) * (1.0 - bound)
		var swing := sin(ph) * (0.45 + 0.5 * bound) * moving
		if state in [S.DOWN, S.DEAD]:
			swing = sin(_t * 12.0) * 0.4 * (1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t))
		(leg["pivot"] as Node3D).rotation = Vector3(swing, 0, 0)
