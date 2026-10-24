extends Node
## Time of day and weather (autoload "Weather").
##
## * A day lasts 24 minutes (DAY_LEN; DayClock: 14 of daylight, 10 of night): dawn ~6:00, dusk ~18:00, a starry
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
const DAY_LEN := DayClock.LEN
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
## How near the camera is to a lit lantern on a fog isle (0 none .. 1 in its glow; FogPlaces.FogClear sets it), and how
## much of the fog that takes away.
var lantern_clear: float = 0.0
const LANTERN_CLEAR := 0.75
## How far you see in a misty place's fog (KitStyle "mist" at 1).
const MIST_END := 70.0
var night: float = 0.0
var state: int = W.CLEAR
## Snow falling (0..1: SNOW_LIGHT always on a snow island, heavy in its rain and storm slots) and blowing
## sand (a desert's sandstorm), by place like the rest; murk is how far either closes the view in.
var snow: float = 0.0
var sand: float = 0.0
var murk: float = 0.0
const SNOW_LIGHT := 0.22
var sun_dir := Vector3(0, 1, 0)
var in_cloud: float = 0.0
var flash: float = 0.0

var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _clouds: Node
## The fog as last set (the sky's horizon haze and the 3D clouds match it).
var fog_color := Color(0.5, 0.72, 0.92)
var fog_begin: float = 90.0
var fog_end: float = 750.0
var haze_height: float = 0.08
## Cloud shadows on the ground and sea drift with the wind (metres).
var _shadow_drift := Vector2.ZERO
## What the cloud_shadow shader global was last set to.
var cloud_shadow := Vector4(0.3, 0.0, 0.0, 0.0)
var _scene: Node
var _rain: GPUParticles3D
var _rays: MultiMeshInstance3D
var _ray_mat: ShaderMaterial
var _rain_snd: AudioStreamPlayer
var _sand_snd: AudioStreamPlayer
var _blizzard_snd: AudioStreamPlayer
var _precip: PrecipFX
## The surf, sea, ship and wind sounds (they follow the weather's wind too),
## and what you see of them (wind streaks, crest spray, surf bursts).
var _ambience: Ambience
var _spray: SeaSpray
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
var _thunder_q: Array = []   # [seconds until it's heard, far]
var _sky_t: float = 0.0
## The style round the camera ([name, weight], KitStyle.around), looked up twice a second.
var _zone: Array = ["brinehollow", 0.0]
var _zone_style: Dictionary = KitStyle.of("brinehollow")
var _zone_t: float = 0.0
const SLOW_EVERY := 0.1
var _slow_t: float = 0.0
var _flash_set: float = 0.0
var _cloud_set: float = 0.0
var _cloud_target: float = 0.0


# --------------------------------------------------------------------------
# Time
# --------------------------------------------------------------------------
func _session() -> float:
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		return net.time()
	# solo: game time, like Ocean's (on the wall clock a forced weather's 8 s blend ran out of step with the game)
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func world_time() -> float:
	return _session() + world_offset


## Continue from a saved world time.
func set_world_time(t: float) -> void:
	world_offset = t - _session()


## Where the wind blows toward (unit, x/z), swinging slowly round through the
## day (from world time: the same on every screen). Its strength is `wind`.
## How much of the sea is whitecapped (0 calm .. 1 a gale): the ocean's crest
## foam, and SeaSpray's spray off the crests and wind streaks.
func whitecaps() -> float:
	return clampf((wind - 0.3) * 1.3 + storm * 0.8, 0.0, 1.0)


func wind_dir() -> Vector2:
	var t := world_time()
	var a := 0.29 + 1.2 * sin(t / 950.0) + 0.45 * sin(t / 331.0 + 1.3)
	return Vector2(cos(a), sin(a))


## 0..24
func hour() -> float:
	return DayClock.hour_of(DayClock.secs_of(START_HOUR) + world_time())


func day() -> int:
	return int(floor((DayClock.secs_of(START_HOUR) + world_time()) / DAY_LEN)) + 1


