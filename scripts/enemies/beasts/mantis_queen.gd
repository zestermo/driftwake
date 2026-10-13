extends JungleBeast
## The Mantis Queen: a mantis taller than a house, coloured like the leaves she
## hides in (a green leaf, an orchid, a dead leaf by the island's look), in her
## bower (BeastArena, BeastPool "mantis"). Rigid parts on joints: a sloping
## thorax, a great ribbed abdomen, the long neck-plate rearing up to a triangle
## of a head with huge eyes, two folded scythes, four walking legs and two
## pairs of leaf wings that flare when she threatens.
##
## Moves (each with its tell):
##   display  she rears, wings flared, and screeches (a shockwave: jump it); woken and at each phase
##   scythe   both scythes raised high, then two cuts in front; the second is the
##            heavy one: parry it and she reels
##   snap     scythes thrown wide, a red strip, then she lunges along it and snaps them shut
##   flit     (phase 2+) up onto a giant's limb on whirring wings, still as a leaf
##            for a breath, then she dives across the floor along a strip through you
##   whirl    (phase 3) a spin with the scythes out: three cuts all round (a ring each time)
## Phases at 60% and 30%.

const FILM := [["display", 2.0], ["scythe", 2.0], ["snap", 1.8], ["flit", 4.6], ["whirl", 2.2]]
const SKINS := [
	[Color(0.36, 0.58, 0.22), Color(0.62, 0.78, 0.36), Color(0.2, 0.34, 0.12)],
	[Color(0.93, 0.8, 0.86), Color(0.98, 0.94, 0.92), Color(0.78, 0.42, 0.6)],
	[Color(0.56, 0.42, 0.24), Color(0.72, 0.58, 0.36), Color(0.32, 0.22, 0.12)],
]
const H := 1.8
const SCY_AT := [0.65, 1.25]
const SNAP_WIND := 0.7
const FLIT_UP := 0.9
const FLIT_HOLD := 1.1
const FLIT_WARN := 0.9

var _skin: Array
var _j := {}
var _hurt: Array = []
var _legs: Array = []
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _n: int = 0
var _perch: int = 0
var _t: float = 0.0
var _last := Vector3.ZERO
var _spd: float = 0.0


func _init() -> void:
	boss_name = "The Mantis Queen"


func _hp_base() -> float:
	return 1300.0


func _poise_max() -> float:
	return 200.0


func _speed() -> float:
	return 4.6 if phase < 3 else 5.6


func _hit_point() -> Vector3:
	return global_position + Vector3(0, 2.4, 0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "pauldron", {"pauldron": true}, "Queen's Scythe-Plate", t)


func _wake_move() -> String:
	return "display"


