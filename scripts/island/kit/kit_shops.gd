class_name KitShops
extends RefCounted
## (1.25.5, docs/v1_26_plan.md "Shops and vendors", "Unique places") Rooms dressed for a trade or a place: KitHouses.room
## builds the shell and hands its inside here for any kind it doesn't dress itself. The village traders' shops (the
## VillageVendors trades: smith, armourer, tailor, luthier, apothecary) and the unique places (UniquePlaces: library,
## onsen, restaurant, swordsmith, sea_shrine, cartographer, dojo, curio). Markers: Vendor (where the keeper stands,
## facing the door) and Customer. Room space: front +Z, the floor at `fl`.

const KINDS := ["smith", "armourer", "tailor", "luthier", "apothecary", "library", "onsen", "restaurant", "swordsmith",
	"sea_shrine", "cartographer", "dojo", "curio"]

const CLOTHS := [Color(0.66, 0.14, 0.12), Color(0.2, 0.32, 0.62), Color(0.8, 0.62, 0.2), Color(0.16, 0.42, 0.44), Color(0.45, 0.25, 0.5)]


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## The room's inside for `kind` (into mb; colliders on body). `h` the wall height.
static func inside(kind: String, body: Node3D, mb: MeshBuilder, w: float, d: float, fl: float, h: float, rng: RandomNumberGenerator) -> void:
	var r := {"x0": -w * 0.5 + KitHouses.WALL_T, "x1": w * 0.5 - KitHouses.WALL_T, "z0": -d * 0.5 + KitHouses.WALL_T,
		"z1": d * 0.5 - KitHouses.WALL_T, "fl": fl, "w": w, "d": d, "h": h}
	match kind:
		"onsen":
			_onsen(body, mb, r, rng)
		"dojo":
			_dojo(body, mb, r, rng)
		"restaurant":
			_restaurant(body, mb, r, rng)
		"sea_shrine":
			_sea_shrine(body, mb, r, rng)
		"library":
			_library(body, mb, r, rng)
		"cartographer":
			_cartographer(body, mb, r, rng)
		_:
			var cz := _counter(body, mb, r, kind == "apothecary" or kind == "curio")
			match kind:
				"smith", "swordsmith":
					_forge(body, mb, r, cz, rng, kind == "swordsmith")
				"armourer":
					_armoury(body, mb, r, cz, rng)
				"tailor":
					_tailor(body, mb, r, cz, rng)
				"luthier":
					_luthier(body, mb, r, cz, rng)
				_:
					_shelves(body, mb, r, cz, rng, kind == "curio")


## The counter across the back of the room, the keeper behind it; returns its z.
static func _counter(body: Node3D, mb: MeshBuilder, r: Dictionary, cloth: bool) -> float:
	var fl: float = r["fl"]
	var cz: float = float(r["z0"]) + 1.45
	var cx0: float = float(r["x0"]) + 0.3
	var cx1: float = float(r["x1"]) - 1.0
	var cw := cx1 - cx0
	mb.add_box(PSXMat.lit("planks"), _xf(Vector3((cx0 + cx1) * 0.5, fl + 0.5, cz)), Vector3(cw, 1.0, 0.56), 1.0)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3((cx0 + cx1) * 0.5, fl + 1.04, cz)), Vector3(cw + 0.1, 0.08, 0.72), 1.0, Color.WHITE, false)
	if cloth:
		mb.add_box(PSXMat.lit("fabric", Color(0.5, 0.2, 0.25)), _xf(Vector3((cx0 + cx1) * 0.5, fl + 0.85, cz + 0.29)), Vector3(cw * 0.8, 0.3, 0.02), 1.0)
	KitHouses._box(body, Vector3(cw, 1.08, 0.6), Vector3((cx0 + cx1) * 0.5, fl + 0.54, cz))
	KitHouses._marker(body, "Vendor", Vector3((cx0 + cx1) * 0.5, fl, float(r["z0"]) + 0.75), 0.0)
	KitHouses._marker(body, "Customer", Vector3((cx0 + cx1) * 0.5, fl, cz + 0.95), PI)
	return cz


## The keeper's spot for a room with no counter: by the back wall, facing the door.
static func _keeper_at(body: Node3D, r: Dictionary, x: float) -> void:
	KitHouses._marker(body, "Vendor", Vector3(x, r["fl"], float(r["z0"]) + 0.6), 0.0)
	KitHouses._marker(body, "Customer", Vector3(x, r["fl"], float(r["z0"]) + 1.8), PI)


static func _shelf_row(mb: MeshBuilder, r: Dictionary, y: float, z: float, x0: float, x1: float) -> void:
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3((x0 + x1) * 0.5, float(r["fl"]) + y, z)), Vector3(x1 - x0, 0.05, 0.34), 1.0, Color.WHITE, false)


## A blade: a grip, a guard and the steel (into mb at xf, the blade up +Y).
static func _blade(mb: MeshBuilder, xf: Transform3D, len_: float, curved := false) -> void:
	mb.add_box(PSXMat.lit("leather", Color(0.3, 0.2, 0.15)), xf * _xf(Vector3(0, 0.1, 0)), Vector3(0.04, 0.22, 0.04), 1.0)
	mb.add_box(PSXMat.lit("metal", Color(0.75, 0.6, 0.3)), xf * _xf(Vector3(0, 0.22, 0)), Vector3(0.18 if not curved else 0.08, 0.03, 0.06), 1.0)
	var steel := PSXMat.lit("metal", Color(0.85, 0.87, 0.9))
	if curved:
		for k in range(4):
			mb.add_box(steel, xf * Transform3D(Basis(Vector3.BACK, -0.05 * k), Vector3(0.012 * k * k, 0.24 + len_ * (k + 0.5) / 4.0, 0)), Vector3(0.035, len_ / 4.0 + 0.02, 0.012), 1.0)
	else:
		mb.add_box(steel, xf * _xf(Vector3(0, 0.24 + len_ * 0.5, 0)), Vector3(0.06, len_, 0.012), 1.0)


