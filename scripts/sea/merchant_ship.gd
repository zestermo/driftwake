class_name MerchantShip
extends SeaVessel
## The wandering merchant (docs/v1_28_plan.md, The sea): a big friendly three-master under sail on a sea leg. She
## sails a slow round about her stretch of sea; when the crew's ship comes near she heaves to and hails them, and
## waits while anyone's aboard or close. Climb her ladders or jump across from alongside: her factor trades from an
## awning amidships (rare gear, a fine weapon, gadget blueprints and parts, exotic ingredients, books once there are
## any), the stock rolled for this visit from the leg's seed (the same on every screen; Shops.extra).

const Shops := preload("res://scripts/game/shops.gd")

const CRUISE := 3.5
const ROUND_R := 90.0
## She heaves to for a crew ship this close, or a captain this close (swimming over).
const HAIL_R := 130.0
const SWIM_R := 60.0
## And sails on once nobody's been near for this long.
const WAIT := 30.0
const EXOTIC := ["pepper", "sea_urchin", "oyster", "coconut", "salt"]
const NAMES := ["Odalric Vane", "Mother Pell", "Saffi Orlo", "Quentin Brask", "Ilse Maren", "Tobiah Crane"]
const SHIPS := ["the Gilded Pelican", "the Patient Gull", "the Lantern Wife", "the Saltpenny", "the Far Errand"]
const LINES := [
	"Silk from the far side of the chain, steel from the near. Coin from you, I hope.",
	"Everything aboard came a long way to meet you. Don't let it go home again.",
	"Blueprints, brass and a few things I won't say where I got.",
]
## (books come later: an agent fills this with book item ids and the merchant shows BOOKS_SHOWN of them)
static var book_pool: Array = []
const BOOKS_SHOWN := 2
## The deck's market: the factor under the awning (ship-local).
const FACTOR_AT := Vector3(0.0, HullLayout.DECK_Y, -4.2)

enum M { SAIL, HOVE }
var mode: M = M.SAIL
var level := 1
var seed_value := 1
var anchor := Vector3.ZERO
var shop_id := ""
var factor: NPC
var _a := 0.0
var _quiet := 0.0
var _hailed := false
var _bark: Label3D
var _bark_t := 0.0


func setup(at: Vector3, lvl: int, seed_: int) -> MerchantShip:
	anchor = Vector3(at.x, 0.0, at.z)
	level = lvl
	seed_value = seed_
	_a = float(seed_ % 628) * 0.01
	return self


func _build() -> void:
	half_len = HullLayout.STERN_Z
	bounds = AABB(Vector3(-4.9, -1.4, -16.5), Vector3(9.8, 21.0, 27.2))
	TraderShips.merchantman(self)
	(get_node("PSXModel") as GeometryInstance3D).visibility_range_end = 1600.0
	_dress()
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = HullLayout.base().ladder_len
		lad.rail = 0.8
		lad.deck_depth = 0.9
		lad.position = Vector3(sgn * (HullLayout.base().half_width(HullLayout.base().ladder_z) + 0.02), HullLayout.DECK_Y, HullLayout.base().ladder_z)
		lad.rotation.y = sgn * PI * 0.5
		add_child(lad)
	_open_shop()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var who := str(NAMES[rng.randi() % NAMES.size()])
	factor = NPC.new()
	factor.setup({"name": who, "shop": shop_id, "look": _look(rng, true), "voice": rng.randf_range(0.85, 1.15),
		"yaw": PI, "barks": LINES})
	factor.humanoid.far_figure = false
	add_child(factor)
	factor.position = FACTOR_AT
	for i in range(2):
		var hand := NPC.new()
		hand.setup({"name": "Deckhand", "look": _look(rng, false), "scenery": true, "yaw": rng.randf() * TAU,
			"barks": ["Mind the crates.", "Fair winds."]})
		hand.humanoid.far_figure = false
		add_child(hand)
		hand.position = Vector3([-1.6, 2.2][i], HullLayout.DECK_Y, [2.2, -8.6][i])
	_bark = Label3D.new()
	_bark.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_bark.font_size = 40
	_bark.pixel_size = 0.012
	_bark.outline_size = 10
	_bark.modulate = Color(0.85, 0.95, 1.0)
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bark.no_depth_test = true
	_bark.position = Vector3(0, 6.0, -4.0)
	_bark.visible = false
	add_child(_bark)


