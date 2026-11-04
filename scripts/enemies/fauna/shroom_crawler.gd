extends Creature
## Mushroom crawlers (the forest, 1.30): a toadstool as wide as a cart wheel - a red cap with white warts, a brown one,
## or a violet one that glows - on a stout stem and six root-feet tucked under it. Sitting still it's just another
## mushroom in the leaf litter; come close and it heaves itself up on its roots and creeps after you. Its tell: the
## cap swells and its spots glow; then it squeezes, and a cloud of spores bursts out all round it (a ring: anyone in
## it is poisoned). Slow, so back off when the cap swells - or hit it while it's swelling and it bursts early.
##
## anim_a: up on its roots (0 squat .. 1 up); anim_b: the cap's swell.

const WAKE_R := 5.5
const CREEP := 1.6
const BURST_R := 2.6
const CAPS := [[Color(0.72, 0.12, 0.08), Color(0.95, 0.92, 0.84)], [Color(0.42, 0.28, 0.16), Color(0.82, 0.74, 0.58)], [Color(0.42, 0.22, 0.55), Color(0.75, 0.95, 0.9)]]
const STEM := Color(0.86, 0.82, 0.72)

var morph: int = 0
var _cap: Node3D
var _stem: Node3D
var _feet: Array = []
var _burst_cd := 0.0


func _setup(args: Dictionary) -> void:
	kind = "shroom_crawler"
	morph = int(args.get("morph", 0)) % 3
	hostile = true
	skin_tex = "fur_white"
	size_k = 1.0 + 0.1 * morph
	max_hp = 70.0
	xp = 40
	coins = Vector2i(0, 3)
	venom = [5.0, 3.0]
	drops = [["mushroom", 0.8, 2]]


func _body_shape() -> Array:
	return [0.4, 0.9, Vector3(1.1, 1.0, 1.1)]


## The spore burst: a ring all round it.
func _moves() -> Array:
	return [[9.0, 5.0, Vector3(BURST_R * 2.0, 1.6, BURST_R * 2.0), Vector3(0, 0.6, 0), false, 0.4]]


func _build() -> void:
	var skin := _skin()
	var c: Array = CAPS[morph]
	var cap_col: Color = c[0]
	var wart: Color = c[1]
	var spot := _glow(wart) if morph == 2 else skin
	_stem = _part(model, "Stem", Vector3(0, 0.25, 0), "stem", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0)), 0.22, 0.17, 0.6, 8, 1.0, STEM)
		# the skirt under the cap and two dark knots of eyes in the stem
		mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.38, 0)), 0.24, 0.2, 0.08, 8, 1.0, STEM.darkened(0.1))
		for s in [-1.0, 1.0]:
			mb.add_box(_glow(Color(1.0, 0.85, 0.4)), Transform3D(Basis.IDENTITY, Vector3(s * 0.06, 0.22, -0.18)), Vector3(0.04, 0.04, 0.02), 1.0, Color.WHITE, false, false)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, -0.19)), Vector3(0.1, 0.03, 0.02), 1.0, Color(0.2, 0.14, 0.1), false, false)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.28, 0)), Vector3(0.28, 0.1, 0.28), rng, 0.2, 2, 6, 1.0, Color(0.3, 0.22, 0.14)))
	_cap = _part(_stem, "Cap", Vector3(0, 0.5, 0), "cap%d" % morph, func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var rings := [[0.0, 0.62, 0.62, 0.0], [0.1, 0.64, 0.64, 0.0], [0.24, 0.52, 0.52, 0.0], [0.36, 0.3, 0.3, 0.0], [0.42, 0.06, 0.06, 0.0]]
		mb.add_loft(skin, Transform3D.IDENTITY, rings, MeshBuilder.profile_circle(10), 1.0, cap_col, true, true)
		# gills under it
		mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), 0.6, 0.2, 0.04, 10, 1.0, STEM.darkened(0.25))
		for k in range(11):
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.1, 0.52)
			var y := 0.42 * (1.0 - pow(r / 0.64, 2.0)) + 0.02
			mb.add_blob(spot, Transform3D(Basis.IDENTITY, Vector3(cos(a) * r, y, sin(a) * r)), Vector3(0.06, 0.03, 0.06), rng, 0.2, 2, 5, 1.0, wart))
	for i in range(6):
		var a := TAU * i / 6.0 + 0.3
		var foot := _part(_stem, "Root%d" % i, Vector3(cos(a) * 0.16, -0.28, sin(a) * 0.16), "root", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_tube(skin, PackedVector3Array([Vector3.ZERO, Vector3(0.12, -0.08, 0), Vector3(0.24, -0.22, 0.0)]), 0.05, 0.02, 4, 1.0, Color(0.45, 0.36, 0.24)))
		foot.rotation.y = -a
		_feet.append(foot)