## The world time at hour `h` of day `day_n`.
static func time_at(h: float, day_n: int = 1) -> float:
	return DayClock.secs_between(START_HOUR, h) + (day_n - 1) * DAY_LEN


## Moves the clock forward to the next hour `h`.
func skip_to(h: float) -> void:
	world_offset += DayClock.secs_between(hour(), h)


func clock_text() -> String:
	var h := hour()
	return "Day %d, %02d:%02d" % [day(), int(h), int(fmod(h, 1.0) * 60.0)]


## The weather's odds by place (KitStyle "weather"): where clear, cloudy and rain
## end on a slot's 0..1 roll, the rest storm. Home waters are Brinehollow's.
const HOME_ODDS: Array = KitStyle.BRINEHOLLOW["weather"]


func _slot_state(slot: int, odds: Array = HOME_ODDS) -> int:
	# a new game starts with ten minutes of fair weather
	if slot < 2:
		return W.CLEAR
	var s := _slot_raw(slot, odds)
	# no back-to-back storms; the first slot of a session is never a storm
	if s == W.STORM and (slot <= 0 or _slot_raw(slot - 1, odds) == W.STORM):
		s = W.RAIN
	return s


func _slot_raw(slot: int, odds: Array = HOME_ODDS) -> int:
	var r := absf(fmod(sin(float(slot) * 12.9898 + 78.233) * 43758.5453, 1.0))
	return W.CLEAR if r < odds[0] else (W.CLOUDY if r < odds[1] else (W.RAIN if r < odds[2] else W.STORM))


func _params_at(t: float, odds: Array = HOME_ODDS) -> Array:
	if forced >= 0:
		var k := clampf((t - forced_at) / 8.0, 0.0, 1.0)
		var from: Array = _natural(forced_at, odds)
		var to: Array = PARAMS[forced]
		var out: Array = []
		for i in range(6):
			out.append(lerpf(float(from[i]), float(to[i]), k))
		return out
	return _natural(t, odds)


func _natural(t: float, odds: Array = HOME_ODDS) -> Array:
	var slot := int(floor(t / SLOT))
	var into := t - slot * SLOT
	var a: Array = PARAMS[_slot_state(slot, odds)]
	if into < SLOT - BLEND:
		return a
	var b: Array = PARAMS[_slot_state(slot + 1, odds)]
	var k := smoothstep(SLOT - BLEND, SLOT, into)
	var out: Array = []
	for i in range(6):
		out.append(lerpf(float(a[i]), float(b[i]), k))
	return out


## The weather where the camera is: home's, blended into a themed island's
## odds and haze over its reach (KitStyle.around).
func _params_here(t: float) -> Array:
	return params_in(t, _zone_style, float(_zone[1]))


## The weather at world time `t` in style `st` held with weight `k` over home's: PARAMS' six, then snow and sand.
## A theme whose fall isn't rain turns its rain and storm slots' rain into its snow or its sandstorm.
func params_in(t: float, st: Dictionary, k: float) -> Array:
	# (a slot's params are PARAMS' own read-only row)
	var p: Array = _params_at(t).duplicate()
	p.append_array([0.0, 0.0])
	if k <= 0.0:
		return p
	var q: Array = _params_at(t, st["weather"]).duplicate()
	var fall := float(q[1])
	var kind: String = st["precip"]
	if kind != "rain":
		q[1] = 0.0
	for i in range(6):
		p[i] = lerpf(float(p[i]), float(q[i]), k)
	p[5] = minf(float(p[5]) + float(st["haze"]) * k, 1.0)
	if kind == "snow":
		p[6] = maxf(fall, SNOW_LIGHT) * k
	elif kind == "sand":
		p[7] = fall * k
	return p


func current_state() -> int:
	if forced >= 0:
		return forced
	var odds: Array = _zone_style["weather"] if float(_zone[1]) > 0.5 else HOME_ODDS
	return _slot_state(int(floor(world_time() / SLOT)), odds)


