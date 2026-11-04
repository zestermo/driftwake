extends RefCounted
## The coral atoll's reef under the water (1.28.1, Zach: "a dense fun area to explore deeply"): coral gardens over the
## lagoon floor, thickest on the coral heads and along the reef flat and drop-off outside the ring (branch and brain
## coral, sea fans, tube sponges, anemones, kelp), giant clams on the deeper floor to open for a Lagoon Pearl, coral
## outcrops to break a Coral Spar off (the skimmer's atoll parts: GadgetData), and big life gliding over it all: eagle
## rays and sea turtles on the shoal shader. The gardens are MultiMeshes by kind, colour and CELL-metre cell, each at its
## cell's middle so its range (SEE) is measured from where its corals are (no collision), the clams and outcrops Interactables usable in the water, each taken once (GameManager.opened).
## Everything comes from the island's seed: the same reef on every screen. The build step: AtollTheme.steps.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const SHOALS := preload("res://scripts/island/themes/atoll_shoals.gd")
const DIVE := preload("res://scripts/swim/dive_sites.gd")

## How far a garden is drawn (m), how many places are tried, and the most corals put down.
const SEE := 110.0
const CELL := 60.0
const TRIES := 9000
## The garden patches: how many, how far apart at least, their radius and how many corals each; the scatter between.
const PATCHES := 75
const PATCH_GAP := 22.0
const PATCH_R := [4.0, 9.0]
const PATCH_N := [30, 60]
const SCATTER := 900
## The chance a tried spot gets a garden patch: on a coral head, on the lagoon floor, on the reef outside the ring.
const ON_HEAD := 0.85
const ON_FLOOR := 0.32
const ON_REEF := 0.55
## Corals by kind: [name, weight on a head, on the floor, on the reef, two colours].
const KINDS := [
	["branch", 3.0, 1.0, 2.0, [Color(1.0, 0.55, 0.62), Color(0.95, 0.82, 0.72)]],
	["brain", 2.0, 1.5, 2.0, [Color(0.85, 0.75, 0.35), Color(0.55, 0.78, 0.5)]],
	["fan", 1.5, 0.4, 2.5, [Color(0.75, 0.35, 0.85), Color(1.0, 0.45, 0.3)]],
	["tube", 1.5, 0.8, 1.5, [Color(1.0, 0.65, 0.2), Color(0.45, 0.6, 1.0)]],
	["anemone", 1.0, 1.0, 0.6, [Color(1.0, 0.4, 0.55), Color(0.55, 1.0, 0.85)]],
	["kelp", 0.3, 1.6, 2.0, [Color(0.35, 0.6, 0.25), Color(0.55, 0.62, 0.22)]],
]
## (1.30) The harvest (harvest()): how many of each, from the island's seed. (1.28.1 had 8 clams and 10 outcrops: a
## skimmer's parts were near impossible to find.)
const CLAMS := [12, 18]
const OUTCROPS := [18, 26]
const PENS := [10, 16]
const URCHINS := [8, 12]
const BEDS := [4, 6]
## Swim-through arches of coral rock on the patches, and moray eels in crevices on others (and the basin's walls).
const ARCHES := 6
const MORAYS := 7
const BASIN_MORAYS := 6
## What each gives: [item id, least, most]; ids nobody has made yet (the skimmer's parts before they land) are skipped.
const CLAM_LOOT := [["lagoon_pearl", 1, 1], ["pearl", 0, 1]]
const SPAR_LOOT := [["coral_spar", 2, 2]]
const PEN_LOOT := [["sea_silk", 1, 1]]
const URCHIN_LOOT := [["sea_urchin", 2, 4]]

static var _meshes := {}


