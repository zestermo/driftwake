class_name Splat
extends Node
## (1.30, docs/v1_30_plan.md "round 4") Overkill launches and wall splats. A killing blow that overkills a foe by a
## margin, or a strong blow that overkills it a little, throws the body flat: back along a forward blow, up for a
## launcher. A wall or ceiling within REACH (~26 ft): it flies flat into it, leaves an impact mark (FX.splat), sticks
## STICK s and drops limp. Nothing near: a back throw lands (a small mark) and skids, a launch goes up and falls
## back to a small mark. Whoever simulates the body flies it (kinematic parts, Ragdoll.hold); the other screens'
## copies follow its snapshot and get the marks through Net.fx. Raycasts only when thrown and under a skid.

## Overkill (damage past the health left) that throws anything, as a share of its max health (plan: assumed 50%).
const OVERKILL_K := 0.5
## A strong blow (a heavy, a knockdown, a launcher, a technique or ultimate) throws with only this much (tuned: 15%).
const STRONG_K := 0.15
const CAPTAIN_K := 0.3
const DUEL_K := 0.2
## A captain let go: the muscles barely brace (dazed).
const DAZED_BRACE := 0.3
const REACH := 8.0
const SPEED := 21.0
const STICK := 1.0
const SKID := 2.4
const SKID_SECS := 0.5
const LAND_AHEAD := 2.6
const UP_SPEED := 10.5
## Bodies bigger than this (the rig's scale) don't fly.
const MAX_SCALE := 1.6

enum Phase {FLY, STICK, SKID, AIR}

var rag: Ragdoll
var kind := ""
var blood := true
var phase := Phase.FLY
var n := Vector3.UP
var _d := Vector3.FORWARD
var _rels: Array = []
var _p0: Transform3D
var _p1: Transform3D
var _q0: Quaternion
var _q1: Quaternion
var _at := Vector3.ZERO
var _t := 0.0
var _dur := 0.2
var _arc := 0.0
var _k := 1.0
var _skid_to := Vector3.ZERO
var _dust_t := 0.0
var _vy := 0.0
var _seed := 0


## A killing blow worth a throw: `hp_before` is the health it had left.
static func wants(hit: HitData, hp_before: float, max_hp: float) -> bool:
	if hit == null or hit.dot:
		return false
	var over := hit.damage - hp_before
	if over < 0.0:
		return false
	var k := Levels.gap_splat(hit.gap)
	if over >= max_hp * OVERKILL_K * k:
		return true
	return strong(hit) and not hit.ranged and over >= max_hp * STRONG_K * k


## A blow that broke a captain's poise and throws them flat: a strong one (not a shot) taking CAPTAIN_K of their max
## health (plan: assumed 30%), or DUEL_K from another captain (duel blows land at Duel.DAMAGE_K; tuned). The level gap
## from the attacker's side: a foe above the captain throws them with less.
static func flattens(hit: HitData, dmg: float, max_hp: float, attacker: Node) -> bool:
	if hit.ranged or hit.dot or not strong(hit):
		return false
	var by_captain := attacker != null and attacker.is_in_group("players")
	var k := Levels.gap_splat(hit.gap if Levels.captain(attacker) else -hit.gap)
	return dmg >= max_hp * (DUEL_K if by_captain else CAPTAIN_K) * k


static func strong(hit: HitData) -> bool:
	return hit.knockdown or hit.launch > 0.0 or Poise.of(hit) >= Poise.HEAVY


## A humanoid killed by `hit`: spread out, ragdolled and thrown. False (nothing done) when it isn't one.
static func kill(h: Humanoid, hit: HitData, hp_before: float, max_hp: float, dir: Vector3, bleeds: bool) -> bool:
	if h.ragdoll != null or h.scale.y > MAX_SCALE or not wants(hit, hp_before, max_hp):
		return false
	throw_body(h, dir, hit.launch > 0.0, bleeds, false)
	return true


## Throw `h` (whoever simulates it): spread, ragdolled (`alive`: braced, a captain who'll get up) and flown.
static func throw_body(h: Humanoid, dir: Vector3, up: bool, bleeds: bool, alive: bool) -> Splat:
	spread(h)
	var r := h.start_ragdoll(Vector3.ZERO, Vector3.ZERO, alive)
	var s := Splat.new()
	s.name = "Splat"
	s.rag = r
	s.blood = bleeds
	s._k = h.scale.y
	r.add_child(s)
	s._begin(dir, up)
	return s


