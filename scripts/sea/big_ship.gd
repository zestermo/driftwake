class_name BigShip
extends EnemyShip
## The big named ships (docs/v1_28_plan.md, The sea): a pirate warlord's flagship ("flagship") and an Admiralty
## lieutenant's warship ("warship"), the sloop's hull and rig drawn K times as big (the body, its collision, guns,
## ladders and rail scale with it; her men are drawn at their own size). Cannons, board, duel: she comes for the crew
## and trades double broadsides (she never boards or rams); board her (her ladders, or "Swing aboard" from a deck
## alongside) and her crew fights across her decks; once most of them are down her captain steps out on the
## quarterdeck (a cutscene, Cutscene "sea_captain") and duels the boarders (an AI captain, RivalDuel.build). Beaten,
## the captain yields: she strikes, and the captain's chest is rich (gold, treasure, a fine weapon, gear, blueprints,
## parts, salvage) and the bounty and XP big. Sunk from afar she leaves only flotsam. Fleeing is allowed (she gives up
## past her sight like any other). Co-op: the host sails her and runs the duel; the captain and the cutscene reach
## every screen through Net.everyone.

const K := 1.5
const NAMES := {
	"flagship": ["Gorran Vesk", "Red Maelis", "Brannoc Ironwake", "Sable Huxley", "Old Thessaly Crane"],
	"warship": ["Lieutenant Corwin Hale", "Lieutenant Ada Strand", "Lieutenant Mattias Crewe", "Lieutenant Isolde Varr"],
}
const SHIP_NAMES := {
	"flagship": ["the Red Maw", "the Widowmaker", "the Iron Gull", "the Gallows Queen"],
	"warship": ["the Steadfast", "the Resolute", "the Lawbringer", "the Unbending"],
}
const LINES := {
	"flagship": ["You climbed aboard my ship. Brave. Now climb off it in pieces.",
		"My crew's on the deck at your feet. I'll make you room beside them.",
		"Every ship on this sea pays me. You'll pay in full."],
	"warship": ["By the Admiralty's warrant, you're under arrest. Resist, and I'll write 'killed resisting'.",
		"Your bounty's posted on my cabin wall. I've been looking forward to this.",
		"Strike your colours and come quietly. No? Good."],
}
const YIELD := {"flagship": "Enough! Take the chest and get off my ship!", "warship": "I yield... the warrant can wait."}
const WEAPONS := {"flagship": ["boarding_axe", "greatsword", "warhammer", "cutlass"], "warship": ["naval_sabre", "katana", "spear", "cutlass"]}
## Her captain steps out once her deck crew is down to this many, or this long after you board.
const CAPTAIN_AT := 2
const CAPTAIN_AFTER := 25.0
## The captain's health over a rival captain's, and how hard taking her raises the bounty (x Bounty.TABLE).
const CAPTAIN_HP := 3.5
const BOUNTY_K := 3.0
## "Swing aboard": from a deck alongside, within this of her rail.
const SWING_R := 7.0

var captain_name := ""
var ship_name := ""
## The captain: "" not out yet, "out" (cutscene), "duel", "beaten".
var duel := ""
var captain: Player
var _deck_t := 0.0
var _yield_t := -1.0


func setup_big(center: Vector3, seed_value: int, kind_name: String, lvl: int) -> BigShip:
	setup(center, 70.0, float(seed_value % 628) * 0.01, seed_value, kind_name)
	level = lvl
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "captain"])
	captain_name = str(NAMES[kind_name][rng.randi() % NAMES[kind_name].size()])
	ship_name = str(SHIP_NAMES[kind_name][rng.randi() % SHIP_NAMES[kind_name].size()]).capitalize()
	set_meta("title", "%s (%s)" % [ship_name, captain_name])
	return self


