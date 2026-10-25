extends Node3D
class_name SeaSpray
## Wind and water you can see, round the local camera (each screen makes its
## own, nothing is sent): wind streaks racing past along the wind (more in a
## gale and its gusts, under way and up the mast, fewer inland), spray blown off
## the wave crests near you when it's whitecapping and spindrift streaming off
## them in a gale, foam patches drifting on the swell, and the waves breaking on
## the coasts in sight as each crest arrives: white water on a beach, spray
## thrown high off rocks and cliffs, a slap against a quay, each with its sound.
## The foam itself (whitecaps, surf rolling in, the swash) is the ocean shader's;
## Weather.whitecaps() drives both. Where the coast is: Ambience's CoastProbe.
## The streaks fly and fade on the GPU (shaders/world/wind_streaks.gdshader, 2026-10-25), and the foam patches
## drift, ride the swell and fade there too (shaders/world/sea_foam.gdshader, the ocean's own wave sums): each is
## written into its slot when it's born and nothing runs for it after.

const STREAKS := 48
const STREAK_LEN := Vector2(2.5, 5.0)
const STREAK_LIFE := Vector2(0.45, 1.0)
## Waves break on coasts this close to the camera (heard to BREAK_HEARD).
const BREAK_NEAR := 75.0
const BREAK_HEARD := 55.0
const FOAM := 40
const FOAM_NEAR := Vector2(6.0, 55.0)
const DRIFTS := 5
## The coasts are watched for an arriving crest every SURF_EVERY s.
const SURF_EVERY := 0.06

var _mm: MultiMesh
var _streak_mat: ShaderMaterial
## The streaks' clock (the shader's `now`), the next slot to write, and each slot's birth and life.
var _clock := 0.0
var _slot := 0
var _born: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _spawn_acc := 0.0
var _crest_t := 0.0
var _rng := RandomNumberGenerator.new()
## coast water point (rounded) -> [wave height last frame, cooldown, exposure to the swell]
var _breaks := {}
var _break_gap := 0.0
var _surf_acc := 0.0
## Waves broken so far, by kind (tests).
var breaks := {"beach": 0, "rock": 0, "wall": 0}
var _foam_mm: MultiMesh
var _foam_mat: ShaderMaterial
## Each foam slot: [born, life, x, z, drift x, drift z] (life 0: free).
var _foam: Array = []
var _foam_acc := 0.0
var _foam_slot := 0
var _foam_check := 0.0
var _waves_t := 0.0
## The ocean material's wave uniforms the foam's shader sums the same way (copied every WAVES_EVERY s; the clock
## and the storm cells every frame).
const WAVE_PARAMS := ["waves", "wave_amp_phase", "amp_mult", "crest", "env_dirs", "env_params", "crest_cap", "shore0",
	"shore1", "shore2", "shore3", "shore_rect", "shore_waves", "shore_shape", "shore_fade", "shore_wob", "shore_none"]
const WAVES_EVERY := 1.0
const ROW := 16
## Each MultiMesh's rows as last sent (the headless renderer can't give them back).
var rows := {}
var _drift: Array = []   # [emitter, time left]


