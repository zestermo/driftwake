extends JungleBeast
## The Sand King (BeastPool "sandworm", a desert island's boss): a worm as thick as a cart,
## plated like a beetle, that lives under its ground and comes up through it. It hunts by the
## feel of your feet: a hump of sand runs at you under the surface (the tell: a red ring where
## you stood) and it ERUPTS there, throwing you down, then rears over the arena:
##   bite   the head snaps down in front (parry it: it reels)
##   slam   it topples its whole length down a line (a red strip), then dives back under
##   spit   (from half health) a gout of sand at three spots round you (red rings)
## and dives, to come up again under you - twice running from 60%, three times from 30%.
## While it's under the sand nothing reaches it. Looks: dune gold, rust, bone.

const FILM := [["erupt", 2.6], ["bite", 1.6], ["slam", 2.4], ["spit", 1.8], ["dive", 1.6]]
const SEGS := 12
const SEG_LEN := 1.45
const HEAD_R := 1.5
const TALL := 8.0
const WARN := 1.15
const LOOKS := [
	[Color(0.86, 0.66, 0.36), Color(0.62, 0.42, 0.22), Color(0.98, 0.86, 0.6)],
	[Color(0.66, 0.3, 0.16), Color(0.4, 0.18, 0.1), Color(0.9, 0.6, 0.4)],
	[Color(0.9, 0.86, 0.76), Color(0.62, 0.56, 0.48), Color(1.0, 0.96, 0.88)],
]

## 0 under the sand .. 1 reared to its full height.
var rise: float = 0.0
var _segs: Array = []
var _head: Node3D
var _jaws: Array = []
var _col: CollisionShape3D
var _goal := Vector3.ZERO
var _spit: Array = []
var _runs: int = 0
var _lean: float = 0.0
var _trail_t: float = 0.0


func _init() -> void:
	boss_name = "The Sand King"


func _hp_base() -> float:
	return 1900.0


func _poise_max() -> float:
	return 260.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 760


func _coins_base() -> int:
	return 44


func _speed() -> float:
	return 9.0


func _hit_point() -> Vector3:
	return _head.global_position if _head else global_position + Vector3(0, 4.0, 0)


