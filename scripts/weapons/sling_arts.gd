class_name SlingArts
## The slingshot (style "slingshot", tree "slingshot": the trickster's spark - hot-pink and tangerine sparks, the tricks
## bursting in bright colours). Light and quick: left click draws and lets a stone fly at the reticle (Shell "pellet",
## no reload), right click is the power draw (held: it charges in two levels, let go for a heavy stone that knocks them
## back, at full draw down: HeavyAttackState "power_draw" through heavy_enter / heavy_update). Its identity is the trick
## ammo, each a technique: Fire Pellet, Smoke Pellet, Blast Pellet, Sticky Pellet, and Bag of Tricks (ult); Trick Pouch
## puts a trick in every fifth stone. Skid Shot at a sprint, Hail Shot in the air. A round's trick is its `extra`
## ("fire", "smoke", "blast", "sticky", with "@k" its strength), worked out where it lands (shell_hit).

const RANGE := 40.0
const SPEED := 46.0
const GRAVITY := 7.0
const DAMAGE := 9.0
## A stone's draw and loose: the move's length and when it flies (s, x the design's "speed").
const SHOT_LEN := 0.36
const RELEASE := 0.2
## The power draw: seconds to levels 1 and 2 (Quick Draw shortens them), each level's damage, the longest hold.
const DRAW_AT := [0.4, 0.9]
const DRAW_DAMAGE := [14.0, 24.0, 36.0]
const DRAW_MAX := 1.6
const DRAW_CREEP := 0.3
const POUCH_EVERY := 5
const TRICKS := ["fire", "smoke", "blast", "sticky"]
const TRICK_COL := {"": Color(0.55, 0.52, 0.48), "fire": Color(1.0, 0.45, 0.12), "smoke": Color(0.7, 0.7, 0.68),
	"blast": Color(0.18, 0.16, 0.16), "sticky": Color(0.2, 0.15, 0.08)}
const FXS := preload("res://scripts/game/fx.gd")


static func _net() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Net")


static func _elem(p: Player, tier: int = 1) -> bool:
	return p.progression.elemental("slingshot", tier)


static func _col(p: Player, which: int, tier: int = 1) -> Color:
	return FXS.tree_col("slingshot" if _elem(p, tier) else "plain", which)


## Where the stone leaves from: the pouch in the drawing hand, just behind the fork.
static func pouch(p: Player) -> Vector3:
	return p.body_model.hand_l.global_position


static func _speed(p: Player) -> float:
	return GunKinds.design(p.equipped_weapon, "speed")


## How strong the slingshot's tricks are (its design, the tree).
static func trick_k(p: Player) -> float:
	return GunKinds.design(p.equipped_weapon, "trick") * (1.0 + p.progression.style_stat("trick", "slingshot"))


## A stone let fly at the reticle (or `to`), `spread` rad off the line.
static func loose(p: Player, kind: String, base: float, trick := "", to := Vector3.INF, spread := 0.0) -> void:
	var from := pouch(p)
	var at := GunKinds.aim_point(p, from, RANGE, 0.08) if to == Vector3.INF else to
	var v := Shell.aim_v(from, at, SPEED, GRAVITY)
	if spread != 0.0:
		v = v.rotated(Vector3.UP, spread)
	Shell.launch(p.get_tree(), kind, from, v, p, base, trick)
	var dir := v.normalized()
	var col := _col(p, FXS.EDGE, 2) if _elem(p, 2) else Color(1.0, 0.95, 0.85)
	_net().fx("ring", [from + dir * 0.3, dir, 0.4 if kind == "pellet" else 0.8, col, 0.14, 0.12])
	if _elem(p, 2):
		_net().fx("element", ["slingshot", from + dir * 0.3, dir, 4, 4.0])
	_net().fx("sfx", ["whoosh", from, -8.0 if kind == "pellet" else -3.0, 0.1, 1.7 if kind == "pellet" else 1.3])
	_net().fx("sfx", ["slap", from, -12.0, 0.1, 1.6])


