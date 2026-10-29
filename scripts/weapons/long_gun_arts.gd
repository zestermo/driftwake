class_name LongGunArts
## Long guns (style "long_gun", tree "long_gun": starlight - silver tracers, a moon-blue edge, star glints where the
## shots land). Left click shoulders the gun and fires when let go: a tap is a quick shot, held the aim steadies over
## AIM_STEADY and a steady shot hits harder, goes through the first foe and knocks down (ShootState runs it through
## shoot_enter/shoot_update). The blunderbuss and the fowler scatter pellets in a cone instead, a steady aim
## tightening it. One load (the fowler two), then the ramrod. Right click is the butt stroke (HeavyAttackState
## "butt_stroke"), Stock Rush at a sprint, Sky Shot in the air (PlungeState through air_enter/air_update), and the
## techniques (TechniqueState through enter/update): Pinning Shot, Powder Burst, Volley Line, Stock Sweep, Hawkeye.

const RANGE := 70.0
const DAMAGE := 34.0
## Full damage out to FALLOFF_NEAR m, down to FALLOFF_MIN of it at the gun's range.
const FALLOFF_NEAR := 30.0
const FALLOFF_MIN := 0.6
## Shouldering before the shot can go (s), the hold to a steady aim, how much harder a steady shot hits (x1 + k).
const SHOULDER := 0.12
const AIM_STEADY := 0.7
const STEADY_K := 0.5
## Walking while aimed (x move speed), and after the shot.
const AIM_MOVE := 0.35
const FIRE_LEN := 0.6
const RELOAD := 1.5
## A scatter gun's pellet: damage, full out to SCATTER_NEAR m, down to SCATTER_MIN at its range.
const PELLET := 7.0
const SCATTER_NEAR := 5.0
const SCATTER_MIN := 0.25
## The kick back along the shot (m/s).
const RECOIL := 3.0
const POWDER := Color(0.62, 0.6, 0.58, 0.85)
const FXS := preload("res://scripts/game/fx.gd")


## Net (effects on every screen), reached through the tree: a static func can't see the autoloads in a --script run.
static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


## Where the muzzle is now.
static func muzzle(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, GunModels.LG_BORE, -GunModels.lg_barrel(p.equipped_weapon.design))


static func _elem(p: Player, tier: int = 1) -> bool:
	return p.progression.elemental("long_gun", tier)


static func _col(p: Player, which: int, tier: int = 1) -> Color:
	return FXS.tree_col("long_gun" if _elem(p, tier) else "plain", which)


# --------------------------------------------------------------------------
# The shot (ShootState)
# --------------------------------------------------------------------------
static func shoot_enter(s) -> void:
	var p: Player = s.player
	s.steady = 0.0
	s.face_direction(s.get_camera_forward(), 1.0)
	var ran := p.quick_draw
	p.quick_draw = false
	if ran and p.progression.has_move("stock_rush"):
		_rush_enter(s)
		return
	if p.reloading() or p.ammo[0] <= 0:
		if not p.reloading():
			p.start_reload()
		s.mode = "idle"
		s.dur = 0.15
		return
	s.mode = "aim"
	_pitch(p)
	p.body_model.hold("lg_aim", SHOULDER)


static func shoot_update(s, delta: float) -> void:
	var p: Player = s.player
	s.timer += delta
	match s.mode:
		"aim":
			_walk(s, delta, AIM_MOVE)
			s.face_camera(delta)
			_pitch(p)
			var st := clampf((s.timer - SHOULDER) / (AIM_STEADY * (1.0 - p.progression.style_stat("steady", "long_gun"))), 0.0, 1.0)
			if st >= 1.0 and s.steady < 1.0:
				_net().fx("glint", [muzzle(p), _col(p, FXS.CORE), 0.7])
				_net().fx("sfx", ["blip_high", p.global_position, -12.0, 0.0, 1.6])
			s.steady = st
			if s.timer > 0.3:
				p.cam_kick(0.12 + 0.2 * st, 0.25)
			if s.wants_dodge():
				p.body_model.stop_action()
				s.transitioned.emit(s, "Dodge", {})
				return
			if s.timer >= SHOULDER and not p.inp.pressed("light_attack"):
				fire(p, s.steady)
				s.mode = "fired"
				s.timer = 0.0
				s.dur = FIRE_LEN
		"rush":
			_rush_update(s, delta)
		_:
			_walk(s, delta, 0.5)
			if s.mode == "fired" and s.timer >= FIRE_LEN * 0.5 and p.ammo[0] <= 0 and not p.reloading():
				p.start_reload()
			if s.timer >= s.dur:
				_done(s)


