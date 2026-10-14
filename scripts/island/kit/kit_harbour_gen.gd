class_name GenHarbour
extends RefCounted
## A generated island's harbour district round its pier (GenIsland.dock_shore,
## out along dock_dir), one of the theme's kinds rolled from the island's seed:
##   stilts - a fishing port: a boardwalk along the water with houses on stilts
##            out in the shallows, huts up the beach, canoes, net and fish racks
##   cove   - a smugglers' cove: rocks closing it in, a boathouse over the water
##            with the stash, a dark-sailed sloop at her jetty, a red lamp, a lookout
##   wharf  - a timber trading wharf: a deck along the shore, warehouses, a crane,
##            a merchantman at her own pier, stalls, cargo, a row of houses behind
##   ruins  - a ruined jetty: the old jetty in pieces, a wreck, the stump of the
##            harbour tower, roofless huts and squatters' shacks
## Planned in a frame from the pier (KitHarbour's: s along the shore, d in from
## the waterline) as data on the prepare worker, so its reserves keep the trees
## off; `steps` puts it in the world a piece a frame. Every draw comes from the
## island's seed: a co-op guest builds the same harbour.

const LIGHTS := 6
const SALT := 7311
## The village further than this from the dock: the harbour rolls from the theme's wild kinds.
const WILD_AT := 110.0
## The frame's stations either side of the pier (2 m apart).
const REACH := 24
## Tools: every harbour planned while this is set is this kind.
static var force := ""

var isl: GenIsland
var ctx: KitContext
var f: KitHarbour
var kind := ""
var deck_y := GenIsland.DOCK_DECK_Y
## Where the harbour's people would stand at their work: [point, facing, role] (island space).
var spots: Array = []
var _rng: RandomNumberGenerator
var _work: Array = []
var _props: Array = []
var _walks: Array = []
## [point, top y, radius]: pilings under the houses out on the water and the old jetty's stumps.
var _piles: Array = []
var _deck_taken: Array = []
var _pier := {}


## The harbour of `gi` as data (prepare, after the heights): call before the vegetation.
static func plan(gi: GenIsland) -> GenHarbour:
	var g := GenHarbour.new()
	g.isl = gi
	g.ctx = KitContext.make(gi, int(gi.node["seed"]), gi.theme, LIGHTS, gi.build_ms)
	g._rng = g.ctx.rng(SALT)
	# (no village near the dock: a wilder pool, a bare landing among them)
	var inland: bool = (gi.sites["village"] as Vector2).distance_to(gi.dock_shore) > WILD_AT
	var kinds: Array = g.ctx.style["harbour_wild_kinds" if inland else "harbour_kinds"]
	g.kind = force if force != "" else str(kinds[g._rng.randi() % kinds.size()])
	g._frame()
	g._work.append(["harbour", g._begin])
	match g.kind:
		"stilts":
			g._stilts()
		"cove":
			g._cove()
		"wharf":
			g._wharf()
		"ruins":
			g._ruins()
		"landing":
			g._wild()
	# (the walkways a step per ~60 m: their ropes and pilings are most of a harbour's build)
	var group: Array = []
	var run := 0.0
	for w in g._walks + [null]:
		if (w == null or run > 60.0) and not group.is_empty():
			g._work.append(["harbour", g._build_walks.bind(group, g._piles if w == null else [])])
			group = []
			run = 0.0
		if w != null:
			group.append(w)
			var pts: PackedVector2Array = w["pts"]
			for i in range(pts.size() - 1):
				run += pts[i].distance_to(pts[i + 1])
	g._flush()
	return g


## GenIsland.finish_steps' share: [name, Callable] in order (main thread, the island in the tree).
func steps() -> Array:
	return _work


## The waterfront line (island space), for the fidelity tool's districts.
func waterfront() -> Array:
	var line: Array = []
	var s := f.s0
	while s <= f.s1:
		line.append(at(s, 0.0))
		s += 8.0
	return line + [isl.dock_shore, isl.sites["dock_end"]]


# ==========================================================================
# The frame
# ==========================================================================
## The shore either side of the pier: at each station the waterline, scanned in
## from the sea along the frame's t, smoothed; s0/s1 as far as it runs fairly straight.
func _frame() -> void:
	f = KitHarbour.new()
	f.out = isl.dock_dir
	f.inland = Vector2(-f.out.x + 0.0, -f.out.y + 0.0)
	f.along = Vector2(f.inland.y + 0.0, -f.inland.x + 0.0)
	f.yaw = atan2(f.inland.x, f.inland.y)
	f.origin = isl.dock_shore
	f.dock = isl.dock_shore
	f.quay_y = deck_y
	f.pier_len = GenIsland.PIER_LEN
	var ts: Array = []
	for i in range(-REACH, REACH + 1):
		var s := i * f.step
		var t := 40.0
		while t > -40.0 and ctx.hv(f.pt(s, t)) > 0.6:
			t -= 0.5
		f.wall_s.append(s)
		ts.append(t)
	var lo := REACH
	var hi := REACH
	while lo > 0 and absf(float(ts[lo - 1]) - float(ts[lo])) < 4.0 and absf(float(ts[lo - 1]) - float(ts[REACH])) < 25.0:
		lo -= 1
	while hi < ts.size() - 1 and absf(float(ts[hi + 1]) - float(ts[hi])) < 4.0 and absf(float(ts[hi + 1]) - float(ts[REACH])) < 25.0:
		hi += 1
	for pass_i in range(2):
		var sm: Array = ts.duplicate()
		for i in range(1, ts.size() - 1):
			sm[i] = (float(ts[i - 1]) + float(ts[i]) * 2.0 + float(ts[i + 1])) * 0.25
		ts = sm
	for t in ts:
		f.wall_t.append(float(t) - 2.0)
	f.s0 = f.wall_s[lo]
	f.s1 = f.wall_s[hi]


## The waterline's t at station s.
func shore(s: float) -> float:
	return f.wall(s) + 2.0


## `d` m in from the waterline at station s (island space).
func at(s: float, d: float) -> Vector2:
	return f.pt(s, shore(s) + d)


## `k` m out along the pier from its root.
func _dock(k: float) -> Vector2:
	return isl.dock_shore + isl.dock_dir * k


func _ok_land(p: Vector2, r: float) -> bool:
	var lo := ctx.ground_min(p, r)
	return lo > 0.8 and ctx.ground_max(p, r) - lo < 2.2 and not ctx.excluded(p, r) and ctx.path_dist(p) > r + 0.8


func _ok_water(p: Vector2, r: float, shallowest: float) -> bool:
	return ctx.ground_max(p, r) < shallowest and ctx.ground_min(p, r) > -14.0 and not ctx.excluded(p, r)


## The first point pushing p out 3 m at a time (up to `tries`) where the bottom under
## a hull there (radius r) is deeper than `depth`: the last one tried if none is.
func _deep(p: Vector2, r: float, depth: float, tries := 8) -> Vector2:
	var q := p
	for k in range(tries):
		if ctx.ground_max(q, r) < depth:
			return q
		q += f.out * 3.0
	return q


