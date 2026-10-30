class_name StrongholdShell
extends RefCounted
## The stronghold's buildings (1.27, StrongholdPlan's frame): the fortress's shell, solid and walkable, in its own
## architecture (Zach: nothing like the capital's limestone and cone roofs): dark grey stone and cobbles, iron, square
## and round masses with flat battlemented tops, buttresses and slits, chimneys and gantries, an industrial navy's
## fortress. Over the keep stands the Verdict: a colossal square spire in three stages whose crown is a slab with a
## half-circle cut from its top, a red fire hanging in the cut, seen from far out at sea.
## The districts' cobbles, the grand stair, the ramps, the Bridge of Judgement on its piers over the chasm, the
## curtain walls with their towers and gatehouses, the barracks, the foundry, the prison's drum, the spire. Interiors,
## encounter rooms and the garrison come later. Pieces as CapitalShell's (CapitalShell._piece): on a worker in prepare.

const P := preload("res://scripts/island/stronghold_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const FAR := 3600.0
## The Verdict: its stepped base ([half width, top over the keep's plateau]), its twin towers (each one's width, its
## depth, the cleft between them, their tops) and the circle cut where they meet (its middle's height, its radius).
const SPIRE_STAGES := [[24.0, 32.0], [19.0, 50.0]]
const TWINS := [16.0, 18.0, 6.0, 185.0]
const VERDICT_RING := [140.0, 13.0]


static func build(build_ms: Dictionary) -> Array:
	var out: Array = []
	for step in [["paving", _paving], ["harbour", _harbour], ["ways", _ways], ["walls", _walls], ["buildings", _buildings], ["verdict", _verdict]]:
		var t0 := Time.get_ticks_usec()
		step[1].call(out)
		build_ms[step[0]] = (Time.get_ticks_usec() - t0) / 1000.0
	return out


# --------------------------------------------------------------------------
# The palette
# --------------------------------------------------------------------------
static func _wall_m() -> Material:
	return PSXMat.lit("limestone", Color(0.66, 0.7, 0.8))


static func _dark_m() -> Material:
	return PSXMat.lit("stone_brick", Color(0.72, 0.76, 0.86))


static func _foot_m() -> Material:
	return PSXMat.lit("black_rock", Color(0.6, 0.6, 0.63))


static func _flag_m() -> Material:
	return PSXMat.lit("flagstones", Color(0.56, 0.57, 0.6))


static func _iron_m() -> Material:
	return PSXMat.lit("metal", Color(0.3, 0.31, 0.34))


static func _fire_m() -> Material:
	return PSXMat.glow(Color(1.0, 0.32, 0.1), 3.2)


## A solid block (mesh and collider).
static func _block(mb: MeshBuilder, cols: Array, m: Material, t: Transform3D, size: Vector3, col := Color.WHITE) -> void:
	mb.add_box(m, t, size, 0.5, col)
	M.box(cols, t, size)


# --------------------------------------------------------------------------
# The ground: cobbles, the ways
# --------------------------------------------------------------------------
## The districts' cobbles (the terrain under them is the collider), a black-rock kerb round the quay's sea edge.
static func _paving(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cob := PSXMat.lit("cobbles", Color(0.6, 0.6, 0.62))
	for d in P.DISTRICTS:
		var r: Rect2 = d[1]
		var y: float = float(d[2]) + 0.03
		mb.add_quad(cob, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y),
			Vector2.ZERO, Vector2(r.size.x * 0.35, 0), Vector2(r.size.x * 0.35, r.size.y * 0.35), Vector2(0, r.size.y * 0.35), Color.WHITE, Vector3.UP)
	mb.add_box(_foot_m(), M.xf(M.v3(Vector2(0, P.FRONT_Z - 0.4), P.QUAY_Y - 2.2)), Vector3(112.0, 4.6, 0.8), 0.5)
	CapitalShell._piece(out, "Paving", mb, [], FAR, false)


## The grand stair and the ramps (flagstone steps over a ramp collider), the Bridge of Judgement (a dark deck on piers
## braced with iron), parapets along them all.
static func _ways(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
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
		if str(w[0]) == "bridge":
			mb.add_box(_dark_m(), along * Transform3D(Basis(), Vector3(0, -0.5, 0)), Vector3(hw * 2.0, 1.0, a3.distance_to(b3) + 0.4), 0.5)
			var n := int(L / 8.0)
			for k in range(1, n):
				var p := a.lerp(b, float(k) / n)
				var top := lerpf(ya, yb, float(k) / n) - 1.0
				var pt := M.xf(M.v3(p, (top + P.CHASM_Y - 2.0) * 0.5), M.yaw_of(dir))
				_block(mb, cols, _dark_m(), pt, Vector3(hw * 1.8, top - P.CHASM_Y + 2.0, 3.0))
				# iron bands round each pier
				for yy: float in [top - 3.0, top - 9.0]:
					mb.add_box(_iron_m(), M.xf(M.v3(p, yy), M.yaw_of(dir)), Vector3(hw * 1.8 + 0.2, 0.5, 3.2), 0.5)
			# the arches between the piers: the spandrel in slices, each from the arch's curve up to the deck
			for k in range(n):
				var sa := a.lerp(b, float(k) / n)
				var sb := a.lerp(b, float(k + 1) / n)
				var span := sa.distance_to(sb)
				var r := span * 0.5 - 1.5
				var m := 12
				for j in range(m):
					var s := -span * 0.5 + (j + 0.5) * span / m
					var u := (float(k) + (s + span * 0.5) / span) / n
					var deck := lerpf(ya, yb, u) - 1.0
					var crown := deck - 0.8
					var curve := crown - r + sqrt(maxf(r * r - s * s, 0.0)) if absf(s) < r else deck
					if deck - curve > 0.05:
						var q := (sa + sb) * 0.5 + dir * s
						mb.add_box(_dark_m(), M.xf(M.v3(q, (deck + curve) * 0.5), M.yaw_of(dir)), Vector3(hw * 1.8, deck - curve, span / m + 0.02), 0.5)
		else:
			# torches up both sides of the grand stair
			if str(w[0]) == "stair":
				for k in range(1, int(L / 4.0)):
					for s: float in [-1.0, 1.0]:
						var tp := a.lerp(b, k * 4.0 / L) + Vector2(-dir.y, dir.x) * s * (hw + 0.4)
						_torch(mb, tp, lerpf(ya, yb, k * 4.0 / L) + 1.2)
			var steps := maxi(int(absf(yb - ya) / 0.22), 1)
			for k in range(steps):
				var y := lerpf(ya, yb, float(k + 1) / steps)
				var c := a.lerp(b, (k + 0.5) / steps)
				mb.add_box(_flag_m(), M.xf(M.v3(c, (y + minf(ya, yb) - 0.5) * 0.5), M.yaw_of(dir)), Vector3(hw * 2.0, y - minf(ya, yb) + 0.5, L / steps + 0.02), 0.5, Color.WHITE, false)
		for s: float in [-1.0, 1.0]:
			var side := along * Transform3D(Basis(), Vector3(s * (hw + 0.4), 0.6, 0))
			_block(mb, cols, _wall_m(), side, Vector3(0.8, 1.2, a3.distance_to(b3) + 0.6))
	CapitalShell._piece(out, "Ways", mb, cols, FAR, true)


# --------------------------------------------------------------------------
# The walls, towers and gates
# --------------------------------------------------------------------------
## Curtain walls along each district's edges (cut where a way arrives), towers at the corners (round and square in
## turn, flat-topped), the gatehouses where the stair comes up and the bridge arrives, and the sea gate's towers.
static func _walls(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	for d in P.DISTRICTS:
		if str(d[0]) == "landing":
			continue
		var y: float = d[2]
		var r: Rect2 = (d[1] as Rect2).grow(-1.4)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in range(4):
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			for run in _gapped(a, b):
				for k in range((run as Array).size() - 1):
					_wall(mb, cols, run[k], run[k + 1], y, 6.0)
			# a tall square tower at each corner, and more along a long edge: heights rolled from where they stand
			var out_dir: Vector2 = (a - (d[1] as Rect2).get_center()).normalized()
			_tower(mb, cols, a, y, 7.0, 22.0 + float(posmod(hash(a.round()), 15)), out_dir)
			var L := a.distance_to(b)
			var nm := int(L / 34.0)
			for k in range(1, nm + 1):
				var m := a.lerp(b, float(k) / (nm + 1))
				if _gapped(m, m + (b - a).normalized() * 0.1).is_empty() and _near_way(m, 6.0):
					continue
				var side := Vector2(-(b - a).y, (b - a).x).normalized()
				if side.dot(m - (d[1] as Rect2).get_center()) < 0.0:
					side = -side
				_tower(mb, cols, m, y, 6.0, 18.0 + float(posmod(hash(m.round()), 12)), side)
	_gate(mb, cols, Vector2(0, 18.6), 12.0, 13.0, P.WAYS[0][3] * 2.0 + 1.0)
	_gate(mb, cols, Vector2(0, -49.4), 30.0, 15.0, P.WAYS[3][3] * 2.0 + 1.0)
	for x: float in [-58.0, 58.0]:
		_tower(mb, cols, Vector2(x, 58.0), P.QUAY_Y, 10.0, 30.0, Vector2(0, 1))
	CapitalShell._piece(out, "Walls", mb, cols, FAR, true)


## A straight stretch of curtain wall from a to b on floor y, h high: dark stone on a black-rock footing, square
## merlons on the outer edge, a buttress every few metres on the outside, an iron band under the walk.
static func _wall(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, y: float, h: float) -> void:
	var L := a.distance_to(b)
	if L < 0.2:
		return
	var dir := (b - a) / L
	var yaw := M.yaw_of(dir)
	var c := (a + b) * 0.5
	var t := 2.4
	# (down to the rock or the sea outside it: a sheer face, as in the reference, not a wall perched on a cliff)
	var n := Vector2(-dir.y, dir.x)
	var low := minf(minf(P.terrain(c + n * 3.0), P.terrain(c - n * 3.0)) - 1.0, y - 4.0)
	_block(mb, cols, _wall_m(), M.xf(M.v3(c, (low + y + h) * 0.5), yaw), Vector3(t, y + h - low, L + 0.2))
	mb.add_box(_foot_m(), M.xf(M.v3(c, low + 1.5), yaw), Vector3(t + 1.0, 3.0, L + 0.3), 0.5)
	if posmod(hash(c.round()), 7) == 0:
		_torch(mb, c, y + h)
	mb.add_box(_iron_m(), M.xf(M.v3(c, y + h - 0.4), yaw), Vector3(t + 0.16, 0.3, L + 0.2), 0.5, Color.WHITE, false)
	var mn := maxi(int(L / 2.2), 1)
	for j in range(mn):
		var z := -L * 0.5 + (j + 0.5) * L / mn
		mb.add_box(_wall_m(), M.xf(M.v3(c, 0.0), yaw) * Transform3D(Basis(), Vector3(0, y + h + 0.6, z)), Vector3(t, 1.2, 1.1), 0.5, Color(0.92, 0.92, 0.95))


## A round tower: a drum on a flared black-rock foot, a corbelled ring at the top with square merlons round it and a
## flat iron-grated top, rows of arrow slits.
static func _tower_round(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, r: float, h: float) -> void:
	mb.add_cylinder(_foot_m(), M.xf(M.v3(c, y0 - 8.0)), r * 1.35, r * 1.02, 8.0, 14, 0.5, Color.WHITE, false)
	mb.add_cylinder(_wall_m(), M.xf(M.v3(c, y0)), r, r * 0.96, h, 14, 0.5, Color.WHITE, false)
	M.cyl(cols, M.v3(c, y0 - 8.0), r * 1.1, h + 8.0)
	mb.add_cylinder(_dark_m(), M.xf(M.v3(c, y0 + h)), r * 1.0, r * 1.2, 1.2, 14, 0.5, Color.WHITE, true)
	for k in range(10):
		var a := TAU * k / 10.0
		var p := c + Vector2(cos(a), sin(a)) * (r * 1.14)
		mb.add_box(_wall_m(), M.xf(M.v3(p, y0 + h + 1.8), -a), Vector3(1.0, 1.4, 1.2), 0.5)
	mb.add_cylinder(_iron_m(), M.xf(M.v3(c, y0 + h + 1.2)), r * 0.7, r * 0.7, 0.15, 10, 0.5)
	for k in range(4):
		var a := TAU * k / 4.0 + 0.4
		for row: float in [0.45, 0.75]:
			var p := c + Vector2(cos(a), sin(a)) * (r * 0.97 - row * r * 0.04)
			mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.06)), M.xf(M.v3(p, y0 + h * row), -a), Vector3(0.12, 1.6, 0.4), 1.0, Color.WHITE, false)


