class_name Creature
extends CharacterBody3D
## The jungle's wildlife below the bosses (scripts/enemies/fauna/): what every
## creature shares. Its model is parts on pivots, each part a mesh made once per
## kind and shared (one skin material, the colours in the vertices). It thinks in
## _brain() and poses itself in _pose(); getting hit, hitstun, being knocked
## over, dying, the rewards, the distance LOD and co-op live here.
## FaunaSpawner puts them on the islands and sets their LOD.

signal died(c: Creature)

enum S { IDLE, WANDER, NOTICE, CHASE, TELL, ATTACK, RECOVER, FLEE, HITSTUN, DOWN, DEAD, HIDE, FLY, PERCH, SPECIAL }

const GRAVITY := 20.0
## By the distance to the nearest captain: full, posed every third frame, asleep (frozen), hidden.
enum { LOD_FULL, LOD_LOW, LOD_SLEEP, LOD_HIDDEN }
const LOD_RANGE := [30.0, 70.0, 110.0]

var kind := "creature"
## The island's level (Levels); 0: unscaled.
var level: int = 0
## A respawned creature is worth half the experience.
var xp_k: float = 1.0
var home := Vector3.ZERO
var size_k: float = 1.0
var max_hp: float = 30.0
var xp: int = 20
var coins := Vector2i(1, 2)
## [[item id, chance, count], ...] rolled on death.
var drops: Array = []
## Picks fights (false: minds its own business until hurt).
var hostile := true
## A bite that lands poisons: [seconds, damage a second] (empty: none).
var venom: Array = []
## Rolls onto its back when knocked over (shells), rather than its side.
var flips := false
## Flies: moves itself (no gravity, no floor) until it's knocked down or killed.
var flying := false
## For renders: built and posed, nothing else.
var preview := false
## The skin's texture ("" plain): its grain under the vertex colours.
var skin_tex := ""

var state: S = S.IDLE
var st_t: float = 0.0
var lod: int = LOD_FULL
var net_puppet := false

var model: Node3D
var health: HealthComponent
var hurtbox: Hurtbox
var hitbox: Hitbox

var _col: CollisionShape3D
var _parts: Array[MeshInstance3D] = []
var _hit_mat: ShaderMaterial
var _flash: Tween
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _yaw: float = 0.0
var _want := Vector3.ZERO
var _accel: float = 14.0
var _turn: float = 8.0
var _cool: float = 0.0
var _still: float = 0.0
var _stun_vel := Vector3.ZERO
var _stun_len: float = 0.22
var _daze_len: float = 1.0
var _roll: float = 0.0
var _roll_to: float = 0.0
var _rise: float = 1.0
var _down_len: float = 1.2
var _dead_t: float = 0.0
var _sink: float = 0.0
var _wander_to := Vector3.ZERO
var _wander_wait: float = 0.0
var _stuck: float = 0.0
var _t: float = 0.0
var _pose_dt: float = 0.0
var _frame: int = 0
var _yank: float = 0.0
var _yank_v := Vector3.ZERO
## Pose values a puppet copies from the host (what they mean is the creature's).
var anim_a: float = 0.0
var anim_b: float = 0.0
var strike_id: int = 0
var _net_serial: int = -1
var _net_hb_t: float = 0.0
var _parried_t: float = 0.0
var _damage_number_scene: PackedScene

static var _meshes := {}


## Not moving and not about to (the spawner's LOD skips it for snapshots).
var net_idle: bool:
	get:
		return lod >= LOD_SLEEP


func is_dead() -> bool:
	return state == S.DEAD


func in_combat() -> bool:
	return hostile and state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK, S.RECOVER, S.HITSTUN]


## A creature's spot: home, and whatever else it takes (subclasses read `args`). Before the tree.
func setup(home_pos: Vector3, args: Dictionary = {}) -> Creature:
	home = home_pos
	_setup(args)
	return self


func _setup(_args: Dictionary) -> void:
	pass


## One for a render (modelshot): `Creature.sample(Boar, {"tusker": true})`.
static func sample(cls: GDScript, args: Dictionary = {}) -> Creature:
	var c: Creature = cls.new()
	c.preview = true
	c.setup(Vector3.ZERO, args)
	return c


