extends PirateGrunt
class_name JungleApe
## The jungle's beast boss (BeastArena): a silverback nearly twice a man's height
## reared up, on the same rig as everyone (Humanoid, look "beast": "ape" builds
## ApeBuilder's gorilla body, height APE_H, stance "ape": the knuckle-walk;
## ApePoses for its moves). Its own brain, the grunt's body: death, ragdoll and
## co-op puppets come from PirateGrunt.
##
## Asleep at its post until the arena wakes it: a chest-beating roar (a
## shockwave: jump or dodge it), then it knuckle-runs you down and picks by
## range: the backhand swipe up close (parry it), the two-fist slam (a red
## ring in front of it), a leap onto you from afar (a ring where it lands), or
## it rips up a boulder and hurls it (a ring where it'll come down).
## Below 60% it roars and takes to the trees: it bounds up onto a limb of the
## arena's ring of giants and is gone into the canopy. Up there it runs the
## ring from limb to limb (crowns shake, leaves come down, its grunts and the
## rustle move round you, now and then a glimpse of it crouched on a branch),
## hurls boulders down from wherever it is (it shows itself to throw: the
## branch thrashes, a ring where it lands), then rears up on a limb roaring and
## crashes down onto you (a wide ring). Shoot or strike it while it shows
## itself and it's knocked out of the tree, stunned where it lands. Below 30%
## it's enraged: quicker, the cooldowns shorter, more boulders, back up sooner.
## No knockdowns: poise built up by hits staggers it, and Armament Haki (or a
## guard-breaker) knocks it out of a slam's or a leap's wind-up.
## Co-op: host-run; the shockwaves are judged on each captain's own machine
## (event "aoe"), the boulder flies on every screen (event "rock"), the crowns
## shake on every screen (event "shake"), up or showing itself rides the snapshot.

signal phase_changed(phase: int)

const APE_HP := 1500.0
## Look height: the rig's scale (ApeBuilder's unit body): ~3.5 m reared up, ~2.3 m on its knuckles.
const APE_H := 2.4
const HURT_FWD := 0.45
const RUN := 6.2
const SWIPE_RANGE := 4.9
const SLAM_R := 4.8
const LEAP_R := 5.4
const ROAR_R := 7.5
const ROCK_R := 3.6
const POISE := 220.0
const POISE_DECAY := 30.0
const FUR := Color(0.21, 0.19, 0.18)
const SILVER := Color(0.7, 0.7, 0.68)
const ROAR_LEN := 2.0
const SLAM_WIND := 0.6
const LEAP_WIND := 0.45
const LEAP_AIR := 0.9
const LIFT_LEN := 0.9
const HURL_LEN := 0.6
## The canopy: up a limb, round the ring, boulders down, then down onto you.
const CLIMB_WIND := 0.5
const CLIMB_AIR := 1.0
const HOP := [1.5, 1.1]
const THROWS := [3, 4]
const CANOPY_CD := [30.0, 22.0]
const GLIMPSE := 0.6
const TREE_WIND := 0.75
const DROP_WARN := 1.3
const DROP_AIR := 0.7
const DROP_R := 6.2
## Taking this share of its health while it shows itself up there knocks it out of the tree.
const KNOCK_DOWN := 0.035
const FALL_STUN := 3.0

var phase: int = 1
var arena: Node = null
var boss_name: String = "The Silverback"
var _special: String = ""
var _sp_t: float = 0.0
var _sp_from := Vector3.ZERO
var _sp_target := Vector3.ZERO
var _sp_hit: bool = false
var _cd := {"swipe": 0.0, "slam": 3.0, "leap": 6.0, "throw": 5.0, "canopy": 0.0}
var _poise: float = 0.0
var _hit_swipe: HitData
var _rock: MeshInstance3D
var _rocks: Array = []   # [node, from, to, t, dur] flying
## Up in the canopy: the limb it's on (index into arena.trees), or -1 on the ground.
var up: bool = false
var _perch: int = -1
var _hop_to: int = -1
var _hop_len: float = 1.3
var _hop_dir: int = 1
var _throws: int = 0
var _rustle_t: float = 0.0
var _show_t: float = 0.0
var _tree_hits: float = 0.0