static func build(isl) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_reef"])
	var node := Node3D.new()
	node.name = "AtollReef"
	isl.add_child(node)
	if _meshes.is_empty():
		_make_meshes()
	var reach := float(isl.radius) + D.REEF_FLAT + D.DROP
	var inner := PackedFloat32Array()
	for k in range(128):
		inner.append(float(L.ring_r(isl, TAU * k / 128.0)[1]))
	var in_lagoon := func(q: Vector2) -> bool: return q.length() < inner[int(fposmod(q.angle(), TAU) / TAU * 128.0) % 128]
	# the gardens: dense patches (on the heads, along the reef, now and then on the lagoon floor) and a scatter between
	var lists := {}
	var centres: Array = []
	for i in range(TRIES):
		if centres.size() >= PATCHES:
			break
		if i % 200 == 0:
			await GenIsland.breathe()
		var q := Vector2.from_angle(rng.randf() * TAU) * reach * sqrt(rng.randf())
		var h: float = isl.hv(q)
		if h > -0.9 or h < -12.0:
			continue
		var inside: bool = in_lagoon.call(q)
		var head := inside and h > D.HEADS_Y - 0.6
		if rng.randf() > (ON_HEAD if head else (ON_FLOOR if inside else ON_REEF)):
			continue
		if centres.any(func(c): return Vector2(c[0].x, c[0].z).distance_to(q) < PATCH_GAP):
			continue
		centres.append([Vector3(q.x, h, q.y), 1 if head else (2 if inside else 3)])
	for c in centres:
		var at: Vector3 = c[0]
		var r := rng.randf_range(PATCH_R[0], PATCH_R[1])
		for k in range(rng.randi_range(PATCH_N[0], PATCH_N[1])):
			var off := Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf())
			var q := Vector2(at.x, at.z) + off
			var h: float = isl.hv(q)
			if h > -0.75:
				continue
			_put(lists, rng, int(c[1]), q, h, rng.randf_range(0.8, 2.2) * (1.0 - 0.4 * off.length() / r))
		await GenIsland.breathe()
	for i in range(SCATTER):
		var q := Vector2.from_angle(rng.randf() * TAU) * reach * sqrt(rng.randf())
		var h: float = isl.hv(q)
		if h > -0.75 or h < -16.0:
			continue
		_put(lists, rng, 2 if in_lagoon.call(q) else 3, q, h, rng.randf_range(0.6, 1.4))
	for key in lists:
		var parts: PackedStringArray = (key as String).split("_")
		var mid := Vector3((int(parts[2]) + 0.5) * CELL, 0.0, (int(parts[3]) + 0.5) * CELL)
		_garden(node, _meshes["%s_%s" % [parts[0], parts[1]]], lists[key], mid)
		await GenIsland.breathe()
	node.set_meta("centres", centres)
	# swim-through arches and moray crevices on the patches (the harvest's step puts its clams and spars on them too)
	for i in range(mini(ARCHES, centres.size())):
		var c: Vector3 = centres[(i * 11 + 5) % centres.size()][0]
		_arch(node, c, rng, isl)
	for i in range(mini(MORAYS, centres.size())):
		var c: Vector3 = centres[(i * 13 + 7) % centres.size()][0]
		var q := Vector2(c.x, c.z) + Vector2.from_angle(rng.randf() * TAU) * 3.0
		var m := Moray.new()
		m.name = "Moray%d" % i
		node.add_child(m)
		m.position = Vector3(q.x, isl.hv(q), q.y)
		m.rotation.y = rng.randf() * TAU
	# the big life: eagle rays and sea turtles gliding round the lagoon
	for i in range(4):
		var a := rng.randf() * TAU
		var q := Vector2.from_angle(a) * float(L.ring_r(isl, a)[1]) * rng.randf_range(0.2, 0.8)
		var h: float = isl.hv(q)
		if h > -1.8:
			continue
		var turtle := i % 2 == 1
		SHOALS._add(node, _meshes["turtle" if turtle else "ray"], 0, Vector3(q.x, h + 0.9, q.y), rng.randi_range(1, 3), rng.randf_range(7.0, 14.0), 0.5,
			Color(0.5, 0.42, 0.28) if turtle else Color(0.22, 0.26, 0.32), rng, SEE)


