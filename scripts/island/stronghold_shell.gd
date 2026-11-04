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
## The rooms' lanterns from the last build: [frame Vector3, range] (StrongholdIsland lights them).
static var lights: Array = []
## The Verdict: its stepped base ([half width, top over the keep's plateau]), its twin towers (each one's width, its
## depth, the cleft between them, their tops) and the circle cut where they meet (its middle's height, its radius).
const SPIRE_STAGES := [[24.0, 32.0], [19.0, 50.0]]
const TWINS := [16.0, 18.0, 6.0, 185.0]
const VERDICT_RING := [140.0, 13.0]
## The sea gate: how far out in front of the harbour, and the passage between its towers (centred on the berth).
const SEA_GATE_Z := 96.0
const SEA_GATE_GAP := 26.0


static func build(build_ms: Dictionary) -> Array:
	var out: Array = []
	lights.clear()
	for step in [["paving", _paving], ["harbour", _harbour], ["ways", _ways], ["walls", _walls], ["buildings", _buildings], ["verdict", _verdict], ["viaducts", _viaducts], ["sea gate", _sea_gate]]:
		var t0 := Time.get_ticks_usec()
		step[1].call(out)
		build_ms[step[0]] = (Time.get_ticks_usec() - t0) / 1000.0
	return out


# --------------------------------------------------------------------------
# The palette
# --------------------------------------------------------------------------
## (1.30 round 7, Marineford / Enies Lobby) white dressed stone, navy trim, gold fittings, blue glazed roofs: the stone
## tints all fold into one surface (fold_tints), the metal's too.
static func _wall_m() -> Material:
	return PSXMat.lit("admiralty_stone", Color(1.0, 1.0, 1.0))


static func _dark_m() -> Material:
	return PSXMat.lit("admiralty_stone", Color(0.8, 0.83, 0.88))


static func _trim_m() -> Material:
	return PSXMat.lit("admiralty_stone", Color(0.2, 0.28, 0.56))


static func _soot_m() -> Material:
	return PSXMat.lit("admiralty_stone", Color(0.34, 0.34, 0.37))


static func _foot_m() -> Material:
	return PSXMat.lit("admiralty_stone", Color(0.66, 0.7, 0.76))


static func _flag_m() -> Material:
	return PSXMat.lit("admiralty_paving", Color(0.95, 0.96, 0.98))


static func _roof_m() -> Material:
	return PSXMat.lit("admiralty_roof")


static func _gold_m() -> Material:
	return PSXMat.lit("metal", Color(1.0, 0.8, 0.36))


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
## The districts' cobbles over a floor box each (1.30: the 3 m terrain grid sagged at their edges and captains fell
## through), a black-rock kerb round the quay's sea edge.
static func _paving(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var cob := _flag_m()
	for d in P.DISTRICTS:
		var r: Rect2 = d[1]
		M.box(cols, M.xf(M.v3(r.get_center(), float(d[2]) - 0.75)), Vector3(r.size.x, 1.5, r.size.y))
		var y: float = float(d[2]) + 0.03
		mb.add_quad(cob, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y),
			Vector2.ZERO, Vector2(r.size.x * 0.25, 0), Vector2(r.size.x * 0.25, r.size.y * 0.25), Vector2(0, r.size.y * 0.25), Color.WHITE, Vector3.UP)
	mb.add_box(_foot_m(), M.xf(M.v3(Vector2(0, P.FRONT_Z - 0.4), P.QUAY_Y - 2.2)), Vector3(112.0, 4.6, 0.8), 0.5)
	# the quay's coping in navy-trimmed white, and a border course of darker slabs round each district's floor
	mb.add_box(_trim_m(), M.xf(M.v3(Vector2(0, P.FRONT_Z - 0.35), P.QUAY_Y + 0.06)), Vector3(112.0, 0.14, 0.9), 0.5, Color.WHITE, false)
	for d in P.DISTRICTS:
		var r: Rect2 = (d[1] as Rect2).grow(-0.6)
		var y: float = float(d[2]) + 0.05
		for e in [[Vector2(r.get_center().x, r.position.y), Vector3(r.size.x, 0.04, 1.2)], [Vector2(r.get_center().x, r.end.y), Vector3(r.size.x, 0.04, 1.2)],
				[Vector2(r.position.x, r.get_center().y), Vector3(1.2, 0.04, r.size.y)], [Vector2(r.end.x, r.get_center().y), Vector3(1.2, 0.04, r.size.y)]]:
			mb.add_box(_flag_m(), M.xf(M.v3(e[0], y)), e[1], 0.5, Color(0.72, 0.76, 0.84), true)
	CapitalShell._piece(out, "Paving", mb, cols, FAR, false)


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
			mb.add_box(_trim_m(), side * Transform3D(Basis(), Vector3(0, 0.66, 0)), Vector3(1.0, 0.14, a3.distance_to(b3) + 0.7), 0.5)
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
				# (nor over the sewer drain's mouth)
				if m.distance_to(P.DRAIN) < 10.0:
					continue
				# (never into a room: its windows and stone would stand inside the hall)
				if P.ROOMS.any(func(rm): return (rm[2] as Rect2).grow(1.0).intersects(Rect2(m - Vector2(4, 4), Vector2(8, 8)))):
					continue
				var side := Vector2(-(b - a).y, (b - a).x).normalized()
				if side.dot(m - (d[1] as Rect2).get_center()) < 0.0:
					side = -side
				_tower(mb, cols, m, y, 6.0, 18.0 + float(posmod(hash(m.round()), 12)), side)
	_drain(mb, cols)
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
	# (1.30 round 7) a navy band under the walk with a gold line through it, a navy plinth course over the footing
	mb.add_box(_trim_m(), M.xf(M.v3(c, y + h - 0.6), yaw), Vector3(t + 0.2, 0.9, L + 0.2), 0.5, Color.WHITE, false)
	mb.add_box(_gold_m(), M.xf(M.v3(c, y + h - 0.6), yaw), Vector3(t + 0.26, 0.12, L + 0.2), 1.0, Color.WHITE, false)
	mb.add_box(_trim_m(), M.xf(M.v3(c, low + 3.2), yaw), Vector3(t + 1.1, 0.5, L + 0.3), 0.5, Color(0.8, 0.8, 0.8), false)
	# (1.30 round 7) relief: buttresses down the outer face, pilasters on the inner, framed slits between
	var outn := n if P.terrain(c + n * 3.0) < P.terrain(c - n * 3.0) else -n
	var face := t * 0.5
	match posmod(hash(c.round()), 4):
		0:
			var bt := y + h - 1.6
			_block(mb, cols, _wall_m(), M.xf(M.v3(c + outn * (face + 0.7), (low + bt) * 0.5), yaw), Vector3(1.4, bt - low, 1.3))
			mb.add_box(_trim_m(), M.xf(M.v3(c + outn * (face + 0.7), bt + 0.15), yaw), Vector3(1.6, 0.3, 1.5), 0.5)
			mb.add_box(_wall_m(), M.xf(M.v3(c + outn * (face + 1.0), (low + y) * 0.5 - 1.0), yaw), Vector3(2.0, maxf(y - low - 2.0, 0.5), 1.6), 0.5)
		1:
			var sy := y + h * 0.55
			mb.add_box(PSXMat.flat(Color(0.06, 0.07, 0.1)), M.xf(M.v3(c + outn * (face + 0.02), sy), yaw), Vector3(0.06, 1.8, 0.35), 1.0, Color.WHITE, false)
			for e in [[Vector3(0.16, 0.22, 0.95), 1.0], [Vector3(0.16, 0.22, 0.95), -1.0]]:
				mb.add_box(_dark_m(), M.xf(M.v3(c + outn * (face + 0.06), sy + float(e[1]) * 1.0), yaw), e[0], 0.5)
			for s: float in [-1.0, 1.0]:
				mb.add_box(_dark_m(), M.xf(M.v3(c + outn * (face + 0.06) + dir * s * 0.35, sy), yaw), Vector3(0.14, 2.0, 0.2), 0.5)
		2:
			if y > 10.0 and P.room_at(c - outn * (face + 2.4)) < 0:
				var pt := y + h - 1.0
				_block(mb, cols, _wall_m(), M.xf(M.v3(c - outn * (face + 0.18), (y + pt) * 0.5), yaw), Vector3(0.36, pt - y, 0.9))
				mb.add_box(_trim_m(), M.xf(M.v3(c - outn * (face + 0.22), y + 0.35), yaw), Vector3(0.46, 0.7, 1.06), 0.5)
				mb.add_box(_dark_m(), M.xf(M.v3(c - outn * (face + 0.25), pt - 0.2), yaw), Vector3(0.52, 0.4, 1.1), 0.5)
	var mn := maxi(int(L / 2.2), 1)
	for j in range(mn):
		var z := -L * 0.5 + (j + 0.5) * L / mn
		mb.add_box(_wall_m(), M.xf(M.v3(c, 0.0), yaw) * Transform3D(Basis(), Vector3(0, y + h + 0.55, z)), Vector3(t, 1.1, 1.1), 0.5)
		mb.add_box(_trim_m(), M.xf(M.v3(c, 0.0), yaw) * Transform3D(Basis(), Vector3(0, y + h + 1.17, z)), Vector3(t + 0.12, 0.14, 1.22), 0.5)


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
	mb.add_box(_trim_m(), M.xf(M.v3(c, y0 + 0.4)), Vector3(w + 0.3, 0.8, w + 0.3), 0.5)
	for s in range(4):
		var f: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][s]
		for row: float in [0.45, 0.72]:
			mb.add_box(_window_m(), M.xf(M.v3(c + f * (w * 0.5 + 0.03), y0 + h * row), M.yaw_of(Vector2(-f.y, f.x))), Vector3(0.1, 1.6, 0.7), 1.0, Color.WHITE, false)
	_cap(mb, c, y0 + h, w, h > 20.0)


