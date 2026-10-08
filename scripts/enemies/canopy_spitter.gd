class_name CanopySpitter
extends Scuttlebug
## Spitter: a small venomous bug that hangs hidden in the deep forest's canopy.
## Walk under its tree and it drops on a silk thread; dangling at head height
## it spits arcing blobs of venom (they poison). Hit it and the thread snaps:
## it falls and fights on the ground like a small scuttlebug, and once it's
## lost you it walks back under its tree and climbs the thread up again.

const DROP_RANGE := 8.0
const DANGLE_Y := 2.6
const SPIT_EVERY := 1.9
const SPIT_WIND := 0.5
const LOSE_RANGE := 18.0
const SPIT_DAMAGE := 6.0

## Where its thread hangs from, in the crown (world).
var anchor := Vector3.ZERO
var _ground_y: float = 0.0
var _spit_cd: float = 1.0
var _winding := false
var _far_t: float = 0.0
var _thread: MeshInstance3D

static var _thread_mat: StandardMaterial3D


## Call before adding to the tree.
func roost(anchor_pos: Vector3, ground_pos: Vector3) -> CanopySpitter:
	setup(false, ground_pos)
	anchor = anchor_pos
	_ground_y = ground_pos.y
	size_k = 0.8
	max_hp = 24.0
	return self


func _colors() -> Array:
	return [Color(0.32, 0.16, 0.42), Color(0.55, 0.95, 0.25), Color(0.2, 0.1, 0.3), Color(0.12, 0.08, 0.12), Color(0.6, 1.0, 0.3)]


func _ready() -> void:
	super._ready()
	state = S.HIDE
	if _thread_mat == null:
		_thread_mat = StandardMaterial3D.new()
		_thread_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_thread_mat.albedo_color = Color(0.92, 0.95, 0.9, 0.7)
		_thread_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 1.0, 0.02)
	bm.material = _thread_mat
	_thread = MeshInstance3D.new()
	_thread.name = "Thread"
	_thread.mesh = bm
	_thread.top_level = true
	_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thread.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_thread.visible = false
	add_child(_thread)


func in_combat() -> bool:
	return state not in [S.WANDER, S.DEAD, S.HIDE]


func _aloft() -> bool:
	return state in [S.HIDE, S.DROP, S.DANGLE, S.CLIMB]


func _physics_process(delta: float) -> void:
	if net_puppet or not (_aloft() or state in [S.FALL, S.WANDER]):
		super._physics_process(delta)
		return
	if state == S.WANDER:
		_wander_home()
		super._physics_process(delta)
		return
	st_t += delta
	if state == S.FALL:
		velocity.y -= GRAVITY * delta
		velocity.x *= 0.96
		velocity.z *= 0.96
		move_and_slide()
		if is_on_floor() and st_t > 0.1:
			Net.fx("dust", [global_position, 5, 0.4])
			Net.fx("sfx", ["thud", global_position, -6.0, 0.1, 1.4])
			_daze_len = 1.1
			_set_state(S.DAZED)
		return
	var p := _target()
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	velocity = Vector3.ZERO
	match state:
		S.HIDE:
			global_position = anchor
			var under := _flat(p.global_position - anchor).length() if p else INF
			if _player_ok(p) and under < DROP_RANGE and p.global_position.y < anchor.y - 1.5:
				_set_state(S.DROP)
				_far_t = 0.0
				Net.fx("sfx", ["chitter", global_position, -2.0, 0.1, 1.4])
		S.DROP:
			_face(to_p)
			global_position = Vector3(anchor.x, move_toward(global_position.y, _ground_y + DANGLE_Y, 9.0 * delta), anchor.z)
			if global_position.y <= _ground_y + DANGLE_Y + 0.01:
				_set_state(S.DANGLE)
				_spit_cd = 0.5
				_winding = false
		S.DANGLE:
			_face(to_p)
			global_position = Vector3(anchor.x + sin(_t * 1.3) * 0.15, _ground_y + DANGLE_Y + sin(_t * 2.1) * 0.12, anchor.z + cos(_t * 1.1) * 0.15)
			var in_reach := _player_ok(p) and dist < LOSE_RANGE
			_far_t = 0.0 if in_reach else _far_t + delta
			if _far_t > 4.0:
				_set_state(S.CLIMB)
			_spit_cd -= delta
			if not _winding and _spit_cd <= 0.0 and in_reach:
				_winding = true
				_spit_cd = SPIT_WIND
				_shake = 1.0
				Net.fx("sfx", ["bug_hiss", global_position, -3.0, 0.08, 1.35])
			elif _winding and _spit_cd <= 0.0:
				_winding = false
				_spit_cd = SPIT_EVERY + _rng.randf_range(-0.3, 0.4)
				if in_reach:
					_spit(p)
		S.CLIMB:
			global_position = Vector3(anchor.x, move_toward(global_position.y, anchor.y, 4.0 * delta), anchor.z)
			if global_position.y >= anchor.y - 0.01:
				health.heal(health.max_health)
				_set_state(S.HIDE)
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(10.0 * delta, 1.0))


## Gave up on the ground: back under its tree, then up the thread.
func _wander_home() -> void:
	if st_t < 2.5:
		return
	if _flat(home - global_position).length() < 0.8:
		global_position = Vector3(anchor.x, global_position.y, anchor.z)
		_set_state(S.CLIMB)
		return
	_wander_target = home
	_wander_wait = 0.0


func _spit(p: Node3D) -> void:
	var from := head_node.global_position
	var tgt := p.global_position + Vector3(0, 1.1, 0) + _flat((p as CharacterBody3D).velocity if p is CharacterBody3D else Vector3.ZERO) * 0.25
	var t := clampf(from.distance_to(tgt) / 10.0, 0.45, 1.1)
	var vel := (tgt - from) / t + Vector3(0, 0.5 * PoisonGlob.GRAVITY * t, 0)
	Net.fx("spit", [from, vel, SPIT_DAMAGE, 1.0, 4.0, 3.0])


func _on_hit(hit: HitData, attacker: Node) -> void:
	var was_aloft := _aloft()
	super._on_hit(hit, attacker)
	# the thread snaps: down it comes
	if was_aloft and state in [S.HITSTUN, S.DAZED]:
		velocity = _stun_vel * 0.5
		_set_state(S.FALL)
		Net.fx("sfx", ["chitter", global_position, -2.0, 0.1, 1.5])


func _process(delta: float) -> void:
	super._process(delta)
	var pitch := 0.0
	match state:
		S.HIDE:
			pitch = -1.35
		S.DROP, S.CLIMB:
			pitch = -1.2
		S.DANGLE:
			pitch = -0.75 - (0.25 if _winding else 0.0)
	model.rotation.x = lerpf(model.rotation.x, pitch, minf(8.0 * delta, 1.0))
	var hanging := state in [S.DROP, S.DANGLE, S.CLIMB]
	_thread.visible = hanging
	if hanging:
		var bottom := global_position + Vector3(0, 0.25 * size_k, 0)
		var len := maxf(anchor.y - bottom.y, 0.05)
		_thread.global_transform = Transform3D(Basis().scaled(Vector3(1, len, 1)), Vector3(bottom.x, bottom.y + len * 0.5, bottom.z))
