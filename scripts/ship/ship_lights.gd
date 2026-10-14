class_name ShipLights
extends RefCounted
## Ship's lanterns with real lights (NightLight: dusk to dawn, no shadows, faded
## out with distance). The crew's ship: the stern over the helm, the mast over the
## main deck, the bow, the cabin door and the rail either side; the pirates': the
## stern and the mast. The glass glows at any range, so a ship reads at night far
## past its lights. Ship-local (HullBuilder).

const WARM := Color(1.0, 0.74, 0.42)


static func lantern(mb: MeshBuilder, xf: Transform3D, s: float, frame: Material, glass: Material) -> void:
	BeltLantern.model(mb, xf, s, frame, glass)


## A lantern hung from a bracket: the arm from `wall` out to `hook`, the lantern below it.
static func _hung(mb: MeshBuilder, wall: Vector3, hook: Vector3, frame: Material, glass: Material, wood: Material) -> Vector3:
	BeltLantern.beam(mb, wood, wall, hook, 0.06)
	BeltLantern.beam(mb, frame, hook, hook - Vector3(0, 0.1, 0), 0.015)
	var foot := hook - Vector3(0, 0.62, 0)
	lantern(mb, Transform3D(Basis.IDENTITY, foot), 1.0, frame, glass)
	return foot + Vector3(0, 0.18, 0)


static func _light(model: Node3D, at: Vector3, energy: float, light_range: float) -> NightLight:
	var nl := NightLight.make(WARM, energy, light_range)
	nl.position = at
	model.add_child(nl)
	return nl


## The crew's ship (Ship.ship_model).
static func crew(model: Node3D) -> void:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var glass := PSXMat.glow(Color(1.0, 0.78, 0.4), 2.4)
	var wood := PSXMat.lit("planks_dark")
	var dy := HullBuilder.DECK_Y
	# the stern: a lantern on a post at each of the quarterdeck's aft corners, one light over the helm
	for sx in [-3.2, 3.2]:
		var foot := Vector3(sx, HullBuilder.QD_Y + 0.9, HullBuilder.QD_BACK - 0.3)
		mb.add_box(wood, Transform3D(Basis.IDENTITY, foot - Vector3(0, 0.45, 0)), Vector3(0.13, 0.9, 0.13), 1.0)
		lantern(mb, Transform3D(Basis.IDENTITY, foot), 1.15, iron, glass)
	_light(model, Vector3(0, HullBuilder.QD_Y + 1.4, HullBuilder.QD_BACK - 1.0), 1.3, 11.0)
	# the mast: hung on its aft side over the main deck
	var m := _hung(mb, Vector3(0, dy + 3.05, HullBuilder.MAST_Z + 0.15), Vector3(0, dy + 3.05, HullBuilder.MAST_Z + 0.6), iron, glass, wood)
	_light(model, m, 1.4, 12.0)
	# the bow: on a post at the stem
	var bow := Vector3(0, dy + 1.2, -9.4)
	mb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, dy + 0.6, -9.4)), Vector3(0.14, 1.2, 0.14), 1.0)
	lantern(mb, Transform3D(Basis.IDENTITY, bow), 1.0, iron, glass)
	_light(model, bow + Vector3(0, 0.3, 0.6), 1.1, 9.0)
	# the cabin door: one either side on the quarterdeck's front wall, one light between
	for sx in [-1.25, 1.25]:
		var wall := Vector3(sx, dy + 2.0, HullBuilder.QD_FRONT - 0.02)
		_hung(mb, wall, wall + Vector3(0, 0, -0.35), iron, glass, wood)
	_light(model, Vector3(0, dy + 1.8, HullBuilder.QD_FRONT - 0.8), 1.0, 8.0)
	# the rail amidships (between the shrouds and the stairs), both sides: a stanchion, hung inboard
	for sgn in [-1.0, 1.0]:
		var post := Vector3(sgn * (HullBuilder.half_width(0.0) - 0.02), dy, 0.0)
		mb.add_box(wood, Transform3D(Basis.IDENTITY, post + Vector3(0, 0.8, 0)), Vector3(0.14, 1.6, 0.14), 1.0)
		var r := _hung(mb, post + Vector3(0, 1.5, 0), post + Vector3(-sgn * 0.4, 1.5, 0), iron, glass, wood)
		_light(model, r - Vector3(sgn * 0.3, 0, 0), 0.8, 7.0)
	model.add_child(mb.to_instance("Lanterns"))


## A pirate ship (HullBuilder.build's model, not a wreck): the stern and the mast.
static func enemy(model: Node3D) -> void:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var glass := PSXMat.glow(Color(1.0, 0.72, 0.36), 2.6)
	var wood := PSXMat.lit("planks_dark")
	var m := _hung(mb, Vector3(0, HullBuilder.DECK_Y + 3.05, HullBuilder.MAST_Z + 0.15), Vector3(0, HullBuilder.DECK_Y + 3.05, HullBuilder.MAST_Z + 0.6), iron, glass, wood)
	_light(model, m, 1.3, 11.0)
	_light(model, Vector3(0, HullBuilder.QD_Y + 1.1, HullBuilder.QD_BACK - 0.6), 1.2, 10.0)
	model.add_child(mb.to_instance("Lanterns"))