func _ready() -> void:
	_rng.randomize()
	top_level = true
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 32
	tex.height = 1
	_streak_mat = ShaderMaterial.new()
	_streak_mat.shader = load("res://shaders/world/wind_streaks.gdshader")
	_streak_mat.set_shader_parameter("streak", tex)
	_mm = _multimesh(STREAKS, _streak_mat, Vector2.ONE, "WindStreaks", true)
	_mm.visible_instance_count = STREAKS
	var empty := PackedFloat32Array()
	empty.resize(STREAKS * ROW)
	for i in range(STREAKS):
		empty[i * ROW] = 1.0
		empty[i * ROW + 5] = 1.0
		empty[i * ROW + 10] = 1.0
	_mm.buffer = empty
	rows[_mm] = empty
	_born.resize(STREAKS)
	_born.fill(-INF)
	_life.resize(STREAKS)
	_foam_mat = ShaderMaterial.new()
	_foam_mat.shader = load("res://shaders/world/sea_foam.gdshader")
	_foam_mat.set_shader_parameter("foam_tex", _foam_texture())
	_foam_mm = _multimesh(FOAM, _foam_mat, Vector2.ONE, "Foam", true)
	_foam_mm.visible_instance_count = FOAM
	var none := PackedFloat32Array()
	none.resize(FOAM * ROW)
	for i in range(FOAM):
		none[i * ROW] = 1.0
		none[i * ROW + 5] = 1.0
		none[i * ROW + 10] = 1.0
		none[i * ROW + 12] = 0.0
		none[i * ROW + 13] = 0.0
		_foam.append([-INF, 0.0, 0.0, 0.0, 0.0, 0.0])
	_foam_mm.buffer = none
	rows[_foam_mm] = none
	for i in range(DRIFTS):
		var p := CPUParticles3D.new()
		p.name = "Spindrift"
		p.amount = 26
		p.lifetime = 1.3
		p.local_coords = true
		p.emitting = false
		p.randomness = 0.5
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(2.5, 0.15, 2.5)
		p.spread = 14.0
		p.damping_min = 0.3
		p.damping_max = 0.8
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		p.scale_amount_curve = FX._curve("shrink")
		p.color_ramp = FX._fade_to_clear(Color(0.93, 0.97, 1.0, 0.85))
		p.mesh = FX._quad(0.22, FX._dust_mat)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_drift.append([p, 0.0])


func _multimesh(count: int, mat: Material, size: Vector2, node_name: String, custom := false) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not custom
	mm.use_custom_data = custom
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (these are wherever the camera is: never culled by a stale box)
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mmi)
	return mm


## A ragged blot of foam, 16 px: a lumpy disc with holes (chunky at PSX scale).
func _foam_texture() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	var lobes: Array = []
	for i in range(5):
		lobes.append([Vector2(rng.randf_range(4.0, 12.0), rng.randf_range(4.0, 12.0)), rng.randf_range(2.5, 4.5)])
	for y in range(16):
		for x in range(16):
			var p := Vector2(x + 0.5, y + 0.5)
			var on := false
			for l in lobes:
				if p.distance_to(l[0]) < float(l[1]):
					on = true
			if on and rng.randf() < 0.82:
				var v := rng.randf_range(0.85, 1.0)
				img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var me := get_tree().get_first_node_in_group("player") as Node3D
	_clock += delta
	_streak_mat.set_shader_parameter("now", _clock)
	_waves(delta)
	if cam == null or me == null:
		return
	var wx := get_node_or_null("/root/Weather")
	var wind: float = float(wx.get("wind")) if wx else 0.3
	var storm: float = float(wx.get("storm")) if wx else 0.0
	var caps: float = float(wx.call("whitecaps")) if wx else 0.0
	var w2: Vector2 = wx.call("wind_dir") if wx else Vector2(1, 0)
	var wdir := Vector3(w2.x, 0.0, w2.y).normalized()
	var amb := get_parent().get_node_or_null("Ambience")
	var inland: float = float(amb.get("_land_near")) * float(amb.get("_land_far")) if amb else 0.0
	var gust: float = float(amb.get("gust")) if amb else 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var aboard: bool = ship != null and bool(ship.call("aboard", me.global_position))
	var spd: float = absf(float(ship.get("speed"))) if aboard else 0.0
	# the wind you feel: under way the ship's own speed blows aft over her
	var feel := wdir
	if aboard and spd > 1.0:
		var fwd := -ship.global_basis.z
		feel = (wdir * (0.4 + wind) - Vector3(fwd.x, 0.0, fwd.z).normalized() * spd / 13.0).normalized()
	var high := clampf((me.global_position.y - 2.0) / 14.0, 0.0, 1.0)
	var strength := clampf(wind * 0.8 + storm * 0.6 + spd / 22.0 + high * 0.5 - 0.3 + gust * 0.35, 0.0, 1.0) * (1.0 - 0.7 * inland)
	_spawn_streaks(delta, cam, strength, feel, wind + storm + gust * 0.3)
	_crest_t -= delta
	if _crest_t <= 0.0:
		_crest_t = 0.12
		if caps > 0.12 and _rng.randf() < caps:
			_crest_spray(cam, wdir, caps, wind)
	_spindrift(delta, cam, wdir, caps, wind, storm, gust)
	_drift_foam(delta, cam, wdir, wind, caps, inland, ship)
	_surf_acc += delta
	if amb and _surf_acc >= SURF_EVERY:
		_surf(_surf_acc, cam, amb.get("coast"))
		_surf_acc = 0.0


