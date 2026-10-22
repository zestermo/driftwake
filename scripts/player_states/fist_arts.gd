class_name FistArts
## Bare fists' techniques (style "fist", tree "unarmed"): Shoulder Throw's counter (a blow caught in its guard, then
## its owner over your shoulder) and Heavy Landing (whoever a throw or the haymaker knocks flat lands like a
## cannonball). Run by TechniqueState (`s`: its helpers and timeline); enter() and update() return false for ids that
## aren't theirs. Poses in FistMoves (fs_*) and TechniquePoses (shoulder_throw).

## (the FX script for its colours: the autoloads aren't seen from a static func in a --script suite)
const FXS := preload("res://scripts/game/fx.gd")

const THROW_DUR := 0.95
const THROW_AT := 0.5
const THROW_LAND := 0.82
const THROW_DAMAGE := 28.0
## A boss or a heavy can't be thrown: the caught blow is answered with a straight instead.
const ANSWER_DUR := 0.55
const ANSWER_AT := 0.16
const ANSWER_DAMAGE := 26.0

## Where a thrown body lands: those close go down too; with Heavy Landing (flag throw_splash) wider and harder.
const LAND_R := 1.8
const LAND_DAMAGE := 10.0
const LAND_BIG_R := 3.4
const LAND_BIG_DAMAGE := 22.0
## The haymaker's victim's flight before it lands (Heavy Landing).
const HAY_FLIGHT := 0.45

## Cannonball Fist: who it goes for (m), the drift in to meet them, the punch (s, the pose's strike), and the body's
## flight down the line bowling over everyone it passes.
const CANNON_REACH := 4.5
const CANNON_AT := FistMoves.CANNON_AT
const CANNON_DAMAGE := 34.0
const CANNON_FLY := 18.0
const CANNON_LINE := 9.0
const CANNON_BOWL_R := 1.4
const CANNON_BOWL_DAMAGE := 18.0

## Meteor Fist: the hop, the drive down (m/s), the shockwave (m), its damage, the recovery after the landing, the
## longest it falls before it lands anyway; in the air the dive's speed. A dive hits harder by the height fallen.
const METEOR_UP := 6.0
const METEOR_DOWN := 18.0
const METEOR_DIVE := 26.0
const METEOR_R := 4.5
const METEOR_DAMAGE := 30.0
const METEOR_RECOVER := 0.45
const METEOR_MAX_FALL := 4.0
## Height fallen (from the dive's start or the apex before it, whichever is higher, to the impact): +FALL_PER_M a
## metre above FALL_FREE, at most METEOR_FALL_MAX (Sea King Fist's air unleash: SEA_FALL_MAX).
const FALL_FREE := 5.0
const FALL_PER_M := 0.02
const METEOR_FALL_MAX := 0.5
## Meteor Fist's look (Zach's reference: an honest rookie's big punch): orange-yellow fire on the fist, dark stars
## rimmed red, black-red crackle, purple speed lines.
const METEOR_FIRE := Color(1.0, 0.62, 0.18)
const METEOR_RIM := Color(1.0, 0.16, 0.1)
const METEOR_LINES := Color(0.8, 0.4, 1.0)

