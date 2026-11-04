extends Creature
## Zombies (the fog isles' graveyards, 1.30): the village's own dead, buried in their shrouds, not the sea's drowned.
## Each lies under a fresh grave of the graveyard (FogPlaces.graveyard hands their spots to the FaunaSpawner) until a
## captain comes near: then a hand claws up through the dirt, the ground bursts and it hauls itself out. It shambles
## after you in lurches, slow; close in it raises both arms (the tell) and either rakes you or lunges and GRABS:
## held, you mash to break free (GrabbedState) or it bites and throws you down. Left alone a while by its grave, it
## sinks back into it. Rotten, grey-green under a filthy shroud, its eyes two pale points.
##
## States: HIDE buried, NOTICE rising (anim_a its progress: puppets copy it), SPECIAL holding a captain.

const RISE_R := 11.0
const RISE_LEN := 1.9
const SHAMBLE := 1.35
const REACH := 2.1
const LUNGE := 4.5
const HIP_Y := 0.92
const BURIED_Y := -1.9
## Its grab: held at most this long (the captain's GrabbedState throws at 2.2 s) and not again for GRAB_CD.
const HOLD_MAX := 3.4
const GRAB_CD := 6.0
const GRAB_DMG := 16.0
## Back into the ground after this long by its grave with nobody within LONELY_R.
const SINK_AFTER := 14.0
const LONELY_R := 24.0
const SKINS := [Color(0.46, 0.5, 0.38), Color(0.52, 0.5, 0.42), Color(0.4, 0.46, 0.42)]
const SHROUDS := [Color(0.6, 0.57, 0.48), Color(0.46, 0.44, 0.4), Color(0.55, 0.5, 0.42)]
const EYE := Color(0.75, 1.0, 0.8)

var morph: int = 0
var _move: int = 0
var _grab_cd: float = 0.0
var _check_t: float = 0.0
var _alone: float = 0.0
var _lurch: float = 0.0
var _gait: float = 0.0
var _limp: float = 1.0
var _buried_now := false
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _jaw: Node3D
var _arms: Array = []
var _legs: Array = []
var _facing: Node3D


func _setup(args: Dictionary) -> void:
	kind = "zombie"
	morph = int(args.get("morph", 0)) % 3
	hostile = true
	skin_tex = "leather"
	size_k = 1.0 + 0.06 * morph
	max_hp = 85.0
	xp = 45
	coins = Vector2i(1, 4)
	# grave rags and grave goods
	drops = [["canvas", 0.4, 1], ["ivory", 0.12, 1]]


func in_combat() -> bool:
	return state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK, S.RECOVER, S.HITSTUN, S.SPECIAL]


func _body_shape() -> Array:
	return [0.3, 1.7, Vector3(0.7, 1.75, 0.6)]


## [rake, grab]
func _moves() -> Array:
	return [[14.0, 4.5, Vector3(1.0, 1.0, 1.1), Vector3(0, 1.2, -0.75), false, 0.35],
		[0.0, 0.0, Vector3(1.0, 1.3, 1.2), Vector3(0, 1.1, -0.8), false, 0.0]]


func _arm(i: int) -> void:
	super._arm(i)
	hitbox.hit_data.grab = i == 1