# --------------------------------------------------------------------------
# Wind streaks
# --------------------------------------------------------------------------
func _spawn_streaks(delta: float, cam: Camera3D, strength: float, dir: Vector3, blow: float) -> void:
	_spawn_acc += delta * strength * 45.0
	var any := false
	while _spawn_acc >= 1.0 and alive() < STREAKS:
		_spawn_acc -= 1.0
		var a := _rng.randf() * TAU
		# (closer than ~9 m a streak fills the view like a beam)
		var r := _rng.randf_range(9.0, 28.0)
		var c := cam.global_position + Vector3(cos(a) * r, _rng.randf_range(-3.0, 4.0), sin(a) * r)
		c.y = maxf(c.y, 0.6)
		var d := (dir + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.04, 0.06), _rng.randf_range(-0.1, 0.1))).normalized()
		_streak(c, d, _rng.randf_range(STREAK_LEN.x, STREAK_LEN.y), _rng.randf_range(STREAK_LIFE.x, STREAK_LIFE.y),
			_rng.randf_range(14.0, 22.0) * (0.6 + 0.5 * clampf(blow, 0.0, 1.0)), _rng.randf_range(0.045, 0.08))
		any = true
	_spawn_acc = minf(_spawn_acc, 3.0)
	if any:
		_mm.buffer = rows[_mm]


## A streak born now at c going d: written into the next free slot's row (sent with the frame's others).
func _streak(c: Vector3, d: Vector3, length: float, life: float, speed: float, width: float) -> int:
	var i := _slot
	for k in range(STREAKS):
		if not _alive((_slot + k) % STREAKS):
			i = (_slot + k) % STREAKS
			break
	_slot = (i + 1) % STREAKS
	_born[i] = _clock
	_life[i] = life
	var x := d * length
	var y := (d.cross(Vector3.UP) if absf(d.y) < 0.95 else d.cross(Vector3.RIGHT)).normalized() * width
	var z := x.cross(y).normalized()
	var r: PackedFloat32Array = rows[_mm]
	var o := i * ROW
	var row := [x.x, y.x, z.x, c.x, x.y, y.y, z.y, c.y, x.z, y.z, z.z, c.z, _clock, life, speed, 0.0]
	for k in range(ROW):
		r[o + k] = row[k]
	return i


func _alive(i: int) -> bool:
	return _clock - _born[i] < _life[i]


## Streaks in the air now.
func alive() -> int:
	var n := 0
	for i in range(STREAKS):
		if _alive(i):
			n += 1
	return n


# --------------------------------------------------------------------------
# Spray off the crests, spindrift
# --------------------------------------------------------------------------
## A crest in view over deep water `r` m out, or Vector3.INF.
func _crest_near(cam: Camera3D, near: float, far: float, tall: float) -> Vector3:
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return Vector3.INF
	var a := atan2(fwd.z, fwd.x) + _rng.randf_range(-1.0, 1.0)
	var r := _rng.randf_range(near, far)
	var p := Vector3(cam.global_position.x + cos(a) * r, 0.0, cam.global_position.z + sin(a) * r)
	var h: float = float(Ocean.get_wave_height(p))
	if h < tall * float(Ocean.get("amp_mult")):
		return Vector3.INF
	if float(Ocean.depth_at(Vector3(p.x, 80.0, p.z), [], true)) < 3.0:
		return Vector3.INF
	return Vector3(p.x, h, p.z)


## A crest near you (in view, over deep water) blowing off downwind.
func _crest_spray(cam: Camera3D, wdir: Vector3, caps: float, wind: float) -> void:
	var p := _crest_near(cam, 12.0, 50.0, 0.45)
	if p == Vector3.INF:
		return
	FX.spray(p + Vector3.UP * 0.15, (wdir + Vector3.UP * 0.55).normalized(), int(6 + caps * 8), Color(0.92, 0.97, 1.0), 3.0 + wind * 5.0)


