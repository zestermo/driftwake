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
## * The lunge is its heavy attack: the blade glows yellow for a second as it
##   winds up, and it hits harder.
## * Firearms: keep your distance (10+ m) and a swordsman may pull a pistol
##   (at most every 10 s). Riflemen (role "rifle") keep 10-16 m away, take a
##   shot every ~8 s and move to a new firing spot afterwards; get in close and
##   they knock you down with the rifle butt. Every shot is telegraphed: a
##   faint grey line shows where it will go, it stops tracking (and darkens a
##   little) just before the shot, and only what's on the line gets hit
##   (sidestep, dodge-roll, or parry it). Firing throws sparks and a cloud of
##   powder smoke, with a smoke trail along the shot.

signal died(grunt: PirateGrunt)

enum S { IDLE, ALERT, CHASE, CIRCLE, CLOSE, WIND, SWING, RECOVER, BLOCK, STAGGER, HITSTUN, DOWN, GETUP, RETURN, DEAD, AIM, KEEP, REPOSITION, SHOVE, SWIM, LEAP }

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
## Firearms
const PISTOL_RANGE := 9.1          # ~10 yards: farther than this, a pistol may come out
const PISTOL_COOLDOWN := 10.0
const PISTOL_CHANCE := 0.35        # per second while you're out of reach
const PISTOL_AIM := 1.0
const PISTOL_LOCK := 0.35
const RIFLE_AIM := 1.4
const RIFLE_LOCK := 0.42
const RIFLE_EVERY := 8.0
const RIFLE_NEAR := 10.0
const RIFLE_FAR := 16.0
const SHOVE_RANGE := 3.0
const SHOVE_COOLDOWN := 5.0
const GUN_RANGE := 45.0
const HEAVY_GLOW := 1.0
# water: same depths as the player (feet this far under the surface: swim)
const SWIM_ENTER_DEPTH := 1.15
const SWIM_EXIT_DEPTH := 0.95
const SWIM_SPEED := 2.6
## Seconds a swimmer with no beach in reach lasts before it drowns.
const SWIM_GIVE_UP := 20.0
## A boarder idle this far from every captain for LEFT_BEHIND_SECS slips away.
const LEFT_BEHIND_RANGE := 90.0
const LEFT_BEHIND_SECS := 8
## Won't walk anywhere the sea floor is deeper than this under the mean water
## line (the swell rises ~1 m above it, so this keeps them out of swimming).
const WADE_MAX := 0.0
## In deep water after a knockdown: recover once the hips float this high.
const FLOAT_DEPTH := 0.45
## Aim line: very faint grey while tracking, a touch stronger once locked.
const AIM_TRACK := Color(0.82, 0.82, 0.82, 0.16)
const AIM_LOCKED := Color(0.9, 0.9, 0.9, 0.34)
const AIM_FIRE := Color(1.0, 1.0, 1.0, 0.7)

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
## "sword" (cutlass + pistol) or "rifle" (rifle only).
var role: String = "sword"
## Came over the side from a pirate ship: no post to go back to, fights on
## wherever it lands.
var boarder: bool = false
var _leap_v := Vector3.ZERO

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
var _blade_model: String = "cutlass"
var _blade_id: String = "cutlass"
var _player: Node3D
var _yaw: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_t: float = 0.0
var _has_token: bool = false
var _attack: String = "combo"
var _swing_i: int = 0
var _cooldown: float = 0.0
## The unblockable heavy: the grunt flashes red through a long wind-up, then
## an overhead chop that can't be parried or blocked (dodge it). Armament
## Haki hits break the wind-up; anything else just bounces off (super armor).
var _peril_cd: float = 0.0
var _peril_on: bool = false
var _hit_peril: HitData
static var _peril_mat: StandardMaterial3D
static var _peril_blade: StandardMaterial3D
const PERIL_WIND := 1.0
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
## Least time on the ground before getting up (shorter after a crumple).
var _down_min: float = 1.0
## The last hit that landed (a cutting killing blow can sever).
var _last_hit: HitData
var _hit_by: Node
## Chance a cutting killing blow takes off a head or an arm (a full-charge katana draw always does).
const SEVER_CHANCE := 0.6
var _dead_t: float = 0.0
var _sink: float = 0.0
var _stuck: float = 0.0
var _riposte: bool = false
var _detour := Vector3.ZERO
var _detour_t: float = 0.0
var _path := PackedVector3Array()
var _path_i: int = 0
var _path_goal := Vector3.INF
var _path_t: float = 0.0
var _damage_number_scene: PackedScene
var _gun: String = ""
var _aim_len: float = 1.0
var _lock_len: float = 0.35
var _aim_point := Vector3.ZERO
var _aim_line: MeshInstance3D
var _aim_mat: StandardMaterial3D
var _fired: bool = false
var _locked: bool = false
var _pistol_cd: float = 0.0
var _shot_cd: float = 0.0
var _shove_cd: float = 0.0
var _shoved: bool = false
var _no_los_t: float = 0.0
var _repos_target := Vector3.ZERO
var _glow_t: float = 0.0
var _hit_light: HitData
var _ocean: Node
var _shore := Vector3.INF
var _shore_t: float = 0.0
var _bad_shores: Array = []
var _swim_vy: float = 0.0
var _prev_float: float = INF
var _swim_stuck: float = 0.0
var _swim_t: float = 0.0
var _far_t: float = 0.0
var _far_n: int = 0
var _ripple_t: float = 0.0
var _hit_heavy: HitData
static var _glow_mat: ShaderMaterial
## Co-op client: this grunt is a puppet of the host's (no brain here; it
## plays back the host's snapshots and events).
var net_puppet: bool = false
var _net_serial: int = -1
var _net_hb_t: float = 0.0
var _net_glow: bool = false


## Markers and the like: is it down for good?
func is_dead() -> bool:
	return state == S.DEAD


func setup(cfg: Dictionary) -> PirateGrunt:
	post = cfg.get("post", Vector3.ZERO)
	post_yaw = float(cfg.get("yaw", 0.0))
	idle_mode = str(cfg.get("mode", "stand"))
	patrol = cfg.get("patrol", [])
	seat_y = float(cfg.get("seat_y", 0.45))
	role = str(cfg.get("role", "sword"))
	look = PirateGrunt.look_for(cfg)
	_body = cfg.get("body")
	return self


