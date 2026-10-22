class_name PetalRibbon
extends MeshInstance3D
## A weapon's drawn slash (FX.drawn_slash): the blade in `body`'s hand is sampled every
## frame for `emit` seconds and the pixel-art strip is laid along the path its tip really
## took, so the slash always runs the way the swing went. `kind` picks the look (LOOKS):
## the katana's (plain: steel_trail.png, a thin crescent of steel; awakened by its tree's
## mastery: petal_trail.png, a billowing cloud that curls over at the head, breaks into puffs
## from the tail and sheds petals) or the axe's (plain: axe_trail.png, a heavy crescent of
## iron shedding dust, laid along the bit's path; awakened: ember_trail.png, fire licking off
## a crescent with a charred edge, throwing embers and ash).
## `thrust`: laid along the blade's line instead (a stab), reaching out past the point.
## `fixed`: no blade, a given path drawn on over `emit` (FX.katana_line, FX.katana_arc).
## Camera-facing, the crest on the outside (away from the hilt); in world space, on game time;
## frees itself by its life. Other screens make their own from their copy of the body.

const TRAIL_FRAMES := 8
const FLOW := 1.8
const FPS := 14.0
## Catmull-Rom points between two frames' samples (a fast swing moves its tip ~0.5 m a frame).
const SUB := 3
## How far out along the blade the strip runs (1 = the tip).
const OUT := 1.04
## kind -> [plain strip, awakened strip] (assets/textures/fx/<name>.png).
const LOOKS := {"katana": ["steel_trail", "petal_trail"], "axe": ["axe_trail", "ember_trail"], "dagger": ["steel_trail", "shadow_trail"],
	"dual": ["steel_trail", "twin_trail"], "dual_dagger": ["steel_trail", "venom_trail"], "corsair": ["steel_trail", "powder_trail"]}
## The other elements' bursts (gen_drawn_fx.py): kind -> the cloud let off the head as the cut ends.
const CLOUDS := {"dagger": "shadow_cloud", "dual": "twin_cloud", "dual_dagger": "venom_cloud", "corsair": "powder_cloud"}

var body: Humanoid
var kind := "katana"
var emit := 0.2
var awake := false
var thrust := false
## The off hand's blade (dual wield).
var left := false
var width := 0.34
## Seconds it lasts after the sampling ends (holding, then breaking up from the tail).
var linger := 0.32
var color := Color.WHITE
var seed_v := 0
## Per sample: [base, tip], world space; and the tip in the body's frame when it was taken (the
## way the swing went, read by t/combat/katana_slash).
var samples: Array = []
var local_tips: Array = []
## [[base, tip], ...] in world space, laid in order over `emit` (the crest on the tip's side).
var fixed: Array = []
var _t := 0.0
var _left := 0.0
var _since := 0.0
var _sign := 1.0
var _puffs := 0
var _cloud_at := 0.0
var _am := ArrayMesh.new()
static var _mats: Dictionary = {}


static func material(awakened: bool, look: String = "katana") -> StandardMaterial3D:
	var strip: String = LOOKS[look][1 if awakened else 0]
	if not _mats.has(strip):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load("res://assets/textures/fx/%s.png" % strip)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.texture_repeat = true
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[strip] = m
	return _mats[strip]


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _am
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_left = emit
	_sample()


func _process(delta: float) -> void:
	if fixed.is_empty() and (body == null or not is_instance_valid(body)):
		queue_free()
		return
	_t += delta
	if _left > 0.0:
		# (a hit-stop freezes the body: the window waits for it, or the arc's end is lost)
		if body == null or body._freeze <= 0.0:
			_left -= delta
			_sample()
	else:
		_since += delta
		if _since >= linger:
			queue_free()
			return
	_build()


## The blade's base and tip now (skipped while it hasn't moved: a frozen frame adds nothing).
func _sample() -> void:
	if not fixed.is_empty():
		var due := clampi(ceili(fixed.size() * (1.0 - _left / maxf(emit, 0.001))), 2, fixed.size())
		while samples.size() < due:
			samples.append(fixed[samples.size()])
		return
	var w := body.offhand if left else body.weapon
	if w == null or not is_instance_valid(w) or w.get_parent() not in [body.hand_r, body.hand_l]:
		return
	var box := w.mesh.get_aabb()
	var base := w.global_transform * Vector3(0, 0, box.position.z * 0.3)
	var tip := w.global_transform * Vector3(0, 0, box.position.z * OUT)
	if kind == "axe":
		# (the bit's edge: out on the knuckle side (-y) at the head; the crest away from the hand)
		var hz := WeaponDesigns.axe_head_z(str(w.mesh.get_meta("model", "")))
		base = w.global_transform * Vector3(0, 0, hz * 0.3)
		tip = w.global_transform * Vector3(0, box.position.y * 0.95, hz)
	if not samples.is_empty() and (samples[-1][1] as Vector3).distance_to(tip) < 0.01:
		return
	samples.append([base, tip])
	local_tips.append(body.global_transform.affine_inverse() * tip)


