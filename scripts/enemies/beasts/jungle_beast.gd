class_name JungleBeast
extends CharacterBody3D
## What the jungle's non-human beasts share (the arena's bosses, the minibosses,
## the roamer); each kind builds its own body and brain on top:
##
##   _build()            the model under `model`, `_mats` (its own material copies:
##                       hits flash them), the body's collider, hurtbox shapes
##   _brain(d, p, to, r) free in the fight: the velocity it wants, or begin(move)
##   _move_tick(d, p)    a move under way (begin -> end_move): the velocity it wants
##   _animate(d)         poses the model from state/move/mv_t (host and puppets alike)
##
## The host thinks; guests' copies are puppets that play back its snapshots
## (position, facing, state, the move and its clock) and animate from those.
## Attacks are shapes judged on each captain's own machine (strike(): ring,
## cone, lane, ball), so a guest dodges what their own screen shows. Phases at
## _phase_at() (health fractions), poise built by hits staggers it (not during
## an armoured move), a parried move (_parry_ok) staggers it. Levels scale its
## health, blows, XP and coins (tuned on the first chain island: _lv_ref 6).

signal phase_changed(phase: int)
signal died(beast: JungleBeast)

enum S { SLEEP, FIGHT, STAGGER, RETURN, DEAD }

const GRAVITY := 20.0
const BODY_LAYER := 4 | 2048
## Nobody nearer than this: asleep and skipped altogether.
const DORMANT_R := 110.0
const CORPSE_SECS := 25.0

var arena: Node
var level: int = 0
var post := Vector3.ZERO
var post_yaw: float = 0.0
## The island's look for this kind (skin, size) and its name.
var variant: int = 0
var boss_name: String = ""
var phase: int = 1
var state: S = S.SLEEP
var st_t: float = 0.0
var move: String = ""
var mv_t: float = 0.0
var net_puppet: bool = false
var health: HealthComponent
var hurtbox: Hurtbox
var model: Node3D

var _yaw: float = 0.0
var _turn: float = 6.0
var _rng := RandomNumberGenerator.new()
var _mats: Array = []
var _flash: Tween
var _poise: float = 0.0
var _hit_by: Node
var _player: Node3D
var _cd := {}
var _stagger_len: float = 2.0
var _dead_t: float = 0.0
var _dormant: bool = false
var _dormant_t: float = 0.0
var _hit: bool = false
## A move that sets the position itself (leaps, climbs): no physics step.
var _fly: bool = false
var _path := PackedVector3Array()
var _path_i: int = 0
var _path_t: float = 0.0
var _path_goal := Vector3.INF
## Beasts away from an arena watch for captains themselves: woken within wake_r,
## back to sleep (healed) once nobody's been within leash_r for 6 s. 0: the arena does it.
var wake_r: float = 0.0
var leash_r: float = 40.0
var _watch_t: float = 0.0
var _empty_t: float = 0.0
## Its name and health over its head (minibosses and the roamer).
var _overhead: OverheadBar
## The 1.23 beast pass (BeastPass: phases that add moves, chains, beast poise, parts, motion), for kinds that list
## their moves by phase (_pass_moves); null for the rest.
var bp: BeastPass


func setup(cfg: Dictionary) -> JungleBeast:
	post = cfg["post"]
	post_yaw = float(cfg["yaw"])
	level = int(cfg["level"])
	variant = int(cfg.get("variant", 0))
	boss_name = str(cfg.get("name", boss_name))
	spirit = bool(cfg.get("spirit", false))
	return self


## A spectral beast (the fog isle's bosses, BeastPool "spirit"): it glows the cold blue-white of the dead, shot passes
## through it and it has no blood.
var spirit := false


func bloodless() -> bool:
	return spirit


# ==========================================================================
# What each kind fills in
# ==========================================================================
func _build() -> void:
	pass


func _hp_base() -> float:
	return 1000.0


func _poise_max() -> float:
	return 200.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 600


func _coins_base() -> int:
	return 24


## The level its numbers were tuned for (the first chain island's).
func _lv_ref() -> int:
	return 6