## (1.30) What the reef gives, spread over the lagoon's patches and the deep basin (a step after the basin's): giant
## clams (a Lagoon Pearl), coral outcrops (two Coral Spar), pen shells (Sea-silk: their threads), urchin clusters,
## oyster beds and sponge gardens (DiveSites'). Seeded pools, nothing guaranteed but plenty: a captain who explores the
## lagoon and the basin for a quarter of an hour finds a Mk I skimmer's parts. Each glints (Glints) and the clams'
## pearls, the spars' tips and the shells' silk glow, so they read through the water. Each taken once per save.
static func harvest(isl) -> void:
	var L = isl._theme.LAND_FEATURES
	var lp: Dictionary = isl.land_plan
	var node: Node3D = isl.get_node("AtollReef")
	var basin: Node3D = isl.get_node("AtollBasin")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_harvest"])
	var sid := int(isl.node["seed"])
	var centres: Array = node.get_meta("centres")
	var deep: Array = centres.filter(func(c): return (c[0] as Vector3).y < -1.6).map(func(c): return Vector2((c[0] as Vector3).x, (c[0] as Vector3).z))
	var high: Array = centres.filter(func(c): return int(c[1]) != 2).map(func(c): return Vector2((c[0] as Vector3).x, (c[0] as Vector3).z))
	var hc: Vector2 = lp["hole"][0]
	var ledge: Vector2 = L.basin_ledge(lp)
	var on_ledge := func() -> Vector2:
		var a := rng.randf() * TAU
		return hc + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * (ledge.x + rng.randf_range(-0.04, 0.03))
	var on_floor := func() -> Vector2:
		var a := rng.randf() * TAU
		return hc + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * rng.randf_range(0.1, 0.5)
	var pillars: Array = basin.get_meta("pillars")
	var caves: Array = basin.get_meta("caves")
	var glints := Glints.new()
	glints.name = "Glints"
	node.add_child(glints)
	glints.centre = Vector3.ZERO
	glints.reach = float(isl.radius) + 60.0
	var put := func(q: Vector2, kind: String, i: int) -> void:
		var at := Vector3(q.x, isl.hv(q), q.y)
		match kind:
			"clam":
				glints.add(_clam(node, at, "atoll%d_clam%d" % [sid, i], rng), Color(1.0, 0.9, 0.95))
			"spar":
				glints.add(_outcrop(node, at, "atoll%d_spar%d" % [sid, i], rng), Color(1.0, 0.7, 0.8))
			"pen":
				glints.add(_pen(node, at, "atoll%d_pen%d" % [sid, i], rng), Color(1.0, 0.85, 0.4))
			"urchin":
				glints.add(_urchins(node, at, "atoll%d_urchin%d" % [sid, i], rng), Color(0.85, 0.6, 1.0))
	# giant clams: on the lagoon's deeper patches, the basin's ledge and floor, one in each cave
	var n := rng.randi_range(CLAMS[0], CLAMS[1])
	for i in range(n):
		var q: Vector2
		if i < caves.size():
			q = caves[i]
		elif i % 2 == 0 and not deep.is_empty():
			q = (deep[(i * 7) % deep.size()] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * 1.8
		else:
			q = on_ledge.call() if i % 3 != 0 else on_floor.call()
		put.call(q, "clam", i)
		await GenIsland.breathe()
	# coral outcrops: on the heads and the reef, at the basin's pillars' feet and along its ledge
	n = rng.randi_range(OUTCROPS[0], OUTCROPS[1])
	for i in range(n):
		var q: Vector2
		if i % 2 == 0 and not high.is_empty():
			q = (high[(i * 5 + 3) % high.size()] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * 1.2
		elif i % 4 == 1 and not pillars.is_empty():
			q = (pillars[(i / 4) % pillars.size()] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * 4.6
		else:
			q = on_ledge.call()
		put.call(q, "spar", i)
		await GenIsland.breathe()
	# pen shells: standing in the lagoon's floor patches (seagrass country) and on the basin's ledge and floor
	n = rng.randi_range(PENS[0], PENS[1])
	for i in range(n):
		var q: Vector2
		if i % 2 == 0 and not deep.is_empty():
			q = (deep[(i * 3 + 1) % deep.size()] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * 3.0
		else:
			q = on_ledge.call() if i % 3 == 1 else on_floor.call()
		put.call(q, "pen", i)
		await GenIsland.breathe()
	n = rng.randi_range(URCHINS[0], URCHINS[1])
	for i in range(n):
		var q: Vector2 = (high[(i * 11 + 2) % high.size()] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * 2.0 if i % 2 == 0 and not high.is_empty() else on_ledge.call()
		put.call(q, "urchin", i)
		await GenIsland.breathe()
	# DiveSites' oyster beds and sponge gardens on the basin's ledge
	for i in range(rng.randi_range(BEDS[0], BEDS[1])):
		var q: Vector2 = on_ledge.call()
		var key := "atoll%d_beds%d" % [sid, i]
		var e: Array = DIVE.oyster_bed(node, isl.to_global(Vector3(q.x, isl.hv(q), q.y)), key, rng) if i % 2 == 0 else DIVE.reef_garden(node, isl.to_global(Vector3(q.x, isl.hv(q), q.y)), key, rng)
		if node.get_node("/root/GameManager").opened.has(key):
			((e[0] as Node).get_node("Take") as Interactable).enabled = false
			if e[2]:
				(e[2] as Node3D).visible = false
	# morays in the basin's walls, spear spots by its pillars
	for i in range(BASIN_MORAYS):
		var a := TAU * i / BASIN_MORAYS + rng.randf_range(-0.3, 0.3)
		var q := hc + Vector2.from_angle(a) * float(L.basin_r(lp, a)) * rng.randf_range(0.66, 0.72)
		var m := Moray.new()
		m.name = "Moray%d" % (MORAYS + i)
		node.add_child(m)
		m.position = Vector3(q.x, isl.hv(q), q.y)
		m.rotation.y = atan2(q.x - hc.x, q.y - hc.y)
	for i in range(mini(3, pillars.size())):
		var q: Vector2 = pillars[i]
		AtollSpots.add_marker(node, {"at": Vector3(q.x, isl.hv(q) + 4.0, q.y), "kind": "spear", "where": "basin", "depth": -float(isl.hv(q)), "r": 14.0}, 0)


## One MultiMesh of a coral kind and colour over one cell, placed at the cell's middle `mid`.
static func _garden(node: Node3D, mesh: Mesh, xfs: Array, mid: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		var xf: Transform3D = xfs[i]
		xf.origin -= mid
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Corals%d" % node.get_child_count()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = SEE
	node.add_child(mmi)
	mmi.position = mid


## A giant clam half open on the floor, a pearl glowing inside: F to take it (once).
static func _clam(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Clam_" + key
	node.add_child(holder)
	holder.position = at
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	var shell := PSXMat.lit("", Color(0.92, 0.88, 0.8))
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	mb.add_blob(shell, Transform3D(b, Vector3(0, 0.12, 0)), Vector3(0.75, 0.25, 0.5), rng, 0.12, 3, 8)
	mb.add_blob(shell, Transform3D(b * Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.32, 0) + b * Vector3(0, 0, 0.22)), Vector3(0.75, 0.22, 0.5), rng, 0.12, 3, 8)
	mb.add_blob(PSXMat.glow(Color(0.25, 0.8, 1.0), 0.45), Transform3D(b, Vector3(0, 0.24, -0.05)), Vector3(0.66, 0.08, 0.4), rng, 0.05, 2, 8)
	holder.scale = Vector3.ONE * 1.35
	var m := mb.to_instance("Clam")
	DIVE._quiet(m)
	holder.add_child(m)
	var pearl := MeshBuilder.new()
	pearl.add_blob(PSXMat.glow(Color(1.0, 0.95, 0.88), 0.7), Transform3D(Basis(), Vector3(0, 0.3, -0.05)), Vector3.ONE * 0.09, rng, 0.0, 3, 6)
	var pm := pearl.to_instance("Pearl")
	DIVE._quiet(pm)
	pm.visible = not opened
	holder.add_child(pm)
	var it := DIVE._pickup_area(holder, "Open the giant clam", 1.6)
	it.interacted.connect(func(player: Player): _take(player, key, CLAM_LOOT, "The clam gives up its pearl.", pm))
	return pm


## A coral outcrop of pale branching coral on a head: F to break a spar off (once). It glows pale, its spar pink.
static func _outcrop(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Spar_" + key
	node.add_child(holder)
	holder.position = at
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	_branches(mb, PSXMat.glow(Color(1.0, 0.86, 0.88), 0.3), rng, 2.0, Color.WHITE)
	holder.scale = Vector3.ONE * 1.2
	var m := mb.to_instance("Outcrop")
	DIVE._quiet(m)
	holder.add_child(m)
	var tip := MeshBuilder.new()
	tip.add_tube(PSXMat.glow(Color(1.0, 0.72, 0.8), 0.6), PackedVector3Array([Vector3(0.3, 0.2, 0.0), Vector3(0.45, 0.9, 0.1), Vector3(0.5, 1.6, 0.05)]), 0.09, 0.04, 4, 1.0)
	var tm := tip.to_instance("Spar")
	DIVE._quiet(tm)
	tm.visible = not opened
	holder.add_child(tm)
	var it := DIVE._pickup_area(holder, "Break off a coral spar", 1.8)
	it.interacted.connect(func(player: Player): _take(player, key, SPAR_LOOT, "A spar of coral snaps off clean.", tm))
	return tm


## A pen shell: a tall fan-shaped bivalve standing half buried, a tuft of golden threads at its foot (the sea-silk):
## F to cut the silk (once).
static func _pen(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pen_" + key
	node.add_child(holder)
	holder.position = at
	holder.rotation.y = rng.randf() * TAU
	holder.scale = Vector3.ONE * 1.5
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	var shell := PSXMat.lit("", Color.WHITE)
	var col := Color(0.9, 0.74, 0.62).lerp(Color(1.0, 0.86, 0.8), rng.randf())
	for s in [-1.0, 1.0]:
		var v := PackedVector3Array([Vector3(0, -0.1, 0), Vector3(s * 0.05, 0.3, 0.02), Vector3(s * 0.09, 0.6, 0.04), Vector3(s * 0.08, 0.85, 0.03)])
		mb.add_tube(shell, v, 0.06, 0.2, 5, 1.0, col.darkened(0.15 if s > 0 else 0.0), false, true, true)
	for k in range(5):
		mb.add_box(shell, Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2)), Vector3(0, 0.15 + k * 0.15, 0.0)), Vector3(0.02, 0.012, 0.3 + k * 0.06), 0.5, col.lightened(0.25))
	var m := mb.to_instance("Shell")
	DIVE._quiet(m)
	holder.add_child(m)
	var silk := MeshBuilder.new()
	var gold := PSXMat.glow(Color(1.0, 0.82, 0.38), 0.7)
	for k in range(7):
		var a := rng.randf() * TAU
		silk.add_tube(gold, PackedVector3Array([Vector3(0, 0.02, 0), Vector3(cos(a) * 0.18, 0.08, sin(a) * 0.18), Vector3(cos(a) * 0.32, 0.03, sin(a) * 0.32)]), 0.018, 0.01, 3)
	var sm := silk.to_instance("Silk")
	DIVE._quiet(sm)
	sm.visible = not opened
	holder.add_child(sm)
	var it := DIVE._pickup_area(holder, "Cut the pen shell's silk", 1.6)
	it.interacted.connect(func(player: Player): _take(player, key, PEN_LOOT, "The pen shell's golden threads come away in a skein.", sm))
	return sm


## A cluster of long-spined urchins on a lump of rock: F to gather them (once).
static func _urchins(node: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Urchins_" + key
	node.add_child(holder)
	holder.position = at
	var opened: bool = node.get_node("/root/GameManager").opened.has(key)
	var mb := MeshBuilder.new()
	mb.add_blob(PSXMat.lit("atoll_coral"), Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(0.8, 0.4, 0.7), rng, 0.25, 3, 7, 0.5, Color(1.25, 1.2, 1.15))
	var m := mb.to_instance("Rock")
	DIVE._quiet(m)
	holder.add_child(m)
	var ub := MeshBuilder.new()
	var spine := PSXMat.lit("", Color.WHITE)
	var body := PSXMat.glow(Color(0.6, 0.28, 0.85), 0.6)
	holder.scale = Vector3.ONE * 1.3
	for k in range(6):
		var a := rng.randf() * TAU
		var c := Vector3(cos(a) * rng.randf_range(0.1, 0.5), 0.45, sin(a) * rng.randf_range(0.1, 0.45))
		ub.add_blob(body, Transform3D(Basis(), c), Vector3.ONE * 0.11, rng, 0.05, 2, 6)
		for j in range(10):
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-1, 1)).normalized()
			ub.add_tube(spine, PackedVector3Array([c, c + d * 0.42]), 0.016, 0.004, 3, 1.0, Color(0.25, 0.1, 0.28))
	var um := ub.to_instance("Urchins")
	DIVE._quiet(um)
	um.visible = not opened
	holder.add_child(um)
	var it := DIVE._pickup_area(holder, "Gather the urchins", 1.6)
	it.interacted.connect(func(player: Player): _take(player, key, URCHIN_LOOT, "You pry the urchins off the rock, carefully.", um))
	return um


## A swim-through arch: two pillars of coral rock and a crusted span over them, solid, tall enough to swim under.
static func _arch(node: Node3D, at: Vector3, rng: RandomNumberGenerator, isl) -> void:
	var body := StaticBody3D.new()
	body.name = "Arch%d" % node.get_child_count()
	node.add_child(body)
	body.position = at
	body.rotation.y = rng.randf() * TAU
	var h := clampf(-at.y - 0.6, 1.8, 4.0)
	var gap := rng.randf_range(2.2, 3.0)
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("", Color(0.78, 0.7, 0.68))
	var crust := PSXMat.lit("", Color.WHITE)
	for sx in [-1.0, 1.0]:
		mb.add_blob(rock, Transform3D(Basis(), Vector3(sx * gap, h * 0.5, 0)), Vector3(0.9, h * 0.6, 1.0), rng, 0.2, 4, 7)
		DIVE._box_col(body, Vector3(sx * gap, h * 0.5, 0), Vector3(1.4, h, 1.6))
	mb.add_blob(rock, Transform3D(Basis(), Vector3(0, h, 0)), Vector3(gap + 1.0, 0.55, 1.0), rng, 0.2, 3, 8)
	DIVE._box_col(body, Vector3(0, h, 0), Vector3(gap * 2.0 + 1.4, 0.8, 1.6))
	for k in range(10):
		var o := Vector3(rng.randf_range(-gap - 0.6, gap + 0.6), h + 0.45, rng.randf_range(-0.6, 0.6))
		mb.add_blob(crust, Transform3D(Basis(), o), Vector3.ONE * rng.randf_range(0.15, 0.3), rng, 0.1, 2, 6, 0.5,
			[Color(1.0, 0.55, 0.62), Color(0.75, 0.35, 0.85), Color(1.0, 0.75, 0.25)][k % 3])
	var mi := mb.to_instance("Arch")
	DIVE._quiet(mi)
	body.add_child(mi)


## One coral at `q` (ground height h), its kind picked by where it is (`col`: 1 a head, 2 the floor, 3 the reef).
static func _put(lists: Dictionary, rng: RandomNumberGenerator, col: int, q: Vector2, h: float, s: float) -> void:
	var tot := 0.0
	for k in KINDS:
		tot += float(k[col])
	var x := rng.randf() * tot
	var ki := 0
	while ki < KINDS.size() - 1 and x > float(KINDS[ki][col]):
		x -= float(KINDS[ki][col])
		ki += 1
	var cell := Vector2i(floori(q.x / CELL), floori(q.y / CELL))
	var key := "%d_%d_%d_%d" % [ki, rng.randi() % 2, cell.x, cell.y]
	if not lists.has(key):
		lists[key] = []
	(lists[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, h - 0.05, q.y)))


## Take `table`'s roll once for `key` (only items the game has), the shown piece hidden after.
static func _take(player: Player, key: String, table: Array, line: String, shown: Node3D) -> void:
	var gm := player.get_node("/root/GameManager")
	if gm.opened.has(key):
		player.call("_toast", "Nothing left here")
		return
	# (a part the game doesn't have yet becomes a plain pearl, as many)
	var have: Array = table.map(func(e): return e if ItemDB.get_item(str(e[0])) != null else ["pearl", e[1], e[2]])
	DIVE._take(player, key, have, shown.global_position, line, shown)
	if gm.opened.has(key):
		shown.visible = false
		player.get_node("/root/FX").bubbles(shown.global_position, 8)


# --------------------------------------------------------------------------
# The meshes (built once)
# --------------------------------------------------------------------------
static func _make_meshes() -> void:
	var mat := PSXMat.lit("", Color.WHITE)
	for ki in range(KINDS.size()):
		for ci in range(2):
			var rng := RandomNumberGenerator.new()
			rng.seed = 501 + ki * 7 + ci
			var col: Color = KINDS[ki][4][ci]
			var mb := MeshBuilder.new()
			match str(KINDS[ki][0]):
				"branch":
					_branches(mb, mat, rng, 0.9, col)
				"brain":
					mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.55, 0.42, 0.5), rng, 0.08, 3, 9, 1.0, col)
					for g in range(4):
						var a := g * PI / 4.0
						mb.add_box(mat, Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.42, 0)), Vector3(0.9, 0.04, 0.05), 0.5, col.darkened(0.25), false)
				"fan":
					# a sea fan: a lattice of thin branches spread up and out in one plane from a short stalk
					mb.add_cylinder(mat, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.05, 0.04, 0.25, 4, 0.5, col.darkened(0.3))
					for t in range(9):
						var a := lerpf(-1.2, 1.2, t / 8.0)
						var tip := Vector3(sin(a) * 0.65, 0.25 + cos(a) * 0.75, 0.0)
						mb.add_tube(mat, PackedVector3Array([Vector3(0, 0.22, 0), tip * 0.55 + Vector3(0, 0.1, 0.02), tip]), 0.025, 0.012, 3, 1.0, col)
					for r in [0.45, 0.7]:
						var arc := PackedVector3Array()
						for t in range(7):
							var a := lerpf(-1.1, 1.1, t / 6.0)
							arc.append(Vector3(sin(a) * 0.65 * r, 0.25 + cos(a) * 0.75 * r, 0.0))
						mb.add_tube(mat, arc, 0.015, 0.015, 3, 1.0, col.lightened(0.15))
				"tube":
					for t in range(4):
						var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
						var hh := rng.randf_range(0.35, 0.85)
						mb.add_cylinder(mat, Transform3D(Basis(), off + Vector3(0, hh * 0.5, 0)), 0.1, 0.12, hh, 6, 0.5, col, false, false)
						mb.add_cylinder(mat, Transform3D(Basis(), off + Vector3(0, hh, 0)), 0.07, 0.07, 0.02, 6, 0.5, col.darkened(0.5))
				"anemone":
					mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(0.28, 0.14, 0.28), rng, 0.05, 2, 7, 1.0, col.darkened(0.3))
					for t in range(12):
						var a := t * TAU / 12.0
						var p0 := Vector3(cos(a) * 0.2, 0.2, sin(a) * 0.2)
						mb.add_tube(mat, PackedVector3Array([p0, p0 * 1.6 + Vector3(0, 0.25, 0), p0 * 1.9 + Vector3(0, 0.45, 0)]), 0.035, 0.012, 3, 1.0, col)
				"kelp":
					for t in range(3):
						var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
						var hh := rng.randf_range(1.4, 2.6)
						mb.add_tube(mat, PackedVector3Array([off, off + Vector3(0.15, hh * 0.5, 0.05), off + Vector3(-0.1, hh, 0.1)]), 0.06, 0.03, 3, 1.0, col)
			_meshes["%d_%d" % [ki, ci]] = mb.commit()
	_meshes["ray"] = _ray()
	_meshes["turtle"] = _turtle()


