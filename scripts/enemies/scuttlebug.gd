class_name Scuttlebug
extends CharacterBody3D
## Knee-high shelled beetle of the Brinehollow jungle: the island's first real
## fight, there to get a feel for the combat.
##
## It potters around its burrow. When it spots you it turns with a chitter,
## closes in, then REARS UP (the tell: front legs up, hiss, back legs
## scraping) and RAMS in a straight line. Dodge sideways and it barrels past
## and is left dazed, wide open; ram a wall and it's stunned longer. Light hits
## make it flinch (hitstun); heavy hits and parried rams throw it (physics
## ragdoll) - on its back it kicks its legs until it rolls itself over.
## "Big ones" are larger and tougher, and their ram knocks you off your feet.

signal died(bug: Scuttlebug)

enum S { WANDER, NOTICE, APPROACH, REAR, RAM, RECOVER, DAZED, HITSTUN, DOWN, DEAD }

const GRAVITY := 20.0
const NOTICE_RANGE := 8.5
const GIVE_UP_RANGE := 17.0
const RAM_RANGE := 5.8
const LEASH := 16.0

var big: bool = false
var home := Vector3.ZERO
var size_k: float = 1.0
var max_hp: float = 30.0

var state: S = S.WANDER
var st_t: float = 0.0

var model: Node3D
var rear_pivot: Node3D
var body_node: Node3D
var head_node: Node3D
var legs: Array = []
var hurtbox: Hurtbox
var hitbox: Hitbox
var health: HealthComponent

var _col: CollisionShape3D
var _mats: Array[ShaderMaterial] = []
var _flash: Tween
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _yaw: float = 0.0
var _wander_target := Vector3.ZERO
var _wander_wait: float = 0.0
var _stuck: float = 0.0
var _cooldown: float = 0.0
var _ram_dir := Vector3.ZERO
var _ram_dist: float = 0.0
var _daze_len: float = 1.0
var _stun_vel := Vector3.ZERO
var _stun_len: float = 0.22
var _after_stun: S = S.APPROACH
var _fx_t: float = 0.0
var _t: float = 0.0
var _gait: float = 0.0
var _rear: float = 0.0
var _shake: float = 0.0
var _rag: Ragdoll
var _rest: float = 0.0
var _flip_tries: int = 0
var _flip_cool: float = 0.0
var _righting: float = 0.0
var _flip_side: float = 1.0
var _flip_power: float = 9.0
var _dead_t: float = 0.0
var _sink: float = 0.0
var _settle_t: float = 1.0
var _settle_from := Transform3D.IDENTITY
var _head_from := Transform3D.IDENTITY
var _body_rest := Transform3D.IDENTITY
var _head_rest := Transform3D.IDENTITY
var _damage_number_scene: PackedScene
## Co-op client: a puppet of the host's bug.
var net_puppet: bool = false
var _net_serial: int = -1
var _net_hb_t: float = 0.0


## Markers and the like: is it down for good?
func is_dead() -> bool:
	return state == S.DEAD


## Fighting someone (the music picks up)?
func in_combat() -> bool:
	return state not in [S.WANDER, S.DEAD]


## Call before adding to the tree.
func setup(is_big: bool, home_pos: Vector3) -> Scuttlebug:
	big = is_big
	home = home_pos
	size_k = 1.45 if big else 1.0
	max_hp = 75.0 if big else 30.0
	return self


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	add_to_group("net_sync")
	net_puppet = Net.is_client()
	if net_puppet:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	if home == Vector3.ZERO:
		home = global_position
	_damage_number_scene = load("res://scenes/effects/damage_number.tscn")
	_build_model()
	_build_physics()
	_yaw = _rng.randf() * TAU
	model.rotation.y = _yaw
	_wander_wait = _rng.randf_range(0.5, 2.5)
	_wander_target = global_position
	if Net.hosting:
		net_rescale(Net.hp_scale())


# ==========================================================================
# Model: shell, head with a stubby horn, six two-segment legs
# ==========================================================================
func _mat(c: Color, glow: bool = false) -> ShaderMaterial:
	var base := PSXMat.glow(c, 1.6) if glow else PSXMat.lit("", c)
	var m := base.duplicate() as ShaderMaterial
	_mats.append(m)
	return m