func _brain(_delta: float, _p: Node3D, _to: Vector3, _dist: float) -> Vector3:
	return Vector3.ZERO


func _move_tick(_delta: float, _p: Node3D) -> Vector3:
	end_move(0.3)
	return Vector3.ZERO


func _on_begin(_m: String) -> void:
	pass


func _animate(_delta: float) -> void:
	pass


func _on_phase(_n: int) -> void:
	pass


## Woken: the move it opens with ("" to go straight at you).
func _wake_move() -> String:
	return ""


## Can the move under way be broken by poise (false: it shrugs blows off)?
func _armoured() -> bool:
	return move != ""


## A parry on this move staggers it.
func _parry_ok() -> bool:
	return false


func _on_stagger() -> void:
	pass


func _on_die() -> void:
	pass


func _pack_extra() -> Array:
	return []


func _unpack_extra(_a: Array, _b: Array, _f: float) -> void:
	pass


func _event(_what: String, _args: Array) -> void:
	pass


## Its trophy for the hoard (a gear piece named for it), at loot tier `t`.
func trophy(_t: int) -> ItemData:
	return null


func _speed() -> float:
	return 5.0


## (1.23 beast pass) its moves by phase: [phase 1's, what phase 2 adds, what phase 3 adds]; empty: not on the pass.
func _pass_moves() -> Array:
	return []


## (beast pass) part -> the moves its breaking takes away.
func _part_takes() -> Dictionary:
	return {}


## (beast pass) moves a chain still waits on the cooldown for (the big ones).
func _chain_waits() -> Array:
	return []


## (beast pass) its look for its phase and broken parts, on every screen.
func _on_look() -> void:
	pass


## (beast pass) the phase change's ring went out: the kind's own touch (icicles, the sand bending).
func _on_moment() -> void:
	pass


func _moment_color() -> Color:
	return Color(1.0, 0.62, 0.3)


## (beast pass) a part broke (host): the kind's own reaction on top (BeastPass does the rest).
func _on_part(_n: String) -> void:
	pass


# ==========================================================================
# Setting up
# ==========================================================================
func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	add_to_group("net_sync")
	net_puppet = Net.is_client()
	if net_puppet:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	collision_layer = BODY_LAYER
	collision_mask = 1 | 2 | 2048
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	# (a kind that can prebuild() made its model's geometry ahead, on a worker)
	if model == null:
		model = Node3D.new()
		model.name = "Model"
	add_child(model)
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = _max_hp()
	add_child(health)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)
	if not _pass_moves().is_empty():
		bp = BeastPass.new(self)
		phase_changed.connect(func(_n: int): _on_look())
	_build()
	if spirit:
		Humanoid.spirit_glow(model)
	_yaw = post_yaw
	model.rotation.y = _yaw
	if Net.hosting:
		net_rescale(Net.hp_scale())


func _notification(what: int) -> void:
	# (made ahead and never put in the world: its model never joined it)
	if what == NOTIFICATION_PREDELETE and model != null and model.get_parent() == null:
		model.free()


func _max_hp() -> float:
	return _hp_base() * Levels.hp_k(level, _lv_ref())


func _dmg(base: float) -> float:
	return base * Levels.dmg_k(level, _lv_ref())


func net_rescale(k: float) -> void:
	var frac := health.current_health / maxf(health.max_health, 1.0)
	health.max_health = _max_hp() * k
	if state != S.DEAD:
		health.current_health = maxf(frac * health.max_health, 1.0)


## A copy of a cached material that this beast alone flashes.
func own(m: Material) -> ShaderMaterial:
	var c := (m as ShaderMaterial).duplicate() as ShaderMaterial
	_mats.append(c)
	return c


