extends Node3D
class_name PuffClouds
## Physical 3D clouds: big low-poly-feeling volumes built from soft
## camera-facing puffs (one MultiMesh, blended and sorted back to front each
## frame so they layer properly; the PSX post pass quantises them), drifting
## with the wind and wrapping around the camera so the sky never runs out.
## The weather decides how many there are, how dark and how low; a storm
## pulls them down and turns them grey.
##
## They're real places in the world: density_at(pos) says how deep in cloud a
## point is (0 = clear air, 1 = the thick of it). Weather uses it to white out
## the view when the camera flies into one; flight powers can use it later.

const COUNT := 64
const PERIOD := 2400.0
const HALF := PERIOD * 0.5
const MIN_PUFFS := 7
const MAX_PUFFS := 14

## Driven by Weather each frame.
var coverage: float = 0.35
var storm: float = 0.0
var wind := Vector2(1.0, 0.3)
var wind_speed: float = 4.0
var lit_color := Color(1, 1, 1)
var shade_color := Color(0.62, 0.68, 0.8)
var fog_color := Color(0.5, 0.72, 0.92)
var haze_height: float = 0.08
var fog_begin: float = 90.0
var fog_end: float = 750.0

## clouds: {base: Vector3 (world, unwrapped), radii: Vector3, puffs: [[offset, size, shade]], thr: float}
var clouds: Array = []
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _drift := Vector3.ZERO
var _total: int = 0
var _t: float = 0.0
var _buf := PackedFloat32Array()
var _keys := PackedFloat64Array()
## Per puff, flattened: [cloud index, offset, size, shade, seed]
var _puffs: Array = []

## MultiMesh buffer layout: 12 transform floats, 4 colour, 4 custom.
const STRIDE := 20


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(COUNT):
		var r := Vector3(rng.randf_range(30.0, 75.0), rng.randf_range(12.0, 26.0), rng.randf_range(30.0, 70.0))
		var c := {"base": Vector3(rng.randf_range(-HALF, HALF), rng.randf_range(95.0, 165.0), rng.randf_range(-HALF, HALF)),
			"radii": r, "puffs": [], "thr": rng.randf()}
		var n := rng.randi_range(MIN_PUFFS, MAX_PUFFS)
		for k in range(n):
			# puffs fill an ellipsoid, flatter at the bottom
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 1.0), rng.randf_range(-1, 1))
			if dir.length() > 1.0:
				dir = dir.normalized()
			var off := Vector3(dir.x * r.x * 0.75, dir.y * r.y * 0.7, dir.z * r.z * 0.75)
			var size := rng.randf_range(0.65, 1.0) * (r.x + r.z) * 0.55 * (1.0 - absf(dir.y) * 0.25)
			var shade := 0.82 + 0.18 * clampf((dir.y + 0.35) / 1.35, 0.0, 1.0)
			(c["puffs"] as Array).append([off, size, shade])
			_puffs.append([i, off, size, shade, float(_total + k) * 0.618])
		clouds.append(c)
		_total += n
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_mm.mesh = q
	_mm.instance_count = _total
	_mm.visible_instance_count = 0
	_buf.resize(_total * STRIDE)
	_keys.resize(_total)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/world/cloud_puff.gdshader")
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Puffs"
	_mmi.multimesh = _mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.extra_cull_margin = 16384.0
	_mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_mmi)
	_mm.custom_aabb = AABB(Vector3(-HALF * 2.0, -100.0, -HALF * 2.0), Vector3(PERIOD * 2.0, 600.0, PERIOD * 2.0))


## How visible cloud i is at this coverage (0..1).
func _vis(c: Dictionary) -> float:
	return clampf((coverage - float(c["thr"]) * 0.95) / 0.12 + 0.0, 0.0, 1.0)


## Where cloud i's centre is right now, wrapped to the tile around `around`.
func center_of(c: Dictionary, around: Vector3) -> Vector3:
	var b: Vector3 = c["base"] + _drift
	var x := fposmod(b.x - around.x + HALF, PERIOD) - HALF + around.x
	var z := fposmod(b.z - around.z + HALF, PERIOD) - HALF + around.z
	# storms drag the clouds down and swell them
	var y := lerpf(b.y, b.y * 0.62, storm)
	return Vector3(x, y, z)


func _scale_of() -> float:
	return 1.0 + storm * 0.35