func _start() -> void:
	_set_state(S.IDLE)


func in_combat() -> bool:
	return state in [S.CHASE, S.TELL, S.ATTACK, S.RECOVER, S.HITSTUN]


func _tick(delta: float) -> void:
	_burst_cd -= delta
	anim_a = move_toward(anim_a, 0.0 if state in [S.IDLE, S.DOWN, S.DEAD] else 1.0, delta * 2.5)
	anim_b = move_toward(anim_b, 1.0 if state == S.TELL else 0.0, delta * (1.3 if state == S.TELL else 6.0))


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), WAKE_R):
				_set_state(S.CHASE)
				Net.fx("dust", [global_position, 4, 0.5])
				return
			if state == S.WANDER:
				# (back to its spot, where it sits down again)
				var back := flat(home - global_position)
				if back.length() < 0.6:
					_set_state(S.IDLE)
				else:
					_face(back)
					_want = back.normalized() * CREEP
		S.CHASE:
			if not _player_ok(p) or dist > 16.0 or flat(global_position - home).length() > 20.0:
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 3.0
			if dist > BURST_R * 0.7:
				_want = to_p.normalized() * CREEP
			if dist < BURST_R + 0.3 and _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["spore_puff", global_position, -10.0, 0.1, 1.6])
		S.TELL:
			if st_t >= 1.0:
				_burst()
		S.ATTACK:
			if st_t > 0.25:
				_cool = _rng.randf_range(2.2, 3.2)
				_daze_len = 0.8
				_set_state(S.RECOVER)


## Squeezed: the spores burst out all round.
func _burst() -> void:
	_set_state(S.ATTACK)
	_strike(0)
	var col: Color = (CAPS[morph][1] as Color).lerp(Color(0.7, 0.85, 0.4), 0.5)
	Net.fx("puff_ring", [global_position + Vector3.UP * 0.4, "dust_low", 10, 0.4, 1.3, 1.1, col, 4.5])
	Net.fx("poison", [global_position + Vector3.UP * 0.9, 10, 0.6])
	Net.fx("sfx", ["spore_puff", global_position, 0.0, 0.08, 1.0])


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	# (hit while it swells: it bursts early)
	if state == S.TELL and st_t > 0.3 and _burst_cd <= 0.0:
		_burst_cd = 2.0
		_burst()
		return true
	if state in [S.IDLE, S.WANDER]:
		_set_state(S.CHASE)
	return false


func _after_daze() -> void:
	_set_state(S.CHASE)


func _cry_death() -> void:
	Net.fx("poison", [global_position + Vector3.UP * 0.6, 6, 0.5])
	Net.fx("sfx", ["spore_puff", global_position, -4.0, 0.05, 0.7])


func _pose(delta: float) -> void:
	var up := anim_a
	var swell := anim_b
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_stem.position.y = lerpf(0.05, 0.3, up)
	_stem.rotation = Vector3(sin(_t * 5.0) * 0.06 * moving, 0, sin(_t * 2.5) * 0.08 * moving)
	var throb := 1.0 + swell * (0.3 + 0.05 * sin(_t * 30.0))
	if state == S.ATTACK:
		throb = 0.8
	_cap.scale = Vector3(throb, 1.0 + swell * 0.15, throb)
	_cap.rotation.y += delta * moving * 0.4
	for i in range(_feet.size()):
		var f: Node3D = _feet[i]
		var step := sin(_t * 7.0 + i * 2.1) * 0.35 * moving
		f.rotation = Vector3(0, f.rotation.y, lerpf(0.9, 0.0, up) + step)