# ==========================================================================
# Planning (data)
# ==========================================================================
## A walkway along `pts` at the deck's height (or `ys`), reserved as it goes.
## opts: ys, rails ([side (1 left, -1 right of the way it runs), from m, to m]),
## breaks (a share of rail spans gone), step (pilings), pile_r, square, lean,
## tints, braces, bollards (points on its deck).
func _walk(pts: PackedVector2Array, hw: float, opts := {}) -> Dictionary:
	var w := {"pts": pts, "hw": hw, "ys": opts.get("ys", PackedFloat32Array()), "rails": opts.get("rails", []), "breaks": opts.get("breaks", 0.0),
		"step": opts.get("step", 2.4), "pile_r": opts.get("pile_r", 0.15), "square": opts.get("square", false), "lean": opts.get("lean", 0.0),
		"tints": opts.get("tints", [Color(0.84, 0.84, 0.82), Color.WHITE]), "braces": opts.get("braces", true),
		"bollards": opts.get("bollards", []), "seed": _rng.randi()}
	for i in range(pts.size() - 1):
		var n := maxi(int(pts[i].distance_to(pts[i + 1]) / 3.0), 1)
		for k in range(n + 1):
			ctx.reserve(pts[i].lerp(pts[i + 1], float(k) / n), hw + 0.8)
	_walks.append(w)
	return w


## A walk on from deck point p toward `dir` until it runs into the rising beach,
## or within `reach` ramps down onto it.
func _landing(p: Vector2, dir: Vector2, hw: float, reach := 9.0, opts := {}) -> void:
	var k := 1.0
	while k <= reach:
		if ctx.hv(p + dir * k) >= deck_y - 0.05:
			_walk(PackedVector2Array([p, p + dir * (k + 0.6)]), hw, opts)
			return
		k += 1.0
	var end := p + dir * reach
	var g := ctx.hv(end)
	var ramp := clampf((deck_y - g) * 4.0, 2.5, reach - 1.0)
	var o := opts.duplicate()
	o["ys"] = PackedFloat32Array([deck_y, deck_y, g + 0.06])
	_walk(PackedVector2Array([p, end - dir * ramp, end]), hw, o)


## The main pier, where the ship ties up: GenIsland's line (PIER_Z0 to PIER_LEN, PIER_HW), its ladder,
## lamps, mooring posts down the ship's side and the "Board ship" area. opts as _walk's, plus "fender".
func _main_pier(opts: Dictionary) -> void:
	var pts := PackedVector2Array()
	var k := GenIsland.PIER_Z0
	while k < GenIsland.PIER_LEN - 1.0:
		pts.append(_dock(k))
		k += 6.0
	pts.append(_dock(GenIsland.PIER_LEN))
	var o := opts.duplicate()
	var bol: Array = []
	for d in [12.0, 18.0, 24.0, GenIsland.PIER_LEN - 0.8]:
		bol.append(_dock(d) + f.along * (GenIsland.PIER_HW - 0.35))
	bol.append(_dock(GenIsland.PIER_LEN - 0.8) - f.along * (GenIsland.PIER_HW - 0.35))
	o["bollards"] = bol
	o["seed"] = _rng.randi()
	_pier = {"pts": pts, "hw": GenIsland.PIER_HW, "ys": PackedFloat32Array(), "rails": o.get("rails", []), "breaks": o.get("breaks", 0.0),
		"step": 3.0, "pile_r": 0.17, "square": o.get("square", false), "lean": o.get("lean", 0.0),
		"tints": o.get("tints", [Color(0.84, 0.84, 0.82), Color.WHITE]), "braces": true, "bollards": bol, "seed": o["seed"]}
	_work.append(["harbour", _build_pier])
	spots.append([_dock(GenIsland.PIER_LEN - 4.0) - f.along * 1.2, f.along, "dockhand"])


## A house on the ground (`stilts`: up on posts), reserved now, built a step later.
func _house(spec: Dictionary, p: Vector2, face: Vector2, stilts: bool) -> void:
	ctx.reserve(p, maxf(float(spec["w"]), float(spec["d"])) * 0.6 + 1.5)
	_work.append(["harbour", _build_house.bind(spec, p, face, stilts)])


## A house out on the water, its floor at the deck's height on pilings to the bottom.
func _water_house(spec: Dictionary, p: Vector2, face: Vector2) -> void:
	spec["stilts"] = 0.4
	spec["foundation"] = 0.6
	var w: float = spec["w"]
	var d: float = spec["d"]
	ctx.reserve(p, maxf(w, d) * 0.6 + 1.0)
	var x := Vector2(face.y, -face.x)
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_piles.append([p + x * sx * (w * 0.5 - 0.1) + face * sz * (d * 0.5 - 0.1), deck_y - 0.75, 0.16])
	_work.append(["harbour", _build_water_house.bind(spec, p, face)])


## A jungle hut's spec from the style (`rough`: patched, no flowers).
func _hut_spec(rough := false) -> Dictionary:
	var st := ctx.style
	var walls: Array = st["harbour_walls"]
	var spec := {"w": _rng.randf_range(4.0, 5.4), "d": _rng.randf_range(3.4, 4.4), "h": _rng.randf_range(2.2, 2.5),
		"roof": ["gable", "hip", "gable_front", "gable"][_rng.randi() % 4], "wall": walls[_rng.randi() % walls.size()],
		"roof_tex": st["harbour_roof"], "porch": 1.2 if _rng.randf() < 0.45 else 0.0, "pitch": _rng.randf_range(0.5, 0.7),
		"seed": _rng.randi()}
	spec["flowers"] = not rough and _rng.randf() < 0.3
	spec["trim"] = Color(0.36, 0.34, 0.32) if rough else Color(0.42, 0.3, 0.2)
	return spec


## Up to `n` huts on stilts facing the sea, `d_lo`..`d_hi` up the beach, left to
## right where the ground is clear; each gets a thing or two beside it. Their points.
func _hut_row(n: int, d_lo: float, d_hi: float, rough := false, lit := -1) -> Array:
	var out: Array = []
	var s := -46.0 + _rng.randf_range(0.0, 4.0)
	var passes := 0
	while out.size() < n and passes < 2:
		if s >= 46.0:
			s = -44.0 + _rng.randf_range(0.0, 4.0)
			passes += 1
			continue
		var spec := _hut_spec(rough)
		var w: float = spec["w"]
		var p := at(s + w * 0.5, _rng.randf_range(d_lo, d_hi))
		var r := maxf(w, float(spec["d"])) * 0.6
		s += w + _rng.randf_range(2.5, 6.0)
		if absf(f.s_of(p)) < 7.0 or not _ok_land(p, r):
			continue
		if out.size() == lit:
			spec["lamp_light"] = true
		_house(spec, p, f.out, true)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var q := p + f.along * side * (w * 0.5 + 1.0) + f.inland * _rng.randf_range(-0.8, 0.8)
		_prop(_small(), q, _rng.randf() * TAU)
		if _rng.randf() < 0.6:
			_prop(_small(), q + f.inland * 1.2, _rng.randf() * TAU)
		out.append(p)
	return out


## One of the small things lying about a fishing place (a Callable making it).
func _small() -> Callable:
	match _rng.randi() % 6:
		0:
			return Props.barrel
		1:
			return Props.crate.bind(_rng.randf_range(0.6, 0.85))
		2:
			return Props.net_pile
		3:
			return Props.rope_coil
		4:
			return HarbourModels.fish_traps.bind(_rng.randi(), 3)
	return Props.barrel