func hurt_ball(r: float, at: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	cs.position = at
	hurtbox.add_child(cs)
	return cs


# ==========================================================================
# Questions everyone asks
# ==========================================================================
func is_dead() -> bool:
	return state == S.DEAD


func asleep() -> bool:
	return state == S.SLEEP


func in_combat() -> bool:
	return state in [S.FIGHT, S.STAGGER]


func is_fighting() -> bool:
	return in_combat()


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


func state_name() -> String:
	return "%s%s" % [S.keys()[state], (":" + move) if move != "" else ""]


func vine_weight() -> String:
	return "heavy"


## The camera draws back for a big beast fighting near (CameraRig): 1 within reach.
func camera_room(from: Vector3) -> float:
	if not in_combat() or not is_in_group("bosses"):
		return 0.0
	return 1.0 - smoothstep(26.0, 34.0, from.distance_to(global_position))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _fwd() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0.0, -cos(model.rotation.y))


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		_yaw = atan2(-dir.x, -dir.z)


func _target() -> Node3D:
	if not is_instance_valid(_player):
		_player = null
	var p := Net.nearest_player(global_position, _player_ok, _player) as Node3D
	_player = p
	return p


func _player_ok(p: Node3D) -> bool:
	if p.has_method("current_state_name") and str(p.call("current_state_name")) in ["Downed", "Helm", "Swim"]:
		return false
	var hc := p.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


func ground_at(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 20.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## Which way to run to reach `goal` (the island's navmesh round the trees and rocks).
func _nav_dir(goal: Vector3, delta: float) -> Vector3:
	var straight := _flat(goal - global_position).normalized()
	_path_t -= delta
	if _path_t <= 0.0 or goal.distance_to(_path_goal) > 2.0:
		_path_t = _rng.randf_range(0.4, 0.6)
		_path_goal = goal
		_path_i = 1
		var map := get_world_3d().navigation_map
		var on_mesh := NavigationServer3D.map_get_closest_point(map, global_position).distance_to(global_position) < 2.0
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true) if on_mesh else PackedVector3Array()
	while _path_i < _path.size() and _flat(_path[_path_i] - global_position).length() < 1.2:
		_path_i += 1
	if _path_i >= _path.size():
		return straight
	return _flat(_path[_path_i] - global_position).normalized()


# ==========================================================================
# The brain (host)
# ==========================================================================
## Woken (the arena, or a hit).
func alert(_delay: float = 0.0) -> void:
	if Net.forward(self, "alert", [_delay]):
		return
	if state != S.SLEEP and state != S.RETURN:
		return
	_set_state(S.FIGHT)
	var w := _wake_move()
	if w != "":
		begin(w)


func _set_state(s: S) -> void:
	state = s
	st_t = 0.0


## The last move begun: pick() won't start it again straight after (docs/v1_20_beasts.md "Rules": no move twice in a row).
var _last_move := ""


func begin(m: String) -> void:
	move = m
	_last_move = m
	mv_t = 0.0
	_hit = false
	_fly = false
	if bp:
		bp.began(m)
		if m == "moment":
			say("bellow", _hit_point(), 8.0, 0.55, 140.0)
	_on_begin(m)


## A move it didn't just do: the first of `wants` whose cooldown is up and isn't the last one begun, else "".
## (beast pass: only its phase's moves; a chain's next goes whatever its cooldown, but for the big ones)
func pick(wants: Array) -> String:
	for m in wants:
		if bp and not bp.allows(str(m)):
			continue
		var ready := float(_cd.get(m, 0.0)) <= 0.0 or (bp != null and bp.in_chain and not str(m) in _chain_waits())
		if str(m) != _last_move and ready:
			if bp:
				bp.picked = true
			return str(m)
	if bp and bp.in_chain:
		# (nothing in reach to carry the chain on with: it's over, and the opening comes now)
		bp.chain_over()
		mv_t = -0.8
	return ""


## (tools: bossshot, the tests) Do `m` now, whatever the brain would pick.
func film(m: String) -> void:
	begin(m)


func end_move(recover: float = 0.0) -> void:
	if bp and move != "" and state == S.FIGHT:
		recover = bp.opening(move, recover)
	move = ""
	mv_t = -recover
	_fly = false


