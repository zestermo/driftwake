extends JungleBeast
## The Sand King (BeastPool "sandworm", a desert island's boss): a worm as thick as a cart,
## plated like a beetle, that lives under its ground and comes up through it. It hunts by the
## feel of your feet: a hump of sand runs at you under the surface (the tell: a red ring where
## you stood) and it ERUPTS there in a geyser of sand, then rears over the arena:
##   bite      the mandibles snap down in front (parry it: it reels); its head lies on the sand after
##   slam      it topples its whole length down a line (a red strip, its one knockdown) and lies there a while
##             (run up its back: its plates), then dives back under
##   dive      under again (once a cycle), to come up under you
## 1.23 beast pass (BeastPass, docs/v1_23_previews.md section 6): phase 2 adds the Sinkhole (the ground funnels toward
## a pit) and the Acid Spit (three spots round you), in pairs; phase 3 adds the Twin (a second, smaller worm surfaces
## with it and bites for a round) and the Sandstorm (the arena fills with blowing sand; it hunts by sound, so a captain
## standing still is lost to it), in chains of three. Never the same move twice running. Each phase change: it rears
## roaring, a ring of sand bends out from it. Parts: two armour plates on its back (each broken: +25% damage taken; a
## Sand King Plate), the mandibles (no Bite once broken; a Mandible). Looks: heat rising off it from phase 2, its plates
## glowing like coals in phase 3. While it's under the sand nothing reaches it. Looks: dune gold, rust, bone.

const FILM := [["erupt", 2.6], ["bite", 1.8], ["slam", 3.4], ["spit", 1.8], ["dive", 1.6], ["sinkhole", 6.0], ["twin", 5.0],
	["sandstorm", 4.0], ["moment", 2.4]]
const SEGS := 12
const SEG_LEN := 1.45
const HEAD_R := 1.5
const TALL := 8.0
const WARN := 1.15
## The sinkhole (phase 2+, 1.20): the ground round it funnels toward a pit for SINK_S, its middle biting.
const SINK_R := 7.5
const SINK_S := 4.0
const SINK_PULL := 3.2
## Its slam's opening: lying across the ground this long before it dives (its plates in reach).
const SLAM_LIE := 1.7
## The Twin: up this long, a bite at whoever's nearest within TWIN_REACH every TWIN_EVERY.
const TWIN_S := 5.5
const TWIN_EVERY := 1.7
const TWIN_REACH := 9.0
const TWIN_SEGS := 12
const TWIN_K := 0.6
## The Sandstorm: this long; a captain who moved this far in the last half second is heard.
const STORM_S := 10.0
const STORM_R := 22.0
const HEAR_M := 0.5
const LOOKS := [
	[Color(0.86, 0.66, 0.36), Color(0.62, 0.42, 0.22), Color(0.98, 0.86, 0.6)],
	[Color(0.66, 0.3, 0.16), Color(0.4, 0.18, 0.1), Color(0.9, 0.6, 0.4)],
	[Color(0.9, 0.86, 0.76), Color(0.62, 0.56, 0.48), Color(1.0, 0.96, 0.88)],
]
const SAND := Color(0.92, 0.78, 0.5)
const PLATE_COL := Color(0.72, 0.5, 0.22)

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
var _twin := Vector3.INF
var _sink_t := 0.0
var _sink_at := Vector3.ZERO
var _bites := 0
var _plates: Array = []
var _plate_mat: ShaderMaterial
var _heat: Array = []
## The twin: where it is, how far up (0..1), how long it's left up (host), its body.
var _twin_at := Vector3.ZERO
var _twin_rise := 0.0
var _twin_t := 0.0
var _twin_bite := 0.0
var _twin_model: Node3D
var _twin_segs: Array = []
var _twin_head: Node3D
## The storm (host): how long it has left; who it heard moving.
var _storm_t := 0.0
var _heard_at := {}
var _heard := {}
var _hear_t := 0.0


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


func _pass_moves() -> Array:
	return [["erupt", "bite", "slam", "dive"], ["sinkhole", "spit"], ["twin", "sandstorm"]]


func _part_takes() -> Dictionary:
	return {"mandibles": ["bite"]}


func _chain_waits() -> Array:
	return ["sinkhole", "twin", "sandstorm", "dive"]


func _part_name(n: String) -> String:
	return "Mandibles" if n == "mandibles" else "Plate"