## Arms and legs flung out: the shape that hits the wall.
static func spread(h: Humanoid) -> void:
	h.pivot.rotation = Vector3.ZERO
	h.hips.rotation = Vector3.ZERO
	h.torso.rotation = Vector3(-0.1, 0, 0)
	(h.neck if h.neck else h.head).rotation = Vector3(0.2, 0, 0)
	h.arm_l.rotation = Vector3(0.45, 0, -1.25)
	h.arm_r.rotation = Vector3(0.45, 0, 1.25)
	h.fore_l.rotation = Vector3(0.3, 0, 0)
	h.fore_r.rotation = Vector3(0.3, 0, 0)
	h.leg_l.rotation = Vector3(0.08, 0, -0.32)
	h.leg_r.rotation = Vector3(0.08, 0, 0.32)
	h.shin_l.rotation = Vector3(-0.2, 0, 0)
	h.shin_r.rotation = Vector3(-0.2, 0, 0)


func _begin(dir: Vector3, up: bool) -> void:
	_d = Vector3(dir.x, 0.0, dir.z).normalized()
	var root := rag.root_body()
	_p0 = root.global_transform
	_q0 = _p0.basis.orthonormalized().get_rotation_quaternion()
	for p in rag.parts:
		_rels.append(_p0.affine_inverse() * (p["body"] as RigidBody3D).global_transform)
	_seed = int(absf(_p0.origin.x * 73.0 + _p0.origin.z * 131.0)) % 9973
	var chest := _p0.origin + Vector3.UP * 0.35 * _k
	Net.fx("splat_launch", [chest, Vector3.UP if up else _d, _k])
	var hit := _find(chest, up)
	if not hit.is_empty():
		_to_surface(hit)
	elif up:
		_to_air(Vector3.UP * UP_SPEED + _d * 2.0)
	else:
		_to_ground(chest)


## The nearest wall (or, thrown up, ceiling) the body would fly into within REACH; empty when none.
func _find(from: Vector3, up: bool) -> Dictionary:
	var dirs: Array = []
	if up:
		dirs = [Vector3.UP, (Vector3.UP + _d * 0.5).normalized(), (Vector3.UP + _d * 1.2).normalized()]
	else:
		for a in [0.0, 0.35, -0.35, 0.7, -0.7]:
			dirs.append((_d.rotated(Vector3.UP, a) + Vector3.UP * 0.12).normalized())
	var space := rag.get_world_3d().direct_space_state
	var best := {}
	var best_score := INF
	for i in dirs.size():
		var v: Vector3 = dirs[i]
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + v * REACH, 1))
		if h.is_empty():
			continue
		var hn: Vector3 = h["normal"]
		var ceiling: bool = hn.y < -0.4
		if not ceiling and (absf(hn.y) > 0.6 or hn.dot(-v) < 0.2):
			continue
		if ceiling and not up:
			continue
		var dist := from.distance_to(h["position"])
		var score := dist * (1.0 + 0.2 * i)
		if score < best_score:
			best_score = score
			best = {"at": h["position"], "n": hn, "v": v}
	return best


func _to_surface(hit: Dictionary) -> void:
	n = (hit["n"] as Vector3).normalized()
	kind = "ceiling" if n.y < -0.4 else "wall"
	var u: Vector3
	if kind == "wall":
		u = (Vector3.UP - n * n.y).normalized().rotated(n, (float(_seed % 100) / 100.0 - 0.5) * 0.7)
	else:
		var f: Vector3 = hit["v"]
		u = Vector3(f.x, 0.0, f.z) if Vector2(f.x, f.z).length() > 0.1 else _d
		u = (u - n * u.dot(n)).normalized()
	_at = hit["at"]
	_aim(_flat_on(_at, u), u)
	_dur = clampf(_p0.origin.distance_to(_p1.origin) / SPEED, 0.08, 0.42)
	rag.hold(true)


## The pelvis lying flat on a surface at `at` (normal `n`), the head along `u`, the face out.
func _flat_on(at: Vector3, u: Vector3) -> Vector3:
	return at + n * 0.16 * _k - u * 0.32 * _k


func _aim(origin: Vector3, u: Vector3) -> void:
	var z := -n
	var x := u.cross(z).normalized()
	_p1 = Transform3D(Basis(x, x.cross(z) * -1.0, z).orthonormalized(), origin)
	_q1 = _p1.basis.get_rotation_quaternion()


