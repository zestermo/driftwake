class_name DaggerArts
## The daggers' techniques, run by TechniqueState (`s`: its helpers and timeline,
## the driftwake-abilities skill). enter() and update() return false for ids that
## aren't theirs. One dagger (tree "dagger": crimson and shadow): Cutthroat, Knife
## Fan, Red Eclipse (ult); Slip is a guard skill (TechniqueState's riposte flow).
## Two daggers (tree "dual_dagger": venom green): Viper Flurry, Scissor Leap,
## Bleeding Edge, Hundred Fangs (ult). Wounds bleed through HitData meta "bleed"
## (PowerComponent._wounds).

const FAN_AT := 0.26
const FAN_REACH := 10.0
const FAN_COS := 0.76
const ECL_GO := 0.35
const ECL_EVERY := 0.16
const FANGS_GATHER := 0.4
const FANGS_BLINKS := 8
const FANGS_EVERY := 0.14
const FANGS_BURST := 1.9
const FANGS_R := 2.4


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"cutthroat":
			s.dur = 0.6
			s._target = s._aimed(8.0)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s._blink_behind(s._target)
			p.body_model.play("dg_cutthroat", s.dur)
		"knife_fan":
			s.dur = 0.7
			p.body_model.play("dg_fan", s.dur)
			Net.fx("sfx", ["blip", p.global_position, -12.0, 0.05, 1.4])
		"red_eclipse":
			s._victims = s._closest(12.0, 6)
			if s._victims.is_empty():
				s._refund("Nobody close enough")
				return true
			s.dur = ECL_GO + ECL_EVERY * s._victims.size() + 0.95
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("red_eclipse", s.dur)
			Net.fx("gather", [s._chest(), 2.4, s._col(), 0.32, 20])
			Net.fx("shadow_wisps", [p.global_position + Vector3(0, 0.3, 0), Vector3.UP, 14, s._col(), 1.5])
			Net.fx("ring", [p.global_position, Vector3.UP, 3.5, s._col(), 0.4, 0.08])
			Net.fx("sfx", ["whoosh_big", p.global_position, -4.0, 0.05, 0.55])
			s._moment(0.4, 0.25, 0.45, 0.25)
		"viper_flurry":
			s.dur = 1.0
			p.body_model.play("viper_flurry", s.dur)
			Net.fx("sfx", ["whoosh", p.global_position, -8.0, 0.05, 1.4])
		"scissor_leap":
			s.dur = 0.75
			var reach := 5.0
			var tgt: Node3D = s._aimed(9.0)
			if tgt:
				s._dir = s._flat_to(tgt)
				s.face_direction(s._dir, 1.0)
				reach = maxf(Vector2(tgt.global_position.x - p.global_position.x, tgt.global_position.z - p.global_position.z).length() - 0.9, 0.0)
			p.velocity = s._dir * reach / 0.42 + Vector3.UP * 4.8
			p.body_model.play("scissor_leap", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -5.0, 0.06, 1.35])
		"bleeding_edge":
			s.dur = 0.7
			p.body_model.play("edge_whet", s.dur)
		"hundred_fangs":
			s._target = s._aimed(7.0)
			if s._target == null:
				s._target = s._nearest(7.0, false)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 2.4
			s._from = s._target.global_position
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("hundred_fangs", s.dur)
			Net.fx("gather", [s._chest(), 2.4, s._col(), 0.36, 14])
			Net.fx("gather", [s._chest(), 2.4, s._col(FX.ACCENT) if s._elem() else s._col(FX.CORE), 0.36, 14])
			Net.fx("ring", [p.global_position, Vector3.UP, 3.5, s._col(), 0.4, 0.08])
			Net.fx("sfx", ["parry", p.global_position, -6.0, 0.0, 1.8])
			s._moment(0.4, 0.25, 0.45, 0.2)
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"cutthroat":
			s._rooted(delta, 0.0)
			if s._once("glint", 0.06):
				Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.8])
			if s._once("swoosh", 0.1):
				Net.fx("blade_swoosh", [s.player.body_model, 0.14, s._col()])
			if s._once("cut", 0.14) and s._target and is_instance_valid(s._target):
				_cutthroat(s)
		"knife_fan":
			s._rooted(delta, 0.0)
			if s._once("glint", FAN_AT - 0.08):
				Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.6])
			if s._once("fan", FAN_AT):
				_fan(s)
		"red_eclipse":
			_eclipse(s, delta)
		"viper_flurry":
			_viper(s, delta)
		"scissor_leap":
			s.apply_gravity(delta)
			s.player.move_and_slide()
			if s._once("glint", 0.24):
				Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.8])
				Net.fx("glint", [s._blade_tip(true), s._col(FX.CORE), 0.8])
			if s._once("swoosh", 0.34):
				Net.fx("blade_swoosh", [s.player.body_model, 0.16, s._col(), s._col(FX.ACCENT)])
			if not s._done.has("land") and s.t > 0.22 and (s.player.is_on_floor() or s.t > 0.6):
				s._done["land"] = true
				s.player.velocity = Vector3.ZERO
				_scissor_land(s)
		"bleeding_edge":
			s._rooted(delta, 0.0)
			if s._once("gather", 0.1):
				Net.fx("gather", [s._chest() + s._dir * 0.4, 1.2, s._col(), 0.25, 12])
			if s._once("whet", 0.4):
				_whet(s)
		"hundred_fangs":
			_fangs(s, delta)
		_:
			return false
	return true


