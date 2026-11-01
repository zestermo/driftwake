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
		"flash":
			var cap: Color = [Color(0.85, 0.85, 0.8), BRASS, LACQUER][tier]
			mb.add_blob(PSXMat.glow(Color(1.0, 1.0, 0.85), 0.8), Transform3D.IDENTITY, Vector3(0.036, 0.036, 0.036), rng, 0.05, 4, 6, 4.0)
			mb.add_cylinder(PSXMat.lit("metal", cap), Transform3D(Basis(), Vector3(0, 0.025, 0)), 0.03, 0.022, 0.025, 6, 4.0)
			mb.add_cylinder(PSXMat.lit("metal", cap), Transform3D(Basis(), Vector3(0, -0.05, 0)), 0.022, 0.03, 0.025, 6, 4.0, Color.WHITE, false, true)
			mb.add_tube(PSXMat.flat(Color(0.82, 0.76, 0.6)), MeshBuilder.curve_points(Vector3(0, 0.05, 0), Vector3(0.01, 0.07, 0), Vector3(0.02, 0.08, 0), 3), 0.004, 0.003, 4)
		"pepper":
			var paper: Color = [Color(0.9, 0.82, 0.6), Color(0.85, 0.35, 0.2), LACQUER][tier]
			mb.add_blob(PSXMat.flat(paper), Transform3D.IDENTITY, Vector3(0.045, 0.05, 0.045), rng, 0.15, 4, 6, 4.0)
			mb.add_cylinder(PSXMat.flat(Color(0.75, 0.62, 0.4)), Transform3D(Basis(), Vector3(0, 0.04, 0)), 0.018, 0.012, 0.03, 5, 4.0)
			if tier >= 1:
				mb.add_cylinder(PSXMat.lit("metal", BRASS), Transform3D(Basis(), Vector3(0, 0.035, 0)), 0.022, 0.022, 0.01, 6, 4.0, Color.WHITE, false)
		"star":
			var body: Color = [IRON, Color(0.35, 0.32, 0.3), Color(0.22, 0.2, 0.2)][tier]
			mb.add_blob(PSXMat.lit("metal", body), Transform3D.IDENTITY, Vector3(0.035, 0.035, 0.035), rng, 0.05, 4, 6, 4.0)
			var spikes: int = [6, 8, 10][tier]
			for k in range(spikes):
				var d := Vector3(cos(k * 2.4), sin(k * 1.7) * 0.8, sin(k * 2.4)).normalized()
				mb.add_cone(PSXMat.lit("metal", BRASS if tier == 1 else (LACQUER if tier == 2 else IRON)), Transform3D(Basis(Vector3.UP.cross(d).normalized() if absf(d.y) < 0.99 else Vector3.RIGHT, Vector3.UP.angle_to(d)), d * 0.03), 0.012, 0.035, 4)
		"caltrops":
			var pouch: Color = [LEATHER, Color(0.3, 0.2, 0.12), LACQUER][tier]
			mb.add_blob(PSXMat.flat(pouch), Transform3D.IDENTITY, Vector3(0.045, 0.04, 0.045), rng, 0.15, 4, 6, 4.0)
			for k in range(4):
				var d := Vector3(cos(k * 1.6), 0.9, sin(k * 1.6)).normalized()
				mb.add_cone(PSXMat.lit("metal", IRON), Transform3D(Basis(Vector3.UP.cross(d).normalized(), Vector3.UP.angle_to(d)), d * 0.035), 0.008, 0.03, 3)
		"grapple":
			var reel: Color = [Color(0.45, 0.33, 0.22), BRASS, LACQUER][tier]
			mb.add_cylinder(PSXMat.lit("metal", IRON), Transform3D(Basis(), Vector3(0, -0.02, 0)), 0.01, 0.01, 0.12, 5, 4.0)
			var prongs := 4 if tier == 2 else 3
			for k in range(prongs):
				var a := k * TAU / prongs
				var d := Vector3(cos(a), 0, sin(a))
				mb.add_tube(PSXMat.lit("metal", IRON), MeshBuilder.curve_points(Vector3(0, 0.1, 0), Vector3(0, 0.06, 0) + d * 0.06, Vector3(0, 0.11, 0) + d * 0.05, 4), 0.008, 0.005, 4)
			mb.add_cylinder(PSXMat.lit("metal", reel), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.035, -0.04, 0)), 0.035, 0.035, 0.07, 8, 4.0, Color.WHITE, true, true)
			mb.add_cylinder(PSXMat.lit("rope"), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.03, -0.04, 0)), 0.03, 0.03, 0.06, 8, 4.0, Color.WHITE, false, false)
		"spring_boots":
			var plate: Color = [Color(0.4, 0.28, 0.18), BRASS, LACQUER][tier]
			mb.add_box(PSXMat.flat(LEATHER), Transform3D(Basis(), Vector3(0, 0.05, 0.01)), Vector3(0.07, 0.04, 0.16), 4.0)
			mb.add_box(PSXMat.lit("metal", plate), Transform3D(Basis(), Vector3(0, 0.025, 0.01)), Vector3(0.075, 0.01, 0.17), 4.0, Color.WHITE, false)
			for z in [-0.04, 0.05]:
				var pts := PackedVector3Array()
				for i in range(13):
					var a := i * TAU / 6.0
					pts.append(Vector3(cos(a) * 0.022, 0.02 - i * 0.003, z + sin(a) * 0.022))
				mb.add_tube(PSXMat.lit("metal", Color(0.7, 0.7, 0.72)), pts, 0.004, 0.004, 3)
		"glider":
			var cloth: Color = [Color(0.88, 0.84, 0.72), Color(0.82, 0.78, 0.62), LACQUER][tier]
			mb.add_cylinder(PSXMat.lit("canvas", cloth), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.08, 0, 0)), 0.03, 0.03, 0.16, 7, 4.0, Color.WHITE, true, true)
			for x in [-0.05, 0.05]:
				mb.add_cylinder(PSXMat.lit("planks", Color(0.7, 0.55, 0.38)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.09, 0.0, x * 0.4)), 0.007, 0.007, 0.18, 4, 4.0)
			if tier >= 1:
				mb.add_cylinder(PSXMat.lit("metal", BRASS), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.01, 0, 0)), 0.033, 0.033, 0.015, 7, 4.0, Color.WHITE, false, false)
		"spike":
			var grip: Color = [LEATHER, BRASS, LACQUER][tier]
			mb.add_cone(PSXMat.lit("metal", IRON), Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0, 0)), 0.012, 0.11, 5)
			mb.add_cylinder(PSXMat.lit("metal", grip), Transform3D(Basis(), Vector3(0, 0, 0)), 0.016, 0.016, 0.07, 6, 4.0)
			var ring := PackedVector3Array()
			for i in range(9):
				var a := i * TAU / 8.0
				ring.append(Vector3(cos(a) * 0.022, 0.09 + sin(a) * 0.022, 0))
			mb.add_tube(PSXMat.lit("metal", IRON), ring, 0.004, 0.004, 4)
	return mb.commit()