## In a gale the crests' tops tear off and stream away downwind, low over the water.
func _spindrift(delta: float, cam: Camera3D, wdir: Vector3, caps: float, wind: float, storm: float, gust: float) -> void:
	var k := clampf((caps - 0.35) / 0.55 + gust * 0.25, 0.0, 1.0)
	for e in _drift:
		var p: CPUParticles3D = e[0]
		e[1] = float(e[1]) - delta
		if p.emitting and float(e[1]) <= p.lifetime:
			p.emitting = false
		if float(e[1]) > 0.0 or k <= 0.0 or _rng.randf() > k * 4.0 * delta:
			continue
		var at := _crest_near(cam, 10.0, 60.0, 0.4)
		if at == Vector3.INF:
			continue
		p.global_position = at + Vector3.UP * 0.1
		p.gravity = wdir * (2.5 + wind * 5.0 + storm * 4.0) + Vector3(0.0, -1.2, 0.0)
		p.direction = (wdir + Vector3.UP * 0.3).normalized()
		p.initial_velocity_min = 2.0 + 2.0 * k
		p.initial_velocity_max = 3.5 + 5.0 * k
		p.emitting = true
		e[1] = p.lifetime + _rng.randf_range(0.5, 1.1)


# --------------------------------------------------------------------------
# Foam patches drifting on the swell
# --------------------------------------------------------------------------
func _drift_foam(delta: float, cam: Camera3D, wdir: Vector3, wind: float, caps: float, inland: float, _ship: Node3D) -> void:
	var c := Vector2(cam.global_position.x, cam.global_position.z)
	var any := false
	# (ones drifted out of reach or behind a ship that's sailed on: let go, twice a second)
	_foam_check -= delta
	if _foam_check <= 0.0:
		_foam_check = 0.5
		for i in range(FOAM):
			if _foam_alive(i) and c.distance_to(foam_at(i)) >= FOAM_NEAR.y + 10.0:
				_foam[i][1] = 0.0
				rows[_foam_mm][i * ROW + 13] = 0.0
				any = true
	var want := int(FOAM * (0.4 + 0.6 * caps) * (1.0 - inland))
	_foam_acc += delta * 10.0
	while _foam_acc >= 1.0:
		_foam_acc -= 1.0
		if foam_alive() >= want:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(FOAM_NEAR.x, FOAM_NEAR.y)
		var p := Vector3(cam.global_position.x + cos(a) * r, 80.0, cam.global_position.z + sin(a) * r)
		# (not under a hull: the ship's own collider counts as ground here)
		if float(Ocean.depth_at(p, [], true)) < 1.0:
			continue
		var v := wdir * (0.3 + wind * 0.8)
		_foam_patch(p.x, p.z, _rng.randf_range(7.0, 14.0), _rng.randf_range(0.7, 1.7), _rng.randf() * TAU, Vector2(v.x, v.z))
		any = true
	_foam_acc = minf(_foam_acc, 2.0)
	if any:
		_foam_mm.buffer = rows[_foam_mm]


## A foam patch born now at (x, z): its slot's row (sent with the frame's others).
func _foam_patch(x: float, z: float, life: float, size: float, yaw: float, drift: Vector2) -> int:
	var i := _foam_slot
	for k in range(FOAM):
		if not _foam_alive((_foam_slot + k) % FOAM):
			i = (_foam_slot + k) % FOAM
			break
	_foam_slot = (i + 1) % FOAM
	_foam[i] = [_clock, life, x, z, drift.x, drift.y]
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
	var r: PackedFloat32Array = rows[_foam_mm]
	var row := [b.x.x, b.y.x, b.z.x, x, b.x.y, b.y.y, b.z.y, 0.0, b.x.z, b.y.z, b.z.z, z, _clock, life, drift.x, drift.y]
	for k in range(ROW):
		r[i * ROW + k] = row[k]
	return i


func _foam_alive(i: int) -> bool:
	return _clock - float(_foam[i][0]) < float(_foam[i][1])


## Foam patches on the water now.
func foam_alive() -> int:
	var n := 0
	for i in range(FOAM):
		if _foam_alive(i):
			n += 1
	return n


## Where patch i has drifted to (x, z), as the shader has it.
func foam_at(i: int) -> Vector2:
	var f: Array = _foam[i]
	var age := _clock - float(f[0])
	return Vector2(float(f[2]) + float(f[4]) * age, float(f[3]) + float(f[5]) * age)


