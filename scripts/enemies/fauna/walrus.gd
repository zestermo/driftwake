class_name Walrus
extends Creature
## Walruses hauled out on the shore in a colony: great wrinkled lumps lolling on the
## shingle, a calf or two among them. They mind their own business; walk into the colony
## and the bull rears up bellowing (the tell: head high, tusks out), then heaves at you
## and stabs down with its tusks. It's slow on land and quick to tire; calves flop
## away. Morphs: brown, pink-grey, old and pale.

const HEAVE := 2.6
const LUNGE := 6.5
const BODY_Y := 0.55

var calf := false
var bull := false
var colony: int = -1
var morph: int = 0

var _provoked: float = 0.0
var _flee_from := Vector3.ZERO
var _lunge_dir := Vector3.ZERO
var _body: Node3D
var _head: Node3D
var _flippers: Array = []
var _tail: Node3D


func _setup(args: Dictionary) -> void:
	kind = "walrus"
	calf = bool(args.get("calf", false))
	bull = bool(args.get("lead", false))
	colony = int(args.get("pack", -1))
	morph = int(args.get("morph", 0))
	hostile = false
	skin_tex = "leather"
	if calf:
		size_k = 0.5
		max_hp = 30.0
		xp = 8
		coins = Vector2i(0, 1)
	elif bull:
		size_k = 1.35
		max_hp = 240.0
		xp = 120
		coins = Vector2i(4, 8)
		drops = [["tusk", 0.9, 2]]
	else:
		max_hp = 150.0
		xp = 60
		coins = Vector2i(2, 4)
		drops = [["tusk", 0.4, 1]]


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.55, 1.0, Vector3(1.1, 1.1, 2.0)]


func _moves() -> Array:
	return [[20.0, 7.0, Vector3(1.1, 0.9, 1.0), Vector3(0, 0.5, -1.1), false, 0.5],
		[30.0, 9.0, Vector3(1.3, 1.0, 1.2), Vector3(0, 0.5, -1.2), true, 0.6]]


func _build() -> void:
	var hides := [Color(0.48, 0.32, 0.24), Color(0.62, 0.48, 0.44), Color(0.68, 0.62, 0.56)]
	var hide: Color = hides[morph % 3]
	var dark := hide.darkened(0.4)
	var ivory := Color(0.93, 0.9, 0.8)
	var v := "%d%s" % [morph % 3, "_calf" if calf else ""]
	var skin := _skin()
	var eye := _glow(Color(0.2, 0.1, 0.06))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		var rings := [[-0.8, 0.2, 0.22, 0.05], [-0.65, 0.42, 0.45, 0.0], [-0.25, 0.55, 0.52, -0.02], [0.2, 0.5, 0.45, -0.08],
			[0.6, 0.32, 0.28, -0.2], [0.85, 0.12, 0.1, -0.3]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(9), 1.2, hide, true, true)
		# wrinkled folds round the neck and shoulders
		for k in range(5):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.05 - k * 0.02, -0.6 + k * 0.12)), Vector3(0.5 - k * 0.02, 0.06, 0.05), rng, 0.1, 2, 9, 1.0, hide.darkened(0.15)), true)
	_head = _part(_body, "Head", Vector3(0, 0.25, -0.82), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.12)), Vector3(0.24, 0.2, 0.22), rng, 0.08, 3, 7, 1.0, hide)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.07, -0.3)), Vector3(0.2, 0.12, 0.1), rng, 0.1, 3, 7, 1.0, hide.lightened(0.15))
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.15, 0.08, -0.22)), Vector3(0.03, 0.03, 0.03), 1.0, Color.WHITE, false, false)
			if not calf:
				mb.add_tube(skin, PackedVector3Array([Vector3(s * 0.07, -0.12, -0.33), Vector3(s * 0.08, -0.35, -0.35), Vector3(s * 0.07, -0.58, -0.3)]), 0.035, 0.012, 5, 1.0, ivory)
			for k in range(4):
				mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * (0.04 + k * 0.035), -0.1, -0.395)), Vector3(0.008, 0.008, 0.05), 1.0, dark, false, false))
	_tail = _part(_body, "Tail", Vector3(0, -0.25, 0.85), v + "_tail", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for s in [-1.0, 1.0]:
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.12, 0, 0.1)), PackedVector2Array([Vector2(-0.12, 0), Vector2(0.12, 0), Vector2(0.18 * s, 0.35)]), 0.04, 1.0, dark))
	for s in [-1.0, 1.0]:
		var fl := _part(_body, "Flipper%d" % int(s + 1.0), Vector3(s * 0.45, -0.35, -0.45), v + "_flipper", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0)), PackedVector2Array([Vector2(-0.08, 0), Vector2(0.08, 0), Vector2(0.14, 0.38), Vector2(-0.12, 0.38)]), 0.04, 1.0, dark))
		_flippers.append([fl, s])


