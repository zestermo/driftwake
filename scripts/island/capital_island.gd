class_name CapitalIsland
extends GenIsland
## The royal capital (docs/capital_plan.md): the chain's first city, hand-laid and the same in every world, only
## its name rolled from the chain seed (Chain.capital_name). A GenIsland to the world (WorldGenerator builds,
## frees and registers it like any chain island; the map, music, birds and the debug jump read the same fields),
## but none of a generated island's land, sites, village or wilds: CapitalPlan's layout instead, turned so its
## harbour faces the way the crew sails in (node "face"). Everything built goes under the "City" node, which
## carries that turn, in the plan's frame; the terrain grid stays the island's (the shore map is axis-aligned).
##
## prepare (a worker): the terrain from CapitalPlan.terrain, the shore map, every mesh of the shell (CapitalShell).
## finish_steps: the terrain, its colliders, the dock, then a piece of the city a frame.

const RADIUS := 300.0

## How bright the town's windows glow, by night (Weather.night): looked at every WINDOWS_EVERY s.
const WINDOWS_EVERY := 2.0
const WINDOWS_GLOW := 0.9

var yaw := 0.0
var _windows_t := 0.0
## The shell's pieces from prepare: {"name", "mesh", "range", "shadow", "cols", "faces"}.
var pieces: Array = []
var city: Node3D


func build(n: Dictionary) -> void:
	prepare(n)
	finish()


