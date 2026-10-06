extends PirateGrunt
class_name PirateBoss
## Captain Morrow "Red Tide", master of Redtide Rock. A big man with a big
## cutlass and a brace of pistols; a fight in three acts:
##
## 1. (full health) Three-hit combos ending in a heavy downward cut, the
##    lunge, the red unblockable chop, and a pistol volley (three quick
##    telegraphed shots) when you keep your distance.
## 2. (below 60%) He roars - a shockwave that throws everyone near him off
##    their feet (dodge or jump it) - and calls his crew over the walls. Adds
##    a leaping slam: a red ring marks where he'll land.
## 3. (below 30%) "Red Tide": the blade glows red, he's quicker, and he adds
##    a whirling blade storm that chases you down.
##
## He doesn't get knocked over by ordinary heavy hits and shrugs off light
## hits while winding up (stagger him with a parry, a guard break or Armament
## Haki). Co-op: host-run like any grunt; his roar/slam shockwaves are judged
## on each captain's own machine (Net.event "aoe").

signal phase_changed(phase: int)

const BOSS_HP := 900.0
const ROAR_LEN := 1.7
const SLAM_WIND := 0.75
const SLAM_AIR := 0.8
const WHIRL_LEN := 1.9

const BARK_PHASE2 := ["You've got spirit! LADS! Over the wall!", "Enough games - crew, at 'em!"]
const BARK_PHASE3 := ["Now you'll see the Red Tide!", "RED TIDE! Drown in it!"]
const BARK_TAUNT := ["Is that all?", "Ha! Again!", "You fight like a deckhand!", "Come on, then!"]

var phase: int = 1
var arena: Node = null
var _special: String = ""
var _sp_t: float = 0.0
var _sp_target := Vector3.ZERO
var _sp_from := Vector3.ZERO
var _sp_hit: bool = false
var _volley_left: int = 0
var _slam_cd: float = 8.0
var _whirl_cd: float = 4.0
var _pulse_t: float = 0.0
var _red_mat: ShaderMaterial
var _red: bool = false
var _taunt_t: float = 0.0


static func morrow_look() -> Dictionary:
	var lk := CharacterLook.base_look()
	var C := CharacterLook.CLOTH
	lk.merge({
		"name": "Captain Morrow", "body": "masc", "build": "broad", "height": 1.2,
		"skin": CharacterLook.SKIN_TONES[3], "head": "square", "nose": "hooked", "brows": 3, "mouth": 1,
		"marks": "scar", "hair": "long", "hair_color": CharacterLook.HAIR_COLORS[3], "facial_hair": "long_beard",
		"hat": "tricorn", "hat_color": C[14], "trim_color": CharacterLook.TRIM[0],
		"top": "shirt", "top_color": C[0], "sleeves": "long", "vest": "vest", "vest_color": C[5],
		"coat": "captain", "coat_color": C[13], "legs": "trousers", "legs_color": C[5],
		"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "belt_sash",
		"belt_color": CharacterLook.LEATHER[0], "sash_color": C[15], "gloves": true,
		"gloves_color": CharacterLook.LEATHER[0], "earring": true, "eyepatch": true, "pauldron": true,
	}, true)
	return lk


func _ready() -> void:
	look = PirateBoss.morrow_look()
	role = "sword"
	super._ready()
	add_to_group("bosses")
	health.max_health = BOSS_HP
	health.current_health = BOSS_HP
	# a longer reach for a bigger man
	var bs := hitbox.get_child(0) as CollisionShape3D
	(bs.shape as BoxShape3D).size = Vector3(2.4, 1.6, 2.1)
	bs.position = Vector3(0, 1.1, -1.35)
	_hit_light.damage = 17.0
	_hit_heavy = _hit_heavy.duplicate() as HitData
	_hit_heavy.damage = 26.0
	_hit_heavy.knockdown = true
	_hit_heavy.knockback_force = 8.0
	_hit_peril.damage = 34.0
	_peril_cd = 6.0
	_pistol_cd = 4.0
	_bark.position.y = 2.9
	if Net.hosting:
		net_rescale(Net.hp_scale())


func is_fighting() -> bool:
	return in_combat()


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