## The pocket glider's wing as worn open over the captain (in their torso's space): canvas over two spars, a bar to
## hold; Mk II striped, Mk III red-lacquered with brass tips.
static func glider_wing(tier: int) -> ArrayMesh:
	var key := "wing:%d" % tier
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var cloth: Color = [Color(0.9, 0.86, 0.74), Color(0.86, 0.8, 0.62), Color(0.7, 0.16, 0.12)][tier]
	var cm := PSXMat.lit("canvas", cloth)
	var span: float = [1.1, 1.25, 1.4][tier]
	var y := 0.75
	for s in [-1.0, 1.0]:
		var tip := Vector3(s * span, y - 0.12, 0.35)
		mb.add_tri(cm, Vector3(0, y + 0.08, -0.45), tip, Vector3(0, y, 0.45), Vector3.UP, Vector3.UP, Vector3.UP,
			Vector2(0.5, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.UP)
		mb.add_tri(cm, Vector3(0, y + 0.08, -0.45), Vector3(0, y, 0.45), tip, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN,
			Vector2(0.5, 0), Vector2(0, 1), Vector2(1, 1), Color.WHITE, Vector3.DOWN)
		mb.add_tube(PSXMat.lit("planks", Color(0.6, 0.45, 0.3)), PackedVector3Array([Vector3(0, y + 0.09, -0.45), tip]), 0.015, 0.012, 4)
		if tier == 1:
			mb.add_tube(PSXMat.flat(Color(0.72, 0.16, 0.12)), PackedVector3Array([Vector3(0, y + 0.06, -0.15), tip * Vector3(0.9, 1.0, 0.9) + Vector3(0, 0.005, 0)]), 0.01, 0.01, 3)
		if tier == 2:
			mb.add_blob(PSXMat.lit("metal", BRASS), Transform3D(Basis(), tip), Vector3(0.03, 0.03, 0.03), RandomNumberGenerator.new(), 0.0, 3, 5, 4.0)
	mb.add_tube(PSXMat.lit("planks", Color(0.6, 0.45, 0.3)), PackedVector3Array([Vector3(0, y + 0.09, -0.45), Vector3(0, y, 0.45)]), 0.018, 0.018, 4)
	# the bar the hands hold, hung under it
	mb.add_tube(PSXMat.lit("metal", IRON), PackedVector3Array([Vector3(-0.3, 0.42, -0.1), Vector3(0.3, 0.42, -0.1)]), 0.012, 0.012, 4)
	for s in [-0.3, 0.3]:
		mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([Vector3(s, 0.42, -0.1), Vector3(s * 0.4, y, 0.0)]), 0.006, 0.006, 3)
	_meshes[key] = mb.commit()
	return _meshes[key]


