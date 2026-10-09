extends Node3D
class_name SeaSpray
## Wind and water you can see, round the local camera (each screen makes its
## own, nothing is sent): wind streaks racing past along the wind (more in a
## gale, under way and up the mast, fewer inland), spray blown off the wave
## crests near you when it's whitecapping, and surf bursting where waves
## break on a beach in sight. The foam itself (whitecaps, surf rolling in,
## the swash) is the ocean shader's; Weather.whitecaps() drives both.

const STREAKS := 48
const STREAK_LEN := Vector2(2.5, 5.0)
const STREAK_LIFE := Vector2(0.45, 1.0)
## Surf bursts are looked for this far from the camera.
const SURF_NEAR := 6.0
const SURF_FAR := 45.0

var _mm: MultiMesh
var _streaks: Array = []   # [pos, dir, len, age, life, speed, width]
var _spawn_acc := 0.0
var _crest_t := 0.0
var _surf_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
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
	var quad := QuadMesh.new()
	quad.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = STREAKS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WindStreaks"
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (the streaks are wherever the camera is: never culled by a stale box)
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mmi)
	top_level = true


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if cam == null or me == null:
		_streaks.clear()
		_draw(null)
		return
	var wx := get_node_or_null("/root/Weather")
	var wind: float = float(wx.get("wind")) if wx else 0.3
	var storm: float = float(wx.get("storm")) if wx else 0.0
	var caps: float = float(wx.call("whitecaps")) if wx else 0.0
	var w2: Vector2 = wx.call("wind_dir") if wx else Vector2(1, 0)
	var wdir := Vector3(w2.x, 0.0, w2.y).normalized()
	var amb := get_parent().get_node_or_null("Ambience")
	var inland: float = float(amb.get("_land_near")) * float(amb.get("_land_far")) if amb else 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var aboard: bool = ship != null and bool(ship.call("aboard", me.global_position))
	var spd: float = absf(float(ship.get("speed"))) if aboard else 0.0
	# the wind you feel: under way the ship's own speed blows aft over her
	var feel := wdir
	if aboard and spd > 1.0:
		var fwd := -ship.global_basis.z
		feel = (wdir * (0.4 + wind) - Vector3(fwd.x, 0.0, fwd.z).normalized() * spd / 13.0).normalized()
	var high := clampf((me.global_position.y - 2.0) / 14.0, 0.0, 1.0)
	var strength := clampf(wind * 0.8 + storm * 0.6 + spd / 22.0 + high * 0.5 - 0.3, 0.0, 1.0) * (1.0 - 0.7 * inland)
	_spawn_streaks(delta, cam, strength, feel, wind + storm)
	_update_streaks(delta)
	_draw(cam)
	_crest_t -= delta
	if _crest_t <= 0.0:
		_crest_t = 0.12
		if caps > 0.12 and _rng.randf() < caps:
			_crest_spray(cam, wdir, caps, wind)
	_surf_t -= delta
	if _surf_t <= 0.0:
		_surf_t = 0.3
		_surf_burst(cam, ship)


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
# Spray off the crests, surf on the beaches
# --------------------------------------------------------------------------
## A crest near you (in view, over deep water) blowing off downwind.
func _crest_spray(cam: Camera3D, wdir: Vector3, caps: float, wind: float) -> void:
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return
	var a := atan2(fwd.z, fwd.x) + _rng.randf_range(-1.0, 1.0)
	var r := _rng.randf_range(12.0, 50.0)
	var p := Vector3(cam.global_position.x + cos(a) * r, 0.0, cam.global_position.z + sin(a) * r)
	var h: float = float(Ocean.get_wave_height(p))
	if h < 0.45 * float(Ocean.get("amp_mult")):
		return
	if float(Ocean.depth_at(Vector3(p.x, 80.0, p.z), [], true)) < 3.0:
		return
	p.y = h + 0.15
	FX.spray(p, (wdir + Vector3.UP * 0.55).normalized(), int(6 + caps * 8), Color(0.92, 0.97, 1.0), 3.0 + wind * 5.0)


## A wave breaking on a beach in sight: a burst of white water thrown up.
func _surf_burst(cam: Camera3D, ship: Node3D) -> void:
	var skip: Array = [(ship as CollisionObject3D).get_rid()] if ship is CollisionObject3D else []
	for _i in range(3):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(SURF_NEAR, SURF_FAR)
		var p := Vector3(cam.global_position.x + cos(a) * r, 80.0, cam.global_position.z + sin(a) * r)
		var depth: float = float(Ocean.depth_at(p, skip, true))
		if depth > 0.05 and depth < 0.8:
			var s := Vector3(p.x, float(Ocean.get_wave_height(p)) + 0.05, p.z)
			FX.splash(s, 5, 0.7)
			FX.spray(s, (Vector3.UP + Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))).normalized(), 7, Color(0.95, 0.98, 1.0), 3.2)
			return