func _ready() -> void:
	super._ready()
	add_to_group("big_ships")
	_dress()
	for c in _crew:
		(c["node"] as Node3D).scale = Vector3.ONE / K
	for sgn in [-1.0, 1.0]:
		var it := Interactable.new()
		it.name = "Swing%s" % ("S" if sgn > 0.0 else "P")
		it.collision_layer = 512
		it.collision_mask = 0
		it.prompt_text = "Swing aboard"
		it.usable_in_water = true
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = SWING_R / K
		cs.shape = sph
		it.add_child(cs)
		it.position = Vector3(sgn * (HullLayout.HALF_BEAM + SWING_R / K * 0.6), HullLayout.DECK_Y, -1.0)
		add_child(it)
		it.interacted.connect(_swing_aboard.bind(sgn))
	global_transform = Transform3D(global_transform.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * K), global_transform.origin)


## A ship of the line's rig and finery over the sloop's hull (ship-local, before K): a foremast and a mizzen beside
## the main, stacked square sails, a jib-boom with two jibs, a spanker; a painted band of gunports down each side,
## stern windows and lanterns, quarter galleries, a raised forecastle bulwark and catheads, a figurehead, an ensign.
const FORE_Z := -5.6
const MIZZEN_Z := 8.9
const FIGURE := {"flagship": 9, "warship": 4}