## The look a setup dict gives (its own, or the crew look its seed makes).
static func look_for(cfg: Dictionary) -> Dictionary:
	if cfg.has("look"):
		return cfg["look"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	return PirateGrunt.crew_look(rng)


## A body to take over (a ship's crewman turning boarder) instead of building one.
var _body: Humanoid


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
	# the odd one's kitted out: a mail shirt or brigandine, a morion, a bandolier
	if rng.randf() < 0.15:
		lk["vest"] = ["mail", "brigandine"][rng.randi() % 2]
	if rng.randf() < 0.07:
		lk["hat"] = "morion"
	lk["bandolier"] = rng.randf() < 0.18
	return lk


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	add_to_group("net_sync")
	net_puppet = Net.is_client()
	if net_puppet:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	if _body and is_instance_valid(_body):
		# the crewman himself goes over the side (no new body to build)
		humanoid = _body
		humanoid.get_parent().remove_child(humanoid)
		humanoid.transform = Transform3D.IDENTITY
		humanoid.scale = Vector3.ONE * float(humanoid.look.get("height", 1.0))
		humanoid.visible = true
		humanoid.seated = false
		humanoid.at_helm = false
		humanoid.stop_action()
	else:
		humanoid = Humanoid.make(look)
	humanoid.name = "Model"
	facing.add_child(humanoid)
	humanoid.reset_physics_interpolation()
	# every pirate's blade is their own (and it's the one they drop)
	var d := WeaponDesigns.random_design("cutlass", _rng)
	_blade_model = "cutlass:%s:0" % d
	_blade_id = str(WeaponDesigns.DESIGNS["cutlass"][d]["id"]) if d != "" else "cutlass"
	humanoid.set_weapon(Props.weapon_mesh("rifle" if role == "rifle" else _blade_model))
	if role == "rifle":
		humanoid._attach_weapon(true)
		humanoid.carry = "rifle"
	# the grunt points its gun itself (after the body has posed)
	process_priority = 10
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
	_hit_light = hd
	_hit_heavy = hd.duplicate() as HitData
	_hit_heavy.damage = 16.0
	_hit_heavy.knockback_force = 6.0
	_hit_heavy.hitstop_duration = 0.08
	_hit_heavy.camera_shake_intensity = 0.2
	_hit_peril = hd.duplicate() as HitData
	_hit_peril.damage = 24.0
	_hit_peril.knockback_force = 9.0
	_hit_peril.hitstop_duration = 0.12
	_hit_peril.camera_shake_intensity = 0.3
	_hit_peril.knockdown = true
	_hit_peril.unblockable = true
	_peril_cd = _rng.randf_range(4.0, 9.0)
	_pistol_cd = _rng.randf_range(2.0, 6.0)
	_shot_cd = _rng.randf_range(1.0, 2.5)

	# the aim line (thin, red while tracking, white-hot once locked)
	_aim_mat = StandardMaterial3D.new()
	_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_mat.albedo_color = AIM_TRACK
	_aim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lm := BoxMesh.new()
	lm.size = Vector3(1, 1, 1)
	lm.material = _aim_mat
	_aim_line = MeshInstance3D.new()
	_aim_line.name = "AimLine"
	_aim_line.mesh = lm
	_aim_line.top_level = true
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_aim_line.visible = false
	add_child(_aim_line)

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
	if Net.hosting:
		net_rescale(Net.hp_scale())


# ==========================================================================
# Helpers
# ==========================================================================
func _set_state(s: S) -> void:
	if state in [S.SWING] and s != S.SWING:
		hitbox.deactivate()
	if _peril_on and not (s in [S.WIND, S.SWING] and _attack == "peril"):
		_set_peril(false)
	if state == S.AIM and s != S.AIM:
		_end_aim()
	if state == S.SWIM and s != S.SWIM:
		humanoid.swimming = false
	if s != S.DOWN:
		set_collision_mask_value(2, true)   # (off while crumpled)
	state = s
	st_t = 0.0


func _target() -> Node3D:
	if not Net.coop():
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		return _player
	# co-op: the nearest captain worth fighting (sticking with the current
	# one unless another is clearly closer), else the nearest at all
	if not is_instance_valid(_player):
		_player = null
	var p := Net.nearest_player(global_position, _player_ok, _player) as Node3D
	if p == null:
		p = Net.nearest_player(global_position, Callable(), _player) as Node3D
	_player = p
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


## Where a fight goes on from (after a flinch, a block, getting up...).
func _fight_state() -> S:
	return S.KEEP if role == "rifle" else S.CIRCLE


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
	if role != "rifle":
		humanoid.play("draw", 0.45)
	if camp and is_instance_valid(camp):
		camp.call("alert_all", global_position)


# ==========================================================================
# Brain
# ==========================================================================
func _physics_process(delta: float) -> void:
	if net_puppet:
		# the host thinks for it; a dead body sinks away here by itself
		if state == S.DEAD:
			_dead_update(delta)
		return
	st_t += delta
	_cooldown -= delta
	_peril_cd -= delta
	_guard_t -= delta
	if _guard_t <= 0.0:
		_guard_hits = 0
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
	_pistol_cd -= delta
	_shot_cd -= delta
	_shove_cd -= delta
	if state == S.DEAD:
		_dead_update(delta)
		return
	if boarder and state == S.IDLE and _left_behind(delta):
		vanish(false)
		return
	if state == S.DOWN or (humanoid.ragdoll != null and state != S.DEAD):
		if state != S.DOWN:
			_set_state(S.DOWN)
		_down_update(delta)
		return
	if state == S.SWIM:
		_swim_update(delta)
		return
	if _surface_depth() > SWIM_ENTER_DEPTH:
		_enter_swim(velocity.y)
		_swim_update(delta)
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
			if p and _player_ok(p) and dist < (NOTICE_RANGE * 1.4 if role == "rifle" else NOTICE_RANGE):
				var ahead := _fwd().dot(dir_p) > -0.2
				if ahead or dist < 5.0 or idle_mode == "sit":
					alert()
		S.ALERT:
			_face(dir_p)
			turn = 12.0
			if st_t > 0.5:
				_set_state(S.KEEP if role == "rifle" else S.CHASE)
		S.CHASE:
			if _lost(p, dist):
				_go_home()
			else:
				var nd := _nav_dir(p.global_position, delta)
				_face(nd)
				if _want_pistol(p, dist, delta):
					_start_aim("pistol")
				elif dist > CIRCLE_RANGE + 0.6:
					want = nd * RUN_SPEED + _separation()
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
				if _want_pistol(p, dist, delta):
					_start_aim("pistol")
				elif dist > CIRCLE_RANGE + 3.0:
					_set_state(S.CHASE)
				elif _cooldown <= 0.0 and _player_ok(p) and _get_token():
					_attack = _choose_attack(dist)
					_swing_i = 0
					_begin_attack(dist)
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
			if _attack == "peril" and dist > COMBO_RANGE + 0.6 and st_t < dur * 0.7:
				want = dir_p * 2.4
			if not _glinted and st_t > dur * 0.55 and _attack != "peril":
				_glinted = true
				_glint()
			if st_t >= dur:
				_start_swing()
		S.SWING:
			if _attack == "peril":
				# the chop lands ~0.22 s in (the peril_chop pose started with the wind-up)
				if st_t < 0.25:
					want = _lunge_dir * 5.0
					accel = 40.0
				else:
					accel = 18.0
				if st_t > 0.12 and st_t < 0.34 and not _swung:
					_swung = true
					hitbox.activate()
				elif st_t >= 0.34:
					hitbox.deactivate()
				if st_t > 0.22 and not _glinted:
					_glinted = true
					var front := global_position + _fwd() * 1.4
					Net.fx("dust_ring", [front, 14, 0.9])
					Net.fx("sfx", ["thud", front, -3.0, 0.05, 0.8])
				if st_t > 0.8:
					_end_attack(1.0)
			elif _attack == "lunge":
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
					if _swing_i < _combo_hits() - 1:
						_swing_i += 1
						_start_wind()
					else:
						_end_attack(0.6)
		S.RECOVER:
			accel = 12.0
			if st_t > float(get_meta("recover", 0.6)):
				_release_token()
				_cooldown = _rng.randf_range(1.3, 2.4)
				_set_state(_fight_state())
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
				_set_state(_fight_state())
		S.STAGGER:
			accel = 8.0
			if st_t > _stagger_len:
				_cooldown = 0.8
				_set_state(_fight_state())
		S.HITSTUN:
			want = _stun_vel * maxf(0.0, 1.0 - st_t / _stun_len)
			accel = 30.0
			if st_t > _stun_len:
				_cooldown = maxf(_cooldown, 0.7)
				_set_state(_fight_state())
		S.GETUP:
			if st_t > _getup_len:
				_cooldown = 1.0
				_set_state(_fight_state())
		S.LEAP:
			# flying across from the pirate ship's deck
			want = _leap_v
			accel = 200.0
			turn = 4.0
			if st_t > 0.3 and is_on_floor():
				post = global_position
				Net.fx("dust_ring", [global_position, 10, 0.7])
				Net.fx("sfx", ["land", global_position, -4.0, 0.08])
				humanoid.play("draw", 0.45)
				_set_state(S.CHASE)
			elif st_t > 3.0:
				_set_state(S.CHASE)
		S.AIM:
			accel = 14.0
			turn = 12.0 if st_t < _aim_len - _lock_len else 1.0
			_aim_update(p, delta)
			if st_t >= _aim_len and not _fired:
				_fire(p)
			if st_t >= _aim_len + (0.35 if _gun == "pistol" else 0.3):
				if _gun == "pistol":
					humanoid.set_weapon(Props.weapon_mesh(_blade_model))
					_pistol_cd = PISTOL_COOLDOWN
					_set_state(S.CHASE)
				else:
					_shot_cd = RIFLE_EVERY + _rng.randf_range(-1.0, 1.0)
					_start_reposition(p)
		S.KEEP:
			if _lost(p, dist):
				_go_home()
			else:
				_face(dir_p)
				_strafe_t -= delta
				if _strafe_t <= 0.0:
					_strafe_t = _rng.randf_range(1.5, 3.0)
					_strafe_dir = -_strafe_dir if _rng.randf() < 0.5 else _strafe_dir
				var mid := (RIFLE_NEAR + RIFLE_FAR) * 0.5
				var radial := 0.0
				if dist < RIFLE_NEAR:
					radial = -2.6  # back off
				elif dist > RIFLE_FAR:
					radial = 3.2
					running = dist > RIFLE_FAR + 4.0
				else:
					radial = clampf((dist - mid) * 0.4, -0.8, 0.8)
				want = dir_p * radial + Vector3.UP.cross(dir_p) * _strafe_dir * 1.0 + _separation()
				var sees := _los(p)
				_no_los_t = 0.0 if sees else _no_los_t + delta
				if dist < SHOVE_RANGE and _shove_cd <= 0.0 and _player_ok(p):
					_start_shove()
				elif _shot_cd <= 0.0 and sees and _player_ok(p) and dist < GUN_RANGE * 0.6 and _guns_free():
					_start_aim("rifle")
				elif _no_los_t > 1.5:
					_start_reposition(p)
		S.REPOSITION:
			if _lost(p, dist):
				_go_home()
			else:
				var to_spot := _flat(_repos_target - global_position)
				if to_spot.length() > 0.7 and st_t < 3.5:
					var nd := _nav_dir(_repos_target, delta)
					_face(nd if to_spot.length() > 2.0 else dir_p)
					want = nd * RUN_SPEED * 0.9 + _separation()
					running = true
				else:
					_set_state(S.KEEP)
				if dist < SHOVE_RANGE and _shove_cd <= 0.0 and _player_ok(p):
					_start_shove()
		S.SHOVE:
			_face(dir_p)
			turn = 6.0 if st_t < 0.25 else 1.0
			accel = 12.0
			if st_t > 0.33 and not _shoved:
				_shoved = true
				velocity += _fwd() * 3.0
				Net.fx("sfx", ["whoosh", global_position, -6.0, 0.08, 1.3])
				if p and dist < SHOVE_RANGE and _fwd().dot(dir_p) > 0.2 and p.has_node("Hurtbox"):
					var hb := p.get_node("Hurtbox") as Hurtbox
					if hb.monitorable:
						var hd := HitData.new()
						hd.damage = 6.0
						hd.knockback_force = 7.0
						hd.knockdown = true  # the rifle butt puts you on the ground
						hd.stagger_duration = 0.4
						hd.hitstop_duration = 0.05
						hd.camera_shake_intensity = 0.12
						hb.take_hit(hd, self)
			if st_t > 0.75:
				_shove_cd = SHOVE_COOLDOWN
				_set_state(S.KEEP)
		S.RETURN:
			var to_post := _flat(post - global_position)
			if p and _player_ok(p) and dist < NOTICE_RANGE * 0.7:
				alert()
			elif to_post.length() > 0.6:
				var nd := _nav_dir(post, delta)
				_face(nd)
				want = nd * WALK_SPEED * 1.6
			else:
				global_position.x = post.x
				global_position.z = post.z
				if role != "rifle":
					humanoid.play("sheathe", 0.5)
				health.heal(MAX_HP)
				_enter_idle()

	# walked into something (tent, crate, rock): sidestep around it for a bit
	if _detour_t > 0.0:
		_detour_t -= delta
		if want.length() > 0.3:
			want = (want.normalized() * 0.4 + _detour * 0.9).normalized() * want.length()
	# stay out of the sea (a knockback can still put you in it)
	if state not in [S.HITSTUN, S.STAGGER, S.LEAP]:
		want = _avoid_water(want)
	if state == S.SWING and _attack == "lunge" and st_t < 0.32:
		hv = want
	else:
		hv = hv.move_toward(want, accel * delta)
	if _yank > 0.0:
		# reeled in on a vine: fly straight at the player
		_yank -= delta
		hv = _yank_v
		if _yank <= 0.0:
			hv *= 0.15
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
	humanoid.armed = in_combat() and role != "rifle" and state != S.AIM
	humanoid.sprinting = running
	# (a fighting grunt's blade and aim follow its pose: full detail)
	humanoid.lod = not in_combat()


func _lost(p: Node3D, dist: float) -> bool:
	if p == null:
		return true
	if boarder:
		return dist > 60.0
	if dist > GIVE_UP_RANGE or _flat(global_position - post).length() > LEASH:
		return true
	# the player swam off / is on the ship: give up after a while
	if not _player_ok(p) and str(p.call("current_state_name")) != "Downed" and st_t > 4.0:
		return true
	return false


func _go_home() -> void:
	_release_token()
	if boarder:
		post = global_position
	_set_state(S.RETURN)


## Boarding: jump from where it stands to `to`, landing in `t` seconds.
func leap(to: Vector3, t: float = 1.0) -> void:
	var d := to - global_position
	_leap_v = Vector3(d.x / t, 0.0, d.z / t)
	velocity = _leap_v + Vector3.UP * (d.y / t + 0.5 * GRAVITY * t)
	_face(Vector3(d.x, 0.0, d.z))
	facing.rotation.y = _yaw
	humanoid.seated = false
	humanoid.play("flip", minf(t, 0.9))
	bark(["Boarders away!", "Take the ship!", "Yaaargh!", "Over the side, lads!"], 0.8)
	_set_state(S.LEAP)


func _get_token() -> bool:
	if camp == null or not is_instance_valid(camp):
		_has_token = true
		return true
	_has_token = bool(camp.call("request_token", self))
	return _has_token


## Which way to run to reach `goal`: along the island's navmesh around huts,
## rocks and palms (NavBaker), or straight at it off the mesh (a ship's deck,
## an island not baked yet). Paths refresh twice a second or when the goal moves.
func _nav_dir(goal: Vector3, delta: float) -> Vector3:
	var straight := _flat(goal - global_position).normalized()
	_path_t -= delta
	if _path_t <= 0.0 or goal.distance_to(_path_goal) > 1.5:
		_path_t = _rng.randf_range(0.4, 0.6)
		_path_goal = goal
		_path_i = 1
		var map := get_world_3d().navigation_map
		var on_mesh := NavigationServer3D.map_get_closest_point(map, global_position).distance_to(global_position) < 1.2
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true) if on_mesh else PackedVector3Array()
	while _path_i < _path.size() and _flat(_path[_path_i] - global_position).length() < 0.8:
		_path_i += 1
	if _path_i >= _path.size():
		return straight
	return _flat(_path[_path_i] - global_position).normalized()


