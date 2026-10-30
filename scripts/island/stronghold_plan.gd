class_name StrongholdPlan
extends RefCounted
## The Admiralty's stronghold (1.27, docs/v1_27_raids_fruits_plan.md "Stronghold preview v2"): one fixed fortress
## island, the same shape in every world (its name rolled from the chain seed), as data. Its own frame like
## CapitalPlan's (x along the harbour front, +z out to sea, -z inland); StrongholdIsland turns it to face the open sea.
## Pure functions: safe on a worker.
##
## A rock island of stepped plateaus held up by cliffs: the Landing's quay at the sea, the Lower Ward (the hub) up a
## broad stair, the Arsenal (east) and the Prison Tower (west) up ramps off the hub, a chasm of sea behind the hub
## crossed by the Bridge of Judgement climbing to the Keep's plateau at the top. Districts are rects at their heights;
## between them and round them the rock falls away in cliffs (CLIFF m of drop a metre out).

const QUAY_Y := 1.6
const SEAFLOOR := -14.0
## The land: a disc, cut by the harbour front.
const LAND_C := Vector2(0.0, -30.0)
const LAND_R := 150.0
const FRONT_Z := 62.0
const CLIFF := 1.6
## (1.27, Zach: a real rocky outcrop) the coast never comes nearer than COAST_MIN; the sea stacks round it ([frame point,
## radius, top]); the reef band (from REEF_IN to REEF_OUT past the coast) and the clear channel to the sea gate
## ([x half width round the berth's x, from z]); the west cove's beach (middle, radius) and the sewer drain in the cliff
## behind it (its mouth on the prison's west wall).
const COAST_MIN := 126.0
const STACKS := [[Vector2(172.0, 18.0), 7.0, 22.0], [Vector2(150.0, -128.0), 8.0, 16.0], [Vector2(-168.0, -96.0), 6.0, 26.0],
	[Vector2(-150.0, 64.0), 5.0, 12.0], [Vector2(118.0, 118.0), 5.0, 15.0], [Vector2(-104.0, 132.0), 6.0, 19.0],
	[Vector2(46.0, -214.0), 9.0, 21.0], [Vector2(-60.0, -206.0), 5.0, 13.0], [Vector2(190.0, -60.0), 4.0, 10.0]]
const REEF_IN := 8.0
const REEF_OUT := 90.0
const CHANNEL := [24.0, 62.0]
const BEACH := [Vector2(-128.0, -14.0), 17.0]
const DRAIN := Vector2(-108.6, -14.0)
const DRAIN_Y := 1.4
## The patch cut down to the cove's level behind the drain (the terrain's cells would smear the prison's 12 m step over the
## mouth); StrongholdShell fills it to the prison's floor over the culvert.
const DRAIN_CUT := Rect2(-113.6, -18.0, 10.0, 8.0)
## The districts' floors: [key, rect, height]. The Landing's quay first.
const DISTRICTS := [
	["landing", Rect2(-60.0, 36.0, 120.0, 26.0), QUAY_Y],
	["ward", Rect2(-46.0, -14.0, 92.0, 34.0), 12.0],
	["arsenal", Rect2(54.0, -46.0, 56.0, 60.0), 14.0],
	["prison", Rect2(-110.0, -46.0, 56.0, 60.0), 14.0],
	["keep", Rect2(-42.0, -112.0, 84.0, 64.0), 30.0],
]
## The chasm between the hub and the keep: sea down to the inlet's floor.
const CHASM := Rect2(-46.0, -48.0, 92.0, 34.0)
const CHASM_Y := -6.0
## The ways between districts: [from point, to point, half width] (frame xz; heights from the districts at each end).
## The grand stair up from the quay, the ramps to the wings, the Bridge of Judgement over the chasm.
const WAYS := [
	["stair", Vector2(0.0, 36.0), Vector2(0.0, 20.0), 6.0],
	["east ramp", Vector2(46.0, -4.0), Vector2(54.0, -4.0), 3.5],
	["west ramp", Vector2(-46.0, -4.0), Vector2(-54.0, -4.0), 3.5],
	["bridge", Vector2(0.0, -14.0), Vector2(0.0, -48.0), 3.5],
]
## Where the ship lies: alongside the quay's front, bow along +x.
const BERTH := Vector2(18.0, 68.0)
## The landmarks the shell builds (centres): the keep's tower, the prison's tower, the arsenal's foundry, the spire.
const KEEP := Vector2(0.0, -86.0)
const PRISON := Vector2(-82.0, -18.0)
const FOUNDRY := Vector2(82.0, -18.0)
const SPIRE := Vector2(-30.0, -60.0)