func _physics_process(delta: float) -> void:
	if net_puppet:
		return
	if state == S.DEAD:
		_dead_t += delta
		_corpse(delta)
		return
	if state == S.SLEEP:
		_dormant_t -= delta
		if _dormant_t <= 0.0:
			_dormant_t = 0.5
			_dormant = true
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < DORMANT_R:
					_dormant = false
		if _dormant:
			return
	if wake_r > 0.0:
		_watch(delta)
	st_t += delta
	for k in _cd.keys():
		_cd[k] -= delta * (1.0 + 0.25 * float(phase - 1))
	_poise = maxf(_poise - 30.0 * delta, 0.0)
	var p := _target() if state != S.SLEEP else null
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var want := Vector3.ZERO
	match state:
		S.SLEEP:
			want = _idle(delta)
		S.FIGHT:
			if move != "":
				mv_t += delta
				want = _moment_tick() if move == "moment" else _move_tick(delta, p)
			else:
				# (mv_t < 0: getting over the last move, an opening)
				mv_t += delta
				if p != null and mv_t >= 0.0:
					want = _brain(delta, p, to_p, dist)
		S.STAGGER:
			if st_t > _stagger_len:
				_set_state(S.FIGHT)
				mv_t = 0.0
		S.RETURN:
			var home := _flat(post - global_position)
			if home.length() < 1.5:
				_set_state(S.SLEEP)
			else:
				var nd := _nav_dir(post, delta)
				_face(nd)
				want = nd * _speed() * 0.6
	if _fly:
		model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(_turn * delta, 1.0))
		return
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var hv := _flat(velocity).move_toward(want, 26.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, _yaw, minf(_turn * delta, 1.0))


## Asleep (or not yet roused): what it does meanwhile (stays put at its post).
func _idle(_delta: float) -> Vector3:
	_yaw = post_yaw
	return Vector3.ZERO


func _watch(delta: float) -> void:
	_watch_t -= delta
	if _watch_t > 0.0:
		return
	_watch_t = 0.5
	if state == S.SLEEP:
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(global_position) < wake_r and p.has_method("is_standing") and p.is_standing():
				alert()
				return
	elif in_combat():
		var near := false
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(global_position) < leash_r and p.has_method("is_standing") and p.is_standing():
				near = true
		_empty_t = 0.0 if near else _empty_t + 0.5
		if _empty_t > 6.0:
			_empty_t = 0.0
			reset_fight()


## A name and health bar over its head.
func overhead(title: String, height: float) -> void:
	_overhead = OverheadBar.new().setup(title, height)
	add_child(_overhead)


func _phase_check() -> void:
	var at := _phase_at()
	var f := health_frac()
	var was := phase
	while phase - 1 < at.size() and f < float(at[phase - 1]):
		phase += 1
		phase_changed.emit(phase)
		_on_phase(phase)
	if bp and phase != was and state != S.DEAD:
		bp.phase_up(phase)
		end_move()
		_set_state(S.FIGHT)
		begin("moment")


## (beast pass) The phase change's moment: it reels, rears up roaring (the kind poses move "moment"), and at
## MOMENT_RING a ring of its roar pushes everyone back (BeastFX.moment on every screen: the camera punches in).
func _moment_tick() -> Vector3:
	if mv_t > BeastPass.MOMENT_RING and not _hit:
		_hit = true
		strike("ring", [global_position, BeastPass.MOMENT_R], 6.0, false, false, 1.1, 12.0, 0.6)
		BeastFX.moment(global_position, 1.0, _moment_color())
		Net.event(self, "moment", [global_position])
		_on_moment()
	if mv_t > BeastPass.MOMENT_S:
		end_move(0.3)
	return Vector3.ZERO


## Everyone left (or fell): back to its post, healed, asleep, from the top.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	end_move()
	phase = 1
	_poise = 0.0
	health.current_health = health.max_health
	_set_state(S.RETURN)
	if bp:
		bp.reset()
		_on_look()