## A prop on the ground (or at height `y`), placed later in a batch.
func _prop(make: Callable, p: Vector2, yaw: float, footprint := 0.0, y := INF, then := Callable()) -> void:
	if y == INF:
		ctx.plan_place(_props, make, p, yaw, footprint, 0.0, then)
	else:
		_props.append([make, Vector3(p.x, y, p.y), yaw, then])


## A prop on clear sand (not on a path, a reserve or in the sea): false if not.
func _ground_prop(make: Callable, p: Vector2, yaw: float, footprint := 0.6) -> bool:
	if ctx.hv(p) < 0.55 or ctx.excluded(p, maxf(footprint, 0.4)) or ctx.path_dist(p) < footprint + 0.6:
		return false
	_prop(make, p, yaw, footprint)
	return true


## A prop on a deck, kept `r` clear of the others on decks: false if not.
func _deck_prop(make: Callable, p: Vector2, yaw: float, r := 0.7) -> bool:
	for e in _deck_taken:
		if p.distance_to(e[0]) < r + float(e[1]):
			return false
	_deck_taken.append([p, r])
	_prop(make, p, yaw, 0.0, deck_y)
	return true


## A lantern post (its arm toward `arm`), lit from the budget.
func _lamp(p: Vector2, arm: Vector2, y := INF, energy := 1.6) -> void:
	if y != INF:
		_deck_taken.append([p, 0.5])
	_prop(Props.lantern_post, p, KitContext.face_yaw(arm) - PI * 0.5, 0.4 if y == INF else 0.0, y,
		func(n: Node3D): KitLights.light(ctx, n, Vector3(0.55, 2.0, 0.0), energy))


func _flush() -> void:
	var i := 0
	while i < _props.size():
		_work.append(["harbour", _build_props.bind(_props.slice(i, i + 8))])
		i += 8
	_props = []


# ==========================================================================
# The kinds
# ==========================================================================
func _stilts() -> void:
	var st := ctx.style
	_main_pier({"rails": [[-1, 0.0, 40.0], [1, 0.0, 11.0]]})
	var sa := maxf(f.s0, -40.0)
	var sb := minf(f.s1, 40.0)
	var dw := -2.5
	var hw := 1.2
	# the boardwalk along the water either side of the pier, landings up the beach
	for side in [-1.0, 1.0]:
		var s_end: float = sb if side > 0.0 else sa
		if absf(s_end) < 10.0:
			continue
		var pts := PackedVector2Array([_dock(0.0) + f.along * side * GenIsland.PIER_HW + f.inland * 0.0])
		pts[0] = f.pt(side * GenIsland.PIER_HW, shore(side * GenIsland.PIER_HW) + dw)
		var s: float = side * 5.0
		while absf(s) < absf(s_end) - 1.0:
			pts.append(at(s, dw))
			s += side * 3.0
		pts.append(at(s_end, dw))
		_walk(pts, hw, {"rails": [[-int(side), 0.0, 999.0]]})
		_landing(at(s_end, dw + hw), f.inland, 1.0)
		if absf(s_end) > 24.0:
			_landing(at(side * 20.0, dw + hw), f.inland, 1.0)
	# houses on stilts out in the shallows, a walk out to each, a canoe tied up
	for c in [-31.0, -18.0, 21.0, 32.0]:
		var s: float = c + _rng.randf_range(-2.0, 2.0)
		var spec := _hut_spec()
		spec["porch"] = 1.3
		var p := at(s, _rng.randf_range(-11.5, -9.5))
		if s < sa + 3.0 or s > sb - 3.0 or not _ok_water(p, maxf(spec["w"], spec["d"]) * 0.6, -0.3):
			continue
		var front: Vector2 = p + f.inland * (float(spec["d"]) * 0.5 + 1.3)
		_walk(PackedVector2Array([at(s, dw - hw), front]), 0.9, {"rails": [[1, 0.0, 99.0], [-1, 0.0, 99.0]]})
		_water_house(spec, p, f.inland)
		_prop(HarbourModels.canoe.bind(_rng.randi()), p + f.along * (float(spec["w"]) * 0.5 + 1.5), KitContext.face_yaw(f.along), 0.0, -0.18)
	# huts up the beach, a second row behind
	var row := _hut_row(6, 8.0, 11.0, false, 1)
	row += _hut_row(4, 17.0, 22.0)
	# the fish market at the pier's root: the fishmonger's stall, the harbourmaster's booth
	var mk := at(-6.8, 3.5)
	if ctx.path_dist(mk) < 2.2:
		mk -= f.along * 2.5
	_prop(Buildings.stall.bind("fish"), mk, KitContext.face_yaw(f.along), 1.8)
	spots.append([mk - f.along * 0.6, f.along, "fishmonger"])
	var bp := at(6.5, 3.2)
	if ctx.path_dist(bp) < 2.0:
		bp += f.along * 2.5
	_prop(KitHarbour.booth_model, bp, KitContext.face_yaw(-f.along), 1.6)
	spots.append([bp + f.along * 0.4, -f.along, "harbourmaster"])
	_lamp(mk + f.inland * 2.2 - f.along * 1.2, f.along)
	for k in range(4):
		_ground_prop(Props.barrel if k % 2 == 0 else Props.crate.bind(0.8), mk - f.along * (3.9 + k * 0.9) + f.inland * _rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, 0.5)
		_ground_prop(_small(), bp + f.along * (3.7 + k * 0.9) + f.inland * _rng.randf_range(-0.8, 0.8), _rng.randf() * TAU, 0.5)
	# on the sand: net racks with the mender's bench, fish racks, canoes pulled up, one being dug out
	var made := 0
	for k in range(12):
		if made >= 3:
			break
		var p := at(_rng.randf_range(-30.0, 30.0), _rng.randf_range(2.5, 5.5))
		if absf(f.s_of(p)) < 9.0:
			continue
		if _ground_prop(HarbourModels.net_rack.bind(_rng.randi(), st["harbour_pile"], st["harbour_floats"]), p, KitContext.face_yaw(f.out) + _rng.randf_range(-0.3, 0.3), 1.9):
			if made == 0:
				_ground_prop(Props.bench, p + f.inland * 1.6, KitContext.face_yaw(f.out) + PI * 0.5 - PI * 0.5, 1.0)
				spots.append([p + f.inland * 1.2, f.out, "net mender"])
			made += 1
	for k in range(8):
		var p := at(_rng.randf_range(-34.0, 34.0), _rng.randf_range(0.8, 3.0))
		if absf(f.s_of(p)) > 6.0:
			_ground_prop(HarbourModels.canoe.bind(_rng.randi()), p, KitContext.face_yaw(f.inland.rotated(_rng.randf_range(-0.5, 0.5))), 1.6)
	for k in range(4):
		_ground_prop(Props.fish_rack, at(_rng.randf_range(-28.0, 28.0), _rng.randf_range(5.0, 7.5)), KitContext.face_yaw(f.out), 1.4)
	_ground_prop(Props.upturned_boat, at(_rng.randf_range(-36.0, -12.0), _rng.randf_range(4.0, 7.0)), _rng.randf() * TAU, 2.0)
	var yard := at(_rng.randf_range(12.0, 30.0), _rng.randf_range(5.0, 7.0))
	if _ground_prop(KitHarbour.workbench, yard, KitContext.face_yaw(f.out), 1.2):
		_ground_prop(HarbourModels.canoe.bind(_rng.randi(), false), yard + f.along * 2.6, KitContext.face_yaw(f.inland), 2.0)
		_ground_prop(HarbourModels.timber.bind(_rng.randi()), yard + f.inland * 2.4 + f.along * 1.0, KitContext.face_yaw(f.inland) + PI * 0.5, 1.8)
		spots.append([yard + f.out * 0.9, f.inland, "boatwright"])
	# along the boardwalk: canoes tied up, traps, nets, coils and kegs on the deck, two lamps
	for side in [-1.0, 1.0]:
		var s: float = side * 6.0
		var lamp_at: float = side * 14.0
		while absf(s) < (sb if side > 0.0 else -sa) - 2.0:
			var make: Callable = _small()
			if absf(s - lamp_at) < 1.6:
				_lamp(at(s, dw + hw - 0.3), f.out, deck_y)
			elif _rng.randf() < 0.5 and absf(s) > 9.0:
				_prop(HarbourModels.canoe.bind(_rng.randi()), at(s, dw - hw - 1.4), KitContext.face_yaw(f.along), 0.0, -0.18)
			else:
				_deck_prop(make, at(s, dw + _rng.randf_range(-0.5, 0.5)), _rng.randf() * TAU)
			s += side * _rng.randf_range(4.5, 7.0)
	for k in [8.0, 15.0, 22.0]:
		_deck_prop(_small(), _dock(k) - f.along * (GenIsland.PIER_HW - 0.6), _rng.randf() * TAU)