## A gatehouse across a way at frame point c, its floor y: two square towers either side of an opening `gap` wide and
## h - 5 high under a lintel, a raised iron portcullis in it. (1.30 round 7) Dressed: rusticated jambs, a voussoir
## course and a navy band over the opening, the gold crest on both faces of the lintel, merlons on it, banners down the
## towers.
static func _gate(mb: MeshBuilder, cols: Array, c: Vector2, y: float, h: float, gap: float) -> void:
	var tw := 6.0
	var th := h
	for s: float in [-1.0, 1.0]:
		var tc := c + Vector2(s * (gap * 0.5 + tw * 0.5), 0)
		_tower_square(mb, cols, tc, y, tw, th)
		for f: float in [-1.0, 1.0]:
			_banner(mb, tc + Vector2(0, f * (tw * 0.5 + 0.02)), y + th - 1.5, Vector2(0, f), tw * 0.56, minf(th * 0.55, 12.0))
		# rusticated jambs: stones set proud up the opening's sides, every other one navy-banded
		for k in range(int((h - 5.0) / 0.9)):
			var jy := y + 0.45 + k * 0.9
			var jx := c.x + s * (gap * 0.5 + 0.12)
			for f: float in [-1.0, 1.0]:
				var jw := 1.4 if k % 2 == 0 else 0.9
				mb.add_box(_wall_m() if k % 4 != 3 else _trim_m(), M.xf(Vector3(jx + s * jw * 0.5 - s * 0.3, jy, c.y + f * (tw * 0.5 + 0.06))), Vector3(jw, 0.8, 0.14), 0.5)
	var lt := y + h - 5.0
	var top := y + th
	_block(mb, cols, _dark_m(), M.xf(M.v3(c, (lt + top) * 0.5)), Vector3(gap + 0.4, top - lt, tw))
	mb.add_box(_trim_m(), M.xf(M.v3(c, lt + 0.5)), Vector3(gap + 0.5, 1.0, tw + 0.2), 0.5)
	mb.add_box(_gold_m(), M.xf(M.v3(c, lt + 1.05)), Vector3(gap + 0.5, 0.14, tw + 0.24), 1.0)
	mb.add_box(_trim_m(), M.xf(M.v3(c, top + 0.4)), Vector3(gap + 0.6, 0.8, tw + 1.0), 0.5)
	for f: float in [-1.0, 1.0]:
		_crest(mb, c + Vector2(0, f * (tw * 0.5 + 0.02)), (lt + 1.2 + top) * 0.5, Vector2(0, f), minf(gap * 0.32, (top - lt - 1.2) * 0.46))
		# a voussoir course over the opening: wedge stones fanned along the lintel's foot
		var nv := int(gap / 0.8)
		for k in range(nv):
			var x := -gap * 0.5 + (k + 0.5) * gap / nv
			var tilt := clampf(x / (gap * 0.5), -1.0, 1.0) * 0.25
			mb.add_box(_wall_m() if k % 2 == 0 else _dark_m(), Transform3D(Basis(Vector3.BACK, -tilt), M.v3(c + Vector2(x, f * (tw * 0.5 + 0.08)), lt + 0.55)), Vector3(0.7, 1.1, 0.16), 0.5)
	# merlons along the lintel's top between the towers
	var n := int(gap / 2.2)
	for k in range(n):
		var x := -gap * 0.5 + (k + 0.5) * gap / n
		for f: float in [-1.0, 1.0]:
			mb.add_box(_wall_m(), M.xf(M.v3(c + Vector2(x, f * (tw * 0.5 - 0.4)), top + 1.3)), Vector3(1.1, 1.2, 0.8), 0.5)
			mb.add_box(_trim_m(), M.xf(M.v3(c + Vector2(x, f * (tw * 0.5 - 0.4)), top + 1.97)), Vector3(1.22, 0.14, 0.92), 0.5)
	# the portcullis, raised into the lintel's underside
	var bars := int(gap / 0.9)
	for k in range(bars + 1):
		var x := -gap * 0.5 + k * gap / bars
		mb.add_box(_iron_m(), M.xf(M.v3(c + Vector2(x, 0), lt - 1.2)), Vector3(0.14, 2.6, 0.14), 0.5)
	mb.add_box(_iron_m(), M.xf(M.v3(c, lt - 2.4)), Vector3(gap, 0.16, 0.16), 0.5)