func _dress() -> void:
	var L := HullLayout.base()
	var look: Dictionary = spec["look"]
	var model := get_node("Model")
	var mb := MeshBuilder.new()
	var m := {
		"wood": PSXMat.lit("bark"),
		"rope": PSXMat.lit("rope"),
		"canvas": PSXMat.lit("canvas", look["sail"], {"affine": 0.6}),
		"back": PSXMat.lit("canvas", (look["sail"] as Color).darkened(0.2), {"affine": 0.6}),
		"trim": PSXMat.lit("planks", look["trim"]),
		"hull": PSXMat.lit(str(look.get("hull_tex", "planks_dark")), look["hull"], {"affine": 0.6}),
		"dark": PSXMat.lit("planks_dark", Color(0.12, 0.1, 0.1)),
		"glass": PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5),
		"gilt": PSXMat.lit("planks", Color(1.0, 0.8, 0.35)),
		"flag": PSXMat.lit("cloth_red", look["flag"]),
	}
	var qd := L.qd_y
	# the main's topmast and topsail over the course HullBuilder hangs
	mb.add_cylinder(m["wood"], _xf(Vector3(0, L.mast_top - 1.0, L.mast_z)), 0.18, 0.1, 7.2, 6, 0.8)
	_yard_sail(mb, m, L.mast_z, 21.2, 16.6, 7.2, 6.4)
	# the foremast: a top, course and topsail
	mb.add_cylinder(m["wood"], _xf(Vector3(0, L.deck_y - 0.02, FORE_Z)), 0.27, 0.13, 19.6, 8, 0.8)
	mb.add_cylinder(m["wood"], _xf(Vector3(0, 12.2, FORE_Z)), 1.1, 1.1, 0.14, 10, 1.0, Color.WHITE, true, true)
	_yard_sail(mb, m, FORE_Z, 11.6, 4.6, 7.8, 7.0)
	_yard_sail(mb, m, FORE_Z, 17.8, 12.9, 6.2, 5.6)
	# the mizzen on the quarterdeck: a topsail, a spanker on gaff and boom
	mb.add_cylinder(m["wood"], _xf(Vector3(0, qd - 0.02, MIZZEN_Z)), 0.2, 0.1, 14.6, 6, 0.8)
	_yard_sail(mb, m, MIZZEN_Z, 15.6, 11.9, 4.8, 4.2)
	var b0 := Vector3(0, qd + 1.9, MIZZEN_Z + 0.25)
	var b1 := Vector3(0, qd + 1.9, MIZZEN_Z + 4.8)
	var g1 := Vector3(0, 13.6, MIZZEN_Z + 4.6)
	var g0 := Vector3(0, 11.6, MIZZEN_Z + 0.25)
	Buildings.beam_between(mb, m["wood"], b0, b1, 0.12)
	Buildings.beam_between(mb, m["wood"], g0, g1, 0.1)
	_sheet(mb, m, [b0 + Vector3(0, 0.1, 0.1), g0 + Vector3(0, -0.1, 0.1), g1 + Vector3(0, -0.1, -0.05), b1 + Vector3(0, 0.1, -0.05)])
	# a jib-boom past the bowsprit, two jibs, the stays
	var sdir := Basis(Vector3.RIGHT, deg_to_rad(-70)) * Vector3.UP
	var tip := L.sprit_at + sdir * L.sprit_len
	var jtip := tip + sdir * 4.0
	mb.add_cylinder(m["wood"], Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70)), tip - sdir * 0.6), 0.09, 0.06, 4.6, 5, 0.8)
	_sheet(mb, m, [jtip + Vector3(0, 0.2, 0.3), Vector3(0, 18.4, FORE_Z - 0.4), Vector3(0, 4.4, -10.4)])
	_sheet(mb, m, [tip + Vector3(0, 0.2, 0.3), Vector3(0, 12.0, FORE_Z - 0.4), Vector3(0, 3.0, -8.6)])
	for st in [[Vector3(0, 19.5, FORE_Z), jtip], [Vector3(0, 12.2, FORE_Z), tip], [Vector3(0, 22.6, L.mast_z), Vector3(0, 19.3, FORE_Z)],
			[Vector3(0, 17.0, MIZZEN_Z), Vector3(0, 15.4, L.mast_z)]]:
		mb.add_tube(m["rope"], PackedVector3Array([st[0], st[1]]), 0.035, -1.0, 3, 2.0)
	# shrouds: the fore's and mizzen's from the rail, the main topmast's from the nest; backstays to the stern
	for s in [-1.0, 1.0]:
		for dz in [-0.6, 0.0, 0.6]:
			mb.add_tube(m["rope"], PackedVector3Array([Vector3(s * (L.half_width(FORE_Z + dz) - 0.1), 0.9, FORE_Z + dz), Vector3(s * 0.25, 12.1, FORE_Z)]), 0.035, -1.0, 3, 2.0)
			mb.add_tube(m["rope"], PackedVector3Array([Vector3(s * (L.half_width(MIZZEN_Z - 0.4 + dz * 0.6) - 0.1), qd + 0.5, MIZZEN_Z - 0.4 + dz * 0.6), Vector3(s * 0.2, 12.5, MIZZEN_Z)]), 0.03, -1.0, 3, 2.0)
			mb.add_tube(m["rope"], PackedVector3Array([Vector3(s * 1.45, L.nest_y, L.mast_z + dz), Vector3(s * 0.15, 21.0, L.mast_z)]), 0.03, -1.0, 3, 2.0)
		for k in range(1, 12):
			var y := 0.9 + k * 0.95
			var w := lerpf(L.half_width(FORE_Z) - 0.1, 0.25, (y - 0.9) / 11.2)
			mb.add_tube(m["rope"], PackedVector3Array([Vector3(s * w, y, FORE_Z - 0.6 * (1.0 - (y - 0.9) / 11.2)), Vector3(s * w, y, FORE_Z + 0.6 * (1.0 - (y - 0.9) / 11.2))]), 0.025, -1.0, 3, 2.0)
		mb.add_tube(m["rope"], PackedVector3Array([Vector3(0, 17.0, MIZZEN_Z), Vector3(s * 3.5, qd + 0.8, 9.6)]), 0.03, -1.0, 3, 2.0)
	# pennants at the mastheads, the ensign on its staff over the stern
	_pennant(mb, m["trim"], Vector3(0, 22.7, L.mast_z), 6.0)
	_pennant(mb, m["trim"], Vector3(0, 19.6, FORE_Z), 4.0)
	mb.add_cylinder(m["wood"], _xf(Vector3(0, qd, 10.05)), 0.07, 0.05, 4.4, 5, 1.0)
	for s in [-1.0, 1.0]:
		mb.add_quad(m["flag"], Vector3(0, qd + 4.3, 10.1), Vector3(0, qd + 4.3, 12.3), Vector3(0, qd + 2.9, 12.4), Vector3(0, qd + 2.9, 10.1),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE if s > 0.0 else Color(0.8, 0.8, 0.8), Vector3(s, 0, 0))
	# the painted band with its row of gunports (lids propped up), a gilt moulding under the rail
	for s in [-1.0, 1.0]:
		_band(mb, m["trim"], L, s, -0.8, -0.1, -7.6, 4.8)
		_band(mb, m["gilt"], L, s, 0.12, 0.22, -8.0, 9.8)
		for k in range(9):
			var z := -6.6 + k * 1.35
			var x := L.side_at(z, -0.45) + 0.05
			mb.add_box(m["dark"], Transform3D(Basis(Vector3.BACK, s * 0.12), Vector3(s * x, -0.45, z)), Vector3(0.06, 0.36, 0.42), 1.0)
			Buildings.beam_between(mb, m["trim"], Vector3(s * (x + 0.02), -0.25, z), Vector3(s * (x + 0.36), 0.0, z), 0.42, 0.05)
		# quarter gallery windows on the castle's sides
		for z in [6.3, 8.1]:
			var x := L.half_width(z) + 0.03
			mb.add_box(m["glass"], _xf(Vector3(s * x, 1.55, z)), Vector3(0.06, 0.7, 0.8), 1.0)
			mb.add_box(m["gilt"], _xf(Vector3(s * (x + 0.02), 2.0, z)), Vector3(0.08, 0.1, 1.0), 1.0, Color.WHITE, false)
			mb.add_box(m["gilt"], _xf(Vector3(s * (x + 0.02), 1.1, z)), Vector3(0.08, 0.1, 1.0), 1.0, Color.WHITE, false)
		# stern lanterns on the quarterdeck's corners, catheads at the bow
		var lp := Vector3(s * 3.55, qd + 0.1, 9.6)
		mb.add_box(m["dark"], _xf(lp + Vector3(0, 0.55, 0)), Vector3(0.12, 1.1, 0.12), 1.0)
		mb.add_box(m["glass"], _xf(lp + Vector3(0, 1.35, 0)), Vector3(0.32, 0.5, 0.32), 1.0, Color.WHITE, false)
		mb.add_cone(m["gilt"], _xf(lp + Vector3(0, 1.6, 0)), 0.26, 0.3, 4, 1.0)
		Buildings.beam_between(mb, m["wood"], Vector3(s * 2.6, 1.0, -7.6), Vector3(s * 4.3, 1.25, -8.2), 0.22)
	# the stern: a row of lit windows in gilt frames between gilt rails
	var sz: float = float(L.rings[0][0]) + 0.03
	for x in [-2.7, -0.9, 0.9, 2.7]:
		mb.add_box(m["glass"], _xf(Vector3(x, 1.55, sz)), Vector3(0.9, 0.8, 0.06), 1.0)
		for sx in [-1.0, 1.0]:
			mb.add_box(m["gilt"], _xf(Vector3(x + sx * 0.5, 1.55, sz + 0.03)), Vector3(0.1, 0.95, 0.08), 1.0)
	for y in [0.95, 2.15, qd + 0.05]:
		mb.add_box(m["gilt"], _xf(Vector3(0, y, sz + 0.04)), Vector3(7.8, 0.12, 0.1), 1.0, Color.WHITE, false)
	# the forecastle bulwark rising to the bow, a gilt rail on it
	var fz := [-5.2, -7.0, -8.25, -10.5, -12.4]
	for s in [-1.0, 1.0]:
		for i in range(fz.size() - 1):
			var za: float = fz[i]
			var zb: float = fz[i + 1]
			var ha := 0.25 + float(i) * 0.3
			var hb := 0.25 + float(i + 1) * 0.3
			var ya := float(L.ring_at(za)[3]) + L.lip
			var yb := float(L.ring_at(zb)[3]) + L.lip
			var a := Vector3(s * (L.half_width(za) - 0.04), ya, za)
			var b := Vector3(s * (L.half_width(zb) - 0.04), yb, zb)
			var n := Vector3(s, 0, 0)
			mb.add_quad(m["hull"], a, b, b + Vector3(0, hb, 0), a + Vector3(0, ha, 0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.3), Vector2(0, 0.3), Color.WHITE, n)
			mb.add_quad(m["hull"], a, a + Vector3(0, ha, 0), b + Vector3(0, hb, 0), b, Vector2(0, 0), Vector2(0, 0.3), Vector2(1, 0.3), Vector2(1, 0), Color(0.8, 0.8, 0.8), -n)
			Buildings.beam_between(mb, m["gilt"], a + Vector3(0, ha + 0.04, 0), b + Vector3(0, hb + 0.04, 0), 0.16, 0.1)
			_wall(a, b, ya + maxf(ha, hb) * 0.5, maxf(ha, hb) + 0.1)
	var inst := mb.to_instance("BigRig")
	inst.visibility_range_end = 2000.0
	model.add_child(inst)
	var fig := Figureheads.build(int(FIGURE[kind]))
	fig.name = "Figurehead"
	fig.position = L.figure_at
	fig.scale = Vector3.ONE * L.figure_k
	fig.rotation.x = Figureheads.lean(int(FIGURE[kind]))
	model.add_child(fig)
	# the new masts stand in the way on deck
	for spec_m in [[Vector3(0, L.deck_y, FORE_Z), 0.27, 5.0], [Vector3(0, qd, MIZZEN_Z), 0.2, 4.0]]:
		var c := CylinderShape3D.new()
		c.radius = spec_m[1]
		c.height = spec_m[2]
		var cs := CollisionShape3D.new()
		cs.shape = c
		cs.position = spec_m[0] + Vector3(0, float(spec_m[2]) * 0.5, 0)
		add_child(cs)


