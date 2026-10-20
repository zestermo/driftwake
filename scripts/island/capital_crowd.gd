class_name CapitalCrowd
extends Node3D
## The royal capital's crowd (docs/capital_plan.md: busy, inside the perf gate): townsfolk walking the district's
## lanes, each where the shared clock (Ocean.clock: the same on every screen, so co-op needs no messages) puts them on
## its lane. Built cheap from the start:
## - every walker is an instance of one MultiMesh of a simple figure (two of them: the two strides of a step), no
##   collider, no shadow, tinted by instance colour; positions worked out every TICK s, not every frame;
## - the nearest walkers (within NEAR_R of the camera, at most one per look) are swapped for real bodies from a pool of
##   LOOKS prebuilt Humanoids (CapitalIsland.prepare), which walk with the rig's own LOD;
## - nothing at all runs or draws past SLEEP_R from the district (one distance check every SLEEP_EVERY s).
## Lives under the City node (CapitalPlan's frame).

const P := preload("res://scripts/island/capital_plan.gd")
## Lanes in the frame: [points, walkers, closed loop]. A walker goes to the lane's end and back (round a loop).
const LANES := [
	[[Vector2(-3.4, 77.0), Vector2(-3.4, 23.0)], 7, false],
	[[Vector2(3.4, 23.0), Vector2(3.4, 77.0), Vector2(1.6, 84.0), Vector2(1.6, 96.0)], 7, false],
	[[Vector2(-140.0, 99.0), Vector2(140.0, 99.0)], 7, false],
	[[Vector2(140.0, 108.5), Vector2(-140.0, 108.5)], 6, false],
	[[Vector2(-2.6, -24.0), Vector2(-2.6, -58.0)], 3, false],
	[[Vector2(2.6, -58.0), Vector2(2.6, -24.0)], 3, false],
	[[Vector2(27.0, 2.2), Vector2(60.0, 2.2)], 3, false],
	[[Vector2(-23.0, 19.5), Vector2(23.0, 19.5)], 4, false],
	[[Vector2(23.0, -19.5), Vector2(-23.0, -19.5)], 4, false],
	[[Vector2(-22.0, 6.0), Vector2(-22.0, -14.0)], 2, false],
	[[], 10, true],
]
const RING_R := 8.6
const LOOKS := 8
const NEAR_R := 15.0
const TICK := 0.1
const SLEEP_R := 260.0
const SLEEP_EVERY := 0.5
const SPEED := [0.95, 1.45]
const FIGURE_H := 1.72

## {"lane": int, "s0", "v", "look": int} per walker (from the fixed seed).
var walkers: Array = []
## Each lane's points and cumulative lengths.
var _lanes: Array = []
var looks: Array = []
var _mm: Array = []
var _bodies: Array = []
var _owner: Array = []
var _tick := 0.0
var _sleep_t := 0.0
var awake := true
var centre := Vector3.ZERO


## The townsfolk's looks (the capital's style, a fixed seed): CapitalIsland prebuilds a body for each.
static func make_looks() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	var st := KitStyle.of("capital")
	var out: Array = []
	for i in range(LOOKS):
		var lk := KitStyle.folk_look(st, rng)
		lk["name"] = "Townsfolk%d" % i
		out.append(lk)
	return out


func setup(look_list: Array) -> CapitalCrowd:
	name = "Crowd"
	looks = look_list
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	for li in range(LANES.size()):
		var pts: Array = LANES[li][0]
		if LANES[li][2]:
			pts = []
			for k in range(17):
				var a := TAU * k / 16.0
				pts.append(Vector2(cos(a), sin(a)) * RING_R)
		var lens := [0.0]
		for k in range(1, pts.size()):
			lens.append(float(lens[-1]) + (pts[k] as Vector2).distance_to(pts[k - 1]))
		_lanes.append({"pts": pts, "lens": lens, "loop": LANES[li][2]})
		for k in range(int(LANES[li][1])):
			walkers.append({"lane": li, "s0": rng.randf() * float(lens[-1]) * 2.0, "v": rng.randf_range(SPEED[0], SPEED[1]) * (1.0 if rng.randf() < 0.5 or LANES[li][2] else -1.0),
				"look": walkers.size() % LOOKS})
	for stride in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = figure_mesh(stride)
		mm.instance_count = walkers.size()
		for i in range(walkers.size()):
			mm.set_instance_color(i, looks[int(walkers[i]["look"])]["top_color"])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Figures%d" % stride
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 180.0
		mi.custom_aabb = AABB(Vector3(-160, -5, -80), Vector3(320, 60, 200))
		add_child(mi)
		_mm.append(mm)
	for i in range(LOOKS):
		var h := Humanoid.make(looks[i])
		h.name = "Walker%d" % i
		h.lod = true
		h.visible = false
		h.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(h)
		_bodies.append(h)
		_owner.append(-1)
	return self


