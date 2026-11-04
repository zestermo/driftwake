extends RefCounted
## The coral atoll's lagoon life, all of it moved on the GPU (shaders/atoll_shoal.gdshader): shoals of little reef
## fish circling under the water over the coral heads and the lagoon floor, and white seabirds wheeling over the
## lagoon. Cosmetic (nobody fishes these: the fishing system's catches are its own), the same on every screen from the
## island's seed. One MultiMesh each, no CPU work a frame; seen from SHOAL_SEE (fish) and 500 m (birds).
## The build step: AtollTheme.steps (atoll_land.gd).

const D := preload("res://scripts/island/themes/atoll_data.gd")
const SHADER := preload("res://shaders/atoll_shoal.gdshader")
## A shoal's colours: blue tangs, yellow butterflyfish, silver jacks, striped damsels, parrotfish green.
const FISH := [Color(0.2, 0.42, 0.95), Color(0.98, 0.85, 0.22), Color(0.82, 0.86, 0.9), Color(0.95, 0.95, 0.85), Color(0.3, 0.85, 0.6)]
const BIRDS := 3

static var _fish_mesh: ArrayMesh
static var _bird_mesh: ArrayMesh


static func build(isl) -> void:
	var L = isl._theme.LAND_FEATURES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "atoll_shoals"])
	var node := Node3D.new()
	node.name = "AtollShoals"
	isl.add_child(node)
	if _fish_mesh == null:
		_fish_mesh = _fish()
		_bird_mesh = _bird()
	var n := rng.randi_range(D.SHOALS[0], D.SHOALS[1])
	var made := 0
	for k in range(n * 6):
		if made >= n:
			break
		var a := rng.randf() * TAU
		var inner: float = L.ring_r(isl, a)[1]
		var q := Vector2.from_angle(a) * inner * rng.randf_range(0.25, 0.92)
		var h: float = isl.hv(q)
		if h > -1.6:
			continue
		var col: Color = FISH[rng.randi() % FISH.size()]
		_add(node, _fish_mesh, 0, Vector3(q.x, maxf(h + 0.9, -1.6), q.y), rng.randi_range(D.SHOAL_FISH[0], D.SHOAL_FISH[1]), rng.randf_range(1.6, 3.2), 0.8,
			col, rng, D.SHOAL_SEE)
		made += 1
	for k in range(BIRDS):
		var a := rng.randf() * TAU
		var q := Vector2.from_angle(a) * float(L.ring_r(isl, a)[1]) * rng.randf_range(0.2, 0.8)
		_add(node, _bird_mesh, 1, Vector3(q.x, rng.randf_range(12.0, 22.0), q.y), rng.randi_range(4, 8), rng.randf_range(14.0, 28.0), 3.0, Color(0.96, 0.96, 0.94), rng, 500.0)


static func _add(node: Node3D, mesh: Mesh, mode: int, at: Vector3, count: int, radius: float, height: float, col: Color, rng: RandomNumberGenerator, see: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.18, 0.3) if mode == 0 else rng.randf_range(0.1, 0.18), rng.randf(), rng.randf()))
		mm.set_instance_color(i, col.lerp(Color.WHITE, rng.randf_range(0.0, 0.2)) if mode == 0 else col)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", float(mode))
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("height", height)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = (["Shoal%d", "Gulls%d", "Bubbles%d"][mode] as String) % node.get_child_count()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := radius * 1.3 + 1.0
	mmi.custom_aabb = AABB(Vector3(-reach, -height - 2.0, -reach), Vector3(reach * 2.0, height * 2.0 + 4.0, reach * 2.0))
	mmi.visibility_range_end = see
	node.add_child(mmi)
	mmi.position = at


## A little fish: a body diamond standing up and a tail, crossed with a flat one (seen from above through the water).
static func _fish() -> ArrayMesh:
	var v := PackedVector3Array([
		Vector3(0, 0, -0.16), Vector3(0, 0.07, 0.0), Vector3(0, 0, 0.1), Vector3(0, -0.06, 0.0),
		Vector3(0, 0, 0.1), Vector3(0, 0.06, 0.18), Vector3(0, -0.06, 0.18),
		Vector3(0, 0, -0.16), Vector3(0.05, 0, 0.0), Vector3(0, 0, 0.1), Vector3(-0.05, 0, 0.0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 7, 8, 9, 7, 9, 10])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A gull: two swept wings off a body line.
static func _bird() -> ArrayMesh:
	var span := 0.55
	var body := 0.18
	var v := PackedVector3Array([
		Vector3(0, 0, -body), Vector3(-span, 0.04, -body * 0.1), Vector3(-span * 0.7, 0, body * 0.6), Vector3(0, 0, body * 0.7),
		Vector3(0, 0, -body), Vector3(span, 0.04, -body * 0.1), Vector3(span * 0.7, 0, body * 0.6), Vector3(0, 0, body * 0.7)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
