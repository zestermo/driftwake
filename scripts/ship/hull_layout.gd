class_name HullLayout
extends RefCounted
## A ship's layout as data (1.29): the hull's shape, the main deck, the quarterdeck and the cabin under it (its floor,
## walls, door and fittings), the stairs, the helm, the mast, nest and rigging, the ladders and the gun spots. All
## ship-local: stern +Z, bow -Z, +X starboard. One per crew class and cabin tier (`of`, `for_kit`: the Quarters line
## grows the cabin); the pirates', traders' and wrecks' hull is `base()`. HullBuilder draws and collides a layout, and
## everything aboard reads its own ship's (Ship.layout), never another's.

## The sloop hull's numbers, the start of every layout. Cross-sections along Z: [z, top half-width, bottom
## half-width, top y, bottom y]; ring 0 to 1 is the quarterdeck's length.
const RINGS := [
	[9.9, 4.05, 2.25, 0.35, -2.4],
	[5.0, 4.4, 2.4, 0.25, -2.85],
	[-3.0, 4.4, 2.25, 0.25, -2.85],
	[-8.25, 3.6, 1.5, 0.4, -2.55],
	[-12.6, 0.38, 0.15, 1.0, -1.35],
]
const DECK_Y := 0.32
## Origin height above the (averaged) water: the main deck stands ~1.8 m clear.
const FREEBOARD := 1.45
## Where the swell is sampled (bow, stern, either side).
const BOW_Z := -8.7
const STERN_Z := 8.7
const HALF_BEAM := 4.0

var cls := "sloop"
var tier := 0
var rings: Array = RINGS
var deck_y := DECK_Y
var freeboard := FREEBOARD
var bow_z := BOW_Z
var stern_z := STERN_Z
var half_beam := HALF_BEAM
## The bulwark above the hull's top edge (rail height over the sheer).
var lip := 0.45
## The quarterdeck: from qd_front aft to qd_back, its floor at qd_y.
var qd_front := 5.0
var qd_back := 9.9
var qd_y := DECK_Y + 2.4
## The cabin under it: walls at +-cabin_hw, its floor at cabin_y (below deck_y: steps down inside the door), a door
## 2*door_hw wide and door_h high (from the main deck).
var cabin_hw := 3.95
var cabin_y := DECK_Y
var door_hw := 0.65
var door_h := 2.05
## Stairs up to the quarterdeck either side of the cabin front (x from stair_x0 to cabin_hw), from stair_z0 on the
## main deck to qd_front.
var stair_x0 := 2.75
var stair_z0 := 1.4
var stair_steps := 8
## The wheel and where the helmsman stands (on the quarterdeck).
var wheel_z := 6.6
var helm_z := 7.4
## Mast, yard, crow's nest (nest_r: room to walk round the mast).
var mast_z := -1.8
var mast_top := 16.8
var mast_r := 0.3
var yard_y := 13.8
var nest_y := 15.0
var nest_r := 1.6
## Ratlines from the rail (bottom) up to the nest's edge (top), +x side; the port side mirrors it.
var rig_bottom := Vector3(3.75, DECK_Y + 0.85, -1.8)
var rig_top := Vector3(1.5, 15.05, -1.8)
## Rope ladders down the hull from the water, amidships.
var ladder_z := -2.9
var ladder_len := 3.0
## The gun pairs: [z, x, deck y] (the third, on the quarterdeck, is the refit's).
var gun_spots: Array = [[-6.8, 3.0, DECK_Y], [-4.2, 3.65, DECK_Y], [8.0, 3.55, DECK_Y + 2.4]]
## How many of gun_spots are always fitted (the one after them is the Gun deck line's quarterdeck pair).
var base_guns := 2

