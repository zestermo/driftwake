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
const FACTOR_AT := Vector3(0.0, HullBuilder.DECK_Y, -4.2)

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
	half_len = HullBuilder.STERN_Z
	bounds = AABB(Vector3(-4.9, -1.4, -16.5), Vector3(9.8, 21.0, 27.2))
	TraderShips.merchantman(self)
	(get_node("PSXModel") as GeometryInstance3D).visibility_range_end = 1600.0
	_dress()
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = HullBuilder.LADDER_LEN
		lad.rail = 0.8
		lad.deck_depth = 0.9
		lad.position = Vector3(sgn * (HullBuilder.half_width(HullBuilder.LADDER_Z) + 0.02), HullBuilder.DECK_Y, HullBuilder.LADDER_Z)
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
		hand.position = Vector3([-2.4, 2.2][i], HullBuilder.DECK_Y, [1.2, -8.6][i])
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


## Market dressing on the main deck: a striped awning over the factor, bales, crates and barrels of cargo.
func _dress() -> void:
	var mb := MeshBuilder.new()
	var cloth_a := PSXMat.lit("canvas", Color(0.85, 0.32, 0.18))
	var cloth_b := PSXMat.lit("canvas", Color(0.96, 0.9, 0.76))
	var pole := PSXMat.lit("bark")
	var crate := PSXMat.lit("planks", Color(0.82, 0.66, 0.44))
	var bale := PSXMat.lit("canvas", Color(0.78, 0.7, 0.52))
	var y := HullBuilder.DECK_Y
	var z0 := FACTOR_AT.z
	for x in [-2.2, 2.2]:
		for dz in [-1.6, 1.6]:
			mb.add_cylinder(pole, Transform3D(Basis(), Vector3(x, y, z0 + dz)), 0.06, 0.06, 2.6, 5, 1.0)
	for i in range(6):
		var x := -2.4 + i * 0.8
		mb.add_box(cloth_a if i % 2 == 0 else cloth_b, Transform3D(Basis(Vector3.BACK, 0.0), Vector3(x + 0.4, y + 2.65, z0)), Vector3(0.8, 0.05, 3.6), 1.0)
	mb.add_box(crate, Transform3D(Basis(), Vector3(0.0, y + 0.45, z0 + 1.0)), Vector3(2.4, 0.9, 0.6), 1.0)
	var spots := [[2.6, -7.0, 0.3], [-2.7, -6.4, -0.2], [2.9, 1.8, 0.5], [-2.9, 2.6, 0.1], [2.2, -9.6, 0.0]]
	for s in spots:
		mb.add_box(crate, Transform3D(Basis(Vector3.UP, float(s[2])), Vector3(float(s[0]), y + 0.35, float(s[1]))), Vector3(0.7, 0.7, 0.7), 1.0)
		mb.add_box(bale, Transform3D(Basis(Vector3.UP, float(s[2]) + 0.4), Vector3(float(s[0]) * 0.85, y + 0.95, float(s[1]) + 0.1)), Vector3(0.6, 0.45, 0.8), 1.0)
	for k in range(3):
		mb.add_cylinder(crate, Transform3D(Basis(), Vector3(-1.6 + k * 0.6, y, 3.3)), 0.28, 0.28, 0.8, 7, 1.0)
	var inst := mb.to_instance("Cargo")
	inst.visibility_range_end = 260.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


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