## A part's (or "blueprint"'s) bag icon.
static func part_icon(id: String) -> Texture2D:
	var key := "part:" + id
	if not _icons.has(key):
		_icons[key] = WeaponDesigns.mesh_icon(part_mesh(id), Basis.from_euler(Vector3(0.5, 0.4, 0.0)), 0.0)
	return _icons[key]


static func part_mesh(id: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"black_powder":
			mb.add_blob(PSXMat.flat(Color(0.3, 0.27, 0.24)), Transform3D.IDENTITY, Vector3(0.05, 0.04, 0.05), rng, 0.15, 4, 6, 4.0)
			mb.add_cylinder(PSXMat.flat(Color(0.75, 0.62, 0.4)), Transform3D(Basis(), Vector3(0, 0.03, 0)), 0.012, 0.02, 0.03, 5, 4.0)
		"pitch":
			mb.add_cylinder(PSXMat.lit("", Color(0.06, 0.05, 0.05), {"roughness": 0.15}), Transform3D.IDENTITY, 0.055, 0.05, 0.03, 8, 4.0)
		"springs":
			mb.add_cylinder(PSXMat.lit("metal", Color(0.6, 0.6, 0.62)), Transform3D.IDENTITY, 0.045, 0.045, 0.03, 8, 4.0)
			for k in range(3):
				var pts := PackedVector3Array()
				for i in range(13):
					var a := i * TAU / 6.0
					pts.append(Vector3(cos(a) * 0.012 + (k - 1) * 0.026, 0.03 + i * 0.004, sin(a) * 0.012))
				mb.add_tube(PSXMat.lit("metal", BRASS), pts, 0.003, 0.003, 3)
		"brass":
			mb.add_cylinder(PSXMat.lit("metal", BRASS), Transform3D.IDENTITY, 0.045, 0.045, 0.02, 8, 4.0, Color.WHITE, true, true)
			mb.add_box(PSXMat.lit("metal", BRASS), Transform3D(Basis(), Vector3(0.05, 0.01, 0)), Vector3(0.05, 0.012, 0.03), 4.0)
		"lens":
			mb.add_cylinder(PSXMat.lit("metal", BRASS), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.05, 0.05, 0.015, 10, 4.0, Color.WHITE, false, false)
			mb.add_cylinder(PSXMat.glow(Color(0.7, 0.9, 1.0), 0.6), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.003)), 0.044, 0.044, 0.009, 10, 4.0, Color.WHITE, true, true)
		"ember_ore":
			mb.add_blob(PSXMat.flat(Color(0.3, 0.12, 0.1)), Transform3D.IDENTITY, Vector3(0.05, 0.04, 0.045), rng, 0.25, 4, 6, 4.0)
			mb.add_blob(PSXMat.glow(Color(1.0, 0.4, 0.12), 1.5), Transform3D(Basis(), Vector3(0.02, 0.02, 0.0)), Vector3(0.02, 0.018, 0.02), rng, 0.2, 3, 5, 4.0)
		"leviathan_scale":
			mb.add_blob(PSXMat.lit("", Color(0.2, 0.5, 0.55), {"roughness": 0.3}), Transform3D.IDENTITY, Vector3(0.07, 0.015, 0.06), rng, 0.1, 4, 7, 4.0)
		"blueprint":
			mb.add_cylinder(PSXMat.flat(Color(0.32, 0.5, 0.85)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.06, 0, 0)), 0.022, 0.022, 0.12, 7, 4.0, Color.WHITE, true, true)
			mb.add_cylinder(PSXMat.flat(Color(0.85, 0.2, 0.15)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.006, 0, 0)), 0.024, 0.024, 0.012, 7, 4.0, Color.WHITE, false, false)
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