static func _xf(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


## A yard across the mast at `top` and a square sail hung from it (bellied aft, both faces), `w0` wide at the head
## and `w1` at the foot.
func _yard_sail(mb: MeshBuilder, m: Dictionary, z: float, top: float, bot: float, w0: float, w1: float) -> void:
	mb.add_cylinder(m["wood"], Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(w0 * 0.5 + 0.3, top, z)), 0.1, 0.1, w0 + 0.6, 6, 0.8)
	var sz := z + 0.25
	var mid := (top + bot) * 0.5
	var h0 := w0 * 0.5
	var h1 := w1 * 0.5
	var hm := (h0 + h1) * 0.5
	var t := top - 0.12
	var sn := Vector3(0, 0, 1)
	mb.add_quad(m["canvas"], Vector3(-h0, t, sz), Vector3(h0, t, sz), Vector3(hm, mid, sz + 0.4), Vector3(-hm, mid, sz + 0.4), Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(0, 1), Color.WHITE, sn)
	mb.add_quad(m["canvas"], Vector3(-hm, mid, sz + 0.4), Vector3(hm, mid, sz + 0.4), Vector3(h1, bot, sz + 0.1), Vector3(-h1, bot, sz + 0.1), Vector2(0, 1), Vector2(2, 1), Vector2(2, 2), Vector2(0, 2), Color.WHITE, sn)
	mb.add_quad(m["back"], Vector3(-h0, t, sz), Vector3(-hm, mid, sz + 0.4), Vector3(hm, mid, sz + 0.4), Vector3(h0, t, sz), Vector2(0, 0), Vector2(0, 1), Vector2(2, 1), Vector2(2, 0), Color.WHITE, -sn)
	mb.add_quad(m["back"], Vector3(-hm, mid, sz + 0.4), Vector3(-h1, bot, sz + 0.1), Vector3(h1, bot, sz + 0.1), Vector3(hm, mid, sz + 0.4), Vector2(0, 1), Vector2(0, 2), Vector2(2, 2), Vector2(2, 1), Color.WHITE, -sn)