## Branching coral: a few tubes forking up from a base.
static func _branches(mb: MeshBuilder, mat: Material, rng: RandomNumberGenerator, h: float, col: Color) -> void:
	for b in range(6):
		var a := rng.randf() * TAU
		var p0 := Vector3(cos(a) * 0.1, 0.0, sin(a) * 0.1)
		var p1 := p0 + Vector3(cos(a) * 0.25, h * rng.randf_range(0.4, 0.6), sin(a) * 0.25)
		var p2 := p1 + Vector3(cos(a + 0.6) * 0.15, h * rng.randf_range(0.3, 0.45), sin(a + 0.6) * 0.15)
		mb.add_tube(mat, PackedVector3Array([p0, p1, p2]), 0.06 * h, 0.025, 4, 1.0, col)
		mb.add_tube(mat, PackedVector3Array([p1, p1 + Vector3(cos(a - 0.8) * 0.2, h * 0.25, sin(a - 0.8) * 0.2)]), 0.035 * h, 0.02, 4, 1.0, col)


## An eagle ray: a broad flat diamond with a long thin tail (nose -z, for the shoal shader).
static func _ray() -> ArrayMesh:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.5), Vector3(-0.9, 0.05, 0.1), Vector3(0, 0.08, 0.3), Vector3(0.9, 0.05, 0.1),
		Vector3(-0.02, 0, 0.3), Vector3(0.02, 0, 0.3), Vector3(0, 0, 1.4)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A sea turtle: a domed shell and four flippers (nose -z).