## The edge from a to b cut where a way crosses it: the runs left.
static func _gapped(a: Vector2, b: Vector2) -> Array:
	var runs: Array = [[a]]
	var n := int(a.distance_to(b) / 2.0)
	for k in range(1, n + 1):
		var p := a.lerp(b, float(k) / n)
		var gap := false
		# (the sewer drain's mouth in the prison's west wall, over the cove: built by _drain)
		if p.distance_to(P.DRAIN) < 3.0:
			gap = true
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
	# the rooms you walk into (StrongholdPlan.ROOMS; the Command Hall is the Verdict's base, built there)
	for rm in P.ROOMS:
		if str(rm[0]) != "command":
			_room(mb, cols, rm)
			_furnish(mb, cols, rm)
	# the foundry's chimneys: tapering round stacks banded with iron, their mouths glowing
	for p: Vector2 in [Vector2(74.0, -32.0), Vector2(92.0, -32.0)]:
		mb.add_cylinder(_soot_m(), M.xf(M.v3(p, 14.0)), 2.6, 1.8, 34.0, 12, 0.5, Color.WHITE, false)
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
	mb.add_cylinder(_trim_m(), M.xf(M.v3(P.PRISON, 36.0)), 13.4, 13.4, 1.2, 18, 0.5)
	mb.add_cylinder(_gold_m(), M.xf(M.v3(P.PRISON, 35.9)), 13.45, 13.45, 0.16, 18, 1.0)
	mb.add_cylinder(_trim_m(), M.xf(M.v3(P.PRISON, 14.0)), 13.1, 13.1, 0.8, 18, 0.5)
	mb.add_cylinder(_trim_m(), M.xf(M.v3(P.PRISON, 48.4)), 9.7, 9.7, 0.8, 16, 0.5)
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
		if below == y0:
			# the first stage hollow: the Command Hall, its ceiling the stage's top
			_room(mb, cols, P.ROOMS[3], top)
			_furnish(mb, cols, P.ROOMS[3])
		else:
			_block(mb, cols, _wall_m(), M.xf(M.v3(c, (below + top) * 0.5)), Vector3(hw * 2.0, top - below, hw * 2.0))
		mb.add_box(_trim_m(), M.xf(M.v3(c, top + 0.6)), Vector3(hw * 2.0 + 1.6, 1.2, hw * 2.0 + 1.6), 0.5)
		mb.add_box(_gold_m(), M.xf(M.v3(c, top + 0.1)), Vector3(hw * 2.0 + 1.66, 0.16, hw * 2.0 + 1.66), 1.0)
		_ribs(mb, c, hw, hw, below, top)
		below = top
	var hw0: float = SPIRE_STAGES[0][0]
	for cn: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_tower(mb, cols, c + cn * (hw0 + 4.6), y0, 8.0, float(SPIRE_STAGES[0][1]) + 14.0, cn)
	for f: Vector2 in [Vector2(1, 0), Vector2(-1, 0)]:
		_banner(mb, c + f * (hw0 + 0.12), y0 + float(SPIRE_STAGES[0][1]) - 2.0, f, 10.0, 22.0)
	# (either side of the Command Hall's door, not over it)
	for s: float in [-1.0, 1.0]:
		_banner(mb, c + Vector2(s * 13.0, hw0 + 0.12), y0 + float(SPIRE_STAGES[0][1]) - 2.0, Vector2(0, 1), 8.0, 20.0)
	# (1.30 round 7) the crest over the Command Hall's door, and on the second stage's four faces
	_crest(mb, c + Vector2(0, hw0 + 0.02), y0 + 18.0, Vector2(0, 1), 4.6)
	var hw1: float = SPIRE_STAGES[1][0]
	for f: Vector2 in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
		_crest(mb, c + f * (hw1 + 0.02), y0 + (float(SPIRE_STAGES[0][1]) + float(SPIRE_STAGES[1][1])) * 0.5 + 1.0, f, 5.5)
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
		mb.add_box(_trim_m(), M.xf(M.v3(tc, top_s + 0.6)), Vector3(tw + 1.4, 1.2, td + 1.4), 0.5)
		mb.add_box(_gold_m(), M.xf(M.v3(tc, top_s + 0.08)), Vector3(tw + 1.46, 0.16, td + 1.46), 1.0)
		for cn: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			mb.add_box(_wall_m(), M.xf(M.v3(tc + Vector2(cn.x * (tw * 0.5 - 0.8), cn.y * (td * 0.5 - 0.8)), top_s + 4.0)), Vector3(1.6, 6.0, 1.6), 0.5)
		mb.add_box(_trim_m(), M.xf(M.v3(tc, top_s + 7.4)), Vector3(tw + 0.8, 1.0, td + 0.8), 0.5)
		mb.add_box(_fire_m(), M.xf(M.v3(tc, top_s + 2.2)), Vector3(2.4, 2.0, 2.4), 1.0, Color.WHITE, false)
		# (1.30 round 7) merlons round the crown's slab, a gold staff and the Admiralty's flag over it
		for k in range(6):
			for f: float in [-1.0, 1.0]:
				var x := -tw * 0.5 + (k + 0.5) * tw / 6.0
				mb.add_box(_wall_m(), M.xf(M.v3(tc + Vector2(x, f * (td * 0.5 + 0.1)), top_s + 8.5)), Vector3(1.2, 1.2, 0.8), 0.5)
				mb.add_box(_trim_m(), M.xf(M.v3(tc + Vector2(x, f * (td * 0.5 + 0.1)), top_s + 9.17)), Vector3(1.34, 0.14, 0.94), 0.5)
		mb.add_cylinder(_gold_m(), M.xf(M.v3(tc, top_s + 7.9)), 0.18, 0.12, 12.0, 5, 1.0)
		mb.add_box_unit_uv(_banner_m(), M.xf(M.v3(tc + Vector2(s * 3.0, 0), top_s + 17.6)), Vector3(5.6, 3.6, 0.08))
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
		mb.add_box(_gold_m(), M.xf(M.v3(c + p, ry + sin(a) * rr)), Vector3(1.0, 1.0, td + 0.4), 0.5)
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
			mb.add_box(_dark_m(), M.xf(M.v3(c + o, (y0 + y1) * 0.5)), Vector3(0.5 if absf(f.x) > 0.5 else 0.9, y1 - y0, 0.9 if absf(f.x) > 0.5 else 0.5), 0.5, Color.WHITE, false)


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
	_cap(mb, c, top, w, h > 14.0)
	mb.add_box(_trim_m(), M.xf(M.v3(c, y0 + 0.4)), Vector3(w + 0.3, 0.8, w + 0.3), 0.5)
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


