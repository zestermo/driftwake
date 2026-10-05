extends Node
## Time of day and weather (autoload "Weather").
##
## * A day lasts 24 minutes (DAY_LEN): dawn ~6:00, dusk ~18:00, a starry
##   night with a moon in between. The sun (the world's DirectionalLight3D)
##   swings across the sky; at night the same light becomes moonlight.
## * The weather changes every few minutes (SLOT), blending over a minute:
##   clear, cloudy, rain, storm. Rain falls around the camera (not under
##   roofs); storms add rough seas (Ocean.amp_mult), wind, fog, thunder and
##   lightning. Shafts of sunlight (godrays) come down through the clouds
##   when the sun is low.
## * 3D clouds (PuffClouds, the world's "Clouds" node) follow the weather;
##   fly into one and the view whites out.
## * Everything follows world_time() - the session clock plus a saved offset
##   - so in co-op every machine sees the same sky, rain and lightning
##   without any messages beyond the offset in the world sync.
## Debug (and the co-op host): F6 cycles the weather (auto, clear, cloudy,
## rain, storm), F7 skips two hours ahead.

signal weather_changed(state: int)

enum W { CLEAR, CLOUDY, RAIN, STORM }
const NAMES := ["Clear", "Cloudy", "Rain", "Storm"]
const DAY_LEN := 1440.0
const START_HOUR := 9.0
const SLOT := 300.0
const BLEND := 60.0
## coverage, rain, storm, wind, waves, fog
const PARAMS := [
	[0.22, 0.0, 0.0, 0.3, 1.0, 0.0],
	[0.62, 0.0, 0.15, 0.5, 1.1, 0.15],
	[0.85, 0.7, 0.45, 0.7, 1.3, 0.55],
	[1.0, 1.0, 1.0, 1.0, 1.8, 1.0],
]

## Added to the session clock (saved; shared in co-op).
var world_offset: float = 0.0
## Forced weather (F6 / host): -1 = the natural cycle.
var forced: int = -1
var forced_at: float = 0.0
## Current blended values (read them, don't set them).
var coverage: float = 0.22
var rain: float = 0.0
var storm: float = 0.0
var wind: float = 0.3
var waves: float = 1.0
var fog: float = 0.0
var night: float = 0.0
var state: int = W.CLEAR
var sun_dir := Vector3(0, 1, 0)
var in_cloud: float = 0.0
var flash: float = 0.0

var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _clouds: Node
var _shadow_mat: ShaderMaterial
var _scene: Node
var _rain: GPUParticles3D
var _rays: MultiMeshInstance3D
var _ray_mat: ShaderMaterial
var _rain_snd: AudioStreamPlayer
var _wind_snd: AudioStreamPlayer
var _overlay: ColorRect
var _layer: CanvasLayer
var _bolt: MeshInstance3D
var _bolt_t: float = 0.0
var _last_strike: int = -1
var _shelter: float = 0.0
var _shelter_t: float = 0.0
var _base_deep := Color(0.05, 0.16, 0.3, 0.95)
var _base_shallow := Color(0.2, 0.5, 0.6, 0.8)
var _ocean_mat: ShaderMaterial
var _prev_state: int = -1
var _thunder_q: Array = []   # [time, far]
var _sky_t: float = 0.0


# --------------------------------------------------------------------------
# Time
# --------------------------------------------------------------------------
func _session() -> float:
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		return net.time()
	return Time.get_ticks_usec() * 0.000001


func world_time() -> float:
	return _session() + world_offset


## Continue from a saved world time.
func set_world_time(t: float) -> void:
	world_offset = t - _session()


## 0..24
func hour() -> float:
	return fposmod(START_HOUR + world_time() / DAY_LEN * 24.0, 24.0)


func day() -> int:
	return int(floor((START_HOUR / 24.0 * DAY_LEN + world_time()) / DAY_LEN)) + 1


func clock_text() -> String:
	var h := hour()
	return "Day %d, %02d:%02d" % [day(), int(h), int(fmod(h, 1.0) * 60.0)]


func _slot_state(slot: int) -> int:
	# a new game starts with ten minutes of fair weather
	if slot < 2:
		return W.CLEAR
	var r := absf(fmod(sin(float(slot) * 12.9898 + 78.233) * 43758.5453, 1.0))
	var s := W.CLEAR
	if r < 0.36:
		s = W.CLEAR
	elif r < 0.66:
		s = W.CLOUDY
	elif r < 0.86:
		s = W.RAIN
	else:
		s = W.STORM
	# no back-to-back storms; the first slot of a session is never a storm
	if s == W.STORM and (slot <= 0 or _slot_raw(slot - 1) == W.STORM):
		s = W.RAIN
	return s


