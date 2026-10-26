class_name BeastMotion
extends RefCounted
## The big beasts' shared motion layer (1.23 beast pass, docs/v1_23_previews.md section 6): what makes a heavy body
## read as heavy and alive on top of its keyed or procedural pose. Rig-free: each body ticks one, then lays the channels
## on its own joints after posing (the Silverback's Humanoid in JungleApe._post_pose, a quadruped in its _animate).
##   look    head yaw / pitch toward its target, clamped and lagging; `lock` in a wind-up (it fixes on you)
##   react   a blow's shove: a damped SpringLink the body leans with (x pitch back, y roll), the head snapping after it
##   reel    0..1: the stagger pose's weight (a poise break), eased in fast and out slow
##   breath  a slow heave, deeper and quicker each phase and after a big move
##   chains  secondary motion: SpringLink links (tails, manes, a necklace) swung by how the body moves and turns
## antic() shapes a move's anticipation and follow-through in time (gather, snap, overshoot and settle).
## Runs on every screen from what every screen has (state, phase, the nearest captain): nothing sent.

class SpringLink:
	var x := Vector2.ZERO
	var v := Vector2.ZERO
	var k := 90.0
	var c := 10.0

	func _init(stiff: float = 90.0, damp: float = 10.0) -> void:
		k = stiff
		c = damp

	## (sub-stepped: a long frame mustn't blow it up)
	func step(delta: float, force: Vector2) -> Vector2:
		var n := maxi(ceili(delta / 0.0167), 1)
		var h := delta / n
		for i in range(n):
			v += (force - x * k - v * c) * h
			x += v * h
		return x


class SwingChain:
	var links: Array = []
	var follow := 30.0
	var _pos := Vector3.INF
	var _vel := Vector3.ZERO
	var _yaw := INF

	func _init(n: int, stiff: float, damp: float, lag: float) -> void:
		for i in range(n):
			links.append(SpringLink.new(stiff, damp))
		follow = lag


var look := Vector2.ZERO
var react := Vector2.ZERO
var reel := 0.0
var breath := 0.0
var pant := 0.0
var _react := SpringLink.new(140.0, 9.0)
var _t := 0.0


## Each frame before the body reads the channels. `staggered`: in the stagger pose. `heave` 0..1: how hard it breathes.
func tick(delta: float, staggered: bool, heave: float) -> void:
	_t += delta
	reel = move_toward(reel, 1.0 if staggered else 0.0, delta * (5.0 if staggered else 1.6))
	pant = move_toward(pant, heave, delta * 0.8)
	breath = sin(_t * lerpf(1.6, 3.4, pant)) * lerpf(0.4, 1.0, pant)
	react = _react.step(delta, Vector2.ZERO)


## Head toward `target` (world) from a head at `head_pos` whose parent faces `basis`: yaw (+ left) and pitch (+ up),
## clamped to the neck's reach; `weight` 0 looks ahead, `speed` how fast it follows.
func track(delta: float, basis: Basis, head_pos: Vector3, target: Vector3, weight: float, speed: float = 5.0,
		max_yaw: float = 0.9, max_pitch: float = 0.45) -> void:
	var want := Vector2.ZERO
	var d := basis.orthonormalized().inverse() * (target - head_pos)
	if weight > 0.0 and d.length_squared() > 0.04:
		want = Vector2(clampf(atan2(-d.x, -d.z), -max_yaw, max_yaw), clampf(atan2(d.y, Vector2(d.x, d.z).length()), -max_pitch, max_pitch)) * weight
	look = look.lerp(want, minf(speed * delta, 1.0))


## A blow shoved it along `local_dir` (the body's own frame, flat): it leans away and swings back. `k` ~1 a heavy blow.
func hit(local_dir: Vector3, k: float) -> void:
	_react.v += Vector2(local_dir.z, -local_dir.x) * 6.0 * k


## A SwingChain's link angles this frame (x pitch, y yaw, per link from the root), swung by the motion of `xf` (where the
## SwingChain hangs from, world): it trails what the body does, each link after the one before.
static func swing(c: SwingChain, delta: float, xf: Transform3D, gain: float = 1.0) -> Array:
	var out: Array = []
	if delta <= 0.0:
		for s in c.links:
			out.append((s as SpringLink).x)
		return out
	var force := Vector2.ZERO
	if c._pos != Vector3.INF:
		var vel: Vector3 = (xf.origin - c._pos) / delta
		var acc: Vector3 = xf.basis.orthonormalized().inverse() * ((vel - c._vel) / delta)
		c._vel = vel
		var yaw := atan2(-xf.basis.z.x, -xf.basis.z.z)
		var rate := wrapf(yaw - c._yaw, -PI, PI) / delta
		c._yaw = yaw
		# (pushed back as it lunges ahead, out to the side it turns away from)
		force = Vector2(clampf(acc.z * 0.05, -3.0, 3.0), clampf(-acc.x * 0.05 - rate * 0.9, -3.0, 3.0)) * gain * 30.0
	else:
		c._yaw = atan2(-xf.basis.z.x, -xf.basis.z.z)
	c._pos = xf.origin
	var prev := Vector2.ZERO
	for i in range(c.links.size()):
		var s: SpringLink = c.links[i]
		var f: Vector2 = force if i == 0 else (prev - s.x) * c.follow
		prev = s.step(delta, f)
		out.append(prev)
	return out


## Anticipation and follow-through over a move's time `t`: gathers to -1 by `wind` (a slow-in pull back), snaps to +1
## over `strike`, then overshoots and settles back to 0 over `settle`. A body squashes and leans with it.
static func antic(t: float, wind: float, strike: float, settle: float) -> float:
	if t < 0.0:
		return 0.0
	if t < wind:
		return -sin(t / wind * PI * 0.5)
	if t < wind + strike:
		var x := (t - wind) / strike
		return lerpf(-1.0, 1.0, x * x * (3.0 - 2.0 * x))
	var y := (t - wind - strike) / maxf(settle, 0.01)
	return exp(-3.5 * y) * cos(y * 6.0) if y < 1.4 else 0.0


## The squash or stretch for an antic() value: gathered it squats wide, at the strike it stretches along the blow.
static func squash(a: float, amount: float = 1.0) -> Vector3:
	var g := maxf(-a, 0.0) * amount
	var s := maxf(a, 0.0) * amount
	return Vector3(1.0 + g * 0.05 - s * 0.02, 1.0 - g * 0.07 + s * 0.02, 1.0 + s * 0.07)