func _cove() -> void:
	var st := ctx.style
	_main_pier({"rails": [[-1, 0.0, 40.0], [1, 0.0, 10.0]], "lean": 0.14, "breaks": 0.15,
		"tints": [Color(0.6, 0.58, 0.54), Color(0.86, 0.84, 0.8)]})
	var sa := maxf(f.s0, -40.0)
	var sb := minf(f.s1, 40.0)
	# the boathouse over the water, the stash inside, its landing ashore
	var bs := -_rng.randf_range(9.5, 12.0)
	var bw := 7.0
	var bl := 13.0
	var bc := at(bs, -5.5)
	var back: Vector2 = bc + f.inland * (bl * 0.5)
	var depth := deck_y - ctx.ground_min(bc, bl * 0.45)
	for k in range(5):
		ctx.reserve(bc + f.out * (k - 2) * 3.0, bw * 0.5 + 0.8)
	_work.append(["harbour", _build_boathouse.bind(bc, bw, bl, depth)])
	_landing(back, f.inland, 1.0, 9.0, {"lean": 0.14})
	_work.append(["harbour", _build_moored.bind(bc + f.out * 1.0, -f.out, "longboat")])
	var chest_p: Vector2 = back + f.out * 0.7 + f.along * (bw * 0.5 - 0.7)
	_work.append(["harbour", _build_stash.bind(chest_p, KitContext.face_yaw(-f.along))])
	_lamp(back + f.inland * 1.2 + f.along * 1.4, -f.along)
	spots.append([back + f.out * 1.6, f.out, "smuggler"])
	for k in range(3):
		_deck_prop(Props.barrel if k != 1 else Props.crate.bind(0.8), bc + f.inland * (bl * 0.5 - 2.0 - k * 1.3) - f.along * (bw * 0.5 - 0.6), _rng.randf() * TAU, 0.5)
	# the sloop at her jetty further along, a red lamp at its end
	var js := bs - bw * 0.5 - _rng.randf_range(6.0, 9.0)
	if js > sa - 6.0:
		var root := at(js, 0.5)
		var hull := _deep(root + f.out * 15.0 - f.along * (1.1 + HullBuilder.HALF_BEAM + 0.6), 6.0, -1.5)
		var end := root + f.out * (f.out.dot(hull - root) + 9.0)
		_walk(PackedVector2Array([root, root + f.out * 12.0, end]), 1.1, {"lean": 0.16, "tints": [Color(0.6, 0.58, 0.54), Color(0.86, 0.84, 0.8)],
			"bollards": [end - f.out * 1.0 + f.along * 0.7, end - f.out * 10.0 - f.along * 0.7]})
		_landing(root, f.inland, 1.1, 9.0, {"lean": 0.16})
		_work.append(["harbour", _build_moored.bind(hull, -f.out, "smugglers")])
		_prop(Props.lantern_post.bind(3.0), end - f.out * 0.6 + f.along * 0.6, KitContext.face_yaw(f.out) - PI * 0.5, 0.0, deck_y,
			func(n: Node3D):
				if ctx.take_light():
					var nl := NightLight.make(st["harbour_signal"], 1.8, 14.0)
					nl.position = Vector3(0.55, 2.4, 0.0)
					n.add_child(nl))
		_prop(Props.rope_coil, end - f.out * 3.0, 0.0, 0.0, deck_y)
	# the shacks up the beach, a few further back
	_hut_row(5, 8.0, 16.0, true, 2)
	_hut_row(4, 17.0, 25.0, true)
	# rocks closing the cove in either side, a wall of them behind
	var rocks: Array = []
	for side in [-1.0, 1.0]:
		var s: float = _rng.randf_range(15.0, 18.0) if side > 0.0 else minf(-15.0, js - 4.0)
		for k in range(7):
			var p := at(s, _rng.randf_range(-6.0, 8.0))
			var r := _rng.randf_range(2.8, 5.2)
			var hgt := _rng.randf_range(1.2, 2.0)
			s += side * _rng.randf_range(2.5, 4.0)
			if ctx.path_dist(p) < r + 1.0 or ctx.excluded(p, r * 0.6):
				continue
			rocks.append([p, Vector3(r, r * hgt, r * _rng.randf_range(0.8, 1.2))])
			ctx.reserve(p, r + 0.6)
	for k in range(10):
		var p := at(_rng.randf_range(-40.0, 40.0), _rng.randf_range(20.0, 30.0))
		var r := _rng.randf_range(4.0, 7.0)
		if absf(f.s_of(p)) < 10.0 or ctx.path_dist(p) < r + 1.5 or ctx.excluded(p, r * 0.6):
			continue
		rocks.append([p, Vector3(r, r * _rng.randf_range(0.9, 1.4), r * _rng.randf_range(0.8, 1.2))])
		ctx.reserve(p, r + 0.6)
	_work.append(["harbour", _build_rocks.bind(rocks)])
	# the lookout, contraband under tarps, boats pulled up, nets and kegs about
	for k in range(8):
		var tp := at(_rng.randf_range(8.0, 28.0), _rng.randf_range(4.0, 12.0))
		if _ok_land(tp, 2.6):
			_prop(KitLandmarks.lookout_tower, tp, KitContext.face_yaw(f.inland), 2.6)
			spots.append([tp + f.inland * 2.6, f.out, "lookout"])
			break
	var stash_n := 0
	for k in range(10):
		if stash_n >= 3:
			break
		var p := at(_rng.randf_range(-26.0, 22.0), _rng.randf_range(2.5, 7.0))
		if absf(f.s_of(p)) > 5.0 and _ground_prop(HarbourModels.contraband.bind(_rng.randi(), st["harbour_tarp"]), p, _rng.randf() * TAU, 1.7):
			stash_n += 1
			for j in range(2):
				_ground_prop(Props.barrel if j == 0 else Props.crate.bind(0.75), p + f.along.rotated(_rng.randf() * TAU) * 2.4, _rng.randf() * TAU, 0.5)
	for k in range(4):
		_ground_prop(Props.rowboat, at(_rng.randf_range(-30.0, 30.0), _rng.randf_range(0.6, 2.5)), KitContext.face_yaw(f.inland.rotated(_rng.randf_range(-0.6, 0.6))), 2.0)
	for k in range(2):
		_ground_prop(Props.weapon_rack, at(_rng.randf_range(-20.0, 20.0), _rng.randf_range(7.0, 12.0)), KitContext.face_yaw(f.out), 1.0)
	for k in range(12):
		_ground_prop(_small(), at(_rng.randf_range(-30.0, 30.0), _rng.randf_range(1.5, 9.0)), _rng.randf() * TAU)
	_ground_prop(Props.fish_rack, at(_rng.randf_range(4.0, 14.0), _rng.randf_range(3.0, 6.0)), KitContext.face_yaw(f.out), 1.4)
	for k in [9.0, 17.0, 25.0]:
		_deck_prop(_small(), _dock(k) - f.along * (GenIsland.PIER_HW - 0.6), _rng.randf() * TAU)
	sb = sb