func _slot_raw(slot: int) -> int:
	var r := absf(fmod(sin(float(slot) * 12.9898 + 78.233) * 43758.5453, 1.0))
	return W.CLEAR if r < 0.36 else (W.CLOUDY if r < 0.66 else (W.RAIN if r < 0.86 else W.STORM))


func _params_at(t: float) -> Array:
	if forced >= 0:
		var k := clampf((t - forced_at) / 8.0, 0.0, 1.0)
		var from: Array = _natural(forced_at)
		var to: Array = PARAMS[forced]
		var out: Array = []
		for i in range(6):
			out.append(lerpf(float(from[i]), float(to[i]), k))
		return out
	return _natural(t)


func _natural(t: float) -> Array:
	var slot := int(floor(t / SLOT))
	var into := t - slot * SLOT
	var a: Array = PARAMS[_slot_state(slot)]
	if into < SLOT - BLEND:
		return a
	var b: Array = PARAMS[_slot_state(slot + 1)]
	var k := smoothstep(SLOT - BLEND, SLOT, into)
	var out: Array = []
	for i in range(6):
		out.append(lerpf(float(a[i]), float(b[i]), k))
	return out


func current_state() -> int:
	if forced >= 0:
		return forced
	return _slot_state(int(floor(world_time() / SLOT)))


## Debug / host: force a weather (-1 = back to the natural cycle).
func force(s: int) -> void:
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		net.everyone("_all_weather", [s, world_time(), world_offset])
	else:
		_apply_force(s, world_time())


func _apply_force(s: int, at: float) -> void:
	forced = s
	forced_at = at
	get_tree().call_group("hud", "show_toast", "Weather: %s" % ("natural cycle" if s < 0 else NAMES[s]))


# --------------------------------------------------------------------------
# Scene hookup
# --------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _attach(scene: Node) -> void:
	_scene = scene
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_env = we.environment if we else null
	_sun = scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_clouds = scene.get_node_or_null("Clouds")
	var cs := scene.get_node_or_null("CloudShadows") as MeshInstance3D
	_shadow_mat = cs.mesh.surface_get_material(0) as ShaderMaterial if cs and cs.mesh else null
	if _env:
		_sky_mat = ShaderMaterial.new()
		_sky_mat.shader = load("res://shaders/psx/psx_sky.gdshader")
		var sky := Sky.new()
		sky.sky_material = _sky_mat
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		_env.sky = sky
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_sky_contribution = 0.0
	var om := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	_ocean_mat = null
	if om:
		_ocean_mat = (om.material_override if om.material_override else om.mesh.surface_get_material(0)) as ShaderMaterial
		if _ocean_mat:
			_base_deep = _ocean_mat.get_shader_parameter("deep_color")
			_base_shallow = _ocean_mat.get_shader_parameter("shallow_color")
	_build_rain()
	_build_rays()
	_build_overlay()
	_build_audio()
	_last_strike = -1


func _detach() -> void:
	_scene = null
	_env = null
	_sun = null
	_clouds = null
	_rain = null
	_rays = null
	_bolt = null
	var oc := get_node_or_null("/root/Ocean")
	if oc:
		oc.set("amp_mult", 1.0)
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	if _rain_snd and is_instance_valid(_rain_snd):
		_rain_snd.stop()
	if _wind_snd and is_instance_valid(_wind_snd):
		_wind_snd.stop()


func _is_world(n: Node) -> bool:
	return n != null and n.name == "World" and n.get_node_or_null("WorldEnvironment") != null