func provoke(_by: Node = null) -> void:
	if state == S.DEAD:
		return
	if calf:
		_scare()
		return
	var was := _provoked > 0.0
	_provoked = 12.0
	if not was and state in [S.IDLE, S.WANDER, S.FLEE]:
		_set_state(S.NOTICE)
		Net.fx("sfx", ["roar", global_position, -2.0, 0.1, 0.55 if bull else 0.7])


func _scare() -> void:
	var p := _target()
	_flee_from = p.global_position if p else global_position + _fwd()
	if state != S.FLEE:
		_set_state(S.FLEE)


func _alarm() -> void:
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is Walrus and f != self and (f as Walrus).colony == colony and (f as Node3D).global_position.distance_to(global_position) < 20.0:
			(f as Walrus).provoke()


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	anim_a = move_toward(anim_a, 1.0 if state in [S.NOTICE, S.TELL] else 0.0, delta * 4.0)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), 7.0 if bull else 4.0):
				provoke(p)
				_alarm()
				return
			_wander(0.5, Vector2(0.5, 3.0))
		S.NOTICE:
			_face(to_p)
			_turn = 4.0
			if st_t > 0.9:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 16.0 or flat(global_position - home).length() > 18.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 3.0
			_want = to_p.normalized() * HEAVE * (0.6 + 0.4 * absf(sin(_t * 4.0)))
			if dist < 2.6 * size_k and _cool <= 0.0:
				_set_state(S.TELL)
		S.TELL:
			_face(to_p)
			_turn = 3.0
			if st_t >= 0.7:
				_lunge_dir = _fwd()
				_set_state(S.ATTACK)
				_strike(1 if bull else 0)
				velocity = _lunge_dir * LUNGE
				Net.fx("sfx", ["thud", global_position, -2.0, 0.08, 0.6])
		S.ATTACK:
			_want = _lunge_dir * LUNGE * maxf(0.0, 1.0 - st_t / 0.4)
			_accel = 30.0
			if st_t > 0.4:
				Net.fx("puff_ring", [global_position + _lunge_dir * 1.0 * size_k, "snow", 5, 0.4, 0.9 * size_k, 0.7, Color.WHITE, 3.0])
				_cool = _rng.randf_range(1.8, 2.8)
				_daze_len = 0.9
				_set_state(S.RECOVER)
		S.FLEE:
			var away := _flee_dir(_flee_from)
			_face(away)
			_want = away * HEAVE * 1.3
			if st_t > 3.0:
				_set_state(S.WANDER)


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	provoke(attacker)
	_alarm()
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["roar", global_position, -3.0, 0.05, 0.5])


func _pose(_delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var rear := anim_a
	var heave := sin(_t * 8.0) * clampf(hs, 0.0, 1.0)
	var loll := sin(_t * 0.6 + float(get_instance_id() % 7)) * (1.0 - clampf(hs, 0.0, 1.0)) * (1.0 - rear)
	_body.rotation = Vector3(rear * 0.55 + heave * 0.08, 0, loll * 0.12)
	_body.position.y = BODY_Y + rear * 0.15 + absf(heave) * 0.06
	var stab := -0.9 if state == S.ATTACK and st_t < 0.25 else 0.0
	_head.rotation = Vector3(-rear * 0.35 + stab + loll * 0.1, sin(_t * 0.9) * 0.2 * (1.0 - rear), 0)
	_tail.rotation = Vector3(sin(_t * 2.0) * 0.15, 0, 0)
	for f in _flippers:
		(f[0] as Node3D).rotation = Vector3(heave * 0.6, 0, float(f[1]) * (0.2 + rear * 0.4))
