class_name Rods
extends RefCounted
## Fishing rods (v1.18): equipment-slot gear in four tiers (the look key "rod" names the tier, so crewmates'
## screens build the same one). A rod sets how far it casts, how soon a fish bites, how long the reel window
## is and the odds of a rare fish. Sold by fishers (Marlo, an artisan fisher's camp); the master's rod only
## by treasure merchants. Models built in code: the rod in three sections (butt with the reel, mid, tip) so
## FishRod can bend it, its crank, and the rod broken down for carrying on the back (and the icon).

## tier -> [item id, name, rarity, value, cast range m, bite time k, reel window k, rare odds k, length m, description]
const ITEMS := {
	"driftwood": ["rod_driftwood", "Driftwood Rod", 0, 5, 7.0, 1.0, 1.0, 1.0, 2.1,
		"A bleached branch, a horsehair line and a wooden spool. Fish have been fooled by worse."],
	"bamboo": ["rod_bamboo", "Bamboo Rod", 1, 7, 9.0, 0.85, 1.15, 1.25, 2.3,
		"Springy cane bound at every joint, a brass reel. It casts farther than it looks."],
	"steel": ["rod_steel", "Steel-tipped Rod", 2, 12, 11.0, 0.72, 1.3, 1.6, 2.45,
		"Dark ash with a tempered steel tip that feels the lightest nibble. A fisher's pride."],
	"master": ["rod_master", "Master's Rod", 3, 20, 14.0, 0.6, 1.5, 2.2, 2.6,
		"Black lacquer, gold whipping, a reel that purrs. Made for the fish people tell stories about."],
}
const TIERS := ["driftwood", "bamboo", "steel", "master"]
## The sections, from the grip (origin, the right hand) along -Z: the butt runs back to BUTT_END (the left
## hand) and forward to SEG1; the mid section to SEG1 + SEG2; the tip the rest of the rod's length.
const BUTT_END := 0.4
const SEG1 := 0.85
const SEG2 := 0.8
## The reel hangs under the rod here (rod-local), its crank turning on the left (-X) about its axle (X).
const REEL_AT := Vector3(0, -0.07, 0.11)
const CRANK_X := -0.05
const CRANK_ARM := 0.045
## Looks by tier: [blank texture, blank tint, grip colour, wrap colour, reel colour, tip colour].
const LOOK := {
	"driftwood": ["birch_bark", Color(0.82, 0.78, 0.7), Color(0.4, 0.3, 0.2), Color(0.55, 0.45, 0.3), Color(0.5, 0.38, 0.24), Color(0.7, 0.66, 0.58)],
	"bamboo": ["bamboo", Color(1.0, 0.95, 0.8), Color(0.62, 0.48, 0.3), Color(0.2, 0.14, 0.1), Color(0.78, 0.6, 0.25), Color(0.85, 0.8, 0.6)],
	"steel": ["planks_dark", Color(0.62, 0.48, 0.36), Color(0.22, 0.16, 0.12), Color(0.6, 0.12, 0.1), Color(0.6, 0.6, 0.64), Color(0.72, 0.74, 0.78)],
	"master": ["planks_dark", Color(0.22, 0.12, 0.12), Color(0.12, 0.08, 0.07), Color(0.9, 0.72, 0.3), Color(0.9, 0.72, 0.3), Color(0.15, 0.1, 0.1)],
}

static var _meshes: Dictionary = {}
static var _icons: Dictionary = {}


## What a fisher's camp (Artisans) picks its day's rods from (Shops' daily stock: a pool and a size).
static func fisher_pool() -> Array:
	return [["rod_driftwood"], ["rod_bamboo"], ["rod_steel"]]


static func item_id(tier: String) -> String:
	return str(ITEMS[tier][0])


## The rod's tier ("" if `it` isn't a rod).
static func tier_of(it: ItemData) -> String:
	return str(it.look.get("rod", "")) if it and it.gear_slot == "equipment" else ""


static func stat(tier: String, which: String) -> float:
	return float(ITEMS[tier][{"range": 4, "bite": 5, "window": 6, "rare": 7, "length": 8}[which]])


