class_name PirateGrunt
extends CharacterBody3D
## Cutlass-swinging smuggler. A sword fight, not a damage sponge:
##
## * Every attack has a held wind-up (sword cocked back, a glint on the blade)
##   before it swings: a two-slash combo up close, or a lunge from a few
##   metres out. After attacking it's wide open for a moment.
## * It guards: light hits from the front get blocked (sparks, no damage),
##   but the guard breaks on the third hit and leaves it staggered. Hits from
##   the side or behind, during its wind-up or recovery, and heavy attacks
##   all land.
## * Parrying its swing staggers it wide open. Heavy hits knock it down
##   (physics ragdoll, then it gets up); death ragdolls and drops gold.
## * The squad (GruntCamp) hands out attack turns so only two swing at once;
##   the rest circle, strafe and wait.

signal died(grunt: PirateGrunt)

enum S { IDLE, ALERT, CHASE, CIRCLE, CLOSE, WIND, SWING, RECOVER, BLOCK, STAGGER, HITSTUN, DOWN, GETUP, RETURN, DEAD }

const GRAVITY := 20.0
const RUN_SPEED := 4.4
const WALK_SPEED := 1.3
const STRAFE_SPEED := 1.7
const NOTICE_RANGE := 12.0
const GIVE_UP_RANGE := 24.0
const LEASH := 26.0
const CIRCLE_RANGE := 3.3
const COMBO_RANGE := 2.0
const MAX_HP := 110.0
const GUARD_BLOCKS := 3
const BODY_LAYER := 4 | 2048

const BARK_ALERT := ["Oi! Who goes there?", "Intruder!", "Get 'em, lads!", "You lost, sailor?", "Wrong beach, friend."]
const BARK_HURT := ["Argh!", "Gah!", "Oof!", "Blast it!"]
const BARK_PARRIED := ["Wha-?!", "Huh?!"]
const BARK_DIE := ["Ugh...", "Tell... the cap'n...", "Nngh..."]

var camp: Node  # GruntCamp
var post := Vector3.ZERO
var post_yaw: float = 0.0
var idle_mode: String = "stand"  # stand | sit | patrol
var patrol: Array = []
var look: Dictionary = {}
var seat_y: float = 0.45

var state: S = S.IDLE
var st_t: float = 0.0
var humanoid: Humanoid
var facing: Node3D
var hurtbox: Hurtbox
var hitbox: Hitbox
var health: HealthComponent

var _col: CollisionShape3D
var _bark: Label3D
var _bark_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _yaw: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_t: float = 0.0
var _has_token: bool = false
var _attack: String = "combo"
var _swing_i: int = 0
var _cooldown: float = 0.0
var _guard_hits: int = 0
var _guard_t: float = 0.0
var _stun_len: float = 0.25
var _stun_vel := Vector3.ZERO
var _stagger_len: float = 1.3
var _lunge_dir := Vector3.ZERO
var _glinted: bool = false
var _swung: bool = false
var _patrol_i: int = 0
var _patrol_wait: float = 0.0
var _getup_len: float = 1.0
var _rest: float = 0.0
var _dead_t: float = 0.0
var _sink: float = 0.0
var _stuck: float = 0.0
var _riposte: bool = false
var _detour := Vector3.ZERO
var _detour_t: float = 0.0
var _damage_number_scene: PackedScene


