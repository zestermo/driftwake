class_name CannonArts
## The cannon (style "cannon", tree "cannon": brimstone - sulphur-yellow blasts, violet smoke, burning shrapnel). A hand
## cannon on the right shoulder: left click braces and fires a ball (Shell "ball") that bursts where it lands, its splash
## throwing down everyone round it; the recoil shoves you back; one load and a long reload (ShootState through
## shoot_enter / shoot_update). Right click swings the barrel like a club (HeavyAttackState "barrel_bash"), Cannon Ram
## at a sprint, Recoil Leap in the air (fired straight down, the blast throws you up), and the techniques: Canister Shot,
## Chain Shot, Mortar Lob, Rocket Charge, the Leviathan Shell. What a round does when it lands is shell_hit's.

const RANGE := 60.0
const SPEED := 40.0
const GRAVITY := 9.0
## A ball: the one it strikes, the splash round it (its rim takes half), the splash's radius (x the design's "blast").
const DIRECT := 45.0
const SPLASH := 28.0
const BLAST := 3.2
## A plain shot floors the one it hits only this close (m); further out it staggers and drains poise.
const CLOSE_DOWN := 4.0
const RELOAD := 2.4
## The shot leaves FIRE_AT s into cn_fire (the brace), the move's length, the shove back (m/s; Braced halves it).
const FIRE_AT := 0.25
const FIRE_LEN := 0.9
const RECOIL := 6.0
const FXS := preload("res://scripts/game/fx.gd")


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func muzzle(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * GunModels.cn_muzzle(p.equipped_weapon.design)


static func _elem(p: Player, tier: int = 1) -> bool:
	return p.progression.elemental("cannon", tier)


static func _col(p: Player, which: int, tier: int = 1) -> Color:
	return FXS.tree_col("cannon" if _elem(p, tier) else "plain", which)


## The splash's radius for the cannon in hand.
static func blast_r(p: Player, base: float = BLAST) -> float:
	return base * GunKinds.design(p.equipped_weapon, "blast") * (1.0 + p.progression.style_stat("blast", "cannon"))


# --------------------------------------------------------------------------
# The shot (ShootState)
# --------------------------------------------------------------------------
static func shoot_enter(s) -> void:
	var p: Player = s.player
	s.steady = 0.0
	s.face_direction(s.get_camera_forward(), 1.0)
	var ran := p.quick_draw
	p.quick_draw = false
	if ran and p.progression.has_move("cannon_ram"):
		_ram_enter(s)
		return
	if p.reloading() or p.ammo[0] <= 0:
		if not p.reloading():
			p.start_reload()
		s.mode = "idle"
		s.dur = 0.15
		return
	s.mode = "brace"
	s.dur = FIRE_LEN
	LongGunArts._pitch(p)
	p.body_model.play("cn_fire", FIRE_LEN)
	_net().fx("sfx", ["blip_low", p.global_position, -10.0, 0.0, 0.7])


static func shoot_update(s, delta: float) -> void:
	var p: Player = s.player
	s.timer += delta
	match s.mode:
		"brace":
			LongGunArts._walk(s, delta, 0.15)
			s.face_camera(delta)
			LongGunArts._pitch(p)
			if s.timer >= FIRE_AT:
				fire(p)
				s.mode = "fired"
		"ram":
			_ram_update(s, delta)
			return
		_:
			LongGunArts._walk(s, delta, 0.3)
	if s.mode == "fired" and s.timer >= FIRE_LEN * 0.7 and p.ammo[0] <= 0 and not p.reloading():
		p.start_reload()
	if s.timer >= s.dur:
		LongGunArts._done(s)


static func shoot_exit(s) -> void:
	LongGunArts.shoot_exit(s)


## A ball at the reticle on the low arc that reaches it; the blast at the muzzle and the shove back.
static func fire(p: Player) -> void:
	var mz := muzzle(p)
	var reach := RANGE * GunKinds.design(p.equipped_weapon, "range")
	var to := GunKinds.aim_point(p, mz, reach, 0.08)
	var v := Shell.aim_v(mz, to, SPEED, GRAVITY)
	Shell.launch(p.get_tree(), "ball", mz, v, p, DIRECT)
	p.ammo[0] -= 1
	var dir := v.normalized()
	_net().fx("cannon_fire", [mz, dir])
	if _elem(p):
		_net().fx("element", ["cannon", mz + dir * 0.4, dir, 10, 6.0])
	_net().fx("sfx", ["cannon", mz, -2.0, 0.05, 1.25])
	p.cam_shake(0.3)
	p.cam_kick(0.15, 0.25)
	var back := Vector3(dir.x, 0.0, dir.z).normalized()
	var k := RECOIL * (1.0 - p.progression.style_stat("recoil", "cannon"))
	p.velocity.x -= back.x * k
	p.velocity.z -= back.z * k
	p.squash(-3.0)


# --------------------------------------------------------------------------
# Where a round lands (Shell, on the shooter's machine)
# --------------------------------------------------------------------------
const MORTAR_R := 2.6
const MORTAR_DAMAGE := 22.0
const CHAIN_DAMAGE := 26.0
const GIANT_R := 8.0
const GIANT_DAMAGE := 70.0


static func shell_hit(sh: Shell, at: Vector3, normal: Vector3, hb: Hurtbox) -> void:
	var p := sh.source as Player
	match sh.kind:
		"ball":
			explode(p, at, normal, blast_r(p), sh.damage, SPLASH, hb, 1.0, "", false, true)
		"mortar":
			explode(p, at, normal, blast_r(p, MORTAR_R), sh.damage, sh.damage, hb, 0.8, "skill")
		"giant":
			explode(p, at, normal, GIANT_R, sh.damage, sh.damage, hb, 3.0, "skill", true)
			var seed := randi()
			for i in 6:
				var a := TAU * float(i) / 6.0
				_net().fx("ground_crack", [at, Vector3(cos(a), 0.0, sin(a)), 5.5, _col(p, FXS.ACCENT) if _elem(p) else Color(0, 0, 0, 0), seed + i, 0.2])
			if _elem(p):
				FireZone.spawn(p.get_tree(), at, 5.0, 4.0, 8.0, p)
		"chain":
			# (its line ends on a wall or the ground: just dust there)
			if hb == null:
				_net().fx("dust", [at, 6, 0.6])
				return
			var hd := GunKinds.shot_hit(p, sh.damage, "skill")
			hd.stagger_duration = 1.0
			hd.knockback_force = 8.0
			hd.hitstop_duration = 0.05
			hd.sever = true
			GunKinds.strike(p, hb, hd)
			_net().fx("impact", [GunKinds.center(hb), _col(p, FXS.EDGE)])
			_net().fx("sfx", ["chop", at, -2.0, 0.08, 0.8])


## A burst at `at`: the one struck (`hb`) takes `direct`, everyone within `radius` the splash (half at the rim), all
## knocked down and thrown out (a plain shot: staggered, floored only point-blank); `size` scales the show, `kind` the hit's (a technique's: "skill"). With the design's
## "burn" (the dragon cannon) or the element on every blow they burn.
static func explode(p: Player, at: Vector3, normal: Vector3, radius: float, direct: float, splash: float, hb: Hurtbox, size: float, kind := "", unblock := false, plain := false) -> Array:
	var hit: Array = []
	# (1.26) a plain shot staggers: it floors only point-blank (CLOSE_DOWN); poise does the rest. Techniques, the ram and the
	# leap still throw everyone down.
	var floors := not plain or p.global_position.distance_to(at) <= CLOSE_DOWN
	if hb:
		var hd := GunKinds.shot_hit(p, direct, kind)
		hd.knockdown = floors
		hd.breaker = true
		hd.unblockable = unblock
		hd.knockback_force = 13.0 if floors else 6.0
		hd.stagger_duration = 0.8
		hd.hitstop_duration = 0.08
		hd.camera_shake_intensity = 0.0
		hd.poise = Poise.HEAVY
		GunKinds.strike(p, hb, hd)
		hit.append(hb.owner)
	var sp := GunKinds.shot_hit(p, splash, kind)
	sp.knockdown = not plain
	sp.breaker = true
	sp.unblockable = unblock
	sp.knockback_force = 4.0 if plain else 11.0
	sp.stagger_duration = 0.7
	sp.hitstop_duration = 0.0
	sp.camera_shake_intensity = 0.0
	sp.poise = Poise.HEAVY
	hit.append_array(GunKinds.splash(p, at, radius, sp, 0.5, hit))
	var burn := GunKinds.design(p.equipped_weapon, "burn", 0.0)
	if burn > 0.0 or _elem(p, 2):
		for e in hit:
			if is_instance_valid(e):
				BurnStatus.apply(e as Node3D, maxf(burn, 3.0), 5.0, p)
	var glow := _col(p, FXS.ACCENT) if _elem(p) else Color(0, 0, 0, 0)
	_net().fx("cannon_blast", [at, size * radius / BLAST, glow])
	_net().fx("cannon_hit", [at, normal])
	if _elem(p):
		_net().fx("element", ["cannon", at + Vector3(0, 0.5, 0), Vector3.UP, 12, 5.0])
	_net().fx("sfx", ["cannon_hit", at, 0.0, 0.08, 1.0])
	var near := p.global_position.distance_to(at)
	p.cam_shake(clampf(0.45 - near * 0.02, 0.05, 0.4) * minf(size, 1.5))
	return hit


## Cannon Ride's throw (CrewTechniqueState): the crewmate on the barrel (or you, Recoil Jump) rides the blast along `v`.
static func crew_throw(p: Player, at: Vector3, v: Vector3) -> void:
	var mz := muzzle(p)
	_net().fx("cannon_fire", [mz, v.normalized()])
	_net().fx("cannon_blast", [at, 0.7, _col(p, FXS.ACCENT) if _elem(p) else Color(0, 0, 0, 0)])
	_net().fx("sfx", ["cannon", mz, 0.0, 0.05, 1.15])
	p.cam_shake(0.3)


# --------------------------------------------------------------------------
# Cannon Ram (attacked at a sprint): the muzzle driven into them at the run
# --------------------------------------------------------------------------
const RAM_SPEED := 12.0
const RAM_DAMAGE := 26.0


static func _ram_enter(s) -> void:
	var p: Player = s.player
	s.mode = "ram"
	s.dur = ActionSpecs.length("cn_ram")
	p.set_reach("cannon")
	p.body_model.play("cn_ram", s.dur)
	_net().fx("sfx", ["whoosh_big", p.global_position, -6.0, 0.06, 0.75])


static func _ram_update(s, delta: float) -> void:
	var p: Player = s.player
	var w := ActionSpecs.hit_seconds("cn_ram")
	var f: Vector3 = -p.player_model.global_basis.z
	s.apply_gravity(delta)
	var spd := RAM_SPEED if s.timer < w.y else move_toward(Vector2(p.velocity.x, p.velocity.z).length(), 0.0, 30.0 * delta)
	p.velocity.x = f.x * spd
	p.velocity.z = f.z * spd
	p.move_and_slide()
	if s.timer >= w.x and s.steady < 1.0:
		s.steady = 1.0
		var hd := p.melee_hit(RAM_DAMAGE, "finisher")
		hd.knockdown = true
		hd.breaker = true
		hd.knockback_force = 14.0
		hd.stagger_duration = 0.8
		hd.hitstop_duration = 0.11
		hd.camera_shake_intensity = 0.2
		p.sword_hitbox.activate(hd)
		_net().fx("punch_wind", [p.global_position + Vector3(0, 1.1, 0) + f * 0.8, f, 1.6, _col(p, FXS.EDGE, 2), true])
		_net().fx("sfx", ["thud", p.global_position, -2.0, 0.06, 0.8])
		p.squash(-3.5)
	if s.timer >= w.y and p.sword_hitbox.active:
		p.sword_hitbox.deactivate()
	if s.timer >= s.dur:
		LongGunArts._done(s)


# --------------------------------------------------------------------------
# The barrel bash's show (HeavyAttackState._strike_fx)
# --------------------------------------------------------------------------
static func heavy_fx(p: Player, elem: bool) -> void:
	var f := -p.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var at := p.global_position + f * 1.4
	_net().fx("heavy_dust", [at, 10, 0.8])
	_net().fx("ring", [at + Vector3(0, 0.1, 0), Vector3.UP, 1.8, _col(p, FXS.EDGE, 2), 0.26, 0.12])
	_net().fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + f * 0.3, 4, Color(0.35, 0.3, 0.25), 4.0])
	if elem:
		_net().fx("element", ["cannon", at + Vector3(0, 0.4, 0), Vector3.UP, 8, 4.0])
	p.cam_kick(0.14, 0.28)