static var _enemies: Array = []
static var _enemies_tick: int = -1


## Everyone in the "enemies" group, fetched once per physics tick for all grunts.
func _all_enemies() -> Array:
	var f := Engine.get_physics_frames()
	if f != _enemies_tick:
		_enemies_tick = f
		_enemies = get_tree().get_nodes_in_group("enemies")
	return _enemies


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for g in _all_enemies():
		if not is_instance_valid(g):
			continue
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
## Pick the next attack (bosses override this).
func _choose_attack(dist: float) -> String:
	var a := "lunge" if dist > 2.9 and _rng.randf() < 0.55 else "combo"
	if _peril_cd <= 0.0 and _rng.randf() < 0.4:
		a = "peril"
		_peril_cd = _rng.randf_range(9.0, 14.0)
	return a


func _begin_attack(_dist: float) -> void:
	if _attack == "lunge":
		_start_wind()
	else:
		_set_state(S.CLOSE)


## Swings in a combo.
func _combo_hits() -> int:
	return 2


## Light hits the guard soaks up before it breaks.
func _guard_max() -> int:
	return GUARD_BLOCKS


func _wind_len() -> float:
	if _attack == "peril":
		return PERIL_WIND
	if _attack == "lunge":
		return 0.8
	return 0.6 if _swing_i == 0 else 0.32


func _start_wind() -> void:
	_glinted = false
	_set_state(S.WIND)
	if _attack == "peril":
		# one overhead chop spanning the wind-up and the swing
		humanoid.play("peril_chop", 2.6)
		hitbox.hit_data = _hit_peril
		_set_peril(true)
		Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 1.0])
		Net.fx("impact", [global_position + Vector3(0, 2.0, 0), Color(1.0, 0.15, 0.1)])
		Net.fx("sparkle", [global_position + Vector3(0, 2.1, 0), 8, Color(1.0, 0.2, 0.15)])
		return
	var anim := "lunge_wind" if _attack == "lunge" else ("wind_r" if _swing_i == 0 else "wind_l")
	humanoid.play(anim, _wind_len())
	# the heavy attack (lunge) announces itself: the blade glows yellow
	hitbox.hit_data = _hit_heavy if _attack == "lunge" else _hit_light
	if _attack == "lunge":
		_set_glow(true)
		_glow_t = HEAVY_GLOW
	# Observation Haki: you sense the intent the moment it forms
	_sense(_target())