# --------------------------------------------------------------------------
# Every frame
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _scene:
		if _scene != null:
			_detach()
		if _is_world(cs):
			_attach(cs)
	if _scene == null or not is_instance_valid(_scene):
		return
	_sky_t += delta
	var t := world_time()
	var p := _params_at(t)
	coverage = p[0]
	rain = p[1]
	storm = p[2]
	wind = p[3]
	waves = p[4]
	fog = p[5]
	state = current_state()
	if state != _prev_state:
		_prev_state = state
		weather_changed.emit(state)
	var oc := get_node_or_null("/root/Ocean")
	if oc:
		oc.set("amp_mult", waves)
	_update_sun(hour())
	_update_lightning(t, delta)
	_update_clouds()
	_update_env()
	_update_rain(delta)
	_update_rays()
	_update_audio(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _scene == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var net := get_node_or_null("/root/Net")
	var allowed: bool = OS.is_debug_build() and (net == null or not net.active or net.hosting)
	if not allowed:
		return
	if event.keycode == KEY_F6:
		var nxt := forced + 1
		if nxt > W.STORM:
			nxt = -1
		force(nxt)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F7:
		if net and net.active:
			net.everyone("_all_weather", [forced, forced_at, world_offset + DAY_LEN / 12.0])
		else:
			world_offset += DAY_LEN / 12.0
		get_tree().call_group("hud", "show_toast", clock_text())
		get_viewport().set_input_as_handled()


## Co-op: the host's weather override and clock offset.
func net_apply(s: int, at: float, offset: float) -> void:
	world_offset = offset
	if s != forced or absf(at - forced_at) > 0.01:
		_apply_force(s, at)


# --------------------------------------------------------------------------
# Sun, moon, colours
# --------------------------------------------------------------------------
## Keyframes by hour: top, horizon, sun colour, sun energy, ambient colour, ambient energy
const KEYS := [
	[0.0, Color(0.01, 0.02, 0.06), Color(0.05, 0.08, 0.17), Color(0.5, 0.6, 0.9), 0.22, Color(0.22, 0.26, 0.42), 0.5],
	[4.8, Color(0.03, 0.04, 0.11), Color(0.12, 0.12, 0.24), Color(0.5, 0.6, 0.9), 0.18, Color(0.24, 0.26, 0.42), 0.5],
	[6.0, Color(0.16, 0.24, 0.5), Color(0.9, 0.58, 0.42), Color(1.0, 0.55, 0.32), 0.55, Color(0.5, 0.42, 0.5), 0.6],
	[7.5, Color(0.18, 0.38, 0.75), Color(0.75, 0.72, 0.78), Color(1.0, 0.82, 0.62), 1.1, Color(0.5, 0.55, 0.66), 0.7],
	[9.0, Color(0.15, 0.4, 0.82), Color(0.5, 0.72, 0.92), Color(1.0, 0.92, 0.78), 1.35, Color(0.5, 0.58, 0.7), 0.75],
	[15.5, Color(0.14, 0.39, 0.82), Color(0.52, 0.72, 0.9), Color(1.0, 0.9, 0.74), 1.3, Color(0.52, 0.58, 0.68), 0.75],
	[17.2, Color(0.2, 0.32, 0.66), Color(0.9, 0.62, 0.45), Color(1.0, 0.68, 0.42), 1.0, Color(0.58, 0.5, 0.52), 0.68],
	[18.3, Color(0.14, 0.17, 0.42), Color(0.95, 0.5, 0.32), Color(1.0, 0.45, 0.25), 0.5, Color(0.5, 0.38, 0.45), 0.6],
	[19.6, Color(0.04, 0.05, 0.14), Color(0.2, 0.12, 0.22), Color(0.5, 0.6, 0.9), 0.15, Color(0.26, 0.26, 0.42), 0.52],
	[24.0, Color(0.01, 0.02, 0.06), Color(0.05, 0.08, 0.17), Color(0.5, 0.6, 0.9), 0.22, Color(0.22, 0.26, 0.42), 0.5],
]

var _top := Color()
var _hor := Color()
var _sun_col := Color()
var _sun_e: float = 1.0
var _amb := Color()
var _amb_e: float = 0.75


func _update_sun(h: float) -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in range(KEYS.size() - 1):
		if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var k := smoothstep(float(a[0]), float(b[0]), h)
	_top = (a[1] as Color).lerp(b[1], k)
	_hor = (a[2] as Color).lerp(b[2], k)
	_sun_col = (a[3] as Color).lerp(b[3], k)
	_sun_e = lerpf(float(a[4]), float(b[4]), k)
	_amb = (a[5] as Color).lerp(b[5], k)
	_amb_e = lerpf(float(a[6]), float(b[6]), k)
	# the sun's arc: up at 6, highest at noon (south-ish), down at 18
	var th := (h - 6.0) / 12.0 * PI
	var tilt := deg_to_rad(28.0)
	sun_dir = Vector3(cos(th), sin(th) * cos(tilt), -sin(th) * sin(tilt)).normalized()
	night = clampf(1.0 - (sun_dir.y + 0.12) / 0.2, 0.0, 1.0)
	if _sun:
		var light_dir := sun_dir if sun_dir.y > -0.04 else -sun_dir
		light_dir.y = maxf(light_dir.y, 0.12)
		_sun.global_basis = Basis.looking_at(-light_dir.normalized(), Vector3.UP if absf(light_dir.y) < 0.98 else Vector3.FORWARD)
		var e := _sun_e * (1.0 - storm * 0.72) * (1.0 - in_cloud * 0.6)
		_sun.light_energy = e + flash * 2.5
		_sun.light_color = _sun_col.lerp(Color(0.75, 0.8, 0.9), storm * 0.6)
		_sun.shadow_enabled = e > 0.12


func _update_env() -> void:
	var grey := Color(0.36, 0.38, 0.42)
	var top := _top.lerp(grey * (1.0 - night * 0.75), storm * 0.7)
	var hor := _hor.lerp(grey * 1.2 * (1.0 - night * 0.75), storm * 0.7)
	if _sky_mat:
		_sky_mat.set_shader_parameter("top_color", top)
		_sky_mat.set_shader_parameter("horizon_color", hor)
		_sky_mat.set_shader_parameter("ground_color", hor.darkened(0.55))
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("moon_dir", Vector3(-sun_dir.x, -sun_dir.y, sun_dir.z * 0.6 + 0.3).normalized())
		_sky_mat.set_shader_parameter("sun_color", _sun_col)
		_sky_mat.set_shader_parameter("night", night)
		_sky_mat.set_shader_parameter("coverage", coverage)
		_sky_mat.set_shader_parameter("storm", storm)
		_sky_mat.set_shader_parameter("flash", flash)
		_sky_mat.set_shader_parameter("cloud_time", _sky_t)
		var lit := Color(0.92, 0.93, 0.95).lerp(_sun_col, 0.3).lerp(Color(0.2, 0.22, 0.3), night * 0.85) * clampf(_sun_e / 1.2, 0.55, 1.0)
		_sky_mat.set_shader_parameter("cloud_lit", lit.lerp(Color(0.5, 0.52, 0.56), storm * 0.7))
		_sky_mat.set_shader_parameter("cloud_shade", (_amb * 1.1).lerp(Color(0.25, 0.26, 0.3), storm * 0.8))
	if _env:
		var amb := _amb.lerp(Color(0.42, 0.44, 0.5), storm * 0.5)
		_env.ambient_light_color = amb
		_env.ambient_light_energy = _amb_e * (1.0 - storm * 0.3) + flash * 1.5
		var fogc := hor.lerp(Color(0.85, 0.88, 0.92), in_cloud)
		_env.fog_light_color = fogc
		var begin := lerpf(90.0, 28.0, fog)
		var end := lerpf(750.0, 240.0, fog)
		begin = lerpf(begin, 0.0, in_cloud)
		end = lerpf(end, 28.0, in_cloud)
		_env.fog_depth_begin = begin
		_env.fog_depth_end = end
	if _shadow_mat:
		_shadow_mat.set_shader_parameter("cloud_coverage", clampf(coverage * 0.75, 0.0, 0.85))
		_shadow_mat.set_shader_parameter("shadow_strength", 0.45 * (1.0 - night) * (1.0 - storm * 0.5))
	if _ocean_mat:
		var dk := 1.0 - storm * 0.35
		var dc := Color(_base_deep.r * dk, _base_deep.g * dk, _base_deep.b * dk * 1.02, _base_deep.a)
		var sc := _base_shallow.lerp(Color(0.25, 0.32, 0.36, _base_shallow.a), storm * 0.5)
		_ocean_mat.set_shader_parameter("deep_color", dc)
		_ocean_mat.set_shader_parameter("shallow_color", sc)
	if _overlay:
		_overlay.color = Color(0.9, 0.92, 0.95, in_cloud * 0.55)
		_overlay.visible = in_cloud > 0.01


func _update_clouds() -> void:
	var cam := get_viewport().get_camera_3d()
	if _clouds == null or not is_instance_valid(_clouds):
		in_cloud = 0.0
		return
	_clouds.set("coverage", coverage)
	_clouds.set("storm", storm)
	_clouds.set("wind_speed", 3.0 + wind * 9.0)
	var lit := Color(1, 1, 1).lerp(_sun_col, 0.3).lerp(Color(0.24, 0.26, 0.36), night * 0.85)
	_clouds.set("lit_color", lit.lerp(Color(0.48, 0.5, 0.55), storm * 0.75))
	_clouds.set("shade_color", (_amb * 1.05).lerp(Color(0.22, 0.23, 0.27), storm * 0.8).lerp(Color(0.08, 0.09, 0.14), night * 0.6))
	var target := 0.0
	if cam and _clouds.has_method("density_at"):
		target = float(_clouds.density_at(cam.global_position))
	in_cloud = move_toward(in_cloud, target, get_process_delta_time() * 2.0)


# --------------------------------------------------------------------------
# Rain
# --------------------------------------------------------------------------
func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 2200
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	_rain.emitting = false
	_rain.amount_ratio = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1, 24)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3(0, -6, 0)
	pm.particle_flag_align_y = true
	_rain.process_material = pm
	# a thin cross of two streaks (no billboarding needed)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rot in [0.0, PI * 0.5]:
		var b := Basis(Vector3.UP, rot)
		var w := 0.025
		var hgt := 0.85
		var v := [b * Vector3(-w, -hgt, 0), b * Vector3(w, -hgt, 0), b * Vector3(w, hgt, 0), b * Vector3(-w, hgt, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[idx])
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.82, 0.9, 0.38)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# (streaks right past the lens would be big white bars)
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 5.0
	mesh.surface_set_material(0, mat)
	_rain.draw_pass_1 = mesh
	_scene.add_child(_rain)