# --------------------------------------------------------------------------
# The traders
# --------------------------------------------------------------------------
static func _forge(body: Node3D, mb: MeshBuilder, r: Dictionary, cz: float, rng: RandomNumberGenerator, master: bool) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var stone := PSXMat.lit("stone_brick", Color(0.7, 0.66, 0.62))
	var iron := PSXMat.lit("metal", Color(0.22, 0.22, 0.24))
	# the forge in the back corner past the counter's end: a brick hearth, coals, a hood
	var fp := Vector3(x1 - 0.5, fl, z0 + 0.6)
	mb.add_box(stone, _xf(fp + Vector3(0, 0.4, 0)), Vector3(0.9, 0.8, 0.9), 0.6)
	mb.add_box(PSXMat.glow(Color(1.0, 0.42, 0.1), 3.2), _xf(fp + Vector3(0, 0.82, 0.05)), Vector3(0.6, 0.05, 0.6), 1.0)
	mb.add_cylinder(stone, _xf(fp + Vector3(0, 1.5, 0)), 0.55, 0.22, 0.8, 4, 0.6, Color(0.8, 0.8, 0.8), false, true)
	KitHouses._box(body, Vector3(0.9, 0.8, 0.9), fp + Vector3(0, 0.4, 0))
	# the anvil on its stump, a quench tub
	var ap := Vector3(x1 - 0.8, fl, z1 - 1.2)
	mb.add_cylinder(PSXMat.lit("bark"), _xf(ap), 0.26, 0.24, 0.5, 7, 1.0)
	mb.add_box(iron, _xf(ap + Vector3(0, 0.6, 0)), Vector3(0.6, 0.2, 0.24), 1.0)
	mb.add_box(iron, _xf(ap + Vector3(0.38, 0.63, 0)), Vector3(0.2, 0.12, 0.12), 1.0)
	KitHouses._cyl(body, 0.3, 0.7, ap)
	mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(Vector3(x1 - 0.5, fl, z1 - 0.4)), 0.3, 0.32, 0.5, 8, 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.15, 0.2, 0.22)), _xf(Vector3(x1 - 0.5, fl + 0.46, z1 - 0.4)), 0.27, 0.27, 0.02, 8, 1.0)
	# blades on the wall behind the counter, a few on it
	var n := 5 if master else 4
	for k in range(n):
		var bx := x0 + 0.5 + k * 0.42
		_blade(mb, Transform3D(Basis(Vector3.BACK, 0.0), Vector3(bx, fl + 1.2, z0 + 0.06)), 0.75 + rng.randf() * 0.15, master and k % 2 == 0)
	for k in range(2):
		_blade(mb, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, 0.2 * k), Vector3(x0 + 0.8 + k * 0.6, fl + 1.1, cz + 0.4)), 0.7)
	if master:
		# the masterwork on its stand at the counter's end, lit
		var sp := Vector3(x0 + 0.5, fl, z1 - 0.7)
		mb.add_box(PSXMat.lit("planks_dark"), _xf(sp + Vector3(0, 0.45, 0)), Vector3(0.5, 0.9, 0.4), 1.0)
		mb.add_box(PSXMat.lit("fabric", Color(0.55, 0.1, 0.12)), _xf(sp + Vector3(0, 0.91, 0)), Vector3(0.52, 0.02, 0.42), 1.0)
		_blade(mb, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), sp + Vector3(0.0, 0.98, 0.45)), 0.8, true)
		mb.add_box(PSXMat.glow(Color(1.0, 0.85, 0.5), 0.8), _xf(sp + Vector3(0, 0.93, 0)), Vector3(0.05, 0.01, 0.3), 1.0)
		KitHouses._box(body, Vector3(0.5, 0.9, 0.4), sp + Vector3(0, 0.45, 0))
	else:
		var rack := Props.weapon_rack()
		rack.position = Vector3(x0 + 0.25, fl, z1 - 1.0)
		rack.rotation.y = PI * 0.5
		body.add_child(rack)
	# tongs and hammers hung on the side wall
	for k in range(3):
		mb.add_box(iron, _xf(Vector3(x0 + 0.05, fl + 1.7, -0.2 + k * 0.35)), Vector3(0.03, 0.5, 0.04), 1.0)
		mb.add_box(iron, _xf(Vector3(x0 + 0.07, fl + 1.48, -0.2 + k * 0.35)), Vector3(0.06, 0.08, 0.14), 1.0)


