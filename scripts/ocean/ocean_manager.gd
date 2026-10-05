extends Node

@export var wave_amplitude: float = 0.8
@export var wave_frequency: float = 0.8
@export var wave_speed: float = 1.5
@export var wave_direction: Vector2 = Vector2(1.0, 0.6).normalized()

@export var wave2_amplitude: float = 0.3
@export var wave2_frequency: float = 1.5
@export var wave2_speed: float = 0.8
@export var wave2_direction: Vector2 = Vector2(-0.7, 1.0).normalized()

var ocean_material: ShaderMaterial
## Rough seas (Weather sets it: 1 calm .. ~1.8 in a storm). Scales both waves
## for the game and the shader alike.
var amp_mult: float = 1.0
var _amp_sent: float = -1.0


## The sea mesh: 1 m cells near the camera so the surface you see is the
## surface the game computes (characters, the ship and enemies sample the same
## sine waves); cells grow toward the horizon. One grid, no seams.
const NEAR_HALF := 80.0
const FAR_HALF := 1000.0
const SNAP := 8.0
static var _graded: ArrayMesh
var _mesh_node: MeshInstance3D


func _ready() -> void:
	# tick the clock before anything that floats on the sea
	process_physics_priority = -100
	await get_tree().process_frame
	_adopt_mesh()


## Swap the scene's ocean PlaneMesh for the graded grid (keeps its material).
func _adopt_mesh() -> void:
	var ocean_mesh := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	if ocean_mesh == null or ocean_mesh.mesh == null or ocean_mesh == _mesh_node:
		return
	_mesh_node = ocean_mesh
	_amp_sent = -1.0
	ocean_material = ocean_mesh.mesh.material as ShaderMaterial
	if ocean_material == null:
		ocean_material = ocean_mesh.get_active_material(0) as ShaderMaterial
	var m := graded_mesh()
	ocean_mesh.mesh = m
	if ocean_material:
		ocean_mesh.material_override = ocean_material
	# (it covers far more than it seems: don't let culling drop it)
	ocean_mesh.extra_cull_margin = 16.0
	# Re-positioned every frame on a grid; interpolating would make it slide.
	ocean_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


static func _lines() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var far: Array = []
	var x := NEAR_HALF
	var step := 1.25
	while x < FAR_HALF:
		x = minf(x + step, FAR_HALF)
		far.append(x)
		step *= 1.13
	for i in range(far.size() - 1, -1, -1):
		out.append(-float(far[i]))
	var n := int(NEAR_HALF)
	for i in range(-n, n + 1):
		out.append(float(i))
	for v in far:
		out.append(float(v))
	return out


static func graded_mesh() -> ArrayMesh:
	if _graded:
		return _graded
	var ls := _lines()
	var n := ls.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	uvs.resize(n * n)
	norms.resize(n * n)
	for j in range(n):
		for i in range(n):
			var k := j * n + i
			verts[k] = Vector3(ls[i], 0.0, ls[j])
			uvs[k] = Vector2(ls[i], ls[j]) / (FAR_HALF * 2.0) + Vector2(0.5, 0.5)
			norms[k] = Vector3.UP
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var c := 0
	for j in range(n - 1):
		for i in range(n - 1):
			var a := j * n + i
			var b := a + 1
			var d := a + n
			var e := d + 1
			idx[c] = a; idx[c + 1] = b; idx[c + 2] = d
			idx[c + 3] = b; idx[c + 4] = e; idx[c + 5] = d
			c += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_graded = ArrayMesh.new()
	_graded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_graded.custom_aabb = AABB(Vector3(-FAR_HALF, -6.0, -FAR_HALF), Vector3(FAR_HALF * 2.0, 12.0, FAR_HALF * 2.0))
	return _graded


var _net: Node