## Leaving the shot by any way: an empty gun is reloaded.
static func shoot_exit(s) -> void:
	var p: Player = s.player
	p.sword_hitbox.deactivate()
	if p.ammo[0] <= 0 and not p.reloading():
		p.start_reload()


static func _walk(s, delta: float, k: float) -> void:
	var p: Player = s.player
	s.apply_gravity(delta)
	var mi: Vector2 = s.get_movement_input()
	var want: Vector3 = s.get_camera_relative_direction(mi) * p.move_speed * k if mi.length() > 0.1 else Vector3.ZERO
	p.velocity.x = move_toward(p.velocity.x, want.x, 30.0 * delta)
	p.velocity.z = move_toward(p.velocity.z, want.z, 30.0 * delta)
	p.move_and_slide()


static func _done(s) -> void:
	var p: Player = s.player
	if s.input_buffer.consume_action("light_attack") and not p.reloading() and p.ammo[0] > 0:
		GunKinds.art(p.style()).shoot_enter(s)  # (the sling and cannon end here too: their own shot, not the long gun's)
		s.timer = 0.0
		return
	var next: String = s.combat_input()
	if next != "":
		s.transitioned.emit(s, next, {})
	elif s.wants_dodge():
		s.transitioned.emit(s, "Dodge", {})
	else:
		s.transitioned.emit(s, "Move" if s.get_movement_input().length() > 0.1 else "Idle", {})


## The aim follows the reticle up and down (the shouldered pose leans with it; co-op: aim_pitch is synced).
static func _pitch(p: Player) -> void:
	var ray := p.reticle_ray()
	if not ray.is_empty():
		p.body_model.aim_pitch = clampf(asin(clampf((ray[1] as Vector3).y, -1.0, 1.0)) + 0.1, -0.6, 0.6)


## One shot from the shouldered gun at the reticle, `steady` (0-1) how settled the aim was. A ball down the line, or
## a scatter gun's pellets in a cone.
static func fire(p: Player, steady: float) -> void:
	var it := p.equipped_weapon
	var reach := RANGE * GunKinds.design(it, "range") * (1.0 + p.progression.style_stat("range", "long_gun"))
	var mz := muzzle(p)
	var dir := (GunKinds.aim_point(p, mz, reach) - mz).normalized()
	p.body_model.aim_pitch = clampf(asin(dir.y), -0.6, 0.6)
	p.ammo[0] -= 1
	var last: bool = p.ammo[0] <= 0
	var n := int(GunKinds.design(it, "spread", 0.0))
	if n > 0:
		_scatter(p, mz, dir, reach, n, steady, last)
	else:
		ball(p, mz, dir, reach, DAMAGE * (1.0 + STEADY_K * steady), steady >= 1.0, last)
	var big := n > 0
	_net().fx("blast", [mz + dir * 0.1, dir, 0.7 if big else 0.45, true, POWDER, 8.0])
	_net().fx("muzzle_sparks", [mz, dir, 22 if big else 14])
	if _elem(p):
		_net().fx("element", ["long_gun", mz + dir * 0.4, dir, 6, 5.0])
	_net().fx("sfx", ["gunshot", mz, 1.0, 0.05, 0.62 if big else 0.72])
	p.body_model.play("lg_fire", FIRE_LEN)
	p.cam_shake(0.16 if big else 0.11)
	p.cam_kick(0.1, 0.2)
	var back := Vector3(dir.x, 0.0, dir.z).normalized()
	p.velocity.x -= back.x * RECOIL * (1.6 if big else 1.0)
	p.velocity.z -= back.z * RECOIL * (1.6 if big else 1.0)
	p.squash(-1.5)


