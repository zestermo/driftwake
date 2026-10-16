class_name Wolf
extends Creature
## Snow wolves, in packs under the pines. A pack pads about its ground nose down; come
## near and the lead howls (the tell for the whole pack), then they circle you at a
## lunge's length, each a slot on the ring, and take turns: one crouches (the tell: head
## low, haunches up) and LUNGES for a bite while the rest keep circling. Hurt one and
## the pack closes; a beaten wolf limps off. The lead is bigger, white about the ruff,
## and its bite knocks you down. Morphs: grey, white, dark.

const RUN := 6.8
const LUNGE := 12.0
const RING := 5.4
const BODY_Y := 0.62
## One lunge at a time per pack: the next is free this many seconds after the last.
const TURN_GAP := 1.1

var pack: int = -1
var lead := false
var morph: int = 0

static var _pack_next := {}

var _provoked: float = 0.0
var _slot: float = 0.0
var _lunge_dir := Vector3.ZERO
var _fx_t: float = 0.0
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _tail: Node3D
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "wolf"
	pack = int(args.get("pack", -1))
	lead = bool(args.get("lead", false))
	morph = int(args.get("morph", 0))
	hostile = true
	skin_tex = "fur"
	if lead:
		size_k = 1.3
		max_hp = 150.0
		xp = 90
		coins = Vector2i(3, 6)
	else:
		max_hp = 75.0
		xp = 40
		coins = Vector2i(1, 3)


func in_combat() -> bool:
	return _provoked > 0.0 and state != S.DEAD


func _body_shape() -> Array:
	return [0.28, 0.8, Vector3(0.6, 0.95, 1.5)]


func _moves() -> Array:
	return [[13.0, 4.5, Vector3(0.75, 0.7, 0.8), Vector3(0, 0.55, -0.85), false, 0.35],
		[19.0, 6.5, Vector3(0.85, 0.8, 0.9), Vector3(0, 0.6, -0.9), true, 0.45]]


# ==========================================================================
# Model: a lean deep-chested body, long legs, a long snout and pricked ears, a brush of a tail
# ==========================================================================
func _build() -> void:
	var coats := [[Color(0.5, 0.5, 0.52), Color(0.86, 0.86, 0.84), Color(0.28, 0.27, 0.28)],
		[Color(0.88, 0.89, 0.9), Color(0.97, 0.97, 0.96), Color(0.62, 0.63, 0.66)],
		[Color(0.24, 0.23, 0.24), Color(0.55, 0.53, 0.5), Color(0.1, 0.1, 0.1)]]
	var c: Array = coats[morph % 3]
	var back: Color = c[0]
	var belly: Color = c[1]
	var dark: Color = c[2]
	var ruff := belly if lead else back.lerp(belly, 0.4)
	var v := "%d%s" % [morph % 3, "_lead" if lead else ""]
	var skin := _skin()
	var eye := _glow(Color(1.0, 0.82, 0.3))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		var rings := [[-0.55, 0.08, 0.1, 0.0], [-0.45, 0.17, 0.2, 0.02], [-0.15, 0.2, 0.22, 0.0], [0.2, 0.2, 0.27, 0.04],
			[0.42, 0.18, 0.28, 0.06], [0.58, 0.12, 0.2, 0.05]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(8), 1.5, back, true, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.12, -0.1)), Vector3(0.15, 0.1, 0.4), rng, 0.05, 3, 7, 1.0, belly)
		# the ruff: shaggy fur heaped over the shoulders and throat
		for k in range(6):
			var a := -0.9 + k * 0.36
			mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(sin(a) * 0.17, cos(a) * 0.12 + 0.04, -0.42 + absf(a) * 0.05)),
				Vector3(0.1, 0.14, 0.16), rng, 0.25, 3, 5, 1.0, ruff.darkened(rng.randf() * 0.15))
		# a dark saddle down the back
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.05)), Vector3(0.1, 0.06, 0.38), rng, 0.15, 3, 6, 1.0, dark), true)
	_head = _part(_body, "Head", Vector3(0, 0.16, -0.58), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[0.0, 0.13, 0.14, 0.0], [0.14, 0.12, 0.12, -0.01], [0.26, 0.07, 0.07, -0.04], [0.4, 0.045, 0.05, -0.05]],
			MeshBuilder.profile_circle(7), 1.5, back, true, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, -0.06)), Vector3(0.12, 0.07, 0.12), rng, 0.15, 3, 6, 1.0, belly)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.42)), Vector3(0.05, 0.04, 0.03), 1.0, Color(0.05, 0.05, 0.05), false, false)
		for s in [-1.0, 1.0]:
			var ear := PackedVector2Array([Vector2(-0.05, 0), Vector2(0.05, 0), Vector2(0.0, 0.14)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(s * 0.07, 0.1, 0.03)), ear, 0.02, 1.0, dark)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.065, 0.05, -0.13)), Vector3(0.03, 0.02, 0.02), 1.0, Color.WHITE, false, false))
	_jaw = _part(_head, "Jaw", Vector3(0, -0.07, -0.12), v + "_jaw", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.13)), Vector3(0.07, 0.035, 0.24), 1.0, belly, false, false)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.025, 0.02, -0.22)), Vector3(0.012, 0.03, 0.012), 1.0, Color(0.95, 0.93, 0.85), false, false))
	_tail = _part(_body, "Tail", Vector3(0, 0.1, 0.58), v + "_tail", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var pts := MeshBuilder.curve_points(Vector3.ZERO, Vector3(0, -0.05, 0.25), Vector3(0, -0.4, 0.4), 5)
		mb.add_tube(skin, pts, 0.07, 0.04, 5, 1.0, back)
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.9), Vector3(0, -0.3, 0.36)), Vector3(0.07, 0.15, 0.07), rng, 0.2, 3, 5, 1.0, dark))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(s * 0.12, -0.08, -0.36 if front else 0.42)
		var leg := _part(_body, "Leg%d" % i, at, v + ("_fleg" if front else "_bleg"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			if front:
				mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0)), 0.035, 0.065, 0.52, 6, 1.0, back, false)
			else:
				mb.add_tube(skin, PackedVector3Array([Vector3(0, 0.02, 0), Vector3(0, -0.22, 0.09), Vector3(0, -0.5, 0.0)]), 0.08, 0.035, 6, 1.0, back)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.52, -0.03)), Vector3(0.07, 0.04, 0.1), 1.0, dark, false, false))
		_legs.append({"pivot": leg, "side": s, "front": front, "pair": (i + (0 if front else 1)) % 2})


