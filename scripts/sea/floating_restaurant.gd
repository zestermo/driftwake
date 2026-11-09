class_name FloatingRestaurant
extends SeaVessel
## The floating restaurant (docs/v1_28_plan.md, The sea): a huge ship-restaurant at anchor on a sea leg, a hub at
## sea. An 84 x 42 m barge with a great carved fish's head for a bow, a two-storey timber-framed dining hall with a
## tiled roof, a lantern tower and the kitchen chimney, banners on four tall poles: seen from far off. Come alongside
## the landing stage on her starboard side (a pontoon at the waterline, a ramp up to the deck) or climb a ladder.
## Inside: the head chef behind the kitchen counter sells the day's dishes and teaches recipes (the Captain's Feast,
## and the house's Tidewater Bouillabaisse); a room to rest in (rest and save, GameManager.rest); a rumour board
## with word of the stops on the legs ahead; the cook-off table: once a visit, the judge names a dish and you cook it
## in the cooking game (no ingredients needed, a little quicker than the galley's), prizes by the grade (COOKOFF).
## Sometimes (ATTACK_CHANCE, seeded) pirates hold her deck when you arrive, a pirate sloop standing by: beat the
## boarders and the chef's favour teaches the crew the bouillabaisse for nothing (world flag, every captain).
## At anchor: she doesn't move or roll (a hull this broad sits still on the swell).

const Shops := preload("res://scripts/game/shops.gd")

const ATTACK_CHANCE := 0.4
const SPECIAL := "tidewater_bouillabaisse"
## Gold for each recipe [the feast, the house special].
const RECIPE_PRICE := {"captains_feast": 150, "tidewater_bouillabaisse": 400}
const NAMES := ["The Drifting Ladle", "The Saltbelly", "The Leviathan's Table", "The Floating Larder", "The Gull and Kettle"]
const CHEFS := ["Barro Kettlewick", "Marisol Vance", "Odo Brineheart", "Tamsin Rook", "Ferro Saltmarsh"]
const DISHES := [["fish_stew"], ["reef_salad"], ["forest_curry"], ["porridge"], ["island_skewers"], ["citrus_tart"], ["peppered_boar"]]
## The cook-off: the game's speed, and by grade (Burnt, Fair, Good, Perfect) the gold, Cooking XP and a prize item [id, n].
const COOKOFF_SPEED := 1.15
const COOKOFF := [{"gold": 0, "xp": 20, "item": []}, {"gold": 40, "xp": 60, "item": []},
	{"gold": 120, "xp": 120, "item": ["staple", 3]}, {"gold": 300, "xp": 250, "item": ["book_atlas", 1]}]
const COOKOFF_SAY := ["Burnt to the pan. Everyone starts somewhere. Most of them start better.",
	"Edible. The gulls agree. Here's a little something for trying.", "Good! Clean work. Take these, they're from my own larder.",
	"Perfect. I haven't tasted the like since my mother's galley. Take this, and tell no one I cried."]

## Hull: the deck at y 0 (ship-local), half beam HW, from the stern ST to the bow BW, the keel at KEEL; the fish past BW.
const HW := 21.0
const ST := 42.0
const BW := -42.0
const KEEL := -5.6
## The deck's outline (x, z), port side stern to bow; mirrored for starboard.
const EDGE := [Vector2(19.4, 42.0), Vector2(21.0, 37.0), Vector2(21.0, -28.0), Vector2(18.4, -38.0), Vector2(15.0, -42.0)]
## The hall's ground floor (its upper storey jetties out JETTY and stands UPPER tall); BAY: its timber bays along z.
const HALL := [Vector3(-12.0, 0.0, -24.0), Vector3(12.0, 5.4, 14.0)]
const UPPER := 4.2
const JETTY := 0.6
const BAY := 4.75
const DOOR_HW := 1.6
const DOOR_H := 3.4
## The starboard door (onto the landing), in the hall's fourth bay.
const SIDE_Z := -7.375
const SIDE_HW := 1.2
const SIDE_H := 3.0
const PONTOON := [Vector3(21.4, -1.85, 0.0), Vector3(25.4, -1.5, 24.0)]
const RAMP := [Vector3(22.6, -1.5, 2.0), Vector3(22.6, 0.0, -6.0)]
const RAMP_HEAD := [Vector3(20.8, -0.3, -8.4), Vector3(24.2, 0.0, -6.0)]
## The fish's head past the bow: rings [distance forward of BW, half width, half depth, centre y].
const FISH := [[0.0, 15.0, 2.8, -2.8], [5.0, 14.2, 5.0, 1.1], [12.0, 12.8, 6.4, 2.2], [19.0, 9.6, 5.6, 1.8], [23.5, 5.4, 3.8, 1.0], [26.0, 1.0, 1.4, 0.6]]
## The mouth line's height at the snout (it curls up 0.6 at the corners).
const MOUTH_Y := 0.3
const AWNING := [Vector2(-12.0, 14.0), Vector2(12.0, 30.0)]

var level := 1
var seed_value := 1
var anchor := Vector3.ZERO
var place_name := ""
var chef_name := ""
var shop_id := ""
var attacked := false
var chef: NPC
var camp: GruntCamp
var fleet: EnemyFleet
var _flag := ""
var _thanked := false
var _poll := 0.0
var _cooked_off := false


func setup(at: Vector3, lvl: int, seed_: int) -> FloatingRestaurant:
	anchor = Vector3(at.x, 0.0, at.z)
	level = lvl
	seed_value = seed_
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, "restaurant"])
	place_name = NAMES[rng.randi() % NAMES.size()]
	chef_name = "Chef " + str(CHEFS[rng.randi() % CHEFS.size()])
	attacked = rng.randf() < ATTACK_CHANCE
	_flag = "stop%d_saved" % seed_
	return self


func _build() -> void:
	freeboard = 2.2
	half_len = 40.0
	half_beam = HW
	bounds = AABB(Vector3(-27.0, -6.0, -70.0), Vector3(54.0, 50.0, 113.0))
	_model()
	_collide()
	_fittings()
	_people()
	if attacked and not GameManager.world_flags.has(_flag):
		_raiders()
	else:
		_thanked = GameManager.world_flags.has(_flag)


func _swell(_delta: float) -> void:
	_y = freeboard
	_pitch = 0.0
	_roll = 0.0


func _brain(_delta: float) -> Array:
	return [_heading, 0.0]


func sleep_ok() -> bool:
	return not anyone_aboard() and (camp == null or camp.alive_count() == 0)


# --------------------------------------------------------------------------
# The model: the big shapes in one mesh seen from far off, the dressing in another (near only, no shadow)
# --------------------------------------------------------------------------
var _m := {}


func _mats() -> void:
	_m = {
		"hull": PSXMat.lit("planks_dark", Color(0.95, 0.5, 0.36)),
		"deck": PSXMat.lit("planks", Color(0.92, 0.84, 0.72)),
		"trim": PSXMat.lit("planks", Color(1.0, 0.82, 0.42)),
		"wall": PSXMat.lit("plaster_wash", Color(0.98, 0.93, 0.82)),
		"beam": PSXMat.lit("planks_dark", Color(0.55, 0.36, 0.24)),
		"roof": PSXMat.lit("roof_tiles", Color(0.8, 0.32, 0.22)),
		"fish": PSXMat.lit("scales", Color(0.95, 0.55, 0.25)),
		"belly": PSXMat.lit("scales", Color(1.0, 0.9, 0.7)),
		"window": PSXMat.lit("window", Color.WHITE, {"emission": Color(1.0, 0.75, 0.38), "emission_energy": 0.9, "emission_tex": "window"}),
		"glow": PSXMat.glow(Color(1.0, 0.78, 0.42), 2.0),
		"dark": PSXMat.lit("planks_dark", Color(0.25, 0.2, 0.18)),
		"wood": PSXMat.lit("bark"),
		"red": PSXMat.lit("cloth_red", Color(0.95, 0.3, 0.22)),
		"cream": PSXMat.lit("canvas", Color(0.98, 0.94, 0.84)),
		"stone": PSXMat.lit("stone_brick"),
		"paint": PSXMat.lit("planks", Color(0.32, 0.62, 0.66)),
		"leaves": PSXMat.lit("leaves", Color(0.8, 1.0, 0.8)),
		"door": PSXMat.lit("door_panel", Color(0.5, 0.34, 0.24), {"vertex_color": false}),
	}


static func _xf(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


## A frame facing `out` (local z) at `p`: x along the wall, y up.
static func _face(p: Vector3, out: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), p)


func _model() -> void:
	_mats()
	var mb := MeshBuilder.new()
	var dress := MeshBuilder.new()
	_hull(mb, dress)
	_fish(mb, dress)
	_hall(mb, dress)
	_terrace(mb, dress)
	_landing(mb, dress)
	_deck_dressing(mb, dress)
	var inst := mb.to_instance("PSXModel")
	inst.visibility_range_end = 2400.0
	add_child(inst)
	var d := dress.to_instance("Dressing")
	d.visibility_range_end = 320.0
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(d)
	_signs()
	_lights()
	_interior()


func _hull(mb: MeshBuilder, dress: MeshBuilder) -> void:
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	var prof := PackedVector2Array([Vector2(-1, 1), Vector2(-1, -0.35), Vector2(-0.7, -1), Vector2(0.7, -1), Vector2(1, -0.35), Vector2(1, 1)])
	var rings: Array = []
	for e in EDGE:
		rings.append([ST - e.y, e.x, -KEEL * 0.5, KEEL * 0.5])
	mb.add_loft(_m["hull"], Transform3D(down, Vector3(0, 0, ST)), rings, prof, 0.5, Color.WHITE, false, false, false, true)
	# the stern's transom with its gallery windows, a gilt rail over them
	var hw0: float = EDGE[0].x
	var tr := PackedVector2Array([Vector2(-hw0, 0.0), Vector2(-hw0, KEEL * 0.5 - 0.35 * -KEEL * 0.5), Vector2(-hw0 * 0.7, KEEL),
		Vector2(hw0 * 0.7, KEEL), Vector2(hw0, KEEL * 0.5 - 0.35 * -KEEL * 0.5), Vector2(hw0, 0.0)])
	mb.add_extrude(_m["hull"], _xf(Vector3(0, 0, ST - 0.15)), tr, 0.3, 0.5)
	for x in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		mb.add_box_unit_uv(_m["window"], _xf(Vector3(x, -1.3, ST + 0.02)), Vector3(1.6, 1.1, 0.06))
		dress.add_box(_m["trim"], _xf(Vector3(x, -0.66, ST + 0.06)), Vector3(1.9, 0.14, 0.12), 1.0, Color.WHITE, false)
		dress.add_box(_m["trim"], _xf(Vector3(x, -1.94, ST + 0.06)), Vector3(1.9, 0.14, 0.12), 1.0, Color.WHITE, false)
	mb.add_box(_m["trim"], _xf(Vector3(0, -0.4, ST + 0.08)), Vector3(hw0 * 2.0, 0.22, 0.16), 1.0, Color.WHITE, false)
	# the deck
	var outline := PackedVector2Array()
	for e in EDGE:
		outline.append(Vector2(-e.x, e.y))
	for i in range(EDGE.size() - 1, -1, -1):
		outline.append(Vector2(EDGE[i].x, EDGE[i].y))
	mb.add_extrude(_m["deck"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.2, 0)), outline, 0.4, 0.4)
	# the bulwarks (a gap for the starboard ramp), a gilt cap rail, stanchions inside, a rub rail and portholes outside
	for s in [-1.0, 1.0]:
		var pts: Array = []
		for e in EDGE:
			pts.append(Vector3(s * (e.x - 0.13), 0.0, e.y))
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if s > 0.0 and i == 1:
				_bulwark(mb, a, Vector3(b.x, 0, RAMP_HEAD[1].z))
				_bulwark(mb, Vector3(b.x, 0, RAMP_HEAD[0].z), b)
			else:
				_bulwark(mb, a, b)
		for z in range(-26, 37, 4):
			dress.add_box(_m["beam"], _xf(Vector3(s * (HW - 0.34), 0.5, z)), Vector3(0.16, 1.0, 0.16), 1.0)
		mb.add_box(_m["trim"], _xf(Vector3(s * (HW + 0.08), -0.45, 4.5)), Vector3(0.2, 0.26, 65.0), 1.0, Color.WHITE, false)
		mb.add_box(_m["trim"], _xf(Vector3(s * (HW + 0.05), -2.0, 4.5)), Vector3(0.14, 0.14, 65.0), 1.0, Color(0.8, 0.8, 0.8), false)
		for z in range(-24, 36, 5):
			var at := Vector3(s * (HW - 0.1), -1.2, z + 0.5)
			mb.add_cylinder(_m["glow"], Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), at), 0.32, 0.32, 0.16, 8, 1.0)
			dress.add_cylinder(_m["trim"], Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), at), 0.46, 0.46, 0.12, 8, 1.0)
	_bulwark(mb, Vector3(-hw0, 0, ST - 0.13), Vector3(hw0, 0, ST - 0.13))
	# at anchor: two chains from the hawse holes down into the sea
	for s in [-1.0, 1.0]:
		var hawse := Vector3(s * 15.3, -1.0, BW + 1.0)
		dress.add_cylinder(_m["dark"], Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), hawse - Vector3(s * 0.3, 0, 0)), 0.45, 0.45, 0.4, 8, 1.0)
		mb.add_tube(_m["dark"], MeshBuilder.sag_points(hawse, Vector3(s * 22.0, -14.0, BW - 16.0), 1.5, 8), 0.16, -1.0, 4, 1.0)