static func ape_look() -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge({"name": "Silverback", "beast": "ape", "body": "masc", "build": "broad", "height": APE_H, "skin": FUR,
		"head": "square", "nose": "broad", "eyes": 1, "brows": 3, "mouth": 3, "eye_color": Color(0.55, 0.3, 0.1), "marks": "none",
		"hair": "bald", "facial_hair": "none", "hat": "none", "top": "bare", "sleeves": "none", "vest": "none", "coat": "none",
		"legs": "shorts", "legs_color": FUR, "feet": "barefoot", "belt": "none", "gloves": false, "scarf": false, "earring": false,
		"eyepatch": false, "pouch": false}, true)
	return lk


func _ready() -> void:
	look = JungleApe.ape_look()
	role = "ape"
	super._ready()
	add_to_group("bosses")
	humanoid.set_weapon(null)
	humanoid.stance = "ape"
	# a body to match (the grunt's were made for a man)
	var cap := _col.shape as CapsuleShape3D
	cap.radius = 1.05
	cap.height = 3.0
	_col.position = Vector3(0, 1.5, 0)
	var hcap := (hurtbox.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	hcap.radius = 1.45
	hcap.height = 3.8
	_hurt_follow()
	var bs := hitbox.get_child(0) as CollisionShape3D
	(bs.shape as BoxShape3D).size = Vector3(5.2, 2.8, 4.2)
	bs.position = Vector3(0, 1.4, -2.7)
	_hit_swipe = HitData.new()
	_hit_swipe.damage = _dmg(22.0)
	_hit_swipe.knockback_force = 10.0
	_hit_swipe.stagger_duration = 0.5
	_hit_swipe.hitstop_duration = 0.1
	_hit_swipe.camera_shake_intensity = 0.3
	hitbox.hit_data = _hit_swipe
	_bark.position.y = 5.0


## The hurtbox rides forward over the chest and arms (it knuckle-walks ahead of its feet).
func _hurt_follow() -> void:
	(hurtbox.get_child(0) as CollisionShape3D).position = facing.basis * Vector3(0, 1.9, -HURT_FWD)


## The camera draws back for this fight (CameraRig): 1 while it fights within reach of us.
func camera_room(from: Vector3) -> float:
	if state == S.DEAD or not in_combat():
		return 0.0
	return 1.0 - smoothstep(26.0, 34.0, from.distance_to(global_position))


func is_fighting() -> bool:
	return in_combat()


func asleep() -> bool:
	return state == S.IDLE


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": SILVER}, "Silverback Pelt", t)


## Woken (the arena, or a hit): it rears up and roars first.
func alert(_delay: float = 0.0) -> void:
	if state != S.IDLE and state != S.RETURN:
		return
	humanoid.seated = false
	_begin_special("roar")


# ==========================================================================
# Brain
# ==========================================================================
func _physics_process(delta: float) -> void:
	_fly_rocks(delta)
	_hurt_follow()
	if net_puppet or state in [S.DEAD, S.DOWN] or humanoid.ragdoll != null:
		super._physics_process(delta)
		_rock_follow()
		return
	st_t += delta
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
	for k in _cd.keys():
		_cd[k] -= delta * (1.6 if phase >= 3 else (1.25 if phase == 2 else 1.0))
	_poise = maxf(_poise - POISE_DECAY * delta, 0.0)
	_phase_check()
	_rock_follow()
	if _special != "":
		_special_update(delta)
		return
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var p := _target()
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var want := Vector3.ZERO
	var running := false
	match state:
		S.IDLE:
			_yaw = post_yaw
		S.CHASE:
			if p == null or not _player_ok(p):
				pass
			else:
				var nd := _nav_dir(p.global_position, delta)
				_face(to_p)
				var pick := _choose(dist)
				if pick != "":
					_begin_special(pick)
					return
				if dist > SWIPE_RANGE - 0.6:
					want = nd * RUN * (1.2 if phase >= 3 else 1.0)
					running = true
		S.RECOVER:
			if st_t > float(get_meta("recover", 0.5)):
				_set_state(S.CHASE)
		S.STAGGER:
			if st_t > _stagger_len:
				_set_state(S.CHASE)
		S.RETURN:
			var home := _flat(post - global_position)
			if home.length() < 1.5:
				_set_state(S.IDLE)
			else:
				_face(home)
				want = home.normalized() * RUN * 0.6
		_:
			_set_state(S.CHASE)
	var hv := _flat(velocity).move_toward(want, 24.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(7.0 * delta, 1.0))
	_feed_body(hv, running)


func _choose(dist: float) -> String:
	if phase >= 2 and _cd["canopy"] <= 0.0 and arena != null and not (arena.trees as Array).is_empty():
		return "climb"
	if dist < SWIPE_RANGE and _cd["swipe"] <= 0.0:
		if dist < 5.5 and _cd["slam"] <= 0.0 and _rng.randf() < 0.35:
			_cd["slam"] = _rng.randf_range(5.0, 7.0)
			return "slam"
		_cd["swipe"] = _rng.randf_range(1.0, 1.8)
		return "swipe"
	if dist > 7.0 and dist < 22.0 and _cd["leap"] <= 0.0 and _rng.randf() < 0.6:
		_cd["leap"] = _rng.randf_range(7.0, 10.0)
		return "leap"
	if dist > 9.0 and dist < 30.0 and _cd["throw"] <= 0.0:
		_cd["throw"] = _rng.randf_range(6.0, 9.0)
		return "throw"
	return ""


func _phase_check() -> void:
	var f := health_frac()
	if phase == 1 and f < 0.6:
		phase = 2
		_cd["canopy"] = 0.0
		if not up:
			_begin_special("roar")
		phase_changed.emit(2)
	elif phase == 2 and f < 0.3:
		phase = 3
		if not up:
			_begin_special("roar")
		phase_changed.emit(3)


# ==========================================================================
# Specials
# ==========================================================================
func _begin_special(what: String) -> void:
	hitbox.deactivate()
	_special = what
	_sp_t = 0.0
	_sp_hit = false
	_set_state(S.WIND)
	_attack = what
	var p := _target()
	match what:
		"roar":
			humanoid.play("ape_beat", ROAR_LEN)
			Net.fx("sfx", ["roar", global_position, 6.0, 0.03, 0.7])
		"swipe":
			humanoid.play("ape_swipe", ActionSpecs.length("ape_swipe"))
			Net.fx("sfx", ["whoosh_big", global_position, -2.0, 0.05, 0.7])
		"slam":
			humanoid.hold("ape_slam_wind", SLAM_WIND)
			_sp_target = _ground_at(global_position + _fwd() * 3.2)
			Net.fx("telegraph", [_sp_target, SLAM_R, SLAM_WIND + 0.18, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.7])
		"leap":
			_sp_from = global_position
			_sp_target = _ground_at(p.global_position if p else global_position + _fwd() * 10.0)
			_face(_flat(_sp_target - global_position))
			humanoid.hold("ape_crouch", LEAP_WIND)
			Net.fx("telegraph", [_sp_target, LEAP_R, LEAP_WIND + LEAP_AIR, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.65])
		"throw":
			humanoid.hold("ape_lift", LIFT_LEN)
		"climb":
			_cd["canopy"] = CANOPY_CD[0 if phase < 3 else 1] + _rng.randf_range(-3.0, 3.0)
			_throws = THROWS[0 if phase < 3 else 1]
			_perch = _nearest_perch()
			_hop_dir = 1 if _rng.randf() < 0.5 else -1
			_sp_from = global_position
			_sp_target = _perch_at(_perch)
			_face(_flat(_sp_target - global_position))
			humanoid.hold("ape_crouch", CLIMB_WIND)
			_say("grunt", global_position, 4.0, 0.9)


func _ground_at(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 14.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _special_update(delta: float) -> void:
	_sp_t += delta
	st_t += delta
	var want := Vector3.ZERO
	var grounded := true
	var p := _target()
	match _special:
		"roar":
			if _sp_t > ROAR_LEN * 0.8 and not _sp_hit:
				_sp_hit = true
				_aoe(global_position, ROAR_R, 10.0, true)
				Net.fx("dust_ring", [global_position, 30, 2.2])
				get_node("/root/CombatManager").apply_camera_shake(0.35)
			if _sp_t > ROAR_LEN:
				_end_special(0.2)
		"swipe":
			var len := ActionSpecs.length("ape_swipe")
			var u := _sp_t / len
			if u < 0.4 and p:
				_face(_flat(p.global_position - global_position))
			if u > 0.36 and u < 0.52:
				want = _fwd() * 5.0
			if u > 0.42 and not _sp_hit:
				_sp_hit = true
				hitbox.hit_data = _hit_swipe
				hitbox.activate()
			if u > 0.6:
				hitbox.deactivate()
			if u >= 1.0:
				_end_special(0.5)
		"slam":
			if _sp_t > SLAM_WIND and not has_meta("slam_down"):
				set_meta("slam_down", true)
				humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
			if _sp_t > SLAM_WIND + 0.18 and not _sp_hit:
				_sp_hit = true
				_aoe(_sp_target, SLAM_R, 26.0, true)
				Net.fx("dust_ring", [_sp_target, 28, 1.8])
				Net.fx("impact", [_sp_target + Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.3)])
				Net.fx("sfx", ["thud", _sp_target, 6.0, 0.05, 0.5])
				get_node("/root/CombatManager").apply_camera_shake(0.4)
			if _sp_t > SLAM_WIND + 0.8:
				remove_meta("slam_down")
				_end_special(0.9)
		"leap":
			if _sp_t < LEAP_WIND:
				_face(_flat(_sp_target - global_position))
			elif not _sp_hit:
				var u := clampf((_sp_t - LEAP_WIND) / LEAP_AIR, 0.0, 1.0)
				if humanoid.current_action() != "ape_air":
					humanoid.hold("ape_air")
				var flat := _sp_from.lerp(_sp_target, u)
				global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u) + sin(u * PI) * 6.0, flat.z)
				velocity = Vector3.ZERO
				grounded = false
				if u >= 1.0:
					_sp_hit = true
					humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
					_aoe(global_position, LEAP_R, 30.0, true)
					Net.fx("dust_ring", [global_position, 32, 2.0])
					Net.fx("impact", [global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.3)])
					Net.fx("sfx", ["thud", global_position, 7.0, 0.05, 0.45])
					get_node("/root/CombatManager").apply_camera_shake(0.45)
			elif _sp_t > LEAP_WIND + LEAP_AIR + 0.8:
				_end_special(1.0)
		"throw":
			if p and _sp_t < LIFT_LEN + HURL_LEN * 0.25:
				_face(_flat(p.global_position - global_position))
			if _sp_t > LIFT_LEN * 0.35 and _rock == null and not _sp_hit:
				_grab_rock()
				Net.event(self, "rock", ["grab"])
			if _sp_t > LIFT_LEN and not has_meta("hurling"):
				set_meta("hurling", true)
				humanoid.play("ape_hurl", HURL_LEN)
			if _sp_t > LIFT_LEN + HURL_LEN * 0.25 and not _sp_hit and _rock:
				_sp_hit = true
				_hurl_at(p, 20.0, 0.55)
			if _sp_t > LIFT_LEN + HURL_LEN:
				remove_meta("hurling")
				_end_special(0.6)
		"climb":
			grounded = false
			_climb_update()
		"prowl":
			grounded = false
			_prowl_update(delta)
		"tree_throw":
			grounded = false
			_tree_throw_update(p)
		"drop":
			grounded = false
			_drop_update()
		"fall":
			grounded = false
			_fall_update(delta)
	if grounded:
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
		var hv := _flat(velocity).move_toward(want, 30.0 * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		move_and_slide()
		facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(8.0 * delta, 1.0))
		_feed_body(hv, false)
	else:
		facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(8.0 * delta, 1.0))
		_feed_body(Vector3.ZERO, false)
		humanoid.grounded = false


