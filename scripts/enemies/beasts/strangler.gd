extends JungleBeast
## The Strangler: a constrictor some 25 m long that lives in the brush and the
## trees round its hollow (BeastArena, BeastPool "serpent"). One skinned body on
## a chain of bones that follows the head over the floor like a rope, the head
## and a hinged jaw on top. Hits land on the head or along the body.
##
## Moves (each with its tell):
##   strike  rears up hissing, a red strip where it'll go, then the head shoots
##           along it (parry it: it's left reeling); enraged it strikes twice
##   sweep   the tail swings round behind it (a ring where the tail is: jump it)
##   coil    it runs a ring round you, the ring on the ground filling as it
##           closes; get out before it crushes everything inside
##   ambush  (phase 2+) into the brush round the floor and gone: the undergrowth
##           thrashes where it goes, then it bursts out at you from the brush
##   tree    (phase 2+) up a giant's trunk in a spiral, then it drops on you
##           (a ring), and lies stunned a moment where it lands
##   spit    (phase 2+) rears and sprays venom (globs that poison)
## Phases at 66% and 33% (a long hiss, then it slips into the brush).

const FILM := [["rise", 1.6], ["strike", 2.2], ["sweep", 1.6], ["coil", 3.4], ["spit", 1.6], ["ambush", 6.0], ["tree", 6.5]]
const SEGS := 18
const SPACING := 1.45
const BODY_LEN := SEGS * SPACING
const NECK := 3
const SKINS := [
	[Color(0.2, 0.38, 0.16), Color(0.86, 0.78, 0.42), Color(0.09, 0.19, 0.07)],
	[Color(0.5, 0.37, 0.18), Color(0.9, 0.82, 0.6), Color(0.24, 0.15, 0.07)],
	[Color(0.11, 0.11, 0.12), Color(0.78, 0.75, 0.68), Color(0.86, 0.84, 0.78)],
]
const STRIKE_WIND := 0.75
const STRIKE_LEN := 9.0
const COIL_T := 2.3
const COIL_R := 5.2
const TREE_UP := 2.4
const TREE_WARN := 1.2

var _skel: Skeleton3D
var _body_mi: MeshInstance3D
var _head: Node3D
var _jaw: Node3D
var _segs: Array = []
var _gy: Array = []
var _gy_i: int = 0
var _hurt: Array = []
var _lift: float = 0.9
var _pitch: float = 0.0
var _jaw_open: float = 0.0
var _sway: float = 0.0
var _t: float = 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _aim := Vector3.ZERO
var _n: int = 0
var _tree: int = 0
var _fx_t: float = 0.0
var _hops: int = 0
var _skin: Array


func _init() -> void:
	boss_name = "The Strangler"


func _hp_base() -> float:
	return 1400.0


func _poise_max() -> float:
	return 240.0


func _phase_at() -> Array:
	return [0.66, 0.33]


func _speed() -> float:
	return 5.5 if phase < 3 else 6.6


func _hit_point() -> Vector3:
	return _head.global_position if _head else global_position + Vector3(0, 1.2, 0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": _skin[0]}, "Strangler's Skin", t)


func _wake_move() -> String:
	return "rise"


# ==========================================================================
# The body
# ==========================================================================
func _build() -> void:
	_skin = SKINS[variant % SKINS.size()]
	_cd = {"strike": 1.0, "sweep": 3.0, "coil": 6.0, "ambush": 99.0, "tree": 99.0, "spit": 99.0, "train": 4.0}
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.0
	col.shape = cap
	col.position = Vector3(0, 1.0, 0)
	add_child(col)
	var mat := own(PSXMat.lit("scales", Color(1.1, 1.1, 1.1)))
	_skel = Skeleton3D.new()
	_skel.name = "Body"
	_skel.top_level = true
	add_child(_skel)
	for i in range(SEGS):
		_skel.add_bone("seg%d" % i)
		_skel.set_bone_rest(i, Transform3D(Basis(), Vector3(0, 0, i * SPACING)))
		_segs.append(global_position)
		_gy.append(0.0)
	_skel.reset_bone_poses()
	var mb := MeshBuilder.new()
	mb.skinned = true
	mb.weight_fn = _weights
	var prof := PackedVector2Array()
	for k in range(10):
		var a := TAU * k / 10.0
		prof.append(Vector2(cos(a), sin(a) * (0.78 if sin(a) > 0.0 else 1.0)))
	var rings := []
	var z := -0.6
	while z < BODY_LEN - 0.4:
		rings.append([z, _r_at(z), _r_at(z) * 0.9, 0.0])
		z += 0.7
	rings.append([BODY_LEN - 0.1, 0.06, 0.05, 0.0])
	mb.add_loft(mat, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), rings, prof, 0.8, Color.WHITE, true, true)
	_paint(mb, mat, func(p: Vector3): return _r_at(p.z))
	var skin := Skin.new()
	for b in range(SEGS):
		skin.add_bind(b, _skel.get_bone_global_rest(b).affine_inverse())
	_body_mi = MeshInstance3D.new()
	_body_mi.name = "Mesh"
	_body_mi.mesh = mb.commit()
	_body_mi.skin = skin
	_skel.add_child(_body_mi)
	_body_mi.skeleton = NodePath("..")
	_build_head(mat)
	_hurt.append(hurt_ball(1.15, Vector3(0, 1.0, 0)))
	for i in [2, 5, 8, 11, 14]:
		_hurt.append(hurt_ball(_r_at(i * SPACING) + 0.3, Vector3.ZERO))