func _wharf() -> void:
	var st := ctx.style
	_main_pier({"square": true, "tints": [Color(0.78, 0.76, 0.72), Color.WHITE]})
	var sa := maxf(f.s0, -36.0)
	var sb := minf(f.s1, 36.0)
	var dw := -2.0
	var hw := 4.0
	# warehouses up the beach, a ramp from the wharf to each one's doors
	var doors: Array = []
	for c in [-27.0, -14.0, 14.0, 27.0]:
		var spec := {"w": _rng.randf_range(8.5, 10.5), "d": _rng.randf_range(6.0, 7.0), "h": _rng.randf_range(3.4, 4.0),
			"wall": ["planks", "planks_weathered"][_rng.randi() % 2], "roof": st["harbour_roof"], "seed": _rng.randi(), "pitch": _rng.randf_range(0.38, 0.46)}
		var r := maxf(spec["w"], spec["d"]) * 0.55
		# (a few spots from its slot toward the pier and up the beach: a short, steep or bitten shore loses the first)
		var s := INF
		var p := Vector2.ZERO
		for k in range(5):
			var ts: float = c * (1.0 - 0.12 * k) + _rng.randf_range(-1.5, 1.5)
			var tp := at(ts, float(spec["d"]) * 0.5 + _rng.randf_range(6.0, 7.5) + k * 2.0)
			if ts >= sa + 3.0 and ts <= sb - 3.0 and _ok_land(tp, r):
				s = ts
				p = tp
				break
		if s == INF:
			continue
		ctx.reserve(p, r + 1.5)
		doors.append(s)
		_work.append(["harbour", _build_warehouse.bind(spec, p, f.out)])
		_ground_prop(Props.crate.bind(0.9), p + f.out * (float(spec["d"]) * 0.5 + 1.2) + f.along * 2.8, _rng.randf() * TAU, 0.7)
		_ground_prop(Props.barrel, p + f.out * (float(spec["d"]) * 0.5 + 1.0) - f.along * 3.0, 0.0, 0.5)
		spots.append([p + f.out * (float(spec["d"]) * 0.5 + 1.0), f.out, "dockhand"])
	# the wharf along the shore either side of the pier, ramps up onto it
	for side in [-1.0, 1.0]:
		var s_end: float = sb if side > 0.0 else sa
		if absf(s_end) < 8.0:
			continue
		var pts := PackedVector2Array([f.pt(side * GenIsland.PIER_HW, shore(side * GenIsland.PIER_HW) + dw)])
		var s: float = side * 6.0
		while absf(s) < absf(s_end) - 2.0:
			pts.append(at(s, dw))
			s += side * 4.0
		pts.append(at(s_end, dw))
		var bol: Array = []
		var b: float = side * 8.0
		while absf(b) < absf(s_end) - 1.0:
			bol.append(at(b, dw - hw + 0.4))
			b += side * 6.0
		_walk(pts, hw, {"square": true, "step": 3.0, "pile_r": 0.16, "bollards": bol, "tints": [Color(0.78, 0.76, 0.72), Color.WHITE]})
		for ds in doors:
			if float(ds) * side > 0.0 and absf(ds) < absf(s_end) - 1.5:
				_landing(at(ds, dw + hw), f.inland, 1.4, 4.0, {"square": true})
		_landing(at(s_end, dw), f.along * side, 1.4, 6.0, {"square": true})
		_deck_taken.append([at(s_end, dw), 2.0])
	# the merchantman at her own pier, the crane by her
	var ms := -1.0 if sa < -24.0 else (1.0 if sb > 28.0 else 0.0)
	if ms != 0.0:
		var ps: float = ms * _rng.randf_range(17.0, 20.0) if ms < 0.0 else _rng.randf_range(20.0, 23.0)
		var root := at(ps, dw - hw + 0.2)
		var hull := _deep(root + f.out * 16.5 + f.along * ms * (1.3 + HullBuilder.HALF_BEAM + 0.7), 7.0, -2.0)
		var end := root + f.out * (f.out.dot(hull - root) + 9.5)
		_walk(PackedVector2Array([root, end]), 1.3, {"square": true, "step": 3.0, "bollards": [end - f.out * 1.0 + f.along * ms * 0.8, root + f.out * 11.0 + f.along * ms * 0.8]})
		_work.append(["harbour", _build_moored.bind(hull, -f.out, "merchant")])
		var cp := at(ps - ms * 5.5, dw - hw + 1.0)
		_deck_taken.append([cp, 1.6])
		_prop(Buildings.dock_crane, cp, KitContext.face_yaw(f.out), 0.0, deck_y)
		spots.append([cp + f.inland * 1.4, f.out, "craneman"])
	for c in [-30.0, 28.0]:
		if c > sa + 2.0 and c < sb - 2.0 and absf(c) > 16.0:
			_work.append(["harbour", _build_moored.bind(at(c, dw - hw - 1.7), f.along, "longboat")])
	# the harbourmaster's booth and two traders' stalls on the deck
	var bp := at(6.5, dw + 1.2)
	_deck_taken.append([bp, 1.8])
	_prop(KitHarbour.booth_model, bp, KitContext.face_yaw(-f.along), 0.0, deck_y)
	spots.append([bp + f.along * 0.4, -f.along, "harbourmaster"])
	for c in [-8.0, -13.5]:
		if c > sa + 2.0:
			var sp := at(c, dw + hw - 1.4)
			_deck_taken.append([sp, 2.0])
			_prop(Buildings.stall.bind(["fruit", "cloth", "pots"][_rng.randi() % 3]), sp, KitContext.face_yaw(f.out), 0.0, deck_y)
			spots.append([sp - f.out * 0.7, f.out, "trader"])
	# a row of houses behind them (KitHarbour's waterfront, in the theme's look)
	f.plat_d = _rng.randf_range(19.0, 21.0)
	for e in f.plan_waterfront(ctx, _rng, 1, 7.5, 4.0, _rng.randi() % 1000):
		_work.append(["harbour", _build_house.bind(e[0], e[1], e[2], false)])
	# cargo along the wharf, lamps at its edge
	for side in [-1.0, 1.0]:
		var s_end: float = sb if side > 0.0 else sa
		var s: float = side * 4.5
		while absf(s) < absf(s_end) - 2.5:
			var q := at(s, dw + _rng.randf_range(-1.5, 2.2))
			match _rng.randi() % 6:
				0, 1:
					if _deck_prop(Props.crate.bind(0.9), q, _rng.randf() * TAU, 1.0):
						_prop(Props.crate.bind(0.7), q + f.along * 1.0, _rng.randf() * TAU, 0.0, deck_y)
						_prop(Props.crate.bind(0.6), q, _rng.randf() * TAU, 0.0, deck_y + 0.9)
				2:
					if _deck_prop(Props.barrel, q, 0.0, 1.0):
						_prop(Props.barrel, q + f.along * 0.8, 0.0, 0.0, deck_y)
				3:
					_deck_prop(HarbourModels.sacks.bind(_rng.randi()), q, KitContext.face_yaw(f.out) + _rng.randf_range(-0.3, 0.3), 1.2)
				4:
					_deck_prop(KitVillage.handcart, q, KitContext.face_yaw(f.inland.rotated(_rng.randf_range(-0.8, 0.8))), 1.3)
				_:
					_deck_prop(HarbourModels.timber.bind(_rng.randi()), q, KitContext.face_yaw(f.out) + PI * 0.5, 1.7)
			s += side * _rng.randf_range(2.4, 4.0)
		var ls: float = side * 11.0
		if absf(ls) < absf(s_end) - 2.0:
			_lamp(at(ls, dw - hw + 0.5), f.out, deck_y)
	_lamp(at(-10.8, dw + hw - 0.5), f.out, deck_y)
	for k in [10.0, 20.0]:
		_deck_prop(Props.rope_coil, _dock(k) - f.along * (GenIsland.PIER_HW - 0.6), 0.0, 0.5)


