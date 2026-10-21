class_name BlackLegArts
## Black-leg (style "black_leg": kicks with the hands free, learned not found: Player.kicks; tree "black_leg": heat -
## the kicking leg glowing red-hot, crimson flames off the big kicks, white-hot sparks): the kicks' hits, trails and
## effects, the landed parry's sweep, the air spin's landing, and the techniques. Techniques are run by
## TechniqueState (`s`: its helpers and timeline); enter() and update() return false for ids that aren't theirs.
## Poses in BlackLegMoves.


## The colour of the kicks: plain until the heat is awakened (the tree's mastery passive `tier`: 1 the skills, 2
## every kick), black with a Haki coat.
static func col(p: Player, which: int = FX.EDGE, tier: int = 1) -> Color:
	if p.power.buff("coat"):
		return Player.HAKI_TRAIL
	return FX.tree_col("black_leg" if p.progression.elemental("black_leg", tier) else "plain", which)


## Where a foot is (the ankle), world space.
static func foot(p: Player, right: bool) -> Vector3:
	var b: Humanoid = p.body_model
	return (b.shin_r if right else b.shin_l).global_transform * Vector3(0, b.shin_l.position.y * 1.05, 0)


## The kicking leg's trail for `secs` (the move's "legs"); with the heat on every kick the leg glows red-hot through it.
static func swoosh(p: Player, anim: String, secs: float, color: Color) -> void:
	var legs := str(AnimLab.spec(anim).get("legs", "r"))
	Net.fx("kick_swoosh", [p.body_model, secs, color, color, legs])
	if p.progression.elemental("black_leg", 2) and not p.power.buff("coat"):
		for side in legs:
			Net.fx("hot_leg", [p.body_model, side == "r", secs + 0.25, FX.tree_col("black_leg", FX.EDGE)])


## A combo kick's hit, by the kick: the high kick rings their head (a longer stagger, through a wind-up), the
## handstand spin puts everyone round you down.
static func shape_hit(_p: Player, hit: HitData, anim: String) -> void:
	match anim:
		"bl_2":
			hit.knockback_force = 6.0
		"bl_3":
			hit.breaker = true
			hit.stagger_duration = 0.75
		"bl_4":
			hit.knockdown = true
			hit.knockback_force = 9.0


## A combo kick going out: a ring of air at the foot along the kick, the spin's ring and dust low round you; the heat
## thrown off it once it follows every kick.
static func kick_fx(p: Player, anim: String) -> void:
	var fwd := -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hot := p.progression.elemental("black_leg", 2)
	var c := col(p, FX.EDGE, 2)
	match anim:
		"bl_4":
			Net.fx("ring", [p.global_position + Vector3(0, 0.9, 0), Vector3.UP, 3.4, c, 0.3, 0.1])
			Net.fx("dust_ring", [p.global_position, 12, 0.8])
			if hot:
				Net.fx("element", ["black_leg", p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 10, 3.5])
		"bl_rush":
			var at := p.global_position + Vector3(0, 1.0, 0) + fwd * 1.6
			Net.fx("ring", [at, fwd, 1.2, c, 0.22, 0.16])
			if hot:
				Net.fx("element", ["black_leg", at, fwd, 10, 5.0])
		_:
			var right := anim == "bl_2"
			var h := {"bl_1": 0.5, "bl_2": 0.95, "bl_3": 1.45}.get(anim, 1.0) as float
			var at := p.global_position + Vector3(0, h, 0) + fwd * 1.15
			Net.fx("ring", [at, fwd, 0.7 if anim != "bl_3" else 0.95, c, 0.16, 0.18])
			if hot:
				Net.fx("element", ["black_leg", at, fwd + Vector3.UP * 0.2, 5 if anim != "bl_3" else 8, 3.5])
			if anim == "bl_3":
				CombatManager.apply_camera_kick(0.08, 0.2)
			elif right:
				CombatManager.apply_camera_kick(0.04, 0.15)


