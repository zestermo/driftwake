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
				p.cam_kick(0.08, 0.2)
			elif right:
				p.cam_kick(0.04, 0.15)


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
	p.cam_kick(0.14, 0.28)


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
	p.cam_shake(0.22)
	p.cam_kick(0.12, 0.28)
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
# The techniques: Rising Heel (a heel swung up under the chin: a launcher), Hailstorm Heels (a hail of kicks off one
# foot walking in, a big one last), Sky Chase (up to a juggled foe: kick it higher or spike it down), Last Course (ult: a spin on one
# foot that heats the leg red-hot, a storm of burning kicks, a leap, the heel down into a ring of fire), Cleaver Kick
# (a crescent kick throwing a blade of air down the line), Flambe Dash (a hop, a flying side kick streaking through
# the line). Poses: bl_rise, bl_hail, bl_sky / bl_sky_spike, bl_last, bl_cleave, bl_flambe.
# --------------------------------------------------------------------------
## Rising Heel: steps in on whoever's aimed at within RISE_REACH and launches everyone just in front (Juggle).
const RISE_REACH := 3.5
const RISE_DUR := BlackLegMoves.RISE_DUR
const RISE_AT := BlackLegMoves.RISE_AT
const RISE_DAMAGE := 20.0
const RISE_LAUNCH := 10.0

## (the timings the poses are keyed to live in BlackLegMoves, which mustn't load this file: it touches autoloads)
const HAIL_DUR := BlackLegMoves.HAIL_DUR
const HAIL_KICKS := BlackLegMoves.HAIL_KICKS
const HAIL_FROM := BlackLegMoves.HAIL_FROM
const HAIL_EVERY := BlackLegMoves.HAIL_EVERY
const HAIL_DAMAGE := 5.0
const HAIL_FINAL_AT := BlackLegMoves.HAIL_FINAL_AT
const HAIL_FINAL := 18.0
const HAIL_HEIGHTS := BlackLegMoves.HAIL_HEIGHTS

## Sky Chase: up to a juggled foe within SKY_REACH (Juggle), and the kick: up (it goes higher) or, with the stick held
## forward, a spike down (driven into the ground; you come down with it in a ring).
const SKY_REACH := 10.0
const SKY_DUR := BlackLegMoves.SKY_DUR
const SKY_SPIKE_DUR := BlackLegMoves.SKY_SPIKE_DUR
const SKY_GO := BlackLegMoves.SKY_GO
const SKY_AT := BlackLegMoves.SKY_AT
const SKY_DAMAGE := 18.0
const SKY_UP := 7.0
const SKY_SPIKE_DAMAGE := 26.0
const SKY_SPIKE := -18.0
const SKY_DIVE := 20.0
const SKY_LAND_R := 2.6
const SKY_LAND_DAMAGE := 12.0

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

const CLEAVE_DUR := BlackLegMoves.CLEAVE_DUR
const CLEAVE_AT := BlackLegMoves.CLEAVE_AT
const CLEAVE_REACH := 12.0
const CLEAVE_DAMAGE := 22.0

const FLAMBE_DUR := BlackLegMoves.FLAMBE_DUR
const FLAMBE_GO := BlackLegMoves.FLAMBE_GO
const FLAMBE_LAND := BlackLegMoves.FLAMBE_LAND
const FLAMBE_LEN := BlackLegMoves.FLAMBE_LEN
const FLAMBE_R := 1.5
const FLAMBE_DAMAGE := 24.0
## With the heat: how long they burn, damage a second.
const FLAMBE_BURN := Vector2(3.5, 5.0)


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"rising_heel":
			s._target = s._aimed(RISE_REACH)
			if s._target == null:
				s._target = s._nearest(RISE_REACH, true)
			s.dur = RISE_DUR
			if s._target:
				s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("bl_rise", s.dur)
			Net.fx("sfx", ["hup", p.global_position, -8.0, 0.05, 1.0])
		"hailstorm_heels":
			s.dur = HAIL_DUR
			p.body_model.play("bl_hail", s.dur)
			Net.fx("sfx", ["hup", p.global_position, -8.0, 0.05, 1.1])
		"sky_chase":
			s._target = Juggle.near(p.get_tree(), p.global_position, SKY_REACH, s.get_camera_forward())
			if s._target == null:
				s._refund("Nothing in the air to chase")
				return true
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			# (the stick held forward: the spike)
			var spike: bool = s.get_movement_input().y < -0.5
			s._done["spike"] = spike
			s.dur = SKY_SPIKE_DUR if spike else SKY_DUR
			s._from = p.global_position
			p.variable_jump_active = false
			p.body_model.play("bl_sky_spike" if spike else "bl_sky", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -6.0, 0.05, 1.2])
		"last_course":
			s.dur = LAST_DUR
			s._victims = s._closest(LAST_R + 2.0, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("bl_last", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -6.0, 0.05, 0.7])
		"cleaver_kick", "flambe_dash":
			# (both down the line you face, turned on whoever's ahead of where you look)
			var e: Node3D = s._aimed(CLEAVE_REACH if id == "cleaver_kick" else FLAMBE_LEN)
			if e:
				s._dir = s._flat_to(e)
			s.face_direction(s._dir, 1.0)
			s.dur = CLEAVE_DUR if id == "cleaver_kick" else FLAMBE_DUR
			p.body_model.play("bl_cleave" if id == "cleaver_kick" else "bl_flambe", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 1.1 if id == "cleaver_kick" else 0.9])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"rising_heel":
			_rise(s, delta)
		"hailstorm_heels":
			_hail(s, delta)
		"sky_chase":
			_sky(s, delta)
		"last_course":
			_last(s, delta)
		"cleaver_kick":
			_cleaver(s, delta)
		"flambe_dash":
			_flambe(s, delta)
		_:
			return false
	return true