func _ready() -> void:
	_rng.seed = hash([kind, seed_v(), name])
	add_to_group("enemies")
	add_to_group("fauna")
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
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * size_k
	add_child(model)
	_build()
	_build_physics()
	_yaw = _rng.randf() * TAU
	model.rotation.y = _yaw
	_wander_to = home
	_wander_wait = _rng.randf_range(0.5, 3.0)
	_frame = _rng.randi() % 3
	if preview:
		set_physics_process(false)
		return
	if Net.hosting:
		net_rescale(Net.hp_scale())
	_start()


## (a deterministic seed for the creature's own stream: its spot's)
func seed_v() -> int:
	return int(home.x * 7.0 + home.z * 13.0)


## Make the model: parts on pivots under `model` (faces -Z, origin on the ground).
func _build() -> void:
	pass


## Called once it's in the tree (the first state).
func _start() -> void:
	_set_state(S.WANDER)


## The collider and the hurtbox, in model space (they scale with the creature).
func _body_shape() -> Array:
	return [0.3, 0.5, Vector3(0.6, 0.6, 0.9)]


func _build_physics() -> void:
	var dims := _body_shape()
	var r: float = dims[0] * size_k
	var h: float = dims[1] * size_k
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(h, r * 2.0)
	_col.shape = cap
	_col.position = Vector3(0, maxf(h, r * 2.0) * 0.5, 0)
	add_child(_col)
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = _max_hp()
	add_child(health)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 16
	var hs := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = dims[2]
	hs.shape = hbox
	hs.position = Vector3(0, (dims[2] as Vector3).y * 0.5, 0)
	hurtbox.add_child(hs)
	model.add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)
	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 64
	hitbox.collision_mask = 128
	var hcs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(0.7, 0.7, 0.7)
	hcs.shape = hb
	hcs.position = Vector3(0, 0.4, -0.5)
	hitbox.add_child(hcs)
	model.add_child(hitbox)
	hitbox.owner = self
	hitbox.hit_data = HitData.new()
	hitbox.hit_landed.connect(_landed)


# ==========================================================================
# Model helpers
# ==========================================================================
## The kind's skin: one lit material (`skin_tex`), the colours in the vertices.
func _skin() -> ShaderMaterial:
	return PSXMat.lit(skin_tex, Color.WHITE, {"affine": 0.4})


## Eyes and the like: a glow (its own surface).
func _glow(c: Color) -> ShaderMaterial:
	return PSXMat.glow(c, 1.4)


## A part's mesh, made once per kind and `key` (fn(mb, rng) fills it).
func _mesh(key: String, fn: Callable) -> ArrayMesh:
	var k := kind + ":" + key
	if not _meshes.has(k):
		var mb := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(k)
		fn.call(mb, rng)
		_meshes[k] = mb.commit()
	return _meshes[k]


## A pivot under `parent` at `at`, with the cached mesh `key` on it (no fn: a bare pivot).
func _part(parent: Node3D, pname: String, at: Vector3, key: String = "", fn: Callable = Callable(), shadow: bool = false) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pname
	pivot.position = at
	parent.add_child(pivot)
	if fn.is_valid():
		var mi := MeshInstance3D.new()
		mi.name = "M"
		mi.mesh = _mesh(key, fn)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = LOD_RANGE[2] + 10.0
		pivot.add_child(mi)
		_parts.append(mi)
	return pivot


## A box from a to b (a leg or a limb segment).
static func seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, t: float, col: Color = Color.WHITE) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
	mb.add_box(mat, Transform3D(basis, (a + b) * 0.5), Vector3(t, t, d.length() + t * 0.5), 1.0, col, false, false)


# ==========================================================================
# Senses
# ==========================================================================
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


## A fair target: alive, on foot, not knocked down.
func _player_ok(p: Node3D) -> bool:
	if p == null:
		return false
	if p.has_method("current_state_name") and str(p.call("current_state_name")) in ["Downed", "Helm"]:
		return false
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		_yaw = atan2(-dir.x, -dir.z)


func _fwd() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0.0, -cos(model.rotation.y))


