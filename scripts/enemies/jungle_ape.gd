extends PirateGrunt
class_name JungleApe
## The jungle's beast boss (BeastArena): a silverback twice a man's height,
## built on the same rig as everyone (Humanoid, look height APE_H, stance "ape":
## the knuckle-walk; ApePoses for its moves). Its own brain, the grunt's body:
## death, ragdoll and co-op puppets come from PirateGrunt.
##
## Asleep at its post until the arena wakes it: a chest-beating roar (a
## shockwave: jump or dodge it), then it knuckle-runs you down and picks by
## range: the backhand swipe up close (parry it), the two-fist slam (a red
## ring in front of it), a leap onto you from afar (a ring where it lands), or
## it rips up a boulder and hurls it (a ring where it'll come down).
## Below 60% it roars again; below 30% it roars and is enraged: quicker, the
## cooldowns shorter. No knockdowns: poise built up by hits staggers it, and
## Armament Haki (or a guard-breaker) knocks it out of a slam's or a leap's wind-up.
## Co-op: host-run; the shockwaves are judged on each captain's own machine
## (event "aoe"), the boulder flies on every screen (event "rock").

signal phase_changed(phase: int)

const APE_HP := 1500.0
const APE_H := 2.15
const RUN := 6.2
const SWIPE_RANGE := 4.4
const POISE := 220.0
const POISE_DECAY := 30.0
const FUR := Color(0.21, 0.19, 0.18)
const SILVER := Color(0.7, 0.7, 0.68)
const FACE := Color(0.36, 0.31, 0.29)
const ROAR_LEN := 2.0
const SLAM_WIND := 0.6
const LEAP_WIND := 0.45
const LEAP_AIR := 0.9
const LIFT_LEN := 0.9
const HURL_LEN := 0.6

var phase: int = 1
var arena: Node = null
var boss_name: String = "The Silverback"
var _special: String = ""
var _sp_t: float = 0.0
var _sp_from := Vector3.ZERO
var _sp_target := Vector3.ZERO
var _sp_hit: bool = false
var _cd := {"swipe": 0.0, "slam": 3.0, "leap": 6.0, "throw": 5.0}
var _poise: float = 0.0
var _hit_swipe: HitData
var _rock: MeshInstance3D
var _rocks: Array = []   # [node, from, to, t, dur] flying


static func ape_look() -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge({"name": "Silverback", "body": "masc", "build": "broad", "height": APE_H, "skin": FUR,
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
	health.max_health = APE_HP
	health.current_health = APE_HP
	# a body to match (the grunt's were made for a man)
	var cap := _col.shape as CapsuleShape3D
	cap.radius = 0.85
	cap.height = 3.0
	_col.position = Vector3(0, 1.5, 0)
	var hcap := (hurtbox.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	hcap.radius = 1.25
	hcap.height = 3.4
	(hurtbox.get_child(0) as CollisionShape3D).position = Vector3(0, 1.7, 0)
	var bs := hitbox.get_child(0) as CollisionShape3D
	(bs.shape as BoxShape3D).size = Vector3(4.6, 2.6, 3.8)
	bs.position = Vector3(0, 1.3, -2.4)
	_hit_swipe = HitData.new()
	_hit_swipe.damage = 22.0
	_hit_swipe.knockback_force = 10.0
	_hit_swipe.stagger_duration = 0.5
	_hit_swipe.hitstop_duration = 0.1
	_hit_swipe.camera_shake_intensity = 0.3
	hitbox.hit_data = _hit_swipe
	_bark.position.y = 4.6
	_dress()
	if Net.hosting:
		net_rescale(Net.hp_scale())


## Brow, muzzle, the silver saddle down its back.
func _dress() -> void:
	var fur := PSXMat.lit("hair", FUR)
	var face := PSXMat.flat(FACE)
	var silver := PSXMat.lit("hair", SILVER)
	var hb := MeshBuilder.new()
	hb.add_box(fur, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, 0.155, -0.115)), Vector3(0.22, 0.05, 0.07), 1.0)
	hb.add_box(face, Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, 0.06, -0.13)), Vector3(0.17, 0.1, 0.1), 1.0)
	hb.add_box(PSXMat.flat(Color(0.08, 0.07, 0.07)), Transform3D(Basis(), Vector3(0, 0.09, -0.185)), Vector3(0.08, 0.025, 0.01), 1.0)
	hb.add_blob(fur, Transform3D(Basis(), Vector3(0, 0.19, 0.03)), Vector3(0.13, 0.08, 0.13), RandomNumberGenerator.new(), 0.0, 3, 6)
	humanoid.head.add_child(hb.to_instance("ApeHead"))
	var tb := MeshBuilder.new()
	tb.add_box(silver, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.32, 0.14)), Vector3(0.36, 0.34, 0.05), 1.0)
	tb.add_box(silver, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.08, 0.15)), Vector3(0.3, 0.18, 0.05), 1.0)
	humanoid.torso.add_child(tb.to_instance("SilverBack"))


