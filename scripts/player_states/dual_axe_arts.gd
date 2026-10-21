class_name DualAxeArts
## Twin axes (style "dual_axe": an axe in each hand; tree "dual_axe": frost - rime and ice chips off every chop,
## a cold mist, ice heaving up out of the ground): the pair's numbers, the hook (the combo's third blow, a landed
## parry, the techniques) and the techniques. Techniques are run by TechniqueState (`s`: its helpers and
## timeline); enter() and update() return false for ids that aren't theirs. Poses in DualAxeMoves.


## The pair's design number ("speed", "hook"): the two axes' average (WeaponDesigns.axe).
static func pair(p: Player, key: String) -> float:
	var a := WeaponDesigns.axe(p.equipped_weapon.design, key)
	var b := WeaponDesigns.axe(p.offhand_weapon.design, key) if p.offhand_weapon else a
	return (a + b) * 0.5


## A blow with the off-hand axe hits as hard as that axe (x its power against the main hand's).
static func off_k(p: Player) -> float:
	return p.offhand_weapon.power() / p.equipped_weapon.power() if p.offhand_weapon else 1.0


## The pair's colour: plain steel until the frost is awakened (the tree's mastery passive `tier`: 1 the skills,
## 2 every blow).
static func col(p: Player, which: int = FX.EDGE, tier: int = 1) -> Color:
	if p.power.buff("coat"):
		return Player.HAKI_TRAIL
	return FX.tree_col("dual_axe" if p.progression.elemental("dual_axe", tier) else "plain", which)


## The beard hooked behind them and hauled: a light foe is dragged in to land just in front of you, reeling
## (bosses and the big beasts are too heavy: false, they only take the blow). The yank runs on the host.
static func hook(p: Player, e: Node, dmg: float = 2.0) -> bool:
	if not is_instance_valid(e) or not (e is Node3D) or not e.has_method("vine_yank") or e.is_in_group("bosses"):
		return false
	if not e.has_method("vine_weight") or str(e.call("vine_weight")) != "light":
		return false
	var fwd := -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	e.call("vine_yank", p.global_position + fwd * 0.2, dmg, false)
	var from := (e as Node3D).global_position + Vector3(0, 1.1, 0)
	Net.fx("streak", [from, p.global_position + Vector3(0, 1.1, 0) + fwd * 0.6, col(p), 0.07, 0.22])
	Net.fx("sfx", ["clack", from, -5.0, 0.06, 0.75])
	if p.progression.elemental("dual_axe"):
		Net.fx("element", ["dual_axe", from, -fwd + Vector3.UP * 0.3, 6, 3.0])
	return true


# --------------------------------------------------------------------------
# The techniques: Gallows Hook (the left axe flung round the one you aim at and hauled in, then a chop through
# their guard), Hewing Frenzy (eight chops walking in, then both crossed), Axestorm (everyone close hooked in,
# four turns walking, both crashed down), Fimbulwinter (ult: a roar, everyone hooked in, three turns, both
# crashed into the ground, ice heaving up under them). Poses: dx_gallows, dx_frenzy, dx_storm, dx_winter.
# --------------------------------------------------------------------------
const GALLOWS_REACH := 7.0
const GALLOWS_CHOP := 0.5
const GALLOWS_DAMAGE := 26.0

const FRENZY_DUR := 1.2
const FRENZY_CHOPS := 8
const FRENZY_DAMAGE := 6.0
const FRENZY_CROSS := 0.95
const FRENZY_FINAL := 18.0

const STORM_DUR := 1.8
const STORM_SPIN := Vector2(0.32, 1.42)
const STORM_EVERY := 0.16
const STORM_R := 3.3
const STORM_DAMAGE := 6.0
const STORM_CRASH := 1.6
const STORM_FINAL := 20.0