func _build_model() -> void:
	var shell_c := Color(0.55, 0.19, 0.1) if big else Color(0.16, 0.44, 0.41)
	var spot_c := Color(0.1, 0.07, 0.05) if big else Color(0.96, 0.78, 0.3)
	var plate_c := Color(0.36, 0.12, 0.07) if big else Color(0.11, 0.31, 0.29)
	var dark_c := Color(0.15, 0.1, 0.08)
	var eye_c := Color(1.0, 0.25, 0.12) if big else Color(1.0, 0.62, 0.16)
	var m_shell := _mat(shell_c)
	var m_spot := _mat(spot_c)
	var m_plate := _mat(plate_c)
	var m_dark := _mat(dark_c)
	var m_head := _mat(Color(0.12, 0.11, 0.11))
	var m_horn := _mat(Color(0.86, 0.8, 0.62))
	var m_eye := _mat(eye_c, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 if big else 777

	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * size_k
	add_child(model)
	rear_pivot = Node3D.new()
	rear_pivot.name = "Rear"
	rear_pivot.position = Vector3(0, 0.09, 0.28)
	model.add_child(rear_pivot)
	body_node = Node3D.new()
	body_node.name = "Body"
	body_node.position = Vector3(0, 0.09, -0.28)
	rear_pivot.add_child(body_node)
	_body_rest = body_node.transform

	var mb := MeshBuilder.new()
	# wing cases (two domed halves meeting in a groove) with spots
	for sx in [-1.0, 1.0]:
		mb.add_blob(m_shell, Transform3D(Basis.IDENTITY, Vector3(sx * 0.125, 0.03, 0.04)), Vector3(0.155, 0.17, 0.38), rng, 0.04, 4, 7, 0.5, Color.WHITE, -0.15)
		for sp in [[0.18, -0.08], [0.11, 0.14], [0.2, 0.2]]:
			var spos := Vector3(sx * float(sp[0]) * 0.75, 0.0, float(sp[1]))
			var top := 0.03 + 0.17 * sqrt(maxf(0.0, 1.0 - pow((spos.x - sx * 0.125) / 0.155, 2.0) - pow((spos.z - 0.04) / 0.38, 2.0)))
			mb.add_box(m_spot, Transform3D(Basis.IDENTITY, Vector3(spos.x, top * 0.9 - 0.01, spos.z)), Vector3(0.065, 0.035, 0.075), 0.5, Color.WHITE, true, false)
	# belly and thorax plate
	mb.add_blob(m_dark, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0.02)), Vector3(0.22, 0.08, 0.36), rng, 0.03, 3, 7)
	mb.add_blob(m_plate, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.33)), Vector3(0.2, 0.12, 0.13), rng, 0.03, 3, 7)
	var shell_mi := mb.to_instance("Shell")
	body_node.add_child(shell_mi)

	# head
	head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0, -0.01, -0.44)
	body_node.add_child(head_node)
	_head_rest = head_node.transform
	var hb := MeshBuilder.new()
	hb.add_blob(m_head, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.04)), Vector3(0.12, 0.09, 0.1), rng, 0.03, 3, 6)
	# horn: a stout cone forward, tip curling up (bigger on the big ones)
	var hk := 1.35 if big else 1.0
	hb.add_cone(m_horn, Transform3D(Basis(Vector3.RIGHT, -1.25), Vector3(0, 0.04, -0.1)), 0.05 * hk, 0.16 * hk, 5)
	hb.add_cone(m_horn, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.04 + 0.05 * hk, -0.1 - 0.13 * hk)), 0.028 * hk, 0.1 * hk, 5)
	for sx in [-1.0, 1.0]:
		# eyes
		hb.add_box(m_eye, Transform3D(Basis.IDENTITY, Vector3(sx * 0.085, 0.025, -0.1)), Vector3(0.035, 0.035, 0.035), 0.5, Color.WHITE, false, false)
		# mandibles
		hb.add_box(m_head, Transform3D(Basis(Vector3.UP, sx * 0.4), Vector3(sx * 0.05, -0.05, -0.13)), Vector3(0.025, 0.025, 0.08), 0.5, Color.WHITE, false, false)
		# antennae
		var ab := Basis(Vector3.UP, sx * 0.5) * Basis(Vector3.RIGHT, -0.6)
		hb.add_box(m_dark, Transform3D(ab, Vector3(sx * 0.07, 0.06, -0.08) + ab * Vector3(0, 0, -0.08)), Vector3(0.012, 0.012, 0.17), 0.5, Color.WHITE, false, false)
	head_node.add_child(hb.to_instance("HeadMesh"))

	# legs: front / mid / back on each side; tripod groups for the gait
	var hips := [[-0.2, -0.07], [-0.02, 0.0], [0.18, 0.07]]
	for i in range(3):
		for sx in [-1.0, 1.0]:
			var coxa := Node3D.new()
			coxa.position = Vector3(sx * 0.19, -0.06, float(hips[i][0]))
			body_node.add_child(coxa)
			var dz: float = hips[i][1]
			var knee_p := Vector3(sx * 0.15, 0.07, dz)
			var foot_p := Vector3(sx * 0.09, -0.19, dz * 1.6)
			var fm := MeshBuilder.new()
			_seg(fm, m_dark, Vector3.ZERO, knee_p, 0.065)
			coxa.add_child(fm.to_instance("Femur"))
			var knee := Node3D.new()
			knee.position = knee_p
			coxa.add_child(knee)
			var tm := MeshBuilder.new()
			_seg(tm, m_dark, Vector3.ZERO, foot_p, 0.05)
			knee.add_child(tm.to_instance("Tibia"))
			var group := (i + (0 if sx < 0 else 1)) % 2
			legs.append({"coxa": coxa, "knee": knee, "side": sx, "idx": i, "group": group, "seed": _rng.randf() * TAU})


