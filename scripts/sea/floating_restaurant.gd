class_name FloatingRestaurant
extends SeaVessel
## The floating restaurant (docs/v1_28_plan.md, The sea): a huge ship-restaurant at anchor on a sea leg, a hub at
## sea. A broad barge with a great painted fish for a bow, a timber dining hall with a tiled roof and a lantern
## tower, banners on two tall poles: seen from far off. Come alongside the landing stage on her starboard side (a
## pontoon at the waterline, a ramp up to the deck) or climb a ladder from the water.
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

## Hull: the deck at y 0 (ship-local), half beam HW, from the stern ST to the bow BW; the fish head past it.
const HW := 10.5
const ST := 21.0
const BW := -21.0
const HALL := [Vector3(-7.5, 0.0, -14.0), Vector3(7.5, 5.2, 8.0)]
const DOOR_HW := 1.6
const PONTOON := [Vector3(10.9, -1.85, 0.0), Vector3(14.4, -1.5, 15.0)]

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
	half_len = 20.0
	half_beam = HW
	bounds = AABB(Vector3(-15.0, -3.0, -34.0), Vector3(30.0, 24.0, 58.0))
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
# The model
# --------------------------------------------------------------------------
func _model() -> void:
	var mb := MeshBuilder.new()
	var hull := PSXMat.lit("planks_dark", Color(0.95, 0.5, 0.36), {"affine": 0.6})
	var deck := PSXMat.lit("planks", Color(0.92, 0.84, 0.72), {"affine": 0.6})
	var trim := PSXMat.lit("planks", Color(0.92, 0.82, 0.5))
	var wall := PSXMat.lit("plaster_wash", Color(0.98, 0.93, 0.82))
	var beam := PSXMat.lit("planks_dark", Color(0.55, 0.36, 0.24))
	var roof := PSXMat.lit("roof_tiles", Color(0.8, 0.32, 0.22))
	var fish := PSXMat.lit("scales", Color(0.95, 0.55, 0.25))
	var belly := PSXMat.lit("scales", Color(1.0, 0.9, 0.7))
	var window := PSXMat.glow(Color(1.0, 0.78, 0.42), 1.6)
	var dark := PSXMat.lit("planks_dark", Color(0.25, 0.2, 0.18))
	var white := PSXMat.lit("plaster", Color(0.98, 0.98, 0.95))
	var wood := PSXMat.lit("bark")
	var red := PSXMat.lit("cloth_red", Color(0.95, 0.3, 0.22))
	var cream := PSXMat.lit("canvas", Color(0.98, 0.94, 0.84))
	var down := Basis(Vector3.RIGHT, -PI * 0.5)
	# the hull: a broad barge lofted stern to bow (a rounded box section), then the great fish's head
	var box := MeshBuilder.profile_oct(0.75)
	mb.add_loft(hull, Transform3D(down, Vector3(0, 0, ST)), [[0.0, HW - 0.8, 2.3, -2.4], [3.0, HW, 2.3, -2.4],
		[ST - BW - 8.0, HW, 2.3, -2.4], [ST - BW - 2.0, HW - 1.4, 2.3, -2.4], [ST - BW, HW - 3.0, 2.4, -2.3]], box, 4.0, Color.WHITE, true, false)
	mb.add_loft(fish, Transform3D(down, Vector3(0, 0, BW)), [[0.0, HW - 3.0, 2.4, -2.3], [3.0, 7.2, 3.6, -1.0],
		[7.0, 6.4, 4.0, -0.4], [10.0, 4.6, 3.4, -0.4], [12.0, 2.4, 2.0, -0.6], [12.9, 0.4, 0.5, -0.8]], MeshBuilder.profile_oct(0.5), 2.0, Color.WHITE, false, true)
	# its pale lower jaw and mouth line, eyes, a crest fin over the head, pectoral fins
	mb.add_loft(belly, Transform3D(down, Vector3(0, -1.0, BW - 2.0)), [[0.0, 6.0, 1.6, -2.6], [5.0, 5.6, 1.8, -2.3], [9.0, 3.4, 1.3, -2.0], [11.0, 0.8, 0.5, -1.8]], MeshBuilder.profile_oct(0.5), 2.0)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, -1.2, BW - 11.6)), Vector3(3.8, 0.35, 1.4), 1.0)
	for s in [-1.0, 1.0]:
		var eye := Vector3(s * 6.55, 0.9, BW - 6.4)
		mb.add_cylinder(white, Transform3D(Basis(Vector3.BACK, s * PI * 0.5), eye), 1.5, 1.5, 0.3, 12, 1.0, Color.WHITE, true, true)
		mb.add_cylinder(dark, Transform3D(Basis(Vector3.BACK, s * PI * 0.5), eye + Vector3(s * 0.2, 0.1, -0.2)), 0.75, 0.75, 0.25, 10, 1.0, Color.WHITE, true, true)
		mb.add_tri(fish, Vector3(s * 5.6, -1.2, BW - 2.0), Vector3(s * 9.0, -2.0, BW + 2.5), Vector3(s * 5.8, -0.2, BW + 1.0), Vector3(s, 0, 0), Vector3(s, 0, 0), Vector3(s, 0, 0), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
		mb.add_tri(fish, Vector3(s * 5.6, -1.2, BW - 2.0), Vector3(s * 5.8, -0.2, BW + 1.0), Vector3(s * 9.0, -2.0, BW + 2.5), Vector3(-s, 0, 0), Vector3(-s, 0, 0), Vector3(-s, 0, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1))
	for side in [0.05, -0.05]:
		var n := Vector3(signf(side), 0, 0)
		var a := Vector3(side, 3.4, BW - 2.0)
		var b := Vector3(side, 6.8, BW - 6.0)
		var c := Vector3(side, 3.0, BW - 9.0)
		if side > 0.0:
			mb.add_tri(red, a, b, c, n, n, n, Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1))
		else:
			mb.add_tri(red, a, c, b, n, n, n, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0))
	# the deck, a gilt rub rail round it, the bulwark posts
	mb.add_box(deck, Transform3D(Basis(), Vector3(0, -0.15, (ST + BW) * 0.5)), Vector3(HW * 2.0, 0.3, ST - BW), 0.4)
	for s in [-1.0, 1.0]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(s * (HW + 0.05), -0.55, 0.0)), Vector3(0.18, 0.3, ST - BW), 1.0)
		for k in range(15):
			var z := BW + 1.0 + k * 2.8
			if s > 0.0 and z > -9.5 and z < -5.5:
				continue
			mb.add_box(beam, Transform3D(Basis(), Vector3(s * (HW - 0.15), 0.45, z)), Vector3(0.16, 0.9, 0.16), 1.0)
	_rails(mb, trim)
	# the dining hall: whitewashed walls between dark posts, windows lit warm, the door aft, a tiled gable roof
	var lo: Vector3 = HALL[0]
	var hi: Vector3 = HALL[1]
	var h := hi.y
	for s in [-1.0, 1.0]:
		mb.add_box(wall, Transform3D(Basis(), Vector3(s * hi.x, h * 0.5, (lo.z + hi.z) * 0.5)), Vector3(0.3, h, hi.z - lo.z), 0.5)
		for k in range(6):
			var z := lo.z + 2.0 + k * 3.6
			mb.add_box(window, Transform3D(Basis(), Vector3(s * hi.x, 2.4, z)), Vector3(0.36, 1.4, 1.2), 1.0)
			mb.add_box(beam, Transform3D(Basis(), Vector3(s * (hi.x + 0.12), h * 0.5, z + 1.8)), Vector3(0.12, h, 0.25), 1.0)
	mb.add_box(wall, Transform3D(Basis(), Vector3(0, h * 0.5, lo.z)), Vector3(hi.x * 2.0, h, 0.3), 0.5)
	var side_w := hi.x - DOOR_HW
	for s in [-1.0, 1.0]:
		mb.add_box(wall, Transform3D(Basis(), Vector3(s * (DOOR_HW + side_w * 0.5), h * 0.5, hi.z)), Vector3(side_w, h, 0.3), 0.5)
		mb.add_box(window, Transform3D(Basis(), Vector3(s * 4.6, 2.4, hi.z)), Vector3(1.6, 1.4, 0.36), 1.0)
	mb.add_box(wall, Transform3D(Basis(), Vector3(0, (3.2 + h) * 0.5, hi.z)), Vector3(DOOR_HW * 2.0, h - 3.2, 0.3), 0.5)
	mb.add_box(beam, Transform3D(Basis(), Vector3(0, h + 0.1, (lo.z + hi.z) * 0.5)), Vector3(hi.x * 2.0 + 0.4, 0.25, hi.z - lo.z + 0.4), 0.5, Color(1.2, 1.1, 1.0), false)
	for k in range(5):
		mb.add_box(beam, Transform3D(Basis(), Vector3(0, h - 0.2, lo.z + 2.0 + k * 4.4)), Vector3(hi.x * 2.0, 0.3, 0.3), 1.0, Color.WHITE, false)
	mb.add_gable_roof(roof, Transform3D(Basis(), Vector3(0, h + 0.2, (lo.z + hi.z) * 0.5)), hi.x * 2.0, hi.z - lo.z, 4.2, 0.8, 0.3, Color.WHITE, wall)
	# the lantern tower on the ridge, its pyramid roof and a long pennant
	var tz := (lo.z + hi.z) * 0.5 - 2.0
	mb.add_box(wall, Transform3D(Basis(), Vector3(0, h + 5.5, tz)), Vector3(3.6, 3.4, 3.6), 0.5)
	for s in [-1.0, 1.0]:
		mb.add_box(window, Transform3D(Basis(), Vector3(s * 1.82, h + 5.6, tz)), Vector3(0.05, 1.6, 1.8), 1.0)
		mb.add_box(window, Transform3D(Basis(), Vector3(0, h + 5.6, tz + s * 1.82)), Vector3(1.8, 1.6, 0.05), 1.0)
	mb.add_pyramid_roof(roof, Transform3D(Basis(), Vector3(0, h + 7.2, tz)), 4.4, 4.4, 2.6)
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, h + 9.6, tz)), 0.1, 0.06, 5.0, 5, 1.0)
	_pennant(mb, red, Vector3(0, h + 14.4, tz), 6.0)
	# the kitchen chimney
	mb.add_box(PSXMat.lit("stone_brick"), Transform3D(Basis(), Vector3(4.0, h + 3.0, lo.z + 2.0)), Vector3(1.1, 6.0, 1.1), 0.5)
	# a signboard over the door: a fish
	mb.add_card(PSXMat.cutout("sign_fish"), Transform3D(Basis(), Vector3(0, 4.3, hi.z + 0.2)), 2.4, 1.2)
	# banner poles fore and aft with long streamers, an awning over the stern terrace
	for at in [Vector3(-7.5, 0, -18.0), Vector3(7.5, 0, -18.0), Vector3(-8.5, 0, 18.5), Vector3(8.5, 0, 18.5)]:
		mb.add_cylinder(wood, Transform3D(Basis(), at), 0.2, 0.12, 15.0, 6, 0.8)
		_pennant(mb, red if at.x < 0.0 else cream, at + Vector3(0, 14.4, 0), 5.0)
	for i in range(8):
		var x := -7.6 + i * 1.9
		var m: Material = red if i % 2 == 0 else cream
		var a := Vector3(x, 3.5, 8.2)
		var b := Vector3(x + 1.9, 3.5, 8.2)
		var c := Vector3(x + 1.9, 2.7, 14.8)
		var d := Vector3(x, 2.7, 14.8)
		mb.add_quad(m, a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 0.99, 0.12))
		mb.add_quad(m, d, c, b, a, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.8, 0.8, 0.8), Vector3(0, -0.99, -0.12))
	for x in [-7.5, 7.5]:
		for z in [9.0, 14.4]:
			mb.add_cylinder(wood, Transform3D(Basis(), Vector3(x, 0, z)), 0.08, 0.08, 3.4 - (z - 9.0) * 0.08, 5, 1.0)
	# the landing stage: a pontoon at the waterline and a ramp up the starboard side, ladders down
	var pl: Vector3 = PONTOON[0]
	var ph: Vector3 = PONTOON[1]
	mb.add_box(deck, Transform3D(Basis(), (pl + ph) * 0.5), ph - pl, 0.4)
	mb.add_box(hull, Transform3D(Basis(), Vector3((pl.x + ph.x) * 0.5, pl.y - 0.4, (pl.z + ph.z) * 0.5)), Vector3(ph.x - pl.x - 0.3, 0.6, ph.z - pl.z - 0.3), 1.0)
	var r0 := Vector3(11.9, ph.y, 1.5)
	var r1 := Vector3(11.9, 0.0, -7.5)
	mb.add_box(deck, Transform3D(Basis.looking_at((r1 - r0).normalized(), Vector3.UP), (r0 + r1) * 0.5 + Vector3(0, -0.1, 0)), Vector3(1.9, 0.2, r0.distance_to(r1)), 0.4)
	mb.add_box(deck, Transform3D(Basis(), Vector3(11.75, -0.15, -8.5)), Vector3(2.5, 0.3, 2.4), 0.4)
	var inst := mb.to_instance("PSXModel")
	inst.visibility_range_end = 2400.0
	add_child(inst)
	_interior()


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


