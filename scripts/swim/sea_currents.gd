extends Node3D
## Rip currents off the islands' beaches: a narrow channel of water running straight out to sea from the
## surf, strong near the beach and dying away 50 m out. Swim against one and you go nowhere; swim along
## the shore and you're out of it. Each one churns: foam thrown seaward along it (each screen its own).
## Placed from the island's seed on gentle, exposed shores clear of the dock (the same on every screen).
## DiveSites builds it ("SeaCurrents", group "sea_currents") and keeps its islands in step with its own.

## Strongest flow (m/s): a plain stroke (3.2) barely holds against it, a sprint (4.6) beats it.
const RIP_SPEED := 2.6
const RIP_LEN := 50.0
const RIP_WIDTH := 8.0
## Rips per island (Brinehollow, a chain island), and how far apart they keep.
const HOME_RIPS := 3
const GEN_RIPS := 2
const RIP_GAP := 80.0
const DOCK_KEEP := 80.0
## The churn: how often, and from how far it's drawn.
const CHURN_EVERY := 0.3
const CHURN_RANGE := 90.0

## island key -> [[from (x, z), to (x, z), width], ...] in world space
var rips := {}
var _churn_t := 0.0


func _ready() -> void:
	add_to_group("sea_currents")


func build_island(key: String, isl: Node3D, ground: Callable, seed_value: int, count: int, dock: Vector2, r_min: float, r_max: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "rips"])
	var list: Array = []
	var start := rng.randf() * TAU
	for k in range(48):
		if list.size() >= count:
			break
		var a := start + TAU * float(k) / 48.0
		var d := Vector2(cos(a), sin(a))
		var r := r_min
		while r < r_max and float(ground.call(d.x * r, d.y * r)) > -0.3:
			r += 2.0
		if r >= r_max:
			continue
		var w := d * r
		# a beach: the bottom shelves gently out (not a cliff, not a reef flat), on a shore the swell reaches
		var out := float(ground.call(w.x + d.x * 30.0, w.y + d.y * 30.0))
		if out > -1.5 or out < -7.0 or w.distance_to(dock) < DOCK_KEEP:
			continue
		var wa := isl.to_global(Vector3(w.x - d.x * 4.0, 0.0, w.y - d.y * 4.0))
		var wb := isl.to_global(Vector3(w.x + d.x * RIP_LEN, 0.0, w.y + d.y * RIP_LEN))
		if float(Ocean.shore_at(wa.x, wa.z).w) < 0.35:
			continue
		var a2 := Vector2(wa.x, wa.z)
		if list.any(func(e): return (e[0] as Vector2).distance_to(a2) < RIP_GAP):
			continue
		list.append([a2, Vector2(wb.x, wb.z), RIP_WIDTH])
	rips[key] = list


func drop_island(key: String) -> void:
	rips.erase(key)


## The rips' pull at `p` (m/s, flat).
func rip_at(p: Vector3) -> Vector3:
	var q := Vector2(p.x, p.z)
	var out := Vector2.ZERO
	for list in rips.values():
		for e in list:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var ab := b - a
			var t := clampf((q - a).dot(ab) / ab.length_squared(), -0.1, 1.1)
			var across := q.distance_to(a + ab * clampf(t, 0.0, 1.0))
			var w: float = e[2]
			if across > w or t < -0.05 or t > 1.0:
				continue
			var k := (1.0 - smoothstep(w * 0.45, w, across)) * (1.0 - smoothstep(0.55, 1.0, t))
			out += ab.normalized() * RIP_SPEED * k
	return Vector3(out.x, 0.0, out.y)


func _process(delta: float) -> void:
	_churn_t -= delta
	if _churn_t > 0.0:
		return
	_churn_t = CHURN_EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := Vector2(cam.global_position.x, cam.global_position.z)
	for list in rips.values():
		for e in list:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			if c.distance_to((a + b) * 0.5) > CHURN_RANGE + RIP_LEN * 0.5:
				continue
			# foam thrown seaward somewhere along its first two thirds
			var q := a.lerp(b, randf_range(0.05, 0.65)) + (b - a).normalized().orthogonal() * randf_range(-2.5, 2.5)
			var at := Vector3(q.x, 0.0, q.y)
			at.y = float(Ocean.surface_at(at)) + 0.05
			var dir := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
			FX.spray(at, (dir + Vector3.UP * 0.6).normalized(), 4, Color(0.9, 0.96, 1.0), 2.4)