# ==========================================================================
# The body
# ==========================================================================
func _build() -> void:
	_skin = SKINS[variant % SKINS.size()]
	_cd = {"scythe": 0.5, "snap": 3.0, "flit": 99.0, "whirl": 99.0}
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 3.0
	col.shape = cap
	col.position = Vector3(0, 1.5, 0)
	add_child(col)
	var shell := own(PSXMat.lit("leather", Color(1.15, 1.15, 1.15)))
	var eye := own(PSXMat.lit("leather", Color(0.9, 1.0, 0.85), {"emission": Color(0.35, 0.6, 0.25), "emission_energy": 0.6}))
	var dark := PSXMat.flat(Color(0.08, 0.08, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6631 + variant
	var body := _joint("Body", Vector3(0, H, 0), model)
	var b := MeshBuilder.new()
	# the abdomen: long, ribbed, lifting at the tip
	var ab := []
	for k in range(9):
		var z := 0.2 + k * 0.38
		var r := 0.38 + sin(minf(k / 6.0, 1.0) * PI * 0.8) * 0.5 - maxf(0.0, k - 6) * 0.18
		ab.append([z, r * (1.0 if k % 2 == 0 else 0.93), r * 0.82 * (1.0 if k % 2 == 0 else 0.93), 0.08 * k * k * 0.03])
	b.add_loft(shell, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.12), Vector3(0, 0.05, 0)), ab, MeshBuilder.profile_circle(9), 1.0, Color.WHITE, true, true)
	# the thorax
	b.add_loft(shell, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), [[-0.45, 0.22, 0.24], [-0.1, 0.34, 0.3], [0.25, 0.32, 0.3]], MeshBuilder.profile_circle(8), 1.0, Color(0.95, 0.95, 0.95), true, true)
	_wings(body, shell, rng)
	_mesh(body, b, shell)
	# the long neck-plate rearing up to the head
	var neck := _joint("Neck", Vector3(0, 0.05, -0.4), body)
	neck.rotation.x = 0.95
	var nb := MeshBuilder.new()
	nb.add_loft(shell, Transform3D.IDENTITY, [[0.0, 0.2, 0.18], [0.5, 0.15, 0.14], [1.2, 0.17, 0.15], [1.6, 0.13, 0.12]], MeshBuilder.profile_circle(7), 1.0, Color(0.92, 0.92, 0.92), true, true)
	nb.add_box(shell, Transform3D(Basis(), Vector3(0, 0.7, 0.12)), Vector3(0.3, 1.1, 0.06), 1.0, Color(0.85, 0.85, 0.85), false)
	_mesh(neck, nb, shell)
	var head := _joint("Head", Vector3(0, 1.65, 0), neck)
	head.rotation.x = -0.95
	var hb := MeshBuilder.new()
	hb.add_blob(shell, Transform3D(Basis(), Vector3(0, 0.05, -0.05)), Vector3(0.36, 0.3, 0.26), rng, 0.06, 4, 8, 1.0)
	hb.add_blob(shell, Transform3D(Basis(), Vector3(0, -0.22, -0.18)), Vector3(0.16, 0.2, 0.14), rng, 0.05, 3, 6, 1.0, Color(0.85, 0.85, 0.85))
	for s in [-1.0, 1.0]:
		hb.add_blob(eye, Transform3D(Basis(), Vector3(s * 0.38, 0.14, -0.04)), Vector3(0.2, 0.24, 0.2), rng, 0.0, 4, 8, 1.0)
		hb.add_box(dark, Transform3D(Basis(), Vector3(s * 0.5, 0.14, -0.1)), Vector3(0.04, 0.07, 0.04), 1.0)
		hb.add_tube(shell, PackedVector3Array([Vector3(s * 0.08, 0.3, -0.12), Vector3(s * 0.3, 0.9, -0.4), Vector3(s * 0.7, 1.3, -0.2)]), 0.025, 0.01, 3, 1.0, Color(0.8, 0.8, 0.8))
		hb.add_cylinder(dark, Transform3D(Basis(Vector3.FORWARD, s * 0.4) * Basis(Vector3.RIGHT, PI), Vector3(s * 0.08, -0.36, -0.22)), 0.05, 0.0, 0.18, 4, 1.0)
	_mesh(head, hb, shell)
	_j["Head"] = head
	# the scythes off the neck-plate's foot
	for s in [-1.0, 1.0]:
		var nm := "L" if s < 0.0 else "R"
		var coxa := _joint("Coxa" + nm, Vector3(s * 0.2, 0.3, 0.05), neck)
		var cb := MeshBuilder.new()
		cb.add_cylinder(shell, Transform3D.IDENTITY, 0.13, 0.11, 0.75, 6, 1.0, Color(0.9, 0.9, 0.9))
		_mesh(coxa, cb, shell)
		var femur := _joint("Femur" + nm, Vector3(0, 0.75, 0), coxa)
		var fb := MeshBuilder.new()
		var blade := PackedVector2Array([Vector2(-0.12, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.9), Vector2(0.08, 1.45), Vector2(-0.04, 1.5),
			Vector2(-0.1, 0.5)])
		fb.add_extrude(shell, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0.0)), blade, 0.14, 1.0, Color(0.95, 0.95, 0.95))
		for k in range(5):
			fb.add_cylinder(dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.3), Vector3(0, 0.25 + k * 0.25, 0.1)), 0.03, 0.0, 0.16, 3, 1.0)
		_mesh(femur, fb, shell)
		var tibia := _joint("Tibia" + nm, Vector3(0, 1.45, 0), femur)
		var tb := MeshBuilder.new()
		var hook := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.09, 0.8), Vector2(0.3, 1.15), Vector2(0.05, 1.05), Vector2(-0.05, 0.8)])
		tb.add_extrude(shell, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), hook, 0.1, 1.0, Color(0.88, 0.88, 0.88))
		_mesh(tibia, tb, shell)
	# four walking legs, high-kneed
	for k in range(4):
		var s := -1.0 if k % 2 == 0 else 1.0
		var z := -0.15 if k < 2 else 0.25
		var leg := _joint("Leg%d" % k, Vector3(s * 0.25, -0.05, z), body)
		var lb := MeshBuilder.new()
		var knee := Vector3(s * 1.0, 0.55, -0.35 if k < 2 else 0.5)
		var foot := Vector3(s * 1.55, -H + 0.05, -0.7 if k < 2 else 1.1)
		lb.add_tube(shell, PackedVector3Array([Vector3.ZERO, knee]), 0.07, 0.06, 5, 1.0, Color(0.85, 0.85, 0.85))
		lb.add_tube(shell, PackedVector3Array([knee, foot]), 0.055, 0.03, 5, 1.0, Color(0.8, 0.8, 0.8))
		_mesh(leg, lb, shell)
		_legs.append(leg)
	_hurt.append(hurt_ball(0.8, Vector3(0, H, 0)))
	_hurt.append(hurt_ball(1.0, Vector3(0, H, 1.5)))
	_hurt.append(hurt_ball(0.7, Vector3(0, H + 1.3, -0.9)))