# ==========================================================================
# Body: plated rings on a chain, a head of four jaws round a ring of teeth
# ==========================================================================
func _build() -> void:
	var look: Array = LOOKS[variant % LOOKS.size()]
	var hide := own(PSXMat.lit("leather", look[0]))
	var plate := own(PSXMat.lit("desert_rock", Color(1.0, 0.95, 0.9)))
	var maw := PSXMat.flat(Color(0.35, 0.06, 0.05))
	var tooth := PSXMat.flat(Color(0.95, 0.92, 0.82))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	# one ring mesh, scaled down the body
	var smb := MeshBuilder.new()
	# (a little longer than the spacing: neighbours overlap, no seams)
	var sl := SEG_LEN * 1.15
	smb.add_loft(hide, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -sl * 0.5)), [[0.0, 0.96, 0.96], [sl * 0.2, 1.0, 1.0], [sl * 0.8, 1.0, 1.0], [sl, 0.95, 0.95]],
		MeshBuilder.profile_circle(10), 0.6, look[0])
	for k in range(3):
		var a := PI * 0.5 + (k - 1) * 0.55
		smb.add_box(plate, Transform3D(Basis(Vector3.BACK, a - PI * 0.5), Vector3(cos(a) * 0.98, sin(a) * 0.98, 0.1)), Vector3(0.95, 0.18, SEG_LEN * 0.9), 0.6, (look[1] as Color).lerp(Color.WHITE, 0.25))
	smb.add_blob(hide, Transform3D(Basis(), Vector3(0, -0.85, 0)), Vector3(0.8, 0.25, SEG_LEN * 0.45), rng, 0.05, 2, 7, 0.6, look[2])
	var ring := smb.commit()
	for i in range(SEGS):
		var s := Node3D.new()
		s.name = "Seg%d" % i
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = ring
		s.add_child(mi)
		var r := lerpf(HEAD_R, 0.55, pow(float(i) / (SEGS - 1), 1.3))
		s.scale = Vector3.ONE * r
		model.add_child(s)
		_segs.append(s)
	_head = Node3D.new()
	_head.name = "Head"
	model.add_child(_head)
	var hmb := MeshBuilder.new()
	hmb.add_loft(hide, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.6)), [[0.0, HEAD_R * 1.02, HEAD_R * 1.02], [0.6, HEAD_R * 1.08, HEAD_R * 1.08], [1.0, HEAD_R * 0.95, HEAD_R * 0.95]],
		MeshBuilder.profile_circle(10), 0.6, look[0], true, false)
	hmb.add_cylinder(maw, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.38)), HEAD_R * 0.9, HEAD_R * 0.9, 0.04, 12, 1.0, Color.WHITE, true, false)
	for k in range(14):
		var a := TAU * k / 14.0
		# (a cone grows up +Y: turned to point out of the mouth (-Z), then leant in toward its middle)
		hmb.add_cylinder(tooth, Transform3D(Basis(Vector3(-sin(a), cos(a), 0), -0.6) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(cos(a) * HEAD_R * 0.7, sin(a) * HEAD_R * 0.7, -0.38)),
			0.12, 0.0, 0.5, 4, 1.0, Color.WHITE, false, false, false)
	_head.add_child(hmb.to_instance("Mesh"))
	# four jaws round the mouth, opening like a flower
	for k in range(4):
		var a := TAU * k / 4.0 + PI * 0.25
		var jp := Node3D.new()
		jp.name = "Jaw%d" % k
		jp.position = Vector3(cos(a) * HEAD_R * 0.85, sin(a) * HEAD_R * 0.85, -0.3)
		jp.rotation = Vector3(0, 0, a - PI * 0.5)
		_head.add_child(jp)
		var jmb := MeshBuilder.new()
		var outline := PackedVector2Array([Vector2(-0.75, 0.0), Vector2(0.75, 0.0), Vector2(0.45, 1.5), Vector2(0.0, 1.9), Vector2(-0.45, 1.5)])
		jmb.add_extrude(plate, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), outline, 0.22, 0.6, look[1])
		for t in range(3):
			jmb.add_cylinder(tooth, Transform3D(Basis(Vector3.RIGHT, PI), Vector3((t - 1) * 0.35, -0.12, -0.4 - t % 2 * 0.4)), 0.08, 0.0, 0.35, 4, 1.0, Color.WHITE, false, false, false)
		jmb.add_box(maw, Transform3D(Basis(), Vector3(0, -0.1, -0.8)), Vector3(1.0, 0.04, 1.2), 1.0, Color.WHITE, false)
		jp.add_child(jmb.to_instance("Mesh"))
		_jaws.append(jp)
	# the churned sand round its hole
	var cmb := MeshBuilder.new()
	var sand := PSXMat.lit("desert_sand")
	for k in range(9):
		var a := TAU * k / 9.0 + rng.randf_range(-0.2, 0.2)
		cmb.add_blob(sand, Transform3D(Basis(), Vector3(cos(a), 0.0, sin(a)) * HEAD_R * 1.5), Vector3(1.1, 0.45, 1.1), rng, 0.2, 2, 6, 0.3, Color(0.85, 0.8, 0.75), 0.0)
	cmb.add_cylinder(PSXMat.flat(Color(0.25, 0.18, 0.1)), Transform3D(), HEAD_R * 1.2, HEAD_R * 1.2, 0.05, 12, 1.0, Color.WHITE, true, false)
	var crater := cmb.to_instance("Crater")
	crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(crater)
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = HEAD_R
	cap.height = TALL
	_col.shape = cap
	_col.position = Vector3(0, TALL * 0.5, 0)
	_col.disabled = true
	add_child(_col)
	for k in range(4):
		hurt_ball(HEAD_R * 1.2 - k * 0.15, Vector3.ZERO)


func _ready() -> void:
	_cd = {"bite": 1.0, "slam": 3.0, "spit": 2.0, "dive": 6.0}
	super._ready()
	_fly = true
	model.visible = false
	hurtbox.monitorable = false


# ==========================================================================
# Brain (host): under the sand it hunts; reared up it bites, slams, spits, then dives
# ==========================================================================
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if net_puppet or state == S.DEAD:
		return
	# everyone gone: it sinks and is back under its ground, asleep
	if state == S.RETURN:
		rise = move_toward(rise, 0.0, delta * 1.5)
		if rise <= 0.0:
			global_position = post
			_set_state(S.SLEEP)


func _idle(_delta: float) -> Vector3:
	_yaw = post_yaw
	rise = 0.0
	return Vector3.ZERO


func _wake_move() -> String:
	return "erupt"


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	if rise < 0.5:
		# under: a beat, then up under whoever it hunts
		if mv_t > 0.6:
			_runs = 1 + (1 if phase >= 2 else 0) + (1 if phase >= 3 else 0)
			begin("erupt")
		return Vector3.ZERO
	_face(to)
	if phase >= 2 and _cd["spit"] <= 0.0 and dist > 5.0:
		begin("spit")
	elif dist < 9.0 and _cd["bite"] <= 0.0:
		begin("bite")
	elif _cd["slam"] <= 0.0 and dist < 16.0:
		begin("slam")
	elif _cd["dive"] <= 0.0 or dist > 22.0:
		begin("dive")
	return Vector3.ZERO


