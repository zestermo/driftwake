class_name SnowBear
extends Creature
## White bears of the high pines and the snowfields, alone or a sow with a cub. A bear
## shambles about its ground and pays you no heed at a distance; get close (or near its
## cub) and it rises on its hind legs and roars (the tell), drops and comes at a lope,
## then swipes twice (left, right) and, if you're still in front of it, rears again and
## slams down both paws: a ring of snow that knocks you flat. Back off and it lets you
## go. Cubs tumble about after their mother and run from you. Morphs: white, cream, grey.

const LOPE := 6.2
const BODY_Y := 0.95

var cub := false
var morph: int = 0
var family: int = -1

var _provoked: float = 0.0
var _combo: int = 0
var _flee_from := Vector3.ZERO
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "snow_bear"
	cub = bool(args.get("calf", false))
	morph = int(args.get("morph", 0))
	family = int(args.get("pack", -1))
	hostile = false
	skin_tex = "fur"
	if cub:
		size_k = 0.45
		max_hp = 40.0
		xp = 12
		coins = Vector2i(0, 1)
	else:
		size_k = 1.0
		max_hp = 320.0
		xp = 180
		coins = Vector2i(5, 9)
		drops = [["boar_haunch", 0.8, 2]]


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func vine_weight() -> String:
	return "light" if cub else "heavy"


func _body_shape() -> Array:
	return [0.6, 1.4, Vector3(1.2, 1.5, 2.2)]


func _moves() -> Array:
	return [[22.0, 6.0, Vector3(1.6, 1.2, 1.2), Vector3(-0.3, 0.9, -1.2), false, 0.4],
		[22.0, 6.0, Vector3(1.6, 1.2, 1.2), Vector3(0.3, 0.9, -1.2), false, 0.4],
		[34.0, 9.0, Vector3(3.2, 1.2, 3.0), Vector3(0, 0.6, -1.3), true, 0.7]]


func _build() -> void:
	var coats := [Color(0.93, 0.93, 0.9), Color(0.9, 0.85, 0.72), Color(0.7, 0.71, 0.72)]
	var coat: Color = coats[morph % 3]
	var dark := Color(0.08, 0.07, 0.07)
	var v := "%d%s" % [morph % 3, "_cub" if cub else ""]
	var skin := _skin()
	var eye := _glow(Color(0.2, 0.1, 0.05))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		var rings := [[-0.95, 0.25, 0.28, 0.1], [-0.8, 0.5, 0.55, 0.06], [-0.4, 0.62, 0.66, 0.1], [0.1, 0.58, 0.6, 0.05],
			[0.55, 0.55, 0.58, 0.06], [0.85, 0.35, 0.4, 0.0]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(9), 1.0, coat, true, true)
		# the shoulder hump and a shaggy fringe under the belly
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.45)), Vector3(0.42, 0.25, 0.4), rng, 0.15, 3, 7, 1.0, coat)
		for k in range(7):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.3, 0.3), -0.52, -0.6 + k * 0.2)), Vector3(0.12, 0.12, 0.12), rng, 0.3, 2, 5, 1.0, coat.darkened(0.08)), true)
	_head = _part(_body, "Head", Vector3(0, 0.35, -1.0), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.1)), Vector3(0.3, 0.28, 0.3), rng, 0.08, 3, 7, 1.0, coat)
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.06, -0.3))
		mb.add_loft(skin, xf, [[0.0, 0.17, 0.15, 0.0], [0.2, 0.12, 0.11, -0.02], [0.3, 0.09, 0.08, -0.03]], MeshBuilder.profile_circle(7), 1.5, coat, false, true)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.07, -0.62)), Vector3(0.1, 0.07, 0.04), 1.0, dark, false, false)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.2, 0.25, 0.0)), Vector3(0.08, 0.08, 0.05), rng, 0.1, 2, 5, 1.0, coat)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.12, 0.08, -0.3)), Vector3(0.04, 0.035, 0.03), 1.0, Color.WHITE, false, false))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(s * 0.38, -0.2, -0.6 if front else 0.6)
		var leg := _part(_body, "Leg%d" % i, at, v + ("_fleg" if front else "_bleg"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.72, 0)), 0.17, 0.25, 0.8, 7, 1.0, coat.darkened(0.06), false)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.72, -0.08)), Vector3(0.2, 0.08, 0.26), rng, 0.08, 2, 6, 1.0, coat.darkened(0.1), 0.0)
			for k in range(4):
				mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(-0.12 + k * 0.08, -0.7, -0.33)), Vector3(0.03, 0.03, 0.1), 1.0, dark, false, false))
		_legs.append({"pivot": leg, "side": s, "front": front})