func _moment_color() -> Color:
	return SAND


## Each broken plate: a quarter more from every blow.
func _taken_k(_attacker: Node) -> float:
	return 1.0 + 0.25 * float(int(bp.parts.broken("plate_a")) + int(bp.parts.broken("plate_b")))


## How many of its parts are broken (IslandArcs' hidden finish: "break both its parts").
func parts_broken() -> int:
	return bp.parts.count_broken()


# ==========================================================================
# Body: plated rings on a chain, a head of four jaws round a ring of teeth
# ==========================================================================
func _build() -> void:
	var look: Array = LOOKS[variant % LOOKS.size()]
	var hide := own(PSXMat.lit("leather", look[0]))
	var plate := own(PSXMat.lit("desert_rock", Color(1.0, 0.95, 0.9)))
	_plate_mat = plate
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
	# its two great armour plates, ridged, over the back (parts: broken, a raw red wound under them)
	var bmb := MeshBuilder.new()
	bmb.add_box(plate, Transform3D(Basis(), Vector3(0, 1.18, 0)), Vector3(1.6, 0.34, SEG_LEN * 1.25), 0.6, PLATE_COL)
	for k in range(3):
		bmb.add_box(plate, Transform3D(Basis(Vector3.FORWARD, (k - 1) * 0.35), Vector3((k - 1) * 0.5, 1.4, 0)), Vector3(0.22, 0.3, SEG_LEN * 1.1), 0.6, PLATE_COL.lightened(0.15))
	var plate_mesh := bmb.commit()
	var wmb := MeshBuilder.new()
	wmb.add_box(PSXMat.flat(Color(0.55, 0.08, 0.06)), Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(1.2, 0.08, SEG_LEN * 0.9), 1.0)
	var wound_mesh := wmb.commit()
	for i in [3, 6]:
		var whole := MeshInstance3D.new()
		whole.name = "Plate"
		whole.mesh = plate_mesh
		(_segs[i] as Node3D).add_child(whole)
		var raw := MeshInstance3D.new()
		raw.name = "Wound"
		raw.mesh = wound_mesh
		raw.visible = false
		(_segs[i] as Node3D).add_child(raw)
		_plates.append(_segs[i])
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
	var head_mesh := hmb.commit()
	var hmi := MeshInstance3D.new()
	hmi.name = "Mesh"
	hmi.mesh = head_mesh
	_head.add_child(hmi)
	# four jaws round the mouth, opening like a flower (the mandibles: broken, snapped to stumps)
	var jmb := MeshBuilder.new()
	var outline := PackedVector2Array([Vector2(-0.75, 0.0), Vector2(0.75, 0.0), Vector2(0.45, 1.5), Vector2(0.0, 1.9), Vector2(-0.45, 1.5)])
	jmb.add_extrude(plate, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), outline, 0.22, 0.6, look[1])
	for t in range(3):
		jmb.add_cylinder(tooth, Transform3D(Basis(Vector3.RIGHT, PI), Vector3((t - 1) * 0.35, -0.12, -0.4 - t % 2 * 0.4)), 0.08, 0.0, 0.35, 4, 1.0, Color.WHITE, false, false, false)
	jmb.add_box(maw, Transform3D(Basis(), Vector3(0, -0.1, -0.8)), Vector3(1.0, 0.04, 1.2), 1.0, Color.WHITE, false)
	var jaw_mesh := jmb.commit()
	for k in range(4):
		var a := TAU * k / 4.0 + PI * 0.25
		var jp := Node3D.new()
		jp.name = "Jaw%d" % k
		jp.position = Vector3(cos(a) * HEAD_R * 0.85, sin(a) * HEAD_R * 0.85, -0.3)
		jp.rotation = Vector3(0, 0, a - PI * 0.5)
		_head.add_child(jp)
		var jmi := MeshInstance3D.new()
		jmi.name = "Mesh"
		jmi.mesh = jaw_mesh
		jp.add_child(jmi)
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
	# the twin: a smaller worm of the same rings, its own place (top level), seen only while it's up
	_twin_model = Node3D.new()
	_twin_model.name = "Twin"
	_twin_model.top_level = true
	_twin_model.visible = false
	add_child(_twin_model)
	for i in range(TWIN_SEGS):
		var s := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		s.add_child(mi)
		s.scale = Vector3.ONE * lerpf(HEAD_R, 0.55, float(i) / (TWIN_SEGS - 1)) * TWIN_K
		_twin_model.add_child(s)
		_twin_segs.append(s)
	_twin_head = Node3D.new()
	var tmi := MeshInstance3D.new()
	tmi.mesh = head_mesh
	_twin_head.add_child(tmi)
	_twin_head.scale = Vector3.ONE * TWIN_K
	_twin_model.add_child(_twin_head)
	bp.parts.add("plate_a", _hp_base() * 0.07, [_plates[0]], 2.6, "sand_plate", PLATE_COL)
	bp.parts.add("plate_b", _hp_base() * 0.07, [_plates[1]], 2.6, "sand_plate", PLATE_COL)
	bp.parts.add("mandibles", _hp_base() * 0.08, [_head], HEAD_R + 1.6, "mandible", look[1])
	bp.parts.opens["plate_a"] = _lying
	bp.parts.opens["plate_b"] = _lying
	bp.parts.opens["mandibles"] = _head_down