const WINTER_DUR := 2.6
const WINTER_HOOK := 0.52
const WINTER_SPIN := Vector2(0.68, 1.6)
const WINTER_EVERY := 0.12
const WINTER_DAMAGE := 7.0
const WINTER_CRASH := 1.95
const WINTER_R := 6.5
const WINTER_FINAL := 45.0


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	match id:
		"gallows_hook":
			s._target = s._aimed(GALLOWS_REACH)
			if s._target == null:
				s._target = s._nearest(GALLOWS_REACH, true)
			if s._target == null:
				s._refund("Nobody close enough")
				return true
			s.dur = 0.9
			s._dir = s._flat_to(s._target)
			s.face_direction(s._dir, 1.0)
			p.body_model.play("dx_gallows", s.dur)
		"hewing_frenzy":
			s.dur = FRENZY_DUR
			p.body_model.play("dx_frenzy", s.dur)
			Net.fx("sfx", ["hup", p.global_position, -8.0, 0.05, 0.9])
		"axestorm":
			s.dur = STORM_DUR
			p.body_model.play("dx_storm", s.dur)
			Net.fx("sfx", ["whoosh_big", p.global_position, -7.0, 0.05, 0.9])
		"fimbulwinter":
			s.dur = WINTER_DUR
			s._victims = s._closest(10.0, 8)
			p.hurtbox.set_deferred("monitorable", false)
			p.body_model.play("dx_winter", s.dur)
			Net.fx("gather", [p.global_position + Vector3(0, 0.6, 0), 3.0, s._col(FX.ACCENT) if s._elem() else s._col(), 0.35, 20])
			Net.fx("sfx", ["roar", p.global_position, -4.0, 0.05, 1.5])
		_:
			return false
	return true


static func update(s, delta: float) -> bool:
	match s.id:
		"gallows_hook":
			_gallows(s, delta)
		"hewing_frenzy":
			_frenzy(s, delta)
		"axestorm":
			_storm(s, delta)
		"fimbulwinter":
			_winter(s, delta)
		_:
			return false
	return true


## Both axes crashed down crossed ahead: everyone in front within `r` takes `base`, knocked flat; an X bitten
## into the ground, a ring, rock (and frost with the element).
static func _crash(s, r: float, base: float) -> void:
	var p: Player = s.player
	var at: Vector3 = p.global_position + s._dir * 1.3
	for e in s._pc.enemies_in(at + Vector3(0, 0.9, 0), r):
		var hd: HitData = s._hd(base, 10.0, true)
		hd.breaker = true
		s._strike(e, hd)
	Net.fx("twin_cross", [at + Vector3(0, 0.12, 0), s._dir, 1.0, s._col(), s._col(FX.ACCENT) if s._elem() else s._col(FX.CORE), 0.35, true])
	Net.fx("ring", [at, Vector3.UP, r, s._col(), 0.28, 0.12])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + s._dir * 0.3, 6, Color(0.35, 0.3, 0.25), 4.5])
	Net.fx("sfx", ["chop", at, -1.0, 0.05, 0.8])
	s._spray(at + Vector3(0, 0.4, 0), Vector3.UP + s._dir * 0.3, 12, 4.5)
	p.squash(-3.0)
	CombatManager.apply_hitstop(0.08, [p])
	CombatManager.apply_camera_kick(0.16, 0.3)
	CombatManager.apply_camera_shake(0.2)


