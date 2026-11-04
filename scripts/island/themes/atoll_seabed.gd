extends RefCounted
## The coral atoll's seabed dressed (1.30, Zach: "the ground looks very bare and boring"): never a bare stretch of sand
## under the water. Seagrass meadows sway over the lagoon floor in broad patches, coral rubble and boulders gather round
## the coral heads and along the reef, shells, starfish and urchins lie scattered, sponges stand up from the deeper
## floor, and bleached dead coral lies in patches of its own. The sand itself is atoll_seafloor (the beaches' palette,
## rippled) mottled by the terrain shader (PSXMat.terrain's "deep"). Each kind is a MultiMesh per CELL-metre cell placed
## at the cell's middle (its range is measured from there), the colour per instance, no collision, no shadows.
## Everything from the island's seed: the same floor on every screen. The build steps: AtollTheme.steps.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const REEF := preload("res://scripts/island/themes/atoll_reef.gd")

## The cells (m): the meadows' 60, the rest's 90 (fewer batches; their ranges reach past the cell's half).
const CELL := 60.0
const CELL_SMALL := 90.0
## Each kind: how many, the depth it lies in [least, most], how far it's drawn, its instance colours.
const KINDS := {
	"grass": {"n": 16000, "depth": [0.8, 9.0], "see": 95.0, "cols": [Color(0.55, 0.85, 0.5), Color(0.7, 0.9, 0.45), Color(0.45, 0.72, 0.42), Color(0.8, 0.85, 0.5)]},
	"rubble": {"n": 2600, "depth": [0.6, 30.0], "see": 100.0, "cols": [Color(0.95, 0.92, 0.86), Color(0.98, 0.84, 0.8), Color(0.82, 0.8, 0.76), Color(0.9, 0.86, 0.7)]},
	"rock": {"n": 480, "depth": [1.0, 32.0], "see": 150.0, "cols": [Color(1.0, 1.0, 1.0), Color(0.92, 0.95, 0.9), Color(1.0, 0.92, 0.9)]},
	"shell": {"n": 1600, "depth": [0.5, 12.0], "see": 100.0, "cols": [Color(1.0, 0.8, 0.75), Color(1.0, 0.95, 0.85), Color(0.95, 0.7, 0.45), Color(0.85, 0.75, 0.9)]},
	"star": {"n": 700, "depth": [0.8, 16.0], "see": 100.0, "cols": [Color(1.0, 0.5, 0.15), Color(0.95, 0.2, 0.18), Color(0.25, 0.45, 1.0), Color(0.75, 0.3, 0.85), Color(1.0, 0.85, 0.3)]},
	"urchin": {"n": 900, "depth": [1.2, 22.0], "see": 100.0, "cols": [Color(0.32, 0.12, 0.38), Color(0.16, 0.08, 0.12), Color(0.45, 0.12, 0.16)]},
	"sponge": {"n": 460, "depth": [2.2, 32.0], "see": 150.0, "cols": [Color(1.0, 0.82, 0.2), Color(1.0, 0.5, 0.2), Color(0.65, 0.3, 0.85), Color(0.95, 0.35, 0.35), Color(0.4, 0.75, 0.85)]},
	"dead": {"n": 620, "depth": [1.0, 14.0], "see": 150.0, "cols": [Color(0.92, 0.9, 0.86), Color(0.8, 0.78, 0.74), Color(0.95, 0.9, 0.82)]},
}
## The meadows: a noise over the floor, seagrass where it's over this (and the dead coral's patches where theirs is).
const MEADOW := 0.12
const DEAD := 0.38
## Things that come in clumps: how many round each spot and how far out.
const CLUMP := {"grass": [8, 14, 2.6], "urchin": [3, 7, 1.0], "dead": [3, 6, 1.6], "rubble": [2, 4, 0.9]}

static var _meshes := {}


## [step name, Callable]: a step to plan each kind (data, its own stream), then the MultiMeshes in two steps.
static func steps(isl) -> Array:
	var st := {"lists": {}}
	var out: Array = [["atoll seabed plan", func(): await _start(isl, st)]]
	for kind in KINDS:
		out.append(["atoll seabed plan", func(): await plan_kind(isl, st, kind)])
	out.append(["atoll seabed plan", func(): _basin_floor(isl, st)])
	out.append(["atoll seabed", func(): await _build(isl, st, ["grass", "rubble", "rock", "shell"])])
	out.append(["atoll seabed", func(): await _build(isl, st, ["star", "urchin", "sponge", "dead"])])
	return out


## What every kind's plan reads: the meadows' and dead patches' noises, the lagoon's edge by bearing.
static func _start(isl, st: Dictionary) -> void:
	var L = isl._theme.LAND_FEATURES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_seabed"])
	var meadow := FastNoiseLite.new()
	meadow.seed = rng.randi()
	meadow.frequency = 0.018
	meadow.fractal_octaves = 3
	var dead := FastNoiseLite.new()
	dead.seed = rng.randi()
	dead.frequency = 0.03
	var inner := PackedFloat32Array()
	for k in range(128):
		inner.append(float(L.ring_r(isl, TAU * k / 128.0)[1]))
		await GenIsland.breathe()
	st["meadow"] = meadow
	st["dead"] = dead
	st["inner"] = inner


