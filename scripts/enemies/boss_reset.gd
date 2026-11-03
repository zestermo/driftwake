class_name BossReset
extends RefCounted
## (1.30, docs/v1_30_plan.md "Boss phases") A boss's new phase starts over from its arena's middle: it crouches (WIND),
## leaps there (AIR), lands with a shockwave that throws every captain within SHOCK_R out (SHOCK_DMG, judged on each
## captain's own machine: the boss's "reset_shock" event) and roars for ROAR_S. Nothing hurts it from the crouch to the
## roar's end; then the new phase's moves. The host runs it (tick); guests see the boss's snapshots and the effects.

const WIND := 0.4
const AIR := 0.85
const ROAR_S := 1.5
const LEAP_H := 4.5
const SHOCK_R := 9.0
const SHOCK_DMG := 6.0
## How fast the shockwave throws a captain out (m/s; the stagger slows it at 20 m/s^2: ~5.6 m).
const SHOCK_PUSH := 15.0
const COL := Color(1.0, 0.55, 0.25)

var boss: Node3D
## The node the shockwave's event goes out on (its net_event plays it elsewhere): the boss, or for an AI captain boss
## the node that holds it.
var events: Node3D
var t := -1.0
var from := Vector3.ZERO
var to := Vector3.ZERO
var _guard_fx := 0.0


func _init(b: Node3D, ev: Node3D = null) -> void:
	boss = b
	events = ev if ev != null else b


## Off to `centre` (a point on the arena's floor).
func start(centre: Vector3) -> BossReset:
	t = 0.0
	from = boss.global_position
	to = centre
	Net.fx("telegraph", [to, SHOCK_R, WIND + AIR, COL])
	Net.fx("sfx", ["whoosh_big", from, 0.0, 0.05, 0.6])
	return self


## The floor under `p` (the world's ground, layer 1), past the body `n` itself.
static func floor_at(n: CollisionObject3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 14.0, 1)
	q.exclude = [n.get_rid()]
	var hit := n.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func active() -> bool:
	return t >= 0.0


func stage() -> String:
	if t < 0.0:
		return ""
	if t < WIND:
		return "wind"
	return "air" if t < WIND + AIR else "roar"


func air_u() -> float:
	return clampf((t - WIND) / AIR, 0.0, 1.0)


## Advances it (host): what it moved into this tick ("" nothing new, "air", "land", "done"). In the air it moves the
## boss itself (no physics step then).
func tick(delta: float) -> String:
	var was := stage()
	t += delta
	if t >= WIND + AIR + ROAR_S:
		t = -1.0
		return "done"
	var s := stage()
	if s == "air":
		var u := air_u()
		var flat := from.lerp(to, u)
		boss.global_position = Vector3(flat.x, lerpf(from.y, to.y, u) + sin(u * PI) * LEAP_H, flat.z)
		boss.set("velocity", Vector3.ZERO)
	elif s == "roar" and was != "roar":
		boss.global_position = to
		boss.set("velocity", Vector3.ZERO)
		BossReset.shock(events, to, SHOCK_R, SHOCK_DMG, SHOCK_PUSH)
		Net.fx("sfx", ["roar", to, 6.0, 0.03, 0.85])
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


## The leap's pose on any beast's model (`on`: its move is "leap_home", `t` its clock): squat and nose-down in the
## crouch, stretched, nose-up rising and nose-down falling. Returns whether it posed (the model is put back once it stops).
static func pose_beast(m: Node3D, on: bool, t: float, was: bool) -> bool:
	if not on:
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