# ==========================================================================
# Model: a gaunt body in a torn shroud, ribs and a jaw that hangs, long arms with black nails
# ==========================================================================
func _build() -> void:
	var v := str(morph)
	var flesh: Color = SKINS[morph]
	var rag: Color = SHROUDS[morph]
	var dark := Color(0.12, 0.1, 0.08)
	var bone := Color(0.78, 0.74, 0.62)
	var dirt := Color(0.24, 0.19, 0.14)
	var skin := _skin()
	var eye := _glow(EYE)
	_facing = Node3D.new()
	_facing.name = "Facing"
	add_child(_facing)
	_hips = _part(model, "Hips", Vector3(0, HIP_Y, 0), v + "_hips", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.19, 0.12, 0.13), rng, 0.15, 3, 6, 1.0, rag.darkened(0.15))
		# the shroud's hem in ragged strips to the knees
		for k in range(9):
			var a := TAU * k / 9.0 + rng.randf_range(-0.15, 0.15)
			var l := rng.randf_range(0.3, 0.52)
			mb.add_box(skin, Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)), Vector3(cos(a) * 0.17, -l * 0.5, sin(a) * 0.13)),
				Vector3(0.1, l, 0.02), 1.0, rag.darkened(rng.randf() * 0.3).lerp(dirt, clampf(l - 0.3, 0.0, 1.0) * 1.5), false, false))
	_torso = _part(_hips, "Torso", Vector3(0, 0.05, 0), v + "_torso", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		# a thin chest under the shroud, one side torn open on the ribs
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0.0)), Vector3(0.2, 0.26, 0.13), rng, 0.12, 3, 7, 1.0, rag)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0.09, 0.34, -0.06)), Vector3(0.1, 0.17, 0.08), rng, 0.1, 3, 6, 1.0, flesh.darkened(0.25))
		for k in range(4):
			mb.add_box(skin, Transform3D(Basis(Vector3.BACK, -0.25), Vector3(0.1, 0.42 - k * 0.07, -0.13)), Vector3(0.13, 0.022, 0.03), 1.0, bone, false, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.0)), Vector3(0.16, 0.13, 0.11), rng, 0.15, 3, 6, 1.0, flesh.darkened(0.1))
		# hunched shoulders, the shroud's hood fallen back on them
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0.06)), Vector3(0.24, 0.08, 0.12), rng, 0.2, 3, 6, 1.0, rag.darkened(0.2))
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.58, -0.02)), 0.05, 0.045, 0.12, 5, 1.0, flesh)
		# grave dirt caked down its back
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.32, 0.11)), Vector3(0.15, 0.2, 0.04), rng, 0.3, 3, 5, 1.0, dirt))
	_head = _part(_torso, "Head", Vector3(0, 0.68, -0.05), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Vector3(0.11, 0.13, 0.12), rng, 0.12, 3, 7, 1.0, flesh)
		# sunken sockets, a pale point deep in each
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.045, 0.12, -0.105)), Vector3(0.045, 0.035, 0.02), 1.0, dark, false, false)
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.045, 0.12, -0.112)), Vector3(0.016, 0.016, 0.01), 1.0, Color.WHITE, false, false)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.07, -0.12)), Vector3(0.03, 0.04, 0.03), 1.0, flesh.darkened(0.2), false, false)
		# lank hair over the skull
		for k in range(6):
			var a := -1.2 + k * 0.48
			mb.add_box(skin, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.25), Vector3(sin(a) * 0.09, 0.08, cos(a) * 0.08)), Vector3(0.03, 0.2, 0.02), 1.0, Color(0.16, 0.16, 0.14), false, false))
	_jaw = _part(_head, "Jaw", Vector3(0, 0.03, -0.03), v + "_jaw", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.05)), Vector3(0.12, 0.04, 0.1), 1.0, flesh.darkened(0.1), false, false)
		for k in range(4):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(-0.035 + k * 0.023, 0.01, -0.095)), Vector3(0.012, 0.025, 0.01), 1.0, bone, false, false))
	for s in [-1.0, 1.0]:
		var arm := _part(_torso, "Arm" + ("L" if s < 0.0 else "R"), Vector3(s * 0.22, 0.54, 0.0), v + "_arm" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			seg(mb, skin, Vector3.ZERO, Vector3(s * 0.02, -0.3, 0.0), 0.075, rag.darkened(0.1))
			seg(mb, skin, Vector3(s * 0.02, -0.3, 0.0), Vector3(s * 0.01, -0.6, -0.05), 0.055, flesh)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.01, -0.64, -0.06)), Vector3(0.045, 0.05, 0.035), rng, 0.15, 2, 5, 1.0, flesh.darkened(0.15))
			for k in range(4):
				mb.add_tube(skin, PackedVector3Array([Vector3(s * 0.01 - 0.03 + k * 0.02, -0.67, -0.08), Vector3(s * 0.01 - 0.035 + k * 0.023, -0.76, -0.1)]),
					0.01, 0.004, 3, 1.0, dark))
		_arms.append({"pivot": arm, "side": s})
	for s in [-1.0, 1.0]:
		var leg := _part(_hips, "Leg" + ("L" if s < 0.0 else "R"), Vector3(s * 0.1, -0.05, 0.0), v + "_leg" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			seg(mb, skin, Vector3.ZERO, Vector3(0, -0.44, -0.02), 0.08, rag.darkened(0.25))
			seg(mb, skin, Vector3(0, -0.44, -0.02), Vector3(0, -0.84, 0.03), 0.06, flesh.darkened(0.1))
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.85, -0.04)), Vector3(0.08, 0.05, 0.17), 1.0, dirt, false, false))
		_legs.append({"pivot": leg, "side": s})
	_limp = 0.6 + 0.25 * morph