func setup(cfg: Dictionary) -> PirateGrunt:
	post = cfg.get("post", Vector3.ZERO)
	post_yaw = float(cfg.get("yaw", 0.0))
	idle_mode = str(cfg.get("mode", "stand"))
	patrol = cfg.get("patrol", [])
	seat_y = float(cfg.get("seat_y", 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	look = cfg.get("look", PirateGrunt.crew_look(rng))
	return self


## A random member of the smuggler crew: anyone from the character creator's
## parts, tied together by the crew's red sash and rough working clothes.
static func crew_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.random_look(rng)
	var C := CharacterLook.CLOTH
	lk["name"] = "Smuggler"
	lk["hat"] = ["bandana", "bandana", "tricorn", "none", "knit", "cap"][rng.randi() % 6]
	lk["hat_color"] = [C[13], C[5], C[4], C[14], C[3]][rng.randi() % 5]
	lk["top"] = ["shirt", "shirt", "tunic", "bare"][rng.randi() % 4] if lk["body"] == "masc" else ["shirt", "tunic", "blouse"][rng.randi() % 3]
	lk["top_color"] = [C[0], C[1], C[2], C[6], C[7]][rng.randi() % 5]
	lk["sleeves"] = ["short", "none", "long"][rng.randi() % 3]
	lk["vest"] = ["none", "vest", "vest"][rng.randi() % 3]
	lk["vest_color"] = [C[3], C[4], C[5], C[14]][rng.randi() % 4]
	lk["coat"] = "none" if rng.randf() < 0.7 else "jacket"
	lk["coat_color"] = [C[4], C[5], C[6]][rng.randi() % 3]
	lk["legs"] = ["trousers", "breeches", "shorts"][rng.randi() % 3]
	lk["legs_color"] = [C[2], C[3], C[4], C[6], C[8]][rng.randi() % 5]
	lk["belt"] = ["sash", "belt_sash"][rng.randi() % 2]
	lk["sash_color"] = C[13]  # the crew's red sash
	lk["eyepatch"] = rng.randf() < 0.25
	lk["earring"] = rng.randf() < 0.4
	lk["scarf"] = rng.randf() < 0.2
	lk["scarf_color"] = C[13]
	lk["pauldron"] = rng.randf() < 0.15
	lk["marks"] = ["none", "scar", "scar", "war_paint", "age_lines"][rng.randi() % 5]
	return lk


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	collision_layer = BODY_LAYER
	collision_mask = 1 | 2 | 2048
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	_damage_number_scene = load("res://scenes/effects/damage_number.tscn")
	if post == Vector3.ZERO:
		post = global_position

	facing = Node3D.new()
	facing.name = "Facing"
	add_child(facing)
	humanoid = Humanoid.new()
	humanoid.name = "Model"
	humanoid.setup(look)
	facing.add_child(humanoid)
	humanoid.set_weapon(Props.weapon_mesh("cutlass"))
	_yaw = post_yaw
	facing.rotation.y = _yaw

	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	_col.shape = cap
	_col.position = Vector3(0, 0.9, 0)
	add_child(_col)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = MAX_HP
	add_child(health)
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 16
	var hs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.5
	hcap.height = 1.9
	hs.shape = hcap
	hs.position = Vector3(0, 0.95, 0)
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)

	hitbox = Hitbox.new()
	hitbox.name = "SwordHitbox"
	hitbox.collision_layer = 64
	hitbox.collision_mask = 128
	var bs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.3, 1.5)
	bs.shape = box
	bs.position = Vector3(0, 1.0, -1.0)
	hitbox.add_child(bs)
	facing.add_child(hitbox)
	hitbox.owner = self
	var hd := HitData.new()
	hd.damage = 12.0
	hd.knockback_force = 4.5
	hd.stagger_duration = 0.3
	hd.hitstop_duration = 0.06
	hd.camera_shake_intensity = 0.14
	hitbox.hit_data = hd

	_bark = Label3D.new()
	_bark.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_bark.font_size = 30
	_bark.pixel_size = 0.006
	_bark.outline_size = 8
	_bark.modulate = Color(1.0, 0.85, 0.75)
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bark.position = Vector3(0, 2.35 * float(look.get("height", 1.0)), 0)
	_bark.visible = false
	add_child(_bark)

	_enter_idle()


# ==========================================================================
# Helpers
# ==========================================================================
func _set_state(s: S) -> void:
	if state in [S.SWING] and s != S.SWING:
		hitbox.deactivate()
	state = s
	st_t = 0.0


func _target() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player


## A target worth fighting: on foot, alive, not in the water or knocked down.
func _player_ok(p: Node3D) -> bool:
	if p == null:
		return false
	if p.has_method("current_state_name") and str(p.call("current_state_name")) in ["Downed", "Helm", "Swim", "Climb"]:
		return false
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		_yaw = atan2(-dir.x, -dir.z)


func _fwd() -> Vector3:
	return Vector3(-sin(facing.rotation.y), 0.0, -cos(facing.rotation.y))


func bark(lines: Array, chance: float = 1.0) -> void:
	if _rng.randf() > chance:
		return
	_bark.text = str(lines[_rng.randi() % lines.size()])
	_bark.visible = true
	_bark_t = 1.8


