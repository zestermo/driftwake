class_name WorldGenerator
extends Node3D

@export var world_seed: int = 42
@export var island_count: int = 6
@export var min_island_distance: float = 500.0
@export var world_radius: float = 2000.0
@export var terrain_size: float = 5000.0
@export var terrain_resolution: int = 256
@export var water_level: float = 0.0
@export var seafloor_depth: float = -25.0
@export var base_noise_scale: float = 3.0
@export var enemy_scene: PackedScene

const _terrain_shader = preload("res://scenes/island/terrain.gdshader")
const _island_script = preload("res://scripts/island/island.gd")

var heightmap: Array = []
var island_positions: Array[Vector3] = []  # (x, peak_height, z)


func _ready() -> void:
	_generate_world()


func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	# Step 1: Determine island center positions
	var centers: Array[Dictionary] = []

	# First island near player spawn
	centers.append({"pos": Vector2(150.0, 150.0), "radius": 160.0, "peak": 4.0, "type": "wild"})

	var type_pool: Array[String] = ["wild", "pirate", "military", "town"]
	var attempts := 0
	while centers.size() < island_count and attempts < island_count * 100:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(min_island_distance * 0.8, world_radius)
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist)

		var valid := true
		for c in centers:
			var cp: Vector2 = c["pos"]
			if pos.distance_to(cp) < min_island_distance:
				valid = false
				break
		if not valid:
			continue

		var island_type: String = type_pool[rng.randi_range(0, type_pool.size() - 1)]
		var config: Dictionary = IslandGenerator.TYPE_CONFIGS.get(island_type, IslandGenerator.TYPE_CONFIGS["wild"])
		centers.append({
			"pos": pos,
			"radius": rng.randf_range(float(config["size_min"]), float(config["size_max"])),
			"peak": rng.randf_range(float(config["height_min"]), float(config["height_max"])),
			"type": island_type,
		})

	# Step 2: Generate continuous heightmap
	heightmap = _generate_heightmap(centers, rng)

	# Step 3: Build terrain mesh
	var mesh := _build_mesh()
	var material := _create_terrain_material()

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "WorldTerrain"
	terrain_body.collision_layer = 1

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	mesh_inst.mesh = mesh
	mesh_inst.material_override = material
	terrain_body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = mesh.create_trimesh_shape()
	terrain_body.add_child(col)

	add_child(terrain_body)

	# Step 4: Furnish each island (spawn points, dock, enemies)
	for i in range(centers.size()):
		var c: Dictionary = centers[i]
		var pos: Vector2 = c["pos"]
		var island_type: String = c["type"]
		var peak: float = c["peak"]
		var radius: float = c["radius"]

		var result: Dictionary = IslandGenerator.furnish_island({
			"seed": world_seed + i * 7919,
			"center": Vector3(pos.x, 0.0, pos.y),
			"island_type": island_type,
			"island_name": "%s Island %d" % [str(island_type).capitalize(), i + 1],
			"peak_height": peak,
			"radius": radius,
			"enemy_scene": enemy_scene,
			"heightmap": heightmap,
			"terrain_size": terrain_size,
			"terrain_resolution": terrain_resolution,
			"water_level": water_level,
		})
		var island: Node3D = result["island"]
		add_child(island)

		# Track for other systems
		var peak_y := _sample_height(pos.x, pos.y)
		island_positions.append(Vector3(pos.x, peak_y, pos.y))

		# Place the ship at the first island's dock
		if i == 0:
			var dock_pos: Vector3 = result["dock_world_pos"]
			var ship := get_tree().get_first_node_in_group("ship") as Ship
			if ship:
				ship.global_position = Vector3(dock_pos.x, 5.0, dock_pos.z)

		# Connect all docking areas to board the ship
		var dock_area := island.get_node_or_null("DockingArea")
		if dock_area and dock_area is Interactable:
			dock_area.interacted.connect(_on_dock_interacted)

	print("WorldGenerator: Generated terrain with %d islands (seed: %d)" % [centers.size(), world_seed])


func _on_dock_interacted(player: Player) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if not ship or player.context != Player.Context.ON_FOOT:
		return
	# Teleport player to ship and enter helm
	player.current_ship = ship
	player.global_position = ship.helm_position.global_position
	var sm := player.state_machine
	if sm.current_state:
		sm.current_state.transitioned.emit(sm.current_state, "Helm", {})