static func _turtle() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit("", Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	mb.add_blob(mat, Transform3D(), Vector3(0.45, 0.18, 0.6), rng, 0.05, 2, 8)
	mb.add_blob(mat, Transform3D(Basis(), Vector3(0, 0.0, -0.7)), Vector3(0.14, 0.12, 0.18), rng, 0.0, 2, 6)
	for s in [-1.0, 1.0]:
		mb.add_box(mat, Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * 0.55, 0, -0.25)), Vector3(0.5, 0.04, 0.16), 0.5)
		mb.add_box(mat, Transform3D(Basis(Vector3.UP, -s * 0.4), Vector3(s * 0.4, 0, 0.45)), Vector3(0.3, 0.04, 0.12), 0.5)
	return mb.commit()



## The harvest's tell: what's still to take near the camera catches the light now and then (a sparkle in its colour),
## so a diver sees it through the water. Each screen its own; a check every EVERY s (FAR s while the camera's off
## the atoll).
class Glints extends Node3D:
	const EVERY := 0.7
	const FAR := 2.0
	const NEAR := 40.0
	var centre := Vector3.ZERO
	var reach := 500.0
	var items: Array = []
	var _t := 0.0
	var _k := 0

	func add(shown: Node3D, col: Color) -> void:
		items.append([shown, col])

	func _process(delta: float) -> void:
		_t -= delta
		if _t > 0.0:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.global_position.distance_to(get_parent().global_position + centre) > reach:
			_t = FAR
			return
		_t = EVERY
		_k += 1
		var fx := get_node("/root/FX")
		for i in range(items.size()):
			var e: Array = items[i]
			var n := e[0] as Node3D
			if not n.visible or (i + _k) % 2 != 0:
				continue
			var p := n.global_position + Vector3(0, 0.45, 0)
			if p.distance_to(cam.global_position) < NEAR:
				fx.sparkle(p, 3, e[1])


