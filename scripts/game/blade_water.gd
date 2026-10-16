class_name BladeWater
extends MeshInstance3D
## Water winding round the awakened cutlass (the sword tree's first mastery, "elem_sword"):
## two strands of the pixel-art water strip (water_trail.png) spiralling up the blade,
## flowing toward the tip and turning, while the cutlass is in hand. A child of the weapon's
## mesh; Player keeps it (BladeWater.keep) on every screen through the NF_TIDE snapshot flag.

## Per strand: turns, width, phase. Few loose turns that speed up and slow down along the
## blade (a serpent winding up it, not a spring).
const STRANDS := [[1.15, 0.11, 0.0], [0.8, 0.07, 2.4]]
## The oval round the blade: wide across its flat, close over its edge and back.
const RX := 0.15
const RY := 0.055
const SAMPLES := 44
const FLOW := 1.6
const FPS := 12.0
const TRAIL_FRAMES := 8
static var _mat: StandardMaterial3D
static var _meshes: Dictionary = {}
static var _clock := 0.0
static var _ticked := -1


## Show or hide the water on `body`'s main-hand blade (made on first need).
static func keep(body: Humanoid, on: bool) -> void:
	var w := body.weapon as MeshInstance3D
	if w == null or not is_instance_valid(w) or w.mesh == null:
		return
	var bw := w.get_node_or_null("BladeWater") as BladeWater
	if bw == null:
		if not on:
			return
		bw = BladeWater.new()
		bw.name = "BladeWater"
		w.add_child(bw)
	bw.visible = on and w.get_parent() in [body.hand_r, body.hand_l]


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 45.0
	var box := (get_parent() as MeshInstance3D).mesh.get_aabb()
	# the guard spans the blade's width, so the wider of x and y is the flat
	var flat_x := box.size.x >= box.size.y
	var key := [snappedf(box.position.z, 0.01), flat_x]
	if not _meshes.has(key):
		_meshes[key] = _build(box.position.z, flat_x)
	mesh = _meshes[key]


func _process(delta: float) -> void:
	if not visible:
		return
	# a sway, not a spin: the oval keeps to the flat of the blade
	rotation.z = 0.18 * sin(_clock * 2.6)
	# every blade shares the material: step its strip once a frame
	if _ticked != Engine.get_process_frames():
		_ticked = Engine.get_process_frames()
		_clock += delta
		var m := material()
		m.uv1_offset = Vector3(-floorf(_clock * FLOW * 256.0) / 256.0, float(int(_clock * FPS) % TRAIL_FRAMES) / TRAIL_FRAMES, 0.0)


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_mat.alpha_scissor_threshold = 0.5
		_mat.albedo_texture = load("res://assets/textures/fx/water_trail.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mat.texture_repeat = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


## Two strands winding round the blade's axis (local -z) from near the guard to just past
## the tip, on an oval laid along the flat (`flat_x`: the blade's width is local x).
static func _build(tip: float, flat_x: bool) -> ArrayMesh:
	var z0 := tip * 0.3
	var z1 := tip * 1.04
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var v0 := 0.5 / 512.0
	var v1 := 1.0 / TRAIL_FRAMES - 0.5 / 512.0
	for st in STRANDS:
		var turns: float = st[0]
		var width: float = st[1]
		var ph: float = st[2]
		var pts: Array = []
		var outs: Array = []
		for i in SAMPLES + 1:
			var f := float(i) / SAMPLES
			# the turn runs unevenly (lingering over the flats), the oval swells and pinches,
			# and the whole strand undulates side to side as it climbs
			var a := ph + turns * TAU * f + 0.7 * sin(TAU * 0.75 * f + ph)
			var m := (1.0 + 0.3 * sin(TAU * 1.3 * f + ph * 0.7)) * (1.0 - 0.3 * f)
			var wx := cos(a) * RX * m + 0.035 * sin(TAU * 1.6 * f + ph)
			var wy := sin(a) * RY * m
			var o := Vector2(cos(a) / RX, sin(a) / RY).normalized()
			if flat_x:
				pts.append(Vector3(wx, wy, lerpf(z0, z1, f)))
				outs.append(Vector3(o.x, o.y, 0.0))
			else:
				pts.append(Vector3(wy, wx, lerpf(z0, z1, f)))
				outs.append(Vector3(o.y, o.x, 0.0))
		var along := 0.0
		var rows: Array = []
		for i in SAMPLES + 1:
			var f := float(i) / SAMPLES
			var p: Vector3 = pts[i]
			var tan: Vector3 = (pts[mini(i + 1, SAMPLES)] - pts[maxi(i - 1, 0)]).normalized()
			var across := tan.cross(outs[i] as Vector3).normalized()
			var w := width * pow(sin(PI * clampf(f * 0.92 + 0.04, 0.0, 1.0)), 0.5)
			if i > 0:
				along += p.distance_to(pts[i - 1])
			rows.append([p + across * w * 0.5, p - across * w * 0.5, along / (width * 4.0) + ph * 0.15])
		for i in SAMPLES:
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			verts.append_array([a[0], b[0], a[1], a[1], b[0], b[1]])
			uvs.append_array([Vector2(a[2], v0), Vector2(b[2], v0), Vector2(a[2], v1), Vector2(a[2], v1), Vector2(b[2], v0), Vector2(b[2], v1)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material())
	return m