## One kind's transforms by cell into st.lists: {"<kind>_<cx>_<cz>": [[Transform3D, Color], ...]}.
static func plan_kind(isl, st: Dictionary, kind: String) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_seabed", kind])
	var meadow: FastNoiseLite = st["meadow"]
	var dead: FastNoiseLite = st["dead"]
	var inner: PackedFloat32Array = st["inner"]
	var lists: Dictionary = st["lists"]
	var reach := float(isl.radius) + D.REEF_FLAT + D.DROP
	var e: Dictionary = KINDS[kind]
	var want := int(e["n"])
	var made := 0
	var tries := 0
	while made < want and tries < want * 6:
		tries += 1
		if tries % 64 == 0:
			await GenIsland.breathe()
		var q := Vector2.from_angle(rng.randf() * TAU) * reach * sqrt(rng.randf())
		var h: float = isl.hv(q)
		var depth := -h
		if depth < float(e["depth"][0]) or depth > float(e["depth"][1]):
			continue
		var a := fposmod(q.angle(), TAU)
		var in_lagoon := q.length() < inner[int(a / TAU * 128.0) % 128]
		var head: bool = in_lagoon and L.on_head(lp, q)
		if not _likes(kind, rng, in_lagoon, head, meadow.get_noise_2d(q.x, q.y), dead.get_noise_2d(q.x, q.y), depth):
			continue
		var clump: Array = CLUMP.get(kind, [1, 1, 0.0])
		for c in range(rng.randi_range(int(clump[0]), int(clump[1]))):
			var p := q if c == 0 else q + Vector2.from_angle(rng.randf() * TAU) * float(clump[2]) * sqrt(rng.randf())
			var ph: float = isl.hv(p) if c > 0 else h
			if -ph < float(e["depth"][0]) * 0.8:
				continue
			_put(lists, kind, p, ph, rng, e)
			made += 1


## Whether a kind takes a tried spot: grass in the meadows, dead coral in its patches, rubble and boulders mostly round
## the heads and outside the ring, the rest anywhere with a lean.
static func _likes(kind: String, rng: RandomNumberGenerator, in_lagoon: bool, head: bool, m: float, dd: float, depth: float) -> bool:
	match kind:
		"grass":
			return m > MEADOW and not head
		"dead":
			return dd > DEAD
		"rubble":
			return rng.randf() < (1.0 if head or not in_lagoon else 0.4)
		"rock":
			return rng.randf() < (1.0 if head or not in_lagoon else 0.3)
		"shell":
			return m < MEADOW + 0.2
		"urchin":
			return rng.randf() < (1.0 if head or depth > 6.0 else 0.35)
		"sponge":
			return rng.randf() < (1.0 if depth > 5.0 else 0.4)
	return true


## The deep basin's floor (the blue hole grown: land "hole"): more rubble, boulders and sponges down there.
static func _basin_floor(isl, st: Dictionary) -> void:
	var lists: Dictionary = st["lists"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_seabed", "basin"])
	var hole: Array = isl.land_plan["hole"]
	var c: Vector2 = hole[0]
	var r: float = hole[1]
	for k in range(900):
		var q := c + Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf())
		var h: float = isl.hv(q)
		var kind: String = ["rubble", "rubble", "rock", "sponge", "urchin", "star", "dead", "shell"][k % 8]
		_put(lists, kind, q, h, rng, KINDS[kind])


static func _put(lists: Dictionary, kind: String, q: Vector2, h: float, rng: RandomNumberGenerator, e: Dictionary) -> void:
	var s: float
	match kind:
		"rock":
			s = rng.randf_range(0.6, 1.9)
		"sponge", "dead":
			s = rng.randf_range(0.7, 1.6)
		"grass":
			s = rng.randf_range(0.9, 1.8)
		_:
			s = rng.randf_range(0.7, 1.3)
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
	var cols: Array = e["cols"]
	var cw := CELL if kind == "grass" else CELL_SMALL
	var cell := Vector2i(floori(q.x / cw), floori(q.y / cw))
	var key := "%s_%d_%d" % [kind, cell.x, cell.y]
	if not lists.has(key):
		lists[key] = []
	var sink := 0.15 * s if kind == "rock" else 0.02
	(lists[key] as Array).append([Transform3D(b.scaled(Vector3.ONE * s), Vector3(q.x, h - sink, q.y)), (cols[rng.randi() % cols.size()] as Color).lerp(Color.WHITE, rng.randf() * 0.15)])