## The ocean's wave uniforms into the foam's shader: its clock and storm cells every frame, the rest now and then.
func _waves(delta: float) -> void:
	var om: ShaderMaterial = Ocean.get("ocean_material")
	_foam_mat.set_shader_parameter("now", _clock)
	if om == null:
		return
	_foam_mat.set_shader_parameter("time_val", Ocean.clock())
	_foam_mat.set_shader_parameter("storm_cells", om.get_shader_parameter("storm_cells"))
	_waves_t -= delta
	if _waves_t > 0.0:
		return
	_waves_t = WAVES_EVERY
	for k in WAVE_PARAMS:
		_foam_mat.set_shader_parameter(k, om.get_shader_parameter(k))


# --------------------------------------------------------------------------
# Waves breaking on the coasts in sight, in time with the swell
# --------------------------------------------------------------------------
func _surf(delta: float, cam: Camera3D, coast: CoastProbe) -> void:
	_break_gap -= delta
	var amp: float = float(Ocean.get("amp_mult"))
	var seen := {}
	for c in coast.all():
		var w: Vector3 = c[1]
		var d := Vector2(w.x - cam.global_position.x, w.z - cam.global_position.z).length()
		if d > BREAK_NEAR:
			continue
		var key := Vector3i(roundi(w.x), 0, roundi(w.z))
		seen[key] = true
		# (the crest as it arrives: at the waterline the shallows have calmed the surface itself)
		var h: float = float(Ocean.breaker_height(w))
		var st: Array = _breaks.get(key, [])
		if st.is_empty():
			# (a lee shore's smaller swell breaks smaller: how exposed this spot is, once)
			var sh: Vector4 = Ocean.shore_at(w.x, w.z)
			st = [h, _rng.randf_range(0.0, 1.5), lerpf(1.0, sh.w, sh.z)]
		st[1] = float(st[1]) - delta
		# (each crest as it reaches the shore)
		var expo := float(st[2])
		var crest := 0.28 * amp * expo
		if float(st[0]) < crest and h >= crest and float(st[1]) <= 0.0 and _break_gap <= 0.0:
			st[1] = 2.0
			_break_gap = 0.2
			_break(c, h, d, amp * (0.5 + 0.5 * expo))
		st[0] = h
		_breaks[key] = st
	for k in _breaks.keys():
		if not seen.has(k):
			_breaks.erase(k)


func _break(c: Array, h: float, d: float, amp: float) -> void:
	var kind: String = c[0]
	var w: Vector3 = c[1]
	var out := (w - (c[2] as Vector3)).normalized()
	var along := out.cross(Vector3.UP)
	var p := w + along * _rng.randf_range(-5.0, 5.0)
	p.y = float(Ocean.get_wave_height(p)) + 0.05
	breaks[kind] = int(breaks[kind]) + 1
	var loud := clampf(amp, 0.8, 1.8)
	match kind:
		"beach":
			FX.splash(p, 5, 0.65)
			FX.spray(p, (Vector3.UP * 1.1 - out * 0.6).normalized(), int(6 + 4 * loud), Color(0.95, 0.98, 1.0), 3.0 * loud)
			if d < BREAK_HEARD:
				FX.sfx("wave_break", p, -7.0 + 4.0 * (loud - 1.0), 0.08)
		"rock":
			var at := p - out * 0.8
			FX.spray(at, (Vector3.UP * 1.6 - out * 0.3).normalized(), int(14 + 8 * loud), Color(0.95, 0.98, 1.0), 6.0 + 3.0 * loud)
			FX.spray(at + Vector3.UP * 0.8, (Vector3.UP + out * 0.4).normalized(), int(8 + 4 * loud), Color(0.95, 0.98, 1.0), 4.0 * loud)
			FX.splash(at, 4, 0.65)
			FX.smoke(at + Vector3.UP * 1.2, 4, 1.6, 1.1, Color(0.92, 0.96, 1.0, 0.55))
			if d < BREAK_HEARD:
				FX.sfx("rock_crash", at, -5.0 + 4.0 * (loud - 1.0), 0.08)
		_:
			FX.spray(p, (Vector3.UP * 1.3 - out * 0.3).normalized(), 6, Color(0.95, 0.98, 1.0), 2.8)
			if d < BREAK_HEARD * 0.6:
				FX.sfx("hull_wave", p, -12.0, 0.1, 0.9)