func _generate_heightmap(centers: Array[Dictionary], _rng: RandomNumberGenerator) -> Array:
	# Base seafloor noise
	var floor_noise := FastNoiseLite.new()
	floor_noise.seed = world_seed
	floor_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	floor_noise.frequency = 0.002
	floor_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	floor_noise.fractal_octaves = 2

	# Large terrain features — hills, valleys on island surfaces
	var feature_noise := FastNoiseLite.new()
	feature_noise.seed = world_seed + 9999
	feature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	feature_noise.frequency = 0.008
	feature_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	feature_noise.fractal_octaves = 3
	feature_noise.fractal_lacunarity = 2.0
	feature_noise.fractal_gain = 0.5

	# Small detail — rocks, bumps
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = world_seed + 5555
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.03
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3

	var hmap: Array = []
	var res_f := float(terrain_resolution)

	for z in range(terrain_resolution + 1):
		var row := PackedFloat32Array()
		row.resize(terrain_resolution + 1)
		for x in range(terrain_resolution + 1):
			var wx := (float(x) / res_f - 0.5) * terrain_size
			var wz := (float(z) / res_f - 0.5) * terrain_size

			# Gentle seafloor
			var h := floor_noise.get_noise_2d(wx, wz) * base_noise_scale + seafloor_depth

			# Plateau-style island shapes: flat top with steep edges
			var island_influence := 0.0
			for c in centers:
				var cp: Vector2 = c["pos"]
				var peak: float = c["peak"]
				var radius: float = c["radius"]
				var dx := wx - cp.x
				var dz := wz - cp.y
				var dist := sqrt(dx * dx + dz * dz)

				# Normalized distance (0 at center, 1 at radius edge)
				var t := dist / radius

				# Plateau falloff: flat interior (0 to 0.6), steep drop (0.6 to 1.0), zero beyond
				var plateau: float
				if t < 0.6:
					plateau = 1.0
				elif t < 1.0:
					# Steep cosine falloff from 1 to 0
					var edge_t := (t - 0.6) / 0.4
					plateau = (cos(edge_t * PI) + 1.0) * 0.5
				else:
					plateau = 0.0

				var bump_height := (peak - seafloor_depth + 5.0) * plateau
				h += bump_height
				island_influence = maxf(island_influence, plateau)

			# Add terrain features on islands — hills, ridges, valleys
			if island_influence > 0.05:
				# Large features: hills and valleys (±8m)
				var features := feature_noise.get_noise_2d(wx, wz) * 8.0 * island_influence
				h += features
				# Small detail: rocks and bumps (±1.5m)
				var detail := detail_noise.get_noise_2d(wx, wz) * 1.5 * island_influence
				h += detail

			row[x] = h
		hmap.append(row)

	return hmap


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := terrain_size / float(terrain_resolution)
	var half := terrain_size * 0.5

	for z in range(terrain_resolution):
		var r0: PackedFloat32Array = heightmap[z]
		var r1: PackedFloat32Array = heightmap[z + 1]
		for x in range(terrain_resolution):
			var fx := float(x)
			var fz := float(z)
			var p_tl := Vector3(fx * cell - half, r0[x], fz * cell - half)
			var p_tr := Vector3((fx + 1.0) * cell - half, r0[x + 1], fz * cell - half)
			var p_bl := Vector3(fx * cell - half, r1[x], (fz + 1.0) * cell - half)
			var p_br := Vector3((fx + 1.0) * cell - half, r1[x + 1], (fz + 1.0) * cell - half)
			# CCW winding — normals point UP
			st.add_vertex(p_tl)
			st.add_vertex(p_tr)
			st.add_vertex(p_bl)
			st.add_vertex(p_tr)
			st.add_vertex(p_br)
			st.add_vertex(p_bl)

	st.generate_normals()
	return st.commit()


func _create_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("water_level", water_level)
	mat.set_shader_parameter("sand_height", water_level + 2.0)
	mat.set_shader_parameter("grass_height", water_level + 6.0)
	mat.set_shader_parameter("rock_height", water_level + 12.0)
	return mat


func _sample_height(wx: float, wz: float) -> float:
	var gx := clampi(int((wx / terrain_size + 0.5) * float(terrain_resolution)), 0, terrain_resolution)
	var gz := clampi(int((wz / terrain_size + 0.5) * float(terrain_resolution)), 0, terrain_resolution)
	if gz < heightmap.size():
		var row: PackedFloat32Array = heightmap[gz]
		if gx < row.size():
			return row[gx]
	return 0.0
