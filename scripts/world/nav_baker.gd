extends Node
## Island navmeshes for the grunts (PirateGrunt._nav_dir), baked on a worker
## thread the first time a captain comes near each island. Only where enemies
## are simulated (single player / the host).

const CELL := 0.4
const CELL_H := 0.2
## Bake an island once a captain is this far outside its radius.
const NEAR := 150.0
## Walkable ground stops at the shoreline.
const SHORE_Y := -0.3

var gen: Node3D
var _zones: Array = []
var _check := 0.0


func _ready() -> void:
	var map := gen.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)


## `terrain`: the island stands on the shared world terrain (its faces come
## from the heightmap; hand-built islands carry their own ground).
## `faces` (world faces round a centre and radius): ground handed over instead
## of parsed (a generated island's site: its whole terrain is too big to parse).
func add_zone(node: Node3D, radius: float, terrain: bool, faces: Callable = Callable()) -> void:
	_zones.append({"node": node, "r": radius, "terrain": terrain, "faces": faces, "baked": false})
	set_process(true)


## Parsing an island's colliders has to happen on the main thread (a frame
## hitch), so the islands nobody is near yet are baked one a second while the
## world settles in, instead of when a ship sails up to them.
const PREBAKE_AFTER := 2.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	# (a chain island's zones go with it)
	_zones = _zones.filter(func(z): return is_instance_valid(z["node"]))
	for z in _zones:
		if z["baked"]:
			continue
		var c: Vector3 = (z["node"] as Node3D).global_position
		for p in get_tree().get_nodes_in_group("players"):
			var d := Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length()
			if d < float(z["r"]) + NEAR:
				_bake(z)
				return
	if _t > PREBAKE_AFTER:
		for z in _zones:
			if not z["baked"]:
				_bake(z)
				return
		set_process(false)


func _bake(z: Dictionary) -> void:
	z["baked"] = true
	var node: Node3D = z["node"]
	var r: float = z["r"]
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL_H
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 50.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 2048
	var y0 := SHORE_Y - node.global_position.y
	nm.filter_baking_aabb = AABB(Vector3(-r, y0, -r), Vector3(2.0 * r, 80.0, 2.0 * r))
	var data := NavigationMeshSourceGeometryData3D.new()
	# parsing clears the data and works in the island's space: faces added
	# after it go in world coordinates
	NavigationServer3D.parse_source_geometry_data(nm, data, node)
	if z["terrain"]:
		data.add_faces(_terrain_faces(node.global_position, r), Transform3D.IDENTITY)
	if (z["faces"] as Callable).is_valid():
		data.add_faces(z["faces"].call(node.global_position, r), Transform3D.IDENTITY)
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	node.add_child(region)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, data, func():
		if is_instance_valid(region):  # (the world can be gone by the time a bake finishes)
			region.call_deferred("set_navigation_mesh", nm))


func _terrain_faces(c: Vector3, r: float) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var hm: Array = gen.heightmap
	var res: int = gen.terrain_resolution
	var size: float = gen.terrain_size
	var cell := size / float(res)
	var half := size * 0.5
	var x0 := clampi(int(floor((c.x - r + half) / cell)), 0, res - 1)
	var x1 := clampi(int(ceil((c.x + r + half) / cell)), 0, res - 1)
	var z0 := clampi(int(floor((c.z - r + half) / cell)), 0, res - 1)
	var z1 := clampi(int(ceil((c.z + r + half) / cell)), 0, res - 1)
	for iz in range(z0, z1 + 1):
		var r0: PackedFloat32Array = hm[iz]
		var r1: PackedFloat32Array = hm[iz + 1]
		for ix in range(x0, x1 + 1):
			var tl := Vector3(ix * cell - half, r0[ix], iz * cell - half)
			var tr := Vector3((ix + 1) * cell - half, r0[ix + 1], iz * cell - half)
			var bl := Vector3(ix * cell - half, r1[ix], (iz + 1) * cell - half)
			var br := Vector3((ix + 1) * cell - half, r1[ix + 1], (iz + 1) * cell - half)
			# same triangles and winding as WorldGenerator._build_chunk
			faces.append(tl)
			faces.append(tr)
			faces.append(bl)
			faces.append(tr)
			faces.append(br)
			faces.append(bl)
	return faces
