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


func _ready() -> void:
	await get_tree().process_frame
	var ocean_mesh := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	if ocean_mesh and ocean_mesh.mesh:
		ocean_material = ocean_mesh.mesh.material as ShaderMaterial
		# Re-positioned every frame on a grid; interpolating would make it slide.
		ocean_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


var _net: Node


## The swell's clock: the session clock in co-op, so every player sees the
## same waves (and the ship rides them the same way).
func clock() -> float:
	if _net == null:
		_net = get_node_or_null("/root/Net")
	if _net and _net.active:
		return _net.time()
	return Time.get_ticks_usec() * 0.000001


func get_wave_height(world_pos: Vector3, time: float = -1.0) -> float:
	if time < 0.0:
		time = clock()

	var dot1 := world_pos.x * wave_direction.x + world_pos.z * wave_direction.y
	var h1 := sin(dot1 * wave_frequency + time * wave_speed) * wave_amplitude

	var dot2 := world_pos.x * wave2_direction.x + world_pos.z * wave2_direction.y
	var h2 := sin(dot2 * wave2_frequency + time * wave2_speed) * wave2_amplitude

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
	if om and om.mesh:
		ocean_material = om.mesh.material as ShaderMaterial
	if ocean_material:
		var time := clock()
		ocean_material.set_shader_parameter("time_val", time)

	# Follow camera on XZ for infinite ocean illusion
	# Snap to grid so vertices always align with world positions (prevents pattern sliding)
	# Mesh is 2000 units with 256 subdivisions = ~7.8125 per cell
	var camera := get_viewport().get_camera_3d()
	if camera:
		var ocean_mesh := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
		if ocean_mesh:
			var cell_size := 2000.0 / 256.0  # must match PlaneMesh size / subdivisions
			ocean_mesh.global_position.x = snappedf(camera.global_position.x, cell_size)
			ocean_mesh.global_position.z = snappedf(camera.global_position.z, cell_size)
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