## Guillotine Heel coming down: the heel into the ground ahead - a crack, dust thrown up, a ring; with the heat on
## every kick, flames bursting off the spot.
static func heel_fx(p: Player) -> void:
	var fwd := -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := p.global_position + fwd * 1.15
	var hot := p.progression.elemental("black_leg", 2)
	var c := col(p, FX.EDGE, 2)
	Net.fx("ground_crack", [at - fwd * 0.2, fwd, 1.6, FX.tree_col("black_leg", FX.EDGE) if hot else Color(0, 0, 0, 0), randi() % 10000, 0.08])
	Net.fx("dust_ring", [at, 14, 1.0])
	Net.fx("ring", [at, Vector3.UP, 2.2, c, 0.26, 0.12])
	Net.fx("impact", [at + Vector3(0, 0.25, 0), FX.tree_col("black_leg" if hot else "plain", FX.CORE)])
	Net.fx("sfx", ["thud", at, -1.0, 0.05, 0.85])
	if hot:
		Net.fx("element", ["black_leg", at + Vector3(0, 0.3, 0), Vector3.UP + fwd * 0.3, 14, 4.5])
	CombatManager.apply_camera_kick(0.14, 0.28)


## A landed parry: down onto one hand and a sweep through their legs a beat later (bl_deflect) - a light blow
## that puts them on the ground.
const SWEEP_AT := 0.16
const SWEEP_DAMAGE := 6.0


static func parried(p: Player, attacker: Node) -> void:
	if not (attacker is Node3D) or not is_instance_valid(attacker) or attacker.is_in_group("bosses"):
		return
	p.get_tree().create_timer(SWEEP_AT, false).timeout.connect(func():
		if not is_instance_valid(attacker) or not is_instance_valid(p):
			return
		var hb := (attacker as Node).get("hurtbox") as Hurtbox
		if hb == null or (attacker as Node3D).global_position.distance_to(p.global_position) > 3.0:
			return
		var hd := p.melee_hit(SWEEP_DAMAGE)
		hd.knockdown = true
		hd.knockback_force = 3.0
		hd.stagger_duration = 0.5
		hd.hitstop_duration = 0.05
		hb.take_hit(hd, p)
		var at := (attacker as Node3D).global_position + Vector3(0, 0.25, 0)
		Net.fx("dust_ring", [(attacker as Node3D).global_position, 8, 0.6])
		Net.fx("ring", [at, Vector3.UP, 1.2, col(p, FX.EDGE, 2), 0.2, 0.16])
		Net.fx("sfx", ["whoosh", at, -6.0, 0.05, 1.3]))


## Cyclone Heel's landing: down on one knee and a hand, a ring thrown out that knocks everyone close flat (not those
## already kicked on the way down); the heat with it once it follows every kick.
const AIR_LAND_R := 3.0
const AIR_LAND_DAMAGE := 14.0


static func air_land(p: Player, already: Array, recover: float) -> void:
	p.body_model.play("bl_air_land", recover)
	p.squash(-4.5)
	var at := p.global_position
	var hot := p.progression.elemental("black_leg", 2)
	Net.fx("ring", [at + Vector3(0, 0.1, 0), Vector3.UP, AIR_LAND_R, col(p, FX.EDGE, 2), 0.28, 0.12])
	Net.fx("dust_ring", [at, 16, 1.0])
	Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.9])
	if hot:
		Net.fx("element", ["black_leg", at + Vector3(0, 0.3, 0), Vector3.UP, 12, 4.0])
	CombatManager.apply_camera_shake(0.22)
	CombatManager.apply_camera_kick(0.12, 0.28)
	for e in p.power.enemies_in(at + Vector3(0, 0.8, 0), AIR_LAND_R):
		if e in already:
			continue
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := HitData.new()
		hd.damage = AIR_LAND_DAMAGE * p.damage_multiplier()
		hd.knockdown = true
		hd.knockback_force = 9.0
		hd.stagger_duration = 0.5
		hd.hitstop_duration = 0.07
		hd.impact = "punch"
		hb.take_hit(hd, p)


# --------------------------------------------------------------------------
# The techniques: Mule Kick (your back to them, down on both hands, both heels driven in), Hailstorm Heels (a hail
# of kicks off one foot walking in, a big one last), Cartwheel Crescent (two cartwheels forward hand over hand, the
# legs wheeling over through everyone on the way, a heel brought down at the end), Last Course (ult: a spin on one
# foot that heats the leg red-hot, a storm of burning kicks, a leap, the heel down into a ring of fire). Poses:
# bl_mule, bl_hail, bl_wheel, bl_last.
# --------------------------------------------------------------------------
const MULE_REACH := 4.5
const MULE_DUR := 0.95
const MULE_AT := 0.42
const MULE_DAMAGE := 28.0