# --------------------------------------------------------------------------
# One dagger
# --------------------------------------------------------------------------
## Cutthroat: behind them, the blade across the throat: a sure crit that bleeds.
static func _cutthroat(s) -> void:
	var p: Player = s.player
	var hd: HitData = p.melee_hit(30.0, "skill")
	if not hd.has_meta("crit"):
		hd.damage *= 1.5
		hd.set_meta("crit", true)
	hd.set_meta("bleed", 5.0)
	hd.stagger_duration = 0.9
	hd.knockback_force = 4.0
	hd.unblockable = true
	hd.sever = true
	hd.hitstop_duration = 0.08
	hd.camera_shake_intensity = 0.12
	s._strike(s._target, hd)
	var at: Vector3 = s._target.global_position + Vector3(0, 1.45, 0)
	Net.fx("impact", [at, s._col(FX.CORE)])
	Net.fx("ring", [at, s._dir, 1.0, s._col(), 0.2, 0.14])
	Net.fx("streak", [at - s._dir.cross(Vector3.UP) * 0.6, at + s._dir.cross(Vector3.UP) * 0.6, s._col(), 0.06, 0.25])
	s._spray(at, s._dir + Vector3.UP * 0.4, 10, 3.0)
	Net.fx("sfx", ["parry", p.global_position, -8.0, 0.05, 1.9])
	CombatManager.apply_camera_kick(0.16, 0.3)


## Knife Fan: five knives flicked out across a fan; everyone in it is cut and bleeds.
static func _fan(s) -> void:
	var p: Player = s.player
	var from: Vector3 = s._chest() + s._dir * 0.4
	var hit_dirs: Array = []
	for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0) + s._dir * FAN_REACH * 0.5, FAN_REACH):
		var d: Vector3 = (e as Node3D).global_position - p.global_position
		d.y = 0.0
		if d.length() > FAN_REACH or (d.length() > 0.6 and d.normalized().dot(s._dir) < FAN_COS):
			continue
		var c: Vector3 = s._body_center(e)
		var hd: HitData = s._hd(12.0, 3.0, false)
		hd.ranged = true
		hd.stagger_duration = 0.45
		hd.set_meta("bleed", 3.0)
		s._strike(e, hd)
		Net.fx("streak", [from, c, s._col(), 0.05, 0.2])
		Net.fx("impact", [c, s._col(FX.CORE)])
		hit_dirs.append(d.normalized())
	for i in range(5):
		var a := lerpf(-0.68, 0.68, i / 4.0)
		var d2: Vector3 = s._dir.rotated(Vector3.UP, a)
		Net.fx("streak", [from, from + d2 * FAN_REACH * 0.8 + Vector3(0, -0.3, 0), s._col(FX.CORE), 0.04, 0.18])
	Net.fx("ring", [from, s._dir, 1.0, s._col(), 0.18, 0.12])
	s._spray(from, s._dir, 8, 4.0)
	Net.fx("sfx", ["whoosh", from, -3.0, 0.05, 1.7])
	CombatManager.apply_camera_kick(0.1, 0.2)
	p.squash(-1.5)