## Sea King Fist (the ult) arms the fist instead of punching: a short charge, then ARMED_SECS to let it go (attack
## or the ult key) while you move freely; run out and the glow fades with ARMED_REFUND of the ult back. The unleash
## adapts: on the ground a straight Galaxy punch down a line (SEA_LINE m, wide SEA_W) that blows up where it lands;
## in the air a dive onto the ground (harder by the height fallen, at most SEA_FALL_MAX, the blast a little wider);
## within COUNTER_TICKS of a landed parry it hits that attacker point-blank first; out of a dash it carries the speed.
const ARM_DUR := 0.6
const ARM_AT := 0.45
const ARMED_SECS := 8.0
const ARMED_REFUND := 0.5
const SEA_DUR := 1.25
const SEA_AT := 0.3
const SEA_LINE := 16.0
const SEA_W := 2.8
const SEA_TRAVEL := 0.35
const SEA_DAMAGE := 60.0
const SEA_BLAST_R := 5.0
const SEA_BLAST_DAMAGE := 40.0
const SEA_DIVE := 30.0
const SEA_AIR_R := 6.0
const SEA_AIR_DAMAGE := 80.0
const SEA_FALL_MAX := 0.8
const COUNTER_TICKS := 60
const COUNTER_DAMAGE := 45.0
## After the unleash the fist keeps glowing this long.
const AFTERGLOW := 3.0
## Its look (Zach's reference: an old marine hero's galaxy punch): a white-gold core, a red/orange cross flare,
## stars in every colour, a white-hot pillar and an orange dome where it lands.
const SEA_GOLD := Color(1.0, 0.82, 0.4)
const SEA_FLARE := Color(1.0, 0.35, 0.12)
const STARS := [Color(1.0, 0.85, 0.3), Color(0.35, 0.95, 1.0), Color(1.0, 0.35, 0.85), Color(1.0, 1.0, 1.0)]


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func _cm() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("CombatManager")


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"shoulder_throw":
			var e: Node3D = s._target
			if e != null and is_instance_valid(e):
				s._dir = s._flat_to(e)
				s.face_direction(s._dir, 1.0)
			s._done["throwable"] = throwable(e)
			var clash: Vector3 = s._chest() + Vector3(0, 0.1, 0) + s._dir * 0.5
			if s._done["throwable"]:
				s.dur = THROW_DUR
				e.call("grabbed", s.dur + 0.3)
				p.body_model.play("shoulder_throw", s.dur)
			else:
				s.dur = ANSWER_DUR
				p.body_model.play("fs_cross", s.dur)
			_net().fx("sfx", ["parry", p.global_position, -3.0, 0.05, 0.8])
			_net().fx("ring", [clash, s._dir, 1.2, s._col(), 0.2, 0.16])
			_net().fx("impact", [clash, s._col(FXS.CORE)])
			_cm().apply_hitstop(0.08, [p])
			_cm().apply_slowmo(0.35, 0.12, 0.12)
			_cm().apply_camera_kick(0.22, 0.35)
		"cannonball_fist":
			s._target = s._aimed(CANNON_REACH)
			if s._target == null:
				s._target = s._nearest(CANNON_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = FistMoves.CANNON_LEN
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("fs_cannon", s.dur)
			_net().fx("sfx", ["whoosh", p.global_position, -9.0, 0.05, 0.8])
		"meteor_fist":
			s._done["air"] = not p.is_on_floor()
			s._done["top"] = maxf(p.fall_top, p.global_position.y)
			s.dur = METEOR_MAX_FALL
			p.body_model.play("fs_meteor", METEOR_MAX_FALL + 1.0)
			_net().fx("hot_fist", [p.body_model, true, 1.2, METEOR_FIRE, "fire", 1.1])
			_net().fx("sfx", ["whoosh", p.global_position, -7.0, 0.05, 0.7])
		"sea_king_fist":
			s.dur = ARM_DUR
			p.body_model.play("sea_king_charge", s.dur)
			_net().fx("gather", [_fist(p), 1.6, SEA_GOLD, ARM_AT, 18])
			_net().fx("sfx", ["haki", p.global_position, -6.0, 0.0, 0.8])
		"sea_king_unleash":
			_unleash_enter(s)
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"shoulder_throw":
			s._rooted(delta, 0.0)
			if s._done["throwable"]:
				_throw(s)
			elif s._once("answer", ANSWER_AT):
				_answer(s)
		"cannonball_fist":
			_cannon(s, delta)
		"meteor_fist":
			_meteor(s, delta)
		"sea_king_fist":
			s._rooted(delta, 0.0)
			if s.t < ARM_AT and s._once("dust%d" % int(s.t / 0.1), s.t):
				_net().fx("dust", [s.player.global_position + Vector3(randf_range(-1.0, 1.0), 0.05, randf_range(-1.0, 1.0)), 2, 0.5])
				_cm().apply_camera_shake(0.03 + s.t * 0.06)
			if s._once("armed", ARM_AT):
				s.player.fist_armed = ARMED_SECS
				_net().fx("star_glint", [_fist(s.player), 1.2, SEA_GOLD, 0.35])
				_net().fx("ring", [_fist(s.player), Vector3.UP, 1.4, SEA_GOLD, 0.3, 0.14])
				_net().fx("sfx", ["blip_high", s.player.global_position, -6.0, 0.0, 0.7])
		"sea_king_unleash":
			_unleash_update(s, delta)
		_:
			return false
	return true


## A light enemy that can be picked up (not a boss, a heavy or a big bug).
static func throwable(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e is Node3D and not e.is_in_group("bosses") and e.has_method("grabbed") \
		and e.has_method("vine_weight") and str(e.call("vine_weight")) == "light"


## Their arm caught, your back turned into them, then over your shoulder and down ahead.
static func _throw(s) -> void:
	var p: Player = s.player
	var fwd: Vector3 = s._dir
	if s.t < 0.25:
		s._carry(p.global_position + fwd * 0.7 + Vector3.UP * 0.1)
	elif s.t < THROW_AT:
		var k := clampf((s.t - 0.25) / (THROW_AT - 0.25), 0.0, 1.0)
		s._carry(p.global_position + fwd * (0.4 + 1.6 * k) + Vector3.UP * (0.1 + 1.6 * sin(k * PI * 0.8)))
	if s._once("throw", THROW_AT) and s._target and is_instance_valid(s._target):
		var hd: HitData = s._hd(THROW_DAMAGE, 12.0, true)
		hd.unblockable = true
		s._strike_toward(s._target, hd, fwd)
		_net().fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 1.1])
		_cm().apply_camera_kick(0.12, 0.25)
	if s._once("land", THROW_LAND):
		landing(p, p.global_position + fwd * 4.5, [s._target])


