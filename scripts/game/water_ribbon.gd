class_name WaterRibbon
extends MeshInstance3D
## A ribbon of water thrown along a path (FX.water_arc, FX.water_wake): the head races
## along it, the pixel-art water strip (water_trail.png: a foam crest with little curls
## breaking over it) flows along it stepping through its frames, a wave curls over at the
## head, then it breaks up from the tail into droplets and is gone. Rebuilt each frame in
## world space, on game time (it slows with slow motion).

const SEGS := 30
## How far past the arc's end the head curls inward, as a share of the arc.
const CURL := 0.22
const TRAIL_FRAMES := 8
## Flow along the ribbon (tiles a second) and the strip's frames a second.
const FLOW := 2.2
const FPS := 14.0

var center := Vector3.ZERO
## The arc's plane: `u` is where it starts, `v` the way it sweeps.
var u := Vector3.RIGHT
var v := Vector3.UP
var radius := 1.5
var sweep := PI
## A straight run from `center` to `to` lying flat on the ground instead of an arc.
var line := false
var to := Vector3.ZERO
var width := 0.5
var draw := 0.1
var life := 0.6
var color := Color(0.3, 0.72, 1.0)
var seed_v := 0
var _t := 0.0
var _sign := 1.0
var _drops := 0
var _am := ArrayMesh.new()
static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_texture = load("res://assets/textures/fx/water_trail.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mat.texture_repeat = true
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _am
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_build()


func _span() -> float:
	return 1.0 if line else 1.0 + CURL


func _at(s: float) -> Vector3:
	if line:
		var side := (to - center).cross(Vector3.UP).normalized()
		return center.lerp(to, s) + side * sin(s * 6.0 + seed_v) * 0.14
	var a := s * sweep
	var r := radius
	if s > 1.0:
		var k := (s - 1.0) / CURL
		a = sweep + (s - 1.0) * sweep * 1.9
		r = radius * (1.0 - 0.45 * k * k)
	return center + (u * cos(a) + v * sin(a)) * r


func _out(p: Vector3) -> Vector3:
	if line:
		return (to - center).cross(Vector3.UP).normalized()
	return (p - center).normalized()


## Arc length to `s` (the texture runs along it at a steady size).
func _len(s: float) -> float:
	if line:
		return center.distance_to(to) * s
	return absf(sweep) * radius * s


func _build() -> void:
	_am.clear_surfaces()
	var end := _span()
	var x := minf(_t / draw, 1.0)
	var head := end * (1.0 - pow(1.0 - x, 3.0))
	var hold := draw + (life - draw) * 0.2
	var k := clampf((_t - hold) / (life - hold), 0.0, 1.0)
	var tail := end * pow(k, 1.4)
	if head - tail < 0.02:
		return
	var cam := get_viewport().get_camera_3d()
	# a fixed grid in s, so the gaps the tail breaks into stay put frame to frame
	var ss: Array = [tail]
	var step := end / SEGS
	var g := int(ceil(tail / step))
	while g * step < head:
		if g * step > tail + 0.001:
			ss.append(g * step)
		g += 1
	ss.append(head)
	var n := ss.size()
	var pts: Array = []
	for s in ss:
		pts.append(_at(s))
	var sides: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var tan: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		tan = tan.normalized() if tan.length() > 0.0001 else v
		var side: Vector3
		if line or cam == null:
			side = _out(p)
		else:
			# faces the camera (a stroke from any side), the foam crest kept on the outside
			side = tan.cross((cam.global_position - p).normalized())
			side = side.normalized() if side.length() > 0.001 else _out(p)
		sides.append(side)
	if not line and cam:
		var d: float = (sides[n / 2] as Vector3).dot(_out(pts[n / 2]))
		if absf(d) > 0.15:
			_sign = signf(d)
	# it thins and breaks up rather than going see-through
	var fade := 1.0 - pow(k, 4.0)
	var thin := 1.0 - 0.6 * k
	var tile := width * 4.0
	var flow := floorf(_t * FLOW * 128.0) / 128.0
	var fr := float(int(_t * FPS + seed_v) % TRAIL_FRAMES)
	var v0 := fr / TRAIL_FRAMES
	var v1 := (fr + 1.0) / TRAIL_FRAMES - 0.5 / 512.0
	var col := Color(1, 1, 1, fade)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var outer: Array = []
	var inner: Array = []
	var us: Array = []
	for i in n:
		var s: float = ss[i]
		var w := width * thin * _shape(s / end)
		w *= smoothstep(tail, tail + 0.12 * end, s) * smoothstep(head, head - 0.05 * end, s)
		var off: Vector3 = (sides[i] as Vector3) * (_sign * w * 0.5)
		outer.append(pts[i] + off)
		inner.append(pts[i] - off)
		us.append(_len(s) / tile - flow)
	for i in n - 1:
		# the trailing part breaks up into separate gobs of water
		var cell := int(ss[i] / step + 0.5)
		if k > 0.0 and (ss[i] - tail) < (head - tail) * (0.3 + 0.5 * k) and posmod(cell * 7 + seed_v * 3, 3) == 0:
			continue
		var ua: float = us[i]
		var ub: float = us[i + 1]
		verts.append_array([outer[i], outer[i + 1], inner[i], inner[i], outer[i + 1], inner[i + 1]])
		uvs.append_array([Vector2(ua, v0), Vector2(ub, v0), Vector2(ua, v1), Vector2(ua, v1), Vector2(ub, v0), Vector2(ub, v1)])
	if not verts.is_empty():
		var cols := PackedColorArray()
		cols.resize(verts.size())
		cols.fill(col)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_COLOR] = cols
		_am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_am.surface_set_material(0, material())
	_ends(head, tail, k)


## The crescent's thickness along it: fattest past the middle, thin at both ends.
func _shape(x: float) -> float:
	if line:
		return 0.6 + 0.4 * sin(PI * clampf(x, 0.0, 1.0))
	return pow(maxf(sin(PI * pow(clampf(x, 0.0, 1.0), 0.8)), 0.0), 0.55)


## A wave curling over off the head once it lands, then spray off the tail twice as it breaks up.
func _ends(head: float, tail: float, k: float) -> void:
	var foam := color.lerp(Color.WHITE, 0.7)
	if _drops == 0 and _t >= draw:
		_drops = 1
		var p := _at(head)
		var dir := (p - _at(head - 0.05)).normalized()
		if not line:
			FX.water_burst(p, "water_curl", width * 2.8, 0.45, 40.0)
		FX.droplets(p, dir + _out(p) * 0.4, 6, foam, 4.5)
	elif (_drops == 1 and k > 0.3) or (_drops == 2 and k > 0.65):
		_drops += 1
		var p := _at(tail)
		FX.droplets(p, (_at(tail + 0.05) - p).normalized() + Vector3.UP * 0.5, 4, foam, 3.0)