func _look(rng: RandomNumberGenerator, rich: bool) -> Dictionary:
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["name"] = "Merchant"
	if rich:
		lk["coat"] = "longcoat"
		lk["coat_color"] = Color(0.14, 0.3, 0.32)
		lk["trim_color"] = Color(0.9, 0.75, 0.3)
		lk["hat"] = "tricorn"
		lk["hat_color"] = Color(0.12, 0.1, 0.1)
	return lk


## The deck's cargo, by kind: [x, z, yaw] (ship-local, on the main deck clear of the masts, ladders and the lane aft).
const CRATES := [[3.0, -6.6, 0.3], [-3.0, 0.4, 0.1], [-1.2, -9.9, -0.2]]
const BARRELS := [[-3.0, -6.0], [2.9, 0.0]]
const BALES := [[-2.0, -8.0, -0.3], [-3.3, -4.4, 0.0]]


## Market dressing on the main deck: a covered stall under a striped awning (its counter laid with goods on show, a
## rack of blades behind the factor), and the cargo: crate stacks, roped bales, barrels, sacks of spice.
func _dress() -> void:
	var m := {
		"a": PSXMat.lit("canvas", Color(0.85, 0.32, 0.18)),
		"b": PSXMat.lit("canvas", Color(0.96, 0.9, 0.76)),
		"teal": PSXMat.lit("canvas", Color(0.25, 0.55, 0.6)),
		"pole": PSXMat.lit("bark"),
		"crate": PSXMat.lit("planks", Color(0.82, 0.66, 0.44)),
		"bale": PSXMat.lit("canvas", Color(0.78, 0.7, 0.52)),
		"dark": PSXMat.lit("planks_dark", Color(0.45, 0.32, 0.24)),
		"rope": PSXMat.lit("rope"),
		"metal": PSXMat.lit("metal", Color(0.85, 0.87, 0.9)),
		"gilt": PSXMat.lit("planks", Color(1.0, 0.8, 0.35)),
		"glow": PSXMat.glow(Color(1.0, 0.78, 0.42), 2.0),
	}
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "cargo"])
	_stall(mb, m, rng)
	var y := HullLayout.DECK_Y
	for c in CRATES:
		var xf := Transform3D(Basis(Vector3.UP, float(c[2])), Vector3(float(c[0]), y, float(c[1])))
		_crate(mb, m, xf * _xf(Vector3(-0.38, 0.4, 0)), 0.8)
		_crate(mb, m, xf * _xf(Vector3(0.42, 0.35, 0.05)), 0.7)
		_crate(mb, m, xf * Transform3D(Basis(Vector3.UP, 0.25), Vector3(0.0, 1.1, 0)), 0.6)
	for b in BARRELS:
		for k in range(3):
			var p: Vector3 = Vector3(float(b[0]), y, float(b[1])) + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.42
			mb.add_cylinder(m["dark"], _xf(p), 0.27, 0.27, 0.8, 8, 1.0, Color(1.3, 1.2, 1.1))
			for hy in [0.14, 0.64]:
				mb.add_cylinder(m["metal"], _xf(p + Vector3(0, hy, 0)), 0.285, 0.285, 0.05, 8, 1.0, Color(0.4, 0.4, 0.42))
		var lie := Vector3(float(b[0]), y + 0.27, float(b[1]) + 0.95)
		mb.add_cylinder(m["dark"], Transform3D(Basis(Vector3.BACK, PI * 0.5), lie + Vector3(0.4, 0, 0)), 0.27, 0.27, 0.8, 8, 1.0, Color(1.3, 1.2, 1.1), true, true)
	for b in BALES:
		var xf := Transform3D(Basis(Vector3.UP, float(b[2])), Vector3(float(b[0]), y, float(b[1])))
		for k in range(3):
			var at := xf * Vector3([-0.33, 0.33, 0.0][k], [0.25, 0.25, 0.72][k], 0)
			var bx := Transform3D(xf.basis * Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), at)
			mb.add_box(m["bale"], bx, Vector3(0.62, 0.5, 0.85), 1.0, Color.WHITE, false)
			for dz in [-0.22, 0.22]:
				mb.add_box(m["rope"], bx * _xf(Vector3(0, 0, dz)), Vector3(0.65, 0.53, 0.05), 2.0, Color.WHITE, false)
		for k in range(3):
			var sp := xf * Vector3(0.9 + k * 0.1, 0, -0.5 + k * 0.5)
			mb.add_blob(m["bale"], _xf(sp + Vector3(0, 0.28, 0)), Vector3(0.25, 0.3, 0.22), rng, 0.12, 3, 6, 1.0, Color(0.9, 0.85, 0.7), 0.0)
			mb.add_blob([m["a"], m["gilt"], m["teal"]][k], _xf(sp + Vector3(0, 0.56, 0)), Vector3(0.17, 0.05, 0.15), rng, 0.1, 2, 6, 1.0)
	var inst := mb.to_instance("Cargo")
	inst.visibility_range_end = 260.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	_cargo_collide()