## A square tower w across: a block on a black-rock foot, an overhanging crown with merlons at its edges, iron
## brackets under it, slits on each face.
static func _tower_square(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, w: float, h: float) -> void:
	mb.add_box(_foot_m(), M.xf(M.v3(c, y0 - 4.0)), Vector3(w + 1.6, 8.0, w + 1.6), 0.5)
	_block(mb, cols, _wall_m(), M.xf(M.v3(c, y0 + h * 0.5 - 4.0)), Vector3(w, h + 8.0, w))
	mb.add_box(_dark_m(), M.xf(M.v3(c, y0 + h + 0.5)), Vector3(w + 1.2, 1.0, w + 1.2), 0.5)
	var n := maxi(int(w / 2.0), 2)
	for s in range(4):
		for k in range(n):
			var t := -w * 0.5 + (k + 0.5) * w / n
			var o: Vector2 = [Vector2(t, -w * 0.5 - 0.3), Vector2(w * 0.5 + 0.3, t), Vector2(t, w * 0.5 + 0.3), Vector2(-w * 0.5 - 0.3, t)][s]
			if k % 2 == 0:
				mb.add_box(_wall_m(), M.xf(M.v3(c + o, y0 + h + 1.7)), Vector3(1.1, 1.4, 1.1), 0.5)
		var f: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][s]
		mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.06)), M.xf(M.v3(c + f * (w * 0.5 + 0.02), y0 + h * 0.6), M.yaw_of(Vector2(-f.y, f.x))), Vector3(0.4, 2.0, 0.1), 1.0, Color.WHITE, false)


