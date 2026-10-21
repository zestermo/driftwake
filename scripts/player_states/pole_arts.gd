class_name PoleArts
## The polearm's techniques (tree "polearm": storm - lemon-white lightning, a violet afterglow), run by
## TechniqueState (`s`: its helpers and timeline, the driftwake-abilities skill); enter() and update() return
## false for ids that aren't theirs. Hundred Thrusts (seven thrusts at four paces), Dragon Sweep (two low turns,
## the second trips), Vaulting Strike (over them, the point driven down, landing behind), Raijin's Wheel (ult:
## up spinning the spear overhead, down in the middle of a wheel of cuts, the point driven in and the wheel
## bursts). Poses in PoleMoves (pole_flurry, pole_dragon, pole_vstrike, pole_raijin).

const THRUSTS := 7
const THRUST_AT := 0.14
const THRUST_EVERY := 0.1
const THRUST_REACH := 4.2
const THRUST_DAMAGE := 6.0
const THRUST_LAST := 15.0

const DRAGON_R := 5.0
const DRAGON_AT := [0.42, 0.8]
const DRAGON_DAMAGE := [12.0, 16.0]

const VSTRIKE_REACH := 9.0
const VSTRIKE_AIR := 0.6
const VSTRIKE_AT := 0.4
const VSTRIKE_DAMAGE := 28.0

const WHEEL_DUR := 2.4
const WHEEL_UP := 6.0
const WHEEL_MOMENT := 0.42
const WHEEL_SPIN := Vector2(0.5, 1.72)
const WHEEL_EVERY := 0.14
const WHEEL_R := 5.5
const WHEEL_DAMAGE := 7.0
const WHEEL_SLAM := 1.8
const WHEEL_FINAL := 40.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"hundred_thrusts":
			s.dur = 1.1
			p.body_model.play("pole_flurry", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -9.0, 0.05, 1.3])
		"dragon_sweep":
			s.dur = 1.2
			p.body_model.play("pole_dragon", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -7.0, 0.05, 0.8])
		"vault_strike":
			s._target = s._aimed(VSTRIKE_REACH)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 1.0
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			var to: Vector3 = s._target.global_position - p.global_position
			to.y = 0.0
			p.velocity = s._dir * (to.length() + 1.4) / VSTRIKE_AIR + Vector3.UP * 7.0
			p.body_model.play("pole_vstrike", s.dur)
			Net.fx("dust", [p.global_position + s._dir * 1.1 + Vector3(0, 0.05, 0), 8, 0.6])
			Net.fx("sfx", ["thud", p.global_position, -9.0, 0.05, 1.3])
			Net.fx("sfx", ["whoosh_big", p.global_position, -6.0, 0.06, 1.0])
		"raijin_wheel":
			s.dur = WHEEL_DUR
			s._victims = s._closest(WHEEL_R + 3.0, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.velocity = Vector3(0, WHEEL_UP, 0)
			p.body_model.play("pole_raijin", s.dur)
			Net.fx("gather", [s._chest(), 2.6, s._col(), 0.4, 22])
			Net.fx("dust_ring", [p.global_position, 14, 0.9])
			Net.fx("sfx", ["whoosh_big", p.global_position, -3.0, 0.05, 0.6])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"hundred_thrusts":
			_thrusts(s, delta)
		"dragon_sweep":
			_dragon(s, delta)
		"vault_strike":
			_vstrike(s, delta)
		"raijin_wheel":
			_wheel(s, delta)
		_:
			return false
	return true


## Seven thrusts on a rhythm (the pose's peaks), each catching everyone on a narrow line four paces long; the
## last drives deeper and throws them back.
static func _thrusts(s, delta: float) -> void:
	s._rooted(delta, 0.1)
	var p: Player = s.player
	if s._once("glint", THRUST_AT - 0.06):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.7])
	for i in THRUSTS:
		if not s._once("t%d" % i, THRUST_AT + THRUST_EVERY * i):
			continue
		var last: bool = i == THRUSTS - 1
		var at: Vector3 = s._chest() + s._dir * 0.7
		var tip: Vector3 = at + s._dir * (THRUST_REACH + (0.4 if last else 0.0))
		if last:
			s._cone(THRUST_REACH + 0.4, 0.88, THRUST_LAST, 10.0, false, false)
			Net.fx("streak", [at, tip, s._col(), 0.2, 0.3])
			Net.fx("ring", [tip, s._dir, 1.4, s._col(), 0.24, 0.16])
			Net.fx("sfx", ["whoosh_big", p.global_position, -4.0, 0.05, 1.2])
			s._spray(tip, s._dir, 10, 5.0)
			if s._elem():
				Net.fx("bolt", [at, tip, s._col(), 0.1, 0.22, randi() % 1000])
			CombatManager.apply_camera_kick(0.12, 0.25)
		else:
			s._cone(THRUST_REACH, 0.9, THRUST_DAMAGE, 1.5, false, false, 0.25)
			var off := Vector3(randf_range(-0.15, 0.15), randf_range(-0.12, 0.18), 0)
			Net.fx("streak", [at + off, tip + off, s._col(FX.CORE) if i % 2 == 0 else s._col(), 0.07, 0.14])
			Net.fx("sfx", ["whoosh", p.global_position, -11.0, 0.08, 1.4 + 0.05 * i])