func _rails(mb: MeshBuilder, trim: Material) -> void:
	for s in [-1.0, 1.0]:
		if s > 0.0:
			mb.add_box(trim, Transform3D(Basis(), Vector3(HW - 0.15, 0.9, (BW + -9.8) * 0.5)), Vector3(0.14, 0.1, -9.8 - BW), 1.0)
			mb.add_box(trim, Transform3D(Basis(), Vector3(HW - 0.15, 0.9, (-5.2 + ST) * 0.5)), Vector3(0.14, 0.1, ST + 5.2), 1.0)
		else:
			mb.add_box(trim, Transform3D(Basis(), Vector3(-(HW - 0.15), 0.9, 0.0)), Vector3(0.14, 0.1, ST - BW), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, 0.9, ST - 0.15)), Vector3(HW * 2.0, 0.1, 0.14), 1.0)


## Tables and stools, the kitchen counter and its stove, the guest room's door, the rumour board (one mesh).
func _interior() -> void:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.7, 0.5, 0.34))
	var cloth := PSXMat.lit("fabric_check", Color(0.95, 0.9, 0.85))
	var stone := PSXMat.lit("stone_brick")
	var fire := PSXMat.glow(Color(1.0, 0.5, 0.2), 2.2)
	var door := PSXMat.lit("door")
	for t in _tables():
		mb.add_cylinder(wood, Transform3D(Basis(), t), 0.12, 0.12, 0.75, 6, 1.0)
		mb.add_cylinder(cloth, Transform3D(Basis(), t + Vector3(0, 0.75, 0)), 0.85, 0.85, 0.06, 10, 1.0, Color.WHITE, true, true)
		for k in range(3):
			var a := k * TAU / 3.0 + 0.4
			mb.add_cylinder(wood, Transform3D(Basis(), t + Vector3(cos(a), 0, sin(a)) * 1.25), 0.22, 0.2, 0.45, 6, 1.0, Color.WHITE, false, true)
	var lo: Vector3 = HALL[0]
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.55, lo.z + 3.6)), Vector3(8.0, 1.1, 0.8), 0.5)
	mb.add_box(stone, Transform3D(Basis(), Vector3(4.0, 0.6, lo.z + 1.2)), Vector3(2.2, 1.2, 1.4), 0.5)
	mb.add_box(fire, Transform3D(Basis(), Vector3(4.0, 0.7, lo.z + 1.95)), Vector3(1.2, 0.5, 0.05), 1.0)
	mb.add_box(stone, Transform3D(Basis(), Vector3(-3.5, 0.5, lo.z + 1.0)), Vector3(3.0, 1.0, 1.0), 0.5)
	mb.add_box(door, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-7.32, 1.1, 4.5)), Vector3(1.2, 2.2, 0.06), 1.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(7.32, 1.7, 5.5)), Vector3(1.6, 1.1, 0.08), 1.0)
	mb.add_card(PSXMat.lit("canvas", Color(0.95, 0.92, 0.8)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(7.26, 1.75, 5.5)), 1.3, 0.8)
	mb.add_box(wood, Transform3D(Basis(), Vector3(-4.5, 0.45, -6.0)), Vector3(2.4, 0.9, 1.2), 0.5)
	var inst := mb.to_instance("Interior")
	inst.visibility_range_end = 120.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _tables() -> Array:
	return [Vector3(-4.0, 0, 2.5), Vector3(0.0, 0, 3.5), Vector3(4.0, 0, 2.5), Vector3(-4.0, 0, -2.0), Vector3(4.0, 0, -2.0), Vector3(0.0, 0, -1.0)]