## The boulder in its fists flies at `p` (where it's heading), a ring where it'll come down.
func _hurl_at(p: Node3D, speed: float, min_t: float) -> void:
	var from := _rock.global_position
	var to := _ground_at((p.global_position + _flat((p as CharacterBody3D).velocity) * 0.4) if p else global_position + _fwd() * 12.0)
	var dur := clampf(from.distance_to(to) / speed, min_t, 1.5)
	Net.fx("telegraph", [to, ROCK_R, dur, Color(1.0, 0.18, 0.12)])
	_throw_rock(from, to, dur)
	Net.event(self, "rock", ["throw", from, to, dur])
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(self):
			_aoe(to, ROCK_R, 24.0, true))


func _end_special(recover: float) -> void:
	hitbox.deactivate()
	_special = ""
	set_meta("recover", recover)
	_set_state(S.RECOVER)


# ==========================================================================
# The canopy
# ==========================================================================
func _perch_at(i: int) -> Vector3:
	return arena.trees[i]["perch"]


func _nearest_perch() -> int:
	var best := 0
	var bd := INF
	for i in range((arena.trees as Array).size()):
		var d := _flat(_perch_at(i) - global_position).length()
		if d < bd:
			bd = d
			best = i
	return best


## Facing the floor's middle from up on limb `i`.
func _face_in() -> void:
	_face(_flat(arena.centre() - global_position))