## Where walker i is at clock time t (frame): [position, heading].
func place_of(i: int, t: float) -> Array:
	var w: Dictionary = walkers[i]
	var lane: Dictionary = _lanes[int(w["lane"])]
	var lens: Array = lane["lens"]
	var L: float = lens[-1]
	var s := float(w["s0"]) + float(w["v"]) * t
	var back := false
	if lane["loop"]:
		s = fposmod(s, L)
	else:
		s = fposmod(s, L * 2.0)
		if s > L:
			s = L * 2.0 - s
			back = true
	var pts: Array = lane["pts"]
	var k := 1
	while k < pts.size() - 1 and float(lens[k]) < s:
		k += 1
	var a: Vector2 = pts[k - 1]
	var b: Vector2 = pts[k]
	var u := clampf((s - float(lens[k - 1])) / maxf(float(lens[k]) - float(lens[k - 1]), 0.001), 0.0, 1.0)
	var q := a.lerp(b, u)
	var dir := (b - a).normalized()
	if back != (float(w["v"]) < 0.0):
		dir = -dir
	return [Vector3(q.x, P.ground(q), q.y), dir]


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := to_local(cam.global_position)
	_sleep_t -= delta
	if _sleep_t <= 0.0:
		_sleep_t = SLEEP_EVERY
		var want := eye.distance_to(centre) < SLEEP_R
		if want != awake:
			awake = want
			visible = want
			if not want:
				for b in range(_bodies.size()):
					_free_body(b)
	if not awake:
		return
	var t := float(Ocean.clock())
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_assign(eye, t)
		_update_figures(t)
	for b in range(_bodies.size()):
		var i: int = _owner[b]
		if i < 0:
			continue
		var pl := place_of(i, t)
		var h: Humanoid = _bodies[b]
		h.position = pl[0]
		var d: Vector2 = pl[1]
		h.rotation.y = atan2(-d.x, -d.y)
		h.ground_speed = absf(float(walkers[i]["v"]))


## Each body to the nearest walker of its look within NEAR_R (or none).
func _assign(eye: Vector3, t: float) -> void:
	var best: Array = []
	best.resize(LOOKS)
	best.fill(-1)
	var bd: Array = []
	bd.resize(LOOKS)
	bd.fill(NEAR_R)
	for i in range(walkers.size()):
		var p: Vector3 = place_of(i, t)[0]
		var d := Vector2(p.x - eye.x, p.z - eye.z).length()
		var lk: int = walkers[i]["look"]
		if d < float(bd[lk]):
			bd[lk] = d
			best[lk] = i
	for b in range(LOOKS):
		if int(best[b]) == int(_owner[b]):
			continue
		if int(best[b]) < 0:
			_free_body(b)
			continue
		_owner[b] = best[b]
		var h: Humanoid = _bodies[b]
		h.visible = true
		h.process_mode = Node.PROCESS_MODE_INHERIT


func _free_body(b: int) -> void:
	_owner[b] = -1
	var h: Humanoid = _bodies[b]
	h.visible = false
	h.process_mode = Node.PROCESS_MODE_DISABLED


## Every figure's transform for this tick into the two strides' buffers (a hidden instance is scaled to nothing).
func _update_figures(t: float) -> void:
	var taken := {}
	for o in _owner:
		if int(o) >= 0:
			taken[int(o)] = true
	var n := walkers.size()
	var at: Array = []
	for i in range(n):
		at.append(place_of(i, t))
	for s in range(2):
		var buf := PackedFloat32Array()
		buf.resize(n * 16)
		for i in range(n):
			var p: Vector3 = at[i][0]
			var d: Vector2 = at[i][1]
			var phase := t * absf(float(walkers[i]["v"])) * 1.6 + float(i) * 0.37
			var show := int(floor(phase)) % 2 == s and not taken.has(i)
			var b := Basis(Vector3.UP, atan2(d.x, d.y))
			if not show:
				b = b.scaled(Vector3.ZERO)
			var o := i * 16
			buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
			buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = p.y + absf(sin(phase * PI)) * 0.05
			buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
			var c: Color = looks[int(walkers[i]["look"])]["top_color"]
			buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = 1.0
		(_mm[s] as MultiMesh).buffer = buf


## A townsperson for the far crowd, facing +Z, FIGURE_H tall: legs (the step's two strides), a coat, arms swinging,
## a head and hair; one surface, its colour from the instance (vertex colour keeps the skin and hair apart).
static func figure_mesh(stride: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var m := PSXMat.lit("fabric")
	var skin := Color(1.0, 0.86, 0.72)
	var dark := Color(0.35, 0.3, 0.28)
	var sw := 0.38 if stride == 0 else -0.38
	for s: float in [-1.0, 1.0]:
		var leg := Transform3D(Basis(Vector3.RIGHT, sw * s), Vector3(s * 0.1, 0.86, 0)) * Transform3D(Basis(), Vector3(0, -0.42, 0))
		mb.add_box(m, leg, Vector3(0.14, 0.84, 0.16), 1.0, Color(0.55, 0.5, 0.48), false)
		var arm := Transform3D(Basis(Vector3.RIGHT, -sw * s * 0.8), Vector3(s * 0.27, 1.42, 0)) * Transform3D(Basis(), Vector3(0, -0.3, 0))
		mb.add_box(m, arm, Vector3(0.11, 0.6, 0.12), 1.0, Color.WHITE, false)
		mb.add_box(m, arm * Transform3D(Basis(), Vector3(0, -0.34, 0)), Vector3(0.09, 0.1, 0.1), 1.0, skin, false)
	mb.add_loft(m, Transform3D(Basis(), Vector3(0, 0.82, 0)), [[0.0, 0.2, 0.14], [0.35, 0.21, 0.13], [0.62, 0.24, 0.14], [0.68, 0.12, 0.08]], MeshBuilder.profile_oct(), 1.0, Color.WHITE, true, true)
	mb.add_box(m, Transform3D(Basis(), Vector3(0, 1.53, 0)), Vector3(0.09, 0.08, 0.09), 1.0, skin)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	mb.add_blob(m, Transform3D(Basis(), Vector3(0, FIGURE_H - 0.13, 0.01)), Vector3(0.11, 0.13, 0.12), rng, 0.0, 3, 6, 1.0, skin)
	mb.add_blob(m, Transform3D(Basis(), Vector3(0, FIGURE_H - 0.08, -0.02)), Vector3(0.12, 0.09, 0.12), rng, 0.0, 2, 6, 1.0, dark)
	return mb.commit()