## A ball from `from` along `dir`: `pierce` goes through the first foe into a second (and knocks them down). The
## techniques fire it too.
static func ball(p: Player, from: Vector3, dir: Vector3, reach: float, base: float, pierce: bool, last: bool, kind: String = "") -> Array:
	var ln := GunKinds.line(p, from, dir, reach, 2 + int(p.progression.style_stat("pierce", "long_gun")) if pierce else 1)
	var end: Vector3 = ln[0]
	var hits: Array = ln[1]
	for i in hits.size():
		var hb := hits[i] as Hurtbox
		var at := GunKinds.center(hb)
		var far := from.distance_to(at)
		var hd := GunKinds.shot_hit(p, base * (1.0 if i == 0 else 0.7), kind)
		hd.damage *= lerpf(1.0, FALLOFF_MIN, clampf((far - FALLOFF_NEAR) / maxf(reach - FALLOFF_NEAR, 1.0), 0.0, 1.0))
		hd.knockback_force = 9.0 if pierce else 5.0
		hd.knockdown = pierce
		hd.stagger_duration = 0.8 if pierce else 0.45
		hd.hitstop_duration = 0.08 if pierce else 0.05
		hd.camera_shake_intensity = 0.12 if pierce else 0.06
		hd.poise = Poise.SHOT_CLOSE if far < Poise.CLOSE_M or pierce else Poise.SHOT * 2.0
		TraitMoves.shape_shot(p, hd, last)
		GunKinds.strike(p, hb, hd)
		_hit_fx(p, at, dir, pierce)
	if hits.is_empty():
		_net().fx("dust", [end, 4, 0.45])
	_net().fx("tracer", [from, end, _col(p, FXS.EDGE, 2) if _elem(p, 2) else Color(1.0, 0.92, 0.7)])
	return hits


## A scatter gun's load: `n` pellets in a cone (tighter the steadier the aim), each foe struck once for all the pellets
## that found it (harder close up; most of a load point-blank knocks them down).
static func _scatter(p: Player, from: Vector3, dir: Vector3, reach: float, n: int, steady: float, last: bool) -> void:
	var cone := GunKinds.design(p.equipped_weapon, "cone", 0.15) * lerpf(1.0, 0.5, steady)
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var got := {}
	for i in n:
		var a := TAU * (float(i) + randf() * 0.6) / float(n)
		var r := cone * sqrt(randf_range(0.15, 1.0))
		var d := (dir + side * cos(a) * tan(r) + up * sin(a) * tan(r)).normalized()
		var ln := GunKinds.line(p, from, d, reach, 1)
		if i % 2 == 0:
			_net().fx("tracer", [from, ln[0], _col(p, FXS.EDGE, 2) if _elem(p, 2) else Color(1.0, 0.85, 0.55)])
		if (ln[1] as Array).is_empty():
			if i % 3 == 0:
				_net().fx("dust", [ln[0], 2, 0.3])
			continue
		var hb := (ln[1] as Array)[0] as Hurtbox
		got[hb] = int(got.get(hb, 0)) + 1
	for hb in got.keys():
		var at := GunKinds.center(hb)
		var far := from.distance_to(at)
		var k := lerpf(1.0, SCATTER_MIN, clampf((far - SCATTER_NEAR) / maxf(reach - SCATTER_NEAR, 1.0), 0.0, 1.0))
		var c := int(got[hb])
		var hd := GunKinds.shot_hit(p, PELLET * c * k)
		hd.knockback_force = minf(3.0 + 1.3 * c, 12.0)
		hd.knockdown = far < SCATTER_NEAR and c * 2 >= n
		hd.stagger_duration = 0.35 + 0.05 * c
		hd.hitstop_duration = 0.06
		hd.camera_shake_intensity = 0.1
		hd.poise = Poise.SHOT_CLOSE * (1.0 + 0.2 * c)
		TraitMoves.shape_shot(p, hd, last)
		GunKinds.strike(p, hb, hd)
		_hit_fx(p, at, dir, hd.knockdown)