func _r_at(z: float) -> float:
	var k := z / BODY_LEN
	if k < 0.08:
		return lerpf(0.42, 0.62, smoothstep(-0.03, 0.08, k))
	if k < 0.4:
		return lerpf(0.62, 0.78, smoothstep(0.08, 0.4, k))
	return lerpf(0.78, 0.06, pow((k - 0.4) / 0.6, 1.3))


## Each vertex blends between the two bones it lies between (a pure function of position).
func _weights(p: Vector3) -> Array:
	var f := p.z / SPACING - 0.5
	var i0 := clampi(floori(f), 0, SEGS - 1)
	var i1 := mini(i0 + 1, SEGS - 1)
	var t := clampf(f - i0, 0.0, 1.0) if f > 0.0 else 0.0
	return [PackedInt32Array([i0, i1, 0, 0]), PackedFloat32Array([1.0 - t, t, 0.0, 0.0])]


## The hide: the back's colour broken by dark saddles down the spine, the belly pale.
func _paint(mb: MeshBuilder, mat: Material, radius: Callable) -> void:
	var v: PackedVector3Array = mb._surfaces[mat]["v"]
	var c: PackedColorArray = mb._surfaces[mat]["c"]
	for i in range(v.size()):
		var p := v[i]
		var up := p.y / maxf(float(radius.call(p)), 0.1)
		var side := absf(p.x) / maxf(float(radius.call(p)), 0.1)
		var saddle := smoothstep(0.55, 0.85, sin(p.z * 1.7 + sin(p.z * 0.4) * 1.5) * 0.5 + 0.5) * smoothstep(0.1, 0.6, up + 0.3 - side * 0.3)
		var col: Color = (_skin[0] as Color).lerp(_skin[2], saddle * 0.85)
		c[i] = col.lerp(_skin[1], smoothstep(-0.25, -0.6, up)) * c[i].r
	mb._surfaces[mat]["c"] = c