## The caught blow turned aside and a straight right back into them.
static func _answer(s) -> void:
	var p: Player = s.player
	if s._target == null or not is_instance_valid(s._target):
		return
	var hd: HitData = s._hd(ANSWER_DAMAGE, 9.0, false)
	hd.unblockable = true
	hd.breaker = true
	hd.stagger_duration = 0.7
	hd.impact = "punch_heavy"
	s._strike_toward(s._target, hd, s._dir)
	var at: Vector3 = s._chest() + s._dir * 0.9
	_net().fx("punch_wind", [at - s._dir * 0.4, s._dir, 1.4, s._col(FXS.CORE), true])
	_net().fx("sfx", ["punch_heavy", at, -3.0, 0.05, 0.9])


static func _fist(p: Player) -> Vector3:
	return p.body_model.hand_r.global_position


## Planted, chambered, then one long straight: the one it meets is launched down the line and everyone the body
## passes on the way (CANNON_LINE m) is bowled over behind it.
static func _cannon(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	if s.t < CANNON_AT - 0.06 and alive:
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.3) / maxf(CANNON_AT - 0.06 - s.t, 0.05), 0.0, 12.0))
	else:
		s._rooted(delta, 0.0)
	if s._once("gather", 0.04):
		_net().fx("gather", [p.global_position + Vector3(0, 0.9, 0) - s._dir * 0.2, 1.3, s._col(), 0.24, 12])
	if s._once("glint", CANNON_AT - 0.06):
		_net().fx("star_glint", [_fist(p), 0.6, s._col(), 0.18])
	if s._once("punch", CANNON_AT):
		var at: Vector3 = s._chest() + s._dir * 1.0
		_net().fx("punch_wind", [at - s._dir * 0.5, s._dir, 2.2, s._col(FXS.CORE), true])
		_net().fx("ring", [at, s._dir, 1.6, s._col(), 0.24, 0.16])
		_net().fx("speed_lines", [at, s._dir, Color(1.0, 0.97, 0.9), 8, 2.2, 0.2, randi() % 1000])
		_net().fx("dust", [p.global_position + Vector3(0, 0.05, 0) - s._dir * 0.4, 8, 0.7])
		s._spray(at, s._dir, 10, 7.0)
		_net().fx("sfx", ["punch_heavy", at, 0.0, 0.05, 0.75])
		p.squash(-3.0)
		_cm().apply_camera_kick(0.18, 0.3)
		if alive and s._target.global_position.distance_to(p.global_position) < 3.0:
			var hd: HitData = s._hd(CANNON_DAMAGE, 16.0, true)
			hd.unblockable = true
			hd.breaker = true
			hd.impact = "punch_heavy"
			hd.hitstop_duration = 0.1
			s._strike_toward(s._target, hd, s._dir)
			s._hit.append(s._target)
			s._done["from"] = s._target.global_position
			_net().fx("impact", [s._body_center(s._target), s._col(FXS.ACCENT)])
			_cm().apply_hitstop(0.09, [p])
	# the body flying down the line: a streak behind it, everyone it reaches knocked down along it
	if s._done.has("from") and s.t > CANNON_AT:
		var from: Vector3 = s._done["from"]
		var gone := minf((s.t - CANNON_AT) * CANNON_FLY, CANNON_LINE)
		var ball: Vector3 = from + s._dir * gone
		for e in s._pc.enemies_in(ball + Vector3(0, 0.8, 0), CANNON_BOWL_R):
			if e in s._hit:
				continue
			s._hit.append(e)
			var hd: HitData = s._hd(CANNON_BOWL_DAMAGE, 10.0, true)
			hd.impact = "punch"
			s._strike_toward(e, hd, s._dir + (e.global_position - ball).normalized() * 0.3)
			_net().fx("dust_ring", [e.global_position, 8, 0.7])
			_net().fx("sfx", ["thud", e.global_position, -2.0, 0.05, 0.9])
		if s._once("trail", CANNON_AT + 0.05):
			_net().fx("streak", [from + Vector3(0, 1.0, 0), from + Vector3(0, 1.0, 0) + s._dir * CANNON_LINE, s._col(FXS.EDGE), 0.3, 0.4])
		for k in 4:
			if s._once("dust%d" % k, CANNON_AT + 0.08 + k * 0.1):
				_net().fx("dust", [ball + Vector3(0, 0.1, 0), 4, 0.6])


