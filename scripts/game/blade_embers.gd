class_name BladeEmbers
extends MeshInstance3D
## Fire on the awakened axe (the axe tree's first mastery, "elem_axe"): the ember strip (ember_trail.png) licking off
## the bit's edge, the flames flowing along it, in two crossed sheets so it reads from any side, and cinders and ash
## let go off it now and then (world coords, so they trail the swing). A child of the weapon's mesh; Player keeps it
## (BladeEmbers.keep) on every screen through the NF_EMBERS snapshot flag.

## How far the flames stand off the edge (m), and how far along the head they run either side of its middle.
const W := 0.24
const HALF := 0.15
const SAMPLES := 10
const FLOW := 1.6
const FPS := 12.0
const TRAIL_FRAMES := 8
static var _mat: StandardMaterial3D
static var _meshes: Dictionary = {}
static var _clock := 0.0
static var _ticked := -1
var _cinders: CPUParticles3D


## Show or hide the fire on `body`'s axe (made on first need).
static func keep(body: Humanoid, on: bool) -> void:
	var w := body.weapon as MeshInstance3D
	if w == null or not is_instance_valid(w) or w.mesh == null:
		return
	var be := w.get_node_or_null("BladeEmbers") as BladeEmbers
	if be == null:
		if not on:
			return
		be = BladeEmbers.new()
		be.name = "BladeEmbers"
		w.add_child(be)
	var show := on and w.get_parent() in [body.hand_r, body.hand_l]
	if be.visible != show:
		be.visible = show
		be._cinders.emitting = show


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 45.0
	var m := (get_parent() as MeshInstance3D).mesh
	var hz := WeaponDesigns.axe_head_z(str(m.get_meta("model", "")))
	var edge := m.get_aabb().position.y
	var key := Vector2(snappedf(hz, 0.01), snappedf(edge, 0.01))
	if not _meshes.has(key):
		_meshes[key] = _build(hz, edge)
	mesh = _meshes[key]
	_cinders = CPUParticles3D.new()
	_cinders.amount = 5
	_cinders.lifetime = 0.9
	_cinders.local_coords = false
	_cinders.position = Vector3(0, edge - 0.04, hz)
	_cinders.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_cinders.emission_box_extents = Vector3(0.02, 0.02, HALF * 0.8)
	_cinders.direction = Vector3.UP
	_cinders.spread = 40.0
	_cinders.gravity = Vector3(0, 1.2, 0)
	_cinders.initial_velocity_min = 0.3
	_cinders.initial_velocity_max = 0.8
	_cinders.damping_min = 1.5
	_cinders.damping_max = 1.5
	_cinders.anim_speed_min = 1.0
	_cinders.anim_speed_max = 1.0
	_cinders.scale_amount_min = 0.6
	_cinders.scale_amount_max = 1.1
	# (the autoload by path: Player loads this, and tools compile Player before the autoloads)
	_cinders.mesh = get_node("/root/FX").cinder_quad(0.12)
	_cinders.visibility_range_end = 45.0
	_cinders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cinders)
	_cinders.emitting = visible


func _process(delta: float) -> void:
	if not visible:
		return
	# every axe shares the material: step its strip once a frame
	if _ticked != Engine.get_process_frames():
		_ticked = Engine.get_process_frames()
		_clock += delta
		material().uv1_offset = Vector3(-floorf(_clock * FLOW * 256.0) / 256.0, float(int(_clock * FPS) % TRAIL_FRAMES) / TRAIL_FRAMES, 0.0)


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_mat.alpha_scissor_threshold = 0.5
		_mat.albedo_texture = load("res://assets/textures/fx/ember_trail.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mat.texture_repeat = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


## Two crossed sheets of the strip along the bit's edge (local: the head at z `hz`, its edge out at y `edge` on the
## knuckle side, -y): the flames' crest away from the edge, tallest at the middle of the bit, thinning to its horns.
static func _build(hz: float, edge: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var v0 := 0.5 / 512.0
	var v1 := 1.0 / TRAIL_FRAMES - 0.5 / 512.0
	for sheet in 2:
		var out := Vector3.DOWN if sheet == 0 else Vector3(0.6, -0.8, 0).normalized()
		var rows: Array = []
		for i in SAMPLES + 1:
			var f := float(i) / SAMPLES
			var p := Vector3(0, edge * (0.92 - 0.12 * pow(2.0 * f - 1.0, 2.0)), hz - 0.04 + HALF * (2.0 * f - 1.0))
			var w := W * pow(sin(PI * f), 0.6) * (1.0 if sheet == 0 else 0.75)
			rows.append([p + out * w, p - out * w * 0.25, f * HALF * 2.0 / (W * 3.0) + sheet * 0.41])
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
