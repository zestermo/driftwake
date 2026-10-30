class_name StrongholdIsland
extends CapitalIsland
## The Admiralty's stronghold (1.27, docs/v1_27_raids_fruits_plan.md): an island off the sea chain (Chain's stronghold
## node: not on the route, the log pose never points to it), built when a ship comes near it whether the crew has
## heard of it or not. The capital's machinery (a GenIsland to the world, everything under the turned "City" node, its
## pieces a frame each) with StrongholdPlan's rock and StrongholdShell's fortress; its garrison and raid come later.

const STRONGHOLD_RADIUS := 170.0


func prepare(n: Dictionary) -> void:
	node = n
	theme = "capital"
	add_to_group("stronghold")
	radius = STRONGHOLD_RADIUS
	extent = ceilf((radius + MARGIN) * 2.0 / CELL) * CELL
	half = extent * 0.5
	res = int(extent / CELL)
	var face: Vector2 = n.get("face", Vector2(0, 1))
	yaw = atan2(face.x, face.y)
	dock_dir = from_city_dir(Vector2(0, 1))
	dock_shore = from_city(Vector2(StrongholdPlan.BERTH.x, StrongholdPlan.FRONT_Z))
	var ward: Rect2 = StrongholdPlan.DISTRICTS[1][1]
	sites = {"dock": dock_shore, "dock_end": from_city(Vector2(StrongholdPlan.BERTH.x, StrongholdPlan.FRONT_Z + 1.0)),
		"village": from_city(ward.get_center())}
	village_plan = {"c": sites["village"], "plaza_r": 40.0, "hamlets": [], "buildings": []}
	var t0 := Time.get_ticks_usec()
	heights.resize((res + 1) * (res + 1))
	for iz in range(res + 1):
		for ix in range(res + 1):
			heights[iz * (res + 1) + ix] = StrongholdPlan.terrain(to_city(Vector2(-half + ix * CELL, -half + iz * CELL)))
	build_ms["land"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_rock_arrays()
	build_ms["arrays"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_shore_map()
	build_ms["shore"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	pieces = StrongholdShell.build(build_ms)
	build_ms["shell"] = _lap(t0)
	places = []
	var titles := {"landing": "The Landing", "ward": "The Lower Ward", "arsenal": "The Arsenal", "prison": "The Prison Tower", "keep": "The Keep"}
	for d in StrongholdPlan.DISTRICTS:
		places.append({"kind": "landmark", "title": titles[str(d[0])], "at": from_city((d[1] as Rect2).get_center()), "r": 18.0})
	places.append({"kind": "landmark", "title": "The Bridge of Judgement", "at": from_city(Vector2(0, -31)), "r": 10.0})


func finish_steps() -> Array:
	island_name = str(node["name"])
	island_type = "stronghold"
	is_generated = true
	var steps: Array = [["terrain", _capital_terrain]]
	for i in range(GROUND * GROUND):
		steps.append(["ground", _terrain_collider.bind(i)])
	steps.append(["dock", _dock_here])
	for i in range(pieces.size()):
		steps.append(["fortress", _piece.bind(i)])
	steps.append(["arrival", _arrival])
	return steps


## Bare rock and the paving's earth: the terrain's paint (dirt, rock, sand) from its slope and height.
func _rock_arrays() -> void:
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
			var rock := clampf((1.0 - nm.y) * 5.0 - 0.3, 0.0, 1.0)
			cols[i] = Color(0.3 * (1.0 - rock), rock, 1.0 if h < 0.6 and rock < 0.5 else 0.0, 1.0)
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


func hv(p: Vector2) -> float:
	var g := StrongholdPlan.ground(to_city(p))
	return g if g > -INF else height_at(p.x, p.y)


func pigeon_flocks() -> Array:
	return []


func nav_faces(_c: Vector3, _r: float) -> PackedVector3Array:
	return PackedVector3Array()


func harbour_spawn() -> Vector3:
	return city_global(Vector2(StrongholdPlan.BERTH.x, StrongholdPlan.FRONT_Z - 6.0), StrongholdPlan.QUAY_Y + 0.4)


func mooring() -> Array:
	var b := from_city_dir(Vector2(1, 0))
	return [city_global(StrongholdPlan.BERTH, 0.0), atan2(-b.x, -b.y)]


func _dock_here() -> void:
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
	area.position = CapitalModels.v3(Vector2(StrongholdPlan.BERTH.x, StrongholdPlan.FRONT_Z - 1.5), StrongholdPlan.QUAY_Y + 1.0)


## Coming ashore: the banner, and the crew has found it (on the chart from now on: Chain.stronghold_known).
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
			Chain.learn_stronghold(get_tree(), "found")
			get_tree().call_group("hud", "show_banner", island_name, "The Admiralty's stronghold  (Lv %d)" % int(node["level"]), true))


func _in_stone(at: Vector3, ship: bool) -> bool:
	var l := to_local(at)
	var q := to_city(Vector2(l.x, l.z))
	if ship:
		return StrongholdPlan.land_t(q) < 3.0
	return StrongholdPlan.land_t(q) < -1.0 and l.y < StrongholdPlan.terrain(q) - 0.5