## A planked bulwark from a to b (deck level), its gilt cap.
func _bulwark(mb: MeshBuilder, a: Vector3, b: Vector3) -> void:
	Buildings.beam_between(mb, _m["hull"], a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), 0.26, 1.0)
	Buildings.beam_between(mb, _m["trim"], a + Vector3(0, 1.04, 0), b + Vector3(0, 1.04, 0), 0.4, 0.1)


static func _fish_at(t: float) -> Array:
	for i in range(FISH.size() - 1):
		var a: Array = FISH[i]
		var b: Array = FISH[i + 1]
		if t <= float(b[0]):
			var k := clampf((t - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return [lerpf(a[1], b[1], k), lerpf(a[3], b[3], k), lerpf(a[2], b[2], k)]
	var l: Array = FISH[FISH.size() - 1]
	return [l[1], l[3], l[2]]


## A point on the fish's side (s = -1 port, 1 starboard) `t` forward of the bow, at height y, `out` off the surface.
static func _fish_side(s: float, t: float, y: float, out: float = 0.0) -> Vector3:
	return Vector3(s * (float(_fish_at(t)[0]) + out), y, BW - t)


func _fish(mb: MeshBuilder, dress: MeshBuilder) -> void:
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	var sq := PackedVector2Array([Vector2(0.7, -1), Vector2(1, -0.35), Vector2(1, 0.3), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, 0.3), Vector2(-1, -0.35), Vector2(-0.7, -1)])
	var rings: Array = []
	for r in FISH:
		rings.append([r[0], r[1], r[2], r[3]])
	rings[0] = [0.0, FISH[0][1], FISH[0][2], FISH[0][3], 0.0, sq]
	mb.add_loft(_m["fish"], Transform3D(down, Vector3(0, 0, BW)), rings, MeshBuilder.profile_oct(0.5), 0.45, Color.WHITE, false, true)
	# the pale throat under the jaw
	mb.add_loft(_m["belly"], Transform3D(down, Vector3(0, 0, BW - 4.0)), [[0.0, 13.4, 1.6, -3.2], [8.0, 12.2, 2.0, -2.4], [15.0, 9.0, 1.8, -1.8],
		[19.5, 4.6, 1.2, -1.4], [21.6, 1.0, 0.6, -1.0]], MeshBuilder.profile_oct(0.5), 0.45, Color.WHITE, false, true)
	# the mouth: a dark gap between pink lips, curling up at the corners, teeth along both
	var up := PackedVector3Array()
	var lo := PackedVector3Array()
	var gap := PackedVector3Array()
	for s in [-1.0, 1.0]:
		for k in range(9):
			var t := (9.0 + k * 2.1) if s < 0.0 else (9.0 + (8 - k) * 2.1)
			var g := clampf((t - 9.0) / 5.0, 0.0, 1.0) * 0.55
			var y := MOUTH_Y + (1.0 - clampf((t - 9.0) / 5.0, 0.0, 1.0)) * 0.6
			up.append(_fish_side(s, t, y + g, 0.12))
			lo.append(_fish_side(s, t, y - g, 0.12))
			gap.append(_fish_side(s, t, y, -0.05))
		if s < 0.0:
			up.append(Vector3(0, MOUTH_Y + 0.55, BW - 26.2))
			lo.append(Vector3(0, MOUTH_Y - 0.55, BW - 26.2))
			gap.append(Vector3(0, MOUTH_Y, BW - 26.25))
	var lip := Color(1.0, 0.8, 0.75)
	mb.add_tube(_m["dark"], gap, 0.42, -1.0, 5, 1.0)
	mb.add_tube(_m["red"], up, 0.4, -1.0, 6, 1.0, lip)
	mb.add_tube(_m["red"], lo, 0.4, -1.0, 6, 1.0, lip)
	for s in [-1.0, 1.0]:
		for k in range(8):
			var t := 11.5 + k * 1.75
			var g := clampf((t - 9.0) / 5.0, 0.0, 1.0) * 0.55
			var y := MOUTH_Y + (1.0 - clampf((t - 9.0) / 5.0, 0.0, 1.0)) * 0.6
			mb.add_cone(_m["wall"], Transform3D(Basis(Vector3.RIGHT, PI), _fish_side(s, t, y + g - 0.1, 0.3)), 0.42, 1.0, 5, 1.0)
			if k % 2 == 1:
				mb.add_cone(_m["wall"], _xf(_fish_side(s, t + 0.8, y - g + 0.1, 0.3)), 0.36, 0.8, 5, 1.0)
	# the painted eyes: white, a gold iris, the pupil and its glint, a heavy lid over the top
	for s in [-1.0, 1.0]:
		var eye := _fish_side(s, 13.0, 4.0, -0.3)
		var turn := Basis(Vector3.BACK, -s * PI * 0.5)
		mb.add_cylinder(_m["wall"], Transform3D(turn, eye), 2.2, 2.2, 0.7, 14, 1.0, Color(1.05, 1.05, 1.05), true, false, false)
		mb.add_cylinder(_m["trim"], Transform3D(turn, eye), 1.25, 1.25, 0.76, 12, 1.0, Color.WHITE, true, false, false)
		mb.add_cylinder(_m["dark"], Transform3D(turn, eye), 0.7, 0.7, 0.82, 10, 1.0, Color(0.5, 0.5, 0.5), true, false, false)
		mb.add_cylinder(_m["wall"], Transform3D(turn, eye + Vector3(0, 0.35, 0.35)), 0.22, 0.22, 0.86, 6, 1.0, Color(1.2, 1.2, 1.2), true, false, false)
		var lid := PackedVector2Array()
		for k in range(11):
			var a := deg_to_rad(12.0 + k * 15.6)
			lid.append(Vector2(cos(a), sin(a)) * 2.35)
		lid.append(Vector2(0.0, 0.42))
		var lid_xf := Transform3D(Basis(Vector3.UP, s * PI * 0.5), eye + Vector3(s * 0.45, 0, 0))
		mb.add_extrude(_m["fish"], lid_xf, lid, 0.9, 0.5, Color(0.85, 0.85, 0.85))
		var lash := PackedVector3Array([lid_xf * Vector3(-2.3, 0.49, 0.47), lid_xf * Vector3(0, 0.4, 0.47), lid_xf * Vector3(2.3, 0.49, 0.47)])
		mb.add_tube(_m["dark"], lash, 0.12, -1.0, 4, 1.0)
		# the brow ridge and two carved gill lines behind the eye
		var brow := PackedVector3Array()
		for k in range(7):
			var t := 10.0 + k * 1.0
			brow.append(Vector3(s * (float(_fish_at(t)[0]) - 0.6), 6.4 - absf(k - 3.0) * 0.25, BW - t))
		mb.add_tube(_m["fish"], brow, 0.45, -1.0, 6, 1.0, Color(0.85, 0.85, 0.85))
		for g in [0.0, 1.3]:
			var gill := PackedVector3Array()
			for k in range(7):
				var y := 3.4 - k * 0.7
				var t: float = 7.5 + g - sin(k / 6.0 * PI) * 1.6
				gill.append(_fish_side(s, t, y, 0.08))
			mb.add_tube(_m["trim"], gill, 0.2, -1.0, 5, 1.0)
		# a pectoral fin swept back along the side: gilt ribs and a red web
		var root := _fish_side(s, 8.0, 0.2, -0.2)
		var tips: Array = []
		for k in range(5):
			tips.append(root + Vector3(s * (5.0 - k * 0.5), -0.3 - k * 0.5, 1.5 + k * 1.4))
		for k in range(5):
			dress.add_tube(_m["trim"], PackedVector3Array([root, root.lerp(tips[k], 0.5) + Vector3(0, 0.3, 0), tips[k]]), 0.16, 0.05, 4, 1.0)
			if k < 4:
				_web(mb, root, tips[k], tips[k + 1])
	# the crest: gilt spines leaning back with a red web between them
	var spines: Array = []
	for k in range(6):
		var t := 4.0 + k * 2.6
		var top: float = float(_fish_at(t)[1]) + float(_fish_at(t)[2]) - 0.5
		var length: float = [4.6, 6.0, 6.6, 6.2, 5.0, 3.4][k]
		spines.append([Vector3(0, top, BW - t), Vector3(0, top + length, BW - t + 2.6)])
	for k in range(spines.size()):
		var sp: Array = spines[k]
		mb.add_tube(_m["trim"], PackedVector3Array([sp[0], (sp[0] as Vector3).lerp(sp[1], 0.5) + Vector3(0, 0, -0.3), sp[1]]), 0.24, 0.07, 5, 1.0)
		if k < spines.size() - 1:
			var nx: Array = spines[k + 1]
			var dip: Vector3 = (sp[1] as Vector3).lerp(nx[1], 0.5) + Vector3(0, -1.2, 0)
			_web(mb, sp[0], sp[1], dip)
			_web(mb, sp[0], dip, nx[0])
			_web(mb, nx[0], dip, nx[1])
	# nostrils and a pair of whiskers trailing from the snout
	for s in [-1.0, 1.0]:
		mb.add_cylinder(_m["dark"], _xf(Vector3(s * 1.6, float(_fish_at(23.0)[1]) + float(_fish_at(23.0)[2]) - 0.6, BW - 23.0)), 0.35, 0.3, 0.3, 6, 1.0)
		var w0 := _fish_side(s, 22.0, 1.0, 0.0)
		dress.add_tube(_m["fish"], MeshBuilder.curve_points(w0, w0 + Vector3(s * 4.0, 1.2, 1.0), w0 + Vector3(s * 6.5, -2.6, 6.0), 8), 0.22, 0.05, 4, 1.0)


## A two-sided triangle of red web (fins, the crest).
func _web(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	mb.add_tri(_m["red"], a, b, c, n, n, n, Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Color.WHITE, n)
	mb.add_tri(_m["red"], a, c, b, -n, -n, -n, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Color(0.8, 0.8, 0.8), -n)


func _hall(mb: MeshBuilder, dress: MeshBuilder) -> void:
	var lo: Vector3 = HALL[0]
	var hi: Vector3 = HALL[1]
	var h := hi.y
	var wall: Material = _m["wall"]
	var beam: Material = _m["beam"]
	var zc := (lo.z + hi.z) * 0.5
	var zl := hi.z - lo.z
	# ground floor walls round the two doorways
	Buildings.tiled_box(mb, wall, Vector3(-11.85, h * 0.5, zc), Vector3(0.3, h, zl), 3.2)
	var sz0 := SIDE_Z - SIDE_HW
	var sz1 := SIDE_Z + SIDE_HW
	Buildings.tiled_box(mb, wall, Vector3(11.85, h * 0.5, (lo.z + sz0) * 0.5), Vector3(0.3, h, sz0 - lo.z), 3.2)
	Buildings.tiled_box(mb, wall, Vector3(11.85, h * 0.5, (sz1 + hi.z) * 0.5), Vector3(0.3, h, hi.z - sz1), 3.2)
	mb.add_box(wall, _xf(Vector3(11.85, (SIDE_H + h) * 0.5, SIDE_Z)), Vector3(0.3, h - SIDE_H, SIDE_HW * 2.0), 0.5)
	Buildings.tiled_box(mb, wall, Vector3(0, h * 0.5, lo.z + 0.15), Vector3(24.0, h, 0.3), 3.2)
	for s in [-1.0, 1.0]:
		Buildings.tiled_box(mb, wall, Vector3(s * (DOOR_HW + 12.0) * 0.5, h * 0.5, hi.z - 0.15), Vector3(12.0 - DOOR_HW, h, 0.3), 3.2)
	mb.add_box(wall, _xf(Vector3(0, (DOOR_H + h) * 0.5, hi.z - 0.15)), Vector3(DOOR_HW * 2.0, h - DOOR_H, 0.3), 0.5)
	# the timber frame outside: sills and girts, a post at every bay
	for s in [-1.0, 1.0]:
		mb.add_box(beam, _xf(Vector3(s * 12.07, 0.18, zc)), Vector3(0.26, 0.36, zl + 0.3), 0.8)
		mb.add_box(beam, _xf(Vector3(s * 12.07, h - 0.2, zc)), Vector3(0.28, 0.4, zl + 0.3), 0.8)
		for k in range(9):
			mb.add_box(beam, _xf(Vector3(s * 12.06, h * 0.5, lo.z + k * BAY)), Vector3(0.26, h, 0.3), 0.8)
	for zz in [lo.z - 0.07, hi.z + 0.07]:
		mb.add_box(beam, _xf(Vector3(0, 0.18, zz)), Vector3(24.3, 0.36, 0.26), 0.8)
		mb.add_box(beam, _xf(Vector3(0, h - 0.2, zz)), Vector3(24.3, 0.4, 0.28), 0.8)
	for x in [-8.0, -4.0, 4.0, 8.0]:
		mb.add_box(beam, _xf(Vector3(x, h * 0.5, lo.z - 0.06)), Vector3(0.3, h, 0.26), 0.8)
	for x in [-8.0, -DOOR_HW - 0.15, DOOR_HW + 0.15, 8.0]:
		mb.add_box(beam, _xf(Vector3(x, h * 0.5, hi.z + 0.06)), Vector3(0.3, h, 0.26), 0.8)
	mb.add_box(beam, _xf(Vector3(0, DOOR_H + 0.15, hi.z + 0.08)), Vector3(DOOR_HW * 2.0 + 0.6, 0.3, 0.3), 0.8, Color.WHITE, false)
	for zz in [SIDE_Z - SIDE_HW - 0.15, SIDE_Z + SIDE_HW + 0.15]:
		mb.add_box(beam, _xf(Vector3(12.08, SIDE_H * 0.5, zz)), Vector3(0.3, SIDE_H, 0.3), 0.8)
	mb.add_box(beam, _xf(Vector3(12.1, SIDE_H + 0.15, SIDE_Z)), Vector3(0.3, 0.3, SIDE_HW * 2.0 + 0.6), 0.8, Color.WHITE, false)
	# the doors stand open against the walls
	for s in [-1.0, 1.0]:
		mb.add_box_unit_uv(_m["door"], _xf(Vector3(s * (DOOR_HW + 0.85), DOOR_H * 0.5 - 0.05, hi.z + 0.06)), Vector3(1.6, DOOR_H - 0.1, 0.08))
		mb.add_box_unit_uv(_m["door"], _xf(Vector3(12.06, SIDE_H * 0.5 - 0.05, SIDE_Z + s * (SIDE_HW + 0.75))), Vector3(0.08, SIDE_H - 0.1, 1.2))
	# windows: every bay but the doors' and the room's and the board's walls inside
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "hall"])
	for s in [-1.0, 1.0]:
		for k in range(8):
			var z := lo.z + (k + 0.5) * BAY
			if k == 6 or (s > 0.0 and k == 3):
				continue
			_window(mb, dress, Vector3(s * 12.0, 2.7, z), Vector3(s, 0, 0), 1.5, 1.9, k % 2 == 0, rng)
	for x in [-10.0, -6.0, 6.0, 10.0]:
		_window(mb, dress, Vector3(x, 2.7, hi.z), Vector3.BACK, 1.5, 1.9, true, rng)
		_window(mb, dress, Vector3(x * 0.85, 2.7, lo.z), Vector3.FORWARD, 1.4, 1.6, false, rng)
	# the upper storey, jettied out on brackets: its floor (the hall's ceiling), framed walls with braces, small windows
	var ux := 12.0 + JETTY
	var uz0 := lo.z - JETTY
	var uz1 := hi.z + JETTY
	var uh := h + UPPER
	mb.add_box(_m["deck"], _xf(Vector3(0, h + 0.15, zc)), Vector3(ux * 2.0 - 0.2, 0.3, uz1 - uz0 - 0.2), 0.4, Color(0.75, 0.72, 0.68), false)
	for s in [-1.0, 1.0]:
		Buildings.tiled_box(mb, wall, Vector3(s * (ux - 0.15), h + UPPER * 0.5, zc), Vector3(0.3, UPPER, uz1 - uz0), 3.2)
		Buildings.tiled_box(mb, wall, Vector3(0, h + UPPER * 0.5, (uz0 + 0.15) if s < 0.0 else (uz1 - 0.15)), Vector3(ux * 2.0, UPPER, 0.3), 3.2)
		mb.add_box(beam, _xf(Vector3(s * (ux + 0.07), h + 0.12, zc)), Vector3(0.26, 0.3, uz1 - uz0 + 0.3), 0.8, Color.WHITE, false)
		mb.add_box(beam, _xf(Vector3(s * (ux + 0.07), uh - 0.12, zc)), Vector3(0.26, 0.26, uz1 - uz0 + 0.3), 0.8)
		mb.add_box(beam, _xf(Vector3(0, h + 0.12, uz0 - 0.07 if s < 0.0 else uz1 + 0.07)), Vector3(ux * 2.0 + 0.3, 0.3, 0.26), 0.8, Color.WHITE, false)
		mb.add_box(beam, _xf(Vector3(0, uh - 0.12, uz0 - 0.07 if s < 0.0 else uz1 + 0.07)), Vector3(ux * 2.0 + 0.3, 0.26, 0.26), 0.8)
		for k in range(9):
			var z := lo.z + k * BAY
			mb.add_box(beam, _xf(Vector3(s * (ux + 0.06), h + UPPER * 0.5, z)), Vector3(0.22, UPPER, 0.26), 0.8)
			Buildings.beam_between(dress, beam, Vector3(s * 12.1, h - 0.8, z), Vector3(s * (ux - 0.05), h + 0.05, z), 0.2)
			if k < 8:
				Buildings.beam_between(mb, beam, Vector3(s * (ux + 0.05), h + 0.3, z + 0.15), Vector3(s * (ux + 0.05), h + 1.9, z + 1.25), 0.18)
				Buildings.beam_between(mb, beam, Vector3(s * (ux + 0.05), h + 0.3, z + BAY - 0.15), Vector3(s * (ux + 0.05), h + 1.9, z + BAY - 1.25), 0.18)
				if not (s > 0.0 and k == 3):
					_window(mb, dress, Vector3(s * ux, h + 2.2, z + BAY * 0.5), Vector3(s, 0, 0), 1.1, 1.3, k % 2 == 1, rng)
	for x in [-ux, -6.3, 6.3, ux]:
		mb.add_box(beam, _xf(Vector3(x, h + UPPER * 0.5, uz0 - 0.06)), Vector3(0.22, UPPER, 0.22), 0.8)
	for x in [-ux, -6.3, -1.0, 1.0, 6.3, ux]:
		mb.add_box(beam, _xf(Vector3(x, h + UPPER * 0.5, uz1 + 0.06)), Vector3(0.22, UPPER, 0.22), 0.8)
	for x in [-9.4, -3.6, 3.6, 9.4]:
		_window(mb, dress, Vector3(x, h + 2.2, uz1), Vector3.BACK, 1.1, 1.3, true, rng)
		_window(mb, dress, Vector3(x, h + 2.2, uz0), Vector3.FORWARD, 1.1, 1.3, false, rng)
	mb.add_box_unit_uv(_m["door"], _xf(Vector3(0, h + 1.35, uz1 + 0.03)), Vector3(1.6, 2.5, 0.06))
	# the balcony over the front door: its floor on brackets, a balustrade
	var bz := uz1 + 2.3
	mb.add_box(_m["deck"], _xf(Vector3(0, h + 0.12, (uz1 + bz) * 0.5)), Vector3(12.0, 0.24, bz - uz1), 0.5, Color.WHITE, false)
	for x in [-5.5, -2.0, 2.0, 5.5]:
		Buildings.beam_between(mb, beam, Vector3(x, h - 1.0, hi.z + 0.1), Vector3(x, h - 0.02, bz - 0.2), 0.2)
	for s in [-1.0, 1.0]:
		Buildings.beam_between(dress, _m["trim"], Vector3(s * 6.0, h + 1.15, uz1), Vector3(s * 6.0, h + 1.15, bz), 0.12)
		dress.add_box(beam, _xf(Vector3(s * 5.95, h + 0.6, bz - 0.1)), Vector3(0.16, 1.1, 0.16), 1.0)
	dress.add_box(_m["trim"], _xf(Vector3(0, h + 1.15, bz - 0.1)), Vector3(12.0, 0.12, 0.16), 1.0, Color.WHITE, false)
	dress.add_box(beam, _xf(Vector3(0, h + 0.32, bz - 0.1)), Vector3(12.0, 0.08, 0.1), 1.0, Color.WHITE, false)
	for k in range(31):
		dress.add_box(beam, _xf(Vector3(-5.8 + k * 0.3867, h + 0.72, bz - 0.1)), Vector3(0.07, 0.8, 0.07), 1.0)
	# the roof: tiles over a gable each end, barge boards, a ridge beam
	var rz := zc
	mb.add_gable_roof(_m["roof"], _xf(Vector3(0, uh, rz)), ux * 2.0, uz1 - uz0, 6.0, 0.8, 0.3, Color.WHITE, wall)
	var drop := 0.8 * 6.0 / ux
	for zz in [uz0 - 0.8, uz1 + 0.8]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, _m["trim"], Vector3(s * (ux + 0.8), uh - drop, zz), Vector3(0, uh + 6.05, zz), 0.3, 0.4)
	mb.add_box(beam, _xf(Vector3(0, uh + 6.1, rz)), Vector3(0.4, 0.3, uz1 - uz0 + 1.6), 0.8)
	# the lantern tower on the ridge: lit on four sides, a tiled spire and a long pennant
	var tz := -6.0
	var ty := uh + 4.4
	mb.add_box(wall, _xf(Vector3(0, ty + 1.5, tz)), Vector3(4.0, 4.6, 4.0), 0.5)
	for s in [-1.0, 1.0]:
		mb.add_box_unit_uv(_m["window"], _xf(Vector3(s * 2.02, ty + 2.0, tz)), Vector3(0.05, 1.7, 1.8))
		mb.add_box_unit_uv(_m["window"], _xf(Vector3(0, ty + 2.0, tz + s * 2.02)), Vector3(1.8, 1.7, 0.05))
		for s2 in [-1.0, 1.0]:
			mb.add_box(beam, _xf(Vector3(s * 2.05, ty + 1.5, tz + s2 * 2.05)), Vector3(0.24, 4.6, 0.24), 0.8)
	mb.add_box(beam, _xf(Vector3(0, ty + 3.85, tz)), Vector3(4.4, 0.25, 4.4), 0.8, Color.WHITE, false)
	mb.add_pyramid_roof(_m["roof"], _xf(Vector3(0, ty + 3.95, tz)), 4.4, 4.4, 3.4)
	mb.add_cylinder(_m["wood"], _xf(Vector3(0, ty + 7.2, tz)), 0.12, 0.07, 5.5, 5, 1.0)
	_pennant(mb, _m["red"], Vector3(0, ty + 12.5, tz), 8.0)
	# the kitchen chimney through the roof, its cap
	mb.add_box(_m["stone"], _xf(Vector3(7.0, uh + 3.2, lo.z + 3.0)), Vector3(1.6, 9.0, 1.6), 0.5)
	mb.add_box(_m["stone"], _xf(Vector3(7.0, uh + 7.8, lo.z + 3.0)), Vector3(2.0, 0.35, 2.0), 0.5, Color(0.7, 0.7, 0.7), false)