static func _armoury(body: Node3D, mb: MeshBuilder, r: Dictionary, cz: float, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var steel := PSXMat.lit("metal", Color(0.72, 0.74, 0.78))
	var leather := PSXMat.lit("leather", Color(0.45, 0.3, 0.2))
	# shields on the back wall
	for k in range(4):
		var col: Color = CLOTHS[(k + rng.randi()) % CLOTHS.size()]
		var sp := Vector3(x0 + 0.5 + k * 0.6, fl + 1.65, z0 + 0.05)
		mb.add_cylinder(PSXMat.lit("planks", col), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), sp), 0.26, 0.26, 0.05, 8, 1.0, Color.WHITE, true, true)
		mb.add_blob(steel, _xf(sp + Vector3(0, 0, 0.05)), Vector3(0.07, 0.07, 0.04), rng, 0.0, 2, 6)
	# two armour stands by the door
	for s in [-1.0, 1.0]:
		var ap := Vector3((x1 - 0.5) if s > 0 else (x0 + 0.5), fl, z1 - 0.8)
		mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(ap), 0.18, 0.18, 0.05, 6, 1.0)
		mb.add_box(PSXMat.lit("planks_dark"), _xf(ap + Vector3(0, 0.6, 0)), Vector3(0.05, 1.2, 0.05), 1.0)
		mb.add_box(steel if s > 0 else leather, _xf(ap + Vector3(0, 1.25, 0)), Vector3(0.42, 0.5, 0.26), 1.0)
		mb.add_box(steel if s > 0 else leather, _xf(ap + Vector3(0, 0.95, 0)), Vector3(0.38, 0.14, 0.24), 1.0)
		mb.add_blob(steel, _xf(ap + Vector3(0, 1.62, 0)), Vector3(0.14, 0.15, 0.15), rng, 0.05, 3, 6)
		KitHouses._cyl(body, 0.25, 1.7, ap)
	# a helm and gauntlets on the counter
	mb.add_blob(steel, _xf(Vector3(x0 + 0.9, fl + 1.2, cz)), Vector3(0.15, 0.13, 0.16), rng, 0.05, 3, 6)
	for k in range(2):
		mb.add_box(leather, _xf(Vector3(x0 + 1.5 + k * 0.25, fl + 1.12, cz + 0.05), 0.3 * k), Vector3(0.12, 0.08, 0.24), 1.0)


static func _tailor(body: Node3D, mb: MeshBuilder, r: Dictionary, cz: float, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	# bolts of cloth on shelves behind the counter
	for row in range(3):
		var y := 0.85 + row * 0.5
		_shelf_row(mb, r, y, z0 + 0.2, x0 + 0.2, x1 - 0.2)
		var x := x0 + 0.35
		while x < x1 - 0.4:
			mb.add_cylinder(PSXMat.lit("fabric", CLOTHS[rng.randi() % CLOTHS.size()]), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x + 0.22, fl + y + 0.12, z0 + 0.22)), 0.1, 0.1, 0.44, 6, 1.0, Color.WHITE, true, true)
			x += 0.5
	# a dress form with a coat, garments hung on a pole
	var dp := Vector3(x0 + 0.6, fl, z1 - 0.9)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(dp + Vector3(0, 0.45, 0)), Vector3(0.05, 0.9, 0.05), 1.0)
	mb.add_cylinder(PSXMat.lit("fabric", CLOTHS[rng.randi() % CLOTHS.size()]), _xf(dp + Vector3(0, 0.9, 0)), 0.22, 0.2, 0.62, 7, 1.0)
	mb.add_cylinder(PSXMat.lit("canvas", Color(0.85, 0.8, 0.7)), _xf(dp + Vector3(0, 1.52, 0)), 0.17, 0.08, 0.12, 7, 1.0)
	KitHouses._cyl(body, 0.25, 1.6, dp)
	var rail := PSXMat.lit("planks_dark")
	mb.add_box(rail, _xf(Vector3(x1 - 0.25, fl + 1.9, z1 - 1.3)), Vector3(0.04, 0.04, 1.4), 1.0)
	for k in range(4):
		mb.add_box(PSXMat.lit("fabric", CLOTHS[(k * 2 + 1) % CLOTHS.size()]), _xf(Vector3(x1 - 0.25, fl + 1.45, z1 - 1.9 + k * 0.32)), Vector3(0.12, 0.8, 0.28), 1.0)
	# scissors and folded cloth on the counter
	for k in range(3):
		mb.add_box(PSXMat.lit("fabric", CLOTHS[(k + 2) % CLOTHS.size()]), _xf(Vector3(x0 + 0.8, fl + 1.11 + k * 0.05, cz)), Vector3(0.4, 0.05, 0.3), 1.0)
	mb.add_box(PSXMat.lit("metal", Color(0.8, 0.8, 0.85)), _xf(Vector3(x0 + 1.5, fl + 1.09, cz + 0.1), 0.4), Vector3(0.04, 0.01, 0.2), 1.0)


static func _luthier(body: Node3D, mb: MeshBuilder, r: Dictionary, cz: float, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var wood := PSXMat.lit("planks", Color(0.85, 0.55, 0.3))
	var dark := PSXMat.lit("planks_dark")
	# lutes and fiddles hung on the back wall
	for k in range(4):
		var ip := Vector3(x0 + 0.5 + k * 0.55, fl + 1.55 + (k % 2) * 0.15, z0 + 0.06)
		var s := 1.0 if k % 2 == 0 else 0.7
		mb.add_blob(wood, _xf(ip), Vector3(0.18, 0.24, 0.05) * s, rng, 0.0, 3, 6)
		mb.add_box(dark, _xf(ip + Vector3(0, 0.38 * s, 0)), Vector3(0.05, 0.5 * s, 0.03), 1.0)
		mb.add_box(dark, _xf(ip + Vector3(0, 0.66 * s, 0)), Vector3(0.08, 0.1, 0.03), 1.0)
	# drums by the door
	for k in range(3):
		var dp := Vector3(x1 - 0.45, fl, z1 - 0.5 - k * 0.55)
		var rr := 0.2 + 0.05 * k
		mb.add_cylinder(wood, _xf(dp), rr, rr, 0.35 + 0.1 * k, 8, 1.0, Color.WHITE, false)
		mb.add_cylinder(PSXMat.lit("canvas", Color(0.92, 0.88, 0.78)), _xf(dp + Vector3(0, 0.35 + 0.1 * k, 0)), rr, rr, 0.01, 8, 1.0)
	KitHouses._box(body, Vector3(0.6, 0.6, 1.6), Vector3(x1 - 0.45, fl + 0.3, z1 - 1.05))
	# a fiddle and a bow on the counter, a workbench of parts
	mb.add_blob(wood, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(x0 + 1.0, fl + 1.12, cz)), Vector3(0.12, 0.17, 0.04), rng, 0.0, 3, 6)
	mb.add_box(dark, _xf(Vector3(x0 + 1.4, fl + 1.1, cz + 0.05), 0.3), Vector3(0.02, 0.02, 0.55), 1.0)
	for k in range(3):
		mb.add_box(wood, _xf(Vector3(x0 + 0.4, fl + 0.3 + k * 0.08, z1 - 0.8), 0.2 * k), Vector3(0.5, 0.06, 0.18), 1.0)