static func _xf(p: Vector3) -> Transform3D:
	return Transform3D(Basis(), p)


func _crate(mb: MeshBuilder, m: Dictionary, xf: Transform3D, s: float) -> void:
	mb.add_box(m["crate"], xf, Vector3.ONE * s, 1.3, Color.WHITE, false)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			mb.add_box(m["dark"], xf * _xf(Vector3(x * s * 0.47, 0, z * s * 0.47)), Vector3(0.07, s + 0.02, 0.07), 1.0)
	mb.add_box(m["dark"], xf * _xf(Vector3(0, 0, s * 0.5 + 0.01)), Vector3(s * 0.9, 0.07, 0.03), 1.0)


## The factor's stall: four turned posts, a striped awning pitched to a ridge with scalloped valances, a counter in
## front draped in cloth and laid with goods (bolts of cloth, a blade, an open chest of coin, scrolls, a spyglass),
## a rack of blades and a shelf behind, a lantern under the ridge.
func _stall(mb: MeshBuilder, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var y := HullLayout.DECK_Y
	var z0 := FACTOR_AT.z
	var hw := 2.2
	var hd := 1.6
	for x in [-hw, hw]:
		for dz in [-hd, hd]:
			var p := Vector3(x, y, z0 + dz)
			mb.add_cylinder(m["gilt"], _xf(p), 0.08, 0.07, 2.55, 6, 1.0, Color(0.7, 0.55, 0.45))
			mb.add_cylinder(m["dark"], _xf(p), 0.12, 0.12, 0.15, 6, 1.0)
	for dz in [-hd, hd]:
		mb.add_box(m["dark"], _xf(Vector3(0, y + 2.55, z0 + dz)), Vector3(hw * 2.0 + 0.2, 0.12, 0.12), 1.0, Color.WHITE, false)
	for x in [-hw, hw]:
		mb.add_box(m["dark"], _xf(Vector3(x, y + 2.55, z0)), Vector3(0.12, 0.12, hd * 2.0 + 0.2), 1.0, Color.WHITE, false)
	var ridge := y + 3.2
	var eave := y + 2.5
	var n := 6
	var sw := (hw * 2.0 + 0.4) / n
	for i in range(n):
		var x := -hw - 0.2 + i * sw
		var mat: Material = m["a"] if i % 2 == 0 else m["b"]
		for s in [-1.0, 1.0]:
			var e: float = z0 + s * (hd + 0.35)
			var a := Vector3(x, ridge, z0)
			var b := Vector3(x + sw, ridge, z0)
			var c := Vector3(x + sw, eave, e)
			var d := Vector3(x, eave, e)
			var nn := Vector3(0, hd + 0.35, s * (ridge - eave)).normalized()
			mb.add_quad(mat, a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, nn)
			mb.add_quad(mat, d, c, b, a, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.75, 0.75, 0.75), -nn)
			for half in [0.0, 0.5]:
				var p := Vector3(x + half * sw, eave, e)
				var q := Vector3(x + (half + 0.5) * sw, eave, e)
				var tip := Vector3(x + (half + 0.25) * sw, eave - 0.28, e)
				var fn := Vector3(0, 0, s)
				mb.add_tri(mat, p, tip, q, fn, fn, fn, Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0), Color.WHITE, fn)
				mb.add_tri(mat, p, q, tip, -fn, -fn, -fn, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), Color(0.8, 0.8, 0.8), -fn)
	mb.add_box(m["dark"], _xf(Vector3(0, ridge, z0)), Vector3(hw * 2.0 + 0.5, 0.1, 0.1), 1.0, Color.WHITE, false)
	mb.add_tube(m["rope"], PackedVector3Array([Vector3(0, ridge, z0), Vector3(0, ridge - 0.5, z0)]), 0.015, -1.0, 3, 1.0)
	mb.add_box(m["dark"], _xf(Vector3(0, ridge - 0.52, z0)), Vector3(0.22, 0.05, 0.22), 1.0, Color.WHITE, false)
	mb.add_box(m["glow"], _xf(Vector3(0, ridge - 0.7, z0)), Vector3(0.15, 0.28, 0.15), 1.0, Color.WHITE, false)
	# the counter: a plank top on trestles, a cloth draped down its front
	var cz := z0 + 1.0
	mb.add_box(m["crate"], _xf(Vector3(0, y + 0.95, cz)), Vector3(3.6, 0.08, 0.75), 1.2, Color(1.1, 1.0, 0.9), false)
	for x in [-1.5, 1.5]:
		mb.add_box(m["dark"], _xf(Vector3(x, y + 0.45, cz)), Vector3(0.1, 0.9, 0.65), 1.0)
	mb.add_box(m["teal"], _xf(Vector3(0, y + 0.62, cz + 0.39)), Vector3(3.5, 0.62, 0.03), 1.2)
	mb.add_box(m["gilt"], _xf(Vector3(0, y + 0.93, cz + 0.4)), Vector3(3.6, 0.06, 0.04), 1.0, Color.WHITE, false)
	var top := y + 0.99
	for k in range(3):
		mb.add_cylinder([m["a"], m["b"], m["teal"]][k], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.5 + k * 0.24, top + 0.1, cz - 0.3)), 0.1, 0.1, 0.6, 7, 1.0, Color.WHITE, true, true)
	mb.add_box(m["metal"], Transform3D(Basis(Vector3.UP, 0.25), Vector3(-0.35, top + 0.02, cz + 0.05)), Vector3(0.06, 0.02, 0.95), 1.0, Color(1.2, 1.2, 1.2))
	mb.add_box(m["gilt"], Transform3D(Basis(Vector3.UP, 0.25), Vector3(-0.47, top + 0.03, cz + 0.5)), Vector3(0.25, 0.04, 0.05), 1.0)
	mb.add_box(m["dark"], _xf(Vector3(0.65, top + 0.15, cz)), Vector3(0.6, 0.3, 0.4), 1.0)
	mb.add_box(m["dark"], Transform3D(Basis(Vector3.RIGHT, -1.1), Vector3(0.65, top + 0.42, cz - 0.28)), Vector3(0.6, 0.05, 0.4), 1.0)
	for k in range(9):
		mb.add_blob(m["gilt"], _xf(Vector3(0.65 + rng.randf_range(-0.22, 0.22), top + 0.3, cz + rng.randf_range(-0.14, 0.14))), Vector3(0.06, 0.03, 0.06), rng, 0.1, 2, 5, 1.0, Color(1.3, 1.15, 0.8))
	for k in range(3):
		mb.add_cylinder(m["b"], Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(1.55, top + 0.05 + k * 0.09, cz - 0.15 + k * 0.08)), 0.045, 0.045, 0.5, 6, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(m["gilt"], Transform3D(Basis(Vector3.BACK, PI * 0.5 - 0.1), Vector3(1.35, top + 0.06, cz + 0.22)), 0.045, 0.03, 0.55, 6, 1.0, Color.WHITE, true, true)
	# behind the factor: a rack of blades and a shelf of jars and boxes
	var rz := z0 - 1.25
	for x in [-1.6, -0.4]:
		mb.add_box(m["dark"], _xf(Vector3(x, y + 0.8, rz)), Vector3(0.08, 1.6, 0.08), 1.0)
	mb.add_box(m["dark"], _xf(Vector3(-1.0, y + 1.5, rz)), Vector3(1.4, 0.07, 0.1), 1.0, Color.WHITE, false)
	for k in range(4):
		var x := -1.5 + k * 0.33
		mb.add_box(m["metal"], _xf(Vector3(x, y + 0.85, rz + 0.06)), Vector3(0.05, 1.1, 0.02), 1.0, Color(1.15, 1.15, 1.2))
		mb.add_box(m["gilt"], _xf(Vector3(x, y + 1.42, rz + 0.06)), Vector3(0.2, 0.04, 0.05), 1.0)
		mb.add_box(m["dark"], _xf(Vector3(x, y + 1.6, rz + 0.06)), Vector3(0.04, 0.22, 0.04), 1.0)
	for sy in [0.7, 1.3]:
		mb.add_box(m["crate"], _xf(Vector3(1.0, y + sy, rz)), Vector3(1.5, 0.05, 0.35), 1.0, Color(0.9, 0.85, 0.8), false)
		for k in range(5):
			var x := 0.4 + k * 0.3
			if rng.randf() < 0.5:
				mb.add_cylinder(m["b"], _xf(Vector3(x, y + sy + 0.03, rz)), 0.07, 0.06, rng.randf_range(0.15, 0.28), 6, 1.0, [Color(0.85, 0.55, 0.38), Color(1, 1, 0.95), Color(0.5, 0.7, 0.8)][k % 3], true)
			else:
				mb.add_box(m["dark"], _xf(Vector3(x, y + sy + 0.1, rz)), Vector3(0.2, 0.15, 0.2), 1.0, Color(1.3, 1.1, 0.9))
	for x in [0.22, 1.78]:
		mb.add_box(m["dark"], _xf(Vector3(x, y + 0.68, rz)), Vector3(0.06, 1.36, 0.3), 1.0)


