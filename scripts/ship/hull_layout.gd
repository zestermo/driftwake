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
## The cabin's fittings (crew classes; on the cabin floor): the bunk, the galley stove and counter, the storage
## chest, the table.
var bed_at := Vector3(-3.25, DECK_Y, 8.45)
var stove_at := Vector3(3.3, DECK_Y, 9.05)
var storage_at := Vector3(-2.7, DECK_Y, 5.75)
var counter_at := Vector3(3.35, DECK_Y, 7.55)
var table_at := Vector3(0.2, DECK_Y, 8.7)

static var _base: HullLayout
static var _cache := {}


## The pirates', traders' and wrecks' hull (the sloop as she was before 1.29).
static func base() -> HullLayout:
	if _base == null:
		_base = HullLayout.new()
		_base.cls = "base"
	return _base


## A crew class's layout with its cabin at `tier` (the Quarters line's level).
static func of(c: String, t: int) -> HullLayout:
	var key := "%s/%d" % [c, t]
	if not _cache.has(key):
		var l := HullLayout.new()
		l.cls = c
		l.tier = t
		_cache[key] = l
	return _cache[key]


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
	return absf(l.x) < 4.9 and l.z > float(rings[rings.size() - 1][0]) - 1.4 and l.z < qd_back + 0.7 \
		and l.y > minf(cabin_y, deck_y) - 1.72 and l.y < mast_top + 1.5


## Under the quarterdeck (in the cabin).
func in_cabin(l: Vector3) -> bool:
	return absf(l.x) < cabin_hw and l.z > qd_front and l.z < qd_back and l.y < qd_y - 0.3 and l.y > cabin_y - 0.82


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
