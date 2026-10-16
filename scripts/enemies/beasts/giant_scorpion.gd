extends JungleBeast
## The Dune Emperor (BeastPool "giant_scorpion", a desert island's boss): a scorpion as long
## as a longboat, black-plated, its sting the size of an anchor. It stalks you on eight legs:
##   pinch   both claws snap shut in front (parry it: it reels)
##   sting   the tail arches high and quivers, a red ring where you stand, then stabs down
##           there: it throws you down and its venom burns for a while
##   sweep   (from 60%) the tail swings round it low (jump it)
##   ambush  (from 30%) it burrows into the sand and bursts up under you (a red ring)
## Looks: black, sand gold, blood red.

const LOOKS := [
	[Color(0.16, 0.14, 0.14), Color(0.34, 0.3, 0.28), Color(0.7, 0.16, 0.1)],
	[Color(0.84, 0.64, 0.32), Color(0.95, 0.82, 0.55), Color(0.42, 0.26, 0.12)],
	[Color(0.55, 0.12, 0.08), Color(0.8, 0.35, 0.22), Color(0.22, 0.06, 0.04)],
]
const FILM := [["pinch", 1.2], ["sting", 1.8], ["sweep", 1.6], ["ambush", 2.6]]
const BODY_Y := 1.1
const TAIL := 6

var _tail: Array = []
var _claws: Array = []
var _legs: Array = []
var _body: Node3D
var _aim := Vector3.ZERO
var _gait: float = 0.0
var _last := Vector3.ZERO
var _spd: float = 0.0
var _t_anim: float = 0.0


func _init() -> void:
	boss_name = "The Dune Emperor"


func _hp_base() -> float:
	return 1600.0


func _poise_max() -> float:
	return 230.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 720


func _coins_base() -> int:
	return 42


func _speed() -> float:
	return 5.6 if phase < 3 else 6.6


func _hit_point() -> Vector3:
	return global_position + Vector3(0, BODY_Y + 0.4, 0)


func _build() -> void:
	var look: Array = LOOKS[variant % LOOKS.size()]
	var shell := own(PSXMat.lit("leather", Color.WHITE))
	var dark: Color = look[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9213
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, BODY_Y, 0)
	model.add_child(_body)
	var bmb := MeshBuilder.new()
	bmb.add_blob(shell, Transform3D(Basis(), Vector3(0, 0, -1.1)), Vector3(1.2, 0.5, 1.1), rng, 0.04, 3, 9, 0.8, look[0])
	for k in range(6):
		var z := -0.2 + k * 0.48
		bmb.add_blob(shell, Transform3D(Basis(), Vector3(0, 0.03 * k, z)), Vector3(1.15 - absf(k - 1.5) * 0.08, 0.42, 0.34), rng, 0.03, 2, 9, 0.8, (look[0] as Color).darkened(0.08 * (k % 2)))
		bmb.add_box(shell, Transform3D(Basis(), Vector3(0, 0.38, z)), Vector3(0.9, 0.08, 0.3), 0.8, look[1])
	bmb.add_blob(shell, Transform3D(Basis(), Vector3(0, -0.32, 0.3)), Vector3(0.95, 0.15, 1.9), rng, 0.02, 2, 8, 0.8, look[1])
	var eye := PSXMat.glow(Color(1.0, 0.3, 0.15), 2.4)
	for s in [-1.0, 1.0]:
		bmb.add_box(eye, Transform3D(Basis(), Vector3(s * 0.22, 0.38, -1.85)), Vector3(0.12, 0.1, 0.1), 1.0)
	bmb.add_box(shell, Transform3D(Basis(), Vector3(0, -0.15, -2.15)), Vector3(0.5, 0.2, 0.2), 1.0, dark, false, false)
	_body.add_child(bmb.to_instance("Mesh"))
	# the tail: six plated segments on a chain, the sting on the last
	var prev := _body
	var at := Vector3(0, 0.15, 2.6)
	for k in range(TAIL):
		var seg := Node3D.new()
		seg.name = "Tail%d" % k
		seg.position = at
		prev.add_child(seg)
		var r := 0.48 - k * 0.04
		var tmb := MeshBuilder.new()
		tmb.add_blob(shell, Transform3D(Basis(), Vector3(0, 0, 0.42)), Vector3(r, r, 0.55), rng, 0.04, 3, 7, 0.8, (look[0] as Color).darkened(0.04 * k))
		tmb.add_box(shell, Transform3D(Basis(), Vector3(0, r * 0.9, 0.42)), Vector3(r * 1.1, 0.08, 0.6), 0.8, look[1])
		if k == TAIL - 1:
			tmb.add_blob(shell, Transform3D(Basis(), Vector3(0, -0.05, 1.05)), Vector3(0.42, 0.4, 0.5), rng, 0.04, 3, 7, 0.8, look[1])
			var barb := PackedVector2Array([Vector2(-0.18, 0), Vector2(0.18, 0), Vector2(0.0, 1.1)])
			tmb.add_extrude(shell, Transform3D(Basis(Vector3.RIGHT, PI * 0.6), Vector3(0, -0.2, 1.4)), barb, 0.16, 0.8, dark)
		seg.add_child(tmb.to_instance("Mesh"))
		# (curled over its back from the start: asleep, it isn't posed)
		seg.rotation.x = -0.67 if k == 0 else -0.42
		_tail.append(seg)
		prev = seg
		at = Vector3(0, 0, 0.85)
	# claws: arms out front, a great pincer each
	for s in [-1.0, 1.0]:
		var claw := Node3D.new()
		claw.name = "Claw"
		claw.position = Vector3(s * 0.75, -0.05, -1.8)
		_body.add_child(claw)
		var cmb := MeshBuilder.new()
		Creature.seg(cmb, shell, Vector3.ZERO, Vector3(s * 0.9, 0.0, -0.7), 0.32, look[0])
		Creature.seg(cmb, shell, Vector3(s * 0.9, 0.0, -0.7), Vector3(s * 1.0, 0.1, -1.6), 0.28, look[0])
		cmb.add_blob(shell, Transform3D(Basis(), Vector3(s * 1.05, 0.12, -2.1)), Vector3(0.5, 0.42, 0.75), rng, 0.04, 3, 7, 0.8, look[0])
		var finger := PackedVector2Array([Vector2(-0.16, 0), Vector2(0.16, 0), Vector2(0.04, -1.0)])
		cmb.add_extrude(shell, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(s * 0.9, 0.3, -2.6)), finger, 0.26, 0.8, dark)
		cmb.add_extrude(shell, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.3), Vector3(s * 1.25, -0.05, -2.6)), finger, 0.22, 0.8, look[1])
		claw.add_child(cmb.to_instance("Mesh"))
		_claws.append([claw, s])
		for k in range(4):
			var leg := Node3D.new()
			leg.name = "Leg"
			leg.position = Vector3(s * 0.9, -0.1, -0.8 + k * 0.6)
			_body.add_child(leg)
			var lmb := MeshBuilder.new()
			Creature.seg(lmb, shell, Vector3.ZERO, Vector3(s * 0.85, 0.35, k * 0.15 - 0.2), 0.24, look[0])
			Creature.seg(lmb, shell, Vector3(s * 0.85, 0.35, k * 0.15 - 0.2), Vector3(s * 1.35, -BODY_Y + 0.05, k * 0.3 - 0.4), 0.18, (look[0] as Color).darkened(0.2))
			leg.add_child(lmb.to_instance("Mesh"))
			_legs.append([leg, s, k])
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.2
	cap.height = 4.4
	col.shape = cap
	col.rotation = Vector3(PI * 0.5, 0, 0)
	col.position = Vector3(0, 1.2, 0)
	add_child(col)
	hurt_ball(1.5, Vector3(0, BODY_Y + 0.2, -0.8))
	hurt_ball(1.4, Vector3(0, BODY_Y + 0.2, 1.0))
	hurt_ball(0.9, Vector3(0, BODY_Y + 2.5, 2.5))