# ==========================================================================
# Brain
# ==========================================================================
func _start() -> void:
	_bury()


func _bury() -> void:
	velocity = Vector3.ZERO
	anim_a = 0.0
	_alone = 0.0
	global_position = home + Vector3.UP * 0.05
	_set_state(S.HIDE)
	_apply_buried()
	model.visible = false


func buried() -> bool:
	return state == S.HIDE


func set_lod(l: int) -> void:
	super.set_lod(l)
	if state == S.HIDE:
		model.visible = false


## Buried, or only an arm out of the ground: no body to bump into, nothing to hit.
func _apply_buried() -> void:
	if state == S.DEAD:
		return
	var b := state == S.HIDE or (state == S.NOTICE and anim_a < 0.45)
	if b == _buried_now:
		return
	_buried_now = b
	collision_layer = 0 if b else 4
	hurtbox.set_deferred("monitorable", not b)


func _walk(delta: float) -> void:
	if state in [S.HIDE, S.NOTICE]:
		return
	super._walk(delta)


func _tick(delta: float) -> void:
	_grab_cd -= delta
	_facing.rotation.y = model.rotation.y
	if state == S.NOTICE:
		anim_a = minf(st_t / RISE_LEN, 1.0)
	elif state != S.HIDE:
		anim_a = 1.0
	var reach := 1.0 if state in [S.TELL, S.ATTACK, S.SPECIAL] else 0.0
	anim_b = move_toward(anim_b, reach, delta * 5.0)
	_apply_buried()