## The share a dive's fall adds (height fallen from `top` to `y`, above FALL_FREE), capped at `cap`.
static func fall_bonus(top: float, y: float, cap: float) -> float:
	return clampf((top - y - FALL_FREE) * FALL_PER_M, 0.0, cap)


## A hop (or, in the air, a dive straight down) with the fist burning, the overhand driven into the ground: cracked
## earth, a shockwave ring knocking everyone round you flat; harder by the height fallen.
static func _meteor(s, delta: float) -> void:
	var p: Player = s.player
	var air: bool = s._done["air"]
	s._done["top"] = maxf(float(s._done["top"]), p.global_position.y)
	if s._done.has("landed"):
		s._rooted(delta, 0.0)
		return
	if not air and s._once("hop", FistMoves.METEOR_HOP):
		p.velocity = s._dir * 2.5 + Vector3.UP * METEOR_UP
		p.squash(2.0)
	if s._once("glint", FistMoves.METEOR_TOP):
		var f := _fist(p)
		for k in 3:
			var a := TAU * k / 3.0 + randf() * 0.5
			_net().fx("star_glint", [f + Vector3(cos(a) * 0.6, sin(a) * 0.5 + 0.2, sin(a) * 0.4), randf_range(0.5, 0.8), METEOR_RIM, 0.35, true])
		_net().fx("sfx", ["whoosh_big", p.global_position, -5.0, 0.05, 0.75])
	if s.t < FistMoves.METEOR_DRIVE:
		if air:
			p.velocity = p.velocity.move_toward(Vector3.ZERO, 40.0 * delta)
		else:
			s.apply_gravity(delta)
	else:
		if s._once("drive", FistMoves.METEOR_DRIVE):
			var down: Vector3 = (s._dir * (0.15 if air else 0.25) + Vector3.DOWN).normalized()
			_net().fx("speed_lines", [_fist(p), -down, METEOR_LINES, 10, 2.5, 0.3, randi() % 1000])
			if air:
				_net().fx("hot_fist", [p.body_model, true, METEOR_MAX_FALL, METEOR_FIRE, "fire", 1.2])
		var sp := METEOR_DIVE if air else METEOR_DOWN
		var ahead := 0.0 if air else 3.0
		p.velocity = Vector3(s._dir.x * ahead, -sp, s._dir.z * ahead)
		if air and int(s.t * 10.0) != int((s.t - delta) * 10.0):
			_net().fx("bolt", [_fist(p), _fist(p) + Vector3.UP * 2.2 + s._dir * randf_range(-0.6, 0.6), METEOR_RIM, 0.06, 0.18, randi() % 1000, true])
	p.move_and_slide()
	if (s.t > FistMoves.METEOR_DRIVE - 0.05 and p.is_on_floor()) or s.t > METEOR_MAX_FALL - METEOR_RECOVER:
		s._done["landed"] = true
		p.velocity = Vector3.ZERO
		s.dur = s.t + METEOR_RECOVER
		_meteor_slam(s, fall_bonus(float(s._done["top"]), p.global_position.y, METEOR_FALL_MAX))