## (1.30 round 7) The Admiralty's banner hung flat on a wall: its top middle at frame point at, height top_y, facing f
## (bw wide, bh long), on a gold rod with finials; the picture (navy, gold border, the white gull) is admiralty_banner,
## its foot cut in a swallowtail.
static func _banner(mb: MeshBuilder, at: Vector2, top_y: float, f: Vector2, bw: float, bh: float) -> void:
	var along := Vector2(-f.y, f.x)
	var yaw := M.yaw_of(along)
	mb.add_box(_gold_m(), M.xf(M.v3(at + f * 0.08, top_y + 0.1), yaw), Vector3(0.16, 0.16, bw + 0.8), 0.5)
	for s: float in [-1.0, 1.0]:
		mb.add_box(_gold_m(), M.xf(M.v3(at + f * 0.08 + along * s * (bw * 0.5 + 0.45), top_y + 0.1), yaw), Vector3(0.3, 0.3, 0.3), 0.5)
	var body := bh * 0.86
	var t := M.xf(M.v3(at + f * 0.04, top_y - body * 0.5), M.yaw_of(f))
	mb.add_box_unit_uv(_banner_m(), t, Vector3(bw, body, 0.06))
	# the swallowtail: two navy points under the picture
	var tail := bh - body
	for s: float in [-1.0, 1.0]:
		var o := PackedVector2Array([Vector2(s * bw * 0.5, 0.0), Vector2(0.0, 0.0), Vector2(s * bw * 0.25, -tail), Vector2(s * bw * 0.5, -tail)])
		if s < 0.0:
			o.reverse()
		mb.add_extrude(_trim_m(), M.xf(M.v3(at + f * 0.04, top_y - body), M.yaw_of(f)), o, 0.06, 0.5)


static func _banner_m() -> Material:
	return PSXMat.lit("admiralty_banner", Color.WHITE, {"vertex_color": false})


## The gull of the Admiralty's crest (x -1..1, y up), as on its banners: wings spread in a shallow M.
static func gull() -> PackedVector2Array:
	var half := [Vector2(0.0, 0.30), Vector2(0.10, 0.40), Vector2(0.30, 0.52), Vector2(0.55, 0.60), Vector2(0.80, 0.56), Vector2(1.0, 0.44),
		Vector2(0.78, 0.40), Vector2(0.55, 0.38), Vector2(0.32, 0.26), Vector2(0.14, 0.12), Vector2(0.10, -0.10), Vector2(0.20, -0.36), Vector2(0.0, -0.26)]
	var o := PackedVector2Array()
	for k in range(half.size()):
		o.append(half[k])
	for k in range(half.size() - 2, 0, -1):
		o.append(Vector2(-half[k].x, half[k].y))
	o.reverse()
	return o


## The Admiralty's crest on a wall: a navy disc in a gold ring with the white gull over it, r across, its middle at frame
## point at, height y, facing f.
static func _crest(mb: MeshBuilder, at: Vector2, y: float, f: Vector2, r: float) -> void:
	var face := M.yaw_of(f)
	var disc := Basis(Vector3.UP, face) * Basis(Vector3.RIGHT, PI * 0.5)
	mb.add_cylinder(_gold_m(), Transform3D(disc, M.v3(at, y)), r, r, 0.3, 20, 0.5, Color.WHITE, true, true)
	mb.add_cylinder(_trim_m(), Transform3D(disc, M.v3(at + f * 0.3, y)), r * 0.84, r * 0.84, 0.12, 20, 0.5, Color.WHITE, true, false)
	mb.add_extrude(_wall_m(), M.xf(M.v3(at + f * 0.5, y + r * 0.05), face).scaled_local(Vector3(r * 0.78, r * 0.78, 1.0)), gull(), 0.2, 0.5, Color(1.08, 1.08, 1.1))


## A tower's crown at height top, w across (the 1.27 shape: a cornice, an open lantern room on corner piers with a fire,
## a slab roof with merlons at its corners), detailed: the cornice navy over a gold line and corbels, the piers white
## with navy caps, the merlons capped; a flagstaff with the Admiralty's flag over the taller ones.
static func _cap(mb: MeshBuilder, c: Vector2, top: float, w: float, flag: bool) -> void:
	mb.add_box(_trim_m(), M.xf(M.v3(c, top + 0.4)), Vector3(w + 1.0, 0.8, w + 1.0), 0.5)
	mb.add_box(_gold_m(), M.xf(M.v3(c, top + 0.04)), Vector3(w + 1.06, 0.12, w + 1.06), 1.0)
	var nc := maxi(int(w / 1.6), 2)
	for s in range(4):
		var f: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][s]
		var al := Vector2(-f.y, f.x)
		for k in range(nc):
			var u := -w * 0.5 + (k + 0.5) * w / nc
			mb.add_box(_wall_m(), M.xf(M.v3(c + f * (w * 0.5 + 0.2) + al * u, top - 0.35), M.yaw_of(f)), Vector3(0.4, 0.7, 0.4), 0.5)
	var lh := 4.2
	var hw := w * 0.5 - 0.6
	for cn: Vector2 in [Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)]:
		mb.add_box(_wall_m(), M.xf(M.v3(c + cn, top + 0.8 + lh * 0.5)), Vector3(1.2, lh, 1.2), 0.5)
		mb.add_box(_trim_m(), M.xf(M.v3(c + cn, top + 0.8 + lh - 0.2)), Vector3(1.4, 0.3, 1.4), 0.5)
		mb.add_box(_wall_m(), M.xf(M.v3(c + cn * 1.08, top + 0.8 + lh + 1.4)), Vector3(1.2, 1.4, 1.2), 0.5)
		mb.add_box(_trim_m(), M.xf(M.v3(c + cn * 1.08, top + 0.8 + lh + 2.17)), Vector3(1.34, 0.14, 1.34), 0.5)
	mb.add_box(_trim_m(), M.xf(M.v3(c, top + 0.8 + lh + 0.35)), Vector3(w + 0.6, 0.7, w + 0.6), 0.5)
	mb.add_box(_fire_m(), M.xf(M.v3(c, top + 1.4)), Vector3(1.4, 1.1, 1.4), 1.0, Color.WHITE, false)
	mb.add_cylinder(_iron_m(), M.xf(M.v3(c, top + 0.8)), 0.9, 1.1, 0.5, 8, 0.5)
	if flag:
		var ft := top + 0.8 + lh + 0.7
		mb.add_cylinder(_gold_m(), M.xf(M.v3(c, ft)), 0.12, 0.08, 7.0, 5, 1.0)
		mb.add_cylinder(_gold_m(), M.xf(M.v3(c, ft + 7.0)), 0.22, 0.22, 0.3, 6, 1.0)
		var fw := 3.4
		var t := Transform3D(Basis(Vector3.UP, posmod(hash(c.round()), 628) * 0.01), M.v3(c, ft + 5.8))
		mb.add_box_unit_uv(_banner_m(), t * Transform3D(Basis(), Vector3(fw * 0.5 + 0.1, 0, 0)), Vector3(fw, 2.2, 0.05))


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
	for x: float in [-36.0, 42.0]:
		var z0 := P.FRONT_Z
		var z1 := P.FRONT_Z + 10.0
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