func _release_token() -> void:
	if _has_token and camp and is_instance_valid(camp):
		camp.call("release_token", self)
	_has_token = false


func in_combat() -> bool:
	return state not in [S.IDLE, S.RETURN, S.DEAD]


# ==========================================================================
# Idle at the camp
# ==========================================================================
func _enter_idle() -> void:
	_set_state(S.IDLE)
	humanoid.armed = false
	humanoid.seated = idle_mode == "sit"
	humanoid.seat_y = seat_y
	_yaw = post_yaw


## Spotted the player (or got hit / heard the others).
func alert(delay: float = 0.0) -> void:
	if state != S.IDLE and state != S.RETURN:
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self) and (state == S.IDLE or state == S.RETURN):
				alert(0.0))
		return
	humanoid.seated = false
	if state == S.IDLE:
		bark(BARK_ALERT, 0.7)
	_set_state(S.ALERT)
	humanoid.play("draw", 0.45)
	if camp and is_instance_valid(camp):
		camp.call("alert_all", global_position)


# ==========================================================================
# Brain
# ==========================================================================
func _physics_process(delta: float) -> void:
	st_t += delta
	_cooldown -= delta
	_guard_t -= delta
	if _guard_t <= 0.0:
		_guard_hits = 0
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
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
	var dir_p := to_p.normalized() if dist > 0.01 else _fwd()
	var hv := _flat(velocity)
	var want := Vector3.ZERO
	var accel := 18.0
	var turn := 9.0
	var running := false

	match state:
		S.IDLE:
			want = _idle_move(delta)
			if p and _player_ok(p) and dist < NOTICE_RANGE:
				var ahead := _fwd().dot(dir_p) > -0.2
				if ahead or dist < 5.0 or idle_mode == "sit":
					alert()
		S.ALERT:
			_face(dir_p)
			turn = 12.0
			if st_t > 0.5:
				_set_state(S.CHASE)
		S.CHASE:
			if _lost(p, dist):
				_go_home()
			else:
				_face(dir_p)
				if dist > CIRCLE_RANGE + 0.6:
					want = dir_p * RUN_SPEED + _separation()
					running = true
				else:
					_set_state(S.CIRCLE)
		S.CIRCLE:
			if _lost(p, dist):
				_go_home()
			else:
				_face(dir_p)
				_strafe_t -= delta
				if _strafe_t <= 0.0:
					_strafe_t = _rng.randf_range(1.2, 2.6)
					_strafe_dir = -_strafe_dir if _rng.randf() < 0.6 else _strafe_dir
				var radial := clampf((dist - CIRCLE_RANGE) * 1.6, -1.6, 3.0)
				var tangent := Vector3.UP.cross(dir_p) * _strafe_dir * STRAFE_SPEED
				want = dir_p * radial + tangent + _separation() * 1.5
				if dist > CIRCLE_RANGE + 3.0:
					_set_state(S.CHASE)
				elif _cooldown <= 0.0 and _player_ok(p) and _get_token():
					_attack = "lunge" if dist > 2.9 and _rng.randf() < 0.55 else "combo"
					_swing_i = 0
					if _attack == "lunge":
						_start_wind()
					else:
						_set_state(S.CLOSE)
		S.CLOSE:
			_face(dir_p)
			want = dir_p * RUN_SPEED * 0.85 + _separation()
			running = true
			if dist <= COMBO_RANGE + 0.15:
				_start_wind()
			elif st_t > 2.0 or not _player_ok(p):
				_release_token()
				_cooldown = 1.0
				_set_state(S.CIRCLE)
		S.WIND:
			var dur := _wind_len()
			if st_t < dur * 0.65:
				_face(dir_p)
				turn = 10.0
			else:
				turn = 2.0
			if _attack == "combo" and dist > COMBO_RANGE + 0.3 and st_t < dur * 0.65:
				want = dir_p * 2.0
			if not _glinted and st_t > dur * 0.55:
				_glinted = true
				_glint()
			if st_t >= dur:
				_start_swing()
		S.SWING:
			if _attack == "lunge":
				var lt := 0.32
				if st_t < lt:
					want = _lunge_dir * 9.0
					accel = 80.0
					if st_t > 0.04 and not hitbox.active:
						hitbox.activate()
				else:
					hitbox.deactivate()
					accel = 20.0
				if st_t > 0.75:
					_end_attack(0.75)
			else:
				accel = 14.0
				if st_t > 0.06 and st_t < 0.22 and not _swung:
					_swung = true
					hitbox.activate()
				elif st_t >= 0.22:
					hitbox.deactivate()
				if st_t > 0.42:
					if _swing_i == 0:
						_swing_i = 1
						_start_wind()
					else:
						_end_attack(0.6)
		S.RECOVER:
			accel = 12.0
			if st_t > float(get_meta("recover", 0.6)):
				_release_token()
				_cooldown = _rng.randf_range(1.3, 2.4)
				_set_state(S.CIRCLE)
		S.BLOCK:
			_face(dir_p)
			accel = 10.0
			if _riposte and st_t > 0.16 and p and _player_ok(p) and dist < COMBO_RANGE + 1.2:
				_riposte = false
				_has_token = true
				_attack = "combo"
				_swing_i = 1
				_start_wind()
			elif st_t > 0.4:
				_set_state(S.CIRCLE)
		S.STAGGER:
			accel = 8.0
			if st_t > _stagger_len:
				_cooldown = 0.8
				_set_state(S.CIRCLE)
		S.HITSTUN:
			want = _stun_vel * maxf(0.0, 1.0 - st_t / _stun_len)
			accel = 30.0
			if st_t > _stun_len:
				_cooldown = maxf(_cooldown, 0.7)
				_set_state(S.CIRCLE)
		S.GETUP:
			if st_t > _getup_len:
				_cooldown = 1.0
				_set_state(S.CIRCLE)
		S.RETURN:
			var to_post := _flat(post - global_position)
			if p and _player_ok(p) and dist < NOTICE_RANGE * 0.7:
				alert()
			elif to_post.length() > 0.6:
				_face(to_post)
				want = to_post.normalized() * WALK_SPEED * 1.6
			else:
				global_position.x = post.x
				global_position.z = post.z
				humanoid.play("sheathe", 0.5)
				health.heal(MAX_HP)
				_enter_idle()

	# walked into something (tent, crate, rock): sidestep around it for a bit
	if _detour_t > 0.0:
		_detour_t -= delta
		if want.length() > 0.3:
			want = (want.normalized() * 0.4 + _detour * 0.9).normalized() * want.length()
	if state == S.SWING and _attack == "lunge" and st_t < 0.32:
		hv = want
	else:
		hv = hv.move_toward(want, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(turn * delta, 1.0))

	if want.length() > 0.5 and state in [S.CHASE, S.CLOSE, S.RETURN, S.IDLE] and _flat(get_real_velocity()).length() < want.length() * 0.3:
		_stuck += delta
		if _stuck > 0.5:
			_stuck = 0.0
			_strafe_dir = -_strafe_dir
			_detour = Vector3.UP.cross(want.normalized()) * _strafe_dir
			_detour_t = 0.9
	else:
		_stuck = 0.0

	_feed_body(hv, running)


