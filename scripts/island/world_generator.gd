class_name WorldGenerator
extends Node3D

@export var world_seed: int = 42
@export var terrain_size: float = 5000.0
@export var terrain_resolution: int = 256
@export var water_level: float = 0.0
@export var seafloor_depth: float = -25.0
@export var base_noise_scale: float = 3.0
@export var enemy_scene: PackedScene

const _terrain_shader = preload("res://scenes/island/terrain.gdshader")
const _nav_baker = preload("res://scripts/world/nav_baker.gd")
const _sea_features = preload("res://scripts/world/sea_features.gd")

var heightmap: Array = []
## The chain's islands built in this world ({pos, type, radius, name}; the sea chart and charting read it).
var island_infos: Array[Dictionary] = []
var starter_island: StarterIsland
var starter_center := Vector2.ZERO
var redtide: RedtideFort
var fleet: EnemyFleet
var _chain: Chain
## The chain's islands standing in the world now: node id -> GenIsland.
var chain_islands := {}
## ...and those still being worked out on a worker thread: node id -> [GenIsland, task, started usec]
var _pending := {}
var _sync_t := 0.0
## The chain seed the islands standing now were built from.
var _built_seed := 0


func _ready() -> void:
	add_to_group("world_gen")
	GrapplePoints.clear()
	_generate_world()


func _process(delta: float) -> void:
	_finish_ready()
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		sync_chain_islands()


## The islands the log pose points at (and the one the crew is at) stand in
## the world; the rest are freed. Each is worked out on a worker thread
## (GenIsland.prepare), then put in the world in a frame (finish).
func sync_chain_islands() -> void:
	# (a guest builds the host's chain: nothing until the host's world state is here)
	if Net.is_client() and not Net.world_synced:
		return
	var c := chain()
	# a load or the host's world gave us another chain: all of this one goes
	if c.seed_value != _built_seed:
		_built_seed = c.seed_value
		for id in chain_islands.keys():
			_free_chain_island(id)
		for e in _pending.values():
			WorkerThreadPool.wait_for_task_completion(e[1])
			(e[0] as Node).free()
		_pending.clear()
	if not Net.is_client():
		_check_arrival()
	for id in chain_islands.keys():
		if not _wanted().has(id):
			_free_chain_island(id)
	for id in _wanted():
		if not chain_islands.has(id) and not _pending.has(id):
			_start_chain_island(c.node(id))


## Every island wanted is built and its crews have turned up (tests, co-op).
func chain_ready() -> bool:
	if not _pending.is_empty() or chain_islands.size() < _wanted().size():
		return false
	for isl in chain_islands.values():
		for camp in (isl as Node).find_children("*", "GruntCamp", true, false):
			if not (camp as GruntCamp)._warming.is_empty():
				return false
	return true


## The island we're at, and (once the log pose has set) the ones it points to.
func _wanted() -> Array:
	var gm := get_node("/root/GameManager")
	var at := int(gm.chain_at)
	var want: Array = chain().next_of(at).duplicate() if gm.log_pose_set() else []
	if at >= 0:
		want.append(at)
	return want


## Host: a captain well onto one of the islands ahead - the crew is there now.
func _check_arrival() -> void:
	var gm := get_node("/root/GameManager")
	for id in chain().next_of(int(gm.chain_at)):
		if not chain_islands.has(id):
			continue
		var isl: GenIsland = chain_islands[id]
		var c := Vector2(isl.position.x, isl.position.z)
		for p in Net.all_players():
			var pp := p as Node3D
			if Vector2(pp.global_position.x, pp.global_position.z).distance_to(c) < isl.radius * 0.8:
				gm.chain_arrive(id)
				return


func _start_chain_island(n: Dictionary) -> void:
	# (the theme's meshes are made here: prepare only reads them)
	IslandTheme.meshes(str(n["theme"]))
	var isl := GenIsland.new()
	isl.name = "Isle%d" % int(n["id"])
	var p: Vector2 = n["pos"]
	isl.position = Vector3(p.x, 0.0, p.y)
	_pending[int(n["id"])] = [isl, WorkerThreadPool.add_task(isl.prepare.bind(n)), Time.get_ticks_usec()]