## Observation Haki: the captain being targeted senses the attack coming (a
## red flash over the attacker) - on their own screen, since only they have
## the skill (co-op: the target may be on another machine).
func _sense(p: Node) -> void:
	if p == null:
		return
	if p.is_in_group("player"):
		_sense_fx()
	elif Net.coop():
		Net.event(self, "sense", [int(p.get("net_id"))])


func _sense_fx() -> void:
	var me := get_tree().get_first_node_in_group("player")
	if me and me.get("progression") and me.progression.has_flag("observation"):
		FX.sparkle(global_position + Vector3(0, 2.0, 0), 6, Color(1.0, 0.25, 0.2))
		FX.impact(global_position + Vector3(0, 1.9, 0), Color(1.0, 0.3, 0.25))


func _start_swing() -> void:
	_swung = false
	_glinted = false
	_set_state(S.SWING)
	hitbox.deactivate()
	if _attack == "peril":
		_lunge_dir = _fwd()
		Net.fx("sfx", ["whoosh_big", global_position, -2.0, 0.05, 0.8])
	elif _attack == "lunge":
		_lunge_dir = _fwd()
		humanoid.play("lunge", 0.8)
		Net.fx("sfx", ["whoosh", global_position, -4.0, 0.08, 1.15])
	else:
		humanoid.play("swing_r" if _swing_i == 0 else "swing_l", 0.5)
		velocity += _fwd() * 3.0
		Net.fx("sfx", ["whoosh", global_position, -5.0, 0.1, 1.0])


func _end_attack(recover: float) -> void:
	hitbox.deactivate()
	set_meta("recover", recover)
	_set_state(S.RECOVER)


## The tell: a flash on the blade just before it swings.
func _glint() -> void:
	var tip := global_position + Vector3(0, 1.6, 0)
	if humanoid.weapon and humanoid.weapon.is_inside_tree():
		tip = humanoid.weapon.global_transform * Vector3(0, 0, -0.75)
	Net.fx("sparkle", [tip, 4, Color(1.0, 1.0, 0.95)])
	Net.fx("sfx", ["blip_high", tip, -14.0, 0.05, 1.6])


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	_hit_by = attacker
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = _flat(global_position - (attacker as Node3D).global_position)
	dir = dir.normalized() if dir.length() > 0.01 else -_fwd()
	if hit.dot:
		# burning: just the damage (no flinch, no guard)
		Net.damage_number(hit.damage, global_position + Vector3(0, 1.9, 0))
		set_meta("last_dir", dir)
		_last_hit = null   # (burned to death: nothing to cut off)
		health.take_damage(hit.damage)
		if state == S.IDLE or state == S.RETURN:
			alert()
		return
	# on the ground (ragdoll) or getting up: it takes the hit, nothing else.
	# (Flinching from here used to drop it back into the fight while its body
	# was still a ragdoll - riflemen would keep shooting from the ground.)
	if state == S.DOWN or state == S.GETUP:
		_take_damage(hit, dir)
		if state == S.DEAD:
			return
		if state == S.DOWN and humanoid.ragdoll:
			humanoid.ragdoll.push(dir * minf(hit.knockback_force, 8.0) * 0.5 + Vector3.UP * 1.5)
		elif hit.knockdown:
			if hit.crumple:
				_crumple()
			else:
				_knock_down(dir * clampf(hit.knockback_force * 0.7, 4.0, 8.0) + Vector3.UP * 3.2)
		return
	if state == S.SWIM:
		_take_damage(hit, dir)
		if state == S.DEAD:
			return
		bark(BARK_HURT, 0.3)
		if hit.knockdown:
			_knock_down(dir * clampf(hit.knockback_force * 0.7, 4.0, 8.0) + Vector3.UP * 2.0)
		else:
			velocity += dir * minf(hit.knockback_force * 0.4, 3.0)
			Net.fx("splash", [Vector3(global_position.x, _surface(), global_position.z), 4, 0.6])
		return
	# the red wind-up: only Armament Haki breaks it; anything else just lands
	if _attack == "peril" and (state == S.WIND or (state == S.SWING and st_t < 0.34)):
		_take_damage(hit, dir)
		if state == S.DEAD:
			return
		if hit.haki or hit.breaker:
			_set_peril(false)
			hitbox.deactivate()
			_release_token()
			bark(BARK_PARRIED, 0.8)
			var at := global_position + Vector3(0, 1.4, 0)
			Net.fx("sparkle", [at, 14, Color(0.75, 0.45, 1.0)])
			Net.fx("impact", [at, Color(0.6, 0.3, 1.0)])
			Net.fx("sfx", ["haki", at, -6.0, 0.05, 1.3])
			get_node("/root/CombatManager").apply_hitstop(0.12, [_hit_by, self])
			velocity = dir * 4.0
			_stagger_len = 1.6
			humanoid.react("stagger", 1.6, dir)
			_set_state(S.STAGGER)
		else:
			Net.fx("sparkle", [global_position + Vector3(0, 1.6, 0), 4, Color(1.0, 0.3, 0.2)])
		return
	var from_front := _fwd().dot(-dir) > 0.3
	var guarding := role == "sword" and state in [S.CIRCLE, S.CHASE, S.ALERT, S.BLOCK, S.CLOSE]
	if state == S.IDLE or state == S.RETURN:
		alert()
		guarding = false

	# blocked: sparks, no damage (until the guard breaks)
	# (a cutlass can't stop a bullet)
	if guarding and from_front and not hit.knockdown and not hit.unblockable and not hit.ranged and not hit.breaker:
		if _guard_hits < _guard_max():
			_guard_hits += 1
			_guard_t = 3.5
			var spark := global_position + Vector3(0, 1.25, 0) - dir * 0.55
			Net.fx("impact", [spark, Color(1.0, 0.95, 0.7)])
			Net.fx("sparkle", [spark, 6, Color(1.0, 0.9, 0.5)])
			Net.fx("sfx", ["hit", spark, -2.0, 0.05, 1.8])
			get_node("/root/CombatManager").apply_hitstop(0.04, [_hit_by, self])
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
		Net.fx("sparkle", [global_position + Vector3(0, 1.5, 0), 10, Color(1.0, 0.8, 0.4)])
		_release_token()
		humanoid.react("stagger", 1.1, dir)
		velocity = dir * 3.0
		_set_state(S.STAGGER)
		return

	_take_damage(hit, dir)
	if state == S.DEAD:
		return
	bark(BARK_HURT, 0.3)
	_release_token()
	if hit.knockdown and hit.crumple:
		_crumple()
		return
	if hit.knockdown:
		_knock_down(dir * clampf(hit.knockback_force * 0.7, 4.0, 8.0) + Vector3.UP * 3.2)
		return
	if state == S.STAGGER:
		return  # already reeling: keep the punish window
	if hit.breaker:
		# caught mid-move: whatever it was winding up is gone
		hitbox.deactivate()
		velocity = dir * 2.5
		_stagger_len = 1.0
		humanoid.react("stagger", 1.0, dir)
		_set_state(S.STAGGER)
		return
	_stun_len = 0.28
	_stun_vel = dir * minf(hit.knockback_force * 0.6, 5.0)
	velocity = _stun_vel
	humanoid.react("hit", 0.32, dir)
	_set_state(S.HITSTUN)


func _take_damage(hit: HitData, dir: Vector3) -> void:
	Net.damage_number(hit.damage, global_position + Vector3(0, 1.9, 0))
	Net.fx("impact", [global_position + Vector3(0, 1.2, 0) - dir * 0.35, Color(1.0, 0.6, 0.45)])
	Net.fx("blood", [global_position + Vector3(0, 1.15, 0) - dir * 0.15, dir, clampi(int(hit.damage * 0.6), 6, 22)])
	Net.fx("sfx", ["hit", global_position, -2.0, 0.1, 1.05 if hit.damage < 20.0 else 0.85])
	_hit_feedback(hit)
	set_meta("last_dir", dir)
	_last_hit = hit
	health.take_damage(hit.damage)