# ==========================================================================
# Its blows: shapes each captain's own machine judges
# ==========================================================================
## shape "ring" [centre, r] / "ball" [centre, r] (in the air too) / "cone" [from,
## dir, reach, half angle (deg)] / "lane" [from, to, half width]. Jumped over when
## the captain's feet are `jump` m over the shape's ground (INF: no jumping it).
## `parry`: a parry turns it (and calls parried()).
## `stun`: how long a blow that lands staggers you (1.20: a gaze, a blinding spit hold you longer).
func strike(shape: String, args: Array, base_dmg: float, knock: bool, parry: bool = false, jump: float = 1.1, kb: float = 9.0, stun: float = 0.4) -> void:
	var d := _dmg(base_dmg)
	_strike_local(shape, args, d, knock, parry, jump, kb, stun)
	Net.event(self, "strike", [shape, args, d, knock, parry, jump, kb, stun])


func _strike_local(shape: String, args: Array, dmg: float, knock: bool, parry: bool, jump: float, kb: float, stun: float = 0.4) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	if not BeastShapes.inside(shape, args, me.global_position, jump):
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = knock
	hd.unblockable = not parry
	hd.knockback_force = kb
	hd.stagger_duration = stun
	hd.hitstop_duration = 0.08
	hd.camera_shake_intensity = 0.28
	hb.take_hit(hd, self)


## A red ring where a blow will land, on every screen.
func warn_ring(at: Vector3, r: float, secs: float, col: Color = Color(1.0, 0.18, 0.12)) -> void:
	Net.fx("telegraph", [at, r, secs, col])


## A red strip where a lunge or a charge will run, on every screen.
func warn_lane(from: Vector3, to: Vector3, w: float, secs: float, col: Color = Color(1.0, 0.18, 0.12)) -> void:
	BeastFX.lane(from, to, w, secs, col)
	Net.event(self, "lane", [from, to, w, secs, col])


## One of the beasts' own sounds (BeastFX), on every screen.
func say(n: String, at: Vector3, vol: float = 0.0, pitch: float = 1.0, reach: float = 80.0) -> void:
	BeastFX.sfx(n, at, vol, pitch, reach)
	Net.event(self, "say", [n, at, vol, pitch, reach])


## Leaves shaken down, on every screen.
func shower(at: Vector3, amount: int = 16, r: float = 2.5) -> void:
	BeastFX.leaves(at, amount, r)
	Net.event(self, "leaves", [at, amount, r])


## The big ones land: dust, a thud and the ground shaking.
func quake(at: Vector3, size: float = 1.0) -> void:
	Net.fx("dust_ring", [at, int(24 * size), 1.6 * size])
	Net.fx("dust", [at + Vector3(0, 0.4, 0), int(10 * size), 1.2 * size])
	Net.fx("sfx", ["thud", at, 5.0, 0.05, 0.5])
	get_node("/root/CombatManager").apply_camera_shake(0.35 * size)


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	if spirit and (hit.ranged or hit.impact == "shot"):
		Net.fx("sparkle", [_hit_point(), 6, Humanoid.SPIRIT])
		return
	_hit_by = attacker
	if hit.dot:
		Net.damage_number(hit.damage, global_position + Vector3(0, 2.0, 0))
		health.take_damage(hit.damage)
		_phase_check()
		return
	var dir := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else -_fwd()
	var dmg := hit.damage * _taken_k(attacker) * (BeastPass.VULN_K if bp and bp.vulnerable() else 1.0)
	var shove := clampf(dmg / 30.0, 0.25, 1.5)
	_flash_hit()
	if bp:
		bp.motion.hit(model.global_basis.inverse() * dir, shove)
	Net.event(self, "flash", [dir, shove])
	Net.damage_number(dmg, _hit_point())
	Net.fx("impact", [_hit_point() - dir * 0.5, Color(1.0, 0.6, 0.45)])
	if spirit:
		Net.fx("sparkle", [_hit_point(), clampi(int(hit.damage * 0.4), 6, 16), Humanoid.SPIRIT])
	else:
		Net.fx("blood", [_hit_point(), dir, clampi(int(hit.damage * 0.5), 6, 20)])
	CombatManager.impact(hit, global_position, -1.0, 0.1, 0.8 if hit.damage > 20.0 else 0.95)
	if not Net.active or attacker == Net.local_player:
		get_node("/root/CombatManager").apply_hit_effects(hit, [attacker])
	health.take_damage(dmg)
	if state == S.DEAD:
		return
	if state == S.SLEEP or state == S.RETURN:
		alert()
		return
	if bp and attacker is Node3D and not hit.ranged:
		part_hit(bp.parts.near(BeastParts.blow_at(attacker, global_position)), dmg)
	_phase_check()
	if state == S.STAGGER or move == "moment":
		return
	if (hit.haki or hit.breaker) and _armoured() and mv_t < 0.6:
		stagger(1.6)
		return
	# (hits while it's getting over a move - an opening - count double toward a stagger)
	var opening := move == "" and mv_t < 0.0
	if bp:
		# (1.23: beast poise; it reels, never off its feet or up in the air)
		if _armoured():
			return
		var ph := hit.duplicate() as HitData
		if opening:
			ph.poise = Poise.of(hit) * 2.0
		if bp.poise.take(ph) == Poise.BREAK:
			poise_break()
		return
	_poise += hit.damage * (1.6 if hit.knockdown else 1.0) * (2.0 if opening else 1.0)
	if _poise >= _poise_max() and not _armoured():
		stagger(2.0)


