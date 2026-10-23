class_name BeastFX
extends RefCounted
## The jungle beasts' own effects and sounds (local: a beast's net_event plays
## them on the other screens). Sounds are assets/audio/beast_<name>.wav or its
## takes beast_<name>_1.wav... (tools/texture_gen/gen_beast_audio.py).

const LEAF := Color(0.34, 0.5, 0.2)
const LEAF_DRY := Color(0.55, 0.48, 0.22)

static var _streams := {}
static var _leaf_mat: StandardMaterial3D
static var _leaf_quad: QuadMesh
static var _lane_mesh: ArrayMesh


static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene else tree.root


static func _cam_far(pos: Vector3, r: float) -> bool:
	var cam := (Engine.get_main_loop() as SceneTree).root.get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_squared_to(pos) > r * r


static func _stream(n: String) -> AudioStream:
	if not _streams.has(n):
		var takes: Array = []
		while ResourceLoader.exists("res://assets/audio/beast_%s_%d.wav" % [n, takes.size() + 1]):
			takes.append(load("res://assets/audio/beast_%s_%d.wav" % [n, takes.size() + 1]))
		if takes.is_empty():
			_streams[n] = load("res://assets/audio/beast_%s.wav" % n)
		else:
			var r := AudioStreamRandomizer.new()
			r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
			for s in takes:
				r.add_stream(-1, s)
			_streams[n] = r
	return _streams[n]


## A beast's sound at `pos` (heard out to `reach` m: the big ones carry).
static func sfx(n: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, reach: float = 80.0) -> void:
	if _cam_far(pos, reach + 4.0):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n)
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 9.0
	p.max_distance = reach
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	_root().add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Leaves shaken loose from the canopy at `pos`: big tumbling flakes that drift down
## over a few seconds, spread over `r` m.
static func leaves(pos: Vector3, amount: int = 16, r: float = 2.5, dry: bool = false) -> void:
	if _cam_far(pos, 120.0):
		return
	if _leaf_mat == null:
		_leaf_mat = StandardMaterial3D.new()
		_leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_leaf_mat.vertex_color_use_as_albedo = true
		_leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_leaf_mat.albedo_texture = FX._petal_texture()
		_leaf_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_leaf_quad = QuadMesh.new()
		_leaf_quad.size = Vector2(0.32, 0.32)
		_leaf_quad.material = _leaf_mat
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = maxi(amount, 1)
	p.lifetime = 4.5
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r
	p.direction = Vector3.DOWN
	p.spread = 70.0
	p.gravity = Vector3(0, -1.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.6
	p.damping_min = 1.2
	p.damping_max = 1.8
	p.angle_max = 360.0
	p.angular_velocity_min = -260.0
	p.angular_velocity_max = 260.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	var c := LEAF_DRY if dry else LEAF
	g.offsets = PackedFloat32Array([0.0, 0.85, 1.0])
	g.colors = PackedColorArray([c, c.darkened(0.15), Color(c.r, c.g, c.b, 0.0)])
	p.color_ramp = g
	p.color_initial_ramp = _leaf_shades()
	p.mesh = _leaf_quad
	_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static var _shades: Gradient


static func _leaf_shades() -> Gradient:
	if _shades == null:
		_shades = Gradient.new()
		_shades.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_shades.colors = PackedColorArray([Color(0.75, 0.85, 0.7), Color.WHITE, Color(1.25, 1.15, 0.8)])
	return _shades


## A strip on the ground where a charge or a lunge will run, from `from` to `to`
## (`w` m wide), filling in from the start over `secs`.
static func lane(from: Vector3, to: Vector3, w: float, secs: float, color: Color = Color(1.0, 0.18, 0.12)) -> void:
	if _lane_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, -1), Vector3(-0.5, 0, 0), Vector3(0.5, 0, -1), Vector3(-0.5, 0, -1)]:
			st.add_vertex(v)
		_lane_mesh = st.commit()
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var l := d.length()
	if l < 0.1:
		return
	var holder := Node3D.new()
	holder.name = "Lane"
	_root().add_child(holder)
	holder.global_transform = Transform3D(Basis.looking_at(d / l, Vector3.UP), from + Vector3(0, 0.04, 0))
	# the dither warning (FX.warn_mat): rails and the far end at once, chevrons behind a front sweeping along
	var mat := FX.warn_mat(color, 0, Vector2(w, l))
	var mi := MeshInstance3D.new()
	mi.mesh = _lane_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(w, 1.0, l)
	holder.add_child(mi)
	var tw := holder.create_tween()
	tw.tween_method(func(r: float): mat.set_shader_parameter("reveal", r), 0.0, l, maxf(secs, 0.05))
	tw.tween_callback(holder.queue_free)


## Undergrowth thrashing where something big pushes through it: leaf bits and dust kicked up.
static func brush(pos: Vector3, amount: int = 6) -> void:
	leaves(pos + Vector3(0, 0.6, 0), amount, 0.8, false)
	FX.dust(pos, 3, 0.7)