## Its swing was parried: staggered, wide open.
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if state in [S.DEAD, S.DOWN]:
		return
	if state == S.AIM:
		return  # a deflected bullet: no stagger from across the beach
	hitbox.deactivate()
	_release_token()
	bark(BARK_PARRIED, 0.8)
	var dir := -_fwd()
	if by is Node3D:
		dir = _flat(global_position - (by as Node3D).global_position).normalized()
	velocity = dir * 3.5
	_stagger_len = 1.5
	humanoid.react("stagger", 1.5, dir)
	_set_state(S.STAGGER)


func _knock_down(v: Vector3) -> void:
	hitbox.deactivate()
	_drop_aim()
	_release_token()
	humanoid.start_ragdoll(v, Vector3.UP.cross(_flat(v).normalized()) * 5.0)
	_rest = 0.0
	_down_min = 1.0
	_set_state(S.DOWN)


## Cut down in place: the body goes limp and folds where it stood (no throw,
## no spin), and is back up after half a second or so.
func _crumple() -> void:
	hitbox.deactivate()
	_drop_aim()
	_release_token()
	velocity = Vector3.ZERO
	# (the cut carries the player straight through: don't get shoved along by them)
	set_collision_mask_value(2, false)
	humanoid.start_ragdoll(Vector3.DOWN * 0.5, Vector3.ZERO, false)
	_rest = 0.0
	_down_min = 0.6
	_set_state(S.DOWN)


func _down_update(delta: float) -> void:
	var rag := humanoid.ragdoll
	var hips := humanoid.hips.global_position
	var to := _flat(hips - global_position)
	velocity.x = to.x * 10.0
	velocity.z = to.z * 10.0
	# a body in deep water floats: the root rides with the hips
	var hip_depth := _surface(hips) - hips.y
	var deep := hip_depth > -0.3 and _water_depth_at(hips) > SWIM_ENTER_DEPTH
	if deep:
		var want_y := hips.y - humanoid.hip_y * humanoid.global_basis.get_scale().y
		velocity.y = clampf((want_y - global_position.y) * 10.0, -12.0, 8.0)
	else:
		velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if rag == null:
		_set_state(S.CIRCLE)
		return
	if deep:
		# sank in, now bobbing back up: right himself and swim for it
		var rb := rag.root_body()
		var vy := rb.linear_velocity.y if rb else 0.0
		if st_t > 1.0 and (hip_depth < FLOAT_DEPTH and vy > -0.6 or st_t > 4.0):
			var info := humanoid.ragdoll_rest_info()
			var face_up: bool = info["face_up"]
			var head_dir: Vector3 = info["head_dir"]
			var f := -head_dir if face_up else head_dir
			_yaw = atan2(-f.x, -f.z)
			facing.rotation.y = _yaw
			global_position.y = maxf(_float_target(), global_position.y - 0.3)
			humanoid.recover_from_ragdoll(face_up, info["hips_xform"], 0.7)
			_enter_swim(0.0, true)
		return
	if rag.settled():
		_rest += delta
	else:
		_rest = 0.0
	# (a crumple doesn't wait for the limp body to come fully to rest)
	var crumpled := _down_min < 1.0
	if st_t > _down_min and (_rest > (0.12 if crumpled else 0.3) or st_t > (1.0 if crumpled else 3.5)):
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
	_drop_aim()
	_set_glow(false)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	bark(BARK_DIE, 0.6)
	var dir: Vector3 = get_meta("last_dir", -_fwd())
	if humanoid.ragdoll == null:
		humanoid.start_ragdoll(dir * 5.0 + Vector3.UP * 3.0, Vector3.UP.cross(dir) * 5.0, false)
	else:
		humanoid.relax_ragdoll()
		humanoid.ragdoll.push(dir * 3.0)
	if _last_hit and _last_hit.sever and _rng.randf() < (1.0 if _last_hit.crumple else SEVER_CHANCE):
		# heads go a bit more often than either arm
		var r := _rng.randf()
		var part := "head" if r < 0.4 else ("arm_l" if r < 0.7 else "arm_r")
		humanoid.sever(part, dir * 2.2 + Vector3.UP * 2.6)
	_set_state(S.DEAD)
	_dead_t = 0.0
	Net.event(self, "die", [])
	Net.coins(global_position + Vector3(0, 1.0, 0), _rng.randi_range(3, 6))
	Net.award_xp(55 if role == "rifle" else 45, global_position + Vector3(0, 2.0, 0))
	_drop_weapon()
	died.emit(self)


## Sometimes the dead drop their sidearm: a pistol (or the rifleman's...
## nothing - those are too long to carry) or a cutlass.
func _drop_weapon() -> void:
	var roll := _rng.randf()
	var id := ""
	if role == "sword":
		if roll < 0.3:
			id = "pistol"
		elif roll < 0.45:
			id = _blade_id
	elif roll < 0.4:
		id = "pistol"
	if id == "":
		return
	# (in co-op every captain finds their own copy)
	Net.drop_item(id, global_position + Vector3(_rng.randf_range(-0.6, 0.6), 0.1, _rng.randf_range(-0.6, 0.6)), _rng.randf() * TAU)


## Vine Snare: tied in place for a while.
var _yank: float = 0.0
var _yank_v := Vector3.ZERO


## How a Vine grapple treats this enemy: "light" ones are yanked to the
## player, "heavy" ones pull the player to them.
func vine_weight() -> String:
	return "light"


## Vine grapple: reeled in to land just in front of `to`.
func vine_yank(to: Vector3, dmg: float = 4.0) -> void:
	if Net.forward(self, "vine_yank", [to, dmg]):
		return
	if state in [S.DEAD, S.DOWN, S.GETUP, S.SWIM]:
		return
	hitbox.deactivate()
	_drop_aim()
	_release_token()
	var d := _flat(to - global_position)
	var dist := maxf(d.length() - 1.5, 0.0)
	var secs := clampf(dist / 16.0, 0.12, 0.6)
	_yank = secs
	_yank_v = d.normalized() * (dist / secs) if d.length() > 0.01 else Vector3.ZERO
	velocity.y = 3.5
	_stagger_len = secs + 0.7
	humanoid.react("stagger", _stagger_len, d)
	_set_state(S.STAGGER)
	health.take_damage(dmg)
	Net.fx("vine_wrap", [self, secs + 0.3, 0.32])


func rooted(secs: float) -> void:
	if Net.forward(self, "rooted", [secs]):
		return
	if state in [S.DEAD, S.DOWN, S.GETUP, S.SWIM]:
		return
	hitbox.deactivate()
	_drop_aim()
	_release_token()
	_stagger_len = secs
	humanoid.play("stagger", secs)
	velocity = Vector3.ZERO
	_set_state(S.STAGGER)
	Net.fx("vine_wrap", [self, secs, 0.32])


## Held in a captain's grapple (they carry the body; it just can't act).
func grabbed(secs: float) -> void:
	if Net.forward(self, "grabbed", [secs]):
		return
	if state in [S.DEAD, S.DOWN, S.GETUP, S.SWIM]:
		return
	hitbox.deactivate()
	_drop_aim()
	_release_token()
	_stagger_len = secs
	humanoid.play("stagger", secs)
	velocity = Vector3.ZERO
	_set_state(S.STAGGER)


func _dead_update(delta: float) -> void:
	_dead_t += delta
	var rag := humanoid.ragdoll
	if _dead_t > 8.0 and _sink == 0.0:
		_sink = 0.001
		if rag:
			for part in rag.parts:
				(part["body"] as RigidBody3D).freeze = true
		var hp := humanoid.hips.global_position
		if _surface(hp) > hp.y - 0.3:
			FX.splash(Vector3(hp.x, _surface(hp), hp.z), 5, 0.6)
		else:
			FX.dust(hp, 8, 0.8)
	if _sink > 0.0:
		_sink += delta / 1.2
		if rag:
			rag.global_position += Vector3.DOWN * 0.6 * delta / 1.2
		else:
			global_position += Vector3.DOWN * 1.5 * delta / 1.2
		if _sink >= 1.0:
			queue_free()


# ==========================================================================
# Water
# ==========================================================================
func _surface(at: Vector3 = Vector3.INF) -> float:
	if _ocean == null:
		_ocean = get_node_or_null("/root/Ocean")
		if _ocean == null:
			return -INF
	return float(_ocean.call("get_wave_height", global_position if at == Vector3.INF else at))