## A gatehouse across a way at frame point c, its floor y: two square towers either side of an opening `gap` wide
## under a heavy lintel, a raised iron portcullis in it and a fire basket on each tower.
static func _gate(mb: MeshBuilder, cols: Array, c: Vector2, y: float, h: float, gap: float) -> void:
	var tw := 6.0
	for s: float in [-1.0, 1.0]:
		var tc := c + Vector2(s * (gap * 0.5 + tw * 0.5), 0)
		_tower_square(mb, cols, tc, y, tw, h)
		mb.add_box(_iron_m(), M.xf(M.v3(tc, y + h + 2.6)), Vector3(1.2, 0.8, 1.2), 0.5)
		mb.add_box(_fire_m(), M.xf(M.v3(tc, y + h + 3.2)), Vector3(0.9, 0.6, 0.9), 1.0, Color.WHITE, false)
	_block(mb, cols, _dark_m(), M.xf(M.v3(c, y + h - 2.5)), Vector3(gap + 0.4, 5.0, tw))
	# the portcullis, raised into the lintel's underside
	var bars := int(gap / 0.9)
	for k in range(bars + 1):
		var x := -gap * 0.5 + k * gap / bars
		mb.add_box(_iron_m(), M.xf(M.v3(c + Vector2(x, 0), y + h - 6.2)), Vector3(0.14, 2.6, 0.14), 0.5)
	mb.add_box(_iron_m(), M.xf(M.v3(c, y + h - 7.4)), Vector3(gap, 0.16, 0.16), 0.5)