## Nothing behind it: down on its back a little way off, then a skid.
func _to_ground(chest: Vector3) -> void:
	var space := rag.get_world_3d().direct_space_state
	var ahead := chest + _d * LAND_AHEAD
	var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * 8.0, 1))
	var water := float(get_node("/root/Ocean").call("surface_at", ahead))
	if g.is_empty() or water > (g["position"] as Vector3).y:
		_to_air(_d * 9.0 + Vector3.UP * 3.0)
		return
	kind = "skid"
	n = (g["normal"] as Vector3).normalized()
	_at = g["position"]
	_aim(_at + n * 0.14 * _k, _d)
	_dur = 0.2
	_arc = 0.5
	var low := _at + n * 0.3
	var run := SKID * (0.8 + 0.4 * float(_seed % 50) / 50.0)
	var block := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + _d * (run + 0.4), 1))
	if not block.is_empty():
		run = maxf(low.distance_to(block["position"]) - 0.5, 0.0)
	_skid_to = _p1.origin + _d * run
	rag.hold(true)


## Thrown loose (up with no ceiling, or off an edge): the ragdoll flies, and lands on a small mark.
func _to_air(v: Vector3) -> void:
	kind = "fall"
	phase = Phase.AIR
	rag.stiffness_target = minf(rag.stiffness_target, DAZED_BRACE)
	for p in rag.parts:
		var b: RigidBody3D = p["body"]
		b.linear_velocity = v
		b.angular_velocity = Vector3.UP.cross(_d) * 4.0


func _pose(xf: Transform3D) -> void:
	for i in rag.parts.size():
		(rag.parts[i]["body"] as RigidBody3D).global_transform = xf * (_rels[i] as Transform3D)


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.FLY:
			var k := minf(_t / _dur, 1.0)
			var at := _p0.origin.lerp(_p1.origin, k) + Vector3.UP * _arc * sin(PI * k)
			var r := minf(k / 0.6, 1.0)
			_pose(Transform3D(Basis(_q0.slerp(_q1, 1.0 - (1.0 - r) * (1.0 - r))), at))
			if k >= 1.0:
				_contact()
		Phase.STICK:
			var k := minf(_t / STICK, 1.0)
			var slide := Vector3.ZERO
			if kind == "wall":
				slide = (Vector3.DOWN - n * n.dot(Vector3.DOWN)).normalized() * 0.18 * k * k
			_pose(Transform3D(_p1.basis, _p1.origin + slide))
			if k >= 1.0:
				_release(n * 1.4 + Vector3.DOWN * 0.6 if kind == "wall" else Vector3.DOWN)
		Phase.SKID:
			var k := minf(_t / SKID_SECS, 1.0)
			var at := _p1.origin.lerp(_skid_to, 1.0 - (1.0 - k) * (1.0 - k))
			var g := rag.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 1.5, 1))
			if not g.is_empty():
				at.y = (g["position"] as Vector3).y + 0.14 * _k
			_pose(Transform3D(_p1.basis, at))
			_dust_t -= delta
			if _dust_t <= 0.0 and k < 0.85:
				_dust_t = 0.1
				Net.fx("dust", [at - Vector3.UP * 0.1, 4, 0.6])
			if k >= 1.0:
				_release(_d * 1.2)
		Phase.AIR:
			var rb := rag.root_body()
			var vy := rb.linear_velocity.y
			if _t > 0.25 and _vy < -3.0 and vy - _vy > 3.0:
				if rag.root_depth() < -0.3:
					Net.fx("splat", [rb.global_position - Vector3.UP * 0.12 * _k, Vector3.UP, 0.5, blood, _seed])
				queue_free()
				return
			_vy = vy
			if _t > 4.0 or rag.in_water:
				queue_free()


func _contact() -> void:
	_t = 0.0
	if kind == "skid":
		phase = Phase.SKID
		Net.fx("splat", [_at, n, 0.45, blood, _seed])
		Net.fx("sfx", ["thud", _at, -2.0, 0.1, 0.8])
		return
	phase = Phase.STICK
	Net.fx("splat", [_at, n, 1.2, blood, _seed])


func _release(v: Vector3) -> void:
	rag.hold(false)
	rag.stiffness_target = minf(rag.stiffness_target, DAZED_BRACE)
	for p in rag.parts:
		var b: RigidBody3D = p["body"]
		b.linear_velocity = v
		b.angular_velocity = Vector3.ZERO
	queue_free()