## How far the feet are under the waves (negative on dry land).
func _surface_depth() -> float:
	return _surface() - global_position.y


## Surface to sea floor at a spot (INF where there's no bottom in reach).
func _water_depth_at(at: Vector3) -> float:
	if _ocean == null:
		_ocean = get_node_or_null("/root/Ocean")
		if _ocean == null:
			return -INF
	return float(_ocean.call("depth_at", at, [get_rid()]))


## Depth below the calm water line (sea floor under a spot).
func _calm_depth(at: Vector3) -> float:
	if _ocean == null:
		_ocean = get_node_or_null("/root/Ocean")
		if _ocean == null:
			return -INF
	return float(_ocean.call("depth_at", at, [get_rid()], true))


## Steer around the water's edge (and burning ground): if the way ahead goes into the sea, turn
## toward the nearest dry heading (or stop). Standing in the surf already,
## any heading back up the beach is fine.
func _avoid_water(want: Vector3) -> Vector3:
	var spd := want.length()
	if spd < 0.1:
		return want
	var d := want / spd
	var probe := maxf(1.0, spd * 0.35)
	var here := _calm_depth(global_position)
	# burning ground (Ember Field etc.) is avoided like the sea
	var tree := get_tree()
	var in_fire := FireZone.any_contains(tree, global_position, 0.3)
	var ok := func(dd: Vector3) -> bool:
		if not in_fire and (FireZone.any_contains(tree, global_position + dd * probe, 0.5) or FireZone.any_contains(tree, global_position + dd * probe * 0.5, 0.5)):
			return false
		var a := _calm_depth(global_position + dd * probe)
		if a <= WADE_MAX:
			return _calm_depth(global_position + dd * probe * 0.5) <= WADE_MAX or here > WADE_MAX
		return here > WADE_MAX and a < here - 0.05
	if ok.call(d):
		return want
	for a in [0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.2, -2.2]:
		var dd := d.rotated(Vector3.UP, float(a) * _strafe_dir)
		if ok.call(dd):
			return dd * spd * maxf(1.0 - absf(float(a)) * 0.3, 0.35)
	return Vector3.ZERO


func _enter_swim(entry_vy: float, quiet: bool = false) -> void:
	hitbox.deactivate()
	_drop_aim()
	_set_glow(false)
	_release_token()
	if not humanoid.current_action().is_empty():
		humanoid.stop_action()
	humanoid.seated = false
	humanoid.swimming = true
	_swim_vy = minf(entry_vy, 0.0) * 0.45
	_prev_float = INF
	_shore = Vector3.INF
	_shore_t = 0.0
	_swim_stuck = 0.0
	_swim_t = 0.0
	_bad_shores.clear()
	_set_state(S.SWIM)
	var at := Vector3(global_position.x, _surface(), global_position.z)
	if quiet:
		Net.fx("splash", [at, 3, 0.5])
	elif entry_vy < -5.0:
		Net.fx("splash", [at, 12, 1.0])
		Net.fx("sfx", ["splash", at, -2.0, 0.08, 0.85])
	else:
		Net.fx("splash", [at, 6, 0.7])
		Net.fx("sfx", ["splash", at, -6.0, 0.1, 1.05])


## Root height that floats the hips just under the surface (as the player).
func _float_target() -> float:
	var sc := humanoid.global_basis.get_scale().y
	return _surface() - lerpf(0.42, 0.34, clampf(_flat(velocity).length() / SWIM_SPEED, 0.0, 1.0)) * sc - humanoid.hip_y * sc


## The closest bit of beach to wade out onto: shallow, walkable, reachable.
func _find_shore() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var space := get_world_3d().direct_space_state
	var surf := _surface()
	var home := _flat(post - global_position)
	for r in [2.5, 4.0, 6.0, 9.0, 13.0, 18.0, 25.0]:
		for i in range(16):
			var a := TAU * float(i) / 16.0
			var c := global_position + Vector3(sin(a), 0.0, cos(a)) * float(r)
			var skip := false
			for b in _bad_shores:
				if _flat(c - (b as Vector3)).length() < 2.5:
					skip = true
					break
			if skip:
				continue
			var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, surf + 3.0, c.z), Vector3(c.x, surf - 30.0, c.z), 1)
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var g: Vector3 = hit["position"]
			var depth := surf - g.y
			# a beach: about at the water line, not a dock or a cliff face
			if depth > 0.6 or depth < -0.45 or (hit["normal"] as Vector3).y < 0.75:
				continue
			# nothing solid in the way at swimming height
			var lq := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, surf + 0.25, global_position.z), g + Vector3.UP * 0.5, 1)
			lq.exclude = [get_rid()]
			var lh := space.intersect_ray(lq)
			if not lh.is_empty() and (lh["position"] as Vector3).distance_to(g) > 1.2:
				continue
			# nearest wins; a slight pull toward home
			var score := float(r) - (0.15 * float(r) if home.length() > 0.1 and home.normalized().dot(Vector3(sin(a), 0, cos(a))) > 0.5 else 0.0)
			if score < best_d:
				best_d = score
				best = g
		if best != Vector3.INF:
			break
	return best


func _swim_update(delta: float) -> void:
	# open sea with no beach in reach (knocked overboard, a sunk ship's crew):
	# they drown instead of swimming forever
	_swim_t += delta
	if not net_puppet and not (self is PirateBoss) and ((_shore == Vector3.INF and _swim_t > SWIM_GIVE_UP) or _swim_t > SWIM_GIVE_UP * 3.0):
		vanish(true)
		return
	# swim back to shore: no fighting in the water
	_shore_t -= delta
	if _shore == Vector3.INF or _shore_t <= 0.0:
		_shore_t = 1.5
		var s := _find_shore()
		if s != Vector3.INF:
			_shore = s
	var dir := Vector3.ZERO
	if _shore != Vector3.INF:
		dir = _flat(_shore - global_position)
	elif _flat(post - global_position).length() > 0.5:
		dir = _flat(post - global_position)
	if dir.length() > 0.01:
		dir = dir.normalized()
		_face(dir)
	var hv := _flat(velocity).move_toward(dir * SWIM_SPEED, 6.0 * delta)
	# float: same spring as the player, riding the swell
	var target := _float_target()
	var tv := 0.0 if _prev_float == INF else clampf((target - _prev_float) / maxf(delta, 0.0001), -6.0, 6.0)
	_prev_float = target
	_swim_vy += ((target - global_position.y) * 14.0 + (tv - _swim_vy) * 7.5) * delta
	_swim_vy = clampf(_swim_vy, -12.0, 6.0)
	velocity = Vector3(hv.x, _swim_vy, hv.z)
	move_and_slide()
	facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(5.0 * delta, 1.0))
	_feed_body(hv, false)
	humanoid.armed = false
	humanoid.grounded = false
	# stuck against something: try another bit of shore
	if dir != Vector3.ZERO and _flat(get_real_velocity()).length() < 0.4 and st_t > 1.0:
		_swim_stuck += delta
		if _swim_stuck > 1.5:
			_swim_stuck = 0.0
			if _shore != Vector3.INF:
				_bad_shores.append(_shore)
				if _bad_shores.size() > 12:
					_bad_shores.pop_front()
			_shore = Vector3.INF
	else:
		_swim_stuck = 0.0
	_ripple_t -= delta
	if _ripple_t <= 0.0:
		_ripple_t = 0.5 if hv.length() > 0.5 else 1.1
		Net.fx("splash", [Vector3(global_position.x, _surface(), global_position.z) + hv.normalized() * 0.4, 2, 0.4])
	# made it out: back to the fight (or home)
	if is_on_floor() and _surface_depth() < SWIM_EXIT_DEPTH:
		_leave_water()


func _leave_water() -> void:
	humanoid.swimming = false
	_swim_vy = 0.0
	var p := _target()
	var dist := _flat(p.global_position - global_position).length() if p else INF
	if p and _player_ok(p) and dist < GIVE_UP_RANGE and _flat(global_position - post).length() < LEASH:
		_cooldown = 0.8
		_set_state(S.KEEP if role == "rifle" else S.CHASE)
	else:
		_set_state(S.RETURN)


