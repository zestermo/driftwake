class_name IslandGenerator
extends RefCounted

const TYPE_CONFIGS = {
	"wild": {"size_min": 100.0, "size_max": 200.0, "height_min": 2.0, "height_max": 5.0, "spawns_min": 3, "spawns_max": 5, "loot_min": 2, "loot_max": 4},
	"military": {"size_min": 120.0, "size_max": 180.0, "height_min": 2.0, "height_max": 4.0, "spawns_min": 5, "spawns_max": 8, "loot_min": 2, "loot_max": 3},
	"pirate": {"size_min": 80.0, "size_max": 150.0, "height_min": 2.0, "height_max": 5.0, "spawns_min": 4, "spawns_max": 6, "loot_min": 3, "loot_max": 5},
	"town": {"size_min": 110.0, "size_max": 170.0, "height_min": 1.0, "height_max": 3.0, "spawns_min": 1, "spawns_max": 2, "loot_min": 1, "loot_max": 2},
}

const _interactable_script = preload("res://scripts/interaction/interactable.gd")
const _enemy_spawner_script = preload("res://scripts/island/enemy_spawner.gd")
const _island_script = preload("res://scripts/island/island.gd")


## Create an Island node with spawn points, loot, dock, and enemies.
## Returns {"island": Node3D, "dock_world_pos": Vector3, "dock_outward": Vector3}
static func furnish_island(params: Dictionary) -> Dictionary:
	var island_seed := int(params.get("seed", 0))
	var center: Vector3 = params.get("center", Vector3.ZERO)
	var island_type := str(params.get("island_type", "wild"))
	var island_name := str(params.get("island_name", "Unknown Island"))
	var _peak_height := float(params.get("peak_height", 8.0))
	var radius := float(params.get("radius", 50.0))
	var enemy_scene = params.get("enemy_scene", null)
	var heightmap: Array = params.get("heightmap", [])
	var terrain_size := float(params.get("terrain_size", 1800.0))
	var terrain_res := int(params.get("terrain_resolution", 256))
	var water_level := float(params.get("water_level", 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed

	var island := Node3D.new()
	island.name = island_name.replace(" ", "")
	island.set_script(_island_script)
	island.set("island_name", island_name)
	island.set("island_type", island_type)
	island.position = center

	# Spawn points
	var spawn_container := Node3D.new()
	spawn_container.name = "SpawnPoints"
	island.add_child(spawn_container)

	var config: Dictionary = TYPE_CONFIGS.get(island_type, TYPE_CONFIGS["wild"])
	var spawn_count := rng.randi_range(int(config["spawns_min"]), int(config["spawns_max"]))
	var spawn_positions := _scatter_on_terrain(heightmap, terrain_size, terrain_res, center, radius * 0.6, spawn_count, water_level + 2.0, rng)

	for i in range(spawn_positions.size()):
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % i
		marker.position = spawn_positions[i] - center + Vector3(0, 0.2, 0)
		spawn_container.add_child(marker)

	# Loot spawns
	var loot_container := Node3D.new()
	loot_container.name = "LootSpawns"
	island.add_child(loot_container)

	var loot_count := rng.randi_range(int(config["loot_min"]), int(config["loot_max"]))
	var loot_positions := _scatter_on_terrain(heightmap, terrain_size, terrain_res, center, radius * 0.7, loot_count, water_level + 1.0, rng)

	for i in range(loot_positions.size()):
		var marker := Marker3D.new()
		marker.name = "LootSpawn%d" % i
		marker.position = loot_positions[i] - center + Vector3(0, 0.2, 0)
		loot_container.add_child(marker)

	# Enemy spawner
	var spawner := Node.new()
	spawner.name = "EnemySpawner"
	spawner.set_script(_enemy_spawner_script)
	if enemy_scene:
		spawner.set("enemy_scene", enemy_scene)
	spawner.set("max_enemies", spawn_count)
	island.add_child(spawner)

	# Dock at shoreline — find shore point and outward direction
	var shore_data := _find_shoreline(heightmap, terrain_size, terrain_res, center, radius, water_level, rng)
	var shore_pos: Vector3 = shore_data["pos"]
	var outward_dir: Vector3 = shore_data["outward"]
	var dock_local := shore_pos - center
	_add_dock(island, dock_local, outward_dir, water_level)

	# Return island + dock world position for ship placement (ship sits past the dock end)
	var dock_end_world := shore_pos + outward_dir * 50.0
	return {
		"island": island,
		"dock_world_pos": dock_end_world,
		"dock_outward": outward_dir,
	}


static func _sample_height(heightmap: Array, terrain_size: float, terrain_res: int, wx: float, wz: float) -> float:
	var gx := clampi(int((wx / terrain_size + 0.5) * float(terrain_res)), 0, terrain_res)
	var gz := clampi(int((wz / terrain_size + 0.5) * float(terrain_res)), 0, terrain_res)
	if gz < heightmap.size():
		var row: PackedFloat32Array = heightmap[gz]
		if gx < row.size():
			return row[gx]
	return -10.0


static func _scatter_on_terrain(heightmap: Array, terrain_size: float, terrain_res: int, center: Vector3, scatter_radius: float, count: int, min_height: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var attempts := 0

	while points.size() < count and attempts < count * 50:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(0.0, scatter_radius)
		var wx := center.x + cos(angle) * dist
		var wz := center.z + sin(angle) * dist

		var h := _sample_height(heightmap, terrain_size, terrain_res, wx, wz)
		if h < min_height:
			continue

		var too_close := false
		for p in points:
			if p.distance_to(Vector3(wx, h, wz)) < scatter_radius * 0.25:
				too_close = true
				break
		if too_close:
			continue

		points.append(Vector3(wx, h, wz))

	return points


## Find shoreline: march from center outward, find where terrain crosses water level
## Returns {"pos": Vector3, "outward": Vector3} — the shore point and the outward direction
static func _find_shoreline(heightmap: Array, terrain_size: float, terrain_res: int, center: Vector3, radius: float, water_level: float, rng: RandomNumberGenerator) -> Dictionary:
	var angle := rng.randf_range(0.0, TAU)
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var best_pos := center + outward * radius * 0.8
	best_pos.y = water_level + 1.0

	# March outward from center, find where height drops below water
	var prev_h := 999.0
	for i in range(150):
		var t := float(i) / 150.0
		var wx := center.x + outward.x * radius * 2.0 * t
		var wz := center.z + outward.z * radius * 2.0 * t
		var h := _sample_height(heightmap, terrain_size, terrain_res, wx, wz)

		# Find where terrain actually goes below water
		if prev_h > water_level and h <= water_level:
			best_pos = Vector3(wx, water_level, wz)
			break
		prev_h = h
		prev_h = h

	return {"pos": best_pos, "outward": outward}


## Build a dock that extends from shore outward over water
static func _add_dock(island: Node3D, local_shore_pos: Vector3, outward: Vector3, water_level: float) -> void:
	# Dock extends from shore outward over water — starts well inland to connect
	var dock_center := local_shore_pos + outward * 2.0
	dock_center.y = water_level + 1.0

	var dock_body := StaticBody3D.new()
	dock_body.name = "Dock"
	dock_body.collision_layer = 1
	dock_body.position = dock_center
	dock_body.rotation.y = atan2(-outward.x, -outward.z)
	island.add_child(dock_body)

	var mb := MeshBuilder.new()
	var deck := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var post := PSXMat.lit("planks_dark")
	mb.add_box(deck, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), Vector3(32.0, 0.5, 4.0), 0.5, Color.WHITE, false, false)
	for i in range(9):
		for x in [-1.9, 1.9]:
			mb.add_cylinder(post, Transform3D(Basis(), Vector3(x, -8.0, -16.0 + i * 4.0)), 0.16, 0.16, 8.6, 6, 0.6)
	var dock_mesh_inst := mb.to_instance("MeshInstance3D")
	dock_body.add_child(dock_mesh_inst)

	var dock_col := CollisionShape3D.new()
	dock_col.name = "CollisionShape3D"
	var dock_shape := BoxShape3D.new()
	dock_shape.size = Vector3(4.0, 0.5, 32.0)
	dock_col.shape = dock_shape
	dock_body.add_child(dock_col)

	# Docking interaction area at the end of the dock
	var dock_area := Area3D.new()
	dock_area.name = "DockingArea"
	dock_area.collision_layer = 512
	dock_area.collision_mask = 0
	dock_area.set_script(_interactable_script)
	dock_area.set("prompt_text", "Press F to board ship")
	dock_area.position = dock_center + outward * 18.0
	dock_area.position.y = water_level + 2.0
	island.add_child(dock_area)

	var dock_area_col := CollisionShape3D.new()
	dock_area_col.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 50.0
	dock_area_col.shape = sphere
	dock_area.add_child(dock_area_col)