## Its slam's opening: its length lying across the ground (run up its back).
func _lying() -> bool:
	return move == "slam" and mv_t > 1.3


## Its head down on the sand: a bite's end and the opening after, a stagger.
func _head_down() -> bool:
	return (move == "bite" and mv_t > 0.62) or (move == "" and mv_t < 0.0 and _last_move == "bite") or state == S.STAGGER or _lying()


func _ready() -> void:
	_cd = {"bite": 1.0, "slam": 3.0, "spit": 2.0, "dive": 6.0, "sinkhole": 99.0, "twin": 99.0, "sandstorm": 99.0}
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
		_twin_t = 0.0
		_storm_t = 0.0
		if rise <= 0.0:
			global_position = post
			_set_state(S.SLEEP)
	if move == "moment":
		rise = move_toward(rise, 1.0, delta * 2.5)
		_lean = -0.35 if mv_t < BeastPass.MOMENT_REAR else -0.15 + sin(mv_t * 9.0) * 0.08
	_twin_tick(delta)
	if _storm_t > 0.0:
		_storm_t -= delta
		_hear(delta)
		# (nobody heard: under the sand it roams, coming up where it last felt a step)
		if state == S.FIGHT and move == "" and mv_t > 1.2 and _target() == null:
			if rise > 0.5:
				begin("dive")
			else:
				begin("erupt")


func _idle(_delta: float) -> Vector3:
	_yaw = post_yaw
	rise = 0.0
	return Vector3.ZERO


func _wake_move() -> String:
	return "erupt"