static func _meteor_slam(s, bonus: float) -> void:
	var p: Player = s.player
	var at: Vector3 = p.global_position + s._dir * 0.7
	p.body_model.play("fs_meteor_land", METEOR_RECOVER + 0.1)
	s._done["bonus"] = bonus
	for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), METEOR_R):
		var close: bool = e.global_position.distance_to(at) < 2.0
		var hd: HitData = s._hd(METEOR_DAMAGE * (1.25 if close else 1.0) * (1.0 + bonus), 10.0, true)
		hd.unblockable = true
		hd.impact = "punch_heavy"
		strike_from(p, e, hd, at)
	for k in 6:
		_net().fx("ground_crack", [at, s._dir.rotated(Vector3.UP, TAU * k / 6.0 + randf_range(-0.25, 0.25)), METEOR_R * 0.7,
			METEOR_RIM if s._elem() else Color(0, 0, 0, 0), randi() % 10000, 0.12])
	_net().fx("ring", [at, Vector3.UP, METEOR_R, METEOR_FIRE, 0.4, 0.12])
	_net().fx("ring", [at + Vector3(0, 0.3, 0), Vector3.UP, METEOR_R * 0.5, Color(1.0, 0.95, 0.8), 0.25, 0.2])
	_net().fx("dust_ring", [at, 18, 1.3])
	_net().fx("debris", [at + Vector3(0, 0.2, 0), Vector3.UP, 10, Color(0.35, 0.3, 0.25), 6.0])
	_net().fx("impact", [at + Vector3(0, 0.3, 0), METEOR_FIRE])
	_net().fx("star_glint", [at + Vector3(0, 0.6, 0), 1.4, METEOR_RIM, 0.4, true])
	for k in 3:
		var a := TAU * k / 3.0 + randf()
		_net().fx("bolt", [at + Vector3(0, 0.3, 0), at + Vector3(cos(a) * 2.2, 0.4 + randf() * 0.8, sin(a) * 2.2), METEOR_RIM, 0.07, 0.25, randi() % 1000, true])
	_net().fx("flash_light", [at + Vector3(0, 0.8, 0), METEOR_FIRE, 4.0, 8.0, 0.3])
	_net().fx("sfx", ["thud", at, 3.0, 0.05, 0.6])
	_net().fx("sfx", ["punch_heavy", at, 0.0, 0.05, 0.7])
	p.squash(-5.0)
	_cm().apply_hitstop(0.1, [p])
	_cm().apply_camera_shake(0.3 + 0.2 * bonus)
	_cm().apply_camera_kick(0.2, 0.35)


# --------------------------------------------------------------------------
# Sea King Fist: armed, then unleashed
# --------------------------------------------------------------------------
## Let the armed fist go (attack or the ult key while armed): false when the body can't punch right now.
static func unleash(p: Player) -> bool:
	if p.fist_armed <= 0.0 or p.context != Player.Context.ON_FOOT or p.is_swimming():
		return false
	if not p.is_free() and p.current_state_name() not in ["Jump", "Fall", "Dodge", "Parry", "Block", "LightAttack", "HeavyAttack", "Plunge", "Crouch", "Shoot"]:
		return false
	p.state_machine.force_state("Technique", {"id": "sea_king_unleash"})
	return true


## The fist ran out of time: the glow fades and half the ult comes back.
static func armed_out(p: Player) -> void:
	p.fist_armed = 0.0
	p.power.ult = minf(p.power.ult + PowerComponent.ULT_MAX * ARMED_REFUND, PowerComponent.ULT_MAX)
	_net().fx("smoke", [_fist(p), 3, 0.4, 0.8, Color(0.9, 0.85, 0.75, 0.6)])
	_net().fx("sfx", ["blip_low", p.global_position, -8.0, 0.0, 0.7])
	p.call("_toast", "The fist cools")


## The galaxy glow kept on the fist while it's armed (every screen: the snapshot's NF_GALAXY on a crewmate's).
static func keep_glow(h: Humanoid, on: bool) -> void:
	var g = h.get_meta("galaxy_fist") if h.has_meta("galaxy_fist") else null
	if on and (g == null or not is_instance_valid(g)):
		var fx := (Engine.get_main_loop() as SceneTree).root.get_node("FX")
		h.set_meta("galaxy_fist", fx.hot_fist(h, true, -1.0, SEA_GOLD, "galaxy", 1.3))
	elif not on and g != null:
		h.remove_meta("galaxy_fist")
		if is_instance_valid(g):
			(g as Node).queue_free()


