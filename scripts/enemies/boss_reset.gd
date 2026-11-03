class_name BossReset
extends RefCounted
## (1.30, docs/v1_30_plan.md "Boss phases") A boss's new phase starts over from its arena's middle (start): it crouches
## (WIND), leaps there (AIR), lands with a shockwave that throws every captain within SHOCK_R out (SHOCK_DMG, judged on
## each captain's own machine: the "reset_shock" event) and roars for ROAR_S. Nothing hurts it from the crouch to the
## roar's end; then the new phase's moves.
## ("Boss space") A beast boss also makes space (clear): crowded (CROWD_S with captains within reach: two once two or
## more are fighting) or hit BURST_N times inside BURST_S, at most every CLEAR_CD, it rears up and roars a ring round
## itself (RING_WIND's tell, a bigger push: CLEAR_PUSH) or, pinned out past CLEAR_LEAP_D from the middle, leaps back
## there and lands with it. Blows still land through a clearing move.
## The host runs both (tick); guests see the boss's snapshots and the effects.

const WIND := 0.4
const AIR := 0.85
const ROAR_S := 1.5
const LEAP_H := 4.5
const SHOCK_R := 9.0
const SHOCK_DMG := 6.0
## How fast the shockwave throws a captain out (m/s; the stagger slows it at 20 m/s^2: ~5.6 m).
const SHOCK_PUSH := 15.0
const COL := Color(1.0, 0.55, 0.25)
const CROWD_R := 5.5
const CROWD_S := 4.0
const BURST_N := 8
const BURST_S := 3.0
const CLEAR_CD := 12.0
const CLEAR_LEAP_D := 8.0
const RING_WIND := 0.6
const CLEAR_ROAR := 0.6
const CLEAR_R := 8.0
const CLEAR_DMG := 4.0
const CLEAR_PUSH := 17.0

var boss: Node3D
## The node the shockwave's event goes out on (its net_event plays it elsewhere): the boss, or for an AI captain boss
## the node that holds it.
var events: Node3D
var t := -1.0
var from := Vector3.ZERO
var to := Vector3.ZERO
## This run's timings and shockwave (a phase reset's, a clearing leap's or ring's).
var wind := WIND
var air := AIR
var roar := ROAR_S
var guard := true
var _r := SHOCK_R
var _dmg := SHOCK_DMG
var _push := SHOCK_PUSH
var _guard_fx := 0.0
var _crowd := 0.0
var _hits: Array = []
var _cd := CLEAR_CD * 0.5


func _init(b: Node3D, ev: Node3D = null) -> void:
	boss = b
	events = ev if ev != null else b


## A new phase: off to `centre` (a point on the arena's floor), untouchable to the roar's end.
func start(centre: Vector3) -> BossReset:
	_run(centre, WIND, AIR, ROAR_S, true, SHOCK_R, SHOCK_DMG, SHOCK_PUSH)
	_cd = maxf(_cd, CLEAR_CD * 0.5)
	return self


## Making space: a leap back to `centre` when it's been pinned out past CLEAR_LEAP_D, a roar ring where it stands
## otherwise. Whether it leaps.
func clear(centre: Vector3) -> bool:
	_cd = CLEAR_CD
	_crowd = 0.0
	_hits.clear()
	var off := boss.global_position - centre
	var leap := Vector2(off.x, off.z).length() > CLEAR_LEAP_D
	if leap:
		_run(centre, WIND, AIR, CLEAR_ROAR, false, CLEAR_R, CLEAR_DMG, CLEAR_PUSH)
	else:
		_run(boss.global_position, RING_WIND, 0.0, CLEAR_ROAR, false, CLEAR_R, CLEAR_DMG, CLEAR_PUSH)
	return leap


func _run(at: Vector3, w: float, a: float, ro: float, g: bool, r: float, dmg: float, push: float) -> void:
	t = 0.0
	from = boss.global_position
	to = at
	wind = w
	air = a
	roar = ro
	guard = g
	_r = r
	_dmg = dmg
	_push = push
	Net.fx("telegraph", [to, r, w + a, COL])
	Net.fx("sfx", ["whoosh_big" if a > 0.0 else "peril", from, 0.0, 0.05, 0.6])


## The floor under `p` (the world's ground, layer 1), past the body `n` itself.
static func floor_at(n: CollisionObject3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 14.0, 1)
	q.exclude = [n.get_rid()]
	var hit := n.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func active() -> bool:
	return t >= 0.0


## Untouchable now (a phase reset under way).
func guarding() -> bool:
	return t >= 0.0 and guard


func stage() -> String:
	if t < 0.0:
		return ""
	if t < wind:
		return "wind"
	return "air" if t < wind + air else "roar"


func air_u() -> float:
	return clampf((t - wind) / maxf(air, 0.01), 0.0, 1.0)