func _shake(i: int, k: float) -> void:
	arena.shake(i, k)
	Net.event(self, "shake", [i, k])


func _say(n: String, at: Vector3, vol: float, pitch: float) -> void:
	BeastFX.sfx(n, at, vol, pitch, 90.0)
	Net.event(self, "say", [n, at, vol, pitch])


## Hidden in the leaves (`on` false) or showing itself on its limb.
func _show(on: bool) -> void:
	humanoid.visible = on
	hurtbox.monitorable = on


func _go_up(on: bool) -> void:
	up = on
	_col.disabled = on
	_tree_hits = 0.0
	if not on:
		_perch = -1
		_show(true)


## A crouch, then one great bound up onto the limb; into the leaves.
func _climb_update() -> void:
	if _sp_t < CLIMB_WIND:
		_face(_flat(_sp_target - global_position))
		return
	var u := clampf((_sp_t - CLIMB_WIND) / CLIMB_AIR, 0.0, 1.0)
	if humanoid.current_action() != "ape_air":
		humanoid.hold("ape_air", 0.2)
		_go_up(true)
		_show(true)
		Net.fx("dust_ring", [_sp_from, 20, 1.4])
		Net.fx("sfx", ["whoosh_big", _sp_from, 2.0, 0.05, 0.6])
	var flat := _sp_from.lerp(_sp_target, u)
	global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u * u * (3.0 - 2.0 * u)) + sin(u * PI) * 3.0, flat.z)
	velocity = Vector3.ZERO
	if u >= 1.0:
		_shake(_perch, 1.0)
		_say("branch", global_position, 2.0, 0.9)
		_show(false)
		_next_hop()
		_special = "prowl"
		_sp_t = 0.0