## A window in a wall at `c` (the wall's outer face) facing `out`: the lit panes through the wall, a timber frame,
## a sill, shutters hung open, maybe a box of flowers.
func _window(mb: MeshBuilder, dress: MeshBuilder, c: Vector3, out: Vector3, w: float, h: float, flowers: bool, rng: RandomNumberGenerator) -> void:
	var f := _face(c, out)
	mb.add_box_unit_uv(_m["window"], f * _xf(Vector3(0, 0, -0.15)), Vector3(w, h, 0.36))
	var beam: Material = _m["beam"]
	mb.add_box(beam, f * _xf(Vector3(0, h * 0.5 + 0.08, 0.06)), Vector3(w + 0.32, 0.16, 0.12), 1.0, Color.WHITE, false)
	mb.add_box(_m["trim"], f * _xf(Vector3(0, -h * 0.5 - 0.06, 0.1)), Vector3(w + 0.4, 0.12, 0.2), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(beam, f * _xf(Vector3(s * (w * 0.5 + 0.08), 0, 0.06)), Vector3(0.16, h, 0.12), 1.0)
		var leaf := f * Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * (w * 0.5 + 0.17), 0, 0.1)) * _xf(Vector3(s * w * 0.25, 0, 0))
		dress.add_box(_m["paint"], leaf, Vector3(w * 0.5, h + 0.06, 0.05), 1.2, Color.WHITE, false)
	dress.add_box(_m["dark"], f * _xf(Vector3(0, 0, 0.03)), Vector3(0.06, h, 0.04), 1.0)
	dress.add_box(_m["dark"], f * _xf(Vector3(0, 0, 0.03)), Vector3(w, 0.06, 0.04), 1.0)
	if not flowers:
		return
	dress.add_box(beam, f * _xf(Vector3(0, -h * 0.5 - 0.3, 0.22)), Vector3(w + 0.1, 0.3, 0.3), 1.0, Color.WHITE, false)
	for k in range(5):
		var x := -w * 0.42 + k * w * 0.21
		dress.add_blob(_m["leaves"], f * _xf(Vector3(x, -h * 0.5 - 0.12, 0.24)), Vector3(0.14, 0.12, 0.13), rng, 0.25, 2, 5, 1.0)
		dress.add_blob(_m["red"] if k % 2 == 0 else _m["cream"], f * _xf(Vector3(x + 0.05, -h * 0.5 - 0.02, 0.3)), Vector3.ONE * 0.07, rng, 0.2, 2, 4, 1.0)