# --------------------------------------------------------------------------
# Collision
# --------------------------------------------------------------------------
func _collide() -> void:
	var pts := PackedVector3Array()
	for r in [[ST, HW - 0.8], [ST - 3.0, HW], [BW + 6.0, HW], [BW, HW - 3.0], [BW - 6.0, 6.5], [BW - 12.5, 1.0]]:
		for s in [-1.0, 1.0]:
			pts.append(Vector3(s * float(r[1]), 0.0, float(r[0])))
			pts.append(Vector3(s * float(r[1]) * 0.7, -4.4, float(r[0])))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	_shape(hull, Transform3D.IDENTITY)
	var fish := ConvexPolygonShape3D.new()
	fish.points = PackedVector3Array([Vector3(-6.0, 0.0, BW - 1.0), Vector3(6.0, 0.0, BW - 1.0), Vector3(-6.4, 3.0, BW - 6.0),
		Vector3(6.4, 3.0, BW - 6.0), Vector3(0, 0.0, BW - 12.8), Vector3(-6.0, -4.0, BW - 1.0), Vector3(6.0, -4.0, BW - 1.0)])
	_shape(fish, Transform3D.IDENTITY)
	# bulwark rails (a gap for the starboard ramp), the stern
	_box(Vector3(-(HW - 0.15), 0.5, 0.0), Vector3(0.2, 1.0, ST - BW))
	_box(Vector3(HW - 0.15, 0.5, (BW - 9.8) * 0.5), Vector3(0.2, 1.0, -9.8 - BW))
	_box(Vector3(HW - 0.15, 0.5, (ST - 5.2) * 0.5), Vector3(0.2, 1.0, ST + 5.2))
	_box(Vector3(0, 0.5, ST - 0.15), Vector3(HW * 2.0, 1.0, 0.2))
	# the hall: side walls, the back, the front either side of the door and over it
	var lo: Vector3 = HALL[0]
	var hi: Vector3 = HALL[1]
	var h := hi.y
	for s in [-1.0, 1.0]:
		_box(Vector3(s * hi.x, h * 0.5, (lo.z + hi.z) * 0.5), Vector3(0.3, h, hi.z - lo.z))
		_box(Vector3(s * (DOOR_HW + (hi.x - DOOR_HW) * 0.5), h * 0.5, hi.z), Vector3(hi.x - DOOR_HW, h, 0.3))
	_box(Vector3(0, h * 0.5, lo.z), Vector3(hi.x * 2.0, h, 0.3))
	_box(Vector3(0, (3.2 + h) * 0.5, hi.z), Vector3(DOOR_HW * 2.0, h - 3.2, 0.3))
	_box(Vector3(0, h + 0.1, (lo.z + hi.z) * 0.5), Vector3(hi.x * 2.0, 0.3, hi.z - lo.z))
	# the counter and the stoves
	_box(Vector3(0, 0.55, lo.z + 3.6), Vector3(8.0, 1.1, 0.8))
	_box(Vector3(4.0, 0.6, lo.z + 1.2), Vector3(2.2, 1.2, 1.4))
	_box(Vector3(-3.5, 0.5, lo.z + 1.0), Vector3(3.0, 1.0, 1.0))
	# the pontoon, the ramp and its head
	var pl: Vector3 = PONTOON[0]
	var ph: Vector3 = PONTOON[1]
	_box((pl + ph) * 0.5 + Vector3(0, -0.2, 0), ph - pl + Vector3(0, 0.4, 0))
	var r0 := Vector3(11.9, ph.y, 1.5)
	var r1 := Vector3(11.9, 0.0, -7.5)
	var ramp := BoxShape3D.new()
	ramp.size = Vector3(1.9, 0.2, r0.distance_to(r1))
	_shape(ramp, Transform3D(Basis.looking_at((r1 - r0).normalized(), Vector3.UP), (r0 + r1) * 0.5 + Vector3(0, -0.1, 0)))
	_box(Vector3(11.75, -0.15, -8.5), Vector3(2.5, 0.3, 2.4))
	_box(Vector3(12.9, 0.5, -3.0), Vector3(0.12, 1.0, 9.5))


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
	for spec in [[Vector3(-HW, 0.0, -4.0), -PI * 0.5], [Vector3(HW, 0.0, 12.0), PI * 0.5], [Vector3(0.0, 0.0, ST), 0.0]]:
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
	pl.position = Vector3(14.4, -1.5, 8.0)
	pl.rotation.y = PI * 0.5
	add_child(pl)
	var lo: Vector3 = HALL[0]
	_spot("Recipes", "Ask %s about recipes" % chef_name.get_slice(" ", 1), Vector3(0, 1.0, lo.z + 4.3), _recipes)
	_spot("Room", "Take a room and rest", Vector3(-6.6, 1.0, 4.5), _rest)
	_spot("Rumours", "Read the rumour board", Vector3(6.6, 1.2, 5.5), _rumours)
	_spot("CookOff", "Enter the cook-off", Vector3(-4.5, 1.0, -5.2), _cook_off)