static func _shelves(body: Node3D, mb: MeshBuilder, r: Dictionary, cz: float, rng: RandomNumberGenerator, curios: bool) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var glass := [PSXMat.flat(Color(0.25, 0.55, 0.3)), PSXMat.flat(Color(0.55, 0.28, 0.12)), PSXMat.flat(Color(0.25, 0.35, 0.6)), PSXMat.flat(Color(0.6, 0.2, 0.35))]
	for row in range(4):
		var y := 0.75 + row * 0.45
		_shelf_row(mb, r, y, z0 + 0.2, x0 + 0.2, x1 - 0.2)
		var x := x0 + 0.35
		var k := 0
		while x < x1 - 0.35:
			if curios:
				match (row * 3 + k) % 5:
					0:
						mb.add_blob(PSXMat.lit("plaster", Color(0.95, 0.92, 0.84)), _xf(Vector3(x, fl + y + 0.12, z0 + 0.2)), Vector3(0.1, 0.1, 0.11), rng, 0.15, 3, 6)
					1:
						mb.add_blob(PSXMat.flat(Color(0.95, 0.7, 0.55)), _xf(Vector3(x, fl + y + 0.08, z0 + 0.2)), Vector3(0.12, 0.06, 0.1), rng, 0.3, 2, 6)
					2:
						mb.add_cylinder(glass[2], Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x + 0.12, fl + y + 0.1, z0 + 0.2)), 0.08, 0.08, 0.3, 6, 1.0, Color.WHITE, true, true)
						mb.add_box(PSXMat.lit("planks", Color(0.7, 0.5, 0.3)), _xf(Vector3(x - 0.03, fl + y + 0.1, z0 + 0.2)), Vector3(0.12, 0.04, 0.04), 1.0)
					3:
						mb.add_box(PSXMat.lit("metal", Color(0.75, 0.6, 0.3)), _xf(Vector3(x, fl + y + 0.08, z0 + 0.2)), Vector3(0.18, 0.14, 0.14), 1.0)
					_:
						KitHouses._jar(mb, KitHouses._clay(rng), _xf(Vector3(x, fl + y + 0.03, z0 + 0.2)), 0.6)
				x += 0.42
			else:
				for b in range(3):
					mb.add_cylinder(glass[(row + b + k) % glass.size()], _xf(Vector3(x + b * 0.11, fl + y + 0.03, z0 + 0.2)), 0.045, 0.04, 0.2 + 0.04 * (b % 2), 5, 1.0)
				x += 0.42
			k += 1
	# herbs hung from the beam, a mortar and scales on the counter (curios: a stuffed fish and a ship in a bottle)
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	for k in range(5):
		var hx := x0 + 0.5 + k * 0.5
		mb.add_box(rope, _xf(Vector3(hx, fl + 2.3, z1 - 1.0)), Vector3(0.02, 0.3, 0.02), 1.0)
		mb.add_blob(PSXMat.lit("leaves", Color(0.6, 0.8, 0.45) if not curios else Color(0.85, 0.75, 0.55)), _xf(Vector3(hx, fl + 2.08, z1 - 1.0)), Vector3(0.09, 0.16, 0.09), rng, 0.25, 3, 5)
	var stone := PSXMat.lit("rock", Color(0.8, 0.78, 0.74))
	if curios:
		mb.add_blob(PSXMat.flat(Color(0.35, 0.55, 0.6)), _xf(Vector3(x0 + 1.0, fl + 1.2, cz)), Vector3(0.35, 0.12, 0.08), rng, 0.1, 3, 6)
		mb.add_cylinder(glass[0], Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x0 + 1.9, fl + 1.16, cz)), 0.09, 0.09, 0.4, 6, 1.0, Color.WHITE, true, true)
	else:
		mb.add_cylinder(stone, _xf(Vector3(x0 + 0.9, fl + 1.08, cz)), 0.11, 0.14, 0.14, 7, 1.0)
		mb.add_box(PSXMat.lit("metal", Color(0.75, 0.6, 0.3)), _xf(Vector3(x0 + 1.6, fl + 1.3, cz)), Vector3(0.5, 0.03, 0.03), 1.0)
		mb.add_box(PSXMat.lit("metal", Color(0.75, 0.6, 0.3)), _xf(Vector3(x0 + 1.6, fl + 1.18, cz)), Vector3(0.03, 0.25, 0.03), 1.0)
	# a chest of stock by the door
	var cp := Vector3(x0 + 0.5, fl, z1 - 0.6)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(cp + Vector3(0, 0.25, 0)), Vector3(0.8, 0.5, 0.5), 1.0)
	KitHouses._box(body, Vector3(0.8, 0.5, 0.5), cp + Vector3(0, 0.25, 0))