## In the storm it hunts by sound: only a captain who's moving.
func _target() -> Node3D:
	if _storm_t <= 0.0:
		return super._target()
	var best: Node3D = null
	for p in Net.all_players():
		if bool(_heard.get(p.get_instance_id(), false)) and _player_ok(p) and (best == null or (p as Node3D).global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = p
	return best


func _hear(delta: float) -> void:
	_hear_t -= delta
	if _hear_t > 0.0:
		return
	_hear_t = 0.5
	for p in Net.all_players():
		var id: int = p.get_instance_id()
		var at := (p as Node3D).global_position
		_heard[id] = _heard_at.has(id) and _flat(at - (_heard_at[id] as Vector3)).length() > HEAR_M
		_heard_at[id] = at


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	if rise < 0.5:
		# under: a beat, then up under whoever it hunts (phase 3: with its twin)
		if mv_t > 0.6:
			# (1.20: once per dive, never chained: it comes up and fights, docs/v1_20_beasts.md 10)
			_runs = 1
			begin("twin" if bp.allows("twin") and float(_cd.get("twin", 99.0)) <= 0.0 and _last_move != "twin" else "erupt")
		return Vector3.ZERO
	_face(to)
	var wants: Array = []
	if dist > 6.0:
		wants.append("sandstorm")
	wants.append("sinkhole")
	if dist > 5.0:
		wants.append("spit")
	if dist < 9.0:
		wants.append("bite")
	if dist < 16.0:
		wants.append("slam")
	if dist > 22.0 or float(_cd.get("dive", 0.0)) <= 0.0:
		wants.append("dive")
	var m := pick(wants)
	if m != "":
		begin(m)
	return Vector3.ZERO


func _on_begin(m: String) -> void:
	_fly = true
	var p := _target()
	match m:
		"erupt", "twin":
			if p:
				_goal = ground_at(p.global_position)
			else:
				var a := _rng.randf() * TAU
				_goal = ground_at(post + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 10.0))
			warn_ring(_goal, 4.2, WARN)
			_twin = Vector3.INF
			if m == "twin":
				_cd["twin"] = _rng.randf_range(16.0, 20.0)
				var a := _rng.randf() * TAU
				_twin = ground_at(_goal + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(5.0, 7.0))
				warn_ring(_twin, 2.8, WARN)
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
		"sinkhole":
			_cd["sinkhole"] = _rng.randf_range(14.0, 18.0)
			_goal = global_position
			warn_ring(_goal, SINK_R, 0.9, Color(1.0, 0.55, 0.12))
			say("slither", global_position, 6.0, 0.4, 140.0)
		"sandstorm":
			_cd["sandstorm"] = _rng.randf_range(26.0, 32.0)
			say("bellow", _hit_point(), 8.0, 0.45, 160.0)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"erupt", "twin":
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
					strike("ring", [_goal, 4.2], 26.0, false, false, 1.2, 12.0)
					_geyser(_goal, 1.0)
					if _twin != Vector3.INF:
						strike("ring", [_twin, 2.8], 18.0, false, false, 1.2, 9.0)
						_geyser(_twin, 0.7)
						_twin_at = _twin
						_twin_t = TWIN_S
						_twin_bite = TWIN_EVERY
					quake(_goal, 1.4)
					say("bellow", _goal, 6.0, 0.6, 140.0)
				rise = move_toward(rise, 1.0, delta * 2.2)
				if rise >= 1.0:
					_runs -= 1
					end_move(0.4)
					if _runs > 0:
						begin("dive")
		"bite":
			# (the head snaps down and lies on the sand after: the mandibles in reach)
			_lean = sin(clampf((mv_t - 0.5) / 0.4, 0.0, 1.0) * PI * 0.5) * 1.1 if mv_t > 0.5 else -0.3 * minf(mv_t / 0.5, 1.0)
			if p and mv_t < 0.4:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.62 and not _hit:
				_hit = true
				strike("cone", [global_position, _fwd(), 9.5, 38.0], 22.0, false, true, 1.6, 10.0)
				Net.fx("puff", [global_position + _fwd() * 7.0, "sand", 5, 2.0, 0.9, Color.WHITE, 1.5, Vector3.UP])
			if mv_t > 1.6:
				_lean = 0.0
				end_move(1.0)
		"slam":
			_lean = -0.3 * minf(mv_t / 1.0, 1.0) if mv_t < 1.0 else minf((mv_t - 1.0) / 0.35, 1.0) * 1.6
			if mv_t > 1.3 and not _hit:
				_hit = true
				strike("lane", [global_position, _goal, HEAD_R + 0.6], 30.0, true, false, 1.3, 14.0)
				for k in range(4):
					quake(global_position.lerp(_goal, 0.3 + k * 0.2), 0.8)
			if mv_t > 1.3 + SLAM_LIE:
				_lean = 0.0
				begin("dive")
		"spit":
			_lean = -0.2 if mv_t < 0.6 else 0.3
			if mv_t > 0.9 and not _hit:
				_hit = true
				for q in _spit:
					strike("ring", [q, 2.6], 16.0, false, false, 1.1)
					Net.fx("puff", [q + Vector3.UP * 0.4, "sand", 6, 2.2, 1.0, Color(0.85, 1.0, 0.55), 1.8, Vector3.UP])
					Net.fx("poison", [q + Vector3.UP * 0.2, 5, 0.5])
			if mv_t > 1.4:
				_lean = 0.0
				end_move(0.5)
		"sinkhole":
			return _sink_tick(delta)
		"sandstorm":
			# reared back, a roar that bends the sand out from it, then the storm, and under it goes
			_lean = -0.5 if mv_t < 1.0 else -0.2
			if mv_t > 1.0 and not _hit:
				_hit = true
				_storm_t = STORM_S
				_heard.clear()
				_heard_at.clear()
				_storm(global_position, STORM_S)
				Net.event(self, "storm", [global_position, STORM_S])
				Net.fx("puff_ring", [global_position, "sand", 12, 2.0, 3.2, 1.4, Color.WHITE, 10.0])
				Net.fx("ring", [global_position + Vector3.UP * 0.3, Vector3.UP, 12.0, SAND, 0.6, 0.3])
			if mv_t > 1.8:
				_lean = 0.0
				begin("dive")
		"dive":
			rise = move_toward(rise, 0.0, delta * 1.6)
			if not _hit and rise < 0.6:
				_hit = true
				Net.fx("puff", [global_position + Vector3.UP * 0.5, "sand", 8, 3.0, 1.2, Color.WHITE, 2.0, Vector3.UP])
				Net.fx("sfx", ["rock_crash", global_position, 2.0, 0.1, 0.6])
			if rise <= 0.0:
				end_move(0.0)
	return Vector3.ZERO