static func _hit_fx(p: Player, at: Vector3, dir: Vector3, big: bool) -> void:
	_net().fx("impact", [at, Color(1.0, 0.75, 0.45)])
	if big:
		_net().fx("ring", [at, -dir, 1.0, _col(p, FXS.EDGE), 0.22, 0.12])
	if _elem(p, 2):
		_net().fx("elem_hit", ["long_gun", at, -dir])


# --------------------------------------------------------------------------
# Stock Rush (attacked at a sprint): crossways into them with the shoulder
# --------------------------------------------------------------------------
const RUSH_SPEED := 11.0
const RUSH_DAMAGE := 20.0


static func _rush_enter(s) -> void:
	var p: Player = s.player
	s.mode = "rush"
	s.dur = ActionSpecs.length("lg_rush")
	p.set_reach("stock")
	p.body_model.play("lg_rush", s.dur)
	_net().fx("sfx", ["whoosh", p.global_position, -6.0, 0.06, 0.9])


static func _rush_update(s, delta: float) -> void:
	var p: Player = s.player
	var w := ActionSpecs.hit_seconds("lg_rush")
	var f: Vector3 = -p.player_model.global_basis.z
	s.apply_gravity(delta)
	var spd := RUSH_SPEED if s.timer < w.y else move_toward(Vector2(p.velocity.x, p.velocity.z).length(), 0.0, 30.0 * delta)
	p.velocity.x = f.x * spd
	p.velocity.z = f.z * spd
	p.move_and_slide()
	if s.timer >= w.x and not p.sword_hitbox.active:
		if s.steady < 1.0:
			s.steady = 1.0
			var hd := p.melee_hit(RUSH_DAMAGE, "finisher")
			hd.knockdown = true
			hd.breaker = true
			hd.knockback_force = 11.0
			hd.stagger_duration = 0.7
			hd.hitstop_duration = 0.09
			hd.camera_shake_intensity = 0.16
			p.sword_hitbox.activate(hd)
			_net().fx("punch_wind", [p.global_position + Vector3(0, 1.1, 0) + f * 0.6, f, 1.4, _col(p, FXS.EDGE, 2), true])
			_net().fx("sfx", ["whoosh_big", p.global_position, -4.0, 0.06, 1.0])
			p.squash(-3.0)
	if s.timer >= w.y and p.sword_hitbox.active:
		p.sword_hitbox.deactivate()
	if s.timer >= s.dur:
		_done(s)


# --------------------------------------------------------------------------
# The butt stroke's show (HeavyAttackState._strike_fx)
# --------------------------------------------------------------------------
static func heavy_fx(p: Player, elem: bool) -> void:
	var f := -p.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var at := p.global_position + Vector3(0, 1.4, 0) + f * 1.0
	_net().fx("punch_wind", [at, f, 1.2, _col(p, FXS.EDGE, 2), true])
	_net().fx("dust", [p.global_position + Vector3(0, 0.05, 0) - f * 0.3, 5, 0.5])
	if elem:
		_net().fx("element", ["long_gun", at, f + Vector3.UP * 0.2, 8, 4.0])
	p.cam_kick(0.1, 0.25)


# --------------------------------------------------------------------------
# Sky Shot (attacked in the air, PlungeState): hang a beat drawing a bead down, a steady shot, the kick throwing you up
# and back
# --------------------------------------------------------------------------
const SKY_FIRE := 0.42
const SKY_LEN := 0.75
const SKY_KICK := Vector2(5.0, 4.0)
## The aim assist's reach off the reticle in the air (rad; a shot on the ground's is 0.06).
const SKY_ASSIST := 0.15


static func air_enter(s) -> void:
	var p: Player = s.player
	p.variable_jump_active = false
	p.velocity = Vector3(p.velocity.x * 0.3, maxf(p.velocity.y, 0.0) * 0.2, p.velocity.z * 0.3)
	_pitch(p)
	p.body_model.play("lg_air", SKY_LEN)
	_net().fx("sfx", ["blip", p.global_position, -10.0, 0.05, 0.6])