## The left axe flung round the one you aimed at and hauled in (too heavy: you're hauled to them instead), then
## the right chopped down through their guard: unblockable, their wind-up broken, reeling.
static func _gallows(s, delta: float) -> void:
	var p: Player = s.player
	var alive: bool = s._target != null and is_instance_valid(s._target)
	if s._done.has("drag") and s.t < 0.42 and alive:
		var to: Vector3 = s._target.global_position - p.global_position
		to.y = 0.0
		s._drift(delta, clampf((to.length() - 1.4) / maxf(0.42 - s.t, 0.05), 0.0, 22.0))
	else:
		s._rooted(delta, 0.0)
	if s._once("throw", 0.18) and alive:
		Net.fx("streak", [s._blade_tip(true), s._body_center(s._target), s._col(), 0.06, 0.2])
		Net.fx("sfx", ["whoosh", p.global_position, -6.0, 0.05, 1.3])
	if s._once("haul", 0.22) and alive and not hook(p, s._target, 4.0):
		s._done["drag"] = true
		Net.fx("sfx", ["rope", p.global_position, -6.0, 0.05, 1.0])
	if s._once("glint", GALLOWS_CHOP - 0.07):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 0.8])
	if s._once("chop", GALLOWS_CHOP):
		alive = s._target != null and is_instance_valid(s._target)
		if alive and p.global_position.distance_to(s._target.global_position) < 3.4:
			var hd: HitData = s._hd(GALLOWS_DAMAGE, 6.0, false)
			hd.unblockable = true
			hd.breaker = true
			hd.stagger_duration = 1.0
			s._strike(s._target, hd)
			var at: Vector3 = s._body_center(s._target)
			Net.fx("impact", [at, s._col(FX.CORE)])
			Net.fx("ring", [at, s._dir, 1.2, s._col(), 0.22, 0.18])
			s._spray(at, s._dir + Vector3.UP * 0.4, 10, 4.0)
		else:
			s._cone(2.6, 0.5, GALLOWS_DAMAGE, 6.0, false, true)
		Net.fx("sfx", ["chop", p.global_position, -2.0, 0.05, 0.85])
		CombatManager.apply_hitstop(0.09, [p])
		CombatManager.apply_camera_kick(0.14, 0.28)


## Eight chops trading hands every 0.1 s, walking in (each cuts everyone just ahead), then both crossed.
static func _frenzy(s, delta: float) -> void:
	var p: Player = s.player
	if s.t < 0.86:
		s._drift(delta, 1.8)
	else:
		s._rooted(delta, 0.0)
	for i in FRENZY_CHOPS:
		if not s._once("c%d" % i, 0.11 + 0.1 * i):
			continue
		var hit: Array = s._cone(2.6, 0.35, FRENZY_DAMAGE, 1.5, false, false)
		Net.fx("ring", [s._chest() + s._dir * 1.1, s._dir, 0.6, s._col(), 0.12, 0.2])
		Net.fx("sfx", ["whoosh", p.global_position, -9.0, 0.06, 1.15 + 0.05 * (i % 4)])
		if not hit.is_empty():
			Net.fx("sfx", ["chop", p.global_position, -8.0, 0.08, 1.1])
			s._spray(s._chest() + s._dir * 1.1, s._dir + Vector3.UP * 0.3, 4, 3.0)
	if s._once("cross", FRENZY_CROSS):
		_crash(s, 2.8, FRENZY_FINAL)


## Everyone close hooked in, then four turns walking with both axes out, then both crashed down.
static func _storm(s, delta: float) -> void:
	var p: Player = s.player
	if s.t >= STORM_SPIN.x and s.t < STORM_SPIN.y:
		s._drift(delta, 2.0)
	else:
		s._rooted(delta, 0.0)
	if s._once("hook", STORM_SPIN.x - 0.06):
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), 6.0):
			if (e as Node3D).global_position.distance_to(p.global_position) > 2.0:
				hook(p, e)
	if s._once("swoosh", STORM_SPIN.x):
		Net.fx("blade_swoosh", [p.body_model, STORM_SPIN.y - STORM_SPIN.x, s._col(), s._col(FX.ACCENT)])
	if s.t < STORM_SPIN.y:
		s._spin_hits(STORM_R, STORM_EVERY, STORM_DAMAGE, 99.0, 0.0, STORM_SPIN.x)
	if s._once("crash", STORM_CRASH):
		_crash(s, 3.0, STORM_FINAL)