## The edge from a to b cut where a way crosses it: the runs left.
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


# --------------------------------------------------------------------------
# The buildings
# --------------------------------------------------------------------------
## The barracks either side of the hub and the hall behind the spire (flat roofs, iron rails, slit windows, stacks),
## the foundry with its two great chimneys and a gantry, the prison's stepped drum with its iron cage crown, the
## signal spire's iron lattice.
static func _buildings(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var halls := [
		[Rect2(-42.0, -10.0, 24.0, 22.0), 12.0, 10.0], [Rect2(18.0, -10.0, 24.0, 22.0), 12.0, 10.0],
		[Rect2(68.0, -38.0, 30.0, 30.0), 14.0, 14.0], [Rect2(-38.0, -110.0, 76.0, 7.0), 30.0, 9.0],
	]
	for h in halls:
		_hall(mb, cols, h[0], h[1], h[2])
	# the foundry's chimneys: tapering round stacks banded with iron, their mouths glowing
	for p: Vector2 in [Vector2(74.0, -32.0), Vector2(92.0, -32.0)]:
		mb.add_cylinder(_dark_m(), M.xf(M.v3(p, 14.0)), 2.6, 1.8, 34.0, 12, 0.5, Color.WHITE, false)
		M.cyl(cols, M.v3(p, 14.0), 2.6, 34.0)
		for yy: float in [22.0, 32.0, 42.0]:
			mb.add_cylinder(_iron_m(), M.xf(M.v3(p, yy)), 2.6 - (yy - 14.0) * 0.024 + 0.1, 2.6 - (yy - 14.0) * 0.024 + 0.1, 0.5, 12, 0.5)
		mb.add_cylinder(_fire_m(), M.xf(M.v3(p, 47.6)), 1.6, 1.6, 0.3, 10, 1.0)
	# a gantry over the foundry's yard: two iron frames and a beam
	for x: float in [60.0, 104.0]:
		_block(mb, cols, _iron_m(), M.xf(M.v3(Vector2(x, 2.0), 14.0 + 7.0)), Vector3(0.8, 14.0, 0.8))
	mb.add_box(_iron_m(), M.xf(M.v3(Vector2(82.0, 2.0), 28.2)), Vector3(45.0, 1.0, 1.0), 0.5)
	# the prison: a stepped drum, its upper drum narrower, an iron cage crown
	mb.add_cylinder(_foot_m(), M.xf(M.v3(P.PRISON, 6.0)), 15.0, 13.0, 8.0, 18, 0.5, Color.WHITE, false)
	mb.add_cylinder(_wall_m(), M.xf(M.v3(P.PRISON, 14.0)), 13.0, 12.6, 22.0, 18, 0.5, Color.WHITE, false)
	mb.add_cylinder(_dark_m(), M.xf(M.v3(P.PRISON, 36.0)), 13.4, 13.4, 1.2, 18, 0.5)
	mb.add_cylinder(_wall_m(), M.xf(M.v3(P.PRISON, 37.2)), 9.5, 9.0, 12.0, 16, 0.5, Color.WHITE, true)
	M.cyl(cols, M.v3(P.PRISON, 6.0), 13.4, 43.2)
	for k in range(16):
		var a := TAU * k / 16.0
		var p := P.PRISON + Vector2(cos(a), sin(a)) * 9.2
		mb.add_box(_iron_m(), M.xf(M.v3(p, 49.2 + 2.0)), Vector3(0.2, 4.0, 0.2), 0.5)
	mb.add_cylinder(_iron_m(), M.xf(M.v3(P.PRISON, 53.2)), 9.3, 9.3, 0.3, 16, 0.5)
	for k in range(12):
		var a := TAU * k / 12.0
		for row: float in [20.0, 28.0]:
			var p := P.PRISON + Vector2(cos(a), sin(a)) * 12.75
			mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.06)), M.xf(M.v3(p, row), -a), Vector3(0.14, 1.4, 0.5), 1.0, Color.WHITE, false)
	# the signal spire: an iron lattice, a lamp room with a red light
	for cn: Vector2 in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(2.5, 2.5), Vector2(-2.5, 2.5)]:
		_block(mb, cols, _iron_m(), M.xf(M.v3(P.SPIRE + cn, 30.0 + 18.0)), Vector3(0.5, 36.0, 0.5))
	for k in range(6):
		mb.add_box(_iron_m(), M.xf(M.v3(P.SPIRE, 30.0 + 4.0 + k * 6.0)), Vector3(5.6, 0.3, 5.6), 0.5)
	mb.add_box(_dark_m(), M.xf(M.v3(P.SPIRE, 30.0 + 38.0)), Vector3(4.0, 3.0, 4.0), 0.5)
	mb.add_box(_fire_m(), M.xf(M.v3(P.SPIRE, 30.0 + 40.0)), Vector3(1.4, 1.0, 1.4), 1.0, Color.WHITE, false)
	CapitalShell._piece(out, "Buildings", mb, cols, FAR, true)