## The path the strip runs along: the tip's (smoothed), or for a thrust the blade's line.
func _path() -> Array:
	var pts: Array = []
	var outs: Array = []
	var n := samples.size()
	if thrust:
		var s: Array = samples[-1]
		var b: Vector3 = s[0]
		var tip: Vector3 = s[1]
		var dir := (tip - b).normalized()
		var reach := 0.6 + 1.4 * minf(_t / 0.12, 1.0)
		for i in 13:
			pts.append(b.lerp(tip, 0.3) + dir * (tip.distance_to(b) * 0.7 + reach) * (float(i) / 12.0))
			outs.append(Vector3.UP)
		return [pts, outs]
	for i in n:
		var p0: Vector3 = samples[maxi(i - 1, 0)][1]
		var p1: Vector3 = samples[i][1]
		var p2: Vector3 = samples[mini(i + 1, n - 1)][1]
		var p3: Vector3 = samples[mini(i + 2, n - 1)][1]
		var o1: Vector3 = (samples[i][1] as Vector3) - (samples[i][0] as Vector3)
		var o2: Vector3 = (samples[mini(i + 1, n - 1)][1] as Vector3) - (samples[mini(i + 1, n - 1)][0] as Vector3)
		# (a given path is dense already: lines and arcs aren't subdivided)
		var steps := SUB if i < n - 1 and fixed.is_empty() else 1
		for k in steps:
			var x := float(k) / SUB
			pts.append(p1.cubic_interpolate(p2, p0, p3, x))
			outs.append(o1.lerp(o2, x).normalized())
	return [pts, outs]