static func _build(isl, st: Dictionary, kinds: Array) -> void:
	if _meshes.is_empty():
		_make_meshes()
	var node: Node3D = isl.get_node_or_null("AtollSeabed")
	if node == null:
		node = Node3D.new()
		node.name = "AtollSeabed"
		isl.add_child(node)
	var lists: Dictionary = st["lists"]
	for key in lists:
		var parts: PackedStringArray = (key as String).split("_")
		if not kinds.has(parts[0]):
			continue
		var cw := CELL if parts[0] == "grass" else CELL_SMALL
		var mid := Vector3((int(parts[1]) + 0.5) * cw, 0.0, (int(parts[2]) + 0.5) * cw)
		var items: Array = lists[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[parts[0]]
		mm.instance_count = items.size()
		for i in range(items.size()):
			var xf: Transform3D = items[i][0]
			xf.origin -= mid
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, items[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d" % [parts[0].capitalize(), node.get_child_count()]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(KINDS[parts[0]]["see"])
		node.add_child(mmi)
		mmi.position = mid
		await GenIsland.breathe()


# --------------------------------------------------------------------------
# The meshes (built once, white: the instance colour tints them)
# --------------------------------------------------------------------------
static func _make_meshes() -> void:
	var mat := PSXMat.lit("", Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var mb := MeshBuilder.new()
	for k in range(4):
		var o := Vector3(rng.randf_range(-0.3, 0.3), 0.04, rng.randf_range(-0.3, 0.3))
		mb.add_blob(mat, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), o), Vector3(rng.randf_range(0.1, 0.22), rng.randf_range(0.06, 0.12), rng.randf_range(0.08, 0.18)), rng, 0.3, 2, 5, 0.5,
			Color.WHITE.darkened(rng.randf() * 0.25))
	_meshes["rubble"] = mb.commit()
	mb = MeshBuilder.new()
	var stone := PSXMat.lit("atoll_coral", Color.WHITE)
	mb.add_blob(stone, Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.75, 0.48, 0.62), rng, 0.28, 3, 7, 0.5, Color.WHITE, -0.1)
	mb.add_blob(stone, Transform3D(Basis(), Vector3(0.55, 0.12, 0.3)), Vector3(0.32, 0.22, 0.3), rng, 0.25, 2, 6)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(-0.2, 0.7, 0.1)), Vector3(0.22, 0.12, 0.2), rng, 0.2, 2, 6, 0.5, Color(1.0, 0.6, 0.66))
	_meshes["rock"] = mb.commit()
	mb = MeshBuilder.new()
	var blade := PSXMat.cutout("atoll_seagrass", Color.WHITE, 0.07, 0.6)
	mb.add_cross_cards(blade, Transform3D(), 0.75, 0.6, 3)
	_meshes["grass"] = mb.commit()
	mb = MeshBuilder.new()
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.08, 0.06, 0.15), rng, 0.1, 2, 6)
	mb.add_cone(mat, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.05, 0.12)), 0.06, 0.12, 5)
	mb.add_blob(mat, Transform3D(Basis(Vector3.UP, 1.2), Vector3(0.25, 0.03, -0.1)), Vector3(0.07, 0.035, 0.05), rng, 0.05, 2, 5, 0.5, Color(1.0, 0.9, 0.8))
	_meshes["shell"] = mb.commit()
	mb = MeshBuilder.new()
	for k in range(5):
		var a := TAU * k / 5.0
		var arm := Basis(Vector3.UP, a)
		mb.add_cone(mat, Transform3D(arm * Basis(Vector3.RIGHT, PI * 0.5), arm * Vector3(0, 0.025, -0.02)), 0.045, 0.2, 4)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.06, 0.03, 0.06), rng, 0.0, 2, 5)
	_meshes["star"] = mb.commit()
	mb = MeshBuilder.new()
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(0.1, 0.08, 0.1), rng, 0.05, 2, 6)
	for k in range(14):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1.0), rng.randf_range(-1, 1)).normalized()
		mb.add_cone(mat, Transform3D(Basis(Quaternion(Vector3.UP, dir)), Vector3(0, 0.08, 0) + dir * 0.08), 0.015, 0.16, 3)
	_meshes["urchin"] = mb.commit()
	mb = MeshBuilder.new()
	for k in range(3):
		var o := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var hh := rng.randf_range(0.35, 0.8)
		mb.add_cylinder(mat, Transform3D(Basis(), o + Vector3(0, hh * 0.5, 0)), 0.1, 0.16, hh, 6, 0.5, Color.WHITE, false)
		mb.add_cylinder(mat, Transform3D(Basis(), o + Vector3(0, hh - 0.03, 0)), 0.13, 0.13, 0.02, 6, 0.5, Color(0.35, 0.3, 0.3))
	_meshes["sponge"] = mb.commit()
	mb = MeshBuilder.new()
	REEF._branches(mb, mat, rng, 0.7, Color.WHITE)
	_meshes["dead"] = mb.commit()
