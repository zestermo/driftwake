class_name CityPigeons
extends MultiMeshInstance3D
## A city's pigeons (1.21's city detail pass): flocks on its squares, every bird one instance of a little pigeon in
## one MultiMesh, moved on the GPU (shaders/world/city_pigeons.gdshader: pecking, hopping, lifting off flapping
## when a captain walks into the flock). The only CPU work is handing the shader the local captain's position a few
## times a second (the birds past 90 m aren't drawn). Flocks: points on the ground (the parent's space), PER_FLOCK birds round
## each in FLOCK_R; seeded, the same on every screen (what scares them is each screen's own captain: it's only looks).

const PER_FLOCK := 9
const FLOCK_R := 3.2
const SCARE_R := 3.5
const EVERY := 0.15

var _t := 0.0
var _mat: ShaderMaterial


func setup(flocks: Array, seed_value: int) -> CityPigeons:
	name = "Pigeons"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = bird_mesh()
	mm.instance_count = flocks.size() * PER_FLOCK
	var box := AABB()
	for f in range(flocks.size()):
		var c: Vector3 = flocks[f]
		for k in range(PER_FLOCK):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * FLOCK_R
			var at := c + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var i := f * PER_FLOCK + k
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.1)), at))
			mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
			box = AABB(at, Vector3.ZERO) if i == 0 else box.expand(at)
	multimesh = mm
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/world/city_pigeons.gdshader")
	_mat.set_shader_parameter("scare", Vector4(0, -1000, 0, SCARE_R))
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 90.0
	# (room over them for the lift-off)
	custom_aabb = box.grow(3.0).expand(box.end + Vector3(0, 6.0, 0))
	return self


## A pigeon, 0.3 m long, facing -z: a grey body, a darker head with a green-violet neck, a beak, folded wings
## (|x| > 0.075: the shader beats them), a dark-barred tail.
static func bird_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var m := PSXMat.flat(Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var grey := Color(0.6, 0.62, 0.68)
	mb.add_blob(m, Transform3D(Basis(), Vector3(0, 0.1, 0.0)), Vector3(0.07, 0.065, 0.12), rng, 0.0, 2, 6, 1.0, grey)
	mb.add_blob(m, Transform3D(Basis(), Vector3(0, 0.15, -0.085)), Vector3(0.045, 0.05, 0.05), rng, 0.0, 2, 5, 1.0, Color(0.36, 0.5, 0.46))
	mb.add_blob(m, Transform3D(Basis(), Vector3(0, 0.185, -0.12)), Vector3(0.035, 0.035, 0.04), rng, 0.0, 2, 5, 1.0, Color(0.42, 0.44, 0.52))
	mb.add_box(m, Transform3D(Basis(), Vector3(0, 0.18, -0.165)), Vector3(0.014, 0.012, 0.03), 1.0, Color(0.9, 0.82, 0.7), false)
	for s in [-1.0, 1.0]:
		mb.add_box(m, Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(s * 0.1, 0.12, 0.02)), Vector3(0.05, 0.012, 0.15), 1.0, Color(0.52, 0.54, 0.6) , false)
		mb.add_box(m, Transform3D(Basis(), Vector3(s * 0.02, 0.02, -0.01)), Vector3(0.012, 0.05, 0.012), 1.0, Color(0.8, 0.36, 0.34))
	mb.add_box(m, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.09, 0.15)), Vector3(0.06, 0.012, 0.1), 1.0, Color(0.3, 0.3, 0.34), false)
	return mb.commit()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = EVERY
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		var q := p.global_position
		_mat.set_shader_parameter("scare", Vector4(q.x, q.y, q.z, SCARE_R))