## 0 in clear air .. 1 deep inside a cloud.
func density_at(pos: Vector3) -> float:
	var best := 0.0
	var k := _scale_of()
	for c in clouds:
		var v := _vis(c)
		if v <= 0.0:
			continue
		var cc := center_of(c, pos)
		var r: Vector3 = c["radii"] * k
		var d := Vector3((pos.x - cc.x) / r.x, (pos.y - cc.y) / r.y, (pos.z - cc.z) / r.z).length()
		if d < 1.0:
			best = maxf(best, clampf((1.0 - d) * 2.5, 0.0, 1.0) * v)
	return best


## The sorted buffer is rebuilt REBUILD times a second; in between the layer
## just slides with the wind (far, slow clouds: nobody sees the difference).
const REBUILD := 0.05
var _rebuild_t: float = 0.0
var _drift_built := Vector3.ZERO


func _process(delta: float) -> void:
	_t += delta
	var w := Vector3(wind.x, 0.0, wind.y).normalized()
	_drift += w * wind_speed * delta
	_mat.set_shader_parameter("time_s", _t)
	_rebuild_t -= delta
	if _rebuild_t > 0.0:
		_mmi.position = _drift - _drift_built
		return
	_rebuild_t = REBUILD
	_drift_built = _drift
	_mmi.position = Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var around := cam.global_position if cam else Vector3.ZERO
	_mat.set_shader_parameter("lit_color", lit_color)
	_mat.set_shader_parameter("shade_color", shade_color)
	_mat.set_shader_parameter("fog_color", fog_color)
	_mat.set_shader_parameter("haze_height", haze_height)
	# far clouds thin out (the sky's own cloud layer carries on beyond them),
	# well before the 1.2 km wrap so none ever pops
	var fade_end := clampf(fog_end * 2.0, 500.0, 1150.0)
	_mat.set_shader_parameter("fade", Vector2(fade_end * 0.72, fade_end))
	_mat.set_shader_parameter("fog_range", Vector2(fog_begin, fade_end))
	var k := _scale_of()
	var dark := 1.0 - storm * 0.45
	var alpha_k := lerpf(0.92, 1.0, storm)
	# where each visible cloud is this frame
	var centers := []
	var vis := PackedFloat32Array()
	centers.resize(clouds.size())
	vis.resize(clouds.size())
	for ci in range(clouds.size()):
		var c: Dictionary = clouds[ci]
		vis[ci] = _vis(c)
		if vis[ci] > 0.0:
			var cc := center_of(c, around)
			if Vector2(cc.x - around.x, cc.z - around.z).length() > fade_end + 150.0:
				vis[ci] = 0.0
			centers[ci] = cc
	# back-to-front: blended puffs must be drawn farthest first
	var n := 0
	for pi in range(_puffs.size()):
		var pf: Array = _puffs[pi]
		var ci: int = pf[0]
		if vis[ci] <= 0.0:
			continue
		var pos: Vector3 = centers[ci] + (pf[1] as Vector3) * k
		var dist := pos.distance_to(around)
		_keys[n] = float(20000 - mini(int(dist * 8.0), 19999)) * 4096.0 + float(pi)
		n += 1
	var keys := _keys.slice(0, n)
	keys.sort()
	for j in range(n):
		var pi := int(fposmod(keys[j], 4096.0))
		var pf: Array = _puffs[pi]
		var ci: int = pf[0]
		var pos: Vector3 = centers[ci] + (pf[1] as Vector3) * k
		var s: float = float(pf[2]) * k
		var o := j * STRIDE
		_buf[o] = s; _buf[o + 1] = 0.0; _buf[o + 2] = 0.0; _buf[o + 3] = pos.x
		_buf[o + 4] = 0.0; _buf[o + 5] = s * 0.8; _buf[o + 6] = 0.0; _buf[o + 7] = pos.y
		_buf[o + 8] = 0.0; _buf[o + 9] = 0.0; _buf[o + 10] = s; _buf[o + 11] = pos.z
		var sh: float = float(pf[3]) * dark
		_buf[o + 12] = sh; _buf[o + 13] = sh; _buf[o + 14] = sh; _buf[o + 15] = vis[ci] * alpha_k
		_buf[o + 16] = float(pf[4]); _buf[o + 17] = 0.0; _buf[o + 18] = 0.0; _buf[o + 19] = 0.0
	_mm.buffer = _buf
	_mm.visible_instance_count = n