## A barracks-like hall on rect r at floor y, `tall` high: dark-footed grey stone, a flat roof with a parapet and
## iron rail, rows of slit windows on its long sides, two iron stacks.
static func _hall(mb: MeshBuilder, cols: Array, r: Rect2, y: float, tall: float) -> void:
	var c := r.get_center()
	_block(mb, cols, _wall_m(), M.xf(M.v3(c, y + tall * 0.5 - 1.0)), Vector3(r.size.x, tall + 2.0, r.size.y))
	mb.add_box(_foot_m(), M.xf(M.v3(c, y + 0.5)), Vector3(r.size.x + 0.5, 1.4, r.size.y + 0.5), 0.5)
	mb.add_box(_dark_m(), M.xf(M.v3(c, y + tall + 0.5)), Vector3(r.size.x + 0.8, 1.0, r.size.y + 0.8), 0.5)
	for s: float in [-1.0, 1.0]:
		mb.add_box(_iron_m(), M.xf(M.v3(c + Vector2(0, s * (r.size.y * 0.5 + 0.2)), y + tall + 1.6)), Vector3(r.size.x, 0.12, 0.12), 0.5)
		var n := int(r.size.x / 3.0)
		for k in range(n):
			var x := r.position.x + (k + 0.5) * r.size.x / n
			for row: float in [0.35, 0.7]:
				mb.add_box(PSXMat.flat(Color(0.05, 0.05, 0.06)), M.xf(M.v3(Vector2(x, c.y + s * (r.size.y * 0.5 + 0.02)), y + tall * row)), Vector3(0.4, 1.4, 0.1), 1.0, Color.WHITE, false)
	for k: float in [-1.0, 1.0]:
		var sp := c + Vector2(k * r.size.x * 0.3, 0)
		mb.add_cylinder(_iron_m(), M.xf(M.v3(sp, y + tall + 1.0)), 0.6, 0.6, 4.0, 8, 0.5)