## The heat off a kick landing at `at` (the element), else a plain ring.
static func _burst(s, at: Vector3, dir: Vector3, big: bool) -> void:
	Net.fx("ring", [at, dir, 1.4 if big else 0.8, s._col(), 0.22 if big else 0.14, 0.16])
	if s._elem():
		Net.fx("element", ["black_leg", at, dir + Vector3.UP * 0.3, 10 if big else 4, 4.0])


## Sunk deep, then the heel swung straight up under their chin: everyone just in front is launched (Juggle; a heavier
## foe only if it breaks their poise, else it rocks them). It breaks a wind-up.
static func _rise(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	if s.t < RISE_AT - 0.06 and alive:
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.3) / maxf(RISE_AT - 0.06 - s.t, 0.05), 0.0, 12.0))
	else:
		s._rooted(delta, 0.0)
	if s._once("glow", 0.06) and s._elem():
		Net.fx("hot_leg", [p.body_model, true, 0.55, FX.tree_col("black_leg", FX.EDGE)])
	if s._once("swoosh", RISE_AT - 0.05):
		Net.fx("kick_swoosh", [p.body_model, 0.2, s._col(), s._col(FX.ACCENT) if s._elem() else s._col(), "r"])
	if s._once("kick", RISE_AT):
		var at: Vector3 = p.global_position + Vector3(0, 1.5, 0) + s._dir * 1.0
		var hit := false
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0) + s._dir * 1.0, 1.5):
			var hd: HitData = s._hd(RISE_DAMAGE, 2.0, false)
			hd.launch = RISE_LAUNCH
			hd.breaker = true
			hd.stagger_duration = 0.6
			hd.impact = "punch_heavy"
			s._strike(e, hd)
			hit = true
		Net.fx("ring", [at, Vector3.UP, 1.3, s._col(), 0.22, 0.14])
		Net.fx("speed_lines", [at, Vector3.UP, s._col(FX.CORE), 7, 2.0, 0.22, randi() % 1000])
		if s._elem():
			Net.fx("element", ["black_leg", at, Vector3.UP, 10, 5.0])
		Net.fx("dust", [p.global_position + s._dir * 0.6, 6, 0.6])
		Net.fx("sfx", ["punch_heavy" if hit else "whoosh_big", at, -2.0, 0.05, 1.05])
		if hit:
			CombatManager.apply_hitstop(0.08, [p])
		s.player.cam_kick(0.14, 0.26)


