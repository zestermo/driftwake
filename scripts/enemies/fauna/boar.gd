class_name Boar
extends Creature
## Wild boar of the jungle floor, in herds. It wanders and roots in the leaf
## litter and leaves you be - until you hurt it, crowd it, or touch one of its
## piglets. Then it snorts, paws the ground (the tell: head down, dust off the
## hoof) and CHARGES in a straight line: sidestep and it skids past; let it hit
## a tree and it's dazed. A tusker (the big old male) has a short temper and
## its charge knocks you flat. Piglets (striped) squeal and bolt, and their
## squeals bring the herd.

const RUN := 4.6
const CHARGE := 10.0
const CHARGE_TUSKER := 9.0
const BODY_Y := 0.52

var young := false
var tusker := false
## Boars of a herd answer each other (the spawner's group index).
var herd: int = -1

var _provoked: float = 0.0
var _flee_from := Vector3.ZERO
var _charge_dir := Vector3.ZERO
var _charge_dist: float = 0.0
var _tells: int = 0
var _fx_t: float = 0.0
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "boar"
	young = bool(args.get("young", false))
	tusker = bool(args.get("tusker", false))
	herd = int(args.get("herd", -1))
	hostile = false
	skin_tex = "leather"
	if young:
		size_k = 0.48
		max_hp = 18.0
		xp = 6
		coins = Vector2i(0, 1)
		drops = [["boar_haunch", 0.3, 1]]
	elif tusker:
		size_k = 1.3
		max_hp = 170.0
		xp = 110
		coins = Vector2i(4, 7)
		drops = [["boar_haunch", 0.9, 1], ["tusk", 0.9, 1]]
	else:
		max_hp = 110.0
		xp = 60
		coins = Vector2i(2, 4)
		drops = [["boar_haunch", 0.7, 1], ["tusk", 0.35, 1]]


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.3, 0.7, Vector3(0.7, 0.95, 1.45)]


func _moves() -> Array:
	return [[18.0, 7.5, Vector3(0.85, 0.8, 0.7), Vector3(0, 0.45, -0.8), false, 0.45],
		[26.0, 9.0, Vector3(0.9, 0.85, 0.75), Vector3(0, 0.45, -0.8), true, 0.5]]


# ==========================================================================
# Model: a barrel of a body with a bristly ridge, a wedge head with tusks, four legs
# ==========================================================================
func _build() -> void:
	var v := "young" if young else ("tusker" if tusker else "adult")
	var hide := Color(0.52, 0.33, 0.18) if young else (Color(0.15, 0.11, 0.08) if tusker else Color(0.25, 0.16, 0.1))
	var dark := Color(0.07, 0.05, 0.04)
	var snout := Color(0.5, 0.3, 0.27)
	var ivory := Color(0.93, 0.88, 0.74)
	var stripe := Color(0.9, 0.78, 0.55)
	var skin := _skin()
	var eye := _glow(Color(0.9, 0.45, 0.15))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		var rings := [[-0.64, 0.1, 0.12, 0.0], [-0.52, 0.24, 0.26, 0.02], [-0.18, 0.3, 0.3, 0.02], [0.18, 0.31, 0.33, 0.06],
			[0.44, 0.28, 0.36, 0.1], [0.62, 0.2, 0.26, 0.06]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(8), 1.5, hide, true, true)
		# the bristly ridge along the spine, tallest over the shoulders
		for i in range(9):
			var f := lerpf(-0.3, 0.6, i / 8.0)
			var top := 0.3 + 0.06 * clampf((f + 0.3) / 0.7, 0.0, 1.0) + 0.06 * sin(clampf((f + 0.2) / 0.8, 0.0, 1.0) * PI)
			var hgt := 0.06 + 0.07 * sin(clampf((f + 0.3) / 0.9, 0.0, 1.0) * PI)
			mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.35 + rng.randf_range(-0.1, 0.1)), Vector3(rng.randf_range(-0.01, 0.01), top, -f)),
				Vector3(0.07, hgt, 0.12), 1.0, dark, false, false)
		if young:
			# a piglet's stripes along its flanks
			for s in [-1.0, 1.0]:
				for k in range(3):
					var y := 0.12 - k * 0.1
					mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * (0.3 - absf(y) * 0.25), y + 0.02, -0.02)), Vector3(0.02, 0.035, 0.8), 1.0, stripe, false, false)
		# belly a shade lighter
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.18, 0.0)), Vector3(0.22, 0.12, 0.45), rng, 0.05, 3, 7, 1.0, hide.lightened(0.12)), true)
	_head = _part(_body, "Head", Vector3(0, 0.1, -0.58), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[0.0, 0.17, 0.21, 0.0], [0.2, 0.14, 0.15, -0.05], [0.38, 0.09, 0.09, -0.1], [0.46, 0.085, 0.08, -0.11]],
			MeshBuilder.profile_circle(8), 1.5, hide, false, false)
		# the snout's flat disc
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.11, -0.45)), 0.085, 0.08, 0.04, 8, 1.0, snout, true)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.03, -0.11, -0.495)), Vector3(0.025, 0.03, 0.01), 1.0, dark, false, false)
			# ears: pricked triangles
			var ear := PackedVector2Array([Vector2(-0.05, 0), Vector2(0.05, 0), Vector2(0.01, 0.15)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.45) * Basis(Vector3.RIGHT, 0.3), Vector3(s * 0.11, 0.15, 0.06)), ear, 0.025, 1.0, dark)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.115, 0.05, -0.15)), Vector3(0.03, 0.025, 0.03), 1.0, Color.WHITE, false, false)
			if not young:
				var tk := 1.4 if tusker else 1.0
				mb.add_tube(skin, MeshBuilder.curve_points(Vector3(s * 0.07, -0.13, -0.34), Vector3(s * 0.15, -0.14, -0.44), Vector3(s * 0.13, -0.13 + 0.12 * tk, -0.44 - 0.03 * tk), 5),
					0.024 * tk, 0.006, 5, 1.0, ivory, true, false)
		# the shaggy cheeks and brow
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.02)), Vector3(0.16, 0.1, 0.14), rng, 0.15, 3, 6, 1.0, dark))
	_tail = _part(_body, "Tail", Vector3(0, 0.08, 0.64), v + "_tail", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		mb.add_tube(skin, MeshBuilder.curve_points(Vector3.ZERO, Vector3(0, -0.04, 0.12), Vector3(0, -0.24, 0.12), 4), 0.025, 0.01, 4, 1.0, dark))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(s * 0.17, -0.1, -0.34 if front else 0.4)
		var leg := _part(_body, "Leg%d" % i, at, v + ("_fleg" if front else "_bleg"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.36, 0)), 0.05, 0.095 if front else 0.115, 0.4, 6, 1.0, hide.darkened(0.2), false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.38, -0.01)), Vector3(0.085, 0.06, 0.095), 1.0, dark, false, false))
		_legs.append({"pivot": leg, "side": s, "front": front, "pair": (i + (0 if front else 1)) % 2})