## A box from a to b (a leg segment).
func _seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
	mb.add_box(mat, Transform3D(basis, (a + b) * 0.5), Vector3(t, t, d.length() + t * 0.5), 0.5, Color.WHITE, false, false)


func _build_physics() -> void:
	var k := size_k
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.22 * k
	cap.height = 0.8 * k
	_col.shape = cap
	_col.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.23 * k, 0))
	add_child(_col)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = max_hp
	add_child(health)
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 16
	var hs := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = Vector3(0.8, 1.0, 1.1)  # model space (scaled with the bug)
	hs.shape = hbox
	hs.position = Vector3(0, 0.5, 0)
	hurtbox.add_child(hs)
	model.add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)

	hitbox = Hitbox.new()
	hitbox.name = "RamHitbox"
	hitbox.collision_layer = 64
	hitbox.collision_mask = 128
	var hcs := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(0.7, 0.7, 0.55)
	hcs.shape = rb
	hcs.position = Vector3(0, 0.35, -0.55)
	hitbox.add_child(hcs)
	model.add_child(hitbox)
	hitbox.owner = self
	var hd := HitData.new()
	hd.damage = 18.0 if big else 10.0
	hd.knockback_force = 5.0 if big else 4.5
	hd.stagger_duration = 0.35
	hd.hitstop_duration = 0.07 if big else 0.05
	hd.camera_shake_intensity = 0.28 if big else 0.14
	hd.knockdown = big
	hitbox.hit_data = hd


# ==========================================================================
# Brain
# ==========================================================================
func _set_state(s: S) -> void:
	if state == S.RAM and s != S.RAM:
		hitbox.deactivate()
	state = s
	st_t = 0.0
	_fx_t = 0.0


func _target() -> Node3D:
	if not Net.coop():
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		return _player
	if not is_instance_valid(_player):
		_player = null
	var p := Net.nearest_player(global_position, _player_ok, _player) as Node3D
	if p == null:
		p = Net.nearest_player(global_position, Callable(), _player) as Node3D
	_player = p
	return _player


## Is the player a fair target right now? (alive, on foot, not knocked down)
func _player_ok(p: Node3D) -> bool:
	if p == null:
		return false
	if p.has_method("current_state_name") and str(p.call("current_state_name")) in ["Downed", "Helm"]:
		return false
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		_yaw = atan2(-dir.x, -dir.z)