## The head (it looks along -z): a broad wedge of a skull with heavy brow scales over
## glowing slit eyes, heat pits along the lip, fangs, the lower jaw hinged behind.
func _build_head(mat: Material) -> void:
	_head = Node3D.new()
	_head.name = "Head"
	model.add_child(_head)
	var mouth := PSXMat.lit("leather", Color(0.75, 0.3, 0.32))
	var bone := PSXMat.flat(Color(0.95, 0.92, 0.82))
	var eye := PSXMat.glow(Color(1.0, 0.78, 0.15), 2.5)
	var hb := MeshBuilder.new()
	var fwd := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.3))
	var top := MeshBuilder.profile_mirror(PackedVector2Array([Vector2(0, 1.0), Vector2(0.5, 0.92), Vector2(0.9, 0.55), Vector2(1.0, 0.0),
		Vector2(0.85, -0.45), Vector2(0, -0.55)]))
	var skull := [[-0.2, 0.5, 0.36, 0.0], [0.3, 0.62, 0.4, 0.04], [0.9, 0.58, 0.34, 0.02], [1.5, 0.44, 0.27, -0.03], [1.85, 0.26, 0.18, -0.06]]
	hb.add_loft(mat, fwd, skull, top, 0.9, Color.WHITE, true, true, true, false, false, PackedInt32Array(), mouth, Callable(),
		func(p: Vector3): return mouth if p.y < -0.12 and p.z < -0.2 else false)
	for s in [-1.0, 1.0]:
		hb.add_box(mat, Transform3D(Basis(Vector3.UP, s * 0.2) * Basis(Vector3.FORWARD, s * 0.3), Vector3(s * 0.42, 0.33, -0.65)), Vector3(0.24, 0.12, 0.55), 1.0, Color(0.7, 0.7, 0.7), false)
		hb.add_box(eye, Transform3D(Basis(Vector3.UP, s * 0.25), Vector3(s * 0.5, 0.2, -0.68)), Vector3(0.07, 0.13, 0.26), 1.0)
		hb.add_box(bone, Transform3D(Basis(Vector3.UP, s * 0.25), Vector3(s * 0.52, 0.2, -0.68)), Vector3(0.04, 0.16, 0.05), 1.0, Color(0.05, 0.03, 0.02))
		for k in range(3):
			hb.add_box(bone, Transform3D(Basis(), Vector3(s * (0.38 - k * 0.06), -0.02, -1.0 - k * 0.22)), Vector3(0.05, 0.05, 0.08), 1.0, Color(0.1, 0.06, 0.05))
		hb.add_cylinder(bone, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * 0.22, -0.1, -1.35)), 0.06, 0.0, 0.42, 4, 1.0, Color.WHITE, false, false, false)
	_paint_head(hb, mat)
	_head.add_child(hb.to_instance("Skull"))
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, -0.12, 0.2)
	_head.add_child(_jaw)
	var jb := MeshBuilder.new()
	var low := MeshBuilder.profile_mirror(PackedVector2Array([Vector2(0, 0.2), Vector2(0.8, 0.15), Vector2(1.0, -0.2), Vector2(0.6, -0.8), Vector2(0, -1.0)]))
	var jaw := [[-0.3, 0.46, 0.16, -0.06], [0.6, 0.5, 0.15, -0.06], [1.3, 0.38, 0.12, -0.06], [1.75, 0.22, 0.08, -0.06]]
	jb.add_loft(mat, fwd, jaw, low, 0.9, Color.WHITE, true, true, true, false, false, PackedInt32Array(), mouth, Callable(),
		func(p: Vector3): return mouth if p.y > -0.08 else false)
	for s in [-1.0, 1.0]:
		jb.add_cylinder(bone, Transform3D(Basis(), Vector3(s * 0.18, -0.02, -1.15)), 0.05, 0.0, 0.3, 4, 1.0, Color.WHITE, false, false, false)
	_paint_head(jb, mat)
	_jaw.add_child(jb.to_instance("JawMesh"))


func _paint_head(mb: MeshBuilder, mat: Material) -> void:
	var v: PackedVector3Array = mb._surfaces[mat]["v"]
	var c: PackedColorArray = mb._surfaces[mat]["c"]
	for i in range(v.size()):
		c[i] = (_skin[0] as Color).lerp(_skin[1], smoothstep(0.0, -0.2, v[i].y)) * c[i].r
	mb._surfaces[mat]["c"] = c


# ==========================================================================
# The body following the head
# ==========================================================================
func _ready() -> void:
	super._ready()
	for i in range(SEGS):
		_segs[i] = global_position - _fwd() * (1.0 + i * SPACING)
		_gy[i] = global_position.y


func _animate(delta: float) -> void:
	_t += delta
	var lift := _lift
	var pitch := _pitch
	var jaw := _jaw_open
	if net_puppet:
		_pose_from_move()
		lift = _lift
		pitch = _pitch
		jaw = _jaw_open
	_head.position.y = lerpf(_head.position.y, lift, minf(delta * 8.0, 1.0))
	_head.rotation.x = lerp_angle(_head.rotation.x, pitch + sin(_t * 1.7) * 0.05, minf(delta * 8.0, 1.0))
	_jaw.rotation.x = lerpf(_jaw.rotation.x, -jaw * 0.85, minf(delta * 14.0, 1.0))
	if not net_puppet:
		_drag(delta)
	_pose_segs()
	_follow_hurt()


