extends Creature
## Pale stalkers (the fog isles, 1.30): a tall thin thing, half again a man's height, bone-white and faceless, its arms
## hanging past its knees on long fingers. It keeps to the fog: mostly not there at all - a shape that flickers in and
## out of the mist (the PS1's dither: it's drawn on a broken duty, more of it the nearer it is to solid). It follows a
## captain at a distance, circling, never quite there; then it comes solid all at once with a shriek (the tell: it
## rears up, arms spread) and lunges across the gap in two long strides to rake (a knock-down). After, it fades and
## draws off again. Hit, it comes solid for a moment and drops back.
##
## anim_a: how solid it is (0 faded .. 1 solid), the host's, puppets copy it.

const HEIGHT := 2.5
const STALK_R := 8.5
const NOTICE_R := 18.0
const LUNGE := 11.0
const STALK := 3.2
const PALE := Color(0.8, 0.8, 0.76)
const DARK := Color(0.1, 0.1, 0.11)

var _solid_to := 0.0
var _orbit := 1.0
var _lunge_dir := Vector3.ZERO
var _lunge := LUNGE
var _gait := 0.0
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arms: Array = []
var _legs: Array = []


func _setup(_args: Dictionary) -> void:
	kind = "pale_stalker"
	hostile = true
	skin_tex = "fur_white"
	max_hp = 110.0
	xp = 70
	coins = Vector2i(2, 5)
	drops = [["ivory", 0.5, 1]]


func _body_shape() -> Array:
	return [0.3, 2.3, Vector3(0.7, 2.4, 0.6)]


func _moves() -> Array:
	return [[20.0, 7.0, Vector3(1.6, 1.4, 1.6), Vector3(0, 1.3, -1.0), true, 0.45]]


# ==========================================================================
# Model: digitigrade legs, a narrow ribbed body, a smooth head with no face but two black hollows, long arms and fingers
# ==========================================================================
func _build() -> void:
	var skin := _skin()
	var eye := _glow(Color(0.85, 0.95, 1.0))
	_hips = _part(model, "Hips", Vector3(0, 1.15, 0), "hips", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.15, 0.1, 0.1), rng, 0.1, 3, 6, 1.0, PALE.darkened(0.1)))
	_torso = _part(_hips, "Torso", Vector3(0, 0.05, 0), "torso", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		seg(mb, skin, Vector3.ZERO, Vector3(0, 0.75, 0.04), 0.11, PALE)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.62, 0.0)), Vector3(0.2, 0.2, 0.12), rng, 0.1, 3, 7, 1.0, PALE)
		for k in range(5):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.36 + k * 0.07, -0.1)), Vector3(0.26 - k * 0.01, 0.02, 0.03), 1.0, PALE.darkened(0.3), false, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0.03)), Vector3(0.26, 0.07, 0.1), rng, 0.15, 3, 6, 1.0, PALE.darkened(0.05))
		seg(mb, skin, Vector3(0, 0.8, 0.02), Vector3(0, 0.98, -0.04), 0.06, PALE.darkened(0.1)))
	_head = _part(_torso, "Head", Vector3(0, 1.0, -0.05), "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -0.02)), Vector3(0.1, 0.17, 0.12), rng, 0.04, 3, 8, 1.0, PALE.lightened(0.1))
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.04, 0.15, -0.125)), Vector3(0.045, 0.06, 0.02), 1.0, DARK, false, false)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.04, 0.15, -0.13)), Vector3(0.012, 0.012, 0.01), 1.0, Color.WHITE, false, false)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -0.12)), Vector3(0.06, 0.012, 0.01), 1.0, DARK, false, false))
	for s in [-1.0, 1.0]:
		var arm := _part(_torso, "Arm" + ("L" if s < 0.0 else "R"), Vector3(s * 0.26, 0.76, 0.02), "arm" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			seg(mb, skin, Vector3.ZERO, Vector3(s * 0.04, -0.55, 0.0), 0.06, PALE)
			seg(mb, skin, Vector3(s * 0.04, -0.55, 0.0), Vector3(s * 0.05, -1.1, -0.06), 0.045, PALE.darkened(0.08))
			for k in range(4):
				var f := Vector3(s * 0.05 + (k - 1.5) * 0.025, -1.12, -0.08)
				mb.add_tube(skin, PackedVector3Array([f, f + Vector3((k - 1.5) * 0.02, -0.18, -0.06), f + Vector3((k - 1.5) * 0.03, -0.34, -0.02)]), 0.016, 0.005, 3, 1.0, PALE.darkened(0.2)))
		_arms.append({"pivot": arm, "side": s})
	for s in [-1.0, 1.0]:
		var leg := _part(_hips, "Leg" + ("L" if s < 0.0 else "R"), Vector3(s * 0.11, -0.02, 0.0), "leg" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			# (bent back like a hound's: thigh forward, shin back, a long foot)
			seg(mb, skin, Vector3.ZERO, Vector3(0, -0.5, -0.2), 0.08, PALE)
			seg(mb, skin, Vector3(0, -0.5, -0.2), Vector3(0, -0.92, 0.12), 0.055, PALE.darkened(0.08))
			seg(mb, skin, Vector3(0, -0.92, 0.12), Vector3(0, -1.13, 0.02), 0.045, PALE.darkened(0.12))
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -1.14, -0.06)), Vector3(0.06, 0.03, 0.2), 1.0, PALE.darkened(0.2), false, false))
		_legs.append({"pivot": leg, "side": s})