## Off along the ring to another limb (on round the way it's going, now and then doubling back).
func _next_hop() -> void:
	var n: int = (arena.trees as Array).size()
	if _rng.randf() < 0.25:
		_hop_dir = -_hop_dir
	_hop_to = posmod(_perch + _hop_dir * (1 + (1 if _rng.randf() < 0.35 else 0)), n)
	_hop_len = HOP[0 if phase < 3 else 1] * _rng.randf_range(0.85, 1.2)
	_sp_from = global_position
	_sp_target = _perch_at(_hop_to)
	_show_t = 0.0


## Running the canopy: limb to limb along the ring, the leaves thrashing where it goes.
func _prowl_update(delta: float) -> void:
	var u := clampf(_sp_t / _hop_len, 0.0, 1.0)
	var c: Vector3 = arena.centre()
	var a0 := atan2(_sp_from.z - c.z, _sp_from.x - c.x)
	var a1 := atan2(_sp_target.z - c.z, _sp_target.x - c.x)
	var a := a0 + angle_difference(a0, a1) * u
	var r := lerpf(_flat(_sp_from - c).length(), _flat(_sp_target - c).length(), u) + sin(u * PI) * 2.5
	global_position = Vector3(c.x + cos(a) * r, lerpf(_sp_from.y, _sp_target.y, u) + sin(u * PI) * 1.6, c.z + sin(a) * r)
	_face(Vector3(-sin(a), 0.0, cos(a)) * float(signf(angle_difference(a0, a1))))
	velocity = Vector3.ZERO
	_rustle_t -= delta
	if _rustle_t <= 0.0 and u < 0.95:
		_rustle_t = 0.42
		BeastFX.leaves(global_position + Vector3(0, 3.0, 0), 8, 2.0)
		BeastFX.sfx("leaves", global_position, -6.0, 1.1, 80.0)
		Net.event(self, "rustle", [global_position])
	if _show_t > 0.0:
		_show_t -= delta
		if _show_t <= 0.0:
			_show(false)
	if u < 1.0:
		return
	_perch = _hop_to
	_shake(_perch, 0.55)
	_face_in()
	if _rng.randf() < 0.3:
		_say("grunt", global_position, 2.0, _rng.randf_range(0.85, 1.05))
	if _throws > 0 and _rng.randf() < 0.6:
		_throws -= 1
		_special = "tree_throw"
		_sp_t = 0.0
		_sp_hit = false
		_show(true)
		humanoid.hold("ape_lift", TREE_WIND * 0.6)
		_shake(_perch, 1.0)
		_say("grunt", global_position, 4.0, 0.95)
		return
	if _throws <= 0:
		_special = "drop"
		_sp_t = 0.0
		_sp_hit = false
		var p := _target()
		_sp_from = global_position
		_sp_target = _ground_at(p.global_position if p else arena.centre())
		_show(true)
		humanoid.play("ape_beat", DROP_WARN)
		Net.fx("telegraph", [_sp_target, DROP_R, DROP_WARN + DROP_AIR, Color(1.0, 0.18, 0.12)])
		Net.fx("sfx", ["roar", global_position, 8.0, 0.03, 0.62])
		_shake(_perch, 1.0)
		return
	_next_hop()
	_sp_t = 0.0
	# a glimpse now and then: crouched on the limb, eyes in the dark
	if _rng.randf() < 0.35:
		_show(true)
		humanoid.hold("ape_perch", 0.15)
		_show_t = GLIMPSE