func _physics_process(delta: float) -> void:
	if net_puppet:
		if state == S.DEAD:
			_dead_update(delta)
		return
	st_t += delta
	_cooldown -= delta
	if state == S.DEAD:
		_dead_update(delta)
		return
	if state == S.DOWN:
		_down_update(delta)
		return
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var p := _target()
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var hv := _flat(velocity)
	var want := Vector3.ZERO
	var accel := 14.0
	var turn := 6.0
	match state:
		S.WANDER:
			_wander_tick(delta)
			want = _wander_vel()
			if _player_ok(p) and dist < NOTICE_RANGE and _cooldown <= 0.0 and _flat(global_position - home).length() < LEASH:
				_set_state(S.NOTICE)
				velocity.y = 2.6
				Net.fx("sfx", ["chitter", global_position, -2.0, 0.1, 0.85 if big else 1.1])
		S.NOTICE:
			_face(to_p)
			turn = 14.0
			if st_t > 0.5:
				_set_state(S.APPROACH)
		S.APPROACH:
			if not _player_ok(p) or dist > GIVE_UP_RANGE or _flat(global_position - home).length() > LEASH + 8.0:
				_cooldown = 2.5
				_wander_target = home
				_set_state(S.WANDER)
			else:
				_face(to_p)
				if dist > RAM_RANGE:
					want = to_p.normalized() * (2.2 if big else 2.7)
				elif dist < 2.2:
					want = -to_p.normalized() * 1.4  # back off to get a run-up
				elif _cooldown <= 0.0:
					_set_state(S.REAR)
					Net.fx("sfx", ["bug_hiss", global_position, -1.0, 0.08, 0.8 if big else 1.0])
		S.REAR:
			var dur := 0.95 if big else 0.75
			if st_t < dur * 0.7 and p:
				_face(to_p)
			turn = 10.0
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.14
				Net.fx("dust", [global_position + model.global_basis.z * 0.45 * size_k, 3, 0.35 * size_k])
			if st_t >= dur:
				_ram_dir = -model.global_basis.z
				_ram_dir.y = 0.0
				_ram_dir = _ram_dir.normalized()
				_ram_dist = 0.0
				_set_state(S.RAM)
				hitbox.activate()
				Net.fx("sfx", ["whoosh", global_position, -3.0, 0.08, 0.7])
				velocity = _ram_dir * _ram_speed()
		S.RAM:
			want = _ram_dir * _ram_speed()
			accel = 60.0
			_ram_dist += _ram_speed() * delta
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.08
				Net.fx("dust", [global_position, 2, 0.4 * size_k])
			if not hitbox.hit_targets.is_empty():
				# rammed you: bounce off
				velocity = -_ram_dir * 3.0 + Vector3.UP * 2.2
				_daze_len = 0.6
				_set_state(S.RECOVER)
				_cooldown = 1.4
			elif is_on_wall() and st_t > 0.06:
				# rammed a wall / tree: bonk, long daze
				velocity = -_ram_dir * 2.5 + Vector3.UP * 2.6
				Net.fx("sfx", ["thud", global_position, 0.0, 0.08, 0.9])
				Net.fx("sparkle", [global_position + Vector3(0, 0.6 * size_k, 0) + _ram_dir * 0.4, 10, Color(1.0, 0.95, 0.6)])
				Net.fx("dust_ring", [global_position, 10, 0.6])
				_daze_len = 2.0
				_set_state(S.RECOVER)
			elif _ram_dist > 7.5 or st_t > 1.0:
				_daze_len = 1.25
				_set_state(S.RECOVER)
		S.RECOVER:
			accel = 22.0
			_fx_t -= delta
			if _fx_t <= 0.0 and hv.length() > 1.5:
				_fx_t = 0.07
				Net.fx("dust", [global_position, 2, 0.4 * size_k])
			if st_t > 0.32:
				_set_state(S.DAZED)
		S.DAZED:
			accel = 14.0
			_fx_t -= delta
			if _fx_t <= 0.0:
				_fx_t = 0.5
				Net.fx("sparkle", [global_position + Vector3(0, 0.75 * size_k, 0), 4, Color(1.0, 0.95, 0.55)])
			if st_t > _daze_len:
				_cooldown = 0.9
				_set_state(S.APPROACH)
		S.HITSTUN:
			want = _stun_vel * maxf(0.0, 1.0 - st_t / _stun_len)
			accel = 40.0
			if st_t > _stun_len:
				if _after_stun == S.DAZED:
					_set_state(S.DAZED)
					st_t = _daze_len * 0.5
				else:
					_cooldown = maxf(_cooldown, 0.45)
					_set_state(S.APPROACH)
	if state != S.RECOVER or st_t > 0.12:
		hv = hv.move_toward(want, accel * delta)
	if _yank > 0.0:
		_yank -= delta
		hv = _yank_v
		if _yank <= 0.0:
			hv *= 0.15
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(turn * delta, 1.0))
	if state == S.WANDER and _wander_wait <= 0.0 and get_real_velocity().length() < 0.2:
		_stuck += delta
		if _stuck > 0.8:
			_stuck = 0.0
			_pick_wander()


func _ram_speed() -> float:
	return 9.0 if big else 10.5


func _wander_tick(delta: float) -> void:
	if _wander_wait > 0.0:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_pick_wander()
		return
	if _flat(_wander_target - global_position).length() < 0.5:
		_wander_wait = _rng.randf_range(1.0, 3.2)


