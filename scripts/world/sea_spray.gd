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

const STREAKS := 48
const STREAK_LEN := Vector2(2.5, 5.0)
const STREAK_LIFE := Vector2(0.45, 1.0)
## Waves break on coasts this close to the camera (heard to BREAK_HEARD).
const BREAK_NEAR := 75.0
const BREAK_HEARD := 55.0
const FOAM := 40
const FOAM_NEAR := Vector2(6.0, 55.0)
const DRIFTS := 5

var _mm: MultiMesh
var _streaks: Array = []   # [pos, dir, len, age, life, speed, width]
var _spawn_acc := 0.0
var _crest_t := 0.0
var _rng := RandomNumberGenerator.new()
## coast water point (rounded) -> [wave height last frame, cooldown]
var _breaks := {}
var _break_gap := 0.0
## Waves broken so far, by kind (tests).
var breaks := {"beach": 0, "rock": 0, "wall": 0}
var _foam_mm: MultiMesh
var _foam: Array = []   # [x, z, age, life, size, yaw]
var _foam_acc := 0.0
var _foam_i := 0
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
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mm = _multimesh(STREAKS, mat, Vector2.ONE, "WindStreaks")
	var foam := StandardMaterial3D.new()
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foam.alpha_scissor_threshold = 0.5
	foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	foam.vertex_color_use_as_albedo = true
	foam.albedo_texture = _foam_texture()
	foam.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	foam.roughness = 1.0
	_foam_mm = _multimesh(FOAM, foam, Vector2.ONE, "Foam")
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


func _multimesh(count: int, mat: Material, size: Vector2, node_name: String) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
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
	if cam == null or me == null:
		_streaks.clear()
		_draw(null)
		_foam.clear()
		_draw_foam()
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
	_update_streaks(delta)
	_draw(cam)
	_crest_t -= delta
	if _crest_t <= 0.0:
		_crest_t = 0.12
		if caps > 0.12 and _rng.randf() < caps:
			_crest_spray(cam, wdir, caps, wind)
	_spindrift(delta, cam, wdir, caps, wind, storm, gust)
	_drift_foam(delta, cam, wdir, wind, caps, inland, ship)
	if amb:
		_surf(delta, cam, amb.get("coast"))


# --------------------------------------------------------------------------
# Wind streaks
# --------------------------------------------------------------------------
func _spawn_streaks(delta: float, cam: Camera3D, strength: float, dir: Vector3, blow: float) -> void:
	_spawn_acc += delta * strength * 45.0
	while _spawn_acc >= 1.0 and _streaks.size() < STREAKS:
		_spawn_acc -= 1.0
		var a := _rng.randf() * TAU
		# (closer than ~9 m a streak fills the view like a beam)
		var r := _rng.randf_range(9.0, 28.0)
		var c := cam.global_position + Vector3(cos(a) * r, _rng.randf_range(-3.0, 4.0), sin(a) * r)
		c.y = maxf(c.y, 0.6)
		var d := (dir + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.04, 0.06), _rng.randf_range(-0.1, 0.1))).normalized()
		_streaks.append([c, d, _rng.randf_range(STREAK_LEN.x, STREAK_LEN.y), 0.0,
			_rng.randf_range(STREAK_LIFE.x, STREAK_LIFE.y), _rng.randf_range(14.0, 22.0) * (0.6 + 0.5 * clampf(blow, 0.0, 1.0)),
			_rng.randf_range(0.045, 0.08)])
	_spawn_acc = minf(_spawn_acc, 3.0)


func _update_streaks(delta: float) -> void:
	for s in _streaks:
		s[3] = float(s[3]) + delta
		s[0] = (s[0] as Vector3) + (s[1] as Vector3) * float(s[5]) * delta
	_streaks = _streaks.filter(func(s): return float(s[3]) < float(s[4]))


func _draw(cam: Camera3D) -> void:
	var n := mini(_streaks.size(), STREAKS)
	_mm.visible_instance_count = n
	for i in range(n):
		var s: Array = _streaks[i]
		var p: Vector3 = s[0]
		var d: Vector3 = s[1]
		var to_cam := (cam.global_position - p).normalized() if cam else Vector3.UP
		var side := d.cross(to_cam).normalized()
		var k := float(s[3]) / float(s[4])
		var b := Basis(d * float(s[2]), side * float(s[6]), d.cross(side))
		_mm.set_instance_transform(i, Transform3D(b, p))
		_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.4 * sin(PI * k)))


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
func _drift_foam(delta: float, cam: Camera3D, wdir: Vector3, wind: float, caps: float, inland: float, ship: Node3D) -> void:
	var want := int(FOAM * (0.4 + 0.6 * caps) * (1.0 - inland))
	_foam_acc += delta * 10.0
	var skip: Array = [(ship as CollisionObject3D).get_rid()] if ship is CollisionObject3D else []
	while _foam_acc >= 1.0:
		_foam_acc -= 1.0
		if _foam.size() >= want:
			break
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(FOAM_NEAR.x, FOAM_NEAR.y)
		var p := Vector3(cam.global_position.x + cos(a) * r, 80.0, cam.global_position.z + sin(a) * r)
		if float(Ocean.depth_at(p, skip, true)) < 1.0:
			continue
		_foam.append([p.x, p.z, 0.0, _rng.randf_range(7.0, 14.0), _rng.randf_range(0.7, 1.7), _rng.randf() * TAU])
	_foam_acc = minf(_foam_acc, 2.0)
	var v := wdir * (0.3 + wind * 0.8) * delta
	var c := Vector2(cam.global_position.x, cam.global_position.z)
	for f in _foam:
		f[0] = float(f[0]) + v.x
		f[1] = float(f[1]) + v.z
		f[2] = float(f[2]) + delta
	_foam = _foam.filter(func(f): return float(f[2]) < float(f[3]) and c.distance_to(Vector2(f[0], f[1])) < FOAM_NEAR.y + 10.0)
	_draw_foam()


func _draw_foam() -> void:
	var n := mini(_foam.size(), FOAM)
	_foam_mm.visible_instance_count = n
	_foam_i = (_foam_i + 1) % 3
	for i in range(n):
		var f: Array = _foam[i]
		var p := Vector3(f[0], 0.0, f[1])
		p.y = float(Ocean.get_wave_height(p)) + 0.05
		var up := Vector3.UP
		# (the tilt every third frame, a third of them at a time)
		if i % 3 == _foam_i:
			up = Ocean.get_wave_normal(p)
			f.resize(7)
			f[6] = up
		elif f.size() > 6:
			up = f[6]
		var k := float(f[2]) / float(f[3])
		var b := Basis(Vector3.UP, float(f[5]))
		b = Basis(Quaternion(Vector3.UP, up)) * b * Basis(Vector3.RIGHT, -PI * 0.5)
		_foam_mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * float(f[4])), p))
		_foam_mm.set_instance_color(i, Color(0.9, 0.94, 0.96, clampf(minf(k * 4.0, (1.0 - k) * 2.5), 0.0, 1.0)))


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
		var h: float = float(Ocean.get_wave_height(w))
		var st: Array = _breaks.get(key, [h, _rng.randf_range(0.0, 1.5)])
		st[1] = float(st[1]) - delta
		# (each crest as it reaches the shore)
		var crest := 0.28 * amp
		if float(st[0]) < crest and h >= crest and float(st[1]) <= 0.0 and _break_gap <= 0.0:
			st[1] = 2.0
			_break_gap = 0.2
			_break(c, h, d, amp)
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