## (the timings the poses are keyed to live in BlackLegMoves, which mustn't load this file: it touches autoloads)
const HAIL_DUR := BlackLegMoves.HAIL_DUR
const HAIL_KICKS := BlackLegMoves.HAIL_KICKS
const HAIL_FROM := BlackLegMoves.HAIL_FROM
const HAIL_EVERY := BlackLegMoves.HAIL_EVERY
const HAIL_DAMAGE := 5.0
const HAIL_FINAL_AT := BlackLegMoves.HAIL_FINAL_AT
const HAIL_FINAL := 18.0
const HAIL_HEIGHTS := BlackLegMoves.HAIL_HEIGHTS

const WHEEL_DUR := BlackLegMoves.WHEEL_DUR
const WHEEL_ROLL := BlackLegMoves.WHEEL_ROLL
const WHEEL_EVERY := 0.12
const WHEEL_DAMAGE := 7.0
const WHEEL_HEEL := BlackLegMoves.WHEEL_HEEL
const WHEEL_FINAL := 20.0

const LAST_DUR := BlackLegMoves.LAST_DUR
const LAST_HEAT := BlackLegMoves.LAST_HEAT
const LAST_MOMENT := 0.55
const LAST_KICKS := BlackLegMoves.LAST_KICKS
const LAST_KICK_FROM := BlackLegMoves.LAST_KICK_FROM
const LAST_KICK_EVERY := BlackLegMoves.LAST_KICK_EVERY
const LAST_KICK_DAMAGE := 9.0
const LAST_HEEL := BlackLegMoves.LAST_HEEL
const LAST_R := 6.5
const LAST_FINAL := 45.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"mule_kick":
			s._target = s._aimed(MULE_REACH)
			if s._target == null:
				s._target = s._nearest(MULE_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = MULE_DUR
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("bl_mule", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 1.2])
		"hailstorm_heels":
			s.dur = HAIL_DUR
			p.body_model.play("bl_hail", s.dur)
			Net.fx("sfx", ["hup", p.global_position, -8.0, 0.05, 1.1])
		"cartwheel_crescent":
			s.dur = WHEEL_DUR
			p.body_model.play("bl_wheel", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -7.0, 0.05, 0.95])
		"last_course":
			s.dur = LAST_DUR
			s._victims = s._closest(LAST_R + 2.0, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("bl_last", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -6.0, 0.05, 0.7])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"mule_kick":
			_mule(s, delta)
		"hailstorm_heels":
			_hail(s, delta)
		"cartwheel_crescent":
			_wheel(s, delta)
		"last_course":
			_last(s, delta)
		_:
			return false
	return true


## The heat off a kick landing at `at` (the element), else a plain ring.
static func _burst(s, at: Vector3, dir: Vector3, big: bool) -> void:
	Net.fx("ring", [at, dir, 1.4 if big else 0.8, s._col(), 0.22 if big else 0.14, 0.16])
	if s._elem():
		Net.fx("element", ["black_leg", at, dir + Vector3.UP * 0.3, 10 if big else 4, 4.0])


## Your back turned to them, down onto both hands, both heels driven back into them: unblockable, through a
## wind-up, thrown clear.
static func _mule(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	if s.t < MULE_AT - 0.08 and alive:
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.7) / maxf(MULE_AT - 0.08 - s.t, 0.05), 0.0, 14.0))
	else:
		s._rooted(delta, 0.0)
	if s._once("glow", MULE_AT - 0.2) and s._elem():
		Net.fx("hot_leg", [p.body_model, true, 0.6, FX.tree_col("black_leg", FX.EDGE)])
		Net.fx("hot_leg", [p.body_model, false, 0.6, FX.tree_col("black_leg", FX.EDGE)])
	if s._once("kick", MULE_AT):
		var at: Vector3 = p.global_position + Vector3(0, 0.9, 0) + s._dir * 1.4
		var hit := false
		for e in s._pc.enemies_in(at, 1.6):
			var hd: HitData = s._hd(MULE_DAMAGE, 14.0, true)
			hd.unblockable = true
			hd.breaker = true
			s._strike(e, hd)
			hit = true
		_burst(s, at, s._dir, true)
		Net.fx("punch_wind", [at - s._dir * 0.6, s._dir, 1.6, s._col(FX.CORE), true])
		Net.fx("sfx", ["punch_heavy" if hit else "whoosh_big", at, -2.0, 0.05, 0.9])
		CombatManager.apply_hitstop(0.09, [p])
		CombatManager.apply_camera_kick(0.16, 0.3)