## Up to the juggled foe (a stamp on the air, then carried to it by SKY_GO), and the kick at SKY_AT: up (a scissor
## kick, it goes higher, you hang and fall) or the spike (the heel down through it, you dive after it and land in a
## ring that knocks everyone round flat).
static func _sky(s, delta: float) -> void:
	var p: Player = s.player
	var spike: bool = s._done.get("spike", false)
	var alive: bool = s._target != null and is_instance_valid(s._target) and s._target.is_in_group(Juggle.GROUP)
	if s.t < SKY_AT and alive:
		var goal: Vector3 = s._target.global_position - s._dir * 1.0 + Vector3(0, 1.3 if spike else -0.7, 0)
		p.velocity = ((goal - p.global_position) / maxf(SKY_GO - s.t, 0.06)).limit_length(30.0)
		p.move_and_slide()
	elif spike and s._done.has("kick"):
		p.velocity = Vector3(0, -SKY_DIVE, 0)
		p.move_and_slide()
	else:
		p.velocity.x = move_toward(p.velocity.x, 0.0, 10.0 * delta)
		p.velocity.z = move_toward(p.velocity.z, 0.0, 10.0 * delta)
		p.velocity.y = maxf(p.velocity.y - p.gravity * 0.5 * delta, -12.0)
		p.move_and_slide()
	if s._once("stamp", 0.06):
		var at: Vector3 = p.global_position + Vector3(0, 0.04, 0)
		Net.fx("ring", [at, Vector3.UP, 0.9, Color(1.0, 0.98, 0.9, 0.85), 0.26, 0.08])
		Net.fx("afterimage", [p.body_model, s._col(), 0.25])
		Net.fx("sfx", ["jump", at, -6.0, 0.05, 1.1])
	if s._once("swoosh", SKY_AT - 0.06):
		Net.fx("kick_swoosh", [p.body_model, 0.2, s._col(), s._col(FX.ACCENT) if s._elem() else s._col(), "r"])
	if s._once("kick", SKY_AT):
		var at: Vector3 = Juggle.chest(s._target) if alive else p.global_position + Vector3(0, 1.2, 0) + s._dir
		if alive and at.distance_to(p.global_position + Vector3(0, 1.0, 0)) < 3.2:
			var hd: HitData = s._hd(SKY_SPIKE_DAMAGE if spike else SKY_DAMAGE, 3.0, false)
			hd.launch = SKY_SPIKE if spike else SKY_UP
			hd.impact = "punch_heavy"
			s._strike(s._target, hd)
			CombatManager.apply_hitstop(0.1 if spike else 0.07, [p])
		var d := Vector3.DOWN if spike else Vector3.UP
		Net.fx("ring", [at, d, 1.5, s._col(), 0.24, 0.14])
		Net.fx("speed_lines", [at, d, s._col(FX.CORE), 8, 2.2, 0.24, randi() % 1000])
		if s._elem():
			Net.fx("element", ["black_leg", at, d, 10, 5.0])
		Net.fx("sfx", ["punch_heavy", at, -1.0, 0.05, 0.85 if spike else 1.1])
		s.player.cam_kick(0.16, 0.28)
		if not spike:
			p.velocity = Vector3(0, 2.0, 0)
	if spike and s._done.has("kick") and not s._done.has("land") and (p.is_on_floor() or s.t > SKY_SPIKE_DUR - 0.5):
		s._done["land"] = true
		s.dur = s.t + 0.45
		p.velocity = Vector3.ZERO
		var at2: Vector3 = p.global_position
		p.body_model.play("bl_air_land", 0.45)
		p.squash(-5.0)
		for e in s._pc.enemies_in(at2 + Vector3(0, 0.8, 0), SKY_LAND_R):
			if e == s._target:
				continue
			s._strike(e, s._hd(SKY_LAND_DAMAGE, 7.0, true))
		Net.fx("ring", [at2 + Vector3(0, 0.1, 0), Vector3.UP, SKY_LAND_R * 1.2, s._col(), 0.3, 0.12])
		Net.fx("dust_ring", [at2, 16, 1.1])
		Net.fx("ground_crack", [at2 + s._dir * 0.4, s._dir, 1.8, s._col(FX.EDGE) if s._elem() else Color(0, 0, 0, 0), randi() % 10000, 0.1])
		Net.fx("sfx", ["thud", at2, 0.0, 0.05, 0.8])
		s.player.cam_shake(0.25)


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
		# (the ring on the foot itself as it snaps out, read off the body: a fixed height per kick sat beside it)
		var at: Vector3 = foot(p, true) + s._dir * 0.15
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
		s.player.cam_kick(0.14, 0.26)


## A high crescent kick: the leg swung up on the outside and over the top, and at the top (CLEAVE_AT) a blade of air
## shot off the foot down the line (Projectile "cleaver": cuts everyone it passes; red-hot with the heat, burning them).
static func _cleaver(s, delta: float) -> void:
	var p: Player = s.player
	s._rooted(delta, 0.0)
	if s._once("glow", 0.08) and s._elem():
		Net.fx("hot_leg", [p.body_model, true, 0.6, FX.tree_col("black_leg", FX.EDGE)])
	if s._once("swoosh", CLEAVE_AT - 0.08):
		Net.fx("kick_swoosh", [p.body_model, 0.2, s._col(), s._col(), "r"])
		Net.fx("glint", [foot(p, true), s._col(FX.CORE), 0.7])
	if s._once("cut", CLEAVE_AT):
		var from: Vector3 = p.global_position + Vector3(0, 1.2, 0) + s._dir * 0.9
		Projectile.launch(p.get_tree(), "cleaver", from, s._dir, p, CLEAVE_DAMAGE, "elem" if s._elem() else "")
		var f := foot(p, true)
		Net.fx("ring", [f, s._dir, 0.9, s._col(), 0.18, 0.16])
		Net.fx("punch_wind", [from - s._dir * 0.4, s._dir, 1.8, s._col(FX.CORE), true])
		if s._elem():
			Net.fx("element", ["black_leg", f, s._dir + Vector3.UP * 0.2, 8, 4.5])
		Net.fx("sfx", ["whoosh_big", from, -3.0, 0.05, 1.25])
		s.player.cam_kick(0.1, 0.22)