# --------------------------------------------------------------------------
# The stone (ShootState)
# --------------------------------------------------------------------------
static func shoot_enter(s) -> void:
	var p: Player = s.player
	s.steady = 0.0
	s.face_direction(s.get_camera_forward(), 1.0)
	if p.sprinting and p.progression.has_move("skid_shot"):
		s.mode = "skid"
		s.dur = ActionSpecs.length("sl_skid")
		p.body_model.play("sl_skid", s.dur)
		_net().fx("dust", [p.global_position, 6, 0.5])
		return
	s.mode = "shot"
	s.dur = SHOT_LEN / _speed(p)
	LongGunArts._pitch(p)
	p.body_model.play("sl_shot", s.dur)


static func shoot_update(s, delta: float) -> void:
	var p: Player = s.player
	s.timer += delta
	match s.mode:
		"shot":
			LongGunArts._walk(s, delta, 0.7)
			s.face_camera(delta)
			LongGunArts._pitch(p)
			if s.steady < 1.0 and s.timer >= RELEASE / _speed(p):
				s.steady = 1.0
				loose(p, "pellet", DAMAGE, _pouch_trick(p))
		"skid":
			_skid_update(s, delta)
	if s.timer >= s.dur:
		LongGunArts._done(s)


static func shoot_exit(_s) -> void:
	pass


## Trick Pouch: every fifth stone carries a trick at half strength.
static func _pouch_trick(p: Player) -> String:
	if p.progression.style_stat("pouch", "slingshot") <= 0.0:
		return ""
	var n := int(p.get_meta("sling_n", 0)) + 1
	p.set_meta("sling_n", n % POUCH_EVERY)
	if n < POUCH_EVERY:
		return ""
	return "%s@%.2f" % [TRICKS[randi() % TRICKS.size()], 0.5]


# --------------------------------------------------------------------------
# Skid Shot (attacked at a sprint): down into a slide, three stones fanned out ahead
# --------------------------------------------------------------------------
const SKID_SPEED := 10.0
const SKID_AT := 0.22
const SKID_FAN := 0.12


static func _skid_update(s, delta: float) -> void:
	var p: Player = s.player
	var f: Vector3 = -p.player_model.global_basis.z
	s.apply_gravity(delta)
	var spd := SKID_SPEED * clampf(1.0 - s.timer / s.dur, 0.0, 1.0)
	p.velocity.x = f.x * spd
	p.velocity.z = f.z * spd
	p.move_and_slide()
	if s.steady < 1.0 and s.timer >= SKID_AT:
		s.steady = 1.0
		for a in [-SKID_FAN, 0.0, SKID_FAN]:
			loose(p, "pellet", DAMAGE, "", Vector3.INF, a)
		_net().fx("dust", [p.global_position, 8, 0.6])


# --------------------------------------------------------------------------
# The power draw (HeavyAttackState, cfg "arts"): held, drawn back to the ear in two levels; let go, the heavy stone
# --------------------------------------------------------------------------
static func heavy_enter(s) -> void:
	var p: Player = s.player
	s._charging = true
	s._level = 0
	s._charge_t = 0.0
	s.timer = 0.0
	LongGunArts._pitch(p)
	p.body_model.hold("sl_draw", 0.18)
	_net().fx("sfx", ["rope", p.global_position, -14.0, 0.05, 1.6])