# --------------------------------------------------------------------------
# Brain additions
# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if net_puppet:
		super._physics_process(delta)
		return
	_slam_cd -= delta
	_whirl_cd -= delta
	_taunt_t -= delta
	if state != S.DEAD and humanoid.ragdoll == null:
		_phase_check()
		if _special != "":
			_special_update(delta)
			return
	# walking back to his post: the fight starts over from the top
	if state in [S.RETURN, S.IDLE] and (phase != 1 or health.current_health < health.max_health or _red):
		phase = 1
		_volley_left = 0
		_set_red(false)
		health.current_health = health.max_health
	var was := state
	super._physics_process(delta)
	# a pistol volley: three quick shots, not one
	if was == S.AIM and state != S.AIM and _volley_left > 0 and state in [S.CHASE, S.CIRCLE]:
		_volley_left -= 1
		_start_aim("pistol")


func _phase_check() -> void:
	var f := health_frac()
	if phase == 1 and f < 0.6 and state not in [S.DOWN, S.GETUP, S.DEAD]:
		phase = 2
		_begin_special("roar")
		bark(BARK_PHASE2, 1.0)
		phase_changed.emit(2)
		if arena and arena.has_method("call_crew"):
			arena.call_crew()
	elif phase == 2 and f < 0.3 and state not in [S.DOWN, S.GETUP, S.DEAD]:
		phase = 3
		_begin_special("roar")
		bark(BARK_PHASE3, 1.0)
		_set_red(true)
		phase_changed.emit(3)


func _choose_attack(dist: float) -> String:
	if phase >= 2 and _slam_cd <= 0.0 and dist > 3.5 and dist < 13.0 and _rng.randf() < 0.55:
		_slam_cd = _rng.randf_range(9.0, 13.0)
		return "slam"
	if phase >= 3 and _whirl_cd <= 0.0 and dist < 7.0 and _rng.randf() < 0.5:
		_whirl_cd = _rng.randf_range(8.0, 11.0)
		return "whirl"
	if _peril_cd <= 0.0 and _rng.randf() < 0.45:
		_peril_cd = _rng.randf_range(7.0, 11.0) * (0.75 if phase >= 3 else 1.0)
		return "peril"
	if dist > 3.2 and _rng.randf() < 0.45:
		return "lunge"
	return "combo"


func _begin_attack(dist: float) -> void:
	if _attack in ["slam", "whirl"]:
		_begin_special(_attack)
		return
	super._begin_attack(dist)


func _combo_hits() -> int:
	return 3


func _guard_max() -> int:
	return 5


func _wind_len() -> float:
	var k := 0.8 if phase >= 3 else 1.0
	if _attack == "combo" and _swing_i == 2:
		return 0.5 * k
	return super._wind_len() * k


func _start_wind() -> void:
	super._start_wind()
	if _attack == "combo" and _swing_i == 2:
		# the finisher: overhead, glowing - a downward cut that floors you
		humanoid.play("wind_r", _wind_len() + 0.05)
		hitbox.hit_data = _hit_heavy
		_set_glow(true)
		_glow_t = 0.9


func _start_swing() -> void:
	if _attack == "combo" and _swing_i == 2:
		_swung = false
		_glinted = false
		_set_state(S.SWING)
		hitbox.deactivate()
		humanoid.play("slash_down", 0.5)
		velocity += _fwd() * 4.0
		Net.fx("sfx", ["whoosh_big", global_position, -2.0, 0.08, 0.9])
		return
	super._start_swing()


func _start_aim(gun: String) -> void:
	if gun == "pistol" and _volley_left == 0 and state != S.AIM:
		_volley_left = 2
	super._start_aim(gun)
	if gun == "pistol":
		_aim_len = 0.62 if _volley_left < 2 else 0.85
		_lock_len = 0.26


## No more random pistol pulls between volleys than a grunt would.
func _want_pistol(p: Node3D, dist: float, delta: float) -> bool:
	return super._want_pistol(p, dist, delta * 1.4)