## Off the left foot, kick after kick at every height walking in (each into everyone just ahead), a big one last.
static func _hail(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < HAIL_FINAL_AT:
		s._drift(delta, 1.6)
	else:
		s._rooted(delta, 0.0)
	if s._once("glow", 0.1) and s._elem():
		Net.fx("hot_leg", [p.body_model, true, HAIL_DUR - 0.1, FX.tree_col("black_leg", FX.EDGE)])
	for i in HAIL_KICKS:
		if not s._once("k%d" % i, HAIL_FROM + HAIL_EVERY * i):
			continue
		var hit: Array = s._cone(2.5, 0.35, HAIL_DAMAGE, 1.5, false, false)
		var at: Vector3 = p.global_position + Vector3(0, 0.5 + 0.45 * float(HAIL_HEIGHTS[i]), 0) + s._dir * 1.1
		Net.fx("ring", [at, s._dir, 0.55, s._col(), 0.1, 0.2])
		Net.fx("sfx", ["whoosh", p.global_position, -10.0, 0.06, 1.2 + 0.05 * (i % 4)])
		if not hit.is_empty():
			Net.fx("sfx", ["punch", at, -7.0, 0.08, 1.1])
			s._spray(at, s._dir, 3, 3.0)
	if s._once("final", HAIL_FINAL_AT):
		var at: Vector3 = p.global_position + Vector3(0, 1.0, 0) + s._dir * 1.2
		s._cone(2.7, 0.3, HAIL_FINAL, 11.0, true, false)
		_burst(s, at, s._dir, true)
		Net.fx("sfx", ["punch_heavy", at, -2.0, 0.05, 0.95])
		CombatManager.apply_hitstop(0.08, [p])
		CombatManager.apply_camera_kick(0.14, 0.26)


## Two cartwheels forward, the legs wheeling over through everyone about you on the way, then the heel brought down.
static func _wheel(s, delta: float) -> void:
	var p: Player = s.player
	if s.t >= WHEEL_ROLL.x and s.t < WHEEL_ROLL.y:
		s._drift(delta, 5.0)
	else:
		s._rooted(delta, 0.0)
	if s._once("swoosh", WHEEL_ROLL.x):
		Net.fx("kick_swoosh", [p.body_model, WHEEL_ROLL.y - WHEEL_ROLL.x, s._col(), s._col(FX.ACCENT) if s._elem() else s._col(), "lr"])
	if s.t >= WHEEL_ROLL.x and s.t < WHEEL_ROLL.y and s._once("w%d" % s._hits, WHEEL_ROLL.x + 0.08 + WHEEL_EVERY * s._hits):
		s._hits += 1
		s._ring(2.2, WHEEL_DAMAGE, 3.0, false, false)
		Net.fx("sfx", ["whoosh", p.global_position, -9.0, 0.08, 1.0 + 0.05 * (s._hits % 3)])
	if s._once("glint", WHEEL_HEEL - 0.08):
		Net.fx("glint", [p.global_position + Vector3(0, 2.0, 0) + s._dir * 0.6, s._col(FX.CORE), 0.8])
	if s._once("heel", WHEEL_HEEL):
		var at: Vector3 = p.global_position + s._dir * 1.15
		s._cone(2.8, 0.4, WHEEL_FINAL, 8.0, true, false)
		Net.fx("dust_ring", [at, 14, 1.0])
		Net.fx("ground_crack", [at - s._dir * 0.2, s._dir, 1.5, s._col(FX.EDGE) if s._elem() else Color(0, 0, 0, 0), randi() % 10000, 0.08])
		_burst(s, at + Vector3(0, 0.2, 0), Vector3.UP, true)
		Net.fx("sfx", ["thud", at, -1.0, 0.05, 0.9])
		CombatManager.apply_hitstop(0.08, [p])
		CombatManager.apply_camera_kick(0.14, 0.28)


## The ultimate: a spin on one foot heating the leg (sparks off it on the ground, the moment as it catches), a storm
## of burning kicks driving in, a leap, and the heel down: a ring of crimson fire throws everyone round you down.
static func _last(s, delta: float) -> void:
	var p: Player = s.player
	var elem: bool = s._elem()
	if s.t >= LAST_KICK_FROM and s.t < LAST_KICK_FROM + LAST_KICK_EVERY * LAST_KICKS:
		s._drift(delta, 3.2)
	else:
		s._rooted(delta, 0.0)
	if s._once("glow", LAST_HEAT.x):
		if elem:
			Net.fx("hot_leg", [p.body_model, true, LAST_HEEL + 0.4 - LAST_HEAT.x, FX.tree_col("black_leg", FX.EDGE)])
		Net.fx("gather", [p.global_position + Vector3(0, 0.4, 0), 2.4, s._col(FX.ACCENT) if elem else s._col(), 0.5, 18])
	if s.t < LAST_HEAT.y and s._once("scrape%d" % int(s.t / 0.1), s.t):
		var f := foot(p, true)
		Net.fx("sparkle", [Vector3(f.x, p.global_position.y + 0.1, f.z), 5, s._col(FX.CORE)])
		if elem:
			Net.fx("heat", [Vector3(f.x, p.global_position.y + 0.15, f.z), Vector3.UP, 4, 2.5])
	if s._once("moment", LAST_MOMENT):
		s._moment(0.35, 0.3, 0.45, 0.3)
		Net.fx("ring", [p.global_position + Vector3(0, 0.3, 0), Vector3.UP, 3.5, s._col(), 0.35, 0.12])
		Net.fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 1.3])
	for i in LAST_KICKS:
		if not s._once("k%d" % i, LAST_KICK_FROM + LAST_KICK_EVERY * i):
			continue
		var hit: Array = s._cone(2.8, 0.3, LAST_KICK_DAMAGE, 3.0, false, true)
		var at: Vector3 = p.global_position + Vector3(0, 0.8 + 0.4 * (i % 2), 0) + s._dir * 1.2
		_burst(s, at, s._dir, false)
		Net.fx("sfx", ["punch" if not hit.is_empty() else "whoosh", at, -6.0, 0.06, 1.0 + 0.06 * i])
		if not hit.is_empty():
			CombatManager.apply_hitstop(0.03, [p])
	if s._once("glint", LAST_HEEL - 0.12):
		Net.fx("glint", [p.global_position + Vector3(0, 2.4, 0) + s._dir * 0.5, s._col(FX.CORE), 1.3])
	if s._once("heel", LAST_HEEL):
		var at: Vector3 = p.global_position + s._dir * 1.1
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), LAST_R):
			var hd: HitData = s._hd(LAST_FINAL, 12.0, true)
			hd.breaker = true
			s._strike(e, hd)
		Net.fx("ring", [at, Vector3.UP, LAST_R, s._col(), 0.45, 0.1])
		Net.fx("ring", [at, Vector3.UP, LAST_R * 0.55, s._col(FX.CORE), 0.3, 0.18])
		Net.fx("dust_ring", [at, 20, 1.3])
		for k in 5:
			Net.fx("ground_crack", [at, s._dir.rotated(Vector3.UP, TAU * k / 5.0 + randf_range(-0.2, 0.2)), LAST_R * 0.75,
				s._col(FX.EDGE) if elem else Color(0, 0, 0, 0), randi() % 10000, 0.16])
		var c: Color = s._col(FX.CORE)
		Net.fx("screen_flash", [p.global_position, Color(c.r, c.g, c.b, 0.35), 0.25])
		Net.fx("sfx", ["thud", at, 2.0, 0.05, 0.6])
		Net.fx("sfx", ["punch_heavy", at, 0.0, 0.05, 0.7])
		if elem:
			Net.fx("heat_ring", [at, LAST_R])
			for e in s._victims:
				if is_instance_valid(e):
					Net.fx("heat", [(e as Node3D).global_position + Vector3(0, 0.4, 0), Vector3.UP, 10, 4.0])
		else:
			Net.fx("debris", [at + Vector3(0, 0.2, 0), Vector3.UP, 10, Color(0.35, 0.3, 0.25), 5.0])
		p.squash(-5.0)
		CombatManager.apply_hitstop(0.12, [p])
		CombatManager.apply_camera_shake(0.42)
		CombatManager.apply_camera_kick(0.2, 0.4)
		p.hurtbox.set_deferred("monitorable", true)