# ==========================================================================
# Brain
# ==========================================================================
## Angry: comes for whoever it saw (a herd-mate's alarm, a blow, crowding).
func provoke(_by: Node = null) -> void:
	if state == S.DEAD:
		return
	if young:
		scare()
		return
	var was := _provoked > 0.0
	_provoked = 14.0
	if not was and state in [S.IDLE, S.WANDER, S.FLEE]:
		_set_state(S.NOTICE)
		Net.fx("sfx", ["grunt", global_position, 0.0, 0.08, 0.75 if tusker else 0.95])


## A piglet's fright: it bolts.
func scare() -> void:
	if state in [S.DEAD, S.DOWN] or not young:
		return
	var p := _target()
	_flee_from = p.global_position if p else global_position + _fwd()
	if state != S.FLEE:
		_set_state(S.FLEE)
		Net.fx("sfx", ["squeal", global_position, -2.0, 0.1, 1.5])


## The herd hears it: the grown ones come, the young ones run.
func _alarm() -> void:
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is Boar and f != self and (f as Boar).herd == herd and (f as Node3D).global_position.distance_to(global_position) < 22.0:
			(f as Boar).provoke()


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	anim_a = move_toward(anim_a, 1.0 if (state == S.WANDER and _wander_wait > 0.6) else 0.0, delta * 3.0)


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if young:
				if _player_ok(p) and dist < 6.5:
					scare()
					_alarm()
					return
				_wander(1.1, Vector2(1.0, 4.0))
				return
			if _player_ok(p) and dist < (8.5 if tusker else 3.8):
				provoke(p)
				_alarm()
				return
			if _provoked > 0.0 and _player_ok(p):
				_set_state(S.NOTICE)
				return
			_wander(0.9, Vector2(2.0, 7.0))
		S.NOTICE:
			_face(to_p)
			_turn = 12.0
			if st_t > 0.45:
				_tells = 0
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 26.0 or flat(global_position - home).length() > 40.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			if dist > 10.0:
				_want = to_p.normalized() * RUN
			elif dist < 2.8:
				_want = -to_p.normalized() * 2.0
			elif _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["grunt", global_position, -1.0, 0.1, 0.7 if tusker else 0.85])
		S.TELL:
			var len := (0.95 if tusker else 0.75) * (0.7 if _tells > 0 else 1.0)
			if st_t < len * 0.7:
				_face(to_p)
			_turn = 10.0
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.16
				Net.fx("dust", [global_position + _fwd() * 0.4 * size_k, 3, 0.35 * size_k])
			if st_t >= len:
				_tells += 1
				_charge_dir = _fwd()
				_charge_dist = 0.0
				_set_state(S.ATTACK)
				_strike(1 if tusker else 0)
				velocity = _charge_dir * _charge_speed()
				Net.fx("sfx", ["squeal", global_position, 0.0, 0.08, 0.7 if tusker else 0.85])
		S.ATTACK:
			_want = _charge_dir * _charge_speed()
			_accel = 50.0
			_turn = 3.0
			_charge_dist += _charge_speed() * delta
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.07
				Net.fx("dust", [global_position, 2, 0.45 * size_k])
			if not hitbox.hit_targets.is_empty():
				velocity = -_charge_dir * 2.5 + Vector3.UP * 2.0
				_daze_len = 0.5
				_cool = 1.2
				_set_state(S.RECOVER)
			elif is_on_wall() and st_t > 0.08:
				velocity = -_charge_dir * 2.5 + Vector3.UP * 2.8
				Net.fx("sfx", ["thud", global_position, 0.0, 0.08, 0.8])
				Net.fx("sparkle", [global_position + Vector3(0, 0.8 * size_k, 0) + _charge_dir * 0.5, 10, Color(1.0, 0.95, 0.6)])
				Net.fx("dust_ring", [global_position, 10, 0.7])
				_daze_len = 1.8
				_set_state(S.RECOVER)
			elif _charge_dist > 11.0 or st_t > 1.3:
				_daze_len = 0.55
				_cool = 0.6
				_set_state(S.RECOVER)
		S.FLEE:
			var away := _flee_dir(_flee_from)
			away = away.rotated(Vector3.UP, sin(_t * 5.0) * 0.5)
			_face(away)
			_want = away * (5.4 if young else RUN)
			_turn = 10.0
			if p and _flee_from.distance_to(p.global_position) > 0.5 and dist < 8.0:
				_flee_from = p.global_position
			if st_t > 3.0 and dist > 12.0:
				_set_state(S.WANDER)
				_wander_to = home