## Two low turns at the shins: everyone within five paces cut on each, the second taking their legs.
static func _dragon(s, delta: float) -> void:
	s._rooted(delta, 0.0)
	var p: Player = s.player
	if s._once("swoosh", 0.22):
		Net.fx("blade_swoosh", [p.body_model, 0.72, s._col()])
	for i in 2:
		if not s._once("turn%d" % i, DRAGON_AT[i]):
			continue
		var second: bool = i == 1
		s._ring(DRAGON_R, DRAGON_DAMAGE[i], 6.0 if second else 3.0, second, false)
		Net.fx("dust_ring", [p.global_position, 14 if second else 9, 1.0])
		Net.fx("ring", [p.global_position + Vector3(0, 0.25, 0), Vector3.UP, DRAGON_R, s._col(), 0.3, 0.1])
		Net.fx("sfx", ["whoosh_big", p.global_position, -5.0, 0.05, 0.85 if second else 1.0])
		if s._elem():
			for k in 3:
				var a := randf() * TAU
				var at := p.global_position + Vector3(cos(a), 0.3, sin(a)) * DRAGON_R * 0.8
				Net.fx("bolt", [at + Vector3(0, 0.9, 0), at, s._col(), 0.07, 0.18, randi() % 1000])
		if second:
			CombatManager.apply_camera_shake(0.2)


## Up and over the one you face: the point driven down into them at the top of the vault (it breaks a guard),
## then down behind them, turned to face them.
static func _vstrike(s, delta: float) -> void:
	var p: Player = s.player
	s.apply_gravity(delta)
	p.move_and_slide()
	if s._once("glint", VSTRIKE_AT - 0.08):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.8])
	if s._once("strike", VSTRIKE_AT) and s._target and is_instance_valid(s._target):
		var hd: HitData = s._hd(VSTRIKE_DAMAGE, 6.0, true)
		hd.breaker = true
		hd.unblockable = true
		s._strike(s._target, hd)
		var at: Vector3 = s._body_center(s._target)
		Net.fx("blade_swoosh", [p.body_model, 0.14, s._col()])
		Net.fx("streak", [s._blade_tip() + Vector3.UP * 1.2, at, s._col(), 0.16, 0.25])
		Net.fx("impact", [at, s._col(FX.ACCENT)])
		s._spray(at, Vector3.DOWN, 10, 4.0)
		if s._elem():
			Net.fx("bolt", [at + Vector3(0, 5.0, 0), at, s._col(), 0.12, 0.25, randi() % 1000])
		CombatManager.apply_hitstop(0.07, [p])
		CombatManager.apply_camera_kick(0.16, 0.3)
	if not s._done.has("land") and s.t > VSTRIKE_AT and (p.is_on_floor() or s.t > 0.9):
		s._done["land"] = true
		p.velocity = Vector3.ZERO
		if s._target and is_instance_valid(s._target):
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
		Net.fx("dust_ring", [p.global_position, 12, 0.8])
		Net.fx("sfx", ["thud", p.global_position, -6.0, 0.05, 0.9])
	if s._done.has("land"):
		p.velocity.x = 0.0
		p.velocity.z = 0.0