## The cargo's colliders (it's in the way on deck): a box over each stack, the stall's counter and posts.
func _cargo_collide() -> void:
	var y := HullLayout.DECK_Y
	for c in CRATES:
		_col_box(Transform3D(Basis(Vector3.UP, float(c[2])), Vector3(float(c[0]), y + 0.7, float(c[1]))), Vector3(1.7, 1.4, 0.85))
	for b in BARRELS:
		_col_box(_xf(Vector3(float(b[0]), y + 0.4, float(b[1]) + 0.35)), Vector3(1.4, 0.8, 1.9))
	for b in BALES:
		_col_box(Transform3D(Basis(Vector3.UP, float(b[2])), Vector3(float(b[0]) + 0.2, y + 0.5, float(b[1]))), Vector3(1.9, 1.0, 1.2))
	_col_box(_xf(Vector3(0, y + 0.5, FACTOR_AT.z + 1.0)), Vector3(3.6, 1.0, 0.75))
	for x in [-2.2, 2.2]:
		for dz in [-1.6, 1.6]:
			_col_box(_xf(Vector3(x, y + 1.25, FACTOR_AT.z + dz)), Vector3(0.18, 2.5, 0.18))


func _col_box(xf: Transform3D, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	var cs := CollisionShape3D.new()
	cs.shape = b
	cs.transform = xf
	add_child(cs)


## This visit's stock in Shops.extra (seeded by the leg: the same on every screen, a new roll each leg).
func _open_shop() -> void:
	shop_id = "merchant_%d" % seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "stock"])
	var tier := mini(Levels.tier(level) + 1, 4)
	var out: Array = []
	var kind: String = Shops.RARE_KINDS[rng.randi() % Shops.RARE_KINDS.size()]
	out.append([ItemDB.tiered(WeaponDesigns.pick_id(kind, rng), tier).id + "+" + WeaponTraits.roll(kind, rng)])
	var gear: Array = Shops.RARE_GEAR.duplicate()
	for i in range(2):
		var g: Array = gear.pop_at(rng.randi() % gear.size())
		out.append([g[0], g[1], g[2], tier])
	var bps := Gadgets.blueprint_ids()
	for i in range(2):
		out.append([bps.pop_at(rng.randi() % bps.size())])
	var parts := Gadgets.part_ids()
	for i in range(3):
		out.append([parts.pop_at(rng.randi() % parts.size())])
	var exotic: Array = EXOTIC.duplicate()
	for i in range(2):
		out.append([exotic.pop_at(rng.randi() % exotic.size())])
	var books: Array = book_pool.duplicate()
	for i in range(mini(BOOKS_SHOWN, books.size())):
		out.append([books.pop_at(rng.randi() % books.size())])
	Shops.extra[shop_id] = {"name": "Merchant's Hold", "line": str(LINES[rng.randi() % LINES.size()]), "trade": "merchant",
		"stock": out, "buys": {"loot": 0.9, "gear": 0.5, "weapon": 0.5, "ingredient": 0.6}}