# --------------------------------------------------------------------------
# The unique places
# --------------------------------------------------------------------------
static func _library(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var books := [Color(0.5, 0.15, 0.12), Color(0.18, 0.28, 0.5), Color(0.25, 0.4, 0.2), Color(0.55, 0.42, 0.2), Color(0.3, 0.22, 0.15)]
	# shelves of books along the back and both side walls
	for wall in [[Vector3(0, 0, z0 + 0.18), float(r["w"]) - 0.6, 0.0], [Vector3(x0 + 0.18, 0, -0.3), float(r["d"]) - 2.4, PI * 0.5], [Vector3(x1 - 0.18, 0, -0.3), float(r["d"]) - 2.4, -PI * 0.5]]:
		var base: Vector3 = wall[0]
		var len_: float = wall[1]
		var xf := _xf(base, wall[2])
		mb.add_box(PSXMat.lit("planks_dark"), xf * _xf(Vector3(0, fl + 1.1, -0.02)), Vector3(len_, 2.2, 0.06), 1.0)
		for row in range(4):
			var y := fl + 0.25 + row * 0.5
			mb.add_box(PSXMat.lit("planks_dark"), xf * _xf(Vector3(0, y, 0.08)), Vector3(len_, 0.04, 0.3), 1.0, Color.WHITE, false)
			var x := -len_ * 0.5 + 0.1
			while x < len_ * 0.5 - 0.1:
				var bw := rng.randf_range(0.04, 0.08)
				var bh := rng.randf_range(0.26, 0.38)
				mb.add_box(PSXMat.flat(books[rng.randi() % books.size()]), xf * _xf(Vector3(x, y + 0.02 + bh * 0.5, 0.1), rng.randf_range(-0.05, 0.05)), Vector3(bw, bh, 0.22), 1.0)
				x += bw + 0.01 + (0.08 if rng.randf() < 0.08 else 0.0)
	KitHouses._box(body, Vector3(float(r["w"]) - 0.6, 2.2, 0.4), Vector3(0, fl + 1.1, z0 + 0.25))
	# a reading table, an open book, a candle
	var tp := Vector3(0.0, fl, 0.2)
	mb.add_box(PSXMat.lit("planks"), _xf(tp + Vector3(0, 0.76, 0)), Vector3(1.4, 0.06, 0.8), 1.0, Color.WHITE, false)
	for x in [-0.6, 0.6]:
		for z in [-0.32, 0.32]:
			mb.add_box(PSXMat.lit("planks_dark"), _xf(tp + Vector3(x, 0.37, z)), Vector3(0.06, 0.74, 0.06), 1.0)
	mb.add_box(PSXMat.flat(Color(0.92, 0.88, 0.76)), _xf(tp + Vector3(-0.15, 0.8, 0), 0.1), Vector3(0.5, 0.02, 0.35), 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.95, 0.92, 0.85)), _xf(tp + Vector3(0.45, 0.79, -0.2)), 0.03, 0.03, 0.16, 5, 1.0)
	mb.add_box(PSXMat.glow(Color(1.0, 0.8, 0.4), 3.0), _xf(tp + Vector3(0.45, 0.98, -0.2)), Vector3(0.03, 0.05, 0.03), 1.0)
	KitHouses._box(body, Vector3(1.4, 0.8, 0.8), tp + Vector3(0, 0.4, 0))
	for s in [-1.0, 1.0]:
		Props.seats().add(body, tp + Vector3(s * 0.4, 0.45, 0.75), 0.45, Vector3(0, 0, -1))
		mb.add_box(PSXMat.lit("planks_dark"), _xf(tp + Vector3(s * 0.4, 0.22, 0.75)), Vector3(0.36, 0.44, 0.36), 1.0)
	# scrolls in a basket by the door
	var bp := Vector3(x1 - 0.5, fl, z1 - 0.5)
	mb.add_cylinder(PSXMat.lit("straw"), _xf(bp), 0.22, 0.26, 0.4, 7, 1.0)
	for k in range(5):
		mb.add_cylinder(PSXMat.flat(Color(0.9, 0.86, 0.72)), Transform3D(Basis(Vector3.BACK, 0.2 * (k - 2)), bp + Vector3(-0.1 + k * 0.05, 0.2, 0.0)), 0.04, 0.04, 0.5, 5, 1.0)
	_keeper_at(body, r, -0.9)