func _update_rain(delta: float) -> void:
	if _rain == null or not is_instance_valid(_rain):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# under a roof (or in the tavern): no rain right here
	_shelter_t -= delta
	if _shelter_t <= 0.0:
		_shelter_t = 0.3
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + Vector3.UP * 25.0, 1)
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		_shelter = 1.0 if not hit.is_empty() else 0.0
	var amt := rain * (1.0 - _shelter * 0.9) * (1.0 - in_cloud)
	var wv := Vector3(1.0, 0, 0.3).normalized() * wind * 4.0
	_rain.global_position = cam.global_position + Vector3(0, 14.0, 0) - wv * 0.4 + (-cam.global_basis.z) * 6.0
	(_rain.process_material as ParticleProcessMaterial).gravity = Vector3(wv.x, -6.0, wv.z)
	_rain.amount_ratio = clampf(amt, 0.0, 1.0)
	_rain.emitting = amt > 0.02


# --------------------------------------------------------------------------
# Godrays: shafts of sun through the clouds (low sun, broken cloud)
# --------------------------------------------------------------------------
const RAYS := 14

func _build_rays() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	mm.mesh = q
	mm.instance_count = RAYS
	_ray_mat = ShaderMaterial.new()
	_ray_mat.shader = load("res://shaders/world/godray.gdshader")
	_rays = MultiMeshInstance3D.new()
	_rays.name = "Godrays"
	_rays.multimesh = mm
	_rays.material_override = _ray_mat
	_rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rays.extra_cull_margin = 4096.0
	mm.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1500, 4000))
	_scene.add_child(_rays)