func _pennant(mb: MeshBuilder, mat: Material, top: Vector3, length: float) -> void:
	var a := top
	var b := top + Vector3(0, -1.2, length * 0.35)
	var c := top + Vector3(0, -0.4, length)
	var d := top + Vector3(0, -0.8, 0)
	for s in [1.0, -1.0]:
		var n := Vector3(s, 0, 0)
		if s > 0.0:
			mb.add_quad(mat, a, b + Vector3(0, -0.4, 0), c, d, Vector2(0, 0), Vector2(0.5, 0.5), Vector2(1, 0), Vector2(0, 1), Color.WHITE, n)
		else:
			mb.add_quad(mat, a, d, c, b + Vector3(0, -0.4, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(0.5, 0.5), Color(0.85, 0.85, 0.85), n)


## A lantern on an iron arm off a wall facing `out` (or hung from a post or a beam: `out` zero).
func _lantern(mb: MeshBuilder, at: Vector3, out: Vector3) -> void:
	var p := at + out * 0.34
	if out != Vector3.ZERO:
		Buildings.beam_between(mb, _m["dark"], at + Vector3(0, 0.26, 0), p + Vector3(0, 0.26, 0), 0.05)
	mb.add_box(_m["dark"], _xf(p + Vector3(0, 0.13, 0)), Vector3(0.26, 0.06, 0.26), 1.0, Color.WHITE, false)
	mb.add_box(_m["glow"], _xf(p + Vector3(0, -0.06, 0)), Vector3(0.18, 0.3, 0.18), 1.0, Color.WHITE, false)
	mb.add_box(_m["dark"], _xf(p + Vector3(0, -0.24, 0)), Vector3(0.24, 0.06, 0.24), 1.0, Color.WHITE, false)


## The stern terrace: a striped awning on posts with a scalloped valance and a string of lanterns, tables under it.
func _terrace(mb: MeshBuilder, dress: MeshBuilder) -> void:
	var a0: Vector2 = AWNING[0]
	var a1: Vector2 = AWNING[1]
	var y0 := 4.6
	var y1 := 3.3
	var n := 12
	var sw := (a1.x - a0.x) / n
	var nt := Vector3(0, a1.y - a0.y, y0 - y1).normalized()
	for i in range(n):
		var x := a0.x + i * sw
		var m: Material = _m["red"] if i % 2 == 0 else _m["cream"]
		var a := Vector3(x, y0, a0.y)
		var b := Vector3(x + sw, y0, a0.y)
		var c := Vector3(x + sw, y1, a1.y)
		var d := Vector3(x, y1, a1.y)
		mb.add_quad(m, a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, nt)
		mb.add_quad(m, d, c, b, a, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.75, 0.75, 0.75), -nt)
		for half in [0.0, 0.5]:
			var p := Vector3(x + half * sw, y1, a1.y)
			var q := Vector3(x + (half + 0.5) * sw, y1, a1.y)
			var tip := Vector3(x + (half + 0.25) * sw, y1 - 0.45, a1.y)
			mb.add_tri(m, p, tip, q, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0), Color.WHITE, Vector3.BACK)
			mb.add_tri(m, p, q, tip, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), Color(0.8, 0.8, 0.8), Vector3.FORWARD)
	for x in _awning_posts():
		mb.add_cylinder(_m["wood"], _xf(Vector3(x, 0, a1.y - 0.2)), 0.14, 0.12, y1, 6, 1.0)
	mb.add_box(_m["beam"], _xf(Vector3(0, y1 - 0.1, a1.y - 0.2)), Vector3(a1.x - a0.x, 0.2, 0.2), 0.8, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		Buildings.beam_between(dress, _m["beam"], Vector3(s * 11.6, y1 - 0.05, a1.y - 0.2), Vector3(s * 11.6, y0 - 0.05, a0.y + 0.2), 0.14)
	# lanterns strung along the front
	var posts := _awning_posts()
	for i in range(posts.size() - 1):
		var pts := MeshBuilder.sag_points(Vector3(posts[i], y1 - 0.15, a1.y + 0.05), Vector3(posts[i + 1], y1 - 0.15, a1.y + 0.05), 0.5, 6)
		dress.add_tube(_m["dark"], pts, 0.025, -1.0, 3, 1.0)
		for k in [2, 4]:
			_lantern(dress, pts[k] + Vector3(0, -0.2, 0), Vector3.ZERO)
	for t in _terrace_tables():
		_table(dress, t, true)


static func _awning_posts() -> Array:
	return [-11.6, -4.0, 4.0, 11.6]


static func _terrace_tables() -> Array:
	return [Vector3(-8.0, 0, 18.5), Vector3(8.0, 0, 18.5), Vector3(-4.5, 0, 22.0), Vector3(4.5, 0, 22.0), Vector3(-8.0, 0, 25.5), Vector3(8.0, 0, 25.5)]


## A round table with a cloth, three chairs (the diners' seats) and places laid: the terrace's cloth red check,
## the hall's white with a candle.
func _table(mb: MeshBuilder, t: Vector3, outside: bool) -> void:
	var wood := PSXMat.lit("planks", Color(0.7, 0.5, 0.34))
	var cloth := PSXMat.lit("fabric_check", Color(1.0, 0.55, 0.5) if outside else Color(0.95, 0.9, 0.85))
	mb.add_cylinder(wood, _xf(t), 0.12, 0.12, 0.75, 6, 1.0)
	mb.add_cylinder(wood, _xf(t), 0.45, 0.3, 0.06, 6, 1.0)
	mb.add_cylinder(cloth, _xf(t + Vector3(0, 0.6, 0)), 0.92, 0.85, 0.2, 10, 1.0, Color.WHITE, true, true)
	for k in range(3):
		var a := k * TAU / 3.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var ch := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), t + dir * 1.25)
		mb.add_box(wood, ch * _xf(Vector3(0, 0.42, 0)), Vector3(0.46, 0.06, 0.44), 1.0, Color.WHITE, false)
		for lx in [-0.19, 0.19]:
			for lz in [-0.18, 0.18]:
				mb.add_box(wood, ch * _xf(Vector3(lx, 0.2, lz)), Vector3(0.05, 0.4, 0.05), 1.0, Color(0.8, 0.8, 0.8))
			mb.add_box(wood, ch * _xf(Vector3(lx, 0.7, 0.2)), Vector3(0.05, 0.56, 0.05), 1.0, Color(0.8, 0.8, 0.8))
		mb.add_box(wood, ch * _xf(Vector3(0, 0.86, 0.2)), Vector3(0.44, 0.22, 0.04), 1.0)
		mb.add_cylinder(_m["wall"], _xf(t + dir * 0.55 + Vector3(0, 0.8, 0)), 0.16, 0.17, 0.025, 8, 1.0, Color(1.05, 1.05, 1.0))
		mb.add_cylinder(_m["beam"], _xf(t + dir * 0.5 + Vector3(dir.z, 0, -dir.x) * 0.26 + Vector3(0, 0.8, 0)), 0.05, 0.05, 0.13, 6, 1.0, Color(1.3, 1.2, 1.0))
	if not outside:
		mb.add_cylinder(_m["wall"], _xf(t + Vector3(0, 0.8, 0)), 0.04, 0.04, 0.16, 5, 1.0)
		mb.add_box(_m["glow"], _xf(t + Vector3(0, 1.0, 0)), Vector3(0.04, 0.07, 0.04), 1.0, Color.WHITE, false)


func _landing(mb: MeshBuilder, dress: MeshBuilder) -> void:
	var pl: Vector3 = PONTOON[0]
	var ph: Vector3 = PONTOON[1]
	mb.add_box(_m["deck"], _xf((pl + ph) * 0.5), ph - pl, 0.4)
	mb.add_box(_m["hull"], _xf(Vector3((pl.x + ph.x) * 0.5, pl.y - 0.4, (pl.z + ph.z) * 0.5)), Vector3(ph.x - pl.x - 0.3, 0.6, ph.z - pl.z - 0.3), 0.5)
	for x in [pl.x + 0.06, ph.x - 0.06]:
		mb.add_box(_m["beam"], _xf(Vector3(x, (pl.y + ph.y) * 0.5 - 0.02, (pl.z + ph.z) * 0.5)), Vector3(0.16, ph.y - pl.y + 0.06, ph.z - pl.z), 0.8)
	# bollards, rope fenders on the outer edge, a lamp post at the ramp's foot
	for z in [4.0, 12.0, 20.0]:
		dress.add_cylinder(_m["dark"], _xf(Vector3(ph.x - 0.45, ph.y, z)), 0.2, 0.18, 0.5, 6, 1.0)
		dress.add_cylinder(_m["dark"], _xf(Vector3(ph.x - 0.45, ph.y + 0.5, z)), 0.28, 0.28, 0.08, 6, 1.0)
	for z in range(2, 24, 3):
		dress.add_cylinder(PSXMat.lit("rope"), _xf(Vector3(ph.x + 0.12, pl.y - 0.6, z)), 0.18, 0.18, 0.7, 6, 1.5)
	mb.add_box(_m["beam"], _xf(Vector3(ph.x - 0.4, ph.y + 1.6, 0.6)), Vector3(0.2, 3.2, 0.2), 0.8)
	_lantern(dress, Vector3(ph.x - 0.4, ph.y + 2.9, 0.6), Vector3(-1, 0, 0))
	# the ramp up the side, its rail; the head at the deck's gap
	var r0: Vector3 = RAMP[0]
	var r1: Vector3 = RAMP[1]
	mb.add_box(_m["deck"], Transform3D(Basis.looking_at((r1 - r0).normalized(), Vector3.UP), (r0 + r1) * 0.5 + Vector3(0, -0.1, 0)), Vector3(2.2, 0.2, r0.distance_to(r1)), 0.4)
	var h0: Vector3 = RAMP_HEAD[0]
	var h1: Vector3 = RAMP_HEAD[1]
	mb.add_box(_m["deck"], _xf((h0 + h1) * 0.5), h1 - h0, 0.4)
	var o := Vector3(1.2, 0, 0)
	for k in range(5):
		var p := (r0 + o).lerp(r1 + o, k / 4.0)
		dress.add_box(_m["beam"], _xf(p + Vector3(0, 0.45, 0)), Vector3(0.12, 0.9, 0.12), 1.0)
	Buildings.beam_between(dress, _m["trim"], r0 + o + Vector3(0, 0.92, 0), r1 + o + Vector3(0, 0.92, 0), 0.1)
	Buildings.beam_between(dress, _m["trim"], Vector3(h1.x - 0.06, 0.92, h1.z), Vector3(h1.x - 0.06, 0.92, h0.z + 0.06), 0.1)
	Buildings.beam_between(dress, _m["trim"], Vector3(h1.x - 0.06, 0.92, h0.z + 0.06), Vector3(HW, 0.92, h0.z + 0.06), 0.1)
	for p in [Vector3(h1.x - 0.06, 0, h0.z + 0.06), Vector3(h1.x - 0.06, 0, h1.z)]:
		dress.add_box(_m["beam"], _xf(p + Vector3(0, 0.45, 0)), Vector3(0.12, 0.9, 0.12), 1.0)


