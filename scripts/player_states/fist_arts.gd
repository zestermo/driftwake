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
