class_name CitySmoke
extends RefCounted
## Smoke from a city's chimneys (1.21's city detail pass): every chimney top that smokes in one GPUParticles3D, the
## tops as its emission points, so a whole city's smoke is one node and no work on the CPU after it's made. Grey
## wisps rising and drifting downwind, growing as they fade (FX's dust puff on a billboard); a little over one puff in
## the air per chimney. The tops in the parent's space; ONE_IN chimneys smoke (seeded by the list, the same on every
## screen).

const ONE_IN := 2
const PER_TOP := 3
const LIFE := 6.0


static func make(tops: Array, seed_value: int) -> GPUParticles3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts: Array = tops.filter(func(_t): return rng.randi() % ONE_IN == 0)
	if pts.is_empty():
		return null
	var img := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
	var box := AABB(pts[0], Vector3.ZERO)
	for i in range(pts.size()):
		var v: Vector3 = pts[i]
		img.set_pixel(i, 0, Color(v.x, v.y, v.z))
		box = box.expand(v)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(img)
	pm.emission_point_count = pts.size()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.3, 0.32, 0.12)
	pm.damping_min = 0.1
	pm.damping_max = 0.2
	pm.scale_min = 1.0
	pm.scale_max = 1.5
	var sc := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	sc.curve = curve
	pm.scale_curve = sc
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(0.74, 0.72, 0.7, 0.0), Color(0.74, 0.72, 0.7, 0.42), Color(0.8, 0.8, 0.8, 0.0)])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	var p := GPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = pts.size() * PER_TOP
	p.lifetime = LIFE
	p.preprocess = LIFE
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.material = (Engine.get_main_loop() as SceneTree).root.get_node("FX")._dust_mat
	p.draw_pass_1 = q
	p.visibility_aabb = box.grow(1.0).expand(box.end + Vector3(12.0, 14.0, 12.0)).expand(box.position - Vector3(12.0, 0.0, 12.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 420.0
	return p