## Banner poles, barrels and crates, the dinner bell by the landing, life rings on the bulwarks.
func _deck_dressing(mb: MeshBuilder, dress: MeshBuilder) -> void:
	for at in [Vector3(-17.5, 0, -32.0), Vector3(17.5, 0, -32.0), Vector3(-17.0, 0, 36.0), Vector3(17.0, 0, 36.0)]:
		mb.add_cylinder(_m["wood"], _xf(at), 0.26, 0.14, 22.0, 6, 0.8)
		mb.add_box(_m["trim"], _xf(at + Vector3(0, 21.0, 0)), Vector3(1.8, 0.14, 0.14), 1.0, Color.WHITE, false)
		_pennant(mb, _m["red"] if at.x < 0.0 else _m["cream"], at + Vector3(0, 21.4, 0), 7.0)
	for c in _barrel_spots():
		for k in range(3):
			var b: Vector3 = c + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.7
			dress.add_cylinder(_m["beam"], _xf(b), 0.36, 0.36, 0.95, 8, 1.0, Color(1.2, 1.1, 1.0))
			for y in [0.18, 0.77]:
				dress.add_cylinder(_m["dark"], _xf(b + Vector3(0, y, 0)), 0.38, 0.38, 0.06, 8, 1.0)
	for c in _crate_spots():
		for b in [[_xf(c + Vector3(0, 0.5, 0)), 1.0], [_xf(c + Vector3(1.05, 0.4, 0.1)), 0.8], [Transform3D(Basis(Vector3.UP, 0.3), c + Vector3(0.3, 1.35, 0)), 0.7]]:
			_crate(dress, b[0], b[1])
	var bell := Vector3(19.4, 0, -10.6)
	mb.add_box(_m["beam"], _xf(bell + Vector3(0, 1.4, 0)), Vector3(0.2, 2.8, 0.2), 0.8)
	dress.add_box(_m["beam"], _xf(bell + Vector3(0, 2.7, 0.35)), Vector3(0.12, 0.12, 0.7), 1.0)
	dress.add_loft(_m["trim"], _xf(bell + Vector3(0, 2.0, 0.6)), [[0.0, 0.3, 0.3], [0.3, 0.24, 0.24], [0.6, 0.12, 0.12]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)
	for s in [-1.0, 1.0]:
		for z in [-18.0, 26.0]:
			var ring := PackedVector3Array()
			for k in range(13):
				var a := k * TAU / 12.0
				ring.append(Vector3(s * (HW + 0.06), 0.5 + sin(a) * 0.42, z + cos(a) * 0.42))
			dress.add_tube(_m["red"], ring, 0.11, -1.0, 4, 1.0)


## A plank crate of side `s` centred at `xf`, dark corner battens.
func _crate(mb: MeshBuilder, xf: Transform3D, s: float) -> void:
	mb.add_box(_m["deck"], xf, Vector3.ONE * s, 1.2, Color(0.95, 0.88, 0.75), false)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			mb.add_box(_m["dark"], xf * _xf(Vector3(x * s * 0.47, 0, z * s * 0.47)), Vector3(0.08, s + 0.02, 0.08), 1.0)


static func _barrel_spots() -> Array:
	return [Vector3(-16.0, 0, -28.0), Vector3(15.5, 0, -27.0), Vector3(-17.5, 0, 22.0), Vector3(17.6, 0, 8.0), Vector3(-9.0, 0, 39.0)]


static func _crate_spots() -> Array:
	return [Vector3(13.6, 0, -33.0), Vector3(-14.0, 0, -35.0), Vector3(17.0, 0, 14.0)]


## The name on a big painted board over the balcony and another facing the landing.
func _signs() -> void:
	var mb := MeshBuilder.new()
	var hi: Vector3 = HALL[1]
	var uz1 := hi.z + JETTY
	var ux := 12.0 + JETTY
	var y := hi.y + UPPER + 1.7
	for spec in [[Vector3(0, y, uz1 + 0.06), Vector3.BACK, 9.0, 1.9], [Vector3(ux + 0.12, hi.y + 2.2, SIDE_Z), Vector3.RIGHT, 4.2, 1.3]]:
		var f := _face(spec[0], spec[1])
		var w: float = spec[2]
		var h: float = spec[3]
		mb.add_box(_m["paint"], f, Vector3(w, h, 0.1), 0.6, Color(0.8, 0.8, 0.8))
		for s in [-1.0, 1.0]:
			mb.add_box(_m["trim"], f * _xf(Vector3(0, s * (h * 0.5 + 0.06), 0.02)), Vector3(w + 0.24, 0.14, 0.16), 1.0, Color.WHITE, false)
			mb.add_box(_m["trim"], f * _xf(Vector3(s * (w * 0.5 + 0.06), 0, 0.02)), Vector3(0.14, h, 0.16), 1.0)
		var l := Label3D.new()
		l.text = place_name
		l.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
		l.font_size = 64
		l.pixel_size = minf(0.013, w * 0.85 / (place_name.length() * 34.0))
		l.outline_size = 12
		l.outline_modulate = Color(0.12, 0.08, 0.05)
		l.modulate = Color(1.0, 0.86, 0.5)
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.shaded = false
		l.double_sided = false
		l.visibility_range_end = 260.0
		l.transform = f * _xf(Vector3(0, 0, 0.07))
		add_child(l)
	mb.add_card(PSXMat.cutout("sign_fish"), _xf(Vector3(0, DOOR_H + 0.55, hi.z + 0.25)), 2.4, 1.2)
	for s in [-1.0, 1.0]:
		_lantern(mb, Vector3(s * 3.6, 3.0, hi.z + 0.05), Vector3.BACK)
		_lantern(mb, Vector3(12.15, 2.8, SIDE_Z + s * 2.0), Vector3.RIGHT)
		_lantern(mb, Vector3(s * 5.95, hi.y + 1.5, uz1 + 2.2), Vector3.ZERO)
	var inst := mb.to_instance("Signs")
	inst.visibility_range_end = 320.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Real light, on the budget: the front door, the terrace, the hall inside (always), the chimney's smoke.
func _lights() -> void:
	var hi: Vector3 = HALL[1]
	for spec in [[Vector3(0, 3.6, hi.z + 1.5), 1.2, 12.0, false], [Vector3(0, 3.0, 24.0), 1.0, 14.0, false], [Vector3(0, 4.6, -6.0), 0.8, 24.0, true], [Vector3(7.0, 1.8, HALL[0].z + 3.2), 0.9, 7.0, true]]:
		var l := NightLight.make(Color(1.0, 0.75, 0.45), spec[1], spec[2], spec[3])
		l.position = spec[0]
		add_child(l)
	FX.chimney_smoke(self, Vector3(7.0, hi.y + UPPER + 8.2, HALL[0].z + 3.0))


## The dining hall inside (one mesh, near only): wainscot, posts, beams and pillars, chandeliers and sconces, the
## tables laid, the counter, the open kitchen behind it, the room's door, the rumour board, the cook-off table, a
## mounted marlin over the door and nets on the walls.
func _interior() -> void:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "interior"])
	_frame_inside(mb)
	for t in _tables():
		_table(mb, t, false)
	_counter(mb, rng)
	_kitchen(mb, rng)
	_decor(mb, rng)
	var inst := mb.to_instance("Interior")
	inst.visibility_range_end = 90.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Interior posts, beams and pillars (x, z) under the long beams.
const PILLARS := [Vector2(-6.25, -7.25), Vector2(6.25, -7.25), Vector2(-6.25, -0.75), Vector2(6.25, -0.75), Vector2(-6.25, 5.75), Vector2(6.25, 5.75)]
const IN_X := 11.7


func _frame_inside(mb: MeshBuilder) -> void:
	var lo: Vector3 = HALL[0]
	var hi: Vector3 = HALL[1]
	var h := hi.y
	var dark := PSXMat.lit("planks_dark", Color(0.62, 0.42, 0.3))
	var z0 := lo.z + 0.3
	var z1 := hi.z - 0.3
	# wainscot round the walls (gaps at the doors), a gilt cap rail
	var runs := [[Vector3(-IN_X, 0, z0), Vector3(-IN_X, 0, z1), Vector3.RIGHT], [Vector3(IN_X, 0, z0), Vector3(IN_X, 0, SIDE_Z - SIDE_HW), Vector3.LEFT],
		[Vector3(IN_X, 0, SIDE_Z + SIDE_HW), Vector3(IN_X, 0, z1), Vector3.LEFT], [Vector3(-IN_X, 0, z0), Vector3(IN_X, 0, z0), Vector3.BACK],
		[Vector3(-IN_X, 0, z1), Vector3(-DOOR_HW, 0, z1), Vector3.FORWARD], [Vector3(DOOR_HW, 0, z1), Vector3(IN_X, 0, z1), Vector3.FORWARD]]
	for r in runs:
		var n: Vector3 = r[2]
		Buildings.beam_between(mb, dark, r[0] + n * 0.03 + Vector3(0, 0.6, 0), r[1] + n * 0.03 + Vector3(0, 0.6, 0), 0.06, 1.2)
		Buildings.beam_between(mb, _m["trim"], r[0] + n * 0.06 + Vector3(0, 1.22, 0), r[1] + n * 0.06 + Vector3(0, 1.22, 0), 0.1, 0.08)
	# posts on the side walls at every bay, cross beams over them, two long beams on pillars down the room
	for k in range(1, 8):
		var z := lo.z + k * BAY
		for s in [-1.0, 1.0]:
			mb.add_box(_m["beam"], _xf(Vector3(s * (IN_X - 0.15), h * 0.5, z)), Vector3(0.3, h, 0.3), 0.8)
			Buildings.beam_between(mb, _m["beam"], Vector3(s * (IN_X - 0.3), h - 1.0, z), Vector3(s * (IN_X - 1.1), h - 0.2, z), 0.16)
		mb.add_box(_m["beam"], _xf(Vector3(0, h - 0.18, z)), Vector3(IN_X * 2.0, 0.36, 0.3), 0.8, Color.WHITE, false)
		if k % 2 == 1:
			for s in [-1.0, 1.0]:
				_lantern(mb, Vector3(s * (IN_X - 0.3), 2.9, z), Vector3(-s, 0, 0))
	for s in [-1.0, 1.0]:
		mb.add_box(_m["beam"], _xf(Vector3(s * 6.25, h - 0.51, (z0 + z1) * 0.5)), Vector3(0.3, 0.3, z1 - z0), 0.8, Color(0.85, 0.85, 0.85), false)
	for p in PILLARS:
		mb.add_box(_m["beam"], _xf(Vector3(p.x, (h - 0.66) * 0.5, p.y)), Vector3(0.34, h - 0.66, 0.34), 0.8)
		mb.add_box(dark, _xf(Vector3(p.x, 0.2, p.y)), Vector3(0.48, 0.4, 0.48), 0.8)
		for dz in [-1.0, 1.0]:
			Buildings.beam_between(mb, _m["beam"], Vector3(p.x, h - 1.6, p.y + dz * 0.15), Vector3(p.x, h - 0.7, p.y + dz * 1.0), 0.16)
	# chandeliers: an iron wheel of candles on three chains
	for z in [-7.25, -0.75, 5.75]:
		var c := Vector3(0, 3.7, z)
		var ring := PackedVector3Array()
		for k in range(13):
			ring.append(c + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * 1.1)
		mb.add_tube(_m["dark"], ring, 0.05, -1.0, 4, 1.0)
		for k in range(6):
			var a := k * TAU / 6.0
			var p := c + Vector3(cos(a), 0, sin(a)) * 1.1
			mb.add_cylinder(_m["wall"], _xf(p), 0.05, 0.05, 0.2, 5, 1.0)
			mb.add_box(_m["glow"], _xf(p + Vector3(0, 0.26, 0)), Vector3(0.05, 0.09, 0.05), 1.0, Color.WHITE, false)
			if k % 2 == 0:
				mb.add_tube(_m["dark"], PackedVector3Array([p, Vector3(0, h - 0.36, z)]), 0.02, -1.0, 3, 1.0)