## (beast pass) What a blow from `attacker` is worth on it (a broken plate, a bare patch of hide: more).
func _taken_k(_attacker: Node) -> float:
	return 1.0


## (beast pass) Its poise ran out: the stagger pose, double damage for VULN_S.
func poise_break() -> void:
	bp.broke()
	Net.fx("float_text", [_hit_point() + Vector3(0, 2.0, 0), "Staggered!", Color(1.0, 0.9, 0.4), 32])
	stagger(BeastPass.REEL_S)


## (beast pass) `dmg` lands on part `n` ("" none): broken, it drops its material for every captain, changes the look,
## takes its moves away (_part_takes) and drains a lot of poise.
func part_hit(n: String, dmg: float) -> void:
	if not bp.parts.hurt(n, dmg):
		return
	var at := bp.parts.where(n)
	BeastFX.part_break(at, bp.parts.color(n))
	Net.event(self, "part", [n, at])
	Net.fx("float_text", [at + Vector3.UP * 1.5, "%s broken!" % _part_name(n), Color(1.0, 0.85, 0.4), 28])
	Net.kill_loot([[bp.parts.item(n), 1.0 / Loot.PART_K, 1]], ground_at(at) + Vector3.UP * 0.3)
	_on_look()
	_on_part(n)
	var ph := HitData.new()
	ph.damage = 0.0
	ph.poise = BeastPass.PART_POISE
	if bp.poise.take(ph) == Poise.BREAK and state == S.FIGHT and move != "moment":
		poise_break()
	elif move == "" and state == S.FIGHT:
		stagger(0.9)


func _part_name(n: String) -> String:
	return n.capitalize()


## Where hits show (numbers, sparks): the middle of the body.
func _hit_point() -> Vector3:
	return global_position + Vector3(0, 1.4, 0)


func stagger(secs: float) -> void:
	_poise = 0.0
	end_move()
	if bp:
		bp.chain_over()
	_stagger_len = secs
	velocity = Vector3.ZERO
	_set_state(S.STAGGER)
	_on_stagger()
	Net.fx("sparkle", [_hit_point() + Vector3(0, 0.6, 0), 16, Color(1.0, 0.95, 0.55)])


func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if state != S.FIGHT or not _parry_ok():
		return
	Net.fx("sfx", ["parry", _hit_point(), 0.0, 0.05, 0.8])
	stagger(2.2)


func rooted(secs: float) -> void:
	if Net.forward(self, "rooted", [secs]):
		return
	if state == S.FIGHT and not _armoured():
		stagger(minf(secs, 0.8))
		Net.fx("vine_wrap", [self, minf(secs, 0.8), 0.9])


func grabbed(_secs: float) -> void:
	pass


func _set_tint(c: Color) -> void:
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("tint_mul", c)


func _flash_hit() -> void:
	if _flash:
		_flash.kill()
	_set_tint(Color(2.2, 1.0, 0.9))
	_flash = create_tween()
	_flash.tween_method(_set_tint, Color(2.2, 1.0, 0.9), Color.WHITE, 0.16)