func _night() -> float:
	return float(Weather.night)


# ==========================================================================
# The loop
# ==========================================================================
## (a blow never outlives the state that threw it: strike after setting the state)
func _set_state(s: S) -> void:
	if hitbox.active:
		hitbox.deactivate()
	state = s
	st_t = 0.0


func _physics_process(delta: float) -> void:
	if net_puppet:
		if state == S.DEAD:
			_dead_update(delta)
		return
	st_t += delta
	_cool -= delta
	_parried_t -= delta
	if state == S.DEAD:
		_dead_update(delta)
		return
	if state == S.DOWN:
		_down_update(delta)
		return
	_want = Vector3.ZERO
	_accel = 14.0
	_turn = 8.0
	_tick(delta)
	match state:
		S.HITSTUN:
			_want = _stun_vel * maxf(0.0, 1.0 - st_t / _stun_len)
			_accel = 40.0
			if st_t > _stun_len:
				_after_stun()
		S.RECOVER:
			if st_t > _daze_len:
				_after_daze()
		_:
			_brain(delta)
	if flying and state not in [S.HITSTUN, S.RECOVER]:
		_fly(delta)
	else:
		_walk(delta)
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(_turn * delta, 1.0))


## The creature's own thinking: set _want (flat velocity), _accel, _turn, _face(), states.
func _brain(_delta: float) -> void:
	_wander(1.2)


## Every tick, whatever the state (on its feet): easing its pose values.
func _tick(_delta: float) -> void:
	pass


## Flying creatures move themselves here (no floor, no gravity).
func _fly(_delta: float) -> void:
	pass


func _after_stun() -> void:
	_set_state(S.CHASE if hostile else S.FLEE)


func _after_daze() -> void:
	_cool = maxf(_cool, 0.6)
	_set_state(S.CHASE if hostile else S.FLEE)


func _walk(delta: float) -> void:
	var hv := flat(velocity).move_toward(_want, _accel * delta)
	if _yank > 0.0:
		_yank -= delta
		hv = _yank_v
		if _yank <= 0.0:
			hv *= 0.15
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	velocity.x = hv.x
	velocity.z = hv.z
	# standing still on the ground: no need to slide (most of the jungle, most of the time)
	if hv.length_squared() < 0.0004 and _want == Vector3.ZERO and is_on_floor():
		_still += delta
		if _still > 0.4:
			return
	else:
		_still = 0.0
	move_and_slide()


## Potter about home: walk to a spot, wait, pick another.
func _wander(speed: float, reach: Vector2 = Vector2(1.5, 6.0)) -> void:
	if _wander_wait > 0.0:
		_wander_wait -= get_physics_process_delta_time()
		if _wander_wait <= 0.0:
			_pick_wander(reach)
		return
	var d := flat(_wander_to - global_position)
	if d.length() < 0.5:
		_wander_wait = _rng.randf_range(1.0, 3.5)
		return
	_face(d)
	_want = d.normalized() * speed
	if get_real_velocity().length() < 0.15 and st_t > 0.5:
		_stuck += get_physics_process_delta_time()
		if _stuck > 0.8:
			_stuck = 0.0
			_pick_wander(reach)
	else:
		_stuck = 0.0


func _pick_wander(reach: Vector2) -> void:
	var a := _rng.randf() * TAU
	_wander_to = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(reach.x, reach.y)


## Away from `from` (flat), toward home if it's strayed far.
func _flee_dir(from: Vector3) -> Vector3:
	var away := flat(global_position - from).normalized()
	var back := flat(home - global_position)
	if back.length() > 18.0:
		away = (away + back.normalized() * 0.7).normalized()
	return away


# ==========================================================================
# Attacks
# ==========================================================================
## The creature's blows: [damage, knockback, box size, box centre (model space), knockdown, stagger].
func _moves() -> Array:
	return [[8.0, 4.0, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.4, -0.5), false, 0.3]]