## A walkway on arches from frame point a to b at deck height y (w wide): its deck and parapets, piers every span down
## to the rock or sea, the arches between them, and a square tower at each end rising to it.
static func _viaduct(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, y: float, w: float, end_towers := true) -> void:
	var L := a.distance_to(b)
	var dir := (b - a) / L
	var yaw := M.yaw_of(dir)
	var side := Vector2(-dir.y, dir.x)
	_block(mb, cols, _dark_m(), M.xf(M.v3((a + b) * 0.5, y - 0.6), yaw), Vector3(w, 1.2, L))
	for s: float in [-1.0, 1.0]:
		_block(mb, cols, _wall_m(), M.xf(M.v3((a + b) * 0.5 + side * s * (w * 0.5 - 0.3), y + 0.6), yaw), Vector3(0.6, 1.2, L))
	var n := maxi(int(L / 11.0), 1)
	for k in range(n + 1):
		var p := a.lerp(b, float(k) / n)
		var foot := P.terrain(p) - 1.0
		if k > 0 and k < n:
			_block(mb, cols, _wall_m(), M.xf(M.v3(p, (foot + y - 1.2) * 0.5), yaw), Vector3(w + 0.8, y - 1.2 - foot, 2.6))
			mb.add_box(_foot_m(), M.xf(M.v3(p, foot + 1.5), yaw), Vector3(w + 1.6, 3.0, 3.4), 0.5)
		if k == n:
			break
		# the arch from this pier to the next: the spandrel in slices down to its curve
		var span := L / n
		var r := span * 0.5 - 1.3
		var m := 14
		for j in range(m):
			var s := -span * 0.5 + (j + 0.5) * span / m
			var q := a.lerp(b, (k + 0.5) / n) + dir * s
			var deck := y - 1.2
			var spring := deck - 1.0 - r
			var curve := spring + sqrt(maxf(r * r - s * s, 0.0)) if absf(s) < r else maxf(P.terrain(q) - 1.0, spring - 30.0)
			if absf(s) >= r:
				curve = P.terrain(q) - 1.0
			if deck - curve > 0.05:
				mb.add_box(_wall_m(), M.xf(M.v3(q, (deck + curve) * 0.5), yaw), Vector3(w, deck - curve, span / m + 0.02), 0.5)
	if end_towers:
		for e: Vector2 in [a, b]:
			var fy := maxf(P._height_near(e), P.QUAY_Y)
			_tower(mb, cols, e - dir * 0.0, fy, w + 3.0, maxf(y - fy, 4.0) + 1.0, side)


