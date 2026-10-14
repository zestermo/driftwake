class_name Crab
extends Creature
## Shore crabs, scuttling sideways along the sand. Get close and one turns on
## you: claws up and clacking (the tell), then a lunging PINCH. Its shell turns
## blows from the front - go round it, or flip it with a heavy hit: on its back
## it kicks helplessly for a while. Giants (rare) are as big as a cart and their
## pinch throws you. Morphs: red, violet-blue, sand.

const NOTICE := 5.5
const COLORS := [
	[Color(0.78, 0.22, 0.1), Color(0.95, 0.65, 0.4), Color(0.25, 0.08, 0.04)],
	[Color(0.3, 0.25, 0.6), Color(0.55, 0.65, 0.9), Color(0.1, 0.08, 0.2)],
	[Color(0.75, 0.62, 0.4), Color(0.92, 0.85, 0.65), Color(0.3, 0.22, 0.12)],
]

var morph: int = 0
var giant := false
var _gait: float = 0.0
var _pinches: int = 0
var _shell: Node3D
var _claws: Array = []
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "crab"
	morph = int(args.get("morph", 0))
	giant = bool(args.get("giant", false))
	size_k = 1.7 if giant else 1.0
	max_hp = 40.0 * (2.5 if giant else 1.0)
	xp = 70 if giant else 25
	coins = Vector2i(2, 5) if giant else Vector2i(0, 2)
	drops = [["crab_meat", 0.95 if giant else 0.55, 2 if giant else 1]]
	flips = true
	skin_tex = "rock"


func _body_shape() -> Array:
	return [0.28, 0.4, Vector3(0.95, 0.5, 0.75)]


