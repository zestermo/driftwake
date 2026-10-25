class_name CanalIsland
extends CapitalIsland
## The canal city (docs/v1_21_plan.md: lagoon shipbuilders, the chain's second city): hand-laid and the same in every
## world, its name rolled from the chain seed (Chain.canal_name). The capital's machinery (a GenIsland to the world,
## everything under the turned "City" node, pieces built a frame each, the lamps, the dock, the arrival) with its own
## layout: CanalPlan's terrain and floors, CanalShell and CanalDistrict's pieces, CanalLife's people and boatmen, the
## crowd on its walkways.

const CANAL_RADIUS := 260.0

var canal_life: CanalLife


func prepare(n: Dictionary) -> void:
	node = n
	theme = "canal"
	add_to_group("canal_city")
	radius = CANAL_RADIUS
	extent = ceilf((radius + MARGIN) * 2.0 / CELL) * CELL
	half = extent * 0.5
	res = int(extent / CELL)
	var face: Vector2 = n.get("face", Vector2(0, 1))
	yaw = atan2(face.x, face.y)
	dock_dir = from_city_dir(Vector2(0, 1))
	dock_shore = from_city(Vector2(CanalPlan.BERTH.x, CanalPlan.FRONT_Z))
	sites = {"dock": dock_shore, "dock_end": from_city(Vector2(CanalPlan.BERTH.x, CanalPlan.FRONT_Z + 1.0)),
		"village": from_city(CanalPlan.PIAZZA.get_center())}
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
			heights[iz * (res + 1) + ix] = CanalPlan.terrain(to_city(Vector2(-half + ix * CELL, -half + iz * CELL)))
	build_ms["land"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_canal_arrays()
	build_ms["arrays"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_shore_map()
	build_ms["shore"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	CanalShell.smoke_tops.clear()
	pieces = CanalShell.build(build_ms)
	build_ms["shell"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	var d := CanalDistrict.build(build_ms)
	pieces.append_array(d["pieces"])
	spots = d["spots"]
	doors = d["doors"]
	lights = d["lights"]
	smoke_tops = CanalShell.smoke_tops.duplicate()
	CanalShell.smoke_tops.clear()
	build_ms["district"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_stocked = CanalLife.looks() + CanalLife.crowd_looks()
	for lk in _stocked:
		var h := Humanoid.new()
		h.setup(lk)
		Humanoid.stock(h, lk)
	build_ms["townsfolk"] = _lap(t0)
	places = [
		{"kind": "landmark", "title": "The piazza", "at": from_city(CanalPlan.PIAZZA.get_center()), "r": 14.0},
		{"kind": "landmark", "title": "The arsenal", "at": from_city(CanalPlan.ARSENAL.get_center()), "r": 16.0},
		{"kind": "landmark", "title": "The market bridge", "at": from_city(Vector2(0, -30)), "r": 10.0},
		{"kind": "landmark", "title": "The Oar and Lantern", "at": from_city((CanalPlan.SPECIAL["inn"][0] as Rect2).get_center()), "r": 10.0},
	]
	for l in CanalPlan.LANDINGS:
		places.append({"kind": "landmark", "title": "Water taxi: %s" % l[0], "at": from_city(l[1]), "r": 6.0})


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
	steps.append(["lamps", _lamps])
	steps.append(["smoke", _smoke])
	steps.append(["pigeons", _pigeons])
	canal_life = CanalLife.new().setup(self)
	steps.append(["life", add_child.bind(canal_life)])
	steps.append_array(canal_life.steps())
	steps.append(["crowd", _crowd])
	steps.append(["arrival", _arrival])
	return steps


## The campi's and the piazza's pigeons (off each campo's wellhead, tree and lamp).
func pigeon_flocks() -> Array:
	var out: Array = []
	for f in CanalPlan.floors():
		if str(f[0]).ends_with("_campo"):
			out.append(CapitalModels.v3((f[1] as Rect2).get_center() + Vector2(3.5, 3.5), CanalPlan.QUAY_Y))
	var c := CanalPlan.PIAZZA.get_center()
	for o in [Vector2(-14.0, 4.0), Vector2(12.0, -6.0)]:
		out.append(CapitalModels.v3(c + o, CanalPlan.QUAY_Y))
	return out


func hv(p: Vector2) -> float:
	var q := to_city(p)
	if CanalPlan.in_floor(q) or (CanalPlan.land_t(q) < -0.5 and not CanalPlan.in_canal(q)):
		return CanalPlan.QUAY_Y
	return height_at(p.x, p.y)


func harbour_spawn() -> Vector3:
	return city_global(Vector2(CanalPlan.BERTH.x, CanalPlan.FRONT_Z - 5.0), CanalPlan.QUAY_Y + 0.4)


func mooring() -> Array:
	var b := from_city_dir(Vector2(1, 0))
	return [city_global(CanalPlan.BERTH, 0.0), atan2(-b.x, -b.y)]


## (no one to fight in the canal city: nothing for the nav baker)
func nav_faces(_c: Vector3, _r: float) -> PackedVector3Array:
	return PackedVector3Array()


func _canal_arrays() -> void:
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
			norms[i] = Vector3(_h(ix - 1, iz) - _h(ix + 1, iz), 2.0 * CELL, _h(ix, iz - 1) - _h(ix, iz + 1)).normalized()
			var q := to_city(p)
			var t := CanalPlan.land_t(q)
			# paving-coloured earth in the city, mud under the water, sand at the lagoon's edge
			var sand := 1.0 if h < 0.5 else 0.0
			cols[i] = Color(0.0 if t < -4.0 else 0.4, 0.6 if h < -1.0 else 0.0, sand, 1.0)
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
					var qi := (iz * res + ix) * 6
					for j in range(6):
						f.append(verts[idx[qi + j]])
			_faces.append(f)
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = verts
	_arrays[Mesh.ARRAY_NORMAL] = norms
	_arrays[Mesh.ARRAY_COLOR] = cols
	_arrays[Mesh.ARRAY_INDEX] = idx


func _crowd() -> void:
	crowd = CapitalCrowd.new().setup(CanalLife.crowd_looks(), CanalLife.LANES, CanalPlan.ground)
	crowd.centre = CapitalModels.v3(Vector2(0, 0), CanalPlan.QUAY_Y)
	city.add_child(crowd)


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
	area.position = CapitalModels.v3(Vector2(CanalPlan.BERTH.x, CanalPlan.FRONT_Z - 1.5), CanalPlan.QUAY_Y + 1.0)


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
			get_tree().call_group("hud", "show_banner", island_name, "The canal city  (Lv %d)" % int(node["level"]), true))
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
		return CanalPlan.land_t(q) < 3.0 and not CanalPlan.in_canal(q)
	return CanalPlan.land_t(q) < -1.0 and not CanalPlan.in_floor(q) and not CanalPlan.in_canal(q) and l.y < CanalPlan.QUAY_Y + 30.0