# --------------------------------------------------------------------------
# Recoil Leap (attacked in the air): the muzzle straight down, fired: the blast below throws everyone round it down
# and you up and on
# --------------------------------------------------------------------------
const LEAP_FIRE := 0.2
const LEAP_LEN := 0.8
const LEAP_DOWN := 6.0
const LEAP_R := 3.0
const LEAP_DAMAGE := 24.0
const LEAP_V := Vector2(6.0, 13.0)


static func air_enter(s) -> void:
	var p: Player = s.player
	p.variable_jump_active = false
	p.velocity = Vector3(p.velocity.x * 0.4, maxf(p.velocity.y, 0.0) * 0.2, p.velocity.z * 0.4)
	p.body_model.play("cn_air", LEAP_LEN)
	_net().fx("sfx", ["blip_low", p.global_position, -10.0, 0.0, 0.7])


static func air_update(s, delta: float) -> void:
	var p: Player = s.player
	if not s._fired:
		p.velocity.y = move_toward(p.velocity.y, -1.0, 10.0 * delta)
		s.face_direction(s.get_camera_forward(), delta)
		if s.timer >= LEAP_FIRE:
			s._fired = true
			var mz := muzzle(p)
			var q := PhysicsRayQueryParameters3D.create(mz, mz + Vector3.DOWN * LEAP_DOWN, 1)
			q.exclude = [p.get_rid()]
			var h := p.get_world_3d().direct_space_state.intersect_ray(q)
			var at: Vector3 = h["position"] if not h.is_empty() else mz + Vector3.DOWN * LEAP_DOWN
			p.ammo[0] -= 1
			explode(p, at, Vector3.UP, blast_r(p, LEAP_R), LEAP_DAMAGE, LEAP_DAMAGE, null, 0.9)
			_net().fx("cannon_fire", [mz, Vector3.DOWN])
			_net().fx("sfx", ["cannon", mz, -2.0, 0.05, 1.3])
			var f: Vector3 = s.get_camera_forward()
			p.velocity = f * LEAP_V.x + Vector3.UP * LEAP_V.y
			p.squash(5.0)
	else:
		s.apply_gravity(delta)
	p.move_and_slide()
	if s._fired and p.is_on_floor() and s.timer > LEAP_FIRE + 0.15:
		if p.ammo[0] <= 0:
			p.start_reload()
		s.transitioned.emit(s, "Idle", {})
	elif s.timer >= LEAP_LEN:
		if p.ammo[0] <= 0:
			p.start_reload()
		s.transitioned.emit(s, "Fall", {})