static func heavy_update(s, delta: float) -> void:
	var p: Player = s.player
	s.apply_gravity(delta)
	if not s._charging:
		s.timer += delta
		p.velocity.x = move_toward(p.velocity.x, 0.0, 20.0 * delta)
		p.velocity.z = move_toward(p.velocity.z, 0.0, 20.0 * delta)
		p.move_and_slide()
		if s.timer >= 0.35:
			s.transitioned.emit(s, "Idle", {})
		return
	var mi: Vector2 = s.get_movement_input()
	var want: Vector3 = s.get_camera_relative_direction(mi) * p.move_speed * DRAW_CREEP if mi.length() > 0.1 else Vector3.ZERO
	p.velocity.x = move_toward(p.velocity.x, want.x, 30.0 * delta)
	p.velocity.z = move_toward(p.velocity.z, want.z, 30.0 * delta)
	p.move_and_slide()
	s.face_camera(delta)
	LongGunArts._pitch(p)
	s._charge_t += delta
	var k := 1.0 - p.progression.style_stat("draw", "slingshot")
	while s._level < DRAW_AT.size() and s._charge_t >= float(DRAW_AT[s._level]) * k:
		s._level += 1
		var at := pouch(p)
		_net().fx("glint", [at, _col(p, FXS.CORE), 0.5 + 0.25 * s._level])
		_net().fx("sfx", ["rope", at, -10.0, 0.0, 1.2 + 0.2 * s._level])
		if s._level == 2:
			_net().fx("ring", [p.global_position, Vector3.UP, 1.6, _col(p, FXS.EDGE), 0.3, 0.1])
		p.squash(0.8 * s._level)
	if s.wants_dodge():
		p.body_model.stop_action()
		s.transitioned.emit(s, "Dodge", {})
		return
	if not p.inp.pressed("heavy_attack") or s._charge_t >= DRAW_MAX:
		s._charging = false
		s.timer = 0.0
		loose(p, "pellet_big", float(DRAW_DAMAGE[s._level]), str(s._level))
		p.body_model.play("sl_release", 0.35)
		p.cam_kick(0.06 + 0.04 * s._level, 0.2)


# --------------------------------------------------------------------------
# Where a stone lands (Shell, on the shooter's machine), and its trick
# --------------------------------------------------------------------------
static func shell_hit(sh: Shell, at: Vector3, normal: Vector3, hb: Hurtbox) -> void:
	var p := sh.source as Player
	var trick := sh.extra
	if sh.kind == "pellet_big":
		var lv := int(sh.extra)
		trick = ""
		if hb:
			var hd := GunKinds.shot_hit(p, sh.damage, "heavy")
			hd.knockdown = lv >= 2
			hd.knockback_force = 6.0 + 4.0 * lv
			hd.stagger_duration = 0.5 + 0.2 * lv
			hd.hitstop_duration = 0.04 + 0.03 * lv
			hd.camera_shake_intensity = 0.05 * lv
			hd.poise = Poise.SHOT_CLOSE * (1.0 + lv)
			GunKinds.strike(p, hb, hd)
			_net().fx("ring", [at, normal, 0.8 + 0.3 * lv, _col(p, FXS.EDGE, 2), 0.2, 0.14])
	elif hb:
		var hd := GunKinds.shot_hit(p, sh.damage, "skill" if trick != "" and not trick.contains("@0.5") else "")
		hd.knockback_force = 2.0
		hd.stagger_duration = 0.25
		hd.hitstop_duration = 0.02
		hd.camera_shake_intensity = 0.0
		hd.poise = Poise.SHOT
		GunKinds.strike(p, hb, hd)
	if hb:
		_net().fx("impact", [at, _col(p, FXS.ACCENT) if _elem(p, 2) else Color(1.0, 0.9, 0.7)])
		if _elem(p, 2):
			_net().fx("elem_hit", ["slingshot", at, normal])
	else:
		_net().fx("dust", [at, 3, 0.35])
	if trick != "":
		var parts := trick.split("@")
		burst(p, parts[0], at, (float(parts[1]) if parts.size() > 1 else 1.0) * trick_k(p))


