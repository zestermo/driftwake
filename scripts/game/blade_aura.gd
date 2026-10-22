class_name BladeAura
extends MeshInstance3D
## The other awakened blades' aura (dagger shadow, dual wield's twin currents, the twin daggers' venom, the corsair's
## powder; the cutlass, katana and axe have their own): the tree's drawn strip (PetalRibbon.LOOKS) rising off the
## blade's back and flowing to the point, in two crossed sheets so it reads from any side. One per drawn blade (both
## hands' with two); built once per blade length and tree, one shared material per tree stepped once a frame. Player
## keeps it (BladeAura.keep) on every screen through the NF_AURA snapshot flag.

## The strip's height off the back (m, x the blade's length / 0.7) and how far up the blade it starts.
const W := 0.09
const FROM := 0.25
const SAMPLES := 10
const FLOW := 1.5
const FPS := 12.0
const TRAIL_FRAMES := 8
static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _clock := 0.0
static var _ticked := -1
var tree := ""


## Show or hide `tree`'s aura on `body`'s drawn blades (made on first need; another tree's is swapped out).
static func keep(body: Humanoid, tree: String, on: bool) -> void:
	for w in [body.weapon, body.offhand]:
		if w == null or not is_instance_valid(w) or (w as MeshInstance3D).mesh == null:
			continue
		var a := (w as Node).get_node_or_null("BladeAura") as BladeAura
		if a != null and a.tree != tree:
			a.free()
			a = null
		if a == null:
			if not on:
				continue
			a = BladeAura.new()
			a.name = "BladeAura"
			a.tree = tree
			(w as Node).add_child(a)
		var show := on and (w as Node).get_parent() in [body.hand_r, body.hand_l]
		if a.visible != show:
			a.visible = show


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 45.0
	var box := (get_parent() as MeshInstance3D).mesh.get_aabb()
	var key := [tree, snappedf(box.position.z, 0.01), snappedf(box.end.y, 0.01)]
	if not _meshes.has(key):
		_meshes[key] = _build(box.position.z, box.end.y, material(tree))
	mesh = _meshes[key]


func _process(delta: float) -> void:
	if not visible:
		return
	# every blade of the tree shares its material: the materials step once a frame
	if _ticked != Engine.get_process_frames():
		_ticked = Engine.get_process_frames()
		_clock += delta
		var off := Vector3(-floorf(_clock * FLOW * 256.0) / 256.0, float(int(_clock * FPS) % TRAIL_FRAMES) / TRAIL_FRAMES, 0.0)
		for m in _mats.values():
			(m as StandardMaterial3D).uv1_offset = off


static func material(t: String) -> StandardMaterial3D:
	if not _mats.has(t):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.albedo_texture = load("res://assets/textures/fx/%s.png" % PetalRibbon.LOOKS[t][1])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.texture_repeat = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[t] = m
	return _mats[t]


## Two crossed sheets along the blade from FROM to just past the point (local: the blade runs down -Z to `tip`, its
## back toward +y up to `back`), swelling past the middle and thinning to the point.
static func _build(tip: float, back: float, mat: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var v0 := 0.5 / 512.0
	var v1 := 1.0 / TRAIL_FRAMES - 0.5 / 512.0
	var length := -tip
	var h := W * clampf(length / 0.7, 0.6, 1.4)
	for sheet in 2:
		var up := Vector3.UP if sheet == 0 else Vector3(1, 0.4, 0).normalized()
		var rows: Array = []
		for i in SAMPLES + 1:
			var f := lerpf(FROM, 1.04, float(i) / SAMPLES)
			var p := Vector3(0.0, maxf(back * 0.5, 0.01), -length * f)
			var w := h * pow(sin(PI * clampf((f - FROM) / (1.04 - FROM), 0.0, 1.0)), 0.6) * (1.0 if sheet == 0 else 0.8)
			rows.append([p + up * w, p - up * w * 0.15, (f - FROM) * length / (h * 4.0) + sheet * 0.37])
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
	m.surface_set_material(0, mat)
	return m