static func _unleash_enter(s) -> void:
	var p: Player = s.player
	p.fist_armed = 0.0
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	s._done["carry"] = hv if hv.length() > p.move_speed * 1.1 else Vector3.ZERO
	s._done["air"] = not p.is_on_floor() and p.height_above_ground() > 1.5
	s._done["top"] = maxf(p.fall_top, p.global_position.y)
	var foe = p.parried_by
	s._done["counter"] = is_instance_valid(foe) and Engine.get_physics_frames() - p.parried_tick <= COUNTER_TICKS \
		and foe.global_position.distance_to(p.global_position) < 4.0 and not s._done["air"]
	if s._done["counter"]:
		s._target = foe
		s._dir = s._flat_to(foe)
		s.face_direction(s._dir, 1.0)
	elif (s._done["carry"] as Vector3).length() > 0.1:
		s._dir = (s._done["carry"] as Vector3).normalized()
		s.face_direction(s._dir, 1.0)
	p.hurtbox.set_deferred("monitorable", false)
	if s._done["air"]:
		s.dur = METEOR_MAX_FALL
		p.body_model.play("fs_meteor", METEOR_MAX_FALL + 1.0)
	else:
		s.dur = SEA_DUR
		p.body_model.play("fs_cannon", SEA_AT / FistMoves.CANNON_AT * FistMoves.CANNON_LEN)
	_net().fx("hot_fist", [p.body_model, true, SEA_DUR, SEA_GOLD, "galaxy", 1.6])
	_net().fx("sfx", ["whoosh_big", p.global_position, -2.0, 0.05, 0.55])


static func _unleash_update(s, delta: float) -> void:
	var p: Player = s.player
	if s._done["air"]:
		_sea_dive(s, delta)
		return
	var carry: Vector3 = s._done["carry"]
	if carry.length() > 0.1 and s.t < SEA_AT + 0.2:
		var k: float = 1.0 - s.t / (SEA_AT + 0.2)
		p.velocity.x = carry.x * k
		p.velocity.z = carry.z * k
		s.apply_gravity(delta)
		p.move_and_slide()
	else:
		s._rooted(delta, 0.0)
	if s._once("glint", SEA_AT - 0.1):
		_net().fx("star_glint", [_fist(p), 1.0, SEA_GOLD, 0.2])
	if s._once("punch", SEA_AT):
		var at: Vector3 = s._chest() + s._dir * 0.9
		if s._done["counter"] and s._target and is_instance_valid(s._target):
			var hd: HitData = s._hd(COUNTER_DAMAGE, 14.0, true)
			hd.unblockable = true
			hd.impact = "punch_heavy"
			s._strike_toward(s._target, hd, s._dir)
			s._hit.append(s._target)
			_net().fx("impact", [s._body_center(s._target), SEA_GOLD])
		_flare(s, at)
		var end: Vector3 = p.global_position + s._dir * SEA_LINE
		_net().fx("comet", [at, end + Vector3(0, 0.9, 0), 2.0, SEA_TRAVEL, SEA_GOLD])
		_net().fx("ground_crack", [p.global_position + s._dir * 1.0, s._dir, SEA_LINE * 0.8, SEA_FLARE if s._elem() else Color(0, 0, 0, 0), randi() % 10000, SEA_TRAVEL])
		s._done["blast_at"] = end
	# the line: everyone on it struck as the punch reaches them; the blast where it lands
	if s._done.has("blast_at") and not s._done.has("blasted"):
		var gone: float = clampf((s.t - SEA_AT) / SEA_TRAVEL, 0.0, 1.0) * SEA_LINE
		for e in s._pc.enemies_in(p.global_position + s._dir * SEA_LINE * 0.5 + Vector3(0, 0.9, 0), SEA_LINE * 0.6):
			if e in s._hit:
				continue
			var rel: Vector3 = e.global_position - p.global_position
			rel.y = 0.0
			var along: float = rel.dot(s._dir)
			if along < -0.5 or along > gone or (rel - s._dir * along).length() > SEA_W:
				continue
			s._hit.append(e)
			var hd: HitData = s._hd(SEA_DAMAGE, 16.0, true)
			hd.unblockable = true
			hd.impact = "punch_heavy"
			s._strike_toward(e, hd, s._dir)
			_net().fx("star_glint", [s._body_center(e), 0.9, STARS[s._hit.size() % STARS.size()], 0.3])
		if s.t >= SEA_AT + SEA_TRAVEL:
			s._done["blasted"] = true
			var b: Vector3 = s._done["blast_at"]
			_blast(s, Vector3(b.x, p.global_position.y, b.z), SEA_BLAST_R, SEA_BLAST_DAMAGE, 0.0)
	if s._once("afterglow", s.dur - 0.05):
		_net().fx("hot_fist", [p.body_model, true, AFTERGLOW, SEA_GOLD, "galaxy", 1.0])