## A trick going off at `at`, `k` its strength.
static func burst(p: Player, trick: String, at: Vector3, k: float) -> void:
	var pc := p.power
	match trick:
		"fire":
			var hd := GunKinds.shot_hit(p, 10.0 * k, "skill")
			hd.stagger_duration = 0.4
			hd.knockback_force = 3.0
			for e in GunKinds.splash(p, at, 2.2 * k, hd, 0.7):
				if is_instance_valid(e):
					BurnStatus.apply(e as Node3D, 4.0, 6.0 * k, p)
			_net().fx("blast", [at, Vector3.UP, 0.6 * k, true, Color(0.4, 0.38, 0.37, 0.8), 3.0])
			_net().fx("fire_ring", [at, 2.2 * k, int(18 * k)])
			_net().fx("sfx", ["fire_burst", at, -4.0, 0.08, 1.2])
		"smoke":
			var r := 4.0 * k
			for e in pc.enemies_in(at + Vector3(0, 0.9, 0), r):
				var hd := HitData.new()
				hd.damage = 1.0
				hd.stagger_duration = 2.0 * k
				hd.knockback_force = 0.5
				hd.unblockable = true
				hd.ranged = true
				((e as Node).get("hurtbox") as Hurtbox).take_hit(hd, p)
				_net().fx("float_text", [(e as Node3D).global_position + Vector3(0, 2.2, 0), "Blinded", Color(0.85, 0.85, 0.8)])
			for i in 8:
				var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 0.8), randf_range(-1.0, 1.0)) * r * 0.5
				_net().fx("smoke", [at + off, 5, 1.4 * k, 3.0])
			_net().fx("sfx", ["thud", at, -6.0, 0.05, 1.5])
			if p.global_position.distance_to(at) <= r:
				p.vanish(2.0)
		"blast":
			var hd := GunKinds.shot_hit(p, 20.0 * k, "skill")
			hd.knockdown = true
			hd.knockback_force = 10.0
			hd.stagger_duration = 0.6
			hd.poise = Poise.HEAVY
			GunKinds.splash(p, at, 2.6 * k, hd, 0.5)
			_net().fx("cannon_blast", [at, 0.55 * k, _col(p, FXS.ACCENT) if _elem(p) else Color(0, 0, 0, 0)])
			_net().fx("sfx", ["cannon_hit", at, -4.0, 0.08, 1.5])
			p.cam_shake(clampf(0.3 - p.global_position.distance_to(at) * 0.02, 0.0, 0.25))
		"sticky":
			var r := 3.0 * k
			for e in pc.enemies_in(at + Vector3(0, 0.6, 0), r):
				var hd := HitData.new()
				hd.damage = roundf(4.0 * k)
				hd.stagger_duration = 0.5
				hd.knockback_force = 0.0
				hd.ranged = true
				((e as Node).get("hurtbox") as Hurtbox).take_hit(hd, p)
				pc.root_enemy(e as Node3D, 3.0 * k)
				_net().fx("float_text", [(e as Node3D).global_position + Vector3(0, 2.2, 0), "Stuck!", Color(0.9, 0.75, 0.4)])
			_net().fx("ring", [at, Vector3.UP, r, Color(0.25, 0.18, 0.1, 1.0), 0.5, 0.2])
			_net().fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, Color(0.16, 0.12, 0.07), 3.0])
			_net().fx("sfx", ["splash", at, -6.0, 0.05, 0.6])
	if _elem(p):
		_net().fx("element", ["slingshot", at + Vector3(0, 0.5, 0), Vector3.UP, 10, 4.0])


# --------------------------------------------------------------------------
# Hail Shot (attacked in the air): hang a beat, three stones fanned down at the reticle
# --------------------------------------------------------------------------
const HAIL_AT := 0.28
const HAIL_LEN := 0.6
const HAIL_FAN := 0.14


static func air_enter(s) -> void:
	var p: Player = s.player
	p.variable_jump_active = false
	p.velocity = Vector3(p.velocity.x * 0.3, maxf(p.velocity.y, 0.0) * 0.2, p.velocity.z * 0.3)
	LongGunArts._pitch(p)
	p.body_model.play("sl_air", HAIL_LEN)