func is_fighting() -> bool:
	return in_combat()


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


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
		_begin_special("roar")
		phase_changed.emit(2)
	elif phase == 2 and f < 0.3:
		phase = 3
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
			_sp_target = _ground_at(global_position + _fwd() * 3.0)
			Net.fx("telegraph", [_sp_target, 4.5, SLAM_WIND + 0.18, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.7])
		"leap":
			_sp_from = global_position
			_sp_target = _ground_at(p.global_position if p else global_position + _fwd() * 10.0)
			_face(_flat(_sp_target - global_position))
			humanoid.hold("ape_crouch", LEAP_WIND)
			Net.fx("telegraph", [_sp_target, 5.0, LEAP_WIND + LEAP_AIR, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.65])
		"throw":
			humanoid.hold("ape_lift", LIFT_LEN)


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
				_aoe(global_position, 7.0, 10.0, true)
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
				_aoe(_sp_target, 4.5, 26.0, true)
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
					_aoe(global_position, 5.0, 30.0, true)
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
				var from := _rock.global_position
				var to := _ground_at((p.global_position + _flat((p as CharacterBody3D).velocity) * 0.4) if p else global_position + _fwd() * 12.0)
				var dur := clampf(from.distance_to(to) / 20.0, 0.55, 1.4)
				Net.fx("telegraph", [to, 3.4, dur, Color(1.0, 0.18, 0.12)])
				_throw_rock(from, to, dur)
				Net.event(self, "rock", ["throw", from, to, dur])
				get_tree().create_timer(dur).timeout.connect(func():
					if is_instance_valid(self):
						_aoe(to, 3.4, 24.0, true))
			if _sp_t > LIFT_LEN + HURL_LEN:
				remove_meta("hurling")
				_end_special(0.6)
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
		_feed_body(Vector3.ZERO, false)
		humanoid.grounded = false


func _end_special(recover: float) -> void:
	hitbox.deactivate()
	_special = ""
	set_meta("recover", recover)
	_set_state(S.RECOVER)


## A shockwave: every machine checks its own captain (jump it or dodge through).
func _aoe(center: Vector3, radius: float, dmg: float, knock: bool) -> void:
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
	_rock.scale = Vector3.ONE * 0.75
	_rock.top_level = true
	add_child(_rock)
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
		n.global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * from.distance_to(to) * 0.22
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
	if _rock:
		_rock.queue_free()
		_rock = null
	super._on_died()
	Net.coins(global_position + Vector3(0, 1.5, 0), 24)
	Net.award_xp(600, global_position + Vector3(0, 3.0, 0), 70.0)


func _drop_weapon() -> void:
	pass


func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = APE_HP * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


## Everyone left (or fell): back to its post, healed, asleep, from the top.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	_special = ""
	hitbox.deactivate()
	_set_peril(false)
	phase = 1
	_poise = 0.0
	health.current_health = health.max_health
	humanoid.stop_action()
	_set_state(S.RETURN)


# ==========================================================================
# Co-op extras
# ==========================================================================
func net_pack() -> Array:
	var a := super.net_pack()
	a.append(phase)
	return a


func _net_update(delta: float) -> void:
	super._net_update(delta)
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var b: Array = smp[1]
	if b.size() >= 22 and int(b[21]) != phase:
		phase = int(b[21])
		phase_changed.emit(phase)


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
	super.net_event(what, args)