func _feed_body(hv: Vector3, running: bool) -> void:
	humanoid.ground_speed = hv.length()
	var local := facing.global_basis.inverse() * hv
	humanoid.local_move = Vector2(local.x, -local.z).normalized() if hv.length() > 0.2 else Vector2(0, 1)
	humanoid.grounded = is_on_floor()
	humanoid.vertical_speed = velocity.y
	humanoid.armed = in_combat()
	humanoid.sprinting = running


func _lost(p: Node3D, dist: float) -> bool:
	if p == null:
		return true
	if dist > GIVE_UP_RANGE or _flat(global_position - post).length() > LEASH:
		return true
	# the player swam off / is on the ship: give up after a while
	if not _player_ok(p) and str(p.call("current_state_name")) != "Downed" and st_t > 4.0:
		return true
	return false


func _go_home() -> void:
	_release_token()
	_set_state(S.RETURN)


func _get_token() -> bool:
	if camp == null or not is_instance_valid(camp):
		_has_token = true
		return true
	_has_token = bool(camp.call("request_token", self))
	return _has_token


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for g in get_tree().get_nodes_in_group("enemies"):
		if g == self or not (g is PirateGrunt):
			continue
		var d := _flat(global_position - (g as Node3D).global_position)
		var l := d.length()
		if l < 1.6 and l > 0.01:
			push += d / l * (1.6 - l) * 2.0
	return push