## The body behind the head like a rope over the ground (in the air where it's hung off a branch).
func _drag(delta: float) -> void:
	var prev := _head.global_position + _head.global_basis.z * 0.6
	var space := get_world_3d().direct_space_state
	for k in range(3):
		_gy_i = (_gy_i + 1) % SEGS
		var s: Vector3 = _segs[_gy_i]
		var q := PhysicsRayQueryParameters3D.create(s + Vector3.UP * 4.0, s + Vector3.DOWN * 12.0, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_gy[_gy_i] = (hit["position"] as Vector3).y
	var side := _fwd().cross(Vector3.UP)
	for i in range(SEGS):
		var p: Vector3 = _segs[i]
		var d := p - prev
		if d.length() < 0.01:
			d = -_fwd()
		p = prev + d.normalized() * SPACING
		if _sway != 0.0 and i > SEGS / 2:
			p += side * _sway * sin(float(i - SEGS / 2) / (SEGS / 2) * PI * 0.5) * delta * 9.0
		var floor_y: float = float(_gy[i]) + _r_at((i + 0.5) * SPACING) * 0.85
		if i < NECK:
			p.y = lerpf(prev.y, floor_y, 0.55)
		else:
			p.y = maxf(p.y - 4.0 * delta, floor_y) if p.y > floor_y + 0.05 else lerpf(p.y, floor_y, minf(delta * 10.0, 1.0))
		_segs[i] = p
		prev = p


func _pose_segs() -> void:
	var prev := _head.global_position + _head.global_basis.z * 0.6
	var box := AABB(prev, Vector3.ZERO)
	for i in range(SEGS):
		var p: Vector3 = _segs[i]
		var dir := p - prev
		if dir.length() > 0.01:
			var b := Basis.looking_at(-dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.97 else Vector3.FORWARD)
			_skel.set_bone_global_pose(i, Transform3D(b * Basis.from_scale(Vector3(1, 1, maxf(dir.length() / SPACING, 1.0))), prev))
		box = box.expand(p)
		prev = p
	_body_mi.custom_aabb = box.grow(2.0)


func _follow_hurt() -> void:
	(_hurt[0] as CollisionShape3D).position = to_local(_head.global_position)
	var idx := [2, 5, 8, 11, 14]
	for k in range(idx.size()):
		(_hurt[k + 1] as CollisionShape3D).position = to_local(_segs[idx[k]])


## (puppets) the head's lift, pitch and jaw for the move under way, as the host sets them.
func _pose_from_move() -> void:
	_lift = 0.9
	_pitch = 0.0
	_jaw_open = 0.1
	if state == S.STAGGER or state == S.DEAD:
		_lift = 0.35
		_jaw_open = 0.6
		return
	match move:
		"rise", "spit":
			_lift = 3.0
			_pitch = 0.25
			_jaw_open = 0.9
		"strike":
			_lift = 2.6 if mv_t < STRIKE_WIND else 1.0
			_pitch = 0.3 if mv_t < STRIKE_WIND else -0.15
			_jaw_open = 1.0
		"train":
			_lift = 0.8
			_pitch = -0.1
			_jaw_open = 1.0
		"ambush":
			_lift = 0.3
		"coil", "sweep":
			_lift = 1.2


# ==========================================================================
# The brain
# ==========================================================================
func _brain(_delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	_lift = 0.9
	_pitch = 0.0
	_jaw_open = 0.1
	_sway = 0.0
	# (1.20, docs/v1_20_beasts.md 2: the rules - pick(), never a move twice running - and the train)
	var wants: Array = []
	var arena_ok := arena != null and not (arena.brush as Array).is_empty()
	if phase >= 2 and arena_ok:
		wants.append("ambush")
	if phase >= 2 and arena != null and not (arena.trees as Array).is_empty() and dist > 5.0:
		wants.append("tree")
	if dist > 6.0:
		wants.append("train")
	if dist < 8.5:
		wants.append("strike")
	if dist < 7.0:
		wants.append_array(["coil", "sweep"])
	if phase >= 2 and dist > 8.0:
		wants.append("spit")
	var m := pick(wants)
	if m != "":
		begin(m)
	elif dist > 5.5:
		var nd := _nav_dir(p.global_position, _delta)
		_face(nd)
		return nd * _speed()
	else:
		# too close: slide round to the side, the body winding
		return to.normalized().cross(Vector3.UP) * 2.5
	return Vector3.ZERO


func _on_phase(_n_: int) -> void:
	say("hiss", global_position, 6.0, 0.8)
	_cd["ambush"] = 0.0
	_cd["tree"] = 9.0
	_cd["spit"] = 4.0


func _parry_ok() -> bool:
	return move == "strike" and mv_t >= STRIKE_WIND - 0.1 and mv_t < STRIKE_WIND + 0.35


func _armoured() -> bool:
	return move in ["coil", "tree", "ambush"]


func _on_begin(m: String) -> void:
	var p := _target()
	_aim = p.global_position if p else global_position + _fwd() * 6.0
	_n = 0
	_hops = 0
	match m:
		"rise":
			_lift = 3.0
			_pitch = 0.25
			_jaw_open = 0.9
			say("hiss", global_position, 6.0, 0.85)
		"strike":
			_cd["strike"] = _rng.randf_range(2.6, 3.8)
			_strike_begin()
		"sweep":
			_cd["sweep"] = _rng.randf_range(6.0, 8.0)
			_aim = _segs[12]
			warn_ring(ground_at(_aim), 5.6, 0.8)
			say("slither", global_position, 0.0, 1.0)
		"coil":
			_cd["coil"] = _rng.randf_range(9.0, 12.0)
			_aim = ground_at(_aim)
			warn_ring(_aim, COIL_R - 0.6, COIL_T, Color(1.0, 0.55, 0.12))
			say("slither", _aim, 4.0, 0.9)
			_from = global_position
			_fly = true
		"spit":
			_cd["spit"] = _rng.randf_range(7.0, 10.0)
			say("hiss", global_position, 4.0, 1.2)
		"ambush":
			_cd["ambush"] = _rng.randf_range(24.0, 30.0)
			_fly = true
			_from = global_position
			_tree = _far_brush(_aim)
			_to = arena.brush[_tree]
			say("slither", global_position, 2.0, 1.0)
		"train":
			_cd["train"] = _rng.randf_range(11.0, 14.0)
			_train_passes = 3 if phase >= 3 else 2
			_fly = true
			say("slither", global_position, 4.0, 0.8, 120.0)
		"tree":
			_cd["tree"] = _rng.randf_range(22.0, 28.0)
			_tree = _near_tree()
			_fly = true
			_from = global_position
			var t: Dictionary = arena.trees[_tree]
			var base: Vector3 = t["base"]
			_to = base + _flat(arena.centre() - base).normalized() * (float(t["r"]) + 1.0)


func _strike_begin() -> void:
	_from = global_position
	var d := _flat(_aim - global_position)
	d = d.normalized() if d.length() > 0.1 else _fwd()
	_face(d)
	_to = ground_at(global_position + d * STRIKE_LEN)
	warn_lane(global_position, _to, 2.6, STRIKE_WIND)
	say("hiss", global_position, 4.0, 1.0)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"rise":
			if mv_t > 1.5:
				end_move(0.2)
		"strike":
			return _strike_tick(delta, p)
		"sweep":
			_lift = 1.2
			_sway = 1.0 if mv_t > 0.7 and mv_t < 1.1 else 0.0
			if mv_t > 0.8 and not _hit:
				_hit = true
				strike("ring", [ground_at(_segs[12]), 5.6], 20.0, false, false, 1.0, 9.0)
				Net.fx("dust_ring", [ground_at(_segs[12]), 18, 1.3])
				Net.fx("sfx", ["whoosh_big", _segs[12], 2.0, 0.05, 0.6])
			if mv_t > 1.4:
				end_move(0.6)
		"coil":
			_lift = 1.2
			_jaw_open = 0.5
			var a0 := atan2(_from.z - _aim.z, _from.x - _aim.x)
			var a := a0 + TAU * 1.05 * clampf(mv_t / COIL_T, 0.0, 1.0)
			var at := _aim + Vector3(cos(a), 0, sin(a)) * COIL_R
			at.y = ground_at(at).y
			_face(Vector3(-sin(a), 0, cos(a)))
			global_position = global_position.lerp(at, minf(delta * 12.0, 1.0))
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.3
				Net.fx("dust", [global_position, 4, 0.8])
			if mv_t > COIL_T and not _hit:
				_hit = true
				strike("ring", [_aim, COIL_R - 0.6], 30.0, false, false, 1.4, 4.0, 1.2)
				Net.fx("dust_ring", [_aim, 30, 2.0])
				Net.fx("sfx", ["crunch", _aim, 6.0, 0.05, 0.6])
				get_node("/root/CombatManager").apply_camera_shake(0.35)
			if mv_t > COIL_T + 0.6:
				end_move(1.0)
		"spit":
			_lift = 3.0
			_pitch = 0.25
			_jaw_open = 1.0
			if p:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.6 and not _hit and p:
				_hit = true
				_spit(p)
			if mv_t > 1.3:
				end_move(0.5)
		"train":
			return _train_tick(delta, p)
		"ambush":
			return _ambush_tick(delta, p)
		"tree":
			return _tree_tick(delta, p)
	return Vector3.ZERO


func _strike_tick(_delta: float, p: Node3D) -> Vector3:
	if mv_t < STRIKE_WIND:
		_lift = 2.6
		_pitch = 0.3
		_jaw_open = 1.0
		return Vector3.ZERO
	var u := clampf((mv_t - STRIKE_WIND) / 0.24, 0.0, 1.0)
	_fly = true
	_lift = 1.0
	_pitch = -0.15
	global_position = _from.lerp(_to, u * (2.0 - u))
	if not _hit and u > 0.3:
		_hit = true
		strike("lane", [_from, _to, 1.4], 24.0, false, true, 1.1, 10.0)
		Net.fx("sfx", ["whoosh_big", global_position, 2.0, 0.05, 0.8])
	if mv_t > STRIKE_WIND + 0.24:
		_fly = false
		_jaw_open = 0.2
		_lift = 0.5
	if mv_t > STRIKE_WIND + 1.0:
		if phase >= 3 and _n == 0 and p:
			_n = 1
			_hit = false
			_aim = p.global_position
			mv_t = 0.2
			_strike_begin()
			return Vector3.ZERO
		end_move(0.8)
	return Vector3.ZERO


## Into the brush and along it, unseen but for the thrashing, then out at you.
func _ambush_tick(delta: float, p: Node3D) -> Vector3:
	_lift = 0.3
	_jaw_open = 0.05
	_fx_t -= delta
	if _n == 0:
		# slipping off into the brush
		var to := _flat(_to - global_position)
		_face(to)
		global_position = global_position.move_toward(Vector3(_to.x, ground_at(_to).y, _to.z), delta * 10.0)
		if to.length() < 0.8:
			_n = 1
			mv_t = 0.0
			model.visible = false
			_skel.visible = false
			hurtbox.monitorable = false
		return Vector3.ZERO
	if _n == 1:
		# moving through the undergrowth, brush spot to brush spot
		var n: int = (arena.brush as Array).size()
		if mv_t > 0.8:
			mv_t = 0.0
			_hops += 1
			if _hops > 3 + (1 if phase >= 3 else 0):
				_n = 2
				return Vector3.ZERO
			_tree = posmod(_tree + (1 if _rng.randf() < 0.65 else -1), n)
			_to = arena.brush[_tree]
		global_position = global_position.lerp(Vector3(_to.x, ground_at(_to).y, _to.z), minf(delta * 4.0, 1.0))
		if _fx_t <= 0.0:
			_fx_t = 0.35
			BeastFX.brush(global_position, 6)
			Net.event(self, "brush", [global_position])
			if _rng.randf() < 0.4:
				say("slither", global_position, 0.0, 1.0)
		return Vector3.ZERO
	if _n == 2:
		# out: the body laid back into the brush behind the head, a strip toward you
		_n = 3
		mv_t = 0.0
		var out := _flat(global_position - arena.centre()).normalized()
		for i in range(SEGS):
			_segs[i] = global_position + out * (1.0 + i * SPACING * 0.6)
		model.visible = true
		_skel.visible = true
		hurtbox.monitorable = true
		_aim = p.global_position if p else arena.centre()
		_from = global_position
		var d := _flat(_aim - global_position).normalized()
		_face(d)
		_to = ground_at(global_position + d * 13.0)
		warn_lane(_from, _to, 2.6, 0.65)
		say("hiss", global_position, 6.0, 0.9)
		BeastFX.brush(global_position, 14)
		Net.event(self, "brush", [global_position])
		return Vector3.ZERO
	_lift = 1.6 if mv_t < 0.65 else 0.9
	_jaw_open = 1.0
	if mv_t >= 0.65:
		var u := clampf((mv_t - 0.65) / 0.32, 0.0, 1.0)
		global_position = _from.lerp(_to, u * (2.0 - u))
		if not _hit and u > 0.3:
			_hit = true
			strike("lane", [_from, _to, 1.5], 28.0, false, true, 1.1, 11.0)
			Net.fx("sfx", ["whoosh_big", global_position, 3.0, 0.05, 0.7])
	if mv_t > 1.6:
		end_move(1.0)
	return Vector3.ZERO


## Up a giant in a spiral, then down onto you.
func _tree_tick(delta: float, p: Node3D) -> Vector3:
	var t: Dictionary = arena.trees[_tree]
	var base: Vector3 = t["base"]
	var r: float = float(t["r"]) + 0.9
	if _n == 0:
		var to := _flat(_to - global_position)
		_face(to)
		global_position = global_position.move_toward(Vector3(_to.x, ground_at(_to).y, _to.z), delta * _speed() * 1.6)
		if to.length() < 0.8:
			_n = 1
			mv_t = 0.0
			_from = global_position
			say("slither", global_position, 4.0, 0.9)
		return Vector3.ZERO
	if _n == 1:
		var u := clampf(mv_t / TREE_UP, 0.0, 1.0)
		var a0 := atan2(_from.z - base.z, _from.x - base.x)
		var a := a0 + TAU * 1.3 * u
		global_position = base + Vector3(cos(a) * r, 0.5 + 9.5 * u, sin(a) * r)
		_face(Vector3(-sin(a), 0, cos(a)))
		_lift = 0.5
		_pitch = 0.6 * u
		_fx_t -= delta
		if _fx_t <= 0.0:
			_fx_t = 0.5
			Net.fx("debris", [global_position, Vector3.UP, 4, Color(0.4, 0.3, 0.22), 2.0])
		if u >= 1.0:
			_n = 2
			mv_t = 0.0
			_from = global_position
			_aim = ground_at(p.global_position if p else arena.centre())
			warn_ring(_aim, 4.4, TREE_WARN + 0.45)
			say("hiss", global_position, 8.0, 0.75)
			arena.shake(_tree, 0.8)
			Net.event(self, "shake", [_tree, 0.8])
		return Vector3.ZERO
	if _n == 2:
		_face(_flat(_aim - global_position))
		_pitch = -0.5
		_jaw_open = 1.0
		if mv_t > TREE_WARN:
			var u := clampf((mv_t - TREE_WARN) / 0.45, 0.0, 1.0)
			global_position = _from.lerp(_aim, u * u)
			if u >= 1.0 and not _hit:
				_hit = true
				strike("ring", [_aim, 4.4], 32.0, false, false, 1.2, 10.0)
				quake(_aim, 1.0)
				_n = 3
				mv_t = 0.0
		return Vector3.ZERO
	# stunned where it landed: the opening
	_lift = 0.35
	_pitch = 0.0
	_jaw_open = 0.6
	if mv_t > 1.8:
		end_move(0.3)
	return Vector3.ZERO


func _spit(p: Node3D) -> void:
	var from := _head.global_position + _fwd() * 1.2
	var tgt := p.global_position + Vector3(0, 1.0, 0)
	var t := clampf(from.distance_to(tgt) / 12.0, 0.5, 1.3)
	var n := 5 if phase < 3 else 7
	for i in range(n):
		var off := (i - (n - 1) * 0.5) * deg_to_rad(12.0)
		var d := tgt - from
		var flat := Vector3(d.x, 0, d.z).rotated(Vector3.UP, off)
		var vel := Vector3(flat.x, d.y, flat.z) / t + Vector3(0, 0.5 * PoisonGlob.GRAVITY * t, 0)
		Net.fx("spit", [from, vel, _dmg(9.0), 1.4, 5.0, 4.0])


func _far_brush(from: Vector3) -> int:
	var best := 0
	var bd := -1.0
	for i in range((arena.brush as Array).size()):
		var d := _flat((arena.brush[i] as Vector3) - from).length()
		if d > bd:
			bd = d
			best = i
	return best


func _near_tree() -> int:
	var best := 0
	var bd := INF
	for i in range((arena.trees as Array).size()):
		var d := _flat((arena.trees[i]["base"] as Vector3) - global_position).length()
		if d < bd:
			bd = d
			best = i
	return best


func _on_stagger() -> void:
	_lift = 0.35
	_jaw_open = 0.6
	model.visible = true
	_skel.visible = true
	hurtbox.monitorable = true
	say("hiss", global_position, 2.0, 1.3)


func _on_die() -> void:
	_lift = 0.2
	_pitch = 0.1
	_jaw_open = 1.0
	model.visible = true
	_skel.visible = true
	say("hiss", global_position, 4.0, 0.6)


func reset_fight() -> void:
	super.reset_fight()
	model.visible = true
	_skel.visible = true
	hurtbox.monitorable = true
	global_position = post + Vector3.UP * 0.3


# ==========================================================================
# Co-op
# ==========================================================================
func _pack_extra() -> Array:
	return [PackedVector3Array(_segs), _skel.visible]


func _unpack_extra(a: Array, b: Array, f: float) -> void:
	var sa: PackedVector3Array = a[0]
	var sb: PackedVector3Array = b[0]
	for i in range(SEGS):
		_segs[i] = sa[i].lerp(sb[i], f)
	_skel.visible = bool(a[1])
	hurtbox.monitorable = bool(a[1]) and state != S.DEAD


func _event(what: String, args: Array) -> void:
	match what:
		"brush":
			BeastFX.brush(args[0], 6)
		"shake":
			arena.shake(int(args[0]), float(args[1]))
		"train_hide":
			model.visible = not bool(args[0])
			_skel.visible = not bool(args[0])


# ==========================================================================
# The train (1.20, docs/v1_20_beasts.md 2; Zach: it barely came into its arena): gone into the brush, then out of it
# at the floor's edge on a line through you (a red lane and the ground rumbling), straight across the whole floor and
# out the far side at a train's speed; back on another line; two passes, three enraged. Then it lies there, its head
# on the ground: the opening. Its one knockdown.
# ==========================================================================
const TRAIN_SPEED := 24.0
const TRAIN_WARN := 0.9
var _train_passes := 2


func _train_r() -> float:
	return BeastArena.FLOOR_R + 3.0


func _train_tick(delta: float, p: Node3D) -> Vector3:
	var c: Vector3 = p.global_position if p else (arena.centre() if arena else global_position)
	if _n == 0:
		# into the brush (hidden), set up the first pass
		_train_hide(true)
		_n = 1
		mv_t = 0.0
		_train_line(c)
		return Vector3.ZERO
	if _n % 2 == 1:
		# the warning: under the brush at the floor's edge, a lane through you, the ground rumbling
		_fx_t -= delta
		if _fx_t <= 0.0:
			_fx_t = 0.15
			Net.fx("dust", [_from.lerp(_to, randf()), 4, 0.8])
		if mv_t >= TRAIN_WARN:
			_n += 1
			mv_t = 0.0
			_hit = false
			_train_hide(false)
			say("hiss", _from, 6.0, 0.7, 120.0)
			BeastFX.brush(_from, 14)
			Net.event(self, "brush", [_from])
		return Vector3.ZERO
	# the pass: the head runs the whole line, the body pouring along behind it
	var ln := _flat(_to - _from).length()
	var u := clampf(mv_t * TRAIN_SPEED / maxf(ln, 1.0), 0.0, 1.0)
	global_position = _from.lerp(_to, u)
	global_position.y = ground_at(global_position).y
	if not _hit and u > 0.05:
		_hit = true
		strike("lane", [_from, _to, 1.7], 30.0, true)
		Net.fx("sfx", ["whoosh_big", global_position, 4.0, 0.05, 0.6])
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.1
		Net.fx("dust", [global_position, 5, 1.0])
	if u >= 1.0:
		var done := floori(_n / 2.0)
		if done >= _train_passes:
			# down at the far side, its head on the ground: the opening
			_fly = false
			_lift = 0.35
			end_move(1.6)
			return Vector3.ZERO
		_train_hide(true)
		_n += 1
		mv_t = 0.0
		_train_line(c)
	return Vector3.ZERO


## A line through `c` at an angle of its own, from outside the floor's edge to past the far side; the body laid
## back along it behind the head.
func _train_line(c: Vector3) -> void:
	var a := _rng.randf() * TAU
	var d := Vector3(cos(a), 0.0, sin(a))
	_from = ground_at(c - d * _train_r())
	_to = ground_at(c + d * _train_r())
	global_position = _from
	reset_physics_interpolation()
	_face(d)
	for i in range(SEGS):
		_segs[i] = _from - d * (1.0 + i * SPACING)
	warn_lane(_from, _to, 3.4, TRAIN_WARN)


func _train_hide(on: bool) -> void:
	model.visible = not on
	_skel.visible = not on
	hurtbox.monitorable = not on
	Net.event(self, "train_hide", [on])