## Arm the hitbox with blow `i` (puppets arm the same one from the snapshot).
func _arm(i: int) -> void:
	strike_id = i
	var m: Array = _moves()[i]
	var hd := HitData.new()
	hd.damage = _dmg(float(m[0]))
	hd.knockback_force = float(m[1])
	hd.knockdown = bool(m[4])
	hd.stagger_duration = float(m[5])
	hd.hitstop_duration = 0.06 if hd.knockdown else 0.04
	hd.camera_shake_intensity = 0.25 if hd.knockdown else 0.12
	hitbox.hit_data = hd
	var cs := hitbox.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = m[2]
	cs.position = m[3]


func _strike(i: int) -> void:
	_arm(i)
	hitbox.activate()


## A hit of ours landed on a captain (on that captain's machine).
func _landed(target: Node, _data: HitData) -> void:
	if venom.is_empty() or not (target is Player) or not (target as Player).is_local or _parried_t > 0.0:
		return
	# (only a bite that hurt poisons: not one dodged, blocked or parried)
	if float(target.get("_since_hit")) == 0.0:
		PoisonStatus.apply(target as Node3D, float(venom[0]), float(venom[1]), null)


func _max_hp() -> float:
	return max_hp * Levels.hp_k(level)


func _dmg(base: float) -> float:
	return base * Levels.dmg_k(level)


# ==========================================================================
# Getting hit
# ==========================================================================
## How much of a blow gets through (shells, a ball rolled up).
func _armor(_hit: HitData, _dir: Vector3) -> float:
	return 1.0


## The creature's own answer to a blow (true: handled, skip the flinch).
func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	return false


func _can_knock() -> bool:
	return true


func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD or preview:
		return
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = flat(global_position - (attacker as Node3D).global_position)
	dir = dir.normalized() if dir.length() > 0.01 else -_fwd()
	if hit.dot:
		_number(hit.damage)
		health.take_damage(hit.damage)
		return
	var k := _armor(hit, dir)
	var dmg := hit.damage * k
	_flash_hit(k < 0.6)
	Net.event(self, "flash", [k < 0.6])
	_number(dmg)
	var at := global_position + Vector3(0, 0.45 * size_k, 0) - dir * 0.3 * size_k
	if k < 0.6:
		Net.fx("sparkle", [at, 6, Color(1.0, 0.9, 0.6)])
		Net.fx("sfx", ["block", global_position, -4.0, 0.1, 1.3])
	else:
		Net.fx("impact", [at, Color(1.0, 0.85, 0.55)])
		CombatManager.impact(hit, global_position, -2.0, 0.1, 1.15 if dmg < 20.0 else 0.9)
	if not Net.active or attacker == Net.local_player:
		get_node("/root/CombatManager").apply_hit_effects(hit, [attacker])
	health.take_damage(dmg)
	if state == S.DEAD:
		return
	if _hurt(hit, attacker, dir):
		return
	if state == S.DOWN:
		velocity += dir * minf(hit.knockback_force, 6.0) * 0.5 + Vector3.UP * 2.0
		return
	if hit.knockdown and _can_knock():
		knock(dir * clampf(hit.knockback_force * 0.7, 3.5, 8.0) / sqrt(size_k) + Vector3.UP * 4.0)
		return
	_stun_len = 0.18 + 0.06 / size_k
	_stun_vel = dir * minf(hit.knockback_force * 0.6, 5.0) / size_k
	velocity = _stun_vel + Vector3.UP * (1.5 if flying else 0.0)
	_set_state(S.HITSTUN)