## Advances it (host): what it moved into this tick ("" nothing new, "air", "land", "done"). In the air it moves the
## boss itself (no physics step then).
func tick(delta: float) -> String:
	var was := stage()
	t += delta
	if t >= wind + air + roar:
		t = -1.0
		return "done"
	var s := stage()
	if s == "air":
		var u := air_u()
		var flat := from.lerp(to, u)
		boss.global_position = Vector3(flat.x, lerpf(from.y, to.y, u) + sin(u * PI) * LEAP_H, flat.z)
		boss.set("velocity", Vector3.ZERO)
	elif s == "roar" and was != "roar":
		if air > 0.0:
			boss.global_position = to
		boss.set("velocity", Vector3.ZERO)
		BossReset.shock(events, to, _r, _dmg, _push)
		Net.fx("sfx", ["roar", to, 6.0 if guard else 3.0, 0.03, 0.85 if guard else 1.0])
		return "land"
	return s if s != was else ""


func stop() -> void:
	t = -1.0


## A blow on it while it's untouchable: it glances off (sparks now and then, not every hit).
func deflect(at: Vector3) -> void:
	var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	if now < _guard_fx:
		return
	_guard_fx = now + 0.25
	Net.fx("sparkle", [at, 10, Color(1.0, 0.95, 0.8)])
	Net.fx("sfx", ["parry", at, -4.0, 0.08, 0.7])


## A blow landed on it (for the burst that sets off a clearing move).
func hit() -> void:
	_hits.append(Engine.get_physics_frames())


## (host, every tick of the fight) Whether it's crowded enough, or hit fast enough, to make space now. `reach`: how near
## counts as crowding it.
func crowded(delta: float, reach: float = CROWD_R) -> bool:
	_cd -= delta
	var near := 0
	var fighting := 0
	for p in Net.all_players():
		if not (p.has_method("is_standing") and p.is_standing()):
			continue
		fighting += 1
		var off: Vector3 = (p as Node3D).global_position - boss.global_position
		if Vector2(off.x, off.z).length() < reach:
			near += 1
	_crowd = _crowd + delta if near >= mini(fighting, 2) and near > 0 else maxf(_crowd - delta * 2.0, 0.0)
	var since := Engine.get_physics_frames() - int(BURST_S * Engine.physics_ticks_per_second)
	while not _hits.is_empty() and int(_hits[0]) < since:
		_hits.pop_front()
	return _cd <= 0.0 and (_crowd >= CROWD_S or _hits.size() >= BURST_N)


## The leap's pose on any beast's model (its move "leap_home", or "clear_ring" rearing for the ring; `t` its clock):
## squat and nose-down in the crouch, stretched, nose-up rising and nose-down falling; reared up for the ring. Returns
## whether it posed (the model is put back once it stops). `roars`: a kind with no pose of its own for the roar after
## the landing (move "moment") rears up trembling.
static func pose_beast(m: Node3D, mv: String, t: float, was: bool, roars: bool) -> bool:
	if mv == "moment" and roars:
		m.scale = Vector3(1.0, 1.05, 1.0)
		m.rotation.x = 0.3 + sin(t * 40.0) * 0.025
		return true
	if mv == "clear_ring":
		var k := clampf(t / RING_WIND, 0.0, 1.0)
		m.scale = Vector3(1.0, 1.0 + 0.08 * k, 1.0)
		m.rotation.x = 0.4 * k * k
		return true
	if mv != "leap_home":
		if was:
			m.scale = Vector3.ONE
			m.rotation.x = 0.0
		return false
	if t < WIND:
		var k := t / WIND
		m.scale = Vector3(1.0 + 0.08 * k, 1.0 - 0.2 * k, 1.0 + 0.08 * k)
		m.rotation.x = -0.15 * k
	else:
		var u := clampf((t - WIND) / AIR, 0.0, 1.0)
		m.scale = Vector3(0.94, 1.12, 1.06)
		m.rotation.x = lerpf(0.5, -0.45, u)
	return true


## A ring out from `at` (r m) that throws every captain in it outward at `push` m/s and hurts `dmg`, on every screen:
## each machine judges its own captain (and shows the rings and dust).
static func shock(b: Node, at: Vector3, r: float, dmg: float, push: float) -> void:
	shock_local(b, at, r, dmg, push)
	b.get_node("/root/Net").event(b, "reset_shock", [at, r, dmg, push])


static func shock_local(b: Node, at: Vector3, r: float, dmg: float, push: float) -> void:
	BeastFX.moment(at, r / 10.0, COL)
	b.get_node("/root/FX").sfx("thud", at, 6.0, 0.05, 0.55)
	var me := b.get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var off := me.global_position - at
	off.y = 0.0
	if off.length() > r or me.global_position.y > at.y + 2.5:
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable or str(me.call("current_state_name")) in ["Downed", "Swim", "Helm", "Grabbed"]:
		return
	var hp := me.get_node("HealthComponent") as HealthComponent
	var was := hp.current_health
	var hd := HitData.new()
	hd.damage = dmg
	hd.unblockable = true
	hd.knockback_force = 0.0
	hd.stagger_duration = 0.2
	hd.hitstop_duration = 0.05
	hd.camera_shake_intensity = 0.3
	hb.take_hit(hd, b)
	if hp.current_health >= was or hp.current_health <= 0.0:
		return
	var dir := off.normalized() if off.length() > 0.3 else -(b as Node3D).global_basis.z
	me.call("shoved", dir * push)
