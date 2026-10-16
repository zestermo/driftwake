class_name Scorpion
extends Creature
## Desert scorpions, low and quick on eight legs. Close in and one squares up: claws wide, the
## tail arched high and quivering (the tell), then either a PINCH from both claws or the
## STING, the tail whipping down over its back - the sting poisons. Its plates turn blows
## from the front. Emperors (rare) are as long as a man is tall and their sting knocks you
## down. Morphs: sand yellow, black, rust.

const NOTICE := 7.0
const RUN := 3.6
const COLORS := [
	[Color(0.86, 0.68, 0.36), Color(0.95, 0.85, 0.6), Color(0.45, 0.3, 0.14)],
	[Color(0.14, 0.12, 0.12), Color(0.32, 0.28, 0.26), Color(0.55, 0.12, 0.08)],
	[Color(0.62, 0.3, 0.14), Color(0.85, 0.55, 0.3), Color(0.3, 0.12, 0.06)],
]

var morph: int = 0
var emperor := false
var _sting := false
var _gait: float = 0.0
var _body: Node3D
var _tail: Array = []
var _claws: Array = []
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "scorpion"
	morph = int(args.get("morph", 0))
	# (one pack lead in eight, by its spot: the same on every screen)
	emperor = bool(args.get("lead", false)) and int(absf(home.x * 3.0 + home.z * 5.0)) % 8 == 0
	size_k = 1.9 if emperor else 1.15
	max_hp = 45.0 * (2.6 if emperor else 1.0)
	xp = 85 if emperor else 30
	coins = Vector2i(2, 5) if emperor else Vector2i(0, 2)
	drops = [["chitin_shard", 0.9 if emperor else 0.5, 2 if emperor else 1]]
	skin_tex = "leather"


func _body_shape() -> Array:
	return [0.26, 0.35, Vector3(0.7, 0.45, 1.0)]


func _moves() -> Array:
	return [[11.0, 3.5, Vector3(0.9, 0.5, 0.6), Vector3(0, 0.2, -0.55), false, 0.3],
		[16.0, 5.0, Vector3(0.7, 0.8, 0.7), Vector3(0, 0.35, -0.6), emperor, 0.4]]


# ==========================================================================
# Model: a flat plated body, two big claws, four legs a side, a five-jointed tail and its sting
# ==========================================================================
func _build() -> void:
	var c: Array = COLORS[morph % 3]
	var shell: Color = c[0]
	var pale: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var v := "m%d" % (morph % 3)
	_body = _part(model, "Body", Vector3(0, 0.2, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.18)), Vector3(0.17, 0.07, 0.17), rng, 0.04, 3, 8, 1.5, shell)
		for k in range(5):
			var z := -0.02 + k * 0.08
			var w := 0.17 - absf(k - 1.5) * 0.02
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.005 * k, z)), Vector3(w, 0.06, 0.05), rng, 0.03, 2, 8, 1.5, shell.darkened(0.06 * (k % 2)))
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0.05)), Vector3(0.14, 0.03, 0.28), rng, 0.02, 2, 7, 1.5, pale)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.04, 0.05, -0.28)), Vector3(0.018, 0.018, 0.018), rng, 0.0, 2, 5, 1.5, Color(0.04, 0.03, 0.03))
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.34)), Vector3(0.08, 0.03, 0.04), 1.5, dark, false, false), true)
	# the tail: five segments on a chain of pivots, the sting at its end
	var prev := _body
	var at := Vector3(0, 0.03, 0.36)
	for k in range(5):
		var r := 0.065 - k * 0.006
		var seg := _part(prev, "Tail%d" % k, at, v + "_tail%d" % k, func(mb: MeshBuilder, rng: RandomNumberGenerator):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.06)), Vector3(r, r, 0.08), rng, 0.04, 3, 6, 1.5, shell.darkened(0.05 * k)))
		_tail.append(seg)
		prev = seg
		at = Vector3(0, 0, 0.13)
	_part(prev, "Sting", at, v + "_sting", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.04)), Vector3(0.06, 0.06, 0.07), rng, 0.04, 3, 6, 1.5, pale)
		var barb := PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0.0, 0.14)])
		mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.35), Vector3(0, 0.0, 0.09)), barb, 0.025, 1.5, dark))
	# the claws on their arms
	for s in [-1.0, 1.0]:
		var claw := _part(_body, "Claw", Vector3(s * 0.12, 0.0, -0.28), v + ("_claw_l" if s < 0.0 else "_claw_r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.12, 0.0, -0.1), 0.04, shell)
			Creature.seg(mb, skin, Vector3(s * 0.12, 0.0, -0.1), Vector3(s * 0.14, 0.02, -0.22), 0.035, shell)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.15, 0.02, -0.3)), Vector3(0.065, 0.05, 0.1), rng, 0.04, 3, 6, 1.5, shell)
			var finger := PackedVector2Array([Vector2(-0.022, 0), Vector2(0.022, 0), Vector2(0.006, -0.12)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.13, 0.04, -0.37)), finger, 0.035, 1.5, dark)
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.3), Vector3(s * 0.17, 0.0, -0.37)), finger, 0.03, 1.5, pale))
		_claws.append([claw, s])
		var legs := _part(_body, "Legs", Vector3(s * 0.13, -0.02, -0.05), v + ("_legs_l" if s < 0.0 else "_legs_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			for k in range(4):
				var z := -0.08 + k * 0.08
				Creature.seg(mb, skin, Vector3(0, 0, z), Vector3(s * 0.16, 0.07, z + k * 0.02), 0.022, shell)
				Creature.seg(mb, skin, Vector3(s * 0.16, 0.07, z + k * 0.02), Vector3(s * 0.25, -0.18, z + k * 0.04), 0.018, shell.darkened(0.25)))
		_legs.append([legs, s])


# ==========================================================================
# Brain
# ==========================================================================
func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			_wander(1.1, Vector2(2.0, 7.0))
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE * sqrt(size_k)) and _cool <= 0.0:
				_set_state(S.CHASE)
				Net.fx("sfx", ["clack", global_position, -3.0, 0.1, 0.8 / size_k])
		S.CHASE:
			if not _player_ok(p) or dist > 14.0 or flat(global_position - home).length() > 22.0:
				_cool = 3.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 10.0
			if dist > 1.5 * size_k:
				_want = to_p.normalized() * RUN
			elif _cool <= 0.0:
				_sting = _rng.randf() < 0.55
				_set_state(S.TELL)
				Net.fx("sfx", ["clack", global_position, -1.0, 0.1, 0.7 / size_k])
		S.TELL:
			_face(to_p)
			_turn = 12.0
			if st_t >= (0.55 if _sting else 0.4) * (1.2 if emperor else 1.0):
				venom = [4.0, 3.0 * (1.5 if emperor else 1.0)] if _sting else []
				_set_state(S.ATTACK)
				_strike(1 if _sting else 0)
				velocity = _fwd() * (1.5 if _sting else 3.5)
		S.ATTACK:
			_want = _fwd() * (2.0 if st_t < 0.12 else 0.0)
			_accel = 30.0
			if st_t > 0.35:
				venom = []
				_cool = _rng.randf_range(0.9, 1.8)
				_set_state(S.CHASE)
		S.FLEE:
			var away := _flee_dir(p.global_position if p else global_position + _fwd())
			_face(away)
			_want = away * RUN
			if st_t > 3.0:
				_set_state(S.WANDER)