## The long counter before the kitchen: panelled front, a foot rail, a top laid with the day's bowls and loaves,
## bar stools, the menu board hung over it.
func _counter(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var cz := HALL[0].z + 8.5
	var dark := PSXMat.lit("planks_dark", Color(0.62, 0.42, 0.3))
	mb.add_box(dark, _xf(Vector3(0, 0.5, cz)), Vector3(16.0, 1.0, 0.8), 0.6)
	mb.add_box(_m["deck"], _xf(Vector3(0, 1.05, cz + 0.1)), Vector3(16.4, 0.1, 1.1), 0.8, Color(1.1, 1.0, 0.9), false)
	mb.add_box(_m["dark"], _xf(Vector3(0, 0.08, cz + 0.42)), Vector3(16.0, 0.16, 0.05), 1.0)
	for k in range(17):
		mb.add_box(_m["beam"], _xf(Vector3(-8.0 + k * 1.0, 0.55, cz + 0.42)), Vector3(0.12, 0.8, 0.05), 1.0)
	mb.add_tube(_m["trim"], PackedVector3Array([Vector3(-7.8, 0.25, cz + 0.62), Vector3(7.8, 0.25, cz + 0.62)]), 0.04, -1.0, 5, 1.0)
	for x in [-7.0, -4.8, -2.4, 2.4, 4.8, 7.0]:
		mb.add_cylinder(_m["beam"], _xf(Vector3(x, 0, cz + 1.0)), 0.05, 0.05, 0.75, 5, 1.0)
		mb.add_cylinder(_m["red"], _xf(Vector3(x, 0.75, cz + 1.0)), 0.22, 0.22, 0.08, 8, 1.0, Color.WHITE, true, true)
		mb.add_cylinder(_m["dark"], _xf(Vector3(x, 0.25, cz + 1.0)), 0.18, 0.18, 0.03, 6, 1.0)
	# on the counter: bowls of the pot, loaves, stacked plates, bottles, the service bell
	for k in range(9):
		var x := -7.2 + k * 1.8 + rng.randf_range(-0.3, 0.3)
		match k % 3:
			0:
				mb.add_cylinder(_m["wall"], _xf(Vector3(x, 1.1, cz + 0.1)), 0.12, 0.18, 0.1, 8, 1.0, Color(0.9, 0.95, 1.0))
				mb.add_cylinder(_m["fish"], _xf(Vector3(x, 1.1, cz + 0.1)), 0.15, 0.15, 0.09, 8, 1.0, Color(0.8, 0.55, 0.4))
			1:
				mb.add_blob(_m["trim"], _xf(Vector3(x, 1.16, cz + 0.2)), Vector3(0.22, 0.1, 0.12), rng, 0.1, 2, 6, 1.0, Color(0.9, 0.62, 0.38))
			2:
				for j in range(4):
					mb.add_cylinder(_m["wall"], _xf(Vector3(x, 1.1 + j * 0.03, cz - 0.05)), 0.17, 0.17, 0.025, 8, 1.0)
	for x in [-3.2, 3.6, 3.75]:
		mb.add_loft(_m["paint"], _xf(Vector3(x, 1.1, cz - 0.15)), [[0.0, 0.07, 0.07], [0.2, 0.07, 0.07], [0.27, 0.025, 0.025], [0.36, 0.025, 0.025]],
			MeshBuilder.profile_circle(6), 1.0, Color(0.5, 0.75, 0.45), false, true)
	mb.add_loft(_m["trim"], _xf(Vector3(0.6, 1.1, cz + 0.3)), [[0.0, 0.12, 0.12], [0.08, 0.1, 0.1], [0.14, 0.03, 0.03]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, false, true)
	# the menu board hung from the beam over the counter
	var mz := cz + 0.95
	mb.add_box(_m["dark"], _xf(Vector3(0, 3.8, mz)), Vector3(4.2, 1.3, 0.06), 1.0, Color(0.4, 0.45, 0.4), false)
	for s in [-1.0, 1.0]:
		mb.add_box(_m["trim"], _xf(Vector3(0, 3.8 + s * 0.69, mz)), Vector3(4.4, 0.1, 0.1), 1.0, Color.WHITE, false)
		mb.add_box(_m["trim"], _xf(Vector3(s * 2.15, 3.8, mz)), Vector3(0.1, 1.3, 0.1), 1.0)
		mb.add_tube(_m["dark"], PackedVector3Array([Vector3(s * 1.8, 4.5, mz), Vector3(s * 1.8, HALL[1].y - 0.36, HALL[0].z + 9.5)]), 0.015, -1.0, 3, 1.0)
	_label("TODAY'S POT\nTidewater Bouillabaisse", Transform3D(Basis(), Vector3(0, 3.8, mz + 0.05)), 0.0058, Color(0.95, 0.95, 0.88))


## The kitchen behind the counter: the range under its hood and the chimney, an iron stove, the prep table, hams and
## herbs and pans hanging from a rack, shelves of jars and bottles, sacks and barrels.
func _kitchen(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var lo: Vector3 = HALL[0]
	var iron := PSXMat.lit("metal", Color(0.32, 0.31, 0.33))
	var stone: Material = _m["stone"]
	var fire := PSXMat.glow(Color(1.0, 0.5, 0.2), 2.4)
	var rz := lo.z + 1.2
	mb.add_box(stone, _xf(Vector3(7.0, 0.5, rz)), Vector3(4.2, 1.0, 1.6), 0.6)
	mb.add_box(iron, _xf(Vector3(7.0, 1.04, rz)), Vector3(4.3, 0.08, 1.7), 1.0)
	for x in [6.0, 8.0]:
		mb.add_box(fire, _xf(Vector3(x, 0.45, rz + 0.81)), Vector3(0.8, 0.45, 0.04), 1.0)
		mb.add_box(iron, _xf(Vector3(x, 0.72, rz + 0.83)), Vector3(0.95, 0.08, 0.06), 1.0)
	mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(7.0, 2.3, rz - 0.1)), 2.5, 1.05, 1.6, 4, 0.6, Color(0.85, 0.85, 0.85), true, true, false)
	mb.add_box(stone, _xf(Vector3(7.0, 4.65, rz - 0.1)), Vector3(1.5, 1.5, 1.5), 0.6, Color(0.85, 0.85, 0.85))
	mb.add_loft(iron, _xf(Vector3(6.1, 1.08, rz)), [[0.0, 0.42, 0.42], [0.55, 0.45, 0.45], [0.58, 0.47, 0.47]], MeshBuilder.profile_circle(10), 1.0, Color.WHITE, true, true)
	mb.add_cylinder(iron, _xf(Vector3(8.0, 1.08, rz + 0.2)), 0.32, 0.3, 0.1, 8, 1.0)
	mb.add_box(iron, _xf(Vector3(8.0, 1.14, rz + 0.75)), Vector3(0.06, 0.04, 0.5), 1.0)
	mb.add_loft(iron, _xf(Vector3(7.9, 1.08, rz - 0.45)), [[0.0, 0.18, 0.18], [0.25, 0.2, 0.2], [0.35, 0.08, 0.08]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)
	# the iron stove and its pipe, a pot on it
	var sv := Vector3(-3.5, 0, lo.z + 0.9)
	mb.add_box(iron, _xf(sv + Vector3(0, 0.45, 0)), Vector3(2.0, 0.9, 1.1), 1.0)
	mb.add_box(fire, _xf(sv + Vector3(-0.4, 0.42, 0.56)), Vector3(0.5, 0.3, 0.03), 1.0)
	mb.add_cylinder(iron, _xf(sv + Vector3(0.6, 0.9, -0.3)), 0.14, 0.14, HALL[1].y - 0.9, 6, 1.0)
	mb.add_loft(iron, _xf(sv + Vector3(-0.3, 0.9, 0.1)), [[0.0, 0.28, 0.28], [0.32, 0.3, 0.3], [0.34, 0.32, 0.32]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)
	# the prep table: a board, a fish, vegetables, a knife
	var pt := Vector3(0.5, 0, lo.z + 4.4)
	mb.add_box(_m["deck"], _xf(pt + Vector3(0, 0.9, 0)), Vector3(4.0, 0.08, 1.2), 0.8, Color(1.1, 1.05, 0.95), false)
	mb.add_box(_m["deck"], _xf(pt + Vector3(0, 0.25, 0)), Vector3(3.8, 0.05, 1.0), 0.8, Color(0.8, 0.75, 0.7), false)
	for x in [-1.9, 1.9]:
		for z in [-0.5, 0.5]:
			mb.add_box(_m["beam"], _xf(pt + Vector3(x, 0.45, z)), Vector3(0.09, 0.9, 0.09), 1.0)
	mb.add_box(_m["beam"], _xf(pt + Vector3(-0.8, 0.97, 0)), Vector3(0.9, 0.05, 0.6), 1.0, Color(1.4, 1.25, 1.0))
	mb.add_loft(_m["fish"], Transform3D(Basis(Vector3.BACK, -PI * 0.5), pt + Vector3(-1.25, 1.06, 0)), [[0.0, 0.03, 0.02], [0.2, 0.1, 0.05], [0.55, 0.08, 0.04], [0.75, 0.02, 0.01]], MeshBuilder.profile_circle(6), 2.0, Color(0.7, 0.85, 1.0))
	mb.add_box(iron, _xf(pt + Vector3(-0.3, 1.0, 0.15)), Vector3(0.3, 0.02, 0.06), 1.0, Color(1.6, 1.6, 1.6))
	for k in range(7):
		var m: Material = [_m["leaves"], _m["red"], _m["cream"]][k % 3]
		mb.add_blob(m, _xf(pt + Vector3(0.5 + rng.randf_range(-0.4, 1.3), 1.02, rng.randf_range(-0.4, 0.4))), Vector3.ONE * rng.randf_range(0.07, 0.11), rng, 0.2, 2, 5, 1.0)
	mb.add_cylinder(_m["wall"], _xf(pt + Vector3(1.5, 0.94, -0.3)), 0.25, 0.3, 0.14, 8, 1.0, Color(0.85, 0.55, 0.38))
	# the rack over it: hams, herb bundles, garlic, pans
	var ry := 3.3
	mb.add_box(_m["beam"], _xf(pt + Vector3(0, ry, 0)), Vector3(4.4, 0.12, 0.12), 1.0, Color.WHITE, false)
	for x in [-2.0, 2.0]:
		mb.add_tube(_m["dark"], PackedVector3Array([pt + Vector3(x, ry, 0), Vector3(pt.x + x, HALL[1].y - 0.36, lo.z + BAY)]), 0.02, -1.0, 3, 1.0)
	var ham := PSXMat.lit("leather", Color(0.78, 0.36, 0.26))
	for k in range(10):
		var x := -1.9 + k * 0.42
		var at := pt + Vector3(x, ry, 0)
		match k % 4:
			0:
				mb.add_tube(_m["dark"], PackedVector3Array([at, at - Vector3(0, 0.25, 0)]), 0.012, -1.0, 3, 1.0)
				mb.add_blob(ham, _xf(at - Vector3(0, 0.55, 0)), Vector3(0.17, 0.3, 0.15), rng, 0.12, 3, 6, 1.0)
				mb.add_cylinder(_m["wall"], _xf(at - Vector3(0, 0.3, 0)), 0.04, 0.05, 0.1, 5, 1.0)
			1:
				mb.add_blob(_m["leaves"], _xf(at - Vector3(0, 0.3, 0)), Vector3(0.1, 0.24, 0.1), rng, 0.25, 2, 5, 1.0, Color(0.75, 0.9, 0.6))
			2:
				for j in range(4):
					mb.add_blob(_m["wall"], _xf(at - Vector3(0, 0.12 + j * 0.14, 0)), Vector3.ONE * 0.07, rng, 0.15, 2, 5, 1.0, Color(1.1, 1.05, 0.95))
			3:
				mb.add_box(iron, _xf(at - Vector3(0, 0.25, 0)), Vector3(0.03, 0.4, 0.03), 1.0)
				mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at - Vector3(0, 0.6, 0.02)), 0.24, 0.22, 0.05, 8, 1.0)
	# shelves of jars and bottles on the bow wall, more on the port wall, sacks and barrels below
	for spec in [[Vector3(-8.7, 0, lo.z + 0.55), 0.0, 5.0], [Vector3(-IN_X + 0.3, 0, lo.z + 4.2), PI * 0.5, 4.0]]:
		var sh := Transform3D(Basis(Vector3.UP, spec[1]), spec[0])
		var w: float = spec[2]
		for s in [-1.0, 1.0]:
			mb.add_box(_m["beam"], sh * _xf(Vector3(s * w * 0.5, 1.4, 0)), Vector3(0.08, 2.8, 0.45), 1.0)
		for y in [0.9, 1.7, 2.5]:
			mb.add_box(_m["deck"], sh * _xf(Vector3(0, y, 0)), Vector3(w, 0.06, 0.45), 1.0, Color(0.85, 0.75, 0.65), false)
			var x := -w * 0.5 + 0.25
			while x < w * 0.5 - 0.2:
				var r := rng.randf_range(0.07, 0.13)
				var hh := rng.randf_range(0.18, 0.36)
				if rng.randf() < 0.55:
					mb.add_cylinder(_m["wall"], sh * _xf(Vector3(x, y + 0.03, 0)), r, r * 0.9, hh, 6, 1.0, [Color(0.85, 0.55, 0.38), Color(1, 1, 0.95), Color(0.6, 0.7, 0.8)][rng.randi() % 3], true)
				else:
					mb.add_loft(_m["paint"], sh * _xf(Vector3(x, y + 0.03, 0)), [[0.0, 0.06, 0.06], [hh, 0.06, 0.06], [hh + 0.07, 0.02, 0.02], [hh + 0.14, 0.02, 0.02]],
						MeshBuilder.profile_circle(6), 1.0, [Color(0.4, 0.7, 0.35), Color(0.7, 0.45, 0.25)][rng.randi() % 2], false, true)
				x += r * 2.0 + rng.randf_range(0.05, 0.2)
	for p in [Vector3(-10.4, 0, lo.z + 7.0), Vector3(-9.6, 0, lo.z + 7.4), Vector3(-10.1, 0.45, lo.z + 7.2)]:
		mb.add_blob(_m["cream"], _xf(p + Vector3(0, 0.3, 0)), Vector3(0.32, 0.32, 0.28), rng, 0.15, 3, 6, 1.0, Color(0.85, 0.78, 0.62), 0.0)
	for p in _kitchen_barrels():
		mb.add_cylinder(_m["beam"], _xf(p), 0.36, 0.36, 0.95, 8, 1.0, Color(1.2, 1.1, 1.0))
		for y in [0.18, 0.77]:
			mb.add_cylinder(_m["dark"], _xf(p + Vector3(0, y, 0)), 0.38, 0.38, 0.06, 8, 1.0)


static func _kitchen_barrels() -> Array:
	return [Vector3(10.6, 0, HALL[0].z + 4.2), Vector3(10.7, 0, HALL[0].z + 5.1), Vector3(4.2, 0, HALL[0].z + 0.8)]


## The room's door, the rumour board, the cook-off table and its banner, the marlin over the front door, nets,
## potted plants by the door.
func _decor(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var hi: Vector3 = HALL[1]
	var rz := _room_z()
	# the room: a panelled door in a frame, a sign over it
	mb.add_box_unit_uv(_m["door"], _xf(Vector3(-IN_X + 0.08, 1.15, rz)), Vector3(0.06, 2.3, 1.2))
	for s in [-1.0, 1.0]:
		mb.add_box(_m["beam"], _xf(Vector3(-IN_X + 0.1, 1.2, rz + s * 0.7)), Vector3(0.16, 2.4, 0.2), 1.0)
	mb.add_box(_m["beam"], _xf(Vector3(-IN_X + 0.1, 2.45, rz)), Vector3(0.16, 0.2, 1.6), 1.0, Color.WHITE, false)
	mb.add_box(_m["paint"], _xf(Vector3(-IN_X + 0.06, 2.85, rz)), Vector3(0.06, 0.45, 1.3), 1.0)
	_label("Rooms", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-IN_X + 0.1, 2.85, rz)), 0.006, Color(1.0, 0.86, 0.5))
	# the rumour board: a cork panel in a frame, notes pinned up
	var bx := IN_X - 0.06
	mb.add_box(_m["deck"], _xf(Vector3(bx, 1.75, rz)), Vector3(0.06, 1.2, 1.8), 1.0, Color(0.85, 0.62, 0.42))
	for s in [-1.0, 1.0]:
		mb.add_box(_m["beam"], _xf(Vector3(bx - 0.02, 1.75 + s * 0.64, rz)), Vector3(0.1, 0.08, 1.96), 1.0, Color.WHITE, false)
		mb.add_box(_m["beam"], _xf(Vector3(bx - 0.02, 1.75, rz + s * 0.94)), Vector3(0.1, 1.2, 0.08), 1.0)
	for k in range(8):
		var at := Vector3(bx - 0.05, 1.75 + rng.randf_range(-0.4, 0.4), rz + rng.randf_range(-0.7, 0.7))
		mb.add_box(_m["cream"] if k % 3 != 0 else _m["wall"], Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), at), Vector3(0.02, rng.randf_range(0.22, 0.32), rng.randf_range(0.18, 0.26)), 2.0)
		mb.add_box(_m["red"], _xf(at + Vector3(-0.02, 0.1, 0)), Vector3(0.03, 0.03, 0.03), 1.0)
	_label("RUMOURS", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(bx - 0.08, 2.55, rz)), 0.006, Color(1.0, 0.86, 0.5))
	# the cook-off table: a red runner, the judge's bell, a covered dish and a cup for the winner; a banner over it
	var ct := Vector3(-8.5, 0, -10.5)
	mb.add_box(_m["deck"], _xf(ct + Vector3(0, 0.86, 0)), Vector3(2.4, 0.08, 1.2), 0.8, Color(1.1, 1.0, 0.9), false)
	for x in [-1.1, 1.1]:
		for z in [-0.5, 0.5]:
			mb.add_box(_m["beam"], _xf(ct + Vector3(x, 0.41, z)), Vector3(0.09, 0.82, 0.09), 1.0)
	mb.add_box(_m["red"], _xf(ct + Vector3(0, 0.91, 0)), Vector3(2.5, 0.02, 0.5), 1.0)
	mb.add_loft(PSXMat.lit("metal", Color(0.85, 0.85, 0.9)), _xf(ct + Vector3(-0.5, 0.92, 0)), [[0.0, 0.3, 0.3], [0.15, 0.28, 0.28], [0.28, 0.15, 0.15], [0.33, 0.04, 0.04], [0.38, 0.04, 0.04]],
		MeshBuilder.profile_circle(10), 1.0, Color.WHITE, false, true)
	mb.add_loft(_m["trim"], _xf(ct + Vector3(0.5, 0.92, 0.1)), [[0.0, 0.1, 0.1], [0.03, 0.04, 0.04], [0.16, 0.04, 0.04], [0.2, 0.08, 0.08], [0.36, 0.12, 0.12], [0.38, 0.12, 0.12]],
		MeshBuilder.profile_circle(8), 1.0, Color.WHITE, true, true)
	mb.add_loft(_m["trim"], _xf(ct + Vector3(0.95, 0.92, -0.25)), [[0.0, 0.1, 0.1], [0.08, 0.09, 0.09], [0.14, 0.03, 0.03]], MeshBuilder.profile_circle(8), 1.0, Color.WHITE, false, true)
	mb.add_box(_m["red"], _xf(Vector3(-IN_X + 0.05, 4.45, ct.z)), Vector3(0.05, 0.75, 3.0), 1.0)
	_label("COOK-OFF", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-IN_X + 0.09, 4.45, ct.z)), 0.01, Color(1.0, 0.92, 0.7))
	# the marlin over the front door, on a plaque
	var mz := hi.z - 0.36
	mb.add_box(_m["beam"], _xf(Vector3(0, 4.35, mz - 0.02)), Vector3(4.6, 1.3, 0.08), 1.0)
	var blue := PSXMat.lit("scales", Color(0.4, 0.55, 0.85))
	var mf := Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-1.5, 4.35, mz - 0.18))
	mb.add_loft(blue, mf, [[0.0, 0.06, 0.04], [0.5, 0.28, 0.12], [1.4, 0.36, 0.14], [2.3, 0.26, 0.11], [2.7, 0.1, 0.05]], MeshBuilder.profile_circle(8), 1.5)
	mb.add_cone(_m["dark"], Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(1.15, 4.33, mz - 0.18)), 0.06, 1.3, 5, 1.0)
	var fins := Transform3D(Basis(), Vector3(-1.5, 4.35, mz - 0.18))
	mb.add_extrude(blue, fins, PackedVector2Array([Vector2(0.06, 0), Vector2(-0.5, 0.6), Vector2(-0.25, 0.0), Vector2(-0.5, -0.6)]), 0.04, 1.5, Color(0.7, 0.7, 0.8))
	mb.add_extrude(blue, fins, PackedVector2Array([Vector2(0.5, 0.25), Vector2(0.9, 0.85), Vector2(1.9, 0.6), Vector2(2.2, 0.25)]), 0.03, 1.5, Color(0.6, 0.65, 0.8))
	mb.add_cylinder(_m["dark"], Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.95, 4.4, mz - 0.18)), 0.05, 0.05, 0.16, 6, 1.0)
	# fishing nets with cork floats draped over a post on each side wall
	for spec in [[-1.0, -0.25], [1.0, 4.5]]:
		var s: float = spec[0]
		var x := s * (IN_X - 0.36)
		var zc: float = spec[1]
		for k in range(-4, 5):
			var top := Vector3(x, 3.9, zc + k * 0.3)
			mb.add_tube(PSXMat.lit("rope"), MeshBuilder.sag_points(top, Vector3(x, 2.1, zc + k * 0.3 + 0.9), 0.06, 3), 0.015, -1.0, 3, 2.0)
			mb.add_tube(PSXMat.lit("rope"), MeshBuilder.sag_points(top, Vector3(x, 2.1, zc + k * 0.3 - 0.9), 0.06, 3), 0.015, -1.0, 3, 2.0)
			mb.add_blob(_m["red"] if k % 2 else _m["cream"], _xf(top + Vector3(0, 0.02, 0)), Vector3(0.08, 0.06, 0.08), rng, 0.1, 2, 5, 1.0)
	# potted palms either side of the front door
	for s in [-1.0, 1.0]:
		var pp := Vector3(s * 2.7, 0, hi.z - 0.8)
		mb.add_cylinder(_m["wall"], _xf(pp), 0.3, 0.4, 0.55, 8, 1.0, Color(0.85, 0.48, 0.32), true)
		for k in range(5):
			var a := k * TAU / 5.0 + 0.3
			mb.add_blob(_m["leaves"], _xf(pp + Vector3(cos(a) * 0.3, 0.95 + k * 0.05, sin(a) * 0.3)), Vector3(0.35, 0.16, 0.22), rng, 0.25, 2, 5, 1.0)