## How bright the ambient light is now (its colour's luminance x energy).
func ambient_level() -> float:
	return _env.ambient_light_color.get_luminance() * _env.ambient_light_energy


## The moon's (or the sun's) light on the ground now: its energy x its colour's luminance.
func sky_light_level() -> float:
	return _sun.light_energy * _sun.light_color.get_luminance()


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
	get_tree().call_group("hud", "show_toast", "Weather: %s" % ("natural cycle" if s < 0 else state_name(s)))


## A state's name where you are: a snow island's rain is heavy snow and its storm a blizzard, a desert's both sandstorms.
func state_name(s: int) -> String:
	if float(_zone[1]) > 0.5 and s >= W.RAIN:
		match str(_zone_style["precip"]):
			"snow":
				return "Heavy snow" if s == W.RAIN else "Blizzard"
			"sand":
				return "Blowing sand" if s == W.RAIN else "Sandstorm"
	return NAMES[s]


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
	_build_rain()
	_build_rays()
	_build_overlay()
	_build_audio()
	_last_strike = -1
	_slow_t = 0.0


func _detach() -> void:
	RenderingServer.global_shader_parameter_set("cloud_shadow", Vector4(0.3, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("sky_haze", Vector4(0.5, 0.72, 0.92, 0.0))
	_scene = null
	_env = null
	_sun = null
	_clouds = null
	_rain = null
	_precip = null
	_rays = null
	_bolt = null
	var oc := get_node_or_null("/root/Ocean")
	if oc:
		oc.set("amp_mult", 1.0)
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	for snd in [_rain_snd, _sand_snd, _blizzard_snd]:
		if snd and is_instance_valid(snd):
			snd.stop()
	if _ambience and is_instance_valid(_ambience):
		_ambience.queue_free()
	_ambience = null
	if _spray and is_instance_valid(_spray):
		_spray.queue_free()
	_spray = null


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
	var cam := get_viewport().get_camera_3d()
	_zone_t -= delta
	if cam and _zone_t <= 0.0:
		_zone_t = 0.5
		_zone = KitStyle.around(get_tree(), cam.global_position)
		_zone_style = KitStyle.of(_zone[0])
	_update_lightning(t, delta)
	in_cloud = move_toward(in_cloud, _cloud_target, delta * 2.0)
	_check_under(cam)
	_slow_t -= delta
	if _slow_t <= 0.0 or flash != _flash_set or in_cloud != _cloud_set or under_water != _under_set or absf(_under_depth - _depth_set) > 0.5:
		_slow_t = SLOW_EVERY
		_flash_set = flash
		_cloud_set = in_cloud
		_under_set = under_water
		_depth_set = _under_depth
		_update_slow(t)
	_drift_sky(delta)
	_update_rain(delta)
	_update_rays()
	_update_audio(delta)


## Under the sea (the camera below the waves, on a dive): the fog closes in blue-green, darker and nearer with
## depth, a tint over the screen, and the sea's underside drawn.
const UNDER_SHALLOW := Color(0.13, 0.45, 0.47)
const UNDER_DEEP := Color(0.02, 0.12, 0.2)
## Depth (m) where it's darkest, and how far you see (m) just under the surface / at that depth.
const UNDER_DARK := 22.0
const UNDER_SEE := Vector2(34.0, 13.0)
const UNDER_TINT := 0.22
var under_water := false
var _under_depth := 0.0
var _under_set := false
var _depth_set := 0.0


func _check_under(cam: Camera3D) -> void:
	under_water = false
	_under_depth = 0.0
	# (well over the highest crest there's nothing to ask; an inland pool's swimmers are under 2.5 m of it)
	if cam == null or (cam.global_position.y > 2.5 * Ocean.amp_mult and Ocean.pools.is_empty()):
		return
	var surf := float(Ocean.surface_at(cam.global_position))
	if cam.global_position.y < surf - 0.05:
		under_water = true
		_under_depth = surf - cam.global_position.y


## The weather's blend, sun, sky, fog and 3D clouds: SLOW_EVERY s apart, every frame while a flash or the whiteout changes.
func _update_slow(t: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var p := _params_here(t)
	coverage = p[0]
	rain = p[1]
	storm = p[2]
	wind = p[3]
	waves = p[4]
	fog = p[5]
	snow = p[6]
	sand = p[7]
	murk = maxf(smoothstep(0.35, 1.0, snow), smoothstep(0.2, 0.9, sand))
	# out at sea: inside a storm cell or a fog bank (SeaFeatures)
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf and cam:
		var lw: Vector2 = sf.local_weather(cam.global_position)
		storm = maxf(storm, lw.x)
		rain = maxf(rain, lw.x)
		coverage = maxf(coverage, lw.x * 0.9)
		wind = maxf(wind, lw.x * 0.85)
		fog = maxf(fog, lw.y)
	# a lit lantern near the camera (the fog isle's, FogPlaces.FogClear) thins the fog round it
	fog *= 1.0 - LANTERN_CLEAR * lantern_clear
	state = current_state()
	if state != _prev_state:
		_prev_state = state
		weather_changed.emit(state)
	var oc := get_node_or_null("/root/Ocean")
	if oc:
		oc.set("amp_mult", waves)
	_update_sun(hour())
	_update_clouds()
	_update_env()


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
		var step := DayClock.secs_between(hour(), hour() + 2.0)
		if net and net.active:
			net.everyone("_all_weather", [forced, forced_at, world_offset + step])
		else:
			world_offset += step
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
## Nights are moonlit blue: the moon and the ambient keep the ground, the crew and the
## enemies readable, darker than day, so the lamps' warm pools still stand out.
const KEYS := [
	[0.0, Color(0.01, 0.02, 0.06), Color(0.07, 0.1, 0.2), Color(0.55, 0.66, 1.0), 0.42, Color(0.3, 0.36, 0.56), 0.62],
	[4.8, Color(0.03, 0.04, 0.11), Color(0.12, 0.12, 0.24), Color(0.55, 0.66, 1.0), 0.36, Color(0.3, 0.34, 0.54), 0.6],
	[6.0, Color(0.16, 0.24, 0.5), Color(0.9, 0.58, 0.42), Color(1.0, 0.55, 0.32), 0.55, Color(0.5, 0.42, 0.5), 0.6],
	[7.5, Color(0.18, 0.38, 0.75), Color(0.75, 0.72, 0.78), Color(1.0, 0.82, 0.62), 1.1, Color(0.5, 0.55, 0.66), 0.7],
	[9.0, Color(0.15, 0.4, 0.82), Color(0.5, 0.72, 0.92), Color(1.0, 0.92, 0.78), 1.35, Color(0.5, 0.58, 0.7), 0.75],
	[15.5, Color(0.14, 0.39, 0.82), Color(0.52, 0.72, 0.9), Color(1.0, 0.9, 0.74), 1.3, Color(0.52, 0.58, 0.68), 0.75],
	[17.2, Color(0.2, 0.32, 0.66), Color(0.9, 0.62, 0.45), Color(1.0, 0.68, 0.42), 1.0, Color(0.58, 0.5, 0.52), 0.68],
	[18.3, Color(0.14, 0.17, 0.42), Color(0.95, 0.5, 0.32), Color(1.0, 0.45, 0.25), 0.5, Color(0.5, 0.38, 0.45), 0.6],
	[19.6, Color(0.04, 0.05, 0.14), Color(0.2, 0.12, 0.22), Color(0.55, 0.66, 1.0), 0.32, Color(0.32, 0.33, 0.52), 0.6],
	[24.0, Color(0.01, 0.02, 0.06), Color(0.07, 0.1, 0.2), Color(0.55, 0.66, 1.0), 0.42, Color(0.3, 0.36, 0.56), 0.62],
]
## The least the ambient light may be (its colour's luminance x energy): storms and
## overcast nights stay playable. ambient_level() reads it back.
const AMBIENT_FLOOR := 0.16

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
		var storm_light := STORM_LIGHT.lerp((_zone_style["storm_color"] as Color).lightened(0.35), float(_zone[1]))
		_sun.light_color = _sun_col.lerp(storm_light, storm * 0.6)
		_sun.shadow_enabled = e > 0.12


## Home's storm sky and storm light; a themed island's storm_color takes over across its reach.
const STORM_GREY := Color(0.36, 0.38, 0.42)
const STORM_LIGHT := Color(0.75, 0.8, 0.9)


## The fog's colour from the horizon's: leaning to the place's haze_color (by its alpha x weight `k`) and, as a heavy
## fall or a sandstorm closes in (`mk`), to its storm colour; both dim with the night.
func haze_here(hor: Color, st: Dictionary, k: float, mk: float) -> Color:
	var hz: Color = st["haze_color"]
	var dim := lerpf(1.0, 0.2, night)
	var c := hor.lerp(Color(hz.r * dim, hz.g * dim, hz.b * dim), hz.a * k)
	var sc := (st["storm_color"] as Color).lightened(0.2)
	return c.lerp(Color(sc.r * dim, sc.g * dim, sc.b * dim), mk)


func _update_env() -> void:
	var zk := float(_zone[1])
	var grey := STORM_GREY.lerp(_zone_style["storm_color"], zk)
	var top := _top.lerp(grey * (1.0 - night * 0.75), storm * 0.7)
	# (a hazy place's sky pales toward its haze overhead too: a snow island's white, a desert's dusty pale blue)
	var hz: Color = _zone_style["haze_color"]
	# (a misty place, the fog isle: the whole sky greys into its fog)
	var misty := float(_zone_style["mist"]) * zk * (1.0 - LANTERN_CLEAR * lantern_clear)
	top = top.lerp(Color(hz.r, hz.g, hz.b) * lerpf(1.0, 0.2, night), maxf(hz.a * zk * 0.4, misty * 0.85))
	var hor := _hor.lerp(grey * 1.2 * (1.0 - night * 0.75), storm * 0.7)
	hor = hor.lerp(Color(hz.r, hz.g, hz.b) * lerpf(1.0, 0.2, night), misty * 0.9)
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
		_sky_mat.set_shader_parameter("fog_color", fog_color)
		_sky_mat.set_shader_parameter("haze_height", haze_height)
		var lit := Color(0.92, 0.93, 0.95).lerp(_sun_col, 0.3).lerp(Color(0.2, 0.22, 0.3), night * 0.85) * clampf(_sun_e / 1.2, 0.55, 1.0)
		_sky_mat.set_shader_parameter("cloud_lit", lit.lerp(Color(0.5, 0.52, 0.56), storm * 0.7))
		_sky_mat.set_shader_parameter("cloud_shade", (_amb * 1.1).lerp(Color(0.25, 0.26, 0.3), storm * 0.8))
	if _env:
		var amb := _amb.lerp(Color(0.42, 0.44, 0.5).lerp(Color(0.3, 0.34, 0.5), night), storm * 0.5)
		_env.ambient_light_color = amb
		_env.ambient_light_energy = maxf(_amb_e * (1.0 - storm * 0.3), AMBIENT_FLOOR / amb.get_luminance()) + flash * 1.5
		var fogc := haze_here(hor, _zone_style, zk, murk).lerp(Color(0.85, 0.88, 0.92), in_cloud)
		_env.fog_light_color = fogc
		# Long-range fog: the sea is fully fogged well inside its edge (1 km),
		# and the sky shader hazes into the same colour at the horizon.
		var begin := lerpf(110.0, 28.0, fog)
		var end := lerpf(820.0, 240.0, fog)
		# (a whiteout or a sandstorm: the next house is a shape in it)
		begin = lerpf(begin, 2.0, murk)
		end = lerpf(end, 65.0, murk)
		# (a misty place, the fog isle: the fog close in all round, thinned round a lit lantern)
		var mist := float(_zone_style["mist"]) * zk * (1.0 - LANTERN_CLEAR * lantern_clear)
		begin = lerpf(begin, 3.0, mist)
		end = lerpf(end, MIST_END, mist)
		begin = lerpf(begin, 0.0, in_cloud)
		end = lerpf(end, 28.0, in_cloud)
		if under_water:
			var deep := clampf(_under_depth / UNDER_DARK, 0.0, 1.0)
			var wc := UNDER_SHALLOW.lerp(UNDER_DEEP, deep) * lerpf(1.0, 0.22, night) * (1.0 - storm * 0.4)
			fogc = Color(wc.r, wc.g, wc.b)
			_env.fog_light_color = fogc
			begin = 0.5
			end = lerpf(UNDER_SEE.x, UNDER_SEE.y, deep)
			_env.ambient_light_energy *= lerpf(0.9, 0.5, deep)
		_env.fog_depth_begin = begin
		_env.fog_depth_end = end
		_env.fog_sky_affect = 0.0
		_env.fog_sun_scatter = 0.0
		fog_color = fogc
		fog_begin = begin
		fog_end = end
		var hazed := float((_zone_style["haze_color"] as Color).a) * zk * 0.3 * (1.0 - LANTERN_CLEAR * lantern_clear)
		haze_height = lerpf(lerpf(lerpf(lerpf(0.09, 0.3, fog) + hazed, 1.0, mist), 1.3, murk), 1.6, in_cloud)
		RenderingServer.global_shader_parameter_set("sky_haze", Vector4(fogc.r, fogc.g, fogc.b, haze_height))
		RenderingServer.global_shader_parameter_set("fog_range", Vector2(begin, end))
	if _ocean_mat:
		var dk := 1.0 - storm * 0.35
		var dc := Color(_base_deep.r * dk, _base_deep.g * dk, _base_deep.b * dk * 1.02, _base_deep.a)
		var sc := _base_shallow.lerp(Color(0.25, 0.32, 0.36, _base_shallow.a), storm * 0.5)
		# (a misty place, the fog isle: the sea goes grey and dark under its fog)
		sc = sc.lerp(Color(0.24, 0.3, 0.3, _base_shallow.a), misty * 0.85)
		dc = dc.lerp(Color(0.1, 0.14, 0.15, _base_deep.a), misty * 0.7)
		_ocean_mat.set_shader_parameter("deep_color", dc)
		_ocean_mat.set_shader_parameter("shallow_color", sc)
		_ocean_mat.set_shader_parameter("whitecaps", whitecaps())
		_ocean_mat.set_shader_parameter("wind_dir", wind_dir())
		_ocean_mat.set_shader_parameter("under_sea", 1.0 if under_water else 0.0)
	if _overlay:
		_overlay.color = Color(0.9, 0.92, 0.95, in_cloud * 0.55)
		if under_water:
			_overlay.color = Color(fog_color.r, fog_color.g, fog_color.b, UNDER_TINT)
		_overlay.visible = in_cloud > 0.01 or under_water


## Every frame: the sky's clouds and the cloud shadows on the ground and sea (shaders/world/cloud_shadow.gdshaderinc) drift.
func _drift_sky(delta: float) -> void:
	if _sky_mat:
		_sky_mat.set_shader_parameter("cloud_time", _sky_t)
	var wd := wind_dir() * (3.0 + wind * 9.0)
	_shadow_drift += wd * delta
	var strength := 0.4 * (1.0 - night) * (1.0 - storm * 0.6) * (1.0 - in_cloud)
	cloud_shadow = Vector4(clampf(coverage * 0.75, 0.0, 0.85), strength if _env else 0.0, _shadow_drift.x, _shadow_drift.y)
	RenderingServer.global_shader_parameter_set("cloud_shadow", cloud_shadow)


func _update_clouds() -> void:
	var cam := get_viewport().get_camera_3d()
	if _clouds == null or not is_instance_valid(_clouds):
		in_cloud = 0.0
		_cloud_target = 0.0
		return
	_clouds.set("coverage", coverage)
	_clouds.set("storm", storm)
	_clouds.set("wind_speed", 3.0 + wind * 9.0)
	_clouds.set("fog_color", fog_color)
	_clouds.set("haze_height", haze_height)
	_clouds.set("fog_begin", fog_begin)
	_clouds.set("fog_end", fog_end)
	var lit := Color(1, 1, 1).lerp(_sun_col, 0.3).lerp(Color(0.24, 0.26, 0.36), night * 0.85)
	_clouds.set("lit_color", lit.lerp(Color(0.48, 0.5, 0.55), storm * 0.75))
	_clouds.set("shade_color", (_amb * 1.05).lerp(Color(0.22, 0.23, 0.27), storm * 0.8).lerp(Color(0.08, 0.09, 0.14), night * 0.6))
	_cloud_target = 0.0
	if cam and _clouds.has_method("density_at"):
		_cloud_target = float(_clouds.density_at(cam.global_position))


# --------------------------------------------------------------------------
# Rain
# --------------------------------------------------------------------------
func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 1500
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
		var w := 0.012
		var hgt := 0.55
		var v := [b * Vector3(-w, -hgt, 0), b * Vector3(w, -hgt, 0), b * Vector3(w, hgt, 0), b * Vector3(-w, hgt, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(b * Vector3.BACK)
			st.add_vertex(v[idx])
	var mesh := st.commit()
	# (lit by the scene: grey by day, dark at night, lamplit near a lamp)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.68, 0.72, 0.78, 0.32)
	mat.roughness = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# (streaks right past the lens would be big white bars)
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 5.0
	mesh.surface_set_material(0, mat)
	_rain.draw_pass_1 = mesh
	_scene.add_child(_rain)
	_scene.add_child(RainFX.make(_rain))
	_precip = PrecipFX.new()
	_precip.name = "PrecipFX"
	_scene.add_child(_precip)
	var gl := GroundLayer.new()
	gl.name = "GroundLayer"
	_scene.add_child(gl)


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
	var wd2 := wind_dir()
	var wv := Vector3(wd2.x, 0, wd2.y) * wind * 4.0
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
	# (rebuilt around the camera every frame: interpolating it only warns)
	_rays.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
		th[0] = float(th[0]) - delta
		if float(th[0]) <= 0.0:
			_thunder_q.erase(th)
			FX_sfx("thunder_far" if th[1] else "thunder", -4.0 if th[1] else 0.0)
	# (no lightning in a blizzard or a sandstorm)
	if (storm if _zone_style["precip"] == "rain" else storm * (1.0 - float(_zone[1]))) < 0.55:
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
	_thunder_q.append([dist / 340.0, dist > 300.0])


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
		_sand_snd = _loop_player("res://assets/audio/sandstorm_loop.wav")
		_blizzard_snd = _loop_player("res://assets/audio/blizzard_loop.wav")
	if _ambience == null:
		_ambience = Ambience.new()
		_ambience.name = "Ambience"
		add_child(_ambience)
	if _spray == null:
		_spray = SeaSpray.new()
		_spray.name = "SeaSpray"
		add_child(_spray)


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := load(path) as AudioStreamWAV
	if s:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		# (in frames: the imported data is QOA-compressed, so its byte count says nothing)
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	p.volume_db = -60.0
	add_child(p)
	return p


func _update_audio(delta: float) -> void:
	var cover := 1.0 - _shelter * 0.5
	_set_loop(_rain_snd, rain * cover, -6.0, delta)
	_set_loop(_sand_snd, sand * cover, -6.0, delta)
	# (a light fall is quiet: the bed is for a heavy one and the blizzard)
	_set_loop(_blizzard_snd, smoothstep(SNOW_LIGHT, 1.0, snow) * cover, -6.0, delta)


func _set_loop(p: AudioStreamPlayer, k: float, top_db: float, delta: float) -> void:
	if p == null:
		return
	var want := -60.0 if k < 0.02 else linear_to_db(k) + top_db
	p.volume_db = move_toward(p.volume_db, want, 30.0 * delta)
	if p.volume_db > -55.0 and not p.playing:
		p.play(randf() * p.stream.get_length())
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