## (1.30) The brig's and galleon's numbers over the sloop's (every one below is the sloop's own for her and base()).
## The map from the sloop's deck onto this hull (x and z stretched; heights stay a captain's): fittings that ShipParts
## and Ship place by the sloop's numbers go through map().
var kx := 1.0
var kz := 1.0
## The bowsprit's foot and length, where the forestays come down at the bow, the main deck's rail stanchions (z),
## the quarterdeck's front and stern rail posts (x).
var sprit_at := Vector3(0, 1.05, -12.3)
var sprit_len := 4.5
var stay_z := -12.0
var stanchions: Array = [-9.5, -6.0, -3.0, 0.0, 3.0]
var qd_posts: Array = [-2.6, -1.3, 0.0, 1.3, 2.6]
## The main yard's width and how much bigger its sail is than the sloop's (x across, y down).
var yard_w := 9.0
var sail_k := Vector2.ONE
## More masts than the main (which carries the nest and the ratlines): [z, foot y, top y, yard y, yard width] each.
var masts: Array = []
## Ship's fittings on deck: the anchor's cathead, the capstan, the bilge pump, the figurehead (and its scale), the
## crates you sit on, where holes, fires and torn-sail mends land, the waterline (ship-local y).
var anchor_at := Vector3(2.4, 1.3, -9.3)
var capstan_at := Vector3(0.0, DECK_Y, -7.0)
var pump_at := Vector3(1.2, DECK_Y, -0.3)
var figure_at := Vector3(0, 0.2, -12.7)
var figure_k := 2.0
var deck_seats: Array = [[Vector3(2.1, DECK_Y + 0.6, -0.4), 0.6, Vector3(-1, 0, 0)], [Vector3(-2.2, DECK_Y + 0.5, -4.5), 0.5, Vector3(1, 0, 0)]]
var mend_at: Array = [Vector3(-1.2, DECK_Y, -2.9), Vector3(1.2, DECK_Y, -2.9), Vector3(-1.1, DECK_Y, -0.7)]
var deck_z_min := -7.8
var deck_z_max := 4.4
var deck_x_max := 2.6
var waterline_y := -1.15
## The helm's camera arm (m).
var cam_arm := 21.0
## (the galleon) A gun deck under the main deck: its floor at lower_y from lower_front aft to lower_back, reached down
## a stair through a hatch in the main deck (hatch: [z top, z foot, half-width]); NAN without one.
var lower_y := NAN
var lower_front := 0.0
var lower_back := 0.0
var hatch: Array = []
## (the galleon) The poop: a deck over the quarterdeck from poop_front aft at poop_y, a stateroom under it on the
## quarterdeck (its door forward), stairs up either side. poop_front past qd_back: none.
var poop_front := 99.0
var poop_y := 0.0
## Several rooms (the brig and galleon: ShipRooms furnishes them) instead of the sloop's one cabin (ShipCabin's tiers).
var rooms := false
## The cabin's fittings (crew classes; on the cabin floor): the bunk, the galley stove and counter, the storage
## chest, the table.
var bed_at := Vector3(-3.25, DECK_Y, 8.45)
var stove_at := Vector3(3.3, DECK_Y, 9.05)
var storage_at := Vector3(-2.7, DECK_Y, 5.75)
var counter_at := Vector3(3.35, DECK_Y, 7.55)
var table_at := Vector3(0.2, DECK_Y, 8.7)
var pantry_at := Vector3(3.25, DECK_Y, 5.6)

static var _base: HullLayout
static var _cache := {}


## The pirates', traders' and wrecks' hull (the sloop as she was before 1.29).
static func base() -> HullLayout:
	if _base == null:
		_base = HullLayout.new()
		_base.cls = "base"
	return _base


## A crew class's layout with its cabin at `tier` (the Quarters line's level; the brig's and galleon's rooms don't grow).
static func of(c: String, t: int) -> HullLayout:
	if c in ROOMED:
		t = 0
	var key := "%s/%d" % [c, t]
	if not _cache.has(key):
		var l := HullLayout.new()
		l.cls = c
		l.tier = t
		l._crew(t)
		if c == "brig":
			l._brig()
		elif c == "galleon":
			l._galleon()
		_cache[key] = l
	return _cache[key]


## The classes with their own several-room layouts (1.30): no Quarters line.
const ROOMED := ["brig", "galleon"]


## The sloop's deck onto this hull: x and z stretched, heights kept.
func map(p: Vector3) -> Vector3:
	return Vector3(p.x * kx, p.y, p.z * kz)