## Red Eclipse: the dark gathers, then you're gone - out from behind each of them in
## turn, a cut and a crimson mark - then back in sight with your back to them, and
## a beat later every wound opens.
static func _eclipse(s, delta: float) -> void:
	var p: Player = s.player
	var n: int = s._victims.size()
	if s.t < ECL_GO:
		s._rooted(delta, 0.0)
		if int(s.t * 14.0) != int((s.t - delta) * 14.0):
			Net.fx("shadow_wisps", [p.global_position + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2)), Vector3.UP, 4, s._col(), 1.2])
		return
	if s._once("go", ECL_GO):
		p.vanish(ECL_EVERY * n + 0.18)
		Net.fx("shadow_wisps", [p.global_position + Vector3(0, 0.9, 0), Vector3.UP, 16, s._col(), 2.0])
		Net.fx("ring", [p.global_position, Vector3.UP, 2.6, s._col(), 0.3, 0.12])
		Net.fx("sfx", ["whoosh_big", p.global_position, -3.0, 0.05, 1.5])
	var i := int((s.t - ECL_GO) / ECL_EVERY)
	if i < n and not s._done.has("v%d" % i):
		s._done["v%d" % i] = true
		var e: Node3D = s._victims[i]
		if is_instance_valid(e) and BurnStatus.alive(e):
			var from: Vector3 = s._chest()
			var through: Vector3 = s._flat_to(e)
			s._place(e.global_position + through * 1.1)
			s._dir = -through
			s.face_direction(s._dir, 1.0)
			var hd: HitData = s._hd(10.0, 0.0, false)
			hd.stagger_duration = 1.2
			hd.unblockable = true
			s._strike(e, hd)
			var at := e.global_position + Vector3(0, 1.2, 0)
			Net.fx("streak", [from, s._chest(), s._col(), 0.08, 0.3])
			Net.fx("glint", [at, s._col(), 1.0])
			Net.fx("shadow_wisps", [at, Vector3.UP, 6, s._col(), 1.5])
			Net.fx("sfx", ["whoosh", at, -6.0, 0.1, 1.7])
	else:
		s._rooted(delta, 0.0)
	if s._once("back", s.dur - 0.75):
		# back in sight, your back to them, the blade flicked clean
		var c := Vector3.ZERO
		var k := 0
		for e in s._victims:
			if is_instance_valid(e):
				c += (e as Node3D).global_position
				k += 1
		if k > 0:
			var away: Vector3 = p.global_position - c / k
			away.y = 0.0
			if away.length() > 0.1:
				s._dir = away.normalized()
				s.face_direction(s._dir, 1.0)
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 1.2])
		Net.fx("sfx", ["parry", p.global_position, -6.0, 0.0, 2.0])
	if s._once("open", s.dur - 0.5):
		p.hurtbox.set_deferred("monitorable", true)
		for e in s._victims:
			if is_instance_valid(e) and BurnStatus.alive(e):
				var hd: HitData = s._hd(38.0, 5.0, true)
				hd.crumple = true
				hd.unblockable = true
				hd.sever = true
				hd.set_meta("bleed", 6.0)
				s._strike(e, hd)
				var at := (e as Node3D).global_position
				Net.fx("blood", [at + Vector3(0, 1.2, 0), Vector3.UP, 20])
				Net.fx("ring", [at, Vector3.UP, 2.0, s._col(), 0.35, 0.12])
				Net.fx("impact", [at + Vector3(0, 1.1, 0), s._col(FX.CORE)])
				if s._elem():
					Net.fx("shadow_wisps", [at + Vector3(0, 1.0, 0), Vector3.UP, 14, s._col(), 3.0])
		Net.fx("ring", [p.global_position, Vector3.UP, 9.0, s._col(), 0.6, 0.06])
		Net.fx("sfx", ["whoosh_big", p.global_position, 3.0, 0.05, 0.7])
		CombatManager.apply_camera_shake(0.4)
		CombatManager.apply_hitstop(0.1, [p])
		s._moment(0.3, 0.35, 0.7, 0.4)