func _finish_ready() -> void:
	for id in _pending.keys():
		var e: Array = _pending[id]
		if not WorkerThreadPool.is_task_completed(e[1]):
			continue
		WorkerThreadPool.wait_for_task_completion(e[1])
		_pending.erase(id)
		if _wanted().has(id):
			_finish_chain_island(e[0], int(e[2]))
		else:
			(e[0] as Node).free()


func _finish_chain_island(isl: GenIsland, t0: int) -> void:
	var n := isl.node
	var p: Vector2 = n["pos"]
	var t1 := Time.get_ticks_usec()
	add_child(isl)
	isl.finish()
	chain_islands[int(n["id"])] = isl
	island_infos.append({"pos": p, "type": n["theme"], "radius": isl.radius, "name": n["name"], "id": int(n["id"])})
	EnemyShip.no_go.append([p, isl.radius + 30.0])
	(isl.find_child("DockingArea", true, false) as Interactable).interacted.connect(_on_dock_interacted)
	isl.set_meta("shoals", isl.shallows())
	_send_isle_shoals()
	# (built after the save was applied: its chests opened before are gone)
	var gm := get_node("/root/GameManager")
	for bag in isl.find_children("*", "LootBag", true, false):
		if (bag as LootBag).save_id != "" and gm.opened.has((bag as LootBag).save_id):
			bag.queue_free()
	print("GenIsland: %s (%s, r %.0f m, %d px) ready in %d ms, %d ms of it on the main thread %s" % [n["name"], n["theme"], isl.radius, isl.res,
		(Time.get_ticks_usec() - t0) / 1000, (Time.get_ticks_usec() - t1) / 1000, isl.build_ms])


func _free_chain_island(id: int) -> void:
	var isl: GenIsland = chain_islands[id]
	chain_islands.erase(id)
	var p := Vector2(isl.position.x, isl.position.z)
	island_infos = island_infos.filter(func(info): return int(info.get("id", -1)) != id)
	EnemyShip.no_go = EnemyShip.no_go.filter(func(z): return (z[0] as Vector2) != p)
	isl.queue_free()
	_send_isle_shoals()


func _send_isle_shoals() -> void:
	var list: Array = []
	for isl in chain_islands.values():
		if list.size() < Ocean.MAX_ISLES:
			list.append(isl.get_meta("shoals"))
	Ocean.isle_shoals = list


## The island chain from GameManager.chain_seed (remade when a load or a host's world changes it).
## It runs from Brinehollow out past Redtide Rock.
func chain() -> Chain:
	var gm := get_node("/root/GameManager")
	if _chain == null or _chain.seed_value != int(gm.chain_seed):
		var rp := Vector2(redtide.position.x, redtide.position.z)
		_chain = Chain.make(int(gm.chain_seed), starter_center, rp - starter_center)
	return _chain


func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	# Step 1: Brinehollow (the chain's islands are built as the crew sails to them)
	var centers: Array[Dictionary] = []
	centers.append({"pos": Vector2(150.0, 150.0), "radius": 160.0, "peak": 4.0, "type": "town", "starter": true})

	# Step 2: Generate continuous heightmap
	heightmap = _generate_heightmap(centers, rng)

	# Step 3: Build terrain mesh (in chunks, so the view and the sun's shadow
	# passes only draw the parts near them; one collision shape for it all)
	var material := _create_terrain_material()

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "WorldTerrain"
	terrain_body.collision_layer = 1

	var faces := PackedVector3Array()
	for cz in range(TERRAIN_CHUNKS):
		for cx in range(TERRAIN_CHUNKS):
			var mesh_inst := MeshInstance3D.new()
			mesh_inst.name = "Chunk%d_%d" % [cx, cz]
			mesh_inst.mesh = _build_chunk(cx, cz, faces)
			mesh_inst.material_override = material
			terrain_body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	col.shape = shape
	terrain_body.add_child(col)

	add_child(terrain_body)

	_build_starter_island(centers[0])
	_build_redtide()
	bake_shallows()
	var features := _sea_features.new()
	features.name = "SeaFeatures"
	features.gen = self
	add_child(features)
	if not Net.is_client():
		var baker := _nav_baker.new()
		baker.name = "NavBaker"
		baker.gen = self
		baker.add_zone(starter_island, StarterIsland.LAND_R, false)
		baker.add_zone(redtide, 70.0, false)
		add_child(baker)
	_register_dialogue_tokens()
	print("WorldGenerator: Generated terrain with %d islands (seed: %d)" % [centers.size(), world_seed])