func _moves() -> Array:
	return [[10.0, 3.5, Vector3(1.0, 0.6, 0.6), Vector3(0, 0.25, -0.5), false, 0.3],
		[22.0, 7.0, Vector3(1.0, 0.6, 0.6), Vector3(0, 0.25, -0.5), true, 0.45]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var shell: Color = c[0]
	var pale: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var m := "m%d_" % morph
	_shell = _part(model, "Shell", Vector3(0, 0.22, 0), m + "shell", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.32, 0.1, 0.24), rng, 0.06, 3, 9, 1.5, shell)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0.0)), Vector3(0.28, 0.06, 0.21), rng, 0.03, 2, 8, 1.5, pale)
		for k in range(5):
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.16, 0.16), 0.08, rng.randf_range(-0.1, 0.12))), Vector3(0.05, 0.03, 0.04), rng, 0.1, 2, 5, 1.5, shell.darkened(0.15))
		for s in [-1.0, 1.0]:
			# eyes on stalks
			Creature.seg(mb, skin, Vector3(s * 0.06, 0.06, -0.2), Vector3(s * 0.08, 0.17, -0.22), 0.025, shell)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.08, 0.19, -0.22)), Vector3(0.025, 0.025, 0.025), rng, 0.0, 2, 5, 1.5, Color(0.04, 0.03, 0.03))
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.235)), Vector3(0.12, 0.04, 0.02), 1.5, dark, false, false), true)
	for s in [-1.0, 1.0]:
		var claw := _part(_shell, "Claw", Vector3(s * 0.2, 0.0, -0.18), m + ("claw_l" if s < 0.0 else "claw_r"), func(mb: MeshBuilder, rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.12, 0.02, -0.12), 0.06, shell)
			var big := 1.25 if s > 0.0 else 1.0
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.15, 0.04, -0.22)), Vector3(0.07, 0.065, 0.11) * big, rng, 0.04, 3, 6, 1.5, shell)
			var finger := PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0.008, -0.13 * big)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.15, 0.06, -0.3 * big)), finger, 0.04, 1.5, dark)
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.35), Vector3(s * 0.15, 0.0, -0.3 * big)), finger, 0.035, 1.5, pale))
		_claws.append([claw, s])
		var legs := _part(_shell, "Legs", Vector3(s * 0.22, -0.02, 0.04), m + ("legs_l" if s < 0.0 else "legs_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			for k in range(3):
				var z := -0.06 + k * 0.1
				Creature.seg(mb, skin, Vector3(0, 0, z), Vector3(s * 0.18, 0.08, z + 0.02), 0.03, shell)
				Creature.seg(mb, skin, Vector3(s * 0.18, 0.08, z + 0.02), Vector3(s * 0.27, -0.2, z + 0.04), 0.022, shell.darkened(0.2)))
		_legs.append([legs, s])


func _brain(_delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.IDLE, S.WANDER:
			# sideways: it faces across its way
			if _wander_wait <= 0.0:
				var d := flat(_wander_to - global_position)
				if d.length() > 0.5:
					_yaw = atan2(-d.x, -d.z) + PI * 0.5
					_want = d.normalized() * 1.6
					if d.length() < 0.6:
						_wander_wait = _rng.randf_range(1.0, 3.0)
				else:
					_wander_wait = _rng.randf_range(1.0, 3.0)
				if get_real_velocity().length() < 0.1 and st_t > 0.5:
					_stuck += get_physics_process_delta_time()
					if _stuck > 0.8:
						_stuck = 0.0
						_pick_wander(Vector2(2.0, 6.0))
			else:
				_wander_wait -= get_physics_process_delta_time()
				if _wander_wait <= 0.0:
					_pick_wander(Vector2(2.0, 6.0))
			if _player_ok(p) and dist < Stealth.range_for(p, global_position, _fwd(), NOTICE * size_k) and _cool <= 0.0:
				_set_state(S.CHASE)
				Net.fx("sfx", ["clack", global_position, -3.0, 0.1, 1.0 / size_k])
		S.CHASE:
			if not _player_ok(p) or dist > 12.0 or flat(global_position - home).length() > 20.0:
				_cool = 3.0
				_wander_to = home
				_set_state(S.WANDER)
				return
			_face(to_p)
			_turn = 9.0
			if dist > 1.6 * size_k:
				# a sidelong scuttle in, then square up
				_want = (to_p.normalized() + to_p.normalized().cross(Vector3.UP) * sin(_t * 1.5) * 0.8).normalized() * 2.3
			elif _cool <= 0.0:
				_pinches = 0
				_set_state(S.TELL)
				Net.fx("sfx", ["clack", global_position, -1.0, 0.1, 0.9 / size_k])
		S.TELL:
			_face(to_p)
			_turn = 10.0
			if st_t >= (0.6 if giant else 0.45):
				_set_state(S.ATTACK)
				_strike(1 if giant else 0)
				velocity = _fwd() * 3.0
		S.ATTACK:
			_want = _fwd() * (2.5 if st_t < 0.15 else 0.0)
			_accel = 30.0
			if st_t > 0.3:
				_pinches += 1
				if _pinches < 2 and _rng.randf() < 0.5:
					_set_state(S.TELL)
					st_t = 0.2
				else:
					_cool = _rng.randf_range(0.8, 1.5)
					_set_state(S.CHASE)


func _armor(_hit: HitData, dir: Vector3) -> float:
	# from the front, it's all shell and claw
	return 0.45 if _fwd().dot(-dir) > 0.5 and state != S.DOWN else 1.0


func _after_stun() -> void:
	_set_state(S.CHASE)


func _cry_death() -> void:
	Net.fx("sfx", ["clack", global_position, -2.0, 0.1, 0.6])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 16.0 * delta / size_k
	var raise := 0.0
	var snap := 0.3 + sin(_t * 3.0) * 0.1
	match state:
		S.TELL:
			raise = 1.0
			snap = 0.5 + sin(_t * 26.0) * 0.4
		S.ATTACK:
			raise = 0.2
			snap = 0.0 if st_t > 0.1 else 0.9
		S.CHASE:
			raise = 0.45
	for cl in _claws:
		var s: float = cl[1]
		(cl[0] as Node3D).rotation = Vector3(raise * 0.9, -s * snap * 0.5, -s * raise * 0.3)
	var flail := 1.0 if state == S.DOWN else (maxf(0.0, 1.0 - _dead_t) if state == S.DEAD else 0.0)
	for l in _legs:
		var s: float = l[1]
		var ph := _gait + (PI if s > 0.0 else 0.0)
		var lift := sin(ph) * 0.35 * moving + sin(_t * 17.0 + s) * 0.5 * flail
		(l[0] as Node3D).rotation = Vector3(cos(ph) * 0.2 * moving, 0, s * lift)
	_shell.position.y = 0.22 + absf(sin(_gait)) * 0.015 * moving