func _idle_move(delta: float) -> Vector3:
	if idle_mode != "patrol" or patrol.is_empty():
		return Vector3.ZERO
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		return Vector3.ZERO
	var tgt: Vector3 = patrol[_patrol_i % patrol.size()]
	var d := _flat(tgt - global_position)
	if d.length() < 0.5:
		_patrol_i += 1
		_patrol_wait = _rng.randf_range(1.5, 3.5)
		return Vector3.ZERO
	_face(d)
	return d.normalized() * WALK_SPEED


# ==========================================================================
# Attacks
# ==========================================================================
func _wind_len() -> float:
	if _attack == "lunge":
		return 0.7
	return 0.6 if _swing_i == 0 else 0.32


func _start_wind() -> void:
	_glinted = false
	_set_state(S.WIND)
	var anim := "lunge_wind" if _attack == "lunge" else ("wind_r" if _swing_i == 0 else "wind_l")
	humanoid.play(anim, _wind_len())


func _start_swing() -> void:
	_swung = false
	_set_state(S.SWING)
	hitbox.deactivate()
	if _attack == "lunge":
		_lunge_dir = _fwd()
		humanoid.play("lunge", 0.8)
		FX.sfx("whoosh", global_position, -4.0, 0.08, 1.15)
	else:
		humanoid.play("swing_r" if _swing_i == 0 else "swing_l", 0.5)
		velocity += _fwd() * 3.0
		FX.sfx("whoosh", global_position, -5.0, 0.1, 1.0)


func _end_attack(recover: float) -> void:
	hitbox.deactivate()
	set_meta("recover", recover)
	_set_state(S.RECOVER)


## The tell: a flash on the blade just before it swings.
func _glint() -> void:
	var tip := global_position + Vector3(0, 1.6, 0)
	if humanoid.weapon and humanoid.weapon.is_inside_tree():
		tip = humanoid.weapon.global_transform * Vector3(0, 0, -0.75)
	FX.sparkle(tip, 4, Color(1.0, 1.0, 0.95))
	FX.sfx("blip_high", tip, -14.0, 0.05, 1.6)


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = _flat(global_position - (attacker as Node3D).global_position)
	dir = dir.normalized() if dir.length() > 0.01 else -_fwd()
	var from_front := _fwd().dot(-dir) > 0.3
	var guarding := state in [S.CIRCLE, S.CHASE, S.ALERT, S.BLOCK, S.CLOSE]
	if state == S.IDLE or state == S.RETURN:
		alert()
		guarding = false

	# blocked: sparks, no damage (until the guard breaks)
	if guarding and from_front and not hit.knockdown:
		if _guard_hits < GUARD_BLOCKS:
			_guard_hits += 1
			_guard_t = 3.5
			var spark := global_position + Vector3(0, 1.25, 0) - dir * 0.55
			FX.impact(spark, Color(1.0, 0.95, 0.7))
			FX.sparkle(spark, 6, Color(1.0, 0.9, 0.5))
			FX.sfx("hit", spark, -2.0, 0.05, 1.8)
			get_node("/root/CombatManager").apply_hitstop(0.04)
			humanoid.play("block", 0.4)
			velocity = dir * 2.5
			# mashing into a guard gets you a quick counter-slash
			_riposte = _guard_hits >= 2 or _rng.randf() < 0.35
			_set_state(S.BLOCK)
			return
		# third hit: the guard breaks
		_guard_hits = 0
		_stagger_len = 1.1
		_take_damage(hit, dir)
		if state == S.DEAD:
			return
		bark(BARK_HURT, 0.5)
		FX.sparkle(global_position + Vector3(0, 1.5, 0), 10, Color(1.0, 0.8, 0.4))
		_release_token()
		humanoid.play("stagger", 1.1)
		velocity = dir * 3.0
		_set_state(S.STAGGER)
		return

	_take_damage(hit, dir)
	if state == S.DEAD:
		return
	bark(BARK_HURT, 0.3)
	_release_token()
	if hit.knockdown:
		_knock_down(dir * clampf(hit.knockback_force * 0.7, 4.0, 8.0) + Vector3.UP * 3.2)
		return
	if state == S.STAGGER:
		return  # already reeling: keep the punish window
	_stun_len = 0.28
	_stun_vel = dir * minf(hit.knockback_force * 0.6, 5.0)
	velocity = _stun_vel
	humanoid.play("hit", 0.32)
	_set_state(S.HITSTUN)