func _build() -> void:
	_am.clear_surfaces()
	if samples.size() < (1 if thrust else 2):
		return
	var path := _path()
	var pts: Array = path[0]
	var outs: Array = path[1]
	var n := pts.size()
	var lens: Array = [0.0]
	for i in range(1, n):
		lens.append(float(lens[i - 1]) + (pts[i] as Vector3).distance_to(pts[i - 1]))
	var total: float = lens[n - 1]
	if total < 0.05:
		return
	# after the sampling, it holds a beat, then breaks up from the tail toward the head
	var k := clampf((_since - linger * 0.25) / (linger * 0.75), 0.0, 1.0)
	var tail := total * pow(k, 1.3)
	var cam := get_viewport().get_camera_3d()
	var sides: Array = []
	for i in n:
		var p: Vector3 = pts[i]
		var tan: Vector3 = (pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		tan = tan.normalized() if tan.length() > 0.0001 else Vector3.UP
		var side: Vector3 = outs[i]
		if cam:
			side = tan.cross((cam.global_position - p).normalized())
			side = side.normalized() if side.length() > 0.001 else outs[i]
		sides.append(side)
	# the crest on the outside: the side the blade points out to, as seen
	var d: float = (sides[n / 2] as Vector3).dot(outs[n / 2])
	if absf(d) > 0.15:
		_sign = signf(d)
	var tile := width * 4.0
	var flow := floorf(_t * FLOW * 128.0) / 128.0
	var fr := float(int(_t * FPS + seed_v) % TRAIL_FRAMES)
	var v0 := fr / TRAIL_FRAMES
	var v1 := (fr + 1.0) / TRAIL_FRAMES - 0.5 / 512.0
	var col := Color(color.r, color.g, color.b, 1.0 - pow(k, 4.0))
	var thin := 1.0 - 0.55 * k
	var outer: Array = []
	var inner: Array = []
	var us: Array = []
	for i in n:
		var s: float = float(lens[i]) / total
		var w := width * thin * _shape(s)
		w *= smoothstep(tail, tail + 0.1 * total, float(lens[i]))
		var off: Vector3 = (sides[i] as Vector3) * (_sign * w)
		# (laid a little outside the tip's path: the cut reaches past the steel)
		var c: Vector3 = (pts[i] as Vector3) + off * 0.15
		outer.append(c + off * 0.5)
		inner.append(c - off * 0.5)
		us.append(float(lens[i]) / tile - flow)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in n - 1:
		# the awakened cloud parts into puffs from the tail as it breaks up
		if awake and k > 0.0 and float(lens[i]) - tail < (total - tail) * (0.3 + 0.5 * k) and posmod(int(float(lens[i]) / (width * 0.5)) * 7 + seed_v * 3, 3) == 0:
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
		_am.surface_set_material(0, material(awake, kind))
	if kind == "axe":
		_shed_axe(pts, lens, tail, k)
	elif awake and kind == "katana":
		_shed(pts, lens, total, tail, k)
	elif awake:
		_shed_drawn(pts, lens, tail, k)


## The thickness along it (0 = the tail, 1 = the head): fattest past the middle, thin at both
## ends; a thrust swells toward the point and narrows to it.
func _shape(x: float) -> float:
	if thrust:
		return pow(clampf(x, 0.0, 1.0), 0.6) * (1.0 - pow(clampf(x, 0.0, 1.0), 8.0)) * 1.2
	return pow(maxf(sin(PI * pow(clampf(x, 0.0, 1.0), 0.75)), 0.0), 0.55)


## The awakened slash: a cloud curling over at the head once the cut's drawn, puffs off the
## tail as it breaks up, petals shed along it as it goes.
func _shed(pts: Array, lens: Array, total: float, tail: float, k: float) -> void:
	var head: Vector3 = pts[pts.size() - 1]
	if _puffs == 0 and _left <= 0.0:
		_puffs = 1
		FX.katana_burst(head, "katana_cloud", width * 2.2, 0.5)
		FX.sakura(head, (head - (pts[maxi(pts.size() - 4, 0)] as Vector3)).normalized() + Vector3.UP * 0.3, 4, 2.5)
	elif (_puffs == 1 and k > 0.25) or (_puffs == 2 and k > 0.6):
		_puffs += 1
		var at := _at(pts, lens, tail)
		FX.katana_burst(at, "katana_cloud", width * 1.6, 0.45)
	_cloud_at += get_process_delta_time()
	if _left > 0.0 and _cloud_at > 0.07:
		_cloud_at = 0.0
		FX.sakura(head, Vector3.UP * 0.4 + (head - (pts[maxi(pts.size() - 4, 0)] as Vector3)).normalized(), 2, 1.6)


## The axe's: plain, a puff of dust off the head once the bite's drawn and one off the tail as
## it breaks; awakened, a gout of fire at the head, cinders flying off it as it goes and ash
## drifting off the tail as it chars away.
func _shed_axe(pts: Array, lens: Array, tail: float, k: float) -> void:
	var head: Vector3 = pts[pts.size() - 1]
	var way := (head - (pts[maxi(pts.size() - 4, 0)] as Vector3)).normalized()
	if _puffs == 0 and _left <= 0.0:
		_puffs = 1
		if awake:
			FX.drawn_burst(head, "ember_cloud", width * 2.0, 0.5)
			FX.cinders(head, way + Vector3.UP * 0.5, 5, 3.0)
		else:
			FX.puff(head, "dust", 2, width * 1.8, 0.6, Color.WHITE, 0.7, way + Vector3.UP)
	elif _puffs == 1 and k > 0.35:
		_puffs = 2
		var at := _at(pts, lens, tail)
		if awake:
			FX.ash(at, Vector3.UP, 4, 1.0)
		else:
			FX.puff(at, "dust", 1, width * 1.4, 0.55, Color.WHITE, 0.4)
	_cloud_at += get_process_delta_time()
	if awake and _left > 0.0 and _cloud_at > 0.08:
		_cloud_at = 0.0
		FX.cinders(head, Vector3.UP * 0.5 + way, 2, 2.0)


## The other awakened elements': a burst of the element off the head once the cut's drawn, its material thrown off it,
## and a smaller one off the tail as it breaks.
func _shed_drawn(pts: Array, lens: Array, tail: float, k: float) -> void:
	var head: Vector3 = pts[pts.size() - 1]
	var way := (head - (pts[maxi(pts.size() - 4, 0)] as Vector3)).normalized()
	if _puffs == 0 and _left <= 0.0:
		_puffs = 1
		FX.drawn_burst(head, CLOUDS[kind], width * 2.0, 0.45)
		FX.element(kind, head, way + Vector3.UP * 0.4, 4, 2.5)
	elif _puffs == 1 and k > 0.35:
		_puffs = 2
		FX.drawn_burst(_at(pts, lens, tail), CLOUDS[kind], width * 1.3, 0.4)


func _at(pts: Array, lens: Array, l: float) -> Vector3:
	for i in range(1, pts.size()):
		if float(lens[i]) >= l:
			return pts[i]
	return pts[pts.size() - 1]