## Showing itself on the limb, a boulder hauled up and hurled down.
func _tree_throw_update(p: Node3D) -> void:
	if p:
		_face(_flat(p.global_position - global_position))
	if _sp_t > TREE_WIND * 0.4 and _rock == null and not _sp_hit:
		_grab_rock()
		Net.event(self, "rock", ["grab"])
	if _sp_t > TREE_WIND and not has_meta("hurling"):
		set_meta("hurling", true)
		humanoid.play("ape_hurl", HURL_LEN)
	if _sp_t > TREE_WIND + HURL_LEN * 0.25 and not _sp_hit and _rock:
		_sp_hit = true
		_hurl_at(p, 22.0, 0.8)
	if _sp_t > TREE_WIND + HURL_LEN + 0.15:
		remove_meta("hurling")
		_show(false)
		_special = "prowl"
		_next_hop()
		_sp_t = 0.0


## Reared up on the limb roaring, then down out of the canopy onto you.
func _drop_update() -> void:
	if _sp_t < DROP_WARN:
		_face(_flat(_sp_target - global_position))
		return
	var u := clampf((_sp_t - DROP_WARN) / DROP_AIR, 0.0, 1.0)
	if humanoid.current_action() != "ape_dive":
		humanoid.hold("ape_dive", 0.15)
		_hurt_off_for_dive()
		BeastFX.leaves(global_position + Vector3(0, 2.0, 0), 30, 3.0)
		Net.event(self, "rustle", [global_position])
		Net.fx("sfx", ["whoosh_big", global_position, 4.0, 0.05, 0.55])
	var flat := _sp_from.lerp(_sp_target, u)
	global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u * u) + sin(u * PI) * 2.0, flat.z)
	velocity = Vector3.ZERO
	if u >= 1.0 and not _sp_hit:
		_sp_hit = true
		_go_up(false)
		humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
		_aoe(global_position, DROP_R, 34.0, true)
		Net.fx("dust_ring", [global_position, 40, 2.6])
		Net.fx("impact", [global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.3)])
		Net.fx("sfx", ["thud", global_position, 8.0, 0.05, 0.4])
		get_node("/root/CombatManager").apply_camera_shake(0.55)
		_end_special(1.4)


## (it can't be struck mid-dive: the blow lands as it does)
func _hurt_off_for_dive() -> void:
	hurtbox.monitorable = false