## In the air: hang a beat with the fist up, then straight down onto the ground, the blast where you land.
static func _sea_dive(s, delta: float) -> void:
	var p: Player = s.player
	s._done["top"] = maxf(float(s._done["top"]), p.global_position.y)
	if s._done.has("landed"):
		s._rooted(delta, 0.0)
		return
	if s.t < FistMoves.METEOR_DRIVE:
		p.velocity = p.velocity.move_toward(Vector3.ZERO, 40.0 * delta)
	else:
		if s._once("drive", FistMoves.METEOR_DRIVE):
			_flare(s, _fist(p))
		p.velocity = Vector3(0, -SEA_DIVE, 0)
		if int(s.t * 12.0) != int((s.t - delta) * 12.0):
			_net().fx("star_glint", [_fist(p) + Vector3(randf_range(-0.8, 0.8), randf_range(0.3, 1.5), randf_range(-0.8, 0.8)),
				randf_range(0.4, 0.8), STARS[randi() % STARS.size()], 0.3])
	p.move_and_slide()
	if (s.t > FistMoves.METEOR_DRIVE - 0.05 and p.is_on_floor()) or s.t > METEOR_MAX_FALL - METEOR_RECOVER:
		s._done["landed"] = true
		p.velocity = Vector3.ZERO
		s.dur = s.t + METEOR_RECOVER + 0.2
		p.body_model.play("fs_meteor_land", METEOR_RECOVER + 0.3)
		var bonus := fall_bonus(float(s._done["top"]), p.global_position.y, SEA_FALL_MAX)
		_blast(s, p.global_position + s._dir * 0.6, SEA_AIR_R * (1.0 + bonus * 0.5), SEA_AIR_DAMAGE * (1.0 + bonus), bonus)
		_net().fx("hot_fist", [p.body_model, true, AFTERGLOW, SEA_GOLD, "galaxy", 1.0])


## The throw of the Galaxy punch: a huge cross flare at the fist (red-orange beams, a white-hot centre), stars in
## every colour, speed lines, the moment.
static func _flare(s, at: Vector3) -> void:
	var p: Player = s.player
	_net().fx("star_glint", [at, 2.6, SEA_FLARE, 0.45, false, 2.6])
	_net().fx("star_glint", [at, 1.4, SEA_GOLD, 0.3])
	for k in 5:
		_net().fx("star_glint", [at + Vector3(randf_range(-1.2, 1.2), randf_range(-0.6, 1.0), randf_range(-1.2, 1.2)), randf_range(0.4, 0.8), STARS[k % STARS.size()], 0.4])
	_net().fx("speed_lines", [at, s._dir, Color(1.0, 0.9, 0.7), 12, 3.0, 0.3, randi() % 1000])
	_net().fx("punch_wind", [at - s._dir * 0.4, s._dir, 2.6, SEA_GOLD, true])
	_net().fx("sfx", ["punch_heavy", at, 2.0, 0.05, 0.55])
	_net().fx("sfx", ["whoosh_big", at, 2.0, 0.05, 0.5])
	p.squash(-4.0)
	s._moment(0.3, 0.3, 0.6, 0.35)