## A fore-and-aft sail (a jib or the spanker) in the ship's centre plane through these corners, both faces.
func _sheet(mb: MeshBuilder, m: Dictionary, pts: Array) -> void:
	for s in [1.0, -1.0]:
		var n := Vector3(s, 0, 0)
		var mat: Material = m["canvas"] if s > 0.0 else m["back"]
		var a: Vector3 = pts[0] + n * 0.02
		for i in range(1, pts.size() - 1):
			var b: Vector3 = pts[i] + n * 0.02
			var c: Vector3 = pts[i + 1] + n * 0.02
			if s > 0.0:
				mb.add_tri(mat, a, b, c, n, n, n, Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1), Color.WHITE, n)
			else:
				mb.add_tri(mat, a, c, b, n, n, n, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), Color.WHITE, n)


func _pennant(mb: MeshBuilder, mat: Material, top: Vector3, length: float) -> void:
	for s in [1.0, -1.0]:
		var n := Vector3(s, 0, 0)
		var a := top + n * 0.02
		var b := top + Vector3(0, -0.7, 0) + n * 0.02
		var c := top + Vector3(0, -0.5, length) + n * 0.02
		if s > 0.0:
			mb.add_tri(mat, a, b, c, n, n, n, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0.5), Color.WHITE, n)
		else:
			mb.add_tri(mat, a, c, b, n, n, n, Vector2(0, 0), Vector2(1, 0.5), Vector2(0, 1), Color(0.8, 0.8, 0.8), n)


