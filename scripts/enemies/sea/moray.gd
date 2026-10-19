extends Creature
## A moray eel in a hole among the rocks by a reef or a wreck, its head out, jaws working. Dive close
## in front of it and it tells you first (it draws back, gapes, eyes lit, a burst of bubbles) for TELL s,
## then lunges a couple of metres out at you and snaps back into its hole. It never leaves the hole;
## struck, it pulls in and hides a while. The host runs it (Creature's co-op); SeaThreats puts it to sleep far off.

const REACH := 3.6
const TELL := 0.65
const LUNGE := 1.8
const STRIKE_TIME := 0.32
const HIDE := 5.0
const COOL := 2.4

var _lunge := 0.0
var _hide_t := 0.0
var _head: Node3D
var _neck: Node3D


func _setup(args: Dictionary) -> void:
	kind = "moray"
	size_k = float(args.get("size", 1.0))
	max_hp = 70.0
	xp = 40
	coins = Vector2i(0, 0)
	flying = true
	skin_tex = "scales"


func _start() -> void:
	_set_state(S.IDLE)


func in_combat() -> bool:
	return state in [S.TELL, S.ATTACK, S.RECOVER]


func _body_shape() -> Array:
	return [0.3, 0.6, Vector3(0.6, 0.6, 1.0)]


func _moves() -> Array:
	return [[11.0, 4.0, Vector3(0.9, 0.9, 1.0), Vector3(0, 0.45, -2.2), false, 0.35]]


func _can_knock() -> bool:
	return false


func _player_ok(p: Node3D) -> bool:
	if not super(p):
		return false
	return p.has_method("current_state_name") and str(p.call("current_state_name")) == "Swim"


func _build() -> void:
	var skin := _skin()
	var col := Color(0.42, 0.46, 0.2)
	var spots := Color(0.78, 0.74, 0.4)
	var rock := PSXMat.lit("rock", Color(0.72, 0.74, 0.7))
	_part(model, "Rocks", Vector3.ZERO, "rocks", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		# a heap of stones round the hole's mouth, the hole facing -z
		for i in range(4):
			var a := float(i) / 4.0 * TAU + 0.4
			mb.add_blob(rock, Transform3D(Basis(), Vector3(cos(a) * 0.45, 0.2, sin(a) * 0.3 + 0.45)), Vector3(0.38, 0.32, 0.34), rng, 0.25, 4, 6)
		# the hole's dark mouth
		mb.add_cylinder(PSXMat.flat(Color(0.03, 0.04, 0.05)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.45, 0.1)), 0.3, 0.3, 0.05, 7, 0.5, Color.WHITE, true, false, false))
	_neck = _part(model, "Neck", Vector3(0, 0.45, 0.0), "neck", func(mb: MeshBuilder, _rng2: RandomNumberGenerator):
		mb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.4)), 0.2, 0.17, 0.9, 7, 1.0, col))
	_head = _part(_neck, "Head", Vector3(0, 0, -0.5), "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis(), Vector3(0, 0.03, -0.14)), Vector3(0.21, 0.24, 0.36), rng, 0.08, 3, 7, 1.0, col)
		mb.add_blob(skin, Transform3D(Basis(), Vector3(0, -0.1, -0.26)), Vector3(0.17, 0.08, 0.28), rng, 0.08, 3, 6, 1.0, spots)
		for s in [-1.0, 1.0]:
			mb.add_box(PSXMat.glow(Color(0.9, 0.85, 0.3), 1.2), Transform3D(Basis(), Vector3(s * 0.14, 0.14, -0.3)), Vector3(0.05, 0.05, 0.05), 1.0, Color.WHITE, false, false))


func _tick(delta: float) -> void:
	flying = true
	_hide_t = maxf(_hide_t - delta, 0.0)
	var want := 0.0
	match state:
		S.TELL:
			want = -0.35
		S.ATTACK:
			want = LUNGE
		S.HIDE:
			want = -0.9
	_lunge = move_toward(_lunge, want, delta * (14.0 if state == S.ATTACK else 3.0))
	anim_a = _lunge
	anim_b = move_toward(anim_b, 1.0 if state in [S.TELL, S.ATTACK] else 0.0, delta * 6.0)


func _brain(_delta: float) -> void:
	var p := _target()
	match state:
		S.IDLE, S.WANDER:
			if _cool > 0.0 or not _player_ok(p):
				return
			var to_p := p.global_position + Vector3(0, 0.8, 0) - (global_position + Vector3(0, 0.45, 0))
			if to_p.length() < REACH and _fwd().dot(flat(to_p).normalized()) > 0.2:
				_face(flat(to_p))
				_set_state(S.TELL)
				Net.fx("bubbles", [global_position + Vector3(0, 0.6, 0) + _fwd() * 0.4, 8])
				Net.fx("sfx", ["hiss", global_position, -4.0, 0.1, 0.7])
		S.TELL:
			if st_t >= TELL:
				_set_state(S.ATTACK)
				_strike(0)
				Net.fx("sfx", ["chitter", global_position, -3.0, 0.1, 0.6])
		S.ATTACK:
			if st_t >= STRIKE_TIME:
				_set_state(S.IDLE)
				_cool = COOL
		S.HIDE:
			if _hide_t <= 0.0:
				_set_state(S.IDLE)


## It never moves from its hole.
func _fly(_delta: float) -> void:
	velocity = Vector3.ZERO


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	_hide_t = HIDE
	_set_state(S.HIDE)
	return true


func _dead_update(delta: float) -> void:
	_dead_t += delta
	_neck.scale = Vector3.ONE * maxf(1.0 - _dead_t / 2.0, 0.01)
	if _dead_t > 2.0:
		_neck.visible = false
		set_physics_process(false)


func _pose(_delta: float) -> void:
	var sway := sin(_t * 2.2) * 0.15 * (1.0 - anim_b)
	_neck.position = Vector3(0, 0.45, -_lunge * 0.5)
	_neck.rotation = Vector3(sin(_t * 1.6) * 0.08, sway, 0.0)
	_head.position = Vector3(0, 0, -0.5 - maxf(_lunge, 0.0) * 0.5)
	_head.rotation.x = anim_b * 0.35 + sin(_t * 5.0) * 0.06