func _wings(body: Node3D, shell: Material, rng: RandomNumberGenerator) -> void:
	for s in [-1.0, 1.0]:
		var w := _joint("Wing" + ("L" if s < 0.0 else "R"), Vector3(s * 0.12, 0.3, 0.0), body)
		var wb := MeshBuilder.new()
		var leaf := PackedVector2Array([Vector2(0, 0), Vector2(0.45, 0.6), Vector2(0.55, 1.6), Vector2(0.35, 2.6), Vector2(0.0, 3.0), Vector2(-0.15, 2.0), Vector2(-0.1, 0.8)])
		wb.add_extrude(shell, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, 0.0), Vector3(0, 0.0, 0)), leaf, 0.03, 0.6, Color(1.05, 1.05, 1.05))
		wb.add_extrude(shell, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.15, -0.05, 0.1)), leaf, 0.03, 0.6, Color(0.85, 0.85, 0.85))
		var vein := PSXMat.flat(_skin[2])
		wb.add_box(vein, Transform3D(Basis(), Vector3(0.15, 0.03, 1.4)), Vector3(0.03, 0.02, 2.6), 1.0)
		_mesh(w, wb, shell)
		_j["Wing" + ("L" if s < 0.0 else "R")] = w
		rng.randf()


func _joint(n: String, pos: Vector3, parent: Node3D) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	parent.add_child(x)
	_j[n] = x
	return x


func _mesh(node: Node3D, b: MeshBuilder, shell: Material) -> void:
	if b._surfaces.has(shell):
		var v: PackedVector3Array = b._surfaces[shell]["v"]
		var c: PackedColorArray = b._surfaces[shell]["c"]
		for i in range(v.size()):
			var stripe := smoothstep(0.6, 0.9, sin(v[i].z * 6.0 + v[i].x * 3.0) * 0.5 + 0.5) * 0.35
			c[i] = (_skin[0] as Color).lerp(_skin[1], smoothstep(0.0, -0.3, v[i].y)).lerp(_skin[2], stripe) * c[i].r
		b._surfaces[shell]["c"] = c
	node.add_child(b.to_instance("Mesh"))