func _label(text: String, xf: Transform3D, px: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	l.font_size = 48
	l.pixel_size = px
	l.outline_size = 8
	l.outline_modulate = Color(0.1, 0.07, 0.05)
	l.modulate = col
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = 40.0
	l.transform = xf
	add_child(l)


static func _room_z() -> float:
	return HALL[0].z + 6.5 * BAY


## The hall's tables (the cook-off table takes the place of one).
static func _tables() -> Array:
	var out: Array = []
	for z in [-10.5, -4.0, 2.5, 9.0]:
		for x in [-8.5, -4.0, 4.0, 8.5]:
			if not (x == -8.5 and z == -10.5):
				out.append(Vector3(x, 0, z))
	return out


# --------------------------------------------------------------------------
# Collision
# --------------------------------------------------------------------------
func _collide() -> void:
	var pts := PackedVector3Array()
	for e in EDGE:
		for s in [-1.0, 1.0]:
			pts.append(Vector3(s * e.x, 0.0, e.y))
			pts.append(Vector3(s * e.x * 0.7, KEEL, e.y))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	_shape(hull, Transform3D.IDENTITY)
	var fp := PackedVector3Array()
	for r in FISH:
		var t: float = r[0]
		var hw: float = r[1]
		var hd: float = r[2]
		var cz: float = r[3]
		for s in [-1.0, 1.0]:
			fp.append(Vector3(s * hw, minf(cz + hd * 0.5, 0.0) if t == 0.0 else cz + hd * 0.5, BW - t))
			fp.append(Vector3(s * hw, cz - hd * 0.5, BW - t))
			fp.append(Vector3(s * hw * 0.5, cz + hd, BW - t))
			fp.append(Vector3(s * hw * 0.5, cz - hd, BW - t))
	var fish := ConvexPolygonShape3D.new()
	fish.points = fp
	_shape(fish, Transform3D.IDENTITY)
	# the bulwarks (a gap for the starboard ramp) and the stern's
	for s in [-1.0, 1.0]:
		for i in range(EDGE.size() - 1):
			var a := Vector3(s * (EDGE[i].x - 0.13), 0.0, EDGE[i].y)
			var b := Vector3(s * (EDGE[i + 1].x - 0.13), 0.0, EDGE[i + 1].y)
			if s > 0.0 and i == 1:
				_seg(a, Vector3(b.x, 0, RAMP_HEAD[1].z))
				_seg(Vector3(b.x, 0, RAMP_HEAD[0].z), b)
			else:
				_seg(a, b)
	_seg(Vector3(-EDGE[0].x, 0, ST - 0.13), Vector3(EDGE[0].x, 0, ST - 0.13))
	# the hall: walls round the doors, the upper storey solid, its roof
	var lo: Vector3 = HALL[0]
	var hi: Vector3 = HALL[1]
	var h := hi.y
	var zc := (lo.z + hi.z) * 0.5
	_box(Vector3(-11.85, h * 0.5, zc), Vector3(0.3, h, hi.z - lo.z))
	var sz0 := SIDE_Z - SIDE_HW
	var sz1 := SIDE_Z + SIDE_HW
	_box(Vector3(11.85, h * 0.5, (lo.z + sz0) * 0.5), Vector3(0.3, h, sz0 - lo.z))
	_box(Vector3(11.85, h * 0.5, (sz1 + hi.z) * 0.5), Vector3(0.3, h, hi.z - sz1))
	_box(Vector3(11.85, (SIDE_H + h) * 0.5, SIDE_Z), Vector3(0.3, h - SIDE_H, SIDE_HW * 2.0))
	_box(Vector3(0, h * 0.5, lo.z + 0.15), Vector3(24.0, h, 0.3))
	for s in [-1.0, 1.0]:
		_box(Vector3(s * (DOOR_HW + 12.0) * 0.5, h * 0.5, hi.z - 0.15), Vector3(12.0 - DOOR_HW, h, 0.3))
	_box(Vector3(0, (DOOR_H + h) * 0.5, hi.z - 0.15), Vector3(DOOR_HW * 2.0, h - DOOR_H, 0.3))
	var ux := 12.0 + JETTY
	_box(Vector3(0, h + UPPER * 0.5, zc), Vector3(ux * 2.0, UPPER, hi.z - lo.z + JETTY * 2.0))
	var roof := ConvexPolygonShape3D.new()
	var rz0 := lo.z - JETTY
	var rz1 := hi.z + JETTY
	roof.points = PackedVector3Array([Vector3(-ux, h + UPPER, rz0), Vector3(ux, h + UPPER, rz0), Vector3(-ux, h + UPPER, rz1), Vector3(ux, h + UPPER, rz1),
		Vector3(0, h + UPPER + 6.0, rz0), Vector3(0, h + UPPER + 6.0, rz1)])
	_shape(roof, Transform3D.IDENTITY)
	_box(Vector3(0, h + 0.12, hi.z + JETTY + 1.15), Vector3(12.0, 0.24, 2.3))
	# the awning's posts, the terrace's and the hall's tables, barrels and crates, the bell post
	for x in _awning_posts():
		_cyl(Vector3(x, 0, AWNING[1].y - 0.2), 0.15, 3.3)
	for t in _terrace_tables() + _tables():
		_cyl(t, 0.9, 0.8)
	for c in _barrel_spots():
		_cyl(c, 1.1, 0.95)
	for c in _crate_spots():
		_box(c + Vector3(0.5, 0.7, 0.05), Vector3(2.0, 1.4, 1.1))
	_cyl(Vector3(19.4, 0, -10.6), 0.12, 2.8)
	for at in [Vector3(-17.5, 0, -32.0), Vector3(17.5, 0, -32.0), Vector3(-17.0, 0, 36.0), Vector3(17.0, 0, 36.0)]:
		_cyl(at, 0.26, 6.0)
	# inside: the counter, the range and the stove, the prep table, shelves, barrels, pillars, the cook-off table, plants
	_box(Vector3(0, 0.55, lo.z + 8.55), Vector3(16.0, 1.1, 1.0))
	_box(Vector3(7.0, 0.55, lo.z + 1.2), Vector3(4.3, 1.1, 1.7))
	_box(Vector3(-3.5, 0.45, lo.z + 0.9), Vector3(2.0, 0.9, 1.1))
	_box(Vector3(0.5, 0.47, lo.z + 4.4), Vector3(4.0, 0.95, 1.2))
	_box(Vector3(-8.7, 1.4, lo.z + 0.55), Vector3(5.0, 2.8, 0.5))
	_box(Vector3(-IN_X + 0.3, 1.4, lo.z + 4.2), Vector3(0.5, 2.8, 4.0))
	for p in _kitchen_barrels():
		_cyl(p, 0.4, 0.95)
	for p in PILLARS:
		_cyl(Vector3(p.x, 0, p.y), 0.26, h - 0.66)
	_box(Vector3(-8.5, 0.45, -10.5), Vector3(2.4, 0.9, 1.2))
	for s in [-1.0, 1.0]:
		_cyl(Vector3(s * 2.7, 0, hi.z - 0.8), 0.4, 0.6)
	# the pontoon, the ramp and its head and rails
	var pl: Vector3 = PONTOON[0]
	var ph: Vector3 = PONTOON[1]
	_box((pl + ph) * 0.5 + Vector3(0, -0.2, 0), ph - pl + Vector3(0, 0.4, 0))
	var r0: Vector3 = RAMP[0]
	var r1: Vector3 = RAMP[1]
	var ramp := BoxShape3D.new()
	ramp.size = Vector3(2.2, 0.2, r0.distance_to(r1))
	_shape(ramp, Transform3D(Basis.looking_at((r1 - r0).normalized(), Vector3.UP), (r0 + r1) * 0.5 + Vector3(0, -0.1, 0)))
	var h0: Vector3 = RAMP_HEAD[0]
	var h1: Vector3 = RAMP_HEAD[1]
	_box((h0 + h1) * 0.5, h1 - h0)
	_seg(r0 + Vector3(1.2, 0, 0), r1 + Vector3(1.2, 0, 0), 0.12)
	_seg(Vector3(h1.x - 0.06, 0, h1.z), Vector3(h1.x - 0.06, 0, h0.z + 0.06), 0.12)
	_seg(Vector3(h1.x - 0.06, 0, h0.z + 0.06), Vector3(HW, 0, h0.z + 0.06), 0.12)


## A wall 1 m tall along a→b (deck level).
func _seg(a: Vector3, b: Vector3, t: float = 0.26) -> void:
	var s := BoxShape3D.new()
	s.size = Vector3(t, 1.0, a.distance_to(b))
	_shape(s, Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + Vector3(0, 0.5, 0)))