# --------------------------------------------------------------------------
# The techniques (TechniqueState `s`): Canister Shot (a canister of grape: a cone of shot that hurls everyone close in
# front back), Chain Shot (two balls on a chain, spinning down the line through everyone on it), Mortar Lob (three
# shells lobbed high onto the reticle and either side of it), Rocket Charge (fired backwards: the recoil hurls you
# through them), the Leviathan Shell (ult: braced on a knee, one giant shell that levels everything round where it lands).
# Poses: cn_fire, cn_lob, cn_back, cn_brace.
# --------------------------------------------------------------------------
const CANISTER_AT := 0.25
const CANISTER_REACH := 14.0
const CANISTER_CONE := 0.62
const CANISTER_BALLS := 18
const CANISTER_BALL := 5.0

const CHAIN_AT := 0.25
const CHAIN_SPEED := 30.0

const LOB_AT := [0.35, 0.5, 0.65]
const LOB_REACH := 30.0
const LOB_SIDE := 2.6
const LOB_SECS := 0.9

const ROCKET_AT := 0.2
const ROCKET_END := 0.68
const ROCKET_SPEED := 20.0
const ROCKET_R := 1.5
const ROCKET_DAMAGE := 26.0

const LEVI_DUR := 1.9
const LEVI_MOMENT := 0.45
const LEVI_FIRE := 0.95
const LEVI_SPEED := 28.0
const LEVI_GRAVITY := 6.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"canister_shot", "chain_shot":
			s.dur = FIRE_LEN
			LongGunArts._pitch(p)
			p.body_model.play("cn_fire", FIRE_LEN)
		"mortar_lob":
			s.dur = 1.2
			# (where they'll come down: the reticle's spot, kept in _from)
			s._from = GunKinds.aim_point(p, muzzle(p), LOB_REACH, 0.1)
			p.body_model.play("cn_lob", s.dur)
		"rocket_charge":
			s.dur = 1.0
			s._hit = []
			p.body_model.play("cn_back", s.dur)
			_net().fx("sfx", ["blip_low", p.global_position, -8.0, 0.0, 0.6])
		"leviathan_shell":
			s.dur = LEVI_DUR
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.hold("cn_brace", 0.2)
			LongGunArts._pitch(p)
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	var p: Player = s.player
	match s.id:
		"canister_shot":
			s._rooted(delta, 0.0)
			if s._once("fire", CANISTER_AT):
				_canister(s)
		"chain_shot":
			s._rooted(delta, 0.0)
			if s._once("fire", CHAIN_AT):
				var mz := muzzle(p)
				var dir := (GunKinds.aim_point(p, mz, 40.0) - mz).normalized()
				Shell.launch(p.get_tree(), "chain", mz, dir * CHAIN_SPEED, p, CHAIN_DAMAGE)
				_report(s, mz, dir, 0.9)
		"mortar_lob":
			s._rooted(delta, 0.0)
			var side: Vector3 = s._dir.cross(Vector3.UP).normalized()
			for i in LOB_AT.size():
				if s._once("lob%d" % i, float(LOB_AT[i])):
					var mz := muzzle(p)
					var to: Vector3 = s._from + side * LOB_SIDE * float([0, -1, 1][i])
					Shell.launch(p.get_tree(), "mortar", mz, Shell.lob_v(mz, to, LOB_SECS, float(Shell.KINDS["mortar"][1])), p, MORTAR_DAMAGE)
					_report(s, mz, Vector3.UP, 0.8)
					_net().fx("ring", [to, Vector3.UP, MORTAR_R, s._col(), LOB_SECS, 0.08])
		"rocket_charge":
			if s.t < ROCKET_AT:
				s._rooted(delta, 0.0)
			elif s.t < ROCKET_END:
				s.apply_gravity(delta)
				p.velocity.x = s._dir.x * ROCKET_SPEED
				p.velocity.z = s._dir.z * ROCKET_SPEED
				p.move_and_slide()
				for e in s._pc.enemies_in(s._chest() - Vector3(0, 0.3, 0), ROCKET_R):
					if e in s._hit:
						continue
					s._hit.append(e)
					s._strike_toward(e, s._hd(ROCKET_DAMAGE, 12.0, true), s._dir)
					_net().fx("impact", [s._body_center(e), s._col(FXS.CORE)])
					p.cam_shake(0.15)
			else:
				s._rooted(delta, 0.0)
			if s._once("fire", ROCKET_AT):
				var mz := muzzle(p)
				_net().fx("cannon_fire", [mz, -s._dir])
				_net().fx("cannon_blast", [p.global_position - s._dir * 1.4, 0.8, s._col(FXS.ACCENT) if s._elem() else Color(0, 0, 0, 0)])
				_net().fx("sfx", ["cannon", mz, 0.0, 0.05, 1.1])
				_net().fx("afterimage", [p.body_model, s._col(), 0.3])
				p.cam_shake(0.3)
				p.cam_kick(0.2, 0.35)
		"leviathan_shell":
			s._rooted(delta, 0.0)
			s.face_direction(s.get_camera_forward(), delta)
			LongGunArts._pitch(p)
			if s._once("moment", LEVI_MOMENT):
				s._moment(0.35, 0.5, 0.35, 0.3)
				_net().fx("gather", [muzzle(p), 1.6, s._col(FXS.EDGE), 0.4, 20])
				_net().fx("sfx", ["blip_low", p.global_position, -4.0, 0.0, 0.5])
			if s._once("fire", LEVI_FIRE):
				var mz := muzzle(p)
				var to := GunKinds.aim_point(p, mz, RANGE, 0.1)
				var v := Shell.aim_v(mz, to, LEVI_SPEED, LEVI_GRAVITY)
				Shell.launch(p.get_tree(), "giant", mz, v, p, GIANT_DAMAGE)
				_report(s, mz, v.normalized(), 2.0)
				p.velocity -= Vector3(v.x, 0.0, v.z).normalized() * 8.0
				p.body_model.play("cn_fire", 0.8)
			if s._once("open", LEVI_DUR - 0.3):
				p.hurtbox.set_deferred("monitorable", true)
				p._reset_ammo()
		_:
			return false
	return true