# ==========================================================================
# Poses
# ==========================================================================
func _animate(delta: float) -> void:
	_t += delta
	var moved := _flat(global_position - _last)
	_last = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	var rear := 0.0
	var wings := 0.0
	var arm := [0.0, 0.0]   # coxa pitch, femur fold (0 folded .. 1 out)
	var low := 0.0
	if state == S.STAGGER:
		rear = -0.25
		low = 0.4
	elif state == S.DEAD:
		rear = -0.4
		low = 1.0
		wings = 0.4
	elif state == S.SLEEP:
		low = 0.25
	else:
		match move:
			"display":
				rear = 0.45
				wings = 1.0
				arm = [-0.6, 0.9]
			"scythe":
				var up := 0.0
				var cut := 0.0
				for at in SCY_AT:
					up = maxf(up, 1.0 - clampf(absf(mv_t - float(at) + 0.25) / 0.25, 0.0, 1.0))
					cut = maxf(cut, 1.0 - clampf(absf(mv_t - float(at) - 0.05) / 0.12, 0.0, 1.0))
				rear = up * 0.35 - cut * 0.2
				arm = [-1.1 * up + 1.1 * cut, up + cut]
			"snap":
				if mv_t < SNAP_WIND:
					rear = 0.2
					arm = [-0.7, 1.0]
					wings = 0.5
				else:
					rear = -0.25
					arm = [1.0, 0.1]
			"flit":
				wings = 0.6 + 0.4 * sin(_t * 60.0) if (_n == 1 or _n == 3) else 0.15
				arm = [0.3, 0.3] if _n != 3 else [0.9, 0.9]
				rear = 0.1 if _n != 3 else -0.4
			"whirl":
				arm = [0.4, 1.0]
				wings = 0.3
	var body: Node3D = _j["Body"]
	body.position.y = lerpf(body.position.y, H * (1.0 - low * 0.45) + sin(_t * 2.0) * 0.04, minf(delta * 8.0, 1.0))
	body.rotation.x = lerp_angle(body.rotation.x, -rear * 0.6, minf(delta * 9.0, 1.0))
	var head: Node3D = _j["Head"]
	head.rotation.y = sin(_t * 0.9) * 0.25 if move == "" else 0.0
	for s in ["L", "R"]:
		var coxa: Node3D = _j["Coxa" + s]
		var femur: Node3D = _j["Femur" + s]
		var tibia: Node3D = _j["Tibia" + s]
		coxa.rotation.x = lerp_angle(coxa.rotation.x, -1.6 + float(arm[0]), minf(delta * 16.0, 1.0))
		femur.rotation.x = lerp_angle(femur.rotation.x, -2.6 + float(arm[1]) * 2.0, minf(delta * 16.0, 1.0))
		tibia.rotation.x = lerp_angle(tibia.rotation.x, -2.5 + float(arm[1]) * 1.6, minf(delta * 18.0, 1.0))
		var w: Node3D = _j["Wing" + s]
		var sg := -1.0 if s == "L" else 1.0
		w.rotation.z = lerp_angle(w.rotation.z, sg * wings * 1.1, minf(delta * 14.0, 1.0))
		w.rotation.x = lerp_angle(w.rotation.x, -wings * 0.7, minf(delta * 14.0, 1.0))
	var step := clampf(_spd / 4.0, 0.0, 1.0)
	for i in range(_legs.size()):
		var leg: Node3D = _legs[i]
		leg.rotation.y = sin(_t * 9.0 + i * PI * 0.5) * 0.25 * step
		leg.rotation.z = maxf(0.0, sin(_t * 9.0 + i * PI * 0.5)) * 0.15 * step * (1.0 if i % 2 == 0 else -1.0)
	if move == "whirl" and not net_puppet and mv_t > 0.4 and mv_t < 1.8:
		_yaw += delta * TAU * 1.4
		model.rotation.y = _yaw
	(_hurt[0] as CollisionShape3D).position = to_local(body.global_position)
	(_hurt[1] as CollisionShape3D).position = to_local(body.global_transform * Vector3(0, 0.1, 1.5))
	(_hurt[2] as CollisionShape3D).position = to_local(head.global_position)