func _brain(delta: float) -> void:
	if state == S.HIDE:
		# (asleep in the ground: a look round now and then)
		_check_t -= delta
		if _check_t <= 0.0:
			_check_t = 0.2
			var q := _target()
			if _player_ok(q) and flat(q.global_position - global_position).length() < RISE_R:
				rise(q)
		return
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.NOTICE:
			_face(to_p)
			_turn = 2.0
			if st_t < delta * 1.5 or (st_t >= 0.7 and st_t < 0.7 + delta * 1.5):
				_burst(st_t > 0.5)
			if st_t >= RISE_LEN:
				_set_state(S.CHASE)
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < RISE_R + 2.0:
				_set_state(S.CHASE)
				return
			_wander(0.6, Vector2(0.5, 2.5))
			_check_t -= delta
			if _check_t <= 0.0:
				_check_t = 0.5
				var near := Net.all_players().any(func(q): return (q as Node3D).global_position.distance_to(global_position) < LONELY_R)
				_alone = 0.0 if near else _alone + 0.5
				if _alone > SINK_AFTER and flat(home - global_position).length() < 3.0:
					Net.fx("dust", [global_position, 8, 0.6])
					_bury()
		S.CHASE:
			if not _player_ok(p) or dist > 30.0 or flat(global_position - home).length() > 38.0:
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 3.0
			# lurching: a heave forward, a drag of the bad leg
			_lurch += delta
			if dist > REACH:
				_want = to_p.normalized() * SHAMBLE * (0.55 + 0.75 * absf(sin(_lurch * 2.4)))
			elif _cool <= 0.0:
				_move = 1 if _grab_cd <= 0.0 and _rng.randf() < 0.55 else 0
				_set_state(S.TELL)
				Net.fx("sfx", ["zombie_moan", global_position, -2.0, 0.12, 1.0 if _move == 1 else 1.15])
		S.TELL:
			_face(to_p)
			_turn = 5.0
			if st_t >= (0.85 if _move == 1 else 0.7):
				_set_state(S.ATTACK)
				_strike(_move)
				velocity = _fwd() * LUNGE
		S.ATTACK:
			_want = _fwd() * LUNGE * maxf(0.0, 1.0 - st_t / 0.35)
			_accel = 30.0
			_turn = 1.0
			if _move == 0 and (not hitbox.hit_targets.is_empty() or st_t > 0.4):
				_cool = _rng.randf_range(1.4, 2.2)
				_daze_len = 0.5
				_set_state(S.RECOVER)
			elif _move == 1 and st_t > 0.55:
				# (grabbed at air: wide open; a captain it caught tells it so: grab_held)
				_grab_cd = GRAB_CD * 0.5
				_cool = 1.6
				_daze_len = 1.2
				_set_state(S.RECOVER)
		S.SPECIAL:
			_face(to_p)
			_turn = 6.0
			if st_t > HOLD_MAX:
				_cool = 1.5
				_daze_len = 0.6
				_set_state(S.RECOVER)


## Up out of its grave: a hand first, then the ground bursts and it hauls itself out.
func rise(_by: Node = null) -> void:
	if state != S.HIDE:
		return
	_set_state(S.NOTICE)
	model.visible = lod < LOD_HIDDEN
	Net.event(self, "rise", [])


func _burst(big: bool) -> void:
	var at := global_position + Vector3.UP * 0.1
	if big:
		Net.fx("debris", [at, Vector3.UP, 14, Color(0.3, 0.24, 0.17), 6.0])
		Net.fx("dust_ring", [at, 12, 0.9])
		Net.fx("sfx", ["grave_burst", at, 0.0, 0.08, 1.0])
		Net.fx("sfx", ["zombie_moan", at, -3.0, 0.12, 0.9])
	else:
		Net.fx("debris", [at, Vector3.UP, 5, Color(0.3, 0.24, 0.17), 3.0])
		Net.fx("dust", [at, 4, 0.4])
		Net.fx("sfx", ["grave_burst", at, -8.0, 0.1, 1.4])


## Its grab caught a captain (from that captain's machine): it holds on until GrabbedState says how it ended.
func grab_held() -> void:
	if Net.forward(self, "grab_held", []):
		return
	if state in [S.DEAD, S.DOWN, S.HIDE]:
		return
	_grab_cd = GRAB_CD
	_set_state(S.SPECIAL)
	Net.fx("sfx", ["zombie_moan", global_position, 0.0, 0.1, 0.8])


func grab_ended(broke: bool) -> void:
	if Net.forward(self, "grab_ended", [broke]):
		return
	if state != S.SPECIAL:
		return
	_cool = 1.6
	if broke:
		velocity = -_fwd() * 3.0
		_daze_len = 1.4
	else:
		_daze_len = 0.6
	_set_state(S.RECOVER)


## GrabbedState: it lets go only when it's put down.
func holding() -> bool:
	return state not in [S.DEAD, S.DOWN, S.HIDE]


func grab_spot() -> Vector3:
	return global_position + _fwd() * 0.75 * size_k


func grab_damage() -> float:
	return _dmg(GRAB_DMG)


func _landed(target: Node, data: HitData) -> void:
	super._landed(target, data)
	if data.grab and target is Player and (target as Player).is_local:
		grab_held()


func _cry_death() -> void:
	Net.fx("sfx", ["zombie_moan", global_position, -2.0, 0.08, 0.7])
	Net.fx("debris", [global_position + Vector3.UP * 0.8, Vector3.UP, 6, Color(0.42, 0.44, 0.36), 3.0])