## A hop as the leg heats, then a flying side kick streaking FLAMBE_LEN m down the line (through them: enemies don't
## stop you), everyone it passes kicked aside off it and down; a trail along it, of crimson fire with the heat (and
## them left burning), else of air and dust. Landed crouched.
static func _flambe(s, delta: float) -> void:
	var p: Player = s.player
	var elem: bool = s._elem()
	var flying: bool = s.t >= FLAMBE_GO and s.t < FLAMBE_LAND
	if flying:
		s._drift(delta, FLAMBE_LEN / (FLAMBE_LAND - FLAMBE_GO))
		player_through(p, true)
	else:
		s._rooted(delta, 0.0)
	if s._once("glow", 0.04) and elem:
		Net.fx("hot_leg", [p.body_model, true, FLAMBE_LAND + 0.25, FX.tree_col("black_leg", FX.EDGE)])
	if s._once("hop", 0.12):
		Net.fx("dust", [p.global_position, 5, 0.5])
		Net.fx("sfx", ["hup", p.global_position, -8.0, 0.05, 1.0])
		if elem:
			Net.fx("heat", [foot(p, true), Vector3.UP, 6, 2.5])
	if s._once("go", FLAMBE_GO):
		s._from = p.global_position
		Net.fx("kick_swoosh", [p.body_model, FLAMBE_LAND - FLAMBE_GO, s._col(), s._col(FX.ACCENT) if elem else s._col(), "r"])
		Net.fx("dust_ring", [p.global_position, 10, 0.7])
		Net.fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 1.1])
		s.player.cam_kick(0.08, 0.2)
	if flying:
		# the trail: a puff of it every few hundredths of a second (~1.4 m) behind the foot
		if s._once("trail%d" % int((s.t - FLAMBE_GO) / 0.04), s.t):
			var at: Vector3 = p.global_position + Vector3(0, 0.9, 0)
			if elem:
				Net.fx("heat", [at, Vector3.UP - s._dir * 0.5, 5, 2.0])
			else:
				Net.fx("dust", [p.global_position, 3, 0.45])
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), FLAMBE_R):
			if e in s._hit:
				continue
			s._hit.append(e)
			# kicked aside: off the line to whichever side they stood, and on along it
			var rel: Vector3 = (e as Node3D).global_position - p.global_position
			rel.y = 0.0
			var side: Vector3 = s._dir.cross(Vector3.UP)
			if rel.dot(side) < 0.0:
				side = -side
			var hd: HitData = s._hd(FLAMBE_DAMAGE, 10.0, true)
			hd.breaker = true
			s._strike_toward(e, hd, side + s._dir * 0.5)
			var hit_at: Vector3 = (e as Node3D).global_position + Vector3(0, 1.0, 0)
			_burst(s, hit_at, side, true)
			Net.fx("impact", [hit_at, s._col(FX.ACCENT) if elem else Color(1.0, 0.9, 0.7)])
			Net.fx("sfx", ["punch_heavy", hit_at, -3.0, 0.05, 1.0])
			CombatManager.apply_hitstop(0.05, [p])
			if elem:
				BurnStatus.apply(e as Node3D, FLAMBE_BURN.x, FLAMBE_BURN.y, p)
	if s._once("land", FLAMBE_LAND):
		player_through(p, false)
		# (landed, it stops: the dash's speed bled off over most of a second used to carry it 10 m past the landing)
		p.velocity.x = s._dir.x * 2.5
		p.velocity.z = s._dir.z * 2.5
		var c: Color = s._col()
		Net.fx("streak", [s._from + Vector3(0, 0.9, 0), p.global_position + Vector3(0, 0.9, 0), Color(c.r, c.g, c.b, 0.8), 0.22, 0.35])
		Net.fx("dust_ring", [p.global_position, 12, 0.8])
		Net.fx("sfx", ["thud", p.global_position, -4.0, 0.05, 1.0])
		if elem:
			Net.fx("heat", [p.global_position + Vector3(0, 0.3, 0), Vector3.UP, 8, 3.0])
		p.squash(-3.5)


## Through enemies (they don't stop you) or not: TechniqueState.exit() puts it back.
static func player_through(p: Player, on: bool) -> void:
	p.set_collision_mask_value(12, not on)


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
		s.player.cam_shake(0.42)
		s.player.cam_kick(0.2, 0.4)
		p.hurtbox.set_deferred("monitorable", true)