func _ruins() -> void:
	_main_pier({"rails": [[-1, 0.0, 40.0]], "breaks": 0.3, "lean": 0.06, "tints": [Color(0.55, 0.6, 0.5), Color(1.05, 1.0, 0.92)]})
	var sa := maxf(f.s0, -40.0)
	var sb := minf(f.s1, 40.0)
	var rot := [Color(0.45, 0.5, 0.42), Color(0.8, 0.78, 0.7)]
	# the old jetty: sound at its root, a gap, a fallen bay sloping into the sea, then stumps
	var jside := -1.0 if sa < -20.0 else 1.0
	var js: float = jside * _rng.randf_range(14.0, 18.0) if jside < 0.0 else _rng.randf_range(22.0, 26.0)
	var root := at(js, 1.0)
	_walk(PackedVector2Array([root, root + f.out * 10.0]), 1.5, {"rails": [[1, 0.0, 10.0]], "breaks": 0.5, "lean": 0.1, "tints": rot})
	_landing(root, f.inland, 1.5, 8.0, {"tints": rot})
	_walk(PackedVector2Array([root + f.out * 13.0, root + f.out * 19.5]), 1.5, {"ys": PackedFloat32Array([deck_y - 0.4, -0.6]), "tints": rot, "braces": false})
	var x := Vector2(f.out.y, -f.out.x)
	var k := 10.0
	while k < 36.0:
		for side in [-1.0, 1.0]:
			if (k > 12.0 and k < 20.0) or _rng.randf() < 0.3:
				continue
			_piles.append([root + f.out * k + x * side * 1.36, _rng.randf_range(0.7, deck_y + 0.9) if k > 20.0 else deck_y - 0.1, 0.19])
		k += 2.4
	for j in range(6):
		ctx.reserve(root + f.out * (12.0 + j * 4.0), 2.5)
	# the wreck further along
	var wp := _deep(at(js + jside * _rng.randf_range(9.0, 13.0), _rng.randf_range(-20.0, -16.0)), 5.0, -2.0)
	_work.append(["harbour", _build_wreck.bind(wp, KitContext.face_yaw(f.along.rotated(_rng.randf_range(-0.5, 0.5))), _rng.randf_range(0.3, 0.5))])
	# the stump of the old harbour tower on the other side
	for t in range(6):
		var tp := at(-jside * _rng.randf_range(14.0, 26.0), _rng.randf_range(5.0, 10.0))
		if _ok_land(tp, 3.8):
			_prop(HarbourModels.tower_stump.bind(_rng.randi()), tp, _rng.randf() * TAU, 3.8)
			break
	# roofless huts, squatters' shacks still standing among them
	var ruined := 0
	for t in range(100):
		if ruined >= 6:
			break
		# (the two big ones first, but not forever: a shore with no room for them still gets the small ones)
		var big := ruined < 2 and t < 30
		var w := _rng.randf_range(7.5, 9.0) if big else _rng.randf_range(4.0, 5.6)
		var d := _rng.randf_range(5.5, 6.5) if big else _rng.randf_range(3.4, 4.4)
		# (higher up the beach as the tries go: a steep or bitten shore has no room low down)
		var p := at(_rng.randf_range(-38.0, 38.0), _rng.randf_range(6.0, 16.0 + t * 0.08))
		if absf(f.s_of(p)) < 7.0 or not _ok_land(p, maxf(w, d) * 0.6):
			continue
		_prop(HarbourModels.ruined_hut.bind(_rng.randi(), w, d, _rng.randf_range(0.4, 0.9)), p, KitContext.face_yaw(f.out.rotated(_rng.randf_range(-0.4, 0.4))), maxf(w, d) * 0.6)
		# what the sea and the squatters left round it: a broken crate or keg, a spar, nets
		var sd := 1.0 if _rng.randf() < 0.5 else -1.0
		_prop(_small(), p + f.along * sd * (w * 0.5 + 1.1) + f.out * _rng.randf_range(-0.5, 1.5), _rng.randf() * TAU)
		_prop(KitCamps.log_seat, p + f.out * (d * 0.5 + 2.2) + f.along * _rng.randf_range(-1.5, 1.5), _rng.randf() * TAU)
		ruined += 1
	var shacks := _hut_row(4, 9.0, 20.0, true, 0)
	if not shacks.is_empty():
		var c: Vector2 = shacks[0] + f.out * 4.5
		_lamp(c + f.along * 1.5, -f.along)
		_ground_prop(KitCamps.log_seat, c - f.along * 1.0, KitContext.face_yaw(f.along), 1.0)
		spots.append([c, f.out, "squatter"])
		for j in range(2):
			var tp: Vector2 = c + f.along.rotated(_rng.randf_range(-0.6, 0.6)) * (4.0 + j * 3.5) * (1.0 if j == 0 else -1.0)
			_ground_prop(KitCamps.tent.bind(ctx.style["camp_tent"]), tp, KitContext.face_yaw(c - tp), 2.0)
		_ground_prop(Props.fish_rack, c + f.inland * 3.5, KitContext.face_yaw(f.along), 1.4)
	# wreckage and what the squatters keep
	for t in range(5):
		_ground_prop(KitCamps.log_seat, at(_rng.randf_range(-36.0, 36.0), _rng.randf_range(0.8, 4.0)), _rng.randf() * TAU, 1.0)
	for t in range(2):
		_ground_prop(Props.upturned_boat, at(_rng.randf_range(-30.0, 30.0), _rng.randf_range(2.0, 6.0)), _rng.randf() * TAU, 2.0)
	for t in range(2):
		_ground_prop(HarbourModels.canoe.bind(_rng.randi()), at(_rng.randf_range(-30.0, 30.0), _rng.randf_range(0.8, 2.6)), KitContext.face_yaw(f.inland.rotated(_rng.randf_range(-0.5, 0.5))), 1.6)
	_ground_prop(Props.fish_rack, at(_rng.randf_range(-20.0, 20.0), _rng.randf_range(4.0, 8.0)), KitContext.face_yaw(f.out), 1.4)
	for t in range(14):
		_ground_prop(_small(), at(_rng.randf_range(-34.0, 34.0), _rng.randf_range(1.0, 10.0)), _rng.randf() * TAU)
	_deck_prop(Props.net_pile, root + f.out * 6.0, 0.4)
	_deck_prop(Props.barrel, root + f.out * 3.0 + x * 0.6, 0.0)
	for k2 in [7.0, 16.0, 26.0]:
		_deck_prop(_small(), _dock(k2) - f.along * (GenIsland.PIER_HW - 0.6), _rng.randf() * TAU)
	sb = sb