## Up spinning the spear overhead (the moment), down into the middle of a wheel of cuts that drags them in, then
## the point driven into the ground: the wheel bursts (lightning on everyone with the element) and they're down.
static func _wheel(s, delta: float) -> void:
	var p: Player = s.player
	s._rooted(delta, 0.0)
	if s._once("moment", WHEEL_MOMENT):
		s._moment(0.4, 0.25, 0.45, 0.25)
		Net.fx("ring", [p.global_position + Vector3(0, 2.2, 0), Vector3.UP, 2.6, s._col(), 0.35, 0.1])
		if s._elem():
			Net.fx("bolt", [p.global_position + Vector3(0.4, 9.0, 0.2), p.global_position + Vector3(0, 2.6, 0), s._col(), 0.14, 0.3, randi() % 1000])
		Net.fx("sfx", ["whoosh_big", p.global_position, 0.0, 0.05, 0.7])
	if s._once("swoosh", WHEEL_SPIN.x):
		Net.fx("blade_swoosh", [p.body_model, WHEEL_SPIN.y - WHEEL_SPIN.x, s._col()])
	# (its own burst is the slam: the turns' end is set past the move so _spin_hits never bursts)
	if s.t < WHEEL_SPIN.y:
		s._spin_hits(WHEEL_R, WHEEL_EVERY, WHEEL_DAMAGE, 9.0, 0.0, WHEEL_SPIN.x)
	if s._once("glint", WHEEL_SLAM - 0.1):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 1.0])
	if s._once("slam", WHEEL_SLAM):
		var at := p.global_position - p.player_model.global_basis.z * 1.1
		s._ring(WHEEL_R + 1.0, WHEEL_FINAL, 12.0, true, false)
		Net.fx("dust_ring", [at, 22, 1.4])
		Net.fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, WHEEL_R + 1.0, s._col(), 0.4, 0.14])
		Net.fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, (WHEEL_R + 1.0) * 0.6, s._col(FX.ACCENT), 0.3, 0.2])
		Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, Color(0.36, 0.31, 0.26), 5.0])
		Net.fx("impact", [at + Vector3(0, 0.3, 0), s._col(FX.CORE)])
		Net.fx("sfx", ["thud", at, 3.0, 0.05, 0.6])
		Net.fx("sfx", ["jelly_zap", at, 0.0, 0.05, 0.6])
		Net.fx("screen_flash", [p.global_position, Color(s._col(FX.CORE).r, s._col(FX.CORE).g, s._col(FX.CORE).b, 0.35), 0.25])
		if s._elem():
			Net.fx("bolt", [at + Vector3(0, 9.0, 0), at, s._col(), 0.18, 0.35, randi() % 1000])
			for e in s._victims:
				if is_instance_valid(e):
					var c: Vector3 = s._body_center(e)
					Net.fx("bolt", [c + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6)), c, s._col(), 0.1, 0.3, randi() % 1000])
					Net.fx("element", ["polearm", c, Vector3.UP, 8, 4.0])
		else:
			s._spray(at, Vector3.UP, 12, 5.0)
		CombatManager.apply_camera_shake(0.35)
		CombatManager.apply_camera_kick(0.2, 0.4)
		p.hurtbox.set_deferred("monitorable", true)
