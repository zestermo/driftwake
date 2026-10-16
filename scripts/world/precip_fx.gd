class_name PrecipFX
extends Node3D
## Snow and blowing sand round the camera (each screen its own; Weather's snow, sand and murk are the
## same on every screen): flakes drifting down on the wind (a light fall always on a snow island, thick in
## its spells), and once a heavy fall or a sandstorm closes in, streaks racing past on the wind and big
## drifting curtains of the flipbook's snow or sand. Nothing emits or draws where neither falls.
## Made by Weather beside the rain.

const FLAKES := 1800
const STREAKS := 900
const CURTAINS := 36
const UPDATE_EVERY := 0.2
const SNOW_STREAK := Color(0.93, 0.95, 1.0, 0.45)
const SAND_STREAK := Color(0.86, 0.72, 0.5, 0.38)
const SNOW_CURTAIN := Color(0.96, 0.97, 1.0, 0.42)
const SAND_CURTAIN := Color(0.86, 0.7, 0.48, 0.5)

var _flakes: GPUParticles3D
var _streaks: GPUParticles3D
var _curtains: GPUParticles3D
var _curtain_mats := {}
var _kind := ""
var _t := 0.0
## The wind's push now (m/s, world), the flakes' and the streaks'.
var _flake_v := Vector3.ZERO
var _gust_v := Vector3.ZERO


func _ready() -> void:
	top_level = true
	_flakes = _emitter("Flakes", FLAKES, 7.0, Vector3(14, 6, 14), _flake_mesh())
	_streaks = _emitter("Streaks", STREAKS, 0.7, Vector3(16, 4, 16), _streak_mesh())
	(_streaks.process_material as ParticleProcessMaterial).particle_flag_align_y = true
	for sheet in ["snow", "sand"]:
		var m := (FX._flip_mat(sheet) as StandardMaterial3D).duplicate() as StandardMaterial3D
		# (a curtain passing the lens would fill the screen)
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 2.5
		m.distance_fade_max_distance = 9.0
		_curtain_mats[sheet] = m
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 5.0)
	_curtains = _emitter("Curtains", CURTAINS, 3.2, Vector3(24, 2.5, 24), quad)
	var cpm := _curtains.process_material as ParticleProcessMaterial
	cpm.anim_speed_min = 1.0
	cpm.anim_speed_max = 1.0
	cpm.anim_offset_max = 1.0
	cpm.angle_min = -30.0
	cpm.angle_max = 30.0
	cpm.scale_min = 0.7
	cpm.scale_max = 1.4


func _emitter(n: String, amount: int, life: float, box: Vector3, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.visible = false
	p.amount_ratio = 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-50, -30, -50), Vector3(100, 60, 100))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.gravity = Vector3.ZERO
	pm.spread = 12.0
	p.process_material = pm
	p.draw_pass_1 = mesh
	add_child(p)
	return p


## A flake: a 3x3 cross of pixels, lit by the scene (grey in the dark, warm by a lamp).
func _flake_mesh() -> QuadMesh:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for xy in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		img.set_pixelv(xy, Color.WHITE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.95, 0.96, 1.0)
	m.roughness = 1.0
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 1.2
	m.distance_fade_max_distance = 3.5
	var q := QuadMesh.new()
	q.size = Vector2(0.13, 0.13)
	q.material = m
	return q


## A streak: a thin cross of two long quads (laid along its flight by align_y).
func _streak_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot in [0.0, PI * 0.5]:
		var b := Basis(Vector3.UP, rot)
		var w := 0.012
		var hgt := 0.3
		var v := [b * Vector3(-w, -hgt, 0), b * Vector3(w, -hgt, 0), b * Vector3(w, hgt, 0), b * Vector3(-w, hgt, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v[idx])
	var mesh := st.commit()
	# (unshaded: lit, the sand read as dark sticks in the storm's dim light; dimmed with the night by hand)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 5.0
	mesh.surface_set_material(0, mat)
	return mesh


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var open := (1.0 - Weather._shelter * 0.9) * (1.0 - Weather.in_cloud)
	var r_flake := clampf(Weather.snow * 1.6, 0.0, 1.0) * open
	var r_heavy := Weather.murk * open
	_t -= delta
	if _t <= 0.0:
		_t = UPDATE_EVERY
		_retune()
	var c := cam.global_position
	var ahead := -cam.global_basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized() * 5.0
	# (each placed upwind of the view by about half the way its particles travel; snow streaks only in a blizzard)
	_run(_flakes, r_flake, c + ahead + Vector3(0, 5.0, 0) - Vector3(_flake_v.x, 0.0, _flake_v.z) * 3.5)
	_run(_streaks, r_heavy if _kind == "sand" else smoothstep(0.55, 1.0, r_heavy), c + ahead + Vector3(0, 2.0, 0) - _gust_v * 0.35)
	_run(_curtains, r_heavy, c + ahead + Vector3(0, 1.5, 0) - _gust_v * 1.6)


func _run(p: GPUParticles3D, ratio: float, at: Vector3) -> void:
	p.global_position = at
	p.amount_ratio = ratio
	p.emitting = ratio > 0.01
	p.visible = ratio > 0.005


## The wind's direction and strength, and what is blowing (snow or sand), into the emitters (new particles take it).
func _retune() -> void:
	var wd := Weather.wind_dir()
	var w := Weather.wind
	var murk := Weather.murk
	var sandy := Weather.sand > Weather.snow
	var kind := "sand" if sandy else "snow"
	# flakes: about 1.4 m/s down, carried sideways more the harder it blows; a blizzard drives them
	var side := (0.6 + w * 1.8) * (1.0 + murk * 3.0)
	_flake_v = Vector3(wd.x * side, -1.4 * (1.0 + murk * 1.6), wd.y * side)
	var fpm := _flakes.process_material as ParticleProcessMaterial
	fpm.direction = _flake_v.normalized()
	fpm.initial_velocity_min = _flake_v.length() * 0.75
	fpm.initial_velocity_max = _flake_v.length() * 1.15
	var gust := 12.0 + w * 10.0
	_gust_v = Vector3(wd.x * gust, -0.3 if not sandy else -0.05, wd.y * gust)
	for p in [_streaks, _curtains]:
		var pm := (p as GPUParticles3D).process_material as ParticleProcessMaterial
		pm.direction = _gust_v.normalized()
		pm.initial_velocity_min = gust * (0.7 if p == _curtains else 0.85)
		pm.initial_velocity_max = gust * (0.9 if p == _curtains else 1.25)
	# (curtains and streaks are unshaded: dimmed with the night like FX's lit sheets, and with a storm's dusk)
	var k := FX._night_k() * clampf((Weather.sky_light_level() + Weather.ambient_level() * 0.6) / 0.5, 0.2, 1.0)
	var cc := SAND_CURTAIN if sandy else SNOW_CURTAIN
	(_curtains.process_material as ParticleProcessMaterial).color = Color(cc.r * k, cc.g * k, cc.b * k, cc.a)
	var sc := SAND_STREAK if sandy else SNOW_STREAK
	var spm := _streaks.process_material as ParticleProcessMaterial
	spm.color = Color(sc.r * k, sc.g * k, sc.b * k, sc.a)
	if kind != _kind:
		_kind = kind
		# (blown snow in shorter dashes than the sand's long hiss)
		spm.scale_min = 0.8 if sandy else 0.4
		spm.scale_max = 1.3 if sandy else 0.7
		(_curtains.draw_pass_1 as QuadMesh).material = _curtain_mats[kind]