func _exit_tree() -> void:
	Shops.extra.erase(shop_id)


func _brain(delta: float) -> Array:
	var near := _crew_near()
	match mode:
		M.SAIL:
			var wp := anchor + Vector3(cos(_a), 0.0, sin(_a)) * ROUND_R
			var to := wp - _pos
			to.y = 0.0
			if to.length() < 25.0:
				_a += 0.7
			if near:
				mode = M.HOVE
				_quiet = 0.0
				if not _hailed:
					_hailed = true
					say("Ahoy! %s, fair trade aboard - come alongside!" % str(SHIPS[seed_value % SHIPS.size()]).capitalize(), 4.0)
					Net.fx("sfx", ["bell", global_position, 0.0, 0.02, 1.3])
			return [atan2(-to.x, -to.z), CRUISE]
		_:
			_quiet = 0.0 if near or anyone_aboard() else _quiet + delta
			if _quiet > WAIT:
				mode = M.SAIL
				_hailed = false
	return [_heading, 0.0]


func _crew_near() -> bool:
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship and _flat(ship.global_position) < HAIL_R:
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(ship.global_position) < 40.0:
				return true
	for p in Net.all_players():
		if _flat((p as Node3D).global_position) < SWIM_R:
			return true
	return false


## (from _pos: a freshly placed hull's node still reads where it was until its next physics step)
func _flat(p: Vector3) -> float:
	return Vector2(p.x - _pos.x, p.z - _pos.z).length()


func say(text: String, secs: float = 2.5) -> void:
	_bark.text = text
	_bark.visible = true
	_bark_t = secs


func _process(delta: float) -> void:
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false


func net_extra() -> Array:
	return [int(mode), _bark.text if _bark.visible else ""]


func net_apply(e: Array) -> void:
	mode = int(e[0]) as M
	var txt := str(e[1])
	if txt != "" and (txt != _bark.text or not _bark.visible):
		say(txt, 1.0)
