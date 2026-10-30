class_name CapitalBellTower
extends RefCounted
## The plaza's bell tower, climbed (1.27, docs/v1_27_plan.md C2): hollow, a door in its south face onto the bell yard (a
## floor off the plaza's corner, CapitalPlan.FLOORS "bell_yard"), stairs round the inside walls (nine flights at 39
## degrees, a landing at each corner) up to the belfry: a floor over the shaft (open over the last flight), an open arch
## each side with a rail, the bell hung in the middle, the hip roof and its gilded spike over it. The hooded stranger
## waits up there (CapitalLife, spot "informant"). Frame coordinates, into the shell's Landmarks piece.

const M := preload("res://scripts/island/capital_models.gd")
const W := 6.5
const H := 27.0
const WALL := 0.6
const FLIGHTS := 9
const BELFRY := 22.0
const STAIR_W := 1.1
const DOOR_W := 1.6
const DOOR_H := 3.0
## The belfry's arches: bottom, height, width.
const ARCH_Y := 22.0
const ARCH_H := 3.4
const ARCH_W := 2.4


## The belfry floor's middle (frame), where the stranger stands.
static func top(c: Vector2, y0: float) -> Vector3:
	return M.v3(c + Vector2(0, 0.6), y0 + BELFRY)


static func build(mb: MeshBuilder, cols: Array, c: Vector2, y0: float) -> void:
	var t := M.xf(M.v3(c, 0.0))
	var lime := M.mat("lime")
	var col := Color(0.95, 0.93, 0.89)
	var hw := W * 0.5
	var a := hw - WALL
	var deep := 2.0
	# the four walls, each in pieces round its openings: the door (south), the arch (every side), the rest solid
	for side in range(4):
		var yaw := side * PI * 0.5
		var st := t * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		var z := hw - WALL * 0.5
		var spans: Array = [[y0 - deep, ARCH_Y + y0, []], [ARCH_Y + y0, ARCH_Y + ARCH_H + y0, [ARCH_W]], [ARCH_Y + ARCH_H + y0, y0 + H, []]]
		if side == 0:
			# (south, +z: the door at the foot)
			spans = [[y0 - deep, y0, []], [y0, y0 + DOOR_H, [DOOR_W]], [y0 + DOOR_H, ARCH_Y + y0, []], [ARCH_Y + y0, ARCH_Y + ARCH_H + y0, [ARCH_W]], [ARCH_Y + ARCH_H + y0, y0 + H, []]]
		for sp in spans:
			var lo: float = sp[0]
			var hi: float = sp[1]
			var gap: Array = sp[2]
			if gap.is_empty():
				var bt := st * Transform3D(Basis(), Vector3(0, (lo + hi) * 0.5, z))
				mb.add_box(lime, bt, Vector3(W, hi - lo, WALL), 0.5, col)
				M.box(cols, bt, Vector3(W, hi - lo, WALL))
			else:
				var gw: float = gap[0]
				var pw := (W - gw) * 0.5
				for s in [-1.0, 1.0]:
					var bt := st * Transform3D(Basis(), Vector3(s * (gw * 0.5 + pw * 0.5), (lo + hi) * 0.5, z))
					mb.add_box(lime, bt, Vector3(pw, hi - lo, WALL), 0.5, col)
					M.box(cols, bt, Vector3(pw, hi - lo, WALL))
		# the clock faces under the belfry, a rail across each arch, the arch's sill
		var ct := st * Transform3D(Basis(), Vector3(0, y0 + 18.5, hw + 0.02))
		mb.add_cylinder(lime, ct * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 1.3, 1.3, 0.12, 12, 1.0, Color(0.96, 0.95, 0.92))
		mb.add_box(M.mat("iron"), ct * Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0, 0, 0.18)), Vector3(0.08, 1.0, 0.04), 1.0, Color.WHITE, false)
		mb.add_box(M.mat("iron"), ct * Transform3D(Basis(Vector3.BACK, -1.9), Vector3(0, 0, 0.18)), Vector3(0.08, 0.7, 0.04), 1.0, Color.WHITE, false)
		var rt := st * Transform3D(Basis(), Vector3(0, y0 + ARCH_Y + 0.95, z))
		mb.add_box(M.mat("iron"), rt, Vector3(ARCH_W, 0.06, 0.06), 1.0, Color.WHITE, false)
		for k in range(5):
			mb.add_box(M.mat("iron"), st * Transform3D(Basis(), Vector3(-ARCH_W * 0.5 + 0.2 + k * (ARCH_W - 0.4) / 4.0, y0 + ARCH_Y + 0.48, z)), Vector3(0.04, 0.95, 0.04), 1.0, Color.WHITE, false)
		M.box(cols, rt * Transform3D(Basis(), Vector3(0, -0.45, 0)), Vector3(ARCH_W, 1.0, 0.2))
		# the door's lintel and steps out on the yard (south only)
		if side == 0:
			mb.add_box(lime, st * Transform3D(Basis(), Vector3(0, y0 + DOOR_H + 0.2, hw + 0.1)), Vector3(DOOR_W + 0.6, 0.4, 0.3), 0.6, Color(0.9, 0.88, 0.84), false)
	# the cornice and the roof (as the old solid tower had)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y0 + H + 0.4, 0)), Vector3(W + 0.6, 0.8, W + 0.6), 0.6, Color(0.85, 0.83, 0.79), false)
	mb.add_box(lime, t * Transform3D(Basis(), Vector3(0, y0 + H - 0.1, 0)), Vector3(W, 0.4, W), 0.6, Color(0.85, 0.83, 0.79), false)
	M._hip(mb, t * Transform3D(Basis(), Vector3(0, y0 + H + 0.8, 0)), W + 0.4, W + 0.4, W * 0.75, 0.3, Color.WHITE)
	mb.add_cylinder(M.mat("gold"), t * Transform3D(Basis(), Vector3(0, y0 + H + 0.8 + W * 0.75 - 0.1, 0)), 0.07, 0.03, 1.3, 4)
	# the ground floor
	mb.add_box(PSXMat.lit("planks_dark"), t * Transform3D(Basis(), Vector3(0, y0 - 0.05, 0)), Vector3(a * 2.0, 0.1, a * 2.0), 0.6, Color.WHITE, false)
	M.box(cols, t * Transform3D(Basis(), Vector3(0, y0 - 0.2, 0)), Vector3(a * 2.0, 0.4, a * 2.0))
	# the stairs: flight k runs from corner k to corner k + 1 (counterclockwise from the north-west), rising `rise`
	var rise := BELFRY / FLIGHTS
	var corners := [Vector2(-a + STAIR_W * 0.5, -a + STAIR_W * 0.5), Vector2(a - STAIR_W * 0.5, -a + STAIR_W * 0.5),
		Vector2(a - STAIR_W * 0.5, a - STAIR_W * 0.5), Vector2(-a + STAIR_W * 0.5, a - STAIR_W * 0.5)]
	var wood := PSXMat.lit("planks_dark")
	for k in range(FLIGHTS):
		var q0: Vector2 = corners[k % 4]
		var q1: Vector2 = corners[(k + 1) % 4]
		var y_a := y0 + k * rise
		var y_b := y0 + (k + 1) * rise
		var dir := (q1 - q0).normalized()
		var p0 := q0 + dir * STAIR_W * 0.5
		var p1 := q1 - dir * STAIR_W * 0.5
		var L := p0.distance_to(p1)
		# the landing at its foot (the first: on the floor)
		if k > 0:
			var lt := t * Transform3D(Basis(), M.v3(q0, y_a - 0.15))
			mb.add_box(wood, lt, Vector3(STAIR_W, 0.3, STAIR_W), 0.6, Color.WHITE)
			M.box(cols, lt, Vector3(STAIR_W, 0.3, STAIR_W))
		# the treads (to see) and one ramp under them (to walk)
		var n := 10
		var yaw := atan2(dir.x, dir.y)
		for i in range(n):
			var f := (i + 0.5) / n
			var q := p0.lerp(p1, f)
			var sy := lerpf(y_a, y_b, (i + 1.0) / n)
			mb.add_box(wood, t * Transform3D(Basis(Vector3.UP, yaw), M.v3(q, sy - 0.12)), Vector3(STAIR_W, 0.24, L / n + 0.02), 0.6, Color(0.92, 0.88, 0.82), false)
		var ang := atan2(y_b - y_a, L)
		var mid := M.v3((p0 + p1) * 0.5, (y_a + y_b) * 0.5 - 0.18)
		M.box(cols, t * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -ang), mid), Vector3(STAIR_W, 0.3, L / cos(ang) + 0.1))
	# the belfry floor, open over the last flight's strip (it climbs up through it)
	var last: int = (FLIGHTS - 1) % 4
	var ql0: Vector2 = corners[last]
	var ql1: Vector2 = corners[(last + 1) % 4]
	var strip := Rect2(Vector2(minf(ql0.x, ql1.x), minf(ql0.y, ql1.y)) - Vector2.ONE * STAIR_W * 0.5, (ql1 - ql0).abs() + Vector2.ONE * STAIR_W)
	strip = strip.grow_individual(-STAIR_W, 0, -STAIR_W, 0) if absf(ql1.x - ql0.x) > absf(ql1.y - ql0.y) else strip.grow_individual(0, -STAIR_W, 0, -STAIR_W)
	var inner := Rect2(-a, -a, a * 2.0, a * 2.0)
	for r in _minus(inner, strip):
		var ft := t * Transform3D(Basis(), M.v3(r.get_center(), y0 + BELFRY - 0.15))
		mb.add_box(wood, ft, Vector3(r.size.x, 0.3, r.size.y), 0.6, Color.WHITE)
		M.box(cols, ft, Vector3(r.size.x, 0.3, r.size.y))
	# the bell, hung from a beam across the belfry
	mb.add_box(wood, t * Transform3D(Basis(), Vector3(0, y0 + ARCH_Y + ARCH_H + 0.3, 0)), Vector3(a * 2.0, 0.3, 0.3), 0.6, Color.WHITE)
	var bronze := PSXMat.lit("", Color(0.62, 0.46, 0.22))
	mb.add_cylinder(bronze, t * Transform3D(Basis(), Vector3(0, y0 + ARCH_Y + 1.4, 0)), 0.95, 0.45, 1.5, 12, 0.5, Color.WHITE, true, true)
	mb.add_cylinder(bronze, t * Transform3D(Basis(), Vector3(0, y0 + ARCH_Y + 2.9, 0)), 0.45, 0.2, 0.35, 10, 0.5, Color.WHITE)
	M.cyl(cols, M.v3(c, y0 + ARCH_Y + 1.4), 0.95, 1.9)
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, y0 + 10.0, hw - 0.1)), Vector3(W, 18.0, 0.2))


## `r` with `hole` cut out: up to four rects.
static func _minus(r: Rect2, hole: Rect2) -> Array:
	var h := r.intersection(hole)
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		return [r]
	var out: Array = []
	if h.position.y > r.position.y:
		out.append(Rect2(r.position.x, r.position.y, r.size.x, h.position.y - r.position.y))
	if h.end.y < r.end.y:
		out.append(Rect2(r.position.x, h.end.y, r.size.x, r.end.y - h.end.y))
	if h.position.x > r.position.x:
		out.append(Rect2(r.position.x, h.position.y, h.position.x - r.position.x, h.size.y))
	if h.end.x < r.end.x:
		out.append(Rect2(h.end.x, h.position.y, r.end.x - h.end.x, h.size.y))
	return out
