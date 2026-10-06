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
const _nav_baker = preload("res://scripts/world/nav_baker.gd")

var heightmap: Array = []
var island_positions: Array[Vector3] = []  # (x, peak_height, z)
var island_infos: Array[Dictionary] = []   # procedural islands: {pos, type, radius}
var starter_island: StarterIsland
var starter_center := Vector2.ZERO
var redtide: RedtideFort
var fleet: EnemyFleet

var _decor := {}  # name -> Array[Mesh]


func _ready() -> void:
	GrapplePoints.clear()
	_generate_world()


func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	# Step 1: Determine island center positions
	var centers: Array[Dictionary] = []

	# First island near player spawn
	centers.append({"pos": Vector2(150.0, 150.0), "radius": 160.0, "peak": 4.0, "type": "town", "starter": true})

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
	_build_decor_meshes()
	var nav_islands: Array = []
	for i in range(centers.size()):
		var c: Dictionary = centers[i]
		if c.get("starter", false):
			_build_starter_island(c)
			continue
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
		nav_islands.append([island, radius])
		_decorate_island(island, Vector2(pos.x, pos.y), radius, island_type, world_seed + i * 131, result["dock_world_pos"])

		# Track for other systems
		var peak_y := _sample_height(pos.x, pos.y)
		island_positions.append(Vector3(pos.x, peak_y, pos.y))
		island_infos.append({"pos": Vector2(pos.x, pos.y), "type": island_type, "radius": radius})

		# Connect all docking areas to board the ship
		var dock_area := island.get_node_or_null("DockingArea")
		if dock_area and dock_area is Interactable:
			dock_area.interacted.connect(_on_dock_interacted)

	_build_redtide()
	if not Net.is_client():
		var baker := _nav_baker.new()
		baker.name = "NavBaker"
		baker.gen = self
		baker.add_zone(starter_island, StarterIsland.HALF, false)
		baker.add_zone(redtide, 70.0, false)
		for z in nav_islands:
			baker.add_zone(z[0], z[1], true)
		add_child(baker)
	_register_dialogue_tokens()
	print("WorldGenerator: Generated terrain with %d islands (seed: %d)" % [centers.size(), world_seed])


func _on_dock_interacted(player: Player) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if not ship or player.context != Player.Context.ON_FOOT:
		return
	# Teleport player to ship and enter helm
	player.current_ship = ship
	player.global_position = ship.helm_position.global_position
	player.reset_physics_interpolation()
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
				if c.get("starter", false):
					# Hand-built island sits here: keep the seafloor below its chunk
					var sp: Vector2 = c["pos"]
					if absf(wx - sp.x) < 215.0 and absf(wz - sp.y) < 215.0:
						h = minf(h, seafloor_depth - 3.0)
					continue
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
	return PSXMat.terrain(false, water_level)


func _sample_height(wx: float, wz: float) -> float:
	var gx := clampi(int((wx / terrain_size + 0.5) * float(terrain_resolution)), 0, terrain_resolution)
	var gz := clampi(int((wz / terrain_size + 0.5) * float(terrain_resolution)), 0, terrain_resolution)
	if gz < heightmap.size():
		var row: PackedFloat32Array = heightmap[gz]
		if gx < row.size():
			return row[gx]
	return 0.0


## Exact height of the rendered world terrain (matches the mesh triangles).
func height_at(wx: float, wz: float) -> float:
	var cell := terrain_size / float(terrain_resolution)
	var fx := (wx + terrain_size * 0.5) / cell
	var fz := (wz + terrain_size * 0.5) / cell
	var ix := clampi(int(floor(fx)), 0, terrain_resolution - 1)
	var iz := clampi(int(floor(fz)), 0, terrain_resolution - 1)
	var u := clampf(fx - ix, 0.0, 1.0)
	var v := clampf(fz - iz, 0.0, 1.0)
	var r0: PackedFloat32Array = heightmap[iz]
	var r1: PackedFloat32Array = heightmap[iz + 1]
	var h00 := r0[ix]
	var h10 := r0[ix + 1]
	var h01 := r1[ix]
	var h11 := r1[ix + 1]
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