func _on_begin(m: String) -> void:
	_fly = true
	var p := _target()
	match m:
		"erupt":
			_goal = ground_at(p.global_position if p else global_position)
			warn_ring(_goal, 4.2, WARN)
			say("slither", global_position, 4.0, 0.5, 120.0)
		"bite":
			_cd["bite"] = _rng.randf_range(2.2, 3.4)
			say("hiss", _hit_point(), 2.0, 0.5)
		"slam":
			_cd["slam"] = _rng.randf_range(7.0, 9.0)
			var d := _flat((p.global_position if p else global_position + _fwd()) - global_position).normalized()
			_face(d)
			_goal = ground_at(global_position + d * (SEGS * SEG_LEN * 0.8))
			warn_lane(global_position, _goal, HEAD_R + 1.0, 1.0)
		"spit":
			_cd["spit"] = _rng.randf_range(6.0, 8.0)
			_spit = []
			var c := p.global_position if p else global_position + _fwd() * 8.0
			for k in range(3):
				var q := ground_at(c + Vector3(cos(TAU * k / 3.0), 0, sin(TAU * k / 3.0)) * (0.0 if k == 0 else _rng.randf_range(3.5, 5.5)))
				_spit.append(q)
				warn_ring(q, 2.6, 0.9, Color(1.0, 0.55, 0.12))
		"dive":
			_cd["dive"] = _rng.randf_range(7.0, 10.0)


func _move_tick(delta: float, _p: Node3D) -> Vector3:
	match move:
		"erupt":
			if mv_t < WARN:
				# the hump of sand runs at the ring under the surface
				rise = move_toward(rise, 0.0, delta * 2.5)
				var to := _flat(_goal - global_position)
				var step := minf(to.length(), (to.length() / maxf(WARN - mv_t, 0.1)) * delta)
				if to.length() > 0.1:
					global_position += to.normalized() * step
					_face(to)
				global_position.y = ground_at(global_position).y
				_trail(delta)
			else:
				if not _hit:
					_hit = true
					global_position = _goal
					strike("ring", [_goal, 4.2], 26.0, true, false, 1.2, 12.0)
					quake(_goal, 1.4)
					Net.fx("puff", [_goal + Vector3.UP * 0.5, "sand", 10, 3.5, 1.4, Color.WHITE, 3.0, Vector3.UP])
					say("bellow", _goal, 6.0, 0.6, 140.0)
				rise = move_toward(rise, 1.0, delta * 2.2)
				if rise >= 1.0:
					_runs -= 1
					end_move(0.4)
					if _runs > 0:
						begin("dive")
		"bite":
			_lean = sin(clampf((mv_t - 0.5) / 0.4, 0.0, 1.0) * PI) if mv_t > 0.5 else -0.25 * minf(mv_t / 0.5, 1.0)
			if mv_t > 0.62 and not _hit:
				_hit = true
				strike("cone", [global_position, _fwd(), 9.5, 38.0], 22.0, true, true, 1.6)
				Net.fx("puff", [global_position + _fwd() * 7.0, "sand", 5, 2.0, 0.9, Color.WHITE, 1.5, Vector3.UP])
			if mv_t > 1.3:
				_lean = 0.0
				end_move(0.6)
		"slam":
			_lean = -0.3 * minf(mv_t / 1.0, 1.0) if mv_t < 1.0 else minf((mv_t - 1.0) / 0.35, 1.0) * 1.6
			if mv_t > 1.3 and not _hit:
				_hit = true
				strike("lane", [global_position, _goal, HEAD_R + 0.6], 30.0, true, false, 1.3, 14.0)
				for k in range(4):
					quake(global_position.lerp(_goal, 0.3 + k * 0.2), 0.8)
			if mv_t > 1.9:
				_lean = 0.0
				begin("dive")
		"spit":
			_lean = -0.2 if mv_t < 0.6 else 0.3
			if mv_t > 0.9 and not _hit:
				_hit = true
				for q in _spit:
					strike("ring", [q, 2.6], 16.0, false, false, 1.1)
					Net.fx("puff", [q + Vector3.UP * 0.4, "sand", 6, 2.2, 1.0, Color.WHITE, 1.8, Vector3.UP])
			if mv_t > 1.4:
				_lean = 0.0
				end_move(0.5)
		"dive":
			rise = move_toward(rise, 0.0, delta * 1.6)
			if not _hit and rise < 0.6:
				_hit = true
				Net.fx("puff", [global_position + Vector3.UP * 0.5, "sand", 8, 3.0, 1.2, Color.WHITE, 2.0, Vector3.UP])
				Net.fx("sfx", ["rock_crash", global_position, 2.0, 0.1, 0.6])
			if rise <= 0.0:
				end_move(0.0)
	return Vector3.ZERO