## A geyser of sand where it bursts up: a column of it thrown high, falling back.
func _geyser(at: Vector3, size: float) -> void:
	Net.fx("plume", [at + Vector3.UP * 0.3, Vector3.UP, "sand", int(6 * size), 3.2 * size, 1.6, Color.WHITE, 11.0 * size, 10.0])
	Net.fx("puff", [at + Vector3.UP * 0.5, "sand", int(10 * size), 3.5 * size, 1.4, Color.WHITE, 3.0, Vector3.UP])


## The twin (host): up for TWIN_S, biting whoever's nearest within TWIN_REACH every TWIN_EVERY, then back under.
func _twin_tick(delta: float) -> void:
	if _twin_t > 0.0:
		_twin_t -= delta
		_twin_rise = move_toward(_twin_rise, 1.0, delta * 2.2)
		_twin_bite -= delta
		if _twin_bite <= 0.0 and _twin_rise >= 1.0:
			_twin_bite = TWIN_EVERY
			var who := Net.nearest_player(_twin_at, _player_ok) as Node3D
			if who and _flat(who.global_position - _twin_at).length() < TWIN_REACH:
				var d := _flat(who.global_position - _twin_at).normalized()
				warn_lane(_twin_at, _twin_at + d * TWIN_REACH * 0.9, 2.2, 0.45)
				get_tree().create_timer(0.45).timeout.connect(func():
					if is_instance_valid(self) and state != S.DEAD:
						strike("cone", [_twin_at, d, TWIN_REACH, 30.0], 16.0, false, false, 1.4, 8.0)
						say("hiss", _twin_at + Vector3.UP * 4.0, 2.0, 0.75))
	else:
		_twin_rise = move_toward(_twin_rise, 0.0, delta * 1.5)


## The hump of sand it pushes along under the surface: puffs behind it, on every screen.
func _trail(delta: float) -> void:
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.12
		Net.fx("puff", [global_position + Vector3.UP * 0.3, "sand", 2, 1.6, 0.8, Color.WHITE, 0.8, Vector3.UP])


func _armoured() -> bool:
	return rise < 0.9 or move == "slam" and mv_t < 1.3


func _parry_ok() -> bool:
	return move == "bite" and mv_t > 0.45 and mv_t < 0.75


func _on_stagger() -> void:
	say("hiss", _hit_point(), 3.0, 0.7)
	_lean = 0.0


func _on_phase(n: int) -> void:
	_cd["spit"] = 0.0
	if n >= 2:
		_cd["sinkhole"] = 2.0
	if n >= 3:
		_cd["twin"] = 0.0
		_cd["sandstorm"] = 4.0


## The roar's ring: the sand bends out from it in a wave.
func _on_moment() -> void:
	Net.fx("puff_ring", [global_position, "sand", 14, 2.0, 3.4, 1.5, Color.WHITE, 11.0])


## Heat rising off it from phase 2; its plates glowing like coals in phase 3; broken plates and mandibles.
func _on_look() -> void:
	for i in range(_plates.size()):
		var gone := bp.parts.broken("plate_a" if i == 0 else "plate_b")
		(_plates[i] as Node3D).get_node("Plate").visible = not gone
		(_plates[i] as Node3D).get_node("Wound").visible = gone
	for k in range(_jaws.size()):
		(_jaws[k] as Node3D).scale = Vector3.ONE * (0.35 if bp.parts.broken("mandibles") and k % 2 == 0 else 1.0)
	_plate_mat.set_shader_parameter("emission_color", Color(1.0, 0.38, 0.08) if phase >= 3 else Color(0, 0, 0))
	_plate_mat.set_shader_parameter("emission_energy", 1.1)
	_plate_mat.set_shader_parameter("emission_pulse", 0.6 if phase >= 3 else 0.0)
	for h in _heat:
		if is_instance_valid(h):
			(h as Node).queue_free()
	_heat.clear()
	if phase >= 2 and state != S.DEAD:
		for i in [2, 5, 8]:
			_heat.append(FX.flip_emitter(_segs[i], "wisp", 3, 0.9, 1.6, {"direction": Vector3.UP, "vel_min": 0.4, "vel_max": 0.8, "radius": 0.4,
				"color": Color(1.0, 0.9, 0.75, 0.22), "fade": 0.6, "range": 90.0}))


