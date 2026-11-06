extends Creature
## Owl-beasts (the forest, 1.30): a bear's bulk in a coat of barred brown feathers, an owl's round face on it - a
## hooked beak, ear tufts, eyes like lamps - and taloned forelegs. By day it sleeps hunched in the wood and lets you be
## (unless you hit it). At night it hunts: it sees a captain from far off, its eyes burning amber, and comes on all
## fours; close, it rears up on its hind legs with its wings flung wide and screams (the tell), then drops on you with
## both talons (a knock-down). It turns quickly, so keep moving; it's a hunter, not a brawler: hurt badly, it flees.
##
## anim_a: reared (0 down on all fours .. 1 up); anim_b: awake (its eyes lit).

const NOTICE_R := 22.0
const RUN := 6.2
const REACH := 3.4
const BROWN := Color(0.4, 0.3, 0.2)
const PALE := Color(0.78, 0.7, 0.55)
const BAR := Color(0.22, 0.16, 0.1)
const EYE := Color(1.0, 0.7, 0.2)

var _hunting := false
var _pounce_dir := Vector3.ZERO
var _gait := 0.0
var _look_t := 0.0
var _body: Node3D
var _head: Node3D
var _wings: Array = []
var _fore: Array = []
var _hind: Array = []


func _setup(_args: Dictionary) -> void:
	kind = "owl_beast"
	hostile = false
	skin_tex = "fur_white"
	size_k = 1.25
	max_hp = 180.0
	xp = 110
	coins = Vector2i(3, 7)
	drops = [["plume", 0.8, 2], ["bear_claw", 0.2, 1]]


func in_combat() -> bool:
	return _hunting and state != S.DEAD


func _body_shape() -> Array:
	return [0.45, 1.2, Vector3(1.0, 1.3, 1.4)]


func _moves() -> Array:
	return [[22.0, 8.0, Vector3(1.3, 1.2, 1.3), Vector3(0, 0.7, -0.95), true, 0.5]]