## The hump of sand it pushes along under the surface: puffs behind it, on every screen.
func _trail(delta: float) -> void:
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.12
		Net.fx("puff", [global_position + Vector3.UP * 0.3, "sand", 2, 1.6, 0.8, Color.WHITE, 0.8, Vector3.UP])


func _armoured() -> bool:
	return rise < 0.9 or move == "slam"


func _parry_ok() -> bool:
	return move == "bite" and mv_t > 0.45 and mv_t < 0.75


func _on_stagger() -> void:
	say("hiss", _hit_point(), 3.0, 0.7)
	_lean = 0.0


func _on_phase(_n: int) -> void:
	say("bellow", _hit_point(), 6.0, 0.5, 140.0)
	_cd["spit"] = 0.0


func _on_die() -> void:
	say("bellow", _hit_point(), 6.0, 0.4, 140.0)


## (it sets its own place: never physics-moved, never falling)
func end_move(recover: float = 0.0) -> void:
	super.end_move(recover)
	_fly = true


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": (LOOKS[variant % LOOKS.size()][0] as Color)}, "Sand King's Mantle", t)


func _pack_extra() -> Array:
	return [rise, _lean]


func _unpack_extra(a: Array, b: Array, f: float) -> void:
	if a.size() < 2 or b.size() < 2:
		return
	rise = lerpf(float(a[0]), float(b[0]), f)
	_lean = lerpf(float(a[1]), float(b[1]), f)


# ==========================================================================
# Pose: the body out of its hole along an arc, the head at its tip, the jaws
# ==========================================================================
func _animate(delta: float) -> void:
	var up := rise
	if state == S.DEAD:
		up = maxf(0.0, 1.0 - _dead_t / 2.5) * 0.8
		_lean = minf(_lean + delta * 0.8, 1.8)
	model.visible = up > 0.02
	hurtbox.monitorable = up > 0.6 and state != S.DEAD
	if is_instance_valid(_col):
		_col.disabled = up < 0.6 or state == S.DEAD
	if not model.visible:
		return
	var sway := sin(_t_anim * 1.1) * 0.12
	_t_anim += delta
	# the arc: from deep in its hole up and over toward where it faces; the head runs up it as it rises
	var p0 := Vector3(0, -6.0, 0.5)
	var top := TALL * (1.0 - absf(_lean) * 0.25)
	var p1 := Vector3(sway * 3.0, top * 1.15, 0.8)
	var p2 := Vector3(sway * 5.0, top * (0.85 - maxf(_lean, 0.0) * 0.55), -4.0 - maxf(_lean, 0.0) * 6.0 + minf(_lean, 0.0) * -3.0)
	var length := SEGS * SEG_LEN
	var head_t := clampf(up, 0.0, 1.0)
	var pts: Array = []
	for i in range(SEGS + 1):
		var t := head_t - float(i) * SEG_LEN / length
		pts.append(_bez(p0, p1, p2, t) if t >= 0.0 else p0 + Vector3(0, t * length, 0))
	_head.position = pts[0]
	var hd: Vector3 = (pts[0] - pts[1]).normalized()
	_head.basis = Basis.looking_at(hd, Vector3.UP if absf(hd.y) < 0.95 else Vector3.BACK)
	for i in range(SEGS):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var s: Node3D = _segs[i]
		s.position = (a + b) * 0.5
		var d := (a - b).normalized()
		var sc := s.scale
		s.basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.BACK).scaled(sc)
		s.visible = maxf(a.y, b.y) > -0.3
	var open := 0.15 + sin(_t_anim * 2.0) * 0.05
	match move:
		"bite":
			open = 0.9 if mv_t < 0.62 else 0.1
		"erupt":
			open = 0.8
		"spit":
			open = 1.0 if mv_t > 0.8 else 0.5
	if state == S.STAGGER:
		open = 0.6
	for j in _jaws:
		(j as Node3D).rotation.x = -open * 0.9
	for k in range(4):
		(hurtbox.get_child(k) as CollisionShape3D).position = model.basis * (pts[mini(k * 2, SEGS)] as Vector3)


var _t_anim: float = 0.0


static func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t