## A bare landing where nobody lives near the shore: a rough jetty, boats pulled
## up, a lamp at its root, maybe a fisher's lean-to.
func _wild() -> void:
	_main_pier({"rails": [[-1, 0.0, 14.0]], "breaks": 0.25, "lean": 0.16, "tints": [Color(0.55, 0.56, 0.5), Color(0.85, 0.83, 0.78)]})
	_lamp(_dock(-4.0) - f.along * (GenIsland.PIER_HW + 0.8), f.along)
	if _rng.randf() < 0.6:
		var hut := _hut_row(1, 8.0, 14.0, true)
		if not hut.is_empty():
			spots.append([hut[0] + f.out * 3.0, f.out, "fisher"])
	# (by the jetty's root, retried until on dry sand: the shore by the pier drops into the dredged fairway)
	var put := 0
	for k in range(16):
		var side := 1.0 if k % 2 == 0 else -1.0
		if put < 3 and _ground_prop(HarbourModels.canoe.bind(_rng.randi(), _rng.randf() < 0.6), at(side * _rng.randf_range(5.2, 6.0), _rng.randf_range(1.0, 3.0 + k * 0.4)), KitContext.face_yaw(f.inland.rotated(_rng.randf_range(-0.5, 0.5))), 1.6):
			put += 1
	for k in range(8):
		if _ground_prop(Props.upturned_boat, at(_rng.randf_range(-24.0, 24.0), _rng.randf_range(2.0, 5.0 + k * 0.5)), _rng.randf() * TAU, 2.0):
			break
	put = 0
	for k in range(20):
		var side := 1.0 if k % 2 == 0 else -1.0
		if put < 5 and _ground_prop(_small(), at(side * _rng.randf_range(4.2, 5.6), _rng.randf_range(1.0, 5.0 + k * 0.2)), _rng.randf() * TAU):
			put += 1
	_deck_prop(Props.rope_coil, _dock(GenIsland.PIER_LEN - 3.0) - f.along * 1.2, 0.0)


# ==========================================================================
# Building (main thread, a step each)
# ==========================================================================
func _begin() -> void:
	var root := Node3D.new()
	root.name = "Site_harbour"
	isl.add_child(root)
	ctx.parent = root


func _build_pier() -> void:
	ctx.add(_walk_body([_pier], [], "Pier"))
	var pl := GenIsland.PIER_LEN
	var hw := GenIsland.PIER_HW
	var lad := Ladder.new()
	lad.length = deck_y + 1.2
	lad.rail = 0.0
	lad.deck_depth = 0.9
	ctx.put(lad, KitContext.v3(_dock(pl), deck_y), KitContext.face_yaw(isl.dock_dir))
	var head := Props.lantern_post()
	ctx.put(head, KitContext.v3(_dock(pl - 1.0) - f.along * (hw - 0.5), deck_y), KitContext.face_yaw(f.along) - PI * 0.5)
	KitLights.light(ctx, head, Vector3(0.55, 2.0, 0.0), 1.6)
	# a fender of upright timbers down the side the ship lies on
	var mb := MeshBuilder.new()
	var dark := PSXMat.lit("planks_dark")
	var k := 12.0
	while k < pl - 0.5:
		var q := _dock(k) + f.along * (hw + 0.12)
		mb.add_box(dark, Transform3D(Basis(Vector3.UP, KitContext.face_yaw(isl.dock_dir)), Vector3(q.x, (deck_y - 0.6) * 0.5 + 0.1, q.y)), Vector3(0.24, deck_y + 0.6, 0.26), 1.0)
		k += 1.6
	ctx.add(mb.to_instance("PierFender"))
	var area := Interactable.new()
	area.name = "DockingArea"
	area.collision_layer = 512
	area.collision_mask = 0
	area.prompt_text = "Board ship"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	cs.shape = sph
	area.add_child(cs)
	ctx.put(area, KitContext.v3(_dock(pl - 2.0), deck_y + 1.0))


func _build_walks(list: Array, loose: Array) -> void:
	ctx.add(_walk_body(list, loose, "Boardwalk"))


