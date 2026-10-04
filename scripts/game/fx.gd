extends Node
## One-shot visual + audio effects (autoload "FX"): dust puffs and rings,
## sparkles, hit impacts, sword slash trails and positional sounds.
## Everything is spawned on demand and frees itself.

const SLASH_SHADER := preload("res://shaders/psx/slash_trail.gdshader")
const SOUNDS := {
	"whoosh": "res://assets/audio/whoosh.wav",
	"whoosh_big": "res://assets/audio/whoosh_big.wav",
	"hit": "res://assets/audio/hit.wav",
	"step": "res://assets/audio/step.wav",
	"jump": "res://assets/audio/jump.wav",
	"land": "res://assets/audio/land.wav",
	"chitter": "res://assets/audio/chitter.wav",
	"bug_hiss": "res://assets/audio/bug_hiss.wav",
	"thud": "res://assets/audio/thud.wav",
	"coin": "res://assets/audio/coin.wav",
	"splash": "res://assets/audio/splash.wav",
	"blip_high": "res://assets/audio/blip_high.wav",
}

var _dust_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _impact_mat: StandardMaterial3D
var _slash_mat: ShaderMaterial
var _streams: Dictionary = {}
var _slash_meshes: Dictionary = {}


func _ready() -> void:
	_dust_mat = _billboard_mat("res://assets/textures/fx/dust.png", false)
	_spark_mat = _billboard_mat("res://assets/textures/fx/sparkle.png", true)
	_impact_mat = _billboard_mat("res://assets/textures/fx/impact.png", true)
	_slash_mat = ShaderMaterial.new()
	_slash_mat.shader = SLASH_SHADER
	for k in SOUNDS.keys():
		_streams[k] = load(SOUNDS[k])


