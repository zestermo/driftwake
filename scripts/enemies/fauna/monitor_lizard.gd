class_name MonitorLizard
extends Creature
## Giant monitor lizards basking on the warm rock. They leave you be until you come too close
## or hit one: then it hisses with its throat puffed and its tongue flicking (the tell) and
## lunges for a BITE, or swings round and lashes its TAIL across the ground in front of it,
## which knocks you off your feet. A badly hurt one runs for it. Morphs: banded ochre, grey,
## dusky green.

const NOTICE := 4.5
const RUN := 5.2
const BODY_Y := 0.22
const COLORS := [
	[Color(0.62, 0.5, 0.3), Color(0.86, 0.76, 0.52), Color(0.3, 0.22, 0.12)],
	[Color(0.45, 0.43, 0.4), Color(0.7, 0.68, 0.62), Color(0.2, 0.19, 0.18)],
	[Color(0.38, 0.42, 0.28), Color(0.66, 0.68, 0.48), Color(0.16, 0.18, 0.1)],
]

var morph: int = 0
var _provoked: float = 0.0
var _whip := false
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _tongue: Node3D
var _tail: Array = []
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "lizard"
	morph = int(args.get("morph", 0))
	size_k = 1.35 if bool(args.get("calf", false)) == false else 0.8
	max_hp = 90.0 * size_k
	xp = 50
	coins = Vector2i(1, 3)
	drops = [["snakeskin", 0.6, 1]]
	hostile = true
	skin_tex = "scales"


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.3, 0.55, Vector3(0.7, 0.55, 1.8)]


func _moves() -> Array:
	return [[15.0, 4.0, Vector3(0.7, 0.6, 0.8), Vector3(0, 0.35, -1.0), false, 0.35],
		[12.0, 8.0, Vector3(2.4, 0.6, 1.4), Vector3(0, 0.3, -0.9), true, 0.45]]


# ==========================================================================
# Model: a long low body, a wedge head with a hinged jaw and forked tongue, four sprawling legs, a long tail
# ==========================================================================
func _build() -> void:
	var c: Array = COLORS[morph % 3]
	var back: Color = c[0]
	var belly: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var v := "m%d" % (morph % 3)
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[-0.5, 0.1, 0.08, 0.0], [-0.35, 0.18, 0.12, 0.01], [0.0, 0.22, 0.14, 0.02], [0.3, 0.2, 0.13, 0.01], [0.5, 0.12, 0.09, 0.0]],
			MeshBuilder.profile_circle(8), 1.5, back, true, true)
		for k in range(6):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, -0.4 + k * 0.17)), Vector3(0.3, 0.02, 0.06), 1.5, dark, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.09, 0)), Vector3(0.17, 0.05, 0.45), rng, 0.03, 2, 7, 1.5, belly), true)
	_head = _part(_body, "Head", Vector3(0, 0.03, -0.52), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[0.0, 0.09, 0.08, 0.0], [0.14, 0.085, 0.07, 0.0], [0.28, 0.06, 0.045, -0.01], [0.36, 0.03, 0.025, -0.02]],
			MeshBuilder.profile_circle(7), 1.5, back, true, true)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.065, 0.04, -0.14)), Vector3(0.022, 0.022, 0.022), rng, 0.0, 2, 5, 1.5, Color(0.9, 0.7, 0.2))
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.02)), Vector3(0.07, 0.05, 0.1), rng, 0.05, 2, 6, 1.5, belly))
	_jaw = _part(_head, "Jaw", Vector3(0, -0.03, -0.04), v + "_jaw", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.015, -0.15)), Vector3(0.1, 0.03, 0.28), 1.5, belly, false, false))
	_tongue = _part(_head, "Tongue", Vector3(0, -0.02, -0.35), v + "_tongue", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var pink := Color(0.75, 0.3, 0.35)
		Creature.seg(mb, skin, Vector3.ZERO, Vector3(0, 0, -0.12), 0.012, pink)
		for s in [-1.0, 1.0]:
			Creature.seg(mb, skin, Vector3(0, 0, -0.12), Vector3(s * 0.025, 0, -0.17), 0.008, pink))
	var prev := _body
	var at := Vector3(0, -0.01, 0.5)
	for k in range(4):
		var r := 0.085 - k * 0.018
		var seg := _part(prev, "Tail%d" % k, at, v + "_tail%d" % k, func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), r, maxf(r - 0.018, 0.012), 0.36, 6, 1.5, back.darkened(0.05 * k), false, k == 3))
		_tail.append(seg)
		prev = seg
		at = Vector3(0, 0, 0.36)
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var leg := _part(_body, "Leg%d" % i, Vector3(s * 0.17, -0.02, -0.3 if front else 0.32), v + ("_legf" if front else "_legb") + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.2, 0.02, 0.02), 0.07, back)
			Creature.seg(mb, skin, Vector3(s * 0.2, 0.02, 0.02), Vector3(s * 0.27, -BODY_Y + 0.03, -0.06), 0.055, back)
			for t in range(3):
				Creature.seg(mb, skin, Vector3(s * 0.27, -BODY_Y + 0.03, -0.06), Vector3(s * 0.29 + (t - 1) * 0.05, -BODY_Y + 0.01, -0.15), 0.016, dark))
		_legs.append({"pivot": leg, "side": s, "front": front})