static func air_update(s, delta: float) -> void:
	var p: Player = s.player
	if not s._fired:
		p.velocity.y = move_toward(p.velocity.y, -0.8, 8.0 * delta)
		p.velocity.x = move_toward(p.velocity.x, 0.0, 10.0 * delta)
		p.velocity.z = move_toward(p.velocity.z, 0.0, 10.0 * delta)
		s.face_direction(s.get_camera_forward(), 1.0)
		_pitch(p)
		if s.timer >= SKY_FIRE - 0.1 and s.phase == 0:
			s.phase = 1
			_net().fx("glint", [muzzle(p), _col(p, FXS.CORE), 0.6])
		if s.timer >= SKY_FIRE:
			s._fired = true
			var mz := muzzle(p)
			var reach := RANGE * GunKinds.design(p.equipped_weapon, "range")
			var dir := (GunKinds.aim_point(p, mz, reach, SKY_ASSIST) - mz).normalized()
			p.ammo[0] -= 1
			if GunKinds.design(p.equipped_weapon, "spread", 0.0) > 0.0:
				_scatter(p, mz, dir, reach, int(GunKinds.design(p.equipped_weapon, "spread")), 1.0, p.ammo[0] <= 0)
			else:
				ball(p, mz, dir, reach, DAMAGE * (1.0 + STEADY_K), true, p.ammo[0] <= 0)
			_net().fx("blast", [mz + dir * 0.1, dir, 0.5, true, POWDER, 8.0])
			_net().fx("muzzle_sparks", [mz, dir, 16])
			_net().fx("sfx", ["gunshot", mz, 1.0, 0.05, 0.68])
			p.cam_shake(0.16)
			var back := Vector3(dir.x, 0.0, dir.z).normalized()
			p.velocity = -back * SKY_KICK.x + Vector3.UP * SKY_KICK.y
			p.squash(-2.0)
	else:
		s.apply_gravity(delta)
	p.move_and_slide()
	if s._fired and p.is_on_floor() and s.timer > SKY_FIRE + 0.1:
		if p.ammo[0] <= 0:
			p.start_reload()
		s.transitioned.emit(s, "Idle", {})
	elif s.timer >= SKY_LEN:
		if p.ammo[0] <= 0:
			p.start_reload()
		s.transitioned.emit(s, "Fall", {})


# --------------------------------------------------------------------------
# The techniques (TechniqueState `s`): Pinning Shot (down on a knee, a shot that nails the aimed foe in place), Powder
# Burst (a double charge from the hip: a cone of fire and shot that throws them down, and you back), Volley Line (three
# paper cartridges in quick succession at up to three foes ahead, then reloaded), Stock Sweep (the gun let out butt
# first and swung round once), Hawkeye (ult: time slows while every foe ahead is marked, then a shot through each).
# Poses: lg_kneel / lg_kneel_fire, lg_burst, lg_fire, lg_sweep.
# --------------------------------------------------------------------------
const PIN_REACH := 45.0
const PIN_AT := 0.35
const PIN_DAMAGE := 30.0
const PIN_SECS := 2.5

const BURST_AT := 0.32
const BURST_REACH := 6.5
const BURST_CONE := 0.8
const BURST_DAMAGE := 28.0
const BURST_KICK := 7.0

const VOLLEY_REACH := 32.0
const VOLLEY_AT := [0.25, 0.55, 0.85]
const VOLLEY_DAMAGE := 22.0

const SWEEP_R := 3.2
const SWEEP_AT := [0.36, 0.6]
const SWEEP_DAMAGE := [12.0, 20.0]