# ==========================================================================
# The brain
# ==========================================================================
func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	if phase >= 2 and _cd["flit"] <= 0.0 and not (arena.trees as Array).is_empty():
		begin("flit")
	elif phase >= 3 and dist < 5.0 and _cd["whirl"] <= 0.0:
		begin("whirl")
	elif dist < 5.2 and _cd["scythe"] <= 0.0:
		begin("scythe")
	elif dist > 4.5 and dist < 9.5 and _cd["snap"] <= 0.0:
		begin("snap")
	elif dist > 4.2:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	else:
		return -to.normalized() * 1.2
	return Vector3.ZERO


func _on_phase(k: int) -> void:
	_cd["flit"] = 1.0
	if k >= 3:
		_cd["whirl"] = 2.0
	begin("display")


func _parry_ok() -> bool:
	return move == "scythe" and mv_t > SCY_AT[1] - 0.25 and mv_t < SCY_AT[1] + 0.12


func _armoured() -> bool:
	return move in ["display", "flit", "whirl"]


func _on_begin(m: String) -> void:
	_n = 0
	var p := _target()
	match m:
		"display":
			say("screech", global_position, 6.0, 1.0)
		"scythe":
			_cd["scythe"] = _rng.randf_range(2.4, 3.4)
			say("click", global_position, 0.0, 1.0)
		"snap":
			_cd["snap"] = _rng.randf_range(5.0, 7.0)
			_from = global_position
			var d := _flat((p.global_position if p else global_position + _fwd()) - global_position).normalized()
			_face(d)
			_to = ground_at(global_position + d * 8.5)
			warn_lane(_from, _to, 2.8, SNAP_WIND)
			say("click", global_position, 3.0, 0.8)
		"flit":
			_cd["flit"] = _rng.randf_range(18.0, 24.0)
			_perch = _rng.randi() % (arena.trees as Array).size()
			_from = global_position
			_to = arena.trees[_perch]["perch"]
			_fly = true
			say("screech", global_position, 0.0, 1.5)
		"whirl":
			_cd["whirl"] = _rng.randf_range(10.0, 13.0)
			warn_ring(global_position, 4.8, 0.45)
			say("screech", global_position, 3.0, 1.3)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"display":
			if mv_t > 0.9 and not _hit:
				_hit = true
				strike("ring", [global_position, 7.0], 10.0, true, false, 1.1)
				Net.fx("dust_ring", [global_position, 26, 2.0])
				get_node("/root/CombatManager").apply_camera_shake(0.3)
			if mv_t > 1.8:
				end_move(0.3)
		"scythe":
			if p and mv_t < SCY_AT[mini(_n, 1)] - 0.15:
				_face(_flat(p.global_position - global_position))
			if _n < 2 and mv_t > SCY_AT[_n]:
				var heavy := _n == 1
				strike("cone", [global_position, _fwd(), 5.0, 55.0], 22.0 if heavy else 15.0, heavy, heavy)
				Net.fx("sfx", ["whoosh_big", global_position + _fwd() * 2.5, 2.0, 0.05, 1.1])
				var side := _fwd().cross(Vector3.UP) * (1.0 if _n == 0 else -1.0)
				Net.fx("streak", [global_position + _fwd() * 3.0 + side * 2.0 + Vector3(0, 2.6, 0), global_position + _fwd() * 3.2 - side * 2.0 + Vector3(0, 0.5, 0),
					Color(0.85, 1.0, 0.75) if not heavy else Color(1.0, 0.35, 0.25), 0.16, 0.22])
				_n += 1
				return _fwd() * 4.0
			if mv_t > SCY_AT[1] + 0.7:
				end_move(0.8)
		"snap":
			if mv_t < SNAP_WIND:
				return Vector3.ZERO
			var u := clampf((mv_t - SNAP_WIND) / 0.25, 0.0, 1.0)
			_fly = u < 1.0
			global_position = _from.lerp(_to, u * (2.0 - u))
			if not _hit and u > 0.4:
				_hit = true
				strike("lane", [_from, _to, 1.5], 26.0, true)
				Net.fx("sfx", ["crunch", _to, 4.0, 0.05, 1.2])
			if mv_t > SNAP_WIND + 1.0:
				end_move(0.9)
		"flit":
			return _flit_tick(delta, p)
		"whirl":
			for k in range(3):
				var at := 0.45 + k * 0.45
				if _n == k and mv_t > at:
					_n += 1
					strike("ring", [global_position, 4.8], 12.0, k == 2, false, 1.0)
					Net.fx("sfx", ["whoosh_big", global_position, 2.0, 0.05, 1.2])
					Net.fx("ring", [global_position + Vector3(0, 1.4, 0), Vector3.UP, 4.8, Color(0.85, 1.0, 0.7), 0.25, 0.14])
			if mv_t > 2.0:
				end_move(1.0)
	return Vector3.ZERO