# --------------------------------------------------------------------------
# The Verdict
# --------------------------------------------------------------------------
## The colossal spire over the keep (docs/art/stronghold_reference.webp; its plateau at the keep district's height):
## a stepped base the size of a city block, then two square towers side by side with a narrow cleft between them,
## and high up a full circle cut out where they meet (VERDICT_RING), the towers going on above it to flat crowns with
## lantern fires. Iron ribs up every face, lit windows, banners on the base, buttress towers at its corners, a red
## fire hanging in the circle on chains. The tallest thing in the sea, seen from far out.
static func _verdict(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var y0: float = P.DISTRICTS[4][2]
	var c := P.KEEP
	var below := y0
	for st in SPIRE_STAGES:
		var hw: float = st[0]
		var top: float = y0 + float(st[1])
		_block(mb, cols, _dark_m() if below == y0 else _wall_m(), M.xf(M.v3(c, (below + top) * 0.5 - (2.0 if below == y0 else 0.0))), Vector3(hw * 2.0, top - below + (4.0 if below == y0 else 0.0), hw * 2.0))
		mb.add_box(_dark_m(), M.xf(M.v3(c, top + 0.6)), Vector3(hw * 2.0 + 1.6, 1.2, hw * 2.0 + 1.6), 0.5)
		_ribs(mb, c, hw, hw, below, top)
		below = top
	var hw0: float = SPIRE_STAGES[0][0]
	for cn: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_tower(mb, cols, c + cn * (hw0 + 3.0), y0, 8.0, float(SPIRE_STAGES[0][1]) + 14.0, cn)
	for f: Vector2 in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]:
		_banner(mb, c + f * (hw0 + 0.12), y0 + float(SPIRE_STAGES[0][1]) - 2.0, f, 10.0, 22.0)
	# the twin towers: each in slices across its width, the slices near the cleft cut by the circle
	var tw: float = TWINS[0]
	var td: float = TWINS[1]
	var gap: float = TWINS[2]
	var ttop: float = y0 + float(TWINS[3])
	var ry: float = y0 + float(VERDICT_RING[0])
	var rr: float = VERDICT_RING[1]
	var n := 16
	for s: float in [-1.0, 1.0]:
		var x_in := gap * 0.5
		var mid := s * (x_in + tw * 0.5)
		# (the left one the taller, as in the reference: two towers, not one)
		var top_s := ttop - (0.0 if s < 0.0 else 14.0)
		M.box(cols, M.xf(M.v3(c + Vector2(mid, 0), (below + ry - rr) * 0.5)), Vector3(tw, ry - rr - below, td))
		for k in range(n):
			var xa := x_in + k * tw / n
			var xm := xa + tw / n * 0.5
			var q := c + Vector2(s * xm, 0)
			var size_x := tw / n + 0.02
			if xm < rr:
				var h := sqrt(rr * rr - xm * xm)
				mb.add_box(_wall_m(), M.xf(M.v3(q, (below + ry - h) * 0.5)), Vector3(size_x, ry - h - below, td), 0.5)
				mb.add_box(_wall_m(), M.xf(M.v3(q, (ry + h + top_s) * 0.5)), Vector3(size_x, top_s - ry - h, td), 0.5)
			else:
				mb.add_box(_wall_m(), M.xf(M.v3(q, (below + top_s) * 0.5)), Vector3(size_x, top_s - below, td), 0.5)
		M.box(cols, M.xf(M.v3(c + Vector2(mid, 0), (ry + rr + top_s) * 0.5)), Vector3(tw, top_s - ry - rr, td))
		_ribs(mb, c + Vector2(mid, 0), tw * 0.5, td * 0.5, below, ry - rr)
		_ribs(mb, c + Vector2(mid, 0), tw * 0.5, td * 0.5, ry + rr, top_s)
		# its crown: a cornice, a lantern room with merlons and a fire
		var tc := c + Vector2(mid, 0)
		mb.add_box(_dark_m(), M.xf(M.v3(tc, top_s + 0.6)), Vector3(tw + 1.4, 1.2, td + 1.4), 0.5)
		for cn: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			mb.add_box(_dark_m(), M.xf(M.v3(tc + Vector2(cn.x * (tw * 0.5 - 0.8), cn.y * (td * 0.5 - 0.8)), top_s + 4.0)), Vector3(1.6, 6.0, 1.6), 0.5)
		mb.add_box(_dark_m(), M.xf(M.v3(tc, top_s + 7.4)), Vector3(tw + 0.8, 1.0, td + 0.8), 0.5)
		mb.add_box(_fire_m(), M.xf(M.v3(tc, top_s + 2.2)), Vector3(2.4, 2.0, 2.4), 1.0, Color.WHITE, false)
		# lit windows in columns up the outer faces
		for row in range(8):
			var wy := below + 10.0 + row * (top_s - below - 20.0) / 7.0
			if absf(wy - ry) < rr + 2.0:
				continue
			for face: float in [-1.0, 1.0]:
				mb.add_box(_window_m(), M.xf(M.v3(tc + Vector2(0, face * (td * 0.5 + 0.03)), wy)), Vector3(1.2, 2.2, 0.1), 1.0, Color.WHITE, false)
	# the circle's rim in iron, round both towers' cut faces, and the fire hanging in it on chains from its top
	for k in range(24):
		var a := TAU * k / 24.0
		var p := Vector2(cos(a) * rr, 0)
		if absf(p.x) < gap * 0.5:
			continue
		mb.add_box(_iron_m(), M.xf(M.v3(c + p, ry + sin(a) * rr)), Vector3(1.0, 1.0, td + 0.4), 0.5)
	var fy := ry - 2.0
	mb.add_box(_iron_m(), M.xf(M.v3(c, fy)), Vector3(4.0, 4.0, 4.0), 0.5)
	mb.add_box(_fire_m(), M.xf(M.v3(c, fy + 0.5)), Vector3(3.2, 3.8, 3.2), 1.0, Color.WHITE, false)
	for s: float in [-1.0, 1.0]:
		var a3 := M.v3(c + Vector2(s * rr * 0.7, 0), ry + rr * 0.7)
		var b3 := M.v3(c + Vector2(s * 1.8, 0), fy + 2.0)
		mb.add_box(_iron_m(), Transform3D(Basis.looking_at(b3 - a3, Vector3.UP), (a3 + b3) * 0.5), Vector3(0.3, 0.3, a3.distance_to(b3)), 0.5)
	CapitalShell._piece(out, "Verdict", mb, cols, FAR, true)