## A technique's report from the muzzle: the blast, smoke, the boom and the kick.
static func _report(s, mz: Vector3, dir: Vector3, size: float) -> void:
	var p: Player = s.player
	_net().fx("blast", [mz + dir * 0.2, dir, size, true, Color(0.5, 0.48, 0.47, 0.85), 8.0])
	_net().fx("muzzle_sparks", [mz, dir, 18])
	if s._elem():
		_net().fx("element", ["cannon", mz + dir * 0.5, dir, 10, 6.0])
	_net().fx("sfx", ["cannon", mz, -3.0, 0.05, 1.2])
	p.cam_shake(0.22 * size)
	p.squash(-2.0)


## Canister Shot: CANISTER_BALLS balls in a cone, each foe struck once for the balls that found it.
static func _canister(s) -> void:
	var p: Player = s.player
	var mz := muzzle(p)
	var dir: Vector3 = s._dir
	var side := dir.cross(Vector3.UP).normalized()
	var got := {}
	for i in CANISTER_BALLS:
		var a := TAU * (float(i) + randf() * 0.5) / float(CANISTER_BALLS)
		var r := CANISTER_CONE * sqrt(randf_range(0.1, 1.0))
		var d := (dir + side * cos(a) * tan(r) + Vector3.UP * (sin(a) * tan(r) * 0.5 + 0.05)).normalized()
		var ln := GunKinds.line(p, mz, d, CANISTER_REACH, 1)
		if i % 3 != 2:
			_net().fx("tracer", [mz, ln[0], s._col(FXS.EDGE) if s._elem() else Color(1.0, 0.8, 0.5)])
		if not (ln[1] as Array).is_empty():
			var hb := (ln[1] as Array)[0] as Hurtbox
			got[hb] = int(got.get(hb, 0)) + 1
	for hb in got.keys():
		var hd: HitData = s._hd(CANISTER_BALL * int(got[hb]), minf(5.0 + int(got[hb]) * 1.5, 14.0), int(got[hb]) >= 3)
		hd.ranged = true
		hd.impact = "shot"
		s._strike(hb.owner, hd)
		_net().fx("impact", [GunKinds.center(hb), Color(1.0, 0.75, 0.45)])
	# (1.26) the grape bursting out of the barrel: a wide spray of hot shot along the cone
	_net().fx("muzzle_sparks", [mz + dir * 0.3, dir, 40])
	# (1.26) the grape bursting out of the barrel: hot shot sprayed across the whole cone
	for k in [-1.0, 0.0, 1.0]:
		_net().fx("muzzle_sparks", [mz + dir * 0.3, dir.rotated(Vector3.UP, k * CANISTER_CONE * 0.7), 14])
	_report(s, mz, dir, 1.3)
	p.velocity -= dir * 4.0