func prepare(n: Dictionary) -> void:
	node = n
	theme = "capital"
	radius = RADIUS
	extent = ceilf((radius + MARGIN) * 2.0 / CELL) * CELL
	half = extent * 0.5
	res = int(extent / CELL)
	var face: Vector2 = n.get("face", Vector2(0, 1))
	yaw = atan2(face.x, face.y)
	dock_dir = from_city_dir(Vector2(0, 1))
	dock_shore = from_city(Vector2(CapitalPlan.BERTH.x, CapitalPlan.FRONT_Z))
	sites = {"dock": dock_shore, "dock_end": from_city(Vector2(CapitalPlan.BERTH.x, CapitalPlan.FRONT_Z + 1.0)),
		"village": from_city(CapitalPlan.PLAZA.get_center())}
	var front: Array = []
	var x := -140.0
	while x <= 140.0:
		front.append({"p": from_city(Vector2(x, 100.0))})
		x += 20.0
	village_plan = {"c": sites["village"], "plaza_r": 92.0, "hamlets": [], "buildings": front}
	var t0 := Time.get_ticks_usec()
	heights.resize((res + 1) * (res + 1))
	for iz in range(res + 1):
		for ix in range(res + 1):
			heights[iz * (res + 1) + ix] = CapitalPlan.terrain(to_city(Vector2(-half + ix * CELL, -half + iz * CELL)))
	build_ms["land"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_capital_arrays()
	build_ms["arrays"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_shore_map()
	build_ms["shore"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	pieces = CapitalShell.build(build_ms)
	build_ms["shell"] = _lap(t0)


func finish_steps() -> Array:
	island_name = str(node["name"])
	island_type = theme
	is_generated = true
	var steps: Array = [["terrain", _capital_terrain]]
	for i in range(GROUND * GROUND):
		steps.append(["ground", _terrain_collider.bind(i)])
	steps.append(["dock", _dock])
	for i in range(pieces.size()):
		steps.append(["city", _piece.bind(i)])
	steps.append(["arrival", _arrival])
	return steps


func _process(delta: float) -> void:
	_windows_t -= delta
	if _windows_t > 0.0:
		return
	_windows_t = WINDOWS_EVERY
	var e := WINDOWS_GLOW * clampf(float(Weather.night) * 1.4 - 0.2, 0.0, 1.0)
	for k in ["facade_a", "facade_b"]:
		(CapitalModels.mat(k) as ShaderMaterial).set_shader_parameter("emission_energy", e)


# --------------------------------------------------------------------------
# The city's frame
# --------------------------------------------------------------------------
## A frame point (CapitalPlan's coordinates) in island space, and back.
func from_city(q: Vector2) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(q.x * c + q.y * s, -q.x * s + q.y * c)


func to_city(p: Vector2) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(p.x * c - p.y * s, p.x * s + p.y * c)


func from_city_dir(d: Vector2) -> Vector2:
	return from_city(d)


## A frame point at height y, in the world.
func city_global(q: Vector2, y: float) -> Vector3:
	var p := from_city(q)
	return to_global(Vector3(p.x, y, p.y))


## The walking height: the city's floors where they're laid, else the terrain.
func hv(p: Vector2) -> float:
	var q := to_city(p)
	if CapitalPlan.in_floor(q):
		return CapitalPlan.ground(q)
	return height_at(p.x, p.y)


func walk_height(x: float, z: float) -> float:
	return hv(Vector2(x, z))


func undergrowth_at(_at: Vector3) -> float:
	return 0.0


## On the quay by the ship (the debug jump, a load that would leave you inside the city's stone).
func harbour_spawn() -> Vector3:
	return city_global(Vector2(CapitalPlan.BERTH.x, CapitalPlan.FRONT_Z - 5.0), CapitalPlan.QUAY_Y + 0.4)


## Where the crew's ship lies: alongside the quay, bow along the harbour front.
func mooring() -> Array:
	var b := from_city_dir(Vector2(1, 0))
	return [city_global(CapitalPlan.BERTH, 0.0), atan2(-b.x, -b.y)]


# --------------------------------------------------------------------------
# Terrain
# --------------------------------------------------------------------------
func _capital_arrays() -> void:
	var n := (res + 1) * (res + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n)
	norms.resize(n)
	cols.resize(n)
	for iz in range(res + 1):
		for ix in range(res + 1):
			var i := iz * (res + 1) + ix
			var p := Vector2(-half + ix * CELL, -half + iz * CELL)
			var h := heights[i]
			verts[i] = Vector3(p.x, h, p.y)
			var nm := Vector3(_h(ix - 1, iz) - _h(ix + 1, iz), 2.0 * CELL, _h(ix, iz - 1) - _h(ix, iz + 1)).normalized()
			norms[i] = nm
			var q := to_city(p)
			var t := CapitalPlan.land_t(q)
			var rock := clampf((1.0 - nm.y) * 5.0 - 0.6, 0.0, 1.0)
			if t > -8.0 and not CapitalPlan.quay_coast(q):
				rock = maxf(rock, 1.0 - CapitalPlan.smooth(3.0, 8.0, t))
			var hill := CapitalPlan.steep(q)
			var dirt := (1.0 - hill) * (1.0 - rock) if t < -6.0 else 0.0
			var sand := (1.0 - CapitalPlan.smooth(0.8, 2.0, h)) * (1.0 - rock) if t > -6.0 else 0.0
			if CapitalPlan.ellipse(q, CapitalPlan.ARENA_C, CapitalPlan.ARENA_R) < 1.15:
				sand = 1.0
				dirt = 0.0
			cols[i] = Color(dirt, rock, sand, 1.0)
	var idx := PackedInt32Array()
	idx.resize(res * res * 6)
	var k := 0
	for iz in range(res):
		for ix in range(res):
			var tl := iz * (res + 1) + ix
			var bl := tl + res + 1
			idx[k] = tl; idx[k + 1] = tl + 1; idx[k + 2] = bl
			idx[k + 3] = tl + 1; idx[k + 4] = bl + 1; idx[k + 5] = bl
			k += 6
	_faces = []
	for gz in range(GROUND):
		for gx in range(GROUND):
			var f := PackedVector3Array()
			for iz in range(gz * res / GROUND, (gz + 1) * res / GROUND):
				for ix in range(gx * res / GROUND, (gx + 1) * res / GROUND):
					var q := (iz * res + ix) * 6
					for j in range(6):
						f.append(verts[idx[q + j]])
			_faces.append(f)
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = verts
	_arrays[Mesh.ARRAY_NORMAL] = norms
	_arrays[Mesh.ARRAY_COLOR] = cols
	_arrays[Mesh.ARRAY_INDEX] = idx


func _capital_terrain() -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh.surface_set_material(0, PSXMat.terrain(true, 0.0, KitStyle.of(theme)["ground"], ""))
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	city = Node3D.new()
	city.name = "City"
	city.rotation.y = yaw
	add_child(city)


# --------------------------------------------------------------------------
# The city's pieces, the dock, the arrival
# --------------------------------------------------------------------------
func _piece(i: int) -> void:
	var pc: Dictionary = pieces[i]
	var cols: Array = pc["cols"]
	var faces: Array = pc["faces"]
	var root: Node3D
	if cols.is_empty() and faces.is_empty():
		root = Node3D.new()
	else:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		root = body
		for c in cols:
			var cs := CollisionShape3D.new()
			if c.has("box"):
				var b := BoxShape3D.new()
				b.size = c["box"]
				cs.shape = b
			else:
				var cy := CylinderShape3D.new()
				cy.radius = float(c["cyl"][0])
				cy.height = float(c["cyl"][1])
				cs.shape = cy
			cs.transform = c["xf"]
			body.add_child(cs)
		for f in faces:
			var cs := CollisionShape3D.new()
			var tri := ConcavePolygonShape3D.new()
			tri.set_faces(f)
			cs.shape = tri
			body.add_child(cs)
	root.name = str(pc["name"])
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = pc["mesh"]
	mi.visibility_range_end = float(pc["range"])
	if not pc["shadow"]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	city.add_child(root)
	pieces[i] = {}


func _dock() -> void:
	var area := Interactable.new()
	area.name = "DockingArea"
	area.collision_layer = 512
	area.collision_mask = 0
	area.prompt_text = "Board ship"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	cs.shape = sph
	area.add_child(cs)
	city.add_child(area)
	area.position = CapitalModels.v3(Vector2(CapitalPlan.BERTH.x, CapitalPlan.FRONT_Z - 1.5), CapitalPlan.QUAY_Y + 1.0)


func _arrival() -> void:
	var area := Area3D.new()
	area.name = "ArrivalZone"
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius + 30.0
	cs.shape = sph
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player") and b.get("is_local"):
			get_tree().call_group("hud", "show_banner", island_name, "The royal capital  (Lv %d)" % int(node["level"]), true))
	# (a save from before the capital, made on the generated island that stood here: a ship left on what's land now
	# goes to the berth, a captain inside the city's stone to the quay)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship and not Net.is_client() and _in_stone(ship.global_position, true):
		var moor := mooring()
		ship.call("place", moor[0], moor[1])
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and _in_stone(me.global_position, false):
		me.global_position = harbour_spawn()
		me.reset_physics_interpolation()


func _in_stone(at: Vector3, ship: bool) -> bool:
	var l := to_local(at)
	var q := to_city(Vector2(l.x, l.z))
	if ship:
		return CapitalPlan.land_t(q) < 3.0 or CapitalPlan.mole_dist(q) < CapitalPlan.MOLE_HW + 3.0
	return CapitalPlan.land_t(q) < -1.0 and not CapitalPlan.in_floor(q) and l.y < CapitalPlan.ground(q) + 30.0