func _billboard_mat(tex_path: String, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(tex_path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	return m


func _scene_root() -> Node:
	var cs := get_tree().current_scene
	return cs if cs else get_tree().root


func _burst(pos: Vector3, amount: int, mat: Material, size: float, life: float, cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = cfg.get("explosiveness", 0.95)
	p.amount = maxi(amount, 1)
	p.lifetime = life
	# Local space: bursts never move once spawned, and world-space CPU particles
	# drop out entirely on long frames (hitches), which local space avoids.
	p.local_coords = true
	p.emission_shape = cfg.get("shape", CPUParticles3D.EMISSION_SHAPE_SPHERE)
	p.emission_sphere_radius = cfg.get("radius", 0.2)
	if cfg.has("ring_radius"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_height = 0.05
		p.emission_ring_radius = cfg["ring_radius"]
		p.emission_ring_inner_radius = cfg["ring_radius"] * 0.8
	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = cfg.get("spread", 60.0)
	p.gravity = cfg.get("gravity", Vector3(0, -2.0, 0))
	p.initial_velocity_min = cfg.get("vel_min", 0.6)
	p.initial_velocity_max = cfg.get("vel_max", 1.6)
	p.damping_min = cfg.get("damping", 2.0)
	p.damping_max = cfg.get("damping", 2.0)
	p.radial_accel_min = cfg.get("radial", 0.0)
	p.radial_accel_max = cfg.get("radial", 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	var grow: bool = cfg.get("grow", true)
	curve.add_point(Vector2(0, 0.6 if grow else 1.0))
	curve.add_point(Vector2(1, 1.3 if grow else 0.0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	var col: Color = cfg.get("color", Color(0.85, 0.8, 0.68, 0.85))
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	p.mesh = quad
	_scene_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Little dust puff (footsteps, jumps, rolls).
func dust(pos: Vector3, amount: int = 5, size: float = 0.5) -> void:
	_burst(pos, amount, _dust_mat, size, 0.55, {
		"radius": 0.15, "spread": 70.0, "vel_min": 0.5, "vel_max": 1.4, "gravity": Vector3(0, 0.4, 0), "damping": 3.0})


## Expanding ring of dust (landings, heavy slam).
func dust_ring(pos: Vector3, amount: int = 12, size: float = 0.7) -> void:
	_burst(pos + Vector3(0, 0.08, 0), amount, _dust_mat, size, 0.6, {
		"ring_radius": 0.35, "spread": 15.0, "direction": Vector3(0, 0.2, 0), "vel_min": 0.4, "vel_max": 0.8,
		"radial": 6.0, "gravity": Vector3(0, 0.3, 0), "damping": 5.0})


## Twinkly stars (double jump, parry, pickups).
func sparkle(pos: Vector3, amount: int = 8, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	_burst(pos, amount, _spark_mat, 0.22, 0.6, {
		"radius": 0.25, "spread": 180.0, "vel_min": 1.0, "vel_max": 2.8, "gravity": Vector3(0, -3.0, 0),
		"damping": 2.0, "grow": false, "color": Color(color.r, color.g, color.b, 1.0)})


## Sea spray: white droplets thrown up and falling back (bow wave, wake).
func splash(pos: Vector3, amount: int = 4, size: float = 0.6) -> void:
	_burst(pos, amount, _dust_mat, size, 0.7, {
		"radius": 0.3, "spread": 35.0, "vel_min": 1.2, "vel_max": 2.6, "gravity": Vector3(0, -7.0, 0), "damping": 0.5,
		"color": Color(0.92, 0.97, 1.0, 0.85)})


## Hit impact: a flash plus a spray of sparks.
func impact(pos: Vector3, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	_burst(pos, 1, _impact_mat, 0.9, 0.12, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"grow": true, "color": Color(1, 1, 1, 1)})
	_burst(pos, 10, _spark_mat, 0.18, 0.4, {"radius": 0.1, "spread": 180.0, "vel_min": 3.0, "vel_max": 6.0,
		"gravity": Vector3(0, -9.0, 0), "damping": 4.0, "grow": false, "color": color})


# --------------------------------------------------------------------------
# Slash trails
# --------------------------------------------------------------------------
## kind: "right" (right-to-left), "left" (backhand), "spin" (full circle),
## "overhead" (vertical chop). The trail is parented to `follow` (the player
## model) so it sweeps with the character.
func slash(follow: Node3D, kind: String, duration: float = 0.25, color: Color = Color(0.45, 0.75, 1.0)) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _slash_mesh(kind)
	mi.material_override = _slash_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	follow.add_child(mi)
	mi.position = Vector3(0, 1.05, 0)
	mi.set_instance_shader_parameter("progress", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	var tail := 0.85 if kind == "spin" else 0.55
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("progress", v), 0.0, 1.0 + tail, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, duration).set_delay(duration * 0.45)
	tw.tween_callback(mi.queue_free)


func _slash_mesh(kind: String) -> ArrayMesh:
	if _slash_meshes.has(kind):
		return _slash_meshes[kind]
	# arc in the plane spanned by u (angle 0) and v (angle +90 deg)
	var u := Vector3.RIGHT
	var v := Vector3.FORWARD
	var a0 := -0.5
	var a1 := PI + 0.5
	var r0 := 0.45
	var r1 := 1.75
	var tilt := Basis()
	match kind:
		"right":
			tilt = Basis(Vector3.FORWARD, 0.28)
		"left":
			a0 = PI + 0.5
			a1 = -0.5
			tilt = Basis(Vector3.FORWARD, -0.28)
		"spin":
			# the spin finisher turns clockwise seen from above, starting on the right
			a0 = 0.2
			a1 = 0.2 - TAU
			r1 = 2.0
		"overhead":
			u = Vector3.FORWARD
			v = Vector3.UP
			a0 = deg_to_rad(150.0)
			a1 = deg_to_rad(-55.0)
			r0 = 0.5
			r1 = 1.9
	if kind == "thrust":
		return _thrust_mesh()
	var segs := 28
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var t := float(i) / segs
		var a := lerpf(a0, a1, t)
		var d := (u * cos(a) + v * sin(a))
		verts.append(tilt * (d * r0))
		verts.append(tilt * (d * r1))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i < segs:
			var b := i * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slash_meshes[kind] = mesh
	return mesh


## Straight streak forward for thrusts: narrow at the tip, sweeping out along
## its length with the same progress/fade shader as the arcs.
func _thrust_mesh() -> ArrayMesh:
	var segs := 12
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var t := float(i) / segs
		var z := -lerpf(0.35, 2.4, t)
		var w := lerpf(0.16, 0.03, t)
		var p := Vector3(0.18, 0.12, z)
		verts.append(p + Vector3(-w, -w * 0.4, 0))
		verts.append(p + Vector3(w, w * 0.4, 0))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i < segs:
			var b := i * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slash_meshes["thrust"] = mesh
	return mesh


# --------------------------------------------------------------------------
# Sounds
# --------------------------------------------------------------------------
## Positional one-shot on the SFX bus. pitch_jitter randomizes pitch +-.
func sfx(sound_name: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound_name]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	_scene_root().add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