func _on_die() -> void:
	say("bellow", _hit_point(), 6.0, 0.4, 140.0)
	_twin_t = 0.0
	_storm_t = 0.0


## (it sets its own place: never physics-moved, never falling)
func end_move(recover: float = 0.0) -> void:
	super.end_move(recover)
	_fly = true


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": (LOOKS[variant % LOOKS.size()][0] as Color)}, "Sand King's Mantle", t)


func _pack_extra() -> Array:
	return [rise, _lean, _twin_rise, _twin_at]


func _unpack_extra(a: Array, b: Array, f: float) -> void:
	if a.size() < 4 or b.size() < 4:
		return
	rise = lerpf(float(a[0]), float(b[0]), f)
	_lean = lerpf(float(a[1]), float(b[1]), f)
	_twin_rise = lerpf(float(a[2]), float(b[2]), f)
	_twin_at = b[3]


# ==========================================================================
# Pose: the body out of its hole along an arc, the head at its tip, the jaws
# ==========================================================================
func _animate(delta: float) -> void:
	_animate_twin()
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
	var m := bp.motion
	# (it heaves as it breathes, reels when staggered, a blow knocks it back)
	var sway := sin(_t_anim * 1.1) * 0.12 + sin(_t_anim * 2.3) * 0.25 * m.reel
	_t_anim += delta
	var lean := _lean + m.react.x * 0.25 + m.reel * 0.35 + m.breath * 0.03
	# the arc: from deep in its hole up and over toward where it faces; the head runs up it as it rises
	var p0 := Vector3(0, -6.0, 0.5)
	var top := TALL * (1.0 - absf(lean) * 0.25)
	var p1 := Vector3(sway * 3.0 + m.react.y * 1.5, top * 1.15, 0.8)
	var p2 := Vector3(sway * 5.0 + m.react.y * 2.5, top * (0.85 - maxf(lean, 0.0) * 0.55), -4.0 - maxf(lean, 0.0) * 6.0 + minf(lean, 0.0) * -3.0)
	var length := SEGS * SEG_LEN
	var head_t := clampf(up, 0.0, 1.0)
	var pts: Array = []
	for i in range(SEGS + 1):
		var t := head_t - float(i) * SEG_LEN / length
		pts.append(_bez(p0, p1, p2, t) if t >= 0.0 else p0 + Vector3(0, t * length, 0))
	_head.position = pts[0]
	var hd: Vector3 = (pts[0] - pts[1]).normalized()
	_head.basis = Basis.looking_at(hd, Vector3.UP if absf(hd.y) < 0.95 else Vector3.BACK)
	# (its head turns to whoever it's after, as far as the neck lets it)
	var tgt := Net.nearest_player(global_position) as Node3D
	if tgt and in_combat():
		m.track(delta, _head.global_basis, _head.global_position, tgt.global_position + Vector3.UP, 1.0 - m.reel, 3.0, 0.6, 0.5)
		_head.basis = _head.basis * Basis.from_euler(Vector3(m.look.y, m.look.x, 0.0))
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
		"erupt", "twin":
			open = 0.8
		"spit":
			open = 1.0 if mv_t > 0.8 else 0.5
		"sandstorm", "moment":
			open = 1.0 if mv_t > 0.5 else 0.4
	if state == S.STAGGER:
		open = 0.6 + sin(_t_anim * 3.0) * 0.2
	for j in _jaws:
		(j as Node3D).rotation.x = -open * 0.9
	for k in range(4):
		(hurtbox.get_child(k) as CollisionShape3D).position = model.basis * (pts[mini(k * 2, SEGS)] as Vector3)


var _t_anim: float = 0.0