## (1.30) The sloop's layout stretched kx across and kz along (the hull d deeper, the bow's sheer up `bow_up`), riding
## with the deck `fb` over the water: everything ShipParts and Ship place by the sloop's numbers lands on her by map().
func _scale(x: float, z: float, d: float, fb: float, bow_up: float) -> void:
	kx = x
	kz = z
	var out: Array = []
	for i in range(RINGS.size()):
		var r: Array = RINGS[i]
		# (her sheer rising to the bow: the bow ring bow_up, the one before it a third of that)
		var up := bow_up if i == RINGS.size() - 1 else (bow_up * 0.3 if i == RINGS.size() - 2 else 0.0)
		out.append([float(r[0]) * z, float(r[1]) * x, float(r[2]) * x, float(r[3]) + up, float(r[4]) * d])
	rings = out
	var bow := float(rings[rings.size() - 1][0])
	freeboard = fb
	bow_z = BOW_Z * z
	stern_z = STERN_Z * z
	half_beam = HALF_BEAM * x
	qd_front *= z
	qd_back = float(rings[0][0])
	cabin_hw *= x
	stair_x0 *= x
	stair_z0 = qd_front - 3.5
	wheel_z *= z
	helm_z *= z
	mast_z *= z
	ladder_z *= z
	ladder_len = DECK_Y + fb + 0.06
	sprit_at = Vector3(0, sprit_at.y + bow_up, bow + 0.3)
	sprit_len *= sqrt(z)
	stay_z = bow + 0.6
	qd_posts = qd_posts.map(func(v): return float(v) * x)
	anchor_at = map(anchor_at) + Vector3(0, bow_up * 0.6, 0)
	capstan_at = map(capstan_at)
	pump_at = map(pump_at)
	figure_at = Vector3(0, figure_at.y + bow_up, bow - 0.1)
	figure_k *= sqrt(x)
	deck_seats = deck_seats.map(func(s): return [map(s[0]), s[1], s[2]])
	mend_at = mend_at.map(func(v): return map(v))
	deck_z_min *= z
	deck_z_max *= z
	deck_x_max *= x
	waterline_y = 0.3 - fb
	cam_arm *= 0.6 + 0.4 * z
	rooms = true


## Stanchions every `step` m from the bow aft to the quarterdeck's stairs.
func _posts(step: float) -> Array:
	var out: Array = []
	var z := float(rings[rings.size() - 1][0]) + 3.1
	while z < stair_z0 - 0.4:
		out.append(snappedf(z, 0.1))
		z += step
	return out


## A pair of guns at z on the deck at y, inboard of the side by `inset`.
func _gun(z: float, y: float, inset: float) -> Array:
	return [z, snappedf(side_at(z, y + 0.9) - inset, 0.01), y]


## (1.30) The brig: 1.5x the sloop's length and 1.25x her beam (~34 m by 11), two masts (a foremast forward of the
## main, which carries the nest), five gun pairs down her waist (one gun deck) and a sixth on the quarterdeck from
## the Gun deck line, a cabin of two rooms under the quarterdeck: a lounge and galley forward of a partition, the
## captain's cabin aft (ShipRooms).
func _brig() -> void:
	_scale(1.25, 1.5, 1.25, 1.8, 0.7)
	mast_r = 0.38
	mast_top = 21.0
	yard_y = 17.0
	nest_y = 18.4
	nest_r = 1.75
	yard_w = 11.0
	sail_k = Vector2(1.22, 1.3)
	rig_bottom = Vector3(rig_bottom.x * kx, rig_bottom.y, mast_z)
	rig_top = Vector3(1.65, nest_y + 0.05, mast_z)
	masts = [[-12.0, DECK_Y, 18.6, 15.0, 9.6]]
	stanchions = _posts(3.0)
	gun_spots = []
	for z in [-14.6, -9.4, -6.6, -0.4, 2.3]:
		gun_spots.append(_gun(z, deck_y, 0.8))
	gun_spots.append(_gun(12.0, qd_y, 0.85))
	base_guns = 5
	storage_at = Vector3(-cabin_hw + 0.95, cabin_y, qd_front + 0.85)
	pantry_at = Vector3(cabin_hw - 0.7, cabin_y, qd_front + 1.3)
	counter_at = Vector3(cabin_hw - 0.6, cabin_y, qd_front + 2.95)
	stove_at = Vector3(cabin_hw - 0.65, cabin_y, qd_front + 3.85)
	table_at = Vector3(1.75, cabin_y, qd_front + 2.5)
	bed_at = Vector3(-cabin_hw + 0.75, cabin_y, qd_back - 1.45)