func _spot(nm: String, prompt: String, at: Vector3, fn: Callable) -> void:
	var it := Interactable.new()
	it.name = nm
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = prompt
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
	chef.position = Vector3(0.0, 0.0, HALL[0].z + 3.0)
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
	judge.position = Vector3(-6.2, 0.0, -6.0)


## Pirates hold the deck: a crew round the hall's door and on the stern terrace, a sloop of theirs standing off.
func _raiders() -> void:
	camp = GruntCamp.new()
	camp.name = "Raiders"
	camp.respawn_time = INF
	camp.level = level
	camp.warm_start = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "raiders"])
	var posts := [Vector3(-2.0, 0.2, 10.5), Vector3(2.5, 0.2, 11.5), Vector3(-5.0, 0.2, 15.0), Vector3(5.0, 0.2, 16.0), Vector3(0.0, 0.2, 18.0)]
	for i in range(3 + mini(level / 8, 2)):
		camp.add_grunt({"post": posts[i], "role": "gun" if i == 2 else "sword", "seed": rng.randi(), "yaw": 0.0})
	add_child(camp)
	fleet = EnemyFleet.new()
	fleet.name = "Raiders"
	fleet.seed_base = 31000 + seed_value % 5000
	fleet.respawn_time = INF
	fleet.warm = true
	fleet.add_zone(anchor + Vector3(80.0, 0.0, 0.0), 40.0, ["sloop"], level)
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