static func _onsen(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var stone := PSXMat.lit("rock", Color(0.6, 0.6, 0.58))
	# the hot pool in the middle of the room: a rim of stones round steaming water
	var pc := Vector3((x0 + x1) * 0.5, fl, (z0 + z1) * 0.5 - 0.3)
	var pw := (x1 - x0) - 1.2
	var pd := (z1 - z0) - 2.0
	for k in range(int((pw + pd) * 2.0 / 0.35)):
		var t := k * 0.35
		var q: Vector3
		if t < pw:
			q = Vector3(-pw * 0.5 + t, 0, -pd * 0.5)
		elif t < pw + pd:
			q = Vector3(pw * 0.5, 0, -pd * 0.5 + t - pw)
		elif t < pw * 2.0 + pd:
			q = Vector3(pw * 0.5 - (t - pw - pd), 0, pd * 0.5)
		else:
			q = Vector3(-pw * 0.5, 0, pd * 0.5 - (t - pw * 2.0 - pd))
		mb.add_blob(stone, _xf(pc + q + Vector3(0, 0.12, 0)), Vector3(0.2, 0.14, 0.18), rng, 0.25, 2, 5)
	mb.add_box(PSXMat.glow(Color(0.24, 0.55, 0.56), 0.6), _xf(pc + Vector3(0, 0.12, 0)), Vector3(pw - 0.1, 0.03, pd - 0.1), 0.6, Color.WHITE, true, false)
	for k in range(5):
		mb.add_blob(PSXMat.flat(Color(0.85, 0.92, 0.92)), _xf(pc + Vector3(rng.randf_range(-pw, pw) * 0.35, 0.16, rng.randf_range(-pd, pd) * 0.3)), Vector3(0.12, 0.02, 0.1), rng, 0.3, 2, 5)
	# towels on a rail, buckets, a low bench
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(x0 + 0.1, fl + 1.3, z1 - 0.6)), Vector3(0.04, 0.04, 0.9), 1.0)
	for k in range(3):
		mb.add_box(PSXMat.lit("canvas", [Color(0.92, 0.9, 0.85), Color(0.6, 0.75, 0.85), Color(0.9, 0.7, 0.6)][k]), _xf(Vector3(x0 + 0.13, fl + 1.05, z1 - 0.95 + k * 0.3)), Vector3(0.04, 0.5, 0.26), 1.0)
	for k in range(2):
		mb.add_cylinder(PSXMat.lit("planks", Color(0.8, 0.65, 0.45)), _xf(Vector3(x1 - 0.4 - k * 0.45, fl, z1 - 0.4)), 0.15, 0.17, 0.25, 7, 1.0)
	mb.add_box(PSXMat.lit("planks"), _xf(Vector3(x1 - 0.3, fl + 0.35, -0.2)), Vector3(0.4, 0.06, 1.6), 1.0, Color.WHITE, false)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(x1 - 0.3, fl + 0.16, -0.2)), Vector3(0.34, 0.32, 1.4), 1.0)
	for z in [-0.6, 0.2]:
		Props.seats().add(body, Vector3(x1 - 0.3, fl + 0.38, z), 0.38, Vector3(-1, 0, 0))
	KitHouses._marker(body, "Vendor", Vector3(x0 + 0.6, fl, z0 + 0.5), 0.6)
	KitHouses._marker(body, "Customer", Vector3(x0 + 0.6, fl, z1 - 0.4), PI)


static func _restaurant(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	# the pass at the back: a low counter of dishes, the kitchen's glow behind it
	var cz := z0 + 0.9
	mb.add_box(PSXMat.lit("planks"), _xf(Vector3(0, fl + 0.5, cz)), Vector3(x1 - x0 - 0.6, 1.0, 0.5), 1.0)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(0, fl + 1.03, cz)), Vector3(x1 - x0 - 0.5, 0.06, 0.62), 1.0, Color.WHITE, false)
	KitHouses._box(body, Vector3(x1 - x0 - 0.6, 1.06, 0.55), Vector3(0, fl + 0.53, cz))
	for k in range(4):
		var dp := Vector3(x0 + 0.7 + k * 0.6, fl + 1.07, cz)
		mb.add_cylinder(PSXMat.flat(Color(0.92, 0.9, 0.85)), _xf(dp), 0.14, 0.16, 0.03, 8, 1.0)
		mb.add_blob(PSXMat.flat([Color(0.85, 0.45, 0.2), Color(0.55, 0.7, 0.3), Color(0.9, 0.8, 0.5), Color(0.75, 0.25, 0.15)][k]), _xf(dp + Vector3(0, 0.05, 0)), Vector3(0.09, 0.04, 0.09), rng, 0.2, 2, 5)
	mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.18), 2.0), _xf(Vector3(x1 - 0.8, fl + 0.6, z0 + 0.15)), Vector3(0.7, 0.4, 0.04), 1.0)
	# two dining tables with cloths, plates and stools
	for s in [-1.0, 1.0]:
		var tp := Vector3(s * (x1 - x0) * 0.24, fl, z1 - 1.3)
		mb.add_box(PSXMat.lit("fabric", Color(0.9, 0.88, 0.82)), _xf(tp + Vector3(0, 0.76, 0)), Vector3(0.9, 0.06, 0.9), 1.0, Color.WHITE, false)
		mb.add_box(PSXMat.lit("planks_dark"), _xf(tp + Vector3(0, 0.37, 0)), Vector3(0.12, 0.74, 0.12), 1.0)
		for k in range(2):
			mb.add_cylinder(PSXMat.flat(Color(0.95, 0.93, 0.88)), _xf(tp + Vector3(-0.2 + k * 0.4, 0.8, -0.15 + k * 0.3)), 0.12, 0.12, 0.02, 8, 1.0)
		mb.add_cylinder(PSXMat.flat(Color(0.95, 0.92, 0.85)), _xf(tp + Vector3(0, 0.79, 0)), 0.025, 0.025, 0.14, 5, 1.0)
		mb.add_box(PSXMat.glow(Color(1.0, 0.8, 0.4), 3.0), _xf(tp + Vector3(0, 0.96, 0)), Vector3(0.025, 0.04, 0.025), 1.0)
		KitHouses._box(body, Vector3(0.9, 0.8, 0.9), tp + Vector3(0, 0.4, 0))
		for z in [-0.65, 0.65]:
			mb.add_cylinder(PSXMat.lit("planks"), _xf(tp + Vector3(0, 0, z)), 0.16, 0.16, 0.45, 6, 1.0)
			Props.seats().add(body, tp + Vector3(0, 0.45, z), 0.45, Vector3(0, 0, -signf(z)))
	# paper lanterns overhead
	for k in range(3):
		var lp := Vector3(x0 + 0.8 + k * (x1 - x0 - 1.6) * 0.5, fl + float(r["h"]) - 0.6, z1 - 1.3)
		mb.add_cylinder(PSXMat.glow(Color(1.0, 0.45, 0.3), 1.6), _xf(lp), 0.12, 0.12, 0.26, 7, 1.0, Color.WHITE, true, true)
	KitHouses._marker(body, "Vendor", Vector3(0, fl, z0 + 0.35), 0.0)
	KitHouses._marker(body, "Customer", Vector3(0, fl, cz + 0.85), PI)