## The twin's body out of its own hole, its head toward whoever's nearest (every screen from _twin_at/_twin_rise).
func _animate_twin() -> void:
	_twin_model.visible = _twin_rise > 0.02 and state != S.DEAD
	if not _twin_model.visible:
		return
	var who := Net.nearest_player(_twin_at) as Node3D
	var d := _flat(who.global_position - _twin_at).normalized() if who else _fwd()
	_twin_model.global_transform = Transform3D(Basis.looking_at(d if d.length() > 0.1 else Vector3.FORWARD, Vector3.UP), _twin_at)
	var sway := sin(_t_anim * 1.6 + 1.0) * 0.2
	var p0 := Vector3(0, -4.0, 0.3)
	var p1 := Vector3(sway * 2.0, TALL * TWIN_K * 1.15, 0.5)
	var p2 := Vector3(sway * 3.0, TALL * TWIN_K * 0.85, -2.5)
	var length := TWIN_SEGS * SEG_LEN * TWIN_K
	var pts: Array = []
	for i in range(TWIN_SEGS + 1):
		var t := _twin_rise - float(i) * SEG_LEN * TWIN_K / length
		pts.append(_bez(p0, p1, p2, t) if t >= 0.0 else p0 + Vector3(0, t * length, 0))
	_twin_head.position = pts[0]
	var hd: Vector3 = (pts[0] - pts[1]).normalized()
	_twin_head.basis = Basis.looking_at(hd, Vector3.UP if absf(hd.y) < 0.95 else Vector3.BACK).scaled(Vector3.ONE * TWIN_K)
	for i in range(TWIN_SEGS):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var s: Node3D = _twin_segs[i]
		s.position = (a + b) * 0.5
		var sd := (a - b).normalized()
		s.basis = Basis.looking_at(sd, Vector3.UP if absf(sd.y) < 0.95 else Vector3.BACK).scaled(s.scale)
		s.visible = maxf(a.y, b.y) > -0.3


static func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u + b * 2.0 * u * t + c * t * t


## The sinkhole: under, a spin, then the sand round it pulls toward the pit for SINK_S (run out of it); the pit's middle
## bites three times; then its head comes up out of the pit, open.
func _sink_tick(delta: float) -> Vector3:
	if mv_t < 0.9:
		rise = move_toward(rise, 0.0, delta * 2.0)
		return Vector3.ZERO
	if _sink_t <= 0.0 and _bites == 0 and mv_t < 1.0:
		_sink(_goal, SINK_S)
		Net.event(self, "sink", [_goal, SINK_S])
	if _bites < 3 and mv_t > 1.6 + _bites * 1.1:
		_bites += 1
		strike("ring", [_goal, 2.6], 20.0, false, false, 1.0, 6.0)
		Net.fx("puff", [_goal + Vector3.UP * 0.4, "sand", 8, 2.2, 1.0, Color.WHITE, 2.0, Vector3.UP])
	if mv_t > 1.0 + SINK_S:
		rise = move_toward(rise, 1.0, delta * 2.0)
		if rise >= 1.0:
			_bites = 0
			end_move(1.2)
	return Vector3.ZERO


## (every screen) the sand runs toward the pit: its own captain dragged in while they stand in it.
func _sink(at: Vector3, secs: float) -> void:
	_sink_at = at
	_sink_t = secs


## (every screen) the sandstorm: sand blowing across the arena, and word for this screen's captain that it hunts by sound.
func _storm(at: Vector3, secs: float) -> void:
	BeastFX.sandstorm(at, STORM_R, secs)
	var me := get_tree().get_first_node_in_group("player")
	if me and (me as Node3D).global_position.distance_to(at) < STORM_R + 20.0 and me.has_method("_toast"):
		me.call("_toast", "Sandstorm! It hunts by sound: stand still")


func _process(delta: float) -> void:
	super._process(delta)
	if _sink_t <= 0.0:
		return
	_sink_t -= delta
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	var to := _flat(_sink_at - me.global_position)
	if to.length() < SINK_R and to.length() > 0.5:
		me.global_position += to.normalized() * SINK_PULL * delta
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.25
		var a := randf() * TAU
		FX.dust(_sink_at + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, SINK_R), 3, 0.6)


func _event(what: String, args: Array) -> void:
	match what:
		"sink":
			_sink(args[0], float(args[1]))
		"storm":
			_storm(args[0], float(args[1]))