## (1.30) The galleon: 2.2x the sloop's length and 1.5x her beam (~50 m by 13), standing high: three masts (the
## mizzen on the poop), a gun deck under the main deck (down a hatch) with five pairs and five more on the main deck,
## a sixth-and-more on the quarterdeck from the Gun deck line; a high stern castle: the cabin at main-deck level under
## the quarterdeck (a lounge and galley, the crew's bunk room aft), and the captain's stateroom on the quarterdeck under
## the poop.
func _galleon() -> void:
	_scale(1.5, 2.2, 1.65, 3.0, 0.9)
	cabin_y = deck_y
	qd_y = DECK_Y + 2.68
	stair_z0 = qd_front - 3.9
	stair_steps = 9
	poop_front = 15.6
	poop_y = qd_y + 2.6
	wheel_z = 13.3
	helm_z = 14.1
	mast_r = 0.46
	mast_top = 26.0
	yard_y = 21.4
	nest_y = 22.8
	nest_r = 1.9
	yard_w = 14.0
	sail_k = Vector2(1.5, 1.75)
	rig_bottom = Vector3(rig_bottom.x * kx, rig_bottom.y, mast_z)
	rig_top = Vector3(1.75, nest_y + 0.05, mast_z)
	masts = [[-18.5, DECK_Y, 22.0, 18.2, 12.0], [18.6, poop_y, poop_y + 12.0, poop_y + 9.8, 8.0]]
	stanchions = _posts(3.4)
	lower_y = -2.0
	lower_front = -16.0
	lower_back = qd_front
	hatch = [2.0, 5.4, 0.85]
	gun_spots = []
	for z in [-22.0, -14.0, -10.5, -0.8, 3.0]:
		gun_spots.append(_gun(z, deck_y, 0.8))
	for z in [-13.0, -8.5, -1.5, 2.8, 7.0]:
		gun_spots.append(_gun(z, lower_y, 0.95))
	gun_spots.append(_gun(11.0, qd_y, 0.85))
	base_guns = 10
	storage_at = Vector3(-cabin_hw + 0.95, cabin_y, qd_front + 1.0)
	pantry_at = Vector3(cabin_hw - 0.7, cabin_y, qd_front + 1.3)
	counter_at = Vector3(cabin_hw - 0.6, cabin_y, qd_front + 3.0)
	stove_at = Vector3(cabin_hw - 0.65, cabin_y, qd_front + 3.9)
	table_at = Vector3(2.2, cabin_y, qd_front + 2.6)
	bed_at = Vector3(-cabin_hw + 0.75, cabin_y, 17.4)


## The poop seen as a quarterdeck one storey up (HullBuilder draws and collides it with the same code): the
## quarterdeck its main deck and the stateroom's floor, the poop over it, its stairs up either side.
func castle_view() -> HullLayout:
	var v := HullLayout.new()
	v.cls = cls
	v.rings = rings
	v.lip = lip
	v.kx = kx
	v.kz = kz
	v.cabin_hw = cabin_hw
	v.door_hw = door_hw
	v.door_h = door_h
	v.stair_x0 = stair_x0
	v.qd_posts = qd_posts
	v.qd_back = qd_back
	v.deck_y = qd_y
	v.cabin_y = qd_y
	v.qd_y = poop_y
	v.qd_front = poop_front
	v.stair_z0 = poop_front - 3.9
	v.stair_steps = stair_steps
	return v


## The poop over the quarterdeck (the galleon's).
func has_poop() -> bool:
	return poop_front < qd_back


## A gun deck under the main deck (the galleon's).
func has_lower() -> bool:
	return not is_nan(lower_y)