## The swell's clock. It advances with the physics ticks (so swimmers, the
## ship and enemies are pushed by exactly the waves of that tick, however the
## frame rate stutters) and drifts toward the session clock (the host's in
## co-op, so every player sees the same waves). Rendering uses the same time
## interpolated within the tick, so the sea you see is the sea they float on.
var _phys_t: float = -1.0


func _session_time() -> float:
	if _net == null:
		_net = get_node_or_null("/root/Net")
	if _net and _net.active:
		return _net.time()
	return Time.get_ticks_usec() * 0.000001


func clock() -> float:
	if _phys_t < 0.0:
		_phys_t = _session_time()
	if Engine.is_in_physics_frame():
		return _phys_t
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	return _phys_t + Engine.get_physics_interpolation_fraction() * tick


func _physics_process(delta: float) -> void:
	var target := _session_time()
	if _phys_t < 0.0 or absf(target - _phys_t) > 0.5:
		_phys_t = target
	else:
		_phys_t += delta + (target - _phys_t) * 0.02


func get_wave_height(world_pos: Vector3, time: float = -1.0) -> float:
	if time < 0.0:
		time = clock()

	var dot1 := world_pos.x * wave_direction.x + world_pos.z * wave_direction.y
	var h1 := sin(dot1 * wave_frequency + time * wave_speed) * wave_amplitude * amp_mult

	var dot2 := world_pos.x * wave2_direction.x + world_pos.z * wave2_direction.y
	var h2 := sin(dot2 * wave2_frequency + time * wave2_speed) * wave2_amplitude * amp_mult

	return h1 + h2


func get_wave_normal(world_pos: Vector3, time: float = -1.0) -> Vector3:
	if time < 0.0:
		time = clock()
	var eps := 0.1
	var h := get_wave_height(world_pos, time)
	var hx := get_wave_height(world_pos + Vector3(eps, 0.0, 0.0), time)
	var hz := get_wave_height(world_pos + Vector3(0.0, 0.0, eps), time)
	return Vector3(h - hx, eps, h - hz).normalized()


func _process(_delta: float) -> void:
	# follow whichever ocean the current world has (title -> game, loading)
	var om := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	if om and om != _mesh_node:
		_adopt_mesh()
	if ocean_material:
		var time := clock()
		ocean_material.set_shader_parameter("time_val", time)
		if absf(amp_mult - _amp_sent) > 0.0005:
			_amp_sent = amp_mult
			ocean_material.set_shader_parameter("wave_amplitude", wave_amplitude * amp_mult)
			ocean_material.set_shader_parameter("wave2_amplitude", wave2_amplitude * amp_mult)

	# Follow camera on XZ for infinite ocean illusion
	# Snap to grid so vertices always align with world positions (prevents pattern sliding)
	# Mesh is 2000 units with 256 subdivisions = ~7.8125 per cell
	var camera := get_viewport().get_camera_3d()
	if camera:
		var ocean_mesh := _mesh_node
		if ocean_mesh and is_instance_valid(ocean_mesh):
			# (the 1 m cells stay on whole metres of the world)
			ocean_mesh.global_position.x = snappedf(camera.global_position.x, SNAP)
			ocean_mesh.global_position.z = snappedf(camera.global_position.z, SNAP)
			ocean_mesh.global_position.y = 0.0


## How deep the water is at a spot: wave surface minus the ground (world
## layer) under it. INF over open water with no bottom in reach; negative on
## dry land above the waves. calm: measured from the mean sea level instead of
## the passing wave.
func depth_at(world_pos: Vector3, exclude: Array = [], calm: bool = false) -> float:
	var vp := get_viewport()
	if vp == null or vp.world_3d == null:
		return -INF
	var surf := 0.0 if calm else get_wave_height(world_pos)
	var top := maxf(world_pos.y, surf) + 1.5
	var q := PhysicsRayQueryParameters3D.create(Vector3(world_pos.x, top, world_pos.z), Vector3(world_pos.x, surf - 40.0, world_pos.z), 1)
	q.exclude = exclude
	var hit := vp.world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return surf - (hit["position"] as Vector3).y