# ==========================================================================
# Firearms
# ==========================================================================
## Out of sword reach: now and then a swordsman pulls his pistol.
func _want_pistol(p: Node3D, dist: float, delta: float) -> bool:
	if role != "sword" or _pistol_cd > 0.0 or dist < PISTOL_RANGE or dist > GUN_RANGE * 0.5:
		return false
	if not _player_ok(p) or _rng.randf() > PISTOL_CHANCE * delta:
		return false
	return _los(p) and _guns_free()


## No more than two guns aimed at you at once.
func _guns_free() -> bool:
	var n := 0
	for g in _all_enemies():
		if is_instance_valid(g) and g != self and g is PirateGrunt and (g as PirateGrunt).state == S.AIM:
			n += 1
	return n < 2


func _chest(p: Node3D) -> Vector3:
	return p.global_position + Vector3(0, 1.1, 0)


func _los(p: Node3D) -> bool:
	if p == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), _chest(p), 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _start_aim(gun: String) -> void:
	_release_token()
	_gun = gun
	_fired = false
	_aim_len = PISTOL_AIM if gun == "pistol" else RIFLE_AIM
	_lock_len = PISTOL_LOCK if gun == "pistol" else RIFLE_LOCK
	if gun == "pistol":
		humanoid.set_weapon(Props.weapon_mesh("pistol"))
		humanoid._attach_weapon(true)
	var p := _target()
	_aim_point = _chest(p) if p else global_position + _fwd() * 10.0
	_set_state(S.AIM)
	humanoid.play("aim_pistol" if gun == "pistol" else "aim_rifle", _aim_len + 0.3)
	_aim_mat.albedo_color = AIM_TRACK
	_locked = false
	_aim_line.visible = true
	Net.fx("sfx", ["blip_low", global_position, -10.0, 0.05, 0.7])
	bark(["Hold still...", "Got you now.", "Steady..."], 0.3)


## Track the target (lagging a little, so moving makes it miss), then lock.
func _aim_update(p: Node3D, delta: float) -> void:
	var locked := st_t >= _aim_len - _lock_len
	if not locked and p:
		var to := _chest(p) + _flat(p.get("velocity") if p is CharacterBody3D else Vector3.ZERO) * 0.1
		_aim_point = _aim_point.lerp(to, minf(7.0 * delta, 1.0))
		_face(_flat(_aim_point - global_position))
	if locked and not _locked:
		_locked = true
		_aim_mat.albedo_color = AIM_LOCKED
		Net.fx("sfx", ["blip_high", global_position, -12.0, 0.03, 1.2])
	var muzzle := _muzzle()
	var d := _aim_point - muzzle
	humanoid.aim_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.6)


func _muzzle() -> Vector3:
	var w := humanoid.weapon
	if w and w.is_inside_tree():
		return w.global_transform * Vector3(0, 0.06, -(1.35 if _gun == "rifle" else 0.4))
	return global_position + Vector3(0, 1.4, 0) + _fwd() * 0.6


## Where the shot would end: the first wall along the line (or max range).
func _shot_end(from: Vector3) -> Vector3:
	var dir := (_aim_point - from).normalized()
	var to := from + dir * GUN_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return to if hit.is_empty() else (hit["position"] as Vector3)


func _fire(p: Node3D) -> void:
	_fired = true
	var from := _muzzle()
	var end := _shot_end(from)
	var big := _gun == "rifle"
	var shot_dir := (end - from).normalized()
	# muzzle flash, a spray of sparks and a cloud of powder smoke (readable
	# from across the beach), plus a thin smoke trail along the shot
	Net.fx("impact", [from, Color(1.0, 0.85, 0.5)])
	Net.fx("muzzle_sparks", [from, shot_dir, 14 if big else 9])
	Net.fx("smoke", [from + shot_dir * 0.3, 10 if big else 6, 1.1 if big else 0.8, 1.8])
	var length := from.distance_to(end)
	var n := mini(int(length / 1.6), 18)
	for k in range(1, n + 1):
		Net.fx("smoke", [from + shot_dir * (length * float(k) / float(n + 1)), 1, 0.55, 1.3])
	Net.fx("sfx", ["gunshot", from, 2.0 if big else 0.0, 0.06, 0.85 if big else 1.0])
	get_node("/root/CombatManager").apply_camera_shake(0.06)
	_aim_mat.albedo_color = AIM_FIRE
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self):
			_aim_line.visible = false)
	set_meta("shot_end", end)
	# only whoever is on the line gets hit (dodge i-frames make it pass
	# through); in co-op each captain checks the line on their own screen
	var hd := HitData.new()
	hd.ranged = true
	hd.damage = 10.0 if _gun == "pistol" else 15.0
	hd.knockback_force = 3.0 if _gun == "pistol" else 4.0
	hd.stagger_duration = 0.3
	hd.hitstop_duration = 0.05
	hd.camera_shake_intensity = 0.16
	var hit_player := Net.shot(from, end, hd, self)
	if not hit_player:
		Net.fx("dust", [end, 5, 0.5])
		Net.fx("sparkle", [end, 3, Color(1.0, 0.8, 0.5)])


## Shortest distance between segments p1-q1 and p2-q2.
static func _seg_seg_dist(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var pts := Geometry3D.get_closest_points_between_segments(p1, q1, p2, q2)
	return (pts[0] as Vector3).distance_to(pts[1] as Vector3)


func _end_aim() -> void:
	_aim_line.visible = false
	humanoid.aim_pitch = 0.0


## Interrupted (hit, knocked down, killed): put the pistol away.
func _drop_aim() -> void:
	_aim_line.visible = false
	if _gun == "pistol" and role == "sword":
		humanoid.set_weapon(Props.weapon_mesh(_blade_model))
		humanoid._attach_weapon(true)
		_pistol_cd = PISTOL_COOLDOWN * 0.5
	_gun = ""


## After a shot: run to a new spot 11-15 m from the target with a clear line.
func _start_reposition(p: Node3D) -> void:
	_set_state(S.REPOSITION)
	_repos_target = global_position
	if p == null:
		return
	var best := INF
	for i in range(10):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(11.0, 15.0)
		var c := p.global_position + Vector3(cos(a), 0, sin(a)) * r
		if _flat(c - post).length() > LEASH - 2.0:
			continue
		# stand on the ground there
		var down := PhysicsRayQueryParameters3D.create(c + Vector3(0, 12, 0), c + Vector3(0, -12, 0), 1)
		var g := get_world_3d().direct_space_state.intersect_ray(down)
		if g.is_empty():
			continue
		c = g["position"]
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.5, 0), _chest(p), 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var cost := c.distance_to(global_position)
		if cost < 3.0:
			cost += 6.0  # actually move somewhere
		if cost < best:
			best = cost
			_repos_target = c
	if best == INF:
		# nowhere better in reach: close in a bit instead
		_repos_target = global_position + _flat(p.global_position - global_position) * 0.4


func _start_shove() -> void:
	_shoved = false
	_set_state(S.SHOVE)
	humanoid.play("shove", 0.75)
	bark(["Back off!", "Get away!", "Too close!"], 0.5)


## Flash red all over (and a red-hot blade) for the unblockable attack.
func _set_peril(on: bool) -> void:
	_peril_on = on
	if _peril_mat == null:
		_peril_mat = StandardMaterial3D.new()
		_peril_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_peril_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_peril_mat.albedo_color = Color(1.0, 0.08, 0.05, 0.4)
		_peril_blade = StandardMaterial3D.new()
		_peril_blade.albedo_color = Color(1.0, 0.2, 0.12)
		_peril_blade.emission_enabled = true
		_peril_blade.emission = Color(1.0, 0.1, 0.05)
		_peril_blade.emission_energy_multiplier = 1.6
	if humanoid == null:
		return
	for mi in humanoid.find_children("*", "MeshInstance3D", true, false):
		if mi == humanoid.weapon:
			(mi as MeshInstance3D).material_override = _peril_blade if on else null
		else:
			(mi as MeshInstance3D).material_overlay = _peril_mat if on else null


func _set_glow(on: bool) -> void:
	if humanoid.weapon == null:
		return
	if on:
		if _glow_mat == null:
			_glow_mat = PSXMat.lit("metal", Color(1.0, 0.95, 0.65), {"emission": Color(1.0, 0.78, 0.2), "emission_energy": 1.3})
		humanoid.weapon.material_override = _glow_mat
	else:
		humanoid.weapon.material_override = null


