class_name RainFX
extends Node3D
## What the rain does when it lands, round the camera (each screen its own; the
## weather itself is synced): the drops stop at whatever is under them (ground,
## roofs, decks: a heightfield of the scene from above, GPU collision) and splash
## there (a sub-emitter on contact), pock the sea's surface with little rings,
## and pool into puddles on flat ground that grow while it rains and dry after.
## The ship's deck has its own puddles (Ship.wet). Made by Weather with its rain.

const POCKS := 64
const POCK_NEAR := Vector2(2.0, 22.0)
const PUDDLE_CELL := 7.0
const PUDDLE_R := 40.0
const PUDDLES := 48
## Rain soaks the ground fully in WET_TIME s of heavy rain and it dries in DRY_TIME s (as on deck).
const WET_TIME := 50.0
const DRY_TIME := 160.0
const PUDDLE_EVERY := 0.25

## How soaked the ground is (0..1).
var wet := 0.0
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _field: GPUParticlesCollisionHeightField3D
var _pock_mm: MultiMesh
var _pocks: Array = []   # [x, z, age]
var _pock_acc := 0.0
var _sea := {}
var _puddle_mm: MultiMesh
## cell -> [ground point, normal ok] (or [] where there's no puddle)
var _cells := {}
var _puddle_at := Vector3i(1 << 30, 0, 0)
var _puddle_t := 0.0
var _puddle_pending := false
var _rng := RandomNumberGenerator.new()


static func make(rain: GPUParticles3D) -> RainFX:
	var fx := RainFX.new()
	fx.name = "RainFX"
	fx._rain = rain
	return fx


func _ready() -> void:
	_rng.randomize()
	top_level = true
	# the drops stop on contact with the scene's surfaces (seen from above) and splash
	var pm := _rain.process_material as ParticleProcessMaterial
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.collision_use_scale = false
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	pm.sub_emitter_amount_at_collision = 2
	_rain.collision_base_size = 0.05
	_field = GPUParticlesCollisionHeightField3D.new()
	_field.name = "RainField"
	_field.size = Vector3(56.0, 64.0, 56.0)
	_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	# (decks move under the rain: redrawn every frame while it rains)
	_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	_field.visible = false
	add_child(_field)
	_splash = GPUParticles3D.new()
	_splash.name = "RainSplash"
	_splash.amount = 1200
	_splash.lifetime = 0.3
	_splash.local_coords = false
	_splash.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3.UP
	spm.spread = 55.0
	spm.initial_velocity_min = 0.6
	spm.initial_velocity_max = 1.6
	spm.gravity = Vector3(0.0, -9.0, 0.0)
	spm.scale_min = 0.6
	spm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	spm.color_ramp = ramp
	_splash.process_material = spm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.08, 0.08)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(0.72, 0.76, 0.82)
	dm.roughness = 0.4
	drop.material = dm
	_splash.draw_pass_1 = drop
	add_child(_splash)
	_rain.sub_emitter = _rain.get_path_to(_splash)
	_pock_mm = _multimesh(POCKS, _pock_mat(), 0.8)
	_puddle_mm = _multimesh(PUDDLES, _puddle_mat(), 1.0)


func _multimesh(count: int, mat: Material, size: float) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mmi)
	return mm


## A ring 8 px across (a raindrop's pock on the water).
func _pock_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			var d := Vector2(x - 3.5, y - 3.5).length()
			if d > 2.2 and d < 3.7:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.8, 0.86, 0.9)
	m.roughness = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Standing water: the dither puddle loop (gen_dither_fx.py), glossy, faded in by its instance's alpha.
## A decal (PSXMat.decal_sheet): pulled toward the camera rather than floated, so slopes and the snapped
## ground don't poke through it.
func _puddle_mat() -> ShaderMaterial:
	return PSXMat.decal_sheet("dither_puddle_rain", Color.WHITE, {"roughness": 0.06, "specular": 0.9, "fps": 5.0})


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var wx := get_node_or_null("/root/Weather")
	if cam == null or wx == null:
		return
	var rain: float = float(wx.get("rain"))
	var shelter: float = float(wx.get("_shelter"))
	wet = clampf(wet + (delta / WET_TIME * rain if rain > 0.05 else -delta / DRY_TIME), 0.0, 1.0)
	var c := cam.global_position
	_field.visible = rain > 0.02
	_field.global_position = Vector3(snappedf(c.x, 1.0), snappedf(c.y, 1.0) + 6.0, snappedf(c.z, 1.0))
	_water_pocks(delta, c, rain * (1.0 - shelter * 0.9))
	_puddles(c, delta)