## A captain parried its blow: thrown off its feet (or out of the air).
func parried(by: Node) -> void:
	_parried_t = 0.5
	if Net.forward(self, "parried", [by]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	var dir := -_fwd()
	if by is Node3D:
		dir = flat(global_position - (by as Node3D).global_position).normalized()
	knock(dir * 3.5 + Vector3.UP * 4.5)


## Thrown tumbling along `v` (Cannonball Swing).
func launched(v: Vector3) -> void:
	if Net.forward(self, "launched", [v]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	knock(v)


## Bowled over: tumbles, lies a moment kicking, gets back up.
func knock(v: Vector3) -> void:
	if state == S.DEAD:
		return
	Net.event(self, "knock", [v])
	hitbox.deactivate()
	velocity = v
	_roll_to = PI * (0.97 if flips else 0.5) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_rise = 1.0
	_down_len = _rng.randf_range(1.0, 1.6)
	_set_state(S.DOWN)
	_knocked()


## (a flyer that's knocked down falls like anything else)
func _knocked() -> void:
	pass


func _down_update(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()
	if _rise >= 1.0:
		_roll = move_toward(_roll, _roll_to, 9.0 * delta)
		if st_t > 0.3 and st_t > _down_len and is_on_floor():
			_rise = 0.0
			Net.event(self, "getup", [])
			Net.fx("dust", [global_position, 4, 0.5 * size_k])
	else:
		_rise = minf(_rise + delta / 0.35, 1.0)
		_roll = lerpf(_roll_to, 0.0, _rise * _rise * (3.0 - 2.0 * _rise))
		if _rise >= 1.0:
			_roll = 0.0
			_got_up()


func _got_up() -> void:
	flying = false
	_daze_len = 0.6
	_set_state(S.RECOVER)


## Vine grapple: small creatures get reeled in, big ones haul the player over.
func vine_weight() -> String:
	return "heavy" if size_k > 1.3 else "light"


func vine_yank(to: Vector3, dmg: float = 4.0, wrap: bool = true) -> void:
	if Net.forward(self, "vine_yank", [to, dmg, wrap]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	var d := flat(to - global_position)
	var dist := maxf(d.length() - 1.3, 0.0)
	var secs := clampf(dist / 16.0, 0.12, 0.6)
	_yank = secs
	_yank_v = d.normalized() * (dist / secs) if d.length() > 0.01 else Vector3.ZERO
	velocity.y = 3.0
	flying = false
	_daze_len = secs + 0.8
	_set_state(S.RECOVER)
	health.take_damage(dmg)
	_number(dmg)
	if wrap:
		Net.fx("vine_wrap", [self, secs + 0.3, 0.45 * size_k])


func rooted(secs: float) -> void:
	if Net.forward(self, "rooted", [secs]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	_daze_len = secs
	velocity = Vector3.ZERO
	_set_state(S.RECOVER)
	Net.fx("vine_wrap", [self, secs, 0.45 * size_k])


func grabbed(secs: float) -> void:
	if Net.forward(self, "grabbed", [secs]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	_daze_len = secs
	velocity = Vector3.ZERO
	_set_state(S.RECOVER)


func _number(dmg: float) -> void:
	Net.damage_number(dmg, global_position + Vector3(0, 0.7 * size_k, 0))


func _set_tint(c: Color) -> void:
	_hit_mat.set_shader_parameter("tint_mul", c)


func _flash_hit(armored: bool = false) -> void:
	if _hit_mat == null:
		_hit_mat = _skin().duplicate() as ShaderMaterial
	for mi in _parts:
		mi.material_override = _hit_mat
	if _flash:
		_flash.kill()
	var c := Color(1.6, 1.5, 1.2) if armored else Color(2.2, 0.8, 0.7)
	_set_tint(c)
	_flash = create_tween()
	_flash.tween_method(_set_tint, c, Color.WHITE, 0.18)
	_flash.tween_callback(func():
		for mi in _parts:
			mi.material_override = null)


# ==========================================================================
# Death and rewards
# ==========================================================================
func _on_died() -> void:
	if state == S.DEAD:
		return
	var p := _target()
	var dir := flat(global_position - p.global_position).normalized() if p else -_fwd()
	_die(dir)
	Net.event(self, "die", [dir])
	_cry_death()
	_reward()
	died.emit(self)


func _die(dir: Vector3) -> void:
	hitbox.deactivate()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	flying = false
	velocity = dir * 3.0 / sqrt(size_k) + Vector3.UP * 3.5
	_roll_to = PI * (0.97 if flips else 0.5) * (1.0 if _rng.randf() < 0.5 else -1.0)
	state = S.DEAD
	st_t = 0.0
	_dead_t = 0.0
	set_physics_process(true)
	set_process(true)
	model.visible = true


func _cry_death() -> void:
	pass


func _reward() -> void:
	var at := global_position + Vector3(0, 0.5, 0)
	var n := roundi(_rng.randi_range(coins.x, coins.y) * Levels.coins_k(level))
	if n > 0:
		Net.coins(at, n)
	Net.award_xp(roundi(xp * xp_k * Levels.xp_k(level)), global_position + Vector3(0, 1.0 * size_k, 0))
	# (each captain rolls their own)
	if not drops.is_empty():
		Net.kill_loot(drops, global_position + Vector3(0, 0.3, 0))


func _dead_update(delta: float) -> void:
	_dead_t += delta
	if _sink == 0.0:
		velocity.y -= GRAVITY * delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()
		_roll = move_toward(_roll, _roll_to, 7.0 * delta)
	if _dead_t > 3.2 and _sink == 0.0:
		_sink = 0.001
		FX.dust(global_position, 5, 0.5 * size_k)
	if _sink > 0.0:
		_sink += delta / 0.7
		model.scale = Vector3.ONE * size_k * maxf(1.0 - _sink, 0.01)
		model.position.y -= 0.3 * delta / 0.7
		if _sink >= 1.0:
			queue_free()


# ==========================================================================
# Pose
# ==========================================================================
func _process(delta: float) -> void:
	if net_puppet:
		_net_update(delta)
	_t += delta
	_pose_dt += delta
	_frame += 1
	if lod == LOD_LOW and _frame % 3 != 0:
		return
	var d := _pose_dt
	_pose_dt = 0.0
	_pose(d)
	model.rotation.z = _roll


## Set the parts' rotations for this frame (`delta`: since the last pose).
func _pose(_delta: float) -> void:
	pass


## The distance LOD (FaunaSpawner, a few times a second).
func set_lod(l: int) -> void:
	lod = l
	if preview:
		return
	# (never frozen mid-tumble or while sinking away)
	var awake := l <= LOD_LOW or state in [S.DEAD, S.DOWN]
	if awake != is_physics_processing():
		set_physics_process(awake)
		set_process(awake)
	var vis := l < LOD_HIDDEN or state == S.DEAD
	if model.visible != vis:
		model.visible = vis


# ==========================================================================
# Co-op
# ==========================================================================
func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = _max_hp() * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


func net_pack() -> Array:
	return [global_position, model.rotation.y, velocity, int(state), health.current_health, health.max_health,
		hitbox.active, hitbox.activations, anim_a, anim_b, _roll, strike_id]


func _net_update(delta: float) -> void:
	_net_hb_t -= delta
	if state == S.DEAD:
		return
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	if a.size() < 12 or b.size() < 12:
		return
	if int(a[3]) == S.DEAD:
		_die(-_fwd())
		died.emit(self)
		return
	global_position = (a[0] as Vector3).lerp(b[0], f)
	model.rotation.y = lerp_angle(float(a[1]), float(b[1]), f)
	_yaw = model.rotation.y
	velocity = b[2]
	var st := int(a[3])
	if st != state:
		if hitbox.active:
			hitbox.deactivate()
		state = st as S
		st_t = 0.0
	health.max_health = float(b[5])
	health.current_health = float(b[4])
	anim_a = lerpf(float(a[8]), float(b[8]), f)
	anim_b = lerpf(float(a[9]), float(b[9]), f)
	_roll = lerpf(float(a[10]), float(b[10]), f)
	var serial := int(a[7])
	if serial != _net_serial:
		var first := _net_serial < 0
		_net_serial = serial
		if not first:
			_arm(int(a[11]))
			hitbox.activate()
			_net_hb_t = 0.15
	if hitbox.active and not bool(a[6]) and _net_hb_t <= 0.0:
		hitbox.deactivate()


func net_event(what: String, args: Array) -> void:
	match what:
		"flash":
			_flash_hit(bool(args[0]) if args.size() > 0 else false)
		"knock":
			hitbox.deactivate()
			state = S.DOWN
			st_t = 0.0
		"getup":
			pass
		"die":
			if state != S.DEAD:
				_die(args[0])
				died.emit(self)
		"burn_fx":
			BurnStatus.apply(self, float(args[0]), 0.0, null)
		"poison_fx":
			PoisonStatus.apply(self, float(args[0]), 0.0, null)
		_:
			_net_event(what, args)


## A creature's own one-shots.
func _net_event(_what: String, _args: Array) -> void:
	pass