## A painted band on the hull's side `s` between heights y0 and y1, from z0 to z1 (following the hull).
func _band(mb: MeshBuilder, mat: Material, L: HullLayout, s: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var z := z0
	while z < z1 - 0.01:
		var zn := minf(z + 0.8, z1)
		var p0 := Vector3(s * (L.side_at(z, y0) + 0.03), y0, z)
		var p1 := Vector3(s * (L.side_at(zn, y0) + 0.03), y0, zn)
		var p2 := Vector3(s * (L.side_at(zn, y1) + 0.03), y1, zn)
		var p3 := Vector3(s * (L.side_at(z, y1) + 0.03), y1, z)
		var n := Vector3(s, -0.3, 0).normalized()
		if s > 0.0:
			mb.add_quad(mat, p0, p1, p2, p3, Vector2(z, y0), Vector2(zn, y0), Vector2(zn, y1), Vector2(z, y1), Color.WHITE, n)
		else:
			mb.add_quad(mat, p1, p0, p3, p2, Vector2(zn, y0), Vector2(z, y0), Vector2(z, y1), Vector2(zn, y1), Color.WHITE, n)
		z = zn


## A collision wall along a→b at height y (the forecastle bulwark over the rail).
func _wall(a: Vector3, b: Vector3, y: float, h: float) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, h, a.distance_to(b))
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), Vector3((a.x + b.x) * 0.5, y, (a.z + b.z) * 0.5))
	add_child(cs)


func _place_hull(xf: Transform3D) -> void:
	super._place_hull(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * K), xf.origin))


## Battered under this share of her hull, her rigging's shot through: she loses way (BATTERED_SPEED m/s) and the crew
## can come alongside to board.
const BATTERED_AT := 0.75
const BATTERED_SPEED := 2.5
var _battered := false


func _max_speed() -> float:
	return minf(super._max_speed(), BATTERED_SPEED) if hull < max_hull * BATTERED_AT else super._max_speed()


## A named ship comes for the crew whatever their bounty (the lieutenant was sent for them).
func _wants_crew() -> bool:
	return true


