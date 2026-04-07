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


func get_wave_height(world_pos: Vector3, time: float = -1.0) -> float:
	if time < 0.0:
		time = Time.get_ticks_msec() / 1000.0

	var dot1 := world_pos.x * wave_direction.x + world_pos.z * wave_direction.y
	var h1 := sin(dot1 * wave_frequency + time * wave_speed) * wave_amplitude

	var dot2 := world_pos.x * wave2_direction.x + world_pos.z * wave2_direction.y
	var h2 := sin(dot2 * wave2_frequency + time * wave2_speed) * wave2_amplitude

	return h1 + h2


func get_wave_normal(world_pos: Vector3, time: float = -1.0) -> Vector3:
	if time < 0.0:
		time = Time.get_ticks_msec() / 1000.0
	var eps := 0.1
	var h := get_wave_height(world_pos, time)
	var hx := get_wave_height(world_pos + Vector3(eps, 0.0, 0.0), time)
	var hz := get_wave_height(world_pos + Vector3(0.0, 0.0, eps), time)
	return Vector3(h - hx, eps, h - hz).normalized()


func _process(_delta: float) -> void:
	if ocean_material:
		var time := Time.get_ticks_msec() / 1000.0
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