func _update_rays() -> void:
	if _rays == null or not is_instance_valid(_rays):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var elev := sun_dir.y
	# strongest with a lowish sun and broken cloud, none at night or in rain
	var k := smoothstep(0.02, 0.15, elev) * (1.0 - smoothstep(0.55, 0.85, elev))
	var cloudy := 1.0 - absf(coverage - 0.55) / 0.55
	k *= clampf(0.35 + cloudy, 0.0, 1.0) * (1.0 - rain) * (1.0 - storm) * (1.0 - in_cloud)
	_ray_mat.set_shader_parameter("intensity", k * 0.22)
	_ray_mat.set_shader_parameter("sun_dir", sun_dir)
	_ray_mat.set_shader_parameter("ray_color", _sun_col)
	_ray_mat.set_shader_parameter("time_s", _sky_t)
	_rays.visible = k > 0.01
	if not _rays.visible:
		return
	var mm := _rays.multimesh
	var axis := sun_dir.normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var other := axis.cross(side).normalized()
	var base := cam.global_position
	base.y = 0.0
	for i in range(RAYS):
		var h := float(i) * 1.618
		# spread around ahead of the camera, toward the sun
		var ox := (fmod(h * 37.0, 1.0) - 0.5) * 160.0
		var oz := (fmod(h * 91.0, 1.0) - 0.5) * 160.0
		var foot := base + side * ox + other * oz * 0.6 + Vector3(-axis.x, 0, -axis.z).normalized() * -40.0
		foot.y = -2.0
		var length := 170.0
		var width := 4.0 + fmod(h * 13.0, 1.0) * 10.0
		var b := Basis(side * width, axis * length, other)
		mm.set_instance_transform(i, Transform3D(b, foot))
		var flick := 0.6 + 0.4 * sin(_sky_t * (0.2 + fmod(h, 0.3)) + h * 7.0)
		mm.set_instance_color(i, Color(1, 1, 1, flick))