## Decks, pilings, braces, rails and mooring posts of `list` (and loose pilings
## `loose`) as one body: one mesh, its decks' tops the collider.
func _walk_body(list: Array, loose: Array, node_name: String) -> StaticBody3D:
	var st := ctx.style
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var top := MeshBuilder.new()
	var deck := PSXMat.lit(st["harbour_deck"], Color.WHITE, {"affine": 0.5})
	var dark := PSXMat.lit("planks_dark")
	var palm := PSXMat.lit(st["harbour_pile"])
	var rope := PSXMat.lit("rope")
	for w in list:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(w["seed"])
		var pts: PackedVector2Array = w["pts"]
		var ys: PackedFloat32Array = w["ys"]
		var p3 := PackedVector3Array()
		for i in range(pts.size()):
			p3.append(Vector3(pts[i].x, deck_y if ys.is_empty() else ys[i], pts[i].y))
		var hw: float = w["hw"]
		HarbourModels.deck_strip(mb, top, deck, dark, p3, hw, rng, w["tints"])
		var piles: Array = []
		var posts := {1: [], -1: []}
		var step: float = w["step"]
		for smp in _samples(p3, step):
			var q: Vector3 = smp[0]
			var lft := Vector2(-(smp[1] as Vector2).y, (smp[1] as Vector2).x)
			var feet: Array = []
			for side: int in [1, -1]:
				var e := Vector2(q.x, q.z) + lft * float(side) * (hw - 0.14)
				var g := ctx.hv(e)
				if g < q.y - 0.45:
					piles.append([Vector3(e.x, g - 0.6, e.y), Vector3(e.x, q.y - 0.1, e.y), w["pile_r"]])
					feet.append(Vector3(e.x, maxf(g, -2.5), e.y))
				for rl in w["rails"]:
					if int(rl[0]) == side and float(smp[2]) >= float(rl[1]) and float(smp[2]) <= float(rl[2]) and g < q.y - 0.6:
						var ep := Vector2(q.x, q.z) + lft * float(side) * (hw - 0.08)
						(posts[side] as Array).append([float(smp[2]), Vector3(ep.x, q.y, ep.y)])
			if feet.size() == 2 and bool(w["braces"]) and q.y - maxf(feet[0].y, feet[1].y) > 1.2:
				var a: Vector3 = feet[0]
				var b: Vector3 = feet[1]
				Buildings.beam_between(mb, dark, Vector3(a.x, q.y - 0.32, a.z), Vector3(b.x, q.y - 0.32, b.z), 0.2)
				Buildings.beam_between(mb, dark, Vector3(a.x, q.y - 0.4, a.z), Vector3(b.x, b.y + 0.4, b.z), 0.09)
				Buildings.beam_between(mb, dark, Vector3(b.x, q.y - 0.4, b.z), Vector3(a.x, a.y + 0.4, a.z), 0.09)
		HarbourModels.piles(mb, dark if w["square"] else palm, piles, rng, w["square"], w["lean"])
		for side in [1, -1]:
			var run := PackedVector3Array()
			var last := -INF
			var breaks: Array = []
			for e in (posts[side] as Array) + [[INF, Vector3.ZERO]]:
				if float(e[0]) - last > step * 1.6 and run.size() > 0:
					HarbourModels.rope_rail(mb, palm, rope, run, breaks)
					run = PackedVector3Array()
					breaks = []
				if float(e[0]) == INF:
					break
				if rng.randf() < float(w["breaks"]):
					breaks.append(run.size())
				run.append(e[1])
				last = float(e[0])
		for b in w["bollards"]:
			HarbourModels.bollard(mb, dark, rope, KitContext.v3(b, deck_y))
	if not loose.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([ctx.seed, SALT, node_name])
		var piles: Array = []
		for e in loose:
			var p: Vector2 = e[0]
			piles.append([KitContext.v3(p, ctx.hv(p) - 0.6), KitContext.v3(p, e[1]), e[2]])
		HarbourModels.piles(mb, palm, piles, rng, false, 0.08)
	var mesh := mb.to_instance(node_name + "Mesh")
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	cs.shape = top.commit().create_trimesh_shape()
	body.add_child(cs)
	return body


## Points every ~`step` along a polyline (both ends included): [point, direction (x/z), distance along].
static func _samples(p3: PackedVector3Array, step: float) -> Array:
	var lens := [0.0]
	for i in range(1, p3.size()):
		lens.append(float(lens[i - 1]) + Vector2(p3[i].x - p3[i - 1].x, p3[i].z - p3[i - 1].z).length())
	var total: float = lens[lens.size() - 1]
	var n := maxi(int(round(total / step)), 1)
	var out: Array = []
	var seg := 0
	for k in range(n + 1):
		var d := total * k / n
		while seg < p3.size() - 2 and d > float(lens[seg + 1]):
			seg += 1
		var t := (d - float(lens[seg])) / maxf(float(lens[seg + 1]) - float(lens[seg]), 0.001)
		out.append([p3[seg].lerp(p3[seg + 1], t), Vector2(p3[seg + 1].x - p3[seg].x, p3[seg + 1].z - p3[seg].z).normalized(), d])
	return out


func _build_house(spec: Dictionary, p: Vector2, face: Vector2, stilts: bool) -> void:
	ctx.house(spec, p, face, stilts, false)


func _build_water_house(spec: Dictionary, p: Vector2, face: Vector2) -> void:
	ctx.put(Buildings.house(spec), Vector3(p.x, deck_y - 0.7, p.y), KitContext.face_yaw(face))


func _build_warehouse(spec: Dictionary, p: Vector2, face: Vector2) -> void:
	var r := maxf(spec["w"], spec["d"]) * 0.6
	spec["found"] = ctx.ground_max(p, r) - ctx.ground_min(p, r) + 0.6
	ctx.place(HarbourModels.warehouse(spec), p, KitContext.face_yaw(face), r, 0.0, false)


func _build_boathouse(c: Vector2, w: float, l: float, depth: float) -> void:
	var st := ctx.style
	ctx.put(HarbourModels.boathouse({"w": w, "l": l, "depth": depth, "roof": st["harbour_roof"], "wall": "planks_weathered", "pile": st["harbour_pile"]}),
		KitContext.v3(c, deck_y), KitContext.face_yaw(f.out))


func _build_stash(p: Vector2, yaw: float) -> void:
	var t := IslandContent.tier(isl)
	KitCamps.strongbox(ctx, p, yaw, "cove_stash", [["gold", 15 + t * 6], ["rum", 3], ["treasure", 1]], 1.0, deck_y - ctx.hv(p))


func _build_moored(p: Vector2, face: Vector2, what: String) -> void:
	var hull := MooredHull.new()
	hull.name = "Moored_" + what
	hull.collision_layer = 1
	hull.collision_mask = 0
	if what == "longboat":
		hull.freeboard = 0.15
		hull.half_len = 2.4
	ctx.put(hull, KitContext.v3(p, hull.freeboard), KitContext.face_yaw(face))
	match what:
		"merchant":
			TraderShips.merchantman(hull)
		"longboat":
			TraderShips.longboat(hull)
		"smugglers":
			HullBuilder.build(hull, {"hull": Color(0.38, 0.33, 0.3), "sail": Color(0.34, 0.31, 0.3), "trim": Color(0.45, 0.16, 0.12), "flag": Color(0.2, 0.2, 0.22)})
			HullBuilder.collide(hull)


func _build_wreck(p: Vector2, yaw: float, roll: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Wreck"
	body.collision_layer = 1
	body.collision_mask = 0
	HullBuilder.build(body, {"wreck": true, "hull": Color(0.55, 0.52, 0.46)})
	HullBuilder.collide(body, false)
	ctx.put(body, KitContext.v3(p, -0.9), yaw)
	body.rotate_object_local(Vector3.BACK, roll)
	body.rotate_object_local(Vector3.RIGHT, 0.08)


func _build_rocks(rocks: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "CoveRocks"
	body.collision_layer = 1
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color.WHITE, {"affine": 0.6})
	var rng := ctx.rng(SALT + 1)
	for e in rocks:
		var p: Vector2 = e[0]
		var rad: Vector3 = e[1]
		var y := ctx.ground_min(p, rad.x * 0.7)
		mb.add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y + rad.y * 0.35, p.y)), rad, rng, 0.25, 4, 7, 0.35,
			Color(0.78 + rng.randf() * 0.22, 0.84, 0.8), -0.6)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = rad.x * 0.8
		cyl.height = rad.y * 1.5
		cs.shape = cyl
		cs.position = Vector3(p.x, y + rad.y * 0.6, p.y)
		body.add_child(cs)
	body.add_child(mb.to_instance("RockMesh"))
	ctx.add(body)


func _build_props(chunk: Array) -> void:
	for n in ctx.build_list(chunk):
		for gi in (n as Node).find_children("*", "GeometryInstance3D", true, false) + ([n] if n is GeometryInstance3D else []):
			(gi as GeometryInstance3D).visibility_range_end = 220.0
