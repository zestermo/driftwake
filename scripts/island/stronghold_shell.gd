class_name StrongholdShell
extends RefCounted
## The stronghold's buildings (1.27, StrongholdPlan's frame), first piece: the blockout of the whole fortress, solid
## and walkable. The districts' paving, the grand stair up from the quay, the ramps to the wings, the Bridge of
## Judgement on its piers over the chasm, the curtain walls with their towers and gatehouses, the barracks halls round
## the hub, the arsenal's foundry, the prison's tower, the keep and the signal spire. Interiors, encounter rooms and
## the garrison come in later pieces. Pieces as CapitalShell's (CapitalShell._piece): on a worker in prepare.

const P := preload("res://scripts/island/stronghold_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const FAR := 3600.0


static func build(build_ms: Dictionary) -> Array:
	var out: Array = []
	for step in [["paving", _paving], ["ways", _ways], ["walls", _walls], ["buildings", _buildings]]:
		var t0 := Time.get_ticks_usec()
		step[1].call(out)
		build_ms[step[0]] = (Time.get_ticks_usec() - t0) / 1000.0
	return out


static func _stone() -> Material:
	return PSXMat.lit("stone_brick", Color(0.66, 0.64, 0.62))


## The districts' paving (the terrain under it is the collider): grey slabs, the quay's edge a kerb.
static func _paving(out: Array) -> void:
	var mb := MeshBuilder.new()
	var slab := M.mat("slabs")
	for d in P.DISTRICTS:
		var r: Rect2 = d[1]
		var y: float = float(d[2]) + 0.03
		mb.add_quad(slab, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y),
			Vector2.ZERO, Vector2(r.size.x * 0.4, 0), Vector2(r.size.x * 0.4, r.size.y * 0.4), Vector2(0, r.size.y * 0.4), Color(0.72, 0.72, 0.74), Vector3.UP)
	CapitalShell._piece(out, "Paving", mb, [], FAR, false)