## A moray eel in a crevice of coral rock: a diver who comes within REACH gets its tell (the head out, its jaws open),
## then a bite if they're still there; it ducks back and waits COOL s. Judged on each captain's own machine (like the
## jellyfish's sting), awake only while a swimmer is within WAKE.
class Moray extends Node3D:
	const REACH := 2.4
	const WAKE := 30.0
	const TELL := 0.55
	const BITE := 12.0
	const COOL := 4.0
	var _head: Node3D
	var _t := 0.0
	var _phase := 0
	var _check := 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name)
		var mb := MeshBuilder.new()
		var rock := PSXMat.lit("", Color(0.72, 0.66, 0.64))
		mb.add_blob(rock, Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(1.2, 0.7, 1.0), rng, 0.25, 4, 7)
		mb.add_blob(PSXMat.flat(Color(0.04, 0.05, 0.06)), Transform3D(Basis(), Vector3(0, 0.45, -0.85)), Vector3(0.32, 0.25, 0.1), rng, 0.05, 2, 6)
		var mi := mb.to_instance("Crevice")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 90.0
		add_child(mi)
		_head = Node3D.new()
		_head.position = Vector3(0, 0.45, -0.7)
		add_child(_head)
		var hb := MeshBuilder.new()
		var skin := PSXMat.lit("leather", Color(0.45, 0.55, 0.25))
		hb.add_cylinder(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.25)), 0.13, 0.11, 0.6, 6, 0.5)
		hb.add_cone(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.02, -0.55)), 0.12, 0.22, 6)
		hb.add_box(PSXMat.glow(Color(1.0, 0.85, 0.3), 1.0), Transform3D(Basis(), Vector3(0, 0.08, -0.5)), Vector3(0.2, 0.04, 0.04), 0.5)
		var hm := hb.to_instance("Moray")
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(hm)
		_head.scale = Vector3(1, 1, 0.2)

	func _physics_process(delta: float) -> void:
		_check -= delta
		var me := get_tree().get_first_node_in_group("player") as Player
		if me == null:
			return
		if _phase == 0 and _check > 0.0:
			return
		_check = 0.25
		var d := me.global_position.distance_to(global_position + Vector3(0, 0.45, 0))
		if _phase == 0 and (d > WAKE or not me.is_swimming()):
			_check = 1.0
			return
		_t += delta if _phase != 0 else 0.0
		match _phase:
			0:
				if d < REACH:
					_phase = 1
					_t = 0.0
					me.get_node("/root/FX").sfx("hiss", global_position, -4.0, 0.1, 1.3)
			1:
				_head.scale = Vector3(1, 1, lerpf(0.2, 0.75, minf(_t / TELL, 1.0)))
				_head.look_at(me.global_position + Vector3(0, 0.9, 0), Vector3.UP)
				if _t >= TELL:
					if d < REACH + 0.6:
						me.health_component.take_damage(BITE * (1.0 - me.damage_reduction()))
						me.get_node("/root/FX").blood(me.global_position + Vector3(0, 0.9, 0), Vector3.UP, 8)
						me.get_node("/root/CombatManager").apply_camera_shake(0.15)
						me.call("_toast", "A moray bit you!")
					_head.scale = Vector3(1, 1, 1.0)
					_phase = 2
					_t = 0.0
			2:
				_head.scale = Vector3(1, 1, lerpf(1.0, 0.2, minf(_t / 0.4, 1.0)))
				if _t >= COOL:
					_phase = 0
