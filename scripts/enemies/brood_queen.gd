class_name BroodQueen
extends Scuttlebug
## The brood queen: a scuttlebug the size of a rowboat, nesting in the cave
## under the deep forest (BroodCave). She sleeps on her eggs until a captain
## walks in, then:
##   * rams like her children, and the ram knocks you flat (parry it and she's
##     left reeling);
##   * rears up and sprays a fan of venom blobs (they poison);
##   * rears high and slams the ground: a red ring shows where (jump or dodge);
##   * shrieks, and her brood crawls out of the egg sacs.
## Blows don't throw her; enough of them in a short while stagger her, wide
## open. Below half health she roars, moves faster, sprays wider and calls
## the brood again. Co-op: host-run; the slam is judged on every screen.

const SIZE := 4.2
const HP := 1100.0
const POISE := 150.0
const SLAM_R := 5.5

var cave: Node
var phase: int = 1
var _special: String = ""
var _volley_cd: float = 3.0
var _slam_cd: float = 6.0
var _brood_cd: float = 8.0
var _poise: float = 0.0
var _fired: int = 0
var _slam_at := Vector3.ZERO
var _qrear: float = 0.0


## Call before adding to the tree.
func queen(home_pos: Vector3) -> BroodQueen:
	setup(true, home_pos)
	size_k = SIZE
	max_hp = HP
	return self


func _colors() -> Array:
	return [Color(0.3, 0.1, 0.24), Color(0.55, 0.95, 0.25), Color(0.2, 0.07, 0.16), Color(0.1, 0.06, 0.08), Color(0.7, 1.0, 0.3)]


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	hitbox.hit_data.damage = 26.0
	hitbox.hit_data.knockback_force = 8.0
	hitbox.hit_data.camera_shake_intensity = 0.35
	# asleep on her eggs, facing the cave mouth
	_face(Vector3.RIGHT)
	model.rotation.y = _yaw


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


## A captain walked into the cave.
func wake() -> void:
	if state != S.WANDER:
		return
	_set_state(S.NOTICE)
	Net.fx("sfx", ["roar", global_position, 2.0, 0.05, 1.5])
	Net.fx("dust_ring", [global_position, 16, 1.4])


## Everyone left: back onto her eggs, healed.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	_special = ""
	hitbox.deactivate()
	health.heal(health.max_health)
	phase = 1
	_poise = 0.0
	global_position = home + Vector3.UP * 0.3
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_set_state(S.WANDER)


func _ram_speed() -> float:
	return 12.0 if phase == 1 else 14.0


func _physics_process(delta: float) -> void:
	if net_puppet or state in [S.REAR, S.RAM, S.RECOVER, S.DAZED, S.HITSTUN, S.DOWN, S.DEAD]:
		super._physics_process(delta)
		return
	st_t += delta
	_cooldown -= delta
	_volley_cd -= delta
	_slam_cd -= delta
	_brood_cd -= delta
	_poise = maxf(_poise - 25.0 * delta, 0.0)
	var p := _target()
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var want := Vector3.ZERO
	var turn := 5.0
	match state:
		S.WANDER:
			pass
		S.NOTICE:
			_face(to_p)
			_shake = 1.0
			if st_t > 1.2:
				_set_state(S.APPROACH)
		S.APPROACH:
			_face(to_p)
			turn = 4.0 if phase == 1 else 5.5
			var speed := 3.0 if phase == 1 else 3.9
			if phase == 1 and health_frac() < 0.5:
				_begin("roar")
			elif _brood_cd <= 0.0 and cave and cave.call("brood_alive") < 2:
				_begin("brood")
			elif _slam_cd <= 0.0 and dist < SLAM_R + 1.0:
				_begin("slam")
			elif _volley_cd <= 0.0 and dist > 5.0 and dist < 18.0:
				_begin("volley")
			elif _cooldown <= 0.0 and dist > 4.0 and dist < 8.5:
				_set_state(S.REAR)
				Net.fx("sfx", ["bug_hiss", global_position, 2.0, 0.05, 0.55])
			elif dist > 4.5:
				want = to_p.normalized() * speed
			elif dist < 3.2:
				want = -to_p.normalized() * 1.5
		S.SPECIAL:
			_special_tick(p, to_p, dist)
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var hv := _flat(velocity).move_toward(want, 10.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(turn * delta, 1.0))


func _begin(what: String) -> void:
	_special = what
	_fired = 0
	_set_state(S.SPECIAL)
	Net.event(self, "special", [what])
	match what:
		"roar":
			phase = 2
			Net.fx("sfx", ["roar", global_position, 3.0, 0.05, 1.35])
		"brood":
			Net.fx("sfx", ["chitter", global_position, 3.0, 0.05, 0.5])
		"volley":
			Net.fx("sfx", ["bug_hiss", global_position, 2.0, 0.05, 0.6])
		"slam":
			_slam_at = global_position - model.global_basis.z * 2.6
			_slam_at.y = global_position.y
			Net.fx("telegraph", [_slam_at, SLAM_R, 1.0])