## Knocked out of the tree: down it comes, stunned where it lands.
func _fall_update(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	if _sp_t > 0.2 and global_position.y <= _sp_target.y:
		global_position.y = _sp_target.y
		_go_up(false)
		Net.fx("dust_ring", [global_position, 30, 2.0])
		Net.fx("sfx", ["thud", global_position, 6.0, 0.05, 0.5])
		Net.fx("float_text", [global_position + Vector3(0, 4.0, 0), "Knocked down!", Color(1.0, 0.85, 0.4), 30])
		get_node("/root/CombatManager").apply_camera_shake(0.35)
		_special = ""
		_stagger_len = FALL_STUN
		humanoid.react("stagger", FALL_STUN, -_fwd())
		_set_state(S.STAGGER)


func _knock_out_of_tree() -> void:
	if _rock:
		_rock.queue_free()
		_rock = null
		Net.event(self, "rock", ["drop"])
	remove_meta("hurling")
	_special = "fall"
	_sp_t = 0.0
	_sp_target = _ground_at(global_position)
	velocity = _flat(arena.centre() - global_position).normalized() * 3.0
	_show(true)
	humanoid.hold("ape_air", 0.15)
	_shake(_perch, 1.0)
	Net.fx("sfx", ["roar", global_position, 4.0, 0.05, 1.15])


## Everyone left while it was up: down it comes, back to its post.
func _come_down() -> void:
	if not up:
		return
	_go_up(false)
	global_position = post + Vector3.UP * 0.3
	reset_physics_interpolation()


## A shockwave: every machine checks its own captain (jump it or dodge through).
func _aoe(center: Vector3, radius: float, dmg: float, knock: bool) -> void:
	dmg = _dmg(dmg)
	_aoe_local(center, radius, dmg, knock)
	Net.event(self, "aoe", [center, radius, dmg, knock])


func _aoe_local(center: Vector3, radius: float, dmg: float, knock: bool) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	if _flat(me.global_position - center).length() > radius or me.global_position.y > center.y + 1.1:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = knock
	hd.unblockable = true
	hd.knockback_force = 9.0
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.07
	hd.camera_shake_intensity = 0.25
	hb.take_hit(hd, self)


# ==========================================================================
# The boulder
# ==========================================================================
func _grab_rock() -> void:
	if _rock:
		return
	_rock = MeshInstance3D.new()
	_rock.name = "Boulder"
	_rock.mesh = Props.rock_mesh(9911, 1.0, true)
	_rock.scale = Vector3.ONE * 0.95
	_rock.top_level = true
	add_child(_rock)
	if not up:
		Net.fx("dust", [global_position + _fwd() * 1.5, 10, 1.0])
	_rock_follow()


## Held between its fists.
func _rock_follow() -> void:
	if _rock == null:
		return
	var mid := (humanoid.hand_l.global_position + humanoid.hand_r.global_position) * 0.5
	_rock.global_position = mid + Vector3(0, 0.35, 0)


func _throw_rock(from: Vector3, to: Vector3, dur: float) -> void:
	if _rock == null:
		_grab_rock()
	_rocks.append([_rock, from, to, 0.0, dur])
	_rock = null


func _fly_rocks(delta: float) -> void:
	for r in _rocks.duplicate():
		var n: MeshInstance3D = r[0]
		r[3] = float(r[3]) + delta
		var u := clampf(float(r[3]) / float(r[4]), 0.0, 1.0)
		var from: Vector3 = r[1]
		var to: Vector3 = r[2]
		# (thrown down from the canopy it barely arcs)
		var arc := 0.22 if from.y - to.y < 5.0 else 0.06
		n.global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * from.distance_to(to) * arc
		n.rotation += Vector3(4.0, 2.5, 0) * delta
		if u >= 1.0:
			FX.dust_ring(to, 22, 1.6)
			FX.dust(to + Vector3.UP * 0.5, 18, 1.4)
			FX.sfx("thud", to, 5.0, 0.05, 0.6)
			n.queue_free()
			_rocks.erase(r)


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	_hit_by = attacker
	var dir := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else -_fwd()
	# far too big to throw down; the hit lands all the same
	var h := hit.duplicate() as HitData
	h.knockdown = false
	h.crumple = false
	_take_damage(h, dir)
	if state == S.DEAD:
		return
	if state == S.IDLE:
		alert()
		return
	if up:
		_tree_hits += hit.damage
		if (_tree_hits >= health.max_health * KNOCK_DOWN or hit.haki) and _special in ["prowl", "tree_throw", "drop"] and not (_special == "drop" and _sp_t >= DROP_WARN):
			_knock_out_of_tree()
		return
	# Haki (or a guard-breaker) knocks it out of a slam's or a leap's wind-up
	if (_special == "slam" and _sp_t < SLAM_WIND) or (_special == "leap" and _sp_t < LEAP_WIND):
		if hit.haki or hit.breaker:
			_stagger(dir, 1.8)
		return
	if _special != "":
		return
	_poise += hit.damage * (1.6 if hit.knockdown else 1.0)
	if _poise >= POISE:
		_poise = 0.0
		_stagger(dir, 2.0)


func _stagger(dir: Vector3, length: float) -> void:
	_special = ""
	hitbox.deactivate()
	if _rock:
		_rock.queue_free()
		_rock = null
		Net.event(self, "rock", ["drop"])
	remove_meta("slam_down")
	remove_meta("hurling")
	_stagger_len = length
	velocity = dir * 3.0
	humanoid.react("stagger", length, dir)
	Net.fx("sfx", ["roar", global_position, -2.0, 0.05, 1.2])
	_set_state(S.STAGGER)


## A parried swipe staggers it, wide open.
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if _special != "swipe":
		return
	var dir := -_fwd()
	if by is Node3D:
		dir = _flat(global_position - (by as Node3D).global_position).normalized()
	_stagger(dir, 2.2)


func _on_died() -> void:
	if state == S.DEAD:
		return
	_special = ""
	_set_peril(false)
	if up:
		_go_up(false)
	if _rock:
		_rock.queue_free()
		_rock = null
	super._on_died()
	Net.coins(global_position + Vector3(0, 1.5, 0), _coins(24))
	Net.award_xp(_xp(600), global_position + Vector3(0, 3.0, 0), 70.0)


func _drop_weapon() -> void:
	pass


func _max_hp() -> float:
	return APE_HP * Levels.hp_k(level, _lv_ref())


## Its health and blows were tuned on the first chain island (its XP and coins are Brinehollow's sort).
func _lv_ref() -> int:
	return 6


## Everyone left (or fell): back to its post, healed, asleep, from the top.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	_come_down()
	_special = ""
	hitbox.deactivate()
	_set_peril(false)
	phase = 1
	_poise = 0.0
	_cd["canopy"] = 0.0
	health.current_health = health.max_health
	humanoid.stop_action()
	_set_state(S.RETURN)


# ==========================================================================
# Co-op extras
# ==========================================================================
func net_pack() -> Array:
	var a := super.net_pack()
	a.append(phase)
	a.append(up)
	a.append(humanoid.visible)
	return a


func _net_update(delta: float) -> void:
	super._net_update(delta)
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	if b.size() >= 22 and int(b[21]) != phase:
		phase = int(b[21])
		phase_changed.emit(phase)
	if a.size() >= 24 and state != S.DEAD:
		up = bool(a[22])
		humanoid.visible = bool(a[23])
		hurtbox.monitorable = bool(a[23])


func net_event(what: String, args: Array) -> void:
	match what:
		"aoe":
			_aoe_local(args[0], float(args[1]), float(args[2]), bool(args[3]))
			return
		"rock":
			match str(args[0]):
				"grab":
					_grab_rock()
				"throw":
					_throw_rock(args[1], args[2], float(args[3]))
				"drop":
					if _rock:
						_rock.queue_free()
						_rock = null
			return
		"shake":
			arena.shake(int(args[0]), float(args[1]))
			return
		"say":
			BeastFX.sfx(str(args[0]), args[1], float(args[2]), float(args[3]), 90.0)
			return
		"rustle":
			BeastFX.leaves(args[0] + Vector3(0, 3.0, 0), 8, 2.0)
			BeastFX.sfx("leaves", args[0], -6.0, 1.1, 80.0)
			return
	super.net_event(what, args)