# ==========================================================================
# Model: a round feathered barrel, the owl's disc face, folded wings, thick taloned forelegs, short hind legs
# ==========================================================================
func _build() -> void:
	var skin := _skin()
	var eye := _glow(EYE)
	_body = _part(model, "Body", Vector3(0, 0.75, 0), "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.05)), Vector3(0.42, 0.4, 0.55), rng, 0.08, 4, 8, 1.0, BROWN)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.28)), Vector3(0.36, 0.34, 0.3), rng, 0.08, 4, 7, 1.0, PALE)
		# barred breast feathers, a ruff round the neck
		for k in range(5):
			mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, -0.2 + k * 0.08, -0.5 + k * 0.02)), Vector3(0.36 - absf(k - 2) * 0.04, 0.025, 0.04), 1.0, BAR, false, false)
		for k in range(8):
			var a := -1.4 + k * 0.4
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.3, cos(a) * 0.22 + 0.18, -0.36)), Vector3(0.1, 0.12, 0.1), rng, 0.2, 3, 5, 1.0, BROWN.lightened(0.1))
		# the tail fan
		for k in range(5):
			var a := -0.5 + k * 0.25
			mb.add_box(skin, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.5), Vector3(sin(a) * 0.12, 0.05, 0.62)), Vector3(0.08, 0.02, 0.36), 1.0, BROWN.darkened(0.15 * (k % 2)), false, false))
	_head = _part(_body, "Head", Vector3(0, 0.38, -0.42), "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.02)), Vector3(0.27, 0.25, 0.24), rng, 0.06, 4, 7, 1.0, BROWN)
		# the facial disc, pale, ringed dark
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1, -0.2)), 0.25, 0.23, 0.04, 10, 1.0, BAR)
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1, -0.215)), 0.22, 0.2, 0.04, 10, 1.0, PALE)
		for s in [-1.0, 1.0]:
			mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.095, 0.13, -0.235)), 0.075, 0.075, 0.02, 8, 1.0, Color(0.06, 0.05, 0.04))
			mb.add_cylinder(eye, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.095, 0.13, -0.25)), 0.045, 0.045, 0.01, 8, 1.0, Color.WHITE)
			# ear tufts
			mb.add_cone(skin, Transform3D(Basis(Vector3.BACK, s * 0.4), Vector3(s * 0.16, 0.3, 0.0)), 0.06, 0.2, 4, 1.0, BAR)
		mb.add_cone(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.6), Vector3(0, 0.04, -0.24)), 0.045, 0.12, 4, 1.0, Color(0.85, 0.78, 0.5)))
	for s in [-1.0, 1.0]:
		var w := _part(_body, "Wing" + ("L" if s < 0.0 else "R"), Vector3(s * 0.38, 0.22, -0.1), "wing" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			for k in range(6):
				var z := -0.05 + k * 0.13
				mb.add_box(skin, Transform3D(Basis(Vector3.UP, s * 0.1), Vector3(s * 0.02, -0.15 - k * 0.04, z)), Vector3(0.04, 0.42 - k * 0.03, 0.16), 1.0, (BROWN if k % 2 == 0 else BAR.lightened(0.15)), false, false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.02, 0.02, 0.3)), Vector3(0.06, 0.14, 0.78), 1.0, BROWN.darkened(0.1), false, false))
		_wings.append({"pivot": w, "side": s})
		var fore := _part(_body, "Fore" + ("L" if s < 0.0 else "R"), Vector3(s * 0.26, -0.1, -0.32), "fore" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0)), Vector3(0.13, 0.22, 0.13), rng, 0.15, 3, 6, 1.0, BROWN)
			seg(mb, skin, Vector3(0, -0.3, 0), Vector3(0, -0.6, -0.04), 0.1, Color(0.7, 0.6, 0.3))
			for k in range(3):
				var x := (k - 1) * 0.045
				mb.add_tube(skin, PackedVector3Array([Vector3(x, -0.6, -0.06), Vector3(x * 1.4, -0.66, -0.17), Vector3(x * 1.5, -0.72, -0.2)]), 0.025, 0.005, 3, 1.0, Color(0.12, 0.1, 0.08)))
		_fore.append({"pivot": fore, "side": s})
		var hind := _part(_body, "Hind" + ("L" if s < 0.0 else "R"), Vector3(s * 0.24, -0.2, 0.32), "hind" + ("l" if s < 0.0 else "r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), Vector3(0.14, 0.2, 0.16), rng, 0.15, 3, 6, 1.0, BROWN.darkened(0.1))
			seg(mb, skin, Vector3(0, -0.25, 0), Vector3(0, -0.52, 0.02), 0.09, Color(0.7, 0.6, 0.3))
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.53, -0.05)), Vector3(0.12, 0.04, 0.18), 1.0, Color(0.12, 0.1, 0.08), false, false))
		_hind.append({"pivot": hind, "side": s})


# ==========================================================================
# Brain
# ==========================================================================
func _start() -> void:
	_set_state(S.IDLE)


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, 1.0 if state in [S.TELL, S.ATTACK] else 0.0, delta * (5.0 if state == S.TELL else 3.0))
	anim_b = move_toward(anim_b, 1.0 if (_hunting or _night() > 0.5) else 0.15, delta * 1.5)