func _special_tick(p: Node3D, to_p: Vector3, dist: float) -> void:
	match _special:
		"roar":
			_shake = 1.0
			if _fired == 0 and st_t > 0.3:
				_fired = 1
				Net.fx("dust_ring", [global_position, 24, 1.8])
				get_node("/root/CombatManager").apply_camera_shake(0.3)
			if st_t > 1.3:
				_brood_cd = 0.0
				_end_special(0.5)
		"brood":
			_shake = 1.0
			if _fired == 0 and st_t > 0.7:
				_fired = 1
				if cave:
					cave.call("call_brood")
			if st_t > 1.4:
				_brood_cd = 24.0 if phase == 1 else 16.0
				_end_special(0.6)
		"volley":
			if st_t < 0.7:
				_face(to_p)
			if _fired == 0 and st_t > 0.8 and p:
				_fired = 1
				_volley(p, dist)
			if st_t > 1.5:
				_volley_cd = 6.0 if phase == 1 else 4.5
				_end_special(0.4)
		"slam":
			if _fired == 0 and st_t > 1.0:
				_fired = 1
				_aoe(_slam_at, SLAM_R, 24.0)
				Net.fx("dust_ring", [_slam_at, 24, 1.6])
				Net.fx("dust", [_slam_at, 10, 1.2])
				Net.fx("sfx", ["thud", _slam_at, 4.0, 0.05, 0.6])
				get_node("/root/CombatManager").apply_camera_shake(0.45)
			if st_t > 1.7:
				_slam_cd = 8.0 if phase == 1 else 6.0
				_end_special(0.6)


func _end_special(rest: float) -> void:
	_special = ""
	_cooldown = rest
	_set_state(S.APPROACH)


## A fan of venom blobs at the captain (wider in the second phase).
func _volley(p: Node3D, dist: float) -> void:
	var from := head_node.global_position + Vector3.UP * 0.3
	var n := 5 if phase == 1 else 7
	var spread := deg_to_rad(14.0)
	var tgt := p.global_position + Vector3(0, 1.0, 0)
	var t := clampf(dist / 11.0, 0.5, 1.3)
	for i in range(n):
		var off := (i - (n - 1) * 0.5) * spread
		var d := (tgt - from)
		var flat := Vector3(d.x, 0, d.z).rotated(Vector3.UP, off)
		var vel := Vector3(flat.x, d.y, flat.z) / t + Vector3(0, 0.5 * PoisonGlob.GRAVITY * t, 0)
		Net.fx("spit", [from, vel, 10.0, 1.6, 5.0, 4.0])


## The slam's ring: every machine checks its own captain (jump it or dodge).
func _aoe(center: Vector3, radius: float, dmg: float) -> void:
	_aoe_local(center, radius, dmg)
	Net.event(self, "aoe", [center, radius, dmg])


func _aoe_local(center: Vector3, radius: float, dmg: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	if _flat(me.global_position - center).length() > radius or me.global_position.y > center.y + 1.0:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = true
	hd.unblockable = true
	hd.knockback_force = 8.0
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.06
	hd.camera_shake_intensity = 0.25
	hb.take_hit(hd, self)


# --------------------------------------------------------------------------
# Getting hit: no flinching or throws, but a stagger once enough lands
# --------------------------------------------------------------------------
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	if hit.dot:
		_number(hit.damage)
		health.take_damage(hit.damage)
		return
	var dir := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else model.global_basis.z
	_flash_hit()
	Net.event(self, "flash", [])
	_number(hit.damage)
	Net.fx("impact", [global_position + Vector3(0, 0.45 * size_k, 0) - dir * 0.8, Color(0.75, 1.0, 0.55)])
	Net.fx("sfx", ["hit", global_position, -1.0, 0.1, 0.8])
	if not Net.active or attacker == Net.local_player:
		get_node("/root/CombatManager").apply_hit_effects(hit, [attacker])
	health.take_damage(hit.damage)
	if state == S.DEAD:
		return
	if state == S.WANDER:
		wake()
	_poise += hit.damage * (1.6 if hit.knockdown else 1.0)
	if _poise >= POISE and state != S.DAZED:
		_stagger(2.2)


func _stagger(secs: float) -> void:
	_poise = 0.0
	_special = ""
	hitbox.deactivate()
	_daze_len = secs
	velocity = Vector3.ZERO
	_set_state(S.DAZED)
	Net.fx("sparkle", [global_position + Vector3(0, 1.2 * size_k, 0), 16, Color(1.0, 0.95, 0.55)])
	Net.fx("sfx", ["chitter", global_position, 2.0, 0.05, 0.7])


## The ram parried: reeling.
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if state == S.RAM:
		_stagger(2.4)


func rooted(secs: float) -> void:
	super.rooted(minf(secs, 1.0))


func grabbed(_secs: float) -> void:
	pass


func _on_died() -> void:
	if state == S.DEAD:
		return
	super._on_died()
	Net.coins(global_position + Vector3(0, 1.0, 0), 25)
	Net.award_xp(600, global_position + Vector3(0, 2.0 * size_k, 0))


func _process(delta: float) -> void:
	super._process(delta)
	if net_puppet:
		st_t += delta
	if _rag != null or state == S.DEAD:
		return
	var target := 0.0
	if state == S.SPECIAL:
		match _special:
			"volley":
				target = 1.0
			"slam":
				target = 1.5 if st_t < 0.95 else -0.25
			"brood", "roar":
				target = 0.6
	elif state == S.REAR:
		target = 1.0
	_qrear = lerpf(_qrear, target, minf(delta * (14.0 if target < _qrear else 7.0), 1.0))
	rear_pivot.rotation.x = _qrear * 0.55 + (sin(_t * 40.0) * 0.02 if _shake > 0.0 else 0.0)
	head_node.rotation.x = _qrear * 0.3


func net_event(what: String, args: Array) -> void:
	match what:
		"special":
			_special = str(args[0])
			st_t = 0.0
		"aoe":
			_aoe_local(args[0], float(args[1]), float(args[2]))
		_:
			super.net_event(what, args)
