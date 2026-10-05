extends Node3D
class_name PuffClouds
## Physical 3D clouds: big low-poly-feeling volumes built from soft
## camera-facing puffs (one MultiMesh, PS1 dithered transparency), drifting
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

## clouds: {base: Vector3 (world, unwrapped), radii: Vector3, puffs: [[offset, size, shade]], thr: float}
var clouds: Array = []
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _drift := Vector3.ZERO
var _total: int = 0
var _t: float = 0.0


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
	for j in range(_total):
		_mm.set_instance_custom_data(j, Color(float(j) * 0.618, 0, 0, 0))
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


func _process(delta: float) -> void:
	_t += delta
	var w := Vector3(wind.x, 0.0, wind.y).normalized()
	_drift += w * wind_speed * delta
	var cam := get_viewport().get_camera_3d()
	var around := cam.global_position if cam else Vector3.ZERO
	_mat.set_shader_parameter("lit_color", lit_color)
	_mat.set_shader_parameter("shade_color", shade_color)
	_mat.set_shader_parameter("time_s", _t)
	var k := _scale_of()
	var dark := 1.0 - storm * 0.45
	var i := 0
	for c in clouds:
		var v := _vis(c)
		var cc := center_of(c, around)
		for p in c["puffs"]:
			var off: Vector3 = p[0]
			var s: float = float(p[1]) * k
			if v <= 0.0:
				_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), cc))
				_mm.set_instance_color(i, Color(1, 1, 1, 0))
			else:
				_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * 0.8, s)), cc + off * k))
				var sh: float = float(p[2]) * dark
				_mm.set_instance_color(i, Color(sh, sh, sh, v * lerpf(0.92, 1.0, storm)))
			i += 1