# ==========================================================================
# Brain
# ==========================================================================
func provoke() -> void:
	if state == S.DEAD:
		return
	var was := _provoked > 0.0
	_provoked = 14.0
	if not was and state in [S.IDLE, S.WANDER]:
		_set_state(S.NOTICE)


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	anim_a = move_toward(anim_a, 1.0 if state in [S.NOTICE, S.TELL] else 0.0, delta * 5.0)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			# basking: long waits, short ambles
			_wander(0.9, Vector2(2.0, 6.0))
			if _wander_wait > 0.0:
				_wander_wait += get_physics_process_delta_time() * 0.6
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE * size_k):
				provoke()
		S.NOTICE:
			_face(to_p)
			_turn = 6.0
			if st_t < 0.05:
				Net.fx("sfx", ["hiss", global_position, -2.0, 0.1, 0.8])
			if st_t > 0.8:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 18.0 or flat(global_position - home).length() > 26.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 6.0
			if dist > 1.9 * size_k:
				_want = to_p.normalized() * RUN
			elif _cool <= 0.0:
				_whip = _rng.randf() < 0.35
				_set_state(S.TELL)
				Net.fx("sfx", ["hiss", global_position, -1.0, 0.1, 1.0])
		S.TELL:
			_face(to_p)
			_turn = 8.0
			if st_t >= (0.65 if _whip else 0.45):
				_set_state(S.ATTACK)
				_strike(1 if _whip else 0)
				if not _whip:
					velocity = _fwd() * 6.0
		S.ATTACK:
			_want = _fwd() * (5.0 if st_t < 0.15 and not _whip else 0.0)
			_accel = 30.0
			_turn = 2.0
			if st_t > (0.55 if _whip else 0.35):
				_cool = _rng.randf_range(1.2, 2.2)
				_set_state(S.CHASE)
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_face(away)
			_want = away * RUN
			if st_t > 4.0 and dist > 14.0:
				_provoked = 0.0
				_set_state(S.WANDER)
				_wander_to = home


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	provoke()
	if health.current_health < health.max_health * 0.2 and state != S.FLEE:
		_set_state(S.FLEE)
		return true
	return false


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _cry_death() -> void:
	Net.fx("sfx", ["hiss", global_position, -4.0, 0.05, 0.6])


# ==========================================================================
# Pose: the sprawling walk (body swinging side to side), the tail sweeping, the hiss
# ==========================================================================
func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 5.5 * delta / size_k
	var sway := sin(_gait) * 0.22 * moving
	var whip := 0.0
	if state == S.ATTACK and _whip:
		whip = sin(clampf(st_t / 0.45, 0.0, 1.0) * PI) * 1.4
	elif state == S.TELL and _whip:
		whip = -0.4 * minf(st_t / 0.3, 1.0)
	_body.rotation = Vector3(0, sway + whip * 0.4, 0)
	var hiss := anim_a
	_head.rotation = Vector3(0.15 * hiss, -sway * 1.2, 0)
	_jaw.rotation = Vector3(0.55 * hiss + (0.6 if state == S.ATTACK and not _whip and st_t < 0.2 else 0.0), 0, 0)
	_tongue.scale = Vector3.ONE * (1.0 if fmod(_t, 1.6) < 0.25 or hiss > 0.5 else 0.01)
	for k in range(_tail.size()):
		(_tail[k] as Node3D).rotation = Vector3(0.05, -sway * 0.8 + sin(_t * 2.0 + k * 0.8) * 0.06 + whip * (0.5 + k * 0.15), 0)
	for leg in _legs:
		var s: float = leg["side"]
		var ph := _gait + (0.0 if (leg["front"] == (s > 0.0)) else PI)
		var swing := sin(ph) * 0.5 * moving
		var lift := maxf(0.0, cos(ph)) * 0.35 * moving
		if state in [S.DOWN, S.DEAD]:
			var kick := 1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t / 1.5)
			swing = sin(_t * 12.0 + s) * 0.5 * kick
		(leg["pivot"] as Node3D).rotation = Vector3(0, swing * s, s * lift)
	_body.position.y = BODY_Y + absf(sin(_gait)) * 0.02 * moving