func _ready() -> void:
	_cd = {"pinch": 0.6, "sting": 2.0, "sweep": 99.0, "ambush": 99.0}
	super._ready()
	_last = global_position


func _wake_move() -> String:
	return "sting"


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	if phase >= 3 and _cd["ambush"] <= 0.0 and dist > 6.0:
		begin("ambush")
	elif phase >= 2 and dist < 5.5 and _cd["sweep"] <= 0.0:
		begin("sweep")
	elif dist < 5.0 and _cd["pinch"] <= 0.0:
		begin("pinch")
	elif dist < 11.0 and _cd["sting"] <= 0.0:
		begin("sting")
	elif dist > 4.0:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _on_phase(n: int) -> void:
	say("hiss", global_position, 4.0, 0.5)
	if n == 2:
		_cd["sweep"] = 0.0
	else:
		_cd["ambush"] = 0.0


func _on_begin(m: String) -> void:
	var p := _target()
	match m:
		"pinch":
			_cd["pinch"] = _rng.randf_range(1.8, 2.6)
			say("click", global_position, 2.0, 0.6)
		"sting":
			_cd["sting"] = _rng.randf_range(4.0, 5.5)
			_aim = ground_at(p.global_position if p else global_position + _fwd() * 6.0)
			warn_ring(_aim, 2.6, 1.0)
			say("hiss", global_position, 2.0, 0.6)
		"sweep":
			_cd["sweep"] = _rng.randf_range(5.0, 7.0)
			warn_ring(global_position, 6.2, 0.8)
		"ambush":
			_cd["ambush"] = _rng.randf_range(9.0, 12.0)
			Net.fx("puff", [global_position + Vector3.UP * 0.5, "sand", 8, 3.0, 1.2, Color.WHITE, 2.0, Vector3.UP])


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"pinch":
			if p and mv_t < 0.3:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.42 and not _hit:
				_hit = true
				strike("cone", [global_position, _fwd(), 5.6, 50.0], 18.0, false, true, 1.2)
				Net.fx("sfx", ["clack", global_position + _fwd() * 3.0, 4.0, 0.05, 0.5])
			if mv_t > 0.9:
				end_move(0.4)
		"sting":
			if mv_t > 1.0 and not _hit:
				_hit = true
				strike("ring", [_aim, 2.6], 24.0, true, false, 1.1)
				_venom(_aim, 2.6)
				Net.fx("puff", [_aim + Vector3.UP * 0.3, "sand", 5, 1.8, 0.9, Color.WHITE, 1.4, Vector3.UP])
				Net.fx("sfx", ["rock_crash", _aim, 2.0, 0.1, 0.9])
			if mv_t > 1.6:
				end_move(0.6)
		"sweep":
			if mv_t > 0.8 and not _hit:
				_hit = true
				strike("ring", [global_position, 6.2], 16.0, true, false, 1.0)
				Net.fx("dust_ring", [global_position, 24, 2.0])
			if mv_t > 1.4:
				end_move(0.5)
		"ambush":
			if mv_t < 0.5:
				return Vector3.ZERO
			if mv_t < 1.8:
				model.visible = false
				hurtbox.monitorable = false
				if p and not _hit:
					_aim = ground_at(p.global_position)
				if p and mv_t > 0.6 and mv_t < 0.62 + get_physics_process_delta_time():
					warn_ring(_aim, 3.2, 1.1)
				return Vector3.ZERO
			if not _hit:
				_hit = true
				global_position = _aim
				reset_physics_interpolation()
				model.visible = true
				hurtbox.monitorable = true
				strike("ring", [_aim, 3.2], 22.0, true, false, 1.1)
				quake(_aim, 1.0)
				Net.fx("puff", [_aim + Vector3.UP * 0.5, "sand", 10, 3.0, 1.3, Color.WHITE, 2.4, Vector3.UP])
			if mv_t > 2.4:
				end_move(0.5)
	return Vector3.ZERO