func _armor(_hit: HitData, dir: Vector3) -> float:
	return 0.55 if _fwd().dot(-dir) > 0.5 and state != S.DOWN else 1.0


func _after_stun() -> void:
	_set_state(S.CHASE)


func _cry_death() -> void:
	Net.fx("sfx", ["clack", global_position, -2.0, 0.1, 0.5])


# ==========================================================================
# Pose: legs rippling, the tail curled over the back, raised and quivering before it strikes
# ==========================================================================
func _tick(delta: float) -> void:
	var raise := 1.0 if state == S.TELL else (0.0 if state == S.ATTACK and _sting else 0.4)
	anim_a = move_toward(anim_a, raise, delta * (14.0 if state == S.ATTACK else 4.0))
	anim_b = 1.0 if _sting else 0.0


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 18.0 * delta / size_k
	var raise := anim_a
	var quiver := sin(_t * 40.0) * 0.04 if state == S.TELL else 0.0
	# the tail: each joint bends up and forward, more as it raises
	for k in range(_tail.size()):
		(_tail[k] as Node3D).rotation = Vector3(0.35 + raise * 0.38 + quiver + (0.1 if k == 0 else 0.0), 0, sin(_t * 1.3 + k) * 0.03)
	var open := 0.3 + sin(_t * 2.0) * 0.08
	match state:
		S.TELL:
			open = 0.7 if anim_b < 0.5 else 0.45
		S.ATTACK:
			open = 0.05 if anim_b < 0.5 else 0.4
		S.CHASE:
			open = 0.5
	for cl in _claws:
		var s: float = cl[1]
		(cl[0] as Node3D).rotation = Vector3(0.15 * raise, -s * open, 0)
	var flail := 1.0 if state == S.DOWN else (maxf(0.0, 1.0 - _dead_t) if state == S.DEAD else 0.0)
	for l in _legs:
		var s: float = l[1]
		var ph := _gait + (PI * 0.5 if s > 0.0 else 0.0)
		(l[0] as Node3D).rotation = Vector3(cos(ph) * 0.18 * moving, sin(ph) * 0.12 * moving, s * (sin(ph) * 0.25 * moving + sin(_t * 18.0 + s) * 0.4 * flail))
	_body.position.y = 0.2 + absf(sin(_gait * 2.0)) * 0.01 * moving