func _on_died() -> void:
	if state == S.DEAD:
		return
	end_move()
	_set_state(S.DEAD)
	_dead_t = 0.0
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	_on_die()
	Net.event(self, "die", [])
	Net.coins(global_position + Vector3(0, 1.5, 0), roundi(_coins_base() * Levels.coins_k(level)))
	# (1.26: a boss is the whole crew's, wherever they are)
	Net.award_xp(roundi(_xp_base() * Levels.xp_k(level)), global_position + Vector3(0, 3.0, 0), INF)
	Net.bounty("boss", global_position, 70.0, 1.0 if is_in_group("bosses") else 0.4)   # (a miniboss, the roamer: less)
	died.emit(self)


func _net_die() -> void:
	if state == S.DEAD:
		return
	move = ""
	state = S.DEAD
	_dead_t = 0.0
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	_on_die()
	died.emit(self)


## The body lies a while, then sinks into the floor and is gone.
func _corpse(delta: float) -> void:
	if _dead_t > CORPSE_SECS:
		global_position += Vector3.DOWN * 0.8 * delta
		if _dead_t > CORPSE_SECS + 4.0:
			queue_free()


func _process(delta: float) -> void:
	if net_puppet:
		_net_update(delta)
		if state == S.DEAD:
			_dead_t += delta
			_corpse(delta)
	if _overhead:
		_overhead.visible = state != S.DEAD
		_overhead.track(health.current_health, health.max_health)
	if _dormant and state == S.SLEEP:
		return
	if bp:
		bp.motion.tick(delta, state == S.STAGGER, clampf([0.25, 0.55, 0.85][phase - 1] + (0.3 if move == "" and mv_t < 0.0 else 0.0), 0.0, 1.0))
	_animate(delta)


# ==========================================================================
# Co-op
# ==========================================================================
func net_pack() -> Array:
	return [global_position, model.rotation.y, int(state), move, mv_t, health.current_health, health.max_health, phase,
		model.visible, _pack_extra(), bp.parts.mask() if bp else 0]


func _net_update(_delta: float) -> void:
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	if int(a[2]) == S.DEAD:
		_net_die()
		return
	if state == S.DEAD:
		return
	global_position = (a[0] as Vector3).lerp(b[0], f)
	model.rotation.y = lerp_angle(float(a[1]), float(b[1]), f)
	_yaw = model.rotation.y
	state = int(a[2]) as S
	if str(a[3]) != move:
		move = str(a[3])
		_hit = false
	mv_t = lerpf(float(a[4]), float(b[4]), f) if str(a[3]) == str(b[3]) else float(a[4])
	health.max_health = float(b[6])
	health.current_health = float(b[5])
	if int(b[7]) != phase:
		phase = int(b[7])
		phase_changed.emit(phase)
	model.visible = bool(a[8])
	_unpack_extra(a[9], b[9], f)
	if bp and b.size() > 10 and not bp.parts.set_mask(int(b[10])).is_empty():
		_on_look()


func net_event(what: String, args: Array) -> void:
	match what:
		"flash":
			_flash_hit()
			if bp and args.size() > 1:
				bp.motion.hit(model.global_basis.inverse() * (args[0] as Vector3), float(args[1]))
		"moment":
			BeastFX.moment(args[0], 1.0, _moment_color())
		"part":
			if bp:
				BeastFX.part_break(args[1], bp.parts.color(str(args[0])))
		"strike":
			_strike_local(str(args[0]), args[1], float(args[2]), bool(args[3]), bool(args[4]), float(args[5]), float(args[6]), float(args[7]) if args.size() > 7 else 0.4)
		"lane":
			BeastFX.lane(args[0], args[1], float(args[2]), float(args[3]), args[4])
		"say":
			BeastFX.sfx(str(args[0]), args[1], float(args[2]), float(args[3]), float(args[4]))
		"leaves":
			BeastFX.leaves(args[0], int(args[1]), float(args[2]))
		"die":
			_net_die()
		_:
			_event(what, args)