static func air_update(s, delta: float) -> void:
	var p: Player = s.player
	if not s._fired:
		p.velocity.y = move_toward(p.velocity.y, -0.6, 8.0 * delta)
		s.face_direction(s.get_camera_forward(), 1.0)
		LongGunArts._pitch(p)
		if s.timer >= HAIL_AT:
			s._fired = true
			var to := GunKinds.aim_point(p, pouch(p), RANGE, LongGunArts.SKY_ASSIST)
			for a in [-HAIL_FAN, 0.0, HAIL_FAN]:
				loose(p, "pellet", DAMAGE * 1.2, "", to, a)
	else:
		s.apply_gravity(delta)
	p.move_and_slide()
	if s._fired and p.is_on_floor():
		s.transitioned.emit(s, "Idle", {})
	elif s.timer >= HAIL_LEN:
		s.transitioned.emit(s, "Fall", {})


# --------------------------------------------------------------------------
# The trick shots (TechniqueState `s`): one stone at the reticle loaded with its trick; Bag of Tricks (ult) a fan of
# five, a trick each, at double strength, at the foes ahead
# --------------------------------------------------------------------------
const TRICK_SHOT := {"fire_pellet": "fire", "smoke_pellet": "smoke", "blast_pellet": "blast", "sticky_pellet": "sticky"}
const TRICK_AT := 0.28
const TRICK_DAMAGE := 10.0
const BAG := ["fire", "sticky", "blast", "smoke", "fire"]
const BAG_REACH := 30.0
const BAG_FIRST := 0.45
const BAG_EVERY := 0.17
const BAG_K := 1.6


static func enter(s, id: String) -> bool:
	var p: Player = s.player
	if TRICK_SHOT.has(id):
		s.dur = 0.55
		LongGunArts._pitch(p)
		p.body_model.play("sl_shot", s.dur)
		return true
	if id == "bag_of_tricks":
		s._victims = s._closest(BAG_REACH, 99).filter(func(e): return s._flat_to(e).dot(s._dir) > 0.3).slice(0, BAG.size())
		s.dur = BAG_FIRST + BAG_EVERY * BAG.size() + 0.35
		p.hurtbox.set_deferred("monitorable", false)
		p.body_model.hold("sl_draw", 0.2)
		return true
	return false


static func update(s, delta: float) -> bool:
	var p: Player = s.player
	if TRICK_SHOT.has(s.id):
		s._rooted(delta, 0.2)
		s.face_direction(s.get_camera_forward(), delta)
		if s._once("loose", TRICK_AT):
			loose(p, "pellet", TRICK_DAMAGE, "%s@%.2f" % [TRICK_SHOT[s.id], 1.0])
			_net().fx("glint", [pouch(p), s._col(FXS.CORE), 0.6])
		return true
	if s.id == "bag_of_tricks":
		s._rooted(delta, 0.0)
		if s._once("moment", 0.2):
			s._moment(0.4, 0.4, 0.3, 0.2)
			_net().fx("sparkle", [pouch(p), 16, s._col(FXS.EDGE)])
		for i in BAG.size():
			if s._once("bag%d" % i, BAG_FIRST + BAG_EVERY * i):
				var to := Vector3.INF
				if not s._victims.is_empty():
					var e: Node3D = s._victims[i % s._victims.size()]
					if is_instance_valid(e):
						to = s._body_center(e)
						s.face_direction(s._flat_to(e), 1.0)
				p.body_model.play("sl_shot", BAG_EVERY + 0.05)
				loose(p, "pellet", TRICK_DAMAGE * BAG_K, "%s@%.2f" % [BAG[i], BAG_K], to, 0.0 if to != Vector3.INF else (i - 2) * 0.15)
		if s._once("open", s.dur - 0.2):
			p.hurtbox.set_deferred("monitorable", true)
		return true
	return false