static func _sea_shrine(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	# the altar at the back: a stone step, the sea idol, shells and candles, a rope with paper streamers over it
	var ap := Vector3(0, fl, z0 + 0.6)
	mb.add_box(PSXMat.lit("stone_brick", Color(0.8, 0.82, 0.86)), _xf(ap + Vector3(0, 0.3, 0)), Vector3(1.8, 0.6, 0.8), 0.6)
	mb.add_box(PSXMat.lit("stone_brick", Color(0.7, 0.72, 0.78)), _xf(ap + Vector3(0, 0.75, -0.1)), Vector3(1.2, 0.3, 0.5), 0.6)
	KitHouses._box(body, Vector3(1.8, 0.9, 0.8), ap + Vector3(0, 0.45, 0))
	var idol := PSXMat.lit("rock", Color(0.45, 0.6, 0.66))
	mb.add_blob(idol, _xf(ap + Vector3(0, 1.25, -0.1)), Vector3(0.22, 0.32, 0.18), rng, 0.15, 3, 6)
	mb.add_blob(idol, _xf(ap + Vector3(0, 1.65, -0.1)), Vector3(0.16, 0.14, 0.15), rng, 0.1, 3, 6)
	for s in [-1.0, 1.0]:
		mb.add_blob(idol, Transform3D(Basis(Vector3.BACK, s * 0.6), ap + Vector3(s * 0.25, 1.5, -0.1)), Vector3(0.05, 0.2, 0.05), rng, 0.1, 2, 5)
	for k in range(6):
		var sp := ap + Vector3(-0.75 + k * 0.3, 0.62, 0.25)
		if k % 2 == 0:
			mb.add_blob(PSXMat.flat([Color(0.95, 0.8, 0.75), Color(0.95, 0.9, 0.8), Color(0.85, 0.65, 0.55)][k / 2]), _xf(sp), Vector3(0.08, 0.04, 0.06), rng, 0.3, 2, 5)
		else:
			mb.add_cylinder(PSXMat.flat(Color(0.95, 0.92, 0.85)), _xf(sp), 0.025, 0.025, 0.12, 5, 1.0)
			mb.add_box(PSXMat.glow(Color(1.0, 0.8, 0.4), 3.0), _xf(sp + Vector3(0, 0.15, 0)), Vector3(0.025, 0.04, 0.025), 1.0)
	var rope := PSXMat.lit("rope", Color(0.9, 0.82, 0.6))
	Buildings.beam_between(mb, rope, Vector3(x0 + 0.1, fl + 2.1, z0 + 0.3), Vector3(x1 - 0.1, fl + 2.1, z0 + 0.3), 0.05)
	for k in range(5):
		mb.add_box(PSXMat.flat(Color(0.97, 0.97, 0.95)), _xf(Vector3(x0 + 0.6 + k * (x1 - x0 - 1.2) / 4.0, fl + 1.85, z0 + 0.3)), Vector3(0.1, 0.4, 0.01), 1.0)
	# nets and floats hung on the side walls, offerings of fish on a mat
	for s in [-1.0, 1.0]:
		var wx: float = (x0 + 0.05) if s < 0 else (x1 - 0.05)
		for k in range(4):
			Buildings.beam_between(mb, rope, Vector3(wx, fl + 2.2, -0.6 + k * 0.4), Vector3(wx, fl + 1.3 + (k % 2) * 0.2, -0.4 + k * 0.4), 0.015)
		mb.add_blob(PSXMat.flat(Color(0.9, 0.55, 0.2)), _xf(Vector3(wx, fl + 1.6, 0.3)), Vector3.ONE * 0.09, rng, 0.1, 2, 5)
	mb.add_quad(PSXMat.lit("straw", Color(0.9, 0.8, 0.6)), Vector3(-0.7, fl + 0.012, z0 + 1.2), Vector3(0.7, fl + 0.012, z0 + 1.2), Vector3(0.7, fl + 0.012, z0 + 2.2), Vector3(-0.7, fl + 0.012, z0 + 2.2),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 0.7), Vector2(0, 0.7), Color.WHITE, Vector3.UP)
	KitHouses._marker(body, "Vendor", Vector3(x1 - 0.7, fl, z0 + 1.2), -0.6)
	KitHouses._marker(body, "Customer", Vector3(0, fl, z0 + 1.9), PI)