## (ItemDB._load_all) the rods into the item table.
static func make_items(items: Dictionary) -> void:
	for tier in TIERS:
		var e: Array = ITEMS[tier]
		var it := ItemData.new()
		it.id = str(e[0])
		it.display_name = str(e[1])
		it.rarity = int(e[2]) as ItemData.Rarity
		it.value = int(e[3])
		it.description = str(e[9])
		it.item_type = ItemData.ItemType.GEAR
		it.gear_slot = "equipment"
		it.look = {"rod": tier}
		it.icon_kind = "rod"
		it.stackable = false
		it.max_stack = 1
		it.icon = icon(tier)
		items[it.id] = it


# --------------------------------------------------------------------------
# Models (rod-local: the grip at the origin, the tip along -Z, the reel under it at -Y)
# --------------------------------------------------------------------------
## "butt" (handle, reel seat, reel, the first section), "mid", "tip" (each from its own joint at the origin
## along -Z), "crank" (its axle at the origin along X, the arm up +Y), "carried" (broken down, three pieces
## side by side along +Y, for the back and the icon).
static func mesh(tier: String, part: String) -> ArrayMesh:
	var key := tier + ":" + part
	if _meshes.has(key):
		return _meshes[key]
	var lk: Array = LOOK[tier]
	var blank := PSXMat.lit(str(lk[0]), lk[1])
	var flat := PSXMat.lit("leather", Color.WHITE)
	var metal := PSXMat.lit("metal", Color.WHITE)
	var length := stat(tier, "length")
	var mb := MeshBuilder.new()
	match part:
		"butt":
			_butt(mb, tier, blank, flat, metal, Transform3D.IDENTITY)
		"mid":
			_section(mb, tier, blank, flat, metal, Transform3D.IDENTITY, SEG2, 0.0095, 0.0068, 3)
		"tip":
			_section(mb, tier, blank, flat, metal, Transform3D.IDENTITY, length - SEG1 - SEG2, 0.0068, 0.0035, 3)
			mb.add_cylinder(metal, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -(length - SEG1 - SEG2))), 0.006, 0.004, 0.03, 4, 2.0, lk[5])
		"crank":
			_crank(mb, metal, flat, lk, Transform3D.IDENTITY)
		"carried":
			# along +Y: the butt (its reel), the mid and tip sections strapped beside it
			var up := Basis(Vector3.RIGHT, PI * 0.5)
			_butt(mb, tier, blank, flat, metal, Transform3D(up, Vector3(0, BUTT_END, 0)))
			_crank(mb, metal, flat, lk, Transform3D(up, Vector3(0, BUTT_END, 0)) * Transform3D(Basis(), REEL_AT))
			_section(mb, tier, blank, flat, metal, Transform3D(up, Vector3(0.022, 0.05, 0.004)), SEG2, 0.0095, 0.0068, 3)
			_section(mb, tier, blank, flat, metal, Transform3D(up, Vector3(-0.02, 0.1, 0.006)), length - SEG1 - SEG2, 0.0068, 0.0035, 3)
			for y in [0.28, 0.82]:
				mb.add_box(flat, Transform3D(Basis(), Vector3(0, y, 0.003)), Vector3(0.07, 0.025, 0.035), 2.0, lk[3], false)
		_:
			push_error("Rods.mesh: no part \"%s\"" % part)
	var m := mb.commit()
	m.set_meta("model", "rod:" + key)
	_meshes[key] = m
	return m


