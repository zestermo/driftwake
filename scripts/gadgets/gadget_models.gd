class_name GadgetModels
extends RefCounted
## The gadgets' models (built in code, cached): what's thrown and held at each tier (Mk I plain, Mk II banded in
## brass, Mk III iron and red lacquer), their bag/belt icons, and the belt pouch worn on the captain's back.

const BRASS := Color(0.86, 0.66, 0.28)
const IRON := Color(0.3, 0.3, 0.33)
const LACQUER := Color(0.72, 0.14, 0.1)
const CLAY := Color(0.62, 0.5, 0.4)
const LEATHER := Color(0.36, 0.22, 0.13)

static var _meshes: Dictionary = {}
static var _icons: Dictionary = {}


## The thrown (or held) gadget `gid` at `tier` (0-2). Its "model" meta lets a crewmate's screen show it in hand.
static func mesh(gid: String, tier: int) -> ArrayMesh:
	var key := "%s:%d" % [gid, tier]
	if not _meshes.has(key):
		var m := _build(gid, tier)
		m.set_meta("model", "gadget:" + key)
		_meshes[key] = m
	return _meshes[key]


## mesh() by its "gadget:<id>:<tier>" model name (HumanoidSync).
static func from_model(model: String) -> ArrayMesh:
	return mesh(model.get_slice(":", 1), int(model.get_slice(":", 2)))


static func icon(gid: String, tier: int) -> Texture2D:
	var key := "%s:%d" % [gid, tier]
	if not _icons.has(key):
		_icons[key] = WeaponDesigns.mesh_icon(mesh(gid, tier), Basis.from_euler(Vector3(0.45, 0.6, 0.0)), 0.0)
	return _icons[key]


static func _build(gid: String, tier: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(gid) + tier
	match gid:
		"smoke":
			var shell: Color = [CLAY, Color(0.5, 0.5, 0.52), Color(0.16, 0.15, 0.17)][tier]
			mb.add_blob(PSXMat.flat(shell), Transform3D.IDENTITY, Vector3(0.045, 0.042, 0.045), rng, 0.08, 5, 7, 4.0)
			if tier >= 1:
				mb.add_cylinder(PSXMat.lit("metal", BRASS if tier == 1 else LACQUER), Transform3D(Basis(), Vector3(0, -0.008, 0)), 0.047, 0.047, 0.016, 8, 4.0, Color.WHITE, false, false)
			if tier == 2:
				for k in range(4):
					var a := k * TAU / 4.0
					mb.add_box(PSXMat.lit("metal", IRON), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.044, 0.0, sin(a) * 0.044)), Vector3(0.012, 0.012, 0.012), 4.0, Color.WHITE, false)
			var fuses := 2 if tier == 2 else 1
			for f in range(fuses):
				var off := Vector3((f - (fuses - 1) * 0.5) * 0.02, 0.04, 0)
				mb.add_tube(PSXMat.flat(Color(0.82, 0.76, 0.6)), MeshBuilder.curve_points(off, off + Vector3(0.006, 0.02, 0), off + Vector3(0.018, 0.032, 0.004), 4), 0.0045, 0.0035, 4)
		"tar":
			var body: Color = [Color(0.42, 0.3, 0.22), Color(0.36, 0.26, 0.2), IRON][tier]
			mb.add_cylinder(PSXMat.flat(body), Transform3D(Basis(), Vector3(0, -0.05, 0)), 0.035, 0.05, 0.05, 8, 4.0, Color.WHITE, false, true)
			mb.add_cylinder(PSXMat.flat(body), Transform3D(Basis(), Vector3(0, 0.0, 0)), 0.05, 0.022, 0.035, 8, 4.0, Color.WHITE, false, false)
			mb.add_cylinder(PSXMat.flat(Color(0.7, 0.55, 0.35)), Transform3D(Basis(), Vector3(0, 0.033, 0)), 0.02, 0.018, 0.02, 6, 4.0, Color.WHITE, true, false)
			# black pitch dribbled down from the cork
			mb.add_tube(PSXMat.flat(Color(0.05, 0.04, 0.04)), MeshBuilder.curve_points(Vector3(0.018, 0.03, 0), Vector3(0.04, 0.0, 0.01), Vector3(0.048, -0.03, 0.0), 4), 0.006, 0.004, 4)
			if tier == 1:
				for y in [-0.035, -0.012]:
					mb.add_cylinder(PSXMat.flat(Color(0.72, 0.62, 0.4)), Transform3D(Basis(), Vector3(0, y, 0)), 0.048, 0.05, 0.008, 8, 4.0, Color.WHITE, false, false)
			if tier == 2:
				mb.add_cylinder(PSXMat.lit("metal", LACQUER), Transform3D(Basis(), Vector3(0, -0.02, 0)), 0.05, 0.051, 0.012, 8, 4.0, Color.WHITE, false, false)
				for k in range(5):
					var a := k * TAU / 5.0
					var d := Vector3(cos(a), 0, sin(a))
					mb.add_cone(PSXMat.lit("metal", IRON), Transform3D(Basis(Vector3.UP.cross(d).normalized(), PI * 0.5), d * 0.048 + Vector3(0, -0.02, 0)), 0.007, 0.02, 4)
	return mb.commit()


## The pouch on the captain's back (the belt's three canisters): plain leather, Mk II's brass buckles, Mk III's
## red-lacquered caps (by the belt's best tier).
static func pouch(tier: int) -> ArrayMesh:
	var key := "pouch:%d" % tier
	if not _meshes.has(key):
		var mb := MeshBuilder.new()
		mb.add_box(PSXMat.flat(LEATHER), Transform3D.IDENTITY, Vector3(0.2, 0.07, 0.05), 4.0, Color.WHITE, false)
		var cap: Color = [Color(0.55, 0.42, 0.3), BRASS, LACQUER][tier]
		for k in range(3):
			var x := (k - 1) * 0.065
			mb.add_cylinder(PSXMat.lit("metal", IRON if tier == 2 else Color(0.5, 0.45, 0.4)), Transform3D(Basis(), Vector3(x, 0.0, 0.028)), 0.018, 0.018, 0.06, 6, 4.0, Color.WHITE, false, false)
			mb.add_cylinder(PSXMat.lit("metal", cap), Transform3D(Basis(), Vector3(x, 0.06, 0.028)), 0.02, 0.016, 0.014, 6, 4.0, Color.WHITE, true, false)
		if tier >= 1:
			mb.add_box(PSXMat.lit("metal", BRASS), Transform3D(Basis(), Vector3(0.0, 0.0, -0.002)), Vector3(0.03, 0.04, 0.056), 4.0, Color.WHITE, false)
		_meshes[key] = mb.commit()
	return _meshes[key]