# ==========================================================================
# Brain
# ==========================================================================
## The pack hears it: every wolf of the pack comes.
func provoke(_by: Node = null) -> void:
	if state == S.DEAD:
		return
	var was := _provoked > 0.0
	_provoked = 16.0
	if not was and state in [S.IDLE, S.WANDER]:
		_set_state(S.NOTICE)


func _alarm() -> void:
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is Wolf and f != self and (f as Wolf).pack == pack and (f as Node3D).global_position.distance_to(global_position) < 30.0:
			(f as Wolf).provoke()


## Whether it's this pack's turn to lunge (one at a time), claiming it if so.
func _claim_turn() -> bool:
	var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	if now < float(_pack_next.get(pack, 0.0)):
		return false
	_pack_next[pack] = now + TURN_GAP
	return true


func _tick(delta: float) -> void:
	_provoked = maxf(_provoked - delta, 0.0)
	var crouch := 1.0 if state == S.TELL else 0.0
	anim_a = move_toward(anim_a, crouch, delta * 6.0)
	anim_b = move_toward(anim_b, 1.0 if (state == S.WANDER and _wander_wait > 0.5) else 0.0, delta * 2.0)


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), 14.0 if lead else 10.0):
				provoke(p)
				_alarm()
				return
			if _provoked > 0.0 and _player_ok(p):
				_set_state(S.NOTICE)
				return
			_wander(1.4, Vector2(2.0, 9.0))
		S.NOTICE:
			_face(to_p)
			_turn = 10.0
			if st_t < delta * 1.5 and lead:
				Net.fx("sfx", ["howl", global_position, 0.0, 0.08, 0.9])
			if st_t > (0.9 if lead else 0.5):
				_slot = float(get_instance_id() % 997) / 997.0 * TAU
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or _provoked <= 0.0 or dist > 32.0 or flat(global_position - home).length() > 48.0:
				_provoked = 0.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			# a place on the ring round the captain, drifting round it
			var a := _slot + _t * 0.5
			var spot := p.global_position + Vector3(cos(a), 0, sin(a)) * RING
			var to_spot := flat(spot - global_position)
			if to_spot.length() > 0.6:
				_want = to_spot.normalized() * minf(RUN, to_spot.length() * 3.0)
			_face(to_p if dist < RING + 2.0 else to_spot)
			_turn = 9.0
			if dist < RING + 1.5 and _cool <= 0.0 and _claim_turn():
				_set_state(S.TELL)
				Net.fx("sfx", ["grunt", global_position, -3.0, 0.1, 1.3])
		S.TELL:
			_face(to_p)
			_turn = 12.0
			if st_t >= (0.5 if lead else 0.4):
				_lunge_dir = _fwd()
				_set_state(S.ATTACK)
				_strike(1 if lead else 0)
				velocity = _lunge_dir * LUNGE + Vector3.UP * 2.5
				Net.fx("puff", [global_position, "snow", 3, 0.7 * size_k, 0.6, Color.WHITE, 0.4, Vector3.UP])
		S.ATTACK:
			_want = _lunge_dir * LUNGE * maxf(0.0, 1.0 - st_t / 0.45)
			_accel = 40.0
			_turn = 2.0
			if not hitbox.hit_targets.is_empty() or st_t > 0.45:
				_cool = _rng.randf_range(1.6, 2.6)
				_daze_len = 0.35
				_set_state(S.RECOVER)
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_face(away)
			_want = away * RUN * 0.8
			if st_t > 4.0 and dist > 16.0:
				_provoked = 0.0
				_set_state(S.WANDER)
				_wander_to = home