func _on_dock_interacted(player: Player) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if not ship or player.context != Player.Context.ON_FOOT:
		return
	if not ship.owned():
		player.call("_toast", "She isn't yours to sail. Tackett's still working on her.")
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
					if absf(wx - sp.x) < StarterIsland.HALF + 5.0 and absf(wz - sp.y) < StarterIsland.HALF + 5.0:
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


const TERRAIN_CHUNKS := 8


## One square of the terrain grid (its triangles also go into `faces`).
func _build_chunk(cx: int, cz: int, faces: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := terrain_size / float(terrain_resolution)
	var half := terrain_size * 0.5
	var n := terrain_resolution / TERRAIN_CHUNKS

	for z in range(cz * n, mini((cz + 1) * n, terrain_resolution)):
		var r0: PackedFloat32Array = heightmap[z]
		var r1: PackedFloat32Array = heightmap[z + 1]
		for x in range(cx * n, mini((cx + 1) * n, terrain_resolution)):
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
			faces.append(p_tl)
			faces.append(p_tr)
			faces.append(p_bl)
			faces.append(p_tr)
			faces.append(p_br)
			faces.append(p_bl)

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


## The seabed's depth for the ocean shader's turquoise shallows: the world
## terrain (a texel per heightmap point) and Brinehollow's own, finer.
func bake_shallows() -> void:
	var n := terrain_resolution + 1
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	for z in range(n):
		var row: PackedFloat32Array = heightmap[z]
		for x in range(n):
			img.set_pixel(x, z, Color(_shoal(row[x]), 0, 0))
	var cell := terrain_size / float(terrain_resolution)
	Ocean.shoal_map = ImageTexture.create_from_image(img)
	Ocean.shoal_rect = Vector4(-terrain_size * 0.5 - cell * 0.5, -terrain_size * 0.5 - cell * 0.5, terrain_size + cell, 1.0)
	var fine := Image.create(StarterIsland.RES, StarterIsland.RES, false, Image.FORMAT_L8)
	for z in range(StarterIsland.RES):
		for x in range(StarterIsland.RES):
			var lx := -StarterIsland.HALF + (x + 0.5) * StarterIsland.CELL
			var lz := -StarterIsland.HALF + (z + 0.5) * StarterIsland.CELL
			fine.set_pixel(x, z, Color(_shoal(starter_island.height_at(lx, lz)), 0, 0))
	Ocean.shoal_fine = ImageTexture.create_from_image(fine)
	Ocean.fine_rect = Vector4(starter_center.x - StarterIsland.HALF, starter_center.y - StarterIsland.HALF, StarterIsland.HALF * 2.0, 1.0)


func _shoal(h: float) -> float:
	return clampf(-h / Ocean.SHOAL_DEPTH, 0.0, 1.0)


func _exit_tree() -> void:
	# (the title screen's sea has no shoals)
	Ocean.shoal_rect = Vector4.ZERO
	Ocean.fine_rect = Vector4.ZERO
	Ocean.isle_shoals = []
	for e in _pending.values():
		WorkerThreadPool.wait_for_task_completion(e[1])
		(e[0] as Node).free()
	_pending.clear()
	Humanoid.clear_prebuilt()


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
	EnemyShip.no_go = []
	for z in StarterIsland.NO_GO:
		EnemyShip.no_go.append([starter_center + (z[0] as Vector2), z[1]])
	EnemyShip.no_go.append([spot, 45.0])
	fleet = EnemyFleet.new()
	fleet.name = "PirateFleet"
	add_child(fleet)
	fleet.add_zone(Vector3(spot.x, 0.0, spot.y), 115.0, ["sloop", "brig"])
	var lanes: Array = [Vector3(spot.x, 0.0, spot.y)]
	# gunboats on the way out past Redtide, where the log pose points
	var z2 := spot + (spot - starter_center).normalized() * 320.0
	if _deep_enough(z2, 110.0):
		fleet.add_zone(Vector3(z2.x, 0.0, z2.y), 110.0, ["gunboat", "sloop"])
		lanes.append(Vector3(z2.x, 0.0, z2.y))
	# further out: a Marine patrol and a heavy brig's hunting ground, on open water
	var picks := [["marine"], ["brig", "gunboat"]]
	for pi in range(picks.size()):
		var c := _open_sea(lanes, 600.0 + 250.0 * pi, pi * 1.7)
		if c != Vector3.INF:
			fleet.add_zone(c, 120.0, picks[pi])
			lanes.append(c)


## Deep water clear of land at about `r` from Brinehollow, well apart from
## the other patrol lanes (INF if there's none).
func _open_sea(lanes: Array, r: float, a0: float) -> Vector3:
	for k in range(36):
		var a := a0 + k * TAU / 36.0
		var c := starter_center + Vector2(cos(a), sin(a)) * r
		var c3 := Vector3(c.x, 0.0, c.y)
		if not _deep_enough(c, 120.0) or not EnemyShip.huntable_at(c3):
			continue
		var apart := true
		for l in lanes:
			if c3.distance_to(l) < 400.0:
				apart = false
		if apart:
			return c3
	return Vector3.INF


func redtide_phrase() -> String:
	if redtide == null:
		return "a rock to the north"
	var p := Vector2(redtide.position.x, redtide.position.z)
	var dist := int(round(starter_center.distance_to(p) / 50.0) * 50.0)
	return "out to the %s, some %d meters past the harbour mouth" % [_compass(starter_center, p), dist]


# --------------------------------------------------------------------------
# Dialogue tokens (NPCs can mention real places of this world)
# --------------------------------------------------------------------------
const _COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


func _compass(from: Vector2, to: Vector2) -> String:
	var d := to - from
	var ang := atan2(d.x, -d.y)  # 0 = north (-Z), clockwise
	var idx := int(round(ang / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return _COMPASS[idx]


## Gus's rumours: the chain's first islands (they're out there whether or not
## anyone's log pose has found them yet).
func _rumor() -> String:
	var c := chain()
	var first: Dictionary = c.node(c.start_next[randi() % c.start_next.size()])
	var picks := [
		"%s past Redtide Rock, %s" % [Chain.THEMES[first["theme"]]["blurb"], "if you've a log pose to find it by"],
		"a fort on a sea stack %s. Captain Morrow's. Keeps a log pose, they say" % redtide_phrase(),
		"a whole chain of islands out past Redtide, one after the next, and cities on it bigger than any you've seen",
	]
	return picks[randi() % picks.size()]


func _register_dialogue_tokens() -> void:
	var dm := get_node_or_null("/root/Dialogue")
	if dm == null:
		return
	dm.register_token("rumor", _rumor)
	dm.register_token("nearest_island", func() -> String:
		return "Redtide Rock, " + redtide_phrase())
	dm.register_token("redtide", func() -> String:
		return redtide_phrase())
	dm.register_token("banked", func() -> String:
		var gm := get_node_or_null("/root/GameManager")
		return str(gm.stored_count() if gm else 0))
