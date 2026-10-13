class_name FaunaAmbient
extends Node3D
## Harmless life that makes an island feel lived in, moved on the GPU
## (shaders/fauna_swarm.gdshader): butterflies over the jungle floor by day and
## fireflies by night, flocks of birds wheeling over the canopy. One MultiMesh
## per swarm or flock, drawn only near (60 m / 300 m), no script per critter.
## Local only: it never touches play, so guests just roll the same places.

const SHADER := preload("res://shaders/fauna_swarm.gdshader")

var _mats: Array[ShaderMaterial] = []
var _t: float = 0.0

static var _wings: ArrayMesh
static var _bird: ArrayMesh


static func build(f: FaunaSpawner, rng: RandomNumberGenerator) -> FaunaAmbient:
	var a := FaunaAmbient.new()
	a.name = "Ambient"
	f.add_child(a)
	var amb: Dictionary = f.pool["ambient"]
	var floor_pts: PackedVector2Array = f.zones["floor"]
	if not floor_pts.is_empty() and (bool(amb["butterflies"]) or bool(amb["fireflies"])):
		for i in range(mini(int(amb["swarms"]), floor_pts.size())):
			var p := floor_pts[rng.randi() % floor_pts.size()]
			a._add(0, f._ground(p), rng.randi_range(10, 16), 4.0, 1.4, rng, bool(amb["butterflies"]), bool(amb["fireflies"]))
	var crowns: Array = f.zones["canopy"]
	if not crowns.is_empty():
		for i in range(int(amb["flocks"])):
			var c: Vector3 = crowns[rng.randi() % crowns.size()]
			a._add(1, c + Vector3.UP * rng.randf_range(5.0, 9.0), rng.randi_range(6, 10), rng.randf_range(14.0, 26.0), 0.0, rng, true, true)
	return a


static func _wing_mesh(span: float, body: float) -> ArrayMesh:
	var v := PackedVector3Array([
		Vector3(0, 0, -body), Vector3(-span, 0, -body * 0.3), Vector3(-span * 0.8, 0, body), Vector3(0, 0, body * 0.6),
		Vector3(0, 0, -body), Vector3(span, 0, -body * 0.3), Vector3(span * 0.8, 0, body), Vector3(0, 0, body * 0.6)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _add(mode: int, at: Vector3, count: int, radius: float, height: float, rng: RandomNumberGenerator, day_on: bool, night_on: bool) -> void:
	if _wings == null:
		_wings = _wing_mesh(0.07, 0.05)
		_bird = _wing_mesh(0.32, 0.12)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _wings if mode == 0 else _bird
	mm.instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.05, 0.4) if mode == 0 else rng.randf_range(0.12, 0.2),
			rng.randf_range(0.4, 1.0) if mode == 0 else rng.randf_range(0.85, 1.0), rng.randf_range(0.8, 1.3)))
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", float(mode))
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("height", height)
	mat.set_shader_parameter("day_on", 1.0 if day_on else 0.0)
	mat.set_shader_parameter("night_on", 1.0 if night_on else 0.0)
	_mats.append(mat)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Swarm" if mode == 0 else "Flock"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-radius - 1.0, -2.0, -radius - 1.0), Vector3(radius * 2.0 + 2.0, height + 6.0, radius * 2.0 + 2.0))
	mmi.visibility_range_end = 60.0 if mode == 0 else 300.0
	add_child(mmi)
	mmi.position = at


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var n := float(Weather.night)
	for m in _mats:
		m.set_shader_parameter("night", n)