# --------------------------------------------------------------------------
# Lightning (deterministic from world time: same strikes on every screen)
# --------------------------------------------------------------------------
func _update_lightning(t: float, delta: float) -> void:
	flash = maxf(flash - delta * 5.0, 0.0)
	if _bolt and is_instance_valid(_bolt):
		_bolt_t -= delta
		_bolt.visible = _bolt_t > 0.0 and fmod(_bolt_t, 0.08) > 0.03
		if _bolt_t <= 0.0:
			_bolt.queue_free()
			_bolt = null
	for th in _thunder_q.duplicate():
		if Time.get_ticks_msec() * 0.001 >= float(th[0]):
			_thunder_q.erase(th)
			FX_sfx("thunder_far" if th[1] else "thunder", -4.0 if th[1] else 0.0)
	if storm < 0.55:
		return
	var tick := int(floor(t * 2.0))
	if tick == _last_strike:
		return
	_last_strike = tick
	var r := absf(fmod(sin(float(tick) * 78.233 + 12.9898) * 43758.5453, 1.0))
	if r > 0.045 * storm:
		return
	var a := absf(fmod(sin(float(tick) * 4.1414) * 9631.3, 1.0)) * TAU
	var dist := 120.0 + absf(fmod(sin(float(tick) * 7.31) * 5121.7, 1.0)) * 420.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_strike(cam.global_position + Vector3(cos(a), 0, sin(a)) * dist, dist, tick)


func _strike(at: Vector3, dist: float, seed_value: int) -> void:
	flash = clampf(1.0 - dist / 700.0, 0.25, 1.0)
	# a jagged bolt from the clouds to the sea
	var im := ImmediateMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var top := Vector3(at.x, 150.0, at.z)
	var pts: Array = [top]
	var p := top
	while p.y > 0.0:
		p += Vector3(rng.randf_range(-6, 6), -rng.randf_range(8, 16), rng.randf_range(-6, 6))
		pts.append(Vector3(p.x, maxf(p.y, 0.0), p.z))
	var cam := get_viewport().get_camera_3d()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var side := (b - a).cross(cam.global_position - a).normalized() * 0.9 if cam else Vector3.RIGHT
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			im.surface_add_vertex(v)
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	if _bolt and is_instance_valid(_bolt):
		_bolt.queue_free()
	_bolt = MeshInstance3D.new()
	_bolt.mesh = im
	_bolt.material_override = mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene.add_child(_bolt)
	_bolt_t = 0.28
	# thunder arrives later the farther away it struck
	_thunder_q.append([Time.get_ticks_msec() * 0.001 + dist / 340.0, dist > 300.0])


func FX_sfx(name_: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.wav" % name_)
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	p.volume_db = db
	p.pitch_scale = randf_range(0.9, 1.1)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# --------------------------------------------------------------------------
# Sound, the in-cloud whiteout
# --------------------------------------------------------------------------
func _build_audio() -> void:
	if _rain_snd == null:
		_rain_snd = _loop_player("res://assets/audio/rain_loop.wav")
		_wind_snd = _loop_player("res://assets/audio/wind_loop.wav")


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path) as AudioStreamWAV
	if s:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.data.size() / 2)
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	p.volume_db = -60.0
	add_child(p)
	return p


func _update_audio(delta: float) -> void:
	var rv := rain * (1.0 - _shelter * 0.5)
	_set_loop(_rain_snd, rv, -10.0, delta)
	_set_loop(_wind_snd, clampf((wind - 0.3) * 1.4 + storm * 0.4 + in_cloud * 0.5, 0.0, 1.0), -12.0, delta)


func _set_loop(p: AudioStreamPlayer, k: float, top_db: float, delta: float) -> void:
	if p == null:
		return
	var want := -60.0 if k < 0.02 else linear_to_db(k) + top_db
	p.volume_db = move_toward(p.volume_db, want, 30.0 * delta)
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -59.0 and p.playing:
		p.stop()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "WeatherOverlay"
	_layer.layer = 0
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1, 1, 1, 0)
	_overlay.visible = false
	_layer.add_child(_overlay)