# --------------------------------------------------------------------------
# Pocks on the sea
# --------------------------------------------------------------------------
func _water_pocks(delta: float, c: Vector3, amt: float) -> void:
	_pock_acc += delta * amt * 160.0
	while _pock_acc >= 1.0 and _pocks.size() < POCKS:
		_pock_acc -= 1.0
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf_range(POCK_NEAR.x * POCK_NEAR.x, POCK_NEAR.y * POCK_NEAR.y))
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		if _is_sea(x, z):
			_pocks.append([x, z, 0.0])
	_pock_acc = minf(_pock_acc, 4.0)
	var keep := 0
	for p in _pocks:
		p[2] = float(p[2]) + delta
		if float(p[2]) < 0.4:
			_pocks[keep] = p
			keep += 1
	_pocks.resize(keep)
	_pock_mm.visible_instance_count = _pocks.size()
	for i in range(_pocks.size()):
		var p: Array = _pocks[i]
		var k := float(p[2]) / 0.4
		var at := Vector3(p[0], 0.0, p[1])
		at.y = float(Ocean.get_wave_height(at)) + 0.03
		_pock_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.25 + 0.75 * k)), at))
		_pock_mm.set_instance_color(i, Color(1, 1, 1, 0.8 * (1.0 - k)))


## Open water at (x, z) with nothing over it (judged once per 4 m cell; a hull over it isn't kept).
func _is_sea(x: float, z: float) -> bool:
	var key := Vector2i(floori(x / 4.0), floori(z / 4.0))
	if _sea.has(key):
		return _sea[key]
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -40.0, z), 1))
	var sea := hit.is_empty() or (hit["position"] as Vector3).y < -0.4
	if not hit.is_empty() and (hit["collider"] as Node).is_in_group("ship"):
		return false
	if _sea.size() > 4096:
		_sea.clear()
	_sea[key] = sea
	return sea


# --------------------------------------------------------------------------
# Puddles on flat ground
# --------------------------------------------------------------------------
## Each 7 m cell near the camera may hold a puddle (decided by the cell, so they
## stay put): flat ground open to the sky, not the ship (she has her own).
func _puddles(c: Vector3, delta: float) -> void:
	if wet <= 0.01:
		_puddle_mm.visible_instance_count = 0
		return
	var n := 0
	var reach := ceili(PUDDLE_R / PUDDLE_CELL)
	var cx := floori(c.x / PUDDLE_CELL)
	var cz := floori(c.z / PUDDLE_CELL)
	# (laid out again when the camera moves a metre, cells are still to be judged, or the wet has grown a little)
	var cam_cell := Vector3i(roundi(c.x), roundi(c.z), 0)
	_puddle_t -= delta
	if cam_cell == _puddle_at and not _puddle_pending and _puddle_t > 0.0:
		return
	_puddle_at = cam_cell
	_puddle_t = PUDDLE_EVERY
	_puddle_pending = false
	var looked := 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if n >= PUDDLES:
				break
			var key := Vector2i(cx + dx, cz + dz)
			if not _cells.has(key):
				# (a few new cells a frame)
				if looked >= 6:
					_puddle_pending = true
					continue
				looked += 1
				_cells[key] = _cell(key)
			var e: Array = _cells[key]
			if e.is_empty():
				continue
			var at: Vector3 = e[0]
			if Vector2(at.x - c.x, at.z - c.z).length() > PUDDLE_R:
				continue
			var size := float(e[1]) * clampf(wet * 1.4 - 0.15, 0.0, 1.0)
			if size < 0.05:
				continue
			_puddle_mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, float(e[2])).scaled(Vector3(size, 1.0, size * float(e[3]))), at + Vector3.UP * 0.05))
			_puddle_mm.set_instance_color(n, Color(1, 1, 1, clampf(wet * 2.0, 0.0, 0.65)))
			n += 1
	_puddle_mm.visible_instance_count = n
	if _cells.size() > 2048:
		_cells.clear()


## [ground point, size, yaw, stretch] for a cell's puddle, or [] if it has none.
func _cell(key: Vector2i) -> Array:
	var h := absi(hash(key))
	if h % 100 >= 45:
		return []
	var u := float(h % 997) / 997.0
	var v := float((h / 997) % 991) / 991.0
	var p := Vector3((key.x + 0.15 + 0.7 * u) * PUDDLE_CELL, 60.0, (key.y + 0.15 + 0.7 * v) * PUDDLE_CELL)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 100.0, 1))
	if hit.is_empty():
		return []
	var col := hit["collider"] as Node
	var at: Vector3 = hit["position"]
	if (hit["normal"] as Vector3).y < 0.97 or at.y < 0.6 or col.is_in_group("ship") or col.is_in_group("enemy_ships"):
		return []
	return [at, 1.2 + 2.2 * u, v * TAU, 0.6 + 0.4 * v]