# --------------------------------------------------------------------------
# Specials: roar, slam, whirl
# --------------------------------------------------------------------------
func _begin_special(what: String) -> void:
	_release_token()
	hitbox.deactivate()
	_drop_aim()
	_special = what
	_sp_t = 0.0
	_sp_hit = false
	_set_state(S.WIND)
	_attack = what
	match what:
		"roar":
			humanoid.play("parry", ROAR_LEN)
			Net.fx("sfx", ["roar", global_position, 4.0, 0.03, 0.95])
			Net.fx("impact", [global_position + Vector3(0, 2.2, 0), Color(1.0, 0.3, 0.2)])
		"slam":
			var p := _target()
			_sp_from = global_position
			_sp_target = p.global_position if p else global_position + _fwd() * 6.0
			_face(_flat(_sp_target - global_position))
			humanoid.play("lunge_wind", SLAM_WIND)
			_set_peril(true)
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.8])
			Net.fx("telegraph", [_ground_at(_sp_target), 4.0, SLAM_WIND + SLAM_AIR, Color(1.0, 0.18, 0.12)])
		"whirl":
			humanoid.play("spin_slash", 0.5)
			_set_peril(true)
			bark(["Red Tide!", "Come here!"], 1.0)
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 1.0])


func _ground_at(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 12.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _special_update(delta: float) -> void:
	_sp_t += delta
	st_t += delta
	var want := Vector3.ZERO
	var accel := 20.0
	var g := true
	match _special:
		"roar":
			if _sp_t > ROAR_LEN * 0.55 and not _sp_hit:
				_sp_hit = true
				_aoe(global_position, 5.5, 8.0, true)
				Net.fx("dust_ring", [global_position, 24, 1.4])
				Net.fx("impact", [global_position + Vector3(0, 1.2, 0), Color(1.0, 0.5, 0.3)])
				get_node("/root/CombatManager").apply_camera_shake(0.25)
			if _sp_t > ROAR_LEN:
				_end_special(0.3)
		"slam":
			if _sp_t < SLAM_WIND:
				_face(_flat(_sp_target - global_position))
			elif not _sp_hit:
				# up and over: a ballistic hop that lands on the marked spot
				var u := clampf((_sp_t - SLAM_WIND) / SLAM_AIR, 0.0, 1.0)
				if u == 0.0 or humanoid.current_action() != "plunge_air":
					humanoid.play("plunge_air", SLAM_AIR)
				var flat := _sp_from.lerp(_sp_target, u)
				var h := sin(u * PI) * 3.2
				global_position = Vector3(flat.x, lerpf(_sp_from.y, _ground_at(_sp_target).y, u) + h, flat.z)
				velocity = Vector3.ZERO
				g = false
				if u >= 1.0:
					_sp_hit = true
					humanoid.play("plunge_land", 0.6)
					_aoe(global_position, 4.0, 22.0, true)
					Net.fx("dust_ring", [global_position, 26, 1.5])
					Net.fx("impact", [global_position + Vector3(0, 0.5, 0), Color(1.0, 0.4, 0.25)])
					Net.fx("sfx", ["thud", global_position, 4.0, 0.05, 0.6])
					get_node("/root/CombatManager").apply_camera_shake(0.3)
					_set_peril(false)
			elif _sp_t > SLAM_WIND + SLAM_AIR + 0.7:
				_end_special(0.5)
		"whirl":
			var p := _target()
			if p:
				var to := _flat(p.global_position - global_position)
				want = to.normalized() * 5.2 if to.length() > 1.0 else Vector3.ZERO
			accel = 12.0
			# spin the body (and the blade's hitbox with it), re-arming it
			facing.rotation.y += delta * 14.0
			_yaw = facing.rotation.y
			_pulse_t -= delta
			if _pulse_t <= 0.0:
				_pulse_t = 0.3
				hitbox.deactivate()
				hitbox.hit_data = _hit_light
				hitbox.activate()
				humanoid.play("spin_slash", 0.32)
				Net.fx("sfx", ["whoosh", global_position, -3.0, 0.1, 0.9])
			if _sp_t > WHIRL_LEN:
				hitbox.deactivate()
				_set_peril(false)
				_end_special(0.9)
	if g:
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
		var hv := _flat(velocity).move_toward(want, accel * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		move_and_slide()
		if _special != "whirl":
			facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(8.0 * delta, 1.0))
		_feed_body(hv, false)
	else:
		_feed_body(Vector3.ZERO, false)
		humanoid.grounded = false


func _end_special(recover: float) -> void:
	_special = ""
	_attack = "combo"
	set_meta("recover", recover)
	_set_state(S.RECOVER)
	if _taunt_t <= 0.0 and _rng.randf() < 0.4:
		_taunt_t = 8.0
		bark(BARK_TAUNT, 1.0)


## A shockwave around `center`: every machine checks its own captain (jump
## over it, or dodge through it).
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
	var d := _flat(me.global_position - center).length()
	if d > radius or me.global_position.y > center.y + 1.0:
		return  # out of reach, or jumped over it
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = knock
	hd.unblockable = true
	hd.knockback_force = 8.0
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.06
	hd.camera_shake_intensity = 0.2
	hb.take_hit(hd, self)


# --------------------------------------------------------------------------
# Getting hit
# --------------------------------------------------------------------------
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	var h := hit
	# not floored by ordinary heavies (only while he's reeling)
	if h.knockdown and state != S.STAGGER:
		h = hit.duplicate() as HitData
		h.knockdown = false
		h.knockback_force = minf(h.knockback_force, 3.0)
	if _special != "":
		# mid-special: the hit lands, but he doesn't flinch - except Armament
		# Haki breaking a slam before he leaves the ground
		var dir := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else -_fwd()
		_take_damage(h, dir)
		if state == S.DEAD:
			return
		if _special == "slam" and (h.haki or h.breaker) and _sp_t < SLAM_WIND:
			_set_peril(false)
			_special = ""
			_stagger_len = 1.6
			humanoid.play("stagger", 1.6)
			Net.fx("sparkle", [global_position + Vector3(0, 1.6, 0), 14, Color(0.75, 0.45, 1.0)])
			Net.fx("sfx", ["haki", global_position, -6.0, 0.05, 1.3])
			_set_state(S.STAGGER)
		return
	# winding up a normal attack: armour against light hits
	if state in [S.WIND, S.SWING] and _attack in ["combo", "lunge"] and not h.haki and not h.breaker and h.damage < 20.0 and not h.dot:
		var dir2 := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else -_fwd()
		_take_damage(h, dir2)
		return
	super._on_hit(h, attacker)


## A parried whirl stops the storm (and staggers him like anyone else).
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if _special == "whirl":
		_special = ""
		_set_peril(false)
		hitbox.deactivate()
	elif _special != "":
		return
	super.parried(by)


func _on_died() -> void:
	if state == S.DEAD:
		return
	_special = ""
	_set_red(false)
	_set_peril(false)
	super._on_died()
	Net.coins(global_position + Vector3(0, 1.0, 0), 18)
	Net.award_xp(400, global_position + Vector3(0, 2.5, 0), 60.0)


func _net_die() -> void:
	super._net_die()
	_red = false
	_set_red(false)


## The usual weapon drop: none (his cutlass is in the reward chest).
func _drop_weapon() -> void:
	pass


func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = BOSS_HP * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


## Everyone left (or fell): back to his post, healed, from the top.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	_special = ""
	_set_peril(false)
	_set_red(false)
	phase = 1
	_volley_left = 0
	health.current_health = health.max_health
	_drop_aim()
	hitbox.deactivate()
	_go_home()


## Red Tide: the blade glows red for the rest of the fight.
func _set_red(on: bool) -> void:
	_red = on
	if humanoid == null or humanoid.weapon == null:
		return
	if on:
		if _red_mat == null:
			_red_mat = PSXMat.lit("metal", Color(1.0, 0.3, 0.25), {"emission": Color(1.0, 0.15, 0.1), "emission_energy": 2.2, "emission_pulse": 3.0})
		humanoid.weapon.material_override = _red_mat
	elif humanoid.weapon.material_override == _red_mat:
		humanoid.weapon.material_override = null


func _set_glow(on: bool) -> void:
	super._set_glow(on)
	if not on and _red:
		_set_red(true)


# --------------------------------------------------------------------------
# Co-op extras
# --------------------------------------------------------------------------
func net_pack() -> Array:
	var a := super.net_pack()
	a.append(phase)
	a.append(_red)
	return a


func _net_update(delta: float) -> void:
	super._net_update(delta)
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var b: Array = smp[1]
	if b.size() >= 22:
		if int(b[20]) != phase:
			phase = int(b[20])
			phase_changed.emit(phase)
		if bool(b[21]) != _red:
			_set_red(bool(b[21]))


func net_event(what: String, args: Array) -> void:
	if what == "aoe":
		_aoe_local(args[0], float(args[1]), float(args[2]), bool(args[3]))
		return
	super.net_event(what, args)