## The handle (BUTT_END back to the reel seat), the seat, the reel, and the first length of blank to SEG1.
static func _butt(mb: MeshBuilder, tier: String, blank: Material, flat: Material, metal: Material, xf: Transform3D) -> void:
	var lk: Array = LOOK[tier]
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	# the handle: a butt cap, the rear grip, the reel seat, the fore grip under the right hand
	mb.add_cylinder(metal, xf * Transform3D(along, Vector3(0, 0, BUTT_END)), 0.021, 0.021, 0.02, 6, 2.0, lk[4], true, true)
	mb.add_cylinder(flat, xf * Transform3D(along, Vector3(0, 0, BUTT_END - 0.02)), 0.019, 0.016, 0.24, 6, 3.0, lk[2], false, false)
	mb.add_cylinder(metal, xf * Transform3D(along, Vector3(0, 0, 0.14)), 0.014, 0.014, 0.07, 6, 2.0, lk[4] * 0.8, false, false)
	mb.add_cylinder(flat, xf * Transform3D(along, Vector3(0, 0, 0.07)), 0.017, 0.012, 0.16, 6, 3.0, lk[2], true, false)
	_section(mb, tier, blank, flat, metal, xf * Transform3D(Basis(), Vector3(0, 0, -0.09)), SEG1 - 0.09, 0.012, 0.0095, 2)
	# the reel: a foot down from the seat, the spool (axle along X), the drag knob
	var r := xf * Transform3D(Basis(), REEL_AT)
	mb.add_box(metal, xf * Transform3D(Basis(), Vector3(0, -0.035, REEL_AT.z)), Vector3(0.008, 0.04, 0.03), 2.0, lk[4], false)
	var spool := 0.038 if tier != "driftwood" else 0.034
	mb.add_cylinder(metal, r * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.02, 0, 0)), spool, spool, 0.04, 8, 2.0, lk[4], true, true)
	mb.add_cylinder(flat, r * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.016, 0, 0)), spool * 0.8, spool * 0.8, 0.032, 8, 2.0, Color(0.9, 0.88, 0.82), true, true)
	mb.add_cylinder(metal, r * Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.02, 0, 0)), 0.01, 0.008, 0.015, 6, 2.0, lk[4] * 0.7)


## A length of blank from xf's origin along -Z, tapering r0 to r1, with `guides` line guides under it.
static func _section(mb: MeshBuilder, tier: String, blank: Material, flat: Material, metal: Material, xf: Transform3D,
		length: float, r0: float, r1: float, guides: int) -> void:
	var lk: Array = LOOK[tier]
	mb.add_cylinder(blank, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), r0, r1, length, 5, 4.0, Color.WHITE, false, false)
	# a whipped ferrule at the joint, and the guides (rings under the blank, each on a little whipped foot)
	mb.add_cylinder(flat, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.02)), r0 + 0.003, r0 + 0.003, 0.05, 5, 4.0, lk[3], false, false)
	for i in range(guides):
		var z := -length * (0.3 + 0.6 * float(i) / maxf(guides - 1, 1))
		var r := lerpf(r0, r1, -z / length)
		mb.add_box(flat, xf * Transform3D(Basis(), Vector3(0, -r - 0.006, z)), Vector3(0.006, 0.012, 0.016), 4.0, lk[3], false)
		mb.add_tube(metal, _ring(xf, Vector3(0, -r - 0.021, z), 0.008), 0.0018, 0.0018, 3, 2.0, Color(0.85, 0.85, 0.88))
	if tier == "bamboo":
		# the cane's nodes
		for k in range(1, int(length / 0.22) + 1):
			var z := -k * 0.22
			mb.add_cylinder(flat, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, z + 0.008)), lerpf(r0, r1, -z / length) + 0.0025, lerpf(r0, r1, -z / length) + 0.0025, 0.016, 5, 4.0, lk[3] * 1.8, false, false)


## A closed ring of points round `c` in the plane across the rod (xf's XY), for add_tube.
static func _ring(xf: Transform3D, c: Vector3, r: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in range(7):
		var a := TAU * i / 6.0
		pts.append(xf * (c + Vector3(cos(a), sin(a), 0) * r))
	return pts


## The crank: the axle out along X (to CRANK_X from the spool's side), the arm along +Y, a knob on the end.
static func _crank(mb: MeshBuilder, metal: Material, flat: Material, lk: Array, xf: Transform3D) -> void:
	mb.add_cylinder(metal, xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), 0.005, 0.005, -CRANK_X, 4, 2.0, lk[4] * 0.8)
	mb.add_box(metal, xf * Transform3D(Basis(), Vector3(CRANK_X, CRANK_ARM * 0.5, 0)), Vector3(0.006, CRANK_ARM + 0.012, 0.012), 2.0, lk[4], false)
	mb.add_cylinder(flat, xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(CRANK_X - 0.003, CRANK_ARM, 0)), 0.009, 0.008, 0.028, 6, 2.0, lk[2], true, true)


static func icon(tier: String) -> Texture2D:
	if not _icons.has(tier):
		_icons[tier] = WeaponDesigns.mesh_icon(mesh(tier, "carried"), Basis.from_euler(Vector3(0, PI * 0.5, 0)), -PI * 0.25)
	return _icons[tier]