## Iron ribs up the four faces of a block (half sizes hx, hz round c) from y0 to y1.
static func _ribs(mb: MeshBuilder, c: Vector2, hx: float, hz: float, y0: float, y1: float) -> void:
	if y1 - y0 < 0.5:
		return
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		for k: float in [-0.6, 0.0, 0.6]:
			var o := Vector2(f.x * (hx + 0.1) - f.y * hx * k, f.y * (hz + 0.1) + f.x * hz * k)
			mb.add_box(_iron_m(), M.xf(M.v3(c + o, (y0 + y1) * 0.5)), Vector3(0.5 if absf(f.x) > 0.5 else 0.7, y1 - y0, 0.7 if absf(f.x) > 0.5 else 0.5), 0.5, Color.WHITE, false)


# --------------------------------------------------------------------------
# The reference's details (docs/art/stronghold_reference.webp)
# --------------------------------------------------------------------------
## Is p within pad of a way's line?
static func _near_way(p: Vector2, pad: float) -> bool:
	for w in P.WAYS:
		var wa: Vector2 = w[1]
		var wb: Vector2 = w[2]
		var ab := wb - wa
		var u := clampf((p - wa).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(wa + ab * u) < float(w[3]) + pad:
			return true
	return false


static func _window_m() -> Material:
	return PSXMat.glow(Color(1.0, 0.68, 0.32), 1.4)


## The face of a square block that looks most along d: (1,0), (-1,0), (0,1) or (0,-1).
static func _face(d: Vector2) -> Vector2:
	return Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y) if d.y != 0.0 else 1.0)


## A tall square tower w across, h over floor y0 (its foot down to the rock or sea outside it): a block on a black-rock
## footing, a cornice, an open lantern room on top (corner piers, a slab roof with merlons, a fire inside), lit windows
## high on every face, a banner with the emblem on its outward face.
static func _tower(mb: MeshBuilder, cols: Array, c: Vector2, y0: float, w: float, h: float, out_dir: Vector2) -> void:
	var foot := minf(y0 - 4.0, P.terrain(c + out_dir * (w * 0.5 + 2.0)) - 1.0)
	mb.add_box(_foot_m(), M.xf(M.v3(c, (foot + y0) * 0.5 - 0.5)), Vector3(w + 1.6, y0 - foot + 1.0, w + 1.6), 0.5)
	_block(mb, cols, _wall_m(), M.xf(M.v3(c, (foot + y0 + h) * 0.5)), Vector3(w, y0 + h - foot, w))
	var top := y0 + h
	mb.add_box(_dark_m(), M.xf(M.v3(c, top + 0.4)), Vector3(w + 1.0, 0.8, w + 1.0), 0.5)
	var lh := 4.2
	var hw := w * 0.5 - 0.6
	for cn: Vector2 in [Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)]:
		mb.add_box(_dark_m(), M.xf(M.v3(c + cn, top + 0.8 + lh * 0.5)), Vector3(1.2, lh, 1.2), 0.5)
		mb.add_box(_wall_m(), M.xf(M.v3(c + cn * 1.08, top + 0.8 + lh + 1.4)), Vector3(1.2, 1.4, 1.2), 0.5)
	mb.add_box(_dark_m(), M.xf(M.v3(c, top + 0.8 + lh + 0.35)), Vector3(w + 0.6, 0.7, w + 0.6), 0.5)
	mb.add_box(_fire_m(), M.xf(M.v3(c, top + 1.4)), Vector3(1.4, 1.1, 1.4), 1.0, Color.WHITE, false)
	# lit windows high up, a row or two on each face
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var along := Vector2(-f.y, f.x)
		for row: float in [0.7, 0.86]:
			for k: float in [-0.22, 0.22]:
				if posmod(hash([c.round(), f, row, k]), 3) == 0:
					continue
				var p := c + f * (w * 0.5 + 0.03) + along * w * k
				mb.add_box(_window_m(), M.xf(M.v3(p, y0 + h * row), M.yaw_of(along)), Vector3(0.1, 1.5, 0.8), 1.0, Color.WHITE, false)
	var bf := _face(out_dir)
	_banner(mb, c + bf * (w * 0.5 + 0.12), top - 1.5, bf, w * 0.62, minf(h * 0.45, 12.0))