static func smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Signed distance from the coast (- inland).
static func land_t(q: Vector2) -> float:
	return maxf(q.distance_to(LAND_C) - coast_r(q), q.y - FRONT_Z)


## (1.27) The coast's radius by bearing: LAND_R wobbled by three harmonics into bays and headlands (never inside
## COAST_MIN, so no district is cut), the west cove's beach pushed out.
static func coast_r(q: Vector2) -> float:
	var a := (q - LAND_C).angle()
	var r := LAND_R + 13.0 * sin(3.0 * a + 1.0) + 8.0 * sin(7.0 * a + 2.3) + 4.0 * sin(13.0 * a + 0.7)
	return maxf(r, COAST_MIN)


## A rough noise in [-1, 1] from sines (the same everywhere, no rng): the rock's ledges, the reefs' patches.
static func noise(q: Vector2, k := 1.0) -> float:
	return 0.5 * sin(q.x * 0.07 * k + 1.3) * sin(q.y * 0.09 * k - 0.4) + 0.3 * sin(q.x * 0.19 * k + q.y * 0.13 * k) \
		+ 0.2 * sin(q.x * 0.41 * k - q.y * 0.37 * k + 2.0)


## The district at q (its index), or -1.
static func district_at(q: Vector2) -> int:
	for i in range(DISTRICTS.size()):
		if (DISTRICTS[i][1] as Rect2).has_point(q):
			return i
	return -1


## The way at q ([its index, its height there]) or [-1, -INF]: a way runs from its start's district height to its end's.
static func way_at(q: Vector2) -> Array:
	for i in range(WAYS.size()):
		var a: Vector2 = WAYS[i][1]
		var b: Vector2 = WAYS[i][2]
		var hw: float = WAYS[i][3]
		var ab := b - a
		var u := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if q.distance_to(a + ab * u) <= hw:
			return [i, lerpf(_height_near(a), _height_near(b), u)]
	return [-1, -INF]


## The height of the district at or nearest a way's end.
static func _height_near(p: Vector2) -> float:
	var best := INF
	var y := QUAY_Y
	for d in DISTRICTS:
		var r: Rect2 = d[1]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if c.distance_to(p) < best:
			best = c.distance_to(p)
			y = float(d[2])
	return y


## The designed ground: a district's floor or a way's slope where they are, else -INF.
static func ground(q: Vector2) -> float:
	var w := way_at(q)
	if int(w[0]) >= 0:
		return float(w[1])
	var di := district_at(q)
	return float(DISTRICTS[di][2]) if di >= 0 else -INF