## The crew's ships (1.29, every class: they share the sloop's deck): the cabin stepped down into the hull and
## 0.6 m longer than the pirates', the hull ladders ending at the waterline. The Quarters line grows it: 1 a metre
## longer (forward: the quarterdeck and its stairs with it), 3 a taller deckhead (the quarterdeck 0.25 m up), 4 a
## second step down.
func _crew(t: int) -> void:
	cabin_y = DECK_Y - (0.6 if t >= 4 else 0.4)
	qd_front = 4.4 if t < 1 else 3.4
	stair_z0 = qd_front - 3.5
	if t >= 3:
		qd_y = DECK_Y + 2.65
	ladder_len = DECK_Y + FREEBOARD + 0.06
	gun_spots = [[-6.8, 3.0, DECK_Y], [-4.2, 3.65, DECK_Y], [8.0, 3.55, qd_y]]
	bed_at = Vector3(-3.25, cabin_y, 8.45)
	stove_at = Vector3(3.3, cabin_y, 9.05)
	counter_at = Vector3(3.35, cabin_y, 7.55)
	storage_at = Vector3(-2.7, cabin_y, qd_front + 1.35)
	table_at = Vector3(0.2, cabin_y, 8.4)
	pantry_at = Vector3(3.25, cabin_y, qd_front + 1.25)


## (A merged kit: ShipKit.merged. Read as plain keys: tests load this before the autoloads.)
static func for_kit(kit: Dictionary) -> HullLayout:
	return of(str(kit.get("class", "sloop")), int(kit.get("quarters", 0)))


## Half the deck's width at `z`.
func half_width(z: float) -> float:
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var t := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return 0.45


## [z, top half-width, bottom half-width, top y, bottom y] at `z` (the end ring past either end).
func ring_at(z: float) -> Array:
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var k := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			var out: Array = [z]
			for j in range(1, 5):
				out.append(lerpf(float(a[j]), float(b[j]), k))
			return out
	return rings[0] if z > 0.0 else rings[rings.size() - 1]


## The hull's half-width at (z, y): straight up from its top edge, tapering to the keel.
func side_at(z: float, y: float) -> float:
	var r := ring_at(z)
	var k := clampf((float(r[3]) - y) / maxf(float(r[3]) - float(r[4]), 0.01), 0.0, 1.0)
	return lerpf(float(r[1]), float(r[2]), k)


## Inside the ship's bounds: on a deck, in the cabin, in the rigging or the nest, on a ladder, jumping about over
## the deck.
func aboard_local(l: Vector3) -> bool:
	var low := minf(cabin_y, deck_y)
	if has_lower():
		low = minf(low, lower_y)
	return absf(l.x) < half_beam + 0.9 and l.z > float(rings[rings.size() - 1][0]) - 1.4 and l.z < qd_back + 0.7 \
		and l.y > low - 1.72 and l.y < mast_top + 1.5


## Under the quarterdeck (in the cabin), or (the galleon) in the stateroom under the poop.
func in_cabin(l: Vector3) -> bool:
	if has_poop() and absf(l.x) < cabin_hw and l.z > poop_front and l.z < qd_back and l.y > qd_y - 0.3 and l.y < poop_y - 0.3:
		return true
	return absf(l.x) < cabin_hw and l.z > qd_front and l.z < qd_back and l.y < qd_y - 0.3 and l.y > cabin_y - 0.82


## (the galleon) Below, on the gun deck.
func in_hold(l: Vector3) -> bool:
	return has_lower() and l.z > lower_front and l.z < lower_back and l.y < deck_y - 0.3 and l.y > lower_y - 0.5 \
		and absf(l.x) < half_width(l.z)


## Angles of the crow's nest rail's boards (a gap each side for the ratlines).
func nest_rail() -> Array:
	var out: Array = []
	for k in range(12):
		var a := TAU * (k + 0.5) / 12.0
		if absf(cos(a)) < 0.95:
			out.append(a)
	return out


func nest_rail_at(a: float) -> Vector3:
	return Vector3(cos(a) * (nest_r - 0.05), nest_y + 0.45, mast_z + sin(a) * (nest_r - 0.05))