func _charge_speed() -> float:
	return CHARGE_TUSKER if tusker else CHARGE


func _after_stun() -> void:
	if young:
		scare()
	else:
		_set_state(S.CHASE)


func _after_daze() -> void:
	if young:
		scare()
	elif _provoked > 0.0:
		_cool = maxf(_cool, 0.5)
		_set_state(S.CHASE)
	else:
		_set_state(S.WANDER)


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	if young:
		_alarm()
	else:
		provoke(attacker)
		_alarm()
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["squeal", global_position, 0.0, 0.05, 1.3 if young else 0.65])


# ==========================================================================
# Pose: trot, gallop on the charge, rooting, pawing, dazed sway
# ==========================================================================
func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	var charging := state == S.ATTACK or (state == S.FLEE and hs > 3.0)
	_gait += hs * (2.6 if charging else 4.2) * delta / maxf(size_k, 0.7)
	var root := anim_a
	var head_pitch := root * 0.75 + sin(_t * 9.0) * 0.08 * root
	var head_yaw := sin(_t * 0.8) * 0.25 * (1.0 - root)
	var body_pitch := root * 0.1
	var bob := 0.0
	match state:
		S.NOTICE:
			head_pitch = -0.3
		S.TELL:
			head_pitch = 0.4
			body_pitch = 0.12 + sin(_t * 30.0) * 0.015
		S.ATTACK:
			head_pitch = 0.35
			body_pitch = 0.06
			bob = absf(sin(_gait)) * 0.05
		S.RECOVER:
			head_pitch = 0.2
			head_yaw = sin(_t * 4.0) * 0.45
		S.FLEE:
			head_pitch = -0.1
			bob = absf(sin(_gait)) * 0.04
		S.DOWN, S.DEAD:
			head_pitch = 0.1
			head_yaw = 0.0
	_body.rotation = Vector3(-body_pitch, 0, 0)
	_body.position.y = BODY_Y + bob
	_head.rotation = Vector3(-head_pitch, head_yaw, 0)
	_tail.rotation = Vector3(0.4 + sin(_t * (14.0 if charging else 3.0)) * 0.25, sin(_t * 5.0) * 0.4, 0)
	for leg in _legs:
		var ph := _gait + (PI if int(leg["pair"]) == 1 else 0.0)
		if charging:
			ph = _gait * 1.0 + (0.0 if leg["front"] else PI * 0.6) + (0.25 if float(leg["side"]) > 0.0 else 0.0)
		var swing := sin(ph) * (0.75 if charging else 0.5) * moving
		if state == S.TELL and leg["front"] and float(leg["side"]) > 0.0:
			swing = sin(_t * 13.0) * 0.6 - 0.2
		elif state in [S.DOWN, S.DEAD]:
			var kick := 1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t / 1.5)
			swing = sin(_t * 15.0 + float(leg["side"]) * 2.0 + (1.0 if leg["front"] else 0.0)) * 0.5 * kick + 0.3
		(leg["pivot"] as Node3D).rotation = Vector3(swing, 0, 0)
	# rooting kicks up the leaf litter (here only: it's only for looks)
	if root > 0.8 and lod == LOD_FULL and fmod(_t, 0.7) < delta:
		FX.dust(_head.global_position + _fwd() * 0.45 * size_k + Vector3.DOWN * 0.5 * size_k, 2, 0.3 * size_k)