func _pick_wander() -> void:
	var a := _rng.randf() * TAU
	_wander_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.5, 6.0)


func _wander_vel() -> Vector3:
	if _wander_wait > 0.0:
		return Vector3.ZERO
	var d := _flat(_wander_target - global_position)
	if d.length() < 0.5:
		return Vector3.ZERO
	_face(d)
	return d.normalized() * (1.0 if big else 1.3)


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = _flat(global_position - (attacker as Node3D).global_position)
	dir = dir.normalized() if dir.length() > 0.01 else model.global_basis.z
	if hit.dot:
		_number(hit.damage)
		health.take_damage(hit.damage)
		return
	_flash_hit()
	Net.event(self, "flash", [])
	_number(hit.damage)
	Net.fx("impact", [global_position + Vector3(0, 0.45 * size_k, 0) - dir * 0.3 * size_k, Color(0.75, 1.0, 0.55)])
	Net.fx("sfx", ["hit", global_position, -2.0, 0.1, 1.2 if hit.damage < 20.0 else 0.9])
	if not Net.active:
		get_node("/root/CombatManager").apply_hit_effects(hit)
	var was_down := state == S.DOWN
	health.take_damage(hit.damage)
	if state == S.DEAD:
		return
	if was_down:
		# kick it while it's down: the shell skids
		_rag.push(dir * minf(hit.knockback_force, 8.0) * 0.6 + Vector3.UP * 2.5)
		return
	if hit.knockdown:
		var v := dir * clampf(hit.knockback_force * 0.75, 4.0, 8.0) / sqrt(size_k) + Vector3.UP * 4.0
		_knock_down(v, Vector3.UP.cross(dir) * 9.0)
		return
	# hitstun: a short flinch and a shove (interrupts the rear-up and the ram)
	_after_stun = S.DAZED if state in [S.DAZED, S.RECOVER] else S.APPROACH
	_stun_len = 0.16 if big else 0.22
	_stun_vel = dir * minf(hit.knockback_force * 0.6, 5.0) / size_k
	velocity = _stun_vel
	_shake = 1.0
	_rear = minf(_rear, 0.3)
	_set_state(S.HITSTUN)


## The player parried the ram: it gets flipped onto its back.
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	var dir := -_ram_dir if _ram_dir.length() > 0.1 else model.global_basis.z
	if by is Node3D:
		dir = _flat(global_position - (by as Node3D).global_position).normalized()
	_knock_down(dir * 3.5 + Vector3.UP * 4.8, model.global_basis.z.normalized() * 11.0)


## Vine Snare: tied in place for a while.
var _yank: float = 0.0
var _yank_v := Vector3.ZERO


## Vine grapple: small bugs get reeled in, big ones haul the player over.
func vine_weight() -> String:
	return "heavy" if big else "light"