func _turn_grunt(ci: int, tag: String, seed_value: int) -> PirateGrunt:
	var g := super._turn_grunt(ci, tag, seed_value)
	(_crew[ci]["node"] as Node3D).scale = Vector3.ONE
	return g


## A captain on a deck alongside (or swimming by) swings across onto her main deck by the rail on their side.
func _swing_aboard(p: Player, sgn: float) -> void:
	if state == S.SINK or aboard(p.global_position):
		return
	var land := to_global(Vector3(sgn * (HullLayout.base().half_width(-1.0) - 1.2), HullLayout.DECK_Y + 0.3, -1.0))
	FX.sfx("whoosh", p.global_position, -4.0, 0.05, 0.9)
	Net.fx("tracer", [p.global_position + Vector3(0, 1.4, 0), land + Vector3(0, 1.0, 0), Color(0.75, 0.6, 0.4)])
	p.global_position = land
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if net_puppet or state == S.SINK:
		return
	if not _battered and hull < max_hull * BATTERED_AT:
		_battered = true
		bark("Her rigging's shot through! Stand by to repel boarders!" if kind == "flagship" else "We've lost the mainyard! All hands, prepare to be boarded!", 3.0)
	if state == S.DECK and duel == "":
		_deck_t += delta
		var up := deck_crew.filter(func(g): return is_instance_valid(g) and not g.is_dead()).size()
		if up <= CAPTAIN_AT or _deck_t > CAPTAIN_AFTER:
			_captain_out()
	if _yield_t >= 0.0:
		_yield_t += delta
		if _yield_t > 2.5:
			_yield_t = -1.0
			if is_instance_valid(captain):
				Net.everyone("_all_rival_gone", [Net.key_of(captain)])
			_strike()


## (host) Her captain on the quarterdeck, the intro on every screen, then the duel.
func _captain_out() -> void:
	duel = "out"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([look_seed, "captain_look"])
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["name"] = captain_name
	if kind == "warship":
		EnemyShip.marine_look(lk, rng, true)
		lk["name"] = captain_name
		lk["coat_color"] = Color(0.92, 0.93, 0.96)
		lk["trim_color"] = Color(0.85, 0.7, 0.3)
	else:
		lk["coat"] = "greatcoat"
		lk["coat_color"] = Color(0.4, 0.06, 0.08)
		lk["trim_color"] = Color(0.9, 0.72, 0.25)
		lk["hat"] = "tricorn"
		lk["hat_color"] = Color(0.1, 0.08, 0.08)
	lk["height"] = 1.12
	var weapons: Array = WEAPONS[kind]
	var w := str(weapons[rng.randi() % weapons.size()])
	var at := to_global(Vector3(0.0, HullLayout.base().qd_y + 0.2, HullLayout.base().helm_z - 1.2))
	var rname := "Captain_%s" % name
	var parent := get_parent()
	Net.everyone("_all_spawn_rival", [Net.key_of(parent), rname, lk, w, at, global_rotation.y, 0.85 if kind == "warship" else 0.75])
	captain = parent.get_node_or_null(rname) as Player
	if captain == null:
		duel = "beaten"
		return
	captain.hp_k = CAPTAIN_HP + level * 0.05
	captain.poise = Poise.make("elite")
	captain.call("_recalc_stats")
	captain.health_component.current_health = captain.health_component.max_health
	captain.defeated.connect(_on_captain_beaten)
	var b = captain.get_node("Brain")
	b.order = "hold"
	b.pace = 1.2
	var line: String = LINES[kind][rng.randi() % LINES[kind].size()]
	var you = get_tree().get_first_node_in_group("player")
	Net.everyone("_all_cutscene", ["sea_captain", [Net.key_of(captain), captain_name, line, Net.key_of(you), ship_name]])
	var c := Cutscene.active
	if c:
		c.finished.connect(func(_skipped): _start_duel())
	else:
		_start_duel()