func _cyl(at: Vector3, r: float, h: float) -> void:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	_shape(c, _xf(at + Vector3(0, h * 0.5, 0)))


func _box(at: Vector3, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	_shape(b, Transform3D(Basis(), at))


func _shape(s: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = xf
	add_child(cs)


# --------------------------------------------------------------------------
# Fittings and people
# --------------------------------------------------------------------------
func _fittings() -> void:
	for spec in [[Vector3(-HW, 0.0, -12.0), -PI * 0.5], [Vector3(HW, 0.0, 30.0), PI * 0.5], [Vector3(0.0, 0.0, ST), 0.0]]:
		var lad := Ladder.new()
		lad.length = 2.6
		lad.rail = 1.0
		lad.deck_depth = 0.9
		lad.position = spec[0]
		lad.rotation.y = spec[1]
		add_child(lad)
	var pl := Ladder.new()
	pl.name = "PontoonLadder"
	pl.length = 1.2
	pl.deck_depth = 0.8
	pl.position = Vector3(PONTOON[1].x, PONTOON[1].y, 14.0)
	pl.rotation.y = PI * 0.5
	add_child(pl)
	var lo: Vector3 = HALL[0]
	_spot("Recipes", "Ask %s about recipes" % chef_name.get_slice(" ", 1), Vector3(0, 1.0, lo.z + 9.4), _recipes)
	_spot("Room", "Take a room and rest", Vector3(-10.9, 1.0, _room_z()), _rest)
	_spot("Rumours", "Read the rumour board", Vector3(10.9, 1.2, _room_z()), _rumours)
	_spot("CookOff", "Enter the cook-off", Vector3(-8.5, 1.0, -9.3), _cook_off)


func _spot(nm: String, prompt: String, at: Vector3, fn: Callable) -> void:
	var it := Interactable.new()
	it.name = nm
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = prompt
	it.gesture = "hand"  # (1.31)
	it.reach = 1.1
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.2
	cs.shape = sph
	it.add_child(cs)
	it.position = at
	add_child(it)
	it.interacted.connect(fn)


func _people() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "people"])
	shop_id = "restaurant_%d" % seed_value
	var dishes: Array = DISHES.duplicate()
	var stock: Array = [["stew"], ["rum"]]
	for i in range(3):
		stock.append(dishes.pop_at(rng.randi() % dishes.size()))
	stock.append_array([["pepper"], ["sea_urchin"], ["oyster"]])
	Shops.extra[shop_id] = {"name": place_name, "line": "Sit, eat, and don't tell me how your cook does it.", "trade": "cook",
		"stock": stock, "buys": {"ingredient": 0.6, "consumable": 0.4}}
	var lk := CharacterLook.random_look(rng)
	lk["name"] = chef_name
	lk["top"] = "shirt"
	lk["top_color"] = Color(0.97, 0.97, 0.94)
	lk["coat"] = "jacket"
	lk["coat_color"] = Color(0.95, 0.95, 0.92)
	lk["hat"] = "bandana"
	lk["hat_color"] = Color(0.97, 0.97, 0.95)
	chef = NPC.new()
	chef.setup({"name": chef_name, "shop": shop_id, "look": lk, "voice": rng.randf_range(0.8, 1.0), "yaw": PI,
		"barks": ["Welcome aboard %s! Today's pot is the best on the sea." % place_name,
			"A cook who can't feed a crew in a gale isn't a cook.",
			"Eat first. Fight after. That's the house rule."]})
	chef.humanoid.far_figure = false
	add_child(chef)
	chef.position = Vector3(0.0, 0.0, HALL[0].z + 7.4)
	if attacked and not GameManager.world_flags.has(_flag):
		return
	var tables := _tables()
	for i in range(4):
		var d := NPC.new()
		var dl := CharacterLook.random_look(rng)
		dl["name"] = "Diner"
		var t: Vector3 = tables[i]
		var a := 0.4 + float(i % 3) * TAU / 3.0
		d.setup({"name": "Diner", "look": dl, "scenery": true, "seated": true, "yaw": atan2(cos(a), sin(a)),
			"barks": ["Best chowder this side of the chain.", "Pass the salt.", "They say the chef fought off a whole crew once."]})
		d.humanoid.far_figure = false
		add_child(d)
		d.position = t + Vector3(cos(a), 0, sin(a)) * 1.25
	var judge := NPC.new()
	var jl := CharacterLook.random_look(rng)
	jl["name"] = "Cook-off judge"
	judge.setup({"name": "Judge Pell", "look": jl, "yaw": PI * 0.5,
		"barks": ["The cook-off table's by the wall. One go a visit: I name the dish, you cook it.", "Burn it and I'll know. I always know."]})
	judge.humanoid.far_figure = false
	add_child(judge)
	judge.position = Vector3(-10.6, 0.0, -10.5)


## Pirates hold the deck: a crew round the hall's door and on the stern terrace, a sloop of theirs standing off.
func _raiders() -> void:
	camp = GruntCamp.new()
	camp.name = "Raiders"
	camp.respawn_time = INF
	camp.level = level
	camp.warm_start = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "raiders"])
	var posts := [Vector3(-1.5, 0.2, 19.0), Vector3(1.5, 0.2, 24.0), Vector3(-5.0, 0.2, 32.0), Vector3(5.0, 0.2, 33.0), Vector3(0.0, 0.2, 36.0)]
	for i in range(3 + mini(level / 8, 2)):
		camp.add_grunt({"post": posts[i], "role": "gun" if i == 2 else "sword", "seed": rng.randi(), "yaw": 0.0})
	add_child(camp)
	fleet = EnemyFleet.new()
	fleet.name = "Raiders"
	fleet.seed_base = 31000 + seed_value % 5000
	fleet.respawn_time = INF
	fleet.warm = true
	fleet.add_zone(anchor + Vector3(150.0, 0.0, 0.0), 40.0, ["sloop"], level)
	get_parent().add_child.call_deferred(fleet)

func _exit_tree() -> void:
	Shops.extra.erase(shop_id)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 1.0
	if camp == null:
		return
	if not Net.is_client() and not GameManager.world_flags.has(_flag) and camp.grunts.size() > 0 and camp.alive_count() == 0:
		Net.world_flag(_flag)
	if not _thanked and GameManager.world_flags.has(_flag):
		_thanked = true
		_favour()


## (every screen) The deck's cleared: the chef's thanks and the house recipe for this captain.
func _favour() -> void:
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null:
		return
	Food.teach(me.progression, SPECIAL)
	get_tree().call_group("hud", "show_banner", "The chef's favour", "%s teaches you the house Tidewater Bouillabaisse." % chef_name, true)
	FX.sfx("bell", global_position, 0.0, 0.02, 1.2)
	chef.barks = ["You saved my kitchen. Eat here on the house any time - well, nearly.", "That's my bouillabaisse you're carrying. Cook it proud."]


func _say(text: String) -> void:
	get_node("/root/Dialogue").say(chef_name, [text], chef, chef.voice)


func _recipes(p: Player) -> void:
	var pr = p.progression
	var want := ""
	for id in ["captains_feast", SPECIAL]:
		if not Food.known(pr, id):
			want = id
			break
	if want == "":
		_say("You know everything I'll teach. The rest is practice.")
		return
	var price: int = RECIPE_PRICE[want]
	if want == SPECIAL and GameManager.world_flags.has(_flag):
		price = 0
	var inv = p.inventory_component
	if inv.count("gold") < price:
		_say("The %s? %d gold, and worth every coin. Come back when you've got it." % [Food.MEALS[want]["name"], price])
		return
	if price > 0:
		inv.remove_item(ItemDB.get_item("gold"), price)
	Food.teach(pr, want)
	_say("Watch closely. %s: %s. Cook it in your galley." % [Food.MEALS[want]["name"], Food.recipe_text(want)])
	p._toast("Recipe learned: %s" % Food.MEALS[want]["name"])


func _rest(p: Player) -> void:
	p._toast(GameManager.rest(p))


## Word of the stops on the legs ahead (Chain.sea_stop, the same roll the legs make).
func _rumours(_p: Player) -> void:
	var gen := get_tree().get_first_node_in_group("world_gen")
	var lines: Array = []
	if gen and gen.chain():
		var c: Chain = gen.chain()
		var tier := SeaStops.crew_tier(get_tree())
		var words := {"restaurant": "another floating kitchen", "merchant": "a merchant ship trading", "warlord": "a warlord's flagship prowling",
			"lieutenant": "an Admiralty warship hunting"}
		var frontier: Array = c.next_of(int(GameManager.chain_at))
		var seen := 0
		while not frontier.is_empty() and lines.size() < 3 and seen < 12:
			var at := int(frontier.pop_front())
			seen += 1
			for nx in c.next_of(at):
				var k := c.sea_stop(at, int(nx), tier)
				if k != "":
					lines.append("Word is there's %s on the way to %s." % [words[k], c.node(int(nx))["name"]])
				frontier.append(int(nx))
	if lines.is_empty():
		lines = ["Nothing on the board but a recipe for fish soup, and a drawing of the chef."]
	get_node("/root/Dialogue").say("Rumour board", lines, null, 1.0)


## The cook-off (once a visit for each captain, on their own machine): the judge names one of the day's dishes, the
## cooking game plays it (GameMenu.open_cook_game), the grade picks the prize (COOKOFF).
func _cook_off(p: Player) -> void:
	if attacked and not GameManager.world_flags.has(_flag):
		_say("Cook-off? With pirates on the deck? Clear them off first!")
		return
	if _cooked_off:
		_say("One go a visit. Come back to another of our kitchens and try again.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "cookoff"])
	var dish := str(DISHES[rng.randi() % DISHES.size()][0])
	_cooked_off = true
	GameMenu.open_cook_game("Cook-off: %s" % Food.MEALS[dish]["name"], func(_q: float, grade: int): cookoff_prize(p, grade),
		{"meal": dish, "back": "", "speed": COOKOFF_SPEED})


## The judge's verdict and prize for `grade` (tests call it).
func cookoff_prize(p: Player, grade: int) -> void:
	var prize: Dictionary = COOKOFF[grade]
	var inv = p.inventory_component
	var got: Array = []
	if int(prize["gold"]) > 0:
		inv.add_item(ItemDB.get_item("gold"), int(prize["gold"]))
		got.append("%d gold" % int(prize["gold"]))
	var it: Array = prize["item"]
	if not it.is_empty():
		var id := str(it[0])
		if id == "staple":
			var staples: Array = Food.STAPLES.values()
			id = str(staples[hash([seed_value, "staple"]) % staples.size()])
		if id != "" and ItemDB.get_item(id):
			inv.add_item(ItemDB.get_item(id), int(it[1]))
			got.append("%s%s" % [ItemDB.get_item(id).display_name, " x%d" % int(it[1]) if int(it[1]) > 1 else ""])
	p.progression.add_life("cook", int(prize["xp"]))
	_say(str(COOKOFF_SAY[grade]))
	get_tree().call_group("hud", "show_banner", "Cook-off: %s" % CookTiming.GRADE_NAMES[grade], ", ".join(got) if not got.is_empty() else "No prize this time", false)