# --------------------------------------------------------------------------
# Two daggers
# --------------------------------------------------------------------------
## Viper Flurry: eight stabs on a 0.09 s rhythm from 0.12 s, the blades in turn, then
## both ripped out (0.82 s): thrown back, bleeding.
static func _viper(s, delta: float) -> void:
	var p: Player = s.player
	s._drift(delta, 2.0)
	if s._once("ready", 0.04):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.6])
		Net.fx("blade_swoosh", [p.body_model, 0.78, s._col(), s._col(FX.ACCENT)])
	if s._hits < 8 and s.t >= 0.12 + s._hits * 0.09:
		s._hits += 1
		s._cone(2.3, 0.6, 4.0, 1.0, false, false, 0.25)
		var left: bool = s._hits % 2 == 0
		var tip: Vector3 = s._chest() + s._dir * 1.1 + s._dir.cross(Vector3.UP) * (0.15 if left else -0.15)
		Net.fx("ring", [tip, s._dir, 0.5, s._col(FX.ACCENT if left else FX.EDGE), 0.12, 0.18])
		if s._hits % 3 == 0:
			s._spray(tip, s._dir + Vector3.UP * 0.2, 4, 3.0)
		Net.fx("sfx", ["whoosh", p.global_position, -10.0, 0.1, 1.5 + s._hits * 0.04])
	if s._once("rip", 0.82):
		for e in s._cone(2.5, 0.6, 14.0, 9.0, false, true):
			BleedStatus.apply(e, 4.0, 5.0, p)
			Net.fx("twin_cross", [(e as Node3D).global_position + Vector3(0, 1.1, 0), s._dir, 0.55, s._col(), s._col(FX.ACCENT), 0.22])
		Net.fx("ring", [s._chest() + s._dir * 1.2, s._dir, 1.4, s._col(), 0.22, 0.16])
		s._spray(s._chest() + s._dir * 1.0, s._dir + Vector3.UP * 0.3, 10, 4.0)
		Net.fx("sfx", ["whoosh_big", p.global_position, -4.0, 0.05, 1.4])
		CombatManager.apply_camera_kick(0.18, 0.3)
		p.squash(-2.0)


## Scissor Leap's landing: both blades scissor through whoever's in front: it breaks
## their guard and bleeds.
static func _scissor_land(s) -> void:
	var p: Player = s.player
	for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0) + s._dir * 1.2, 2.6):
		var d: Vector3 = (e as Node3D).global_position - p.global_position
		d.y = 0.0
		if d.length() > 2.8 or (d.length() > 0.6 and d.normalized().dot(s._dir) < 0.35):
			continue
		var hd: HitData = s._hd(28.0, 6.0, false)
		hd.breaker = true
		hd.unblockable = true
		hd.sever = true
		hd.stagger_duration = 0.9
		hd.set_meta("bleed", 4.0)
		s._strike(e, hd)
		var c := (e as Node3D).global_position + Vector3(0, 1.1, 0)
		Net.fx("twin_cross", [c, s._dir, 0.7, s._col(), s._col(FX.ACCENT), 0.26])
		Net.fx("impact", [c, s._col(FX.CORE)])
	var at: Vector3 = p.global_position + s._dir * 1.1
	Net.fx("ring", [at, Vector3.UP, 2.2, s._col(), 0.28, 0.12])
	Net.fx("dust_ring", [p.global_position, 12, 0.9])
	s._spray(at + Vector3(0, 0.8, 0), s._dir + Vector3.UP * 0.3, 10, 3.5)
	Net.fx("sfx", ["thud", p.global_position, -2.0, 0.05, 1.1])
	Net.fx("sfx", ["parry", p.global_position, -8.0, 0.05, 1.6])
	CombatManager.apply_camera_shake(0.16)
	CombatManager.apply_camera_kick(0.16, 0.3)
	p.squash(-3.5)