const HAWK_REACH := 50.0
const HAWK_MAX := 6
const HAWK_MARK := 0.3
const HAWK_FIRST := 0.75
const HAWK_EVERY := 0.24
const HAWK_DAMAGE := 48.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"pin_shot":
			s.dur = 0.8
			s._target = s._aimed(PIN_REACH)
			if s._target == null:
				s._refund("Nobody in your sights")
				return true
			s.face_direction(s._flat_to(s._target), 1.0)
			_pitch_to(p, s._body_center(s._target))
			p.body_model.hold("lg_kneel", 0.18)
		"powder_burst":
			s.dur = 0.75
			p.body_model.play("lg_burst", s.dur)
		"volley_line":
			s._victims = s._closest(VOLLEY_REACH, 99).filter(func(e): return s._flat_to(e).dot(s._dir) > 0.3).slice(0, 3)
			if s._victims.is_empty():
				s._refund("Nobody ahead to shoot")
				return true
			s.dur = 1.2
			p.body_model.hold("lg_aim", SHOULDER)
		"stock_sweep":
			s.dur = ActionSpecs.length("lg_sweep")
			p.body_model.play("lg_sweep", s.dur)
		"hawkeye":
			s._victims = s._closest(HAWK_REACH, 99).filter(func(e): return s._flat_to(e).dot(s._dir) > 0.45).slice(0, HAWK_MAX)
			if s._victims.is_empty():
				s._refund("Nobody in your sights")
				return true
			s.dur = HAWK_FIRST + HAWK_EVERY * s._victims.size() + 0.45
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.hold("lg_kneel", 0.2)
			_net().fx("sfx", ["blip_high", p.global_position, -6.0, 0.0, 0.7])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	var p: Player = s.player
	match s.id:
		"pin_shot":
			s._rooted(delta, 0.0)
			if s._once("glint", PIN_AT - 0.1):
				_net().fx("glint", [muzzle(p), s._col(FXS.CORE), 0.8])
			if s._once("fire", PIN_AT):
				p.body_model.play("lg_kneel_fire", 0.4)
				_tech_shot(s, s._target, PIN_DAMAGE, func(hd: HitData):
					hd.stagger_duration = PIN_SECS
					hd.knockback_force = 0.0
					hd.unblockable = true
					hd.poise = Poise.TECH_MAX)
				if s._target and is_instance_valid(s._target):
					p.power.root_enemy(s._target, PIN_SECS)
					var at: Vector3 = s._target.global_position
					_net().fx("ring", [at, Vector3.UP, 1.3, s._col(), 0.5, 0.14])
					_net().fx("float_text", [at + Vector3(0, 2.3, 0), "Pinned", s._col(FXS.CORE)])
		"powder_burst":
			s._rooted(delta, 0.0)
			if s._once("fire", BURST_AT):
				var hits: Array = s._cone(BURST_REACH, BURST_CONE, BURST_DAMAGE, 12.0, true, true)
				var mz := muzzle(p)
				_net().fx("blast", [mz + s._dir * 0.2, s._dir, 1.2, true, POWDER, 12.0])
				_net().fx("muzzle_sparks", [mz, s._dir, 28])
				_net().fx("ring", [mz + s._dir * 1.0, s._dir, 2.0, s._col(), 0.25, 0.2])
				for e in hits:
					_net().fx("impact", [s._body_center(e), Color(1.0, 0.75, 0.45)])
				s._spray(mz + s._dir * 0.5, s._dir, 12, 7.0)
				_net().fx("sfx", ["gunshot", mz, 3.0, 0.05, 0.5])
				_net().fx("sfx", ["fire_burst", mz, -4.0, 0.05, 1.1])
				p.velocity.x = -s._dir.x * BURST_KICK
				p.velocity.z = -s._dir.z * BURST_KICK
				p.cam_shake(0.25)
				p.cam_kick(0.18, 0.3)
				p.squash(-3.0)
		"volley_line":
			s._rooted(delta, 0.0)
			for i in VOLLEY_AT.size():
				var e: Node3D = s._victims[mini(i, s._victims.size() - 1)]
				if s.t < float(VOLLEY_AT[i]) and is_instance_valid(e):
					s.face_direction(s._flat_to(e), delta * 2.0)
				if s._once("shot%d" % i, float(VOLLEY_AT[i])):
					if is_instance_valid(e):
						s._dir = s._flat_to(e)
						s.face_direction(s._dir, 1.0)
						_pitch_to(p, s._body_center(e))
						p.body_model.play("lg_fire", 0.28)
						_tech_shot(s, e, VOLLEY_DAMAGE, func(hd: HitData):
							hd.stagger_duration = 0.5
							hd.knockdown = i == VOLLEY_AT.size() - 1)
			if s._once("reload", 1.05):
				p._reset_ammo()
				_net().fx("sfx", ["blip_low", p.global_position, -10.0, 0.0, 1.4])
		"stock_sweep":
			s._rooted(delta, 0.1)
			for i in SWEEP_AT.size():
				if s._once("sweep%d" % i, float(SWEEP_AT[i])):
					s._ring(SWEEP_R, float(SWEEP_DAMAGE[i]), 6.0 + 5.0 * i, i == 1, false)
					_net().fx("slash", [p.player_model, "spin", 0.2, s._col()])
					_net().fx("sfx", ["whoosh_big" if i == 1 else "whoosh", p.global_position, -4.0, 0.06, 0.9])
					if i == 1:
						_net().fx("dust_ring", [p.global_position, 12, 0.9])
						_net().fx("ring", [p.global_position, Vector3.UP, SWEEP_R, s._col(), 0.3, 0.14])
						if s._elem():
							_net().fx("element", ["long_gun", p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 10, 4.0])
						p.cam_shake(0.18)
		"hawkeye":
			s._rooted(delta, 0.0)
			if s._once("mark", HAWK_MARK):
				s._moment(0.3, 0.9, 0.35, 0.25)
				for e in s._victims:
					if is_instance_valid(e):
						var at: Vector3 = s._body_center(e)
						_net().fx("glint", [at + Vector3(0, 0.4, 0), s._col(FXS.CORE), 1.0])
						_net().fx("ring", [(e as Node3D).global_position, Vector3.UP, 1.0, s._col(), 0.6, 0.12])
			for i in s._victims.size():
				if s._once("shot%d" % i, HAWK_FIRST + HAWK_EVERY * i):
					var e: Node3D = s._victims[i]
					if is_instance_valid(e):
						s._dir = s._flat_to(e)
						s.face_direction(s._dir, 1.0)
						_pitch_to(p, s._body_center(e))
						p.body_model.play("lg_kneel_fire", HAWK_EVERY + 0.05)
						_tech_shot(s, e, HAWK_DAMAGE, func(hd: HitData):
							hd.knockdown = true
							hd.unblockable = true
							hd.knockback_force = 9.0
							hd.poise = Poise.ULT)
						if s._elem():
							var at: Vector3 = s._body_center(e)
							_net().fx("streak", [at + Vector3(0, 6.0, 0), at, s._col(FXS.EDGE), 0.12, 0.3])
							_net().fx("element", ["long_gun", at, Vector3.UP, 10, 4.0])
			if s._once("open", s.dur - 0.3):
				p.hurtbox.set_deferred("monitorable", true)
				p._reset_ammo()
		_:
			return false
	return true