## A blue banner with the Admiralty's emblem (a ring with a staff and a bar through it) hung flat on a wall: its top
## middle at frame point at, height top_y, facing f (bw wide, bh long), on an iron rod.
static func _banner(mb: MeshBuilder, at: Vector2, top_y: float, f: Vector2, bw: float, bh: float) -> void:
	var along := Vector2(-f.y, f.x)
	var yaw := M.yaw_of(along)
	mb.add_box(_iron_m(), M.xf(M.v3(at + f * 0.05, top_y + 0.1), yaw), Vector3(0.12, 0.12, bw + 0.6), 0.5)
	mb.add_box(PSXMat.lit("cloth_blue", Color(0.5, 0.58, 1.0)), M.xf(M.v3(at, top_y - bh * 0.5), yaw), Vector3(0.06, bh, bw), 0.5, Color.WHITE, false)
	var pale := PSXMat.flat(Color(0.82, 0.86, 0.96))
	var o := at + f * 0.05
	var ring_y := top_y - bh * 0.32
	var rr := bw * 0.24
	for k in range(14):
		var a := TAU * k / 14.0
		mb.add_box(pale, M.xf(M.v3(o + along * cos(a) * rr, ring_y + sin(a) * rr), yaw), Vector3(0.05, 0.22, 0.22), 1.0, Color.WHITE, false)
	mb.add_box(pale, M.xf(M.v3(o, ring_y - bh * 0.12), yaw), Vector3(0.05, bh * 0.62, 0.2), 1.0, Color.WHITE, false)
	mb.add_box(pale, M.xf(M.v3(o, ring_y), yaw), Vector3(0.05, 0.2, bw * 0.62), 1.0, Color.WHITE, false)


## A torch: an iron post with a fire basket, its foot on frame point p at height y.
static func _torch(mb: MeshBuilder, p: Vector2, y: float) -> void:
	mb.add_box(_iron_m(), M.xf(M.v3(p, y + 0.8)), Vector3(0.16, 1.6, 0.16), 0.5)
	mb.add_box(_iron_m(), M.xf(M.v3(p, y + 1.7)), Vector3(0.5, 0.3, 0.5), 0.5)
	mb.add_box(_fire_m(), M.xf(M.v3(p, y + 2.0)), Vector3(0.36, 0.5, 0.36), 1.0, Color.WHITE, false)


## The Landing's harbour works: two timber docks out from the quay on piles, iron cranes with crates hanging off their
## jibs over the water, and stacks of crates and barrels along the quay.
static func _harbour(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var wood := PSXMat.lit("planks_dark")
	var deck_y := P.QUAY_Y - 0.15
	for x: float in [-36.0, 46.0]:
		var z0 := P.FRONT_Z
		var z1 := P.FRONT_Z + 20.0
		_block(mb, cols, wood, M.xf(M.v3(Vector2(x, (z0 + z1) * 0.5), deck_y)), Vector3(4.0, 0.3, z1 - z0))
		var z := z0 + 2.0
		while z < z1:
			for s: float in [-1.0, 1.0]:
				mb.add_box(wood, M.xf(M.v3(Vector2(x + s * 1.8, z), deck_y - 3.0)), Vector3(0.4, 6.0, 0.4), 0.5)
			z += 4.0
	for e in [[Vector2(-22.0, 54.0), 1.0], [Vector2(36.0, 54.0), -1.0]]:
		var base: Vector2 = e[0]
		var mast := 16.0
		_block(mb, cols, _iron_m(), M.xf(M.v3(base, P.QUAY_Y + mast * 0.5)), Vector3(1.0, mast, 1.0))
		mb.add_box(_foot_m(), M.xf(M.v3(base, P.QUAY_Y + 0.6)), Vector3(3.0, 1.2, 3.0), 0.5)
		# the jib out over the water, a stay back to the mast's top, a chain down to a crate
		var tip := base + Vector2(float(e[1]) * 3.0, 12.0)
		var a3 := M.v3(base, P.QUAY_Y + mast - 1.0)
		var b3 := M.v3(tip, P.QUAY_Y + mast - 2.5)
		mb.add_box(_iron_m(), Transform3D(Basis.looking_at(b3 - a3, Vector3.UP), (a3 + b3) * 0.5), Vector3(0.6, 0.8, a3.distance_to(b3) + 0.5), 0.5)
		mb.add_box(_iron_m(), M.xf(M.v3(tip, P.QUAY_Y + mast - 6.0)), Vector3(0.12, 7.0, 0.12), 0.5)
		mb.add_box(wood, M.xf(M.v3(tip, P.QUAY_Y + mast - 10.5)), Vector3(2.0, 2.0, 2.0), 0.5, Color(0.8, 0.7, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2710
	for k in range(14):
		var p := Vector2(rng.randf_range(-54.0, 54.0), rng.randf_range(40.0, 52.0))
		if absf(p.x) < 10.0:
			continue
		var tall := rng.randi_range(1, 3)
		for j in range(tall):
			_block(mb, cols, wood, M.xf(M.v3(p, P.QUAY_Y + 0.5 + j * 1.0), rng.randf_range(-0.2, 0.2)), Vector3(1.0, 1.0, 1.0), Color(0.75, 0.68, 0.56))
	CapitalShell._piece(out, "Harbour", mb, cols, FAR, true)