## The sting's venom on whoever it struck (each captain's own machine, like the strike).
func _venom(at: Vector3, r: float) -> void:
	_venom_local(at, r)
	Net.event(self, "venom", [at, r])


func _venom_local(at: Vector3, r: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and BeastShapes.inside("ring", [at, r], me.global_position, 1.1):
		PoisonStatus.apply(me, 5.0, 4.0 * Levels.dmg_k(level, _lv_ref()), null)


func _event(what: String, args: Array) -> void:
	if what == "venom":
		_venom_local(args[0], float(args[1]))


func _parry_ok() -> bool:
	return move == "pinch" and mv_t > 0.25 and mv_t < 0.5


func _armoured() -> bool:
	return move in ["sting", "ambush"] and mv_t > 0.6


func _on_stagger() -> void:
	say("hiss", global_position, 3.0, 0.8)
	model.visible = true
	hurtbox.monitorable = true


func _on_die() -> void:
	say("hiss", global_position, 4.0, 0.4)
	model.visible = true


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": (LOOKS[variant % LOOKS.size()][0] as Color)}, "Emperor's Carapace Cloak", t)


func _animate(delta: float) -> void:
	_t_anim += delta
	var moved := _flat(global_position - _last)
	_last = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	var moving := clampf(_spd / 2.0, 0.0, 1.0)
	_gait += delta * _spd * 1.6
	# the tail: curled up over the back; raised high and quivering for the sting, stabbing down, swung for the sweep
	var raise := 0.35
	var swing := 0.0
	match move:
		"sting":
			raise = 0.75 + sin(_t_anim * 40.0) * 0.03 if mv_t < 0.95 else -0.1
		"sweep":
			raise = 0.0
			swing = sin(clampf((mv_t - 0.6) / 0.5, 0.0, 1.0) * PI) * 2.2 if mv_t > 0.6 else -0.3
	if state == S.DEAD:
		raise = -0.15
	for k in range(_tail.size()):
		var t: Node3D = _tail[k]
		t.rotation.x = lerp_angle(t.rotation.x, -(0.32 + raise * 0.3) if k > 0 else -0.5 - raise * 0.5, minf(delta * 12.0, 1.0))
		t.rotation.y = swing * 0.3 if k == 0 else 0.0
	var open := 0.25 + sin(_t_anim * 1.5) * 0.05
	if move == "pinch":
		open = 0.8 if mv_t < 0.4 else 0.0
	for c in _claws:
		var s: float = c[1]
		(c[0] as Node3D).rotation = Vector3(0.1 if move == "pinch" and mv_t < 0.4 else 0.0, -s * open * 0.6, 0)
	for l in _legs:
		var s: float = l[1]
		var ph := _gait + float(l[2]) * 1.4 + (PI if s > 0.0 else 0.0)
		(l[0] as Node3D).rotation = Vector3(cos(ph) * 0.2 * moving, sin(ph) * 0.25 * moving, 0)
	_body.position.y = BODY_Y + (0.0 if state != S.DEAD else -0.5) + absf(sin(_gait * 2.0)) * 0.04 * moving