static func _cartographer(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	var paper := PSXMat.lit("canvas", Color(0.93, 0.86, 0.68))
	# the chart table in the middle, a great map on it, weights at its corners, dividers
	var tp := Vector3(0, fl, -0.1)
	mb.add_box(PSXMat.lit("planks"), _xf(tp + Vector3(0, 0.86, 0)), Vector3(1.8, 0.08, 1.1), 1.0, Color.WHITE, false)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(tp + Vector3(0, 0.42, 0)), Vector3(1.5, 0.84, 0.8), 1.0)
	mb.add_box(paper, _xf(tp + Vector3(0, 0.91, 0)), Vector3(1.6, 0.01, 0.95), 1.0)
	var ink := PSXMat.flat(Color(0.35, 0.28, 0.2))
	for k in range(6):
		mb.add_blob(PSXMat.flat(Color(0.55, 0.7, 0.45)), _xf(tp + Vector3(rng.randf_range(-0.6, 0.6), 0.92, rng.randf_range(-0.3, 0.3))), Vector3(rng.randf_range(0.06, 0.16), 0.004, rng.randf_range(0.05, 0.12)), rng, 0.4, 2, 6)
	for k in range(3):
		mb.add_box(ink, _xf(tp + Vector3(-0.5 + k * 0.45, 0.92, 0.1 * (k - 1)), 0.4 * k), Vector3(0.4, 0.004, 0.01), 1.0)
	for sx in [-0.75, 0.75]:
		for sz in [-0.42, 0.42]:
			mb.add_cylinder(PSXMat.lit("metal", Color(0.65, 0.55, 0.3)), _xf(tp + Vector3(sx, 0.92, sz)), 0.04, 0.04, 0.05, 6, 1.0)
	KitHouses._box(body, Vector3(1.8, 0.9, 1.1), tp + Vector3(0, 0.45, 0))
	# charts pinned on the walls, a globe on its stand, rolled maps in a barrel
	for k in range(4):
		mb.add_box(paper, _xf(Vector3(x0 + 0.6 + k * 0.7, fl + 1.6 + (k % 2) * 0.15, z0 + 0.03), 0.05 * (k - 2)), Vector3(0.55, 0.45, 0.01), 1.0)
	for k in range(2):
		mb.add_box(paper, _xf(Vector3(x1 - 0.03, fl + 1.5, -0.6 + k * 0.8), -PI * 0.5), Vector3(0.6, 0.5, 0.01), 1.0)
	var gp := Vector3(x0 + 0.5, fl, z1 - 0.6)
	mb.add_box(PSXMat.lit("planks_dark"), _xf(gp + Vector3(0, 0.45, 0)), Vector3(0.06, 0.9, 0.06), 1.0)
	mb.add_blob(PSXMat.flat(Color(0.3, 0.5, 0.65)), _xf(gp + Vector3(0, 1.12, 0)), Vector3(0.22, 0.22, 0.22), rng, 0.0, 4, 8)
	mb.add_blob(PSXMat.flat(Color(0.65, 0.6, 0.35)), _xf(gp + Vector3(0.08, 1.18, 0.12)), Vector3(0.08, 0.1, 0.12), rng, 0.3, 2, 5)
	KitHouses._cyl(body, 0.25, 1.3, gp)
	var bp := Vector3(x1 - 0.5, fl, z1 - 0.5)
	mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(bp), 0.24, 0.26, 0.6, 8, 1.0)
	for k in range(6):
		mb.add_cylinder(paper, Transform3D(Basis(Vector3.BACK, 0.15 * (k - 3)), bp + Vector3(-0.12 + (k % 3) * 0.12, 0.4, -0.06 + (k / 3) * 0.12)), 0.04, 0.04, 0.6, 5, 1.0)
	KitHouses._cyl(body, 0.27, 0.6, bp)
	_keeper_at(body, r, 0.9)


static func _dojo(body: Node3D, mb: MeshBuilder, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var fl: float = r["fl"]
	var x0: float = r["x0"]
	var x1: float = r["x1"]
	var z0: float = r["z0"]
	var z1: float = r["z1"]
	# mats across the floor, a scroll on the back wall, practice weapons on racks, a straw dummy
	for k in range(int((x1 - x0) / 0.9)):
		for j in range(int((z1 - z0 - 0.4) / 1.8)):
			mb.add_box(PSXMat.lit("straw", Color(0.85, 0.8, 0.6) if (k + j) % 2 == 0 else Color(0.78, 0.74, 0.56)), _xf(Vector3(x0 + 0.45 + k * 0.9, fl + 0.015, z0 + 0.3 + 0.9 + j * 1.8)), Vector3(0.88, 0.03, 1.78), 1.0)
	mb.add_box(PSXMat.flat(Color(0.93, 0.9, 0.82)), _xf(Vector3(0, fl + 1.6, z0 + 0.03)), Vector3(0.6, 1.0, 0.01), 1.0)
	for k in range(4):
		mb.add_box(PSXMat.flat(Color(0.15, 0.12, 0.1)), _xf(Vector3(-0.1 + (k % 2) * 0.2, fl + 1.85 - k * 0.18, z0 + 0.04)), Vector3(0.04, 0.12, 0.01), 1.0)
	mb.add_box(PSXMat.flat(Color(0.7, 0.15, 0.1)), _xf(Vector3(0.15, fl + 1.25, z0 + 0.04)), Vector3(0.08, 0.08, 0.01), 1.0)
	var wood := PSXMat.lit("planks", Color(0.75, 0.6, 0.4))
	for s in [-1.0, 1.0]:
		var wx: float = (x0 + 0.08) if s < 0 else (x1 - 0.08)
		mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(wx, fl + 1.5, -0.2)), Vector3(0.06, 0.06, 1.6), 1.0)
		for k in range(5):
			mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(wx, fl + 0.85, -0.85 + k * 0.32)), Vector3(0.04, 1.3 if k % 2 == 0 else 0.9, 0.04), 1.0)
	var dummy := MeshInstance3D.new()
	dummy.mesh = Props.straw_dummy_mesh()
	dummy.position = Vector3(x1 - 0.8, fl, z1 - 0.9)
	dummy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(dummy)
	KitHouses._cyl(body, 0.3, 1.8, Vector3(x1 - 0.8, fl, z1 - 0.9))
	_keeper_at(body, r, -0.9)