## The rock: every district's height falling off in cliffs round it, the chasm cut down to the sea, and the sea floor
## past the coast.
static func terrain(q: Vector2) -> float:
	var t := land_t(q)
	# the rock: a rugged mound with ledges (the noise) rising inland, under the districts and between them
	var inland := smooth(-2.0, 40.0, -t)
	var h := lerpf(-2.0, 10.0 + 6.0 * noise(q), inland) + 3.0 * noise(q, 2.3) * inland
	# (never over the floors near it: the rock stays a metre under the nearest district)
	h = minf(h, _height_near(q) - 1.0)
	for d in DISTRICTS:
		var r: Rect2 = d[1]
		var c := Vector2(clampf(q.x, r.position.x, r.end.x), clampf(q.y, r.position.y, r.end.y))
		h = maxf(h, float(d[2]) - c.distance_to(q) * CLIFF * (1.0 + 0.45 * noise(q, 1.7)))
	# (the ways on the rock raise it to their slope; the bridge stands on its piers over the open chasm)
	var w := way_at(q)
	var on_rock := int(w[0]) >= 0 and str(WAYS[int(w[0])][0]) != "bridge"
	if on_rock:
		h = float(w[1])
	elif district_at(q) >= 0:
		h = float(DISTRICTS[district_at(q)][2])
	if DRAIN_CUT.has_point(q):
		h = DRAIN_Y - 0.2
	if CHASM.has_point(q) and not on_rock:
		h = minf(h, CHASM_Y)
	# the west cove: a shingle shelf from the drain's foot down into the water (never into a district)
	var bc: Vector2 = BEACH[0]
	var br: float = BEACH[1]
	var bd := q.distance_to(bc)
	if bd < br + 8.0 and district_at(q) < 0:
		var shelf := lerpf(DRAIN_Y - 0.2, -1.8, smooth(DRAIN.x - 2.0, bc.x - br, q.x)) + 0.25 * noise(q, 3.0)
		h = lerpf(h, shelf, 1.0 - smooth(br, br + 8.0, bd))
	# past the coast a sheer drop to the sea, reefs in a band round it, the sea stacks
	if t > -1.0:
		h = lerpf(h, sea_floor(q, t), smooth(-1.0, 6.0, t))
	for s in STACKS:
		var sp: Vector2 = s[0]
		var d := q.distance_to(sp)
		if d < float(s[1]) + 12.0:
			h = maxf(h, float(s[2]) - maxf(d - float(s[1]), 0.0) * 3.5 + 2.0 * noise(q, 2.7))
	return maxf(h, SEAFLOOR)


## The sea's floor past the coast (t: land_t): shelving down from the cliff's foot, reef patches in the band from
## REEF_IN to REEF_OUT (some breaking the surface), deep in the harbour basin and the channel to the sea gate.
static func sea_floor(q: Vector2, t: float) -> float:
	var sea := lerpf(-3.0, SEAFLOOR, smooth(0.0, 110.0, t))
	if in_channel(q):
		return minf(sea, -7.0)
	var n := noise(q, 1.6)
	var band := smooth(REEF_IN - 4.0, REEF_IN, t) * (1.0 - smooth(REEF_OUT - 25.0, REEF_OUT, t))
	if n > 0.05 and band > 0.0:
		sea = lerpf(sea, -1.4 + 2.6 * n, band)
	return sea


## The harbour basin inside the sea walls and the channel out from the sea gate: kept deep for the ship.
static func in_channel(q: Vector2) -> bool:
	if q.x > -58.0 and q.x < 58.0 and q.y > FRONT_Z - 1.0 and q.y < 100.0:
		return true
	return absf(q.x - BERTH.x) < float(CHANNEL[0]) and q.y >= float(CHANNEL[1])


## (1.27) The rooms you walk into (the encounter rooms of preview v2): [key, title, rect, floor y, height, door's
## side (the wall it's in, outward), door width]. The Mess Hall (the hub's sealed brawl), the barracks beside it, the
## Arsenal's casting hall (the Commodore's), and the Command Hall in the Verdict's base (the Vice Admiral's).
const ROOMS := [
	["mess", "The Mess Hall", Rect2(-42.0, -10.0, 24.0, 22.0), 12.0, 10.0, Vector2(1, 0), 4.0],
	["barracks", "The Barracks", Rect2(18.0, -10.0, 24.0, 22.0), 12.0, 10.0, Vector2(-1, 0), 4.0],
	["casting", "The Casting Hall", Rect2(68.0, -38.0, 30.0, 30.0), 14.0, 14.0, Vector2(-1, 0), 6.0],
	["command", "The Command Hall", Rect2(-24.0, -110.0, 48.0, 48.0), 30.0, 28.0, Vector2(0, 1), 8.0],
]


## The room at q (its index), or -1.
static func room_at(q: Vector2) -> int:
	for i in range(ROOMS.size()):
		if (ROOMS[i][2] as Rect2).has_point(q):
			return i
	return -1