## A technique's shot from the muzzle into `e` (its hit shaped by `shape`), with the gun's report.
static func _tech_shot(s, e: Node3D, base: float, shape: Callable) -> void:
	var p: Player = s.player
	var mz := muzzle(p)
	var to: Vector3 = s._body_center(e) if e and is_instance_valid(e) else mz + s._dir * 20.0
	var dir := (to - mz).normalized()
	if e and is_instance_valid(e) and e.get("hurtbox") is Hurtbox:
		var hd: HitData = s._hd(base, 5.0, false)
		hd.ranged = true
		hd.impact = "shot"
		hd.hitstop_duration = 0.05
		shape.call(hd)
		s._strike(e, hd)
		_hit_fx(p, to, dir, hd.knockdown)
		if s._elem():
			_net().fx("element", ["long_gun", to, -dir, 6, 3.0])
	_net().fx("tracer", [mz, to, s._col(FXS.EDGE) if s._elem() else Color(1.0, 0.92, 0.7)])
	_net().fx("blast", [mz + dir * 0.1, dir, 0.45, true, POWDER, 8.0])
	_net().fx("muzzle_sparks", [mz, dir, 14])
	_net().fx("sfx", ["gunshot", mz, 1.0, 0.05, 0.72])
	p.cam_shake(0.1)


static func _pitch_to(p: Player, at: Vector3) -> void:
	var d := at - (p.global_position + Vector3(0, 1.45, 0))
	p.body_model.aim_pitch = clampf(asin(clampf(d.normalized().y, -1.0, 1.0)), -0.6, 0.6)