func _take_damage(hit: HitData, dir: Vector3) -> void:
	if _damage_number_scene:
		var n: Node = _damage_number_scene.instantiate()
		get_tree().current_scene.add_child(n)
		n.call("setup", hit.damage, global_position + Vector3(0, 1.9, 0))
	FX.impact(global_position + Vector3(0, 1.2, 0) - dir * 0.35, Color(1.0, 0.6, 0.45))
	FX.sfx("hit", global_position, -2.0, 0.1, 1.05 if hit.damage < 20.0 else 0.85)
	get_node("/root/CombatManager").apply_hit_effects(hit)
	set_meta("last_dir", dir)
	health.take_damage(hit.damage)


## Its swing was parried: staggered, wide open.
func parried(by: Node) -> void:
	if state in [S.DEAD, S.DOWN]:
		return
	hitbox.deactivate()
	_release_token()
	bark(BARK_PARRIED, 0.8)
	var dir := -_fwd()
	if by is Node3D:
		dir = _flat(global_position - (by as Node3D).global_position).normalized()
	velocity = dir * 3.5
	_stagger_len = 1.5
	humanoid.play("stagger", 1.5)
	_set_state(S.STAGGER)


func _knock_down(v: Vector3) -> void:
	hitbox.deactivate()
	_release_token()
	humanoid.start_ragdoll(v, Vector3.UP.cross(_flat(v).normalized()) * 5.0)
	_rest = 0.0
	_set_state(S.DOWN)


func _down_update(delta: float) -> void:
	var rag := humanoid.ragdoll
	var hips := humanoid.hips.global_position
	var to := _flat(hips - global_position)
	velocity.x = to.x * 10.0
	velocity.z = to.z * 10.0
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if rag == null:
		_set_state(S.CIRCLE)
		return
	if rag.settled():
		_rest += delta
	else:
		_rest = 0.0
	if st_t > 1.0 and (_rest > 0.3 or st_t > 3.5):
		var info := humanoid.ragdoll_rest_info()
		var face_up: bool = info["face_up"]
		var head_dir: Vector3 = info["head_dir"]
		var f := -head_dir if face_up else head_dir
		_yaw = atan2(-f.x, -f.z)
		facing.rotation.y = _yaw
		_getup_len = 1.1 if face_up else 1.0
		humanoid.begin_getup(face_up, _getup_len, info["hips_xform"])
		_set_state(S.GETUP)


func _on_died() -> void:
	if state == S.DEAD:
		return
	_release_token()
	hitbox.deactivate()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	bark(BARK_DIE, 0.6)
	var dir: Vector3 = get_meta("last_dir", -_fwd())
	if humanoid.ragdoll == null:
		humanoid.start_ragdoll(dir * 5.0 + Vector3.UP * 3.0, Vector3.UP.cross(dir) * 5.0)
	else:
		humanoid.ragdoll.push(dir * 3.0)
	_set_state(S.DEAD)
	_dead_t = 0.0
	CoinPickup.spawn(get_tree(), global_position + Vector3(0, 1.0, 0), _rng.randi_range(3, 6))
	died.emit(self)


func _dead_update(delta: float) -> void:
	_dead_t += delta
	var rag := humanoid.ragdoll
	if _dead_t > 8.0 and _sink == 0.0:
		_sink = 0.001
		if rag:
			for part in rag.parts:
				(part["body"] as RigidBody3D).freeze = true
		FX.dust(humanoid.hips.global_position, 8, 0.8)
	if _sink > 0.0:
		_sink += delta / 1.2
		if rag:
			rag.global_position += Vector3.DOWN * 0.6 * delta / 1.2
		if _sink >= 1.0:
			queue_free()


func _exit_tree() -> void:
	if humanoid:
		humanoid.end_ragdoll()