## Where it lands: a white-hot pillar, an orange dome swelling over the ground, a shockwave ring, rock flung, cracks;
## everyone within `r` knocked flat.
static func _blast(s, at: Vector3, r: float, damage: float, bonus: float) -> void:
	var p: Player = s.player
	for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), r):
		if e in s._hit:
			continue
		s._hit.append(e)
		var hd: HitData = s._hd(damage, 14.0, true)
		hd.unblockable = true
		hd.impact = "punch_heavy"
		strike_from(p, e, hd, at)
	_net().fx("light_pillar", [at, 12.0 + 6.0 * bonus, r, 0.9, SEA_FLARE])
	_net().fx("ring", [at, Vector3.UP, r * 1.4, SEA_FLARE, 0.5, 0.1])
	_net().fx("ring", [at + Vector3(0, 0.4, 0), Vector3.UP, r * 0.7, SEA_GOLD, 0.35, 0.18])
	_net().fx("dust_ring", [at, 22, 1.6])
	_net().fx("debris", [at + Vector3(0, 0.2, 0), Vector3.UP, 14, Color(0.35, 0.3, 0.25), 8.0])
	for k in 6:
		_net().fx("ground_crack", [at, s._dir.rotated(Vector3.UP, TAU * k / 6.0 + randf_range(-0.2, 0.2)), r * 0.8, SEA_FLARE if s._elem() else Color(0, 0, 0, 0), randi() % 10000, 0.14])
	for k in 6:
		var a := TAU * k / 6.0 + randf()
		_net().fx("star_glint", [at + Vector3(cos(a) * r * 0.5, randf_range(0.8, 3.0), sin(a) * r * 0.5), randf_range(0.5, 1.0), STARS[k % STARS.size()], 0.45])
	_net().fx("sfx", ["thud", at, 6.0, 0.03, 0.45])
	_net().fx("sfx", ["cannon", at, 0.0, 0.05, 0.6])
	p.hurtbox.set_deferred("monitorable", true)
	_cm().apply_hitstop(0.12, [p])
	_cm().apply_camera_shake(0.5 + 0.2 * bonus)


## A body come down at `at`: dust and a thud, and everyone close (not those in `skip`) knocked flat; with Heavy
## Landing it lands like a cannonball (a wider ring, harder, rock thrown up, the camera shaken).
static func landing(p: Player, at: Vector3, skip: Array) -> void:
	var big := p.progression.has_flag("throw_splash")
	var r := LAND_BIG_R if big else LAND_R
	_net().fx("dust_ring", [at, 16 if big else 8, 1.3 if big else 0.8])
	_net().fx("sfx", ["thud", at, 3.0 if big else 0.0, 0.05, 0.65 if big else 0.8])
	if big:
		var tree := "unarmed" if p.progression.elemental("unarmed") else "plain"
		_net().fx("ring", [at + Vector3(0, 0.12, 0), Vector3.UP, r, FXS.tree_col(tree, FXS.EDGE), 0.32, 0.14])
		_net().fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 7, Color(0.35, 0.3, 0.25), 4.5])
		_net().fx("ground_crack", [at, Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), r * 0.6, Color(0, 0, 0, 0), randi() % 10000, 0.1])
		if at.distance_to(p.global_position) < 18.0:
			_cm().apply_camera_shake(0.2)
	for e in p.power.enemies_in(at + Vector3(0, 0.8, 0), r):
		if e in skip:
			continue
		var hd := p.melee_hit(LAND_BIG_DAMAGE if big else LAND_DAMAGE, "skill")
		hd.knockdown = true
		hd.knockback_force = 8.0 if big else 6.0
		hd.stagger_duration = 0.5
		hd.hitstop_duration = 0.05
		strike_from(p, e, hd, at)


## Heavy Landing on whoever the haymaker put down: where they come down after the flight.
static func haymaker_landed(p: Player, victims: Array) -> void:
	if not p.progression.has_flag("throw_splash"):
		return
	for e in victims:
		if not (e is Node3D) or not is_instance_valid(e):
			continue
		p.get_tree().create_timer(HAY_FLIGHT, false).timeout.connect(func():
			if is_instance_valid(e) and is_instance_valid(p):
				var c := CorsairGun.body_center(e)
				landing(p, Vector3(c.x, (e as Node3D).global_position.y, c.z), [e]))


## Strike `e` as if from `from` (the knockback carries it away from there).
static func strike_from(p: Player, e: Node3D, hd: HitData, from: Vector3) -> void:
	var hb := e.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var away := e.global_position - from
	away.y = 0.0
	if away.length() < 0.05:
		away = -p.player_model.global_basis.z
	p.power._proxy.global_position = e.global_position - away.normalized() * 2.0
	hb.take_hit(hd, p.power._proxy)
	p.power.add_ult(hd.damage)
	p.power.on_sword_hit(e, hd)