func _after_daze() -> void:
	_set_state(S.CHASE if _provoked > 0.0 else S.WANDER)


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	provoke(attacker)
	_alarm()
	if not lead and health.current_health < health.max_health * 0.25 and state != S.FLEE:
		_set_state(S.FLEE)
		Net.fx("sfx", ["squeal", global_position, -2.0, 0.1, 1.6])
		return true
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["howl", global_position, -4.0, 0.05, 1.4])


# ==========================================================================
# Pose: trot, gallop, the crouch before a lunge, sniffing, the dazed shake
# ==========================================================================
func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	var running := hs > 4.0
	_gait += hs * (2.2 if running else 3.6) * delta / maxf(size_k, 0.7)
	var crouch := anim_a
	var sniff := anim_b
	var head_pitch := sniff * 0.7 + sin(_t * 7.0) * 0.05 * sniff - crouch * 0.1
	var body_pitch := crouch * -0.12
	var jaw := 0.0
	match state:
		S.NOTICE:
			head_pitch = -0.6 if lead else -0.2
			jaw = 0.5 if lead and st_t < 0.8 else 0.0
		S.TELL:
			jaw = 0.25
		S.ATTACK:
			head_pitch = -0.15
			jaw = 0.7
		S.CHASE:
			head_pitch = 0.1
		S.RECOVER:
			head_pitch = 0.15
		S.DOWN, S.DEAD:
			head_pitch = 0.2
	_body.rotation = Vector3(body_pitch, 0, 0)
	_body.position.y = BODY_Y - crouch * 0.14 + (absf(sin(_gait)) * 0.05 if running else 0.0)
	_head.rotation = Vector3(-head_pitch, sin(_t * 0.7) * 0.2 * (1.0 - moving), 0)
	_jaw.rotation = Vector3(jaw, 0, 0)
	_tail.rotation = Vector3(-0.3 + (0.6 if state in [S.CHASE, S.TELL, S.ATTACK] else 0.0) + sin(_t * 4.0) * 0.1, sin(_t * 3.0) * 0.3, 0)
	for leg in _legs:
		var ph := _gait + (PI if int(leg["pair"]) == 1 else 0.0)
		if running:
			ph = _gait + (0.0 if leg["front"] else PI * 0.7) + (0.3 if float(leg["side"]) > 0.0 else 0.0)
		var swing := sin(ph) * (0.8 if running else 0.5) * moving
		if state == S.TELL:
			swing = (-0.35 if leg["front"] else 0.5)
		elif state in [S.DOWN, S.DEAD]:
			var kick := 1.0 if state == S.DOWN else maxf(0.0, 1.0 - _dead_t / 1.5)
			swing = sin(_t * 14.0 + float(leg["side"]) * 2.0) * 0.5 * kick + 0.3
		(leg["pivot"] as Node3D).rotation = Vector3(swing, 0, 0)
	if running and lod == LOD_FULL and fmod(_t, 0.35) < delta:
		FX.puff(global_position, "snow", 1, 0.5 * size_k, 0.5, Color.WHITE, 0.3, Vector3.UP)