## The viaducts of the reference: from the Arsenal and the Prison wings up to the keep's plateau at its height, and an
## arcade across the Landing between the quay's two towers, high over the quay.
static func _viaducts(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var ky: float = P.DISTRICTS[4][2]
	_viaduct(mb, cols, Vector2(66.0, -44.0), Vector2(44.0, -66.0), ky, 4.0)
	_viaduct(mb, cols, Vector2(-66.0, -44.0), Vector2(-44.0, -66.0), ky, 4.0)
	_viaduct(mb, cols, Vector2(-52.0, 58.0), Vector2(52.0, 58.0), 24.0, 4.0, false)
	CapitalShell._piece(out, "Viaducts", mb, cols, FAR, true)


## The sea gate: two towers standing in the water in front of the harbour, a lintel over the passage between them with
## its portcullis raised and chains to it, and sea walls from them back to the quay's ends: the harbour a basin you
## sail into through the gate.
static func _sea_gate(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var cols: Array = []
	var g1 := Vector2(P.BERTH.x - SEA_GATE_GAP * 0.5 - 6.0, SEA_GATE_Z)
	var g2 := Vector2(P.BERTH.x + SEA_GATE_GAP * 0.5 + 6.0, SEA_GATE_Z)
	var top := 30.0
	for g: Vector2 in [g1, g2]:
		_tower(mb, cols, g, P.QUAY_Y, 12.0, top - P.QUAY_Y, Vector2(0, 1))
	var mid := (g1 + g2) * 0.5
	var lb := top - 7.0
	_block(mb, cols, _dark_m(), M.xf(M.v3(mid, (lb + top) * 0.5)), Vector3(SEA_GATE_GAP + 1.0, top - lb, 8.0))
	mb.add_box(_trim_m(), M.xf(M.v3(mid, lb + 0.5)), Vector3(SEA_GATE_GAP + 1.1, 1.0, 8.2), 0.5)
	mb.add_box(_trim_m(), M.xf(M.v3(mid, top + 0.4)), Vector3(SEA_GATE_GAP + 1.2, 0.8, 8.6), 0.5)
	for f: float in [-1.0, 1.0]:
		_crest(mb, mid + Vector2(0, f * 4.02), (lb + 1.0 + top) * 0.5, Vector2(0, f), 2.6)
	var bars := int(SEA_GATE_GAP / 1.2)
	for k in range(bars + 1):
		var x := -SEA_GATE_GAP * 0.5 + k * SEA_GATE_GAP / bars
		mb.add_box(_iron_m(), M.xf(M.v3(mid + Vector2(x, 0), lb - 2.0)), Vector3(0.22, 4.0, 0.22), 0.5)
	mb.add_box(_iron_m(), M.xf(M.v3(mid, lb - 4.0)), Vector3(SEA_GATE_GAP, 0.3, 0.3), 0.5)
	for s: float in [-1.0, 1.0]:
		var a3 := M.v3(mid + Vector2(s * (SEA_GATE_GAP * 0.5 + 3.0), 0), top + 3.0)
		var b3 := M.v3(mid + Vector2(s * SEA_GATE_GAP * 0.4, 0), lb - 4.0)
		mb.add_box(_iron_m(), Transform3D(Basis.looking_at(b3 - a3, Vector3.UP), (a3 + b3) * 0.5), Vector3(0.3, 0.3, a3.distance_to(b3)), 0.5)
	# the sea walls back to the quay's ends
	for e in [[g1, Vector2(-58.0, P.FRONT_Z)], [g2, Vector2(58.0, P.FRONT_Z)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := int(a.distance_to(b) / 4.0)
		for k in range(n):
			_wall(mb, cols, a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), P.QUAY_Y + 2.0, 8.0)
	CapitalShell._piece(out, "SeaGate", mb, cols, FAR, true)


# --------------------------------------------------------------------------
# The rooms (StrongholdPlan.ROOMS)
# --------------------------------------------------------------------------
## A room you walk into: a flagstone floor slab, walls WALL thick round its rect with the door's gap (and a lintel)
## in the wall on its door's side, a ceiling slab from its height up to `top` (default: a hall's roof just over it),
## and outside a cornice, lit slits and iron stacks. Everything solid.
static func _room(mb: MeshBuilder, cols: Array, rm: Array, top := -1.0) -> void:
	var r: Rect2 = rm[2]
	var y: float = rm[3]
	var h: float = rm[4]
	var door: Vector2 = rm[5]
	var dw: float = rm[6]
	var t := 1.2
	var roof := top if top > 0.0 else y + h + 1.0
	var c := r.get_center()
	_block(mb, cols, _flag_m(), M.xf(M.v3(c, y - 0.25)), Vector3(r.size.x, 0.5, r.size.y))
	var dh := minf(h * 0.6, 9.0)
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var along := Vector2(-f.y, f.x)
		var yaw := M.yaw_of(along)
		var half_len := (r.size.y if absf(f.x) > 0.5 else r.size.x) * 0.5
		var wc := c + Vector2(f.x * (r.size.x * 0.5 - t * 0.5), f.y * (r.size.y * 0.5 - t * 0.5))
		if f.is_equal_approx(door):
			var piece := half_len - dw * 0.5
			for s: float in [-1.0, 1.0]:
				_block(mb, cols, _wall_m(), M.xf(M.v3(wc + along * s * (dw * 0.5 + piece * 0.5), (y - 2.0 + roof) * 0.5), yaw), Vector3(t, roof - y + 2.0, piece))
			_block(mb, cols, _dark_m(), M.xf(M.v3(wc, (y + dh + roof) * 0.5), yaw), Vector3(t, roof - y - dh, dw + 0.1))
			# the door's iron-banded frame and a torch each side, outside
			for s: float in [-1.0, 1.0]:
				_torch(mb, wc + f * 1.4 + along * s * (dw * 0.5 + 1.0), y)
		else:
			_block(mb, cols, _wall_m(), M.xf(M.v3(wc, (y - 2.0 + roof) * 0.5), yaw), Vector3(t, roof - y + 2.0, half_len * 2.0))
	if roof - y - h > 0.1:
		_block(mb, cols, _dark_m(), M.xf(M.v3(c, (y + h + roof) * 0.5)), Vector3(r.size.x, roof - y - h, r.size.y))
	if top > 0.0:
		return
	mb.add_box(_trim_m(), M.xf(M.v3(c, roof + 0.5)), Vector3(r.size.x + 0.8, 1.0, r.size.y + 0.8), 0.5)
	mb.add_box(_gold_m(), M.xf(M.v3(c, roof + 0.02)), Vector3(r.size.x + 0.86, 0.14, r.size.y + 0.86), 1.0)
	# a navy plinth course round the outside (four strips: the hall's floor inside stays clear)
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * r.size.x + absf(al.y) * r.size.y
		var e := c + Vector2(f.x * r.size.x * 0.5, f.y * r.size.y * 0.5)
		if f.is_equal_approx(door):
			for s: float in [-1.0, 1.0]:
				var pl := L * 0.5 - dw * 0.5 - 0.6
				mb.add_box(_trim_m(), M.xf(M.v3(e + f * 0.08 + al * s * (L * 0.5 - pl * 0.5), y + 0.4), M.yaw_of(al)), Vector3(0.16, 0.8, pl), 0.5)
		else:
			mb.add_box(_trim_m(), M.xf(M.v3(e + f * 0.08, y + 0.4), M.yaw_of(al)), Vector3(0.16, 0.8, L + 0.3), 0.5)
	# (1.30 round 7) a crenellated parapet round the flat roof, the stacks dressed stone with navy caps, a skylight
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * r.size.x + absf(al.y) * r.size.y
		var nm := int(L / 2.2)
		var e := c + Vector2(f.x * r.size.x * 0.5, f.y * r.size.y * 0.5)
		mb.add_box(_wall_m(), M.xf(M.v3(e, roof + 1.4), M.yaw_of(al)), Vector3(0.6, 0.8, L + 0.8), 0.5)
		for k in range(nm):
			if k % 2 == 0:
				var q := e + al * (-L * 0.5 + (k + 0.5) * L / nm)
				mb.add_box(_wall_m(), M.xf(M.v3(q, roof + 2.2), M.yaw_of(al)), Vector3(0.6, 0.8, L / nm), 0.5)
				mb.add_box(_trim_m(), M.xf(M.v3(q, roof + 2.66), M.yaw_of(al)), Vector3(0.72, 0.12, L / nm + 0.1), 0.5)
	for k: float in [-1.0, 1.0]:
		var sc := c + Vector2(k * r.size.x * 0.3, 0)
		mb.add_box(_wall_m(), M.xf(M.v3(sc, roof + 2.5)), Vector3(1.6, 3.0, 1.2), 0.5)
		mb.add_box(_trim_m(), M.xf(M.v3(sc, roof + 4.1)), Vector3(1.8, 0.2, 1.4), 0.5)
		for j: float in [-0.35, 0.35]:
			mb.add_cylinder(_soot_m(), M.xf(M.v3(sc + Vector2(j, 0), roof + 4.2)), 0.22, 0.2, 0.8, 6, 1.0)
	mb.add_box(_roof_m(), M.xf(M.v3(c, roof + 1.25)), Vector3(r.size.x * 0.4, 0.5, 3.0), 0.5)
	for f: Vector2 in [Vector2(0, -1), Vector2(0, 1)]:
		var n := int(r.size.x / 3.0)
		for k in range(n):
			var x := r.position.x + (k + 0.5) * r.size.x / n
			var wq := Vector2(x, c.y + f.y * (r.size.y * 0.5 + 0.02))
			var wy := y + h * 0.75
			mb.add_box(_window_m(), M.xf(M.v3(wq, wy)), Vector3(0.4, 1.4, 0.1), 1.0, Color.WHITE, false)
			# (1.30 round 7) its frame: a navy sill, a white hood, louvred navy shutters folded back
			mb.add_box(_trim_m(), M.xf(M.v3(wq + f * 0.1, wy - 0.82)), Vector3(1.0, 0.16, 0.3), 0.5)
			mb.add_box(_dark_m(), M.xf(M.v3(wq + f * 0.12, wy + 0.86)), Vector3(1.1, 0.3, 0.34), 0.5)
			for s: float in [-1.0, 1.0]:
				mb.add_box(_dark_m(), M.xf(M.v3(wq + f * 0.05 + Vector2(s * 0.28, 0), wy)), Vector3(0.12, 1.5, 0.1), 0.5)
				mb.add_box(_trim_m(), M.xf(M.v3(wq + f * 0.06 + Vector2(s * 0.62, 0), wy)), Vector3(0.48, 1.4, 0.06), 0.5)
				for j in range(4):
					mb.add_box(_dark_m(), M.xf(M.v3(wq + f * 0.1 + Vector2(s * 0.62, 0), wy - 0.5 + j * 0.33)), Vector3(0.44, 0.05, 0.04), 1.0)
	# (1.30 round 7) pilasters up the outer faces (between the windows), the door's frame and the crest over it
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * r.size.x + absf(al.y) * r.size.y
		var e := c + Vector2(f.x * r.size.x * 0.5, f.y * r.size.y * 0.5)
		var n := int(L / 3.0) if absf(f.y) > 0.5 else int(L / 4.0)
		# (not on a face over a narrow strip to the curtain wall: the sneaking ways behind the halls stay as wide)
		var dr: Rect2 = P.DISTRICTS[P.district_at(c)][1]
		var to_edge := (dr.end.x - e.x) * f.x + (dr.end.y - e.y) * f.y if f.x + f.y > 0.0 else (e.x - dr.position.x) * -f.x + (e.y - dr.position.y) * -f.y
		if to_edge < 4.0:
			n = 0
		for k in range(1, n):
			var u := -L * 0.5 + k * L / n
			if f.is_equal_approx(door) and absf(u) < dw * 0.5 + 0.9:
				continue
			var q := e + al * u + f * 0.18
			_block(mb, cols, _wall_m(), M.xf(M.v3(q, (y + roof) * 0.5), M.yaw_of(al)), Vector3(0.36, roof - y, 0.7))
			mb.add_box(_trim_m(), M.xf(M.v3(q + f * 0.04, y + 0.5), M.yaw_of(al)), Vector3(0.46, 1.0, 0.84), 0.5)
			mb.add_box(_dark_m(), M.xf(M.v3(q + f * 0.05, roof - 0.35), M.yaw_of(al)), Vector3(0.5, 0.5, 0.9), 0.5)
		if f.is_equal_approx(door):
			for s: float in [-1.0, 1.0]:
				_block(mb, cols, _dark_m(), M.xf(M.v3(e + al * s * (dw * 0.5 + 0.35) + f * 0.25, y + dh * 0.5), M.yaw_of(al)), Vector3(0.5, dh, 0.7))
			mb.add_box(_trim_m(), M.xf(M.v3(e + f * 0.3, y + dh + 0.4), M.yaw_of(al)), Vector3(0.6, 0.8, dw + 1.8), 0.5)
			mb.add_box(_gold_m(), M.xf(M.v3(e + f * 0.62, y + dh + 0.4), M.yaw_of(al)), Vector3(0.04, 0.12, dw + 1.8), 1.0)
			if roof - y - dh > 3.6:
				_crest(mb, e + f * 0.02, y + dh + 0.8 + minf(roof - y - dh - 1.0, 4.0) * 0.5, f, minf(roof - y - dh - 1.4, 3.6) * 0.45)


## What's in a room, by its key, and its lanterns (lights).
static func _furnish(mb: MeshBuilder, cols: Array, rm: Array) -> void:
	var r: Rect2 = (rm[2] as Rect2).grow(-1.2)
	var y: float = rm[3]
	var h: float = rm[4]
	var c := r.get_center()
	var wood := PSXMat.lit("planks_dark")
	match str(rm[0]):
		"mess":
			# three long tables along the hall with benches, a hearth on the back wall
			for z: float in [-6.0, 0.0, 6.0]:
				_block(mb, cols, wood, M.xf(M.v3(c + Vector2(-1.0, z), y + 0.8)), Vector3(14.0, 0.15, 1.6))
				for s: float in [-1.0, 1.0]:
					_block(mb, cols, wood, M.xf(M.v3(c + Vector2(-1.0, z + s * 1.4), y + 0.45)), Vector3(14.0, 0.12, 0.5))
				for x: float in [-7.0, 5.0]:
					mb.add_box(wood, M.xf(M.v3(c + Vector2(x, z), y + 0.4)), Vector3(0.2, 0.8, 1.4), 0.5)
			var hc := Vector2(r.position.x + 0.8, c.y)
			_block(mb, cols, _dark_m(), M.xf(M.v3(hc, y + 1.8)), Vector3(1.6, 3.6, 4.0))
			mb.add_box(_fire_m(), M.xf(M.v3(hc + Vector2(0.85, 0), y + 0.7)), Vector3(0.1, 1.0, 2.4), 1.0, Color.WHITE, false)
			lights.append([M.v3(c, y + h - 2.0), 16.0])
		"barracks":
			# bunks two high along both long walls
			var n := int(r.size.x / 2.6)
			for k in range(n):
				var x := r.position.x + (k + 0.5) * r.size.x / n
				for s: float in [-1.0, 1.0]:
					var b := Vector2(x, c.y + s * (r.size.y * 0.5 - 1.1))
					for lv: float in [0.5, 1.9]:
						_block(mb, cols, wood, M.xf(M.v3(b, y + lv)), Vector3(1.0, 0.2, 2.0))
					mb.add_box(wood, M.xf(M.v3(b + Vector2(0.45, 0), y + 1.2)), Vector3(0.12, 2.4, 0.12), 0.5)
			lights.append([M.v3(c, y + h - 2.0), 16.0])
		"casting":
			# pillars, a glowing channel of iron down the floor, two furnaces at the back, a crucible on a chain
			for p: Vector2 in [Vector2(-7, -7), Vector2(7, -7), Vector2(-7, 7), Vector2(7, 7)]:
				_block(mb, cols, _dark_m(), M.xf(M.v3(c + p, y + h * 0.5)), Vector3(1.6, h, 1.6))
			mb.add_box(_fire_m(), M.xf(M.v3(c, y + 0.03)), Vector3(r.size.x - 4.0, 0.06, 1.0), 1.0, Color.WHITE, false)
			for z: float in [-6.0, 6.0]:
				var fc := Vector2(r.end.x - 1.8, c.y + z)
				_block(mb, cols, _dark_m(), M.xf(M.v3(fc, y + 3.0)), Vector3(3.2, 6.0, 5.0))
				mb.add_box(_fire_m(), M.xf(M.v3(fc + Vector2(-1.65, 0), y + 1.6)), Vector3(0.1, 1.8, 2.4), 1.0, Color.WHITE, false)
			mb.add_box(_iron_m(), M.xf(M.v3(c + Vector2(4, 0), y + h - 3.0)), Vector3(0.14, 6.0, 0.14), 0.5)
			mb.add_box(_iron_m(), M.xf(M.v3(c + Vector2(4, 0), y + h - 7.0)), Vector3(2.2, 2.0, 2.2), 0.5)
			mb.add_box(_fire_m(), M.xf(M.v3(c + Vector2(4, 0), y + h - 5.95)), Vector3(1.8, 0.1, 1.8), 1.0, Color.WHITE, false)
			lights.append([M.v3(c + Vector2(-5, 0), y + h - 3.0), 20.0])
		"command":
			# a ring of pillars, the dais at the back with its seat, the war table in the middle, braziers, banners
			for k in range(10):
				var a := TAU * k / 10.0
				_block(mb, cols, _dark_m(), M.xf(M.v3(c + Vector2(cos(a), sin(a)) * 15.0, y + h * 0.5)), Vector3(2.0, h, 2.0))
			var dz := r.position.y + 4.0
			_block(mb, cols, _dark_m(), M.xf(M.v3(Vector2(c.x, dz), y + 0.6)), Vector3(14.0, 1.2, 6.0))
			_block(mb, cols, _iron_m(), M.xf(M.v3(Vector2(c.x, dz - 1.2), y + 2.6)), Vector3(2.4, 2.8, 1.0))
			_block(mb, cols, wood, M.xf(M.v3(c + Vector2(0, 4), y + 0.9)), Vector3(8.0, 0.2, 5.0))
			mb.add_box(PSXMat.lit("canvas", Color(0.85, 0.8, 0.65)), M.xf(M.v3(c + Vector2(0, 4), y + 1.02)), Vector3(7.4, 0.04, 4.4), 0.5)
			for p: Vector2 in [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9)]:
				_torch(mb, c + p, y)
			for s: float in [-1.0, 1.0]:
				_banner(mb, Vector2(c.x + s * 6.0, r.position.y - 1.08), y + h - 2.0, Vector2(0, 1), 5.0, 14.0)
			lights.append([M.v3(c, y + h - 4.0), 30.0])
			lights.append([M.v3(Vector2(c.x, dz + 2.0), y + 6.0), 14.0])


## The sewer drain over the west cove (StrongholdPlan.DRAIN): the prison's wall closes over a low stone culvert mouth,
## an iron grate across it and a dark recess behind, its trickle on the shingle. The sneaky way in (preview v2's
## "sewer"); the tunnel behind it comes with the interiors.
static func _drain(mb: MeshBuilder, cols: Array) -> void:
	var d := P.DRAIN
	var y0 := P.DRAIN_Y
	var top: float = float(P.DISTRICTS[3][2]) + 6.0
	var ow := 3.0
	var oh := 3.0
	var yaw := M.yaw_of(Vector2(0, 1))
	var low := P.terrain(d + Vector2(-3, 0)) - 1.0
	# the wall over and beside the mouth (the gap _gapped left is 6 m)
	_block(mb, cols, _wall_m(), M.xf(M.v3(d, (y0 + oh + top) * 0.5), yaw), Vector3(2.4, top - y0 - oh, 6.4))
	for s: float in [-1.0, 1.0]:
		_block(mb, cols, _wall_m(), M.xf(M.v3(d + Vector2(0, s * (ow * 0.5 + 0.9)), (low + y0 + oh) * 0.5), yaw), Vector3(2.4, y0 + oh - low, 1.8))
	_block(mb, cols, _foot_m(), M.xf(M.v3(d, (low + y0) * 0.5), yaw), Vector3(2.4, y0 - low, ow))
	# the recess: sides, roof and a dark back 2 m in
	var inn := d + Vector2(2.2, 0)
	_block(mb, cols, _dark_m(), M.xf(M.v3(inn + Vector2(1.2, 0), y0 + oh * 0.5), yaw), Vector3(0.4, oh, ow + 0.4))
	for s: float in [-1.0, 1.0]:
		_block(mb, cols, _dark_m(), M.xf(M.v3(inn + Vector2(0, s * (ow * 0.5 + 0.2)), y0 + oh * 0.5), yaw), Vector3(2.4, oh, 0.4))
	_block(mb, cols, _dark_m(), M.xf(M.v3(inn, y0 + oh + 0.2), yaw), Vector3(2.4, 0.4, ow + 0.8))
	mb.add_box(PSXMat.flat(Color(0.03, 0.03, 0.04)), M.xf(M.v3(inn + Vector2(0.95, 0), y0 + oh * 0.5), yaw), Vector3(0.05, oh - 0.2, ow - 0.2), 1.0)
	# the grate across the mouth, and stones round its arch
	for k in range(7):
		var z := -ow * 0.5 + (k + 0.5) * ow / 7.0
		_block(mb, cols, _iron_m(), M.xf(M.v3(d + Vector2(-0.9, z), y0 + oh * 0.5), yaw), Vector3(0.14, oh, 0.14))
	mb.add_box(_iron_m(), M.xf(M.v3(d + Vector2(-0.9, 0), y0 + oh * 0.7), yaw), Vector3(0.14, 0.14, ow), 0.5)
	for k in range(7):
		var a := PI * k / 6.0
		mb.add_box(_foot_m(), M.xf(M.v3(d + Vector2(-1.3, cos(a) * (ow * 0.5 + 0.3)), y0 + oh - 0.4 + sin(a) * 0.6), yaw), Vector3(0.6, 0.6, 0.7), 0.5)
	# the stone filled in over the cut behind the mouth, up to the prison's floor (a cobbled top), 3 m past it each way
	var py: float = P.DISTRICTS[3][2]
	var fill := Rect2(Vector2(d.x + 1.2, P.DRAIN_CUT.position.y - 3.0), Vector2(P.DRAIN_CUT.end.x + 3.0 - d.x - 1.2, P.DRAIN_CUT.size.y + 6.0))
	_block(mb, cols, _dark_m(), M.xf(M.v3(fill.get_center(), (y0 + oh + 0.4 + py) * 0.5)), Vector3(fill.size.x, py - y0 - oh - 0.4, fill.size.y))
	mb.add_box(PSXMat.lit("cobbles", Color(0.6, 0.6, 0.62)), M.xf(M.v3(fill.get_center(), py + 0.01)), Vector3(fill.size.x, 0.02, fill.size.y), 0.5)
	# the trickle out over the shingle
	mb.add_box(PSXMat.lit("water", Color(0.5, 0.6, 0.6)), M.xf(M.v3(d + Vector2(-4.0, 0), P.terrain(d + Vector2(-4, 0)) + 0.06), yaw), Vector3(6.0, 0.02, 1.2), 0.5)