## The grand stair, the ramps (both on the terrain, steps drawn over a ramp collider) and the bridge on its piers.
static func _ways(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var stone := _stone()
	for w in P.WAYS:
		var a: Vector2 = w[1]
		var b: Vector2 = w[2]
		var hw: float = w[3]
		var ya := P._height_near(a)
		var yb := P._height_near(b)
		var dir := (b - a).normalized()
		var L := a.distance_to(b)
		var a3 := M.v3(a, ya)
		var b3 := M.v3(b, yb)
		var along := Transform3D(Basis.looking_at(b3 - a3, Vector3.UP), (a3 + b3) * 0.5)
		M.box(cols, along * Transform3D(Basis(), Vector3(0, -0.25, 0)), Vector3(hw * 2.0, 0.5, a3.distance_to(b3) + 0.4))
		var steps := maxi(int(absf(yb - ya) / 0.22), 1)
		if str(w[0]) == "bridge":
			# the deck as one sloped slab, parapets, and piers down into the chasm every 8 m
			mb.add_box(stone, along * Transform3D(Basis(), Vector3(0, -0.4, 0)), Vector3(hw * 2.0, 0.8, a3.distance_to(b3) + 0.4), 0.5, Color(0.7, 0.68, 0.66), false)
			var n := int(L / 8.0)
			for k in range(1, n):
				var p := a.lerp(b, float(k) / n)
				var top := lerpf(ya, yb, float(k) / n) - 0.8
				mb.add_box(stone, M.xf(M.v3(p, (top + P.CHASM_Y - 2.0) * 0.5), M.yaw_of(dir)), Vector3(hw * 1.6, top - P.CHASM_Y + 2.0, 2.4), 0.5, Color(0.62, 0.6, 0.58))
				M.box(cols, M.xf(M.v3(p, (top + P.CHASM_Y - 2.0) * 0.5), M.yaw_of(dir)), Vector3(hw * 1.6, top - P.CHASM_Y + 2.0, 2.4))
		else:
			for k in range(steps):
				var p0 := a.lerp(b, float(k) / steps)
				var y := lerpf(ya, yb, float(k + 1) / steps)
				var c := a.lerp(b, (k + 0.5) / steps)
				mb.add_box(stone, M.xf(M.v3(c, (y + minf(ya, yb) - 0.5) * 0.5), M.yaw_of(dir)), Vector3(hw * 2.0, y - minf(ya, yb) + 0.5, L / steps + 0.02), 0.5, Color(0.74, 0.72, 0.7), false)
		# parapets each side, sloped with the way
		for s: float in [-1.0, 1.0]:
			var side := along * Transform3D(Basis(), Vector3(s * (hw + 0.3), 0.55, 0))
			mb.add_box(stone, side, Vector3(0.6, 1.1, a3.distance_to(b3) + 0.6), 0.5, Color(0.68, 0.66, 0.64))
			M.box(cols, side, Vector3(0.6, 1.1, a3.distance_to(b3) + 0.6))
	CapitalShell._piece(out, "Ways", mb, cols, FAR, true)


## The curtain walls along each district's edges that face the drop (gaps where a way arrives), round towers at the
## corners, and a gatehouse where the grand stair comes up into the ward and where the bridge reaches the keep.
static func _walls(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var ground := func(q: Vector2) -> float: return _floor_y(q)
	var low := func(q: Vector2) -> float: return _floor_y(q) - 6.0
	for d in P.DISTRICTS:
		if str(d[0]) == "landing":
			continue
		var r: Rect2 = d[1].grow(-1.4)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			for run in _gapped(a, b):
				M.wall_run(mb, cols, run, 4.0, 2.2, ground, low)
			M.round_tower(mb, cols, a, float(d[2]), 3.2, 11.0, true, 8.0, i % 2 == 0)
	# the gatehouses: the ward's at the stair's head, the keep's at the bridge's end
	M.gatehouse(mb, cols, M.xf(M.v3(Vector2(0, 18.6), 12.0)), 16.0, 6.0, 11.0, 5.0, 4.0, 3.4, false)
	M.gatehouse(mb, cols, M.xf(M.v3(Vector2(0, -49.4), 30.0)), 16.0, 6.0, 12.0, 5.0, 4.0, 3.4, false)
	# the sea gate's two towers at the quay's ends, and the quay's kerb
	for x in [-58.0, 58.0]:
		M.round_tower(mb, cols, Vector2(x, 60.0), P.QUAY_Y, 4.5, 16.0, true, 10.0, true)
	mb.add_box(_stone(), M.xf(M.v3(Vector2(0, P.FRONT_Z - 0.3), P.QUAY_Y - 2.0)), Vector3(112.0, 4.2, 0.6), 0.5, Color(0.6, 0.6, 0.6))
	CapitalShell._piece(out, "Walls", mb, cols, FAR, true)


## The edge from a to b cut where a way crosses it (the stair, the ramps, the bridge): the runs left.
static func _gapped(a: Vector2, b: Vector2) -> Array:
	var runs: Array = [[a]]
	var n := int(a.distance_to(b) / 2.0)
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / n)
		var gap := false
		for w in P.WAYS:
			var wa: Vector2 = w[1]
			var wb: Vector2 = w[2]
			var ab := wb - wa
			var u := clampf((p - wa).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.distance_to(wa + ab * u) < float(w[3]) + 2.0:
				gap = true
		if gap:
			if (runs[-1] as Array).size() >= 2:
				runs.append([])
			else:
				runs[-1] = []
		else:
			(runs[-1] as Array).append(p)
	return runs.filter(func(r): return r.size() >= 2)


## A district's floor under q (the nearest one's), for the walls' feet.
static func _floor_y(q: Vector2) -> float:
	return P._height_near(q)


## The big buildings, solid for now: the barracks halls either side of the hub's middle, the mess hall, the foundry
## with its chimneys, the prison's round tower, the keep's tower and the signal spire.
static func _buildings(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var lime := M.mat("lime")
	var roof := M.mat("roof")
	var halls := [
		[Rect2(-42.0, -10.0, 24.0, 22.0), 12.0, 9.0], [Rect2(18.0, -10.0, 24.0, 22.0), 12.0, 9.0],
		[Rect2(72.0, -36.0, 24.0, 30.0), 14.0, 13.0], [Rect2(-38.0, -110.0, 76.0, 7.0), 30.0, 8.0],
	]
	for h in halls:
		var r: Rect2 = h[0]
		var y: float = h[1]
		var tall: float = h[2]
		var c := r.get_center()
		mb.add_box(lime, M.xf(M.v3(c, y + tall * 0.5 - 1.0)), Vector3(r.size.x, tall + 2.0, r.size.y), 0.5, Color(0.86, 0.84, 0.8))
		M.box(cols, M.xf(M.v3(c, y + tall * 0.5 - 1.0)), Vector3(r.size.x, tall + 2.0, r.size.y))
		mb.add_box(roof, M.xf(M.v3(c, y + tall + 1.0)), Vector3(r.size.x + 0.6, 0.6, r.size.y + 0.6), 0.5, Color(0.55, 0.4, 0.35))
	# the foundry's chimneys
	for x in [76.0, 92.0]:
		mb.add_box(_stone(), M.xf(M.v3(Vector2(x, -32.0), 14.0 + 13.0)), Vector3(2.4, 26.0, 2.4), 0.5, Color(0.4, 0.38, 0.36))
		M.box(cols, M.xf(M.v3(Vector2(x, -32.0), 14.0 + 13.0)), Vector3(2.4, 26.0, 2.4))
	# the prison's tower
	M.round_tower(mb, cols, P.PRISON, 14.0, 12.0, 34.0, false, 6.0, true)
	# the keep: a square tower of four storeys and a crown of merlons
	var kh := 30.0
	mb.add_box(lime, M.xf(M.v3(P.KEEP, 30.0 + kh * 0.5 - 1.0)), Vector3(24.0, kh + 2.0, 24.0), 0.5, Color(0.9, 0.88, 0.84))
	M.box(cols, M.xf(M.v3(P.KEEP, 30.0 + kh * 0.5 - 1.0)), Vector3(24.0, kh + 2.0, 24.0))
	for s in range(4):
		for k in range(6):
			var t := -11.0 + k * 4.4
			var o: Vector2 = [Vector2(t, -12.3), Vector2(12.3, t), Vector2(t, 12.3), Vector2(-12.3, t)][s]
			mb.add_box(lime, M.xf(M.v3(P.KEEP + o, 30.0 + kh + 1.0)), Vector3(1.4, 2.0, 1.4), 0.5, Color(0.88, 0.86, 0.82))
	for cn in [Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)]:
		M.round_tower(mb, cols, P.KEEP + cn, 30.0, 3.4, kh + 8.0, true, 2.0, true)
	# the signal spire: a lattice of four posts and braces, a lamp room on top
	var dark := M.mat("dark")
	for cn in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(2.5, 2.5), Vector2(-2.5, 2.5)]:
		mb.add_box(dark, M.xf(M.v3(P.SPIRE + cn, 30.0 + 18.0)), Vector3(0.5, 36.0, 0.5), 0.5, Color(0.5, 0.45, 0.4))
		M.box(cols, M.xf(M.v3(P.SPIRE + cn, 30.0 + 18.0)), Vector3(0.5, 36.0, 0.5))
	for k in range(6):
		mb.add_box(dark, M.xf(M.v3(P.SPIRE, 30.0 + 4.0 + k * 6.0)), Vector3(5.6, 0.3, 5.6), 0.5, Color(0.45, 0.4, 0.36))
	mb.add_box(lime, M.xf(M.v3(P.SPIRE, 30.0 + 38.0)), Vector3(4.0, 3.0, 4.0), 0.5, Color(0.9, 0.86, 0.8))
	CapitalShell._piece(out, "Buildings", mb, cols, FAR, true)