func vine_yank(to: Vector3, dmg: float = 4.0) -> void:
	if Net.forward(self, "vine_yank", [to, dmg]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	var d := _flat(to - global_position)
	var dist := maxf(d.length() - 1.3, 0.0)
	var secs := clampf(dist / 16.0, 0.12, 0.6)
	_yank = secs
	_yank_v = d.normalized() * (dist / secs) if d.length() > 0.01 else Vector3.ZERO
	velocity.y = 3.0
	_daze_len = secs + 0.8
	_set_state(S.DAZED)
	health.take_damage(dmg)
	_number(dmg)
	Net.fx("vine_wrap", [self, secs + 0.3, 0.45 * size_k])


func rooted(secs: float) -> void:
	if Net.forward(self, "rooted", [secs]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	_daze_len = secs
	velocity = Vector3.ZERO
	_set_state(S.DAZED)
	Net.fx("vine_wrap", [self, secs, 0.45 * size_k])


func _number(dmg: float) -> void:
	Net.damage_number(dmg, global_position + Vector3(0, 0.6 * size_k, 0))


func _set_tint(c: Color) -> void:
	for m in _mats:
		m.set_shader_parameter("tint_mul", c)


func _flash_hit() -> void:
	if _flash:
		_flash.kill()
	_set_tint(Color(2.2, 0.8, 0.7))
	_flash = create_tween()
	_flash.tween_method(_set_tint, Color(2.2, 0.8, 0.7), Color.WHITE, 0.18)


# ==========================================================================
# Ragdoll: thrown, on its back, rolling over; death
# ==========================================================================
func _make_ragdoll(v: Vector3, spin: Vector3) -> void:
	if _rag:
		return
	_rag = Ragdoll.create(get_tree())
	_rag.add_part("shell", body_node, {"box": [Vector3(0, 0.01, 0.02), Vector3(0.48, 0.3, 0.8)]}, 6.0)
	_rag.add_part("head", head_node, {"sphere": [Vector3(0, 0, -0.04), 0.11]}, 1.0, "shell",
		{"x": [-0.5, 0.5], "y": [-0.5, 0.5], "z": [-0.3, 0.3]})
	_rag.launch(v, spin)
	_rag.drive()


func _knock_down(v: Vector3, spin: Vector3) -> void:
	Net.event(self, "knock", [v, spin])
	hitbox.deactivate()
	_rear = 0.0
	_make_ragdoll(v, spin)
	_rest = 0.0
	_flip_tries = 0
	_flip_cool = 0.9
	_righting = 0.0
	velocity = Vector3.ZERO
	_set_state(S.DOWN)
	Net.fx("sfx", ["chitter", global_position, -1.0, 0.1, 1.35])


func _shell_up() -> float:
	return body_node.global_basis.orthonormalized().y.y


func _follow_shell(delta: float) -> void:
	var rb := _rag.root_body() if _rag else null
	if rb == null:
		return
	var to := _flat(rb.global_position - global_position)
	velocity.x = to.x * 10.0
	velocity.z = to.z * 10.0
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _down_update(delta: float) -> void:
	_follow_shell(delta)
	if _rag == null:
		_set_state(S.DAZED)
		return
	var rb := _rag.root_body()
	_flip_cool -= delta
	if _rag.settled(0.3, 1.0):
		_rest += delta
	else:
		_rest = 0.0
	var up := _shell_up()
	if st_t > 0.6 and _rest > 0.2 and up > 0.6:
		_get_up()
		return
	# rolling itself over: steer the shell's spin toward upright for a moment
	if _righting > 0.0:
		_righting -= delta
		var cur_up := rb.global_basis.orthonormalized().y
		var axis := cur_up.cross(Vector3.UP)
		if axis.length() < 0.2:
			axis = rb.global_basis.orthonormalized().z * _flip_side
		if cur_up.y < 0.85:
			rb.angular_velocity = rb.angular_velocity.lerp(axis.normalized() * _flip_power, minf(delta * 12.0, 1.0))
	elif up < 0.4 and _rest > 0.55 and _flip_cool <= 0.0:
		# kick, hop and roll over (the first try is often a weak one)
		_flip_tries += 1
		_flip_cool = 1.2
		_rest = 0.0
		if _flip_tries > 4:
			_get_up()
			return
		_flip_side = 1.0 if _rng.randf() < 0.5 else -1.0
		_flip_power = 5.0 if _flip_tries == 1 and _rng.randf() < 0.6 else 9.0
		_righting = 0.45
		for p in _rag.parts:
			(p["body"] as RigidBody3D).linear_velocity += Vector3.UP * 2.8
		Net.fx("sfx", ["chitter", global_position, -3.0, 0.1, 1.2])
		Net.fx("dust", [rb.global_position, 4, 0.5])
	if st_t > 7.0:
		_get_up()


## Back on its feet: the root turns to where the shell points and the body
## eases from where it lies back into its stance.
func _get_up() -> void:
	Net.event(self, "getup", [])
	var g := body_node.global_transform
	var hg := head_node.global_transform
	var f := -g.basis.z
	f.y = 0.0
	if f.length() > 0.05:
		_face(f.normalized())
		model.rotation.y = _yaw
	if _rag:
		_rag.restore_rig()
		_rag.queue_free()
		_rag = null
	_settle_from = rear_pivot.global_transform.affine_inverse() * g
	_head_from = g.affine_inverse() * hg
	body_node.global_transform = g
	_settle_t = 0.0
	_daze_len = 0.9
	_set_state(S.DAZED)


func _on_died() -> void:
	if state == S.DEAD:
		return
	var p := _target()
	var dir := _flat(global_position - p.global_position).normalized() if p else model.global_basis.z
	hitbox.deactivate()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	_col.set_deferred("disabled", true)
	collision_layer = 0
	if _rag == null:
		_make_ragdoll(dir * 4.0 / sqrt(size_k) + Vector3.UP * 4.2, Vector3.UP.cross(dir) * 10.0)
	else:
		_rag.push(dir * 3.0 + Vector3.UP * 3.0)
	_set_state(S.DEAD)
	_dead_t = 0.0
	Net.event(self, "die", [dir])
	Net.fx("sfx", ["chitter", global_position, 0.0, 0.05, 0.6])
	Net.coins(global_position + Vector3(0, 0.4, 0), _rng.randi_range(3, 5) if big else _rng.randi_range(1, 2))
	Net.award_xp(120 if big else 25, global_position + Vector3(0, 1.2 * size_k, 0))
	died.emit(self)


func _dead_update(delta: float) -> void:
	_dead_t += delta
	# dead bugs end up legs-in-the-air: once it's down, roll it onto its back
	if _rag and _dead_t > 0.35 and _dead_t < 1.3:
		var rb := _rag.root_body()
		var cur_up := rb.global_basis.orthonormalized().y
		if cur_up.y > -0.85:
			var axis := cur_up.cross(Vector3.DOWN)
			if axis.length() < 0.2:
				axis = rb.global_basis.orthonormalized().z
			rb.angular_velocity = rb.angular_velocity.lerp(axis.normalized() * 7.0, minf(delta * 8.0, 1.0))
	if _dead_t > 3.2 and _sink == 0.0:
		_sink = 0.001
		if _rag:
			for p in _rag.parts:
				(p["body"] as RigidBody3D).freeze = true
		FX.dust(body_node.global_position, 6, 0.6 * size_k)
	if _sink > 0.0:
		_sink += delta / 0.7
		if _rag:
			_rag.set_process(false)
		var s := maxf(1.0 - _sink, 0.01)
		body_node.global_transform = Transform3D(body_node.global_basis.orthonormalized() * s * size_k,
			body_node.global_position + Vector3.DOWN * 0.25 * delta / 0.7)
		if _sink >= 1.0:
			if _rag:
				_rag.restore_rig()
				_rag.queue_free()
			queue_free()


func _exit_tree() -> void:
	if _rag and is_instance_valid(_rag):
		_rag.restore_rig()
		_rag.queue_free()


# ==========================================================================
# Animation: tripod gait, rear-up, ram, daze, flailing on its back, death curl
# ==========================================================================
func _process(delta: float) -> void:
	if net_puppet:
		_net_update(delta)
	_t += delta
	_shake = maxf(_shake - delta * 5.0, 0.0)
	var hspeed := _flat(velocity).length() if state != S.DOWN else 0.0
	var moving := clampf(hspeed / 0.6, 0.0, 1.0)
	var step_rate := 15.0 if state != S.RAM else 34.0
	_gait += clampf(hspeed, 0.0, 3.0) * step_rate * delta / maxf(size_k, 1.0)
	var rear_target := 1.0 if state == S.REAR else 0.0
	_rear = lerpf(_rear, rear_target, minf(delta * (9.0 if rear_target > _rear else 6.0), 1.0))

	var free := _rag == null and state != S.DEAD
	if free:
		# body pose on the rear pivot
		var pitch := _rear * 0.6
		var roll := 0.0
		var head_pitch := _rear * 0.35
		var head_yaw := 0.0
		if state == S.RAM:
			pitch = -0.1
			head_pitch = -0.15
		elif state in [S.DAZED, S.RECOVER]:
			roll = sin(_t * 6.0) * 0.13
			head_pitch = -0.25
			head_yaw = sin(_t * 3.5) * 0.4
		elif state == S.NOTICE:
			head_pitch = 0.25
		elif state == S.WANDER:
			head_yaw = sin(_t * 0.9) * 0.3
		if state == S.REAR:
			pitch += sin(_t * 40.0) * 0.02
		rear_pivot.rotation = Vector3(pitch, 0, roll)
		var bob := sin(_gait * 2.0) * 0.012 * moving
		var jit := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.025 * _shake
		var pose := Transform3D(Basis.IDENTITY, _body_rest.origin + Vector3(0, bob, 0) + jit)
		var head_pose := Transform3D(Basis.from_euler(Vector3(head_pitch, head_yaw, 0)), _head_rest.origin)
		if _settle_t < 1.0:
			_settle_t = minf(_settle_t + delta / 0.3, 1.0)
			var e := _settle_t * _settle_t * (3.0 - 2.0 * _settle_t)
			body_node.transform = _settle_from.interpolate_with(pose, e)
			head_node.transform = _head_from.interpolate_with(head_pose, e)
		else:
			body_node.transform = pose
			head_node.transform = head_pose

	# legs
	var upside := state == S.DOWN and _shell_up() < 0.4
	for leg in legs:
		var side: float = leg["side"]
		var idx: int = leg["idx"]
		var ph: float = _gait + (0.0 if leg["group"] == 0 else PI)
		var swing := sin(ph) * 0.42 * moving
		var lift := maxf(cos(ph), 0.0) * 0.4 * moving
		var bend := -lift * 0.5
		match state:
			S.REAR:
				if idx == 0:
					lift = 0.85 + sin(_t * 15.0 + side) * 0.3
					swing = 0.35 + sin(_t * 11.0 + side * 2.0) * 0.2
					bend = 0.4
				elif idx == 2:
					swing = sin(_t * 24.0 + side * 1.7) * 0.38
					lift = maxf(cos(_t * 24.0 + side * 1.7), 0.0) * 0.2
			S.DAZED, S.RECOVER:
				swing = sin(_t * 4.0 + float(leg["seed"])) * 0.15
				lift = 0.12 + sin(_t * 5.0 + float(leg["seed"])) * 0.06
				bend = 0.15
			S.HITSTUN:
				lift = 0.3
				bend = 0.3
			S.DOWN:
				var f := 1.0 if upside else 0.35
				swing = sin(_t * 17.0 + float(leg["seed"]) * 3.0) * 0.55 * f
				lift = 0.25 + sin(_t * 13.0 + float(leg["seed"]) * 2.0) * 0.45 * f
				bend = 0.3 + sin(_t * 9.0 + float(leg["seed"])) * 0.3 * f
			S.DEAD:
				var tw := maxf(0.0, 1.0 - _dead_t / 1.6)
				swing = sin(_t * 30.0 + float(leg["seed"]) * 4.0) * 0.25 * tw
				lift = lerpf(0.2, -0.75, minf(_dead_t / 0.8, 1.0))
				bend = lerpf(0.2, 1.1, minf(_dead_t / 0.8, 1.0)) + sin(_t * 25.0 + float(leg["seed"])) * 0.2 * tw
		var coxa: Node3D = leg["coxa"]
		var knee: Node3D = leg["knee"]
		coxa.rotation = Vector3(0.0, swing * side, lift * side)
		knee.rotation = Vector3(0.0, 0.0, -bend * side)


# ==========================================================================
# Co-op
# ==========================================================================
func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = max_hp * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


func net_pack() -> Array:
	return [global_position, model.rotation.y, velocity, int(state), health.current_health, health.max_health,
		hitbox.active, hitbox.activations, _rag.net_pack() if _rag else []]


func _net_update(delta: float) -> void:
	_net_hb_t -= delta
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	if a.size() < 9 or b.size() < 9:
		return
	if _rag and (b[8] as Array).size() > 0:
		_rag.net_follow(a[8], b[8], f)
	if state == S.DEAD:
		return
	var st := int(a[3])
	if st == S.DEAD:
		_net_die(model.global_basis.z)
		return
	global_position = (a[0] as Vector3).lerp(b[0], f)
	if _rag == null:
		model.rotation.y = lerp_angle(float(a[1]), float(b[1]), f)
		_yaw = model.rotation.y
	velocity = b[2]
	if st != state:
		if state == S.RAM:
			hitbox.deactivate()
		state = st as S
		st_t = 0.0
	health.max_health = float(b[5])
	health.current_health = float(b[4])
	var serial := int(a[7])
	if serial != _net_serial:
		var first := _net_serial < 0
		_net_serial = serial
		if not first:
			hitbox.activate()
			_net_hb_t = 0.15
	if hitbox.active and not bool(a[6]) and _net_hb_t <= 0.0:
		hitbox.deactivate()


func _net_die(dir: Vector3) -> void:
	if state == S.DEAD:
		return
	hitbox.deactivate()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	_col.set_deferred("disabled", true)
	collision_layer = 0
	if _rag == null:
		_make_ragdoll(dir * 4.0 / sqrt(size_k) + Vector3.UP * 4.2, Vector3.UP.cross(dir) * 10.0)
	else:
		_rag.push(dir * 3.0 + Vector3.UP * 3.0)
	state = S.DEAD
	st_t = 0.0
	_dead_t = 0.0
	died.emit(self)


func net_event(what: String, args: Array) -> void:
	match what:
		"flash":
			_flash_hit()
		"knock":
			hitbox.deactivate()
			_rear = 0.0
			_make_ragdoll(args[0], args[1])
			state = S.DOWN
			st_t = 0.0
		"getup":
			_get_up()
		"die":
			_net_die(args[0])
		"burn_fx":
			BurnStatus.apply(self, float(args[0]), 0.0, null)
