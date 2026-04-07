extends Node3D

@export var cloud_count: int = 40
@export var spawn_radius: float = 1500.0
@export var min_height: float = 80.0
@export var max_height: float = 150.0
@export var min_cloud_size: float = 60.0
@export var max_cloud_size: float = 200.0
@export var wind_speed: float = 3.0
@export var wind_direction: Vector2 = Vector2(1.0, 0.3)

const _cloud_shader = preload("res://scenes/world/cloud.gdshader")

var clouds: Array[MeshInstance3D] = []
var cloud_velocities: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var wind_dir_3d := Vector3(wind_direction.x, 0.0, wind_direction.y).normalized()

	for i in range(cloud_count):
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, spawn_radius)
		var height := rng.randf_range(min_height, max_height)
		var cloud_size := rng.randf_range(min_cloud_size, max_cloud_size)

		var pos := Vector3(cos(angle) * dist, height, sin(angle) * dist)

		# Create cloud mesh
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Cloud%d" % i

		var quad := QuadMesh.new()
		quad.size = Vector2(cloud_size, cloud_size * rng.randf_range(0.3, 0.6))

		# Create unique material per cloud (different seed = different shape)
		var mat := ShaderMaterial.new()
		mat.shader = _cloud_shader
		mat.set_shader_parameter("cloud_seed", rng.randf_range(0.0, 1000.0))
		mat.set_shader_parameter("cloud_density", rng.randf_range(0.45, 0.7))
		mat.set_shader_parameter("cloud_softness", rng.randf_range(0.15, 0.35))
		mat.set_shader_parameter("scale", rng.randf_range(0.8, 1.5))
		mat.set_shader_parameter("drift_speed", rng.randf_range(0.001, 0.003))
		mat.set_shader_parameter("cloud_color", Color(1.0, 1.0, 1.0, rng.randf_range(0.7, 0.95)))
		mat.set_shader_parameter("cloud_shadow_color", Color(0.65, 0.7, 0.82, 1.0))
		quad.material = mat

		mesh_inst.mesh = quad
		mesh_inst.position = pos
		mesh_inst.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF

		add_child(mesh_inst)
		clouds.append(mesh_inst)

		# Slight random speed variation per cloud
		var speed_var := rng.randf_range(0.7, 1.3)
		cloud_velocities.append(wind_dir_3d * wind_speed * speed_var)


func _process(delta: float) -> void:
	# Drift clouds and wrap around when they go too far
	for i in range(clouds.size()):
		clouds[i].position += cloud_velocities[i] * delta

		# Wrap clouds that drift too far from origin
		var dist := Vector2(clouds[i].position.x, clouds[i].position.z).length()
		if dist > spawn_radius * 1.5:
			# Teleport to opposite side
			clouds[i].position.x = -clouds[i].position.x * 0.8
			clouds[i].position.z = -clouds[i].position.z * 0.8