## The ultimate: a roar (the moment), every foe close hooked in at once, three turns with both axes out, then up
## and both crashed into the ground: a great ring throws them all down (ice heaving up under each with the frost).
static func _winter(s, delta: float) -> void:
	var p: Player = s.player
	s._rooted(delta, 0.0)
	if s._once("moment", 0.3):
		s._moment(0.35, 0.25, 0.3, 0.25)
		Net.fx("ring", [p.global_position + Vector3(0, 1.2, 0), Vector3.UP, 4.0, s._col(), 0.35, 0.1])
		s._spray(p.global_position + Vector3(0, 1.0, 0), Vector3.UP, 14, 3.0)
	if s._once("hook", WINTER_HOOK):
		for e in s._victims:
			if is_instance_valid(e):
				hook(p, e, 4.0)
		CombatManager.apply_camera_kick(0.1, 0.25)
	if s._once("swoosh", WINTER_SPIN.x):
		Net.fx("blade_swoosh", [p.body_model, WINTER_SPIN.y - WINTER_SPIN.x, s._col(), s._col(FX.ACCENT)])
	if s.t < WINTER_SPIN.y:
		s._spin_hits(3.6, WINTER_EVERY, WINTER_DAMAGE, 99.0, 0.0, WINTER_SPIN.x)
	if s._once("glint", WINTER_CRASH - 0.12):
		Net.fx("glint", [s._blade_tip(), s._col(FX.CORE), 1.3])
		Net.fx("glint", [s._blade_tip(true), s._col(FX.CORE), 1.3])
	if s._once("crash", WINTER_CRASH):
		var at: Vector3 = p.global_position + s._dir * 1.2
		var elem: bool = s._elem()
		for e in s._pc.enemies_in(p.global_position + Vector3(0, 0.9, 0), WINTER_R):
			var hd: HitData = s._hd(WINTER_FINAL, 12.0, true)
			hd.breaker = true
			s._strike(e, hd)
		Net.fx("twin_cross", [at + Vector3(0, 0.12, 0), s._dir, 1.6, s._col(), s._col(FX.ACCENT) if elem else s._col(FX.CORE), 0.45, true])
		Net.fx("ring", [at, Vector3.UP, WINTER_R, s._col(), 0.45, 0.1])
		Net.fx("ring", [at, Vector3.UP, WINTER_R * 0.55, s._col(FX.CORE), 0.3, 0.18])
		Net.fx("dust_ring", [at, 20, 1.3])
		for k in 4:
			Net.fx("ground_crack", [at, s._dir.rotated(Vector3.UP, TAU * k / 4.0 + PI * 0.25 + randf_range(-0.2, 0.2)), WINTER_R * 0.8,
				s._col(FX.ACCENT) if elem else Color(0, 0, 0, 0), randi() % 10000, 0.16])
		var c: Color = s._col(FX.CORE)
		Net.fx("screen_flash", [p.global_position, Color(c.r, c.g, c.b, 0.35), 0.25])
		Net.fx("sfx", ["chop", at, 2.0, 0.05, 0.6])
		Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.6])
		if elem:
			Net.fx("rock_spikes", [at, WINTER_R * 0.75, 12, randi() % 10000, 1.6, 1.2, true])
			for e in s._victims:
				if is_instance_valid(e):
					Net.fx("rock_spikes", [(e as Node3D).global_position, 0.6, 4, randi() % 10000, 1.2, 0.9, true])
			Net.fx("element", ["dual_axe", at + Vector3(0, 0.5, 0), Vector3.UP, 16, 5.0])
		else:
			Net.fx("debris", [at + Vector3(0, 0.2, 0), Vector3.UP, 12, Color(0.35, 0.3, 0.25), 6.0])
		p.squash(-5.0)
		CombatManager.apply_hitstop(0.12, [p])
		CombatManager.apply_camera_shake(0.42)
		CombatManager.apply_camera_kick(0.2, 0.4)
		p.hurtbox.set_deferred("monitorable", true)