func provoke(_by: Node = null) -> void:
	if state == S.DEAD:
		return
	if cub:
		_scare()
		return
	var was := _provoked > 0.0
	_provoked = 15.0
	if not was and state in [S.IDLE, S.WANDER]:
		_set_state(S.NOTICE)
		Net.fx("sfx", ["roar", global_position, 0.0, 0.08, 0.8])


func _scare() -> void:
	var p := _target()
	_flee_from = p.global_position if p else global_position + _fwd()
	if state != S.FLEE:
		_set_state(S.FLEE)


func _family_alarm() -> void:
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is SnowBear and f != self and (f as SnowBear).family == family and (f as Node3D).global_position.distance_to(global_position) < 30.0:
			(f as SnowBear).provoke()


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	var rear := 1.0 if state == S.NOTICE and st_t < 1.1 else (1.0 if state == S.TELL and _combo == 2 else 0.0)
	anim_a = move_toward(anim_a, rear, delta * 5.0)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), 2.5 if cub else 7.0):
				provoke(p)
				_family_alarm()
				return
			_wander(0.4 if cub else 1.0, Vector2(2.0, 8.0))
		S.NOTICE:
			_face(to_p)
			_turn = 5.0
			if st_t > 1.4:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 24.0 or flat(global_position - home).length() > 36.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 5.0
			_want = to_p.normalized() * LOPE
			if dist < 2.6 and _cool <= 0.0:
				_combo = 0
				_set_state(S.TELL)
		S.TELL:
			_face(to_p)
			_turn = 7.0
			if st_t >= (0.75 if _combo == 2 else 0.38):
				_set_state(S.ATTACK)
				_strike(_combo)
				velocity = _fwd() * (3.0 if _combo < 2 else 1.0)
				if _combo == 2:
					Net.fx("sfx", ["thud", global_position, 0.0, 0.08, 0.6])
					Net.fx("puff_ring", [global_position + _fwd() * 1.2, "snow", 8, 0.6, 1.2, 0.8, Color.WHITE, 5.0])
				else:
					Net.fx("sfx", ["whoosh_big", global_position, -4.0, 0.1, 0.7])
		S.ATTACK:
			_want = Vector3.ZERO
			_accel = 12.0
			if st_t > 0.3:
				hitbox.deactivate()
				var in_front := dist < 3.2 and to_p.normalized().dot(_fwd()) > 0.3
				if _combo < 2 and (_combo == 0 or in_front):
					_combo += 1
					_set_state(S.TELL)
				else:
					_cool = _rng.randf_range(1.6, 2.4)
					_daze_len = 1.1 if _combo == 2 else 0.5
					_set_state(S.RECOVER)
		S.FLEE:
			var away := _flee_dir(_flee_from)
			_face(away)
			_want = away * 4.5
			if st_t > 3.0:
				_set_state(S.WANDER)


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _can_knock() -> bool:
	return cub


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	provoke(attacker)
	_family_alarm()
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["roar", global_position, -2.0, 0.05, 0.6 if not cub else 1.4])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	_gait += hs * 2.4 * delta / maxf(size_k, 0.7)
	var rear := anim_a
	var swipe := 0.0
	var side := 0.0
	if state == S.TELL and _combo < 2:
		swipe = -0.6 * clampf(st_t / 0.38, 0.0, 1.0)
		side = -1.0 if _combo == 0 else 1.0
	elif state == S.ATTACK and _combo < 2:
		swipe = lerpf(-0.6, 1.2, clampf(st_t / 0.15, 0.0, 1.0))
		side = -1.0 if _combo == 0 else 1.0
	_body.rotation = Vector3(rear * 1.0, side * swipe * 0.15, 0)
	_body.position.y = BODY_Y + rear * 0.55 + absf(sin(_gait)) * 0.06 * moving
	_head.rotation = Vector3(-rear * 0.7 + sin(_t * 0.8) * 0.1 * (1.0 - moving), side * swipe * 0.3, 0)
	for leg in _legs:
		var sw := sin(_gait + (0.0 if leg["front"] else PI) + (PI * 0.5 if float(leg["side"]) > 0.0 else 0.0)) * 0.45 * moving
		if leg["front"]:
			sw -= rear * 1.1
			if side != 0.0 and float(leg["side"]) == side:
				sw = -swipe * 1.4
		(leg["pivot"] as Node3D).rotation = Vector3(sw, 0, 0)