# --------------------------------------------------------------------------
# Starter island (Brinehollow)
# --------------------------------------------------------------------------
func _build_starter_island(c: Dictionary) -> void:
	var pos: Vector2 = c["pos"]
	starter_center = pos
	starter_island = StarterIsland.new()
	starter_island.name = "Brinehollow"
	starter_island.position = Vector3(pos.x, 0.0, pos.y)
	add_child(starter_island)
	var result: Dictionary = starter_island.build(world_seed)
	island_positions.append(Vector3(pos.x, 4.0, pos.y))

	var dock_area := starter_island.get_node_or_null("DockingArea")
	if dock_area and dock_area is Interactable:
		dock_area.interacted.connect(_on_dock_interacted)

	# Moor the ship alongside the dock, bow pointing out to sea
	var outward: Vector3 = result["dock_outward"]
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship:
		var dp: Vector3 = result["dock_world_pos"]
		ship.place(Vector3(dp.x, 0.5, dp.z), atan2(-outward.x, -outward.z))

	# Start the player on the dock, facing the village
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = result["player_spawn"]
		player.reset_physics_interpolation()
		var model := player.get_node_or_null("PlayerModel") as Node3D
		if model:
			model.rotation.y = atan2(outward.x, outward.z)
	for child in get_parent().get_children():
		if child.has_method("shake"):
			(child as Node3D).rotation.y = atan2(outward.x, outward.z)


# --------------------------------------------------------------------------
# Redtide Rock (the pirate captain's fort) and the pirate ships at sea
# --------------------------------------------------------------------------
func _deep_enough(c: Vector2, r: float) -> bool:
	if height_at(c.x, c.y) > -12.0:
		return false
	for k in range(16):
		var q: Vector2 = c + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * r
		if height_at(q.x, q.y) > -12.0:
			return false
	for info in island_infos:
		if c.distance_to(info["pos"]) < float(info["radius"]) + r + 80.0:
			return false
	return true


func _build_redtide() -> void:
	# north of Brinehollow, past the harbour (or the nearest clear stretch)
	var spot := starter_center + Vector2(0, -400)
	if not _deep_enough(spot, 60.0):
		var found := false
		for r in [400.0, 460.0, 520.0]:
			for k in range(24):
				var a := -PI * 0.5 + (k / 2 + 1) * (TAU / 24.0) * (1.0 if k % 2 == 0 else -1.0)
				var c: Vector2 = starter_center + Vector2(cos(a), sin(a)) * r
				if _deep_enough(c, 60.0):
					spot = c
					found = true
					break
			if found:
				break
	redtide = RedtideFort.new()
	redtide.name = "RedtideRock"
	var to_home := (starter_center - spot).normalized()
	redtide.position = Vector3(spot.x, 0.0, spot.y)
	redtide.rotation.y = atan2(to_home.x, to_home.y)
	add_child(redtide)
	EnemyShip.safe_center = Vector3(starter_center.x, 0.0, starter_center.y)
	EnemyShip.no_go = [[starter_center, StarterIsland.HALF + 5.0], [spot, 45.0]]
	for info in island_infos:
		EnemyShip.no_go.append([info["pos"], float(info["radius"]) + 30.0])
	fleet = EnemyFleet.new()
	fleet.name = "PirateFleet"
	add_child(fleet)
	fleet.add_zone(Vector3(spot.x, 0.0, spot.y), 115.0)
	# a second patrol on the way out to the nearest island
	var near := Vector2.ZERO
	var best := INF
	for info in island_infos:
		var d := starter_center.distance_to(info["pos"])
		if d < best:
			best = d
			near = info["pos"]
	if best < INF:
		var dir := (near - starter_center).normalized()
		var z2 := starter_center + dir * (EnemyShip.SAFE_RADIUS + 240.0)
		if z2.distance_to(spot) > 220.0:
			fleet.add_zone(Vector3(z2.x, 0.0, z2.y), 110.0)


func redtide_phrase() -> String:
	if redtide == null:
		return "a rock to the north"
	var p := Vector2(redtide.position.x, redtide.position.z)
	var dist := int(round(starter_center.distance_to(p) / 50.0) * 50.0)
	return "out to the %s, some %d meters past the harbour mouth" % [_compass(starter_center, p), dist]


# --------------------------------------------------------------------------
# Procedural island decoration (palms, jungle trees, bushes, rocks)
# --------------------------------------------------------------------------
func _build_decor_meshes() -> void:
	_decor["palm"] = [Props.palm_mesh(101), Props.palm_mesh(102), Props.palm_mesh(103)]
	_decor["jungle"] = [Props.jungle_tree_mesh(201), Props.jungle_tree_mesh(202)]
	_decor["bush"] = [Props.bush_mesh(301), Props.bush_mesh(302)]
	_decor["rock"] = [Props.rock_mesh(401, 1.0), Props.rock_mesh(402, 1.0, true)]
	_decor["grass"] = [Props.grass_mesh()]