## Bleeding Edge: the blades drawn apart along each other, both edges catching the light.
static func _whet(s) -> void:
	var p: Player = s.player
	s._pc.add_buff("bleeding_edge", 8.0)
	Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 1.0])
	Net.fx("glint", [s._blade_tip(true), s._col(FX.CORE), 1.0])
	Net.fx("ring", [s._chest(), Vector3.UP, 2.2, s._col(), 0.3, 0.1])
	Net.fx("sparkle", [s._chest(), 12, s._col()])
	s._spray(s._chest(), Vector3.UP, 12, 2.5)
	Net.fx("sfx", ["parry", p.global_position, -6.0, 0.0, 2.1])
	CombatManager.apply_camera_kick(0.1, 0.25)


## Hundred Fangs: blink after blink round the one you picked, the path drawing a
## star ({8/3}) of streaks, cutting everyone close each time and dragging them in;
## then the star bursts and they all fall, bleeding.
static func _fangs(s, delta: float) -> void:
	var p: Player = s.player
	var c: Vector3 = s._target.global_position if s._target and is_instance_valid(s._target) else s._from
	if s.t < FANGS_GATHER:
		s._rooted(delta, 0.0)
		return
	var i := int((s.t - FANGS_GATHER) / FANGS_EVERY)
	if i < FANGS_BLINKS and not s._done.has("b%d" % i):
		s._done["b%d" % i] = true
		var a := float(i) * TAU * 3.0 / 8.0
		var from: Vector3 = s._chest()
		Net.fx("afterimage", [p.body_model, s._col(FX.EDGE if i % 2 == 0 else FX.ACCENT), 0.4])
		s._place(Vector3(c.x + cos(a) * FANGS_R, p.global_position.y, c.z + sin(a) * FANGS_R))
		var to_c := c - p.global_position
		to_c.y = 0.0
		s._dir = to_c.normalized() if to_c.length() > 0.05 else s._dir
		s.face_direction(s._dir, 1.0)
		Net.fx("streak", [from, s._chest(), s._col(FX.EDGE if i % 2 == 0 else FX.ACCENT), 0.1, 0.9])
		for e in s._pc.enemies_in(c + Vector3(0, 0.9, 0), 3.0):
			var hd: HitData = s._hd(7.0, 1.5, false)
			hd.stagger_duration = 0.5
			s._strike_toward(e, hd, c - (e as Node3D).global_position)
		Net.fx("sfx", ["whoosh", p.global_position, -6.0, 0.1, 1.3 + 0.06 * i])
	elif i >= FANGS_BLINKS:
		s._rooted(delta, 0.0)
	if s._once("burst", FANGS_BURST):
		p.hurtbox.set_deferred("monitorable", true)
		Net.fx("twin_cross", [c + Vector3(0, 0.12, 0), s._dir, 3.0, s._col(), s._col(FX.ACCENT), 0.5, true])
		for e in s._pc.enemies_in(c + Vector3(0, 0.9, 0), 4.2):
			var hd: HitData = s._hd(38.0, 9.0, true)
			hd.unblockable = true
			hd.sever = true
			hd.set_meta("bleed", 5.0)
			s._strike_toward(e, hd, (e as Node3D).global_position - c)
			Net.fx("twin_cross", [(e as Node3D).global_position + Vector3(0, 1.1, 0), s._flat_to(e), 0.8, s._col(), s._col(FX.ACCENT), 0.35])
		Net.fx("ring", [c, Vector3.UP, 7.0, s._col(), 0.5, 0.08])
		Net.fx("ring", [c + Vector3(0, 1.0, 0), Vector3.UP, 5.0, s._col(FX.ACCENT) if s._elem() else s._col(FX.CORE), 0.4, 0.06])
		s._spray(c + Vector3(0, 1.0, 0), Vector3.UP, 20, 4.0)
		Net.fx("sfx", ["parry", p.global_position, 0.0, 0.0, 1.4])
		CombatManager.apply_camera_shake(0.35)
		CombatManager.apply_hitstop(0.1, [p])
		s._moment(0.3, 0.35, 0.7, 0.45)