func _process(delta: float) -> void:
	if net_puppet:
		_net_update(delta)
	if _peril_on and _peril_mat:
		_peril_mat.albedo_color.a = 0.18 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.012))
	if _glow_t > 0.0:
		_glow_t -= delta
		if _glow_t <= 0.0:
			_set_glow(false)
	if state == S.DEAD or humanoid == null:
		return
	var w := humanoid.weapon
	# point the gun: at the aim point while aiming, held across the body otherwise
	if w and w.is_inside_tree() and w.get_parent() == humanoid.hand_r:
		var grip := w.global_position
		if state == S.AIM and _gun != "":
			var d := _aim_point - grip
			if d.length() > 0.2:
				w.global_basis = Basis.looking_at(d.normalized(), Vector3.UP)
		elif role == "rifle" and humanoid.ragdoll == null and not humanoid.swimming and humanoid.current_action() != "shove":
			w.global_basis = facing.global_basis * Basis.from_euler(Vector3(0.75, 0.25, 0.85))
		# riflemen keep the off hand on the stock, whatever the pose
		if role == "rifle" and humanoid.ragdoll == null and not humanoid.swimming:
			# grab the forestock as far forward as the arm reaches
			var sh := humanoid.arm_l.global_position
			var reach := (humanoid.fore_l.position.length() + humanoid.hand_l.position.length()) * humanoid.global_basis.get_scale().x * 0.95
			var stock := w.global_transform * Vector3(0, -0.01, -0.15)
			for z in [-0.6, -0.5, -0.4, -0.3, -0.2]:
				var c := w.global_transform * Vector3(0, -0.01, z)
				if c.distance_to(sh) < reach:
					stock = c
					break
			humanoid.reach_left_hand(stock, facing.global_basis * Vector3(-1.0, -1.3, 0.4).normalized())
	# the aim line: muzzle to where the shot will land
	if _aim_line.visible:
		var from := _muzzle()
		var end: Vector3 = get_meta("shot_end", _aim_point) if _fired else _shot_end(from)
		var seg := end - from
		var l := seg.length()
		if l > 0.05:
			var th := 0.045 if _locked else 0.03
			_aim_line.global_transform = Transform3D(Basis.looking_at(seg / l, Vector3.UP).scaled_local(Vector3(th, th, l)), from + seg * 0.5)


func _exit_tree() -> void:
	if humanoid:
		humanoid.end_ragdoll()


# ==========================================================================
# Co-op
# ==========================================================================
## Hit feedback (hitstop, shake) is for whoever landed the blow (a guest's
## own blows get theirs in Net.route_hit).
func _hit_feedback(hit: HitData) -> void:
	if not Net.active or _hit_by == Net.local_player:
		get_node("/root/CombatManager").apply_hit_effects(hit, [_hit_by, self])


func hit_freeze(duration: float) -> void:
	humanoid.freeze(duration)


## More captains, more health (keeps the share of health it has left).
func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = MAX_HP * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


func _hit_kind() -> int:
	if hitbox.hit_data == _hit_peril:
		return 2
	return 1 if hitbox.hit_data == _hit_heavy else 0


## Host: what the puppets need, ~20 times a second.
func net_pack() -> Array:
	humanoid.net_sync = true
	var glow := humanoid.weapon != null and humanoid.weapon.material_override == _glow_mat and _glow_mat != null
	# on a ship's deck (boarders, a pirate crew): deck-relative, so they ride it on every screen
	var at := Net.deck_pack(global_position)
	return [at[0], facing.rotation.y, velocity, int(state), health.current_health, health.max_health,
		HumanoidSync.pack(humanoid), hitbox.active, hitbox.activations, _hit_kind(),
		_aim_line.visible, _aim_point, _locked, _fired, _gun, glow, _peril_on,
		_bark.text if _bark.visible else "", get_meta("shot_end", Vector3.ZERO),
		humanoid.ragdoll.net_pack() if humanoid.ragdoll else [], at[1]]


## Puppet: play back the host's grunt.
func _net_update(delta: float) -> void:
	_bark_t -= delta
	_net_hb_t -= delta
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	if b.size() < 21 or a.size() < 21:
		return
	# a body on the ground (or floating, or dead) lies where the host's does
	if humanoid.ragdoll and (b[19] as Array).size() > 0:
		humanoid.ragdoll.net_follow(a[19], b[19], f)
	if state == S.DEAD:
		return
	var st := int(a[3])  # (discrete state from the older snapshot: in step with events)
	if st == S.DEAD:
		_net_die()  # (we joined after it fell, or missed the moment)
		return
	global_position = Net.deck_unpack(a[0], str(a[20])).lerp(Net.deck_unpack(b[0], str(b[20])), f)
	facing.rotation.y = lerp_angle(float(a[1]), float(b[1]), f)
	_yaw = facing.rotation.y
	velocity = b[2]
	if st != state:
		state = st as S
		st_t = 0.0
	health.max_health = float(b[5])
	health.current_health = float(b[4])
	HumanoidSync.apply(humanoid, a[6], b[6], f)
	# the sword hitbox: every new swing on the host swings here too, so it
	# can hit this machine's captain
	var kind := int(a[9])
	var serial := int(a[8])
	if serial != _net_serial:
		var first := _net_serial < 0
		_net_serial = serial
		if not first:
			# (a quick swing can start and end between two snapshots)
			hitbox.activate(_hit_peril if kind == 2 else (_hit_heavy if kind == 1 else _hit_light))
			_net_hb_t = 0.1
	if hitbox.active and not bool(a[7]) and _net_hb_t <= 0.0:
		hitbox.deactivate()
	# gun aim line
	_aim_line.visible = bool(a[10])
	_aim_point = (a[11] as Vector3).lerp(b[11], f)
	_locked = bool(a[12])
	_fired = bool(a[13])
	_gun = str(a[14])
	if _fired:
		set_meta("shot_end", a[18])
	_aim_mat.albedo_color = AIM_FIRE if _fired else (AIM_LOCKED if _locked else AIM_TRACK)
	if bool(a[15]) != _net_glow:
		_net_glow = bool(a[15])
		_set_glow(_net_glow)
	if bool(a[16]) != _peril_on:
		_set_peril(bool(a[16]))
	var txt := str(a[17])
	if txt != "" and (txt != _bark.text or not _bark.visible):
		_bark.text = txt
		_bark.visible = true
	elif txt == "" and _bark.visible:
		_bark.visible = false


func _net_die() -> void:
	if state == S.DEAD:
		return
	hitbox.deactivate()
	_aim_line.visible = false
	_set_glow(false)
	_set_peril(false)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	if humanoid.ragdoll == null:
		var dir := -_fwd()
		humanoid.start_ragdoll(dir * 4.0 + Vector3.UP * 2.0, Vector3.ZERO, false)
	state = S.DEAD
	_dead_t = 0.0
	died.emit(self)


## Gone without a fight, no loot or XP: a swimmer who can't reach land sinks,
## a boarder left behind with no captain near just slips away.
func vanish(sink: bool) -> void:
	Net.event(self, "vanish", [sink])
	_vanish(sink)


func _vanish(sink: bool) -> void:
	if state == S.DEAD:
		return
	hitbox.deactivate()
	_drop_aim()
	_set_glow(false)
	_set_peril(false)
	_release_token()
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	collision_layer = 0
	state = S.DEAD
	if not sink:
		queue_free()
		return
	FX.splash(Vector3(global_position.x, _surface(), global_position.z), 6, 0.6)
	_dead_t = 8.0
	_sink = 0.001


## No captain within LEFT_BEHIND_RANGE for LEFT_BEHIND_SECS (checked once a second).
func _left_behind(delta: float) -> bool:
	_far_t -= delta
	if _far_t > 0.0:
		return false
	_far_t = 1.0
	for c in get_tree().get_nodes_in_group("players"):
		if (c as Node3D).global_position.distance_to(global_position) < LEFT_BEHIND_RANGE:
			_far_n = 0
			return false
	_far_n += 1
	return _far_n >= LEFT_BEHIND_SECS


func net_event(what: String, args: Array) -> void:
	match what:
		"die":
			_net_die()
		"vanish":
			_vanish(bool(args[0]))
		"sense":
			var me := get_tree().get_first_node_in_group("player")
			if me and int(me.get("net_id")) == int(args[0]):
				_sense_fx()
		"burn_fx":
			BurnStatus.apply(self, float(args[0]), 0.0, null)