func _brain(delta: float) -> void:
	_look_t -= delta
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			# (it hunts by night; by day it sleeps where it is)
			if _look_t <= 0.0:
				_look_t = 0.3
				if _night() > 0.5 and _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE_R):
					_hunt()
					return
			if _night() > 0.5:
				_wander(1.4, Vector2(3.0, 10.0))
			elif state == S.WANDER:
				_set_state(S.IDLE)
		S.NOTICE:
			_face(to_p)
			_turn = 6.0
			if st_t > 0.6:
				_set_state(S.CHASE)
		S.CHASE:
			if not _player_ok(p) or dist > 36.0 or flat(global_position - home).length() > 55.0:
				_hunting = false
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 9.0
			if dist > REACH:
				_want = to_p.normalized() * RUN
			elif _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["owl_screech", global_position, 0.0, 0.08, 1.0])
			else:
				_want = -to_p.normalized() * 1.5
		S.TELL:
			_face(to_p)
			_turn = 8.0
			if st_t >= 0.75:
				_pounce_dir = _fwd()
				_set_state(S.ATTACK)
				_strike(0)
				velocity = _pounce_dir * 7.0 + Vector3.UP * 2.0
		S.ATTACK:
			_want = _pounce_dir * 7.0 * maxf(0.0, 1.0 - st_t / 0.4)
			_accel = 30.0
			_turn = 1.0
			if st_t > 0.5:
				Net.fx("dust_ring", [global_position + _pounce_dir * 0.9, 10, 0.7])
				_cool = _rng.randf_range(1.6, 2.6)
				_daze_len = 0.7
				_set_state(S.RECOVER)
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_face(away)
			_want = away * RUN
			if st_t > 5.0:
				_hunting = false
				_set_state(S.WANDER)


func _hunt() -> void:
	_hunting = true
	hostile = true
	_set_state(S.NOTICE)
	Net.fx("sfx", ["owl_screech", global_position, -6.0, 0.1, 1.3])


func _after_daze() -> void:
	_set_state(S.CHASE if _hunting else S.WANDER)


func _after_stun() -> void:
	_set_state(S.CHASE if _hunting else S.WANDER)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	if not _hunting:
		_hunt()
		return true
	if health.current_health < health.max_health * 0.2 and state != S.FLEE:
		_set_state(S.FLEE)
		return true
	return false


func _cry_death() -> void:
	Net.fx("sfx", ["owl_screech", global_position, -4.0, 0.05, 0.7])
	Net.fx("sparkle", [global_position + Vector3.UP * 1.0, 10, PALE])


# ==========================================================================
# Pose: asleep hunched, the run on all fours, rearing with the wings flung wide (the tell), the drop with both talons
# ==========================================================================
func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	_gait += hs * 2.4 * delta
	var rear := anim_a
	var asleep := state == S.IDLE and anim_b < 0.5
	# (x+ lifts the nose: up on its hind legs)
	var pitch := lerpf(0.0, 1.0, rear) if state != S.ATTACK else -0.3
	_body.position.y = 0.75 + rear * 0.45 - (0.12 if asleep else 0.0) + absf(sin(_gait)) * 0.06 * moving
	_body.rotation = Vector3(pitch, 0, 0)
	# (an owl's head stays level and turns to watch)
	var hx := -pitch * 0.9 + (0.5 if asleep else 0.0)
	var hy := sin(_t * 0.6) * 0.9 * (1.0 - moving) * (0.0 if asleep else 1.0)
	_head.rotation = Vector3(hx, hy, 0.25 * sin(_t * 1.1) if state == S.NOTICE else 0.0)
	for w in _wings:
		var s: float = w["side"]
		var open := rear if state == S.TELL else (0.4 if state == S.ATTACK else 0.0)
		(w["pivot"] as Node3D).rotation = Vector3(-open * 0.4, s * open * 1.0, -s * open * 1.3 + sin(_t * 18.0) * 0.06 * open)
	for f in _fore:
		var s: float = f["side"]
		var x := sin(_gait + (PI if s > 0.0 else 0.0)) * 0.7 * moving
		if state == S.TELL:
			x = 0.6 + rear * 0.4
		elif state == S.ATTACK:
			x = 1.4
		(f["pivot"] as Node3D).rotation = Vector3(x, 0, -s * (0.35 if state == S.TELL else 0.0))
	for h in _hind:
		var s: float = h["side"]
		(h["pivot"] as Node3D).rotation = Vector3(-sin(_gait + (0.0 if s > 0.0 else PI)) * 0.6 * moving - pitch, 0, 0)


## Its blows rake and pinch: claws, pincers, nails.
func _impact_kind(_i: int) -> String:
	return "claw"