## Up onto a limb on whirring wings, still as a leaf, then a dive through you.
func _flit_tick(delta: float, p: Node3D) -> Vector3:
	if _n == 0:
		_n = 1
	if _n == 1:
		var u := clampf(mv_t / FLIT_UP, 0.0, 1.0)
		var flat := _from.lerp(_to, u)
		global_position = Vector3(flat.x, lerpf(_from.y, _to.y - H * 0.6, u * u * (3.0 - 2.0 * u)) + sin(u * PI) * 1.5, flat.z)
		_face(_flat(_to - _from))
		if u >= 1.0:
			_n = 2
			mv_t = 0.0
			arena.shake(_perch, 0.6)
			Net.event(self, "shake", [_perch, 0.6])
			_face(_flat(arena.centre() - global_position))
		return Vector3.ZERO
	if _n == 2:
		if mv_t > FLIT_HOLD:
			_n = 3
			mv_t = 0.0
			_from = global_position
			var aim: Vector3 = p.global_position if p else arena.centre()
			var d := _flat(aim - _from).normalized()
			_face(d)
			var land := ground_at(_flat(aim) + d * 5.0 + Vector3(0, aim.y, 0))
			_to = land
			warn_lane(ground_at(_from), land, 3.0, FLIT_WARN + 0.5)
			say("screech", global_position, 5.0, 1.2)
		return Vector3.ZERO
	if mv_t < FLIT_WARN:
		return Vector3.ZERO
	var u := clampf((mv_t - FLIT_WARN) / 0.5, 0.0, 1.0)
	global_position = _from.lerp(_to, u)
	if not _hit and u > 0.5:
		_hit = true
		strike("lane", [ground_at(_from), _to, 1.6], 28.0, true)
		Net.fx("sfx", ["whoosh_big", global_position, 4.0, 0.05, 0.9])
	if u >= 1.0 and _n == 3:
		_n = 4
		quake(_to, 0.6)
	if mv_t > FLIT_WARN + 1.6:
		end_move(0.6)
	return Vector3.ZERO


func _on_stagger() -> void:
	say("click", global_position, 2.0, 0.7)


func _on_die() -> void:
	say("screech", global_position, 2.0, 0.6)


func reset_fight() -> void:
	super.reset_fight()
	global_position = post + Vector3.UP * 0.3


func _event(what: String, args: Array) -> void:
	if what == "shake":
		arena.shake(int(args[0]), float(args[1]))