# ==========================================================================
# Brain
# ==========================================================================
func _start() -> void:
	_set_state(S.WANDER)
	_orbit = 1.0 if _rng.randf() < 0.5 else -1.0


func in_combat() -> bool:
	return state in [S.CHASE, S.TELL, S.ATTACK, S.RECOVER, S.HITSTUN]


func _tick(delta: float) -> void:
	var solid := 1.0 if state in [S.TELL, S.ATTACK, S.HITSTUN, S.DOWN, S.DEAD] else (0.55 if state == S.RECOVER else 0.12)
	anim_a = move_toward(anim_a, maxf(solid, _solid_to), delta * (6.0 if solid > anim_a else 0.9))
	_solid_to = maxf(_solid_to - delta * 0.6, 0.0)


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE_R):
				_cool = _rng.randf_range(2.5, 4.5)
				_set_state(S.CHASE)
				return
			_wander(1.0, Vector2(3.0, 12.0))
		S.CHASE:
			if not _player_ok(p) or dist > 34.0 or flat(global_position - home).length() > 50.0:
				_wander_to = home
				_set_state(S.WANDER)
				return
			# a place on a ring round the captain, drifting round it
			var a := atan2(-to_p.z, -to_p.x) + _orbit * 0.6
			var spot := p.global_position + Vector3(cos(a), 0, sin(a)) * STALK_R
			var to_spot := flat(spot - global_position)
			_want = to_spot.normalized() * minf(STALK, to_spot.length() * 2.0) if to_spot.length() > 0.5 else Vector3.ZERO
			_face(to_p)
			_turn = 6.0
			if _cool <= 0.0 and dist < STALK_R + 2.5:
				_set_state(S.TELL)
				Net.fx("sfx", ["stalker_shriek", global_position, -1.0, 0.1, 1.0])
		S.TELL:
			_face(to_p)
			_turn = 10.0
			if st_t >= 0.8:
				_lunge_dir = _fwd()
				# (across the whole gap: the lunge's ramp covers 0.35 x its speed)
				_lunge = clampf((dist - 1.0) / 0.35, LUNGE, 26.0)
				_set_state(S.ATTACK)
				_strike(0)
				velocity = _lunge_dir * _lunge
		S.ATTACK:
			_want = _lunge_dir * _lunge * maxf(0.0, 1.0 - st_t / 0.75)
			_accel = 30.0
			_turn = 1.0
			if st_t > 0.55 or (not hitbox.hit_targets.is_empty() and st_t > 0.3):
				_cool = _rng.randf_range(4.0, 6.5)
				_orbit = -_orbit
				_daze_len = 0.9
				_set_state(S.RECOVER)
				Net.fx("smoke", [global_position + Vector3.UP * 1.2, 5, 1.0, 1.4, Color(0.8, 0.82, 0.82, 0.5)])


func _after_daze() -> void:
	_set_state(S.CHASE)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	_solid_to = 1.0
	if state in [S.IDLE, S.WANDER]:
		_cool = 1.0
		_set_state(S.CHASE)
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["stalker_shriek", global_position, -2.0, 0.05, 0.6])
	Net.fx("smoke", [global_position + Vector3.UP * 1.2, 10, 1.2, 2.0, Color(0.85, 0.86, 0.86, 0.6)])


# ==========================================================================
# Pose: the flicker of a faded one, the loping stalk, rearing up (the tell), the long lunge
# ==========================================================================
func _pose(delta: float) -> void:
	# (in and out of the fog: drawn on a broken duty, more of the time the more solid it is)
	if lod < LOD_HIDDEN:
		var k := anim_a
		var on := k >= 0.95 or fposmod(_t * 13.0 + sin(_t * 3.1) * 2.0, 1.0) < k * 0.9 + 0.08
		model.visible = on or state == S.DEAD
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.6, 0.0, 1.0)
	_gait += hs * 2.0 * delta
	var lean := 0.35 * moving + 0.15
	var arm_x := 0.15 + sin(_gait) * 0.3 * moving
	var arm_z := 0.05
	var head := -0.3 + sin(_t * 0.8) * 0.15
	var head_z := sin(_t * 0.37) * 0.35
	var crouch := 0.0
	match state:
		S.TELL:
			lean = -0.25
			arm_x = 2.2
			arm_z = 0.9
			head = 0.5
			head_z = 0.0
			crouch = -0.08
		S.ATTACK:
			lean = 0.85
			arm_x = 1.7
			arm_z = -0.2
			head = -0.2
			crouch = 0.2
		S.CHASE:
			crouch = 0.15
			lean = 0.55
		S.DOWN, S.DEAD:
			lean = 0.0
	_hips.position.y = 1.15 - crouch - absf(sin(_gait)) * 0.06 * moving
	_hips.rotation = Vector3(0, sin(_gait) * 0.15 * moving, 0)
	_torso.rotation = Vector3(-lean, 0, sin(_gait) * 0.05 * moving)
	_head.rotation = Vector3(head, 0, head_z)
	for a in _arms:
		var s: float = a["side"]
		var swing := arm_x * (1.0 if state in [S.TELL, S.ATTACK] else (1.0 if s > 0.0 else -1.0))
		(a["pivot"] as Node3D).rotation = Vector3(swing, 0, -s * arm_z)
	for l in _legs:
		var s: float = l["side"]
		var x := sin(_gait + (PI if s > 0.0 else 0.0)) * 0.55 * moving + crouch * 1.2
		(l["pivot"] as Node3D).rotation = Vector3(x, 0, s * 0.05)