func _decorate_island(island: Node3D, center: Vector2, radius: float, island_type: String, seed_value: int, dock_world: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var buckets := {}
	var colliders := StaticBody3D.new()
	colliders.name = "DecorColliders"
	colliders.collision_layer = 1
	colliders.collision_mask = 0
	island.add_child(colliders)
	var jungle_bias := 0.45 if island_type == "wild" else (0.15 if island_type == "pirate" else 0.05)
	var dock2 := Vector2(dock_world.x, dock_world.z)
	var step := 6.0
	var x := -radius
	while x <= radius:
		var z := -radius
		while z <= radius:
			var p := center + Vector2(x + rng.randf_range(-2.5, 2.5), z + rng.randf_range(-2.5, 2.5))
			z += step
			if p.distance_to(center) > radius * 1.05:
				continue
			if p.distance_to(dock2) < 60.0:
				continue
			var h := height_at(p.x, p.y)
			if h < 0.8:
				continue
			var e := 2.0
			var nrm := Vector3(height_at(p.x - e, p.y) - height_at(p.x + e, p.y), 2.0 * e, height_at(p.x, p.y - e) - height_at(p.x, p.y + e)).normalized()
			var slope := 1.0 - nrm.y
			var roll := rng.randf()
			var beach := 1.0 - smoothstep(2.0, 4.0, h)
			var kind := ""
			if slope > 0.5:
				kind = "rock" if roll < 0.25 else ""
			elif roll < 0.25 * beach + 0.04:
				kind = "palm"
			elif roll < 0.25 * beach + 0.04 + jungle_bias * (1.0 - beach):
				kind = "jungle"
			elif roll < 0.25 * beach + 0.1 + jungle_bias * (1.0 - beach):
				kind = "bush"
			elif roll < 0.25 * beach + 0.13 + jungle_bias * (1.0 - beach):
				kind = "rock"
			elif roll < 0.6:
				kind = "grass"
			if kind == "":
				continue
			var meshes: Array = _decor[kind]
			var mesh: Mesh = meshes[rng.randi() % meshes.size()]
			var s := rng.randf_range(0.8, 1.3) * (rng.randf_range(0.6, 2.0) if kind == "rock" else 1.0)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var local := Vector3(p.x, h - 0.15, p.y) - island.position
			if not buckets.has(mesh):
				buckets[mesh] = []
			buckets[mesh].append(Transform3D(basis, local))
			if kind == "palm" or kind == "jungle":
				GrapplePoints.add(island, local + basis * GrapplePoints.crown_of(mesh))
			if kind == "palm" or kind == "jungle" or (kind == "rock" and s > 0.9):
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.4 * s if kind != "rock" else 0.8 * s
				cyl.height = 3.0
				cs.shape = cyl
				cs.position = local + Vector3(0, 1.5, 0)
				colliders.add_child(cs)
		x += step
	for mesh in buckets.keys():
		var xforms: Array = buckets[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		island.add_child(mmi)


# --------------------------------------------------------------------------
# Dialogue tokens (NPCs can mention real islands of this world)
# --------------------------------------------------------------------------
const _TYPE_DESC := {
	"wild": "an untamed jungle isle",
	"pirate": "a pirate haven",
	"military": "a Marine fort",
	"town": "a trading town",
}
const _COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


func _compass(from: Vector2, to: Vector2) -> String:
	var d := to - from
	var ang := atan2(d.x, -d.y)  # 0 = north (-Z), clockwise
	var idx := int(round(ang / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return _COMPASS[idx]


func _island_phrase(info: Dictionary) -> String:
	var pos: Vector2 = info["pos"]
	var dist := int(round(starter_center.distance_to(pos) / 50.0) * 50.0)
	return "%s to the %s, some %d meters out" % [_TYPE_DESC.get(info["type"], "an island"), _compass(starter_center, pos), dist]


func _register_dialogue_tokens() -> void:
	var dm := get_node_or_null("/root/Dialogue")
	if dm == null or island_infos.is_empty():
		return
	dm.register_token("rumor", func() -> String:
		var info: Dictionary = island_infos[randi() % island_infos.size()]
		return _island_phrase(info))
	dm.register_token("nearest_island", func() -> String:
		var best: Dictionary = island_infos[0]
		for info in island_infos:
			if starter_center.distance_to(info["pos"]) < starter_center.distance_to(best["pos"]):
				best = info
		return _island_phrase(best))
	dm.register_token("redtide", func() -> String:
		return redtide_phrase())
	dm.register_token("banked", func() -> String:
		var gm := get_node_or_null("/root/GameManager")
		return str(gm.banked_count() if gm else 0))