func _start_duel() -> void:
	if duel != "out" or not is_instance_valid(captain):
		return
	duel = "duel"
	var b = captain.get_node("Brain")
	b.order = "fight"
	var best: Node3D = null
	for p in Net.all_players():
		if best == null or (p as Node3D).global_position.distance_to(captain.global_position) < best.global_position.distance_to(captain.global_position):
			best = p
	b.target = best


func _on_captain_beaten() -> void:
	if duel == "beaten":
		return
	duel = "beaten"
	captain.get_node("Brain").order = "hold"
	bark(YIELD[kind], 3.0)
	_yield_t = 0.0


## The cutscene's shots: her captain from the boarders' side, then close as they speak.
## args: [captain key, name, line, your key, ship name]
static func intro_shots(tree: SceneTree, args: Array) -> Array:
	var net := tree.root.get_node("Net")
	var cap := net.node_of(str(args[0])) as Player
	var you := net.node_of(str(args[3])) as Player
	if cap == null or you == null:
		return []
	return [
		{"secs": 2.0, "cam": [you.player_model, cap], "off": Vector3(1.0, 2.2, -3.6), "fov": 55.0, "to": [you.player_model, cap]},
		{"secs": 1.6, "cam": [cap.player_model, cap], "off": Vector3(-2.5, 2.6, 6.0), "fov": 50.0,
			"say": {"who": cap, "name": str(args[1]), "text": "Captain of %s." % str(args[4]), "pitch": 0.8}},
		{"cam": [cap.player_model, cap], "off": Vector3(0.8, 1.7, 2.8), "fov": 45.0,
			"say": {"who": cap, "name": str(args[1]), "text": str(args[2]), "pitch": 0.8}},
	]


## Taken: her colours come down only once her captain's beaten too.
func _strike() -> void:
	if state == S.PRIZE or duel != "beaten" or _yield_t >= 0.0:
		return
	_set_state(S.PRIZE)
	_empty_t = 0.0
	Net.award_xp(_xp(500), global_position, 200.0)
	Net.bounty(_bounty_kind(), global_position, 200.0, BOUNTY_K)
	Net.event(self, "prize", [])
	_prize()


func _prize() -> void:
	state = S.PRIZE
	if _jolly:
		_jolly.visible = false
	get_tree().call_group("hud", "show_banner", "%s is taken!" % ship_name, "%s yields. The captain's chest is yours." % captain_name, false)
	FX.sfx("bell", global_position, 0.0, 0.02, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "bigprize")
	var tier := mini(Levels.tier(level) + 1, 4)
	var picks := [["gold", roundi(rng.randi_range(160, 260) * Levels.coins_k(level))], ["treasure", rng.randi_range(4, 7)], ["rum", 2],
		["%s@%d" % [WeaponDesigns.random_item(rng), tier], 1], [Gear.random_piece(rng, tier).id, 1]]
	var bps := Gadgets.blueprint_ids()
	picks.append([bps[rng.randi() % bps.size()], 1])
	var parts := Gadgets.part_ids()
	for i in range(3):
		picks.append([parts[rng.randi() % parts.size()], rng.randi_range(1, 3)])
	picks.append_array(Salvage.roll(rng, 4, 0.8))
	var items: Array[ItemStack] = []
	for e in picks:
		var stk := ItemStack.new()
		stk.item = ItemDB.get_item(str(e[0]))
		stk.quantity = int(e[1])
		items.append(stk)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	bag.setup(items, false)
	bag.rolls = true
	bag.name = "Prize_%s" % name
	get_node("Model").add_child(bag)
	bag.position = Vector3(1.6, HullLayout.base().qd_y, 7.4)
	bag.scale = Vector3.ONE / K


## Sunk from afar: her hoard goes down with her; a little flotsam and salvage.
func _drop_chest() -> void:
	var root := get_tree().current_scene
	Salvage.scatter(root, Vector3(_pos.x, 0.0, _pos.z), "frigate", hash(name + "salvage"))