func _net_event(what: String, _args: Array) -> void:
	if what == "rise":
		model.visible = lod < LOD_HIDDEN


# ==========================================================================
# Pose: buried, the climb out, the shamble, both arms up (the tell), the rake and the grab, the hold
# ==========================================================================
func _pose(delta: float) -> void:
	if net_puppet:
		_apply_buried()
	if state == S.HIDE:
		model.visible = false
		return
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD, S.NOTICE] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 2.6 * delta
	var gait := _gait
	var reach := anim_b
	var rise_k := anim_a
	var lean := 0.25 + 0.1 * sin(gait * 0.5)
	var sway := sin(gait * 0.5) * 0.14 * moving + sin(_t * 0.9) * 0.05
	var arm_x := lerpf(0.15 + 0.9 * moving, 1.45, reach)
	var arm_z := 0.0
	var head_x := -0.2 + sin(_t * 1.3) * 0.12
	var head_z := 0.35 * sin(_t * 0.7)
	var jaw := 0.25 + 0.15 * sin(_t * 2.0)
	if state not in [S.NOTICE, S.DEAD]:
		model.position.y = 0.0
	match state:
		S.NOTICE:
			# a hand out first, then it hauls itself up the side of the grave, leaning on its arms
			var up := smoothstep(0.25, 1.0, rise_k)
			model.position.y = lerpf(BURIED_Y + 0.65, 0.0, up) if rise_k > 0.12 else lerpf(BURIED_Y, BURIED_Y + 0.65, rise_k / 0.12)
			lean = lerpf(1.1, 0.25, up)
			arm_x = lerpf(2.9, 1.9, up)
			arm_z = 0.2
			head_x = lerpf(0.6, -0.1, up)
			jaw = 0.5
		S.TELL:
			arm_x = 2.4 if _move == 1 else 2.6
			arm_z = 0.55
			lean = -0.05
			head_x = 0.45
			jaw = 0.85
		S.ATTACK:
			arm_x = 1.5
			arm_z = -0.25 if _move == 1 else 0.1
			lean = 0.5
			jaw = 0.7
		S.SPECIAL:
			arm_x = 1.35
			arm_z = -0.4
			lean = 0.45
			head_x = -0.4
			jaw = 0.4 + 0.4 * absf(sin(_t * 9.0))
		S.RECOVER:
			head_z = sin(_t * 3.0) * 0.4
			arm_x = 0.3
		S.DOWN, S.DEAD:
			arm_x = 0.6
			lean = 0.1
	_hips.position.y = HIP_Y - absf(sin(gait)) * 0.05 * moving
	_hips.rotation = Vector3(0, sin(gait) * 0.12 * moving, sway)
	_torso.rotation = Vector3(-lean, 0, -sway * 0.6)
	_head.rotation = Vector3(head_x, 0, head_z)
	_jaw.rotation = Vector3(jaw, 0, 0)
	for a in _arms:
		var s: float = a["side"]
		# (one arm hangs lower: it's dead weight)
		var lag := sin(_t * 1.1 + s) * 0.12 if reach < 0.5 else 0.0
		var x := arm_x * (1.0 if s > 0.0 or reach > 0.5 or state == S.NOTICE else 0.75) + lag
		(a["pivot"] as Node3D).rotation = Vector3(x, 0, -s * arm_z)
	for l in _legs:
		var s: float = l["side"]
		var step := sin(gait + (PI if s > 0.0 else 0.0))
		# the bad leg drags: it swings short and stiff
		var k := _limp if s > 0.0 else 1.0
		var x := step * 0.45 * moving * k
		if state == S.NOTICE:
			x = 0.6 * (1.0 - rise_k) * (1.0 if s > 0.0 else -0.4)
		elif state in [S.DOWN, S.DEAD]:
			x = 0.2
		(l["pivot"] as Node3D).rotation = Vector3(x, 0, s * 0.04)
